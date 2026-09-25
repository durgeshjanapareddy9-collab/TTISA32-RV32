`timescale 1ns/1ps

module fetch_tb;
    
    reg clk;
    reg rst;
    reg branch_taken;
    reg [31:0] branch_target;
    wire [31:0] pc;
    wire [31:0] pc_next;
    
    // Instantiate fetch unit
    fetch_unit dut (
        .clk(clk),
        .rst(rst),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .pc(pc),
        .pc_next(pc_next)
    );
    
    // Clock generation
    always begin
        clk = 1'b0;
        #5;
        clk = 1'b1;
        #5;
    end
    
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
        $display("║               FETCH UNIT (PC SEQUENCER) TESTBENCH               ║");
        $display("║         Testing PC Increment and Branch Redirection            ║");
        $display("╚════════════════════════════════════════════════════════════════╝\n");
        
        // Initialize
        rst = 1'b1;
        branch_taken = 1'b0;
        branch_target = 32'h0;
        
        #15;
        rst = 1'b0;
        
        // ===== TEST 1: PC starts at 0 =====
        $display("\n[TEST 1] PC initialization");
        assert_equal(pc, 32'h00000000, "PC reset to 0");
        
        // ===== TEST 2: PC increments by 4 each cycle =====
        $display("\n[TEST 2] Sequential PC increment (+4 per cycle)");
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000004, "PC = 0x4 after 1 cycle");
        
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000008, "PC = 0x8 after 2 cycles");
        
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h0000000C, "PC = 0xC after 3 cycles");
        
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000010, "PC = 0x10 after 4 cycles");
        
        // ===== TEST 3: pc_next is one step ahead =====
        $display("\n[TEST 3] pc_next shows next instruction address");
        assert_equal(pc_next, 32'h00000014, "pc_next = 0x14 (current 0x10 + 4)");
        
        // ===== TEST 4: Branch taken redirects PC =====
        $display("\n[TEST 4] Branch taken to target address");
        branch_taken = 1'b1;
        branch_target = 32'h00000100;  // Jump to 0x100
        #1;
        assert_equal(pc_next, 32'h00000100, "pc_next = branch_target (0x100)");
        
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000100, "PC now at branch target (0x100)");
        
        // ===== TEST 5: Continue sequential after branch =====
        $display("\n[TEST 5] Resume sequential execution after branch");
        branch_taken = 1'b0;  // No more branches
        #1;
        assert_equal(pc_next, 32'h00000104, "pc_next = 0x104 (0x100 + 4)");
        
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000104, "PC incremented to 0x104");
        
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000108, "PC incremented to 0x108");
        
        // ===== TEST 6: Jump to different address =====
        $display("\n[TEST 6] Jump to different target");
        branch_taken = 1'b1;
        branch_target = 32'h00000050;  // Jump to 0x50
        #1;
        assert_equal(pc_next, 32'h00000050, "pc_next = 0x50");
        
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000050, "PC jumped to 0x50");
        
        // ===== TEST 7: Large address jump (simulating far jump) =====
        $display("\n[TEST 7] Large address jump");
        branch_target = 32'h80000000;  // Jump to high memory
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h80000000, "PC jumped to 0x80000000");
        
        // ===== TEST 8: Jump back to low address =====
        $display("\n[TEST 8] Jump back to low address (loop)");
        branch_taken = 1'b1;
        branch_target = 32'h00000010;  // Loop back
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000010, "PC looped back to 0x10");
        
        // ===== TEST 9: Reset clears PC =====
        $display("\n[TEST 9] Reset clears PC");
        branch_taken = 1'b0;
        @(posedge clk);
        rst = 1'b1;
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000000, "Reset returns PC to 0x0");
        
        // ===== TEST 10: Verify 32-bit overflow behavior (wraps) =====
        $display("\n[TEST 10] Address arithmetic (32-bit behavior)");
        rst = 1'b0;
        branch_taken = 1'b1;
        branch_target = 32'hFFFFFFFC;  // Near end of 32-bit space
        @(posedge clk);
        #1;
        assert_equal(pc, 32'hFFFFFFFC, "PC = 0xFFFFFFFC");
        
        // Sequential increment from high address
        branch_taken = 1'b0;
        @(posedge clk);
        #1;
        assert_equal(pc, 32'h00000000, "PC wraps around at 32-bit boundary (0xFFFFFFFC + 4 = 0x0)");
        
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
