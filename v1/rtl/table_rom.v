`include "he_params.vh"

module table_rom #(
    parameter DATA_W    = `COEFF_W,
    parameter ADDR_W    = `ADDR_W,
    parameter DEPTH     = `NTT_N,
    parameter INIT_FILE = ""
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              req,
    input  wire [ADDR_W-1:0] addr,
    output reg  [DATA_W-1:0] rdata,
    output reg               valid
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
            valid <= 1'b0;
            rdata <= {DATA_W{1'b0}};
        end else begin
            valid <= req;
            if (req) begin
                rdata <= mem[addr];
            end
        end
    end
endmodule
