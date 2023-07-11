#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include <queue>


// temporary, 8 buffers of size 32MB
#define MEM_PORT_CNT 2
#define MEM_BUF_SIZE (1024*1024*512)

bool g_initialized = false;
uint32_t* g_buffers[MEM_PORT_CNT];
uint32_t g_writereq_tag[MEM_PORT_CNT];



void init() {
	if ( g_initialized ) return;

	for ( int i = 0; i < MEM_PORT_CNT; i++ ) {
		g_buffers[i] = (uint32_t*)malloc(MEM_BUF_SIZE);
		for ( int j = 0; j < MEM_BUF_SIZE/sizeof(uint32_t); j++ ) g_buffers[i][j] = 0;
		g_writereq_tag[i] = 0;
		//TODO load, memcpy, to buffers
	}
	FILE* fin = fopen("../host/minisudoku.bin", "rb");
	int off = 0;
	while(!feof(fin)) {
		uint64_t data = 0;
		if ( 0 == fread(&data, 1, sizeof(uint32_t), fin) ) continue;

		g_buffers[0][off] = data;
		g_buffers[1][off] = data;
		off++;
	}
	/*if ( off*4 < 268435455 ) {
		uint64_t data = 0;
		g_buffers[0][off] = data;
		g_buffers[1][off] = data;
		off++;
	}*/
	printf( "Sent %d bytes done!\n", off*4 );
	g_initialized = true;
}

extern "C" uint32_t bdpi_read_word(int bufidx, uint64_t addr) {
	init();
	if ( addr >= MEM_BUF_SIZE ) return 0xffffffff;


	uint32_t r = g_buffers[bufidx][addr/sizeof(uint32_t)];
	//printf( "%d %x --> %x\n", bufidx, addr, r );
	//fflush(stdout);
	return r;
}

extern "C" void bdpi_write_word(int bufidx, uint64_t addr, uint32_t data, uint32_t tag) {
	init();
	//if ( tag != g_writereq_tag[bufidx] ) return;
	if ( addr >= MEM_BUF_SIZE ) return;
	g_writereq_tag[bufidx]++;
	g_buffers[bufidx][addr/sizeof(uint32_t)] = data;
}

/*
extern "C" void bdpi_write_word(int bufidx, uint64_t addr, 
	uint64_t data0, uint64_t data1, uint64_t data2, uint64_t data3, uint64_t data4, uint64_t data5, uint64_t data6, uint64_t data7, 
	uint64_t data8, uint64_t data9, uint64_t data1, uint64_t data3, uint64_t data4, uint64_t data5, uint64_t data6, uint64_t data7, 
	uint32_t tag) {
	init();
	if ( tag != g_writereq_tag[bufidx] ) return;
	if ( addr >= MEM_BUF_SIZE ) return;

	g_writereq_tag[bufidx]++;

	g_buffers[bufidx][addr/sizeof(uint64_t)] = data0;
	g_buffers[bufidx][addr/sizeof(uint64_t) + 1] = data1;
	g_buffers[bufidx][addr/sizeof(uint64_t) + 2] = data2;
	g_buffers[bufidx][addr/sizeof(uint64_t) + 3] = data3;
	g_buffers[bufidx][addr/sizeof(uint64_t) + 4] = data4;
	g_buffers[bufidx][addr/sizeof(uint64_t) + 5] = data5;
	g_buffers[bufidx][addr/sizeof(uint64_t) + 6] = data6;
	g_buffers[bufidx][addr/sizeof(uint64_t) + 7] = data7;

}
*/
