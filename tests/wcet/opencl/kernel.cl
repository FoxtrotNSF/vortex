#include "../bootrom_kernel_mesure.h"

int __attribute__ ((noinline)) f(unsigned num_warps, unsigned gid){
    int out = 2;
    BOOTROM_START_KERNEL_MESURE(num_warps);
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    if(gid) out = 1;
    BOOTROM_END_KERNEL_MESURE(num_warps);
    return out;
}

__kernel void test_kernel (unsigned num_warps, __global int* out)
{
    int gid = get_global_id(0);
    out[gid] = f(num_warps, gid);
}
