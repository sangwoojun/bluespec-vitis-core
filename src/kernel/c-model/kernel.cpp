#include <iostream>

extern "C" {
	void mkKernelTop(int size, int* mem) { // Size in integer
		for ( int i = 0; i < size; i++ ) mem[i] = i;
	}
}
