`timescale 1ns/1ps

// Data memory (RAM) with byte-enable writes.
// The single-cycle core uses SYNC_READ=0 so loads finish in the same cycle.
module dmem #(
    parameter DEPTH = 256,  // 256 words = 1KB
    parameter SYNC_READ = 1 // 1=registered read, 0=combinational read (single-cycle)
) (
    input clk,
    input rst,
    
    // Primary port (from LSU)
    input [31:0] addr,
    input [31:0] wr_data,
    input [3:0] byte_enable,
    input mem_we,      // write enable
    input mem_re,      // read enable
    output reg [31:0] rd_data,
    
    // Debug port (optional, for testing/inspection)
    input [31:0] debug_addr,
    output [31:0] debug_data
);
    
    reg [31:0] mem [0:DEPTH-1];
    integer i;
    
    // Initialize all memory to zero on startup
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0;
    end
    
    // Convert byte address to word address
    wire [31:0] word_addr = addr[31:2];
    wire [31:0] debug_word_addr = debug_addr[31:2];
    
    // ===== WRITE LOGIC (Synchronous) =====
    // Only write bytes that are enabled (byte_enable controls which bytes)
    // Memory contents are not cleared by reset, only by the initial block
    always @(posedge clk) begin
        if (!rst && mem_we) begin
            if (byte_enable[0])
                mem[word_addr][7:0] <= wr_data[7:0];
            if (byte_enable[1])
                mem[word_addr][15:8] <= wr_data[15:8];
            if (byte_enable[2])
                mem[word_addr][23:16] <= wr_data[23:16];
            if (byte_enable[3])
                mem[word_addr][31:24] <= wr_data[31:24];
        end
    end
    
    // ===== READ LOGIC =====
    generate
        if (SYNC_READ) begin : g_sync_read
            // Read happens at clock edge when mem_re=1
            always @(posedge clk) begin
                if (rst) begin
                    rd_data <= 32'h0;
                end else if (mem_re) begin
                    rd_data <= mem[word_addr];
                end
            end
        end else begin : g_async_read
            // Load data is available in the same cycle (single-cycle datapath)
            always @(*) begin
                rd_data = mem[word_addr];
            end
        end
    endgenerate
    
    // ===== DEBUG PORT (Combinational Read) =====
    // Allows immediate inspection without affecting main datapath
    assign debug_data = mem[debug_word_addr];

endmodule
