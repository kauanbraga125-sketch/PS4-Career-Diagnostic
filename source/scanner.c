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
#include <stdarg.h>
#include <sys/stat.h>

#define DIAG_DIR GOLDHEN_PATH "/career_diag"
#define DIAG_LOG DIAG_DIR "/diagnostic.log"
#define TRACE_EVENTS DIAG_DIR "/trace_events.txt"
#define TRACE_PAGES DIAG_DIR "/trace_pages.txt"
#define TRACE_RANK DIAG_DIR "/trace_rank.txt"
#define TRACE_TEST DIAG_DIR "/trace_test.txt"

#define VQ_FIND_NEXT 1
#define CPU_READ  0x01
#define CPU_WRITE 0x02

#define TRACE_PAGE_SIZE 4096u
#define TRACE_CHUNK_SIZE (512u * 1024u)
#define TRACE_MAX_PAGES 720000u
#define TRACE_MAX_FOCUS_PAGES 384u
#define TRACE_MAX_FOCUS_BYTES (TRACE_MAX_FOCUS_PAGES * TRACE_PAGE_SIZE)
#define TRACE_TOP_RESULTS 300u
#define TRACE_TEST_QUEUE 64u

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
} TracePage;

typedef struct RankItem {
    int8_t score;
    uint8_t type;
    uint16_t page_index;
    uint16_t offset;
    uint16_t reserved;
} RankItem;

static TracePage g_pages[TRACE_MAX_PAGES];
static uint8_t g_chunk[TRACE_CHUNK_SIZE];

static uint64_t g_focus_address[TRACE_MAX_FOCUS_PAGES];
static uint8_t g_focus_prev[TRACE_MAX_FOCUS_BYTES];
static int8_t g_detail_score[TRACE_TYPE_COUNT][TRACE_MAX_FOCUS_BYTES];

static RankItem g_top_results[TRACE_TOP_RESULTS];
static size_t g_top_count = 0;

static uint16_t g_test_queue[TRACE_TEST_QUEUE];
static size_t g_test_queue_count = 0;
static size_t g_test_queue_cursor = 0;
static bool g_test_armed = false;
static bool g_test_active = false;
static uint64_t g_test_active_address = 0;
static uint64_t g_test_original_raw = 0;
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

static volatile int g_pending_action = DIAG_ACTION_NONE;
static volatile int g_worker_running = 0;
static volatile int g_busy = 0;
static OrbisPthread g_worker_thread;

static void restore_active_test(void);
static void dump_detail_ranking(void);

static void ensure_output_dir(void)
{
    mkdir(DIAG_DIR, 0777);
}

static void append_file_line(const char *path, const char *fmt, va_list args)
{
    char line[768];
    int fd;
    int len;

    ensure_output_dir();

    len = vsnprintf(line, sizeof(line), fmt, args);
    if (len <= 0)
        return;
    if ((size_t)len >= sizeof(line))
        len = (int)sizeof(line) - 1;

    fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (fd < 0)
        return;

    write(fd, line, (size_t)len);
    write(fd, "\n", 1);
    close(fd);
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

static void append_test_line(const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    append_file_line(TRACE_TEST, fmt, args);
    va_end(args);
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
                       (uintptr_t)&g_detail_score[TRACE_TYPE_COUNT - 1][TRACE_MAX_FOCUS_BYTES - 1] + 1))
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

static int8_t sat_detail_score(int value)
{
    if (value > 120) return 120;
    if (value < -120) return -120;
    return (int8_t)value;
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

    memset(g_detail_score, 0, sizeof(g_detail_score));
}

static void initial_page_snapshot(void)
{
    OrbisKernelVirtualQueryInfo info;
    void *cursor = NULL;
    uintptr_t last_end = 0;
    uint64_t bytes_scanned = 0;
    uint32_t regions_scanned = 0;
    bool hit_cap = false;

    reset_trace_state();
    clear_trace_files();

    notify_status("[CareerTrace v2100] Baseline completo iniciado. Aguarde.");
    append_log("=== CareerTrace v2100 page baseline ===");

    while (!hit_cap &&
           sceKernelVirtualQuery(cursor, VQ_FIND_NEXT, &info, sizeof(info)) >= 0) {
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
        if (overlaps_internal_region(start, end))
            continue;

        regions_scanned++;

        uintptr_t current = start;
        while (current + TRACE_PAGE_SIZE <= end && !hit_cap) {
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
            }

            bytes_scanned += amount;
            current += amount;
            sceKernelUsleep(1000);
        }
    }

    g_phase = TRACE_PHASE_PAGES;

    append_log("baseline regions=%u bytes=%llu pages=%zu cap=%d",
               regions_scanned,
               (unsigned long long)bytes_scanned,
               g_page_count,
               hit_cap ? 1 : 0);

    append_event_line("CareerTrace v2100");
    append_event_line("BASELINE pages=%zu bytes=%llu regions=%u cap=%d",
                      g_page_count,
                      (unsigned long long)bytes_scanned,
                      regions_scanned,
                      hit_cap ? 1 : 0);

    notify_status("[CareerTrace] Baseline: %zu paginas. Faça 2 UP + 2 DOWN + 1 SAME antes do FOCUS.",
                  g_page_count);
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

    while (i < g_page_count) {
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
                    continue;
                }

                uint64_t now_hash = hash_page(g_chunk);
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
                         "CareerTrace v2100 - page ranking\n"
                         "page_events=%u up=%u down=%u same=%u pages=%zu\n\n",
                         g_page_events, g_page_up, g_page_down,
                         g_page_same, g_page_count);
        if (n > 0) write(fd, line, (size_t)n);
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
        if (n > 0) write(fd, line, (size_t)n);
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
        if (g_pages[i].changes == 0)
            continue;

        if (g_pages[i].score < 0 && captured >= 128)
            break;

        uint8_t *dst = g_focus_prev + captured * TRACE_PAGE_SIZE;
        if (read_process(g_pages[i].address, dst, TRACE_PAGE_SIZE) != 0)
            continue;

        g_focus_address[captured] = g_pages[i].address;
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

static void score_relation(int8_t *score, int relation, TraceLabel label)
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
                          int8_t score, TraceType type,
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

static int detail_max_score(void)
{
    return (int)(g_detail_up + g_detail_down) * 8 +
           (int)g_detail_same * 3;
}

static int item_confidence(const RankItem *r)
{
    int max_score = detail_max_score();
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
            uint64_t diff = address > old_address ?
                            address - old_address :
                            old_address - address;
            if (diff <= 7) {
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
    char line[420];

    if (g_phase != TRACE_PHASE_DETAIL || g_focus_count == 0) {
        notify_status("[CareerTrace] Ranking exato ainda nao existe. Primeiro faca FOCUS.");
        return;
    }

    for (size_t p = 0; p < g_focus_count; p++) {
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
    if (fd < 0)
        return;

    {
        int n = snprintf(line, sizeof(line),
                         "CareerTrace v2100 - exact correlation ranking\n"
                         "focused_pages=%zu detail_events=%u UP=%u DOWN=%u SAME=%u\n"
                         "types=u8,u16,i16,u32,i32,i64,f32,f64; unaligned offsets included\n"
                         "score: direction match +8, opposite -8, no-change on directional -2, SAME stable +3, SAME noise -10\n"
                         "confidence = score / best possible score for labeled events\n"
                         "test_queue=%zu (confidence>=55%%, score>=8, near-duplicates collapsed)\n\n",
                         g_focus_count, g_detail_events,
                         g_detail_up, g_detail_down, g_detail_same,
                         g_test_queue_count);
        if (n > 0) write(fd, line, (size_t)n);
    }

    for (size_t i = 0; i < heap_count; i++) {
        RankItem *r = &heap[i];
        size_t base = (size_t)r->page_index * TRACE_PAGE_SIZE;
        const uint8_t *ptr = g_focus_prev + base + r->offset;
        uint64_t address = g_focus_address[r->page_index] + r->offset;
        char value[80];

        format_value(value, sizeof(value), (TraceType)r->type, ptr);

        int n = snprintf(line, sizeof(line),
                         "%03zu score=%d conf=%d%% type=%s addr=0x%016llX value=%s page=%u off=0x%03X\n",
                         i + 1,
                         (int)r->score,
                         item_confidence(r),
                         type_name((TraceType)r->type),
                         (unsigned long long)address,
                         value,
                         (unsigned)r->page_index,
                         (unsigned)r->offset);
        if (n > 0) write(fd, line, (size_t)n);
    }

    close(fd);

    if (heap_count > 0) {
        RankItem *top = &heap[0];
        uint64_t address = g_focus_address[top->page_index] + top->offset;

        notify_status("[CareerTrace] TOP: score=%d conf=%d%% %s 0x%llX | fila teste=%zu.",
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

    for (size_t p = 0; p < g_focus_count; p++) {
        uint8_t *prev = g_focus_prev + p * TRACE_PAGE_SIZE;

        if (read_process(g_focus_address[p], g_chunk, TRACE_PAGE_SIZE) != 0) {
            pages_failed++;
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
            }

            if (off + 8 <= TRACE_PAGE_SIZE) {
                rel = relation_i64(prev, g_chunk, off);
                score_relation(&g_detail_score[TRACE_I64][idx], rel, label);

                rel = relation_f64(prev, g_chunk, off, &valid);
                if (valid)
                    score_relation(&g_detail_score[TRACE_F64][idx], rel, label);
            }
        }

        memcpy(prev, g_chunk, TRACE_PAGE_SIZE);
        sceKernelUsleep(250);
    }

    g_detail_events++;
    if (label == TRACE_LABEL_UP) g_detail_up++;
    else if (label == TRACE_LABEL_DOWN) g_detail_down++;
    else g_detail_same++;

    append_event_line("DETAIL %u %s read=%zu fail=%zu focused=%zu U=%u D=%u S=%u",
                      g_detail_events, label_name(label),
                      pages_read, pages_failed, g_focus_count,
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

static void restore_active_test(void)
{
    if (!g_test_active)
        return;

    if (write_process(g_test_active_address,
                      &g_test_original_raw,
                      g_test_active_size) == 0) {
        append_test_line("RESTORE type=%s addr=0x%016llX size=%zu",
                         type_name(g_test_active_type),
                         (unsigned long long)g_test_active_address,
                         g_test_active_size);
    } else {
        append_test_line("RESTORE_FAIL type=%s addr=0x%016llX size=%zu",
                         type_name(g_test_active_type),
                         (unsigned long long)g_test_active_address,
                         g_test_active_size);
    }

    g_test_active = false;
    g_test_active_address = 0;
    g_test_active_size = 0;
    g_test_original_raw = 0;
}

static bool make_test_value(TraceType type, uint64_t original,
                            uint64_t *test_out, char *before,
                            size_t before_size, char *after,
                            size_t after_size)
{
    uint64_t test = original;

    if (type == TRACE_U8) {
        uint8_t a = (uint8_t)original;
        uint8_t b = a <= 247 ? (uint8_t)(a + 8) : (uint8_t)(a - 8);
        test = b;
        snprintf(before, before_size, "%u", (unsigned)a);
        snprintf(after, after_size, "%u", (unsigned)b);
    } else if (type == TRACE_U16) {
        uint16_t a = (uint16_t)original;
        uint16_t b = a <= 65503 ? (uint16_t)(a + 32) : (uint16_t)(a - 32);
        test = b;
        snprintf(before, before_size, "%u", (unsigned)a);
        snprintf(after, after_size, "%u", (unsigned)b);
    } else if (type == TRACE_I16) {
        int16_t a;
        memcpy(&a, &original, sizeof(a));
        int16_t b = a <= 32735 ? (int16_t)(a + 32) : (int16_t)(a - 32);
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%d", (int)a);
        snprintf(after, after_size, "%d", (int)b);
    } else if (type == TRACE_U32) {
        uint32_t a;
        memcpy(&a, &original, sizeof(a));
        uint32_t b = a <= 0xFFFFFFDFu ? a + 32u : a - 32u;
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%u", (unsigned)a);
        snprintf(after, after_size, "%u", (unsigned)b);
    } else if (type == TRACE_I32) {
        int32_t a;
        memcpy(&a, &original, sizeof(a));
        int32_t b = a <= 2147483615 ? a + 32 : a - 32;
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%d", a);
        snprintf(after, after_size, "%d", b);
    } else if (type == TRACE_I64) {
        int64_t a;
        memcpy(&a, &original, sizeof(a));
        int64_t b = a <= 9223372036854775743LL ? a + 64 : a - 64;
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
        float delta = aa * 0.10f;
        if (delta < 0.05f) delta = 0.05f;
        if (delta > 5.0f) delta = 5.0f;
        b = a + delta;
        memcpy(&test, &b, sizeof(b));
        snprintf(before, before_size, "%.8g", (double)a);
        snprintf(after, after_size, "%.8g", (double)b);
    } else if (type == TRACE_F64) {
        double a, b;
        if (!f64_finite(original))
            return false;
        memcpy(&a, &original, sizeof(a));

        double aa = a < 0.0 ? -a : a;
        double delta = aa * 0.10;
        if (delta < 0.05) delta = 0.05;
        if (delta > 5.0) delta = 5.0;
        b = a + delta;
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
        restore_active_test();
        g_test_armed = false;
        g_test_queue_cursor = 0;
        notify_status("[CareerTrace] TESTE desarmado; valor restaurado.");
        return;
    }

    if (g_phase != TRACE_PHASE_DETAIL || !detail_evidence_ready()) {
        notify_status("[CareerTrace] TESTE pede detalhe com 2 UP + 2 DOWN + 1 SAME. Atual U%u D%u S%u.",
                      g_detail_up, g_detail_down, g_detail_same);
        return;
    }

    dump_detail_ranking();

    if (g_test_queue_count == 0) {
        notify_status("[CareerTrace] Nenhum candidato com confianca >=55%% ainda. Colete mais eventos.");
        return;
    }

    truncate_file(TRACE_TEST);
    append_test_line("CareerTrace v2100 test queue=%zu", g_test_queue_count);

    g_test_armed = true;
    g_test_queue_cursor = 0;

    RankItem *top = &g_top_results[g_test_queue[0]];
    uint64_t address = g_focus_address[top->page_index] + top->offset;

    notify_status("[CareerTrace] TESTE ARMADO: %zu candidatos. TOP conf=%d%% %s 0x%llX. R1+ESQ testa 1.",
                  g_test_queue_count,
                  item_confidence(top),
                  type_name((TraceType)top->type),
                  (unsigned long long)address);
}

static void test_next_ranked(void)
{
    OrbisKernelVirtualQueryInfo info;
    uint64_t raw = 0;
    uint64_t test = 0;
    char before[64];
    char after[64];

    if (!g_test_armed) {
        notify_status("[CareerTrace] Primeiro arme TESTE com L1+R1.");
        return;
    }

    restore_active_test();

    if (g_test_queue_count == 0)
        return;

    if (g_test_queue_cursor >= g_test_queue_count)
        g_test_queue_cursor = 0;

    size_t rank_index = g_test_queue[g_test_queue_cursor];
    RankItem *r = &g_top_results[rank_index];
    TraceType type = (TraceType)r->type;
    uint64_t address = g_focus_address[r->page_index] + r->offset;
    size_t size = type_size(type);

    g_test_queue_cursor++;

    if (sceKernelVirtualQuery((void *)(uintptr_t)address, 0,
                              &info, sizeof(info)) < 0 ||
        (info.prot & CPU_READ) == 0 ||
        (info.prot & CPU_WRITE) == 0) {
        append_test_line("SKIP rank=%zu addr=0x%016llX INVALID",
                         rank_index + 1, (unsigned long long)address);
        notify_status("[CareerTrace] TOP %zu invalido agora; R1+ESQ proximo.",
                      rank_index + 1);
        return;
    }

    if (read_process(address, &raw, size) != 0) {
        notify_status("[CareerTrace] Falha lendo TOP %zu.", rank_index + 1);
        return;
    }

    if (!make_test_value(type, raw, &test,
                         before, sizeof(before),
                         after, sizeof(after))) {
        notify_status("[CareerTrace] TOP %zu tipo %s nao seguro para teste.",
                      rank_index + 1, type_name(type));
        return;
    }

    if (write_process(address, &test, size) != 0) {
        notify_status("[CareerTrace] Falha escrevendo TOP %zu.", rank_index + 1);
        return;
    }

    g_test_active = true;
    g_test_active_address = address;
    g_test_original_raw = raw;
    g_test_active_size = size;
    g_test_active_type = type;

    append_test_line("ACTIVE queue=%zu/%zu rank=%zu score=%d conf=%d%% type=%s addr=0x%016llX %s -> %s",
                     g_test_queue_cursor,
                     g_test_queue_count,
                     rank_index + 1,
                     (int)r->score,
                     item_confidence(r),
                     type_name(type),
                     (unsigned long long)address,
                     before, after);

    notify_status("[CareerTrace] TEST %zu/%zu | rank %zu conf=%d%% %s 0x%llX | %s -> %s. R1+DIR restaura.",
                  g_test_queue_cursor,
                  g_test_queue_count,
                  rank_index + 1,
                  item_confidence(r),
                  type_name(type),
                  (unsigned long long)address,
                  before, after);
}

static void manual_restore_test(void)
{
    if (!g_test_active) {
        notify_status("[CareerTrace] Nenhum teste ativo.");
        return;
    }

    restore_active_test();
    notify_status("[CareerTrace] Valor do teste restaurado. R1+ESQ testa o proximo.");
}

static void execute_action(DiagAction action)
{
    g_busy = 1;

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

    g_page_count = 0;
    g_focus_count = 0;
    g_phase = TRACE_PHASE_IDLE;
    g_test_armed = false;
    g_test_active = false;

    ensure_output_dir();
    truncate_file(DIAG_LOG);

    append_log("=== CareerTrace v2100 ===");
    append_log("read-only correlation search until explicit TEST mode");
    append_log("two-stage: full-RAM page fingerprint -> exact multi-type ranking");
    append_log("types=u8,u16,i16,u32,i32,i64,f32,f64; unaligned exact scan");
    append_log("SAME controls penalize background noise; candidates are scored, not destructively deleted");

    return scePthreadCreate(&g_worker_thread, NULL, worker_main, NULL,
                            "career_trace_worker");
}

void diag_stop_worker(void)
{
    if (!g_worker_running)
        return;

    g_worker_running = 0;
    scePthreadJoin(g_worker_thread, NULL);
    restore_active_test();
}

void diag_request(DiagAction action)
{
    if (!g_worker_running)
        return;
    if (g_busy)
        return;
    if (g_pending_action == DIAG_ACTION_NONE)
        g_pending_action = (int)action;
}
