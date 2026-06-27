`include "he_params.vh"

module pointwise_mul_engine #(
    parameter COEFF_W = `COEFF_W,
    parameter ADDR_W  = `ADDR_W,
    parameter N       = `NTT_N
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               start,
    output reg                busy,
    output reg                done,

    output reg                a_req,
    output reg                a_we,
    output reg [ADDR_W-1:0]   a_addr,
    output reg [COEFF_W-1:0]  a_wdata,
    input  wire [COEFF_W-1:0] a_rdata,
    input  wire               a_valid,

    output reg                b_req,
    output reg                b_we,
    output reg [ADDR_W-1:0]   b_addr,
    output reg [COEFF_W-1:0]  b_wdata,
    input  wire [COEFF_W-1:0] b_rdata,
    input  wire               b_valid,

    output reg                c_req,
    output reg                c_we,
    output reg [ADDR_W-1:0]   c_addr,
    output reg [COEFF_W-1:0]  c_wdata,
    input  wire [COEFF_W-1:0] c_rdata,
    input  wire               c_valid
);
    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_REQ   = 3'd1;
    localparam [2:0] S_WAIT  = 3'd2;
    localparam [2:0] S_WRITE = 3'd3;
    localparam [2:0] S_DONE  = 3'd4;

    reg [2:0] state;
    reg [ADDR_W:0] idx;
    reg [COEFF_W-1:0] a_reg;
    reg [COEFF_W-1:0] b_reg;

    wire [COEFF_W-1:0] product;
    mod_mul u_mul (.a(a_reg), .b(b_reg), .y(product));

    always @(*) begin
        a_req   = 1'b0;
        a_we    = 1'b0;
        a_addr  = idx[ADDR_W-1:0];
        a_wdata = {COEFF_W{1'b0}};

        b_req   = 1'b0;
        b_we    = 1'b0;
        b_addr  = idx[ADDR_W-1:0];
        b_wdata = {COEFF_W{1'b0}};

        c_req   = 1'b0;
        c_we    = 1'b0;
        c_addr  = idx[ADDR_W-1:0];
        c_wdata = {COEFF_W{1'b0}};

        case (state)
            S_REQ: begin
                a_req = 1'b1;
                b_req = 1'b1;
            end
            S_WRITE: begin
                c_req   = 1'b1;
                c_we    = 1'b1;
                c_wdata = product;
            end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            busy  <= 1'b0;
            done  <= 1'b0;
            idx   <= {ADDR_W+1{1'b0}};
            a_reg <= {COEFF_W{1'b0}};
            b_reg <= {COEFF_W{1'b0}};
        end else begin
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        idx   <= {ADDR_W+1{1'b0}};
                        busy  <= 1'b1;
                        state <= S_REQ;
                    end
                end
                S_REQ: begin
                    state <= S_WAIT;
                end
                S_WAIT: begin
                    if (a_valid && b_valid) begin
                        a_reg <= a_rdata;
                        b_reg <= b_rdata;
                        state <= S_WRITE;
                    end
                end
                S_WRITE: begin
                    if (idx == (N-1)) begin
                        state <= S_DONE;
                    end else begin
                        idx   <= idx + {{ADDR_W{1'b0}}, 1'b1};
                        state <= S_REQ;
                    end
                end
                S_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
