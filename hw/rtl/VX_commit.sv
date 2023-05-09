`include "VX_define.vh"

module VX_commit #(
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,

    // inputs
    VX_commit_if.slave      alu_commit_if,
    VX_commit_if.slave      ld_commit_if,
    VX_commit_if.slave      st_commit_if, 
    VX_commit_if.slave      csr_commit_if,
`ifdef EXT_F_ENABLE
    VX_commit_if.slave      fpu_commit_if,
`endif
    VX_commit_if.slave      gpu_commit_if,

    // outputs
    VX_writeback_if.master  writeback_if,
    VX_cmt_to_csr_if.master cmt_to_csr_if
);
    // CSRs update

    wire alu_commit_fire = alu_commit_if.valid && alu_commit_if.ready;
    wire ld_commit_fire  = ld_commit_if.valid && ld_commit_if.ready;
    wire st_commit_fire  = st_commit_if.valid && st_commit_if.ready;
    wire csr_commit_fire = csr_commit_if.valid && csr_commit_if.ready;
`ifdef EXT_F_ENABLE
    wire fpu_commit_fire = fpu_commit_if.valid && fpu_commit_if.ready;
`endif
    wire gpu_commit_fire = gpu_commit_if.valid && gpu_commit_if.ready;

    wire commit_fire = alu_commit_fire
                    || ld_commit_fire
                    || st_commit_fire
                    || csr_commit_fire
                `ifdef EXT_F_ENABLE
                    || fpu_commit_fire
                `endif
                    || gpu_commit_fire;

`ifdef EXT_F_ENABLE
    wire [5:0][31:0]            commit_pcs;
    wire [5:0]                  commit_valid;
    wire [5:0][`NW_BITS-1:0]    commit_wid;
    wire [(6*`NUM_THREADS)-1:0] commit_tmask;
`else
    wire [4:0][31:0]            commit_pcs;
    wire [4:0]                  commit_valid;
    wire [4:0][`NW_BITS-1:0]    commit_wid;
    wire [(5*`NUM_THREADS)-1:0] commit_tmask;
`endif

     assign commit_pcs = {
        alu_commit_if.PC,
        ld_commit_if.PC,
        st_commit_if.PC,
        csr_commit_if.PC,
    `ifdef EXT_F_ENABLE
        fpu_commit_if.PC,
    `endif
        gpu_commit_if.PC
    };

    assign commit_valid = {
       alu_commit_fire,
       ld_commit_fire,
       st_commit_fire,
       csr_commit_fire,
    `ifdef EXT_F_ENABLE
       fpu_commit_fire,
    `endif
       gpu_commit_fire
    };

    assign commit_wid = {
       alu_commit_if.wid,
       ld_commit_if.wid,
       st_commit_if.wid,
       csr_commit_if.wid,
    `ifdef EXT_F_ENABLE
       fpu_commit_if.wid,
    `endif
       gpu_commit_if.wid
    };

    wire [$clog2($bits(commit_tmask)+1)-1:0] commit_size;

    assign commit_tmask = {
        {`NUM_THREADS{alu_commit_fire}} & alu_commit_if.tmask,
        {`NUM_THREADS{ld_commit_fire}}  & ld_commit_if.tmask, 
        {`NUM_THREADS{st_commit_fire}}  & st_commit_if.tmask,
        {`NUM_THREADS{csr_commit_fire}} & csr_commit_if.tmask,
    `ifdef EXT_F_ENABLE
        {`NUM_THREADS{fpu_commit_fire}} & fpu_commit_if.tmask,
    `endif
        {`NUM_THREADS{gpu_commit_fire}} & gpu_commit_if.tmask
    };
    
    `POP_COUNT(commit_size, commit_tmask);

    VX_pipe_register #(
        .DATAW  (1 + $bits(commit_size)),
        .RESETW (1)
    ) pipe_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({commit_fire,         commit_size}),
        .data_out ({cmt_to_csr_if.valid, cmt_to_csr_if.commit_size})
    );

    // Writeback

    VX_writeback #(
        .CORE_ID(CORE_ID)
    ) writeback (
        .clk            (clk),
        .reset          (reset),

        .alu_commit_if  (alu_commit_if),
        .ld_commit_if   (ld_commit_if),        
        .csr_commit_if  (csr_commit_if),
    `ifdef EXT_F_ENABLE
        .fpu_commit_if  (fpu_commit_if),
    `endif
        .gpu_commit_if  (gpu_commit_if),
        .writeback_if   (writeback_if)
    );

    always_ff @(posedge clk) begin
        if(!cmt_to_csr_if.timeit_enable) cmt_to_csr_if.timeit_active <= '0;
        else begin
            for (integer i = 0; i < $bits(commit_valid); ++i) begin
                for (integer w = 0; w < `NUM_WARPS; ++w) begin
                    if(commit_valid[i] && (commit_wid[i] == `NW_BITS'(w))) begin
                        if(commit_pcs[i] == cmt_to_csr_if.timeit_start_addr)
                            cmt_to_csr_if.timeit_active[w] <= 1'b1;
                        if(commit_pcs[i] == cmt_to_csr_if.timeit_end_addr)
                            cmt_to_csr_if.timeit_active[w] <= 1'b0;
                    end
                end
            end
        end
    end

    // store and gpu commits don't writeback  
    assign st_commit_if.ready  = 1'b1;

`ifdef DBG_TRACE_CORE_PIPELINE
    always @(posedge clk) begin
        if (alu_commit_if.valid && alu_commit_if.ready) begin
             dpi_trace("%d: core%0d-commit: wid=%0d, PC=%0h, ex=ALU, tmask=%b, wb=%0d, rd=%0d, data=", $time, CORE_ID, alu_commit_if.wid, alu_commit_if.PC, alu_commit_if.tmask, alu_commit_if.wb, alu_commit_if.rd);
            `TRACE_ARRAY1D(alu_commit_if.data, `NUM_THREADS);
             dpi_trace(" (#%0d)\n", alu_commit_if.uuid);
        end
        if (ld_commit_if.valid && ld_commit_if.ready) begin
             dpi_trace("%d: core%0d-commit: wid=%0d, PC=%0h, ex=LSU, tmask=%b, wb=%0d, rd=%0d, data=", $time, CORE_ID, ld_commit_if.wid, ld_commit_if.PC, ld_commit_if.tmask, ld_commit_if.wb, ld_commit_if.rd);
            `TRACE_ARRAY1D(ld_commit_if.data, `NUM_THREADS);
             dpi_trace(" (#%0d)\n", ld_commit_if.uuid);
        end
        if (st_commit_if.valid && st_commit_if.ready) begin
            dpi_trace("%d: core%0d-commit: wid=%0d, PC=%0h, ex=LSU, tmask=%b, wb=%0d, rd=%0d (#%0d)\n", $time, CORE_ID, st_commit_if.wid, st_commit_if.PC, st_commit_if.tmask, st_commit_if.wb, st_commit_if.rd, st_commit_if.uuid);
        end
        if (csr_commit_if.valid && csr_commit_if.ready) begin
             dpi_trace("%d: core%0d-commit: wid=%0d, PC=%0h, ex=CSR, tmask=%b, wb=%0d, rd=%0d, data=", $time, CORE_ID, csr_commit_if.wid, csr_commit_if.PC, csr_commit_if.tmask, csr_commit_if.wb, csr_commit_if.rd);
            `TRACE_ARRAY1D(csr_commit_if.data, `NUM_THREADS);
             dpi_trace(" (#%0d)\n", csr_commit_if.uuid);
        end      
    `ifdef EXT_F_ENABLE
        if (fpu_commit_if.valid && fpu_commit_if.ready) begin
             dpi_trace("%d: core%0d-commit: wid=%0d, PC=%0h, ex=FPU, tmask=%b, wb=%0d, rd=%0d, data=", $time, CORE_ID, fpu_commit_if.wid, fpu_commit_if.PC, fpu_commit_if.tmask, fpu_commit_if.wb, fpu_commit_if.rd);
            `TRACE_ARRAY1D(fpu_commit_if.data, `NUM_THREADS);
             dpi_trace(" (#%0d)\n", fpu_commit_if.uuid);
        end
    `endif
        if (gpu_commit_if.valid && gpu_commit_if.ready) begin
             dpi_trace("%d: core%0d-commit: wid=%0d, PC=%0h, ex=GPU, tmask=%b, wb=%0d, rd=%0d, data=", $time, CORE_ID, gpu_commit_if.wid, gpu_commit_if.PC, gpu_commit_if.tmask, gpu_commit_if.wb, gpu_commit_if.rd);
            `TRACE_ARRAY1D(gpu_commit_if.data, `NUM_THREADS);
             dpi_trace(" (#%0d)\n", gpu_commit_if.uuid);
        end
    end
`endif

endmodule







