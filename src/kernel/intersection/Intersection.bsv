import SingleIntersect::*;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import BRAM::*;

typedef TMul#(TupleWords,WordBits) TupleBits;
typedef Bit#(TupleBits) TuplePacked;

interface IntersectIfc;
	method Action streamPageA(TuplePacked data);
	method Action streamPageB(TuplePacked data);
	method ActionValue#(TuplePacked) out;
endinterface

module mkIntersection#(Integer pageSizeBytes) (IntersectIfc);
	
	BRAM2Port#(Bit#(cacheRowCntSz), Tuple4#(Bit#(tagSz), Vector#(TExp#(CacheLineWordsSz), Word),Bool,Bool)) mem <- mkBRAM2Server(defaultValue); 

	method Action streamPageA(TuplePacked data);
	endmethod
	method Action streamPageB(TuplePacked data);
	endmethod
	method ActionValue#(TuplePacked) out;
		return ?;
	endmethod
endmodule
