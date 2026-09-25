// Immediate generator for RISC-V (I, S, B, U, J forms)
module imm_gen(
    input  wire [31:0] instr,
    output wire [31:0] imm_i,
    output wire [31:0] imm_s,
    output wire [31:0] imm_b,
    output wire [31:0] imm_u,
    output wire [31:0] imm_j
);
    // I-type: imm[11:0] = instr[31:20]
    assign imm_i = {{20{instr[31]}}, instr[31:20]};

    // S-type: imm[11:5]=instr[31:25], imm[4:0]=instr[11:7]
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // B-type: imm[12]=instr[31], imm[11]=instr[7], imm[10:5]=instr[30:25], imm[4:1]=instr[11:8], imm[0]=0
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

    // U-type: imm[31:12]=instr[31:12], imm[11:0]=0
    assign imm_u = {instr[31:12], 12'b0};

    // J-type: imm[20]=instr[31], imm[19:12]=instr[19:12], imm[11]=instr[20], imm[10:1]=instr[30:21], imm[0]=0
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

endmodule
