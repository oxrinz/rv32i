# RV32I

RISC-V int only with multiply extensions

Full stack from hardware to c compiler implemented in systemverilog and zig.

I aim to expand this project with time, potentially building a small OS on top of the rv32i

--- 

## Instruction progress
### R-Type
- [x] ADD
- [x] SUB
- [x] XOR
- [x] OR
- [x] AND
- [x] SLL
- [x] SRL
- [ ] SRA
- [x] SLT
- [ ] SLTU
- [x] MUL
- [ ] MULH
- [ ] MULSU
- [ ] MULU
- [x] DIV
- [ ] DIVU
- [ ] REM
- [ ] REMU
### I-Type
- [x] ADDI
- [x] XORI
- [ ] ORI
- [ ] ANDI
- [ ] SLLI
- [ ] SRLI
- [ ] SRAI
- [ ] SLTI
- [x] SLTIU
- [ ] LB
- [ ] LH
- [ ] LW
- [ ] LBU
- [ ] LHU
- Env/syscalls won't be implemented (yet???)
### S-Type
- [ ] SB
- [ ] SH
- [ ] SW
### B-Type
- [x] BEQ
- [x] BNE
- [x] BLT
- [x] BGE
- [ ] BLTU
- [ ] BGEU
### Jumps (J and I)
- [ ] JAL
- [ ] JALR
### U-Type
- [x] LUI
- [ ] AUIPC