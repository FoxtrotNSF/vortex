#pragma once

#ifdef __clang__

#define BOOTROM_START_KERNEL_MESURE(num_warps)  __asm__ __volatile__ ("vx_bar	%0, %1" :: "r"(1), "r"(num_warps));\
                                                __asm__ __volatile__ ("kernel_start:":)

#define BOOTROM_END_KERNEL_MESURE(num_warps)    __asm__ __volatile__ ("kernel_end:":);\
                                                __asm__ __volatile__ ("vx_bar	zero, %0" :: "r"(num_warps))

#else

#define BOOTROM_START_KERNEL_MESURE(num_warps)  __asm__ __volatile__ (".insn s 0x6b, 4, %1, 0(%0)" :: "r"(1), "r"(num_warps));\
                                                __asm__ __volatile__ ("kernel_start:":)

#define BOOTROM_END_KERNEL_MESURE(num_warps)    __asm__ __volatile__ ("kernel_end:":);\
                                                __asm__ __volatile__ (".insn s 0x6b, 4, %0, 0(zero)" :: "r"(num_warps))

#endif
