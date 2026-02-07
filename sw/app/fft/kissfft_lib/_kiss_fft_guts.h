/*
 *  Copyright (c) 2003-2010, Mark Borgerding. All rights reserved.
 *  This file is part of KISS FFT - https://github.com/mborgerding/kissfft
 *
 *  SPDX-License-Identifier: BSD-3-Clause
 *  See COPYING file for more information.
 */

/* kiss_fft.h
   defines kiss_fft_scalar as either short or a float type
   and defines
   typedef struct { kiss_fft_scalar r; kiss_fft_scalar i; }kiss_fft_cpx; */

#ifndef _kiss_fft_guts_h
#define _kiss_fft_guts_h

#include "kiss_fft.h"
#include "kiss_fft_log.h"
#include <limits.h>

#define FIXED_POINT 16

#define MAXFACTORS 32
/* e.g. an fft of length 128 has 4 factors
 as far as kissfft is concerned
 4*4*4*2
 */

struct kiss_fft_state
{
    int nfft;
    int inverse;

    // THE C_EXP OPERATIONS ARE PRECALCULATED
    int *factors;
    kiss_fft_cpx *twiddles;

    //     int factors[2*MAXFACTORS];
    //     kiss_fft_cpx twiddles[1];
};

/*
  Explanation of macros dealing with complex math:

   C_MUL(m,a,b)         : m = a*b
   C_FIXDIV(c , div)  : if a fixed point impl., c /= div. noop otherwise
   C_SUB(res, a,b)     : res = a - b
   C_SUBFROM(res , a)  : res -= a
   C_ADDTO(res , a)    : res += a
*/

#include <stdint.h>
#define FRACBITS 15
#define SAMPPROD int32_t
#define SAMP_MAX INT16_MAX
#define SAMP_MIN INT16_MIN
#define CHECK_OVERFLOW_OP(a, op, b)

#define smul(a, b) ((SAMPPROD)(a) * (b))
#define sround(x) (kiss_fft_scalar)(((x) + (1 << (FRACBITS - 1))) >> FRACBITS)

#define S_MUL(a, b) sround(smul(a, b))

#define DIVSCALAR(x, k) \
    (x) = sround(smul(x, SAMP_MAX / k))

#define C_MULBYSCALAR(c, s)             \
    do                                  \
    {                                   \
        (c).r = sround(smul((c).r, s)); \
        (c).i = sround(smul((c).i, s)); \
    } while (0)

#define DIVSCALAR(x,k) \
    (x) = sround( smul(  x, SAMP_MAX/k ) )

#define C_FIXDIV(c,div) \
    do {    DIVSCALAR( (c).r , div);  \
        DIVSCALAR( (c).i  , div); }while (0)

// ******************* Custom complex operations using CVX instructions *******************

#define C_MUL(m, a, b)                   \
    asm volatile(                        \
        ".insn r 0x7B, 3, 0, %0, %1, %2" \
        : "=r"(*(uint32_t *)&(m))        \
        : "r"(*(uint32_t *)&(a)),        \
          "r"(*(uint32_t *)&(b)));

#define C_ADD(res, a, b)                 \
    asm volatile(                        \
        ".insn r 0x7B, 1, 0, %0, %1, %2" \
        : "=r"(*(uint32_t *)&(res))      \
        : "r"(*(uint32_t *)&(a)),        \
          "r"(*(uint32_t *)&(b)));

#define C_SUB(m, a, b)                   \
    asm volatile(                        \
        ".insn r 0x7B, 2, 0, %0, %1, %2" \
        : "=r"(*(uint32_t *)&(m))        \
        : "r"(*(uint32_t *)&(a)),        \
          "r"(*(uint32_t *)&(b)));

#define C_ADDTO(res, a)                  \
    asm volatile(                        \
        ".insn r 0x7B, 1, 0, %0, %1, %2" \
        : "=r"(*(uint32_t *)&(res))      \
        : "r"(*(uint32_t *)&(res)),      \
          "r"(*(uint32_t *)&(a)));

#define C_ADD_ROT(res, a, b)             \
    asm volatile(                        \
        ".insn r 0x7B, 4, 0, %0, %1, %2" \
        : "=r"(*(uint32_t *)&(res))      \
        : "r"(*(uint32_t *)&(a)),        \
          "r"(*(uint32_t *)&(b)));

#define C_SUB_ROT(res, a, b)             \
    asm volatile(                        \
        ".insn r 0x7B, 5, 0, %0, %1, %2" \
        : "=r"(*(uint32_t *)&(res))      \
        : "r"(*(uint32_t *)&(a)),        \
          "r"(*(uint32_t *)&(b)));

#define C_FIXDIV4(c, div)                         \
    do                                           \
    {                                            \
        uint32_t c_tmp = *(uint32_t *)&(c);      \
        asm volatile(                            \
            ".insn r 0x7B, 7, 0, %0, %1, %2"     \
            : "=r"(c_tmp)                        \
            : "r"(c_tmp),                        \
              "r"((uint32_t)div));               \
        *(uint32_t *)&(c) = c_tmp;               \
    } while (0)

// ****************************************************************************************

// Simplified Radix-2 Butterfly Instructions
// Optimized for identity twiddle factors (32767, 0) - no multiplication needed!
// These combine FIXDIV by 2 (right shift) with ADD/SUB in single instructions
#define BUTTERFLY_R2_ADD(res, a, b)              \
    asm volatile(                                \
        ".insn r 0x5B, 1, 0, %0, %1, %2"         \
        : "=r"(*(uint32_t *)&(res))              \
        : "r"(*(uint32_t *)&(a)),                \
          "r"(*(uint32_t *)&(b)));                

#define BUTTERFLY_R2_SUB(res, a, b)              \
    asm volatile(                                \
        ".insn r 0x5B, 2, 0, %0, %1, %2"         \
        : "=r"(*(uint32_t *)&(res))              \
        : "r"(*(uint32_t *)&(a)),                \
          "r"(*(uint32_t *)&(b)));                

#define CPLX_ROT_INVERSE(out1, out2, s5, s4) \
    do                                       \
    {                                        \
        C_ADD_ROT(out1, s5, s4);             \
        C_SUB_ROT(out2, s5, s4);             \
    } while (0)

#define CPLX_ROT_FORWARD(out1, out2, s5, s4) \
    do                                       \
    {                                        \
        C_SUB_ROT(out1, s5, s4);             \
        C_ADD_ROT(out2, s5, s4);             \
    } while (0)

#define C_SUBFROM(res, a)                    \
    do                                       \
    {                                        \
        CHECK_OVERFLOW_OP((res).r, -, (a).r) \
        CHECK_OVERFLOW_OP((res).i, -, (a).i) \
        (res).r -= (a).r;                    \
        (res).i -= (a).i;                    \
    } while (0)

#define KISS_FFT_COS(phase) floor(.5 + SAMP_MAX * cos(phase))
#define KISS_FFT_SIN(phase) floor(.5 + SAMP_MAX * sin(phase))
#define HALF_OF(x) ((x) >> 1)

#define kf_cexp(x, phase)             \
    do                                \
    {                                 \
        (x)->r = KISS_FFT_COS(phase); \
        (x)->i = KISS_FFT_SIN(phase); \
    } while (0)

/* a debugging function */
#define pcpx(c) \
    KISS_FFT_DEBUG("%g + %gi\n", (double)((c)->r), (double)((c)->i))

#ifdef KISS_FFT_USE_ALLOCA
// define this to allow use of alloca instead of malloc for temporary buffers
// Temporary buffers are used in two case:
// 1. FFT sizes that have "bad" factors. i.e. not 2,3 and 5
// 2. "in-place" FFTs.  Notice the quotes, since kissfft does not really do an in-place transform.
#include <alloca.h>
#define KISS_FFT_TMP_ALLOC(nbytes) alloca(nbytes)
#define KISS_FFT_TMP_FREE(ptr)
#else
#define KISS_FFT_TMP_ALLOC(nbytes) KISS_FFT_MALLOC(nbytes)
#define KISS_FFT_TMP_FREE(ptr) KISS_FFT_FREE(ptr)
#endif

#endif
