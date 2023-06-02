#pragma once
#include <inttypes.h>

void set_time_it(void* start, void* end);

void stop_timeit();

uint64_t read_time_it();