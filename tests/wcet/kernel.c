#include "bootrom_kernel_mesure.h"

void test_wcet(unsigned num_warps) {
    BOOTROM_START_KERNEL_MESURE(num_warps);
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    __asm__ __volatile__ ("nop");
    BOOTROM_END_KERNEL_MESURE(num_warps);
}
