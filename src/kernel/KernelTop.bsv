import Axi4LiteControllerXrt::*;
import Axi4MemoryMaster::*;

import Clocks :: *;

interface KernelTopIfc;
	(* always_ready *)
	interface Axi4MemoryMasterPinsIfc#(64,512) m00_axi;
	(* always_ready *)
	interface Axi4LiteControllerXrtPinsIfc#(12,32) s_axi_control;
	(* always_ready *)
	method Bool interrupt;
endinterface

(* synthesize *)
(* default_reset="ap_rst_n", default_clock_osc="ap_clk" *)
module mkKernelTop (KernelTopIfc);
	Clock defaultClock <- exposeCurrentClock;
	Reset defaultReset <- exposeCurrentReset;

	Axi4LiteControllerXrtIfc#(12,32) axi4control <- mkAxi4LiteControllerXrt(defaultClock, defaultReset);
	Axi4MemoryMasterIfc#(64,512) axi4mem <- mkAxi4MemoryMaster;

	Reg#(Bool) started <- mkReg(False);
	rule checkscalar ( started == False );
		if ( axi4control.ap_start ) started <= True;
	endrule

	Reg#(Bit#(32)) testCounter <- mkReg(0);
	rule issueWork(started && testCounter == 0);
		if ( axi4control.scalar00 > 0 ) begin
			axi4mem.writeReq(axi4control.mem_addr,zeroExtend(axi4control.scalar00)<<6); // 512 bits
			testCounter <= axi4control.scalar00;
		end
	endrule

	rule applyBurst (started == True && testCounter > 0);
		testCounter <= testCounter - 1;
		axi4mem.write({
			testCounter,testCounter,testCounter,testCounter,
			testCounter,testCounter,testCounter,testCounter,
			testCounter,testCounter,testCounter,testCounter,
			testCounter,testCounter,testCounter,testCounter
		});

		if ( testCounter == 1 ) begin
			axi4control.ap_done();
			started <= False;
		end
	endrule

	interface m00_axi = axi4mem.pins;
	interface s_axi_control = axi4control.pins;
	interface interrupt = axi4control.interrupt;
endmodule
