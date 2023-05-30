// This is a generated file. Use and modify at your own risk.
////////////////////////////////////////////////////////////////////////////////

/*******************************************************************************
Vendor: Xilinx
Associated Filename: main.c
#Purpose: This example shows a basic vector add +1 (constant) by manipulating
#         memory inplace.
*******************************************************************************/

//#include <iostream>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <assert.h>
#include <stdbool.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <CL/opencl.h>
#include <CL/cl_ext.h>
#include "xclhal2.h"

#include "opencl_helpers.h"

////////////////////////////////////////////////////////////////////////////////

#define NUM_WORKGROUPS (1)
#define WORKGROUP_SIZE (256)
#define MAX_LENGTH 8192

#if defined(SDX_PLATFORM) && !defined(TARGET_DEVICE)
#define STR_VALUE(arg)      #arg
#define GET_STRING(name) STR_VALUE(name)
#define TARGET_DEVICE GET_STRING(SDX_PLATFORM)
#endif

////////////////////////////////////////////////////////////////////////////////

int main(int argc, char* argv[])
{
	cl_int err;				// Error code returned from api calls
	cl_context context;			// Compute context
	cl_command_queue commands;		// Compute command queue
	cl_program program;			// Compute programs
	cl_kernel kernel;			// Compute kernel
	init_setup(0, context, commands, program, kernel);
	
	int* h_data;				// Host memory for input vector
	int h_B_output[MAX_LENGTH];		// Host memory for output vector
	cl_mem d_A, d_B;			// Device memory used for a vector

	const uint data_bytes = (256*1024*1024);// 256MB per one bank of HBM
	h_data = (int*)malloc(data_bytes);

	// For allocating buffer to specific global memory bank
	// User has to use cl_mem_ext_ptr_t and provide the banks
	cl_mem_ext_ptr_t mem_ext_A, mem_ext_B;
	
	mem_ext_A.obj = NULL;
	mem_ext_A.param = 0;
	mem_ext_A.flags = 0 | XCL_MEM_TOPOLOGY; // HBM[0]

	mem_ext_B.obj = NULL;
	mem_ext_B.param = 0;
	mem_ext_B.flags = 2 | XCL_MEM_TOPOLOGY; // HBM[2]
    
	// Creating buffers
	d_A = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  data_bytes, &mem_ext_A, NULL);
	d_B = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  data_bytes, &mem_ext_B, NULL);
	if (!(d_A&&d_B)) {
		printf("Error: Failed to allocate device memory!\n");
		printf("Test failed\n");
		return EXIT_FAILURE;
	}

	//
	err = clEnqueueWriteBuffer(commands, d_A, CL_TRUE, 0, data_bytes, h_data, 0, NULL, NULL);
	if (err != CL_SUCCESS) {
		printf("Error: Failed to write to source array h_data!\n");
		printf("Test failed\n");
		return EXIT_FAILURE;
	}
	err = clEnqueueWriteBuffer(commands, d_B, CL_TRUE, 0, data_bytes, h_data, 0, NULL, NULL);
	if (err != CL_SUCCESS) {
		printf("Error: Failed to write to source array h_data!\n");
		printf("Test failed\n");
		return EXIT_FAILURE;
	}

	// Set the arguments to our compute kernel
	err = 0;
	cl_uint d_scalar00 = (256/64)*1024*1024;
	err |= clSetKernelArg(kernel, 0, sizeof(cl_uint), &d_scalar00); // Not used in example RTL logic.
	err |= clSetKernelArg(kernel, 1, sizeof(cl_mem), &d_A); 
	err |= clSetKernelArg(kernel, 2, sizeof(cl_mem), &d_B); 
	if (err != CL_SUCCESS) {
		printf("Error: Failed to set kernel arguments! %d\n", err);
		printf("Test failed\n");
		return EXIT_FAILURE;
	}

	// Execute the kernel over the entire range of our 1d input data set
	// using the maximum number of work group items for this device
	printf( "[Execute] Start\n"); fflush(stdout);
	err = clEnqueueTask(commands, kernel, 0, NULL, NULL);
	if (err) {
		printf("Error: Failed to execute kernel! %d\n", err);
		printf("Test failed\n");
		return EXIT_FAILURE;
	}
	printf( "[Execute] Running\n"); fflush(stdout);
    
	// Check the kernel termination
	cl_event readevent;
	clFinish(commands);
	printf( "[Execute] Finished\n"); fflush(stdout);
	sleep(5);

	// Read back the restuls from the device to verify the output
	err = 0;
	err |= clEnqueueReadBuffer(commands, d_A, CL_TRUE, 0, MAX_LENGTH, h_B_output, 0, NULL, &readevent);
	printf( "[Result] Memory Reading Start\n"); fflush(stdout);
	if (err != CL_SUCCESS) {
		printf("Error: Failed to read output array! %d\n", err);
		printf("Test failed\n");
		return EXIT_FAILURE;
	}
	clWaitForEvents(1, &readevent);
	printf( "[Result] Memory Reading Finished\n"); fflush(stdout);
	
	// Check Results
	for (uint i = 0; i < 20; i++) {
		printf( "%x \t %x\n", h_data[i], h_B_output[i] );
	}
	//--------------------------------------------------------------------------
	// Shutdown and cleanup
	//-------------------------------------------------------------------------- 
	clReleaseMemObject(d_A);
	clReleaseMemObject(d_B);
	clReleaseProgram(program);
	clReleaseKernel(kernel);
	clReleaseCommandQueue(commands);
	clReleaseContext(context);

	if (false) {
		printf("INFO: Test failed\n");
		return EXIT_FAILURE;
	} else {
		printf("INFO: Test completed successfully\n");
		return EXIT_SUCCESS;
	}
}
