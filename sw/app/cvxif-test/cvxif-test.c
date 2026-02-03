/*
 * cvxif-test.c
 *
 * Test application for custom complex arithmetic instructions via CVXIF.
 * Author : Martin ROUXEL
 *
 */

#include <stdint.h>
#include <stdio.h>

static inline int16_t sat16(int32_t x)
{
    if (x > 32767)
        return 32767;
    if (x < -32768)
        return -32768;
    return (int16_t)x;
}

static inline int32_t pack_cplx(int16_t re, int16_t im)
{
    return ((int32_t)re << 16) | ((uint16_t)im);
}

static inline int16_t cplx_re(int32_t z) { return (int16_t)(z >> 16); }
static inline int16_t cplx_im(int32_t z) { return (int16_t)(z & 0xFFFF); }

/* Software reference: complex add/sub with per-lane saturation */
static inline int32_t ref_c_add(int32_t a, int32_t b)
{
    int32_t re = (int32_t)cplx_re(a) + (int32_t)cplx_re(b);
    int32_t im = (int32_t)cplx_im(a) + (int32_t)cplx_im(b);
    return pack_cplx(sat16(re), sat16(im));
}

static inline int32_t ref_c_sub(int32_t a, int32_t b)
{
    int32_t re = (int32_t)cplx_re(a) - (int32_t)cplx_re(b);
    int32_t im = (int32_t)cplx_im(a) - (int32_t)cplx_im(b);
    return pack_cplx(sat16(re), sat16(im));
}

/* Software reference: complex mul, keep upper 16 bits of each 32-bit component */
static inline int32_t ref_c_mul(int32_t a, int32_t b)
{
    int32_t ar = (int32_t)cplx_re(a), ai = (int32_t)cplx_im(a);
    int32_t br = (int32_t)cplx_re(b), bi = (int32_t)cplx_im(b);

    int32_t re32 = ar * br - ai * bi;
    int32_t im32 = ar * bi + ai * br;

    int16_t re_hi = (int16_t)(re32 >> 16);
    int16_t im_hi = (int16_t)(im32 >> 16);

    return pack_cplx(re_hi, im_hi);
}

/* Custom instructions (funct3 mapping)
   ADD   = 1
   C_ADD = 2
   C_SUB = 3
   C_MUL = 4
*/
static inline int32_t hw_c_add(int32_t a, int32_t b)
{
    int32_t r;
    asm volatile(".insn r 0x7B, 2, 0, %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static inline int32_t hw_c_sub(int32_t a, int32_t b)
{
    int32_t r;
    asm volatile(".insn r 0x7B, 3, 0, %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static inline int32_t hw_c_mul(int32_t a, int32_t b)
{
    int32_t r;
    asm volatile(".insn r 0x7B, 4, 0, %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));
    return r;
}

static void print_cplx(const char *tag, int32_t z)
{
    printf("%s: 0x%08lx  (re=%d, im=%d)\r\n",
           tag, (unsigned long)(uint32_t)z, (int)cplx_re(z), (int)cplx_im(z));
}

static void run_case(const char *name, int32_t a, int32_t b)
{
    printf("\r\n=== %s ===\r\n", name);
    print_cplx("A", a);
    print_cplx("B", b);

    // C_ADD
    {
        int32_t hw = hw_c_add(a, b);
        int32_t sw = ref_c_add(a, b);
        print_cplx("HW C_ADD", hw);
        print_cplx("SW C_ADD", sw);
    }

    // C_SUB
    {
        int32_t hw = hw_c_sub(a, b);
        int32_t sw = ref_c_sub(a, b);
        print_cplx("HW C_SUB", hw);
        print_cplx("SW C_SUB", sw);
    }

    // C_MUL
    {
        int32_t hw = hw_c_mul(a, b);
        int32_t sw = ref_c_mul(a, b);
        print_cplx("HW C_MUL", hw);
        print_cplx("SW C_MUL", sw);
    }
}

int main(void)
{
    // 1) No saturation (small values)
    int32_t a1 = pack_cplx((int16_t)1000, (int16_t)-2000);
    int32_t b1 = pack_cplx((int16_t)3000, (int16_t)4000);

    // 2) Positive saturation on add (both lanes overflow high)
    int32_t a2 = pack_cplx((int16_t)30000, (int16_t)30000);
    int32_t b2 = pack_cplx((int16_t)10000, (int16_t)10000); // 40000 -> sat to 32767

    // 3) Negative saturation on add (both lanes overflow low)
    int32_t a3 = pack_cplx((int16_t)-30000, (int16_t)-30000);
    int32_t b3 = pack_cplx((int16_t)-10000, (int16_t)-10000); // -40000 -> sat to -32768

    // 4) Saturation on sub (positive and negative extremes)
    int32_t a4 = pack_cplx((int16_t)32767, (int16_t)-32768);
    int32_t b4 = pack_cplx((int16_t)-1, (int16_t)1); // re: 32768 -> sat, im: -32769 -> sat

    // 5) Multiply with visible upper-16 behavior (treat as Q1.15-like magnitudes)
    // Pick values that don't overflow 32-bit, but produce non-trivial high bits.
    int32_t a5 = pack_cplx((int16_t)20000, (int16_t)10000);
    int32_t b5 = pack_cplx((int16_t)15000, (int16_t)-12000);

    run_case("Case 1: no saturation", a1, b1);
    run_case("Case 2: C_ADD positive saturation", a2, b2);
    run_case("Case 3: C_ADD negative saturation", a3, b3);
    run_case("Case 4: C_SUB saturation both directions", a4, b4);
    run_case("Case 5: C_MUL (upper-16 of 32-bit parts)", a5, b5);

    return 0;
}
