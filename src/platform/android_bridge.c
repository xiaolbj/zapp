#include <android/log.h>
#include <android/native_activity.h>
#include <jni.h>
#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define ZAPP_ANDROID_EVENT_CAPACITY 64
#define ZAPP_ANDROID_PAYLOAD_CAPACITY 1024
#define ZAPP_LOG_TAG "zapp-platform"

enum zapp_android_event_kind {
    ZAPP_ANDROID_COMPOSITION_CHANGED = 1,
    ZAPP_ANDROID_COMPOSITION_COMMITTED = 2,
    ZAPP_ANDROID_COMPOSITION_CANCELLED = 3,
    ZAPP_ANDROID_BACKSPACE = 4,
    ZAPP_ANDROID_SUBMIT = 5,
    ZAPP_ANDROID_PERMISSION_RESULT = 6,
    ZAPP_ANDROID_FILE_SELECTED = 7,
    ZAPP_ANDROID_FILE_SELECTION_CANCELLED = 8,
};

typedef struct zapp_android_event {
    int32_t kind_value;
    int32_t permission_value;
    uint64_t request_id;
    uint32_t count;
    bool granted;
    uint8_t reserved[3];
    size_t text_length;
    uint8_t text_buffer[ZAPP_ANDROID_PAYLOAD_CAPACITY];
} zapp_android_event;

typedef struct zapp_jni_scope {
    JavaVM *vm;
    JNIEnv *env;
    bool attached;
} zapp_jni_scope;

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

static void zapp_push_event(
    int32_t kind,
    int32_t permission,
    uint64_t request_id,
    uint32_t count,
    bool granted,
    JNIEnv *env,
    jstring text
) {
    zapp_android_event event;
    memset(&event, 0, sizeof(event));
    event.kind_value = kind;
    event.permission_value = permission;
    event.request_id = request_id;
    event.count = count;
    event.granted = granted;
    if (env != NULL && text != NULL) {
        event.text_length = zapp_string_to_utf8(env, text, event.text_buffer, sizeof(event.text_buffer));
    }

    pthread_mutex_lock(&zapp_event_mutex);
    if (zapp_event_count == ZAPP_ANDROID_EVENT_CAPACITY) {
        zapp_event_head = (zapp_event_head + 1) % ZAPP_ANDROID_EVENT_CAPACITY;
        zapp_event_count -= 1;
        __android_log_print(ANDROID_LOG_WARN, ZAPP_LOG_TAG, "event queue full; dropped oldest event");
    }
    const size_t tail = (zapp_event_head + zapp_event_count) % ZAPP_ANDROID_EVENT_CAPACITY;
    zapp_events[tail] = event;
    zapp_event_count += 1;
    pthread_mutex_unlock(&zapp_event_mutex);
}

static bool zapp_begin_jni_scope(zapp_jni_scope *scope) {
    memset(scope, 0, sizeof(*scope));
    ANativeActivity *activity = zapp_activity;
    if (activity == NULL || activity->vm == NULL || activity->clazz == NULL) return false;
    scope->vm = activity->vm;

    const jint status = (*scope->vm)->GetEnv(scope->vm, (void **)&scope->env, JNI_VERSION_1_6);
    if (status == JNI_EDETACHED) {
        if ((*scope->vm)->AttachCurrentThread(scope->vm, &scope->env, NULL) != JNI_OK) return false;
        scope->attached = true;
    } else if (status != JNI_OK) {
        return false;
    }
    return true;
}

static bool zapp_finish_jni_call(zapp_jni_scope *scope) {
    bool success = true;
    if ((*scope->env)->ExceptionCheck(scope->env)) {
        (*scope->env)->ExceptionDescribe(scope->env);
        (*scope->env)->ExceptionClear(scope->env);
        success = false;
    }
    if (scope->attached) (*scope->vm)->DetachCurrentThread(scope->vm);
    return success;
}

static jobject zapp_activity_object(void) {
    ANativeActivity *activity = zapp_activity;
    return activity == NULL ? NULL : activity->clazz;
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionChanged(JNIEnv *env, jclass clazz, jstring text) {
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_COMPOSITION_CHANGED, 0, 0, 0, false, env, text);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionCommitted(JNIEnv *env, jclass clazz, jstring text) {
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_COMPOSITION_COMMITTED, 0, 0, 0, false, env, text);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionCancelled(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_COMPOSITION_CANCELLED, 0, 0, 0, false, NULL, NULL);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeBackspace(JNIEnv *env, jclass clazz, jint count) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_BACKSPACE, 0, 0, count > 0 ? (uint32_t)count : 1, false, NULL, NULL);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeSubmit(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_SUBMIT, 0, 0, 0, false, NULL, NULL);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativePermissionResult(
    JNIEnv *env,
    jclass clazz,
    jlong request_id,
    jint permission,
    jboolean granted
) {
    (void)env;
    (void)clazz;
    zapp_push_event(
        ZAPP_ANDROID_PERMISSION_RESULT,
        (int32_t)permission,
        (uint64_t)request_id,
        0,
        granted == JNI_TRUE,
        NULL,
        NULL
    );
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeFileSelected(
    JNIEnv *env,
    jclass clazz,
    jlong request_id,
    jstring uri
) {
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_FILE_SELECTED, 0, (uint64_t)request_id, 0, false, env, uri);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeFileSelectionCancelled(
    JNIEnv *env,
    jclass clazz,
    jlong request_id
) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_FILE_SELECTION_CANCELLED, 0, (uint64_t)request_id, 0, false, NULL, NULL);
}

void zapp_android_bridge_attach(const void *activity) {
    zapp_activity = (ANativeActivity *)activity;
}

void zapp_android_bridge_set_ime_visible(bool visible) {
    zapp_jni_scope scope;
    if (!zapp_begin_jni_scope(&scope)) return;
    jobject activity = zapp_activity_object();
    jclass activity_class = (*scope.env)->GetObjectClass(scope.env, activity);
    if (activity_class != NULL) {
        jmethodID method = (*scope.env)->GetMethodID(scope.env, activity_class, "setImeVisibleFromNative", "(Z)V");
        if (method != NULL) {
            (*scope.env)->CallVoidMethod(scope.env, activity, method, visible ? JNI_TRUE : JNI_FALSE);
        }
        (*scope.env)->DeleteLocalRef(scope.env, activity_class);
    }
    (void)zapp_finish_jni_call(&scope);
}

bool zapp_android_bridge_request_permission(uint64_t request_id, int32_t permission) {
    zapp_jni_scope scope;
    if (!zapp_begin_jni_scope(&scope)) return false;
    jobject activity = zapp_activity_object();
    jclass activity_class = (*scope.env)->GetObjectClass(scope.env, activity);
    if (activity_class != NULL) {
        jmethodID method = (*scope.env)->GetMethodID(scope.env, activity_class, "requestPermissionFromNative", "(JI)V");
        if (method != NULL) {
            (*scope.env)->CallVoidMethod(scope.env, activity, method, (jlong)request_id, (jint)permission);
        }
        (*scope.env)->DeleteLocalRef(scope.env, activity_class);
    }
    return zapp_finish_jni_call(&scope) && activity_class != NULL;
}

bool zapp_android_bridge_open_file(uint64_t request_id) {
    zapp_jni_scope scope;
    if (!zapp_begin_jni_scope(&scope)) return false;
    jobject activity = zapp_activity_object();
    jclass activity_class = (*scope.env)->GetObjectClass(scope.env, activity);
    if (activity_class != NULL) {
        jmethodID method = (*scope.env)->GetMethodID(scope.env, activity_class, "openFileFromNative", "(J)V");
        if (method != NULL) {
            (*scope.env)->CallVoidMethod(scope.env, activity, method, (jlong)request_id);
        }
        (*scope.env)->DeleteLocalRef(scope.env, activity_class);
    }
    return zapp_finish_jni_call(&scope) && activity_class != NULL;
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
