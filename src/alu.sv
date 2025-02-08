module alu (
    input clk,
    input is_lui,
    input is_i_type,
    input [3:0] alu_ops,
    input [31:0] rs1_data,
    input [31:0] rs2_data,
    input [31:0] imm,
    output reg [31:0] rd_data
);

  wire signed [31:0] rs1_signed = $signed(rs1_data);
  wire signed [31:0] rs2_signed = $signed(rs2_data);
  wire signed [31:0] imm_signed = $signed(imm);

  always @* begin
    rd_data = 32'b0;

    if (is_lui) begin
      rd_data = imm << 12;
    end else if (is_i_type) begin
      rd_data = rs1_signed + imm_signed;
    end else begin
      case (alu_ops)
        4'b0000: rd_data = rs1_signed + rs2_signed;
        4'b0001: rd_data = rs1_signed - rs2_signed;
        4'b0010: rd_data = rs1_signed ^ rs2_signed;
        4'b0011: rd_data = rs1_signed | rs2_signed;
        4'b0100: rd_data = rs1_signed & rs2_signed;
        4'b0101: rd_data = rs1_signed << rs2_signed;
        4'b0110: rd_data = rs1_signed >> rs2_signed;
        4'b1100: rd_data = rs1_signed * rs2_signed;
        4'b1101: rd_data = rs1_signed / rs2_signed;
        default: rd_data = 32'b0;
      endcase
    end
  end

endmodule
