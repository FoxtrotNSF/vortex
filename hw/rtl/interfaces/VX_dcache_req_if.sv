`ifndef VX_DCACHE_REQ_IF
`define VX_DCACHE_REQ_IF

`include "../cache/VX_cache_define.vh"

interface VX_dcache_req_if #(
    parameter NUM_REQS  = 1,
    parameter WORD_SIZE = 1,
    parameter TAG_WIDTH = 1,
    localparam WORD_LSIZE_WIDTH = $clog2($clog2(WORD_SIZE)+1)
) ();

    wire [NUM_REQS-1:0]                         valid;
    wire [NUM_REQS-1:0]                         rw;
    wire [NUM_REQS-1:0][WORD_SIZE-1:0]          byteen;
    wire [NUM_REQS-1:0][WORD_LSIZE_WIDTH-1:0]   size;
    wire [NUM_REQS-1:0][`XLEN-1:0]              addr;
    wire [NUM_REQS-1:0][`WORD_WIDTH-1:0]        data;
    wire [NUM_REQS-1:0][TAG_WIDTH-1:0]          tag;    
    wire [NUM_REQS-1:0]                         ready;

    modport master (
        output valid,
        output rw,
        output byteen,
        output size,
        output addr,
        output data,        
        output tag,
        input  ready
    );

    modport slave (
        input  valid,
        input  rw,
        input  byteen,
        input  size,
        input  addr,
        input  data,
        input  tag,
        output ready
    );

endinterface

`endif