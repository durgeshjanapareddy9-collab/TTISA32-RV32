`timescale 1ns/1ps

// RV32IM + TTISA-32 single-cycle core.
// Every instruction completes in one clock: fetch, decode, register read,
// execute, memory access and write-back are all combinational between two
// rising edges. State is updated only at the clock edge (PC, register file,
// data memory, time-travel unit).
module rv32_sc_core #(
    parameter TT_SLOTS = 4,
    parameter TT_SW    = 2
) (
    input clk,
    input rst_n,  // Active-low reset

    // Instruction memory interface
    output [31:0] imem_addr,
    input  [31:0] imem_instr,

    // Data memory interface
    output [31:0] dmem_addr,
    output [31:0] dmem_wr_data,
    output [3:0]  dmem_byte_enable,
    output dmem_we,
    output dmem_re,
    input  [31:0] dmem_rd_data
);

    // ===== FETCH =====
    wire [31:0] pc;
    wire [31:0] pc_next;
    wire        pc_redirect;
    wire [31:0] pc_target;

    fetch_unit fetch_stage (
        .clk(clk),
        .rst(~rst_n),
        .branch_taken(pc_redirect),
        .branch_target(pc_target),
        .pc(pc),
        .pc_next(pc_next)
    );

    assign imem_addr = pc;

    wire [31:0] pc_plus4 = pc + 32'd4;

    // ===== DECODE =====
    wire [6:0] opcode;
    wire [4:0] rd;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    decoder decoder_stage (
        .instr(imem_instr),
        .opcode(opcode),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .funct3(funct3),
        .funct7(funct7),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_b(imm_b),
        .imm_u(imm_u),
        .imm_j(imm_j)
    );

    // ===== CONTROL UNIT =====
    wire [3:0] alu_op;
    wire [1:0] alu_a_src;
    wire alu_b_src;
    wire mem_we;
    wire mem_re;
    wire [2:0] mem_width;
    wire mem_sign_ext;
    wire branch_en;
    wire jump_en;
    wire jalr_en;
    wire reg_we;
    wire reg_wa_src;
    wire m_ext_en;
    wire [2:0] m_op;
    wire tt_en;
    wire [2:0] tt_op;

    control_unit ctrl_stage (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .alu_op(alu_op),
        .alu_a_src(alu_a_src),
        .alu_b_src(alu_b_src),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .mem_width(mem_width),
        .mem_sign_ext(mem_sign_ext),
        .branch_en(branch_en),
        .jump_en(jump_en),
        .jalr_en(jalr_en),
        .reg_we(reg_we),
        .reg_wa_src(reg_wa_src),
        .m_ext_en(m_ext_en),
        .m_op(m_op),
        .tt_en(tt_en),
        .tt_op(tt_op)
    );

    // ===== REGISTER FILE =====
    wire [31:0]  rs1_data;
    wire [31:0]  rs2_data;
    wire [31:0]  wb_data;
    wire [991:0] regs_flat;
    wire         tt_restore_en;
    wire [991:0] tt_restore_data;

    tt_regfile rf (
        .clk(clk),
        .rst_n(rst_n),
        .we(reg_we),
        .ra1(rs1),
        .ra2(rs2),
        .wa(rd),
        .wd(wb_data),
        .rd1(rs1_data),
        .rd2(rs2_data),
        .regs_flat(regs_flat),
        .restore_en(tt_restore_en),
        .restore_data(tt_restore_data)
    );

    // ===== ALU =====
    // Immediate for the ALU's B input; branches and JAL use their own adders
    wire [31:0] imm_selected;

    assign imm_selected = (opcode == 7'b0110111) ? imm_u :     // LUI
                          (opcode == 7'b0010111) ? imm_u :     // AUIPC
                          (opcode == 7'b0100011) ? imm_s :     // SB, SH, SW
                          imm_i;                               // OP-IMM, LOAD, JALR

    // A input: rs1, PC (AUIPC) or zero (LUI)
    wire [31:0] alu_a = (alu_a_src == 2'b00) ? rs1_data :
                        (alu_a_src == 2'b01) ? pc :
                        32'h0;
    wire [31:0] alu_b = alu_b_src ? imm_selected : rs2_data;

    wire [31:0] alu_result;

    alu alu_stage (
        .a(alu_a),
        .b(alu_b),
        .alu_op(alu_op),
        .y(alu_result)
    );

    // ===== MUL/DIV (combinational) =====
    // Always computes from rs1/rs2; the result is only used when m_ext_en=1
    wire [31:0] muldiv_result;

    muldiv_comb mdu (
        .op(m_op),
        .a(rs1_data),
        .b(rs2_data),
        .result(muldiv_result)
    );

    // ===== TIME-TRAVEL UNIT =====
    wire [31:0]      tt_snap_id;
    wire [TT_SW:0]   tt_count;
    wire [TT_SW-1:0] tt_pos;
    wire             tt_at_cp;
    wire             tt_overflow;

    tt_unit #(.SLOTS(TT_SLOTS), .SW(TT_SW)) ttu (
        .clk(clk),
        .rst_n(rst_n),
        .tt_en(tt_en),
        .tt_op(tt_op),
        .rs1_data(rs1_data),
        .regs_flat(regs_flat),
        .restore_en(tt_restore_en),
        .restore_data(tt_restore_data),
        .snap_id(tt_snap_id),
        .count(tt_count),
        .pos(tt_pos),
        .at_cp(tt_at_cp),
        .overflow(tt_overflow)
    );

    // ===== LOAD/STORE UNIT =====
    wire [3:0]  byte_enable;
    wire [31:0] store_data;
    wire [31:0] load_data;

    lsu lsu_stage (
        .addr(alu_result),
        .write_data(rs2_data),
        .mem_re(mem_re),
        .mem_width(mem_width),
        .mem_sign_ext(mem_sign_ext),
        .mem_data(dmem_rd_data),
        .byte_enable(byte_enable),
        .store_data(store_data),
        .load_data(load_data)
    );

    assign dmem_addr        = alu_result;
    assign dmem_wr_data     = store_data;
    assign dmem_byte_enable = mem_we ? byte_enable : 4'h0;   // no byte lanes unless storing
    assign dmem_we          = mem_we;
    assign dmem_re          = mem_re;

    // ===== BRANCH / JUMP (next PC) =====
    // Branch condition compares rs1/rs2 directly; the target has its own adder,
    // so the ALU is free to be used by other instructions.
    reg branch_cond;
    always @(*) begin
        case (funct3)
            3'b000:  branch_cond = (rs1_data == rs2_data);                   // BEQ
            3'b001:  branch_cond = (rs1_data != rs2_data);                   // BNE
            3'b100:  branch_cond = ($signed(rs1_data) <  $signed(rs2_data)); // BLT
            3'b101:  branch_cond = ($signed(rs1_data) >= $signed(rs2_data)); // BGE
            3'b110:  branch_cond = (rs1_data <  rs2_data);                   // BLTU
            3'b111:  branch_cond = (rs1_data >= rs2_data);                   // BGEU
            default: branch_cond = 1'b0;
        endcase
    end

    wire [31:0] branch_target = pc + imm_b;
    wire [31:0] jal_target    = pc + imm_j;
    wire [31:0] jalr_target   = {alu_result[31:1], 1'b0};             // (rs1 + imm) & ~1

    assign pc_redirect = jalr_en | jump_en | (branch_en & branch_cond);
    assign pc_target   = jalr_en ? jalr_target :
                         jump_en ? jal_target  :
                         branch_target;

    // ===== WRITE-BACK MUX =====
    // Only one of these sources is active for any instruction
    assign wb_data = mem_re     ? load_data     :
                     m_ext_en   ? muldiv_result :
                     reg_wa_src ? pc_plus4      :   // JAL / JALR link
                     tt_en      ? tt_snap_id    :   // SNAPSHOT rd
                     alu_result;

endmodule
