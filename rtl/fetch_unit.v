`timescale 1ns/1ps

module fetch_unit (
    input clk,
    input rst,
    
    // Branch/Jump control (from control_unit)
    input branch_taken,           // 1 = take branch or jump
    input [31:0] branch_target,   // Target address for branch/jump
    
    // Output: Program Counter
    output reg [31:0] pc,
    output [31:0] pc_next         // PC for next fetch (combinational)
);
    
    // PC incrementer: standard increment by 4 (one instruction)
    // In a 32-bit system, each instruction is 4 bytes (word-aligned)
    assign pc_next = (branch_taken) ? branch_target : (pc + 32'd4);
    
    // Update PC on clock edge
    always @(posedge clk) begin
        if (rst)
            pc <= 32'h0;          // Reset to instruction 0
        else
            pc <= pc_next;        // Load next PC
    end
    
endmodule
