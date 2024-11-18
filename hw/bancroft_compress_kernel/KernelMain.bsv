import FIFO::*;
import FIFOF::*;
import Vector::*;

import BLShifter::*;
import BLHashFunctions::*;

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

function Vector#(64, Maybe#(Bit#(2))) encodeGenome512(Bit#(512) dat);
	Vector#(64, Maybe#(Bit#(2))) ret;
	Vector#(64, Bit#(8)) str = unpack(dat);
	for ( Integer i = 0; i < 64; i=i+1 ) begin
		ret[i] = case (str[i])
			8'h41: tagged Valid 0;           // 'A'
			8'h61: tagged Valid 0;           // 'a'
			8'h32: tagged Valid 1;           // 'C'
			8'h63: tagged Valid 1;           // 'c'
			8'h47: tagged Valid 2;           // 'G'
			8'h67: tagged Valid 2;           // 'g'
			8'h54: tagged Valid 3;           // 'T'
			8'h74: tagged Valid 3;           // 't'
		default: tagged Invalid;
		endcase;      
	end
	return ret;
endfunction

function Bit#(128) reverseComplement(Bit#(128) data);
	Vector#(64,Bit#(2)) orig = unpack(data);
	Vector#(64,Bit#(2)) rev;
	for ( Integer i = 0; i < 64; i=i+1 ) begin
		rev[63-i] = case (orig[i])
			0: 3;
			1: 2;
			2: 1;
			3: 0;
		endcase;
	end
	return pack(rev);
endfunction

function Bit#(8) getMostSignificantValid(Vector#(64, Maybe#(Bit#(2))) val);
	Bit#(64) mask = 0;
	for (Integer i = 0; i < 64; i=i+1 ) begin
		mask[i] = isValid(val[i])?1:0;
	end

	Bit#(8) ret = 0;

	if ( (mask & 64'hAAAAAAAAAAAAAAAA) != 0 ) ret[0] = 1;
	if ( (mask & 64'hCCCCCCCCCCCCCCCC) != 0 ) ret[1] = 1;
	if ( (mask & 64'hF0F0F0F0F0F0F0F0) != 0 ) ret[2] = 1;
	if ( (mask & 64'hFF00FF00FF00FF00) != 0 ) ret[3] = 1;
	if ( (mask & 64'hFFFF0000FFFF0000) != 0 ) ret[4] = 1;
	if ( (mask & 64'hFFFFFFFF00000000) != 0 ) ret[5] = 1;

	return ret;

endfunction

function Bit#(8) getLeastSignificantValid(Vector#(64, Maybe#(Bit#(2))) val);
	Bit#(64) mask = 0;
	for (Integer i = 0; i < 64; i=i+1 ) begin
		mask[63-i] = isValid(val[i])?1:0;
	end

	Bit#(8) ret = 0;

	if ( (mask & 64'hAAAAAAAAAAAAAAAA) != 0 ) ret[0] = 1;
	if ( (mask & 64'hCCCCCCCCCCCCCCCC) != 0 ) ret[1] = 1;
	if ( (mask & 64'hF0F0F0F0F0F0F0F0) != 0 ) ret[2] = 1;
	if ( (mask & 64'hFF00FF00FF00FF00) != 0 ) ret[3] = 1;
	if ( (mask & 64'hFFFF0000FFFF0000) != 0 ) ret[4] = 1;
	if ( (mask & 64'hFFFFFFFF00000000) != 0 ) ret[5] = 1;

	return 63-ret;

endfunction

interface BLMultiCycleCompactor#(numeric type bits);
	method Action put(Bit#(bits) data, Bit#(12) vbits); // let's just fix a number
	method ActionValue#(Bit#(bits)) get;
endinterface

module mkBLMultiCycleCompactor(BLMultiCycleCompactor#(bits))
	provisos(
		Add#(1, a__, bits),
		Add#(2, c__, TLog#(bits)),
		Add#(d__, bits, TMul#(2, bits)),
		Add#(e__, TLog#(bits), 12),
		Add#(1, f__, TMul#(2, bits)),
		Add#(bits, b__, 4096)
	);

	Reg#(Bit#(12)) curoff <- mkReg(0);

	FIFO#(Bit#(12)) bitsQ <- mkSizedFIFO(12);
	BLShiftIfc#(Bit#(TMul#(2,bits)), TLog#(bits), 2) shifter <- mkPipelinedShift(False);

	Reg#(Bit#(TMul#(2,bits))) tempval <- mkReg(0);
	Reg#(Bit#(12)) currecvoff <- mkReg(0);
	FIFO#(Bit#(bits)) outQ <- mkFIFO;
	rule compact;
		let newval = tempval | shifter.first;
		shifter.deq;
		let vbits = bitsQ.first;
		bitsQ.deq;

		if ( currecvoff+ vbits >= fromInteger(valueOf(bits)) ) begin
			currecvoff <= (currecvoff + vbits) - fromInteger(valueOf(bits));
			tempval <= (newval>>fromInteger(valueOf(bits)));
			outQ.enq(truncate(newval));
		end else begin
			currecvoff <= currecvoff + vbits;
			tempval <= newval;
		end
	endrule


	method Action put(Bit#(bits) data, Bit#(12) vbits); // let's just fix a number
		shifter.enq(zeroExtend(data), truncate(curoff));
		bitsQ.enq(vbits);
		if ( curoff + vbits >= fromInteger(valueOf(bits)) ) begin
			curoff <= (curoff + vbits) - fromInteger(valueOf(bits));
		end else begin
			curoff <= curoff + vbits;
		end
	endmethod
	method ActionValue#(Bit#(bits)) get;
		outQ.deq;
		return outQ.first;
	endmethod
endmodule

interface BLMultiCycleVectorMaybeShifter#(numeric type vectorsz, type elementType);
	method Action put(Vector#(vectorsz, Maybe#(elementType)) data, Bit#(8) shamt); // let's not go over 256
	method ActionValue#(Vector#(vectorsz, Maybe#(elementType))) get;
endinterface

module mkBLMultiCycleVectorMaybeShifter(BLMultiCycleVectorMaybeShifter#(vectorsz, elementType))
	provisos(
		Bits#(elementType, elementTypeSz),
		Add#(1, a__, vectorsz),
		Log#(vectorsz, vectorszbits)
	);

	Vector#(vectorszbits, FIFO#(Vector#(vectorsz, Maybe#(elementType)))) intermediateQs <- replicateM(mkFIFO);
	Vector#(vectorszbits, FIFO#(Bit#(8))) shamtQs <- replicateM(mkFIFO);

	FIFO#(Vector#(vectorsz, Maybe#(elementType))) outQ <- mkFIFO;

	for ( Integer i = 0; i < valueOf(vectorszbits); i=i+1 ) begin
		rule doShift;
			Vector#(vectorsz, Maybe#(elementType)) v = intermediateQs[i].first;
			intermediateQs[i].deq;
			let shamt = shamtQs[i].first;
			shamtQs[i].deq;
			
			Vector#(vectorsz, Maybe#(elementType)) vv = replicate(tagged Invalid);
			if ( shamt[0] == 1 ) begin
				for (Integer j = 0; j < valueOf(vectorsz)-(2**i); j=j+1 ) begin
					vv[j] = v[j+(2**i)];
				end
			end
			if ( i+1 < valueOf(vectorszbits) ) begin
				intermediateQs[i+1].enq(vv);
				shamtQs[i+1].enq(shamt>>1);
			end else begin
				outQ.enq(vv);
			end

		endrule
	end

	method Action put(Vector#(vectorsz, Maybe#(elementType)) data, Bit#(8) shamt);
		intermediateQs[0].enq(data);
		shamtQs[0].enq(shamt);
	endmethod
	method ActionValue#(Vector#(vectorsz, Maybe#(elementType))) get;
		outQ.deq;
		return outQ.first;
	endmethod
endmodule


module mkKernelMain(KernelMainIfc);
	Vector#(MemPortCnt, FIFO#(MemPortReq)) readReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(MemPortReq)) writeReqQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) writeWordQs <- replicateM(mkFIFO);
	Vector#(MemPortCnt, FIFO#(Bit#(512))) readWordQs <- replicateM(mkFIFO);

	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	FIFO#(Bit#(32)) startQ <- mkFIFO;
	Reg#(Bool) started <- mkReg(False);
	FIFOF#(Bool) doneQ <- mkFIFOF;

	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule

	////////////////////////////////////////////////////////////////////////// Likely don't touch above

	Reg#(Bit#(32)) readBytesReq <- mkReg(0);
	Reg#(Bit#(32)) doneTimeout <- mkReg(0);

	rule setDone ( started == True );
		if ( doneTimeout > 0 ) begin
			doneTimeout <= doneTimeout - 1;
		end
		if ( doneTimeout == 1 ) begin
			doneQ.enq(True);
			started <= False;
		end
	endrule
	
	rule getStart ( started == False );
		startQ.deq;
		Bit#(32) bytes = startQ.first;

		readBytesReq <= bytes;
		doneTimeout <= 0;
	endrule

	Reg#(Bit#(32)) readBytesOff <- mkReg(0);
	rule sendMemReadReq ( readBytesOff < readBytesReq );
		if ( readBytesReq + 64 >= readBytesReq ) begin
			readBytesOff <= readBytesReq;
			doneTimeout <= 1024*32; // conservative number to make sure everything is done
		end else begin
			readBytesOff <= readBytesOff + 64;
		end
		readReqQs[0].enq(MemPortReq{addr:zeroExtend(readBytesOff), bytes:64});
	endrule

	FIFO#(Bit#(512)) stringInQ <- mkFIFO;
	rule recvMemRead;
		let d = readWordQs[0].first;
		readWordQs[0].deq;
		stringInQ.enq(d);
	endrule

	FIFO#(Vector#(64,Maybe#(Bit#(2)))) encodedQ <- mkFIFO;
	rule encodeStringToBinary;
		stringInQ.deq;
		let d = stringInQ.first;
		let v = encodeGenome512(d);
		if ( isValid(v[63]) || isValid(v[0]) ) begin
			encodedQ.enq(v);
		end
	endrule

	BLMultiCycleVectorMaybeShifter#(64, Bit#(2)) shifter <- mkBLMultiCycleVectorMaybeShifter;
	rule startShift;
		encodedQ.deq;
		let v = encodedQ.first;
		//Bit#(8) msbl = getMostSignificantValid(v);
		Bit#(8) lsbl = getLeastSignificantValid(v);
		shifter.put(v, lsbl); // doesn't matter if lsbl == 0 // shifts by element
	endrule

	BLMultiCycleCompactor#(128) packer <- mkBLMultiCycleCompactor;
	rule startPack;
		let v <- shifter.get;
		Bit#(8) msbl = getMostSignificantValid(v);
		Vector#(64,Bit#(2)) vv;
		for ( Integer i = 0; i < 64; i=i+1 ) begin
			vv[i] = fromMaybe(?, v[i]);
		end
		packer.put(pack(vv), (zeroExtend(msbl)<<1)); // shifts by bit, hence the 1 shift for *2
	endrule

	Reg#(Bit#(256)) hashBuffer <- mkReg(0);
	Reg#(Bool) hashBufferInit <- mkReg(False);


	Vector#(4, HashFunction32Ifc#(Bit#(128))) hashFunctions1s <- replicateM(mkHashFunctionMurmur3_32_128_17);
	Vector#(4, HashFunction32Ifc#(Bit#(128))) hashFunctions2s <- replicateM(mkHashFunctionMurmur3_32_128_37);
	Vector#(4, HashFunction32Ifc#(Bit#(128))) hashFunctions1revs <- replicateM(mkHashFunctionMurmur3_32_128_17);
	Vector#(4, HashFunction32Ifc#(Bit#(128))) hashFunctions2revs <- replicateM(mkHashFunctionMurmur3_32_128_37);
	Vector#(4, FIFO#(Bit#(128))) hashWindowQs <- replicateM(mkFIFO);

	rule stackHashBuffer;
		let d <- packer.get;
		let nh = (hashBuffer>>128)|(zeroExtend(d)<<128); // little endian?
		hashBuffer <= nh;
		if ( !hashBufferInit ) begin
			for ( Integer i = 0; i < 4; i=i+1 ) begin
				Bit#(128) window = truncate(nh>>(i*32));
				hashWindowQs[i].enq(window);
				//hashFunctions1s[i].put(window);
			end
		end else begin
			hashBufferInit <= True;
		end
	endrule

	for ( Integer i = 0; i < 4; i=i+1 ) begin
		rule doHash;
			let window = hashWindowQs[i].first;
			hashWindowQs[i].deq;

			hashFunctions1s[i].put(window);
			hashFunctions2s[i].put(window);
			hashFunctions1revs[i].put(reverseComplement(window));
			hashFunctions2revs[i].put(reverseComplement(window));
		endrule
	end

	FIFO#(Vector#(4,Bit#(32))) hashResultsQ <- mkFIFO;
	Reg#(Bit#(2)) cycleHashesId <- mkReg(0);
	rule cycleHashes;
		cycleHashesId <= cycleHashesId + 1;
		Vector#(4,Bit#(32)) hashres;
		hashres[0] <- hashFunctions1s[cycleHashesId].get;
		hashres[1] <- hashFunctions2s[cycleHashesId].get;
		hashres[2] <- hashFunctions1revs[cycleHashesId].get;
		hashres[3] <- hashFunctions2revs[cycleHashesId].get;
		hashResultsQ.enq(hashres);
	endrule




	Reg#(Bit#(512)) memWriteStaging <- mkReg(0);
	Reg#(Bit#(2)) memWriteStagingIdx <- mkReg(0);

	Reg#(Bit#(32)) memWriteOffset <- mkReg(0);
	rule stageMemWrite;
		hashResultsQ.deq;
		let v = pack(hashResultsQ.first);
		let nd = (memWriteStaging>>128) | (zeroExtend(v)<<(512-128));

		if ( memWriteStagingIdx == 3 ) begin
			memWriteStagingIdx <= 0;
			writeReqQs[1].enq(MemPortReq{addr:zeroExtend(memWriteOffset), bytes:64});
			memWriteOffset <= memWriteOffset + 64;
			writeWordQs[1].enq(nd);
		end else begin
			memWriteStagingIdx <= memWriteStagingIdx + 1;
			memWriteStaging <= nd;
		end
	endrule






	////////////////////////////////////////////////////////////////////////// Likely don't touch below

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
		startQ.enq(param);
	endmethod
	method ActionValue#(Bool) done;
		doneQ.deq;
		return doneQ.first;
	endmethod
	interface mem = mem_;
endmodule

