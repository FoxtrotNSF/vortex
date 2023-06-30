PROJECT ?= vx_decoder_py


SV_INCLUDES = ../../../../hw/dpi/ ../../../../hw/rtl/ ../../../../hw/rtl/interfaces

C_SRCS = decoder_bindings.cpp #../../../../hw/dpi/util_dpi.cpp

C_INCS = $(realpath ../../../../hw)

VL_CFLAGS = $(shell python3 -m pybind11 --includes) $(foreach dir,$(C_INCS),-I$(dir)) -fPIC -O3 -Wall -shared -std=c++11 -fPIC

VL_LDFLAGS = $(shell python3-config --ldflags) --shared

MODULE_NAME = $(PROJECT)$(shell python3-config --extension-suffix)

all:
	verilator --cc --exe --o ../$(MODULE_NAME) -CFLAGS "$(VL_CFLAGS)" -LDFLAGS "$(VL_LDFLAGS)" --Mdir build --build -Wall $(foreach dir,$(SV_INCLUDES),-I$(dir)) -top vx_decoder_wrapper -Wno-lint $(C_SRCS) vx_decoder_wrapper.sv

clean:
	rm -rf ./build
	rm -f $(MODULE_NAME)