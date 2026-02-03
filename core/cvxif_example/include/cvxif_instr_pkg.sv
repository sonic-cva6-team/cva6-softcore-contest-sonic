package cvxif_instr_pkg;

  typedef enum logic [3:0] {
    ILLEGAL = 4'b0000,
    NOP     = 4'b0001,
    ADD     = 4'b0010,
    C_ADD   = 4'b0011,
    C_SUB   = 4'b0100,
    C_MUL   = 4'b0101
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

  // NOP + ADD + C_ADD + C_SUB + C_MUL
  parameter int unsigned NbInstr = 5;
  parameter copro_issue_resp_t CoproInstr[NbInstr] = '{
      '{
          // Custom NOP (funct3=0)
          instr:
          32'b00000_00_00000_00000_0_00_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b0, register_read : {1'b0, 1'b0, 1'b0}},
          opcode: NOP
      },
      '{
          // Custom ADD (funct3=1)
          instr:
          32'b00000_00_00000_00000_0_01_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: ADD
      },
      '{
          // Complex ADD (funct3=2)
          instr:
          32'b00000_00_00000_00000_0_10_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_ADD
      },
      '{
          // Complex SUB (funct3=3)
          instr:
          32'b00000_00_00000_00000_0_11_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_SUB
      },
      '{
          // Complex MUL (funct3=4)
          instr:
          32'b00000_00_00000_00000_1_00_00000_1111011,
          mask: 32'b11111_11_00000_00000_1_11_00000_1111111,
          resp: '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: C_MUL
      }
  };

  // Dummy compressed instructions
  parameter int unsigned NbCompInstr = 1;
  parameter copro_compressed_resp_t CoproCompInstr[NbCompInstr] = '{
      '{instr : 16'b0, mask  : 16'b0, resp  : '{accept : 1'b0, instr : 32'b0}}
  };

endpackage
