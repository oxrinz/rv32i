module alu_tb;

  reg clk;

  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

    initial begin
        #60;
        $display("Simulation completed successfully");
        $finish;
    end

endmodule
