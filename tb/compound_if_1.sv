module alu_tb;
  reg clk;
  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("compound_if_1.vcd");
    $dumpvars(0, dut);
  end

  initial begin
    #68;
    if (dut.memory_inst.data !== 32'd14) begin
      $error("Memory has wrong active data: got %d, expected 14",
             dut.memory_inst.data);
      $fatal(1, "Test failed");
    end

    $finish;
  end
endmodule
