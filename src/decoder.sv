module decoder (
    input [31:0] instr,

    output reg [3:0] alu_ops,  // add, sub, xor, or, and, sll, srl, sra, slt, sltu

    output reg reg_write,  // 1 for R, I. 0 for S, B

    output reg       mem_read,   // 1 for LB/LH/LW
    output reg       mem_write,  // 1 for SB/SH/SW
    output reg [1:0] mem_width,  // 00 byte, 01 half, 10 word

    output reg       is_branch,
    output reg [2:0] branch_type,  // BEQ, BNE, BLT, BGE, BLTU, BGEU
    output reg       is_jump,
    output reg       is_jalr,

    output     [4:0] rs1,
    output     [4:0] rs2,
    output reg       rs1_used,
    output reg       rs2_used,

    output [4:0] rd,

    output reg [31:0] imm
);

  wire [4:0] opcode = instr[6:2];
  wire [2:0] funct3 = instr[14:12];
  wire [6:0] funct7 = instr[31:25];

  localparam R_TYPE = 7'b01100;
  localparam I_TYPE = 7'b00100;
  localparam LOAD = 7'b00000;
  localparam STORE = 7'b01000;
  localparam BRANCH = 7'b11000;
  localparam JAL = 7'b11011;
  localparam JALR = 7'b11001;

  assign rs1 = instr[19:15];
  assign rs2 = instr[24:20];

  assign rd  = instr[11:7];

  always @(*) begin
    case (opcode)
      R_TYPE: begin
        case (funct3)
          3'b000: alu_ops = (funct7 !== 7'b0100000) ? 4'b0000 : 4'b0001;  // ADD / SUB
          3'b100: alu_ops = 4'b0010;  // XOR
          3'b110: alu_ops = 4'b0011;  // OR
          3'b111: alu_ops = 4'b0100;  // AND
          3'b001: alu_ops = 4'b0101;  // SLL
          3'b001: alu_ops = (funct7 !== 7'b0100000) ? 4'b0101 : 4'b0111;  // SRL : SRA
          3'b010: alu_ops = 4'b1000;  // SLT
          3'b011: alu_ops = 4'b1001;  // SLTU
        endcase
      end
    endcase
  end

endmodule
