import FIFO::*;
import FIFOF::*;
import GetPut::*;
import Vector::*;

import BLMergeSorterSingle::*;
import Serializer::*;

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


typedef 1 MergeSrcCountLg;
typedef TExp#(MergeSrcCountLg) MergeSrcCount;
typedef 32 KeyBits;
typedef 32 ValBits;
//typedef 27 BufferBytesSz;
typedef 17 BufferBytesSz;
typedef TExp#(BufferBytesSz) BufferBytes;
typedef TAdd#(KeyBits,ValBits) KVBits;
typedef TDiv#(512,KVBits) KVSerializerMult;

module mkKernelMain(KernelMainIfc);
	Integer iBufferBytes = valueOf(BufferBytes);
	Integer iWordBytes = (valueOf(KeyBits)+valueOf(ValBits))/8;
	Integer iMergeSrcCount = valueOf(MergeSrcCount);

	Integer iMergeSrcCountLog = valueOf(MergeSrcCountLg);
	
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

	FIFO#(Bool) startQ <- mkFIFO;

	BLMergeSorterMemoryManagerIfc#(MergeSrcCount) mergeSorterMemoryMan <- mkBLMergeSorterMemoryManager;
	BLMergeSorterSingleIfc#(MergeSrcCount, TAdd#(KeyBits,ValBits), KeyBits, 1)  mergeSorter <- mkBLMergeSorterSingle2;
	Vector#(MergeSrcCount, SerializerIfc#(512, KVSerializerMult)) readSerializers <- replicateM(mkSerializer);

	for ( Integer i = 0; i < valueOf(MergeSrcCount); i=i+1 ) begin
		rule relayRead;
			let d <- mergeSorterMemoryMan.reads[i].get;
			readSerializers[i].put(d);
		endrule
		rule relayRead2;
			let d <- readSerializers[i].get;
			mergeSorter.put[i].put(d);
		endrule
	end
	rule relayMemReq;
		let r <- mergeSorterMemoryMan.readReq;
		readReqQs[0].enq(MemPortReq{addr:zeroExtend(tpl_1(r)), bytes:tpl_2(r)});
	endrule
	rule relayMemResp;
		readWordQs[0].deq;
		let d = readWordQs[0].first;
		mergeSorterMemoryMan.readResp(d);
	endrule

	Reg#(Bit#(32)) sortedCount <- mkReg(0);
	DeSerializerIfc#(KVBits, KVSerializerMult) writeDeserializer <- mkDeSerializer;
	rule relaySortDone;
		let v <- mergeSorter.get;
		writeDeserializer.put(v);
		sortedCount <= sortedCount + 1;
		
		/*
		if ( sortedCount < 128 ) begin
			Bit#(32) vv = truncate(v);
			if ( sortedCount[0] == 0 ) $write("%x [%x ", sortedCount, vv);
			else  $write("%x]\n", vv);
		end
		*/

		//if ( (sortedCount & 32'hffff) == 0 ) $write( "Sorted %x\n", sortedCount );
		//$write("Sorted value %x\n", v);
	endrule
	rule relayMemWrite;
		let d <- writeDeserializer.get;
		mergeSorterMemoryMan.write(d);
	endrule

	rule relayMemWriteCmd;
		let r <- mergeSorterMemoryMan.writeReq;
		writeReqQs[1].enq(MemPortReq{addr:zeroExtend(tpl_1(r)), bytes:tpl_2(r)});
	endrule
	rule relayMemWriteWord;
		let d <- mergeSorterMemoryMan.writeWord;
		writeWordQs[1].enq(d);
	endrule

	Reg#(Bit#(32)) stride <- mkReg(0);
	Reg#(Bit#(32)) reps <- mkReg(fromInteger(iBufferBytes/iWordBytes/iMergeSrcCount));
	rule procStart (stride == 0);
		startQ.deq;
		startCnt <= startCnt + 1;
		stride <= 1;
		reps <= fromInteger(iBufferBytes/iWordBytes/iMergeSrcCount);
	endrule

	Reg#(Bit#(16)) runIdx <- mkReg(0);
	Reg#(Bit#(8)) activeSourceCnt <- mkReg(fromInteger(iMergeSrcCount));
	FIFO#(Bool) isDoneQ <- mkFIFO;
	rule doStride (stride != 0);

		if ( reps == 0 ) begin
			// if we're on the last rep (reps were made to zero if last reps <= src ount)
			stride <= 0;
			activeSourceCnt <= fromInteger(iMergeSrcCount);
			runIdx <= 0;
			isDoneQ.enq(True);
		end else begin
			stride <= (stride<<iMergeSrcCountLog);

			runIdx <= runIdx + 1;

			if ( reps <= fromInteger(iMergeSrcCount) ) begin
				activeSourceCnt <= truncate(reps);
				reps <= 0;
			end else begin
				activeSourceCnt <= fromInteger(iMergeSrcCount);
				reps <= (reps>>iMergeSrcCountLog);
			end
			isDoneQ.enq(False);
		end


		Bit#(32) roundUpReps = reps;
		if ( roundUpReps == 0 ) roundUpReps = 1;

		$write( "Calling startsweep and runmerge %d %d x %d @ %d\n", runIdx, stride, roundUpReps, activeSourceCnt );

		if ( runIdx[0] == 0 ) begin
			mergeSorterMemoryMan.startSweep(fromInteger(valueOf(BufferBytes)), 0, fromInteger(valueOf(BufferBytes)), activeSourceCnt);
			mergeSorter.runMerge(stride,roundUpReps, activeSourceCnt);
		end else begin
			mergeSorterMemoryMan.startSweep(fromInteger(valueOf(BufferBytes)), fromInteger(valueOf(BufferBytes)),0, activeSourceCnt);
			mergeSorter.runMerge(stride,roundUpReps, activeSourceCnt);
		end

		//mergeSorterMemoryMan.startSweep(fromInteger(valueOf(BufferBytes)), 0, fromInteger(valueOf(BufferBytes)));
		//mergeSorter.runMerge(1,fromInteger(iBufferBytes/iWordBytes/iMergeSrcCount));
	endrule

	rule checkDone;
		let d <- mergeSorterMemoryMan.done;
		let isLastReq = isDoneQ.first;
		isDoneQ.deq;

		if (isLastReq) doneQ.enq(True);
	endrule

/*

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
*/

/*
	rule checkDone ( started );
	    //if (writeReqOff != 0 && readReqOff == writeReqOff) begin
	    if (writeReqOff != 0 && zeroExtend(bytesReq) == writeReqOff) begin
			doneQ.enq(True);
			bytesReq <= 0;
			started <= False;
	    end
	endrule
	*/

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
		startQ.enq(True);
		started <= True;
		$write( "Kernel start called\n" );
	endmethod
	method ActionValue#(Bool) done;
		doneQ.deq;
		return doneQ.first;
	endmethod
	interface mem = mem_;
endmodule

/*
	Reg#(Bit#(32)) stride <- mkReg(1);
	Reg#(Bit#(32)) wordsLeft <- mkReg(0);
	rule issueMergeCmd (stride <= fromInteger(valueOf(BufferBytes)/8/valueOf(MergeSrcCount)) && wordsLeft == 0);
		mergeSorter.runMerge(stride,fromInteger(valueOf(BufferBytes)/8/valueOf(MergeSrcCount))/stride);
		$write("Issuing Merge: %d %d\n", stride,fromInteger(valueOf(BufferBytes)/8/valueOf(MergeSrcCount))/stride );
		wordsLeft  <= fromInteger(valueOf(BufferBytes)/8/valueOf(MergeSrcCount));
	endrule
	rule memReads (wordsLeft > 0);
		Bit#(64) = bdpi_
		wordsLeft <= wordsLeft - 1;
	endrule

*/
