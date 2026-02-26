.section .text.init 
.global _start
.global _stack_top

_start:
    la sp, _stack_top

    li t0, 0x6000 
    csrrs x0, mstatus, t0 
    la t0, _bss_start
    la t1, _bss_end
bss_clear:
    beq t0, t1, bss_done
    sw x0, 0(t0)
    addi t0, t0, 4
    j bss_clear
bss_done:
    call main

loop:
    j loop