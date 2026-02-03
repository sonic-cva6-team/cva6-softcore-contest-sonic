// CVXIF coprocessor enabling complex arithmetic operations
// Original Author: Martin ROUXEL - IMT Atlantique

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

  logic signed [15:0] a_re, a_im, b_re, b_im;
  logic signed [31:0] re32, im32;
  logic signed [31:0] ac, bd, ad, bc;

  assign result_o = result_q;
  assign hartid_o = hartid_q;
  assign id_o     = id_q;
  assign valid_o  = valid_q;
  assign rd_o     = rd_q;
  assign we_o     = we_q;

  function automatic logic signed [15:0] sat16(input logic signed [31:0] x);
    begin
      if (x > 32'sd32767) sat16 = 16'sd32767;
      else if (x < -32'sd32768) sat16 = -16'sd32768;
      else sat16 = x[15:0];
    end
  endfunction

  always_comb begin
    result_n = '0;
    hartid_n = hartid_i;
    id_n     = id_i;
    valid_n  = 1'b0;
    rd_n     = '0;
    we_n     = 1'b0;

    a_re     = $signed(registers_i[0][31:16]);
    a_im     = $signed(registers_i[0][15:0]);
    b_re     = $signed(registers_i[1][31:16]);
    b_im     = $signed(registers_i[1][15:0]);

    re32     = '0;
    im32     = '0;
    ac       = '0;
    bd       = '0;
    ad       = '0;
    bc       = '0;

    case (opcode_i)
      cvxif_instr_pkg::NOP: begin
        result_n = '0;
        valid_n  = 1'b1;
        rd_n     = '0;
        we_n     = 1'b0;
      end

      cvxif_instr_pkg::ADD: begin
        result_n = registers_i[1] + registers_i[0];
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      cvxif_instr_pkg::C_ADD: begin
        re32     = $signed(a_re) + $signed(b_re);
        im32     = $signed(a_im) + $signed(b_im);
        result_n = {sat16(re32), sat16(im32)};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      cvxif_instr_pkg::C_SUB: begin
        re32     = $signed(a_re) - $signed(b_re);
        im32     = $signed(a_im) - $signed(b_im);
        result_n = {sat16(re32), sat16(im32)};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      cvxif_instr_pkg::C_MUL: begin
        ac       = $signed(a_re) * $signed(b_re);
        bd       = $signed(a_im) * $signed(b_im);
        ad       = $signed(a_re) * $signed(b_im);
        bc       = $signed(a_im) * $signed(b_re);

        re32     = ac - bd;
        im32     = ad + bc;

        result_n = {re32[31:16], im32[31:16]};
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
