`include "VX_define.vh"

module VX_gpr_wrapper (
    input wire      clk,
    input wire      reset,    
    VX_wb_if        writeback_if,
    VX_gpr_read_if  gpr_read_if
); 
    wire [`NUM_WARPS-1:0][`NUM_THREADS-1:0][31:0] tmp_a_reg_data;
    wire [`NUM_WARPS-1:0][`NUM_THREADS-1:0][31:0] tmp_b_reg_data;
    wire [`NUM_THREADS-1:0][31:0] jal_data;

    genvar i;
    generate 
    for (i = 0; i < `NUM_THREADS; i++) begin : jal_data_assign
        assign jal_data[i] = gpr_read_if.curr_PC;
    end
    endgenerate

    `ifndef ASIC
        assign gpr_read_if.a_reg_data = gpr_read_if.is_jal ? jal_data : tmp_a_reg_data[gpr_read_if.warp_num];
        assign gpr_read_if.b_reg_data = tmp_b_reg_data[gpr_read_if.warp_num];
    `else 

        wire [`NW_BITS-1:0] old_warp_num; 
           
        VX_generic_register #(
            .N(`NW_BITS-1+1)
        ) store_wn (
            .clk   (clk),
            .reset (reset),
            .stall (1'b0),
            .flush (1'b0),
            .in    (gpr_read_if.warp_num),
            .out   (old_warp_num)
        );

        assign gpr_read_if.a_reg_data = gpr_jal_if.is_jal ? jal_data : tmp_a_reg_data[old_warp_num];
        assign gpr_read_if.b_reg_data = tmp_b_reg_data[old_warp_num];
        
    `endif

    generate        
        for (i = 0; i < `NUM_WARPS; i++) begin : warp_gprs
            wire write_ce = (i == writeback_if.warp_num);
            VX_gpr_ram gpr_ram(
                .clk            (clk),
                .reset          (reset),
                .write_ce       (write_ce),
                .gpr_read_if    (gpr_read_if),
                .writeback_if   (writeback_if),
                .a_reg_data     (tmp_a_reg_data[i]),
                .b_reg_data     (tmp_b_reg_data[i])
            );
        end
    endgenerate

endmodule

