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

  logic signed [15:0] r1_r, r1_i, r2_r, r2_i;
  logic signed [15:0] res_r, res_i;

  // BFLY4 internal state registers
  logic [31:0] bfly4_f0_n, bfly4_f0_q;
  logic [31:0] bfly4_fm_n, bfly4_fm_q;
  logic [31:0] bfly4_fm2_n, bfly4_fm2_q;
  logic [31:0] bfly4_fm3_n, bfly4_fm3_q;
  logic [31:0] bfly4_tw1_n, bfly4_tw1_q;
  logic [31:0] bfly4_tw2_n, bfly4_tw2_q;
  logic [31:0] bfly4_out1_n, bfly4_out1_q;
  logic [31:0] bfly4_out2_n, bfly4_out2_q;
  logic [31:0] bfly4_out3_n, bfly4_out3_q;
  logic [1:0]  bfly4_rd_idx_n, bfly4_rd_idx_q;

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

    // BFLY4 state retention defaults
    bfly4_f0_n     = bfly4_f0_q;
    bfly4_fm_n     = bfly4_fm_q;
    bfly4_fm2_n    = bfly4_fm2_q;
    bfly4_fm3_n    = bfly4_fm3_q;
    bfly4_tw1_n    = bfly4_tw1_q;
    bfly4_tw2_n    = bfly4_tw2_q;
    bfly4_out1_n   = bfly4_out1_q;
    bfly4_out2_n   = bfly4_out2_q;
    bfly4_out3_n   = bfly4_out3_q;
    bfly4_rd_idx_n = bfly4_rd_idx_q;

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
      cvxif_instr_pkg::C_MULDIV4: begin
        logic signed [31:0] div_temp_r, div_temp_i;
        logic signed [15:0] r1_div4_r, r1_div4_i;
        logic signed [31:0] re_long, im_long;
        logic signed [31:0] p1, p2, p3, p4;

        div_temp_r = (32'(r1_r) <<< 13) - 32'(r1_r) + 32'sd16384;
        div_temp_i = (32'(r1_i) <<< 13) - 32'(r1_i) + 32'sd16384;
        r1_div4_r = 16'(div_temp_r >>> 15);
        r1_div4_i = 16'(div_temp_i >>> 15);

        p1       = r1_div4_r * r2_r;
        p2       = r1_div4_i * r2_i;
        p3       = r1_div4_r * r2_i;
        p4       = r1_div4_i * r2_r;

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

      // complex FIXDIV: divide by 4
      // Power-of-2 division via shift - no rounding or format conversion needed
      cvxif_instr_pkg::C_FIXDIV4: begin 

        // Divide by 4 (arithmetic right shift by 2)
        // Q15 format stays Q15, no additional shifting needed
        // Add rounding bias before shifting
        logic signed [31:0] r1_r_ext, r1_i_ext;

        r1_i_ext = (32'(r1_i) <<< 13) - 32'(r1_i) + 32'sd16384; // (r1_i * 16384) - r1_i + 16384 for rounding
        r1_r_ext = (32'(r1_r) <<< 13) - 32'(r1_r) + 32'sd16384;

        res_r = 16'(r1_r_ext >>> 15);
        res_i = 16'(r1_i_ext >>> 15);

        result_n = {res_i, res_r};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end
      // ========================= BFLY2 Simplified Butterfly ==============================================
      // C_MULDIV2
      cvxif_instr_pkg::C_MULDIV2: begin
        logic signed [31:0] div_temp_r, div_temp_i;
        logic signed [15:0] r1_div2_r, r1_div2_i;
        logic signed [31:0] re_long, im_long;
        logic signed [31:0] p1, p2, p3, p4;

        div_temp_r = (32'(r1_r) <<< 14) - 32'(r1_r) + 32'sd16384;
        div_temp_i = (32'(r1_i) <<< 14) - 32'(r1_i) + 32'sd16384;
        r1_div2_r = 16'(div_temp_r >>> 15);
        r1_div2_i = 16'(div_temp_i >>> 15);

        p1       = r1_div2_r * r2_r;
        p2       = r1_div2_i * r2_i;
        p3       = r1_div2_r * r2_i;
        p4       = r1_div2_i * r2_r;

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

      // BFLY2_ADD: rd = rs1/2 + rs2/2
      // Optimized radix-2 butterfly for identity twiddle (no multiplication needed)
      // Combines FIXDIV and ADD into single operation
      // Power-of-2 division via shift - no rounding needed
      cvxif_instr_pkg::BFLY2_ADD: begin

        logic signed [15:0] rs1_r_div2, rs1_i_div2;
        logic signed [31:0] temp_r1, temp_i1;

        temp_r1 = (32'(r1_r) <<< 14) - 32'(r1_r) + 32'sd16384;
        temp_i1 = (32'(r1_i) <<< 14) - 32'(r1_i) + 32'sd16384;

        rs1_r_div2 = 16'(temp_r1 >>> 15);
        rs1_i_div2 = 16'(temp_i1 >>> 15);

        // Add the divided values (both real and imaginary parts)
        res_r = rs1_r_div2 + r2_r;
        res_i = rs1_i_div2 + r2_i;

        result_n = {res_i, res_r};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // BFLY2_SUB: rd = rs1/2 - rs2/2
      // Optimized radix-2 butterfly for identity twiddle (no multiplication needed)
      // Combines FIXDIV and SUB into single operation
      // Power-of-2 division via shift - no rounding needed
      cvxif_instr_pkg::BFLY2_SUB: begin

        logic signed [15:0] rs1_r_div2, rs1_i_div2;
        logic signed [31:0] temp_r1, temp_i1;

        temp_r1 = (32'(r1_r) <<< 14) - 32'(r1_r) + 32'sd16384;
        temp_i1 = (32'(r1_i) <<< 14) - 32'(r1_i) + 32'sd16384;

        rs1_r_div2 = 16'(temp_r1 >>> 15);
        rs1_i_div2 = 16'(temp_i1 >>> 15);

        // Subtract the divided values (both real and imaginary parts)
        res_r = rs1_r_div2 - r2_r;
        res_i = rs1_i_div2 - r2_i;

        result_n = {res_i, res_r};
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // ==================== BFLY4 Full Butterfly Instructions ====================

      // BFLY4_LD01: Store Fout[0] (rs1) and Fout[m] (rs2) into internal registers
      cvxif_instr_pkg::BFLY4_LD01: begin
        bfly4_f0_n = registers_i[0];
        bfly4_fm_n = registers_i[1];
        result_n = '0;
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // BFLY4_LD23: Store Fout[m2] (rs1) and Fout[m3] (rs2) into internal registers
      cvxif_instr_pkg::BFLY4_LD23: begin
        bfly4_fm2_n = registers_i[0];
        bfly4_fm3_n = registers_i[1];
        result_n = '0;
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // BFLY4_TW: Store tw1 (rs1) and tw2 (rs2) into internal registers
      cvxif_instr_pkg::BFLY4_TW: begin
        bfly4_tw1_n = registers_i[0];
        bfly4_tw2_n = registers_i[1];
        result_n = '0;
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // BFLY4_EXEC_FWD / BFLY4_EXEC_INV: Full radix-4 butterfly computation
      cvxif_instr_pkg::BFLY4_EXEC_FWD,
      cvxif_instr_pkg::BFLY4_EXEC_INV: begin
        // tw3 from rs1
        logic signed [15:0] tw3_r, tw3_i;
        // Extract stored operands
        logic signed [15:0] bf0_r, bf0_i, bfm_r, bfm_i;
        logic signed [15:0] bfm2_r, bfm2_i, bfm3_r, bfm3_i;
        logic signed [15:0] btw1_r, btw1_i, btw2_r, btw2_i;

        logic signed [31:0] fd_r, fd_i;
        logic signed [15:0] f0_r, f0_i;

        logic signed [31:0] s0_dt_r, s0_dt_i;
        logic signed [15:0] s0_d4_r, s0_d4_i;
        logic signed [31:0] s0_p1, s0_p2, s0_p3, s0_p4, s0_re, s0_im;
        logic signed [15:0] s0_r, s0_i;

        logic signed [31:0] s1_dt_r, s1_dt_i;
        logic signed [15:0] s1_d4_r, s1_d4_i;
        logic signed [31:0] s1_p1, s1_p2, s1_p3, s1_p4, s1_re, s1_im;
        logic signed [15:0] s1_r, s1_i;

        logic signed [31:0] s2_dt_r, s2_dt_i;
        logic signed [15:0] s2_d4_r, s2_d4_i;
        logic signed [31:0] s2_p1, s2_p2, s2_p3, s2_p4, s2_re, s2_im;
        logic signed [15:0] s2_r, s2_i;

        logic signed [15:0] s5_r, s5_i, s4_r, s4_i, s3_r, s3_i;
        logic signed [15:0] t0_r, t0_i;
        logic signed [15:0] out0_r, out0_i, out1_r, out1_i, out2_r, out2_i, out3_r, out3_i;

        tw3_r = registers_i[0][15:0];
        tw3_i = registers_i[0][31:16];
        
        bf0_r  = bfly4_f0_q[15:0];   bf0_i  = bfly4_f0_q[31:16];
        bfm_r  = bfly4_fm_q[15:0];   bfm_i  = bfly4_fm_q[31:16];
        bfm2_r = bfly4_fm2_q[15:0];  bfm2_i = bfly4_fm2_q[31:16];
        bfm3_r = bfly4_fm3_q[15:0];  bfm3_i = bfly4_fm3_q[31:16];
        btw1_r = bfly4_tw1_q[15:0];  btw1_i = bfly4_tw1_q[31:16];
        btw2_r = bfly4_tw2_q[15:0];  btw2_i = bfly4_tw2_q[31:16];

        // --- Step 1: fixdiv4(Fout[0]) ---
        fd_r = (32'(bf0_r) <<< 13) - 32'(bf0_r) + 32'sd16384;
        fd_i = (32'(bf0_i) <<< 13) - 32'(bf0_i) + 32'sd16384;
        f0_r = 16'(fd_r >>> 15);
        f0_i = 16'(fd_i >>> 15);

        // --- Step 2: s0 = cmuldiv4(Fout[m], tw1) ---
        s0_dt_r = (32'(bfm_r) <<< 13) - 32'(bfm_r) + 32'sd16384;
        s0_dt_i = (32'(bfm_i) <<< 13) - 32'(bfm_i) + 32'sd16384;
        s0_d4_r = 16'(s0_dt_r >>> 15);
        s0_d4_i = 16'(s0_dt_i >>> 15);
        s0_p1 = s0_d4_r * btw1_r;  s0_p2 = s0_d4_i * btw1_i;
        s0_p3 = s0_d4_r * btw1_i;  s0_p4 = s0_d4_i * btw1_r;
        s0_re = s0_p1 - s0_p2;     s0_im = s0_p3 + s0_p4;
        s0_r = 16'((s0_re + 32'sd16384) >>> 15);
        s0_i = 16'((s0_im + 32'sd16384) >>> 15);

        // --- Step 3: s1 = cmuldiv4(Fout[m2], tw2) ---
        s1_dt_r = (32'(bfm2_r) <<< 13) - 32'(bfm2_r) + 32'sd16384;
        s1_dt_i = (32'(bfm2_i) <<< 13) - 32'(bfm2_i) + 32'sd16384;
        s1_d4_r = 16'(s1_dt_r >>> 15);
        s1_d4_i = 16'(s1_dt_i >>> 15);
        s1_p1 = s1_d4_r * btw2_r;  s1_p2 = s1_d4_i * btw2_i;
        s1_p3 = s1_d4_r * btw2_i;  s1_p4 = s1_d4_i * btw2_r;
        s1_re = s1_p1 - s1_p2;     s1_im = s1_p3 + s1_p4;
        s1_r = 16'((s1_re + 32'sd16384) >>> 15);
        s1_i = 16'((s1_im + 32'sd16384) >>> 15);

        // --- Step 4: s2 = cmuldiv4(Fout[m3], tw3) ---
        s2_dt_r = (32'(bfm3_r) <<< 13) - 32'(bfm3_r) + 32'sd16384;
        s2_dt_i = (32'(bfm3_i) <<< 13) - 32'(bfm3_i) + 32'sd16384;
        s2_d4_r = 16'(s2_dt_r >>> 15);
        s2_d4_i = 16'(s2_dt_i >>> 15);
        s2_p1 = s2_d4_r * tw3_r;  s2_p2 = s2_d4_i * tw3_i;
        s2_p3 = s2_d4_r * tw3_i;  s2_p4 = s2_d4_i * tw3_r;
        s2_re = s2_p1 - s2_p2;    s2_im = s2_p3 + s2_p4;
        s2_r = 16'((s2_re + 32'sd16384) >>> 15);
        s2_i = 16'((s2_im + 32'sd16384) >>> 15);

        // --- Step 5: Butterfly combinations ---
        s5_r = f0_r - s1_r;  s5_i = f0_i - s1_i;   // scratch[5] = f0 - s1
        s4_r = s0_r - s2_r;  s4_i = s0_i - s2_i;   // scratch[4] = s0 - s2
        t0_r = f0_r + s1_r;  t0_i = f0_i + s1_i;   // f0 += s1
        s3_r = s0_r + s2_r;  s3_i = s0_i + s2_i;   // scratch[3] = s0 + s2
        out2_r = t0_r - s3_r; out2_i = t0_i - s3_i; // Fout[m2] = f0 - s3
        out0_r = t0_r + s3_r; out0_i = t0_i + s3_i; // Fout[0]  = f0 + s3

        // --- Step 6: Rotation (forward vs inverse) ---
        if (opcode_i == cvxif_instr_pkg::BFLY4_EXEC_INV) begin
          // Inverse: C_ADD_ROT(out1, s5, s4); C_SUB_ROT(out3, s5, s4);
          out1_r = s5_r - s4_i;  out1_i = s5_i + s4_r;
          out3_r = s5_r + s4_i;  out3_i = s5_i - s4_r;
        end else begin
          // Forward: C_SUB_ROT(out1, s5, s4); C_ADD_ROT(out3, s5, s4);
          out1_r = s5_r + s4_i;  out1_i = s5_i - s4_r;
          out3_r = s5_r - s4_i;  out3_i = s5_i + s4_r;
        end

        // Output out[0] via result, store out[1..3] for BFLY4_RD
        result_n = {out0_i, out0_r};
        bfly4_out1_n = {out1_i, out1_r};
        bfly4_out2_n = {out2_i, out2_r};
        bfly4_out3_n = {out3_i, out3_r};
        bfly4_rd_idx_n = 2'd0;
        valid_n  = 1'b1;
        rd_n     = rd_i;
        we_n     = 1'b1;
      end

      // BFLY4_RD: Read next butterfly result (auto-advancing index)
      cvxif_instr_pkg::BFLY4_RD: begin
        case (bfly4_rd_idx_q)
          2'd0: result_n = bfly4_out1_q;
          2'd1: result_n = bfly4_out2_q;
          2'd2: result_n = bfly4_out3_q;
          default: result_n = '0;
        endcase
        bfly4_rd_idx_n = bfly4_rd_idx_q + 2'd1;
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
      bfly4_f0_q     <= '0;
      bfly4_fm_q     <= '0;
      bfly4_fm2_q    <= '0;
      bfly4_fm3_q    <= '0;
      bfly4_tw1_q    <= '0;
      bfly4_tw2_q    <= '0;
      bfly4_out1_q   <= '0;
      bfly4_out2_q   <= '0;
      bfly4_out3_q   <= '0;
      bfly4_rd_idx_q <= '0;
    end else begin
      result_q <= result_n;
      hartid_q <= hartid_n;
      id_q     <= id_n;
      valid_q  <= valid_n;
      rd_q     <= rd_n;
      we_q     <= we_n;
      bfly4_f0_q     <= bfly4_f0_n;
      bfly4_fm_q     <= bfly4_fm_n;
      bfly4_fm2_q    <= bfly4_fm2_n;
      bfly4_fm3_q    <= bfly4_fm3_n;
      bfly4_tw1_q    <= bfly4_tw1_n;
      bfly4_tw2_q    <= bfly4_tw2_n;
      bfly4_out1_q   <= bfly4_out1_n;
      bfly4_out2_q   <= bfly4_out2_n;
      bfly4_out3_q   <= bfly4_out3_n;
      bfly4_rd_idx_q <= bfly4_rd_idx_n;
    end
  end

endmodule