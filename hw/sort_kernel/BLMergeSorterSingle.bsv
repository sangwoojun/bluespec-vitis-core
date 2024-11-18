import FIFO::*;
import Vector::*;

interface BLKvEnqIfc#(type keyType, type valType);
	method Action enq(Tuple2#(keyType, valType) data);
endinterface
interface BLMergeSorterSingleIfc#(numeric type iCnt, type keyType, type valType);
	interface Vector#(iCnt, BLKvEnqIfc#(keyType, valType)) put;
	method Action runMerge(Bit#(32) count);
	method ActionValue#(Tuple2#(keyType, valType)) get;
endinterface

module mkBLMergeSorterSingle (BLMergeSorterSingleIfc#(iCnt, keyType, valType))
	provisos(
		Bits#(keyType,keyTypeSz), Eq#(keyType), Ord#(keyType), Add#(1,a__,keyTypeSz),
		Bits#(valType,valTypeSz), Ord#(valType), Add#(1,b__,valTypeSz)
	);




	Vector#(iCnt, BLKvEnqIfc#(keyType, valType)) put_;
	for ( Integer i = 0; i < valueOf(iCnt); i=i+1 ) begin
		put_[i] = interface BLKvEnqIfc;
			method Action enq(Tuple2#(keyType, valType) data);
			endmethod
		endinterface;
	end
	interface put = put_;
	method Action runMerge(Bit#(32) count);
	endmethod
	method ActionValue#(Tuple2#(keyType, valType)) get;
		return ?;
	endmethod
endmodule

