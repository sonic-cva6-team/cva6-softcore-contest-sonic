/**
 * Copyright (c) 2025 Thales.
 * 
 * Copyright and related rights are licensed under the Apache
 * License, Version 2.0 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * https://www.apache.org/licenses/LICENSE-2.0. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 * 
 * Author:         Julien Mallet -  J-Mallet on github.com
 * 
 * Description:    FFT running on a predefined signal with predefined twiddles.
 * 
 * ===========================================================================
 * Revisions  :
 * Date        Version  Author		Description
 * 2025-10-06  0.1      J.Mallet 	Created
 * ===========================================================================
*/


#include "fft_int16_main.h"
#define FFT_RUNS 5000
//#define FFT_BENCHMARK

#ifndef FFT_BENCHMARK

int main(void)
{
	// metrics
	size_t instret = 0;
	size_t cycles = 0;

	// input array
	kiss_fft_cpx *cx_in = &g_cx_in;

	// output array
	kiss_fft_cpx cx_out[N];

	// FFT configuration
	kiss_fft_cfg cfg = kiss_fft_alloc(N, 0, NULL, NULL);

	if (!cfg)
	{
		printf("FFT alloc failed\r\n");
		return 1;
	}

	printf("FFT running...\r\n");

	// Run FFT
	instret = -read_csr(minstret);
	cycles = -read_csr(mcycle);
	kiss_fft(cfg, cx_in, cx_out);
	instret += read_csr(minstret);
	cycles += read_csr(mcycle);

	printf("FFT finished\r\n");

	printf("kiss_fft took %u instructions and %u cycles\r\n", instret, cycles, instret, cycles);

	// compare gold and output
	if (memcmp(cx_out, g_gold, 2 * N * sizeof(kiss_fft_scalar)) != 0)
	{
		printf("FAIL : fft result values incorrect\nYour out values:\nReal\tImag\r\n");
		for (int i = 0; i < N; i++)
		{
			printf("%d\t%d\r\n",cx_out[i].r,cx_out[i].i);
		}
		return 1;
	}

	printf("SUCCESS : fft result values correct\r\n");

	//kiss_fft_free(cfg);
	return 0;
}

#else

int main(void)
{
	// metrics (accumulators)
	size_t instret_sum = 0;
	size_t cycles_sum = 0;

	// input array
	kiss_fft_cpx *cx_in = &g_cx_in;

	// output array
	kiss_fft_cpx cx_out[N];

	// FFT configuration
	kiss_fft_cfg cfg = kiss_fft_alloc(N, 0, NULL, NULL);

	if (!cfg)
	{
		printf("FFT alloc failed\r\n");
		return 1;
	}

	printf("FFT running (%d runs)...\r\n", FFT_RUNS);

	// Run FFT FFT_RUNS times and accumulate metrics
	for (int run = 0; run < FFT_RUNS; run++)
	{
		size_t instret = (size_t)(-read_csr(minstret));
		size_t cycles  = (size_t)(-read_csr(mcycle));

		kiss_fft(cfg, cx_in, cx_out);

		instret += (size_t)read_csr(minstret);
		cycles  += (size_t)read_csr(mcycle);

		instret_sum += instret;
		cycles_sum  += cycles;
	}

	printf("FFT finished\r\n");

	// Averages (integer division)
	size_t instret_avg = instret_sum / FFT_RUNS;
	size_t cycles_avg  = cycles_sum / FFT_RUNS;

	printf("kiss_fft average over %d runs: %u instructions, %u cycles\r\n",
	       FFT_RUNS, instret_avg, cycles_avg);

	// compare gold and output (from the last run)
	if (memcmp(cx_out, g_gold, 2 * N * sizeof(kiss_fft_scalar)) != 0)
	{
		printf("FAIL : fft result values incorrect\nYour out values:\nReal\tImag\r\n");
		for (int i = 0; i < N; i++)
		{
			printf("%d\t%d\r\n", cx_out[i].r, cx_out[i].i);
		}
		return 1;
	}

	printf("SUCCESS : fft result values correct\r\n");

	//kiss_fft_free(cfg);
	return 0;
}

#endif

