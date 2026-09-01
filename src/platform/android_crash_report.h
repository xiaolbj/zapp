#ifndef ZAPP_ANDROID_CRASH_REPORT_H
#define ZAPP_ANDROID_CRASH_REPORT_H

#include <android/native_activity.h>
#include <stdbool.h>
#include <stdint.h>

#define ZAPP_ANDROID_CRASH_MAGIC UINT32_C(0x5a435231)
#define ZAPP_ANDROID_CRASH_VERSION UINT16_C(1)
#define ZAPP_ANDROID_CRASH_FLAG_PC_IN_APP UINT32_C(1)
#define ZAPP_ANDROID_BUILD_ID_CAPACITY 20

enum zapp_android_crash_architecture {
    ZAPP_ANDROID_CRASH_ARCH_UNKNOWN = 0,
    ZAPP_ANDROID_CRASH_ARCH_ARM64 = 1,
    ZAPP_ANDROID_CRASH_ARCH_X86_64 = 2,
};

typedef struct zapp_android_crash_record {
    uint32_t magic;
    uint16_t version;
    uint16_t record_size;
    int32_t signal_number;
    int32_t signal_code;
    uint32_t architecture;
    uint32_t flags;
    uint64_t relative_pc;
    uint64_t absolute_pc;
    uint64_t fault_address;
    int32_t process_id;
    int32_t thread_id;
    int64_t timestamp_seconds;
    uint8_t build_id_length;
    uint8_t build_id[ZAPP_ANDROID_BUILD_ID_CAPACITY];
    uint8_t reserved[3];
} zapp_android_crash_record;

_Static_assert(sizeof(zapp_android_crash_record) == 88, "Android crash record ABI mismatch");

bool zapp_android_crash_report_setup(
    const ANativeActivity *activity,
    zapp_android_crash_record *previous_record
);
void zapp_android_crash_report_shutdown(void);

#endif
