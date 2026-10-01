`timescale 1ns/1ps

// Instruction memory (ROM), read combinationally so the single-cycle core
// gets the instruction in the same cycle as the PC.
module imem #(
    parameter DEPTH = 256,          // words (256 words = 1 KB)
    parameter MEM_FILE = ""         // optional hex file for $readmemh
) (
    input  [31:0] addr,             // byte address (low 2 bits ignored)
    output reg [31:0] instr         // instruction word
);

    reg [31:0] mem [0:DEPTH-1];
    integer i;

    // Fill with NOPs (ADDI x0, x0, 0), then load the program if a file is given
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h00000013;
        if (MEM_FILE != "")
            $readmemh(MEM_FILE, mem);
    end

    // Word-aligned read: byte address / 4
    always @(*) begin
        instr = mem[addr[31:2]];
    end

endmodule
