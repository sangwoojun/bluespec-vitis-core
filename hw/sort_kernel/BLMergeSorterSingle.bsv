import FIFO::*;
import FIFOF::*;
import BRAMFIFO::*;
import Vector::*;
import GetPut::*;


interface BLMergeSorterMemoryManagerIfc#(numeric type iCnt);
	// start one sweep reading "bytes" from "fromOff", divided into iCnt chunks,
	// write one output merged stream to "bytes" from "toOff"
	method Action startSweep(Bit#(32) bytes, Bit#(32) fromOff, Bit#(32) toOff, Bit#(8) activeCnt); 

	method Action readResp(Bit#(512) data);
	method ActionValue#(Tuple2#(Bit#(32),Bit#(32))) readReq; //addr, bytes
	interface Vector#(iCnt, Get#(Bit#(512))) reads;

	method Action write(Bit#(512) data);
	method ActionValue#(Bit#(512)) writeWord;
	method ActionValue#(Tuple2#(Bit#(32),Bit#(32))) writeReq; //addr, bytes

	method ActionValue#(Bit#(32)) done;
endinterface


// assumptions:
// data type (will be serialized later) can divide 64 bytes (512 bits) -- e.g., 8 bytes, 16 bytes, 32 bytes.
// (basically powers of 2)
// buffer size is multiple of "readBufferWords"


// todo: calling startsweep should cloean up previous sweep
module mkBLMergeSorterMemoryManager(BLMergeSorterMemoryManagerIfc#(iCnt));
	Reg#(Bool) running <- mkReg(False);

	Integer readBufferWords = 128;
	Reg#(Bit#(32)) inputBufferBytes <- mkReg(0);
	Reg#(Bit#(32)) outputBufferBytes <- mkReg(0);
	Reg#(Bit#(32)) inputBufferOff <- mkReg(0);
	Reg#(Bit#(32)) outputBufferOff <- mkReg(0);

	Reg#(Bit#(8)) activeSrcCnt <- mkReg(?);

	Vector#(iCnt, FIFO#(Bit#(512))) readBufferQs <- replicateM(mkSizedBRAMFIFO(readBufferWords)); // maybe larger?
	Vector#(iCnt, Reg#(Bit#(32))) readOffs <- replicateM(mkReg(0));
	Vector#(iCnt, FIFO#(Tuple2#(Bit#(8), Bit#(512)))) readRouteQs <- replicateM(mkFIFO);
	Vector#(iCnt, FIFOF#(Tuple3#(Bit#(8), Bit#(32), Bit#(32)))) readReqRouteQs <- replicateM(mkFIFOF);
	Vector#(iCnt, FIFOF#(Tuple3#(Bit#(8), Bit#(32), Bit#(32)))) readReqRouteInsQs <- replicateM(mkFIFOF);
	Vector#(iCnt, FIFO#(Bool)) startReadBufQs <- replicateM(mkFIFO);


	Vector#(iCnt, Get#(Bit#(512))) reads_;
	for ( Integer i = 0; i < valueOf(iCnt); i=i+1 ) begin
		Reg#(Bit#(16)) readInflightCntUp <- mkReg(0);
		Reg#(Bit#(16)) readInflightCntDn <- mkReg(0);
		rule routeReads;
			let d_ = readRouteQs[i].first;
			readRouteQs[i].deq;

			if ( tpl_1(d_) == fromInteger(i) ) begin
				readBufferQs[i].enq(tpl_2(d_));
			end else if ( i < valueOf(iCnt)-1) begin
				readBufferQs[i+1].enq(tpl_2(d_));
			end
		endrule
		rule routeReaReqs;
			if ( readReqRouteInsQs[i].notEmpty ) begin
				readReqRouteQs[i].enq(readReqRouteInsQs[i].first);
				readReqRouteInsQs[i].deq;
			end else if ( i < valueOf(iCnt)-1 ) begin
				if ( readReqRouteQs[i+1].notEmpty ) begin
					readReqRouteQs[i].enq(readReqRouteQs[i+1].first);
					readReqRouteQs[i+1].deq;
				end
			end
		endrule

		// check activeSrcCnt in case we are merging less than full number of buffers
		rule issueReadReq ( running && fromInteger(i) < activeSrcCnt); 
			if ( readInflightCntUp-readInflightCntDn < fromInteger(readBufferWords/2) 
				&& readOffs[i] < inputBufferBytes  ) begin

				readInflightCntUp <= readInflightCntUp + fromInteger(readBufferWords/2);
				readReqRouteInsQs[i].enq(tuple3(fromInteger(i), readOffs[i], fromInteger(readBufferWords/2)));
				readOffs[i] <= readOffs[i] + fromInteger(readBufferWords/2);

				//$write( "Memory Manager: issue read %d %x\n", i, readOffs[i] );
			end
		endrule

		reads_[i] = interface Get;
			method ActionValue#(Bit#(512)) get;
				readBufferQs[i].deq;
				readInflightCntDn <= readInflightCntDn + 1;

				return readBufferQs[i].first;
			endmethod
		endinterface;
	end


	FIFO#(Tuple2#(Bit#(8), Bit#(32))) readReqOrderQ <- mkSizedBRAMFIFO(fromInteger(valueOf(iCnt)*3));
	Reg#(Bit#(8)) curReadTarget <- mkReg(0);
	Reg#(Bit#(32)) curReadTargetLeft <- mkReg(0);
	FIFO#(Bit#(512)) readRespQ <- mkFIFO;
	rule calcReadTarget;
		readRespQ.deq;
		let r = readRespQ.first;
		if ( curReadTargetLeft == 0 ) begin
			readReqOrderQ.deq;
			let o = readReqOrderQ.first;
			curReadTarget <= tpl_1(o);
			curReadTargetLeft <= tpl_2(o)-1;

			readRouteQs[0].enq(tuple2(tpl_1(o),r));
		end else begin
			readRouteQs[0].enq(tuple2(curReadTarget,r));
			curReadTargetLeft <= curReadTargetLeft - 1;
		end
	endrule



	FIFO#(Bit#(512)) writeBuffer <- mkSizedBRAMFIFO(readBufferWords);
	FIFO#(Tuple2#(Bit#(32), Bit#(32))) writeReqQ <- mkFIFO;
	Reg#(Bit#(16)) bufferedCntDn <- mkReg(0);
	Reg#(Bit#(16)) bufferedCntUp <- mkReg(0);
	Reg#(Bit#(32)) curWriteAddrByte <- mkReg(0);

	FIFO#(Bit#(32)) doneQ <- mkFIFO;

	rule issueWriteCmd (bufferedCntUp-bufferedCntDn >= fromInteger(readBufferWords/2) && running);
		bufferedCntDn <= bufferedCntDn + fromInteger(readBufferWords/2);
		writeReqQ.enq(tuple2(curWriteAddrByte+outputBufferOff, fromInteger(readBufferWords*64/2)));

		let newAddr = curWriteAddrByte + fromInteger(readBufferWords*64/2);
		curWriteAddrByte <= newAddr;
		//$write( "writeCmd -> %x + %x\n", curWriteAddrByte, outputBufferOff );
		if ( newAddr >= outputBufferBytes ) begin
			running <= False;
			doneQ.enq(newAddr);
			//$write( "Merge sorter write done!\n" );
		end
	endrule


	
	method Action startSweep(Bit#(32) bytes, Bit#(32) fromOff, Bit#(32) toOff, Bit#(8) activeCnt) if ( !running );  // TODO safety
		inputBufferOff <= fromOff;
		outputBufferOff <= toOff;
		for ( Integer i = 0; i < valueOf(iCnt); i=i+1) readOffs[i] <= 0;
		outputBufferBytes <= bytes;
		//inputBufferBytes <= bytes/fromInteger(valueOf(iCnt));
		inputBufferBytes <= bytes/zeroExtend(activeCnt);
		running <= True;
		activeSrcCnt <= activeCnt;

		curWriteAddrByte <= 0;
	endmethod

	method Action readResp(Bit#(512) data);
		readRespQ.enq(data);
	endmethod
	method ActionValue#(Tuple2#(Bit#(32),Bit#(32))) readReq; //addr, bytes
		let req = readReqRouteQs[0].first;
		readReqRouteQs[0].deq;
		readReqOrderQ.enq(tuple2(tpl_1(req), tpl_3(req)));

		//$write("Memory read req from buffer %d to %d\n", tpl_1(req), tpl_2(req));

		// NOTE: above is all in words. We want to translate to bytes
		return tuple2(inputBufferOff + zeroExtend(tpl_1(req))*inputBufferBytes + (tpl_2(req)<<6), (tpl_3(req)<<6));
	endmethod
	interface reads = reads_;

	method Action write(Bit#(512) data);
		bufferedCntUp <= bufferedCntUp + 1;
		writeBuffer.enq(data);
	endmethod
	method ActionValue#(Bit#(512)) writeWord;
		writeBuffer.deq;
		return writeBuffer.first;
	endmethod
	method ActionValue#(Tuple2#(Bit#(32),Bit#(32))) writeReq; //addr, bytes
		writeReqQ.deq;
		return writeReqQ.first;
	endmethod
	
	method ActionValue#(Bit#(32)) done;
		doneQ.deq;
		return doneQ.first;
	endmethod
endmodule


interface BLMergeSorterSingleIfc#(numeric type iCnt, numeric type beatBits, numeric type keyBits, numeric type beats);
	interface Vector#(iCnt, Put#(Bit#(beatBits))) put;
	method Action runMerge(Bit#(32) elements, Bit#(32) reps, Bit#(8) activeCnt);
	method ActionValue#(Bit#(beatBits)) get;
endinterface

module mkBLMergeSorterSingle2 (BLMergeSorterSingleIfc#(2, beatBits, keyBits, beats))
	provisos(Add#(a__, keyBits, beatBits));
	FIFO#(Bit#(beatBits)) outQ <- mkFIFO;
	Vector#(2, FIFO#(Bit#(beatBits))) inQv <- replicateM(mkFIFO);

	//Reg#(Bit#(2)) activeSrcCnt <- mkReg(2);

	Integer iBeats = valueOf(beats);

	Vector#(2,Reg#(Bit#(32))) countLeft <- replicateM(mkReg(0));
	Reg#(Bit#(32)) repsLeft <- mkReg(0);
	Reg#(Bit#(32)) countPerReps <- mkReg(?);
	Reg#(Bit#(TAdd#(1,TLog#(beats)))) beatsLeft <- mkReg(0);
	Reg#(Bit#(1)) mergingBeatsFrom <- mkReg(0);

	//rule doMerge (countLeft != 0 || repsLeft != 0);
	rule startMergeBeat (repsLeft != 0 && beatsLeft == 0);
		if (countLeft[0] == 0 && countLeft[1] == 0 ) begin
			countLeft[0] <= countPerReps; // unnecessary if repsLeft == 1 (last one)
			countLeft[1] <= countPerReps;
			repsLeft <= repsLeft - 1;
			//if ( repsLeft <= 1024 ) begin
			//$write("Reps left %d\n", repsLeft);
			//end
		end else if (countLeft[0] == 0 ) begin
			countLeft[1] <= countLeft[1] - 1;
			inQv[1].deq;
			outQ.enq(inQv[1].first);
			beatsLeft <= fromInteger(iBeats-1);
			mergingBeatsFrom<= 1;
			//$write("1 -- %d ", countLeft[1]);
		end else if (countLeft[1] == 0 ) begin
			countLeft[0] <= countLeft[0] - 1;
			inQv[0].deq;
			outQ.enq(inQv[0].first);
			beatsLeft <= fromInteger(iBeats-1);
			mergingBeatsFrom <= 0;
			//$write("0 -- %d ", countLeft[0]);
		end else begin
			Bit#(keyBits) key0 = truncate(inQv[0].first);
			Bit#(keyBits) key1 = truncate(inQv[1].first);

			beatsLeft <= fromInteger(iBeats-1);
			if ( key0 < key1 ) begin
				outQ.enq(inQv[0].first);
				inQv[0].deq;
				mergingBeatsFrom <= 0;
				countLeft[0] <= countLeft[0] - 1;
				//$write("0");
			end else begin
				outQ.enq(inQv[1].first);
				inQv[1].deq;
				mergingBeatsFrom <= 1;
				countLeft[1] <= countLeft[1] - 1;
				//$write("1");
			end
		end
	endrule

	rule mergeBeats(beatsLeft != 0);
		outQ.enq(inQv[mergingBeatsFrom].first);
		inQv[mergingBeatsFrom].deq;
		beatsLeft <= beatsLeft - 1;
	endrule


	
	Vector#(2, Put#(Bit#(beatBits))) put_;
	for ( Integer i = 0; i < 2; i=i+1 ) begin
		put_[i] = interface Put;
			method Action put(Bit#(beatBits) data);
				inQv[i].enq(data);
			endmethod
		endinterface;
	end
	interface put = put_;
	method Action runMerge(Bit#(32) count, Bit#(32) reps, Bit#(8) activeCnt) if (repsLeft == 0 );
		countLeft[0] <= count * fromInteger(iBeats);
		if ( activeCnt >= 2 ) countLeft[1] <= count * fromInteger(iBeats);
		else countLeft[1] <= 0;

		countPerReps <= count * fromInteger(iBeats);
		repsLeft <= reps;
		//activeSrcCnt <= truncate(activeCnt);
	endmethod
	method ActionValue#(Bit#(beatBits)) get;
		outQ.deq;
		return outQ.first;
	endmethod
endmodule

module mkBLMergeSorterSingle (BLMergeSorterSingleIfc#(iCnt, beatBits, keyBits, beats))
	provisos(
		Log#(iCnt, iCntLg)
	);

	FIFO#(Bit#(beatBits)) outQ <- mkFIFO;

	if ( valueOf(iCnt) == 2 ) begin
	end






	Vector#(iCnt, Put#(Bit#(beatBits))) put_;
	for ( Integer i = 0; i < valueOf(iCnt); i=i+1 ) begin
		put_[i] = interface Put;
			method Action put(Bit#(beatBits) data);
				if ( valueOf(iCnt) == 1 ) begin
					outQ.enq(data);
				end
			endmethod
		endinterface;
	end
	interface put = put_;

	method Action runMerge(Bit#(32) count, Bit#(32) reps, Bit#(8) activeCnt);
	endmethod
	method ActionValue#(Bit#(beatBits)) get;
		outQ.deq;
		return outQ.first;
	endmethod

endmodule

