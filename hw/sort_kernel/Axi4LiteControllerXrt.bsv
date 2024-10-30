package Axi4LiteControllerXrt;

interface Axi4LiteControllerXrtPinsIfc#(numeric type addrSz, numeric type dataSz);
	// Write address
	(* always_ready, always_enabled, prefix = "" *)
	method Action write_address ((* port="awaddr" *)  Bit #(addrSz) awaddr);
	(* always_ready, always_enabled, prefix = "" *)
	method Action write_address_valid ((* port="awvalid" *)  Bool awvalid);
	(* always_ready, result="awready" *)
	method Bool awready;

	// Write data
	(* always_ready, always_enabled, prefix = "" *)
	method Action write_data ((* port="wdata" *) Bit#(dataSz) sdata);
	(* always_ready, always_enabled, prefix = "" *)
	method Action write_data_valid ((* port="wvalid" *) Bool wvalid);
	(* always_ready, always_enabled, prefix = "" *)
	method Action write_data_strb ((* port="wstrb" *) Bit#(TDiv#(dataSz,8)) wstrb);
	(* always_ready, result="wready" *)
	method Bool wready;

	// Write response
	(* always_ready, result="bvalid" *) method Bool bvalid;
	(* always_ready, result="bresp" *) method Bit#(2) bresp;
	(* always_ready, always_enabled, prefix="" *)
	method Action write_response_ready ((* port="bready" *) Bool bready);
	
	// Read address
	(* always_ready, always_enabled, prefix = "" *)
	method Action read_address_valid ((* port="arvalid" *) Bool arvalid);
	(* always_ready, always_enabled, prefix = "" *)
	method Action read_address ((* port="araddr" *) Bit #(addrSz) araddr);
	(* always_ready, result="arready" *)
	method Bool arready;

	// Read Data
	(* always_ready, result="rvalid" *)  method Bool rvalid;
	(* always_ready, always_enabled, prefix="" *)
	method Action read_data_ready  ((* port="rready" *) Bool rready);
	(* always_ready, result="rresp" *) method Bit #(2) rresp;
	(* always_ready, result="rdata" *) method Bit #(dataSz) rdata;
	
endinterface

interface Axi4LiteControllerXrtIfc#(numeric type addrSz, numeric type dataSz);
	interface Axi4LiteControllerXrtPinsIfc#(addrSz, dataSz) pins;

	(* always_ready, result="interrupt" *)
	method Bool interrupt;


	method Bit#(32) scalar00;
	method Bit#(64) mem_addr;
	method Bit#(64) file_addr;
	
	//(* result="ap_start" *) 
	method Bool ap_start;
	(* always_ready, prefix="" *)
	method Action ap_done();
	(* always_ready, prefix="" *)
	method Action ap_ready();
	(* always_ready, prefix="" *)
	method Action ap_idle();
	
endinterface

import "BVI" s_axi4_lite_controller =
module mkAxi4LiteControllerXrt#(Clock aclk, Reset arst) (Axi4LiteControllerXrtIfc#(addrSz,dataSz));
	default_clock no_clock;
	default_reset no_reset;

	input_clock (ACLK) = aclk;
	input_reset (ARESET_N) = arst;

	parameter C_S_AXI_ADDR_WIDTH = valueOf(addrSz);
	parameter C_S_AXI_DATA_WIDTH = valueOf(dataSz);
	
	interface Axi4LiteControllerXrtPinsIfc pins;
		// Write address
		method write_address(AWADDR) enable((*inhigh*) write_address_en) clocked_by(aclk) reset_by(arst);
		method write_address_valid(AWVALID) enable((*inhigh*) write_address_valid_en) clocked_by(aclk) reset_by(arst);
		method AWREADY awready() reset_by(arst) clocked_by(aclk);

		// Write data
		method write_data(WDATA) enable((*inhigh*) write_data_en) clocked_by(aclk) reset_by(arst);
		method write_data_valid(WVALID) enable((*inhigh*) write_data_valid_en) clocked_by(aclk) reset_by(arst);
		method write_data_strb(WSTRB) enable((*inhigh*) write_data_strb_en) clocked_by(aclk) reset_by(arst);
		method WREADY wready() reset_by(arst) clocked_by(aclk);
	
		// Write response
		method BVALID bvalid() reset_by(arst) clocked_by(aclk);
		method BRESP bresp() reset_by(arst) clocked_by(aclk);
		method write_response_ready(BREADY) enable((*inhigh*) write_response_en) clocked_by(aclk) reset_by(arst);
	
	
		// Read address
		method read_address(ARADDR) enable((*inhigh*) read_address_en) clocked_by(aclk) reset_by(arst);
		method read_address_valid(ARVALID) enable((*inhigh*) read_address_valid_en) clocked_by(aclk) reset_by(arst);
		method ARREADY arready() reset_by(arst) clocked_by(aclk);
	
		// Read Data
		method RVALID rvalid() reset_by(arst) clocked_by(aclk);
		method read_data_ready(RREADY) enable((*inhigh*) read_data_valid_en) clocked_by(aclk) reset_by(arst);
		method RRESP rresp() reset_by(arst) clocked_by(aclk);
		method RDATA rdata() reset_by(arst) clocked_by(aclk);
	
	endinterface
		
	method interrupt interrupt() reset_by(arst) clocked_by(aclk);

	method scalar00 scalar00() reset_by(arst) clocked_by(aclk);
	method mem mem_addr() reset_by(arst) clocked_by(aclk);
	method file file_addr() reset_by(arst) clocked_by(aclk);
	
	method ap_start ap_start()  reset_by(arst) clocked_by(aclk);
	method ap_done() enable(ap_done) clocked_by(aclk) reset_by(arst);
	method ap_ready() enable(ap_ready) clocked_by(aclk) reset_by(arst);
	method ap_idle() enable(ap_idle) clocked_by(aclk) reset_by(arst);

	schedule (
		pins_write_address, pins_write_address_valid, pins_awready,
		pins_write_data, pins_write_data_valid, pins_write_data_strb, pins_wready,
		pins_write_response_ready, pins_bresp, pins_bvalid,
		pins_read_address, pins_read_address_valid, pins_arready,
		pins_rvalid, pins_read_data_ready, pins_rresp, pins_rdata,
		interrupt,
		scalar00,mem_addr,file_addr,
		ap_start, ap_done, ap_ready, ap_idle
		) CF (
		pins_write_address, pins_write_address_valid, pins_awready,
		pins_write_data, pins_write_data_valid, pins_write_data_strb, pins_wready,
		pins_write_response_ready, pins_bresp, pins_bvalid,
		pins_read_address, pins_read_address_valid, pins_arready,
		pins_rvalid, pins_read_data_ready, pins_rresp, pins_rdata,
		interrupt,
		scalar00,mem_addr,file_addr,
		ap_start, ap_done, ap_ready, ap_idle
		);
	
endmodule


endpackage
