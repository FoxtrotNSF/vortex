`ifndef VX_MEM_REQ_IF
`define VX_MEM_REQ_IF

`include "../cache/VX_cache_define.vh"

interface VX_mem_req_if #(
    parameter DATA_WIDTH = 1,
    parameter ADDR_WIDTH = 1,
    parameter TAG_WIDTH  = 1,
    parameter DATA_SIZE  = DATA_WIDTH / 8,
    localparam SIZE_WIDTH = $clog2($clog2(DATA_SIZE)+1)
) ();

    wire                    valid;    
    wire                    rw;    
    wire [DATA_SIZE-1:0]    byteen;
    wire [SIZE_WIDTH-1:0]   size;
    wire [ADDR_WIDTH-1:0]   addr;
    wire [DATA_WIDTH-1:0]   data;  
    wire [TAG_WIDTH-1:0]    tag;  
    wire                    ready;

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