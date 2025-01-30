module decoder_tb ();
  reg [31:0] instr;

  wire [3:0] alu_ops;
  wire reg_write;
  wire mem_read;
  wire mem_write;
  wire [1:0] mem_width;
  wire is_branch;
  wire [2:0] branch_type;
  wire is_jump;
  wire is_jalr;
  wire [4:0] rs1;
  wire [4:0] rs2;
  wire rs1_used;
  wire rs2_used;
  wire [4:0] rd;
  wire [31:0] imm;

  decoder dut (
      .instr(instr),
      .alu_ops(alu_ops),
      .reg_write(reg_write),
      .mem_read(mem_read),
      .mem_write(mem_write),
      .mem_width(mem_width),
      .is_branch(is_branch),
      .branch_type(branch_type),
      .is_jump(is_jump),
      .is_jalr(is_jalr),
      .rs1(rs1),
      .rs2(rs2),
      .rs1_used(rs1_used),
      .rs2_used(rs2_used),
      .rd(rd),
      .imm(imm)
  );

  initial begin
    instr = 32'h0;

    #100;


    // RS / RD TEST
    instr = 32'h003100b3;  // ADD x1, x2, x3
    #10;
    $display("\n");
    if (rd !== 5'd1) $display("ERROR: rd != 1 for ADD instruction");
    if (rs1 !== 5'd2) $display("ERROR: rs1 != 2 for ADD instruction");
    if (rs2 !== 5'd3) $display("ERROR: rs2 != 3 for ADD instruction");
    if (alu_ops !== 4'b0000) $display("ERROR: alu_ops != 0 for ADD instruction");
    $display("\n");

    $display("All tests completed");
    $finish;
  end

  // initial begin
  //   $dumpfile("decoder_tb.vcd");
  //   $dumpvars(0, decoder_tb);
  // end

endmodule
