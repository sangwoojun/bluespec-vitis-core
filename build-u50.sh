make all TARGET=hw DEVICE=xilinx_u50_gen3x16_xdma_201920_3
#make all TARGET=hw_emu DEVICE=xilinx_samsung_u2x4_201920_3
#export XCL_EMULATION_MODE=hw_emu
#emconfigutil --platform xilinx_samsung_u2x4_201920_3
#./host ./xclbin/kernel.hw_emu.xclbin xilinx_samsung_u2x4_201920_3

#vivado -mode batch -source ./scripts/report.tcl -nolog -nojournal -tclargs utilization_report.rpt
