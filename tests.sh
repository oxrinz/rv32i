#!/bin/bash

if [ "${DEBUG}" = "1" ]; then
    IVERILOG_FLAGS="-DDEBUG"
else
    IVERILOG_FLAGS=""
fi

run_sv_tests() {
    echo -e "\n================================\nRunning SystemVerilog testbenches..."
    local sv_status=0
    
    if [ ! -d "tb" ]; then
        echo "✗ No testbench directory found"
        return 1
    fi
    
    for testbench in tb/*.sv; do
        if [ -f "$testbench" ]; then
            local tb_name=$(basename "$testbench" .sv)
            ./assembler/zig-out/bin/assembler "./tb/${tb_name}.asm" program
            
            iverilog -g2012 ${IVERILOG_FLAGS} "$testbench" src/*.sv -o -
            vvp - 2>/dev/null
            local run_status=$?
            
            if [ $run_status -eq 0 ]; then
                echo -e ""
                # echo "✓ ${tb_name} passed"
                [ -f ${tb_name}_dump.vcd ] && rm ${tb_name}_dump.vcd
            else
                echo "✗ ${tb_name} failed with exit code ${run_status}"
                sv_status=1
            fi
            
        fi
    done
    
    if [ $sv_status -eq 0 ]; then
        echo "✓ systemverilog tests passed"
    fi
    
    echo -e "================================"
    
    return $sv_status
}

run_tests() {
    local component=$1
    echo -e "\n================================\nRunning ${component} tests..."
    cd $component
    zig build test
    local test_result=$?
    cd ..
    if [ $test_result -eq 0 ]; then
        echo "✓ ${component} tests passed"
    else
        echo "✗ ${component} tests failed with exit code ${test_result}"
    fi
    
    echo -e "================================"
    
    return $test_result
}

overall_status=0

run_tests "compiler"
compiler_status=$?
overall_status=$((overall_status + compiler_status))

run_tests "assembler"
assembler_status=$?
overall_status=$((overall_status + assembler_status))

run_sv_tests
sv_status=$?
overall_status=$((overall_status + sv_status))


rm -
rm -rf test_results

echo -e "\nTest Summary:"
echo "Compiler tests: $([ $compiler_status -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "Assembler tests: $([ $assembler_status -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "SystemVerilog tests: $([ $sv_status -eq 0 ] && echo "PASSED" || echo "FAILED")"

exit $overall_status