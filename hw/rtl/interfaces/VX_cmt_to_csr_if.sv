`ifndef VX_CMT_TO_CSR_IF
`define VX_CMT_TO_CSR_IF

`include "VX_define.vh"

interface VX_cmt_to_csr_if ();

    wire                                valid;
    wire [31:0]                         timeit_start_addr;
    wire [31:0]                         timeit_end_addr;
    reg                                 timeit_enable;
    reg [`NUM_WARPS-1:0]                timeit_active;
    initial                             timeit_enable = 1'b0;
    initial                             timeit_active = '0;
`ifdef EXT_F_ENABLE
    wire [$clog2(6*`NUM_THREADS+1)-1:0] commit_size;
`else
    wire [$clog2(5*`NUM_THREADS+1)-1:0] commit_size;
`endif
    modport master (
        output valid,    
        output commit_size,
        output timeit_active,
        input  timeit_start_addr,
        input  timeit_end_addr,
        input  timeit_enable
    );

    modport slave (
        input  valid,
        input  commit_size,
        input  timeit_active,
        output timeit_start_addr,
        output timeit_end_addr,
        output timeit_enable
    );

endinterface

`endif