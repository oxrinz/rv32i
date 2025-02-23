#!/bin/bash

set -e

DEBUG=${DEBUG:-0}

echo "Building Zig projects..."

echo "Building compiler..."
cd compiler
zig build
cd ..

echo "Building assembler..."
cd assembler
zig build
cd ..

echo "Cleaning previous build artifacts..."
rm -rf build
rm -f *.vcd
rm -f program
mkdir -p build

echo "Compiling and assembling program..."
DEBUG=$DEBUG ./compiler/zig-out/bin/compiler program.c
./assembler/zig-out/bin/assembler program.asm program

iverilog -g2012 -o "build/sim_test" src/*.sv "sim.sv"
vvp "build/sim_test"
gtkwave sim.vcd

echo "Cleaning up build files and waveforms..."
rm -rf build
rm sim.vcd