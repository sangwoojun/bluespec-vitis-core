#/*
#Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
#SPDX-License-Identifier: X11
#*/

//#include "cmdlineparser.h"
#include <iostream>
#include <cstring>

// XRT includes
#include "xrt/xrt_bo.h"
#include <experimental/xrt_xclbin.h>
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"

#define DATA_SIZE (1024*1024*128)

#define CHANNEL_SIZE (1024*1024*256)

int main(int argc, char** argv) {

	if ( argc != 2 ) {
		printf( "usage: %s [filename]\n", argv[0] );
		// TODO: parameterize kv bytes?
		exit(1);
	}


	FILE* fin = fopen(argv[1], "rb");
	if ( fin != NULL ) {
		printf( "Failed to open file %s\n", argv[1] );
		exit(2);
	}

	
	uint32_t* inrdbuf = (uint32_t*)malloc();
	while (!feof(fin)) {
		
	}








/*
	std::cout << "argc = " << argc << std::endl;
	for(int i=0; i < argc; i++){
		std::cout << "argv[" << i << "] = " << argv[i] << std::endl;
	}

	// Read settings

	size_t vector_size_bytes = sizeof(int) * DATA_SIZE;

	//auto krnl = xrt::kernel(device, uuid, "vadd");
	auto krnl2 = xrt::kernel(device, uuid, "kernel:{kernel_2}");//, xrt::kernel::cu_access_mode::exclusive);

	std::cout << "Allocate Buffer in Global Memory\n";
	auto boIn1 = xrt::bo(device, vector_size_bytes, krnl.group_id(1)); //Match kernel arguments to RTL kernel
	auto boOut = xrt::bo(device, vector_size_bytes, krnl.group_id(2)); // can this be input to kernel 2

	auto boOut2 = xrt::bo(device, vector_size_bytes, krnl2.group_id(2));
	
	printf( "!\n");
	fflush(stdout);

	// Map the contents of the buffer object into host memory
	auto bo0_map = boIn1.map<int*>();
	auto bo2_map = boOut.map<int*>();
	auto bo3_map = boOut2.map<int*>();
	std::fill(bo0_map, bo0_map + DATA_SIZE, 0);
	std::fill(bo2_map, bo2_map + DATA_SIZE, 0);
	std::fill(bo3_map, bo3_map + DATA_SIZE, 0);


	for ( int q = 0; q < 32; q++ ) {
		for (int i = 0; i < DATA_SIZE; ++i) {
			bo0_map[i] = (q<<16) | i;
		}
		std::fill(bo3_map, bo3_map + DATA_SIZE, 0);

		// Synchronize buffer content with device side
		std::cout << q << " synchronize input buffer data to device global memory\n";
		fflush(stdout);
		boIn1.sync(XCL_BO_SYNC_BO_TO_DEVICE);


		std::cout << "Execution of the kernel\n";
		fflush(stdout);
		auto run = krnl(vector_size_bytes, boIn1, boOut); //DATA_SIZE=size
		run.wait();
		std::cout << "Execution of the kernel 2\n";
		fflush(stdout);
		auto run2 = krnl2(vector_size_bytes, boOut, boOut2); //DATA_SIZE=size
		run2.wait();

		// Get the output;
		std::cout << "Get the output data from the device" << std::endl;
		boOut.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
		boOut2.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

		for ( int i = 0; i < 8; i++ ) {
			printf( "%x %x:%x -- %x %x\n", bo3_map[i], DATA_SIZE-1-i, bo3_map[DATA_SIZE-1-i], bo2_map[i], bo2_map[DATA_SIZE-1-i] );
		}
		int last_nonzero_idx = 0;
		int last_nonzero_idx2 = 0;
		for ( int i = 0; i < DATA_SIZE; i++ ) {
			if (bo2_map[i] != 0 ) last_nonzero_idx = i;
			if (bo3_map[i] != 0 ) last_nonzero_idx2 = i;
		}
		printf( "Last nonzero idx: %x, %x\n", last_nonzero_idx, last_nonzero_idx2 );
	}

	// Validate results
	//if (std::memcmp(bo2_map, bufReference, vector_size_bytes))
		//throw std::runtime_error("Value read back does not match reference");

	std::cout << "TEST PASSED\n";
	*/
	return 0;
}

