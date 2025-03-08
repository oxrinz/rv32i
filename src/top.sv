module top (
    input wire clk
);

  // instr fetch signals
  wire [31:0] instr;
  wire pc_enable;
  wire pc_load;
  wire [31:0] load_addr;
  wire [31:0] pc_out;

  // control signals from decoder
  wire [3:0] alu_ops;
  wire reg_write;
  wire mem_read;
  wire mem_write;
  wire [31:0] mem_addr;
  wire [31:0] mem_out;
  wire [1:0] mem_width;
  wire is_branch;
  wire is_jump;
  wire is_jalr;
  wire is_i_type;
  wire is_i_load_type;
  wire is_store;
  wire [4:0] rs1;
  wire [4:0] rs2;
  wire [31:0] rs1_data;
  wire [31:0] rs2_data;
  wire [4:0] rd;
  wire [31:0] rd_data;
  wire [31:0] imm;
  wire is_lui;

  // pc control
  assign pc_enable = 1;

  // reset logic
  reg rst;
  initial begin
    rst = 1'b1;
    #1 rst = 1'b0;
  end

  // fetch

  program_counter pc_inst (
      .clk(clk),
      .rst(rst),
      .enable(pc_enable),
      .load(pc_load),
      .addr(load_addr),
      .pc(pc_out)
  );

  instruction_memory instr_mem (
      .addr(pc_out),
      .instr_out(instr)
  );

  memory memory_inst (
      .clk(clk),
      .addr(mem_addr),
      .data(rs2_data),
      .read(mem_read),
      .write(mem_write),
      .data_out(mem_out)
  );

  alu alu_inst (
      .clk(clk),
      .is_lui(is_lui),
      .imm(imm),
      .rd_data(rd_data),
      .is_branch(is_branch),
      .is_i_type(is_i_type),
      .is_i_load_type(is_i_load_type),
      .rs1_data(rs1_data),
      .rs2_data(rs2_data),
      .alu_ops(alu_ops),
      .pc_data(pc_out),
      .pc_load(pc_load),
      .new_pc_data(load_addr),
      .is_store(is_store),
      .mem_addr(mem_addr),
      .mem_data(mem_out)
  );

  decoder decoder_inst ( 
      .instr(instr),
      .alu_ops(alu_ops),
      .reg_write(reg_write),
      .mem_read(mem_read),
      .mem_write(mem_write),
      .mem_width(mem_width),
      .is_branch(is_branch),
      .rs1(rs1),
      .rs2(rs2),
      .rd(rd),
      .imm(imm),
      .is_lui(is_lui),
      .is_i_type(is_i_type),
      .is_i_load_type(is_i_load_type),
      .is_store(is_store)
  );

  register_file regfile_inst (
      .clk(clk),
      // .rst_n(rst),
      .rs1_addr(rs1),
      .rs2_addr(rs2),
      .rs1_data(rs1_data),
      .rs2_data(rs2_data),

      .we(reg_write),
      .rd_addr(rd),
      .rd_data(rd_data)
  );

endmodule
