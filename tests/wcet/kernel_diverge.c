#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <vx_print.h>
#include "common.h"

#ifndef SIZE
#define SIZE 4
#endif

void kernel_body(int task_id, kernel_arg_t* arg) {
    //vx_printf("current_warp is : %d\n", vx_warp_id());
	int32_t* src_ptr = (int32_t*)arg->src_addr;
	int32_t* dst_ptr = (int32_t*)arg->dst_addr;

	int value = src_ptr[task_id];

	// none taken
	if (task_id >= 0x7fffffff) {
		value = 0;
	}else {
		value += 2;
	}

	// diverge
	if (task_id > 1) {
		if (task_id > 2) {
			value += 6;
		}else {
			value += 5;
		}
	}else {
		if (task_id > 0) {
			value += 4;
		}else {
			value += 3;
		}
	}

	// all taken
	if (task_id >= 0) {
		value += 7;
	}else {
		value = 0;
	}

	dst_ptr[task_id] = value;

}

void main() {
//    vx_printf("%d cores\n", vx_num_cores());
//    vx_printf("%d warps\n", vx_num_warps());
//    vx_printf("%d threads\n", vx_num_threads());
	kernel_arg_t* arg = (kernel_arg_t*)KERNEL_ARG_DEV_MEM_ADDR;
	vx_spawn_tasks(SIZE, (vx_spawn_tasks_cb)kernel_body, arg);
}