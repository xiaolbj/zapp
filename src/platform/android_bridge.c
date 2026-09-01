#include <android/log.h>
#include <android/native_activity.h>
#include <jni.h>
#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "android_crash_report.h"

#define ZAPP_ANDROID_EVENT_CAPACITY 64
#define ZAPP_ANDROID_STREAM_QUEUE_LIMIT 56
#define ZAPP_ANDROID_PAYLOAD_CAPACITY 4096
#define ZAPP_FILE_DISPLAY_NAME_CAPACITY 256
#define ZAPP_FILE_MIME_TYPE_CAPACITY 128
#define ZAPP_ACCESSIBILITY_NODE_CAPACITY 96
#define ZAPP_ACCESSIBILITY_TEXT_CAPACITY 128
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
    ZAPP_ANDROID_ACCESSIBILITY_ACTION = 9,
    ZAPP_ANDROID_FILE_READ_COMPLETED = 10,
    ZAPP_ANDROID_FILE_READ_FAILED = 11,
    ZAPP_ANDROID_FILE_STREAM_CHUNK = 12,
    ZAPP_ANDROID_FILE_STREAM_COMPLETED = 13,
    ZAPP_ANDROID_FILE_STREAM_FAILED = 14,
    ZAPP_ANDROID_FILE_STREAM_CANCELLED = 15,
    ZAPP_ANDROID_NATIVE_CRASH_RECOVERED = 16,
    ZAPP_ANDROID_CRASH_REPORT_EXPORT_RESULT = 17,
    ZAPP_ANDROID_NAVIGATION_REQUESTED = 18,
};

typedef struct zapp_android_event {
    int32_t kind_value;
    int32_t detail_value;
    uint64_t request_id;
    uint32_t count;
    uint32_t element_id;
    int32_t action_value;
    bool granted;
    bool truncated;
    uint8_t reserved[2];
    size_t text_length;
    uint8_t text_buffer[ZAPP_ANDROID_PAYLOAD_CAPACITY];
    uint64_t file_size;
    uint16_t display_name_length;
    uint16_t mime_type_length;
    bool file_size_known;
    uint8_t metadata_reserved[3];
    uint8_t display_name_buffer[ZAPP_FILE_DISPLAY_NAME_CAPACITY];
    uint8_t mime_type_buffer[ZAPP_FILE_MIME_TYPE_CAPACITY];
    uint64_t crash_absolute_pc;
    int64_t crash_timestamp_seconds;
    int32_t crash_process_id;
    int32_t crash_thread_id;
    uint32_t crash_architecture;
    uint32_t crash_flags;
    uint8_t crash_build_id_length;
    uint8_t crash_build_id[ZAPP_ANDROID_BUILD_ID_CAPACITY];
    uint8_t crash_reserved[3];
} zapp_android_event;

typedef struct zapp_accessibility_node {
    uint32_t element_id;
    int32_t role_value;
    uint32_t flags;
    float x;
    float y;
    float width;
    float height;
    float value;
    uint16_t level;
    uint16_t label_length;
    uint16_t value_text_length;
    uint16_t reserved;
    uint8_t label[ZAPP_ACCESSIBILITY_TEXT_CAPACITY];
    uint8_t value_text[ZAPP_ACCESSIBILITY_TEXT_CAPACITY];
} zapp_accessibility_node;

_Static_assert(sizeof(zapp_android_event) == 4592, "Zig/C Android event ABI mismatch");
_Static_assert(sizeof(zapp_accessibility_node) == 296, "Zig/C accessibility node ABI mismatch");

typedef struct zapp_jni_scope {
    JavaVM *vm;
    JNIEnv *env;
    bool attached;
} zapp_jni_scope;

static pthread_mutex_t zapp_event_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t zapp_event_space_available = PTHREAD_COND_INITIALIZER;
static zapp_android_event zapp_events[ZAPP_ANDROID_EVENT_CAPACITY];
static size_t zapp_event_head;
static size_t zapp_event_count;
static bool zapp_bridge_active;
static pthread_mutex_t zapp_accessibility_mutex = PTHREAD_MUTEX_INITIALIZER;
static zapp_accessibility_node zapp_accessibility_nodes[ZAPP_ACCESSIBILITY_NODE_CAPACITY];
static size_t zapp_accessibility_count;
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

static jstring zapp_utf8_to_string(JNIEnv *env, const uint8_t *text, size_t length) {
    jchar utf16[ZAPP_ANDROID_PAYLOAD_CAPACITY];
    size_t input = 0;
    jsize output = 0;
    while (input < length && output < (jsize)(sizeof(utf16) / sizeof(utf16[0]))) {
        const uint8_t first = text[input++];
        uint32_t codepoint = 0xfffd;
        size_t continuation_count = 0;
        if (first < 0x80) {
            codepoint = first;
        } else if ((first & 0xe0) == 0xc0) {
            codepoint = first & 0x1f;
            continuation_count = 1;
        } else if ((first & 0xf0) == 0xe0) {
            codepoint = first & 0x0f;
            continuation_count = 2;
        } else if ((first & 0xf8) == 0xf0) {
            codepoint = first & 0x07;
            continuation_count = 3;
        }
        bool valid = input + continuation_count <= length;
        for (size_t index = 0; valid && index < continuation_count; ++index) {
            const uint8_t continuation = text[input + index];
            if ((continuation & 0xc0) != 0x80) {
                valid = false;
            } else {
                codepoint = (codepoint << 6) | (continuation & 0x3f);
            }
        }
        if (valid) input += continuation_count;
        if (!valid || codepoint > 0x10ffff || (codepoint >= 0xd800 && codepoint <= 0xdfff)) {
            codepoint = 0xfffd;
        }
        if (codepoint <= 0xffff) {
            utf16[output++] = (jchar)codepoint;
        } else if (output + 1 < (jsize)(sizeof(utf16) / sizeof(utf16[0]))) {
            codepoint -= 0x10000;
            utf16[output++] = (jchar)(0xd800 | (codepoint >> 10));
            utf16[output++] = (jchar)(0xdc00 | (codepoint & 0x3ff));
        } else {
            break;
        }
    }
    return (*env)->NewString(env, utf16, output);
}

static void zapp_enqueue_event(const zapp_android_event *event) {
    pthread_mutex_lock(&zapp_event_mutex);
    if (zapp_event_count == ZAPP_ANDROID_EVENT_CAPACITY) {
        __android_log_print(ANDROID_LOG_WARN, ZAPP_LOG_TAG, "event queue full; dropped incoming event");
        pthread_mutex_unlock(&zapp_event_mutex);
        return;
    }
    const size_t tail = (zapp_event_head + zapp_event_count) % ZAPP_ANDROID_EVENT_CAPACITY;
    zapp_events[tail] = *event;
    zapp_event_count += 1;
    pthread_mutex_unlock(&zapp_event_mutex);
}

static bool zapp_enqueue_stream_event(const zapp_android_event *event) {
    pthread_mutex_lock(&zapp_event_mutex);
    while (zapp_event_count >= ZAPP_ANDROID_STREAM_QUEUE_LIMIT && zapp_bridge_active) {
        pthread_cond_wait(&zapp_event_space_available, &zapp_event_mutex);
    }
    if (!zapp_bridge_active) {
        pthread_mutex_unlock(&zapp_event_mutex);
        return false;
    }
    const size_t tail = (zapp_event_head + zapp_event_count) % ZAPP_ANDROID_EVENT_CAPACITY;
    zapp_events[tail] = *event;
    zapp_event_count += 1;
    pthread_mutex_unlock(&zapp_event_mutex);
    return true;
}

static void zapp_push_event(
    int32_t kind,
    int32_t detail,
    uint64_t request_id,
    uint32_t count,
    uint32_t element_id,
    int32_t action_value,
    bool granted,
    JNIEnv *env,
    jstring text
) {
    zapp_android_event event;
    memset(&event, 0, sizeof(event));
    event.kind_value = kind;
    event.detail_value = detail;
    event.request_id = request_id;
    event.count = count;
    event.element_id = element_id;
    event.action_value = action_value;
    event.granted = granted;
    if (env != NULL && text != NULL) {
        event.text_length = zapp_string_to_utf8(env, text, event.text_buffer, sizeof(event.text_buffer));
    }

    zapp_enqueue_event(&event);
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
    zapp_push_event(ZAPP_ANDROID_COMPOSITION_CHANGED, 0, 0, 0, 0, 0, false, env, text);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionCommitted(JNIEnv *env, jclass clazz, jstring text) {
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_COMPOSITION_COMMITTED, 0, 0, 0, 0, 0, false, env, text);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeCompositionCancelled(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_COMPOSITION_CANCELLED, 0, 0, 0, 0, 0, false, NULL, NULL);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeBackspace(JNIEnv *env, jclass clazz, jint count) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_BACKSPACE, 0, 0, count > 0 ? (uint32_t)count : 1, 0, 0, false, NULL, NULL);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeSubmit(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_SUBMIT, 0, 0, 0, 0, 0, false, NULL, NULL);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeNavigationRequested(JNIEnv *env, jclass clazz, jint command) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_NAVIGATION_REQUESTED, (int32_t)command, 0, 0, 0, 0, false, NULL, NULL);
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
        0,
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
    zapp_push_event(ZAPP_ANDROID_FILE_SELECTED, 0, (uint64_t)request_id, 0, 0, 0, false, env, uri);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeFileSelectionCancelled(
    JNIEnv *env,
    jclass clazz,
    jlong request_id
) {
    (void)env;
    (void)clazz;
    zapp_push_event(ZAPP_ANDROID_FILE_SELECTION_CANCELLED, 0, (uint64_t)request_id, 0, 0, 0, false, NULL, NULL);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeCrashReportExportResult(
    JNIEnv *env,
    jclass clazz,
    jlong request_id,
    jboolean chooser_opened
) {
    (void)env;
    (void)clazz;
    zapp_push_event(
        ZAPP_ANDROID_CRASH_REPORT_EXPORT_RESULT,
        0,
        (uint64_t)request_id,
        0,
        0,
        0,
        chooser_opened == JNI_TRUE,
        NULL,
        NULL
    );
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeFileReadCompleted(
    JNIEnv *env,
    jclass clazz,
    jlong request_id,
    jbyteArray data,
    jboolean truncated,
    jstring display_name,
    jstring mime_type,
    jlong file_size,
    jboolean file_size_known
) {
    (void)clazz;
    zapp_android_event event;
    memset(&event, 0, sizeof(event));
    event.kind_value = ZAPP_ANDROID_FILE_READ_COMPLETED;
    event.request_id = (uint64_t)request_id;
    event.truncated = truncated == JNI_TRUE;
    event.file_size = file_size >= 0 ? (uint64_t)file_size : 0;
    event.file_size_known = file_size_known == JNI_TRUE && file_size >= 0;
    event.display_name_length = (uint16_t)zapp_string_to_utf8(
        env,
        display_name,
        event.display_name_buffer,
        sizeof(event.display_name_buffer)
    );
    event.mime_type_length = (uint16_t)zapp_string_to_utf8(
        env,
        mime_type,
        event.mime_type_buffer,
        sizeof(event.mime_type_buffer)
    );
    if (data != NULL) {
        const jsize length = (*env)->GetArrayLength(env, data);
        event.text_length = (size_t)(length < (jsize)sizeof(event.text_buffer) ? length : (jsize)sizeof(event.text_buffer));
        if (event.text_length > 0) {
            (*env)->GetByteArrayRegion(env, data, 0, (jsize)event.text_length, (jbyte *)event.text_buffer);
            if ((*env)->ExceptionCheck(env)) return;
        }
        if ((size_t)length > sizeof(event.text_buffer)) event.truncated = true;
    }
    zapp_enqueue_event(&event);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeFileReadFailed(
    JNIEnv *env,
    jclass clazz,
    jlong request_id,
    jint error_kind
) {
    (void)env;
    (void)clazz;
    zapp_push_event(
        ZAPP_ANDROID_FILE_READ_FAILED,
        (int32_t)error_kind,
        (uint64_t)request_id,
        0,
        0,
        0,
        false,
        NULL,
        NULL
    );
}

JNIEXPORT jboolean JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeFileStreamChunk(
    JNIEnv *env,
    jclass clazz,
    jlong request_id,
    jlong offset,
    jbyteArray data,
    jint length
) {
    (void)clazz;
    if (offset < 0 || data == NULL || length <= 0 ||
        length > ZAPP_ANDROID_PAYLOAD_CAPACITY ||
        length > (*env)->GetArrayLength(env, data)) return JNI_FALSE;

    zapp_android_event event;
    memset(&event, 0, sizeof(event));
    event.kind_value = ZAPP_ANDROID_FILE_STREAM_CHUNK;
    event.request_id = (uint64_t)request_id;
    event.file_size = (uint64_t)offset;
    event.text_length = (size_t)length;
    (*env)->GetByteArrayRegion(env, data, 0, length, (jbyte *)event.text_buffer);
    if ((*env)->ExceptionCheck(env)) return JNI_FALSE;
    return zapp_enqueue_stream_event(&event) ? JNI_TRUE : JNI_FALSE;
}

static void zapp_push_stream_terminal(
    int32_t kind,
    int32_t detail,
    uint64_t request_id,
    uint64_t total_bytes
) {
    zapp_android_event event;
    memset(&event, 0, sizeof(event));
    event.kind_value = kind;
    event.detail_value = detail;
    event.request_id = request_id;
    event.file_size = total_bytes;
    (void)zapp_enqueue_stream_event(&event);
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeFileStreamCompleted(
    JNIEnv *env,
    jclass clazz,
    jlong request_id,
    jlong total_bytes
) {
    (void)env;
    (void)clazz;
    if (total_bytes < 0) return;
    zapp_push_stream_terminal(
        ZAPP_ANDROID_FILE_STREAM_COMPLETED,
        0,
        (uint64_t)request_id,
        (uint64_t)total_bytes
    );
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeFileStreamFailed(
    JNIEnv *env,
    jclass clazz,
    jlong request_id,
    jint error_kind
) {
    (void)env;
    (void)clazz;
    zapp_push_stream_terminal(
        ZAPP_ANDROID_FILE_STREAM_FAILED,
        (int32_t)error_kind,
        (uint64_t)request_id,
        0
    );
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeFileStreamCancelled(
    JNIEnv *env,
    jclass clazz,
    jlong request_id,
    jlong total_bytes
) {
    (void)env;
    (void)clazz;
    if (total_bytes < 0) return;
    zapp_push_stream_terminal(
        ZAPP_ANDROID_FILE_STREAM_CANCELLED,
        0,
        (uint64_t)request_id,
        (uint64_t)total_bytes
    );
}

JNIEXPORT jint JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeAccessibilityNodeCount(JNIEnv *env, jclass clazz) {
    (void)env;
    (void)clazz;
    pthread_mutex_lock(&zapp_accessibility_mutex);
    const jint count = (jint)zapp_accessibility_count;
    pthread_mutex_unlock(&zapp_accessibility_mutex);
    return count;
}

JNIEXPORT jboolean JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeAccessibilityNodeAt(
    JNIEnv *env,
    jclass clazz,
    jint index,
    jintArray metadata,
    jfloatArray geometry,
    jobjectArray strings
) {
    (void)clazz;
    if (index < 0 || metadata == NULL || geometry == NULL || strings == NULL ||
        (*env)->GetArrayLength(env, metadata) < 4 ||
        (*env)->GetArrayLength(env, geometry) < 5 ||
        (*env)->GetArrayLength(env, strings) < 2) return JNI_FALSE;

    zapp_accessibility_node node;
    pthread_mutex_lock(&zapp_accessibility_mutex);
    if ((size_t)index >= zapp_accessibility_count) {
        pthread_mutex_unlock(&zapp_accessibility_mutex);
        return JNI_FALSE;
    }
    node = zapp_accessibility_nodes[index];
    pthread_mutex_unlock(&zapp_accessibility_mutex);

    const jint metadata_values[4] = {
        (jint)node.element_id,
        (jint)node.role_value,
        (jint)node.flags,
        (jint)node.level,
    };
    const jfloat geometry_values[5] = { node.x, node.y, node.width, node.height, node.value };
    (*env)->SetIntArrayRegion(env, metadata, 0, 4, metadata_values);
    (*env)->SetFloatArrayRegion(env, geometry, 0, 5, geometry_values);
    jstring label = zapp_utf8_to_string(env, node.label, node.label_length);
    jstring value_text = zapp_utf8_to_string(env, node.value_text, node.value_text_length);
    if (label != NULL) (*env)->SetObjectArrayElement(env, strings, 0, label);
    if (value_text != NULL) (*env)->SetObjectArrayElement(env, strings, 1, value_text);
    if (label != NULL) (*env)->DeleteLocalRef(env, label);
    if (value_text != NULL) (*env)->DeleteLocalRef(env, value_text);
    return (*env)->ExceptionCheck(env) ? JNI_FALSE : JNI_TRUE;
}

JNIEXPORT void JNICALL
Java_com_xiaolbj_zapp_ZappActivity_nativeAccessibilityAction(
    JNIEnv *env,
    jclass clazz,
    jint element_id,
    jint action,
    jstring text
) {
    (void)clazz;
    zapp_push_event(
        ZAPP_ANDROID_ACCESSIBILITY_ACTION,
        0,
        0,
        0,
        (uint32_t)element_id,
        (int32_t)action,
        false,
        env,
        text
    );
}

void zapp_android_bridge_attach(const void *activity) {
    pthread_mutex_lock(&zapp_event_mutex);
    zapp_bridge_active = true;
    pthread_mutex_unlock(&zapp_event_mutex);
    zapp_activity = (ANativeActivity *)activity;

    zapp_android_crash_record crash_record;
    if (zapp_android_crash_report_setup(zapp_activity, &crash_record)) {
        zapp_android_event event;
        memset(&event, 0, sizeof(event));
        event.kind_value = ZAPP_ANDROID_NATIVE_CRASH_RECOVERED;
        event.detail_value = crash_record.signal_number;
        event.action_value = crash_record.signal_code;
        event.request_id = crash_record.relative_pc;
        event.file_size = crash_record.fault_address;
        event.crash_absolute_pc = crash_record.absolute_pc;
        event.crash_timestamp_seconds = crash_record.timestamp_seconds;
        event.crash_process_id = crash_record.process_id;
        event.crash_thread_id = crash_record.thread_id;
        event.crash_architecture = crash_record.architecture;
        event.crash_flags = crash_record.flags;
        event.crash_build_id_length = crash_record.build_id_length;
        memcpy(event.crash_build_id, crash_record.build_id, crash_record.build_id_length);
        zapp_enqueue_event(&event);
        __android_log_print(
            ANDROID_LOG_WARN,
            ZAPP_LOG_TAG,
            "recovered native crash signal=%d relative_pc=0x%llx",
            crash_record.signal_number,
            (unsigned long long)crash_record.relative_pc
        );
    }
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

bool zapp_android_bridge_read_file(
    uint64_t request_id,
    const uint8_t *uri,
    size_t uri_length,
    uint32_t max_bytes
) {
    if (uri == NULL || uri_length == 0 || uri_length > ZAPP_ANDROID_PAYLOAD_CAPACITY || max_bytes == 0) return false;
    zapp_jni_scope scope;
    if (!zapp_begin_jni_scope(&scope)) return false;
    jobject activity = zapp_activity_object();
    jclass activity_class = (*scope.env)->GetObjectClass(scope.env, activity);
    jstring uri_string = zapp_utf8_to_string(scope.env, uri, uri_length);
    if (activity_class != NULL && uri_string != NULL) {
        jmethodID method = (*scope.env)->GetMethodID(
            scope.env,
            activity_class,
            "readFileFromNative",
            "(JLjava/lang/String;I)V"
        );
        if (method != NULL) {
            (*scope.env)->CallVoidMethod(
                scope.env,
                activity,
                method,
                (jlong)request_id,
                uri_string,
                (jint)max_bytes
            );
        }
    }
    if (uri_string != NULL) (*scope.env)->DeleteLocalRef(scope.env, uri_string);
    if (activity_class != NULL) (*scope.env)->DeleteLocalRef(scope.env, activity_class);
    return zapp_finish_jni_call(&scope) && activity_class != NULL && uri_string != NULL;
}

bool zapp_android_bridge_stream_file(
    uint64_t request_id,
    const uint8_t *uri,
    size_t uri_length,
    uint32_t chunk_bytes
) {
    if (uri == NULL || uri_length == 0 || uri_length > ZAPP_ANDROID_PAYLOAD_CAPACITY ||
        chunk_bytes == 0 || chunk_bytes > ZAPP_ANDROID_PAYLOAD_CAPACITY) return false;
    zapp_jni_scope scope;
    if (!zapp_begin_jni_scope(&scope)) return false;
    jobject activity = zapp_activity_object();
    jclass activity_class = (*scope.env)->GetObjectClass(scope.env, activity);
    jstring uri_string = zapp_utf8_to_string(scope.env, uri, uri_length);
    if (activity_class != NULL && uri_string != NULL) {
        jmethodID method = (*scope.env)->GetMethodID(
            scope.env,
            activity_class,
            "streamFileFromNative",
            "(JLjava/lang/String;I)V"
        );
        if (method != NULL) {
            (*scope.env)->CallVoidMethod(
                scope.env,
                activity,
                method,
                (jlong)request_id,
                uri_string,
                (jint)chunk_bytes
            );
        }
    }
    if (uri_string != NULL) (*scope.env)->DeleteLocalRef(scope.env, uri_string);
    if (activity_class != NULL) (*scope.env)->DeleteLocalRef(scope.env, activity_class);
    return zapp_finish_jni_call(&scope) && activity_class != NULL && uri_string != NULL;
}

bool zapp_android_bridge_cancel_file_stream(uint64_t request_id) {
    zapp_jni_scope scope;
    if (!zapp_begin_jni_scope(&scope)) return false;
    jobject activity = zapp_activity_object();
    jclass activity_class = (*scope.env)->GetObjectClass(scope.env, activity);
    if (activity_class != NULL) {
        jmethodID method = (*scope.env)->GetMethodID(
            scope.env,
            activity_class,
            "cancelFileStreamFromNative",
            "(J)V"
        );
        if (method != NULL) {
            (*scope.env)->CallVoidMethod(scope.env, activity, method, (jlong)request_id);
        }
        (*scope.env)->DeleteLocalRef(scope.env, activity_class);
    }
    return zapp_finish_jni_call(&scope) && activity_class != NULL;
}

bool zapp_android_bridge_share_crash_report(
    uint64_t request_id,
    const uint8_t *text,
    size_t text_length
) {
    if (text == NULL || text_length == 0 || text_length > ZAPP_ANDROID_PAYLOAD_CAPACITY) return false;
    zapp_jni_scope scope;
    if (!zapp_begin_jni_scope(&scope)) return false;
    jobject activity = zapp_activity_object();
    jclass activity_class = (*scope.env)->GetObjectClass(scope.env, activity);
    jstring report_string = zapp_utf8_to_string(scope.env, text, text_length);
    jmethodID method = NULL;
    if (activity_class != NULL && report_string != NULL) {
        method = (*scope.env)->GetMethodID(
            scope.env,
            activity_class,
            "shareCrashReportFromNative",
            "(JLjava/lang/String;)V"
        );
        if (method != NULL) {
            (*scope.env)->CallVoidMethod(
                scope.env,
                activity,
                method,
                (jlong)request_id,
                report_string
            );
        }
    }
    if (report_string != NULL) (*scope.env)->DeleteLocalRef(scope.env, report_string);
    if (activity_class != NULL) (*scope.env)->DeleteLocalRef(scope.env, activity_class);
    return zapp_finish_jni_call(&scope) && activity_class != NULL && report_string != NULL && method != NULL;
}

void zapp_android_bridge_update_accessibility(const zapp_accessibility_node *nodes, size_t count) {
    if (nodes == NULL && count != 0) return;
    if (count > ZAPP_ACCESSIBILITY_NODE_CAPACITY) count = ZAPP_ACCESSIBILITY_NODE_CAPACITY;

    pthread_mutex_lock(&zapp_accessibility_mutex);
    const bool changed = count != zapp_accessibility_count ||
        (count > 0 && memcmp(zapp_accessibility_nodes, nodes, count * sizeof(*nodes)) != 0);
    if (changed) {
        if (count > 0) memcpy(zapp_accessibility_nodes, nodes, count * sizeof(*nodes));
        zapp_accessibility_count = count;
    }
    pthread_mutex_unlock(&zapp_accessibility_mutex);
    if (!changed) return;

    zapp_jni_scope scope;
    if (!zapp_begin_jni_scope(&scope)) return;
    jobject activity = zapp_activity_object();
    jclass activity_class = (*scope.env)->GetObjectClass(scope.env, activity);
    if (activity_class != NULL) {
        jmethodID method = (*scope.env)->GetMethodID(
            scope.env,
            activity_class,
            "refreshAccessibilitySnapshotFromNative",
            "()V"
        );
        if (method != NULL) (*scope.env)->CallVoidMethod(scope.env, activity, method);
        (*scope.env)->DeleteLocalRef(scope.env, activity_class);
    }
    (void)zapp_finish_jni_call(&scope);
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
    pthread_cond_signal(&zapp_event_space_available);
    pthread_mutex_unlock(&zapp_event_mutex);
    return true;
}

void zapp_android_bridge_reset(void) {
    zapp_android_crash_report_shutdown();
    pthread_mutex_lock(&zapp_event_mutex);
    zapp_bridge_active = false;
    zapp_event_head = 0;
    zapp_event_count = 0;
    pthread_cond_broadcast(&zapp_event_space_available);
    pthread_mutex_unlock(&zapp_event_mutex);
    pthread_mutex_lock(&zapp_accessibility_mutex);
    zapp_accessibility_count = 0;
    pthread_mutex_unlock(&zapp_accessibility_mutex);
    zapp_activity = NULL;
}
