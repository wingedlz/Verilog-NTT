`include "he_params.vh"

module mod_mul #(
    parameter COEFF_W       = `COEFF_W,
    parameter MOD_Q         = `MOD_Q,
    parameter BARRETT_SHIFT = `BARRETT_SHIFT,
    parameter BARRETT_MU    = `BARRETT_MU
)(
    input  wire [COEFF_W-1:0] a,
    input  wire [COEFF_W-1:0] b,
    output wire [COEFF_W-1:0] y
);
    // This module avoids the Verilog '%' operator in RTL.  The reduction is a
    // constant-modulus Barrett reduction.  For v1 q=65537 and 17-bit residues,
    // the product is at most 34 bits and the Barrett path fits comfortably in
    // 64-bit arithmetic.

    localparam [63:0] Q64  = MOD_Q;
    localparam [63:0] MU64 = BARRETT_MU;

    wire [2*COEFF_W-1:0] product = a * b;
    wire [63:0]          p64     = product;

    wire [127:0]         barrett_product = p64 * MU64;
    wire [63:0]          quotient        = barrett_product >> BARRETT_SHIFT;
    wire [127:0]         q_product       = quotient * Q64;
    wire [127:0]         r0_wide         = {64'd0, p64} - q_product;
    wire [63:0]          r0              = r0_wide[63:0];

    // A few conditional subtracts make the reducer robust if parameters are
    // changed to another nearby NTT-friendly prime.
    wire [63:0] r1 = (r0 >= Q64) ? (r0 - Q64) : r0;
    wire [63:0] r2 = (r1 >= Q64) ? (r1 - Q64) : r1;
    wire [63:0] r3 = (r2 >= Q64) ? (r2 - Q64) : r2;
    wire [63:0] r4 = (r3 >= Q64) ? (r3 - Q64) : r3;

    assign y = r4[COEFF_W-1:0];
endmodule
