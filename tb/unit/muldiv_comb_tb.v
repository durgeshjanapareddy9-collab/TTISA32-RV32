`timescale 1ns/1ps

// Unit test for muldiv_comb: directed RISC-V corner cases plus random
// vectors checked against a reference model built on 64-bit arithmetic.
module muldiv_comb_tb;
    reg  [2:0]  op;
    reg  [31:0] a, b;
    wire [31:0] result;

    muldiv_comb dut (.op(op), .a(a), .b(b), .result(result));

    localparam MUL = 3'd0, MULH = 3'd1, MULHSU = 3'd2, MULHU = 3'd3,
               DIV = 3'd4, DIVU = 3'd5, REM    = 3'd6, REMU  = 3'd7;

    integer passed = 0;
    integer failed = 0;
    integer i;

    // Reference model
    function [31:0] ref_model(input [2:0] o, input [31:0] x, input [31:0] y);
        reg signed [63:0] xs, ys;
        reg        [63:0] xu, yu, p;
        integer           xi, yi, qi, ri;
        begin
            xs = {{32{x[31]}}, x};  ys = {{32{y[31]}}, y};
            xu = {32'd0, x};        yu = {32'd0, y};
            xi = x;                 yi = y;
            // Signed / and % in plain signed statements: inside a ?: with
            // unsigned operands they would be evaluated as unsigned.
            qi = (y == 0) ? 0 : xi / yi;
            ri = (y == 0) ? 0 : xi % yi;
            case (o)
                MUL:    begin p = xs * ys; ref_model = p[31:0];  end
                MULH:   begin p = xs * ys; ref_model = p[63:32]; end
                MULHSU: begin p = xs * $signed(yu); ref_model = p[63:32]; end
                MULHU:  begin p = xu * yu; ref_model = p[63:32]; end
                DIV:    ref_model = (y == 0) ? 32'hFFFFFFFF :
                                    (x == 32'h80000000 && y == 32'hFFFFFFFF) ? 32'h80000000 :
                                    qi;
                DIVU:   ref_model = (y == 0) ? 32'hFFFFFFFF : x / y;
                REM:    ref_model = (y == 0) ? x :
                                    (x == 32'h80000000 && y == 32'hFFFFFFFF) ? 32'd0 :
                                    ri;
                REMU:   ref_model = (y == 0) ? x : x % y;
            endcase
        end
    endfunction

    task run(input [2:0] o, input [31:0] x, input [31:0] y, input [31:0] expected);
        begin
            op = o; a = x; b = y; #1;
            if (result === expected) passed = passed + 1;
            else begin
                failed = failed + 1;
                $display("FAIL: op=%0d a=%08h b=%08h -> %08h, expected %08h", o, x, y, result, expected);
            end
        end
    endtask

    initial begin
        // ---- Directed corner cases (expected values from the RISC-V spec) ----
        run(MUL,    32'd7,        -32'sd3,      -32'sd21);
        run(MULH,   32'h80000000, 32'h80000000, 32'h40000000);
        run(MULHU,  32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFE);
        run(MULHSU, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF);
        run(MULHSU, 32'd7,        32'hFFFFFFFF, 32'd6);
        run(DIV,    32'd7,        -32'sd3,      -32'sd2);
        run(DIV,    -32'sd7,      32'd3,        -32'sd2);
        run(REM,    32'd7,        -32'sd3,      32'd1);
        run(REM,    -32'sd7,      32'd3,        -32'sd1);
        run(DIVU,   32'hFFFFFFFF, 32'd2,        32'h7FFFFFFF);
        run(REMU,   32'hFFFFFFFF, 32'd2,        32'd1);
        run(DIV,    32'd7,        32'd0,        32'hFFFFFFFF);   // divide by zero
        run(DIVU,   32'd7,        32'd0,        32'hFFFFFFFF);
        run(REM,    -32'sd3,      32'd0,        -32'sd3);
        run(REMU,   32'd7,        32'd0,        32'd7);
        run(DIV,    32'h80000000, 32'hFFFFFFFF, 32'h80000000);   // signed overflow
        run(REM,    32'h80000000, 32'hFFFFFFFF, 32'd0);

        // ---- Random vectors, including small divisors and sign-bit patterns ----
        for (i = 0; i < 4000; i = i + 1) begin
            op = $random;
            a  = (i % 7 == 0) ? {$random} % 16 : $random;
            b  = (i % 5 == 0) ? {$random} % 16 : $random;
            if (i % 11 == 0) b = -b;
            run(op, a, b, ref_model(op, a, b));
        end

        $display("muldiv_comb_tb: %0d passed, %0d failed", passed, failed);
        if (failed == 0) $display("ALL TESTS PASSED");
        $finish;
    end
endmodule
