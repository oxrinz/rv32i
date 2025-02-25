DEBUG=${DEBUG:-0}

cd compiler
zig build
cd ..

DEBUG=$DEBUG ./compiler/zig-out/bin/compiler program.c