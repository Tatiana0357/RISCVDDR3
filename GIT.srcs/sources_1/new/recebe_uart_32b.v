module recebe_uart_32b #(
    parameter UI_CLK_FREQ = 81_250_000
)(
    input  wire        clk,      
    input  wire        rst,      
    input  wire        uart_rx,  
    output reg  [31:0] out_word, 
    output reg         out_valid 
);

    wire [7:0] rx_data;
    wire       rx_ready;

    uart_rx #( // recebe um byte de dados
        .CLK_FREQ(UI_CLK_FREQ), 
        .BAUD_RATE(115200)
    ) uart_rx_inst (
        .clk   (clk),
        .rx    (uart_rx),
        .data  (rx_data),
        .valid (rx_ready)
    );

    reg [1:0]  byte_cnt;
    reg [31:0] word_buf;

    always @(posedge clk) begin
        if (rst) begin // reset dos registradores
            byte_cnt  <= 2'd0;
            word_buf  <= 32'd0;
            out_word  <= 32'd0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= 1'b0; 
            if (rx_ready) begin 
                case (byte_cnt) // armazena os bytes recebidos em um buffer e forma a palavra de 32 bits
                    2'd0: begin
                        word_buf[7:0] <= rx_data;
                        byte_cnt <= 2'd1;
                    end
                    2'd1: begin
                        word_buf[15:8] <= rx_data;
                        byte_cnt <= 2'd2;
                    end
                    2'd2: begin
                        word_buf[23:16] <= rx_data;
                        byte_cnt <= 2'd3;
                    end
                    2'd3: begin
                        out_word  <= {rx_data, word_buf[23:0]}; 
                        out_valid <= 1'b1; 
                        byte_cnt  <= 2'd0; 
                    end
                endcase
            end
        end
    end
endmodule