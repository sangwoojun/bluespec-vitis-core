package Axi4MemoryMaster;

interface Axi4MemoryMasterPinsIfc#(numeric type addrSz, numeric type dataSz);
	// write address to axi
	(* always_ready, result="awvalid" *)
	method Bool awvalid;
	(* always_ready, always_enabled, prefix = "" *)
	method Action address_write ((* port="awready" *)  Bit #(addrSz) awready);
	(* always_ready, result="awaddr" *)
	method Bit#(addrSz) awaddr;
	(* always_ready, result="awlen" *)
	method Bit#(8) awlen;


	// write data to axi
	(* always_ready, result="wvalid" *)
	method Bool wvalid;
	(* always_ready, always_enabled, prefix = "" *)
	method Action data_write ((* port="wready" *)  Bool wready);
	(* always_ready, result="wdata" *)
	method Bit#(dataSz) wdata;
	(* always_ready, result="wstrb" *)
	method Bit#(TDiv#(dataSz,8)) wstrb;
	(* always_ready, result="wlast" *)
	method Bool wlast;


	// write response from axi
	(* always_ready, always_enabled, prefix = "" *)
	method Action write_resp_valid ((* port="bvalid" *)  Bool bvalid);
	(* always_ready, result="bready" *)
	method Bool bready;
	
	// write read addr to axi
	(* always_ready, result="arvalid" *)
	method Bool arvalid;
	(* always_ready, always_enabled, prefix = "" *)
	method Action read_address_ready ((* port="arready" *)  Bool arready);
	(* always_ready, result="araddr" *)
	method Bit#(addrSz) araddr;
	(* always_ready, result="arlen" *)
	method Bit#(8) arlen;


	// read response from axi
	(* always_ready, always_enabled, prefix = "" *)
	method Action read_data_valid ((* port="rvalid" *)  Bool rvalid);
	(* always_ready, result="rready" *)
	method Bool rready;
	(* always_ready, always_enabled, prefix = "" *)
	method Action read_data ((* port="rdata" *)  Bit#(dataSz) rdata);
	(* always_ready, always_enabled, prefix = "" *)
	method Action read_data_last ((* port="rlast" *)  Bool rlast);
endinterface

interface Axi4MemoryMasterIfc#(numeric type addrSz, numeric type dataSz);

	interface Axi4MemoryMasterPinsIfc#(addrSz,dataSz) pins;
  
	method Action readReq(Bit#(addrSz) addr, Bit#(addrSz) size);
	// ignoring tlast for simplicity
	method ActionValue#(Bit#(dataSz)) readResp;

	method Action writeReq(Bit#(addrSz) addr, Bit#(addrSz) size);
	method Action write(Bit#(dataSz) data);
  /*
  // read user interface
  output wire                          m_axis_tvalid,
  input  wire                          m_axis_tready,
  output wire [C_M_AXI_DATA_WIDTH-1:0] m_axis_tdata,
  output wire                          m_axis_tlast
  */

  /* 
  // write user interface
  input  wire                            s_axis_tvalid,
  output wire                            s_axis_tready,
  input  wire  [C_M_AXI_DATA_WIDTH-1:0]  s_axis_tdata
  */
endinterface

module mkAxi4MemoryMaster (Axi4MemoryMasterIfc#(addrSz,dataSz));

	interface Axi4MemoryMasterPinsIfc pins;
		method Bool awvalid;
			return False;
		endmethod
		method Action address_write (Bit #(addrSz) awready);
		endmethod
		method Bit#(addrSz) awaddr;
			return 0;
		endmethod
		method Bit#(8) awlen;
			return 0;
		endmethod
	
		method Bool wvalid;
			return False;
		endmethod
		method Action data_write ( Bool wready);
		endmethod
		method Bit#(dataSz) wdata;
			return 0;
		endmethod
		method Bit#(TDiv#(dataSz,8)) wstrb;
			return 0;
		endmethod
		method Bool wlast;
			return False;
		endmethod
	
		method Action write_resp_valid (Bool bvalid);
		endmethod
		method Bool bready;
			return False;
		endmethod
	
		// write read addr to axi
		method Bool arvalid;
			return False;
		endmethod
		method Action read_address_ready ( Bool arready);
		endmethod
		method Bit#(addrSz) araddr;
			return 0;
		endmethod
		method Bit#(8) arlen;
			return 0;
		endmethod


		// read response from axi
		method Action read_data_valid ( Bool rvalid);
			
		endmethod
		method Bool rready;
			return False;
		endmethod
		method Action read_data (Bit#(dataSz) rdata);
		endmethod
		method Action read_data_last (Bool rlast);
		endmethod
	endinterface

	method Action readReq(Bit#(addrSz) addr, Bit#(addrSz) size);
	endmethod
	method ActionValue#(Bit#(dataSz)) readResp;
		return ?;
	endmethod

	method Action writeReq(Bit#(addrSz) addr, Bit#(addrSz) size);
	endmethod
	method Action write(Bit#(dataSz) data);
	endmethod
endmodule


endpackage
