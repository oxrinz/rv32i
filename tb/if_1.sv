module alu_tb;
  reg clk;
  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("if_1.vcd");
    $dumpvars(0, dut);
  end

  initial begin
    #31;
    if (dut.alu_inst.rd_data !== 32'd19) begin
      $error("Alu rd_data has wrong value: got %d, expected 19",
             dut.alu_inst.rd_data);
      $fatal(1, "Test failed");
    end

    $finish;
  end
endmodule
