#make all TARGET=hw DEVICE=xilinx_samsung_u2x4_201920_3

# faketime used to work around vitis issue
faketime '2021-03-01 13:00:00' make all TARGET=hw_emu DEVICE=xilinx_samsung_u2x4_201920_3
#make all TARGET=hw_emu DEVICE=xilinx_samsung_u2x4_201920_3
#export XCL_EMULATION_MODE=hw_emu
#emconfigutil --platform xilinx_samsung_u2x4_201920_3
#./host ./xclbin/kernel.hw_emu.xclbin xilinx_samsung_u2x4_201920_3
vivado -mode batch -source ./scripts/report.tcl -nolog -nojournal -tclargs utilization_report.rpt
