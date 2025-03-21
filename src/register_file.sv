module register_file (
    input clk,
    input rst_n,

    input  [ 4:0] rs1_addr,
    input  [ 4:0] rs2_addr,
    output [31:0] rs1_data,
    output [31:0] rs2_data,

    input        we,
    input [ 4:0] rd_addr,
    input [31:0] rd_data
);

  reg [31:0] registers[31:0];
  reg [ 2:0] flags    [ 2:0];

  assign rs1_data = (rs1_addr == 0) ? 32'b0 : registers[rs1_addr];
  assign rs2_data = (rs2_addr == 0) ? 32'b0 : registers[rs2_addr];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      integer i;
      for (i = 0; i < 32; i = i + 1) begin
        registers[i] <= 32'b0;
      end

      registers[2] = 32'h3FF;
      
    end else if (we && rd_addr != 0) begin
      registers[rd_addr] <= rd_data;
    end
  end

endmodule
