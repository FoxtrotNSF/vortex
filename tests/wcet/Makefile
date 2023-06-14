XLEN ?= 32
LLVM_PREFIX ?= /opt/llvm-riscv
RISCV_TOOLCHAIN_PATH ?= /opt/riscv-gnu-toolchain
SYSROOT=${RISCV_TOOLCHAIN_PATH}/riscv32-unknown-elf
VORTEX_RT_PATH ?= $(realpath ../../runtime)
VORTEX_HW_PATH ?= $(realpath ../../hw)

OPTS ?= -n16
USE_GCC ?= 1
ifndef USE_GCC
	VX_CC  = ${LLVM_PREFIX}/bin/clang
	VX_CXX = ${LLVM_PREFIX}/bin/clang++
	VX_DP  = ${LLVM_PREFIX}/bin/llvm-objdump
	VX_CP  = ${LLVM_PREFIX}/bin/llvm-objcopy

    VX_CFLAGS += -Xclang -target-feature -Xclang +vortex
    VX_CFLAGS += --sysroot=${SYSROOT} --gcc-toolchain=${RISCV_TOOLCHAIN_PATH}
	VX_DPFLAGS = -arch=riscv32 -mcpu=generic-rv32 -mattr=+m,+f -mattr=+vortex
else
	VX_CC  = $(RISCV_TOOLCHAIN_PATH)/bin/riscv32-unknown-elf-gcc
	VX_CXX = $(RISCV_TOOLCHAIN_PATH)/bin/riscv32-unknown-elf-g++
	VX_DP  = $(RISCV_TOOLCHAIN_PATH)/bin/riscv32-unknown-elf-objdump
	VX_CP  = $(RISCV_TOOLCHAIN_PATH)/bin/riscv32-unknown-elf-objcopy
endif
VX_CFLAGS += -O3 -march=rv32imf -mabi=ilp32f -fno-exceptions -ffreestanding -nostartfiles -fdata-sections -ffunction-sections
VX_CFLAGS += -I${VORTEX_HW_PATH} -I${VORTEX_RT_PATH}/include
VX_LDFLAGS += -Wl,-Bstatic,-T,$(VORTEX_RT_PATH)/linker/vx_link$(XLEN).ld -Wl,--gc-sections,--defsym=_kernel_entry=$(PROJECT) -e _kernel_entry
VX_CFLAGS += $(CONFIGS)

VX_SRCS = kernel.c

PROJECT = test_wcet

all: kernel.bin kernel.dump
 
kernel.dump: kernel.elf
	$(VX_DP) $(VX_DPFLAGS) -D $(PROJECT)_kernel.elf > $(PROJECT)_kernel.dump

kernel.bin: kernel.elf
	$(VX_CP) -O binary $(PROJECT)_kernel.elf $(PROJECT)_kernel.bin

kernel.elf: $(VX_SRCS)
	$(VX_CC) $(VX_CFLAGS) $(VX_SRCS) $(VX_LDFLAGS) -o $(PROJECT)_kernel.elf

clean:
	rm -rf $(PROJECT) *.o .depend
	rm -rf *.elf *.bin *.dump *.log

ifneq ($(MAKECMDGOALS),clean)
    -include .depend
endif