`include "he_params.vh"

module mod_add #(
    parameter COEFF_W = `COEFF_W,
    parameter MOD_Q   = `MOD_Q
)(
    input  wire [COEFF_W-1:0] a,
    input  wire [COEFF_W-1:0] b,
    output wire [COEFF_W-1:0] y
);
    localparam [COEFF_W:0] Q = MOD_Q;

    wire [COEFF_W:0] sum = {1'b0, a} + {1'b0, b};
    wire [COEFF_W:0] red = (sum >= Q) ? (sum - Q) : sum;

    assign y = red[COEFF_W-1:0];
endmodule
