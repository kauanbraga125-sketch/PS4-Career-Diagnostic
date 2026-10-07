#pragma once

#include <stdint.h>

typedef enum DiagAction {
    DIAG_ACTION_NONE = 0,
    DIAG_ACTION_SNAPSHOT,
    DIAG_ACTION_INCREASED,
    DIAG_ACTION_DECREASED,
    DIAG_ACTION_UNCHANGED,
    DIAG_ACTION_DUMP,
    DIAG_ACTION_TEST_ARM,
    DIAG_ACTION_TEST_NEXT,
    DIAG_ACTION_TEST_RESTORE,
    DIAG_ACTION_STATUS,
    DIAG_ACTION_STRUCTURE_HUNT
} DiagAction;

int diag_start_worker(void);
void diag_stop_worker(void);
void diag_request(DiagAction action);
