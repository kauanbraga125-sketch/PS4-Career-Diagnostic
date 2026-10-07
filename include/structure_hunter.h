#pragma once

#include <stddef.h>

int structure_hunter_scan(void);
size_t structure_hunter_candidate_count(void);
void structure_hunter_format_status(char *out, size_t capacity);
