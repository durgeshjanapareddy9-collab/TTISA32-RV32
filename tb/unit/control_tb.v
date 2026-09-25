// Unit testbench for control_unit: verify all instruction types generate correct signals
`timescale 1ns/1ps
module tb;
    reg  [6:0]  opcode;
    reg  [2:0]  funct3;
    reg  [6:0]  funct7;
    wire [3:0]  alu_op;
    wire        reg_we;
    wire        reg_wa_src;
    wire [1:0]  alu_a_src;
    wire        alu_b_src;
    wire        mem_we;
    wire        mem_re;
    wire [2:0]  mem_width;
    wire        mem_sign_ext;
    wire        branch_en;
    wire        jump_en;
    wire        jalr_en;
    wire        m_ext_en;
    wire [2:0]  m_op;

    control_unit dut(
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .alu_op(alu_op),
        .reg_we(reg_we),
        .reg_wa_src(reg_wa_src),
        .alu_a_src(alu_a_src),
        .alu_b_src(alu_b_src),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .mem_width(mem_width),
        .mem_sign_ext(mem_sign_ext),
        .branch_en(branch_en),
        .jump_en(jump_en),
        .jalr_en(jalr_en),
        .m_ext_en(m_ext_en),
        .m_op(m_op)
    );

    task check1;
        input name;
        input [7:0] got;
        input [7:0] exp;
        begin
            if (got !== exp)
                $display("FAIL %s got=%b exp=%b", name, got, exp);
            else
                $display("PASS %s", name);
        end
    endtask

    initial begin
        // ===== Test 1: LUI (U-type) =====
        // Expected: reg_we=1, alu_op=ADD, alu_a_src=2'b10 (zero), alu_b_src=1 (imm)
        opcode = 7'b0110111; funct3 = 3'b000; funct7 = 7'b0000000;
        #1;
        check1("LUI reg_we",    reg_we,    1'b1);
        check1("LUI alu_a_src", alu_a_src, 2'b10);
        check1("LUI alu_b_src", alu_b_src, 1'b1);
        check1("LUI alu_op",    alu_op,    4'd0);   // ADD

        // ===== Test 2: ADD (R-type, funct7=0000000, funct3=000) =====
        // Expected: reg_we=1, alu_op=ADD, alu_a_src=2'b00 (rs1), alu_b_src=0 (rs2)
        opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0000000;
        #1;
        check1("ADD reg_we",    reg_we,    1'b1);
        check1("ADD alu_a_src", alu_a_src, 2'b00);
        check1("ADD alu_b_src", alu_b_src, 1'b0);
        check1("ADD alu_op",    alu_op,    4'd0);   // ADD

        // ===== Test 3: SUB (R-type, funct7=0100000, funct3=000) =====
        // Expected: reg_we=1, alu_op=SUB
        opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0100000;
        #1;
        check1("SUB reg_we",  reg_we,  1'b1);
        check1("SUB alu_op",  alu_op,  4'd1);      // SUB

        // ===== Test 4: MUL (R-type M-extension, funct7=0000001, funct3=000) =====
        // Expected: reg_we=1, m_ext_en=1, m_op=000
        opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0000001;
        #1;
        check1("MUL reg_we",    reg_we,    1'b1);
        check1("MUL m_ext_en",  m_ext_en,  1'b1);
        check1("MUL m_op",      m_op,      3'b000);

        // ===== Test 5: DIV (R-type M-extension, funct7=0000001, funct3=100) =====
        // Expected: reg_we=1, m_ext_en=1, m_op=100
        opcode = 7'b0110011; funct3 = 3'b100; funct7 = 7'b0000001;
        #1;
        check1("DIV reg_we",    reg_we,    1'b1);
        check1("DIV m_ext_en",  m_ext_en,  1'b1);
        check1("DIV m_op",      m_op,      3'b100);

        // ===== Test 6: ADDI (I-type, funct3=000) =====
        // Expected: reg_we=1, alu_a_src=2'b00 (rs1), alu_b_src=1 (imm), alu_op=ADD
        opcode = 7'b0010011; funct3 = 3'b000; funct7 = 7'b0000000;
        #1;
        check1("ADDI reg_we",    reg_we,    1'b1);
        check1("ADDI alu_a_src", alu_a_src, 2'b00);
        check1("ADDI alu_b_src", alu_b_src, 1'b1);
        check1("ADDI alu_op",    alu_op,    4'd0);  // ADD

        // ===== Test 7: SLLI (I-type shift, funct3=001) =====
        // Expected: reg_we=1, alu_op=SLL
        opcode = 7'b0010011; funct3 = 3'b001; funct7 = 7'b0000000;
        #1;
        check1("SLLI reg_we",   reg_we,   1'b1);
        check1("SLLI alu_op",   alu_op,   4'd2);   // SLL

        // ===== Test 8: SRLI (I-type shift, funct3=101, funct7[5]=0) =====
        // Expected: alu_op=SRL
        opcode = 7'b0010011; funct3 = 3'b101; funct7 = 7'b0000000;
        #1;
        check1("SRLI alu_op", alu_op, 4'd3);   // SRL

        // ===== Test 9: SRAI (I-type shift, funct3=101, funct7[5]=1) =====
        // Expected: alu_op=SRA
        opcode = 7'b0010011; funct3 = 3'b101; funct7 = 7'b0100000;
        #1;
        check1("SRAI alu_op", alu_op, 4'd4);   // SRA

        // ===== Test 10: LW (I-type Load, funct3=010) =====
        // Expected: mem_re=1, reg_we=1, mem_width=010, mem_sign_ext=0
        opcode = 7'b0000011; funct3 = 3'b010; funct7 = 7'b0000000;
        #1;
        check1("LW mem_re",       mem_re,       1'b1);
        check1("LW reg_we",       reg_we,       1'b1);
        check1("LW mem_width",    mem_width,    3'b010);
        check1("LW mem_sign_ext", mem_sign_ext, 1'b0);

        // ===== Test 11: LB (I-type Load, funct3=000) =====
        // Expected: mem_re=1, mem_width=000, mem_sign_ext=1
        opcode = 7'b0000011; funct3 = 3'b000; funct7 = 7'b0000000;
        #1;
        check1("LB mem_re",       mem_re,       1'b1);
        check1("LB mem_width",    mem_width,    3'b000);
        check1("LB mem_sign_ext", mem_sign_ext, 1'b1);

        // ===== Test 12: SW (S-type Store, funct3=010) =====
        // Expected: mem_we=1, mem_width=010, reg_we=0 (no register update)
        opcode = 7'b0100011; funct3 = 3'b010; funct7 = 7'b0000000;
        #1;
        check1("SW mem_we",    mem_we,    1'b1);
        check1("SW mem_width", mem_width, 3'b010);
        check1("SW reg_we",    reg_we,    1'b0);

        // ===== Test 13: BEQ (B-type Branch, funct3=000) =====
        // Expected: branch_en=1, alu_a_src=2'b00 (rs1), alu_b_src=0 (rs2), alu_op=SUB
        opcode = 7'b1100011; funct3 = 3'b000; funct7 = 7'b0000000;
        #1;
        check1("BEQ branch_en",   branch_en,   1'b1);
        check1("BEQ alu_a_src",   alu_a_src,   2'b00);
        check1("BEQ alu_b_src",   alu_b_src,   1'b0);
        check1("BEQ alu_op",      alu_op,      4'd1); // SUB (to check zero flag)

        // ===== Test 14: BLT (B-type Branch, funct3=100) =====
        // Expected: branch_en=1, alu_op=SLT
        opcode = 7'b1100011; funct3 = 3'b100; funct7 = 7'b0000000;
        #1;
        check1("BLT branch_en", branch_en, 1'b1);
        check1("BLT alu_op",    alu_op,    4'd8); // SLT

        // ===== Test 15: JAL (J-type Jump, all funct fields ignored) =====
        // Expected: reg_we=1, reg_wa_src=1 (PC+4), jump_en=1
        opcode = 7'b1101111; funct3 = 3'b000; funct7 = 7'b0000000;
        #1;
        check1("JAL reg_we",      reg_we,      1'b1);
        check1("JAL reg_wa_src",  reg_wa_src,  1'b1);
        check1("JAL jump_en",     jump_en,     1'b1);

        // ===== Test 16: JALR (I-type variant, funct3=000) =====
        // Expected: reg_we=1, reg_wa_src=1 (PC+4), jalr_en=1, alu_op=ADD (for address calc)
        opcode = 7'b1100111; funct3 = 3'b000; funct7 = 7'b0000000;
        #1;
        check1("JALR reg_we",      reg_we,      1'b1);
        check1("JALR reg_wa_src",  reg_wa_src,  1'b1);
        check1("JALR jalr_en",     jalr_en,     1'b1);
        check1("JALR alu_op",      alu_op,      4'd0); // ADD (rs1+imm)

        // ===== Test 17: AUIPC (U-type variant) =====
        // Expected: reg_we=1, alu_a_src=2'b01 (PC), alu_b_src=1 (imm), alu_op=ADD
        opcode = 7'b0010111; funct3 = 3'b000; funct7 = 7'b0000000;
        #1;
        check1("AUIPC reg_we",    reg_we,    1'b1);
        check1("AUIPC alu_a_src", alu_a_src, 2'b01);
        check1("AUIPC alu_b_src", alu_b_src, 1'b1);
        check1("AUIPC alu_op",    alu_op,    4'd0);

        $display("CONTROL_UNIT TESTS COMPLETE");
        #10 $finish;
    end

endmodule
