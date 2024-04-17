    li x1, 0x1000
    li x5, 0xB0BACAFE
    sw x5, 0(x1)
    li x1, 0x1200
    li x5, 0xCAFEB0BA
    sw x5, 0(x1)
    li x1, 0x1000
    lw x5, 0(x1)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    wfi
