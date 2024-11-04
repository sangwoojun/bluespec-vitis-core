# bluespec-vitis-core
Boilerplace codebase for using Bluespec System Verilog for Xilinx Alveo FPGA kernel development.

## File structure
* hw/
* sw/

## How to build
* Build/packaging kernel, xclbin, and hw: cd to hw/ run `make`
* Using a different kernel: `make KERNEL=sort_kernel`
* Building kernel to generate .xo: cd to the kernel directory, run `make`
* Building software: cd to sw/ run `make`

## Notes
Developed in Vitis 2023.2, tested on Alveo U50
