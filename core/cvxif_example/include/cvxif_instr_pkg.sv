package cvxif_instr_pkg;

  typedef enum logic [3:0] {
    ILLEGAL = 4'b0000,
    C_ADD = 4'b0001,
    C_SUB = 4'b0010,
    C_MUL = 4'b0011,
    C_ADD_ROT = 4'b0100,
    C_SUB_ROT = 4'b0101,
    C_FIXDIV = 4'b0110,
    BUTTERFLY_R2_ADD = 4'b0111,
    BUTTERFLY_R2_SUB = 4'b1000

  } opcode_t;

  typedef struct packed {
    logic accept;
    logic writeback;
    logic [2:0] register_read;
  } issue_resp_t;

  typedef struct packed {
    logic        accept;
    logic [31:0] instr;
  } compressed_resp_t;

  typedef struct packed {
    logic [31:0] instr;
    logic [31:0] mask;
    issue_resp_t resp;
    opcode_t     opcode;
  } copro_issue_resp_t;

  typedef struct packed {
    logic [15:0]      instr;
    logic [15:0]      mask;
    compressed_resp_t resp;
  } copro_compressed_resp_t;

  parameter int unsigned NbInstr = 8;
  parameter copro_issue_resp_t CoproInstr[NbInstr] = '{
      '{
          // Complex ADD (funct3=1)
          instr:
          32'b00000_00_00000_00000_0_01_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_ADD
      },
      '{
          // Complex SUB (funct3=2)
          instr:
          32'b00000_00_00000_00000_0_10_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_SUB
      },
      '{
          // Complex MUL (funct3=3)
          instr:
          32'b00000_00_00000_00000_0_11_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_MUL
      },
      '{
          // Complex ADD with rotation (funct3=5)
          instr:
          32'b00000_00_00000_00000_1_00_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_ADD_ROT
      },
      '{
          // Complex SUB with rotation (funct3=6)
          instr:
          32'b00000_00_00000_00000_1_01_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_SUB_ROT
      },
      '{
          // Complex FIXDIV (funct3=7)
          instr:
          32'b00000_00_00000_00000_1_11_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_FIXDIV
      },
      '{
          // Butterfly Radix-2 ADD: rd = rs1/2 + rs2/2
          // Optimized for identity twiddle (32767, 0) - no multiplication needed
          instr:
          32'b00001_00_00000_00000_0_00_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: BUTTERFLY_R2_ADD
      },
      '{
          // Butterfly Radix-2 SUB: rd = rs1/2 - rs2/2
          // Optimized for identity twiddle (32767, 0) - no multiplication needed
          instr:
          32'b00010_00_00000_00000_0_00_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: BUTTERFLY_R2_SUB
      }

  };

  // Dummy compressed instructions
  parameter int unsigned NbCompInstr = 1;
  parameter copro_compressed_resp_t CoproCompInstr[NbCompInstr] = '{
      '{instr : 16'b0, mask  : 16'b0, resp  : '{accept : 1'b0, instr : 32'b0}}
  };

endpackage
