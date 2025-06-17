import FIFO::*;
import FIFOF::*;
import Vector::*;

import BRAM::*;
import BRAMFIFO::*;

import Serializer::*;
import BLShifter::*;


typedef 1 DataCntTotal512b_X;
typedef 1 DataCntTotal512b_Y;

typedef 0 MemPortAddrStart_0;
typedef 0 MemPortAddrStart_1;
typedef 0 ResultAddrStart;

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
	FIFO#(Bool) startQ <- mkFIFO;
	FIFO#(Bool) doneQ  <- mkFIFO;

	FIFO#(Bit#(512)) dataQ_X <- mkSizedBRAMFIFO(8);
	FIFO#(Bit#(512)) dataQ_Y <- mkSizedBRAMFIFO(8);
	FIFO#(Bit#(512)) resultQ <- mkSizedBRAMFIFO(8);

	Reg#(Bool) started <- mkReg(False);
	Reg#(Bool) reqReadDataOn_X <- mkReg(False);
	Reg#(Bool) readDataOn_X <- mkReg(False);
	Reg#(Bool) reqReadDataOn_Y <- mkReg(False);
	Reg#(Bool) readDataOn_Y <- mkReg(False);
	Reg#(Bool) reqWriteResultOn <- mkReg(False);
	Reg#(Bool) writeResultOn <- mkReg(False);
	//------------------------------------------------------------------------------------
	// [Cycle Counter]
	//------------------------------------------------------------------------------------
	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	Reg#(Bit#(32)) cycleStart <- mkReg(0);
	Reg#(Bit#(32)) cycleDone <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule
	//------------------------------------------------------------------------------------
	// [System Start]
	//------------------------------------------------------------------------------------
	rule systemStart( !started );
		startQ.deq;
		started <= True;
		reqReadDataOn_X	<= True;
		reqReadDataOn_Y	<= True;
		reqWriteResultOn <= True;
	endrule
	//------------------------------------------------------------------------------------
	// [Memory Read]
	//------------------------------------------------------------------------------------
	Vector#(MemPortCnt, FIFO#(MemPortReq)) readReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(MemPortReq)) writeReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) writeWordQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) readWordQs <- replicateM(mkFIFO);

	// Read the example data 'X'		[MEMPORT 0]
	Reg#(Bit#(32)) reqReadDataCnt_X <- mkReg(0);
	Reg#(Bit#(64)) memPortAddr_0 <- mkReg(fromInteger(valueOf(MemPortAddrStart_0)));
	rule reqReadDataX( reqReadDataOn_X );
		readReqQs[0].enq(MemPortReq{addr:memPortAddr_0, bytes:64});

		if ( reqReadDataCnt_X + 1 == fromInteger(valueOf(DataCntTotal512b_X)) ) begin
			memPortAddr_0 <= 0;
			reqReadDataCnt_X <= 0;
			reqReadDataOn_X	<= False;
		end else begin
			memPortAddr_0 <= memPortAddr_0 + 64;
			reqReadDataCnt_X <= reqReadDataCnt_X + 1;
		end

		readDataOn_X <= True;
	endrule
	Reg#(Bit#(32)) readDataCnt_X <- mkReg(0);
	rule readDataX( readDataOn_X );
		readWordQs[0].deq;
		let data = readWordQs[0].first;
	
		dataQ_X.enq(data);
		
		if ( readDataCnt_X + 1 == fromInteger(valueOf(DataCntTotal512b_X)) ) begin
			readDataCnt_X <= 0;
			readDataOn_X <= False;
			$write( "\033[1;32mCycle %u\033[0m -> \033[1;33m[KernelMain]\033[0m : Reading data X is done!\n", cycleCounter );
		end else begin
			readDataCnt_X <= readDataCnt_X + 1;
		end

		cycleStart <= cycleCounter;
	endrule

	// Read the example data 'Y'		[MEMPORT 1]
	Reg#(Bit#(32)) reqReadDataCnt_Y <- mkReg(0);
	Reg#(Bit#(64)) memPortAddr_1 <- mkReg(fromInteger(valueOf(MemPortAddrStart_1)));
	rule reqReadDataY( reqReadDataOn_Y );
		readReqQs[1].enq(MemPortReq{addr:memPortAddr_1, bytes:64});

		if ( reqReadDataCnt_Y + 1 == fromInteger(valueOf(DataCntTotal512b_Y)) ) begin
			memPortAddr_1 <= 0;
			reqReadDataCnt_Y <= 0;
			reqReadDataOn_Y	<= False;
		end else begin
			memPortAddr_1 <= memPortAddr_1 + 64;
			reqReadDataCnt_Y <= reqReadDataCnt_Y + 1;
		end

		readDataOn_Y <= True;
	endrule
	Reg#(Bit#(32)) readDataCnt_Y <- mkReg(0);
	rule readDataY( readDataOn_Y );
		readWordQs[1].deq;
		let data = readWordQs[1].first;
	
		dataQ_Y.enq(data);
		
		if ( readDataCnt_Y + 1 == fromInteger(valueOf(DataCntTotal512b_Y)) ) begin
			readDataCnt_Y <= 0;
			readDataOn_Y <= False;
			reqWriteResultOn <= True;
			$write( "\033[1;32mCycle %u\033[0m -> \033[1;33m[KernelMain]\033[0m : Reading data Y is done!\n", cycleCounter );
		end else begin
			readDataCnt_Y <= readDataCnt_Y + 1;
		end
	endrule
	//------------------------------------------------------------------------------------
	// Example Logic
	//------------------------------------------------------------------------------------
	rule example_1;
		dataQ_X.deq;
		dataQ_Y.deq;
		let x = dataQ_X.first;
		let y = dataQ_Y.first;

		Bit#(512) r = x + y;
		
		$write( "\033[1;32mCycle %u\033[0m -> \033[1;33m[KernelMain]\033[0m : Running example is done!\n", cycleCounter );
		$write( "\033[1;32mCycle %u\033[0m -> \033[1;33m[KernelMain]\033[0m : %lu\n", r );

		resultQ.enq(r);
	endrule
	//------------------------------------------------------------------------------------
	// [Memory Write] & [System Finish]
	// Memory Writer is going to use HBM[1] 
	// 536,870,912 
	//------------------------------------------------------------------------------------
	rule reqWriteResult( reqWriteResultOn );
		writeReqQs[1].enq(MemPortReq{addr:fromInteger(valueOf(ResultAddrStart)), bytes:64});
		
		reqWriteResultOn <= False;
		writeResultOn <= True;
	endrule
	rule writeResult( writeResultOn );
		resultQ.deq;
		let r = resultQ.first;
		writeWordQs[1].enq(r);

		// System Finish
		writeResultOn <= False;
		started	<= False;
		doneQ.enq(True);
	endrule
	//------------------------------------------------------------------------------------
	// Interface
	//------------------------------------------------------------------------------------
	Vector#(MemPortCnt, MemPortIfc) mem_;
	for (Integer i = 0; i < valueOf(MemPortCnt); i = i + 1) begin
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
		startQ.enq(True);
	endmethod
	method ActionValue#(Bool) done;
		doneQ.deq;
		return doneQ.first;
	endmethod
	interface mem = mem_;
endmodule
