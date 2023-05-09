#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <vx_print.h>
#include "common.h"
#include "timeit.h"

#ifndef SIZE
#define SIZE 4
#endif

void kernel_body(int task_id, kernel_arg_t* arg) {
    //vx_printf("current_warp is : %d\n", vx_warp_id());
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("nop");
    __asm__ __volatile__("kernel_end: .global kernel_end":);
}

void main() {
//    vx_printf("%d cores\n", vx_num_cores());
//    vx_printf("%d warps\n", vx_num_warps());
//    vx_printf("%d threads\n", vx_num_threads());
    extern uint8_t kernel_body_last_intsr __asm__("kernel_end");
    set_time_it(kernel_body, &kernel_body_last_intsr);
	kernel_arg_t* arg = (kernel_arg_t*)KERNEL_ARG_DEV_MEM_ADDR;
	vx_spawn_tasks(SIZE, (vx_spawn_tasks_cb)kernel_body, arg);
    stop_timeit();
    uint64_t cycles = read_time_it();
    vx_printf("time : " "%llu\n", cycles);
}