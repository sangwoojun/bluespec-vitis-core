TARGET := hw
<<<<<<< HEAD
PROJECT := sort
=======
PROJECT := example
>>>>>>> 22f21ee5cd4bf2084cb1eec451aa57e64cbd5d0e
PLATFORM ?= xilinx_u50_gen3x16_xdma_5_202210_1
HOSTDIR := ../sw/$(PROJECT)_host/
CONFIGDIR := ./configs
KERNEL := ./$(PROJECT)_kernel
BUILD_DIR := ./$(TARGET)
CXXFLAGS += -g -std=c++17 -Wall -O2

KERNEL_DIRS = $(shell find $(KERNEL) -type d)
KERNEL_FILES = $(shell find $(KERNEL) -type f -name '*')

JOBS := 8
VPPFLAGS := --vivado.param general.maxThreads=$(JOBS) --vivado.impl.jobs $(JOBS) --vivado.synth.jobs $(JOBS) --temp_dir $(BUILD_DIR) --log_dir $(BUILD_DIR) --report_dir $(BUILD_DIR) --report_level 2


build: package

host: $(HOSTDIR)/obj/main
$(HOSTDIR)/obj/main: $(HOSTDIR)/$(wildcard *.cpp) $(HOSTDIR)/$(wildcard *.h)
	$(MAKE) -C $(HOSTDIR)



xo: $(BUILD_DIR)/kernel.xo
$(BUILD_DIR)/kernel.xo: $(KERNEL_DIRS) $(KERNEL_FILES)
ifeq ($(TARGET),sw_emu)
	#FIXME
	#v++ -c -t ${TARGET} --platform $(PLATFORM) --config $(CONFIGDIR)/u50.cfg -k kernel $(VPPFLAGS) -I$(KERNEL) $(KERNEL)/*.cpp -o $(BUILD_DIR)/kernel.xo
else
	$(MAKE) -C $(KERNEL)
endif

xclbin: $(BUILD_DIR)/kernel.xclbin
$(BUILD_DIR)/kernel.xclbin: $(BUILD_DIR)/kernel.xo
	v++ -l -t ${TARGET} --platform $(PLATFORM) --config $(CONFIGDIR)/u50.cfg $(VPPFLAGS) $(BUILD_DIR)/kernel.xo -o $(BUILD_DIR)/kernel.xclbin
	vivado -mode batch -source ./scripts/report_hierarchical_utilization.tcl -tclargs $(BUILD_DIR)

emconfig: $(BUILD_DIR)/emconfig.json
$(BUILD_DIR)/emconfig.json:
	emconfigutil --platform $(PLATFORM) --od $(BUILD_DIR) --nd 1

package: host emconfig xclbin
	mkdir -p $(BUILD_DIR)/hw_package
	cd $(BUILD_DIR) && cp ../$(HOSTDIR)/obj/main hw_package && cp kernel.xclbin hw_package && cp emconfig.json hw_package
	cp $(CONFIGDIR)/xrt.ini $(BUILD_DIR)/hw_package
	cd $(BUILD_DIR) && tar czvf hw_package.tgz hw_package/

clean:
	rm -rf $(BUILD_DIR) *json *.log *summary _x xilinx* .run .Xil .ipcache *.jou

