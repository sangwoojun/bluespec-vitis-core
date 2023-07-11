import Axi4LiteControllerXrt::*;
import Axi4MemoryMaster::*;

import Vector::*;
import Clocks :: *;

import KernelMain::*;

interface KernelTopIfc;
	(* always_ready *)
	interface Axi4MemoryMasterPinsIfc#(64,512) m00_axi;
	(* always_ready *)
	interface Axi4MemoryMasterPinsIfc#(64,512) m01_axi;
	/*
	(* always_ready *)
	interface Axi4MemoryMasterPinsIfc#(64,512) m02_axi;
	(* always_ready *)
	interface Axi4MemoryMasterPinsIfc#(64,512) m03_axi;
	*/
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
	Vector#(2, Axi4MemoryMasterIfc#(64,512)) axi4mem <- replicateM(mkAxi4MemoryMaster);
	//Axi4MemoryMasterIfc#(64,512) axi4file <- mkAxi4MemoryMaster;

/*
	Reg#(Bool) started <- mkReg(False);
	Reg#(Bool) done <- mkReg(False);
	rule checkscalar ( started == False );
		if ( axi4control.ap_start ) started <= True;
	endrule
*/
	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule

	Reg#(Bool) started <- mkReg(False);

	KernelMainIfc kernelMain <- mkKernelMain;
	rule checkStart (!started);
		if ( axi4control.ap_start ) begin
			kernelMain.start(axi4control.scalar00);
			started <= True;
		end
	endrule
	rule checkDone ( started );
		Bool done = kernelMain.done;
		if ( done ) axi4control.ap_done();
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


/*
	Reg#(Bit#(32)) readReqCycle <- mkReg(0);
	Reg#(Bit#(32)) testCounter <- mkReg(0);
	rule issueWork(started && testCounter == 0 && !done);
		if ( axi4control.scalar00 > 0 ) begin
			//axi4mem.writeReq(axi4control.mem_addr,zeroExtend(axi4control.scalar00)<<6); // 512 bits
			axi4mem[0].readReq(axi4control.mem_addr,zeroExtend(axi4control.scalar00)<<6); // 512 bits
			for ( Integer i = 1; i< 2; i=i+1) begin
				axi4mem[i].writeReq(axi4control.mem_addr,zeroExtend(axi4control.scalar00)<<6);
			end
			for ( Integer i = 2; i< 4; i=i+1) begin
				axi4mem[i].writeReq(axi4control.file_addr,zeroExtend(axi4control.scalar00)<<6);
			end

			testCounter <= axi4control.scalar00;
			readReqCycle <= cycleCounter;
		end
	endrule
	Reg#(Bit#(32)) readRespFirstCycle <- mkReg(0);
	Reg#(Bit#(32)) readRespLastCycle <- mkReg(0);


	rule readBurst(testCounter != 0 && started == True);
		let d <- axi4mem[0].read;
		for ( Integer i = 1; i< 4; i=i+1) begin
			axi4mem[i].write(d);
		end

		if (readRespFirstCycle == 0 ) readRespFirstCycle <= cycleCounter;
		readRespLastCycle <= cycleCounter;
		testCounter <= testCounter - 1;

		if (testCounter == 1 ) begin
			axi4control.ap_done();
			started <= False;
			done <= True;
			
			axi4mem[0].writeReq(axi4control.mem_addr,64); // 512 bits
			axi4mem[0].write({
				readReqCycle,32'h11111111,readRespFirstCycle,32'h22222222,
				readRespLastCycle,32'h33333333,32'hdeadbeef,testCounter,
				testCounter,testCounter,testCounter,testCounter,
				testCounter,testCounter,testCounter,testCounter
			});
		end
	endrule
	*/

	interface m00_axi = axi4mem[0].pins;
	interface m01_axi = axi4mem[1].pins;
	//interface m02_axi = axi4mem[2].pins;
	//interface m03_axi = axi4mem[3].pins;
	interface s_axi_control = axi4control.pins;
	interface interrupt = axi4control.interrupt;
endmodule
