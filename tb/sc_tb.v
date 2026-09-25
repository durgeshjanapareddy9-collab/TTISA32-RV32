`timescale 1ns/1ps

// Self-checking testbench for the single-cycle core.
//
// Plusargs:
//   +hex=<file>     program to load (required)
//   +vcd=<file>     dump waveforms
//   +trace          print one line per executed instruction
//   +max=<cycles>   cycle limit (default 10000)
//
// Test programs end with EBREAK. Convention (see sw/test_macros.inc):
//   a0 (x10) == 1  -> PASS
//   otherwise      -> FAIL, gp (x3) holds the number of the failing check
module sc_tb;
    reg clk = 0;
    reg rst_n = 0;

    rv32_sc_top #(.IMEM_DEPTH(1024), .DMEM_DEPTH(1024)) dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    always #5 clk = ~clk;

    localparam EBREAK = 32'h0010_0073;

    reg [1023:0] hexfile;
    reg [1023:0] vcdfile;
    integer      max_cycles;
    integer      cycles;
    reg          trace;

    wire [31:0] pc    = dut.core.pc;
    wire [31:0] instr = dut.core.imem_instr;

    initial begin
        if (!$value$plusargs("hex=%s", hexfile)) begin
            $display("ERROR: pass the program with +hex=<file>");
            $finish;
        end
        if (!$value$plusargs("max=%d", max_cycles))
            max_cycles = 10000;
        trace = $test$plusargs("trace");

        // Load after imem's own initial block has filled memory with NOPs
        #1 $readmemh(hexfile, dut.imem_inst.mem);

        if ($value$plusargs("vcd=%s", vcdfile)) begin
            $dumpfile(vcdfile);
            $dumpvars(0, sc_tb);
        end

        cycles = 0;
        #19 rst_n = 1;
    end

    // One line per retired instruction (sampled just before the clock edge)
    always @(negedge clk) begin
        if (rst_n && trace) begin
            $write("%6d  pc=%08h  instr=%08h", cycles, pc, instr);
            if (dut.core.tt_en)
                $write("  TT op=%0d restore=%0d count=%0d pos=%0d at_cp=%0d",
                       dut.core.tt_op, dut.core.tt_restore_en,
                       dut.core.tt_count, dut.core.tt_pos, dut.core.tt_at_cp);
            if (dut.core.reg_we && dut.core.rd != 0)
                $write("  x%0d <= %08h", dut.core.rd, dut.core.wb_data);
            if (dut.core.dmem_we)
                $write("  mem[%08h] <= %08h (be=%b)", dut.core.dmem_addr,
                       dut.core.dmem_wr_data, dut.core.dmem_byte_enable);
            $write("\n");
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cycles = cycles + 1;
            if (instr === EBREAK) begin
                report();
                $finish;
            end
            if (cycles >= max_cycles) begin
                $display("FAIL: timeout after %0d cycles (pc=%08h)", cycles, pc);
                $finish;
            end
            if (^instr === 1'bx) begin
                $display("FAIL: fetched X instruction at pc=%08h", pc);
                $finish;
            end
        end
    end

    task report;
        begin
            $display("----------------------------------------------");
            $display("program : %0s", hexfile);
            $display("cycles  : %0d (instructions = cycles, CPI = 1)", cycles);
            $display("TT state: count=%0d pos=%0d at_cp=%0d overflow=%0d",
                     dut.core.tt_count, dut.core.tt_pos,
                     dut.core.tt_at_cp, dut.core.tt_overflow);
            if (dut.core.rf.regs[10] === 32'd1)
                $display("RESULT  : PASS");
            else
                $display("RESULT  : FAIL at check #%0d (a0=%08h)",
                         dut.core.rf.regs[3], dut.core.rf.regs[10]);
            $display("----------------------------------------------");
        end
    endtask

endmodule
