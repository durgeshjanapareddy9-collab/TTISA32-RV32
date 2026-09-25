// TTISA-32 time-travel unit: checkpoint banks + timeline (history) pointer.
//
// State
//   bank[0..SLOTS-1] : saved images of x1..x31 (992 bits each)
//   count            : number of valid checkpoints; valid IDs are 0..count-1
//   pos              : checkpoint the CPU is currently "at or after"
//   at_cp            : 1 when the register state equals bank[pos], i.e. no
//                      ordinary instruction has executed since the last
//                      checkpoint/restore
//   overflow         : sticky flag, set when a save finds no free slot
//
// Instruction semantics (the PC always advances to PC+4)
//   CHECKPOINT  : save into slot s = (count==0) ? 0 : pos+1. Checkpoints after
//                 pos are discarded (count = s+1), like browser history.
//                 If s == SLOTS the save is dropped and overflow is set.
//   SNAPSHOT rd : same as CHECKPOINT, and rd = s (or 0xFFFFFFFF on overflow).
//                 The saved image is the state *before* rd is written.
//   RESTORE rs1 : restore bank[rs1] if rs1 < count, else no-op. pos = rs1.
//   REWIND      : restore the previous checkpoint. If instructions have run
//                 since the last checkpoint/restore (at_cp == 0), that is
//                 bank[pos] itself; otherwise bank[pos-1]. No-op at the start.
//   FORWARD     : restore bank[pos+1] if it exists, else no-op.
//
// Only registers x1..x31 are rolled back. The PC and data memory are not.
module tt_unit #(
    parameter SLOTS = 4,
    parameter SW    = 2                 // slot index width, log2(SLOTS)
) (
    input  wire         clk,
    input  wire         rst_n,

    // From control unit / register file
    input  wire         tt_en,          // current instruction is a TT instruction
    input  wire [2:0]   tt_op,          // funct3
    input  wire [31:0]  rs1_data,       // RESTORE handle
    input  wire [991:0] regs_flat,      // current x1..x31

    // To register file / write-back
    output wire         restore_en,
    output wire [991:0] restore_data,
    output wire [31:0]  snap_id,        // SNAPSHOT result for rd

    // Status (debug / waveform)
    output reg  [SW:0]  count,
    output reg  [SW-1:0] pos,
    output reg          at_cp,
    output reg          overflow
);
    localparam TT_CHECKPOINT = 3'b000;
    localparam TT_SNAPSHOT   = 3'b001;
    localparam TT_RESTORE    = 3'b010;
    localparam TT_REWIND     = 3'b011;
    localparam TT_FORWARD    = 3'b100;

    reg [991:0] bank [0:SLOTS-1];

    // ---- Save (CHECKPOINT / SNAPSHOT) ----
    wire         is_save   = tt_en && (tt_op == TT_CHECKPOINT || tt_op == TT_SNAPSHOT);
    wire [SW:0]  save_slot = (count == 0) ? {(SW+1){1'b0}} : {1'b0, pos} + 1'b1;
    wire         save_ok   = (save_slot < SLOTS);

    assign snap_id = save_ok ? {{(31-SW){1'b0}}, save_slot} : 32'hFFFF_FFFF;

    // ---- Restore target (RESTORE / REWIND / FORWARD) ----
    wire [SW:0]  pos_next  = {1'b0, pos} + 1'b1;

    reg          tgt_ok;
    reg [SW-1:0] tgt;

    always @(*) begin
        tgt_ok = 1'b0;
        tgt    = pos;
        case (tt_op)
            TT_RESTORE: begin
                tgt_ok = (rs1_data < count);
                tgt    = rs1_data[SW-1:0];
            end
            TT_REWIND: begin
                tgt_ok = (count != 0) && !(at_cp && pos == 0);
                tgt    = at_cp ? pos - 1'b1 : pos;
            end
            TT_FORWARD: begin
                tgt_ok = (count != 0) && (pos_next < count);
                tgt    = pos_next[SW-1:0];
            end
            default: ;
        endcase
    end

    assign restore_en   = tt_en && tgt_ok;
    assign restore_data = bank[tgt];

    // ---- Timeline state ----
    always @(posedge clk) begin
        if (!rst_n) begin
            count    <= 0;
            pos      <= 0;
            at_cp    <= 1'b0;
            overflow <= 1'b0;
        end else if (is_save) begin
            if (save_ok) begin
                bank[save_slot[SW-1:0]] <= regs_flat;
                pos   <= save_slot[SW-1:0];
                count <= save_slot + 1'b1;
                at_cp <= 1'b1;
            end else begin
                overflow <= 1'b1;
            end
        end else if (restore_en) begin
            pos   <= tgt;
            at_cp <= 1'b1;
        end else if (!tt_en) begin
            at_cp <= 1'b0;              // an ordinary instruction moved us off the checkpoint
        end
    end

endmodule
