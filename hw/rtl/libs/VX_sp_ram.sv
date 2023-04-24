`include "VX_platform.vh"

`TRACING_OFF
module VX_sp_ram #(
    parameter DATAW       = 1,
    parameter SIZE        = 1,
    parameter OUT_REG     = 0,
    parameter BYTEENW     = 1,
    parameter NO_RWCHECK  = 0,
    parameter LUTRAM      = 0,
    parameter ADDRW       = $clog2(SIZE),
    parameter INIT_ENABLE = 0,
    parameter INIT_FILE   = "",
    parameter [DATAW-1:0] INIT_VALUE = 0
) (  
    input wire               clk,
    input wire               en,
    input wire [ADDRW-1:0]   addr,
    input wire [BYTEENW-1:0] wren,
    input wire [DATAW-1:0]   wdata,
    output wire [DATAW-1:0]  rdata
);

    `STATIC_ASSERT((1 == BYTEENW) || ((BYTEENW > 1) && 0 == (BYTEENW % 4)), ("invalid parameter"))

`define RAM_INITIALIZATION                        \
    if (INIT_ENABLE) begin                        \
        if (INIT_FILE != "") begin                \
            initial $readmemh(INIT_FILE, ram);    \
        end else begin                            \
            initial                               \
                for (integer i = 0; i < SIZE; ++i)\
                    ram[i] = INIT_VALUE;          \
        end                                       \
    end

    generate
        reg [DATAW-1:0] rdata_r;
        if (LUTRAM) begin
            `USE_FAST_BRAM reg [DATAW-1:0] ram [SIZE-1:0];
            `RAM_INITIALIZATION
            if (BYTEENW > 1) begin
                for (genvar i = 0; i < BYTEENW; i = i+1) begin
                    always @(posedge clk) begin
                        if(en && wren[i])
                            ram[addr][(i+1)*8-1:i*8] <= wdata[(i+1)*8-1:i*8];
                    end
                end
            end else begin
                always @(posedge clk) begin
                    if (en && wren)
                        ram[addr] <= wdata;
                end
            end
            if(OUT_REG) begin
                always @ (posedge clk) begin
                    if (en)
                        rdata_r <= ram[addr];
                end
            end else begin
                assign rdata_r = ram[addr];
            end
        end else begin
            if (NO_RWCHECK) begin
                `NO_RW_RAM_CHECK reg [DATAW-1:0] ram [SIZE-1:0];
                `RAM_INITIALIZATION
                if (BYTEENW > 1) begin
                    for (genvar i = 0; i < BYTEENW; i = i+1) begin
                        always @(posedge clk) begin
                            if (en && wren[i])
                                 ram[addr][(i+1)*8-1:i*8] <= wdata[(i+1)*8-1:i*8];
                        end
                    end
                end else begin
                    always @(posedge clk) begin
                        if (en && wren)
                            ram[addr] <= wdata;
                    end
                end
                if(OUT_REG) begin
                    always @ (posedge clk) begin
                        if (en)
                            rdata_r <= ram[addr];
                    end
                end else begin
                    assign rdata_r = ram[addr];
                end
            end else begin
                reg [DATAW-1:0] ram [SIZE-1:0];
                `RAM_INITIALIZATION
                if (BYTEENW > 1) begin
                    for (genvar i = 0; i < BYTEENW; i = i+1) begin
                        always @(posedge clk) begin
                            if(en) begin
                                if (wren[i]) begin
                                    ram[addr][(i+1)*8-1:i*8] <= wdata[(i+1)*8-1:i*8];
                                    rdata_r[(i+1)*8-1:i*8]  <= wdata[(i+1)*8-1:i*8];
                                end else begin
                                    rdata_r[i*8 +: 8]  <= ram[addr][(i+1)*8-1:i*8] ;
                                end
                            end
                        end
                    end
                end else begin
                    if(OUT_REG) begin
                        always @(posedge clk) begin
                            if(en) begin
                                if (wren) begin
                                    ram[addr] <= wdata;
                                    rdata_r <= wdata;
                                end else
                                    rdata_r <= ram[addr];
                            end
                        end
                    end else begin
                        assign rdata_r = wren ? wdata : ram[addr];
                        always @(posedge clk) begin
                            if(en && wren)
                                ram[addr] <= wdata;
                        end
                    end
                end
            end
        end
        assign rdata = rdata_r;
    endgenerate

endmodule
`TRACING_ON