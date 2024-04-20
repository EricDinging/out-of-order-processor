.section .data
.align 4
data:
    .word 0xB0BACAFE

.section .text
.align 4
    lw x1, data
    li x2, 0xCAFEB0BA
    sb x2, data, x3
    lw x1, data
    sh x2, data, x3
    lw x1, data
    sw x2, data, x3
    lw x1, data
    wfi
