// ============================================================
//  5-Stage Pipelined 32-bit ALU - SYNC RESET (sky130A clean)
//  RTL-to-GDS via LibreLane / sky130A
//  Top module: spm
// ============================================================

`define ALU_ADD  4'b0000
`define ALU_SUB  4'b0001
`define ALU_AND  4'b0010
`define ALU_OR   4'b0011
`define ALU_XOR  4'b0100
`define ALU_SLT  4'b0101
`define ALU_SLTU 4'b0110
`define ALU_SLL  4'b0111
`define ALU_SRL  4'b1000
`define ALU_SRA  4'b1001
`define ALU_NOR  4'b1010
`define ALU_PASS 4'b1011

// ── Barrel Shifter ──────────────────────────────────────────
module barrel_shifter(
    input  [31:0] in,
    input  [4:0]  shamt,
    input         right,
    input         arith,
    output [31:0] out
);
    wire fill = arith & in[31];
    wire [31:0] s0, s1, s2, s3;
    
    assign s0 = right ? (shamt[0] ? {fill,    in[31:1]}  : in) :
                        (shamt[0] ? {in[30:0], 1'b0}     : in);
    
    assign s1 = right ? (shamt[1] ? {{2{fill}}, s0[31:2]}  : s0) :
                        (shamt[1] ? {s0[29:0], 2'b0}       : s0);
    
    assign s2 = right ? (shamt[2] ? {{4{fill}}, s1[31:4]}  : s1) :
                        (shamt[2] ? {s1[27:0], 4'b0}       : s1);
    
    assign s3 = right ? (shamt[3] ? {{8{fill}}, s2[31:8]}  : s2) :
                        (shamt[3] ? {s2[23:0], 8'b0}       : s2);
    
    assign out = right ? (shamt[4] ? {{16{fill}}, s3[31:16]} : s3) :
                         (shamt[4] ? {s3[15:0],  16'b0}      : s3);
endmodule

// ── 4-bit CLA Block ─────────────────────────────────────────
module cla4(
    input  [3:0] a, b,
    input        cin,
    output [3:0] sum,
    output       cout, pg, gg
);
    wire [3:0] g = a & b;
    wire [3:0] p = a ^ b;
    wire c1 = g[0] | (p[0] & cin);
    wire c2 = g[1] | (p[1] & c1);
    wire c3 = g[2] | (p[2] & c2);
    
    assign cout = g[3] | (p[3] & c3);
    assign sum  = p ^ {c3, c2, c1, cin};
    assign pg   = &p;
    assign gg   = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) |
                  (p[3] & p[2] & p[1] & g[0]);
endmodule

// ── 32-bit CLA Adder ────────────────────────────────────────
module cla32(
    input  [31:0] a, b,
    input         cin,
    output [31:0] sum,
    output        cout
);
    wire [7:0] c, pg, gg;
    
    assign c[0] = cin;
    assign c[1] = gg[0] | (pg[0] & cin);
    assign c[2] = gg[1] | (pg[1] & c[1]);
    assign c[3] = gg[2] | (pg[2] & c[2]);
    assign c[4] = gg[3] | (pg[3] & c[3]);
    assign c[5] = gg[4] | (pg[4] & c[4]);
    assign c[6] = gg[5] | (pg[5] & c[5]);
    assign c[7] = gg[6] | (pg[6] & c[6]);
    
    cla4 b0(.a(a[3:0]),   .b(b[3:0]),   .cin(c[0]), .sum(sum[3:0]),   .cout(), .pg(pg[0]), .gg(gg[0]));
    cla4 b1(.a(a[7:4]),   .b(b[7:4]),   .cin(c[1]), .sum(sum[7:4]),   .cout(), .pg(pg[1]), .gg(gg[1]));
    cla4 b2(.a(a[11:8]),  .b(b[11:8]),  .cin(c[2]), .sum(sum[11:8]),  .cout(), .pg(pg[2]), .gg(gg[2]));
    cla4 b3(.a(a[15:12]), .b(b[15:12]), .cin(c[3]), .sum(sum[15:12]), .cout(), .pg(pg[3]), .gg(gg[3]));
    cla4 b4(.a(a[19:16]), .b(b[19:16]), .cin(c[4]), .sum(sum[19:16]), .cout(), .pg(pg[4]), .gg(gg[4]));
    cla4 b5(.a(a[23:20]), .b(b[23:20]), .cin(c[5]), .sum(sum[23:20]), .cout(), .pg(pg[5]), .gg(gg[5]));
    cla4 b6(.a(a[27:24]), .b(b[27:24]), .cin(c[6]), .sum(sum[27:24]), .cout(), .pg(pg[6]), .gg(gg[6]));
    cla4 b7(.a(a[31:28]), .b(b[31:28]), .cin(c[7]), .sum(sum[31:28]), .cout(cout), .pg(pg[7]), .gg(gg[7]));
endmodule

// ── Combinational ALU Core (pure combinational - NO always @*) ──
module alu_core(
    input  [31:0] a, b,
    input  [3:0]  op,
    output [31:0] result,
    output        zero, negative, overflow, carry_out
);
    wire [31:0] add_r, sub_r;
    wire        add_cout, sub_cout;
    wire [31:0] shift_ll, shift_rl, shift_ra;
    
    cla32 adder(.a(a), .b(b),   .cin(1'b0), .sum(add_r), .cout(add_cout));
    cla32 subtr(.a(a), .b(~b),  .cin(1'b1), .sum(sub_r), .cout(sub_cout));
    
    barrel_shifter sll(.in(a), .shamt(b[4:0]), .right(1'b0), .arith(1'b0), .out(shift_ll));
    barrel_shifter srl(.in(a), .shamt(b[4:0]), .right(1'b1), .arith(1'b0), .out(shift_rl));
    barrel_shifter sra(.in(a), .shamt(b[4:0]), .right(1'b1), .arith(1'b1), .out(shift_ra));
    
    wire       slt_r  = sub_r[31] ^ (a[31] ^ b[31] ? a[31] : 1'b0);
    wire       sltu_r = ~sub_cout;
    
    // Mux ALU result using one-hot select to avoid always @(*)
    wire [31:0] mux_add  = {32{op == `ALU_ADD}}  & add_r;
    wire [31:0] mux_sub  = {32{op == `ALU_SUB}}  & sub_r;
    wire [31:0] mux_and  = {32{op == `ALU_AND}}  & (a & b);
    wire [31:0] mux_or   = {32{op == `ALU_OR}}   & (a | b);
    wire [31:0] mux_xor  = {32{op == `ALU_XOR}}  & (a ^ b);
    wire [31:0] mux_nor  = {32{op == `ALU_NOR}}  & (~(a | b));
    wire [31:0] mux_slt  = {32{op == `ALU_SLT}}  & {31'b0, slt_r};
    wire [31:0] mux_sltu = {32{op == `ALU_SLTU}} & {31'b0, sltu_r};
    wire [31:0] mux_sll  = {32{op == `ALU_SLL}}  & shift_ll;
    wire [31:0] mux_srl  = {32{op == `ALU_SRL}}  & shift_rl;
    wire [31:0] mux_sra  = {32{op == `ALU_SRA}}  & shift_ra;
    wire [31:0] mux_pass = {32{op == `ALU_PASS}} & b;
    
    assign result = mux_add | mux_sub | mux_and | mux_or  | mux_xor |
                    mux_nor | mux_slt | mux_sltu | mux_sll | mux_srl |
                    mux_sra | mux_pass;
    
    assign zero      = (result == 32'b0);
    assign negative  = result[31];
    assign overflow  = ((op == `ALU_ADD) & (~a[31] & ~b[31] &  add_r[31]))
                     | ((op == `ALU_ADD) & ( a[31] &  b[31] & ~add_r[31]))
                     | ((op == `ALU_SUB) & ( a[31] & ~b[31] & ~sub_r[31]))
                     | ((op == `ALU_SUB) & (~a[31] &  b[31] &  sub_r[31]));
    assign carry_out = (op == `ALU_ADD) ? add_cout : sub_cout;
endmodule

// ── Top: 5-Stage Pipeline (synchronous reset only) ───────────
module spm(
    input         clk, rst,
    input  [31:0] instr,
    input  [31:0] bypass_a, bypass_b,
    input         bypass_valid,
    output [31:0] result_out,
    output        zero_out, neg_out, ov_out
);
    // ── Stage 1: IF/ID ──────────────────────────────────────
    reg [31:0] ifid_instr;
    always @(posedge clk)
        ifid_instr <= rst ? 32'b0 : instr;
    
    // ── Stage 2: ID/EX ──────────────────────────────────────
    wire [3:0]  dec_op = ifid_instr[31:28];
    wire [31:0] dec_a  = bypass_valid ? bypass_a : {27'b0, ifid_instr[27:23]};
    wire [31:0] dec_b  = bypass_valid ? bypass_b : {{19{ifid_instr[12]}}, ifid_instr[12:0]};
    
    reg [31:0] idex_a, idex_b;
    reg [3:0]  idex_op;
    always @(posedge clk) begin
        idex_a  <= rst ? 32'b0 : dec_a;
        idex_b  <= rst ? 32'b0 : dec_b;
        idex_op <= rst ?  4'b0 : dec_op;
    end
    
    // ── Stage 3: EX/MA ──────────────────────────────────────
    wire [31:0] ex_result;
    wire        ex_zero, ex_neg, ex_ov, ex_co;
    
    alu_core alu(
        .a(idex_a), .b(idex_b), .op(idex_op),
        .result(ex_result),
        .zero(ex_zero), .negative(ex_neg),
        .overflow(ex_ov), .carry_out(ex_co)
    );
    
    reg [31:0] exma_result;
    reg        exma_zero, exma_neg, exma_ov;
    always @(posedge clk) begin
        exma_result <= rst ? 32'b0 : ex_result;
        exma_zero   <= rst ? 1'b0  : ex_zero;
        exma_neg    <= rst ? 1'b0  : ex_neg;
        exma_ov     <= rst ? 1'b0  : ex_ov;
    end
    
    // ── Stage 4: MA/WB ──────────────────────────────────────
    reg [31:0] mawb_result;
    reg        mawb_zero, mawb_neg, mawb_ov;
    always @(posedge clk) begin
        mawb_result <= rst ? 32'b0 : exma_result;
        mawb_zero   <= rst ? 1'b0  : exma_zero;
        mawb_neg    <= rst ? 1'b0  : exma_neg;
        mawb_ov     <= rst ? 1'b0  : exma_ov;
    end
    
    // ── Stage 5: WB out ─────────────────────────────────────
    reg [31:0] wb_result;
    reg        wb_zero, wb_neg, wb_ov;
    always @(posedge clk) begin
        wb_result <= rst ? 32'b0 : mawb_result;
        wb_zero   <= rst ? 1'b0  : mawb_zero;
        wb_neg    <= rst ? 1'b0  : mawb_neg;
        wb_ov     <= rst ? 1'b0  : mawb_ov;
    end
    
    assign result_out = wb_result;
    assign zero_out   = wb_zero;
    assign neg_out    = wb_neg;
    assign ov_out     = wb_ov;
endmodule
