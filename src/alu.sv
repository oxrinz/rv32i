module alu (
    input             clk,
    input             is_lui,
    input             is_i_type,
    input      [31:0] rs1_data,
    input      [31:0] rs2_data,
    input      [31:0] imm,
    output reg [31:0] rd_data
);

  always @(posedge clk) begin
    if (is_lui == 1) begin
      rd_data <= imm << 12;
    end
    if (is_i_type) begin
      rd_data = rs1_data + imm;
    end
  end

endmodule
