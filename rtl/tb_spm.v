// ============================================================
//  Testbench for 5-Stage Pipelined 32-bit ALU (spm)
//  EVOLVE.3X | RTL-to-GDS via LibreLane / sky130A
// ============================================================

`timescale 1ns / 1ps

module tb_spm;

    // Clock and reset
    reg         clk;
    reg         rst;
    
    // Inputs
    reg  [31:0] instr;
    reg  [31:0] bypass_a;
    reg  [31:0] bypass_b;
    reg         bypass_valid;
    
    // Outputs
    wire [31:0] result_out;
    wire        zero_out;
    wire        neg_out;
    wire        ov_out;
    
    // Instantiate DUT
    spm dut (
        .clk(clk),
        .rst(rst),
        .instr(instr),
        .bypass_a(bypass_a),
        .bypass_b(bypass_b),
        .bypass_valid(bypass_valid),
        .result_out(result_out),
        .zero_out(zero_out),
        .neg_out(neg_out),
        .ov_out(ov_out)
    );
    
    // Clock generation: 10ns period (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test stimulus
    integer i;
    reg [31:0] expected_result;
    
    initial begin
        // Initialize waveform dump
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_spm);
        
        // Initialize signals
        rst = 1;
        instr = 32'b0;
        bypass_a = 32'b0;
        bypass_b = 32'b0;
        bypass_valid = 0;
        
        // Reset sequence
        repeat(3) @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        $display("\n========================================");
        $display("  5-Stage Pipelined ALU Testbench");
        $display("  Pipeline Latency: 4 cycles");
        $display("========================================\n");
        
        // ============================================================
        // Test 1: ADD operation
        // ============================================================
        $display("Test 1: ADD (5 + 3 = 8)");
        instr = {4'b0000, 28'b0};  // op=ADD
        bypass_a = 32'd5;
        bypass_b = 32'd3;
        bypass_valid = 1;
        expected_result = 32'd8;
        
        // Wait for pipeline latency (4 cycles)
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = %d (expected %d)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = %d (expected %d)", result_out, expected_result);
        
        // ============================================================
        // Test 2: SUB operation
        // ============================================================
        $display("\nTest 2: SUB (10 - 4 = 6)");
        instr = {4'b0001, 28'b0};  // op=SUB
        bypass_a = 32'd10;
        bypass_b = 32'd4;
        bypass_valid = 1;
        expected_result = 32'd6;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = %d (expected %d)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = %d (expected %d)", result_out, expected_result);
        
        // ============================================================
        // Test 3: AND operation
        // ============================================================
        $display("\nTest 3: AND (0xFF00 & 0x0F0F = 0x0F00)");
        instr = {4'b0010, 28'b0};  // op=AND
        bypass_a = 32'hFF00;
        bypass_b = 32'h0F0F;
        bypass_valid = 1;
        expected_result = 32'h0F00;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = 0x%h (expected 0x%h)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = 0x%h (expected 0x%h)", result_out, expected_result);
        
        // ============================================================
        // Test 4: OR operation
        // ============================================================
        $display("\nTest 4: OR (0xF0F0 | 0x0F0F = 0xFFFF)");
        instr = {4'b0011, 28'b0};  // op=OR
        bypass_a = 32'hF0F0;
        bypass_b = 32'h0F0F;
        bypass_valid = 1;
        expected_result = 32'hFFFF;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = 0x%h (expected 0x%h)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = 0x%h (expected 0x%h)", result_out, expected_result);
        
        // ============================================================
        // Test 5: XOR operation
        // ============================================================
        $display("\nTest 5: XOR (0xAAAA ^ 0x5555 = 0xFFFF)");
        instr = {4'b0100, 28'b0};  // op=XOR
        bypass_a = 32'hAAAA;
        bypass_b = 32'h5555;
        bypass_valid = 1;
        expected_result = 32'hFFFF;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = 0x%h (expected 0x%h)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = 0x%h (expected 0x%h)", result_out, expected_result);
        
        // ============================================================
        // Test 6: NOR operation
        // ============================================================
        $display("\nTest 6: NOR (~(0x0F0F | 0xF0F0) = 0xFFFF0000)");
        instr = {4'b1010, 28'b0};  // op=NOR
        bypass_a = 32'h0F0F;
        bypass_b = 32'hF0F0;
        bypass_valid = 1;
        expected_result = 32'hFFFF0000;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = 0x%h (expected 0x%h)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = 0x%h (expected 0x%h)", result_out, expected_result);
        
        // ============================================================
        // Test 7: SLT (Set Less Than - signed)
        // ============================================================
        $display("\nTest 7: SLT (-5 < 3 = 1)");
        instr = {4'b0101, 28'b0};  // op=SLT
        bypass_a = -32'd5;
        bypass_b = 32'd3;
        bypass_valid = 1;
        expected_result = 32'd1;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = %d (expected %d)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = %d (expected %d)", result_out, expected_result);
        
        // ============================================================
        // Test 8: SLTU (Set Less Than - unsigned)
        // ============================================================
        $display("\nTest 8: SLTU (5 < 10 = 1)");
        instr = {4'b0110, 28'b0};  // op=SLTU
        bypass_a = 32'd5;
        bypass_b = 32'd10;
        bypass_valid = 1;
        expected_result = 32'd1;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = %d (expected %d)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = %d (expected %d)", result_out, expected_result);
        
        // ============================================================
        // Test 9: SLL (Shift Left Logical)
        // ============================================================
        $display("\nTest 9: SLL (0x00000001 << 4 = 0x00000010)");
        instr = {4'b0111, 28'b0};  // op=SLL
        bypass_a = 32'h00000001;
        bypass_b = 32'd4;
        bypass_valid = 1;
        expected_result = 32'h00000010;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = 0x%h (expected 0x%h)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = 0x%h (expected 0x%h)", result_out, expected_result);
        
        // ============================================================
        // Test 10: SRL (Shift Right Logical)
        // ============================================================
        $display("\nTest 10: SRL (0x80000000 >> 4 = 0x08000000)");
        instr = {4'b1000, 28'b0};  // op=SRL
        bypass_a = 32'h80000000;
        bypass_b = 32'd4;
        bypass_valid = 1;
        expected_result = 32'h08000000;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = 0x%h (expected 0x%h)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = 0x%h (expected 0x%h)", result_out, expected_result);
        
        // ============================================================
        // Test 11: SRA (Shift Right Arithmetic)
        // ============================================================
        $display("\nTest 11: SRA (0x80000000 >>> 4 = 0xF8000000)");
        instr = {4'b1001, 28'b0};  // op=SRA
        bypass_a = 32'h80000000;
        bypass_b = 32'd4;
        bypass_valid = 1;
        expected_result = 32'hF8000000;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = 0x%h (expected 0x%h)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = 0x%h (expected 0x%h)", result_out, expected_result);
        
        // ============================================================
        // Test 12: PASS (Move/Load Immediate)
        // ============================================================
        $display("\nTest 12: PASS (b = 0xDEADBEEF)");
        instr = {4'b1011, 28'b0};  // op=PASS
        bypass_a = 32'h00000000;
        bypass_b = 32'hDEADBEEF;
        bypass_valid = 1;
        expected_result = 32'hDEADBEEF;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result)
            $display("  ✓ PASS: result = 0x%h (expected 0x%h)", result_out, expected_result);
        else
            $display("  ✗ FAIL: result = 0x%h (expected 0x%h)", result_out, expected_result);
        
        // ============================================================
        // Test 13: Zero flag test
        // ============================================================
        $display("\nTest 13: Zero flag (5 - 5 = 0, zero_out = 1)");
        instr = {4'b0001, 28'b0};  // op=SUB
        bypass_a = 32'd5;
        bypass_b = 32'd5;
        bypass_valid = 1;
        expected_result = 32'd0;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (result_out == expected_result && zero_out == 1)
            $display("  ✓ PASS: result = %d, zero_out = %b", result_out, zero_out);
        else
            $display("  ✗ FAIL: result = %d, zero_out = %b (expected 0, 1)", result_out, zero_out);
        
        // ============================================================
        // Test 14: Negative flag test
        // ============================================================
        $display("\nTest 14: Negative flag (3 - 10 = -7, neg_out = 1)");
        instr = {4'b0001, 28'b0};  // op=SUB
        bypass_a = 32'd3;
        bypass_b = 32'd10;
        bypass_valid = 1;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (neg_out == 1)
            $display("  ✓ PASS: result = %d, neg_out = %b", $signed(result_out), neg_out);
        else
            $display("  ✗ FAIL: result = %d, neg_out = %b (expected negative)", $signed(result_out), neg_out);
        
        // ============================================================
        // Test 15: Overflow flag test (positive overflow)
        // ============================================================
        $display("\nTest 15: Overflow flag (0x7FFFFFFF + 1 = overflow)");
        instr = {4'b0000, 28'b0};  // op=ADD
        bypass_a = 32'h7FFFFFFF;  // Max positive signed int
        bypass_b = 32'd1;
        bypass_valid = 1;
        
        repeat(4) @(posedge clk);
        @(posedge clk);
        
        if (ov_out == 1)
            $display("  ✓ PASS: overflow detected, ov_out = %b", ov_out);
        else
            $display("  ✗ FAIL: overflow not detected, ov_out = %b", ov_out);
        
        // ============================================================
        // Test 16: Pipeline throughput test (back-to-back operations)
        // ============================================================
        $display("\nTest 16: Pipeline throughput (3 back-to-back ADDs)");
        
        // Issue 3 ADD operations back-to-back
        instr = {4'b0000, 28'b0};  // op=ADD
        bypass_valid = 1;
        
        // Operation 1: 1 + 1 = 2
        bypass_a = 32'd1;
        bypass_b = 32'd1;
        @(posedge clk);
        
        // Operation 2: 2 + 2 = 4
        bypass_a = 32'd2;
        bypass_b = 32'd2;
        @(posedge clk);
        
        // Operation 3: 3 + 3 = 6
        bypass_a = 32'd3;
        bypass_b = 32'd3;
        @(posedge clk);
        
        // Wait for first result (1 more cycle after 3rd issue)
        @(posedge clk);
        
        // Check results come out every cycle
        if (result_out == 32'd2) begin
            $display("  ✓ Cycle 1: result = %d (expected 2)", result_out);
            @(posedge clk);
            if (result_out == 32'd4) begin
                $display("  ✓ Cycle 2: result = %d (expected 4)", result_out);
                @(posedge clk);
                if (result_out == 32'd6) begin
                    $display("  ✓ Cycle 3: result = %d (expected 6)", result_out);
                    $display("  ✓ PASS: Pipeline throughput = 1 result/cycle");
                end else
                    $display("  ✗ FAIL: Cycle 3 result = %d (expected 6)", result_out);
            end else
                $display("  ✗ FAIL: Cycle 2 result = %d (expected 4)", result_out);
        end else
            $display("  ✗ FAIL: Cycle 1 result = %d (expected 2)", result_out);
        
        // ============================================================
        // Test complete
        // ============================================================
        $display("\n========================================");
        $display("  All tests completed!");
        $display("========================================\n");
        
        repeat(5) @(posedge clk);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #10000;
        $display("\n✗ ERROR: Testbench timeout!");
        $finish;
    end

endmodule
