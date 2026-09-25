`timescale 1ns/1ps

// Unit test for tt_unit (checkpoint banks + timeline pointer) and the
// TTISA-32 decode in control_unit.
module tt_unit_tb;
    reg clk = 0;
    reg rst_n = 0;
    always #5 clk = ~clk;

    // ---------------- tt_unit ----------------
    reg          tt_en;
    reg  [2:0]   tt_op;
    reg  [31:0]  rs1_data;
    reg  [991:0] regs_flat;
    wire         restore_en;
    wire [991:0] restore_data;
    wire [31:0]  snap_id;
    wire [2:0]   count;
    wire [1:0]   pos;
    wire         at_cp;
    wire         overflow;

    tt_unit #(.SLOTS(4), .SW(2)) dut (
        .clk(clk), .rst_n(rst_n),
        .tt_en(tt_en), .tt_op(tt_op), .rs1_data(rs1_data), .regs_flat(regs_flat),
        .restore_en(restore_en), .restore_data(restore_data), .snap_id(snap_id),
        .count(count), .pos(pos), .at_cp(at_cp), .overflow(overflow)
    );

    localparam CHECKPOINT = 3'd0, SNAPSHOT = 3'd1, RESTORE = 3'd2,
               REWIND     = 3'd3, FORWARD  = 3'd4, NONE     = 3'd7;

    integer passed = 0;
    integer failed = 0;

    // Register image where every register holds value v
    function [991:0] img(input [31:0] v);
        img = {31{v}};
    endfunction

    task check(input [255:0] name, input cond);
        begin
            if (cond) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("FAIL: %0s  (count=%0d pos=%0d at_cp=%0d restore_en=%0d snap_id=%08h)",
                         name, count, pos, at_cp, restore_en, snap_id);
            end
        end
    endtask

    // Apply one instruction for one cycle. op = NONE means an ordinary instruction.
    task apply(input [2:0] op, input [31:0] rs1, input [31:0] regval);
        begin
            tt_en     = (op != NONE);
            tt_op     = (op == NONE) ? 3'd0 : op;
            rs1_data  = rs1;
            regs_flat = img(regval);
            #1;     // let combinational outputs settle before the edge
        end
    endtask

    task tick;
        begin
            @(posedge clk); #1;
        end
    endtask

    // ---------------- control_unit TT decode ----------------
    reg  [6:0] c_opcode;
    reg  [2:0] c_funct3;
    reg  [6:0] c_funct7;
    wire       c_tt_en, c_reg_we;
    wire [2:0] c_tt_op;

    control_unit cu (
        .opcode(c_opcode), .funct3(c_funct3), .funct7(c_funct7),
        .alu_op(), .reg_we(c_reg_we), .reg_wa_src(), .alu_a_src(), .alu_b_src(),
        .mem_we(), .mem_re(), .mem_width(), .mem_sign_ext(),
        .branch_en(), .jump_en(), .jalr_en(), .m_ext_en(), .m_op(),
        .tt_en(c_tt_en), .tt_op(c_tt_op)
    );

    integer f;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("waves/tt_unit_tb.vcd");
            $dumpvars(0, tt_unit_tb);
        end

        // ===== Decode =====
        c_opcode = 7'b0001011; c_funct7 = 7'd0;
        for (f = 0; f < 8; f = f + 1) begin
            c_funct3 = f; #1;
            check("decode: valid funct3 sets tt_en", c_tt_en == (f <= 4));
            if (f <= 4) check("decode: tt_op = funct3", c_tt_op == f);
            check("decode: only SNAPSHOT writes rd", c_reg_we == (f == 1));
        end
        c_funct3 = 3'd0; c_funct7 = 7'd1; #1;
        check("decode: funct7 != 0 is not TT", !c_tt_en && !c_reg_we);
        c_opcode = 7'b0110011; c_funct7 = 7'd0; #1;
        check("decode: other opcodes are not TT", !c_tt_en);

        // ===== Reset =====
        apply(NONE, 0, 0);
        repeat (2) @(posedge clk);
        rst_n = 1; #1;
        check("reset: empty timeline", count == 0 && pos == 0 && !at_cp && !overflow);

        // ===== Empty timeline: all restores are no-ops =====
        apply(REWIND, 0, 1);   check("empty: REWIND no-op",  !restore_en);
        apply(FORWARD, 0, 1);  check("empty: FORWARD no-op", !restore_en);
        apply(RESTORE, 0, 1);  check("empty: RESTORE no-op", !restore_en);
        tick;

        // ===== CP0 then SNAPSHOT (slot 1) =====
        apply(CHECKPOINT, 0, 10);
        check("CHECKPOINT: slot 0", snap_id == 0 && !restore_en);
        tick;
        check("CHECKPOINT: count=1 pos=0 at_cp", count == 1 && pos == 0 && at_cp);

        apply(NONE, 0, 99); tick;
        check("ordinary instr clears at_cp", !at_cp);

        apply(SNAPSHOT, 0, 11);
        check("SNAPSHOT: id 1", snap_id == 1);
        tick;
        check("SNAPSHOT: count=2 pos=1", count == 2 && pos == 1 && at_cp);

        // ===== REWIND / FORWARD =====
        apply(REWIND, 0, 99);
        check("REWIND at CP1 -> CP0", restore_en && restore_data == img(10));
        tick;
        check("REWIND: pos=0", pos == 0 && at_cp && count == 2);

        apply(REWIND, 0, 99);
        check("REWIND at CP0 -> no-op", !restore_en);
        tick;

        apply(FORWARD, 0, 99);
        check("FORWARD -> CP1", restore_en && restore_data == img(11));
        tick;
        check("FORWARD: pos=1", pos == 1);

        apply(FORWARD, 0, 99);
        check("FORWARD at newest -> no-op", !restore_en);
        tick;

        apply(NONE, 0, 99); tick;
        apply(REWIND, 0, 99);
        check("REWIND after instructions -> same CP", restore_en && restore_data == img(11));
        tick;
        check("REWIND: pos stays 1", pos == 1 && at_cp);

        // ===== RESTORE with handles =====
        apply(RESTORE, 0, 99);
        check("RESTORE 0", restore_en && restore_data == img(10));
        tick;
        check("RESTORE: pos=0, history kept", pos == 0 && count == 2);
        apply(RESTORE, 2, 99);           check("RESTORE 2 (invalid) no-op", !restore_en);
        apply(RESTORE, 32'hFFFFFFFF, 99); check("RESTORE -1 no-op", !restore_en);
        apply(RESTORE, 32'h4, 99);        check("RESTORE 4 (out of range) no-op", !restore_en);
        tick;

        // ===== Fill all slots, then overflow =====
        // pos=0: new checkpoint goes to slot 1 and discards the old slot 1
        apply(CHECKPOINT, 0, 20); check("fill: slot 1", snap_id == 1); tick;
        apply(SNAPSHOT,   0, 21); check("fill: slot 2", snap_id == 2); tick;
        apply(SNAPSHOT,   0, 22); check("fill: slot 3", snap_id == 3); tick;
        check("fill: count=4 pos=3", count == 4 && pos == 3 && !overflow);

        apply(SNAPSHOT, 0, 23);
        check("overflow: id = -1", snap_id == 32'hFFFFFFFF);
        tick;
        check("overflow: flag set, state unchanged", overflow && count == 4 && pos == 3);

        apply(RESTORE, 1, 99);
        check("slot 1 was overwritten", restore_en && restore_data == img(20));
        tick;

        // ===== Truncation: saving from pos=1 discards slots 2 and 3 =====
        apply(SNAPSHOT, 0, 30);
        check("truncate: new slot 2", snap_id == 2);
        tick;
        check("truncate: count=3", count == 3 && pos == 2);
        apply(RESTORE, 3, 99);
        check("truncate: slot 3 invalid", !restore_en);
        apply(RESTORE, 2, 99);
        check("truncate: slot 2 has new image", restore_en && restore_data == img(30));
        tick;

        // ===== Reset clears the timeline =====
        rst_n = 0; tick; rst_n = 1; #1;
        check("reset again: empty", count == 0 && !overflow && !at_cp);

        $display("tt_unit_tb: %0d passed, %0d failed", passed, failed);
        if (failed == 0) $display("ALL TESTS PASSED");
        $finish;
    end
endmodule
