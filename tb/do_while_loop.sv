module alu_tb;
  reg clk;
  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("do_while_loop.vcd");
    $dumpvars(0, dut);
  end

  initial begin
    #78;
    if (dut.instr_mem.addr !== 32'd23) begin
      $error("Instruction memory has wrong active address: got %d, expected 23",
             dut.instr_mem.addr);
      $fatal(1, "Test failed");
    end

    $finish;
  end
endmodule
