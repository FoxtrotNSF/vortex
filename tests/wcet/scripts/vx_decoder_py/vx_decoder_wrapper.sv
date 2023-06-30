`include "VX_define.vh"

module vx_decoder_wrapper (
    input wire [31:0]             in_data,

    output wire [`EX_BITS-1:0]     ex_type,
    output wire [`INST_OP_BITS-1:0] op_type,
    output wire [`INST_MOD_BITS-1:0] op_mod,
    output wire                    wb,
    output wire                    use_PC,
    output wire                    use_imm,
    output wire [31:0]             imm,
    output wire [`NR_BITS-1:0]     rd,
    output wire [`NR_BITS-1:0]     rs1,
    output wire [`NR_BITS-1:0]     rs2,
    output wire [`NR_BITS-1:0]     rs3
);

    VX_ifetch_rsp_if #() ifetch_rsp_if();

    assign ifetch_rsp_if.valid = 1'b1;
    assign ifetch_rsp_if.uuid = 'b0;
    assign ifetch_rsp_if.tmask = 'b0;
    assign ifetch_rsp_if.wid = 'b0;
    assign ifetch_rsp_if.PC = 'b0;
    assign ifetch_rsp_if.data = in_data;
    assign ifetch_rsp_if.ready = 1'b1;


    VX_decode_if #() decode_if;
    assign valid = decode_if.valid;
    assign ex_type = decode_if.ex_type;
    assign op_type = decode_if.op_type;
    assign op_mod = decode_if.op_mod;
    assign wb = decode_if.wb;
    assign use_PC = decode_if.use_PC;
    assign use_imm = decode_if.use_imm;
    assign imm = decode_if.imm;
    assign rd = decode_if.rd;
    assign rs1 = decode_if.rs1;
    assign rs2 = decode_if.rs2;
    assign rs3 = decode_if.rs3;

    VX_wstall_if #() wstall_if;
    VX_join_if #()   join_if;

    VX_decode #(
        .CORE_ID(0)
    ) decode (
        .clk            (1'b0),
        .reset          (1'b0),
        .ifetch_rsp_if  (ifetch_rsp_if),
        .decode_if      (decode_if),
        .wstall_if      (wstall_if),
        .join_if        (join_if)
    );

endmodule
