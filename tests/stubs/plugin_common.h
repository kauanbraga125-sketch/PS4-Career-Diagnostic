#pragma once
#include <stdint.h>
#include <stddef.h>
#define GOLDHEN_PATH "/unused"
#define TEX_ICON_SYSTEM "test"
struct proc_rw { uint64_t address; void *data; size_t length; int write_flags; };
int sys_sdk_proc_rw(struct proc_rw *rw);
void NotifyStatic(const char *icon, const char *text);
