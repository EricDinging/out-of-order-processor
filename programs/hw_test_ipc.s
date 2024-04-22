/* 
    a. If your X-way superscalar processor met the goal of getting an IPC greater than X-1.
        Calculate the inverse of the CPI from executing this program. If the result is greater 
        than X-1, we can claim that the processor met the goal.
    b. If your processor met the goal of executing back-to-back dependent instructions 
    without a stall between them.
        We will first measure the number of clock period required to warm up the cache (cache_warm_up) 
        by executing the first iteration of the for loop. Then measure the number of clock period
        required to warm up the out-of-order system from squash (ooo_warm_up). If the total period is less
        or equal to cache_warm_up + (15 - 1) * (8 / N + ooo_warm_up) + 1, we can say that the processor 
        meets the goal. 
*/
    li  x1, 0x0
    li  x2, 0x10
loop:
    add x3, x1, x1
    add x4, x1, x1
    add x4, x1, x1
    add x5, x4, x1
    add x6, x4, x5
    add x4, x6, x5
    addi    x1, x1, 0x1
    bne x1,	x2,	loop
    wfi