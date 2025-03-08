lui t1 0
addi t1 t1 16
lui t0 0
addi t0 t0 0
sw t1 0(t0)
continue_loop_0:
lui t0 0
addi t0 t0 0
lw t0 0(t0)
lui t1 0
addi t1 t1 12
slt t1 t1 t0
beq t1 zero break_loop_0
lui t0 0
addi t0 t0 0
lw t0 0(t0)
lui t1 0
addi t1 t1 2
sub t1 t0 t1
lui t0 0
addi t0 t0 0
sw t1 0(t0)
jal t0 continue_loop_0
break_loop_0:
end:
