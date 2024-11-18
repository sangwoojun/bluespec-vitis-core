import FIFO::*;
import FIFOF::*;
import Vector::*;

import BLMergeSorterSingle::*;

typedef 2 MemPortCnt;

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

typedef struct {
	Bit#(64) addr;
	Bit#(32) bytes;
} MemPortReq deriving (Eq,Bits);


typedef 16 MergeSrcCount;
typedef 48 KeyBits;
typedef 48 ValBits;
typedef 29 BufferBytesSz;
typedef TExp#(BufferBytesSz) BufferBytes;

module mkKernelMain(KernelMainIfc);
	Vector#(MemPortCnt, FIFO#(MemPortReq)) readReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(MemPortReq)) writeReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) writeWordQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) readWordQs <- replicateM(mkFIFO);

	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	Reg#(Bool) started <- mkReg(False);
	Reg#(Bit#(32)) bytesToRead <- mkReg(0);
	Reg#(Bit#(32)) bytesReq <- mkReg(0);

	Reg#(Bit#(32)) startCnt <- mkReg(0);

	FIFO#(Bit#(512)) resultQ <-mkFIFO;
	FIFOF#(Bool) doneQ <- mkFIFOF;

	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule

	//////////////////////////////////////////////////////////////////////////

	BLMergeSorterSingleIfc#(MergeSrcCount, Bit#(KeyBits), Bit#(ValBits)) mergeSorter <- mkBLMergeSorterSingle;



	Reg#(Bit#(64)) readReqOff <- mkReg(0);
	Reg#(Bit#(64)) writeReqOff <- mkReg(0);

	rule sendReadReq (bytesToRead > 0);
		if ( bytesToRead > 64 ) bytesToRead <= bytesToRead - 64;
		else bytesToRead <= 0;

		readReqQs[0].enq(MemPortReq{addr:zeroExtend(readReqOff), bytes:64});
		readReqOff <= readReqOff+ 64;
	endrule

    // This is a simple calculation for testing
	rule addNumber;
		let d = readWordQs[0].first;
		readWordQs[0].deq;

		d[63:32] = bytesToRead;
		d[31:0] = startCnt;

		resultQ.enq(d);
	endrule

	rule writeResult;
	    let d = resultQ.first;
	    resultQ.deq;

		writeReqQs[1].enq(MemPortReq{addr:writeReqOff, bytes:64});
		writeReqOff <= writeReqOff + 64;
		writeWordQs[1].enq(d);
	endrule

	rule checkDone ( started );
	    //if (writeReqOff != 0 && readReqOff == writeReqOff) begin
	    if (writeReqOff != 0 && zeroExtend(bytesReq) == writeReqOff) begin
			doneQ.enq(True);
			bytesReq <= 0;
			started <= False;
	    end
	endrule

	//////////////////////////////////////////////////////////////////////////

	Reg#(Bool) kernelDone <- mkReg(False);
	
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
		started <= True;
		bytesToRead <= param;
		bytesReq <= param;
		readReqOff <= 0;
		writeReqOff <= 0;
		startCnt <= startCnt + 1;
	endmethod
	method ActionValue#(Bool) done;
		doneQ.deq;
		return doneQ.first;
	endmethod
	interface mem = mem_;
endmodule

