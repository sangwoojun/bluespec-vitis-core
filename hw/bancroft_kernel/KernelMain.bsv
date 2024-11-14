import FIFO::*;
import FIFOF::*;
import Vector::*;

import Decompressor::*;


typedef 128 Kval;
typedef 128 Wval;
typedef 2 MemPortCnt;
typedef struct {
	Bit#(64) addr;
	Bit#(32) bytes;
} MemPortReq deriving (Eq,Bits);


interface MemPortIfc;
	method ActionValue#(MemPortReq) readReq;
	method ActionValue#(MemPortReq) writeReq;
	method ActionValue#(Bit#(512)) writeWord;
	method Action readWord(Bit#(512) word);
endinterface


interface KernelMainIfc;
	method Action start(Bit#(32) param);
	method ActionValue#(Bool) done;
	interface Vector#(MemPortCnt, MemPortIfc) mem;
endinterface
module mkKernelMain(KernelMainIfc);
	Reg#(Bool) started <- mkReg(False);
	FIFO#(Bool) startQ <- mkFIFO;
	FIFO#(Bool) doneQ <- mkFIFO;

	DecompressorIfc decompressor <- mkDecompressor;
	//------------------------------------------------------------------------------------
	// Cycle Counter
	//------------------------------------------------------------------------------------
	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule
	//------------------------------------------------------------------------------------
	// Start & Finish
	//------------------------------------------------------------------------------------
	rule relayStart( !started );
		startQ.deq;
		decompressor.start(startQ.first);
		started <= True;
	endrule
	rule relayFinish( started );
		Bool done <- decompressor.done;
		if ( done ) begin
			doneQ.enq(True);
			started <= False;
		end
	endrule
	//------------------------------------------------------------------------------------
	// Memory Read & Write
	//------------------------------------------------------------------------------------
	Vector#(MemPortCnt, FIFO#(MemPortReq)) readReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(MemPortReq)) writeReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) writeWordQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) readWordQs <- replicateM(mkFIFO);
	for ( Integer i = 0; i < valueOf(MemPortCnt); i = i + 1 ) begin
		rule relayReadReq;
			let r <- decompressor.mem[i].readReq;
			readReqQs[i].enq(MemPortReq{addr:r.addr, bytes:r.bytes});
		endrule
		rule relayWriteReq;
			let r <- decompressor.mem[i].writeReq;
			writeReqQs[i].enq(MemPortReq{addr:r.addr, bytes:r.bytes});
		endrule
		rule relayWriteWord;
			let r <- decompressor.mem[i].writeWord;
			writeWordQs[i].enq(r);
		endrule
		rule relayReadWord;
			readWordQs[i].deq;
			let r = readWordQs[i].first;
			decompressor.mem[i].readword(r);
		endrule
	end
	//------------------------------------------------------------------------------------
	// Interface
	//------------------------------------------------------------------------------------
	Vector#(MemPortCnt, MemPortIfc) mem_;
	for (Integer i = 0; i < valueOf(MemPortCnt); i=i+1) begin
		mem_[i] = interface MemPortIfc;
			method ActionValue#(MemPortReq) readReq;
				readReqQs[i].deq;
				return readReqQs[i].first;
			endmethod
			method ActionValue#(MemPortReq) writeReq;
				writeReqQs[i].deq;
				return writeReqQs[i].first;
			endmethod
			method ActionValue#(Bit#(512)) writeWord;
				writeWordQs[i].deq;
				return writeWordQs[i].first;
			endmethod
			method Action readWord(Bit#(512) word);
				readWordQs[i].enq(word);
			endmethod
		endinterface;
	end
	method Action start(Bit#(32) param) if ( started == False );
		startQ.enq(param);
	endmethod
	method ActionValue#(Bool) done;
		doneQ.deq;
		return doneQ.first;
	endmethod
	interface mem = mem_;
endmodule

