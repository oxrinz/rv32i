lui t1 0
addi t1 t1 16
lui t0 0
addi t0 t0 0
sw t1 0(t0)
lui t1 0
addi t1 t1 0
lui t0 0
addi t0 t0 1
sw t1 0(t0)
loop_0_start:
lui t0 0
addi t0 t0 1
lw t0 0(t0)
lui t1 0
addi t1 t1 4
slt t1 t0 t1
beq t1 zero break_loop_0
lui t0 0
addi t0 t0 1
lw t0 0(t0)
lui t1 0
addi t1 t1 2
rem t1 t0 t1
lui t0 0
addi t0 t0 0
sub t1 t0 t1
sltiu t1 t1 1
beq zero t1 if_end_0
lui t0 0
addi t0 t0 0
lw t0 0(t0)
lui t1 0
addi t1 t1 2
add t1 t0 t1
lui t0 0
addi t0 t0 0
sw t1 0(t0)
jal t0 continue_loop_0
if_end_0:
lui t0 0
addi t0 t0 0
lw t0 0(t0)
lui t1 0
addi t1 t1 1
add t1 t0 t1
lui t0 0
addi t0 t0 0
sw t1 0(t0)
continue_loop_0:
lui t0 0
addi t0 t0 1
lw t0 0(t0)
lui t1 0
addi t1 t1 1
add t1 t0 t1
lui t0 0
addi t0 t0 1
sw t1 0(t0)
jal t0 loop_0_start
break_loop_0:
lui t0 0
addi t0 t0 0
lw t0 0(t0)
lui t1 0
addi t1 t1 10
sub t1 t0 t1
lui t0 0
addi t0 t0 0
sw t1 0(t0)
end:
