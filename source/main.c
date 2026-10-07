#include "plugin_common.h"
#include "scanner.h"

#include <orbis/Pad.h>
#include <orbis/libkernel.h>
#include <stdint.h>

attr_public const char *g_pluginName = "career_diag";
attr_public const char *g_pluginDesc = "On-console player-career memory diagnostic";
attr_public const char *g_pluginAuth = "Kauan project";
attr_public uint32_t g_pluginVersion = 0x00000200;

HOOK_INIT(scePadRead);

static uint32_t g_previous_buttons = 0;

static uint32_t newly_pressed(uint32_t buttons)
{
    return buttons & ~g_previous_buttons;
}

static void handle_shortcuts(uint32_t buttons)
{
    const uint32_t gate = ORBIS_PAD_BUTTON_L3 | ORBIS_PAD_BUTTON_R3;
    uint32_t pressed = newly_pressed(buttons);

    if ((buttons & gate) != gate)
        return;

    if (pressed & ORBIS_PAD_BUTTON_SQUARE)
        diag_request(DIAG_ACTION_SNAPSHOT);

    if (pressed & ORBIS_PAD_BUTTON_DOWN)
        diag_request(DIAG_ACTION_DECREASED);

    if (pressed & ORBIS_PAD_BUTTON_UP)
        diag_request(DIAG_ACTION_INCREASED);

    if (pressed & ORBIS_PAD_BUTTON_TRIANGLE)
        diag_request(DIAG_ACTION_CHANGED);

    if (pressed & ORBIS_PAD_BUTTON_CIRCLE)
        diag_request(DIAG_ACTION_UNCHANGED);

    if (pressed & ORBIS_PAD_BUTTON_OPTIONS)
        diag_request(DIAG_ACTION_DUMP);

    if (pressed & ORBIS_PAD_BUTTON_CROSS)
        diag_request(DIAG_ACTION_RESET);

    if (pressed & ORBIS_PAD_BUTTON_LEFT)
        diag_request(DIAG_ACTION_MODE_INT32);

    if (pressed & ORBIS_PAD_BUTTON_RIGHT)
        diag_request(DIAG_ACTION_MODE_FLOAT);
}

int32_t scePadRead_hook(int32_t handle, OrbisPadData *data, int32_t count)
{
    /*
     * Do not call HOOK_CONTINUE(scePadRead) here.
     * The official GoldHEN gamepad_helper uses scePadReadExt() from inside
     * the scePadRead hook, avoiding recursive/invalid continuation paths.
     */
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

    if (diag_start_worker() != 0) {
        NotifyStatic(TEX_ICON_SYSTEM, "[CareerDiag] Falha ao iniciar worker.");
        return 0;
    }

    HOOK32(scePadRead);

    NotifyStatic(
        TEX_ICON_SYSTEM,
        "[CareerDiag] Carregado. L3+R3+QUADRADO = snapshot."
    );

    return 0;
}

s32 attr_public plugin_unload(s32 argc, const char *argv[])
{
    (void)argc;
    (void)argv;

    UNHOOK(scePadRead);
    diag_stop_worker();
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
