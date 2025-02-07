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

  always @* begin
    rd_data = 32'b0;

    if (is_lui) begin
      rd_data = imm << 12;
    end else if (is_i_type) begin
      rd_data = rs1_data + imm;
    end else begin
      case (alu_ops)
        4'b0000: rd_data = rs1_data + rs2_data;
        4'b0001: rd_data = rs1_data - rs2_data;
        default: rd_data = 32'b0;
      endcase
    end
  end

endmodule
