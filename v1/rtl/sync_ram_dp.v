`include "he_params.vh"

module sync_ram_dp #(
    parameter DATA_W    = `COEFF_W,
    parameter ADDR_W    = `ADDR_W,
    parameter DEPTH     = `NTT_N,
    parameter INIT_FILE = ""
)(
    input  wire              clk,
    input  wire              rst,

    input  wire              req_a,
    input  wire              we_a,
    input  wire [ADDR_W-1:0] addr_a,
    input  wire [DATA_W-1:0] wdata_a,
    output reg  [DATA_W-1:0] rdata_a,
    output reg               valid_a,

    input  wire              req_b,
    input  wire              we_b,
    input  wire [ADDR_W-1:0] addr_b,
    input  wire [DATA_W-1:0] wdata_b,
    output reg  [DATA_W-1:0] rdata_b,
    output reg               valid_b
);
    reg [DATA_W-1:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_W{1'b0}};
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            valid_a <= 1'b0;
            valid_b <= 1'b0;
            rdata_a <= {DATA_W{1'b0}};
            rdata_b <= {DATA_W{1'b0}};
        end else begin
            valid_a <= req_a;
            valid_b <= req_b;

            if (req_a) begin
                if (we_a) begin
                    mem[addr_a] <= wdata_a;
                    rdata_a <= wdata_a;
                end else begin
                    rdata_a <= mem[addr_a];
                end
            end

            if (req_b) begin
                if (we_b) begin
                    mem[addr_b] <= wdata_b;
                    rdata_b <= wdata_b;
                end else begin
                    rdata_b <= mem[addr_b];
                end
            end
        end
    end
endmodule
