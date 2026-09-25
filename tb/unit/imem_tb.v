`timescale 1ns/1ps

module imem_tb;

    reg  clk;
    reg  [31:0] addr;
    wire [31:0] instr;
    reg  [31:0] addr_sync;
    wire [31:0] instr_sync;

    localparam NOP = 32'h00000013;

    // Instantiate instruction memory
    imem #(.DEPTH(8)) dut (
        .clk(clk),
        .addr(addr),
        .instr(instr)
    );
    
    // Synchronous variant (BRAM-friendly)
    imem #(.DEPTH(8), .SYNC_READ(1)) dut_sync (
        .clk(clk),
        .addr(addr_sync),
        .instr(instr_sync)
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

    task sync_read_check(input [31:0] raddr, input [31:0] expected, input string msg);
        begin
            @(negedge clk);
            addr_sync = raddr;
            @(posedge clk);
            #1;
            assert_equal(instr_sync, expected, msg);
        end
    endtask

    // Clock generation
    always begin
        clk = 1'b0;
        #5;
        clk = 1'b1;
        #5;
    end

    initial begin
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║            INSTRUCTION MEMORY (IMEM) TESTBENCH                 ║");
        $display("║         Testing Async + Sync ROM Read                          ║");
        $display("╚════════════════════════════════════════════════════════════════╝\n");

        // Default to NOPs
        addr = 32'h00000000;
        addr_sync = 32'h00000000;
        #1;
        assert_equal(instr, NOP, "Default memory initialized to NOP");

        // Inject a few instructions for test
        dut.mem[0] = 32'hDEADBEEF;
        dut.mem[1] = 32'hCAFEBABE;
        dut.mem[3] = 32'h12345678;
        dut_sync.mem[0] = 32'hDEADBEEF;
        dut_sync.mem[1] = 32'hCAFEBABE;
        dut_sync.mem[3] = 32'h12345678;
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

        // ===== SYNC READ TESTS =====
        $display("\n[SYNC] Testing registered read latency");
        sync_read_check(32'h00000000, 32'hDEADBEEF, "Sync read word 0");
        sync_read_check(32'h00000004, 32'hCAFEBABE, "Sync read word 1");
        sync_read_check(32'h00000008, NOP,         "Sync read default NOP (word 2)");
        sync_read_check(32'h0000000C, 32'h12345678, "Sync read word 3");

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
