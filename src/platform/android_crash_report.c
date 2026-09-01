#define _GNU_SOURCE 1

#include "android_crash_report.h"

#include <android/log.h>
#include <elf.h>
#include <fcntl.h>
#include <limits.h>
#include <link.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <time.h>
#include <ucontext.h>
#include <unistd.h>

#define ZAPP_CRASH_LOG_TAG "zapp-crash"
#define ZAPP_CRASH_FILE_NAME "/native-crash-v1.bin"
#define ZAPP_CRASH_SIGNAL_COUNT 7

static const int zapp_crash_signals[ZAPP_CRASH_SIGNAL_COUNT] = {
    SIGABRT,
    SIGBUS,
    SIGFPE,
    SIGILL,
    SIGSEGV,
    SIGTRAP,
    SIGSYS,
};

static struct sigaction zapp_previous_actions[ZAPP_CRASH_SIGNAL_COUNT];
static bool zapp_action_saved[ZAPP_CRASH_SIGNAL_COUNT];
static bool zapp_handlers_installed;
static int zapp_crash_fd = -1;
static char zapp_crash_path[PATH_MAX];
static uintptr_t zapp_module_load_bias;
static uintptr_t zapp_module_start;
static uintptr_t zapp_module_end;
static uint8_t zapp_build_id[ZAPP_ANDROID_BUILD_ID_CAPACITY];
static uint8_t zapp_build_id_length;
static volatile sig_atomic_t zapp_handling_crash;

static uint32_t zapp_crash_architecture(void) {
#if defined(__aarch64__)
    return ZAPP_ANDROID_CRASH_ARCH_ARM64;
#elif defined(__x86_64__)
    return ZAPP_ANDROID_CRASH_ARCH_X86_64;
#else
    return ZAPP_ANDROID_CRASH_ARCH_UNKNOWN;
#endif
}

static uintptr_t zapp_instruction_pointer(void *context) {
    if (context == NULL) return 0;
    const ucontext_t *ucontext = (const ucontext_t *)context;
#if defined(__aarch64__)
    return (uintptr_t)ucontext->uc_mcontext.pc;
#elif defined(__x86_64__)
    return (uintptr_t)ucontext->uc_mcontext.gregs[REG_RIP];
#else
    (void)ucontext;
    return 0;
#endif
}

static size_t zapp_align_note(size_t value) {
    return (value + 3u) & ~(size_t)3u;
}

static void zapp_read_build_id(const struct dl_phdr_info *info, const ElfW(Phdr) *header) {
    const uint8_t *cursor = (const uint8_t *)((uintptr_t)info->dlpi_addr + (uintptr_t)header->p_vaddr);
    size_t remaining = (size_t)header->p_memsz;
    while (remaining >= sizeof(ElfW(Nhdr))) {
        const ElfW(Nhdr) *note = (const ElfW(Nhdr) *)cursor;
        const size_t name_bytes = zapp_align_note(note->n_namesz);
        const size_t description_bytes = zapp_align_note(note->n_descsz);
        const size_t total = sizeof(*note) + name_bytes + description_bytes;
        if (total > remaining || total < sizeof(*note)) return;
        const uint8_t *name = cursor + sizeof(*note);
        const uint8_t *description = name + name_bytes;
        if (note->n_type == NT_GNU_BUILD_ID && note->n_namesz == 4 &&
            memcmp(name, "GNU", 4) == 0)
        {
            const size_t length = note->n_descsz < ZAPP_ANDROID_BUILD_ID_CAPACITY
                ? note->n_descsz
                : ZAPP_ANDROID_BUILD_ID_CAPACITY;
            memcpy(zapp_build_id, description, length);
            zapp_build_id_length = (uint8_t)length;
            return;
        }
        cursor += total;
        remaining -= total;
    }
}

static int zapp_find_module(struct dl_phdr_info *info, size_t size, void *data) {
    (void)size;
    const uintptr_t probe = *(const uintptr_t *)data;
    bool contains_probe = false;
    uintptr_t start = UINTPTR_MAX;
    uintptr_t end = 0;

    for (ElfW(Half) index = 0; index < info->dlpi_phnum; ++index) {
        const ElfW(Phdr) *header = &info->dlpi_phdr[index];
        if (header->p_type != PT_LOAD) continue;
        const uintptr_t segment_start = (uintptr_t)info->dlpi_addr + (uintptr_t)header->p_vaddr;
        const uintptr_t segment_end = segment_start + (uintptr_t)header->p_memsz;
        if (probe >= segment_start && probe < segment_end) contains_probe = true;
        if (segment_start < start) start = segment_start;
        if (segment_end > end) end = segment_end;
    }
    if (!contains_probe) return 0;

    zapp_module_load_bias = (uintptr_t)info->dlpi_addr;
    zapp_module_start = start;
    zapp_module_end = end;
    for (ElfW(Half) index = 0; index < info->dlpi_phnum; ++index) {
        const ElfW(Phdr) *header = &info->dlpi_phdr[index];
        if (header->p_type == PT_NOTE) zapp_read_build_id(info, header);
    }
    return 1;
}

static int zapp_signal_index(int signal_number) {
    for (int index = 0; index < ZAPP_CRASH_SIGNAL_COUNT; ++index) {
        if (zapp_crash_signals[index] == signal_number) return index;
    }
    return -1;
}

static void zapp_forward_signal(int signal_number) {
    const int index = zapp_signal_index(signal_number);
    if (index >= 0 && zapp_action_saved[index]) {
        (void)sigaction(signal_number, &zapp_previous_actions[index], NULL);
    } else {
        struct sigaction action;
        memset(&action, 0, sizeof(action));
        action.sa_handler = SIG_DFL;
        sigemptyset(&action.sa_mask);
        (void)sigaction(signal_number, &action, NULL);
    }

    const pid_t process_id = getpid();
    const pid_t thread_id = (pid_t)syscall(SYS_gettid);
    sigset_t unblock_set;
    sigemptyset(&unblock_set);
    sigaddset(&unblock_set, signal_number);
    (void)sigprocmask(SIG_UNBLOCK, &unblock_set, NULL);
    (void)syscall(SYS_tgkill, process_id, thread_id, signal_number);
    _exit(128 + signal_number);
}

static void zapp_crash_handler(int signal_number, siginfo_t *info, void *context) {
    if (zapp_handling_crash != 0) zapp_forward_signal(signal_number);
    zapp_handling_crash = 1;

    zapp_android_crash_record record;
    memset(&record, 0, sizeof(record));
    record.magic = ZAPP_ANDROID_CRASH_MAGIC;
    record.version = ZAPP_ANDROID_CRASH_VERSION;
    record.record_size = (uint16_t)sizeof(record);
    record.signal_number = signal_number;
    record.signal_code = info == NULL ? 0 : info->si_code;
    record.architecture = zapp_crash_architecture();
    record.absolute_pc = (uint64_t)zapp_instruction_pointer(context);
    record.fault_address = info == NULL || info->si_code <= 0 ? 0 : (uint64_t)(uintptr_t)info->si_addr;
    record.process_id = (int32_t)getpid();
    record.thread_id = (int32_t)syscall(SYS_gettid);
    struct timespec timestamp;
    if (clock_gettime(CLOCK_REALTIME, &timestamp) == 0) record.timestamp_seconds = timestamp.tv_sec;
    if ((uintptr_t)record.absolute_pc >= zapp_module_start &&
        (uintptr_t)record.absolute_pc < zapp_module_end)
    {
        record.flags |= ZAPP_ANDROID_CRASH_FLAG_PC_IN_APP;
        record.relative_pc = record.absolute_pc - zapp_module_load_bias;
    }
    record.build_id_length = zapp_build_id_length;
    memcpy(record.build_id, zapp_build_id, zapp_build_id_length);

    if (zapp_crash_fd >= 0) {
        const uint8_t *bytes = (const uint8_t *)&record;
        size_t written = 0;
        while (written < sizeof(record)) {
            const ssize_t count = write(zapp_crash_fd, bytes + written, sizeof(record) - written);
            if (count <= 0) break;
            written += (size_t)count;
        }
        (void)fsync(zapp_crash_fd);
    }
    zapp_forward_signal(signal_number);
}

static bool zapp_valid_record(const zapp_android_crash_record *record) {
    return record->magic == ZAPP_ANDROID_CRASH_MAGIC &&
        record->version == ZAPP_ANDROID_CRASH_VERSION &&
        record->record_size == sizeof(*record) &&
        record->signal_number > 0 &&
        record->build_id_length <= ZAPP_ANDROID_BUILD_ID_CAPACITY;
}

static bool zapp_build_crash_path(const ANativeActivity *activity) {
    if (activity == NULL || activity->internalDataPath == NULL) return false;
    const size_t directory_length = strlen(activity->internalDataPath);
    const size_t name_length = sizeof(ZAPP_CRASH_FILE_NAME) - 1;
    if (directory_length == 0 || directory_length + name_length >= sizeof(zapp_crash_path)) return false;
    memcpy(zapp_crash_path, activity->internalDataPath, directory_length);
    memcpy(zapp_crash_path + directory_length, ZAPP_CRASH_FILE_NAME, name_length + 1);
    return true;
}

static bool zapp_read_previous(zapp_android_crash_record *record) {
    memset(record, 0, sizeof(*record));
    const int file = open(zapp_crash_path, O_RDONLY | O_CLOEXEC);
    if (file < 0) return false;
    uint8_t *bytes = (uint8_t *)record;
    size_t received = 0;
    while (received < sizeof(*record)) {
        const ssize_t count = read(file, bytes + received, sizeof(*record) - received);
        if (count <= 0) break;
        received += (size_t)count;
    }
    close(file);
    (void)unlink(zapp_crash_path);
    return received == sizeof(*record) && zapp_valid_record(record);
}

static void zapp_install_handlers(void) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_sigaction = zapp_crash_handler;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_SIGINFO | SA_ONSTACK | SA_RESTART;

    for (int index = 0; index < ZAPP_CRASH_SIGNAL_COUNT; ++index) {
        zapp_action_saved[index] = sigaction(
            zapp_crash_signals[index],
            &action,
            &zapp_previous_actions[index]
        ) == 0;
    }
    zapp_handlers_installed = true;
}

bool zapp_android_crash_report_setup(
    const ANativeActivity *activity,
    zapp_android_crash_record *previous_record
) {
    zapp_android_crash_report_shutdown();
    if (previous_record == NULL || !zapp_build_crash_path(activity)) return false;

    const bool recovered = zapp_read_previous(previous_record);
    const uintptr_t probe = (uintptr_t)&zapp_android_crash_report_setup;
    (void)dl_iterate_phdr(zapp_find_module, (void *)&probe);
    zapp_crash_fd = open(zapp_crash_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
    if (zapp_crash_fd < 0) {
        __android_log_print(ANDROID_LOG_WARN, ZAPP_CRASH_LOG_TAG, "cannot open private crash record");
        return recovered;
    }
    zapp_handling_crash = 0;
    zapp_install_handlers();
    return recovered;
}

void zapp_android_crash_report_shutdown(void) {
    if (zapp_handlers_installed) {
        for (int index = 0; index < ZAPP_CRASH_SIGNAL_COUNT; ++index) {
            if (!zapp_action_saved[index]) continue;
            struct sigaction current;
            if (sigaction(zapp_crash_signals[index], NULL, &current) == 0 &&
                current.sa_sigaction == zapp_crash_handler)
            {
                (void)sigaction(zapp_crash_signals[index], &zapp_previous_actions[index], NULL);
            }
            zapp_action_saved[index] = false;
        }
    }
    zapp_handlers_installed = false;
    if (zapp_crash_fd >= 0) {
        close(zapp_crash_fd);
        zapp_crash_fd = -1;
    }
    if (zapp_crash_path[0] != '\0') (void)unlink(zapp_crash_path);
    zapp_crash_path[0] = '\0';
    zapp_module_load_bias = 0;
    zapp_module_start = 0;
    zapp_module_end = 0;
    memset(zapp_build_id, 0, sizeof(zapp_build_id));
    zapp_build_id_length = 0;
    zapp_handling_crash = 0;
}
