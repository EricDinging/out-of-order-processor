.section .data
.align 4
data:
    .word 0xB0BACAFE

.section .text
.align 4
    lw x1, data
    wfi
