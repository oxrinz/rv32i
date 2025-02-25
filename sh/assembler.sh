rm -f program

cd assembler
zig build
cd ..

./assembler/zig-out/bin/assembler program.asm program