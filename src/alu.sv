module alu (
    input clk,
    input is_lui,
    input is_i_type,
    input is_i_load_type,
    input is_branch,
    input is_store,
    input [3:0] alu_ops,
    input [31:0] rs1_data,
    input [31:0] rs2_data,
    input [31:0] imm,
    input [31:0] pc_data,
    input [31:0] mem_data,
    output reg pc_load,
    output reg [31:0] rd_data,
    output reg [31:0] new_pc_data,
    output reg [31:0] mem_addr
);

  wire signed [31:0] rs1_signed = $signed(rs1_data);
  wire signed [31:0] rs2_signed = $signed(rs2_data);
  wire signed [31:0] imm_signed = $signed(imm);

  always @* begin
    rd_data = 32'b0;
    pc_load = 0;

    if (is_lui) begin
      rd_data = imm << 12;

    end else if (is_i_type) begin
      case (alu_ops)
        4'b0000: rd_data = rs1_signed + imm_signed;
        4'b0010: rd_data = rs1_signed ^ imm_signed;
        4'b1000: rd_data = rs1_signed < imm;
        4'b1011: rd_data = rs1_data < imm;
      endcase

    end else if (is_i_load_type) begin
      mem_addr = rs1_data + imm;
      rd_data  = mem_data;

    end else if (is_branch) begin
      case (alu_ops)
        4'b0000:
        if (rs1_signed == rs2_signed) begin
          pc_load = 1;
          new_pc_data = pc_data + imm_signed;
        end

        4'b0001:
        if (rs1_signed != rs2_signed) begin
          pc_load = 1;
          new_pc_data = pc_data + imm_signed;
        end

        4'b0010:
        if (rs1_signed < rs2_signed) begin
          pc_load = 1;
          new_pc_data = pc_data + imm_signed;
        end

        4'b0011:
        if (rs1_signed >= rs2_signed) begin
          pc_load = 1;
          new_pc_data = pc_data + imm_signed;
        end

        4'b0110: begin
          
          rd_data = pc_data;
          pc_load = 1;
          new_pc_data = $signed(pc_data) + imm_signed;
        end
      endcase

    end else if (is_store) begin
      mem_addr = rs1_data + imm;

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
        4'b1110: rd_data = rs1_signed % rs2_signed;
        4'b1001: rd_data = rs1_signed < rs2_signed;
        default: rd_data = 32'b0;
      endcase
    end
  end

endmodule
