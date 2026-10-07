#include "scanner.h"
#include "plugin_common.h"
#include "structure_hunter.h"

#include <orbis/libkernel.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <sys/stat.h>

#ifndef DIAG_DIR
#define DIAG_DIR GOLDHEN_PATH "/career_diag"
#endif
#define DIAG_LOG DIAG_DIR "/diagnostic.log"
#define TRACE_EVENTS DIAG_DIR "/trace_events.txt"
#define TRACE_PAGES DIAG_DIR "/trace_pages.txt"
#define TRACE_RANK DIAG_DIR "/trace_rank.txt"
#define TRACE_TEST DIAG_DIR "/trace_test.txt"
#define TRACE_STATUS DIAG_DIR "/trace_status.txt"

#define VQ_FIND_NEXT 1
#define CPU_READ  0x01
#define CPU_WRITE 0x02
#define CPU_EXEC  0x04

#define TRACE_PAGE_SIZE 4096u
#define TRACE_CHUNK_SIZE (512u * 1024u)
#define TRACE_MAX_PAGES 720000u
#define TRACE_MAX_FOCUS_PAGES 384u
#define TRACE_MAX_FOCUS_BYTES (TRACE_MAX_FOCUS_PAGES * TRACE_PAGE_SIZE)
#define TRACE_TOP_RESULTS 300u
#define TRACE_TEST_QUEUE 64u
/* Every event contributes at most 8: scores stay exact in int16_t. */
#define TRACE_MAX_DETAIL_EVENTS 3000u
#define TRACE_TEST_DURATION_US 10000000ULL

typedef enum TracePhase {
    TRACE_PHASE_IDLE = 0,
    TRACE_PHASE_PAGES = 1,
    TRACE_PHASE_DETAIL = 2
} TracePhase;

typedef enum TraceLabel {
    TRACE_LABEL_UP = 1,
    TRACE_LABEL_DOWN = 2,
    TRACE_LABEL_SAME = 3
} TraceLabel;

typedef enum TraceType {
    TRACE_U8 = 0,
    TRACE_U16,
    TRACE_I16,
    TRACE_U32,
    TRACE_I32,
    TRACE_I64,
    TRACE_F32,
    TRACE_F64,
    TRACE_TYPE_COUNT
} TraceType;

typedef struct TracePage {
    uint64_t address;
    uint64_t hash;
    int16_t score;
    uint8_t changes;
    uint8_t noise;
    uint8_t valid;
} TracePage;

typedef struct RankItem {
    int16_t score;
    uint8_t type;
    uint16_t page_index;
    uint16_t offset;
    uint16_t reserved;
} RankItem;

typedef struct TraceEvidence {
    uint16_t up;
    uint16_t down;
    uint16_t same;
} TraceEvidence;

static TracePage g_pages[TRACE_MAX_PAGES];
static uint8_t g_chunk[TRACE_CHUNK_SIZE];

static uint64_t g_focus_address[TRACE_MAX_FOCUS_PAGES];
static uint8_t g_focus_prev[TRACE_MAX_FOCUS_BYTES];
static int16_t g_detail_score[TRACE_TYPE_COUNT][TRACE_MAX_FOCUS_BYTES];
static TraceEvidence g_focus_evidence[TRACE_MAX_FOCUS_PAGES];
static bool g_focus_valid[TRACE_MAX_FOCUS_PAGES];

static RankItem g_top_results[TRACE_TOP_RESULTS];
static size_t g_top_count = 0;

static uint16_t g_test_queue[TRACE_TEST_QUEUE];
static size_t g_test_queue_count = 0;
static size_t g_test_queue_cursor = 0;
static bool g_test_armed = false;
static bool g_test_active = false;
static uint64_t g_test_active_address = 0;
static uint64_t g_test_original_raw = 0;
static uint64_t g_test_applied_raw = 0;
static uint64_t g_test_deadline = 0;
static uintptr_t g_test_region_start = 0;
static uintptr_t g_test_region_end = 0;
static bool g_detail_needs_refresh = false;
static size_t g_test_active_size = 0;
static TraceType g_test_active_type = TRACE_U8;

static size_t g_page_count = 0;
static size_t g_focus_count = 0;
static TracePhase g_phase = TRACE_PHASE_IDLE;

static uint32_t g_page_events = 0;
static uint32_t g_page_up = 0;
static uint32_t g_page_down = 0;
static uint32_t g_page_same = 0;

static uint32_t g_detail_events = 0;
static uint32_t g_detail_up = 0;
static uint32_t g_detail_down = 0;
static uint32_t g_detail_same = 0;

static int g_pending_action = DIAG_ACTION_NONE;
static int g_worker_running = 0;
static int g_busy = 0;
static int g_rejected_action = DIAG_ACTION_NONE;
static OrbisPthread g_worker_thread;

typedef enum RestoreResult {
    RESTORE_NONE, RESTORE_OK, RESTORE_GAME_CHANGED, RESTORE_RETRY
} RestoreResult;

static RestoreResult restore_active_test(void);
static void dump_detail_ranking(void);
static void show_status(void);

static bool worker_running(void)
{
    return __atomic_load_n(&g_worker_running, __ATOMIC_ACQUIRE) != 0;
}

static bool write_all(int fd, const char *data, size_t length)
{
    while (length > 0) {
        ssize_t n = write(fd, data, length);
        /* Fail closed on any error: the PS4 libc stub does not export
         * __errno_location, and an incomplete journal must block a test. */
        if (n <= 0) return false;
        data += n;
        length -= (size_t)n;
    }
    return true;
}

static bool write_format(int fd, const char *fmt, ...)
{
    char line[1024];
    va_list args;
    va_start(args, fmt);
    int n = vsnprintf(line, sizeof(line), fmt, args);
    va_end(args);
    /* snprintf returns the required length, not the available bytes. */
    return n >= 0 && (size_t)n < sizeof(line) && write_all(fd, line, (size_t)n);
}

static void ensure_output_dir(void)
{
    mkdir(DIAG_DIR, 0777);
}

static bool append_file_line(const char *path, const char *fmt, va_list args)
{
    char line[768];
    int fd;
    int len;

    ensure_output_dir();

    len = vsnprintf(line, sizeof(line), fmt, args);
    if (len <= 0)
        return false;
    if ((size_t)len >= sizeof(line))
        return false;

    fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (fd < 0)
        return false;

    bool ok = write_all(fd, line, (size_t)len) && write_all(fd, "\n", 1);
    if (close(fd) != 0) ok = false;
    return ok;
}

static void append_log(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    append_file_line(DIAG_LOG, fmt, args);
    va_end(args);
}

static void append_event_line(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    append_file_line(TRACE_EVENTS, fmt, args);
    va_end(args);
}

static bool append_test_line(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    bool ok = append_file_line(TRACE_TEST, fmt, args);
    va_end(args);
    return ok;
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

static int write_process(uint64_t address, const void *data, size_t length)
{
    struct proc_rw rw;
    memset(&rw, 0, sizeof(rw));
    rw.address = address;
    rw.data = (void *)data;
    rw.length = length;
    rw.write_flags = 1;
    return sys_sdk_proc_rw(&rw);
}

static bool ranges_overlap(uintptr_t a0, uintptr_t a1,
                           uintptr_t b0, uintptr_t b1)
{
    return a0 < b1 && b0 < a1;
}

static bool overlaps_internal_region(uintptr_t start, uintptr_t end)
{
    if (ranges_overlap(start, end,
                       (uintptr_t)&g_pages[0],
                       (uintptr_t)&g_pages[TRACE_MAX_PAGES]))
        return true;
    if (ranges_overlap(start, end,
                       (uintptr_t)&g_chunk[0],
                       (uintptr_t)&g_chunk[TRACE_CHUNK_SIZE]))
        return true;
    if (ranges_overlap(start, end,
                       (uintptr_t)&g_focus_address[0],
                       (uintptr_t)&g_focus_address[TRACE_MAX_FOCUS_PAGES]))
        return true;
    if (ranges_overlap(start, end,
                       (uintptr_t)&g_focus_prev[0],
                       (uintptr_t)&g_focus_prev[TRACE_MAX_FOCUS_BYTES]))
        return true;
    if (ranges_overlap(start, end,
                       (uintptr_t)&g_detail_score[0][0],
                       (uintptr_t)(&g_detail_score[TRACE_TYPE_COUNT - 1][TRACE_MAX_FOCUS_BYTES - 1] + 1)))
        return true;
    return false;
}

static uint64_t hash_page(const uint8_t *data)
{
    uint64_t h = 0x9E3779B97F4A7C15ULL;

    for (size_t off = 0; off < TRACE_PAGE_SIZE; off += sizeof(uint64_t)) {
        uint64_t x;
        memcpy(&x, data + off, sizeof(x));
        h ^= x + 0x9E3779B97F4A7C15ULL + (h << 6) + (h >> 2);
        h ^= h >> 29;
        h *= 0xBF58476D1CE4E5B9ULL;
    }

    h ^= h >> 31;
    return h;
}

static int16_t sat_page_score(int value)
{
    if (value > 30000) return 30000;
    if (value < -30000) return -30000;
    return (int16_t)value;
}

static int16_t sat_detail_score(int value)
{
    if (value > 30000) return 30000;
    if (value < -30000) return -30000;
    return (int16_t)value;
}

static const char *label_name(TraceLabel label)
{
    switch (label) {
        case TRACE_LABEL_UP: return "UP";
        case TRACE_LABEL_DOWN: return "DOWN";
        case TRACE_LABEL_SAME: return "SAME";
        default: return "?";
    }
}

static const char *type_name(TraceType type)
{
    switch (type) {
        case TRACE_U8: return "u8";
        case TRACE_U16: return "u16";
        case TRACE_I16: return "i16";
        case TRACE_U32: return "u32";
        case TRACE_I32: return "i32";
        case TRACE_I64: return "i64";
        case TRACE_F32: return "f32";
        case TRACE_F64: return "f64";
        default: return "?";
    }
}

static size_t type_size(TraceType type)
{
    switch (type) {
        case TRACE_U8: return 1;
        case TRACE_U16:
        case TRACE_I16: return 2;
        case TRACE_U32:
        case TRACE_I32:
        case TRACE_F32: return 4;
        case TRACE_I64:
        case TRACE_F64: return 8;
        default: return 1;
    }
}

static void truncate_file(const char *path)
{
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0)
        close(fd);
}

static void clear_trace_files(void)
{
    ensure_output_dir();
    truncate_file(DIAG_LOG);
    truncate_file(TRACE_EVENTS);
    truncate_file(TRACE_PAGES);
    truncate_file(TRACE_RANK);
    truncate_file(TRACE_TEST);
    truncate_file(TRACE_STATUS);
}

static void reset_trace_state(void)
{
    restore_active_test();

    g_page_count = 0;
    g_focus_count = 0;
    g_phase = TRACE_PHASE_IDLE;

    g_page_events = 0;
    g_page_up = 0;
    g_page_down = 0;
    g_page_same = 0;

    g_detail_events = 0;
    g_detail_up = 0;
    g_detail_down = 0;
    g_detail_same = 0;

    g_top_count = 0;
    g_test_queue_count = 0;
    g_test_queue_cursor = 0;
    g_test_armed = false;
    g_detail_needs_refresh = false;

    memset(g_detail_score, 0, sizeof(g_detail_score));
    memset(g_focus_evidence, 0, sizeof(g_focus_evidence));
    memset(g_focus_valid, 0, sizeof(g_focus_valid));
}

static void initial_page_snapshot(void)
{
    OrbisKernelVirtualQueryInfo info;
    void *cursor = NULL;
    uintptr_t last_end = 0;
    uint64_t bytes_scanned = 0;
    uint32_t regions_scanned = 0;
    bool hit_cap = false;

    if (restore_active_test() == RESTORE_RETRY) {
        notify_status("[CareerTrace] Restauracao pendente. R1+DIR tenta novamente antes de reiniciar.");
        return;
    }
    reset_trace_state();
    clear_trace_files();

    notify_status("[CareerTrace v2110] Baseline completo iniciado. Aguarde.");
    append_log("=== CareerTrace v2110 page baseline ===");

    while (worker_running() && !hit_cap &&
           sceKernelVirtualQuery(cursor, VQ_FIND_NEXT, &info, sizeof(info)) >= 0) {
        uintptr_t start = (uintptr_t)info.start_addr;
        uintptr_t end = (uintptr_t)info.end_addr;

        if (end <= start || end <= last_end)
            break;

        last_end = end;
        cursor = (void *)end;

        if ((info.prot & (CPU_READ | CPU_WRITE)) != (CPU_READ | CPU_WRITE))
            continue;
        if (info.isStack || (info.prot & CPU_EXEC))
            continue;
        if (overlaps_internal_region(start, end))
            continue;

        regions_scanned++;

        uintptr_t current = start;
        while (worker_running() && current + TRACE_PAGE_SIZE <= end && !hit_cap) {
            size_t remaining = (size_t)(end - current);
            size_t amount = remaining < TRACE_CHUNK_SIZE ?
                            remaining : TRACE_CHUNK_SIZE;
            amount -= amount % TRACE_PAGE_SIZE;

            if (amount < TRACE_PAGE_SIZE)
                break;

            if (read_process((uint64_t)current, g_chunk, amount) != 0) {
                append_log("baseline read fail 0x%llX size=0x%zx",
                           (unsigned long long)current, amount);
                current += amount;
                continue;
            }

            for (size_t off = 0; off < amount; off += TRACE_PAGE_SIZE) {
                if (g_page_count >= TRACE_MAX_PAGES) {
                    hit_cap = true;
                    break;
                }

                TracePage *p = &g_pages[g_page_count++];
                p->address = (uint64_t)(current + off);
                p->hash = hash_page(g_chunk + off);
                p->score = 0;
                p->changes = 0;
                p->noise = 0;
                p->valid = 1;
            }

            bytes_scanned += amount;
            current += amount;
            sceKernelUsleep(1000);
        }
    }

    if (!worker_running()) return;
    g_phase = g_page_count ? TRACE_PHASE_PAGES : TRACE_PHASE_IDLE;

    append_log("baseline regions=%u bytes=%llu pages=%zu cap=%d",
               regions_scanned,
               (unsigned long long)bytes_scanned,
               g_page_count,
               hit_cap ? 1 : 0);

    append_event_line("CareerTrace v2110");
    append_event_line("BASELINE pages=%zu bytes=%llu regions=%u cap=%d",
                      g_page_count,
                      (unsigned long long)bytes_scanned,
                      regions_scanned,
                      hit_cap ? 1 : 0);

    if (g_page_count == 0)
        notify_status("[CareerTrace] Nenhuma pagina lida. Baseline nao criado; veja diagnostic.log.");
    else
        notify_status("[CareerTrace] FASE 1: %zu paginas. Registre 2 subidas, 2 quedas e 1 igual. R1+BAIXO: ajuda.", g_page_count);
}

static void page_apply_event(TracePage *p, bool changed, TraceLabel label)
{
    int delta;

    if (label == TRACE_LABEL_SAME) {
        if (changed) {
            delta = -6;
            if (p->noise < 255) p->noise++;
        } else {
            delta = 2;
        }
    } else {
        if (changed) {
            delta = 4;
            if (p->changes < 255) p->changes++;
        } else {
            delta = -2;
        }
    }

    p->score = sat_page_score((int)p->score + delta);
}

static size_t rescan_pages(TraceLabel label, size_t *read_fail_out)
{
    size_t changed_pages = 0;
    size_t read_fail = 0;
    size_t i = 0;

    while (worker_running() && i < g_page_count) {
        uint64_t start = g_pages[i].address;
        size_t pages_in_chunk = 1;

        while (i + pages_in_chunk < g_page_count &&
               pages_in_chunk < TRACE_CHUNK_SIZE / TRACE_PAGE_SIZE &&
               g_pages[i + pages_in_chunk].address ==
                   start + pages_in_chunk * TRACE_PAGE_SIZE) {
            pages_in_chunk++;
        }

        size_t amount = pages_in_chunk * TRACE_PAGE_SIZE;

        if (read_process(start, g_chunk, amount) == 0) {
            for (size_t j = 0; j < pages_in_chunk; j++) {
                TracePage *p = &g_pages[i + j];
                uint64_t now_hash = hash_page(g_chunk + j * TRACE_PAGE_SIZE);
                if (!p->valid) {
                    p->hash = now_hash;
                    p->valid = 1;
                    continue;
                }
                bool changed = now_hash != p->hash;

                if (changed)
                    changed_pages++;

                page_apply_event(p, changed, label);
                p->hash = now_hash;
            }
        } else {
            for (size_t j = 0; j < pages_in_chunk; j++) {
                TracePage *p = &g_pages[i + j];

                if (read_process(p->address, g_chunk, TRACE_PAGE_SIZE) != 0) {
                    read_fail++;
                    p->valid = 0;
                    p->score = 0;
                    p->changes = p->noise = 0;
                    continue;
                }

                uint64_t now_hash = hash_page(g_chunk);
                if (!p->valid) {
                    p->hash = now_hash;
                    p->valid = 1;
                    continue;
                }
                bool changed = now_hash != p->hash;

                if (changed)
                    changed_pages++;

                page_apply_event(p, changed, label);
                p->hash = now_hash;
            }
        }

        i += pages_in_chunk;
        sceKernelUsleep(500);
    }

    if (read_fail_out)
        *read_fail_out = read_fail;

    return changed_pages;
}

static int page_rank_cmp(const void *a, const void *b)
{
    const TracePage *pa = (const TracePage *)a;
    const TracePage *pb = (const TracePage *)b;

    if (pa->score != pb->score)
        return pa->score < pb->score ? 1 : -1;
    if (pa->changes != pb->changes)
        return pa->changes < pb->changes ? 1 : -1;
    if (pa->noise != pb->noise)
        return pa->noise > pb->noise ? 1 : -1;
    if (pa->address < pb->address) return -1;
    if (pa->address > pb->address) return 1;
    return 0;
}

static void write_page_ranking(void)
{
    int fd;
    char line[256];
    size_t limit;

    ensure_output_dir();
    fd = open(TRACE_PAGES, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd < 0)
        return;

    {
        int n = snprintf(line, sizeof(line),
                         "CareerTrace v2110 - page ranking\n"
                         "page_events=%u up=%u down=%u same=%u pages=%zu\n\n",
                         g_page_events, g_page_up, g_page_down,
                         g_page_same, g_page_count);
        if (n > 0 && (size_t)n < sizeof(line)) write_all(fd, line, (size_t)n);
    }

    limit = g_page_count < 300 ? g_page_count : 300;
    for (size_t i = 0; i < limit; i++) {
        int n = snprintf(line, sizeof(line),
                         "%03zu score=%d changes=%u noise=%u page=0x%016llX\n",
                         i + 1,
                         (int)g_pages[i].score,
                         (unsigned)g_pages[i].changes,
                         (unsigned)g_pages[i].noise,
                         (unsigned long long)g_pages[i].address);
        if (n > 0 && (size_t)n < sizeof(line)) write_all(fd, line, (size_t)n);
    }

    close(fd);
}

static bool page_evidence_ready(void)
{
    return g_page_events >= 5 &&
           g_page_up >= 2 &&
           g_page_down >= 2 &&
           g_page_same >= 1;
}

static bool capture_focus_pages(void)
{
    size_t captured = 0;

    if (g_phase != TRACE_PHASE_PAGES)
        return false;

    if (!page_evidence_ready()) {
        notify_status("[CareerTrace] FOCUS pede 2 UP + 2 DOWN + 1 SAME. Atual U%u D%u S%u.",
                      g_page_up, g_page_down, g_page_same);
        return false;
    }

    qsort(g_pages, g_page_count, sizeof(g_pages[0]), page_rank_cmp);
    write_page_ranking();
    memset(g_detail_score, 0, sizeof(g_detail_score));

    for (size_t i = 0;
         i < g_page_count && captured < TRACE_MAX_FOCUS_PAGES;
         i++) {
        if (!g_pages[i].valid || g_pages[i].changes == 0)
            continue;

        if (g_pages[i].score < 0 && captured >= 128)
            break;

        uint8_t *dst = g_focus_prev + captured * TRACE_PAGE_SIZE;
        if (read_process(g_pages[i].address, dst, TRACE_PAGE_SIZE) != 0)
            continue;

        g_focus_address[captured] = g_pages[i].address;
        g_focus_valid[captured] = true;
        memset(&g_focus_evidence[captured], 0, sizeof(g_focus_evidence[captured]));
        captured++;
    }

    g_focus_count = captured;
    g_detail_events = 0;
    g_detail_up = 0;
    g_detail_down = 0;
    g_detail_same = 0;
    g_top_count = 0;

    if (captured == 0) {
        notify_status("[CareerTrace] FOCUS falhou: nenhuma pagina legivel.");
        return false;
    }

    g_phase = TRACE_PHASE_DETAIL;

    append_event_line("FOCUS pages=%zu after U%u D%u S%u",
                      g_focus_count, g_page_up, g_page_down, g_page_same);
    append_log("focus pages=%zu from=%zu", g_focus_count, g_page_count);

    notify_status("[CareerTrace] FOCUS: %zu paginas. Repita 2 UP + 2 DOWN + 1 SAME para ranking exato.",
                  g_focus_count);
    return true;
}

static int relation_u8(const uint8_t *p, const uint8_t *c, size_t off)
{
    uint8_t a = p[off], b = c[off];
    return b > a ? 1 : (b < a ? -1 : 0);
}

static int relation_u16(const uint8_t *p, const uint8_t *c, size_t off)
{
    uint16_t a, b;
    memcpy(&a, p + off, sizeof(a));
    memcpy(&b, c + off, sizeof(b));
    return b > a ? 1 : (b < a ? -1 : 0);
}

static int relation_i16(const uint8_t *p, const uint8_t *c, size_t off)
{
    int16_t a, b;
    memcpy(&a, p + off, sizeof(a));
    memcpy(&b, c + off, sizeof(b));
    return b > a ? 1 : (b < a ? -1 : 0);
}

static int relation_u32(const uint8_t *p, const uint8_t *c, size_t off)
{
    uint32_t a, b;
    memcpy(&a, p + off, sizeof(a));
    memcpy(&b, c + off, sizeof(b));
    return b > a ? 1 : (b < a ? -1 : 0);
}

static int relation_i32(const uint8_t *p, const uint8_t *c, size_t off)
{
    int32_t a, b;
    memcpy(&a, p + off, sizeof(a));
    memcpy(&b, c + off, sizeof(b));
    return b > a ? 1 : (b < a ? -1 : 0);
}

static int relation_i64(const uint8_t *p, const uint8_t *c, size_t off)
{
    int64_t a, b;
    memcpy(&a, p + off, sizeof(a));
    memcpy(&b, c + off, sizeof(b));
    return b > a ? 1 : (b < a ? -1 : 0);
}

static bool f32_finite(uint32_t bits)
{
    return ((bits >> 23) & 0xFFu) != 0xFFu;
}

static int relation_f32(const uint8_t *p, const uint8_t *c,
                        size_t off, bool *valid)
{
    uint32_t ap, bp;
    float a, b;

    memcpy(&ap, p + off, sizeof(ap));
    memcpy(&bp, c + off, sizeof(bp));

    if (!f32_finite(ap) || !f32_finite(bp)) {
        *valid = false;
        return 0;
    }

    memcpy(&a, &ap, sizeof(a));
    memcpy(&b, &bp, sizeof(b));

    float aa = a < 0.0f ? -a : a;
    float bb = b < 0.0f ? -b : b;
    if (aa > 1000000000000.0f || bb > 1000000000000.0f) {
        *valid = false;
        return 0;
    }

    *valid = true;

    float d = b - a;
    float base = aa > 1.0f ? aa : 1.0f;
    float eps = base * 0.000001f;

    if (d > eps) return 1;
    if (d < -eps) return -1;
    return 0;
}

static bool f64_finite(uint64_t bits)
{
    return ((bits >> 52) & 0x7FFULL) != 0x7FFULL;
}

static int relation_f64(const uint8_t *p, const uint8_t *c,
                        size_t off, bool *valid)
{
    uint64_t ap, bp;
    double a, b;

    memcpy(&ap, p + off, sizeof(ap));
    memcpy(&bp, c + off, sizeof(bp));

    if (!f64_finite(ap) || !f64_finite(bp)) {
        *valid = false;
        return 0;
    }

    memcpy(&a, &ap, sizeof(a));
    memcpy(&b, &bp, sizeof(b));

    double aa = a < 0.0 ? -a : a;
    double bb = b < 0.0 ? -b : b;
    if (aa > 1000000000000.0 || bb > 1000000000000.0) {
        *valid = false;
        return 0;
    }

    *valid = true;

    double d = b - a;
    double base = aa > 1.0 ? aa : 1.0;
    double eps = base * 0.000000001;

    if (d > eps) return 1;
    if (d < -eps) return -1;
    return 0;
}

static void score_relation(int16_t *score, int relation, TraceLabel label)
{
    int delta;

    if (label == TRACE_LABEL_SAME) {
        delta = relation == 0 ? 3 : -10;
    } else if (label == TRACE_LABEL_UP) {
        delta = relation > 0 ? 8 : (relation < 0 ? -8 : -2);
    } else {
        delta = relation < 0 ? 8 : (relation > 0 ? -8 : -2);
    }

    *score = sat_detail_score((int)*score + delta);
}

static bool rank_less(const RankItem *a, const RankItem *b)
{
    if (a->score != b->score)
        return a->score < b->score;
    if (a->type != b->type)
        return a->type > b->type;
    if (a->page_index != b->page_index)
        return a->page_index > b->page_index;
    return a->offset > b->offset;
}

static void heap_sift_up(RankItem *heap, size_t index)
{
    while (index > 0) {
        size_t parent = (index - 1) / 2;
        if (!rank_less(&heap[index], &heap[parent]))
            break;

        RankItem t = heap[index];
        heap[index] = heap[parent];
        heap[parent] = t;
        index = parent;
    }
}

static void heap_sift_down(RankItem *heap, size_t count, size_t index)
{
    for (;;) {
        size_t left = index * 2 + 1;
        size_t right = left + 1;
        size_t smallest = index;

        if (left < count && rank_less(&heap[left], &heap[smallest]))
            smallest = left;
        if (right < count && rank_less(&heap[right], &heap[smallest]))
            smallest = right;
        if (smallest == index)
            break;

        RankItem t = heap[index];
        heap[index] = heap[smallest];
        heap[smallest] = t;
        index = smallest;
    }
}

static void rank_consider(RankItem *heap, size_t *count,
                          int16_t score, TraceType type,
                          uint16_t page_index, uint16_t offset)
{
    RankItem item;

    if (score <= 0)
        return;

    item.score = score;
    item.type = (uint8_t)type;
    item.page_index = page_index;
    item.offset = offset;
    item.reserved = 0;

    if (*count < TRACE_TOP_RESULTS) {
        heap[*count] = item;
        heap_sift_up(heap, *count);
        (*count)++;
        return;
    }

    if (rank_less(&item, &heap[0]))
        return;

    heap[0] = item;
    heap_sift_down(heap, *count, 0);
}

static int rank_desc_cmp(const void *a, const void *b)
{
    const RankItem *ra = (const RankItem *)a;
    const RankItem *rb = (const RankItem *)b;

    if (ra->score != rb->score)
        return ra->score < rb->score ? 1 : -1;
    if (ra->type != rb->type)
        return ra->type < rb->type ? -1 : 1;
    if (ra->page_index != rb->page_index)
        return ra->page_index < rb->page_index ? -1 : 1;
    if (ra->offset != rb->offset)
        return ra->offset < rb->offset ? -1 : 1;
    return 0;
}

static int detail_max_score(size_t page)
{
    const TraceEvidence *e = &g_focus_evidence[page];
    return (int)(e->up + e->down) * 8 + (int)e->same * 3;
}

static bool focus_evidence_ready(size_t page)
{
    const TraceEvidence *e = &g_focus_evidence[page];
    return g_focus_valid[page] && e->up >= 2 && e->down >= 2 && e->same >= 1;
}

static int item_confidence(const RankItem *r)
{
    int max_score = detail_max_score(r->page_index);
    int score = (int)r->score;

    if (max_score <= 0 || score <= 0)
        return 0;

    int pct = (score * 100) / max_score;
    if (pct > 100) pct = 100;
    return pct;
}

static void format_value(char *out, size_t out_size,
                         TraceType type, const uint8_t *ptr)
{
    if (type == TRACE_U8) {
        snprintf(out, out_size, "%u", (unsigned)*ptr);
    } else if (type == TRACE_U16) {
        uint16_t v;
        memcpy(&v, ptr, sizeof(v));
        snprintf(out, out_size, "%u", (unsigned)v);
    } else if (type == TRACE_I16) {
        int16_t v;
        memcpy(&v, ptr, sizeof(v));
        snprintf(out, out_size, "%d", (int)v);
    } else if (type == TRACE_U32) {
        uint32_t v;
        memcpy(&v, ptr, sizeof(v));
        snprintf(out, out_size, "%u", (unsigned)v);
    } else if (type == TRACE_I32) {
        int32_t v;
        memcpy(&v, ptr, sizeof(v));
        snprintf(out, out_size, "%d", v);
    } else if (type == TRACE_I64) {
        int64_t v;
        memcpy(&v, ptr, sizeof(v));
        snprintf(out, out_size, "%lld", (long long)v);
    } else if (type == TRACE_F32) {
        float v;
        memcpy(&v, ptr, sizeof(v));
        snprintf(out, out_size, "%.8g", (double)v);
    } else {
        double v;
        memcpy(&v, ptr, sizeof(v));
        snprintf(out, out_size, "%.12g", v);
    }
}

static void rebuild_test_queue(void)
{
    g_test_queue_count = 0;
    g_test_queue_cursor = 0;

    for (size_t i = 0;
         i < g_top_count && g_test_queue_count < TRACE_TEST_QUEUE;
         i++) {
        if (!focus_evidence_ready(g_top_results[i].page_index))
            continue;
        if (g_top_results[i].score < 8)
            continue;
        if (item_confidence(&g_top_results[i]) < 55)
            continue;

        uint64_t address =
            g_focus_address[g_top_results[i].page_index] +
            g_top_results[i].offset;

        bool near_duplicate = false;
        for (size_t q = 0; q < g_test_queue_count; q++) {
            RankItem *old = &g_top_results[g_test_queue[q]];
            uint64_t old_address =
                g_focus_address[old->page_index] + old->offset;
            /* Signed/unsigned views of the same width are aliases.
             * Adjacent values and float/int views remain distinct. */
            unsigned type = g_top_results[i].type;
            unsigned old_type = old->type;
            if (type == TRACE_I16) type = TRACE_U16;
            if (type == TRACE_I32) type = TRACE_U32;
            if (old_type == TRACE_I16) old_type = TRACE_U16;
            if (old_type == TRACE_I32) old_type = TRACE_U32;
            if (address == old_address && type == old_type) {
                near_duplicate = true;
                break;
            }
        }

        if (!near_duplicate)
            g_test_queue[g_test_queue_count++] = (uint16_t)i;
    }
}

static void dump_detail_ranking(void)
{
    RankItem heap[TRACE_TOP_RESULTS];
    size_t heap_count = 0;
    int fd;

    if (g_phase != TRACE_PHASE_DETAIL || g_focus_count == 0) {
        notify_status("[CareerTrace] Ranking exato ainda nao existe. Primeiro faca FOCUS.");
        return;
    }

    for (size_t p = 0; p < g_focus_count; p++) {
        if (!g_focus_valid[p]) continue;
        size_t base = p * TRACE_PAGE_SIZE;

        for (size_t off = 0; off < TRACE_PAGE_SIZE; off++) {
            size_t idx = base + off;

            rank_consider(heap, &heap_count,
                          g_detail_score[TRACE_U8][idx],
                          TRACE_U8, (uint16_t)p, (uint16_t)off);

            if (off + 2 <= TRACE_PAGE_SIZE) {
                rank_consider(heap, &heap_count,
                              g_detail_score[TRACE_U16][idx],
                              TRACE_U16, (uint16_t)p, (uint16_t)off);
                rank_consider(heap, &heap_count,
                              g_detail_score[TRACE_I16][idx],
                              TRACE_I16, (uint16_t)p, (uint16_t)off);
            }

            if (off + 4 <= TRACE_PAGE_SIZE) {
                rank_consider(heap, &heap_count,
                              g_detail_score[TRACE_U32][idx],
                              TRACE_U32, (uint16_t)p, (uint16_t)off);
                rank_consider(heap, &heap_count,
                              g_detail_score[TRACE_I32][idx],
                              TRACE_I32, (uint16_t)p, (uint16_t)off);
                rank_consider(heap, &heap_count,
                              g_detail_score[TRACE_F32][idx],
                              TRACE_F32, (uint16_t)p, (uint16_t)off);
            }

            if (off + 8 <= TRACE_PAGE_SIZE) {
                rank_consider(heap, &heap_count,
                              g_detail_score[TRACE_I64][idx],
                              TRACE_I64, (uint16_t)p, (uint16_t)off);
                rank_consider(heap, &heap_count,
                              g_detail_score[TRACE_F64][idx],
                              TRACE_F64, (uint16_t)p, (uint16_t)off);
            }
        }
    }

    qsort(heap, heap_count, sizeof(heap[0]), rank_desc_cmp);

    g_top_count = heap_count;
    if (g_top_count > 0)
        memcpy(g_top_results, heap, g_top_count * sizeof(heap[0]));

    rebuild_test_queue();

    ensure_output_dir();
    fd = open(TRACE_RANK, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd < 0) {
        notify_status("[CareerTrace] Ranking calculado, mas falhou ao salvar trace_rank.txt.");
        return;
    }

    bool saved = write_format(fd,
        "CareerTrace v2110 - ranking de correlacao\n"
        "focused_pages=%zu detail_events=%u UP=%u DOWN=%u SAME=%u\n"
        "types=u8,u16,i16,u32,i32,i64,f32,f64; unaligned offsets included\n"
        "score: match +8, opposite -8, stationary -2, SAME stable +3, SAME noise -10\n"
        "match = score / maximum for this page's valid comparisons; NOT probability or proof\n"
        "test_queue=%zu (match>=55%%, score>=8, at least 2 UP + 2 DOWN + 1 SAME per page)\n"
        "Only equivalent signed/unsigned views at the same address are collapsed.\n\n",
        g_focus_count, g_detail_events, g_detail_up, g_detail_down,
        g_detail_same, g_test_queue_count);

    for (size_t i = 0; i < heap_count; i++) {
        RankItem *r = &heap[i];
        size_t base = (size_t)r->page_index * TRACE_PAGE_SIZE;
        const uint8_t *ptr = g_focus_prev + base + r->offset;
        uint64_t address = g_focus_address[r->page_index] + r->offset;
        const TraceEvidence *e = &g_focus_evidence[r->page_index];
        char value[80];
        format_value(value, sizeof(value), (TraceType)r->type, ptr);
        if (!write_format(fd,
                "%03zu score=%d match=%d%% type=%s addr=0x%016llX value=%s U=%u D=%u S=%u ready=%d page=%u off=0x%03X\n",
                i + 1, (int)r->score, item_confidence(r),
                type_name((TraceType)r->type), (unsigned long long)address, value,
                e->up, e->down, e->same, focus_evidence_ready(r->page_index),
                (unsigned)r->page_index, (unsigned)r->offset)) saved = false;
    }
    if (close(fd) != 0) saved = false;
    if (!saved) {
        notify_status("[CareerTrace] Erro salvando ranking completo. Ranking mantido em memoria.");
        return;
    }

    if (heap_count > 0) {
        RankItem *top = &heap[0];
        uint64_t address = g_focus_address[top->page_index] + top->offset;

        notify_status("[CareerTrace] FASE 2 TOP: score=%d match=%d%% %s 0x%llX | fila teste=%zu.",
                      (int)top->score,
                      item_confidence(top),
                      type_name((TraceType)top->type),
                      (unsigned long long)address,
                      g_test_queue_count);
    } else {
        notify_status("[CareerTrace] Ranking salvo; ainda sem score positivo.");
    }
}

static void detail_event(TraceLabel label)
{
    size_t pages_read = 0;
    size_t pages_failed = 0;
    size_t pages_rebased = 0;

    if (g_detail_events >= TRACE_MAX_DETAIL_EVENTS) {
        notify_status("[CareerTrace] Limite de %u eventos. Salve o ranking e reinicie o baseline.", TRACE_MAX_DETAIL_EVENTS);
        return;
    }

    for (size_t p = 0; worker_running() && p < g_focus_count; p++) {
        uint8_t *prev = g_focus_prev + p * TRACE_PAGE_SIZE;

        if (read_process(g_focus_address[p], g_chunk, TRACE_PAGE_SIZE) != 0) {
            pages_failed++;
            g_focus_valid[p] = false;
            memset(&g_focus_evidence[p], 0, sizeof(g_focus_evidence[p]));
            for (size_t t = 0; t < TRACE_TYPE_COUNT; t++)
                memset(g_detail_score[t] + p * TRACE_PAGE_SIZE, 0,
                       TRACE_PAGE_SIZE * sizeof(g_detail_score[0][0]));
            continue;
        }

        if (!g_focus_valid[p]) {
            memcpy(prev, g_chunk, TRACE_PAGE_SIZE);
            g_focus_valid[p] = true;
            pages_rebased++;
            continue;
        }

        pages_read++;

        for (size_t off = 0; off < TRACE_PAGE_SIZE; off++) {
            size_t idx = p * TRACE_PAGE_SIZE + off;
            int rel;
            bool valid;

            rel = relation_u8(prev, g_chunk, off);
            score_relation(&g_detail_score[TRACE_U8][idx], rel, label);

            if (off + 2 <= TRACE_PAGE_SIZE) {
                rel = relation_u16(prev, g_chunk, off);
                score_relation(&g_detail_score[TRACE_U16][idx], rel, label);

                rel = relation_i16(prev, g_chunk, off);
                score_relation(&g_detail_score[TRACE_I16][idx], rel, label);
            }

            if (off + 4 <= TRACE_PAGE_SIZE) {
                rel = relation_u32(prev, g_chunk, off);
                score_relation(&g_detail_score[TRACE_U32][idx], rel, label);

                rel = relation_i32(prev, g_chunk, off);
                score_relation(&g_detail_score[TRACE_I32][idx], rel, label);

                rel = relation_f32(prev, g_chunk, off, &valid);
                if (valid)
                    score_relation(&g_detail_score[TRACE_F32][idx], rel, label);
                else
                    g_detail_score[TRACE_F32][idx] = 0;
            }

            if (off + 8 <= TRACE_PAGE_SIZE) {
                rel = relation_i64(prev, g_chunk, off);
                score_relation(&g_detail_score[TRACE_I64][idx], rel, label);

                rel = relation_f64(prev, g_chunk, off, &valid);
                if (valid)
                    score_relation(&g_detail_score[TRACE_F64][idx], rel, label);
                else
                    g_detail_score[TRACE_F64][idx] = 0;
            }
        }

        memcpy(prev, g_chunk, TRACE_PAGE_SIZE);
        TraceEvidence *e = &g_focus_evidence[p];
        if (label == TRACE_LABEL_UP) e->up++;
        else if (label == TRACE_LABEL_DOWN) e->down++;
        else e->same++;
        sceKernelUsleep(250);
    }

    if (!worker_running()) return;
    if (pages_read == 0) {
        g_top_count = g_test_queue_count = 0;
        notify_status("[CareerTrace] Evento nao contado: sem comparacoes validas (%zu falhas, %zu referencias renovadas).", pages_failed, pages_rebased);
        dump_detail_ranking();
        return;
    }

    g_detail_events++;
    if (label == TRACE_LABEL_UP) g_detail_up++;
    else if (label == TRACE_LABEL_DOWN) g_detail_down++;
    else g_detail_same++;

    append_event_line("DETAIL %u %s read=%zu fail=%zu rebased=%zu focused=%zu U=%u D=%u S=%u",
                      g_detail_events, label_name(label),
                      pages_read, pages_failed, pages_rebased, g_focus_count,
                      g_detail_up, g_detail_down, g_detail_same);

    dump_detail_ranking();
}

static void record_event(TraceLabel label)
{
    if (g_phase == TRACE_PHASE_IDLE) {
        notify_status("[CareerTrace] Primeiro faca BASELINE com R1+CIMA.");
        return;
    }

    if (g_test_active || g_test_armed) {
        notify_status("[CareerTrace] Restaure/desarme o TESTE antes de registrar eventos.");
        return;
    }

    if (g_phase == TRACE_PHASE_PAGES) {
        size_t fail = 0;
        size_t changed = rescan_pages(label, &fail);

        if (!worker_running()) return;
        if (fail == g_page_count) {
            notify_status("[CareerTrace] Evento nao contado: nenhuma pagina legivel.");
            return;
        }

        g_page_events++;
        if (label == TRACE_LABEL_UP) g_page_up++;
        else if (label == TRACE_LABEL_DOWN) g_page_down++;
        else g_page_same++;

        append_event_line("PAGE %u %s changed=%zu/%zu read_fail=%zu U=%u D=%u S=%u",
                          g_page_events, label_name(label),
                          changed, g_page_count, fail,
                          g_page_up, g_page_down, g_page_same);

        notify_status("[CareerTrace] PAGE %u %s: %zu mudaram | U%u D%u S%u.",
                      g_page_events, label_name(label), changed,
                      g_page_up, g_page_down, g_page_same);
    } else {
        detail_event(label);
    }
}

static void dump_or_focus(void)
{
    if (g_test_armed || g_test_active) {
        notify_status("[CareerTrace] Ranking preservado durante teste. L1+R1 desarma antes de refiltrar.");
        return;
    }
    if (g_phase == TRACE_PHASE_IDLE) {
        notify_status("[CareerTrace] Nada ainda. R1+CIMA cria o baseline.");
        return;
    }

    if (g_phase == TRACE_PHASE_PAGES) {
        capture_focus_pages();
    } else {
        dump_detail_ranking();
    }
}

static bool detail_evidence_ready(void)
{
    return g_detail_events >= 5 &&
           g_detail_up >= 2 &&
           g_detail_down >= 2 &&
           g_detail_same >= 1;
}

static bool query_test_region(uint64_t address, size_t size,
                              OrbisKernelVirtualQueryInfo *info)
{
    if (!size || size > sizeof(uint64_t) || address > UINT64_MAX - size)
        return false;
    if (sceKernelVirtualQuery((void *)(uintptr_t)address, 0,
                              info, sizeof(*info)) < 0)
        return false;
    return (uintptr_t)info->start_addr <= address &&
           address + size <= (uintptr_t)info->end_addr &&
           (info->prot & (CPU_READ | CPU_WRITE)) == (CPU_READ | CPU_WRITE) &&
           !(info->prot & CPU_EXEC) && !info->isStack &&
           !overlaps_internal_region((uintptr_t)address, (uintptr_t)(address + size));
}

static void clear_active_test(void)
{
    g_test_active = false;
    g_test_active_address = 0;
    g_test_active_size = 0;
    g_test_original_raw = g_test_applied_raw = g_test_deadline = 0;
}

static RestoreResult restore_active_test(void)
{
    OrbisKernelVirtualQueryInfo info;
    uint64_t current = 0, verify = 0;
    if (!g_test_active) return RESTORE_NONE;

    if (!query_test_region(g_test_active_address, g_test_active_size, &info) ||
        read_process(g_test_active_address, &current, g_test_active_size) != 0) {
        append_test_line("RESTORE_PENDING addr=0x%016llX original=0x%016llX applied=0x%016llX size=%zu",
                         (unsigned long long)g_test_active_address,
                         (unsigned long long)g_test_original_raw,
                         (unsigned long long)g_test_applied_raw, g_test_active_size);
        return RESTORE_RETRY;
    }
    if ((uintptr_t)info.start_addr != g_test_region_start ||
        (uintptr_t)info.end_addr != g_test_region_end ||
        (memcmp(&current, &g_test_applied_raw, g_test_active_size) != 0 &&
         memcmp(&current, &g_test_original_raw, g_test_active_size) != 0)) {
        append_test_line("RESTORE_SKIPPED_GAME_CHANGED addr=0x%016llX current=0x%016llX",
                         (unsigned long long)g_test_active_address,
                         (unsigned long long)current);
        clear_active_test();
        return RESTORE_GAME_CHANGED;
    }
    if (memcmp(&current, &g_test_original_raw, g_test_active_size) != 0) {
        if (write_process(g_test_active_address, &g_test_original_raw, g_test_active_size) != 0 ||
            read_process(g_test_active_address, &verify, g_test_active_size) != 0 ||
            memcmp(&verify, &g_test_original_raw, g_test_active_size) != 0) {
            append_test_line("RESTORE_PENDING verification_failed addr=0x%016llX",
                             (unsigned long long)g_test_active_address);
            return RESTORE_RETRY;
        }
    }
    append_test_line("RESTORED type=%s addr=0x%016llX size=%zu",
                     type_name(g_test_active_type),
                     (unsigned long long)g_test_active_address, g_test_active_size);
    clear_active_test();
    return RESTORE_OK;
}

/* Test writes must never be learned as natural changes of titularidade. */
static void refresh_detail_reference(void)
{
    if (!g_detail_needs_refresh) return;
    memset(g_detail_score, 0, sizeof(g_detail_score));
    memset(g_focus_evidence, 0, sizeof(g_focus_evidence));
    for (size_t p = 0; p < g_focus_count; p++)
        g_focus_valid[p] = read_process(g_focus_address[p],
                                      g_focus_prev + p * TRACE_PAGE_SIZE,
                                      TRACE_PAGE_SIZE) == 0;
    g_detail_events = g_detail_up = g_detail_down = g_detail_same = 0;
    g_top_count = g_test_queue_count = g_test_queue_cursor = 0;
    g_detail_needs_refresh = false;
    append_event_line("DETAIL_REBASE_AFTER_TEST collect_new_natural_events");
}

static bool make_test_value(TraceType type, uint64_t original,
                            uint64_t *test_out, char *before,
                            size_t before_size, char *after,
                            size_t after_size)
{
    uint64_t test = original;

    if (type == TRACE_U8) {
        uint8_t a = (uint8_t)original;
        uint8_t b = a < 255 ? (uint8_t)(a + 1) : (uint8_t)(a - 1);
        test = b;
        snprintf(before, before_size, "%u", (unsigned)a);
        snprintf(after, after_size, "%u", (unsigned)b);
    } else if (type == TRACE_U16) {
        uint16_t a = (uint16_t)original;
        uint16_t b = a < 65535 ? (uint16_t)(a + 1) : (uint16_t)(a - 1);
        test = b;
        snprintf(before, before_size, "%u", (unsigned)a);
        snprintf(after, after_size, "%u", (unsigned)b);
    } else if (type == TRACE_I16) {
        int16_t a;
        memcpy(&a, &original, sizeof(a));
        int16_t b = a < 32767 ? (int16_t)(a + 1) : (int16_t)(a - 1);
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%d", (int)a);
        snprintf(after, after_size, "%d", (int)b);
    } else if (type == TRACE_U32) {
        uint32_t a;
        memcpy(&a, &original, sizeof(a));
        if (a > 1000000u) return false;
        uint32_t b = a + 1u;
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%u", (unsigned)a);
        snprintf(after, after_size, "%u", (unsigned)b);
    } else if (type == TRACE_I32) {
        int32_t a;
        memcpy(&a, &original, sizeof(a));
        if (a < -1000000 || a > 1000000) return false;
        int32_t b = a + 1;
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%d", a);
        snprintf(after, after_size, "%d", b);
    } else if (type == TRACE_I64) {
        int64_t a;
        memcpy(&a, &original, sizeof(a));
        if (a < -1000000 || a > 1000000) return false;
        int64_t b = a + 1;
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%lld", (long long)a);
        snprintf(after, after_size, "%lld", (long long)b);
    } else if (type == TRACE_F32) {
        uint32_t bits;
        float a, b;
        memcpy(&bits, &original, sizeof(bits));
        if (!f32_finite(bits))
            return false;
        memcpy(&a, &bits, sizeof(a));

        float aa = a < 0.0f ? -a : a;
        if (aa > 1000000.0f || (aa > 0.0f && aa < 0.000001f)) return false;
        float delta = aa <= 1.0f ? 0.01f : 1.0f;
        b = a + delta;
        if (a >= 0.0f && a <= 1.0f && b > 1.0f) b = a - delta;
        if (b == a) return false;
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%.8g", (double)a);
        snprintf(after, after_size, "%.8g", (double)b);
    } else if (type == TRACE_F64) {
        double a, b;
        if (!f64_finite(original))
            return false;
        memcpy(&a, &original, sizeof(a));

        double aa = a < 0.0 ? -a : a;
        if (aa > 1000000.0 || (aa > 0.0 && aa < 0.000000001)) return false;
        double delta = aa <= 1.0 ? 0.01 : 1.0;
        b = a + delta;
        if (a >= 0.0 && a <= 1.0 && b > 1.0) b = a - delta;
        if (b == a) return false;
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%.12g", a);
        snprintf(after, after_size, "%.12g", b);
    } else {
        return false;
    }

    *test_out = test;
    return true;
}

static void toggle_test_arm(void)
{
    if (g_test_armed) {
        RestoreResult result = restore_active_test();
        if (result == RESTORE_RETRY) {
            notify_status("[CareerTrace] Restauracao pendente. R1+DIR tenta novamente.");
            return;
        }
        g_test_armed = false;
        g_test_queue_cursor = 0;
        bool refresh = g_detail_needs_refresh;
        refresh_detail_reference();
        notify_status("[CareerTrace] TESTE desarmado.%s%s",
                      result == RESTORE_GAME_CHANGED ? " Jogo mudou valor; restauracao ignorada." : "",
                      refresh ? " Referencia renovada: repita eventos na FASE 2." : " Filtragem preservada.");
        return;
    }

    if (g_phase != TRACE_PHASE_DETAIL || !detail_evidence_ready()) {
        notify_status("[CareerTrace] TESTE pede detalhe com 2 UP + 2 DOWN + 1 SAME. Atual U%u D%u S%u.",
                      g_detail_up, g_detail_down, g_detail_same);
        return;
    }

    dump_detail_ranking();

    if (g_test_queue_count == 0) {
        notify_status("[CareerTrace] Nenhum candidato com aderencia >=55%% ainda. Colete mais eventos.");
        return;
    }

    append_test_line("CareerTrace v2110 test queue=%zu", g_test_queue_count);

    g_test_armed = true;
    g_test_queue_cursor = 0;

    RankItem *top = &g_top_results[g_test_queue[0]];
    uint64_t address = g_focus_address[top->page_index] + top->offset;

    notify_status("[CareerTrace] TESTE ARMADO: %zu candidatos. TOP match=%d%% %s 0x%llX. R1+ESQ testa 1.",
                  g_test_queue_count,
                  item_confidence(top),
                  type_name((TraceType)top->type),
                  (unsigned long long)address);
}

static void report_restore(RestoreResult result)
{
    if (result == RESTORE_OK)
        notify_status("[CareerTrace] Valor restaurado e verificado.");
    else if (result == RESTORE_GAME_CHANGED)
        notify_status("[CareerTrace] O jogo mudou o valor/regiao. Restauracao antiga ignorada; veja trace_test.txt.");
    else if (result == RESTORE_RETRY)
        notify_status("[CareerTrace] Restauracao pendente. Novos testes bloqueados; R1+DIR tenta novamente.");
    else
        notify_status("[CareerTrace] Nenhum teste ativo.");
}

static void test_next_ranked(void)
{
    OrbisKernelVirtualQueryInfo info;
    uint64_t raw = 0, test = 0, verify = 0;
    char before[64], after[64];
    if (!g_test_armed) {
        notify_status("[CareerTrace] Primeiro arme TESTE com L1+R1.");
        return;
    }
    RestoreResult restored = restore_active_test();
    if (restored == RESTORE_RETRY) {
        report_restore(restored);
        return;
    }
    if (g_test_queue_cursor >= g_test_queue_count) {
        notify_status("[CareerTrace] Fila concluida. L1+R1 desarma e prepara nova filtragem.");
        return;
    }

    size_t rank_index = g_test_queue[g_test_queue_cursor++];
    RankItem *r = &g_top_results[rank_index];
    TraceType type = (TraceType)r->type;
    uint64_t address = g_focus_address[r->page_index] + r->offset;
    size_t size = type_size(type);
    const uint8_t *expected = g_focus_prev + r->page_index * TRACE_PAGE_SIZE + r->offset;

    if (!query_test_region(address, size, &info) ||
        read_process(address, &raw, size) != 0 || memcmp(&raw, expected, size) != 0) {
        append_test_line("SKIP rank=%zu addr=0x%016llX stale_or_unreadable", rank_index + 1,
                         (unsigned long long)address);
        notify_status("[CareerTrace] TOP %zu mudou desde a medicao ou esta ilegivel; candidato ignorado.", rank_index + 1);
        return;
    }
    if (!make_test_value(type, raw, &test, before, sizeof(before), after, sizeof(after))) {
        append_test_line("SKIP rank=%zu addr=0x%016llX type=%s unsupported_value",
                         rank_index + 1, (unsigned long long)address, type_name(type));
        notify_status("[CareerTrace] TOP %zu fora dos limites do teste. Permanece no ranking.", rank_index + 1);
        return;
    }
    if (!append_test_line("PREPARE queue=%zu/%zu rank=%zu type=%s addr=0x%016llX size=%zu original=0x%016llX applied=0x%016llX %s -> %s",
                          g_test_queue_cursor, g_test_queue_count, rank_index + 1, type_name(type),
                          (unsigned long long)address, size, (unsigned long long)raw,
                          (unsigned long long)test, before, after)) {
        notify_status("[CareerTrace] Teste cancelado: falha salvando valores originais.");
        return;
    }
    /* Re-read after logging; a file write can take longer than a game update. */
    if (read_process(address, &verify, size) != 0 || memcmp(&verify, &raw, size) != 0) {
        append_test_line("SKIP rank=%zu changed_before_write", rank_index + 1);
        notify_status("[CareerTrace] Candidato mudou antes da escrita; ignorado.");
        return;
    }

    g_test_active = true;
    g_test_active_address = address;
    g_test_original_raw = raw;
    g_test_applied_raw = test;
    g_test_active_size = size;
    g_test_active_type = type;
    g_test_region_start = (uintptr_t)info.start_addr;
    g_test_region_end = (uintptr_t)info.end_addr;
    g_test_deadline = sceKernelGetProcessTime() + TRACE_TEST_DURATION_US;
    g_detail_needs_refresh = true;

    verify = 0;
    if (write_process(address, &test, size) != 0 ||
        read_process(address, &verify, size) != 0 || memcmp(&verify, &test, size) != 0) {
        append_test_line("WRITE_NOT_CONFIRMED rank=%zu", rank_index + 1);
        notify_status("[CareerTrace] Escrita nao confirmada; interrompendo teste.");
        report_restore(restore_active_test());
        return;
    }
    append_test_line("ACTIVE rank=%zu match=%d%% timeout_seconds=10", rank_index + 1, item_confidence(r));
    notify_status("[CareerTrace] TESTE %zu/%zu | %s %s -> %s | ate 10s. R1+DIR restaura.",
                  g_test_queue_cursor, g_test_queue_count, type_name(type), before, after);
}

static void manual_restore_test(void)
{
    report_restore(restore_active_test());
}

static unsigned remaining(unsigned required, unsigned current)
{
    return current < required ? required - current : 0;
}

static void format_status(char *out, size_t capacity)
{
    if (g_test_active) {
        snprintf(out, capacity, "TESTE %zu/%zu ativo. R1+DIR restaura. L1+R1 desarma.",
                 g_test_queue_cursor, g_test_queue_count);
    } else if (g_test_armed) {
        snprintf(out, capacity, "TESTE armado: %zu/%zu percorridos. R1+ESQ proximo; L1+R1 desarma.",
                 g_test_queue_cursor, g_test_queue_count);
    } else if (g_phase == TRACE_PHASE_IDLE) {
        snprintf(out, capacity, "INICIO: entre na Carreira de Jogador e use R1+CIMA para criar a referencia.");
    } else {
        bool detail = g_phase == TRACE_PHASE_DETAIL;
        unsigned up = detail ? g_detail_up : g_page_up;
        unsigned down = detail ? g_detail_down : g_page_down;
        unsigned same = detail ? g_detail_same : g_page_same;
        if (detail && g_top_count) {
            const TraceEvidence *e = &g_focus_evidence[g_top_results[0].page_index];
            up = e->up; down = e->down; same = e->same;
        }
        const char *next = !detail ? "R2+ESQ faz FOCUS" :
                           g_test_queue_count ? "R2+ESQ salva; L1+R1 arma teste opcional" :
                           "Colete mais mudancas naturais; ainda sem fila apta";
        snprintf(out, capacity,
                 "FASE %u %s | U%u D%u S%u | faltam: %u subidas, %u quedas, %u igual. %s.",
                 detail ? 2u : 1u, detail ? "VALORES" : "REGIOES", up, down, same,
                 remaining(2, up), remaining(2, down), remaining(1, same),
                 up >= 2 && down >= 2 && same >= 1 ? next : "Registre mudancas reais com R2+setas");
    }
}

static void save_status(void)
{
    char status[512];
    format_status(status, sizeof(status));
    int fd = open(TRACE_STATUS, O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd < 0) return;
    write_format(fd, "CareerTrace v2110\n%s\nR2+CIMA=subiu | R2+BAIXO=desceu | R2+DIREITA=igual\nR1+BAIXO=mostrar este resumo\n", status);
    close(fd);
}

static void show_status(void)
{
    char status[512];
    format_status(status, sizeof(status));
    notify_status("[CareerTrace] %s", status);
}

static void expire_active_test(void)
{
    if (!g_test_active || !g_test_deadline || sceKernelGetProcessTime() < g_test_deadline)
        return;
    g_test_deadline = 0; /* A failed restore requires an explicit retry, not a tight loop. */
    report_restore(restore_active_test());
    save_status();
}

static void execute_action(DiagAction action)
{
    __atomic_store_n(&g_busy, 1, __ATOMIC_RELEASE);

    switch (action) {
        case DIAG_ACTION_SNAPSHOT:
            initial_page_snapshot();
            break;
        case DIAG_ACTION_INCREASED:
            record_event(TRACE_LABEL_UP);
            break;
        case DIAG_ACTION_DECREASED:
            record_event(TRACE_LABEL_DOWN);
            break;
        case DIAG_ACTION_UNCHANGED:
            record_event(TRACE_LABEL_SAME);
            break;
        case DIAG_ACTION_DUMP:
            dump_or_focus();
            break;
        case DIAG_ACTION_TEST_ARM:
            toggle_test_arm();
            break;
        case DIAG_ACTION_TEST_NEXT:
            test_next_ranked();
            break;
        case DIAG_ACTION_TEST_RESTORE:
            manual_restore_test();
            break;
        case DIAG_ACTION_STATUS:
            show_status();
            break;
        case DIAG_ACTION_STRUCTURE_HUNT:
            structure_hunter_scan();
            break;
        default:
            break;
    }

    save_status();
    __atomic_store_n(&g_busy, 0, __ATOMIC_RELEASE);
}

static void *worker_main(void *arg)
{
    (void)arg;

    while (worker_running()) {
        DiagAction action = (DiagAction)__atomic_exchange_n(&g_pending_action,
                                            DIAG_ACTION_NONE, __ATOMIC_ACQ_REL);

        if (action != DIAG_ACTION_NONE) {
            execute_action(action);
        }

        expire_active_test();
        int rejected = __atomic_exchange_n(&g_rejected_action, DIAG_ACTION_NONE, __ATOMIC_ACQ_REL);
        if (rejected == DIAG_ACTION_STATUS) show_status();
        else if (rejected != DIAG_ACTION_NONE)
            notify_status("[CareerTrace] O ultimo comando chegou durante outra operacao e NAO foi registrado. Agora repita esse comando.");

        sceKernelUsleep(50000);
    }

    scePthreadExit(NULL);
    return NULL;
}

int diag_start_worker(void)
{
    __atomic_store_n(&g_worker_running, 1, __ATOMIC_RELEASE);
    __atomic_store_n(&g_pending_action, DIAG_ACTION_NONE, __ATOMIC_RELEASE);
    __atomic_store_n(&g_busy, 0, __ATOMIC_RELEASE);
    __atomic_store_n(&g_rejected_action, DIAG_ACTION_NONE, __ATOMIC_RELEASE);

    g_page_count = 0;
    g_focus_count = 0;
    g_phase = TRACE_PHASE_IDLE;
    g_test_armed = false;
    g_test_active = false;

    ensure_output_dir();
    append_log("--- new plugin session ---");

    append_log("=== CareerTrace v2200 + Player Structure Hunter ===");
    append_log("read-only correlation search until explicit TEST mode");
    append_log("two-stage: full-RAM page fingerprint -> exact multi-type ranking");
    append_log("types=u8,u16,i16,u32,i32,i64,f32,f64; unaligned exact scan");
    append_log("SAME controls penalize background noise; candidates are scored, not destructively deleted");

    save_status();
    int result = scePthreadCreate(&g_worker_thread, NULL, worker_main, NULL,
                                 "career_trace_worker");
    if (result != 0) __atomic_store_n(&g_worker_running, 0, __ATOMIC_RELEASE);
    return result;
}

void diag_stop_worker(void)
{
    if (!worker_running())
        return;

    __atomic_store_n(&g_worker_running, 0, __ATOMIC_RELEASE);
    scePthreadJoin(g_worker_thread, NULL);
    restore_active_test();
}

void diag_request(DiagAction action)
{
    if (!worker_running())
        return;
    if (action == DIAG_ACTION_TEST_RESTORE) {
        int displaced = __atomic_exchange_n(&g_pending_action, (int)action, __ATOMIC_ACQ_REL);
        if (displaced != DIAG_ACTION_NONE && displaced != (int)action)
            __atomic_store_n(&g_rejected_action, displaced, __ATOMIC_RELEASE);
        return;
    }
    int expected = DIAG_ACTION_NONE;
    if (__atomic_load_n(&g_busy, __ATOMIC_ACQUIRE) ||
        !__atomic_compare_exchange_n(&g_pending_action, &expected, (int)action,
                                      false, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE))
        __atomic_store_n(&g_rejected_action, (int)action, __ATOMIC_RELEASE);
}
