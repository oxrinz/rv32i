#!/bin/bash

# Function to run SystemVerilog testbenches
run_sv_tests() {
    echo "Running SystemVerilog testbenches..."
    local sv_status=0
    
    # Check if tb directory exists
    if [ ! -d "tb" ]; then
        echo "✗ No testbench directory found"
        return 1
    fi
    
    # Find and run all testbenches
    for testbench in tb/*.sv; do
        if [ -f "$testbench" ]; then
            local tb_name=$(basename "$testbench" .sv)
            echo "Running testbench: ${tb_name}"

            echo "${tb_name}.asm"
            
            ./assembler/zig-out/bin/assembler "./tb/${tb_name}.asm" program

            # Compile and run testbench directly
            iverilog -g2012 "$testbench" src/*.sv -o -
            vvp -
            local run_status=$?
            
            if [ $run_status -eq 0 ]; then
                echo "✓ ${tb_name} passed"
            else
                echo "✗ ${tb_name} failed with exit code ${run_status}"
                sv_status=1
            fi
        fi
    done
    return $sv_status
}

# Function to run component tests
run_tests() {
    local component=$1
    echo "Running ${component} tests..."
    cd $component
    zig build test
    local test_result=$?
    cd ..
    if [ $test_result -eq 0 ]; then
        echo "✓ ${component} tests passed"
    else
        echo "✗ ${component} tests failed with exit code ${test_result}"
    fi
    return $test_result
}

# Run all tests
overall_status=0


# Run component tests
run_tests "compiler"
compiler_status=$?
overall_status=$((overall_status + compiler_status))

run_tests "assembler"
assembler_status=$?
overall_status=$((overall_status + assembler_status))

# Run SystemVerilog testbenches
run_sv_tests
sv_status=$?
overall_status=$((overall_status + sv_status))

rm -
rm -rf test_results

# Print summary
echo -e "\nTest Summary:"
echo "SystemVerilog tests: $([ $sv_status -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "Compiler tests: $([ $compiler_status -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "Assembler tests: $([ $assembler_status -eq 0 ] && echo "PASSED" || echo "FAILED")"

exit $overall_status