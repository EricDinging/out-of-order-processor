.section .data
.align 4
stack:
    .word 0

.section .text
.align 4
main:
    la   sp, stack
    mv   fp, sp
    li   a0, 60
    li   a1, 24
    call gcd
    mv   t0, a0
    wfi

mod:
    blt  a0, a1, .L0
    sub  a0, a0, a1
    tail mod
.L0:
    li   a1, 0
    ret

gcd:
    beqz a1, .L1
    sw   ra, 0x00(sp)
    sw   fp, 0x08(sp)
    sw   a0, 0x10(sp)
    sw   a1, 0x18(sp)
    mv   fp, sp
    addi sp, sp, 0x20
    call mod
    mv   t0, a0
    mv   sp, fp
    lw   ra, 0x00(sp)
    lw   fp, 0x08(sp)
    lw   a0, 0x10(sp)
    lw   a1, 0x18(sp)
    mv   a0, a1
    mv   a1, t0
    tail gcd
.L1
    ret
