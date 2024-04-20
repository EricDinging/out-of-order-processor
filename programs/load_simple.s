.section .data
.align 4
data:
    .word 0xB0BACAFE

.section .text
.align 4
    lb  x1, data
    lh  x1, data
    lw  x1, data
    lbu x1, data
    lhu x1, data
    wfi
