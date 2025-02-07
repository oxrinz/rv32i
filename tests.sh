#!/bin/bash

rm -rf build
rm -f *.vcd
rm -f program
mkdir -p build





./compiler/zig-out/bin/compiler program.c
./assembler/zig-out/bin/assembler program.asm program





for tb_file in tb/*_tb.sv; do
    tb_name=$(basename "$tb_file" _tb.sv)
    src_file="src/${tb_name}.sv"
    
    if [ -f "$src_file" ]; then
        echo "Running tests for $tb_name..."
        iverilog -g2012 -o "build/${tb_name}_test" src/*.sv "$tb_file"
        if [ $? -eq 0 ]; then
            vvp "build/${tb_name}_test"
        else
            echo "Compilation failed for $tb_name"
        fi
    else
        echo "Warning: Source file $src_file not found for testbench $tb_file"
    fi
done

gtkwave top_tb.vcd

echo "Cleaning up build files and waveforms..."
rm -rf build
echo "All tests completed and files cleaned up"