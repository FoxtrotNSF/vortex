#include <stdint.h>
#include <VX_config.h>
#include "vx_print.h"
#include "vx_timeit.h"
#include "vx_spawn.h"

#define MAX_WARPS 64
#define MAX_THDS_PER_WARPS 16

typedef struct{
    int valid;
    uint32_t thd_id[MAX_THDS_PER_WARPS];
    uint64_t time;
} task_nfo_t;

void save_ex_time(int task_id, void* arg){
    task_nfo_t* result = (task_nfo_t*) arg;
    uint32_t warp_thread_id, warp_id;
    __asm__ __volatile__ ("csrr %0, %1" : "=r"(warp_id) : "i"(CSR_GWID));
    __asm__ __volatile__ ("csrr %0, %1" : "=r"(warp_thread_id) : "i"(CSR_WTID));
    result[warp_id].thd_id[warp_thread_id] = task_id;
    if(warp_thread_id == 0) {
        result[warp_id].valid = 1;
        result[warp_id].time = read_time_it();
    }
}

void mesure_user_kernel(int size, void(*user_kernel)(int, void*), void* arg, void* start, void* end){
    task_nfo_t time_results[MAX_WARPS];
    uint32_t num_thds_per_warps;
    __asm__ __volatile__ ("csrr %0, %1" : "=r"(num_thds_per_warps) : "i"(CSR_NT));

    vx_printf("Launching %d threads \n", size);
    set_time_it(start, end);
    vx_spawn_tasks(size, (vx_spawn_tasks_cb)user_kernel, arg);
    stop_timeit();

    vx_printf("Saving results \n");
    int a = size;
    while(a --> 0) time_results[a].valid = 0;
    vx_spawn_tasks(size, (vx_spawn_tasks_cb)save_ex_time, time_results);
    while(size --> 0){
        if(time_results[size].valid){
            vx_printf("warp %d : [", size);
            int i = num_thds_per_warps;
            while(i --> 0) vx_printf("%d%c", time_results[size].thd_id[i], i ? ',' : ']');
            vx_printf(", %llu cycles\n", time_results[size].time);
        }
    }
}

void dummy_function(int thd_id, void* arg) {
    __asm__ __volatile__("kernel_start: .global kernel_start":);
    int *result = (int *) arg;
    int a = thd_id;
    if (thd_id > 2) {
        a = thd_id * 3;
    }
    result[thd_id] = a;
    __asm__ __volatile__("kernel_end: .global kernel_end":);
}

void main() {
    vx_printf("hello world!\n");
    int result[8];
    extern uint8_t function_end __asm__("kernel_end");
    extern uint8_t function_start __asm__("kernel_start");
    mesure_user_kernel(8, dummy_function, result, &function_start, &function_end);
    vx_printf("results :\n");
    for(int i =0; i < 8; i++) vx_printf("%d\n", result[i]);
//    for(int i = 0; i < sizeof(s_data); i++) { while (!send_uart(s_data[i])); }
//    lab_1:
//    while(! uart_available());
//    if(uart_read_data() != 's') goto lab_1;
//    for(int i = 0; i < sizeof(s_data_2); i++) { while (!send_uart(s_data_2[i])); }
//    goto lab_1;
}