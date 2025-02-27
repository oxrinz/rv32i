lui t1 0
addi t1 t1 2
lui t0 0
addi t0 t0 2
bne t0 t1 end
lui t1 0
addi t1 t1 1
lui t0 0
addi t0 t0 2
bge t0 t1 end
lui t1 0
addi t1 t1 3
lui t0 0
addi t0 t0 5
blt t0 t1 end
end:
