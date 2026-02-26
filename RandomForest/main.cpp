#include "model.h"

float dataset[3][4] = {
    {6.0f, 2.9f, 4.5f, 1.5f}, // Esperado: 2 (Versicolor)
    {5.1f, 3.5f, 1.4f, 0.2f}, // Esperado: 0 (Setosa)
    {6.9f, 3.1f, 5.4f, 2.1f}  // Esperado: 1 (Virginica)
};

void delay_gigante() {
    // Delay para conseguir ver o LED aceso
    for (volatile int i = 0; i < 1000; i++) {
        for (volatile int j = 0; j < 1000; j++) {
            asm volatile("nop");
        }
    }
}

int main() {
    Eloquent::ML::Port::RandomForest rf;
    
    while (1) {
        // O loop continua simples: 2, 0, 1.
        for (int i = 0; i < 3; i++) {
            int classe = rf.predict(dataset[i]);

            #ifdef __riscv
            // 1. Mostra o resultado (Joga o valor no registrador x18 -> LEDs)
            asm volatile ("addi x18, %0, 0" :: "r"(classe) : "x18");

            // 2. Espera um tempo com o LED aceso
            delay_gigante();
            asm volatile ("addi x18, x0, 0" ::: "x18"); 
            for (volatile int k=0; k<200000; k++); 
            #endif
        }
    }
    return 0;
}