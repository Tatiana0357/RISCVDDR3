module artic(
    input wire sys_clk,
    input wire sys_rst,
    input wire uart_rx,
    
    input wire botaouart, // botão para resetar o processo de carregamento via UART, permitindo reenvio de instruções sem reiniciar a placa
    
    // DDR3 Pins
    inout  [15:0] ddr3_dq,
    inout  [1:0]  ddr3_dqs_n,
    inout  [1:0]  ddr3_dqs_p,
    output [13:0] ddr3_addr,
    output [2:0]  ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_reset_n,
    output [0:0]  ddr3_ck_p,
    output [0:0]  ddr3_ck_n,
    output [0:0]  ddr3_cke,
    output [0:0]  ddr3_cs_n,
    output [1:0]  ddr3_dm,
    output [0:0]  ddr3_odt,
    
    output wire [3:0] led 
    );

    wire ui_clk;
    wire ui_rst;
    wire calib_done; 
    
    wire [31:0] instr_data;
    wire        instr_valid;

    reg [27:0]  axi_awaddr;
    reg         axi_awvalid;
    wire        axi_awready;
    reg [127:0] axi_wdata;
    reg         axi_wvalid;
    wire        axi_wready;
    reg         axi_wlast;
    reg         axi_bready;
    wire        axi_bvalid;
    reg [27:0]  axi_araddr;
    reg         axi_arvalid;
    wire        axi_arready;
    reg         axi_rready;
    wire        axi_rvalid;
    wire [127:0] axi_rdata;
    reg [15:0]  axi_wstrb;

    // Sinais FemtoRV32
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire        mem_rstrb;
    wire        mem_rbusy;
    wire [31:0] mem_rdata;
    wire        mem_wbusy; 
    reg         mem_wbusy_reg;
    assign mem_wbusy = mem_wbusy_reg;

    reg         cpu_running; // indicar que a CPU pode começar a executar as instruções carregadas
    wire [31:0] val_debug; // valor de debug para mostrar no LED
    
    reg sync1_botao;
    reg sync2_botao;
    
    always @(posedge ui_clk) begin //cria um registrador de deslocamento de 2 estágios para "limpar" e sincronizar o sinal do botão com o clock interno ui_clk
        sync1_botao <= botaouart;
        sync2_botao <= sync1_botao;
    end

    recebe_uart_32b #( // receptor UART com largura de palavra de 32 bits
        .UI_CLK_FREQ(81_250_000)
        ) uart_receiver (
        .clk(ui_clk), 
        .rst(ui_rst), 
        .uart_rx(uart_rx),
        .out_word(instr_data), 
        .out_valid(instr_valid)
    );

    system_wrapper system_i ( // instância do bloco de memória DDR3 e interface AXI
        .CLK100MHZ(sys_clk), 
        .ck_rst(sys_rst), 
        .ck_a0(calib_done),
        .ui_clk_0(ui_clk), 
        .ui_clk_sync_rst_0(ui_rst),
        .ddr3_sdram_addr(ddr3_addr), 
        .ddr3_sdram_ba(ddr3_ba),
        .ddr3_sdram_cas_n(ddr3_cas_n), 
        .ddr3_sdram_ck_n(ddr3_ck_n),
        .ddr3_sdram_ck_p(ddr3_ck_p), 
        .ddr3_sdram_cke(ddr3_cke),
        .ddr3_sdram_cs_n(ddr3_cs_n), 
        .ddr3_sdram_dm(ddr3_dm),
        .ddr3_sdram_dq(ddr3_dq), 
        .ddr3_sdram_dqs_n(ddr3_dqs_n),
        .ddr3_sdram_dqs_p(ddr3_dqs_p), 
        .ddr3_sdram_odt(ddr3_odt),
        .ddr3_sdram_ras_n(ddr3_ras_n), 
        .ddr3_sdram_reset_n(ddr3_reset_n),
        .ddr3_sdram_we_n(ddr3_we_n),
        .S_AXI_0_awaddr(axi_awaddr), 
        .S_AXI_0_awvalid(axi_awvalid), 
        .S_AXI_0_awready(axi_awready),
        .S_AXI_0_awburst(2'b01), 
        .S_AXI_0_awsize(3'b100), 
        .S_AXI_0_awlen(8'd0),
        .S_AXI_0_wdata(axi_wdata), 
        .S_AXI_0_wlast(axi_wlast), 
        .S_AXI_0_wvalid(axi_wvalid), 
        .S_AXI_0_wready(axi_wready),
        .S_AXI_0_wstrb(axi_wstrb), 
        .S_AXI_0_bready(axi_bready), 
        .S_AXI_0_bvalid(axi_bvalid),
        .S_AXI_0_araddr(axi_araddr), 
        .S_AXI_0_arvalid(axi_arvalid), 
        .S_AXI_0_arready(axi_arready),
        .S_AXI_0_arsize(3'b100), 
        .S_AXI_0_arlen(8'd0), 
        .S_AXI_0_arburst(2'b01),
        .S_AXI_0_rdata(axi_rdata), 
        .S_AXI_0_rvalid(axi_rvalid), 
        .S_AXI_0_rready(axi_rready)
    );

    localparam IDLE=0, WAIT_CALIB=1, FETCH_UART=2, WR_ADDR=3, WR_DATA=4, WR_RESP=5, CPU_EXEC=6;
    reg [3:0] state;
    reg start_cpu_flag; 
    reg [1:0] word_count; 
    reg [15:0] warmup_timer;
    reg [27:0] current_addr;
    reg [2:0] cpu_state;
    localparam CPU_IDLE=0, CPU_AR_WAIT=1, CPU_WAIT_RDATA=2, CPU_AW_WAIT=3, CPU_W_WAIT=4, CPU_B_WAIT=5;
    reg [31:0] mem_rdata_reg;
    reg        mem_rbusy_reg;
    assign mem_rdata = mem_rdata_reg;
    assign mem_rbusy = mem_rbusy_reg;

    always @(posedge ui_clk) begin
        if (ui_rst | sync2_botao) begin // Reseta
            state <= IDLE;
            word_count <= 2'b00; 
            cpu_state <= CPU_IDLE;
            axi_awvalid <= 0; 
            axi_wvalid <= 0; 
            axi_bready <= 0;
            axi_arvalid <= 0; 
            axi_rready <= 0;
            axi_wstrb <= 16'hFFFF;
            current_addr <= 0; 
            cpu_running <= 0;
            start_cpu_flag <= 0;
            mem_rbusy_reg <= 0;
            mem_wbusy_reg <= 0;
            warmup_timer <= 0;
        end else begin
            case (state)
                IDLE: if (calib_done) begin // Espera calibração do DDR3
                    state <= WAIT_CALIB;
                end
                
                WAIT_CALIB: begin // Timer de "aquecimento" para garantir que o DDR3 esteja estável após a calibração
                    warmup_timer <= warmup_timer + 1;
                    if (warmup_timer == 16'hFFF) begin
                        state <= FETCH_UART;
                    end
                end

                FETCH_UART: begin // Recebe instruções via UART e as armazena em um buffer de 128 bits (4 palavras de 32 bits) antes de escrever na memória
                    if (instr_valid) begin
                        if (instr_data == 32'hFFFFFFFF) begin // Palavra de controle para fim das intruções
                            if (word_count == 2'b00) begin
                                cpu_running <= 1; // Se não houver instruções a serem carregadas, inicia a CPU imediatamente
                                state <= CPU_EXEC;
                            end else begin // Se houver instruções pendentes no buffer, completa a escrita antes de iniciar a CPU
                                start_cpu_flag <= 1;
                                state <= WR_ADDR;
                            end
                        end else begin // Armazena a instrução recebida no buffer de escrita AXI
                            case (word_count)
                                2'd0: axi_wdata[31:0]   <= instr_data;
                                2'd1: axi_wdata[63:32]  <= instr_data;
                                2'd2: axi_wdata[95:64]  <= instr_data;
                                2'd3: axi_wdata[127:96] <= instr_data;
                            endcase
                            word_count <= word_count + 1; // Incrementa o contador de palavras para saber quando o buffer está cheio
                            if (word_count == 2'd3) begin // Quando o buffer estiver cheio, inicia a escrita na memória
                                state <= WR_ADDR;
                            end
                        end
                    end
                end

                WR_ADDR: begin // Escreve o endereço e configura os sinais de controle para iniciar a escrita via AXI
                    axi_awaddr <= current_addr;
                    axi_awvalid <= 1;
                    axi_wstrb <= 16'hFFFF;
                    if (axi_awvalid && axi_awready) begin // Quando o endereço for aceito, limpa o sinal de validade e passa para a fase de escrita
                        axi_awvalid <= 0;
                        state <= WR_DATA;
                    end
                end

                WR_DATA: begin // configurando os sinais de controle adequados
                    axi_wvalid <= 1; 
                    axi_wlast <= 1;
                    if (axi_wvalid && axi_wready) begin
                        axi_wvalid <= 0; 
                        axi_wlast <= 0;
                        axi_bready <= 1;
                        state <= WR_RESP;
                    end
                end

                WR_RESP: if (axi_bvalid && axi_bready) begin 
                    axi_bready <= 0;
                    current_addr <= current_addr + 16; // Incrementa o endereço para a próxima escrita (alinhamento de 16 bytes)
                    word_count <= 2'b00;
                    if (start_cpu_flag) begin // Se o processo de carregamento foi finalizado (indicado pela palavra de controle recebida via UART), inicia a CPU
                        cpu_running <= 1;
                        state <= CPU_EXEC;
                    end else begin
                        state <= FETCH_UART;
                    end
                end

                CPU_EXEC: begin
                    case (cpu_state)
                        CPU_IDLE: begin
                            if (mem_rstrb) begin // Se a CPU solicita uma leitura, configura os sinais de controle para iniciar a leitura via AXI
                                axi_araddr <= {mem_addr[27:4], 4'b0000};
                                axi_arvalid <= 1;
                                mem_rbusy_reg <= 1;
                                cpu_state <= CPU_AR_WAIT;

                            end else if (|mem_wmask) begin
                                axi_awaddr <= {mem_addr[27:4], 4'b0000};
                                axi_awvalid <= 1;
                                mem_wbusy_reg <= 1;
                                axi_wdata <= {4{mem_wdata}}; 

                                case(mem_addr[3:2]) // Configura os bits de strobe de escrita (wstrb) com base no endereço para garantir que os dados sejam escritos na posição correta dentro da palavra de 128 bits
                                    2'b00: axi_wstrb <= {12'h000, mem_wmask};
                                    2'b01: axi_wstrb <= {8'h00, mem_wmask, 4'h0};
                                    2'b10: axi_wstrb <= {4'h0,  mem_wmask, 8'h00};
                                    2'b11: axi_wstrb <= {mem_wmask, 12'h000};
                                endcase
                                cpu_state <= CPU_AW_WAIT;
                            end
                        end

                        CPU_AR_WAIT: begin // Espera a aceitação do endereço de leitura pela interface AXI
                            if (axi_arready) begin
                                axi_arvalid <= 0;
                                axi_rready <= 1;
                                cpu_state <= CPU_WAIT_RDATA;
                            end
                        end

                        CPU_WAIT_RDATA: begin // armazena no registrador de dados de leitura (mem_rdata_reg) com base no endereço para garantir que a CPU receba os dados corretos, e então sinaliza que a leitura está completa
                            if (axi_rvalid) begin
                                axi_rready <= 0;
                                case(mem_addr[3:2])
                                    2'b00: mem_rdata_reg <= axi_rdata[31:0];
                                    2'b01: mem_rdata_reg <= axi_rdata[63:32];
                                    2'b10: mem_rdata_reg <= axi_rdata[95:64];
                                    2'b11: mem_rdata_reg <= axi_rdata[127:96];
                                endcase
                                mem_rbusy_reg <= 0;
                                cpu_state <= CPU_IDLE;
                            end
                        end
                        
                        CPU_AW_WAIT: begin 
                            if (axi_awready) begin
                                axi_awvalid <= 0;
                                axi_wvalid <= 1;
                                axi_wlast <= 1;
                                cpu_state <= CPU_W_WAIT;
                            end
                        end

                        CPU_W_WAIT: begin //
                            if (axi_wready) begin
                                axi_wvalid <= 0;
                                axi_wlast <= 0;
                                axi_bready <= 1;
                                cpu_state <= CPU_B_WAIT;
                            end
                        end

                        CPU_B_WAIT: begin
                            if (axi_bvalid) begin
                                axi_bready <= 0;
                                mem_wbusy_reg <= 0;
                                axi_wstrb <= 16'hFFFF;
                                cpu_state <= CPU_IDLE;
                            end
                        end
                    endcase
                end
            endcase
        end
    end

    FemtoRV32 #( // instância da CPU RISC-V de 32 bits
        .RESET_ADDR(32'h00000000)
    ) cpu_inst (
        .clk        (ui_clk), 
        .reset      (cpu_running & ~ui_rst),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wmask  (mem_wmask),
        .mem_rstrb  (mem_rstrb),
        .mem_wbusy  (mem_wbusy),
        .mem_rbusy  (mem_rbusy),
        .mem_rdata  (mem_rdata),
        .interrupt_request (1'b0),
        .debug_x18_val (val_debug)
    );

    assign led[3] = calib_done; // Indica que a calibração do DDR3 foi concluída e o sistema está pronto para receber instruções via UART
    assign led[2] = (val_debug == 32'd0);
    assign led[1] = (val_debug == 32'd1);
    assign led[0] = (val_debug == 32'd2);

endmodule