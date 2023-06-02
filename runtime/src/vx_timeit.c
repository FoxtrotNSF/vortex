#include <vx_timeit.h>

void set_time_it(void* start, void* end) {
    __asm__ ("csrw 0xB1E, %0"::"r"(start));
    __asm__ ("csrw 0xB9E, %0"::"r"(end));
}

void stop_timeit(){
    __asm__ __volatile__ ("csrw 0xB9E, zero");
}

uint64_t read_time_it(){
    uint32_t low, high;
    // Inline assembly to read the CSR at addresses 0xB1D and 0xB9D
    __asm__ __volatile__ ("csrr %0, 0xB1D" : "=r"(low));
    __asm__ __volatile__ ("csrr %0, 0xB9D" : "=r"(high));
    return (((uint64_t)high) << 32) | low;
}