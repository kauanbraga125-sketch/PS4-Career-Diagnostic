#include "plugin_common.h"
#include "scanner.h"

#include <orbis/Pad.h>
#include <orbis/libkernel.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <Patcher.h>
#include <Syscall.h>

attr_public const char *g_pluginName = "career_diag";
attr_public const char *g_pluginDesc = "On-console player-career memory diagnostic";
attr_public const char *g_pluginAuth = "Kauan project";
attr_public uint32_t g_pluginVersion = 0x00001040;

HOOK_INIT(scePadRead);

static Patcher *g_scePadReadExt_patcher = NULL;
static uint32_t g_previous_buttons = 0;
static bool g_learning_active = true;

static bool chord_just_pressed(uint32_t buttons, uint32_t modifier, uint32_t button)
{
    const uint32_t chord = modifier | button;
    const bool now_active = (buttons & chord) == chord;
    const bool was_active = (g_previous_buttons & chord) == chord;
    return now_active && !was_active;
}

static void handle_shortcuts(uint32_t buttons)
{
    /*
     * MASTER100 v1040:
     * R2 + LEFT = on first press, validate the compiled master pool in the current
     *             career state and test the first safe batch of up to 100.
     *             Next presses restore the previous batch and test the next 100.
     * L1 + R1   = refine the active batch (100 -> 10 -> 1).
     *
     * Known crash/freeze suspect addresses were compiled out.
     */
    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_L1, ORBIS_PAD_BUTTON_R1)) {
        diag_request(DIAG_ACTION_GROUP_REFINE);
        return;
    }

    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_R2, ORBIS_PAD_BUTTON_LEFT)) {
        diag_request(DIAG_ACTION_BATCH_TEST_ALL);
        return;
    }
}

int32_t scePadRead_hook(int32_t handle, OrbisPadData *data, int32_t count)
{
    int32_t result = scePadReadExt(handle, data, count);

    if (result <= 0 || data == NULL)
        return result;

    for (int32_t i = 0; i < result; i++) {
        handle_shortcuts(data[i].buttons);
        g_previous_buttons = data[i].buttons;
    }

    return result;
}

s32 attr_public plugin_load(s32 argc, const char *argv[])
{
    (void)argc;
    (void)argv;

    final_printf("[CareerDiag] plugin_load\n");

    {
        char module[256];
        int handle = 0;
        snprintf(module, sizeof(module), "/%s/common/lib/%s",
                 sceKernelGetFsSandboxRandomWord(), "libScePad.sprx");
        sys_dynlib_load_prx(module, &handle);
    }

    g_scePadReadExt_patcher = (Patcher *)malloc(sizeof(Patcher));
    if (g_scePadReadExt_patcher == NULL) {
        NotifyStatic(TEX_ICON_SYSTEM, "[CareerDiag] Falha alocando pad patcher.");
        return 0;
    }

    Patcher_Construct(g_scePadReadExt_patcher);
    {
        uint8_t xor_ecx_ecx[5] = {0x31, 0xC9, 0x90, 0x90, 0x90};
        Patcher_Install_Patch(
            g_scePadReadExt_patcher,
            (uint64_t)scePadReadExt,
            xor_ecx_ecx,
            sizeof(xor_ecx_ecx)
        );
    }

    if (diag_start_worker() != 0) {
        Patcher_Destroy(g_scePadReadExt_patcher);
        free(g_scePadReadExt_patcher);
        g_scePadReadExt_patcher = NULL;
        NotifyStatic(TEX_ICON_SYSTEM, "[CareerDiag] Falha ao iniciar worker.");
        return 0;
    }

    HOOK32(scePadRead);

    NotifyStatic(
        TEX_ICON_SYSTEM,
        "[CareerDiag MASTER100 v1040] entre na carreira | R2+ESQ carrega e testa 100 | L1+R1 isola."
    );

    return 0;
}

s32 attr_public plugin_unload(s32 argc, const char *argv[])
{
    (void)argc;
    (void)argv;

    UNHOOK(scePadRead);
    diag_stop_worker();

    if (g_scePadReadExt_patcher != NULL) {
        Patcher_Destroy(g_scePadReadExt_patcher);
        free(g_scePadReadExt_patcher);
        g_scePadReadExt_patcher = NULL;
    }

    final_printf("[CareerDiag] plugin_unload\n");
    return 0;
}

s32 attr_module_hidden module_start(s64 argc, const void *args)
{
    (void)argc;
    (void)args;
    return 0;
}

s32 attr_module_hidden module_stop(s64 argc, const void *args)
{
    (void)argc;
    (void)args;
    return 0;
}
