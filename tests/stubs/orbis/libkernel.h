#pragma once
#include <stdint.h>
#include <stddef.h>
typedef uintptr_t OrbisPthread;
typedef struct {
    void *start_addr;
    void *end_addr;
    int prot;
    int isStack;
} OrbisKernelVirtualQueryInfo;
int sceKernelVirtualQuery(const void *, int, OrbisKernelVirtualQueryInfo *, size_t);
int sceKernelUsleep(unsigned);
uint64_t sceKernelGetProcessTime(void);
int scePthreadCreate(OrbisPthread *, const void *, void *(*)(void *), void *, const char *);
int scePthreadJoin(OrbisPthread, void **);
void scePthreadExit(void *);
