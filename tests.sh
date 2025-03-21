#!/bin/bash

if [ "${DEBUG}" = "1" ]; then
    IVERILOG_FLAGS="-DDEBUG"
else
    IVERILOG_FLAGS=""
fi

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

rm -rf test_results
rm -rf build
echo -e "\nTest Summary:"
echo "Compiler tests: $([ $compiler_status -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "Assembler tests: $([ $assembler_status -eq 0 ] && echo "PASSED" || echo "FAILED")"
exit $overall_status