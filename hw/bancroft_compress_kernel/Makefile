ROOT_DIR = ../../
PLATFORM ?= xilinx_u50_gen3x16_xdma_5_202210_1
BSCFLAGS = -show-schedule -aggressive-conditions 
BSCFLAGS_SYNTH = -bdir ./obj -vdir ./obj/verilog -simdir ./obj -info-dir ./obj -fdir ./obj 
TARGET := hw
BUILD_DIR := ../$(TARGET)
BLIB_DIR = $(ROOT_DIR)/../bluelib/

.PHONY: all verilog

MODULEPATH=$(BLIB_DIR)/src/

VIVADO := $(XILINX_VIVADO)/bin/vivado

all: verilog obj/kernel.xo

obj/kernel.xo: ./kernel.xml ./scripts/package_kernel.tcl ./scripts/gen_xo.tcl $(wildcard ./obj/verilog/*.v) verilog
	mkdir -p obj
	$(VIVADO) -mode batch -tempDir obj -source scripts/gen_xo.tcl -tclargs $(BUILD_DIR)/kernel.xo kernel hw $(PLATFORM)

verilog: $(wildcard *.bsv) $(wildcard *.v)
	mkdir -p obj
	mkdir -p obj/verilog
	bsc  $(BSCFLAGS) $(BSCFLAGS_SYNTH) -remove-dollar -p +:$(MODULEPATH) -verilog -u -g kernel KernelTop.bsv 
	cd obj/verilog/;bash ../../scripts/verilogcopy.sh
	cp *.v ./obj/verilog/
	
clean:
	rm -rf obj
	rm -rf *.log *.jou
