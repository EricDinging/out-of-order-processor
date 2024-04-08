    li x1, 1
    li x2, 10
start:
    addi x1, x1, 1
    bne x1, x2, start
    wfi
