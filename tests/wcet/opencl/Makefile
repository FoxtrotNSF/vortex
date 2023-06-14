XLEN ?= 32

LLVM_PREFIX ?= /opt/llvm-riscv
RISCV_TOOLCHAIN_PATH ?= /opt/riscv-gnu-toolchain
SYSROOT ?= $(RISCV_TOOLCHAIN_PATH)/riscv32-unknown-elf
POCL_CC_PATH ?= /opt/pocl/compiler
POCL_RT_PATH ?= /opt/pocl/runtime

OPTS ?= -n64

VORTEX_DRV_PATH ?= $(realpath ../../../driver)
VORTEX_RT_PATH ?= $(realpath ../../../runtime)
BUILD_DIR ?= $(realpath .)/build

K_LLCFLAGS += "-O3 -march=riscv32 -target-abi=ilp32f -mcpu=generic-rv32 -mattr=+m,+f,+vortex -float-abi=hard -code-model=small"
K_CFLAGS   += "-O3 --sysroot=$(SYSROOT) --gcc-toolchain=$(RISCV_TOOLCHAIN_PATH) -march=rv32imf -mabi=ilp32f -Xclang -target-feature -Xclang +vortex -I$(VORTEX_RT_PATH)/include -fno-rtti -fno-exceptions -ffreestanding -nostartfiles -fdata-sections -ffunction-sections"
K_LDFLAGS  += "-Wl,-Bstatic,-T$(VORTEX_RT_PATH)/linker/vx_link$(XLEN).ld -Wl,--gc-sections $(VORTEX_RT_PATH)/libvortexrt.a -lm"

CXXFLAGS += -std=c++11 -Wall -Wextra -Wfatal-errors

CXXFLAGS += -Wno-deprecated-declarations -Wno-unused-parameter -Wno-narrowing

CXXFLAGS += -I$(POCL_RT_PATH)/include

LDFLAGS += -L$(POCL_RT_PATH)/lib -L$(VORTEX_DRV_PATH)/stub -lOpenCL -lvortex

# Debugigng
ifdef DEBUG
	CXXFLAGS += -g -O0
else    
	CXXFLAGS += -O2 -DNDEBUG
endif

ifndef DUMP_GCC
	VX_DP  = ${LLVM_PREFIX}/bin/llvm-objdump
	VX_DPFLAGS = -arch=riscv32 -mcpu=generic-rv32 -mattr=+m,+f -mattr=+vortex
else
	VX_DP  = $(RISCV_TOOLCHAIN_PATH)/bin/riscv32-unknown-elf-objdump
endif

PROJECT = test_kernel

SRCS = kernel.cl

CLEAN_ELF_C = $(shell echo $(K_CFLAGS))
CLEAN_ELF_LD = $(shell echo "-Wl,-Bstatic,-T$(VORTEX_RT_PATH)/linker/vx_link$(XLEN).ld -Wl,--gc-sections,--defsym=_kernel_entry=_pocl_kernel_$(PROJECT)_workgroup_fast -e _kernel_entry -lm")

all: kernel.pocl

kernel.pocl: kernel.cl
	LLVM_PREFIX=$(LLVM_PREFIX) POCL_KERNEL_CACHE=1 POCL_CACHE_DIR=$(BUILD_DIR) POCL_LEAVE_KERNEL_COMPILER_TEMP_FILES=1 POCL_DEBUG=all LD_LIBRARY_PATH=$(LLVM_PREFIX)/lib:$(POCL_CC_PATH)/lib $(POCL_CC_PATH)/bin/poclcc -LLCFLAGS $(K_LLCFLAGS) -CFLAGS $(K_CFLAGS) -LDFLAGS $(K_LDFLAGS) -o kernel.pocl kernel.cl

parallel.bc: kernel.pocl

kernel_clean.dump: kernel_clean.elf
	 $(VX_DP) $(VX_DPFLAGS) -D ./$(PROJECT)_clean.elf > ./$(PROJECT)_clean.dump

kernel_clean.elf: parallel.bc
	$(LLVM_PREFIX)/bin/clang $(CLEAN_ELF_C) -I$(POCL_CC_PATH)/share/pocl/include ./build/*/*/test_kernel/0-0-0/*.o $(CLEAN_ELF_LD) \
	-o ./$(PROJECT)_clean.elf

clean:
	rm -rf *.o .depend build *.elf
	rm -rf *.pocl *.dump


ifneq ($(MAKECMDGOALS),clean)
    -include .depend
endif
