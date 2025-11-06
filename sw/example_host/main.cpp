#include <iostream>
#include <cstring>
#include <vector>
#include <chrono>
#include <sys/time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <fstream>
#include <string>
#include <unordered_map>
#include <map>
#include <algorithm>
using namespace std;


// XRT includes
#include "xrt/xrt_bo.h"
#include <experimental/xrt_xclbin.h>
#include <experimental/xrt_ip.h>
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"


#define DEVICE_ID 0
#define DATA_SIZE 536870912
#define RESULTADDRESS 0


int main(int argc, char** argv) {
	// Load xclbin
	string xclbin_file = "../../hw/hw/kernel.xclbin";
	xrt::device device = xrt::device(DEVICE_ID);
	xrt::uuid xclbin_uuid = device.load_xclbin(xclbin_file);
	
	// Create kernel object
	cout << "Create Kernel" << endl;
	fflush(stdout);
	auto krnl = xrt::kernel(device, xclbin_uuid, "kernel:{kernel_1}");
	auto ip = xrt::ip(device, xclbin_uuid, "kernel:{kernel_1}");

	cout << "[Xilinx Alveo U50]" << endl;
	cout << "Allocate Buffer in Global Memory" << endl;
	fflush( stdout );
	auto boIn = xrt::bo(device, (size_t)DATA_SIZE, krnl.group_id(1));
	auto boOut = xrt::bo(device, (size_t)DATA_SIZE, krnl.group_id(2)); 
	
	// Map the contents of the buffer object into host memory
	auto bo0_map = boIn.map<int*>();
	auto bo1_map = boOut.map<int*>();
	fill(bo0_map, bo0_map + ((size_t)DATA_SIZE / 4), 0);
	fill(bo1_map, bo1_map + ((size_t)DATA_SIZE / 4), 0);
	bo0_map[0] = 1;
	bo1_map[0] = 2;

	// Synchronize buffer content with device side
	cout << "Synchronize input buffer data to device global memory" << endl;
	fflush(stdout);
	boIn.sync(XCL_BO_SYNC_BO_TO_DEVICE);
	boOut.sync(XCL_BO_SYNC_BO_TO_DEVICE);



	ip.write_register(0, 4);
	int t = ip.read_register(0);

	printf( "reg: %d\n", t );

	cout << "Execution of the kernel" << endl;
	fflush(stdout);
	auto run = krnl((size_t)DATA_SIZE, boIn, boOut);
	run.wait();

	// Get the output
	cout << "Get the output data from the device" << endl;
	fflush(stdout);
	boOut.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

	// Read cycle count
	printf( "Result: %u\n", bo1_map[RESULTADDRESS] );
	cout << "TEST PASSED" << endl;

	return 0;
}

