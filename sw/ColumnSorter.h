#ifndef __COLUMNSORTER_H__
#define __COLUMNSORTER_H__

#include <iostream>
#include <cstring>
#include <vector>
#include <algorithm>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <stdint.h>

// XRT includes
#include "xrt/xrt_bo.h"
#include <experimental/xrt_xclbin.h>
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"


template <typename T>
class ColumnSorter {
public:
	ColumnSorter(size_t buffer_bytes, int threads);

	size_t ReadFile(FILE* fin, bool half=false);
	size_t WriteFile(FILE* fout, bool half=false, size_t elements = 0);
	void Sort();

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

};

template <typename T>
ColumnSorter<T>::ColumnSorter(size_t buffer_bytes, int threads) {
	m_inbuf = (T*)malloc(buffer_bytes);
	m_outbuf = (T*)malloc(buffer_bytes);
	m_buffer_bytes = buffer_bytes;
	m_buffer_elements_max = buffer_bytes/sizeof(T);
	printf( "Created sorter with buffer size %ld (%ld elements)\n", m_buffer_bytes, m_buffer_elements_max );
	printf( "Size of elements: %ld bytes\n", sizeof(T) );
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
	//printf( "Writing %lx elements\n", write_elements );
	return fwrite(m_outbuf, sizeof(T), write_elements, fout);
}

template <typename T>
void
ColumnSorter<T>::Sort() {
	std::sort(m_inbuf, m_inbuf+m_buffer_elements_max, compareElementsLess);
	memcpy(m_outbuf, m_inbuf, m_buffer_bytes);
}

template <typename T>
size_t 
ColumnSorter<T>::SortAllColumns(FILE* fin, FILE* fout, bool shift) {
	fseek(fin, 0, SEEK_END); // Move file pointer to the end
	size_t file_size = ftell(fin); // Get current position (which is the file size)
	rewind(fin);
	rewind(fout);

	printf( "Sorting all columns of file size %ld\n", file_size );

	T last_val = {0};
	uint64_t mismatch_count = 0;

	while (!feof(fin)) {
		size_t cur_off = ftell(fin);
		if ( shift && ( cur_off == 0 || cur_off >= file_size-(m_buffer_bytes/2)  ) ) {
			size_t read_elements = this->ReadFile(fin, true);
			if ( read_elements == 0 ) continue;
			memcpy(m_outbuf, m_inbuf, (sizeof(T)*m_buffer_elements_max)/2);
			
			this->WriteFile(fout, true);
			
			for ( size_t i = 0; i < m_buffer_elements_max/2; i++ ) {
				if ( compareElementsLess( m_inbuf[i], last_val) ) {
					mismatch_count ++;
					printf( "Mismatch --%lx: %x %x ~~ %x %x\n",i, last_val.key[1], last_val.key[0], m_inbuf[i].key[1], m_inbuf[i].key[0] );
				}
				last_val = m_inbuf[i];
			}
			
			printf( "Doing half reads\n" );
		} else {
			size_t read_elements = this->ReadFile(fin);
			if ( read_elements == 0 ) continue;
			this->Sort();
			this->WriteFile(fout);

			if ( read_elements != m_buffer_elements_max ) {
				printf( "Read element count not full buffer! %ld %ld\n", read_elements, m_buffer_elements_max );
			}
			for ( size_t i = 0; i < m_buffer_elements_max; i++ ) {
				if ( compareElementsLess( m_outbuf[i], last_val) ) {
					mismatch_count ++;
					printf( "Mismatch --%lx: %x %x (%lx) ~~ %x %x\n",i, last_val.key[1], last_val.key[0],
						*((uint64_t*)(last_val.key)),
						m_outbuf[i].key[1], m_outbuf[i].key[0] );

				}
				last_val = m_outbuf[i];
			}
		}
	}
	size_t fout_bytes = ftell(fout); 
	printf( "Sort phase done with %ld mismatches -- %ld bytes\n", mismatch_count, fout_bytes );
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

	if ( file_size_out < file_size ) {
		InitFile(fout, file_size-file_size_out);
	}
	rewind(fout);
	
	// Number of columns calculated from file size
	size_t columns = (file_size+((m_buffer_elements_max*sizeof(T))-1))/m_buffer_bytes;


	size_t cur_coloff = 0;

	printf( "Starting transpose: %ld columns\n", columns );
	
	while (!feof(fin)) {
		size_t read_elements = this->ReadFile(fin);
		if ( read_elements == 0 ) continue;

		// column size may not be multiple of columns!
		// TODO leftover elements (<columns) need to be handled separately
		size_t newrows = m_buffer_elements/columns;
		size_t row_remainder = m_buffer_elements%columns;

		printf( "row_remainder: %ld -- TODO these elements should be handled separately\n", row_remainder );

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

		printf("%lx -- %ld\n", cur_coloff, read_elements);
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
			size_t read_elements = fread(m_inbuf+(c*newrows), sizeof(T), newrows, fin);
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
