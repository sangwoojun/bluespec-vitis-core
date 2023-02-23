#include "opencl_helpers.h"

void *allocate_aligned(size_t size, size_t alignment)
{
   const size_t mask = alignment - 1;
   const uintptr_t mem = (uintptr_t) calloc(size + alignment, 1);
	return (void *) ((mem + mask) & ~mask);
}

int load_file_to_memory(const char *filename, char **result)
{
	uint size = 0;
	FILE *f = fopen(filename, "rb");
	if (f == NULL) {
		*result = NULL;
		return -1; // -1 means file opening fail
	}
	fseek(f, 0, SEEK_END);
	size = ftell(f);
	fseek(f, 0, SEEK_SET);
	*result = (char *)malloc(size+1);
	if (size != fread(*result, sizeof(char), size, f)) {
		free(*result);
		return -2; // -2 means file reading fail
	}
	fclose(f);
	(*result)[size] = 0;
	return size;
}


void init_setup(int device_idx, cl_context &context, cl_command_queue &commands, cl_program & program, cl_kernel &kernel) {
	cl_int err;                            // error code returned from api calls

	cl_device_id device_id;             // compute device id
	cl_platform_id platform_id;         // platform id
	//cl_context context;                 // compute context
	//cl_command_queue commands;          // compute command queue
	//cl_program program;                 // compute programs
	//cl_kernel kernel;                   // compute kernel
	char cl_platform_vendor[1001];

   // Get all platforms and then select Xilinx platform
	cl_platform_id platforms[16];       // platform id
	cl_uint platform_count;
	int platform_found = 0;
	err = clGetPlatformIDs(16, platforms, &platform_count);
	if (err != CL_SUCCESS) {
		printf("Error: Failed to find an OpenCL platform!\n");
		printf("Test failed\n");
		exit(EXIT_FAILURE);
	}
	printf("INFO: Found %d platforms\n", platform_count);
	fflush(stdout);


	// Find Xilinx Plaftorm
	for (unsigned int iplat=0; iplat<platform_count; iplat++) {
		err = clGetPlatformInfo(platforms[iplat], CL_PLATFORM_VENDOR, 1000, (void *)cl_platform_vendor,NULL);
		if (err != CL_SUCCESS) {
			printf(  "%s", platforms[iplat]);	
			printf("Error: clGetPlatformInfo(CL_PLATFORM_VENDOR) failed!\n");
			printf("Test failed\n");
			exit(EXIT_FAILURE);
		}
		if (strcmp(cl_platform_vendor, "Xilinx") == 0) {
			printf("INFO: Selected platform %d from %s\n", iplat, cl_platform_vendor);
			platform_id = platforms[iplat];
			platform_found = 1;
		}
	}
	if (!platform_found) {
		printf("ERROR: Platform Xilinx not found. Exit.\n");
		exit(EXIT_FAILURE);
	}

	// Get Accelerator compute device
	cl_uint num_devices;
	unsigned int device_found = 0;
	cl_device_id devices[16];  // compute device id
	char cl_device_name[1001];
	err = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_ACCELERATOR, 16, devices, &num_devices);
	printf("INFO: Found %d devices\n", num_devices);
	if (err != CL_SUCCESS) {
		printf("ERROR: Failed to create a device group!\n");
		printf("ERROR: Test failed\n");
		exit(-1);
	}

	if ( device_idx >= num_devices ) {
		printf( "Device index out of bounds %d >= %d\n", device_idx, num_devices);
		exit(EXIT_FAILURE);
	} else {
		err = clGetDeviceInfo(devices[device_idx], CL_DEVICE_NAME, 1024, cl_device_name, 0);
		if (err != CL_SUCCESS) {
			printf("Error: Failed to get device name for device %d!\n", device_idx);
			printf("Test failed\n");
			exit( EXIT_FAILURE);
		}
		printf("Selected %s as the target device\n", cl_device_name);
		device_id = devices[device_idx];
	}
	device_found = 1;

/*
    //iterate all devices to select the target device.
    for (uint i=0; i<num_devices; i++) {
       err = clGetDeviceInfo(devices[i], CL_DEVICE_NAME, 1024, cl_device_name, 0);
       if (err != CL_SUCCESS) {
            printf("Error: Failed to get device name for device %d!\n", i);
            printf("Test failed\n");
            return EXIT_FAILURE;
        }

       printf("CL_DEVICE_NAME %s\n", cl_device_name);
       if(strstr(target_device_name, cl_device_name) != NULL) {
            device_id = devices[i];
            device_found = 1;
            printf("Selected %s as the target device\n", cl_device_name);
       
       }
    }
	*/
	// Create a compute context
	//
	context = clCreateContext(0, 1, &device_id, NULL, NULL, &err);
	if (!context) {
		printf("Error: Failed to create a compute context!\n");
		printf("Test failed\n");
		exit( EXIT_FAILURE);
	}

	// Create a command commands
	commands = clCreateCommandQueue(context, device_id, 0, &err);
	if (!commands) {
		printf("Error: Failed to create a command commands!\n");
		printf("Error: code %i\n",err);
		printf("Test failed\n");
		exit( EXIT_FAILURE);
	}

	int status;

	// Create Program Objects
	// Load binary from disk
	unsigned char *kernelbinary;
	char *xclbin = "./xclbin/kernel.hw.xclbin";

	//------------------------------------------------------------------------------
	// xclbin
	//------------------------------------------------------------------------------
	printf("INFO: loading xclbin %s\n", xclbin);
	int n_i0 = load_file_to_memory(xclbin, (char **) &kernelbinary);
	if (n_i0 < 0) {
		printf("failed to load kernel from xclbin: %s\n", xclbin);
		printf("Test failed\n");
		exit(EXIT_FAILURE);
	}

	size_t n0 = n_i0;

	// Create the compute program from offline
	program = clCreateProgramWithBinary(context, 1, &device_id, &n0,
			(const unsigned char **) &kernelbinary, &status, &err);

	if ((!program) || (err!=CL_SUCCESS)) {
		printf("Error: Failed to create compute program from binary %d!\n", err);
		printf("Test failed\n");
		exit(EXIT_FAILURE);
	}


	// Build the program executable
	//
	err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
	if (err != CL_SUCCESS) {
		size_t len;
		char buffer[2048];

		printf("Error: Failed to build program executable!\n");
		clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, sizeof(buffer), buffer, &len);
		printf("%s\n", buffer);
		printf("Test failed\n");
		exit(EXIT_FAILURE);
	}

    // Create the compute kernel in the program we wish to run
    //
	kernel = clCreateKernel(program, "mkKernelTop", &err);
	if (!kernel || err != CL_SUCCESS) {
		printf("Error: Failed to create compute kernel!\n");
		printf("Test failed\n");
		exit(EXIT_FAILURE);
	}
}

