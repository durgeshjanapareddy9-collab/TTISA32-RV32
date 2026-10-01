// Combinational RV32M multiply/divide unit for the single-cycle core.
// The result is ready in the same cycle, so M instructions need no stall.
//
// Supported ops (funct3 encoding):
//   000 MUL, 001 MULH, 010 MULHSU, 011 MULHU
//   100 DIV, 101 DIVU, 110 REM,   111 REMU
//
// Corner cases follow the RISC-V spec:
//   divide by zero : DIV/DIVU = all ones, REM/REMU = dividend
//   overflow       : DIV(-2^31, -1) = -2^31, REM(-2^31, -1) = 0
module muldiv_comb(
    input  wire [2:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] result
);
    localparam OP_MUL    = 3'b000;
    localparam OP_MULH   = 3'b001;
    localparam OP_MULHSU = 3'b010;
    localparam OP_MULHU  = 3'b011;
    localparam OP_DIV    = 3'b100;
    localparam OP_DIVU   = 3'b101;
    localparam OP_REM    = 3'b110;
    localparam OP_REMU   = 3'b111;

    // 33-bit operands so one signed multiply covers all three MULH variants
    wire signed [32:0] a_s = {a[31], a};
    wire signed [32:0] a_u = {1'b0,  a};
    wire signed [32:0] b_s = {b[31], b};
    wire signed [32:0] b_u = {1'b0,  b};

    wire signed [65:0] prod_ss = a_s * b_s;
    wire signed [65:0] prod_su = a_s * b_u;
    wire signed [65:0] prod_uu = a_u * b_u;

    wire signed [31:0] a_sgn = a;
    wire signed [31:0] b_sgn = b;

    wire div_by_zero = (b == 32'd0);
    wire div_ovf     = (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);

    // Verilog signed / and % truncate toward zero, matching RISC-V.
    // Kept in their own signed wires: mixing them into a ?: with an unsigned
    // operand would turn the whole expression (and the division) unsigned.
    // Divide-by-zero results are selected below, so X from /0 never escapes.
    wire signed [31:0] quot_s = a_sgn / b_sgn;
    wire signed [31:0] rem_s  = a_sgn % b_sgn;
    wire        [31:0] quot_u = a / b;
    wire        [31:0] rem_u  = a % b;

    always @(*) begin
        case (op)
            OP_MUL:    result = prod_ss[31:0];
            OP_MULH:   result = prod_ss[63:32];
            OP_MULHSU: result = prod_su[63:32];
            OP_MULHU:  result = prod_uu[63:32];
            OP_DIV:    result = div_by_zero ? 32'hFFFF_FFFF :
                                div_ovf     ? 32'h8000_0000 : quot_s;
            OP_DIVU:   result = div_by_zero ? 32'hFFFF_FFFF : quot_u;
            OP_REM:    result = div_by_zero ? a :
                                div_ovf     ? 32'd0 : rem_s;
            OP_REMU:   result = div_by_zero ? a : rem_u;
            default:   result = 32'd0;
        endcase
    end

endmodule
