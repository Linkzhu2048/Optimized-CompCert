/* SPDX-License-Identifier: GPL-2.0-or-later
 * Derived from CompCert-small-tests c/fftw.c.
 * Adapted from the double-array initialization in main() of the FFTW-generated test.
 * The original 1024-element static array and loop bound are retained;
 * a runtime offset varies the input ramp. The DCT itself is omitted.
 * Length counts independent input-array initializations.
 * Source: https://github.com/AbsInt/CompCert-small-tests/blob/081175df374260304a5cd78dd3dfaded93dceb41/c/fftw.c
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static double input[1024];

void init_input(int offset)
{
    int k;
    for (k = 0; k < 1024; ++k) input[k] = k + offset;
}

int main(int argc, char **argv)
{
    int n = argc > 1 ? atoi(argv[1]) : 65536;
    unsigned long rounds = argc > 2 ? strtoul(argv[2], NULL, 10) : 4;
    uint32_t seed = argc > 3 ? (uint32_t)strtoul(argv[3], NULL, 10) : 2048;
    uint32_t checksum = 0;
    unsigned long r;
    int i;
    if (n < 0 || n > 1048576 || rounds == 0 || rounds > 1000000) return 2;
    for (r = 0; r < rounds; r++) {
        for (i = 0; i < n; i++) {
            init_input((int)(seed & 65535u));
            checksum += (uint32_t)input[seed & 1023u];
            seed = seed * 1664525u + 1013904223u + checksum;
        }
    }
    printf("%u\n", checksum);
    return 0;
}
