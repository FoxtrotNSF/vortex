#include <vx_timeit.h>
#include <VX_config.h>

void set_time_it(void* start, void* end) {
    __asm__ ("csrw %0, %1"::"i"(CSR_TIMEIT_RANGE_L),"r"(start));
    __asm__ ("csrw %0, %1"::"i"(CSR_TIMEIT_RANGE_H),"r"(end));
}

void stop_timeit(){
    __asm__ __volatile__ ("csrw %0, zero"::"i"(CSR_TIMEIT_RANGE_L));
}

uint64_t read_start_time(){
    uint32_t low, high;
    __asm__ __volatile__ ("csrr %0, %1" : "=r"(low)  : "i"(CSR_TIMEIT_GLOBAL_CYCLES_START_L));
    __asm__ __volatile__ ("csrr %0, %1" : "=r"(high) : "i"(CSR_TIMEIT_GLOBAL_CYCLES_START_H));
    return (((uint64_t)high) << 32) | low;
}

uint64_t read_end_time(){
    uint32_t low, high;
    __asm__ __volatile__ ("csrr %0, %1" : "=r"(low)  : "i"(CSR_TIMEIT_GLOBAL_CYCLES_END_L));
    __asm__ __volatile__ ("csrr %0, %1" : "=r"(high) : "i"(CSR_TIMEIT_GLOBAL_CYCLES_END_H));
    return (((uint64_t)high) << 32) | low;
}

uint64_t read_time_it(){
    return read_end_time() - read_start_time();
}