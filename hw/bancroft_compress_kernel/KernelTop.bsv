import Axi4LiteControllerXrt::*;
import Axi4MemoryMaster::*;

import FIFO::*;
import Vector::*;
import Clocks :: *;

import KernelMain::*;

interface KernelTopIfc;
	(* always_ready *)
	interface Axi4MemoryMasterPinsIfc#(64,512) in;
	(* always_ready *)
	interface Axi4MemoryMasterPinsIfc#(64,512) out;
	(* always_ready *)
	interface Axi4LiteControllerXrtPinsIfc#(12,32) s_axi_control;
	(* always_ready *)
	method Bool interrupt;
endinterface

(* synthesize *)
(* default_reset="ap_rst_n", default_clock_osc="ap_clk" *)
module kernel (KernelTopIfc);
	Clock defaultClock <- exposeCurrentClock;
	Reset defaultReset <- exposeCurrentReset;

	Axi4LiteControllerXrtIfc#(12,32) axi4control <- mkAxi4LiteControllerXrt(defaultClock, defaultReset);
	Vector#(2, Axi4MemoryMasterIfc#(64,512)) axi4mem <- replicateM(mkAxi4MemoryMaster);
	//Axi4MemoryMasterIfc#(64,512) axi4file <- mkAxi4MemoryMaster;

	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule

	Reg#(Bool) started <- mkReg(False);

	KernelMainIfc kernelMain <- mkKernelMain;

	rule assertControl;
		if ( !started ) begin
			axi4control.ap_idle;
		end
	endrule

	// Check Started if AXI controller is ready
	FIFO#(Bit#(32)) startQ <- mkFIFO;
	Reg#(Bool) last_ap_start <- mkReg(False);
	rule checkStart; 
		if ( !last_ap_start && axi4control.ap_start ) begin
			startQ.enq(axi4control.scalar00);
		end
		last_ap_start <= axi4control.ap_start;
	endrule
	rule relayStart (!started);
		startQ.deq;
		kernelMain.start(startQ.first);
		started <= True;
	endrule

	rule checkDone ( started );
		Bool done <- kernelMain.done;
		if ( done ) begin
			axi4control.ap_done();
			axi4control.ap_ready;
			started <= False;
		end
	endrule
	for ( Integer i = 0; i < valueOf(MemPortCnt); i=i+1 ) begin
		rule relayReadReq00 ( started);
			let r <- kernelMain.mem[i].readReq;
			if ( i == 0 ) axi4mem[i].readReq(axi4control.mem_addr+r.addr,zeroExtend(r.bytes));
			else axi4mem[i].readReq(axi4control.file_addr+r.addr,zeroExtend(r.bytes));
		endrule
		rule relayWriteReq ( started);
			let r <- kernelMain.mem[i].writeReq;
			if ( i == 0 ) axi4mem[i].writeReq(axi4control.mem_addr+r.addr,zeroExtend(r.bytes));
			else axi4mem[i].writeReq(axi4control.file_addr+r.addr,zeroExtend(r.bytes));
		endrule
		rule relayWriteWord ( started);
			let r <- kernelMain.mem[i].writeWord;
			axi4mem[i].write(r);
		endrule
		rule relayReadWord ( started);
			let d <- axi4mem[i].read;
			kernelMain.mem[i].readWord(d);
		endrule
	end

	interface in = axi4mem[0].pins;
	interface out = axi4mem[1].pins;
	//interface m02_axi = axi4mem[2].pins;
	//interface m03_axi = axi4mem[3].pins;
	interface s_axi_control = axi4control.pins;
	interface interrupt = axi4control.interrupt;
endmodule
