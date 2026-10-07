#include "scanner.h"
#include "plugin_common.h"

#include <orbis/libkernel.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define DIAG_DIR GOLDHEN_PATH "/career_diag"
#define DIAG_LOG DIAG_DIR "/diagnostic.log"
#define DIAG_RESULTS DIAG_DIR "/candidates.txt"

#define VQ_FIND_NEXT 1
#define CPU_READ  0x01
#define CPU_WRITE 0x02

#define CHUNK_SIZE (512u * 1024u)
#define MAX_CANDIDATES 2000000u
#define MAX_DUMP_CANDIDATES 5000u

typedef enum ScanMode {
    SCAN_MODE_INT32 = 0,
    SCAN_MODE_FLOAT = 1
} ScanMode;

/*
 * Fixed BSS storage is intentional. It avoids allocating a large candidate
 * vector from the game's heap while we are scanning that same heap.
 */
static uint64_t g_candidate_address[MAX_CANDIDATES];
static uint32_t g_candidate_previous[MAX_CANDIDATES];
static uint8_t g_chunk[CHUNK_SIZE];

static size_t g_candidate_count = 0;
static volatile int g_pending_action = DIAG_ACTION_NONE;
static volatile int g_worker_running = 0;
static volatile int g_busy = 0;
static ScanMode g_mode = SCAN_MODE_INT32;
static OrbisPthread g_worker_thread;

static void dump_candidates(void);

static void ensure_output_dir(void)
{
    mkdir(DIAG_DIR, 0777);
}

static void append_log(const char *fmt, ...)
{
    char line[768];
    va_list args;
    int fd;
    int len;

    ensure_output_dir();

    va_start(args, fmt);
    len = vsnprintf(line, sizeof(line), fmt, args);
    va_end(args);

    if (len < 0)
        return;

    if ((size_t)len >= sizeof(line))
        len = sizeof(line) - 1;

    fd = open(DIAG_LOG, O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (fd < 0)
        return;

    write(fd, line, (size_t)len);
    write(fd, "\n", 1);
    close(fd);
}

static void notify_status(const char *fmt, ...)
{
    char message[512];
    va_list args;

    va_start(args, fmt);
    vsnprintf(message, sizeof(message), fmt, args);
    va_end(args);

    NotifyStatic(TEX_ICON_SYSTEM, message);
    append_log("%s", message);
}

static int read_process(uint64_t address, void *data, size_t length)
{
    struct proc_rw rw;
    memset(&rw, 0, sizeof(rw));
    rw.address = address;
    rw.data = data;
    rw.length = length;
    rw.write_flags = 0;
    return sys_sdk_proc_rw(&rw);
}

static bool is_internal_region(uintptr_t start, uintptr_t end)
{
    uintptr_t a = (uintptr_t)&g_candidate_address[0];
    uintptr_t b = (uintptr_t)&g_candidate_previous[0];
    uintptr_t c = (uintptr_t)&g_chunk[0];

    return (a >= start && a < end) ||
           (b >= start && b < end) ||
           (c >= start && c < end);
}

static float raw_as_float(uint32_t raw)
{
    float out;
    memcpy(&out, &raw, sizeof(out));
    return out;
}

static bool plausible_value(uint32_t raw)
{
    if (g_mode == SCAN_MODE_INT32) {
        int32_t value;
        memcpy(&value, &raw, sizeof(value));
        return value >= 1 && value <= 100;
    }

    float value = raw_as_float(raw);
    return value >= 1.0f && value <= 100.0f;
}

static bool compare_value(uint32_t previous, uint32_t current, DiagAction action)
{
    if (!plausible_value(current))
        return false;

    if (g_mode == SCAN_MODE_INT32) {
        int32_t p;
        int32_t c;
        memcpy(&p, &previous, sizeof(p));
        memcpy(&c, &current, sizeof(c));

        switch (action) {
            case DIAG_ACTION_DECREASED: return c < p;
            case DIAG_ACTION_INCREASED: return c > p;
            case DIAG_ACTION_CHANGED:   return c != p;
            case DIAG_ACTION_UNCHANGED: return c == p;
            default:                    return false;
        }
    }

    {
        float p = raw_as_float(previous);
        float c = raw_as_float(current);
        const float epsilon = 0.0001f;

        switch (action) {
            case DIAG_ACTION_DECREASED: return c < (p - epsilon);
            case DIAG_ACTION_INCREASED: return c > (p + epsilon);
            case DIAG_ACTION_CHANGED: {
                float d = c - p;
                return d > epsilon || d < -epsilon;
            }
            case DIAG_ACTION_UNCHANGED: {
                float d = c - p;
                return d <= epsilon && d >= -epsilon;
            }
            default: return false;
        }
    }
}

static const char *mode_name(void)
{
    return g_mode == SCAN_MODE_INT32 ? "int32" : "float";
}

static void reset_candidates(void)
{
    g_candidate_count = 0;
}

static bool add_candidate(uint64_t address, uint32_t raw)
{
    if (g_candidate_count >= MAX_CANDIDATES)
        return false;

    g_candidate_address[g_candidate_count] = address;
    g_candidate_previous[g_candidate_count] = raw;
    g_candidate_count++;
    return true;
}

static void scan_region(uintptr_t start, uintptr_t end, uint64_t *bytes_scanned, bool *hit_cap)
{
    uintptr_t current = start;

    while (current + sizeof(uint32_t) <= end && !*hit_cap) {
        size_t remaining = (size_t)(end - current);
        size_t amount = remaining < CHUNK_SIZE ? remaining : CHUNK_SIZE;
        amount &= ~(sizeof(uint32_t) - 1u);

        if (amount < sizeof(uint32_t))
            break;

        if (read_process((uint64_t)current, g_chunk, amount) != 0) {
            append_log("read failed: 0x%lx + 0x%zx", (unsigned long)current, amount);
            current += amount;
            continue;
        }

        for (size_t off = 0; off + sizeof(uint32_t) <= amount; off += sizeof(uint32_t)) {
            uint32_t raw;
            memcpy(&raw, &g_chunk[off], sizeof(raw));

            if (!plausible_value(raw))
                continue;

            if (!add_candidate((uint64_t)(current + off), raw)) {
                *hit_cap = true;
                break;
            }
        }

        *bytes_scanned += amount;
        current += amount;

        /* Yield a little so the game remains responsive during large scans. */
        sceKernelUsleep(1000);
    }
}

static void initial_snapshot(void)
{
    OrbisKernelVirtualQueryInfo info;
    void *cursor = NULL;
    uintptr_t last_end = 0;
    uint64_t bytes_scanned = 0;
    uint32_t regions_scanned = 0;
    bool hit_cap = false;

    reset_candidates();
    ensure_output_dir();

    {
        int fd = open(DIAG_LOG, O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0)
            close(fd);
    }

    append_log("=== PS4 Career Diagnostic snapshot ===");
    append_log("mode=%s value_window=1..100", mode_name());

    while (!hit_cap && sceKernelVirtualQuery(cursor, VQ_FIND_NEXT, &info, sizeof(info)) >= 0) {
        uintptr_t start = (uintptr_t)info.start_addr;
        uintptr_t end = (uintptr_t)info.end_addr;

        if (end <= start || end <= last_end)
            break;

        last_end = end;
        cursor = (void *)end;

        if ((info.prot & (CPU_READ | CPU_WRITE)) != (CPU_READ | CPU_WRITE))
            continue;

        if (info.isStack)
            continue;

        if (is_internal_region(start, end))
            continue;

        append_log("region %u: %s 0x%lx-0x%lx prot=0x%x flex=%u direct=%u pooled=%u committed=%u",
                   regions_scanned,
                   info.name,
                   (unsigned long)start,
                   (unsigned long)end,
                   info.prot,
                   info.isFlexibleMemory,
                   info.isDirectMemory,
                   info.isPooledMemory,
                   info.isCommitted);

        regions_scanned++;
        scan_region(start, end, &bytes_scanned, &hit_cap);
    }

    if (hit_cap) {
        notify_status("[CareerDiag] Snapshot: limite de %u candidatos atingido (%s).",
                      MAX_CANDIDATES, mode_name());
    } else {
        notify_status("[CareerDiag] Snapshot pronto: %zu candidatos (%s).",
                      g_candidate_count, mode_name());
    }

    append_log("regions=%u bytes=%llu candidates=%zu cap=%d",
               regions_scanned,
               (unsigned long long)bytes_scanned,
               g_candidate_count,
               hit_cap ? 1 : 0);
}

static void filter_candidates(DiagAction action)
{
    size_t read_index = 0;
    size_t write_index = 0;
    size_t before = g_candidate_count;

    if (g_candidate_count == 0) {
        notify_status("[CareerDiag] Sem candidatos. Faca um snapshot primeiro.");
        return;
    }

    while (read_index < g_candidate_count) {
        uint64_t address = g_candidate_address[read_index];
        OrbisKernelVirtualQueryInfo info;

        if (sceKernelVirtualQuery((void *)(uintptr_t)address, 0, &info, sizeof(info)) < 0 ||
            (info.prot & CPU_READ) == 0) {
            read_index++;
            continue;
        }

        uintptr_t region_end = (uintptr_t)info.end_addr;
        uintptr_t chunk_start = (uintptr_t)address;
        size_t amount = (size_t)(region_end - chunk_start);
        if (amount > CHUNK_SIZE)
            amount = CHUNK_SIZE;

        if (amount < sizeof(uint32_t) ||
            read_process((uint64_t)chunk_start, g_chunk, amount) != 0) {
            read_index++;
            continue;
        }

        while (read_index < g_candidate_count) {
            uint64_t candidate = g_candidate_address[read_index];

            if (candidate < chunk_start ||
                candidate + sizeof(uint32_t) > chunk_start + amount)
                break;

            size_t off = (size_t)(candidate - chunk_start);
            uint32_t current;
            memcpy(&current, &g_chunk[off], sizeof(current));

            if (compare_value(g_candidate_previous[read_index], current, action)) {
                g_candidate_address[write_index] = candidate;
                g_candidate_previous[write_index] = current;
                write_index++;
            }

            read_index++;
        }

        sceKernelUsleep(500);
    }

    g_candidate_count = write_index;

    const char *label = "filtro";
    if (action == DIAG_ACTION_DECREASED) label = "diminuiu";
    else if (action == DIAG_ACTION_INCREASED) label = "aumentou";
    else if (action == DIAG_ACTION_CHANGED) label = "mudou";
    else if (action == DIAG_ACTION_UNCHANGED) label = "nao mudou";

    notify_status("[CareerDiag] %s: %zu -> %zu candidatos.",
                  label, before, g_candidate_count);

    if (g_candidate_count > 0 && g_candidate_count <= 20)
        dump_candidates();
}

static void dump_candidates(void)
{
    int fd;
    char line[256];
    size_t limit;

    ensure_output_dir();
    fd = open(DIAG_RESULTS, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd < 0) {
        notify_status("[CareerDiag] Falha ao gravar candidates.txt.");
        return;
    }

    {
        int n = snprintf(line, sizeof(line),
                         "PS4 Career Diagnostic\nmode=%s\ncandidates=%zu\n\n",
                         mode_name(), g_candidate_count);
        if (n > 0)
            write(fd, line, (size_t)n);
    }

    limit = g_candidate_count < MAX_DUMP_CANDIDATES ?
            g_candidate_count : MAX_DUMP_CANDIDATES;

    for (size_t i = 0; i < limit; i++) {
        int n;

        if (g_mode == SCAN_MODE_INT32) {
            int32_t value;
            memcpy(&value, &g_candidate_previous[i], sizeof(value));
            n = snprintf(line, sizeof(line), "%04zu  0x%016llX  int32=%d\n",
                         i,
                         (unsigned long long)g_candidate_address[i],
                         value);
        } else {
            float value = raw_as_float(g_candidate_previous[i]);
            n = snprintf(line, sizeof(line), "%04zu  0x%016llX  float=%.6f\n",
                         i,
                         (unsigned long long)g_candidate_address[i],
                         value);
        }

        if (n > 0)
            write(fd, line, (size_t)n);
    }

    if (limit < g_candidate_count) {
        int n = snprintf(line, sizeof(line),
                         "\n... truncado: mostrando %zu de %zu candidatos.\n",
                         limit, g_candidate_count);
        if (n > 0)
            write(fd, line, (size_t)n);
    }

    close(fd);

    notify_status("[CareerDiag] %zu candidatos salvos em candidates.txt.",
                  g_candidate_count);
}

static void execute_action(DiagAction action)
{
    g_busy = 1;

    switch (action) {
        case DIAG_ACTION_SNAPSHOT:
            notify_status("[CareerDiag] Iniciando snapshot %s...", mode_name());
            initial_snapshot();
            break;

        case DIAG_ACTION_DECREASED:
        case DIAG_ACTION_INCREASED:
        case DIAG_ACTION_CHANGED:
        case DIAG_ACTION_UNCHANGED:
            filter_candidates(action);
            break;

        case DIAG_ACTION_DUMP:
            dump_candidates();
            break;

        case DIAG_ACTION_RESET:
            reset_candidates();
            notify_status("[CareerDiag] Busca zerada. Modo: %s.", mode_name());
            break;

        case DIAG_ACTION_MODE_INT32:
            reset_candidates();
            g_mode = SCAN_MODE_INT32;
            notify_status("[CareerDiag] Modo INT32 selecionado.");
            break;

        case DIAG_ACTION_MODE_FLOAT:
            reset_candidates();
            g_mode = SCAN_MODE_FLOAT;
            notify_status("[CareerDiag] Modo FLOAT selecionado.");
            break;

        default:
            break;
    }

    g_busy = 0;
}

static void *worker_main(void *arg)
{
    (void)arg;

    while (g_worker_running) {
        DiagAction action = (DiagAction)g_pending_action;

        if (action != DIAG_ACTION_NONE && !g_busy) {
            g_pending_action = DIAG_ACTION_NONE;
            execute_action(action);
        }

        sceKernelUsleep(50000);
    }

    scePthreadExit(NULL);
    return NULL;
}

int diag_start_worker(void)
{
    g_worker_running = 1;
    g_pending_action = DIAG_ACTION_NONE;
    g_busy = 0;
    g_candidate_count = 0;
    g_mode = SCAN_MODE_INT32;

    ensure_output_dir();

    return scePthreadCreate(&g_worker_thread, NULL, worker_main, NULL,
                            "career_diag_worker");
}

void diag_stop_worker(void)
{
    if (!g_worker_running)
        return;

    g_worker_running = 0;
    scePthreadJoin(g_worker_thread, NULL);
}

void diag_request(DiagAction action)
{
    if (!g_worker_running)
        return;

    if (g_busy) {
        return;
    }

    if (g_pending_action == DIAG_ACTION_NONE)
        g_pending_action = (int)action;
}
