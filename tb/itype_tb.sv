module alu_tb;
  reg clk;
  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("itype_tb_dump.vcd");
    $dumpvars(0, dut);
  end

  initial begin
    // SLTIU
    #6; 
    if (dut.regfile_inst.registers[10] !== 32'd0) begin
      $error("a0 has wrong final value: got %d, expected 0", dut.regfile_inst.registers[10]);
      $fatal(1, "Test failed");
    end

    #6;  
    if (dut.regfile_inst.registers[10] !== 32'd1) begin
      $error("a0 has wrong final value: got %d, expected 1", dut.regfile_inst.registers[10]);
      $fatal(1, "Test failed");
    end

    $finish;
  end
endmodule
