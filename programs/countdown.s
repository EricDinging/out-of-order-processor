.section .data
.align 4
counter:
    .word 3

.section .text
.align 4
.L0:
    lw   t0, counter
    beqz t0, .L1
    addi t0, t0, -1
    sw   t0, counter, t2
    j    .L0
.L1:
    wfi
