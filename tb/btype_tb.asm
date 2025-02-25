lui     t0 0
addi        t0 t0 0
lui     t1 0
addi         t1 t1 0
beq          t0 t1 label
addi        t0 t0 26
addi        t0 t0 26
label:
    addi t0 t0 1