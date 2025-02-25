rm -rf build
rm -f *.vcd
mkdir -p build

iverilog -g2012 -o "build/sim_test" src/*.sv "sim.sv"
vvp "build/sim_test"
gtkwave sim.vcd

rm -rf build
rm sim.vcd