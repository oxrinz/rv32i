lui t1 0
addi t1 t1 3
lui t0 0
addi t0 t0 3
blt t1 t0 end
lui t1 0
addi t1 t1 19
lui t0 0
addi t0 t0 19
bne t1 t0 end
lui t1 0
addi t1 t1 3
lui t0 0
addi t0 t0 4
bge t1 t0 end
lui t1 0
addi t1 t1 2
lui t0 0
addi t0 t0 2
bge t0 t1 end
lui t1 0
addi t1 t1 2
lui t0 0
addi t0 t0 2
bne t0 t1 end
end:
