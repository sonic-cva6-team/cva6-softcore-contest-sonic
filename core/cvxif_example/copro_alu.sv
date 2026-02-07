// Authors: Thang VO, Martin ROUXEL - IMT Atlantque

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

  logic signed [15:0] r1_r, r1_i, r2_r, r2_i, r3_r, r3_i;
  logic signed [15:0] res_r, res_i;

  always_comb begin
    result_n = '0;
    hartid_n = hartid_i;
    id_n     = id_i;
    valid_n  = 1'b0;
    rd_n     = '0;
    we_n     = 1'b0;

    r1_r     = registers_i[0][15:0];
    r1_i     = registers_i[0][31:16];
    r2_r     = registers_i[1][15:0];
    r2_i     = registers_i[1][31:16];
    r3_r     = registers_i[2][15:0];
    r3_i     = registers_i[2][31:16];

    case (opcode_i)

      // complex ADD ((ar+br)+i(ai+bi))
      cvxif_instr_pkg::C_ADD: begin
        res_r    = r1_r + r2_r;
        res_i    = r1_i + r2_i;

        result_n = {res_i, res_r};

        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // complex SUB ((ar-br)+i(ai-bi))
      cvxif_instr_pkg::C_SUB: begin

        res_r    = r1_r - r2_r;
        res_i    = r1_i - r2_i;

        result_n = {res_i, res_r};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // complex MUL ((ar*br - ai*bi)+i(ar*bi + ai*br))
      cvxif_instr_pkg::C_MUL: begin
        logic signed [31:0] re_long, im_long;
        logic signed [31:0] p1, p2, p3, p4;

        p1       = r1_r * r2_r;
        p2       = r1_i * r2_i;
        p3       = r1_r * r2_i;
        p4       = r1_i * r2_r;

        re_long  = p1 - p2;
        im_long  = p3 + p4;

        // Rounding logic: (x + 16384) >> 15
        // 16384 is (1 << 14)
        res_r    = 16'((re_long + 32'sd16384) >>> 15);
        res_i    = 16'((im_long + 32'sd16384) >>> 15);

        result_n = {res_i, res_r};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // complex ADD with rotation ((ar - bi)+i(ai + br))
      cvxif_instr_pkg::C_ADD_ROT: begin

        res_r    = r1_r - r2_i;
        res_i    = r1_i + r2_r;

        result_n = {res_i, res_r};

        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // complex SUB with rotation ((ar + bi)+i(ai - br))
      cvxif_instr_pkg::C_SUB_ROT: begin

        res_r    = r1_r + r2_i;
        res_i    = r1_i - r2_r;

        result_n = {res_i, res_r};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // complex FIXDIV ( (ar/2) + i(ai/2) )
      cvxif_instr_pkg::C_FIXDIV: begin 
        logic signed [15:0] c_r, c_i, scale;
        logic signed [31:0] prod_r, prod_i;
        logic signed [31:0] shifted_r, shifted_i;

        c_r = registers_i[0][15:0];
        c_i = registers_i[0][31:16];
        scale = registers_i[1][15:0]; 

        prod_r = c_r * scale;
        prod_i = c_i * scale;

        // Add rounding: (1 << 14) = 16384
        shifted_r = prod_r + 32'sd16384;
        shifted_i = prod_i + 32'sd16384;

        res_r = 16'(shifted_r >>> 15);
        res_i = 16'(shifted_i >>> 15);

        result_n = {res_i, res_r};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // BUTTERFLY_R2_ADD: rd = rs1/2 + rs2/2
      // Optimized radix-2 butterfly for identity twiddle (no multiplication needed)
      // Combines FIXDIV and ADD into single operation
      cvxif_instr_pkg::BUTTERFLY_R2_ADD: begin
        logic signed [15:0] rs1_r_div2, rs1_i_div2, rs2_r_div2, rs2_i_div2;
        logic signed [31:0] shifted_rs1_r, shifted_rs1_i, shifted_rs2_r, shifted_rs2_i;
        logic signed [15:0] rs1_r, rs1_i, rs2_r, rs2_i;

        // Divide both inputs by 2 (arithmetic right shift)
        rs1_r_div2 = r1_r >>> 1;
        rs1_i_div2 = r1_i >>> 1;
        rs2_r_div2 = r2_r >>> 1;
        rs2_i_div2 = r2_i >>> 1;

        // Add rounding: (1 << 14) = 16384
        shifted_rs1_r = rs1_r_div2 + 16'sd16384;
        shifted_rs1_i = rs1_i_div2 + 16'sd16384;
        shifted_rs2_r = rs2_r_div2 + 16'sd16384;
        shifted_rs2_i = rs2_i_div2 + 16'sd16384;

        rs1_r = 16'(shifted_rs1_r >>> 15);
        rs1_i = 16'(shifted_rs1_i >>> 15);
        rs2_r = 16'(shifted_rs2_r >>> 15);
        rs2_i = 16'(shifted_rs2_i >>> 15);

        // Add the divided values
        res_r = rs1_r + rs2_r;
        res_i = rs1_i;

        result_n = {res_i, res_r};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // BUTTERFLY_R2_SUB: rd = rs1/2 - rs2/2
      // Optimized radix-2 butterfly for identity twiddle (no multiplication needed)
      // Combines FIXDIV and SUB into single operation
      cvxif_instr_pkg::BUTTERFLY_R2_SUB: begin
        logic signed [15:0] rs1_r_div2, rs1_i_div2, rs2_r_div2, rs2_i_div2;
        logic signed [31:0] shifted_rs1_r, shifted_rs1_i, shifted_rs2_r, shifted_rs2_i;
        logic signed [15:0] rs1_r, rs1_i, rs2_r, rs2_i;

        // Divide both inputs by 2 (arithmetic right shift)
        rs1_r_div2 = r1_r >>> 1;
        rs1_i_div2 = r1_i >>> 1;
        rs2_r_div2 = r2_r >>> 1;
        rs2_i_div2 = r2_i >>> 1;

        // Add rounding: (1 << 14) = 16384
        shifted_rs1_r = rs1_r_div2 + 16'sd16384;
        shifted_rs1_i = rs1_i_div2 + 16'sd16384;
        shifted_rs2_r = rs2_r_div2 + 16'sd16384;
        shifted_rs2_i = rs2_i_div2 + 16'sd16384;

        rs1_r = 16'(shifted_rs1_r >>> 15);
        rs1_i = 16'(shifted_rs1_i >>> 15);
        rs2_r = 16'(shifted_rs2_r >>> 15);
        rs2_i = 16'(shifted_rs2_i >>> 15);

        // Subtract the divided values
        res_r = rs1_r - rs2_r;
        res_i = rs1_i;

        result_n = {res_i, res_r};
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