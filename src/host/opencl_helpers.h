#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
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

void *allocate_aligned(size_t size, size_t alignment);
int load_file_to_memory(const char *filename, char **result);

void init_setup(int device_idx, cl_context &context, cl_command_queue &commands, cl_program & program, cl_kernel &kernel);

