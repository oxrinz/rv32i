module alu_tb;
  reg clk;
  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("variables_1.vcd");
    $dumpvars(0, dut);
  end

  initial begin
    #50;
    if (dut.alu_inst.rd_data !== 32'd5) begin
      $error("Alu rd_data has wrong value: got %d, expected 5",
             dut.alu_inst.rd_data);
      $fatal(1, "Test failed");
    end

    $finish;
  end
endmodule
