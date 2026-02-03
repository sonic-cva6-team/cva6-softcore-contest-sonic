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


//#include "fft_int16_main.h"
#include <stdio.h>
#include <stdint.h>

int main(void)
{
	int32_t a = 10, b = 20, res = 0;
    printf("Calling custom ADD instruction with a=%d b=%d\r\n", a, b);

  	// Call custom1
  	asm volatile (".insn r 0x7B, 1, 0, %0, %1, %2"
              : "=r"(res)
              : "r"(a), "r"(b));

  	printf("Result: %u\r\n", res);

	return 0;
}