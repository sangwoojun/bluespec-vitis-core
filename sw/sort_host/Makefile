.PHONY: all
all:
	mkdir -p obj/
	g++ -g -std=c++17 -Wall -O0 main.cpp ColumnSorter.cpp -o ./obj/main -I$(XILINX_XRT)/include/ -L$(XILINX_XRT)/lib -lxrt_coreutil -pthread
