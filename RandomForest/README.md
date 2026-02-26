# Random Forest no RISC-V (FPGA) via UART

Este diretório contém os arquivos para execução de um modelo de Machine Learning (Random Forest) em um processador baseado na arquitetura RISC-V em uma FPGA. 

O projeto realiza a inferência de 3 amostras do clássico dataset Iris (Setosa, Virginica e Versicolor). O resultado da classificação é mapeado diretamente para o registrador `x18`, que pode ser utilizado para acender LEDs na placa de desenvolvimento.

## 📂 Arquivos do Projeto

* **`main.cpp`**: Código principal em C++ que instancia o modelo, roda as inferências em um loop contínuo e joga o resultado no registrador `x18` (LEDs). Possui delays em Assembly para permitir a visualização física na FPGA.
* **`model.h`**: Modelo Random Forest puro em C++ contendo as árvores de decisão. Foi gerado utilizando as ferramentas da biblioteca [ArduinoMicroML (TronixLab)](https://github.com/TronixLab/ArduinoMicroML).
* **`main2.hex`**: Código compilado (instruções de máquina) a partir do `main.cpp` e `model.h`. É este arquivo que o processador RISC-V vai de fato entender e executar.
* **`teste.py`**: Script em Python responsável por ler o arquivo `.hex` e enviar as instruções, linha por linha, via comunicação Serial (UART) para a FPGA. O envio termina com uma palavra de controle `0xFFFFFFFF`.

## 🚀 Como Executar

### Pré-requisitos

Para rodar o script de envio, você precisará ter o Python instalado na sua máquina, além da biblioteca `pyserial`. Caso não tenha a biblioteca, instale com:

> pip install pyserial

### Passo a Passo

1. Conecte sua placa/FPGA ao computador via USB/Serial.
2. Verifique se a porta configurada no arquivo `teste.py` está correta. Por padrão, está definida como `COM3` e o baud rate em `115200`. Altere a variável `PORT` dentro do script caso a sua placa esteja em outra porta (ex: `COM4`, ou `/dev/ttyUSB0` no Linux).
3. Execute o script passando o arquivo `.hex` como argumento:

> python teste.py main2.hex

4. Aguarde a mensagem `"Envio concluído."`. Os LEDs da sua placa devem começar a piscar indicando as classes do dataset Iris (0, 1 e 2).
Obs: Com esse main2.hex, ele ira piscar nas ordem (2,0,1).