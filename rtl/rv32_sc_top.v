`timescale 1ns/1ps

// Single-cycle system: core + instruction ROM + data RAM (Harvard).
// Both memories read combinationally so an instruction completes in one cycle.
module rv32_sc_top #(
    parameter IMEM_DEPTH = 1024,        // words
    parameter DMEM_DEPTH = 1024,        // words
    parameter IMEM_FILE  = ""
) (
    input clk,
    input rst_n
);
    wire [31:0] imem_addr, imem_instr;
    wire [31:0] dmem_addr, dmem_wr_data, dmem_rd_data;
    wire [3:0]  dmem_byte_enable;
    wire        dmem_we, dmem_re;

    rv32_sc_core core (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_instr(imem_instr),
        .dmem_addr(dmem_addr),
        .dmem_wr_data(dmem_wr_data),
        .dmem_byte_enable(dmem_byte_enable),
        .dmem_we(dmem_we),
        .dmem_re(dmem_re),
        .dmem_rd_data(dmem_rd_data)
    );

    imem #(.DEPTH(IMEM_DEPTH), .MEM_FILE(IMEM_FILE)) imem_inst (
        .clk(clk),
        .addr(imem_addr),
        .instr(imem_instr)
    );

    dmem #(.DEPTH(DMEM_DEPTH), .SYNC_READ(0)) dmem_inst (
        .clk(clk),
        .rst(~rst_n),
        .addr(dmem_addr),
        .wr_data(dmem_wr_data),
        .byte_enable(dmem_byte_enable),
        .mem_we(dmem_we),
        .mem_re(dmem_re),
        .rd_data(dmem_rd_data),
        .debug_addr(32'h0),
        .debug_data()
    );

endmodule
