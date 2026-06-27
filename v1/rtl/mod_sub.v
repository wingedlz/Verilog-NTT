`include "he_params.vh"

module mod_sub #(
    parameter COEFF_W = `COEFF_W,
    parameter MOD_Q   = `MOD_Q
)(
    input  wire [COEFF_W-1:0] a,
    input  wire [COEFF_W-1:0] b,
    output wire [COEFF_W-1:0] y
);
    localparam [COEFF_W:0] Q = MOD_Q;

    wire [COEFF_W:0] aa = {1'b0, a};
    wire [COEFF_W:0] bb = {1'b0, b};

    wire [COEFF_W:0] raw = (aa >= bb) ? (aa - bb) : (aa + Q - bb);
    assign y = raw[COEFF_W-1:0];
endmodule
