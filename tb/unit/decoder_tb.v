// Unit testbench for decoder: checks field extraction and immediates
`timescale 1ns/1ps
module tb;
    reg  [31:0] instr;
    wire [6:0]  opcode;
    wire [4:0]  rd;
    wire [4:0]  rs1;
    wire [4:0]  rs2;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    decoder dut(
        .instr(instr),
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

    task check32;
        input [127:0] name;
        input [31:0]  got;
        input [31:0]  exp;
        begin
            if (got !== exp)
                $display("FAIL %s got=0x%08x exp=0x%08x", name, got, exp);
            else
                $display("PASS %s", name);
        end
    endtask

    initial begin
        // I-type: addi x1, x0, -1
        instr = 32'b111111111111_00000_000_00001_0010011;
        #1;
        check32("addi opcode", {25'b0, opcode}, 32'h00000013);
        check32("addi rd",     {27'b0, rd},     32'd1);
        check32("addi rs1",    {27'b0, rs1},    32'd0);
        check32("addi funct3", {29'b0, funct3}, 32'd0);
        check32("addi imm_i",  imm_i,           32'hFFFFFFFF);

        // R-type: add x3, x1, x2
        instr = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011};
        #1;
        check32("add opcode", {25'b0, opcode}, 32'h00000033);
        check32("add rd",     {27'b0, rd},     32'd3);
        check32("add rs1",    {27'b0, rs1},    32'd1);
        check32("add rs2",    {27'b0, rs2},    32'd2);
        check32("add funct3", {29'b0, funct3}, 32'd0);
        check32("add funct7", {25'b0, funct7}, 32'd0);

        // S-type: sw x2, 8(x3)
        instr = {7'b0000000, 5'd2, 5'd3, 3'b010, 5'b01000, 7'b0100011};
        #1;
        check32("sw opcode", {25'b0, opcode}, 32'h00000023);
        check32("sw rs1",    {27'b0, rs1},    32'd3);
        check32("sw rs2",    {27'b0, rs2},    32'd2);
        check32("sw funct3", {29'b0, funct3}, 32'd2);
        check32("sw imm_s",  imm_s,           32'd8);

        // B-type: beq x1, x2, +16
        instr = {1'b0, 6'b000000, 5'd2, 5'd1, 3'b000, 4'b1000, 1'b0, 7'b1100011};
        #1;
        check32("beq opcode", {25'b0, opcode}, 32'h00000063);
        check32("beq rs1",    {27'b0, rs1},    32'd1);
        check32("beq rs2",    {27'b0, rs2},    32'd2);
        check32("beq funct3", {29'b0, funct3}, 32'd0);
        check32("beq imm_b",  imm_b,           32'd16);

        // U-type: lui x5, 0x12345
        instr = {20'h12345, 5'd5, 7'b0110111};
        #1;
        check32("lui opcode", {25'b0, opcode}, 32'h00000037);
        check32("lui rd",     {27'b0, rd},     32'd5);
        check32("lui imm_u",  imm_u,           32'h12345000);

        // J-type: jal x1, +8
        instr = {1'b0, 10'b0000000100, 1'b0, 8'b00000000, 5'd1, 7'b1101111};
        #1;
        check32("jal opcode", {25'b0, opcode}, 32'h0000006F);
        check32("jal rd",     {27'b0, rd},     32'd1);
        check32("jal imm_j",  imm_j,           32'd8);

        $display("DECODER TESTS COMPLETE");
        #10 $finish;
    end
endmodule
