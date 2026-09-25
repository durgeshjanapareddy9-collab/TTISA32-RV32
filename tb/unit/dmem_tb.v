`timescale 1ns/1ps

module dmem_tb;
    
    // Clock and reset
    reg clk;
    reg rst;
    
    // Primary port
    reg [31:0] addr;
    reg [31:0] wr_data;
    reg [3:0] byte_enable;
    reg mem_we, mem_re;
    wire [31:0] rd_data;
    
    // Debug port
    reg [31:0] debug_addr;
    wire [31:0] debug_data;
    
    // Instantiate dmem
    dmem #(.DEPTH(256)) dut (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .wr_data(wr_data),
        .byte_enable(byte_enable),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .rd_data(rd_data),
        .debug_addr(debug_addr),
        .debug_data(debug_data)
    );
    
    // Clock generation
    always begin
        clk = 1'b0;
        #5;
        clk = 1'b1;
        #5;
    end
    
    // Test counter
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

    task do_write(input [31:0] waddr, input [31:0] wdata, input [3:0] be);
        begin
            @(negedge clk);
            addr = waddr;
            wr_data = wdata;
            byte_enable = be;
            mem_we = 1'b1;
            mem_re = 1'b0;
            @(posedge clk);
            @(negedge clk);
            mem_we = 1'b0;
        end
    endtask

    task do_read(input [31:0] raddr);
        begin
            @(negedge clk);
            addr = raddr;
            mem_re = 1'b1;
            mem_we = 1'b0;
            @(posedge clk);
            @(negedge clk);
            mem_re = 1'b0;
        end
    endtask
    
    initial begin
        $display("\n╔════════════════════════════════════════════════════════════════╗");
        $display("║            DATA MEMORY (DMEM) TESTBENCH                        ║");
        $display("║         Testing Dual-Port RAM with Byte Enables               ║");
        $display("╚════════════════════════════════════════════════════════════════╝\n");
        
        // Initialize
        rst = 1'b1;
        mem_we = 1'b0;
        mem_re = 1'b0;
        addr = 32'h0;
        wr_data = 32'h0;
        byte_enable = 4'b0000;
        debug_addr = 32'h0;

        repeat (2) @(posedge clk);
        rst = 1'b0;
        
        // ===== TEST 1: Write full word (all 4 bytes) =====
        $display("\n[TEST 1] Write full word to address 0x0");
        do_write(32'h00000000, 32'h12345678, 4'b1111);
        debug_addr = 32'h00000000;
        #1;
        assert_equal(debug_data, 32'h12345678, "Full word write (addr 0x0)");
        
        // ===== TEST 2: Read full word =====
        $display("\n[TEST 2] Read full word from address 0x0");
        do_read(32'h00000000);
        assert_equal(rd_data, 32'h12345678, "Full word read (addr 0x0)");
        
        // ===== TEST 3: Write only byte 0 (LSB) =====
        $display("\n[TEST 3] Write only byte 0 (LSB) to preserve other bytes");
        do_write(32'h00000000, 32'hAAAABBBB, 4'b0001);
        debug_addr = 32'h00000000;
        #1;
        assert_equal(debug_data, 32'h123456BB, "Byte 0 write (byte_enable[0])");
        
        // ===== TEST 4: Write only byte 1 =====
        $display("\n[TEST 4] Write only byte 1");
        do_write(32'h00000000, 32'hAAAA5678, 4'b0010);
        debug_addr = 32'h00000000;
        #1;
        assert_equal(debug_data, 32'h123456BB, "Byte 1 write (byte_enable[1])");
        
        // ===== TEST 5: Write only byte 2 =====
        $display("\n[TEST 5] Write only byte 2");
        do_write(32'h00000000, 32'hABCD0000, 4'b0100);
        debug_addr = 32'h00000000;
        #1;
        assert_equal(debug_data, 32'h12CD56BB, "Byte 2 write (byte_enable[2])");
        
        // ===== TEST 6: Write only byte 3 (MSB) =====
        $display("\n[TEST 6] Write only byte 3 (MSB)");
        do_write(32'h00000000, 32'hFF000000, 4'b1000);
        debug_addr = 32'h00000000;
        #1;
        assert_equal(debug_data, 32'hFFCD56BB, "Byte 3 write (byte_enable[3])");
        
        // ===== TEST 7: Write multiple bytes (0,1,3) =====
        $display("\n[TEST 7] Write bytes 0, 1, 3 (skip byte 2)");
        do_write(32'h00000000, 32'hAABBCC00, 4'b1011);
        debug_addr = 32'h00000000;
        #1;
        assert_equal(debug_data, 32'hAACDCC00, "Multi-byte write (0,1,3)");
        
        // ===== TEST 8: Write to different address =====
        $display("\n[TEST 8] Write to address 0x4 (word 1)");
        do_write(32'h00000004, 32'hDEADBEEF, 4'b1111);
        debug_addr = 32'h00000004;
        #1;
        assert_equal(debug_data, 32'hDEADBEEF, "Write to addr 0x4");
        
        // ===== TEST 9: Verify original write still there =====
        $display("\n[TEST 9] Verify address 0x0 unchanged");
        debug_addr = 32'h00000000;
        #1;
        assert_equal(debug_data, 32'hAACDCC00, "Verify addr 0x0 still intact");
        
        // ===== TEST 10: Read from address 0x4 =====
        $display("\n[TEST 10] Read from address 0x4");
        do_read(32'h00000004);
        assert_equal(rd_data, 32'hDEADBEEF, "Read from addr 0x4");
        
        // ===== TEST 11: Write then read same address =====
        $display("\n[TEST 11] Write then read same address");
        do_write(32'h00000008, 32'h11223344, 4'b1111);
        do_read(32'h00000008);
        assert_equal(rd_data, 32'h11223344, "Write then read (addr 0x8)");
        
        // ===== TEST 12: Write with misaligned address (LSB 2 bits ignored) =====
        $display("\n[TEST 12] Write with address LSBs (should be ignored)");
        do_write(32'h00000007, 32'hCAFEBABE, 4'b1111);
        debug_addr = 32'h00000004;
        #1;
        assert_equal(debug_data, 32'hCAFEBABE, "Misaligned write (addr bits [1:0] ignored)");
        
        // ===== TEST 13: Partial write (byte0 = 0xAA, others unchanged) =====
        $display("\n[TEST 13] Partial byte update");
        do_write(32'h0000000C, 32'h11223344, 4'b1111);
        do_write(32'h0000000C, 32'hAAAAAAAA, 4'b0001);
        debug_addr = 32'h0000000C;
        #1;
        assert_equal(debug_data, 32'h112233AA, "Partial byte update");
        
        // ===== TEST 14: Half-word write (2 bytes) =====
        $display("\n[TEST 14] Half-word write (bytes 1:0)");
        do_write(32'h00000010, 32'h0000AABB, 4'b0011);
        debug_addr = 32'h00000010;
        #1;
        assert_equal(debug_data, 32'h0000AABB, "Half-word write (bytes 1:0)");
        
        // ===== TEST 15: Upper half-word write (2 bytes) =====
        $display("\n[TEST 15] Upper half-word write (bytes 3:2)");
        do_write(32'h00000010, 32'hCCDD0000, 4'b1100);
        debug_addr = 32'h00000010;
        #1;
        assert_equal(debug_data, 32'hCCDDAABB, "Upper half-word write (bytes 3:2)");
        
        // ===== TEST 16: No write when mem_we=0 =====
        $display("\n[TEST 16] No write when mem_we=0");
        @(negedge clk);
        addr = 32'h00000010;
        wr_data = 32'hFFFFFFFF;
        byte_enable = 4'b1111;
        mem_we = 1'b0;
        mem_re = 1'b0;
        @(posedge clk);
        debug_addr = 32'h00000010;
        #1;
        assert_equal(debug_data, 32'hCCDDAABB, "Memory unchanged (mem_we=0)");
        
        // ===== TEST 17: Debug port independent read =====
        $display("\n[TEST 17] Debug port independent read");
        debug_addr = 32'h00000008;
        #1;
        assert_equal(debug_data, 32'h11223344, "Debug port read (addr 0x8)");
        
        // ===== TEST 18: Multiple writes to same address =====
        $display("\n[TEST 18] Multiple sequential writes");
        do_write(32'h00000014, 32'h11111111, 4'b1111);
        do_write(32'h00000014, 32'h22222222, 4'b1111);
        
        debug_addr = 32'h00000014;
        #1;
        assert_equal(debug_data, 32'h22222222, "Last write wins");
        
        // ===== TEST 19: Read during no mem_re =====
        $display("\n[TEST 19] Read port stable when mem_re=0");
        do_read(32'h00000014);
        rd_data_stable = rd_data;  // capture value
        @(posedge clk);
        assert_equal(rd_data, rd_data_stable, "Read data stable");
        
        // ===== TEST 20: Zero write =====
        $display("\n[TEST 20] Write all zeros");
        do_write(32'h00000018, 32'h00000000, 4'b1111);
        debug_addr = 32'h00000018;
        #1;
        assert_equal(debug_data, 32'h00000000, "Write zeros");
        
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
    
    reg [31:0] rd_data_stable;
    
endmodule
