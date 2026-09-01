#include <android/log.h>
#include <android/native_activity.h>
#include <jni.h>
#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define ZAPP_ANDROID_EVENT_CAPACITY 64
#define ZAPP_ANDROID_TEXT_CAPACITY 256
#define ZAPP_LOG_TAG "zapp-ime"

enum zapp_android_event_kind {
    ZAPP_ANDROID_COMPOSITION_CHANGED = 1,
    ZAPP_ANDROID_COMPOSITION_COMMITTED = 2,
    ZAPP_ANDROID_COMPOSITION_CANCELLED = 3,
    ZAPP_ANDROID_BACKSPACE = 4,
    ZAPP_ANDROID_SUBMIT = 5,
};

typedef struct zapp_android_event {
    int32_t kind_value;
    uint32_t count;
    size_t text_length;
    uint8_t text_buffer[ZAPP_ANDROID_TEXT_CAPACITY];
} zapp_android_event;

static pthread_mutex_t zapp_event_mutex = PTHREAD_MUTEX_INITIALIZER;
static zapp_android_event zapp_events[ZAPP_ANDROID_EVENT_CAPACITY];
static size_t zapp_event_head;
static size_t zapp_event_count;
static ANativeActivity *zapp_activity;

static size_t zapp_write_utf8(uint32_t codepoint, uint8_t *output, size_t capacity) {
    if (codepoint <= 0x7f) {
        if (capacity < 1) return 0;
        output[0] = (uint8_t)codepoint;
        return 1;
    }
    if (codepoint <= 0x7ff) {
        if (capacity < 2) return 0;
        output[0] = (uint8_t)(0xc0 | (codepoint >> 6));
        output[1] = (uint8_t)(0x80 | (codepoint & 0x3f));
        return 2;
    }
    if (codepoint <= 0xffff) {
        if (capacity < 3) return 0;
        output[0] = (uint8_t)(0xe0 | (codepoint >> 12));
        output[1] = (uint8_t)(0x80 | ((codepoint >> 6) & 0x3f));
        output[2] = (uint8_t)(0x80 | (codepoint & 0x3f));
        return 3;
    }
    if (capacity < 4) return 0;
    output[0] = (uint8_t)(0xf0 | (codepoint >> 18));
    output[1] = (uint8_t)(0x80 | ((codepoint >> 12) & 0x3f));
    output[2] = (uint8_t)(0x80 | ((codepoint >> 6) & 0x3f));
    output[3] = (uint8_t)(0x80 | (codepoint & 0x3f));
    return 4;
}

static size_t zapp_string_to_utf8(JNIEnv *env, jstring text, uint8_t *output, size_t capacity) {
    if (text == NULL) return 0;
    const jsize length = (*env)->GetStringLength(env, text);
    const jchar *characters = (*env)->GetStringChars(env, text, NULL);
    if (characters == NULL) return 0;

    size_t written = 0;
    for (jsize index = 0; index < length;) {
        uint32_t codepoint = characters[index++];
        if (codepoint >= 0xd800 && codepoint <= 0xdbff && index < length) {
            const uint32_t low = characters[index];
            if (low >= 0xdc00 && low <= 0xdfff) {
                index += 1;
                codepoint = 0x10000 + ((codepoint - 0xd800) << 10) + (low - 0xdc00);
            } else {
                codepoint = 0xfffd;
            }
        } else if (codepoint >= 0xd800 && codepoint <= 0xdfff) {
            codepoint = 0xfffd;
        }
        const size_t encoded = zapp_write_utf8(codepoint, output + written, capacity - written);
        if (encoded == 0) break;
        written += encoded;
    }
    (*env)->ReleaseStringChars(env, text, characters);
    return written;
}

static void zapp_push_event(int32_t kind, uint32_t count, JNIEnv *env, jstring text) {
    zapp_android_event event;
    memset(&event, 0, sizeof(event));
    event.kind_value = kind;
    event.count = count;
    if (env != NULL && text != NULL) {
        event.text_length = zapp_string_to_utf8(env, text, event.text_buffer, sizeof(event.text_buffer));
    }

    pthread_mutex_lock(&zapp_event_mutex);
    if (zapp_event_count == ZAPP_ANDROID_EVENT_CAPACITY) {
        zapp_event_head = (zapp_event_head + 1) % ZAPP_ANDROID_EVENT_CAPACITY;
        zapp_event_count -= 1;
        __android_log_print(ANDROID_LOG_WARN, ZAPP_LOG_TAG, "IME queue full; dropped oldest event");
    }
    const size_t tail = (zapp_event_head + zapp_event_count) % ZAPP_ANDROID_EVENT_CAPACITY;
    zapp_events[tail] = event;
    zapp_event_count += 1;
    pthread_mutex_unlock(&zapp_event_mutex);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionChanged(JNIEnv *env, jclass clazz, jstring text) {
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_COMPOSITION_CHANGED, 0, env, text);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionCommitted(JNIEnv *env, jclass clazz, jstring text) {
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_COMPOSITION_COMMITTED, 0, env, text);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionCancelled(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_COMPOSITION_CANCELLED, 0, NULL, NULL);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeBackspace(JNIEnv *env, jclass clazz, jint count) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_BACKSPACE, count > 0 ? (uint32_t)count : 1, NULL, NULL);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeSubmit(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_SUBMIT, 0, NULL, NULL);
}

void zapp_android_bridge_attach(const void *activity) {
    zapp_activity = (ANativeActivity *)activity;
}

void zapp_android_bridge_set_ime_visible(bool visible) {
    ANativeActivity *activity = zapp_activity;
    if (activity == NULL || activity->vm == NULL || activity->clazz == NULL) return;

    JNIEnv *env = NULL;
    bool attached = false;
    const jint env_status = (*activity->vm)->GetEnv(activity->vm, (void **)&env, JNI_VERSION_1_6);
    if (env_status == JNI_EDETACHED) {
        if ((*activity->vm)->AttachCurrentThread(activity->vm, &env, NULL) != JNI_OK) return;
        attached = true;
    } else if (env_status != JNI_OK) {
        return;
    }

    jclass activity_class = (*env)->GetObjectClass(env, activity->clazz);
    if (activity_class != NULL) {
        jmethodID method = (*env)->GetMethodID(env, activity_class, "setImeVisibleFromNative", "(Z)V");
        if (method != NULL) {
            (*env)->CallVoidMethod(env, activity->clazz, method, visible ? JNI_TRUE : JNI_FALSE);
        }
        (*env)->DeleteLocalRef(env, activity_class);
    }
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    if (attached) (*activity->vm)->DetachCurrentThread(activity->vm);
}

bool zapp_android_bridge_poll(zapp_android_event *event) {
    if (event == NULL) return false;
    pthread_mutex_lock(&zapp_event_mutex);
    if (zapp_event_count == 0) {
        pthread_mutex_unlock(&zapp_event_mutex);
        return false;
    }
    *event = zapp_events[zapp_event_head];
    zapp_event_head = (zapp_event_head + 1) % ZAPP_ANDROID_EVENT_CAPACITY;
    zapp_event_count -= 1;
    pthread_mutex_unlock(&zapp_event_mutex);
    return true;
}

void zapp_android_bridge_reset(void) {
    pthread_mutex_lock(&zapp_event_mutex);
    zapp_event_head = 0;
    zapp_event_count = 0;
    pthread_mutex_unlock(&zapp_event_mutex);
    zapp_activity = NULL;
}
