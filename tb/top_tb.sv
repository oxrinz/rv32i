module top_tb;

  reg clk;
  wire [31:0] pc_out;
  wire [31:0] instr;

  top dut (.clk(clk));

  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("top_tb.vcd");
    $dumpvars(0, top_tb);

    #15;

    #50;

    $display("Simulation completed successfully");
    $finish;
  end

  always @(posedge clk) begin

  end

  initial begin
    #1;
    assert (dut.rst === 1'b1)
    else $error("Reset not active at start");

    @(posedge clk);
    if (dut.pc_out !== 32'h0) $error("PC not reset to 0");
  end

endmodule
