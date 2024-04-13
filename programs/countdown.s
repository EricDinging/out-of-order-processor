.section .data
.align 4
counter:
    .word 3

.section .text
.align 4
begin:
    lw   t0, counter
    beqz t0, end
    addi t0, -1
    sw   t0, counter, t2
    j    begin
end:
    wfi
