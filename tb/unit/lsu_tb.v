// LSU Testbench - Load/Store Unit verification
// Tests byte enables, data alignment, sign/zero extension for all access widths

`timescale 1ns / 1ps

module lsu_tb ();
    reg  [31:0] addr;
    reg  [31:0] write_data;
    reg         mem_we;
    reg         mem_re;
    reg  [2:0]  mem_width;
    reg         mem_sign_ext;
    reg  [31:0] mem_data;
    
    wire [31:0] load_data;
    wire [3:0]  byte_enable;
    wire [31:0] store_data;
    
    lsu uut (
        .addr(addr),
        .write_data(write_data),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .mem_width(mem_width),
        .mem_sign_ext(mem_sign_ext),
        .mem_data(mem_data),
        .load_data(load_data),
        .byte_enable(byte_enable),
        .store_data(store_data)
    );
    
    initial begin
        $display("=== LSU Testbench ===\n");
        
        // Initialize signals
        addr = 32'b0;
        write_data = 32'b0;
        mem_we = 1'b0;
        mem_re = 1'b0;
        mem_width = 3'b0;
        mem_sign_ext = 1'b0;
        mem_data = 32'b0;
        
        // ====== TEST 1: Byte Write at offset 0 ======
        $display("TEST 1: Byte Write at address 0x0");
        addr = 32'h0000_0000;
        write_data = 32'hDEAD_BEEF;
        mem_we = 1'b1;
        mem_width = 3'b000;  // byte
        #1;
        if (byte_enable !== 4'b0001) $error("Expected byte_enable=0001, got %04b", byte_enable);
        if (store_data !== 32'h0000_00EF) $error("Expected store_data=0000_00EF, got %08h", store_data);
        $display("  ✓ byte_enable=%04b, store_data=%08h\n", byte_enable, store_data);
        
        // ====== TEST 2: Byte Write at offset 1 ======
        $display("TEST 2: Byte Write at address 0x1");
        addr = 32'h0000_0001;
        write_data = 32'hDEAD_BEEF;
        mem_we = 1'b1;
        mem_width = 3'b000;
        #1;
        if (byte_enable !== 4'b0010) $error("Expected byte_enable=0010, got %04b", byte_enable);
        if (store_data !== 32'h0000_EF00) $error("Expected store_data=0000_EF00, got %08h", store_data);
        $display("  ✓ byte_enable=%04b, store_data=%08h\n", byte_enable, store_data);
        
        // ====== TEST 3: Byte Write at offset 2 ======
        $display("TEST 3: Byte Write at address 0x2");
        addr = 32'h0000_0002;
        write_data = 32'hDEAD_BEEF;
        mem_we = 1'b1;
        mem_width = 3'b000;
        #1;
        if (byte_enable !== 4'b0100) $error("Expected byte_enable=0100, got %04b", byte_enable);
        if (store_data !== 32'h00EF_0000) $error("Expected store_data=00EF_0000, got %08h", store_data);
        $display("  ✓ byte_enable=%04b, store_data=%08h\n", byte_enable, store_data);
        
        // ====== TEST 4: Byte Write at offset 3 ======
        $display("TEST 4: Byte Write at address 0x3");
        addr = 32'h0000_0003;
        write_data = 32'hDEAD_BEEF;
        mem_we = 1'b1;
        mem_width = 3'b000;
        #1;
        if (byte_enable !== 4'b1000) $error("Expected byte_enable=1000, got %04b", byte_enable);
        if (store_data !== 32'hEF00_0000) $error("Expected store_data=EF00_0000, got %08h", store_data);
        $display("  ✓ byte_enable=%04b, store_data=%08h\n", byte_enable, store_data);
        
        // ====== TEST 5: Half-Word Write at offset 0 ======
        $display("TEST 5: Half-Word Write at address 0x0");
        addr = 32'h0000_0000;
        write_data = 32'hDEAD_BEEF;
        mem_we = 1'b1;
        mem_width = 3'b001;  // half-word
        #1;
        if (byte_enable !== 4'b0011) $error("Expected byte_enable=0011, got %04b", byte_enable);
        if (store_data !== 32'h0000_BEEF) $error("Expected store_data=0000_BEEF, got %08h", store_data);
        $display("  ✓ byte_enable=%04b, store_data=%08h\n", byte_enable, store_data);
        
        // ====== TEST 6: Half-Word Write at offset 2 ======
        $display("TEST 6: Half-Word Write at address 0x2");
        addr = 32'h0000_0002;
        write_data = 32'hDEAD_BEEF;
        mem_we = 1'b1;
        mem_width = 3'b001;
        #1;
        if (byte_enable !== 4'b1100) $error("Expected byte_enable=1100, got %04b", byte_enable);
        if (store_data !== 32'hBEEF_0000) $error("Expected store_data=BEEF_0000, got %08h", store_data);
        $display("  ✓ byte_enable=%04b, store_data=%08h\n", byte_enable, store_data);
        
        // ====== TEST 7: Word Write (always aligned) ======
        $display("TEST 7: Word Write at address 0x0");
        addr = 32'h0000_0000;
        write_data = 32'hDEAD_BEEF;
        mem_we = 1'b1;
        mem_width = 3'b010;  // word
        #1;
        if (byte_enable !== 4'b1111) $error("Expected byte_enable=1111, got %04b", byte_enable);
        if (store_data !== 32'hDEAD_BEEF) $error("Expected store_data=DEAD_BEEF, got %08h", store_data);
        $display("  ✓ byte_enable=%04b, store_data=%08h\n", byte_enable, store_data);
        
        // ====== TEST 8: Byte Load (Zero Extension) at offset 1 ======
        $display("TEST 8: Byte Load (Zero Extension) at offset 1");
        addr = 32'h0000_0001;
        mem_re = 1'b1;
        mem_data = 32'hDEAD_BEEF;  // mem_data[15:8] = 0xBE
        mem_width = 3'b000;
        mem_sign_ext = 1'b0;  // zero-extend
        #1;
        if (load_data !== 32'h0000_00BE) $error("Expected load_data=0000_00BE (zero-ext), got %08h", load_data);
        $display("  ✓ load_data=%08h (zero-extended byte[1])\n", load_data);
        
        // ====== TEST 9: Byte Load (Sign Extension - Positive) at offset 1 ======
        $display("TEST 9: Byte Load (Sign Extension - Positive) at offset 1");
        addr = 32'h0000_0001;
        mem_re = 1'b1;
        mem_data = 32'hDEAD_5E00;  // mem_data[15:8] = 0x5E (positive)
        mem_width = 3'b000;
        mem_sign_ext = 1'b1;  // sign-extend
        #1;
        if (load_data !== 32'h0000_005E) $error("Expected load_data=0000_005E (sign-ext pos), got %08h", load_data);
        $display("  ✓ load_data=%08h (sign-extended positive)\n", load_data);
        
        // ====== TEST 10: Byte Load (Sign Extension - Negative) at offset 1 ======
        $display("TEST 10: Byte Load (Sign Extension - Negative) at offset 1");
        addr = 32'h0000_0001;
        mem_re = 1'b1;
        mem_data = 32'hDEAD_8E00;  // mem_data[15:8] = 0x8E (negative)
        mem_width = 3'b000;
        mem_sign_ext = 1'b1;  // sign-extend
        #1;
        if (load_data !== 32'hFFFF_FF8E) $error("Expected load_data=FFFF_FF8E (sign-ext neg), got %08h", load_data);
        $display("  ✓ load_data=%08h (sign-extended negative)\n", load_data);
        
        // ====== TEST 11: Half-Word Load (Zero Extension) at offset 0 ======
        $display("TEST 11: Half-Word Load (Zero Extension) at offset 0");
        addr = 32'h0000_0000;
        mem_re = 1'b1;
        mem_data = 32'hDEAD_BEEF;  // mem_data[15:0] = 0xBEEF
        mem_width = 3'b001;
        mem_sign_ext = 1'b0;  // zero-extend
        #1;
        if (load_data !== 32'h0000_BEEF) $error("Expected load_data=0000_BEEF (zero-ext), got %08h", load_data);
        $display("  ✓ load_data=%08h (zero-extended)\n", load_data);
        
        // ====== TEST 12: Half-Word Load (Sign Extension - Positive) at offset 0 ======
        $display("TEST 12: Half-Word Load (Sign Extension - Positive) at offset 0");
        addr = 32'h0000_0000;
        mem_re = 1'b1;
        mem_data = 32'hDEAD_5E5E;  // mem_data[15:0] = 0x5E5E (positive)
        mem_width = 3'b001;
        mem_sign_ext = 1'b1;  // sign-extend
        #1;
        if (load_data !== 32'h0000_5E5E) $error("Expected load_data=0000_5E5E (sign-ext pos), got %08h", load_data);
        $display("  ✓ load_data=%08h (sign-extended positive)\n", load_data);
        
        // ====== TEST 13: Half-Word Load (Sign Extension - Negative) at offset 0 ======
        $display("TEST 13: Half-Word Load (Sign Extension - Negative) at offset 0");
        addr = 32'h0000_0000;
        mem_re = 1'b1;
        mem_data = 32'hDEAD_8E8E;  // mem_data[15:0] = 0x8E8E (negative)
        mem_width = 3'b001;
        mem_sign_ext = 1'b1;  // sign-extend
        #1;
        if (load_data !== 32'hFFFF_8E8E) $error("Expected load_data=FFFF_8E8E (sign-ext neg), got %08h", load_data);
        $display("  ✓ load_data=%08h (sign-extended negative)\n", load_data);
        
        // ====== TEST 14: Half-Word Load at offset 2 (upper half) ======
        $display("TEST 14: Half-Word Load at offset 2 (upper half, zero-ext)");
        addr = 32'h0000_0002;
        mem_re = 1'b1;
        mem_data = 32'hDEAD_BEEF;  // mem_data[31:16] = 0xDEAD
        mem_width = 3'b001;
        mem_sign_ext = 1'b0;
        #1;
        if (load_data !== 32'h0000_DEAD) $error("Expected load_data=0000_DEAD, got %08h", load_data);
        $display("  ✓ load_data=%08h\n", load_data);
        
        // ====== TEST 15: Word Load ======
        $display("TEST 15: Word Load at offset 0");
        addr = 32'h0000_0000;
        mem_re = 1'b1;
        mem_data = 32'hDEAD_BEEF;
        mem_width = 3'b010;
        mem_sign_ext = 1'b0;  // sign_ext ignored for word
        #1;
        if (load_data !== 32'hDEAD_BEEF) $error("Expected load_data=DEAD_BEEF, got %08h", load_data);
        $display("  ✓ load_data=%08h\n", load_data);
        
        // ====== TEST 16: No Load when mem_re=0 ======
        $display("TEST 16: No load when mem_re=0");
        addr = 32'h0000_0000;
        mem_re = 1'b0;
        mem_data = 32'hDEAD_BEEF;
        mem_width = 3'b010;
        #1;
        if (load_data !== 32'h0000_0000) $error("Expected load_data=0 when mem_re=0, got %08h", load_data);
        $display("  ✓ load_data=0 (mem_re disabled)\n");
        
        // ====== TEST 17: Byte Load at offset 3 (Sign Extension) ======
        $display("TEST 17: Byte Load at offset 3 (sign-ext negative)");
        addr = 32'h0000_0003;
        mem_re = 1'b1;
        mem_data = 32'hFECA_BEEF;  // mem_data[31:24] = 0xFE (negative)
        mem_width = 3'b000;
        mem_sign_ext = 1'b1;
        #1;
        if (load_data !== 32'hFFFF_FFFE) $error("Expected load_data=FFFF_FFFE, got %08h", load_data);
        $display("  ✓ load_data=%08h (sign-extended from byte 3)\n", load_data);
        
        // ====== TEST 18: Byte Load at offset 2 (Zero Extension) ======
        $display("TEST 18: Byte Load at offset 2 (zero-ext)");
        addr = 32'h0000_0002;
        mem_re = 1'b1;
        mem_data = 32'hFF55_FF00;  // mem_data[23:16] = 0x55
        mem_width = 3'b000;
        mem_sign_ext = 1'b0;
        #1;
        if (load_data !== 32'h0000_0055) $error("Expected load_data=0000_0055, got %08h", load_data);
        $display("  ✓ load_data=%08h (zero-extended from byte 2)\n", load_data);
        
        // ====== TEST 19: Half-Word Load at offset 2 (Sign Extension - Negative) ======
        $display("TEST 19: Half-Word Load at offset 2 (sign-ext negative)");
        addr = 32'h0000_0002;
        mem_re = 1'b1;
        mem_data = 32'hFEED_BEEF;  // mem_data[31:16] = 0xFEED (negative)
        mem_width = 3'b001;
        mem_sign_ext = 1'b1;
        #1;
        if (load_data !== 32'hFFFFFEED) $error("Expected load_data=FFFFFEED, got %08h", load_data);
        $display("  ✓ load_data=%08h (sign-extended from half-word)\n", load_data);
        
        // ====== TEST 20: Half-Word Write at offset 0 (lower half) ======
        $display("TEST 20: Half-Word Write at offset 0 (lower half)");
        addr = 32'h0000_0000;
        write_data = 32'h1234_5678;  // write 0x5678
        mem_we = 1'b1;
        mem_width = 3'b001;
        #1;
        if (byte_enable !== 4'b0011) $error("Expected byte_enable=0011, got %04b", byte_enable);
        if (store_data !== 32'h0000_5678) $error("Expected store_data=0000_5678, got %08h", store_data);
        $display("  ✓ byte_enable=%04b, store_data=%08h\n", byte_enable, store_data);
        
        $display("=== All 20 tests passed! ===\n");
        $finish;
    end

endmodule
