#ifndef __COLUMNSORTER_H__
#define __COLUMNSORTER_H__

#include <iostream>
#include <cstring>
#include <vector>
#include <algorithm>
#include <thread>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// XRT includes
#include "xrt/xrt_bo.h"
#include <experimental/xrt_xclbin.h>
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"

#define MAX_THREADS 64

typedef struct {
	int idx;
	size_t offset_elements;
	FILE* fin;
	FILE* fout;
	bool working;
} WorkerThreadArg;

template <typename T>
class ColumnSorter {
public:
	ColumnSorter(size_t buffer_bytes, int thread_count);

	size_t ReadFile(FILE* fin, bool half=false);
	size_t WriteFile(FILE* fout, bool half=false, size_t elements = 0);
	void Sort();
	void ReadSortWriteWorker(WorkerThreadArg arg);

	size_t SortAllColumns(FILE* fin, FILE* fout, bool shift=false);
	void Transpose(FILE* fin, FILE* fout);
	void UnTranspose(FILE* fin, FILE* fout);
	void InitFile(FILE* fout, size_t bytes);
	
	static bool compareElementsLess(T a, T b);

private:
	T* m_inbuf; 
	T* m_outbuf; 
	size_t m_buffer_bytes;
	size_t m_buffer_elements_max;
	size_t m_buffer_elements;

	std::thread m_worker_threads[MAX_THREADS];
	WorkerThreadArg m_worker_args[MAX_THREADS];
	T* m_inbuf_array[MAX_THREADS];
	//T* m_outbuf_array[MAX_THREADS];
	int m_next_thread_idx;
	int m_thread_max;
	std::mutex m_mutex;

};

template <typename T>
ColumnSorter<T>::ColumnSorter(size_t buffer_bytes, int thread_count) {
	m_inbuf = (T*)malloc(buffer_bytes);
	m_outbuf = (T*)malloc(buffer_bytes);
	m_buffer_bytes = buffer_bytes;
	m_buffer_elements_max = buffer_bytes/sizeof(T);
	printf( "Created sorter with buffer size %ld (%ld elements)\n", m_buffer_bytes, m_buffer_elements_max );
	printf( "Size of elements: %ld bytes\n", sizeof(T) );

	m_thread_max = thread_count;
	for ( int i = 0; i < thread_count; i++ ) {
		m_inbuf_array[i] = (T*)malloc(buffer_bytes);
		//m_outbuf_array[i] = (T*)malloc(buffer_bytes);
		m_worker_args[i].working = false;
	}
}

template <typename T>
size_t 
ColumnSorter<T>::ReadFile(FILE* fin, bool half) {
	memset(m_inbuf, 0xff, m_buffer_bytes);
	m_buffer_elements = fread(m_inbuf, sizeof(T), 
		half? m_buffer_elements_max/2:m_buffer_elements_max, 
	fin);
	return m_buffer_elements;
}
template <typename T>
size_t 
ColumnSorter<T>::WriteFile(FILE* fout, bool half, size_t elements) {
	size_t write_elements = elements;
	if ( !write_elements ) {
		write_elements = half?m_buffer_elements_max/2:m_buffer_elements_max;
	}
	return fwrite(m_outbuf, sizeof(T), write_elements, fout);
}

template <typename T>
void
ColumnSorter<T>::Sort() {
	std::sort(m_inbuf, m_inbuf+m_buffer_elements_max, compareElementsLess);
	memcpy(m_outbuf, m_inbuf, m_buffer_bytes);
}

template <typename T>
void
ColumnSorter<T>::ReadSortWriteWorker(WorkerThreadArg arg) {
	//printf( "Thread start\n" );
	int idx = arg.idx;
	FILE* fin = arg.fin;
	FILE* fout = arg.fout;

	size_t file_offset = arg.offset_elements*sizeof(T);
	memset(m_inbuf_array[idx], 0xff, m_buffer_bytes);
	//printf( "Memset done: 0x%lx\n", m_buffer_bytes);

	m_mutex.lock();
	fseek(fin, file_offset, SEEK_SET);
	m_buffer_elements = fread(m_inbuf_array[idx], sizeof(T), m_buffer_elements_max, fin);
	m_mutex.unlock();
	//printf( "Fread done: 0x%lx\n", m_buffer_elements_max);
	std::sort(m_inbuf_array[idx], m_inbuf_array[idx]+m_buffer_elements_max, compareElementsLess);
	//printf( "Sort done: 0x%lx\n", m_buffer_elements_max);
	
	m_mutex.lock();
	fseek(fout, file_offset, SEEK_SET);
	/*size_t write_elements =*/ fwrite(m_inbuf_array[idx], sizeof(T), m_buffer_elements_max, fout);
	m_mutex.unlock();
	//printf( "Thread finished! Wrote %ld bytes to %ld\n", write_elements*sizeof(T), file_offset );
}

template <typename T>
size_t 
ColumnSorter<T>::SortAllColumns(FILE* fin, FILE* fout, bool shift) {
	fseek(fin, 0, SEEK_END); // Move file pointer to the end
	size_t file_size = ftell(fin); // Get current position (which is the file size)
	rewind(fin);
	rewind(fout);

	printf( "Sorting all columns of file size %ld\n", file_size );

	//T last_val = {0};
	size_t work_offset_elements = 0;

	//while (!feof(fin)) {
	size_t wcount = (file_size+ (m_buffer_elements_max*sizeof(T)-1))/(m_buffer_elements_max*sizeof(T))+1; // plus one because of two half reads
	for ( size_t bid = 0; bid < wcount; bid++) {
		//size_t cur_off = work_offset_elements*sizeof(T);
		//if ( shift && ( cur_off == 0 || cur_off >= file_size-(m_buffer_elements_max*sizeof(T)/2)  ) ) {
		if ( shift && ( bid == 0 || bid == wcount-1) ) {
			for ( int i = 0; i < m_thread_max; i++ ) {
				if ( m_worker_args[i].working ) {
					m_worker_threads[i].join();
					m_worker_args[i].working = false;
				}
			}
			

			size_t read_elements = this->ReadFile(fin, true);
			if ( read_elements == 0 ) continue;
			
			memcpy(m_outbuf, m_inbuf, sizeof(T)*m_buffer_elements_max/2);
			this->WriteFile(fout, true);
			work_offset_elements += m_buffer_elements_max/2;
			printf( "Doing half reads\n" );
		} else {
			
			/*
			size_t read_elements = this->ReadFile(fin);
			if ( read_elements == 0 ) continue;
			this->Sort();
			this->WriteFile(fout);

			if ( read_elements != m_buffer_elements_max ) {
				printf( "Read element count not full buffer! %ld %ld\n", read_elements, m_buffer_elements_max );
			}
			*/
			
			if ( m_worker_args[m_next_thread_idx].working ) {
				m_worker_threads[m_next_thread_idx].join();
			}
			m_worker_args[m_next_thread_idx].working = true;
			m_worker_args[m_next_thread_idx].fin = fin;
			m_worker_args[m_next_thread_idx].fout = fout;
			m_worker_args[m_next_thread_idx].idx = m_next_thread_idx;
			m_worker_args[m_next_thread_idx].offset_elements = work_offset_elements;
			m_worker_threads[m_next_thread_idx] = std::thread(&ColumnSorter<T>::ReadSortWriteWorker, this, m_worker_args[m_next_thread_idx]);

			m_next_thread_idx = (m_next_thread_idx+1)%m_thread_max;

			work_offset_elements += m_buffer_elements_max;
		}
	}

	for ( int i = 0; i < m_thread_max; i++ ) {
		if ( m_worker_args[i].working ) {
			m_worker_threads[i].join();
			m_worker_args[i].working = false;
		}
	}


	fseek(fout, 0, SEEK_END);
	size_t fout_bytes = ftell(fout); 
	printf( "Sort phase done -- %ld bytes\n", fout_bytes );
	return fout_bytes;
}

template <typename T>
void 
ColumnSorter<T>::Transpose(FILE* fin, FILE* fout) {
	fseek(fin, 0, SEEK_END); // Move file pointer to the end
	size_t file_size = ftell(fin); // Get current position (which is the file size)
	fseek(fout, 0, SEEK_END); // Move file pointer to the end
	size_t file_size_out = ftell(fout); // Get current position (which is the file size)
	rewind(fin);
	rewind(fout);

	
	// Number of columns calculated from file size
	size_t columns = (file_size+((m_buffer_elements_max*sizeof(T))-1))/m_buffer_bytes;

	printf( "Starting transpose: %ld columns\n", columns );
	
	if ( file_size_out < file_size ) {
		InitFile(fout, file_size-file_size_out);
	}
	rewind(fout);

	size_t cur_coloff = 0;
	// column size may not be multiple of columns!
	// TODO leftover elements (<columns) need to be handled separately
	size_t newrows = m_buffer_elements/columns;
	size_t row_remainder = m_buffer_elements%columns;

	printf( "row_remainder: %ld -- TODO these elements should be handled separately\n", row_remainder );

	
	while (!feof(fin)) {
		size_t read_elements = this->ReadFile(fin);
		if ( read_elements == 0 ) continue;

		memset(m_outbuf, 0xff, m_buffer_bytes);
		for ( size_t col = 0; col < columns; col++ ) {
			for ( size_t row = 0; row < newrows; row++ ) {
				size_t newoff = col*newrows + row;
				size_t curoff = row*columns + col; 
				m_outbuf[newoff] = m_inbuf[curoff];
			}
		}


		for ( size_t col = 0; col < columns; col++ ) {
			size_t file_offset = (col*m_buffer_elements_max + cur_coloff)*sizeof(T);
			fseek(fout, file_offset, SEEK_SET);
			fwrite(m_outbuf+col*newrows, sizeof(T), newrows, fout);
		}
		cur_coloff += newrows;

		//printf("%lx -- %ld\n", cur_coloff, read_elements);
	}
}
	
template <typename T>
void 
ColumnSorter<T>::UnTranspose(FILE* fin, FILE* fout) {
	fseek(fin, 0, SEEK_END); // Move file pointer to the end
	size_t file_size = ftell(fin); // Get current position (which is the file size)
	rewind(fin);
	rewind(fout);
	// Number of columns calculated from file size
	size_t columns = (file_size+((m_buffer_elements_max*sizeof(T))-1))/m_buffer_bytes;


	printf( "Starting transpose: %ld columns\n", columns );
	size_t newrows = m_buffer_elements_max/columns;
	size_t row_remainder = m_buffer_elements_max%columns;
	printf( "row_remainder: %ld\n", row_remainder );

	for ( size_t col_buffer = 0; col_buffer < columns; col_buffer++ ) {
		// which offset within each column are we gathering elements from
		size_t percol_offset = newrows*col_buffer;

		for ( size_t c = 0; c < columns; c++ ) {
			size_t file_offset_elements = c*m_buffer_elements_max + percol_offset;
			fseek(fin, file_offset_elements*sizeof(T), SEEK_SET);
			/*size_t read_elements = */ fread(m_inbuf+(c*newrows), sizeof(T), newrows, fin);
		}

		memset(m_outbuf, 0xff, m_buffer_bytes);
		for ( size_t col = 0; col < columns; col++ ) {
			for ( size_t row = 0; row < newrows; row++ ) {
				size_t newoff = col*newrows + row;
				size_t curoff = row*columns + col; 
				m_outbuf[newoff] = m_inbuf[curoff];
			}
		}
		WriteFile(fout, false, columns*newrows);
	}
}


template <typename T>
void 
ColumnSorter<T>::InitFile(FILE* fout, size_t bytes) {
	fseek(fout, 0, SEEK_END); // Move file pointer to the end
	memset(m_inbuf, 0xff, m_buffer_bytes);
	while ( bytes > 0 ) {
		size_t write_words = 0;
		if ( bytes >= m_buffer_bytes ) {
			write_words = fwrite(m_inbuf, sizeof(T), m_buffer_elements_max, fout); 
		} else {
			write_words = fwrite(m_inbuf, sizeof(T), bytes/sizeof(T), fout); 
		}
		bytes -= write_words*sizeof(T);
	}
}


template <typename T>
bool ColumnSorter<T>::compareElementsLess(T a, T b) 
{
	// little endian, so MSB is in key[1]
	if ( a.key[1] != b.key[1] ) return a.key[1] < b.key[1];
	
	return a.key[0] < b.key[0];
}


#endif
