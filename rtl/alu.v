// Combinational ALU for the RV32I integer operations.
// Branch compares are done in the core, so only the result is needed here.
module alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_op,
    output reg  [31:0] y
);

    // ALU opcodes (must match control_unit.v)
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

    // RV32 shifts only use the low 5 bits of the shift amount
    wire [4:0] shamt = b[4:0];

    always @(*) begin
        case (alu_op)
            ALU_ADD:  y = a + b;
            ALU_SUB:  y = a - b;
            ALU_SLL:  y = a << shamt;
            ALU_SRL:  y = a >> shamt;                    // logical: fills with 0
            ALU_SRA:  y = $signed(a) >>> shamt;          // arithmetic: keeps sign
            ALU_AND:  y = a & b;
            ALU_OR:   y = a | b;
            ALU_XOR:  y = a ^ b;
            ALU_SLT:  y = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: y = (a < b) ? 32'd1 : 32'd0;
            default:  y = 32'd0;
        endcase
    end

endmodule
