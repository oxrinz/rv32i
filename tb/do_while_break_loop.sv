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
    #102;
    if (dut.instr_mem.addr !== 32'd34) begin
      $error("Instruction memory has wrong active address: got %d, expected 34",
             dut.instr_mem.addr);
      $fatal(1, "Test failed");
    end

    $finish;
  end
endmodule
