# RV32I

RISC-V int only with multiply extension

The full stack from hardware to c compiler implemented in systemverilog and zig.

--- 

### Quick rundown of the project:
- **Assembler**: non universal RISC-V assembler. Works for this architecture only
- **Compiler**: non universal C compiler. Works for this architecture only
- **sh**: Preset files to run the different parts of the stack
- **shared_tests**: Assembly code that is used for testing both the CPU as the source program and the compiler as the expected output
- **src**: CPU source code
- **tb**: SystemVerilog testbenches
- **run.sh**: Takes "program.c" in root directory, compiles it, assembles it, runs the iverilog simulation and opens gtkwave
- **tests.sh**: Runs tests for all modules. Requires all submodules to be imported in order to work

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
- [x] REM
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
- [x] LB
- [x] LH
- [x] LW
- [ ] LBU
- [ ] LHU
- Env/syscalls won't be implemented (yet???)
### S-Type
- [x] SB
- [x] SH
- [x] SW
### B-Type
- [x] BEQ
- [x] BNE
- [x] BLT
- [x] BGE
- [ ] BLTU
- [ ] BGEU
### Jumps (J and I)
- [x] JAL
- [ ] JALR
### U-Type
- [x] LUI
- [ ] AUIPC