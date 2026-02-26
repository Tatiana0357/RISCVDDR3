# Casos de Teste - Random Forest no RISC-V

Esta pasta contém os arquivos essenciais de suporte à compilação *bare-metal* (sem sistema operacional) para a arquitetura RISC-V (`rv32imafc`), bem como o binário final gerado para testes do modelo de Machine Learning.

## 📂 Arquivos da Pasta

* **`start.S`**: Código Assembly de inicialização (Boot code/Startup). É responsável por configurar o hardware básico antes do código em C++ rodar (como inicializar o ponteiro de pilha `sp`, limpar a seção BSS e saltar para a função `main`).
* **`linker.ld`**: Script do Linker. Define o mapa de memória da FPGA, informando ao compilador exatamente em quais endereços de memória as seções de código (`.text`), dados (`.data`, `.rodata`) e variáveis não inicializadas (`.bss`) devem ser alocadas.
* **`main2.hex`**: Código de máquina já compilado e formatado em palavras de 32 bits, pronto para ser enviado via UART para a FPGA. 

---

## 🛠️ Fluxo de Compilação

Caso você altere o código fonte (`main.cpp` ou `model.h`) e precise gerar um novo `.hex`, utilize os comandos abaixo. 

> **Nota:** Certifique-se de que os arquivos de código fonte (`main.cpp` e afins) estejam no mesmo diretório ou aponte os caminhos corretos na hora de rodar o compilador. É necessário ter a toolchain `riscv64-unknown-elf` instalada.

**1. Gerar o arquivo executável (.elf):**
Aqui unimos o código de inicialização (`start.S`) e o código principal (`main.cpp`), seguindo as regras de memória do `linker.ld`.
```bash
riscv64-unknown-elf-g++ -march=rv32imafc -mabi=ilp32f -O0 -nostdlib -fno-exceptions -fno-rtti -T linker.ld -o firmware.elf start.S main.cpp -lgcc

2. Gerar o arquivo Hex em formato Verilog (Opcional):

Bash
riscv64-unknown-elf-objcopy -O verilog firmware.elf firmware.hex

3. Gerar o dump do Assembly para análise (Opcional):
Muito útil para depurar e verificar se as instruções geradas fazem sentido.

Bash
riscv64-unknown-elf-objdump -d firmware.elf > codigo_assembly.txt

4. Extrair o binário cru (.bin):

Bash
riscv64-unknown-elf-objcopy -O binary firmware.elf main.bin

5. Formatar o binário para .hex de 32 bits:
Esse é o passo final que gera o arquivo consumido pelo script Python de envio serial.

Bash
hexdump -v -e '1/4 "%08X\n"' main.bin > main.hex