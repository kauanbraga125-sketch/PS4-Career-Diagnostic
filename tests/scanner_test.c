/* Exercise the actual scanner with a deterministic, private memory model. */
#define DIAG_DIR "build/test-output"
#include "../source/scanner.c"
#include <assert.h>

#define BASE 0x10000000ULL
static uint8_t memory[TRACE_PAGE_SIZE * 2];
static uint64_t now_us;
static int writes, fail_reads, fail_writes, fake_prot;
static uint64_t failed_page;
static char last_notice[600];

int sys_sdk_proc_rw(struct proc_rw *rw)
{
    if (rw->address < BASE || rw->length > sizeof(memory) ||
        rw->address - BASE > sizeof(memory) - rw->length) return -1;
    if (rw->write_flags) {
        if (fail_writes) return -1;
        writes++;
        memcpy(memory + (rw->address - BASE), rw->data, rw->length);
    } else {
        if (fail_reads || (failed_page && rw->address == failed_page)) return -1;
        memcpy(rw->data, memory + (rw->address - BASE), rw->length);
    }
    return 0;
}

int sceKernelVirtualQuery(const void *address, int flags,
                          OrbisKernelVirtualQueryInfo *info, size_t size)
{
    (void)size;
    uintptr_t addr = (uintptr_t)address;
    if (addr >= BASE + sizeof(memory) || (!flags && addr < BASE)) return -1;
    memset(info, 0, sizeof(*info));
    info->start_addr = (void *)(uintptr_t)BASE;
    info->end_addr = (void *)(uintptr_t)(BASE + sizeof(memory));
    info->prot = fake_prot;
    return 0;
}
int sceKernelUsleep(unsigned us) { now_us += us; return 0; }
uint64_t sceKernelGetProcessTime(void) { return now_us; }
void NotifyStatic(const char *icon, const char *text)
{
    (void)icon;
    snprintf(last_notice, sizeof(last_notice), "%s", text);
}
int scePthreadCreate(OrbisPthread *t, const void *a, void *(*f)(void *), void *arg, const char *n)
{ (void)t; (void)a; (void)f; (void)arg; (void)n; return 0; }
int scePthreadJoin(OrbisPthread t, void **p) { (void)t; (void)p; return 0; }
void scePthreadExit(void *p) { (void)p; }

static void clean_state(void)
{
    clear_active_test();
    reset_trace_state();
    memset(memory, 0, sizeof(memory));
    writes = fail_reads = fail_writes = 0;
    failed_page = 0;
    fake_prot = CPU_READ | CPU_WRITE;
    now_us = 100;
    __atomic_store_n(&g_worker_running, 1, __ATOMIC_RELEASE);
    __atomic_store_n(&g_busy, 0, __ATOMIC_RELEASE);
    __atomic_store_n(&g_pending_action, DIAG_ACTION_NONE, __ATOMIC_RELEASE);
}

static void prepare_detail(void)
{
    clean_state();
    g_phase = TRACE_PHASE_DETAIL;
    g_focus_count = 1;
    g_focus_address[0] = BASE;
    g_focus_valid[0] = true;
    memory[16] = 50;
    memcpy(g_focus_prev, memory, TRACE_PAGE_SIZE);
    g_focus_evidence[0] = (TraceEvidence){2, 2, 1};
    g_detail_up = 2; g_detail_down = 2; g_detail_same = 1; g_detail_events = 5;
    g_detail_score[TRACE_U8][16] = 35;
}

static void test_organized_read_only_flow(void)
{
    clean_state();
    memory[16] = memory[20] = 50;
    initial_page_snapshot();
    assert(g_phase == TRACE_PHASE_PAGES && g_page_count == 2);
    TraceLabel labels[] = {TRACE_LABEL_UP, TRACE_LABEL_UP, TRACE_LABEL_DOWN,
                           TRACE_LABEL_DOWN, TRACE_LABEL_SAME};
    for (size_t i = 0; i < 5; i++) {
        if (i < 2) { memory[16]++; memory[20]++; }
        else if (i < 4) { memory[16]--; memory[20]--; }
        record_event(labels[i]);
    }
    assert(page_evidence_ready());
    assert(capture_focus_pages());
    assert(g_focus_count == 1 && g_phase == TRACE_PHASE_DETAIL);
    for (size_t i = 0; i < 5; i++) {
        if (i < 2) { memory[16]++; memory[20]++; }
        else if (i < 4) { memory[16]--; memory[20]--; }
        record_event(labels[i]);
    }
    assert(writes == 0 && detail_evidence_ready() && g_test_queue_count > 0);
    assert(g_detail_score[TRACE_U8][16] == 35);
    assert(g_detail_score[TRACE_U8][20] == 35);
    char status[512]; format_status(status, sizeof(status));
    assert(strstr(status, "FASE 2") && strstr(status, "faltam: 0"));
    FILE *f = fopen(TRACE_RANK, "rb"); assert(f);
    char text[2000]; size_t count = fread(text, 1, sizeof(text)-1, f); text[count] = 0; fclose(f);
    assert(strstr(text, "NOT probability") && strstr(text, "ready=1"));
}

static void test_score_does_not_saturate_after_15_events(void)
{
    prepare_detail();
    int16_t score = 0;
    for (int i = 0; i < 40; i++) score_relation(&score, 1, TRACE_LABEL_UP);
    assert(score == 320);
    g_focus_evidence[0] = (TraceEvidence){40, 0, 0};
    RankItem item = {.score=score, .type=TRACE_U8, .page_index=0, .offset=16};
    assert(item_confidence(&item) == 100);
    score_relation(&score, -1, TRACE_LABEL_UP);
    assert(score == 312);
}

static void test_neighbors_and_types_are_not_lost(void)
{
    prepare_detail();
    g_top_results[0] = (RankItem){.score=35, .type=TRACE_U8, .offset=16};
    g_top_results[1] = (RankItem){.score=35, .type=TRACE_U8, .offset=17};
    g_top_results[2] = (RankItem){.score=35, .type=TRACE_U16, .offset=16};
    g_top_results[3] = (RankItem){.score=35, .type=TRACE_I16, .offset=16};
    g_top_results[4] = (RankItem){.score=35, .type=TRACE_F32, .offset=16};
    g_top_results[5] = (RankItem){.score=35, .type=TRACE_I32, .offset=16};
    g_top_count = 6;
    rebuild_test_queue();
    assert(g_test_queue_count == 5);
    g_focus_evidence[0].down = 0;
    rebuild_test_queue();
    assert(g_test_queue_count == 0);
}

static void test_read_gap_does_not_make_a_false_match(void)
{
    prepare_detail();
    failed_page = BASE;
    detail_event(TRACE_LABEL_UP);
    assert(!g_focus_valid[0] && g_detail_score[TRACE_U8][16] == 0);
    assert(g_focus_evidence[0].up == 0 && g_top_count == 0);
    failed_page = 0;
    memory[16] = 90;
    detail_event(TRACE_LABEL_UP);
    assert(g_focus_valid[0] && g_detail_score[TRACE_U8][16] == 0);
    assert(g_focus_evidence[0].up == 0); /* Rebase, not +8 for a missed interval. */
    memory[16] = 91;
    detail_event(TRACE_LABEL_UP);
    assert(g_detail_score[TRACE_U8][16] == 8 && g_focus_evidence[0].up == 1);
}

static void arm_and_test(void)
{
    prepare_detail();
    toggle_test_arm();
    assert(g_test_armed && !g_test_active && writes == 0);
    test_next_ranked();
    assert(g_test_active && memory[16] == 51 && writes == 1);
}

static void test_restore_verification_and_game_changes(void)
{
    arm_and_test();
    assert(restore_active_test() == RESTORE_OK && memory[16] == 50);
    arm_and_test();
    memory[16] = 70; /* Game writes a new value while the test is active. */
    assert(restore_active_test() == RESTORE_GAME_CHANGED);
    assert(memory[16] == 70 && writes == 1 && !g_test_active);
    arm_and_test();
    fail_reads = 1;
    assert(restore_active_test() == RESTORE_RETRY && g_test_active);
    test_next_ranked();
    assert(writes == 1 && g_test_active); /* No next write while restore is pending. */
    fail_reads = 0;
    assert(restore_active_test() == RESTORE_OK && !g_test_active);
    arm_and_test();
    fail_writes = 1;
    assert(restore_active_test() == RESTORE_RETRY && g_test_active);
    fail_writes = 0;
    assert(restore_active_test() == RESTORE_OK);
}

static void test_stale_candidates_and_test_timeout(void)
{
    prepare_detail(); toggle_test_arm(); memory[16] = 80;
    test_next_ranked();
    assert(!g_test_active && memory[16] == 80 && writes == 0);
    arm_and_test();
    size_t cursor = g_test_queue_cursor;
    dump_or_focus();
    assert(g_test_queue_cursor == cursor); /* Saving cannot restart a live queue. */
    now_us = g_test_deadline;
    expire_active_test();
    assert(!g_test_active && memory[16] == 50);
    toggle_test_arm();
    assert(!g_test_armed && g_detail_events == 0 && g_top_count == 0);
    assert(!g_detail_needs_refresh && g_detail_score[TRACE_U8][16] == 0);
}

static void test_failed_write_status_bounds_and_queue(void)
{
    prepare_detail(); toggle_test_arm(); fail_writes = 1;
    test_next_ranked();
    assert(!g_test_active && memory[16] == 50 && writes == 0);
    OrbisKernelVirtualQueryInfo info;
    assert(!query_test_region(BASE + sizeof(memory) - 1, 4, &info));
    fake_prot |= CPU_EXEC;
    assert(!query_test_region(BASE, 1, &info));
    uint64_t out; char before[80], after[80];
    assert(!make_test_value(TRACE_I64, 0x100000000ULL, &out, before, sizeof(before), after, sizeof(after)));
    __atomic_store_n(&g_busy, 1, __ATOMIC_RELEASE);
    diag_request(DIAG_ACTION_TEST_RESTORE);
    assert(__atomic_load_n(&g_pending_action, __ATOMIC_ACQUIRE) == DIAG_ACTION_TEST_RESTORE);
    diag_request(DIAG_ACTION_INCREASED);
    assert(__atomic_load_n(&g_pending_action, __ATOMIC_ACQUIRE) == DIAG_ACTION_TEST_RESTORE);
}

int main(void)
{
    mkdir("build", 0700); ensure_output_dir();
    test_organized_read_only_flow();
    test_score_does_not_saturate_after_15_events();
    test_neighbors_and_types_are_not_lost();
    test_read_gap_does_not_make_a_false_match();
    test_restore_verification_and_game_changes();
    test_stale_candidates_and_test_timeout();
    test_failed_write_status_bounds_and_queue();
    puts("PASS: 7 scanner regression scenarios (actual scanner, mocked PS4 memory).");
    return 0;
}
