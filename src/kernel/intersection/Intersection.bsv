import FIFO::*;
import FIFOF::*;
import Vector::*;
import BRAM::*;
import BRAMFIFO::*;

interface StreamIntersectionIfc;
	method Action queryStream(TuplePacked data);
	method Action dataStream(TuplePacked data);
	method ActionValue#(TuplePacked) out; 
endinterface

typedef 8 TupleWords;
typedef 32 WordBits;
typedef Bit#(32) Word;
typedef TMul#(TupleWords,WordBits) TupleBits;
typedef Bit#(TupleBits) TuplePacked;

typedef struct {
	Bit#(16) words;
	// bloomfilter?
} ListInfo deriving (Eq,Bits);

module mkStreamIntersection#(Integer blockTuples) (StreamIntersectionIfc);
	Integer tupleWords = valueOf(TupleWords);

	FIFO#(TuplePacked) dataStreamQ <- mkSizedBRAMFIFO(blockTuples);
	FIFO#(TuplePacked) dataStreamInQ <- mkFIFO;
	FIFO#(ListInfo) dataStreamInfoQ <- mkSizedBRAMFIFO(blockTuples/8); // random number for now
	FIFO#(TuplePacked) queryStreamQ <- mkSizedBRAMFIFO(blockTuples);
	FIFO#(TuplePacked) queryStreamInQ <- mkFIFO;
	FIFO#(ListInfo) queryStreamInfoQ <- mkSizedBRAMFIFO(blockTuples/8); // random number for now

	FIFO#(ListInfo) intersectedStreamInfoQ <- mkSizedBRAMFIFO(blockTuples/8);
	FIFO#(TuplePacked) intersectedStreamQ <- mkSizedBRAMFIFO(blockTuples);

	Reg#(Bit#(16)) curDataPageOff <- mkReg(0);
	Reg#(Bit#(32)) dataTuplesCnt <- mkReg(0);
	Reg#(Bool) dataBlockLoaded <- mkReg(False);
	rule separateDataHeader (!dataBlockLoaded);
		dataStreamInQ.deq;
		let d = dataStreamInQ.first;

		if ( fromInteger(blockTuples) < dataTuplesCnt + 1 ) begin
			dataTuplesCnt <= dataTuplesCnt + 1;
		end else begin
			dataTuplesCnt <= 0;
		end


		if ( curDataPageOff == 0 ) begin
			Bit#(16) listElements = truncate(d);
			ListInfo li;
			li.words = listElements;
			dataStreamInfoQ.enq(li);
			curDataPageOff <= listElements;
		end else begin
			dataStreamQ.enq(d);
			curDataPageOff <= curDataPageOff - 1;
		end
	endrule

	Reg#(Bit#(16)) curQueryPageOff <- mkReg(0);
	rule separateQueryHeader;
		queryStreamInQ.deq;
		let d = queryStreamInQ.first;


		//FIXME TODO count words until blockwords and then
		// and then flush the data streamQ

		if ( curQueryPageOff == 0 ) begin
			Bit#(16) listElements = truncate(d);
			ListInfo li;
			li.words = listElements;
			queryStreamInfoQ.enq(li);
			curQueryPageOff <= listElements;
		end else begin
			queryStreamQ.enq(d);
			curQueryPageOff <= curQueryPageOff - 1;
		end
	endrule

	Reg#(Bit#(16)) queryWordsLeft <- mkReg(0);
	Reg#(Bit#(16)) dataWordsLeft <- mkReg(0);
	rule startIntersect(dataBlockLoaded && queryWordsLeft == 0 && dataWordsLeft == 0);
		ListInfo qi = queryStreamInfoQ.first;
		queryStreamInfoQ.deq;
		ListInfo di = dataStreamInfoQ.first;
		dataStreamInfoQ.deq;
		dataStreamInfoQ.enq(di);
		
		Bit#(16) qlen = qi.words;
		Bit#(16) dlen = di.words;
		queryWordsLeft <= qlen;
		dataWordsLeft <= dlen;
	endrule


	Reg#(Bit#(8)) vectorUnrollLeft <- mkReg(0);
	Reg#(Bit#(16)) tuplesToUnroll <- mkReg(0);
	FIFOF#(Bit#(16)) tupleUnrollReqQ <- mkFIFOF;
	Reg#(Vector#(TupleWords, Word)) dataWordVector <- mkReg(?);
	Reg#(Vector#(TupleWords, Word)) queryWordVector <- mkReg(?);

	// TODO instead of blocking on vectorUnrollLeft, just enq tuples to unroll so we can overlap
	rule doIntersect(queryWordsLeft != 0 && dataWordsLeft != 0 && vectorUnrollLeft == 0);
		TuplePacked dt = dataStreamQ.first;
		TuplePacked qt = queryStreamQ.first;
		Vector#(TupleWords, Word) dv = unpack(dt);
		Vector#(TupleWords, Word) qv = unpack(qt);

		Word dvfirst = dv[0];
		Word dvlast = dv[tupleWords-1];
		Word qvfirst = qv[0];
		Word qvlast = qv[tupleWords-1];

		let dl = dataWordsLeft;
		let ql = queryWordsLeft;
		Bool unrollreq = False;
		let tounroll = tuplesToUnroll;

		if ( dvfirst > qvlast ) begin
			queryStreamQ.deq;
			dl = dl - 1;
			ql = ql - 1;
		end else if ( dvlast < qvlast ) begin
			dataStreamQ.deq;
			dl = dl -1 ;
			dataStreamQ.enq(dt); // will make multiple loops through dataStreamQ
		end else begin
			dataWordVector <= dv;
			queryWordVector <= qv;
			vectorUnrollLeft <= fromInteger(tupleWords);
			dataStreamQ.enq(dt); // will make multiple loops through dataStreamQ

			ql = ql - 1;
			dl = dl - 1;
			tounroll = tounroll + 1;
			unrollreq = True;
		end
			
		
		if ( dl == 0 || ql == 0 ) begin
			tuplesToUnroll <= 0;
			tupleUnrollReqQ.enq(tounroll);
		end else if ( unrollreq ) begin
			tuplesToUnroll <= tuplesToUnroll + 1;
		end
		dataWordsLeft <= dl;
		queryWordsLeft <= ql;

	endrule
	rule flushIntersectD(queryWordsLeft == 0 && dataWordsLeft != 0 );
		dataWordsLeft <= dataWordsLeft - 1;
		dataStreamQ.deq;
	endrule
	rule flushIntersectQ(queryWordsLeft != 0 && dataWordsLeft == 0 );
		queryWordsLeft <= queryWordsLeft - 1;
		queryStreamQ.deq;
	endrule

	FIFOF#(Tuple2#(Bool,Word)) unrolledqQ <- mkFIFOF; // last?, value
	FIFOF#(Tuple2#(Bool,Word)) unrolleddQ <- mkFIFOF;
	Reg#(Bit#(16)) tuplesUnrolledCount <- mkReg(0);
	rule unrollIntersect(vectorUnrollLeft != 0);
		if ( tupleUnrollReqQ.notEmpty ) begin
			if ( tuplesUnrolledCount >= tupleUnrollReqQ.first ) begin
				tupleUnrollReqQ.deq;
				unrolledqQ.enq(tuple2(True,?));
				unrolleddQ.enq(tuple2(True,?));
			end
		end else begin
			vectorUnrollLeft <= vectorUnrollLeft - 1;
			tuplesUnrolledCount <= tuplesUnrolledCount+1;
			unrolledqQ.enq(tuple2(False,queryWordVector[0]));
			unrolleddQ.enq(tuple2(False,dataWordVector[0]));
			
			Vector#(TupleWords, Word) ndv = dataWordVector;
			Vector#(TupleWords, Word) nqv = queryWordVector;
			for ( Integer i = 0; i < tupleWords-1; i=i+1 ) begin
				ndv[i] = ndv[i+1];
				nqv[i] = nqv[i+1];
			end
			dataWordVector <= ndv;
			queryWordVector <= nqv;
		end
	endrule
	FIFO#(Tuple2#(Bool,Word)) intersectedQ <- mkFIFO;
	rule wordIntersect;//(unrolleddQ.notEmpty && unrolledqQ.notEmpty);
		let d_ = unrolleddQ.first;
		let q_ = unrolledqQ.first;
		let dl = tpl_1(d_);
		let ql = tpl_1(q_);
		let dw = tpl_2(d_);
		let qw = tpl_2(q_);

		if (!dl && !ql) begin
			if ( dw == qw ) intersectedQ.enq(tuple2(False,dw));
			else if ( dw < qw ) unrolleddQ.deq;
			else unrolledqQ.deq;
		end else if ( dl && !ql ) begin
			unrolledqQ.deq;
		end else if ( ql && !dl ) begin
			unrolleddQ.deq;
		end else begin // both done
			unrolledqQ.deq;
			unrolleddQ.deq;
			intersectedQ.enq(tuple2(True,?));
		end
	endrule

	FIFO#(TuplePacked) intersectedTupleStageQ <- mkSizedBRAMFIFO(blockTuples);
	FIFO#(ListInfo) intersectedListInfoQ <- mkFIFO;

	Reg#(Vector#(TupleWords, Word)) intersectedWordVector <- mkReg(?);
	Reg#(Bit#(8)) intersectedWordCnt <- mkReg(0);
	Reg#(Bit#(16)) tuplesInNewList <- mkReg(0);
	rule deserializeIntersected;
		intersectedQ.deq;
		let d_ = intersectedQ.first;
		Bool last = tpl_1(d_);
		let d = tpl_2(d_);

		if ( last ) begin
			ListInfo li = ?;
			if ( intersectedWordCnt != 0 ) begin
				intersectedTupleStageQ.enq(pack(intersectedWordVector));
				li.words = tuplesInNewList+1;
			end else begin
				li.words = tuplesInNewList;
			end
			intersectedListInfoQ.enq(li);
			tuplesInNewList <= 0;
		end else begin
			Vector#(TupleWords, Word) cv = intersectedWordVector;
			for ( Integer i = 0; i < tupleWords-1; i=i+1) begin
				cv[i] = cv[i+1];
			end
			cv[tupleWords-1] = d;

			if ( intersectedWordCnt + 1 == fromInteger(tupleWords) ) begin
				intersectedWordCnt <= 0;
				intersectedTupleStageQ.enq(pack(cv));
				tuplesInNewList <= tuplesInNewList + 1;
			end else begin
				intersectedWordCnt <= intersectedWordCnt + 1;
			end
		end

	endrule

	FIFO#(TuplePacked) outputQ <- mkSizedBRAMFIFO(blockTuples);
	Reg#(Bit#(16)) outTuplesLeft <- mkReg(0);
	rule mergeInfoStreams;
		if ( outTuplesLeft == 0 ) begin
			intersectedListInfoQ.deq;
			let li = intersectedListInfoQ.first;
			outTuplesLeft <= li.words;

			outputQ.enq(zeroExtend(li.words));
		end else begin
			outTuplesLeft <= outTuplesLeft - 1;

			outputQ.enq(intersectedTupleStageQ.first);
			intersectedTupleStageQ.deq;
		end
	endrule

	method Action queryStream(TuplePacked data);
		queryStreamInQ.enq(data);
	endmethod
	method Action dataStream(TuplePacked data);
		dataStreamInQ.enq(data);
	endmethod
	method ActionValue#(TuplePacked) out; 
		outputQ.deq;
		return outputQ.first;
	endmethod
endmodule

