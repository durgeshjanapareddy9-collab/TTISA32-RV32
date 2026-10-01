`timescale 1ns/1ps

module imem_tb;

    reg  [31:0] addr;
    wire [31:0] instr;

    localparam NOP = 32'h00000013;

    // Instantiate instruction memory
    imem #(.DEPTH(8)) dut (
        .addr(addr),
        .instr(instr)
    );

    integer test_num = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    task assert_equal(input [31:0] actual, input [31:0] expected, input string msg);
        test_num = test_num + 1;
        if (actual == expected) begin
            $display("[PASS] Test %0d: %s | Expected: 0x%08x, Got: 0x%08x",
                     test_num, msg, expected, actual);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: %s | Expected: 0x%08x, Got: 0x%08x",
                     test_num, msg, expected, actual);
            fail_count = fail_count + 1;
        end
    endtask

    initial begin
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║            INSTRUCTION MEMORY (IMEM) TESTBENCH                 ║");
        $display("║         Testing combinational ROM read                         ║");
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        // Default to NOPs
        addr = 32'h00000000;
        #1;
        assert_equal(instr, NOP, "Default memory initialized to NOP");

        // Inject a few instructions for test
        dut.mem[0] = 32'hDEADBEEF;
        dut.mem[1] = 32'hCAFEBABE;
        dut.mem[3] = 32'h12345678;
        #1;

        // Read word 0
        addr = 32'h00000000;
        #1;
        assert_equal(instr, 32'hDEADBEEF, "Read word 0");

        // Read word 1 (aligned address)
        addr = 32'h00000004;
        #1;
        assert_equal(instr, 32'hCAFEBABE, "Read word 1 aligned");

        // Read word 1 (misaligned address uses same word index)
        addr = 32'h00000005;
        #1;
        assert_equal(instr, 32'hCAFEBABE, "Read word 1 misaligned");

        // Read word 2 (still NOP)
        addr = 32'h00000008;
        #1;
        assert_equal(instr, NOP, "Read default NOP at word 2");

        // Read word 3
        addr = 32'h0000000C;
        #1;
        assert_equal(instr, 32'h12345678, "Read word 3");

        // ===== SUMMARY =====
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║                      TEST SUMMARY                              ║");
        $display("╠════════════════════════════════════════════════════════════════╣");
        $display("║  Total Tests:  %0d", test_num);
        $display("║  Passed:       %0d", pass_count);
        $display("║  Failed:       %0d", fail_count);
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        if (fail_count == 0) begin
            $display("✓ ALL TESTS PASSED!\n");
        end else begin
            $display("✗ SOME TESTS FAILED!\n");
        end

        $finish;
    end

endmodule
