`include "he_params.vh"

module ntt_core #(
    parameter COEFF_W = `COEFF_W,
    parameter ADDR_W  = `ADDR_W,
    parameter N       = `NTT_N,
    parameter LOG_N   = `NTT_LOG_N
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 start,
    input  wire                 inverse,   // 0: forward negacyclic NTT, 1: inverse negacyclic NTT
    output reg                  busy,
    output reg                  done,

    // Data RAM port 0
    output reg                  ram0_req,
    output reg                  ram0_we,
    output reg  [ADDR_W-1:0]    ram0_addr,
    output reg  [COEFF_W-1:0]   ram0_wdata,
    input  wire [COEFF_W-1:0]   ram0_rdata,
    input  wire                 ram0_valid,

    // Data RAM port 1
    output reg                  ram1_req,
    output reg                  ram1_we,
    output reg  [ADDR_W-1:0]    ram1_addr,
    output reg  [COEFF_W-1:0]   ram1_wdata,
    input  wire [COEFF_W-1:0]   ram1_rdata,
    input  wire                 ram1_valid
);
    localparam [4:0] S_IDLE     = 5'd0;
    localparam [4:0] S_TW_REQ   = 5'd1;
    localparam [4:0] S_TW_WAIT  = 5'd2;
    localparam [4:0] S_TW_WRITE = 5'd3;
    localparam [4:0] S_BF_REQ   = 5'd4;
    localparam [4:0] S_BF_WAIT  = 5'd5;
    localparam [4:0] S_BF_WRITE = 5'd6;
    localparam [4:0] S_DONE     = 5'd7;
    localparam [ADDR_W:0] N_EXT = N;

    reg [4:0] state;
    reg       mode_inverse;

    reg [ADDR_W:0] idx;
    reg [ADDR_W:0] stage;
    reg [ADDR_W:0] m;
    reg [ADDR_W:0] half;
    reg [ADDR_W:0] group_base;
    reg [ADDR_W:0] j;
    reg [ADDR_W:0] tw_base;

    reg [COEFF_W-1:0] u_reg;
    reg [COEFF_W-1:0] v_reg;
    reg [COEFF_W-1:0] tw_reg;
    reg [COEFF_W-1:0] scale_reg;

    wire [ADDR_W:0] bf_addr0_full = group_base + j;
    wire [ADDR_W:0] bf_addr1_full = group_base + j + half;
    wire [ADDR_W:0] tw_addr_full  = tw_base + j;

    // -------------------------------------------------------------------------
    // Table RAMs.  These are synchronous, one-cycle-latency read memories with
    // req/valid handshaking.  Files live under v1/table/.
    // -------------------------------------------------------------------------
    reg                    twist_fwd_req;
    reg                    twist_inv_req;
    reg                    twiddle_fwd_req;
    reg                    twiddle_inv_req;
    reg  [ADDR_W-1:0]      twist_addr;
    reg  [ADDR_W-1:0]      twiddle_addr;

    wire [COEFF_W-1:0]     twist_fwd_data;
    wire [COEFF_W-1:0]     twist_inv_data;
    wire [COEFF_W-1:0]     twiddle_fwd_data;
    wire [COEFF_W-1:0]     twiddle_inv_data;
    wire                   twist_fwd_valid;
    wire                   twist_inv_valid;
    wire                   twiddle_fwd_valid;
    wire                   twiddle_inv_valid;

    table_rom #(
        .DATA_W(COEFF_W),
        .ADDR_W(ADDR_W),
        .DEPTH(N),
        .INIT_FILE("table/twist_fwd.mem")
    ) u_twist_fwd_rom (
        .clk(clk), .rst(rst), .req(twist_fwd_req), .addr(twist_addr),
        .rdata(twist_fwd_data), .valid(twist_fwd_valid)
    );

    table_rom #(
        .DATA_W(COEFF_W),
        .ADDR_W(ADDR_W),
        .DEPTH(N),
        .INIT_FILE("table/twist_inv_scale.mem")
    ) u_twist_inv_rom (
        .clk(clk), .rst(rst), .req(twist_inv_req), .addr(twist_addr),
        .rdata(twist_inv_data), .valid(twist_inv_valid)
    );

    table_rom #(
        .DATA_W(COEFF_W),
        .ADDR_W(ADDR_W),
        .DEPTH(N),
        .INIT_FILE("table/twiddle_fwd.mem")
    ) u_twiddle_fwd_rom (
        .clk(clk), .rst(rst), .req(twiddle_fwd_req), .addr(twiddle_addr),
        .rdata(twiddle_fwd_data), .valid(twiddle_fwd_valid)
    );

    table_rom #(
        .DATA_W(COEFF_W),
        .ADDR_W(ADDR_W),
        .DEPTH(N),
        .INIT_FILE("table/twiddle_inv.mem")
    ) u_twiddle_inv_rom (
        .clk(clk), .rst(rst), .req(twiddle_inv_req), .addr(twiddle_addr),
        .rdata(twiddle_inv_data), .valid(twiddle_inv_valid)
    );

    wire [COEFF_W-1:0] selected_twist_data  = mode_inverse ? twist_inv_data : twist_fwd_data;
    wire               selected_twist_valid = mode_inverse ? twist_inv_valid : twist_fwd_valid;
    wire [COEFF_W-1:0] selected_tw_data     = mode_inverse ? twiddle_inv_data : twiddle_fwd_data;
    wire               selected_tw_valid    = mode_inverse ? twiddle_inv_valid : twiddle_fwd_valid;

    // -------------------------------------------------------------------------
    // Butterfly arithmetic
    // Forward DIF butterfly:
    //   y0 = u + v
    //   y1 = (u - v) * w
    // Inverse DIT butterfly:
    //   t  = v * w
    //   y0 = u + t
    //   y1 = u - t
    // -------------------------------------------------------------------------
    wire [COEFF_W-1:0] fwd_sum;
    wire [COEFF_W-1:0] fwd_diff;
    wire [COEFF_W-1:0] fwd_prod;
    wire [COEFF_W-1:0] inv_v_tw;
    wire [COEFF_W-1:0] inv_sum;
    wire [COEFF_W-1:0] inv_diff;
    wire [COEFF_W-1:0] scaled_value;

    mod_add u_fwd_add (.a(u_reg),    .b(v_reg),    .y(fwd_sum));
    mod_sub u_fwd_sub (.a(u_reg),    .b(v_reg),    .y(fwd_diff));
    mod_mul u_fwd_mul (.a(fwd_diff), .b(tw_reg),   .y(fwd_prod));

    mod_mul u_inv_mul (.a(v_reg),    .b(tw_reg),   .y(inv_v_tw));
    mod_add u_inv_add (.a(u_reg),    .b(inv_v_tw), .y(inv_sum));
    mod_sub u_inv_sub (.a(u_reg),    .b(inv_v_tw), .y(inv_diff));

    mod_mul u_scale_mul (.a(u_reg),  .b(scale_reg), .y(scaled_value));

    // Combinational output control.
    always @(*) begin
        ram0_req   = 1'b0;
        ram0_we    = 1'b0;
        ram0_addr  = {ADDR_W{1'b0}};
        ram0_wdata = {COEFF_W{1'b0}};

        ram1_req   = 1'b0;
        ram1_we    = 1'b0;
        ram1_addr  = {ADDR_W{1'b0}};
        ram1_wdata = {COEFF_W{1'b0}};

        twist_fwd_req   = 1'b0;
        twist_inv_req   = 1'b0;
        twiddle_fwd_req = 1'b0;
        twiddle_inv_req = 1'b0;
        twist_addr      = idx[ADDR_W-1:0];
        twiddle_addr    = tw_addr_full[ADDR_W-1:0];

        case (state)
            S_TW_REQ: begin
                ram0_req  = 1'b1;
                ram0_we   = 1'b0;
                ram0_addr = idx[ADDR_W-1:0];
                twist_addr = idx[ADDR_W-1:0];
                if (mode_inverse) begin
                    twist_inv_req = 1'b1;
                end else begin
                    twist_fwd_req = 1'b1;
                end
            end

            S_TW_WRITE: begin
                ram0_req   = 1'b1;
                ram0_we    = 1'b1;
                ram0_addr  = idx[ADDR_W-1:0];
                ram0_wdata = scaled_value;
            end

            S_BF_REQ: begin
                ram0_req  = 1'b1;
                ram0_we   = 1'b0;
                ram0_addr = bf_addr0_full[ADDR_W-1:0];

                ram1_req  = 1'b1;
                ram1_we   = 1'b0;
                ram1_addr = bf_addr1_full[ADDR_W-1:0];

                twiddle_addr = tw_addr_full[ADDR_W-1:0];
                if (mode_inverse) begin
                    twiddle_inv_req = 1'b1;
                end else begin
                    twiddle_fwd_req = 1'b1;
                end
            end

            S_BF_WRITE: begin
                ram0_req  = 1'b1;
                ram0_we   = 1'b1;
                ram0_addr = bf_addr0_full[ADDR_W-1:0];

                ram1_req  = 1'b1;
                ram1_we   = 1'b1;
                ram1_addr = bf_addr1_full[ADDR_W-1:0];

                if (mode_inverse) begin
                    ram0_wdata = inv_sum;
                    ram1_wdata = inv_diff;
                end else begin
                    ram0_wdata = fwd_sum;
                    ram1_wdata = fwd_prod;
                end
            end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state        <= S_IDLE;
            mode_inverse <= 1'b0;
            busy         <= 1'b0;
            done         <= 1'b0;
            idx          <= {ADDR_W+1{1'b0}};
            stage        <= {ADDR_W+1{1'b0}};
            m            <= {ADDR_W+1{1'b0}};
            half         <= {ADDR_W+1{1'b0}};
            group_base   <= {ADDR_W+1{1'b0}};
            j            <= {ADDR_W+1{1'b0}};
            tw_base      <= {ADDR_W+1{1'b0}};
            u_reg        <= {COEFF_W{1'b0}};
            v_reg        <= {COEFF_W{1'b0}};
            tw_reg       <= {COEFF_W{1'b0}};
            scale_reg    <= {COEFF_W{1'b0}};
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        busy         <= 1'b1;
                        mode_inverse <= inverse;
                        stage        <= {ADDR_W+1{1'b0}};
                        group_base   <= {ADDR_W+1{1'b0}};
                        j            <= {ADDR_W+1{1'b0}};
                        tw_base      <= {ADDR_W+1{1'b0}};

                        if (inverse) begin
                            // Inverse path: inverse DIT butterfly first, then
                            // multiply by inv_N * psi^(-i).
                            m     <= {{ADDR_W{1'b0}}, 1'b1} << 1; // 2
                            half  <= {{ADDR_W{1'b0}}, 1'b1};      // 1
                            state <= S_BF_REQ;
                        end else begin
                            // Forward path: pre-twist by psi^i first.
                            idx   <= {ADDR_W+1{1'b0}};
                            state <= S_TW_REQ;
                        end
                    end
                end

                S_TW_REQ: begin
                    state <= S_TW_WAIT;
                end

                S_TW_WAIT: begin
                    if (ram0_valid && selected_twist_valid) begin
                        u_reg     <= ram0_rdata;
                        scale_reg <= selected_twist_data;
                        state     <= S_TW_WRITE;
                    end
                end

                S_TW_WRITE: begin
                    if (idx == (N-1)) begin
                        if (mode_inverse) begin
                            state <= S_DONE;
                        end else begin
                            stage      <= {ADDR_W+1{1'b0}};
                            m          <= N_EXT;
                            half       <= (N >> 1);
                            group_base <= {ADDR_W+1{1'b0}};
                            j          <= {ADDR_W+1{1'b0}};
                            tw_base    <= {ADDR_W+1{1'b0}};
                            state      <= S_BF_REQ;
                        end
                    end else begin
                        idx   <= idx + {{ADDR_W{1'b0}}, 1'b1};
                        state <= S_TW_REQ;
                    end
                end

                S_BF_REQ: begin
                    state <= S_BF_WAIT;
                end

                S_BF_WAIT: begin
                    if (ram0_valid && ram1_valid && selected_tw_valid) begin
                        u_reg  <= ram0_rdata;
                        v_reg  <= ram1_rdata;
                        tw_reg <= selected_tw_data;
                        state  <= S_BF_WRITE;
                    end
                end

                S_BF_WRITE: begin
                    if ((j + {{ADDR_W{1'b0}}, 1'b1}) < half) begin
                        j     <= j + {{ADDR_W{1'b0}}, 1'b1};
                        state <= S_BF_REQ;
                    end else begin
                        j <= {ADDR_W+1{1'b0}};

                        if ((group_base + m) < N_EXT) begin
                            group_base <= group_base + m;
                            state      <= S_BF_REQ;
                        end else begin
                            group_base <= {ADDR_W+1{1'b0}};
                            tw_base    <= tw_base + half;

                            if (stage == (LOG_N-1)) begin
                                if (mode_inverse) begin
                                    idx   <= {ADDR_W+1{1'b0}};
                                    state <= S_TW_REQ;
                                end else begin
                                    state <= S_DONE;
                                end
                            end else begin
                                stage <= stage + {{ADDR_W{1'b0}}, 1'b1};
                                if (mode_inverse) begin
                                    m    <= m << 1;
                                    half <= half << 1;
                                end else begin
                                    m    <= m >> 1;
                                    half <= half >> 1;
                                end
                                state <= S_BF_REQ;
                            end
                        end
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
