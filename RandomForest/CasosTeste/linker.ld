OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
}

SECTIONS
{
    .text : {
        . = ALIGN(4);
        *(.text.init) 
        *(.text.startup)
        *(.text*)    
        *(.rodata*)
        *(.srodata*)
    } > RAM

    .data : {
        . = ALIGN(4);
        *(.data*)
        *(.sdata*)
    } > RAM

    .bss : {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss*)
        *(.sbss*)
        . = ALIGN(4);
        _bss_end = .;
    } > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}