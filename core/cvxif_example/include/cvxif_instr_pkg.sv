package cvxif_instr_pkg;

  typedef enum logic [3:0] {
    ILLEGAL = 4'b0000,
    C_ADD = 4'b0001,
    C_SUB = 4'b0010,
    C_MULDIV4 = 4'b0011,
    C_ADD_ROT = 4'b0100,
    C_SUB_ROT = 4'b0101,
    C_FIXDIV4 = 4'b0110,
    BFLY2_ADD = 4'b0111,
    BFLY2_SUB = 4'b1000,
    BFLY4_LD01     = 4'b1001,
    BFLY4_LD23     = 4'b1010,
    BFLY4_TW       = 4'b1011,
    BFLY4_EXEC_FWD = 4'b1100,
    BFLY4_EXEC_INV = 4'b1101,
    BFLY4_RD       = 4'b1110,
    C_MULDIV2      = 4'b1111

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

  parameter int unsigned NbInstr = 15;
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
          opcode: C_MULDIV4
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
          opcode: C_FIXDIV4
      },
      '{
          // Butterfly Radix-2 ADD: rd = rs1/2 + rs2/2
          // Optimized for identity twiddle (32767, 0) - no multiplication needed
          instr:
          32'b00000_00_00000_00000_0_01_00000_1011011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: BFLY2_ADD
      },
      '{
          // Butterfly Radix-2 SUB: rd = rs1/2 - rs2/2
          // Optimized for identity twiddle (32767, 0) - no multiplication needed
          instr:
          32'b00000_00_00000_00000_0_10_00000_1011011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: BFLY2_SUB
      },
      '{
          instr:
          32'b00000_00_00000_00000_0_11_00000_1011011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_MULDIV2
      },
      // === BFLY4 Full Butterfly Instructions (opcode 0x2B = custom-1) ===
      '{
          // BFLY4_LD01: Load Fout[0] (rs1) and Fout[m] (rs2) into internal regs (funct3=0)
          instr:
          32'b00000_00_00000_00000_0_00_00000_0101011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: BFLY4_LD01
      },
      '{
          // BFLY4_LD23: Load Fout[m2] (rs1) and Fout[m3] (rs2) into internal regs (funct3=1)
          instr:
          32'b00000_00_00000_00000_0_01_00000_0101011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: BFLY4_LD23
      },
      '{
          // BFLY4_TW: Load tw1 (rs1) and tw2 (rs2) into internal regs (funct3=2)
          instr:
          32'b00000_00_00000_00000_0_10_00000_0101011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: BFLY4_TW
      },
      '{
          // BFLY4_EXEC_FWD: Load tw3 (rs1), compute forward butterfly, rd=out[0] (funct3=3)
          instr:
          32'b00000_00_00000_00000_0_11_00000_0101011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b0, 1'b1}},
          opcode: BFLY4_EXEC_FWD
      },
      '{
          // BFLY4_EXEC_INV: Load tw3 (rs1), compute inverse butterfly, rd=out[0] (funct3=4)
          instr:
          32'b00000_00_00000_00000_1_00_00000_0101011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b0, 1'b1}},
          opcode: BFLY4_EXEC_INV
      },
      '{
          // BFLY4_RD: Read next butterfly result, auto-advancing (funct3=5)
          instr:
          32'b00000_00_00000_00000_1_01_00000_0101011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b0, 1'b0}},
          opcode: BFLY4_RD
      }

  };

  // Dummy compressed instructions
  parameter int unsigned NbCompInstr = 1;
  parameter copro_compressed_resp_t CoproCompInstr[NbCompInstr] = '{
      '{instr : 16'b0, mask  : 16'b0, resp  : '{accept : 1'b0, instr : 32'b0}}
  };

endpackage
