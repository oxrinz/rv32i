lui t0 0
addi t0 t0 5
lui t1 0
addi t1 t1 1
add t1 t0 t1
lui t0 0
addi t0 t0 0
sw t1 0(t0)
lui t0 0
addi t0 t0 1
lui t1 0
addi t1 t1 2
mul t1 t0 t1
lui t0 0
addi t0 t0 0
lw t0 0(t0)
sub t1 t0 t1
lui t0 0
addi t0 t0 1
sw t1 0(t0)
lui t0 0
addi t0 t0 1
lw t0 0(t0)
lui t1 0
addi t1 t1 1
add t1 t0 t1
