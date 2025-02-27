module sim;

  reg clk;
  wire [31:0] pc_out;
  wire [31:0] instr;

  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("sim.vcd");
    $dumpvars(0, sim);

    #60;

    $display("Simulation completed successfully");
    $finish;
  end

endmodule
