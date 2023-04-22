#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <vx_print.h>
#include "common.h"
#include <stdlib.h>
#ifndef SIZE
#define SIZE 128
#endif
// Parallel Selection sort

void kernel_body(int task_id, kernel_arg_t* arg) {
    uint32_t num_points = arg->size;
    int32_t* src_ptr = (int32_t*)arg->src_addr;
    int32_t* dst_ptr = (int32_t*)arg->dst_addr;

    int32_t ref_value = src_ptr[task_id];
    uint32_t pos = 0;
    for (uint32_t i = 0; i < num_points; ++i) {
        int32_t cur_value = src_ptr[i];
        pos += (cur_value < ref_value) || ((cur_value == ref_value) && (i < task_id));
    }
    dst_ptr[pos] = ref_value;
}

void main() {
    vx_printf("%d cores\n", vx_num_cores());
    vx_printf("%d warps\n", vx_num_warps());
    vx_printf("%d threads\n", vx_num_threads());
    int32_t randArray[SIZE],i, res_array[SIZE];
    for(i=0;i<SIZE;i++)
        randArray[i]=rand()%(8 * SIZE);
    for(i=0;i<SIZE;i++)
        res_array[i]=0;
    for(i=0;i<SIZE;i++)
        vx_printf("%d ", randArray[i]);
    vx_printf("\n");
    kernel_arg_t arg = {.size=SIZE, .src_addr=(uint32_t) randArray, .dst_addr= (uint32_t)res_array};
    __asm__ __volatile__("ebreak");
    vx_spawn_tasks(SIZE, (vx_spawn_tasks_cb)kernel_body, &arg);
    __asm__ __volatile__("ebreak");
    for(i=0;i<SIZE;i++)
        vx_printf("%d ", res_array[i]);
    vx_printf("\n");
}