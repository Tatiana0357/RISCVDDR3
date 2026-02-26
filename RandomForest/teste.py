import serial
import struct
import sys
import time

PORT = "COM3"
BAUD = 115200
END_F = 0xFFFFFFFF

if len(sys.argv) < 2:
    print("Uso: python send.py <arquivo.hex>")
    sys.exit(1)

with serial.Serial(PORT, BAUD, timeout=1) as ser:
    time.sleep(1)  # pequeno tempo pro FPGA acordar
    
    with open(sys.argv[1], "r") as f:
        for line in f:
            line = line.strip()
            if line:
                instr = int(line, 16)
                ser.write(struct.pack("<I", instr))

    # Envia palavra do final
    ser.write(struct.pack("<I", END_F))

print("Envio concluído.")