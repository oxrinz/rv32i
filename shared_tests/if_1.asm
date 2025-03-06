lui t1 0
addi t1 t1 0
lui t0 0
addi t0 t0 0
sw t1 0(t0)
lui t0 0
addi t0 t0 0
lw t0 0(t0)
lui t1 0
addi t1 t1 0
sub t1 t0 t1
sltiu t1 t1 1
xori t1 t1 1
beq zero t1 if_end_0
lui t1 0
addi t1 t1 2
lui t0 0
addi t0 t0 0
sw t1 0(t0)
jal t0 else_end_0
if_end_0:
lui t0 0
addi t0 t0 19
lui t0 0
addi t0 t0 0
sw t1 0(t0)
else_end_0:
end:
