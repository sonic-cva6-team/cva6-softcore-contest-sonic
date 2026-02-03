// Copyright 2024 Thales DIS France SAS
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
// You may obtain a copy of the License at https://solderpad.org/licenses/
//
// Original Author: THANG VO

module copro_alu
  import cvxif_instr_pkg::*;
#(
    parameter int unsigned NrRgprPorts = 2,
    parameter int unsigned XLEN = 32,
    parameter type hartid_t = logic,
    parameter type id_t = logic,
    parameter type registers_t = logic

) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  registers_t            registers_i,
    input  opcode_t               opcode_i,
    input  hartid_t               hartid_i,
    input  id_t                   id_i,
    input  logic       [     4:0] rd_i,
    output logic       [XLEN-1:0] result_o,
    output hartid_t               hartid_o,
    output id_t                   id_o,
    output logic       [     4:0] rd_o,
    output logic                  valid_o,
    output logic                  we_o
);

  logic [XLEN-1:0] result_n, result_q;
  hartid_t hartid_n, hartid_q;
  id_t id_n, id_q;
  logic valid_n, valid_q;
  logic [4:0] rd_n, rd_q;
  logic we_n, we_q;

  assign result_o = result_q;
  assign hartid_o = hartid_q;
  assign id_o     = id_q;
  assign valid_o  = valid_q;
  assign rd_o     = rd_q;
  assign we_o     = we_q;


function automatic logic [15:0] sat16(input logic [16:0] val);
    if ($signed(val) > 32767) return 16'h7FFF;
    else if ($signed(val) < -32768) return 16'h8000;
    else return val[15:0];
endfunction

always_comb begin
    result_n = '0;
    hartid_n = hartid_i;
    id_n     = id_i;
    valid_n  = 1'b0;
    rd_n     = '0;
    we_n     = 1'b0;

    case (opcode_i)
      cvxif_instr_pkg::NOP: begin
        result_n = '0;
        valid_n  = 1'b1;
        rd_n     = '0;
        we_n     = 1'b0;
      end
      //------------------------- New customed instructions for complex arithmetic -------------------------
      cvxif_instr_pkg::C_ADDTO: begin
        // registers_i[0] is RS1 (a), registers_i[1] is RS2 (b)
        // Assume format packed: High=Imag, Low=Real
        logic [15:0] r1_r, r1_i, r2_r, r2_i;
        logic [16:0] res_r, res_i; // 17-bit keep sign when adding

        // Unpack
        r1_r = registers_i[0][15:0]; r1_i = registers_i[0][31:16];
        r2_r = registers_i[1][15:0]; r2_i = registers_i[1][31:16];

        // Calculate
        res_r = $signed(r1_r) + $signed(r2_r);
        res_i = $signed(r1_i) + $signed(r2_i);

        // Pack result and saturate
        result_n = {sat16(res_i), sat16(res_r)};

        // Control signal
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      cvxif_instr_pkg::C_ADD_ROT: begin
        // registers_i[0] is RS1 (a), registers_i[1] is RS2 (b)
        // Assume format packed: High=Imag, Low=Real
        logic [15:0] r1_r, r1_i, r2_r, r2_i;
        logic [16:0] res_r, res_i; // 17-bit keep sign when adding

        // Unpack
        r1_r = registers_i[0][15:0]; r1_i = registers_i[0][31:16];
        r2_r = registers_i[1][15:0]; r2_i = registers_i[1][31:16];

        // Calculate
        res_r = $signed(r1_r) - $signed(r2_i);
        res_i = $signed(r1_i) + $signed(r2_r);

        // Pack result and saturate
        result_n = {sat16(res_i), sat16(res_r)};

        // Control signal
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      cvxif_instr_pkg::C_SUB: begin
        logic [15:0] r1_r, r1_i, r2_r, r2_i;
        logic [16:0] res_r, res_i;

        r1_r = registers_i[0][15:0]; r1_i = registers_i[0][31:16];
        r2_r = registers_i[1][15:0]; r2_i = registers_i[1][31:16];

        res_r = $signed(r1_r) - $signed(r2_r);
        res_i = $signed(r1_i) - $signed(r2_i);

        result_n = {sat16(res_i), sat16(res_r)};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      cvxif_instr_pkg::C_SUB_ROT: begin
        logic [15:0] r1_r, r1_i, r2_r, r2_i;
        logic [16:0] res_r, res_i;

        r1_r = registers_i[0][15:0]; r1_i = registers_i[0][31:16];
        r2_r = registers_i[1][15:0]; r2_i = registers_i[1][31:16];

        res_r = $signed(r1_r) + $signed(r2_i);
        res_i = $signed(r1_i) - $signed(r2_r);

        result_n = {sat16(res_i), sat16(res_r)};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      cvxif_instr_pkg::C_MUL: begin
        // Logic complex multiplication Q15: (Ar*Br - Ai*Bi) + j(Ar*Bi + Ai*Br)
        logic signed [15:0] ar, ai, br, bi;
        logic signed [31:0] p1, p2, p3, p4;
        logic signed [31:0] re_long, im_long;
        logic [15:0] re_out, im_out;

        ar = registers_i[0][15:0]; ai = registers_i[0][31:16];
        br = registers_i[1][15:0]; bi = registers_i[1][31:16];

        p1 = ar * br;
        p2 = ai * bi;
        p3 = ar * bi;
        p4 = ai * br;

        re_long = p1 - p2;
        im_long = p3 + p4;

        // Shift right 15 bit (Q15) with saturation
        // User sat16 function or custom logic
            
        // Saturation and Truncation for Real
        if (re_long >= 32'sh4000_0000)      re_out = 16'h7FFF; 
        else if (re_long < -32'sh4000_0000) re_out = 16'h8000;
        else                                re_out = 16'(re_long >>> 15);

        // Saturation and Truncation for Imaginary
        if (im_long >= 32'sh4000_0000)      im_out = 16'h7FFF; 
        else if (im_long < -32'sh4000_0000) im_out = 16'h8000;
        else                                im_out = 16'(im_long >>> 15);

        // Final result concatenation
        result_n = {im_out, re_out};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      default: begin
        result_n = '0;
        hartid_n = '0;
        id_n     = '0;
        valid_n  = '0;
        rd_n     = '0;
        we_n     = '0;
      end
    endcase
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni) begin
      result_q <= '0;
      hartid_q <= '0;
      id_q     <= '0;
      valid_q  <= '0;
      rd_q     <= '0;
      we_q     <= '0;
    end else begin
      result_q <= result_n;
      hartid_q <= hartid_n;
      id_q     <= id_n;
      valid_q  <= valid_n;
      rd_q     <= rd_n;
      we_q     <= we_n;
    end
  end

endmodule