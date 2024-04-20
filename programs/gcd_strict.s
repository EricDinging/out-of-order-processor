.section .text
.align 4
main:
    li   sp, 0x2000
    mv   fp, sp
    li   a0, 60
    li   a1, 24
    call gcd
    mv   t0, a0
    wfi

mod:
    addi fp, sp, 0x10
    sw   ra, 0x00(fp)
    sw   sp, 0x04(fp)
    sw   a0, 0x08(fp)
    sw   a1, 0x0c(fp)
    blt  a0, a1, .L0
    sub  a0, a0, a1
    call mod
    mv   t0, a0
    mv   fp, sp
    lw   ra, 0x00(fp)
    lw   sp, 0x04(fp)
    lw   a0, 0x08(fp)
    lw   a1, 0x0c(fp)
    mv   a0, t0
.L0:
    ret

gcd:
    beqz a1, .L1
    addi fp, sp, 0x10
    sw   ra, 0x00(fp)
    sw   sp, 0x04(fp)
    sw   a0, 0x08(fp)
    sw   a1, 0x0c(fp)
    mv   sp, fp
    call mod
    mv   t0, a0
    mv   fp, sp
    lw   ra, 0x00(fp)
    lw   sp, 0x04(fp)
    lw   a0, 0x08(fp)
    lw   a1, 0x0c(fp)
    mv   a0, a1
    mv   a1, t0
    call gcd
    mv   t0, a0
    mv   fp, sp
    lw   ra, 0x00(fp)
    lw   sp, 0x04(fp)
    lw   a0, 0x08(fp)
    lw   a1, 0x0c(fp)
    mv   a0, t0
.L1:
    ret
