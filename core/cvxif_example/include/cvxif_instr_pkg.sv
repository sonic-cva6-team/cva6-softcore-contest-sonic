// Copyright 2021 Thales DIS design services SAS
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
// You may obtain a copy of the License at https://solderpad.org/licenses/
//
// Original Author: Guillaume Chauvon (guillaume.chauvon@thalesgroup.com)

package cvxif_instr_pkg;

  typedef enum logic [3:0] {
    ILLEGAL = 4'b0000,
    ADD     = 4'b0010
  } opcode_t;

  typedef struct packed {
    logic accept;
    logic writeback;  // TODO depends on dualwrite
    logic [2:0] register_read;  // TODO Nr read ports
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

  // Only 1 RISCV instruction for Coprocessor
  parameter int unsigned NbInstr = 1;
  parameter copro_issue_resp_t CoproInstr[NbInstr] = '{
      '{
          // Custom Add : cus_add rd, rs1, rs2
          instr: 32'b00000_00_00000_00000_0_01_00000_1111011,  // custom3 opcode
          mask:  32'b11111_11_00000_00000_1_11_00000_1111111,
          resp:  '{accept : 1'b1, writeback : 1'b1, register_read : {1'b0, 1'b1, 1'b1}},
          opcode: ADD
      }
  };

  // Dummy compressed instruction set
  parameter int unsigned NbCompInstr = 1;
  parameter copro_compressed_resp_t CoproCompInstr[NbCompInstr] = '{
    '{
      instr : 16'b0,
      mask  : 16'b0,
      resp  : '{accept : 1'b0, instr : 32'b0}
    }
  };


endpackage
