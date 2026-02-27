# SoC RISC-V em FPGA (Arty A7) com TinyML e DDR3

## O Propósito do Projeto

Este projeto foi criado para um processador **RISC-V (bare-metal)** dentro de uma FPGA **Artix-7 (Placa Arty A7)** e o configuramos para utilizar a memória externa **DDR3** da placa.

Para provar que a arquitetura funciona e aguenta processamento real, implementamos um caso de uso de **Machine Learning (TinyML)**. O código de teste que roda no processador é uma **Random Forest** treinada para classificar espécies de flores (o clássico dataset *Iris*, que identifica se a flor é *Setosa, Versicolor ou Virginica*). Você encontra os detalhes específicos desse modelo na pasta `RandomFlorest/`.

Os codigos são compilado no computador e as instruções geradas são enviadas via cabo serial (UART) diretamente para a memória da FPGA. O RISC-V então lê essas instruções da DDR3, executa a classificação das flores e acende os LEDs da placa indicando o resultado!

---

## Estrutura do Repositório


O projeto está dividido entre a descrição de hardware e os softwares e testes (pastas auxiliares).

### Hardware (Arquivos Verilog)

Localizados na pasta GIT.srcs/sources_1/new/, estes são os arquivos HDL que descrevem o circuito a ser sintetizado na FPGA através do Xilinx Vivado:

* **`artic.v`**: Módulo *Top-Level* (nível superior) do projeto. Ele junta todas as peças: o processador, a comunicação serial e as interfaces de memória (como o controlador MIG da DDR3), ligando os sinais lógicos aos pinos físicos da placa Arty A7.
* **`femtorv32_petitbateau.v`**: O coração do processador. Uma implementação do núcleo RISC-V altamente otimizada para economia de recursos lógicos em FPGAs.
* **`petitbateau.v`**: Um módulo *wrapper* (SoC) que encapsula o núcleo do processador e gerencia suas conexões internas com barramentos de memória e dados.
* **`uart_rx.v`**: Módulo base de recepção serial. Responsável por ler a linha RX física e extrair os bytes (8 bits) enviados pelo computador, lidando com os tempos e baud rate da comunicação.
* **`recebe_uart_32b.v`**: Módulo customizado de agrupamento. Ele recebe os bytes capturados pelo `uart_rx.v` e os empacota em palavras de 32 bits, que é o formato necessário para alimentar as instruções na memória do RISC-V.

### Diretórios Auxiliares
* **`RandomFlorest/`**: Contém o código C++ com as árvores de decisão do modelo e o script em Python (`teste.py`) responsável por transmitir o executável via porta serial.
* **``RandomFlorest/CasosTeste/`**: Armazena os scripts de linker (`linker.ld`), código de boot (`start.S`) e os arquivos binários `.hex` gerados durante a compilação do C++.
* **`MIG/`**: Onde mostra as configurações do MIG.
* **`MIG/Figuras/`**: Imagens de suporte e documentação visual (ex: parâmetros de configuração do Memory Interface Generator - MIG).

---

## Como a Mágica Acontece (Fluxo de Execução)

O projeto une hardware e software seguindo este fluxo:

1. **Síntese:** O hardware descrito nos arquivos `.v` é sintetizado junto com o IP do controlador de memória DDR3 no Vivado e embarcado na placa Arty A7.
2. **Compilação:** O modelo em C++ é compilado utilizando a toolchain `riscv64-unknown-elf`, gerando um executável (`.hex`).
3. **Carga Dinâmica:** O script Python abre a conexão UART e injeta o `.hex` linha por linha. O módulo `recebe_uart_32b.v` decodifica esses dados e os despeja na memória da FPGA.
4. **Execução e Resultado:** Ao receber a palavra-chave de encerramento (`0xFFFFFFFF`), o RISC-V sai do estado de espera e inicia o processamento do dataset Iris. O resultado da inferência é jogado diretamente no registrador `x18`, acendendo os LEDs físicos da placa indicando a classe da flor identificada.

---

## Tecnologias Utilizadas
* **Placa:** Digilent Arty A7 (Xilinx Artix-7 `xc7a35ti-csg324-1L`)
* **Processador:** RISC-V rv32imafc (FemtoRV32)
* **Software:** Xilinx Vivado (Síntese e IP MIG DDR3), Toolchain GCC RISC-V.
* **Linguagens:** Verilog, C/C++, Python e Assembly RISC-V.

## Resultados e Demonstração

No vídeo abaixo, você pode ver o momento exato em que enviamos os dados via UART. Assim que a placa recebe a palavra de encerramento, o RISC-V processa a Random Forest e os LEDs acendem, classificando corretamente a espécie da flor baseada no dataset Iris. Sendo o led4 para 2, led5 para 1, led6 para 0.

https://github.com/user-attachments/assets/c8df1279-f3c3-42a0-9b6a-eefdfcdfaff1

---

## Créditos e Licenças

Este projeto utiliza implementações de código aberto de terceiros. Agradecimentos especiais aos seguintes projetos:

* **FemtoRV32:** O núcleo do processador RISC-V (`femtorv32_petitbateau.v` e `petitbateau.v`) foi desenvolvido por **Bruno Levy** e obtido através do repositório [learn-fpga/FemtoRV](https://github.com/BrunoLevy/learn-fpga). Este código é distribuído sob a licença **BSD 3-Clause**. A reprodução, modificação e uso estão autorizados desde que mantidos os avisos de direitos autorais originais (Copyright (c) 2020-2021, Bruno Levy). O software original é fornecido "como está", sem garantias expressas ou implícitas.
