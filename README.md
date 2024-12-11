# bluespec-vitis-core
Boilerplace codebase for using Bluespec System Verilog for Xilinx Alveo FPGA kernel development.

## File structure
* hw/
* sw/

## Clone bluelib
* bluespec-vitis-core depends on the bluelib library, which can be found here https://github.com/sangwoojun/bluelib.
* By default, bluelib must be cloned at the same level as bluespec-vitis-core (e.g., ~/bluespec-vitis-core and ~/bluelib).

## How to build
* Build/packaging kernel, xclbin, and hw: cd to hw/ run `make`
* Using a different kernel: `make KERNEL=sort_kernel`
* Building kernel to generate .xo: cd to the kernel directory, run `make`
* Building software: cd to sw/ run `make`

## Working examples
* hw/example_kernel & sw/example_host: Simple adder example

## Notes
Developed in Vitis 2023.2, tested on Alveo U50
