SECTIONS
{
    . = 0;

    .text : {
        *(.text.boot)
        *(.text)
        *(.text.*)
    }

    .data : {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        *(.rodata)
        *(.rodata.*)
    }

    .bss : {
        *(.bss)
        *(.bss.*)
    }
}
