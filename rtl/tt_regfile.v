// 32x32 register file for the single-cycle core, with TTISA-32 support.
//
// - No write-through bypass. In a single-cycle datapath the write data is
//   computed from the read data in the same cycle, so a bypass would form a
//   combinational loop (e.g. ADD x1, x1, x2).
// - All 31 architectural registers (x1..x31) are exposed as one flat bus so
//   the tt_unit can copy them into a checkpoint bank in a single clock.
// - A restore port loads all 31 registers in parallel from a checkpoint bank.
//
// Flat bus layout: regs_flat[(i-1)*32 +: 32] = x[i], for i = 1..31.
module tt_regfile(
    input  wire         clk,
    input  wire         rst_n,

    // Normal read/write ports
    input  wire         we,
    input  wire [4:0]   ra1,
    input  wire [4:0]   ra2,
    input  wire [4:0]   wa,
    input  wire [31:0]  wd,
    output wire [31:0]  rd1,
    output wire [31:0]  rd2,

    // Time-travel ports
    output wire [991:0] regs_flat,      // current x1..x31 (to checkpoint banks)
    input  wire         restore_en,     // load all registers from restore_data
    input  wire [991:0] restore_data    // checkpoint image x1..x31
);
    reg [31:0] regs [1:31];
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else if (restore_en) begin
            // Restore takes priority; TT restore instructions never write rd
            for (i = 1; i < 32; i = i + 1)
                regs[i] <= restore_data[(i-1)*32 +: 32];
        end else if (we && (wa != 5'd0)) begin
            regs[wa] <= wd;
        end
    end

    // Combinational reads, x0 hardwired to zero
    assign rd1 = (ra1 == 5'd0) ? 32'b0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'b0 : regs[ra2];

    genvar g;
    generate
        for (g = 1; g < 32; g = g + 1) begin : g_flat
            assign regs_flat[(g-1)*32 +: 32] = regs[g];
        end
    endgenerate

endmodule
