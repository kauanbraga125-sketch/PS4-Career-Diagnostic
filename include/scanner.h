#pragma once

#include <stdint.h>

typedef enum DiagAction {
    DIAG_ACTION_NONE = 0,
    DIAG_ACTION_SNAPSHOT,
    DIAG_ACTION_DECREASED,
    DIAG_ACTION_INCREASED,
    DIAG_ACTION_CHANGED,
    DIAG_ACTION_UNCHANGED,
    DIAG_ACTION_DUMP,
    DIAG_ACTION_RESET,
    DIAG_ACTION_MODE_INT32,
    DIAG_ACTION_MODE_FLOAT,
    DIAG_ACTION_AUTO_TOGGLE,
    DIAG_ACTION_TEST_PLUS_ONE,
    DIAG_ACTION_TEST_NEXT,
    DIAG_ACTION_MEASURE_DOWN,
    DIAG_ACTION_MEASURE_UP,
    DIAG_ACTION_FREEZE_TOGGLE
} DiagAction;

int diag_start_worker(void);
void diag_stop_worker(void);
void diag_request(DiagAction action);
