    li x1, 1
    li x2, 1024
start:
    addi x1,  x1,  1
    addi x3,  x1,  1
    addi x4,  x3,  1
    addi x5,  x4,  1
    addi x6,  x5,  1
    addi x7,  x6,  1
    addi x8,  x7,  1
    addi x9,  x8,  1
    addi x10, x9,  1
    addi x11, x10, 1
    addi x12, x11, 1
    addi x13, x12, 1
    addi x14, x13, 1
    addi x15, x14, 1
    addi x3,  x15, 1
    addi x4,  x3,  1
    addi x5,  x4,  1
    addi x6,  x5,  1
    addi x7,  x6,  1
    addi x8,  x7,  1
    addi x9,  x8,  1
    addi x10, x9,  1
    addi x11, x10, 1
    addi x12, x11, 1
    addi x13, x12, 1
    addi x14, x13, 1
    addi x15, x14, 1
    bne  x1,  x2,  start
    wfi
