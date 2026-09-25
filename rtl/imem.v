`timescale 1ns/1ps

module imem #(
    parameter DEPTH = 256,          // 256 words = 1KB
    parameter MEM_FILE = "",        // Optional hex file for $readmemh
    parameter SYNC_READ = 0         // 0=async (sim), 1=sync (FPGA BRAM)
) (
    input  clk,                     // Required for SYNC_READ=1
    input  [31:0] addr,             // Byte address
    output reg [31:0] instr          // Instruction word
);

    // ROM storage
    reg [31:0] mem [0:DEPTH-1];
    integer i;

    // Initialize memory to NOPs (ADDI x0, x0, 0) unless a file is provided
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h00000013;
        if (MEM_FILE != "")
            $readmemh(MEM_FILE, mem);
    end

    // Combinational read for simulation (async IMEM)
    always @(*) begin
        instr = mem[addr[31:2]];
    end

endmodule
