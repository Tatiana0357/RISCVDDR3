module uart_rx #(
    parameter CLK_FREQ = 100000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rx,
    output reg [7:0]  data,
    output reg        valid
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    reg [1:0]  state = 0;
    reg [15:0] clk_count = 0;
    reg [2:0]  bit_index = 0;
    reg        rx_sync, rx_reg;

    always @(posedge clk) begin
        rx_reg <= rx;
        rx_sync <= rx_reg;
    end

    always @(posedge clk) begin
        valid <= 0;
        case (state)
            2'b00: begin
                clk_count <= 0;
                bit_index <= 0;
                if (rx_sync == 0) state <= 2'b01;
            end
            2'b01: begin
                if (clk_count == (CLKS_PER_BIT / 2)) begin
                    if (rx_sync == 0) begin
                        clk_count <= 0;
                        state <= 2'b10;
                    end else begin
                        state <= 2'b00;
                    end
                end else clk_count <= clk_count + 1;
            end 
            2'b10: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    data[bit_index] <= rx_sync;
                    if (bit_index == 7) state <= 2'b11;
                    else bit_index <= bit_index + 1;
                end else clk_count <= clk_count + 1;
            end
            2'b11: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    if (rx_sync == 1'b1) begin
                        valid <= 1;
                    end
                    state <= 2'b00;
                    bit_index <= 0;
                end else clk_count <= clk_count + 1;
            end 
        endcase
    end
endmodule