module alu_tb;
  reg clk;
  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("or_short_circuit_2_tb.vcd");
    $dumpvars(0, dut);
  end

  initial begin
    #40;
    if (dut.instr_mem.addr !== 32'd25) begin
      $error("Instruction memory has wrong active address: got %d, expected 25",
             dut.instr_mem.addr);
      $fatal(1, "Test failed");
    end

    $finish;
  end
endmodule
