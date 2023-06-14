#include <stdint.h>
#include <VX_config.h>
#include "vx_print.h"
#include "vx_timeit.h"
#include "vx_uart.h"
#include "vx_spawn.h"
#include "vx_intrinsics.h"

typedef void (*user_tasks_cb_t)(unsigned);

unsigned num_warps_to_launch;
user_tasks_cb_t tasks_to_launch;

void mesure_user_kernel(context_t * ctx, vx_spawn_kernel_cb kernel_entry, void* arg, void* start, void* end){
    vx_printf("Kernel dims:\n");
    vx_printf("x: %d * %d (+ %d)\n", ctx->num_groups[0], ctx->local_size[0], ctx->global_offset[0]);
    vx_printf("y: %d * %d (+ %d)\n", ctx->num_groups[1], ctx->local_size[1], ctx->global_offset[1]);
    vx_printf("z: %d * %d (+ %d)\n", ctx->num_groups[2], ctx->local_size[2], ctx->global_offset[2]);
    vx_printf("Launching at %X\n", kernel_entry);
    set_time_it(start, end);
    vx_spawn_kernel(ctx, (vx_spawn_kernel_cb)kernel_entry, arg);
    stop_timeit();
    vx_printf("Completed in %llu cycles\n", read_time_it());
    vx_printf("start: %llu\n", read_start_time());
    vx_printf("end: %llu\n", read_end_time());
}

void launch_tasks(){
    vx_tmc(-1); // launch all threads
    tasks_to_launch(num_warps_to_launch);
    vx_tmc(vx_warp_id() == 0); // stop all warps excepted 0
}

void mesure_user_warps(unsigned size, user_tasks_cb_t kernel_entry, void* start, void* end){
    int wid = vx_warp_id();
    int NW = vx_num_warps();
    if(size > NW){
        vx_printf("Impossible to launch more than %d warps", NW);
        return;
    }
    tasks_to_launch = kernel_entry;
    num_warps_to_launch = size;
    set_time_it(start, end);
    vx_printf("Launching %d warps at %X\n", size, kernel_entry);
    vx_wspawn(size, launch_tasks);
    launch_tasks();
    stop_timeit();
    vx_printf("Completed in %llu cycles\n", read_time_it());
    vx_printf("start: %llu\n", read_start_time());
    vx_printf("end: %llu\n", read_end_time());
}


void main() {
    vx_printf("ready\n");
    lab_1:
    vx_printf("\\\n");
    char command = uart_blocking_read();
    switch(command){
        case 'u': // upload
        {
            uint32_t size = uart_blocking_read_unsigned();
            uint32_t addr = uart_blocking_read_unsigned();
            for (uint32_t p = addr; p < addr + size; p++) (*(char *) p) = uart_blocking_read();
        }
            break;
        case 'r': // run
        {
            void* func = (void*) uart_blocking_read_unsigned();
            char is_kernel = uart_blocking_read();
            void* start = (void*) uart_blocking_read_unsigned();
            void* end   = (void*) uart_blocking_read_unsigned();
            if(is_kernel){
                void* arg = (void*) uart_blocking_read_unsigned();
                char x = uart_blocking_read();
                char y = uart_blocking_read();
                char z = uart_blocking_read();
                context_t ctx = {
                        .local_size = {1, 1, 1},
                        .num_groups = {x, y, z},
                        .global_offset = {0, 0, 0},
                        .work_dim = 0
                };
                mesure_user_kernel(&ctx, (vx_spawn_kernel_cb) func, arg, start, end);
            } else {
                char size = uart_blocking_read();
                mesure_user_warps(size, func, start, end);
            }

        }
            break;
        case 'd': //dump
        {
            uint32_t size = uart_blocking_read_unsigned();
            uint32_t addr = uart_blocking_read_unsigned();
            for (uint32_t p = addr; p < addr + size; p++) uart_blocking_write(*(char *) p);
        }
    }
    goto lab_1;
}