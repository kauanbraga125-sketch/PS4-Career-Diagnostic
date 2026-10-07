#pragma once

#include <Common.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#define GOLDHEN_PATH "/data/GoldHEN"

#define u8  uint8_t
#define u16 uint16_t
#define u32 uint32_t
#define u64 uint64_t
#define s8  int8_t
#define s16 int16_t
#define s32 int32_t
#define s64 int64_t

#define TEX_ICON_SYSTEM "cxml://psnotification/tex_icon_system"

#define attr_module_hidden __attribute__((weak)) __attribute__((visibility("hidden")))
#define attr_public __attribute__((visibility("default")))

#define final_printf(a, args...) klog("(%s:%d) " a, __FILE__, __LINE__, ##args)

void NotifyStatic(const char *IconUri, const char *text);
void Notify(const char *IconUri, const char *fmt, ...);
