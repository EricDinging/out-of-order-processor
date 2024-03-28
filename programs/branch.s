    addi x1, x0, 1
    addi x2, x0, 2
    beq x1, x2, tgt
    addi x3, x0, 4
tgt: addi x3, x0, 8
    wfi


