#include "TaskMan.h"


TaskMan* TaskMan::m_pInstance = NULL;

TaskMan::TaskMan() {
	std::string binaryFile = "./kernel.xclbin";
	int device_index = 0;

	std::cout << "Open the device" << device_index << std::endl;
	xrt::device device = xrt::device(device_index);
	std::cout << "Load the xclbin " << binaryFile << std::endl;
	xrt::uuid uuid = device.load_xclbin(binaryFile);
	xrt::kernel krnl = xrt::kernel(device, uuid, "kernel:{kernel_1}");//, xrt::kernel::cu_access_mode::exclusive);

	printf( "Loaded or verified xclbin in FPGA\n" ); fflush(stdout);
}
