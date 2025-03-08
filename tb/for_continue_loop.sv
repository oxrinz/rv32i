module alu_tb;
  reg clk;
  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("for_continue_loop.vcd");
    $dumpvars(0, dut);
  end

  initial begin
    #350;
    if (dut.memory_inst.data !== 32'd12) begin
      $error("Memory has wrong active data: got %d, expected 12",
             dut.memory_inst.data);
      $fatal(1, "Test failed");
    end
    if (dut.memory_inst.write !== 1) begin
      $error("Memory has write set to off. Should be set to on",
             dut.memory_inst.data);
      $fatal(1, "Test failed");
    end

    $finish;
  end
endmodule
