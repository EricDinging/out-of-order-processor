.section .data
.align 4
data:
    .word 0xB0BACAFE

.section .text
.align 4
    li x2, 0xCAFEB0BA
    nop
    sb x2, data, x3
    sb x2, data, x3
    sb x2, data, x3
    sb x2, data, x3
    sb x2, data, x3
    sb x2, data, x3
    sb x2, data, x3
    sb x2, data, x3
    sb x2, data, x3
    lw x2, data
    lw x2, data
    lw x2, data
    lw x2, data
    wfi
