module alu_tb;
  reg clk;
  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("in_place_operators.vcd");
    $dumpvars(0, dut);
  end

  initial begin
    #44;
    if (dut.memory_inst.data !== 32'd8) begin
      $error("Memory has wrong active data: got %d, expected 8",
             dut.memory_inst.data);
      $fatal(1, "Test failed");
    end

    $finish;
  end
endmodule
