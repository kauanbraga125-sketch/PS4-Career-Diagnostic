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
attr_public const char *g_pluginDesc = "Read-only player-career correlation tracer + ranked single-candidate test";
attr_public const char *g_pluginAuth = "Kauan project";
attr_public uint32_t g_pluginVersion = 0x00002100;

HOOK_INIT(scePadRead);

static Patcher *g_scePadReadExt_patcher = NULL;
static uint32_t g_previous_buttons = 0;

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
     * CareerTrace v2100
     *
     * R1 + CIMA     = baseline completo (reinicia a busca)
     * R2 + CIMA     = titularidade SUBIU
     * R2 + BAIXO    = titularidade DESCEU
     * R2 + DIREITA  = controle: titularidade NAO mudou
     * R2 + ESQUERDA = FOCUS depois de 2 UP + 2 DOWN + 1 SAME;
     *                 na fase detalhada salva/atualiza o ranking
     *
     * Depois do ranking detalhado:
     * L1 + R1       = arma/desarma o teste individual dos melhores
     * R1 + ESQUERDA = restaura o anterior e testa o proximo candidato
     * R1 + DIREITA  = restaura imediatamente o candidato ativo
     *
     * Ate o usuario armar TESTE, o tracer e somente leitura.
     */
    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_L1, ORBIS_PAD_BUTTON_R1)) {
        diag_request(DIAG_ACTION_TEST_ARM);
        return;
    }

    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_R1, ORBIS_PAD_BUTTON_LEFT)) {
        diag_request(DIAG_ACTION_TEST_NEXT);
        return;
    }

    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_R1, ORBIS_PAD_BUTTON_RIGHT)) {
        diag_request(DIAG_ACTION_TEST_RESTORE);
        return;
    }

    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_R1, ORBIS_PAD_BUTTON_UP)) {
        diag_request(DIAG_ACTION_SNAPSHOT);
        return;
    }

    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_R2, ORBIS_PAD_BUTTON_UP)) {
        diag_request(DIAG_ACTION_INCREASED);
        return;
    }

    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_R2, ORBIS_PAD_BUTTON_DOWN)) {
        diag_request(DIAG_ACTION_DECREASED);
        return;
    }

    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_R2, ORBIS_PAD_BUTTON_RIGHT)) {
        diag_request(DIAG_ACTION_UNCHANGED);
        return;
    }

    if (chord_just_pressed(buttons, ORBIS_PAD_BUTTON_R2, ORBIS_PAD_BUTTON_LEFT)) {
        diag_request(DIAG_ACTION_DUMP);
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

    final_printf("[CareerTrace] plugin_load\n");

    {
        char module[256];
        int handle = 0;
        snprintf(module, sizeof(module), "/%s/common/lib/%s",
                 sceKernelGetFsSandboxRandomWord(), "libScePad.sprx");
        sys_dynlib_load_prx(module, &handle);
    }

    g_scePadReadExt_patcher = (Patcher *)malloc(sizeof(Patcher));
    if (g_scePadReadExt_patcher == NULL) {
        NotifyStatic(TEX_ICON_SYSTEM, "[CareerTrace] Falha alocando pad patcher.");
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
        NotifyStatic(TEX_ICON_SYSTEM, "[CareerTrace] Falha ao iniciar worker.");
        return 0;
    }

    HOOK32(scePadRead);

    NotifyStatic(
        TEX_ICON_SYSTEM,
        "[CareerTrace v2100] R1+CIMA baseline | R2+CIMA UP | R2+BAIXO DOWN | R2+DIR SAME | R2+ESQ FOCUS."
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

    final_printf("[CareerTrace] plugin_unload\n");
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
