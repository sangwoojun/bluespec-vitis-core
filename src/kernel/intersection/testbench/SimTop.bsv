
import FIFO::*;
import FIFOF::*;
import Vector::*;


import SingleIntersect::*;

//import "BDPI" function Action bdpi_write_word(Bit#(32) buffer, Bit#(64) addr, Bit#(32) data, Bit#(32) tag);
import "BDPI" function Bit#(32) bdpi_read_word(Bit#(32) addr);


module mkSimTop(Empty);
	SingleIntersectIfc si <- mkSingleIntersect;

	Reg#(Bit#(32)) addroffA <- mkReg(0);
	Reg#(Bit#(32)) addroffB <- mkReg(0);
	rule inputDataA ( addroffA < 1024);
		Vector#(TupleWords, Word) ai;
		for ( Integer i = 0; i < valueOf(TupleWords); i=i+1) begin
			ai[i] = bdpi_read_word(addroffA+fromInteger(i*4));
			//bi[i] = bdpi_read_word(addroff+fromInteger(i)+2048);
		end
		si.streamA(tagged Valid ai);
		//si.streamB(tagged Valid bi);

		addroffA <= addroffA + (4*fromInteger(valueOf(TupleWords)));
	endrule
	rule inputDataB ( addroffB < 1024);
		Vector#(TupleWords, Word) bi;
		for ( Integer i = 0; i < valueOf(TupleWords); i=i+1) begin
			bi[i] = bdpi_read_word(addroffB+fromInteger(i*4)+2048*4);
		end
		si.streamB(tagged Valid bi);

		addroffB <= addroffB + (4*fromInteger(valueOf(TupleWords)));
	endrule

	rule capinputA (addroffA == 1024);
		si.streamA(tagged Invalid);
		addroffA <= addroffA + (4*fromInteger(valueOf(TupleWords)));
	endrule
	rule capinputB (addroffB == 1024);
		si.streamB(tagged Invalid);
		addroffB <= addroffB + (4*fromInteger(valueOf(TupleWords)));
	endrule
	rule sinkOut;
		let d <- si.streamOut;
		if ( !isValid(d) ) begin
			//$write("Done\n");
		end else begin
			//$write("Out\n");
		end
	endrule
endmodule
