// Control unit for RV32I/RV32M + TTISA-32: maps opcode/funct3/funct7 to the
// datapath control signals. Fields are only used when the opcode says they are
// valid, so e.g. funct7 is ignored for I-type instructions.
module control_unit(
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    
    // ALU operation select (output from this unit)
    output reg  [3:0]  alu_op,
    
    // Register write control
    output reg         reg_we,      // register write enable
    output reg         reg_wa_src,  // write-back data: 0=ALU/mem/etc, 1=PC+4 (JAL/JALR)
    
    // ALU operand sources
    output reg  [1:0]  alu_a_src,   // 00=rs1, 01=PC, 10=zero
    output reg         alu_b_src,   // 0=rs2 from regfile, 1=immediate
    
    // Memory operations
    output reg         mem_we,      // memory write enable
    output reg         mem_re,      // memory read enable
    output reg  [2:0]  mem_width,   // 000=byte, 001=half, 010=word
    output reg         mem_sign_ext,// sign extend load (vs zero-extend)
    
    // Branch & jump control
    output reg         branch_en,   // conditional branch (condition checked in core)
    output reg         jump_en,     // unconditional jump
    output reg         jalr_en,     // JALR jump (target = rs1 + imm from the ALU)
    
    // M-extension (multiply/divide)
    output reg         m_ext_en,    // enable M-extension unit
    output reg  [2:0]  m_op,        // MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU

    // TTISA-32 time-travel extension (custom-0 opcode 0001011)
    output reg         tt_en,       // valid TT instruction
    output reg  [2:0]  tt_op        // funct3: CHECKPOINT/SNAPSHOT/RESTORE/REWIND/FORWARD
);

    // ALU operation codes (must match alu.v)
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_SLL  = 4'd2;
    localparam ALU_SRL  = 4'd3;
    localparam ALU_SRA  = 4'd4;
    localparam ALU_AND  = 4'd5;
    localparam ALU_OR   = 4'd6;
    localparam ALU_XOR  = 4'd7;
    localparam ALU_SLT  = 4'd8;
    localparam ALU_SLTU = 4'd9;

    // Main opcode decode with field validation
    always @(*) begin
        // Default: all controls inactive
        alu_op       = ALU_ADD;
        reg_we       = 1'b0;
        reg_wa_src   = 1'b0;
        alu_a_src    = 2'b00;
        alu_b_src    = 1'b0;
        mem_we       = 1'b0;
        mem_re       = 1'b0;
        mem_width    = 3'b000;
        mem_sign_ext = 1'b0;
        branch_en    = 1'b0;
        jump_en      = 1'b0;
        jalr_en      = 1'b0;
        m_ext_en     = 1'b0;
        m_op         = 3'b000;
        tt_en        = 1'b0;
        tt_op        = 3'b000;

        case(opcode)
            // ===== LUI (Load Upper Immediate) =====
            // Valid fields: opcode, rd, imm_u
            // Execution: rd = imm_u
            7'b0110111: begin
                reg_we     = 1'b1;           // write to register
                alu_a_src  = 2'b10;          // use zero so 0 + imm_u = imm_u
                alu_b_src  = 1'b1;           // use imm_u
                alu_op     = ALU_ADD;        // 0 + imm_u
            end

            // ===== AUIPC (Add Upper Immediate to PC) =====
            // Valid fields: opcode, rd, imm_u
            // Execution: rd = PC + imm_u
            7'b0010111: begin
                reg_we     = 1'b1;
                alu_a_src  = 2'b01;          // use PC
                alu_b_src  = 1'b1;           // use immediate
                alu_op     = ALU_ADD;
            end

            // ===== JAL (Jump And Link) =====
            // Valid fields: opcode, rd, imm_j
            // Execution: rd = PC+4; PC = PC + imm_j
            7'b1101111: begin
                reg_we     = 1'b1;
                reg_wa_src = 1'b1;           // write PC+4 (not ALU result)
                jump_en    = 1'b1;           // PC = PC + imm_j (target adder in core)
            end

            // ===== JALR (Jump And Link Register) =====
            // Valid fields: opcode, rd, rs1, imm_i, funct3 (must be 000)
            // Execution: rd = PC+4; PC = rs1 + imm_i
            7'b1100111: begin
                if (funct3 == 3'b000) begin
                    reg_we     = 1'b1;
                    reg_wa_src = 1'b1;       // write PC+4
                    jalr_en    = 1'b1;       // PC = (rs1 + imm_i) & ~1
                    alu_a_src  = 2'b00;      // use rs1
                    alu_b_src  = 1'b1;       // use imm_i
                    alu_op     = ALU_ADD;    // compute address: rs1 + imm_i
                end
            end

            // ===== BRANCH (BEQ, BNE, BLT, BGE, BLTU, BGEU) =====
            // Valid fields: opcode, rs1, rs2, funct3, imm_b
            // Execution: if (condition) PC = PC + imm_b; else PC = PC + 4
            // The core compares rs1/rs2 itself (funct3 picks the condition) and
            // has its own target adder, so the ALU is not used here.
            7'b1100011: begin
                branch_en  = 1'b1;
            end

            // ===== LOAD (LW, LH, LB, LHU, LBU) =====
            // Valid fields: opcode, rd, rs1, imm_i, funct3
            // Execution: rd = mem[rs1 + imm_i]
            7'b0000011: begin
                mem_re     = 1'b1;           // memory read enable
                reg_we     = 1'b1;           // write result to register
                alu_a_src  = 2'b00;          // use rs1
                alu_b_src  = 1'b1;           // use imm_i for address offset
                alu_op     = ALU_ADD;        // compute address: rs1 + imm_i
                case(funct3)
                    3'b000: begin mem_width = 3'b000; mem_sign_ext = 1'b1; end // LB (byte, sign-extend)
                    3'b001: begin mem_width = 3'b001; mem_sign_ext = 1'b1; end // LH (half, sign-extend)
                    3'b010: begin mem_width = 3'b010; mem_sign_ext = 1'b0; end // LW (word, no extension)
                    3'b100: begin mem_width = 3'b000; mem_sign_ext = 1'b0; end // LBU (byte, zero-extend)
                    3'b101: begin mem_width = 3'b001; mem_sign_ext = 1'b0; end // LHU (half, zero-extend)
                    default: ;
                endcase
            end

            // ===== STORE (SW, SH, SB) =====
            // Valid fields: opcode, rs1, rs2, imm_s, funct3
            // Execution: mem[rs1 + imm_s] = rs2
            7'b0100011: begin
                mem_we     = 1'b1;           // memory write enable
                alu_a_src  = 2'b00;          // use rs1
                alu_b_src  = 1'b1;           // use imm_s for address offset
                alu_op     = ALU_ADD;        // compute address: rs1 + imm_s
                case(funct3)
                    3'b000: mem_width = 3'b000; // SB (byte)
                    3'b001: mem_width = 3'b001; // SH (half)
                    3'b010: mem_width = 3'b010; // SW (word)
                    default: ;
                endcase
            end

            // ===== ALU Immediate (ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU) =====
            // Valid fields: opcode, rd, rs1, imm_i, funct3, funct7[5] (for shifts)
            // Execution: rd = rs1 OP imm_i
            7'b0010011: begin
                reg_we     = 1'b1;           // write to register
                alu_a_src  = 2'b00;          // use rs1
                alu_b_src  = 1'b1;           // use imm_i
                case(funct3)
                    3'b000: alu_op = ALU_ADD;   // ADDI
                    3'b010: alu_op = ALU_SLT;   // SLTI (signed)
                    3'b011: alu_op = ALU_SLTU;  // SLTIU (unsigned)
                    3'b100: alu_op = ALU_XOR;   // XORI
                    3'b110: alu_op = ALU_OR;    // ORI
                    3'b111: alu_op = ALU_AND;   // ANDI
                    3'b001: alu_op = ALU_SLL;   // SLLI
                    3'b101: begin
                        // SRLI or SRAI depends on funct7[5]
                        if (funct7[5])
                            alu_op = ALU_SRA;   // SRAI
                        else
                            alu_op = ALU_SRL;   // SRLI
                    end
                endcase
            end

            // ===== ALU Register (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU) =====
            // Valid fields: opcode, rd, rs1, rs2, funct3, funct7
            // Execution: rd = rs1 OP rs2
            7'b0110011: begin
                reg_we     = 1'b1;           // write to register
                alu_a_src  = 2'b00;          // use rs1
                alu_b_src  = 1'b0;           // use rs2
                
                // Check if this is M-extension (funct7[0] == 1)
                if (funct7[0]) begin
                    m_ext_en   = 1'b1;       // enable M-extension
                    m_op       = funct3;     // funct3 selects MUL/MULH/DIV/etc
                end else begin
                    // Standard ALU operations
                    case(funct3)
                        3'b000: begin
                            if (funct7[5])
                                alu_op = ALU_SUB;    // SUB
                            else
                                alu_op = ALU_ADD;    // ADD
                        end
                        3'b001: alu_op = ALU_SLL;   // SLL
                        3'b010: alu_op = ALU_SLT;   // SLT
                        3'b011: alu_op = ALU_SLTU;  // SLTU
                        3'b100: alu_op = ALU_XOR;   // XOR
                        3'b101: begin
                            if (funct7[5])
                                alu_op = ALU_SRA;    // SRA
                            else
                                alu_op = ALU_SRL;    // SRL
                        end
                        3'b110: alu_op = ALU_OR;    // OR
                        3'b111: alu_op = ALU_AND;   // AND
                    endcase
                end
            end

            // ===== TTISA-32 (CHECKPOINT, SNAPSHOT, RESTORE, REWIND, FORWARD) =====
            // Valid fields: opcode, funct7 (must be 0), funct3 (000-100), rd (SNAPSHOT), rs1 (RESTORE)
            // Execution: handled by tt_unit; only SNAPSHOT writes rd (the snapshot ID)
            7'b0001011: begin
                if (funct7 == 7'b0000000 && funct3 <= 3'b100) begin
                    tt_en  = 1'b1;
                    tt_op  = funct3;
                    reg_we = (funct3 == 3'b001);   // SNAPSHOT rd
                end
            end

            // Any other opcode: NOP (do nothing)
            default: begin
                // All signals remain inactive
            end
        endcase
    end

endmodule
