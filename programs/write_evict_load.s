    add x2, x0, x0
    addi x2, x0, 0x07E0    # target addr
    li x5, 0x01E0   # addr with the same block idx
    li x3, 0x000A   # data
    sw x3, 0(x2)    

    li x4, 0xFFFF
    sw x4, 0(x5)    # evict original

    lw x6, 0x7E0(x0)    # load evicted data, should be 0a
    wfi