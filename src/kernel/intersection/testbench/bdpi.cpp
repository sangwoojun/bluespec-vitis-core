#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define MEM_BUF_SIZE (1024*1024*512)

bool g_initialized = false;
uint32_t* g_buffer;


void init() {
	if ( g_initialized ) return;
	g_buffer = (uint32_t*)malloc(MEM_BUF_SIZE);

	g_buffer[0] = 0;
	g_buffer[2048] = 0;
	for ( int i = 1; i < 1024; i++ ) {
		
		g_buffer[i] = g_buffer[i-1] + 1+(rand()%32);
		g_buffer[i+2048] = g_buffer[i-1+2048] + 1+(rand()%32);
	}

	g_initialized = true;
}

extern "C" uint32_t bdpi_read_word(uint32_t addr) {
	init();
	if ( addr >= MEM_BUF_SIZE ) return 0xffffffff;


	uint32_t r = g_buffer[addr/sizeof(uint32_t)];
	return r;
}

