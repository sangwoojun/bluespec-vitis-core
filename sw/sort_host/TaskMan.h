#ifndef __TASKMAN_H__
#define __TASKMAN_H__

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <stdint.h>

// XRT includes
#include "xrt/xrt_bo.h"
#include <experimental/xrt_xclbin.h>
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"

class TaskMan {
public:
	TaskMan(const TaskMan& obj) = delete;
	static TaskMan* getInstance() {
		if ( m_pInstance == NULL ) {
			m_pInstance = new TaskMan();
		}
		return m_pInstance;
	}

private:
	static TaskMan* m_pInstance;
	TaskMan();

};

#endif
