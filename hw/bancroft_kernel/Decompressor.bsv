import FIFO::*;
import FIFOF::*;
import Vector::*;


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


interface DecompressorIfc;
	method Action start(Bit#(32) param);
	method ActionValue#(Bool) done;
	interface Vector#(MemPortCnt, MemPortIfc) mem;
endinterface
module mkDecompressor( DecompressorIfc );
	Reg#(Bool) started <- mkReg(False);
	FIFO#(Bool) doneQ <- mkFIFO;

	SerializerIfc#(512, 16) serializer512b32b <- mkSerializer;
	//------------------------------------------------------------------------------------
	// Cycle Counter
	//------------------------------------------------------------------------------------
	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule
	//------------------------------------------------------------------------------------
	// Memory Read & Write
	//------------------------------------------------------------------------------------
	Vector#(MemPortCnt, FIFO#(MemPortReq)) readReqQs <- replicateM(mkSizedFIFO(1024));
	Vector#(MemPortCnt, FIFO#(Bit#(512))) readWordQs <- replicateM(mkSizedFIFO(1024));
	// Read compressed sequence
	Reg#(Bit#(64)) pcktAddrOff <- mkReg(0);
	rule sendReadReqPckt;
		readReqQs[0].enq(MemPortReq{addr:pcktAddrOff, bytes:64});
	endrule
	rule readWordPckt;
		readWordQs[0].deq;
		let r = readWordQs[0].first;
		serializer512b32b.put(r);
	endrule
	// Read reference sequence
	
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

