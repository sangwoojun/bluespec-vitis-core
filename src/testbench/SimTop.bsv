import FIFO::*;
import Vector::*;
import KernelMain::*;


//import "BDPI" function Action bdpi_write_word(Bit#(32) buffer, Bit#(64) addr, Bit#(64) data0, Bit#(64) data1, Bit#(64) data2, Bit#(64) data3, Bit#(64) data4, Bit#(64) data5, Bit#(64) data6, Bit#(64) data7, Bit#(32) tag);
import "BDPI" function Action bdpi_write_word(Bit#(32) buffer, Bit#(64) addr, Bit#(32) data, Bit#(32) tag);
import "BDPI" function Bit#(64) bdpi_read_word(Bit#(32) buffer, Bit#(64) addr);

module mkSimTop(Empty);
	KernelMainIfc kernelMain <- mkKernelMain;
	rule checkStart;
		//if ( axi4control.ap_start ) kernelMain.start(axi4control.scalar00);
	endrule
	rule checkDone;
		if ( kernelMain.done ) begin
			//axi4control.ap_done();
		end
	endrule
	for ( Integer i = 0; i < valueOf(MemPortCnt); i=i+1 ) begin
		Reg#(Bit#(64)) memReadAddr <- mkReg(0);
		Reg#(Bit#(32)) memReadBytesLeft <- mkReg(0);
		rule relayReadReq00 ( memReadBytesLeft == 0 );
			let r <- kernelMain.mem[i].readReq;
			memReadAddr <= r.addr;
			memReadBytesLeft <= r.bytes;
		endrule

		Reg#(Bit#(64)) memWriteAddr <- mkReg(0);
		Reg#(Bit#(32)) memWriteBytesLeft <- mkReg(-1);
		rule relayWriteReq;
			let r <- kernelMain.mem[i].writeReq;
			memWriteAddr <= r.addr;
			memWriteBytesLeft <= r.bytes;
		endrule


		Reg#(Bit#(32)) memWriteTag <- mkReg(0);
		rule relayWriteWord ( memWriteBytesLeft > 0 );
			let r <- kernelMain.mem[i].writeWord;
			for ( Integer j = 0; j < 512/32; j=j+1 ) begin
				Bit#(32) w = truncate(r>>(j*32));
				bdpi_write_word(fromInteger(i), memWriteAddr + fromInteger(j*4), w, memWriteTag);
			end
			/*
			bdpi_write_word(fromInteger(i), memWriteAddr, 
				wvec[0], wvec[1], wvec[2], wvec[3], 
				wvec[4], wvec[5], wvec[6], wvec[7]
				, memWriteTag);
			*/
			memWriteTag <= memWriteTag + 1;
			memWriteAddr <= memWriteAddr + 64;
			if ( memWriteBytesLeft >= 64 ) begin
				memWriteBytesLeft <= memWriteBytesLeft - 64;
			end else begin
				memWriteBytesLeft <= 0;
			end
		endrule
		rule relayReadWord ( memReadBytesLeft > 0 );
			Bit#(512) rword = 0;
			for ( Integer j = 0; j < 512/32; j=j+1 ) begin
				let d = bdpi_read_word(fromInteger(i), memReadAddr+fromInteger(j*4));
				rword = rword | (zeroExtend(d)<<(j*32));
			end
			memReadAddr <= memReadAddr + 64;
			if ( memReadBytesLeft >= 64 ) begin
				memReadBytesLeft <= memReadBytesLeft - 64;
			end else begin
				memReadBytesLeft <= 0;
			end
			kernelMain.mem[i].readWord(rword);
			//$write( "Mem read from %x %x\n", memReadAddr, rword );
		endrule
	end

endmodule	
