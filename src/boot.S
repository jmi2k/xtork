.section .text.boot

.global _start
_start:
	li      a0, 100
	li      a1, 10
	div     a2, a0, a1
	li      sp, 0x4000
	call    init
	call    main
	j       .

.global spin_cycles
spin_cycles:
	bltz    a0, 2f
1:
	addi    a0, a0, -2
	bgtz    a0, 1b
2:
	ret

.global read_cycle
read_cycle:
	csrr    a1, cycleh
	csrr    a0, cycle
	csrr    t0, cycleh
	bne     a1, t0, read_cycle
	ret

.global read_time
read_time:
	csrr    a1, timeh
	csrr    a0, time
	csrr    t0, timeh
	bne     a1, t0, read_time
	ret

.global read_instret
read_instret:
	csrr    a1, instreth
	csrr    a0, instret
	csrr    t0, instreth
	bne     a1, t0, read_instret
	ret
