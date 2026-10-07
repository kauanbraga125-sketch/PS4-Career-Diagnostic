#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

#include "plugin_common.h"

attr_public const char *g_pluginName = "career_diag_test";
attr_public const char *g_pluginDesc = "Minimal GoldHEN plugin load test";
attr_public const char *g_pluginAuth = "Kauan project";
attr_public uint32_t g_pluginVersion = 0x00000100;

int32_t attr_public plugin_load(int32_t argc, const char* argv[])
{
    (void)argc;
    (void)argv;
    final_printf("[GoldHEN] career_diag_test Plugin Started.\n");
    NotifyStatic(TEX_ICON_SYSTEM, "[CareerDiag TEST] PRX carregou corretamente!");
    return 0;
}

int32_t attr_public plugin_unload(int32_t argc, const char* argv[])
{
    (void)argc;
    (void)argv;
    final_printf("[GoldHEN] career_diag_test Plugin Ended.\n");
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
