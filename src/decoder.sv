module decoder (
    input [31:0] instr,

    output reg [3:0] alu_ops,  // add, sub, xor, or, and, sll, srl, sra, slt, sltu

    output reg reg_write,  // 1 for R, I. 0 for S, B

    output reg       mem_read,   // 1 for LB/LH/LW
    output reg       mem_write,  // 1 for SB/SH/SW
    output reg [1:0] mem_width,  // 00 byte, 01 half, 10 word

    output reg is_lui,
    output reg is_i_type,
    output reg is_i_load_type,
    output reg is_branch,
    output reg is_store,

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

  localparam R_TYPE = 5'b01100;
  localparam I_TYPE = 5'b00100;
  localparam I_LOAD_TYPE = 5'b00000;
  localparam B_TYPE = 5'b11000;
  localparam S_TYPE = 5'b01000;
  localparam J_TYPE = 5'b11011;
  localparam LUI = 5'b01101;
  localparam LOAD = 5'b00000;
  localparam STORE = 5'b01000;
  localparam BRANCH = 5'b11000;
  localparam JAL = 5'b11011;
  localparam JALR = 5'b11001;

  assign rs1 = instr[19:15];
  assign rs2 = instr[24:20];

  assign rd  = instr[11:7];

  always @(*) begin
    is_lui = 0;
    is_i_type = 0;
    is_i_load_type = 0;
    is_branch = 0;
    is_store = 0;

    mem_write = 0;
    mem_read = 0;
    reg_write = 0;

    case (opcode)
      R_TYPE: begin
        if (funct7 != 7'b0000001) begin
          case (funct3)
            3'b000: alu_ops = (funct7 !== 7'b0100000) ? 4'b0000 : 4'b0001;  // ADD / SUB
            3'b100: alu_ops = 4'b0010;  // XOR
            3'b110: alu_ops = 4'b0011;  // OR
            3'b111: alu_ops = 4'b0100;  // AND
            3'b001: alu_ops = 4'b0101;  // SLL
            3'b101: alu_ops = (funct7 !== 7'b0100000) ? 4'b0110 : 4'b1000;  // SRL : SRA
            3'b010: alu_ops = 4'b1001;  // SLT
            3'b011: alu_ops = 4'b1011;  // SLTU
          endcase
        end else begin
          case (funct3)
            3'b000:  alu_ops = 4'b1100;  // MUL
            3'b100:  alu_ops = 4'b1101;  // DIV
            3'b110:  alu_ops = 4'b1110;  // REM
            default: alu_ops = 4'b0000;  // REST NOT DEFINED !! TODO
          endcase
        end

        rs1_used  = 1;
        rs2_used  = 1;
        reg_write = 1;
      end

      I_TYPE: begin
        case (funct3)
          3'b000: alu_ops = 4'b0000;
          3'b100: alu_ops = 4'b0010;
          3'b110: alu_ops = 4'b0011;
          3'b111: alu_ops = 4'b0100;
          3'b101: begin
            if (imm[11:5] == 7'b0000000) alu_ops = 4'b0101;
            else if (imm[11:5] == 7'b0100000) alu_ops = 4'b0111;
          end
          3'b010: alu_ops = 4'b1001;
          3'b011: alu_ops = 4'b1011;  // SLTIU
        endcase

        imm = instr[31:20];
        is_i_type = 1;
        reg_write = 1;
      end

      I_LOAD_TYPE: begin
        case (funct3)
          3'b000: mem_width = 2'b00;  // LB
          3'b001: mem_width = 2'b01;  // LH
          3'b010: mem_width = 2'b10;  // LW
          3'b011: mem_width = 2'b00;  // LBU
          3'b100: mem_width = 2'b01;  // LHU
        endcase

        imm = instr[31:20];
        mem_read = 1;
        is_i_load_type = 1;
        reg_write = 1;
      end

      B_TYPE: begin
        case (funct3)
          3'b000: alu_ops = 4'b0000;  // BEQ
          3'b001: alu_ops = 4'b0001;  // BNE
          3'b100: alu_ops = 4'b0010;  // BLT
          3'b101: alu_ops = 4'b0011;  // BGE
          3'b110: alu_ops = 4'b0100;  // BLTU
          3'b111: alu_ops = 4'b0101;  // BGEU
        endcase

        imm[31:12] = {20{instr[31]}};
        imm[11:5]  = instr[31:25];
        imm[4:0]   = instr[11:7];

        is_branch  = 1;
        rs1_used   = 1;
        rs2_used   = 1;
      end

      J_TYPE: begin
        alu_ops = 4'b0110;  // JAL
 
        imm = {{13{instr[31]}}, instr[30:12]};

        is_branch = 1;
        rs1_used = 1;
        rs2_used = 1;
      end

      S_TYPE: begin
        case (funct3)
          3'b000: mem_width = 2'b00;  // SB
          3'b001: mem_width = 2'b01;  // SH
          3'b010: mem_width = 2'b10;  // SW
        endcase

        imm[11:5] = instr[31:25];
        imm[4:0]  = instr[11:7];

        mem_write = 1;
        is_store  = 1;
        rs1_used  = 1;
        rs2_used  = 1;
      end

      LUI: begin
        is_lui = 1;
        imm = instr[31:20];
        reg_write = 1;
      end
      default: is_i_type = 0;
    endcase
  end

endmodule
