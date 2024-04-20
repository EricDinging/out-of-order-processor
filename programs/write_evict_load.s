    li x2, 0x08E0    # target addr
    li x5, 0x01E0   # addr with the same block idx
    li x3, 0x000A   # data
    sw x3, 0(x2)    

    li x4, 0xFFFF
    sw x4, 0(x5)    # evict original
    nop
    lw x6, 0(x2)    # load evicted data, should be 0a
    wfi
