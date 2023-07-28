import FIFO::*;
import FIFOF::*;
import Vector::*;

typedef 8 TupleWords;
typedef 32 WordBits;
typedef Bit#(32) Word;
typedef Maybe#(Vector#(TupleWords,Word)) StreamElement;



interface SingleIntersectIfc;
	method Action streamA(StreamElement data);
	method Action streamB(StreamElement data);
	method ActionValue#(StreamElement) streamOut; 
endinterface

module mkSingleIntersect (SingleIntersectIfc);
	Integer tupleWords = valueOf(TupleWords);

	FIFO#(StreamElement) streamAQ <- mkFIFO;
	FIFO#(StreamElement) streamBQ <- mkFIFO;


	Vector#(2,FIFO#(StreamElement)) unrollQs <- replicateM(mkFIFO);

	rule doIntersect (isValid(streamAQ.first) && isValid(streamBQ.first));
		Vector#(TupleWords,Word) a = fromMaybe(?,streamAQ.first);
		Vector#(TupleWords,Word) b = fromMaybe(?,streamBQ.first);

		Word afirst = a[0];
		Word alast = a[tupleWords-1];
		Word bfirst = b[0];
		Word blast = b[tupleWords-1];

		if ( afirst > blast ) begin
			streamBQ.deq;
			//$write( "Skip B\n" );
		end else if ( bfirst > alast ) begin
			streamAQ.deq;
			//$write( "Skip A\n" );
		end else begin
			streamAQ.deq;
			streamBQ.deq;

			unrollQs[0].enq(tagged Valid a);
			unrollQs[1].enq(tagged Valid b);
			//$write( "Unrolling\n" );
		end
	endrule
	rule doFFA (!isValid(streamAQ.first) && isValid(streamBQ.first));
		streamBQ.deq;
		//$write("FF B\n");
	endrule
	rule doFFB (isValid(streamAQ.first) && !isValid(streamBQ.first));
		streamAQ.deq;
		//$write("FF A\n");
	endrule
	rule doFFBoth (!isValid(streamAQ.first) && !isValid(streamBQ.first));
		streamAQ.deq;
		streamBQ.deq;
		unrollQs[0].enq(tagged Invalid);
		unrollQs[1].enq(tagged Invalid);
		//$write("Capping\n");
	endrule


	Vector#(2,FIFO#(Maybe#(Word))) unrolledQs <- replicateM(mkFIFO);
	for ( Integer qi = 0; qi < 2; qi=qi+1 ) begin
		Reg#(Vector#(TupleWords,Word)) unrollWordVector <- mkReg(?);
		Reg#(Bit#(8)) unrollWordCnt <- mkReg(0);

		rule unrollWords;
			if ( unrollWordCnt == 0 ) begin
				let d = unrollQs[qi].first;
				unrollQs[qi].deq;
				if ( isValid(d) ) begin
					unrollWordCnt <= fromInteger(tupleWords-1);
					let nd = fromMaybe(?,d);
					unrolledQs[qi].enq(tagged Valid nd[0]);
					Vector#(TupleWords,Word) nnd;
					for ( Integer i = 0; i < tupleWords; i=i+1 ) begin
						if ( i < tupleWords-1 ) nnd[i] = nd[i+1];
						else nnd[i] = ?;
					end
					unrollWordVector <= nnd;
				end else begin
					unrolledQs[qi].enq(tagged Invalid);
				end
			end else begin
				Vector#(TupleWords,Word) nnd;
				for ( Integer i = 0; i < tupleWords; i=i+1 ) begin
					if ( i < tupleWords-1 ) nnd[i] = unrollWordVector[i+1];
					else nnd[i] = ?;
				end
				unrollWordVector <= nnd;
				unrollWordCnt <= unrollWordCnt - 1;
				unrolledQs[qi].enq(tagged Valid unrollWordVector[0]);
			end
		endrule
	end
	FIFO#(Maybe#(Word)) intersectedQ <- mkFIFO;
	rule intersectUnrolled;
		let da = unrolledQs[0].first;
		let db = unrolledQs[1].first;
		
		if ( isValid(da) && isValid(db) ) begin
			let a = fromMaybe(?,da);
			let b = fromMaybe(?,db);
			if ( a < b ) begin
				unrolledQs[0].deq;
			end else if ( a > b ) begin
				unrolledQs[1].deq;
			end else begin
				intersectedQ.enq(da);
				unrolledQs[0].deq;
				unrolledQs[1].deq;
			end
		
		end else if ( !isValid(da) && isValid(db)) begin
			unrolledQs[1].deq;
		end else if ( isValid(da) && !isValid(db)) begin
			unrolledQs[0].deq;
		end else begin
			intersectedQ.enq(tagged Invalid);
			unrolledQs[0].deq;
			unrolledQs[1].deq;
		end
	endrule

	FIFO#(StreamElement) streamOutQ <- mkFIFO;
	Reg#(Vector#(TupleWords,Word)) deserializeWordVector <- mkReg(?);
	Reg#(Bit#(8)) deserializeWordCnt <- mkReg(0);
	Reg#(Bool) shouldFlushDes <- mkReg(False);
	rule deserializeOut(!shouldFlushDes);
		let nd_ = intersectedQ.first;
		intersectedQ.deq;
		if ( isValid(nd_) ) begin
			let nd = fromMaybe(?,nd_);
			//$write("Intersected %d\n", nd );
			if ( deserializeWordCnt == fromInteger(tupleWords-1) ) begin
				Vector#(TupleWords,Word) nnd;
				for ( Integer i = 0; i < tupleWords; i=i+1 ) begin
					if ( i < tupleWords-1 ) nnd[i] = deserializeWordVector[i+1];
					else nnd[i] = nd;
				end
				streamOutQ.enq(tagged Valid nnd);
				deserializeWordCnt <= 0;
			end else begin
				Vector#(TupleWords,Word) nnd;
				for ( Integer i = 0; i < tupleWords; i=i+1 ) begin
					if ( i < tupleWords-1 ) nnd[i] = deserializeWordVector[i+1];
					else nnd[i] = nd;
				end
				deserializeWordVector <= nnd;
				deserializeWordCnt <= deserializeWordCnt + 1;
			end
		end else begin
			if ( deserializeWordCnt == 0 ) begin
				streamOutQ.enq(tagged Invalid);
			end else begin
				streamOutQ.enq(tagged Valid deserializeWordVector);
				deserializeWordCnt <= 0;
				shouldFlushDes <= True;
			end
		end
	endrule
	rule flushDes(shouldFlushDes);
		shouldFlushDes <= False;
		streamOutQ.enq(tagged Invalid);
	endrule


	method Action streamA(StreamElement data);
		streamAQ.enq(data);
	endmethod
	method Action streamB(StreamElement data);
		streamBQ.enq(data);
	endmethod
	method ActionValue#(StreamElement) streamOut; 
		streamOutQ.deq;
		return streamOutQ.first;
	endmethod
endmodule
