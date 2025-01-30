#!/bin/bash

rm -rf build
rm -f *.vcd
mkdir -p build

for tb_file in tb/*_tb.sv; do
    tb_name=$(basename "$tb_file" _tb.sv)
    src_file="src/${tb_name}.sv"
    
    if [ -f "$src_file" ]; then
        echo "Running tests for $tb_name..."
        # Compile all source files together
        iverilog -g2012 -o "build/${tb_name}_test" src/*.sv "$tb_file"
        if [ $? -eq 0 ]; then
            vvp "build/${tb_name}_test"
        else
            echo "Compilation failed for $tb_name"
        fi
        echo "----------------------------------------"
    else
        echo "Warning: Source file $src_file not found for testbench $tb_file"
    fi
done

echo "Cleaning up build files and waveforms..."
rm -rf build
rm -f *.vcd
echo "All tests completed and files cleaned up"