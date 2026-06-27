`timescale 1ns/1ps
`include "he_params.vh"

module tb_v1;
    localparam integer N       = `NTT_N;
    localparam integer ADDR_W  = `ADDR_W;
    localparam integer COEFF_W = `COEFF_W;

    localparam [1:0] OWNER_HOST = 2'd0;
    localparam [1:0] OWNER_NTT  = 2'd1;
    localparam [1:0] OWNER_ADD  = 2'd2;
    localparam [1:0] OWNER_PMUL = 2'd3;

    localparam integer RAM_A   = 0;
    localparam integer RAM_B   = 1;
    localparam integer RAM_C   = 2;
    localparam integer RAM_SUM = 3;

    reg clk;
    reg rst;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Hardwired test vectors and expected outputs.
    reg [COEFF_W-1:0] a_init  [0:N-1];
    reg [COEFF_W-1:0] b_init  [0:N-1];
    reg [COEFF_W-1:0] exp_add [0:N-1];
    reg [COEFF_W-1:0] exp_mul [0:N-1];

    integer i;
    initial begin
        for (i = 0; i < N; i = i + 1) begin
            a_init[i]  = {COEFF_W{1'b0}};
            b_init[i]  = {COEFF_W{1'b0}};
            exp_add[i] = {COEFF_W{1'b0}};
            exp_mul[i] = {COEFF_W{1'b0}};
        end
        `include "hardwired_vectors.svh"
    end

    // ---------------------------------------------------------------------
    // Host-side controls used only by the testbench to load/read RAMs.
    // The design engines still talk to RAM only through req/we/valid ports.
    // ---------------------------------------------------------------------
    reg [1:0] owner_a;
    reg [1:0] owner_b;
    reg [1:0] owner_c;
    reg [1:0] owner_sum;

    reg host_a_req, host_a_we;
    reg [ADDR_W-1:0] host_a_addr;
    reg [COEFF_W-1:0] host_a_wdata;

    reg host_b_req, host_b_we;
    reg [ADDR_W-1:0] host_b_addr;
    reg [COEFF_W-1:0] host_b_wdata;

    reg host_c_req, host_c_we;
    reg [ADDR_W-1:0] host_c_addr;
    reg [COEFF_W-1:0] host_c_wdata;

    reg host_sum_req, host_sum_we;
    reg [ADDR_W-1:0] host_sum_addr;
    reg [COEFF_W-1:0] host_sum_wdata;

    // ---------------------------------------------------------------------
    // RAM wires
    // ---------------------------------------------------------------------
    wire ram_a_req0, ram_a_we0, ram_a_req1, ram_a_we1;
    wire [ADDR_W-1:0] ram_a_addr0, ram_a_addr1;
    wire [COEFF_W-1:0] ram_a_wdata0, ram_a_wdata1;
    wire [COEFF_W-1:0] ram_a_rdata0, ram_a_rdata1;
    wire ram_a_valid0, ram_a_valid1;

    wire ram_b_req0, ram_b_we0, ram_b_req1, ram_b_we1;
    wire [ADDR_W-1:0] ram_b_addr0, ram_b_addr1;
    wire [COEFF_W-1:0] ram_b_wdata0, ram_b_wdata1;
    wire [COEFF_W-1:0] ram_b_rdata0, ram_b_rdata1;
    wire ram_b_valid0, ram_b_valid1;

    wire ram_c_req0, ram_c_we0, ram_c_req1, ram_c_we1;
    wire [ADDR_W-1:0] ram_c_addr0, ram_c_addr1;
    wire [COEFF_W-1:0] ram_c_wdata0, ram_c_wdata1;
    wire [COEFF_W-1:0] ram_c_rdata0, ram_c_rdata1;
    wire ram_c_valid0, ram_c_valid1;

    wire ram_sum_req0, ram_sum_we0, ram_sum_req1, ram_sum_we1;
    wire [ADDR_W-1:0] ram_sum_addr0, ram_sum_addr1;
    wire [COEFF_W-1:0] ram_sum_wdata0, ram_sum_wdata1;
    wire [COEFF_W-1:0] ram_sum_rdata0, ram_sum_rdata1;
    wire ram_sum_valid0, ram_sum_valid1;

    // ---------------------------------------------------------------------
    // NTT core signals: one core per RAM used in the testbench.
    // ---------------------------------------------------------------------
    reg ntt_a_start, ntt_a_inverse;
    wire ntt_a_busy, ntt_a_done;
    wire ntt_a_req0, ntt_a_we0, ntt_a_req1, ntt_a_we1;
    wire [ADDR_W-1:0] ntt_a_addr0, ntt_a_addr1;
    wire [COEFF_W-1:0] ntt_a_wdata0, ntt_a_wdata1;

    reg ntt_b_start, ntt_b_inverse;
    wire ntt_b_busy, ntt_b_done;
    wire ntt_b_req0, ntt_b_we0, ntt_b_req1, ntt_b_we1;
    wire [ADDR_W-1:0] ntt_b_addr0, ntt_b_addr1;
    wire [COEFF_W-1:0] ntt_b_wdata0, ntt_b_wdata1;

    reg ntt_c_start, ntt_c_inverse;
    wire ntt_c_busy, ntt_c_done;
    wire ntt_c_req0, ntt_c_we0, ntt_c_req1, ntt_c_we1;
    wire [ADDR_W-1:0] ntt_c_addr0, ntt_c_addr1;
    wire [COEFF_W-1:0] ntt_c_wdata0, ntt_c_wdata1;

    // ---------------------------------------------------------------------
    // Polynomial addition and pointwise multiplication engine signals.
    // ---------------------------------------------------------------------
    reg add_start;
    wire add_busy, add_done;
    wire add_a_req, add_a_we, add_b_req, add_b_we, add_c_req, add_c_we;
    wire [ADDR_W-1:0] add_a_addr, add_b_addr, add_c_addr;
    wire [COEFF_W-1:0] add_a_wdata, add_b_wdata, add_c_wdata;

    reg pmul_start;
    wire pmul_busy, pmul_done;
    wire pmul_a_req, pmul_a_we, pmul_b_req, pmul_b_we, pmul_c_req, pmul_c_we;
    wire [ADDR_W-1:0] pmul_a_addr, pmul_b_addr, pmul_c_addr;
    wire [COEFF_W-1:0] pmul_a_wdata, pmul_b_wdata, pmul_c_wdata;

    // ---------------------------------------------------------------------
    // RAM ownership muxes.  No '% N' address wrapping is used; ADDR_W slicing
    // naturally maps counters into RAM addresses.
    // ---------------------------------------------------------------------
    assign ram_a_req0   = (owner_a == OWNER_HOST) ? host_a_req   :
                          (owner_a == OWNER_NTT)  ? ntt_a_req0   :
                          (owner_a == OWNER_ADD)  ? add_a_req   :
                          (owner_a == OWNER_PMUL) ? pmul_a_req  : 1'b0;
    assign ram_a_we0    = (owner_a == OWNER_HOST) ? host_a_we    :
                          (owner_a == OWNER_NTT)  ? ntt_a_we0    :
                          (owner_a == OWNER_ADD)  ? add_a_we    :
                          (owner_a == OWNER_PMUL) ? pmul_a_we   : 1'b0;
    assign ram_a_addr0  = (owner_a == OWNER_HOST) ? host_a_addr  :
                          (owner_a == OWNER_NTT)  ? ntt_a_addr0  :
                          (owner_a == OWNER_ADD)  ? add_a_addr  :
                          (owner_a == OWNER_PMUL) ? pmul_a_addr : {ADDR_W{1'b0}};
    assign ram_a_wdata0 = (owner_a == OWNER_HOST) ? host_a_wdata :
                          (owner_a == OWNER_NTT)  ? ntt_a_wdata0 :
                          (owner_a == OWNER_ADD)  ? add_a_wdata :
                          (owner_a == OWNER_PMUL) ? pmul_a_wdata: {COEFF_W{1'b0}};
    assign ram_a_req1   = (owner_a == OWNER_NTT) ? ntt_a_req1 : 1'b0;
    assign ram_a_we1    = (owner_a == OWNER_NTT) ? ntt_a_we1  : 1'b0;
    assign ram_a_addr1  = (owner_a == OWNER_NTT) ? ntt_a_addr1: {ADDR_W{1'b0}};
    assign ram_a_wdata1 = (owner_a == OWNER_NTT) ? ntt_a_wdata1:{COEFF_W{1'b0}};

    assign ram_b_req0   = (owner_b == OWNER_HOST) ? host_b_req   :
                          (owner_b == OWNER_NTT)  ? ntt_b_req0   :
                          (owner_b == OWNER_ADD)  ? add_b_req   :
                          (owner_b == OWNER_PMUL) ? pmul_b_req  : 1'b0;
    assign ram_b_we0    = (owner_b == OWNER_HOST) ? host_b_we    :
                          (owner_b == OWNER_NTT)  ? ntt_b_we0    :
                          (owner_b == OWNER_ADD)  ? add_b_we    :
                          (owner_b == OWNER_PMUL) ? pmul_b_we   : 1'b0;
    assign ram_b_addr0  = (owner_b == OWNER_HOST) ? host_b_addr  :
                          (owner_b == OWNER_NTT)  ? ntt_b_addr0  :
                          (owner_b == OWNER_ADD)  ? add_b_addr  :
                          (owner_b == OWNER_PMUL) ? pmul_b_addr : {ADDR_W{1'b0}};
    assign ram_b_wdata0 = (owner_b == OWNER_HOST) ? host_b_wdata :
                          (owner_b == OWNER_NTT)  ? ntt_b_wdata0 :
                          (owner_b == OWNER_ADD)  ? add_b_wdata :
                          (owner_b == OWNER_PMUL) ? pmul_b_wdata: {COEFF_W{1'b0}};
    assign ram_b_req1   = (owner_b == OWNER_NTT) ? ntt_b_req1 : 1'b0;
    assign ram_b_we1    = (owner_b == OWNER_NTT) ? ntt_b_we1  : 1'b0;
    assign ram_b_addr1  = (owner_b == OWNER_NTT) ? ntt_b_addr1: {ADDR_W{1'b0}};
    assign ram_b_wdata1 = (owner_b == OWNER_NTT) ? ntt_b_wdata1:{COEFF_W{1'b0}};

    assign ram_c_req0   = (owner_c == OWNER_HOST) ? host_c_req   :
                          (owner_c == OWNER_NTT)  ? ntt_c_req0   :
                          (owner_c == OWNER_PMUL) ? pmul_c_req  : 1'b0;
    assign ram_c_we0    = (owner_c == OWNER_HOST) ? host_c_we    :
                          (owner_c == OWNER_NTT)  ? ntt_c_we0    :
                          (owner_c == OWNER_PMUL) ? pmul_c_we   : 1'b0;
    assign ram_c_addr0  = (owner_c == OWNER_HOST) ? host_c_addr  :
                          (owner_c == OWNER_NTT)  ? ntt_c_addr0  :
                          (owner_c == OWNER_PMUL) ? pmul_c_addr : {ADDR_W{1'b0}};
    assign ram_c_wdata0 = (owner_c == OWNER_HOST) ? host_c_wdata :
                          (owner_c == OWNER_NTT)  ? ntt_c_wdata0 :
                          (owner_c == OWNER_PMUL) ? pmul_c_wdata: {COEFF_W{1'b0}};
    assign ram_c_req1   = (owner_c == OWNER_NTT) ? ntt_c_req1 : 1'b0;
    assign ram_c_we1    = (owner_c == OWNER_NTT) ? ntt_c_we1  : 1'b0;
    assign ram_c_addr1  = (owner_c == OWNER_NTT) ? ntt_c_addr1: {ADDR_W{1'b0}};
    assign ram_c_wdata1 = (owner_c == OWNER_NTT) ? ntt_c_wdata1:{COEFF_W{1'b0}};

    assign ram_sum_req0   = (owner_sum == OWNER_HOST) ? host_sum_req   :
                            (owner_sum == OWNER_ADD)  ? add_c_req     : 1'b0;
    assign ram_sum_we0    = (owner_sum == OWNER_HOST) ? host_sum_we    :
                            (owner_sum == OWNER_ADD)  ? add_c_we      : 1'b0;
    assign ram_sum_addr0  = (owner_sum == OWNER_HOST) ? host_sum_addr  :
                            (owner_sum == OWNER_ADD)  ? add_c_addr    : {ADDR_W{1'b0}};
    assign ram_sum_wdata0 = (owner_sum == OWNER_HOST) ? host_sum_wdata :
                            (owner_sum == OWNER_ADD)  ? add_c_wdata   : {COEFF_W{1'b0}};
    assign ram_sum_req1   = 1'b0;
    assign ram_sum_we1    = 1'b0;
    assign ram_sum_addr1  = {ADDR_W{1'b0}};
    assign ram_sum_wdata1 = {COEFF_W{1'b0}};

    // ---------------------------------------------------------------------
    // RAM instances
    // ---------------------------------------------------------------------
    sync_ram_dp u_ram_a (
        .clk(clk), .rst(rst),
        .req_a(ram_a_req0), .we_a(ram_a_we0), .addr_a(ram_a_addr0), .wdata_a(ram_a_wdata0), .rdata_a(ram_a_rdata0), .valid_a(ram_a_valid0),
        .req_b(ram_a_req1), .we_b(ram_a_we1), .addr_b(ram_a_addr1), .wdata_b(ram_a_wdata1), .rdata_b(ram_a_rdata1), .valid_b(ram_a_valid1)
    );

    sync_ram_dp u_ram_b (
        .clk(clk), .rst(rst),
        .req_a(ram_b_req0), .we_a(ram_b_we0), .addr_a(ram_b_addr0), .wdata_a(ram_b_wdata0), .rdata_a(ram_b_rdata0), .valid_a(ram_b_valid0),
        .req_b(ram_b_req1), .we_b(ram_b_we1), .addr_b(ram_b_addr1), .wdata_b(ram_b_wdata1), .rdata_b(ram_b_rdata1), .valid_b(ram_b_valid1)
    );

    sync_ram_dp u_ram_c (
        .clk(clk), .rst(rst),
        .req_a(ram_c_req0), .we_a(ram_c_we0), .addr_a(ram_c_addr0), .wdata_a(ram_c_wdata0), .rdata_a(ram_c_rdata0), .valid_a(ram_c_valid0),
        .req_b(ram_c_req1), .we_b(ram_c_we1), .addr_b(ram_c_addr1), .wdata_b(ram_c_wdata1), .rdata_b(ram_c_rdata1), .valid_b(ram_c_valid1)
    );

    sync_ram_dp u_ram_sum (
        .clk(clk), .rst(rst),
        .req_a(ram_sum_req0), .we_a(ram_sum_we0), .addr_a(ram_sum_addr0), .wdata_a(ram_sum_wdata0), .rdata_a(ram_sum_rdata0), .valid_a(ram_sum_valid0),
        .req_b(ram_sum_req1), .we_b(ram_sum_we1), .addr_b(ram_sum_addr1), .wdata_b(ram_sum_wdata1), .rdata_b(ram_sum_rdata1), .valid_b(ram_sum_valid1)
    );

    // ---------------------------------------------------------------------
    // Engine instances
    // ---------------------------------------------------------------------
    ntt_core u_ntt_a (
        .clk(clk), .rst(rst), .start(ntt_a_start), .inverse(ntt_a_inverse), .busy(ntt_a_busy), .done(ntt_a_done),
        .ram0_req(ntt_a_req0), .ram0_we(ntt_a_we0), .ram0_addr(ntt_a_addr0), .ram0_wdata(ntt_a_wdata0), .ram0_rdata(ram_a_rdata0), .ram0_valid(ram_a_valid0),
        .ram1_req(ntt_a_req1), .ram1_we(ntt_a_we1), .ram1_addr(ntt_a_addr1), .ram1_wdata(ntt_a_wdata1), .ram1_rdata(ram_a_rdata1), .ram1_valid(ram_a_valid1)
    );

    ntt_core u_ntt_b (
        .clk(clk), .rst(rst), .start(ntt_b_start), .inverse(ntt_b_inverse), .busy(ntt_b_busy), .done(ntt_b_done),
        .ram0_req(ntt_b_req0), .ram0_we(ntt_b_we0), .ram0_addr(ntt_b_addr0), .ram0_wdata(ntt_b_wdata0), .ram0_rdata(ram_b_rdata0), .ram0_valid(ram_b_valid0),
        .ram1_req(ntt_b_req1), .ram1_we(ntt_b_we1), .ram1_addr(ntt_b_addr1), .ram1_wdata(ntt_b_wdata1), .ram1_rdata(ram_b_rdata1), .ram1_valid(ram_b_valid1)
    );

    ntt_core u_ntt_c (
        .clk(clk), .rst(rst), .start(ntt_c_start), .inverse(ntt_c_inverse), .busy(ntt_c_busy), .done(ntt_c_done),
        .ram0_req(ntt_c_req0), .ram0_we(ntt_c_we0), .ram0_addr(ntt_c_addr0), .ram0_wdata(ntt_c_wdata0), .ram0_rdata(ram_c_rdata0), .ram0_valid(ram_c_valid0),
        .ram1_req(ntt_c_req1), .ram1_we(ntt_c_we1), .ram1_addr(ntt_c_addr1), .ram1_wdata(ntt_c_wdata1), .ram1_rdata(ram_c_rdata1), .ram1_valid(ram_c_valid1)
    );

    poly_add_engine u_poly_add (
        .clk(clk), .rst(rst), .start(add_start), .busy(add_busy), .done(add_done),
        .a_req(add_a_req), .a_we(add_a_we), .a_addr(add_a_addr), .a_wdata(add_a_wdata), .a_rdata(ram_a_rdata0), .a_valid(ram_a_valid0),
        .b_req(add_b_req), .b_we(add_b_we), .b_addr(add_b_addr), .b_wdata(add_b_wdata), .b_rdata(ram_b_rdata0), .b_valid(ram_b_valid0),
        .c_req(add_c_req), .c_we(add_c_we), .c_addr(add_c_addr), .c_wdata(add_c_wdata), .c_rdata(ram_sum_rdata0), .c_valid(ram_sum_valid0)
    );

    pointwise_mul_engine u_pointwise_mul (
        .clk(clk), .rst(rst), .start(pmul_start), .busy(pmul_busy), .done(pmul_done),
        .a_req(pmul_a_req), .a_we(pmul_a_we), .a_addr(pmul_a_addr), .a_wdata(pmul_a_wdata), .a_rdata(ram_a_rdata0), .a_valid(ram_a_valid0),
        .b_req(pmul_b_req), .b_we(pmul_b_we), .b_addr(pmul_b_addr), .b_wdata(pmul_b_wdata), .b_rdata(ram_b_rdata0), .b_valid(ram_b_valid0),
        .c_req(pmul_c_req), .c_we(pmul_c_we), .c_addr(pmul_c_addr), .c_wdata(pmul_c_wdata), .c_rdata(ram_c_rdata0), .c_valid(ram_c_valid0)
    );

    // ---------------------------------------------------------------------
    // Testbench helper tasks
    // ---------------------------------------------------------------------
    task clear_host_controls;
        begin
            host_a_req = 1'b0; host_a_we = 1'b0; host_a_addr = {ADDR_W{1'b0}}; host_a_wdata = {COEFF_W{1'b0}};
            host_b_req = 1'b0; host_b_we = 1'b0; host_b_addr = {ADDR_W{1'b0}}; host_b_wdata = {COEFF_W{1'b0}};
            host_c_req = 1'b0; host_c_we = 1'b0; host_c_addr = {ADDR_W{1'b0}}; host_c_wdata = {COEFF_W{1'b0}};
            host_sum_req = 1'b0; host_sum_we = 1'b0; host_sum_addr = {ADDR_W{1'b0}}; host_sum_wdata = {COEFF_W{1'b0}};
        end
    endtask

    task host_write;
        input integer ram_id;
        input integer addr;
        input [COEFF_W-1:0] data;
        begin
            case (ram_id)
                RAM_A:   owner_a   = OWNER_HOST;
                RAM_B:   owner_b   = OWNER_HOST;
                RAM_C:   owner_c   = OWNER_HOST;
                RAM_SUM: owner_sum = OWNER_HOST;
            endcase

            @(negedge clk);
            case (ram_id)
                RAM_A: begin host_a_req = 1'b1; host_a_we = 1'b1; host_a_addr = addr[ADDR_W-1:0]; host_a_wdata = data; end
                RAM_B: begin host_b_req = 1'b1; host_b_we = 1'b1; host_b_addr = addr[ADDR_W-1:0]; host_b_wdata = data; end
                RAM_C: begin host_c_req = 1'b1; host_c_we = 1'b1; host_c_addr = addr[ADDR_W-1:0]; host_c_wdata = data; end
                RAM_SUM: begin host_sum_req = 1'b1; host_sum_we = 1'b1; host_sum_addr = addr[ADDR_W-1:0]; host_sum_wdata = data; end
            endcase
            @(negedge clk);
            case (ram_id)
                RAM_A: begin host_a_req = 1'b0; host_a_we = 1'b0; end
                RAM_B: begin host_b_req = 1'b0; host_b_we = 1'b0; end
                RAM_C: begin host_c_req = 1'b0; host_c_we = 1'b0; end
                RAM_SUM: begin host_sum_req = 1'b0; host_sum_we = 1'b0; end
            endcase
        end
    endtask

    task host_read;
        input integer ram_id;
        input integer addr;
        output [COEFF_W-1:0] data;
        begin
            case (ram_id)
                RAM_A:   owner_a   = OWNER_HOST;
                RAM_B:   owner_b   = OWNER_HOST;
                RAM_C:   owner_c   = OWNER_HOST;
                RAM_SUM: owner_sum = OWNER_HOST;
            endcase

            @(negedge clk);
            case (ram_id)
                RAM_A: begin host_a_req = 1'b1; host_a_we = 1'b0; host_a_addr = addr[ADDR_W-1:0]; end
                RAM_B: begin host_b_req = 1'b1; host_b_we = 1'b0; host_b_addr = addr[ADDR_W-1:0]; end
                RAM_C: begin host_c_req = 1'b1; host_c_we = 1'b0; host_c_addr = addr[ADDR_W-1:0]; end
                RAM_SUM: begin host_sum_req = 1'b1; host_sum_we = 1'b0; host_sum_addr = addr[ADDR_W-1:0]; end
            endcase
            @(negedge clk);
            case (ram_id)
                RAM_A: begin data = ram_a_rdata0; host_a_req = 1'b0; end
                RAM_B: begin data = ram_b_rdata0; host_b_req = 1'b0; end
                RAM_C: begin data = ram_c_rdata0; host_c_req = 1'b0; end
                RAM_SUM: begin data = ram_sum_rdata0; host_sum_req = 1'b0; end
                default: data = {COEFF_W{1'b0}};
            endcase
        end
    endtask

    task load_inputs;
        begin
            $display("[TB] loading hardwired a/b vectors into RAM");
            owner_a = OWNER_HOST;
            owner_b = OWNER_HOST;
            owner_c = OWNER_HOST;
            owner_sum = OWNER_HOST;
            for (i = 0; i < N; i = i + 1) begin
                host_write(RAM_A, i, a_init[i]);
                host_write(RAM_B, i, b_init[i]);
                host_write(RAM_C, i, {COEFF_W{1'b0}});
                host_write(RAM_SUM, i, {COEFF_W{1'b0}});
            end
        end
    endtask

    task run_poly_add;
        begin
            $display("[TB] polynomial addition: c = a + b mod q");
            owner_a   = OWNER_ADD;
            owner_b   = OWNER_ADD;
            owner_sum = OWNER_ADD;
            @(negedge clk); add_start = 1'b1;
            @(negedge clk); add_start = 1'b0;
            wait (add_done == 1'b1);
            @(negedge clk);
            owner_a   = OWNER_HOST;
            owner_b   = OWNER_HOST;
            owner_sum = OWNER_HOST;
        end
    endtask

    task run_ntt_a;
        input inv;
        begin
            owner_a = OWNER_NTT;
            ntt_a_inverse = inv;
            @(negedge clk); ntt_a_start = 1'b1;
            @(negedge clk); ntt_a_start = 1'b0;
            wait (ntt_a_done == 1'b1);
            @(negedge clk);
            owner_a = OWNER_HOST;
        end
    endtask

    task run_ntt_b;
        input inv;
        begin
            owner_b = OWNER_NTT;
            ntt_b_inverse = inv;
            @(negedge clk); ntt_b_start = 1'b1;
            @(negedge clk); ntt_b_start = 1'b0;
            wait (ntt_b_done == 1'b1);
            @(negedge clk);
            owner_b = OWNER_HOST;
        end
    endtask

    task run_ntt_c;
        input inv;
        begin
            owner_c = OWNER_NTT;
            ntt_c_inverse = inv;
            @(negedge clk); ntt_c_start = 1'b1;
            @(negedge clk); ntt_c_start = 1'b0;
            wait (ntt_c_done == 1'b1);
            @(negedge clk);
            owner_c = OWNER_HOST;
        end
    endtask

    task run_pointwise_mul;
        begin
            $display("[TB] pointwise multiplication in NTT domain");
            owner_a = OWNER_PMUL;
            owner_b = OWNER_PMUL;
            owner_c = OWNER_PMUL;
            @(negedge clk); pmul_start = 1'b1;
            @(negedge clk); pmul_start = 1'b0;
            wait (pmul_done == 1'b1);
            @(negedge clk);
            owner_a = OWNER_HOST;
            owner_b = OWNER_HOST;
            owner_c = OWNER_HOST;
        end
    endtask

    integer errors;
    reg [COEFF_W-1:0] observed;

    task check_sum_ram;
        begin
            $display("[TB] checking polynomial addition result");
            for (i = 0; i < N; i = i + 1) begin
                host_read(RAM_SUM, i, observed);
                if (observed !== exp_add[i]) begin
                    if (errors < 16) begin
                        $display("ERROR add[%0d]: got %0d expected %0d", i, observed, exp_add[i]);
                    end
                    errors = errors + 1;
                end
            end
        end
    endtask

    task check_a_roundtrip;
        begin
            $display("[TB] checking INTT(NTT(a)) roundtrip");
            for (i = 0; i < N; i = i + 1) begin
                host_read(RAM_A, i, observed);
                if (observed !== a_init[i]) begin
                    if (errors < 16) begin
                        $display("ERROR roundtrip[%0d]: got %0d expected %0d", i, observed, a_init[i]);
                    end
                    errors = errors + 1;
                end
            end
        end
    endtask

    task check_mul_ram;
        begin
            $display("[TB] checking polynomial multiplication result");
            for (i = 0; i < N; i = i + 1) begin
                host_read(RAM_C, i, observed);
                if (observed !== exp_mul[i]) begin
                    if (errors < 16) begin
                        $display("ERROR mul[%0d]: got %0d expected %0d", i, observed, exp_mul[i]);
                    end
                    errors = errors + 1;
                end
            end
        end
    endtask

    initial begin
        rst = 1'b1;
        errors = 0;
        owner_a = OWNER_HOST;
        owner_b = OWNER_HOST;
        owner_c = OWNER_HOST;
        owner_sum = OWNER_HOST;
        add_start = 1'b0;
        pmul_start = 1'b0;
        ntt_a_start = 1'b0; ntt_a_inverse = 1'b0;
        ntt_b_start = 1'b0; ntt_b_inverse = 1'b0;
        ntt_c_start = 1'b0; ntt_c_inverse = 1'b0;
        clear_host_controls();

        repeat (8) @(negedge clk);
        rst = 1'b0;
        repeat (2) @(negedge clk);

        $display("[TB] v1 parameters: N=%0d q=%0d coeff_w=%0d", N, `MOD_Q, COEFF_W);

        load_inputs();
        run_poly_add();
        check_sum_ram();

        load_inputs();
        $display("[TB] forward NTT(a)");
        run_ntt_a(1'b0);
        $display("[TB] inverse NTT(a)");
        run_ntt_a(1'b1);
        check_a_roundtrip();

        load_inputs();
        $display("[TB] forward NTT(a)");
        run_ntt_a(1'b0);
        $display("[TB] forward NTT(b)");
        run_ntt_b(1'b0);
        run_pointwise_mul();
        $display("[TB] inverse NTT(product)");
        run_ntt_c(1'b1);
        check_mul_ram();

        if (errors == 0) begin
            $display("PASS: all v1 RAM/handshake NTT tests passed");
        end else begin
            $display("FAIL: %0d mismatches", errors);
        end
        $finish;
    end
endmodule
