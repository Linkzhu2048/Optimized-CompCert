/* SPDX-License-Identifier: GPL-2.0-or-later
 * Derived from CompCert-small-tests c/perlin.c.
 * Original permutation and init() loop from the Perlin noise reference adaptation.
 * The harness swaps two permutation entries before rebuilding the duplicated table;
 * noise evaluation is omitted. Length counts independent table rebuilds.
 * Source: https://github.com/AbsInt/CompCert-small-tests/blob/081175df374260304a5cd78dd3dfaded93dceb41/c/perlin.c
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int p[512];

static int permutation[256] = { 151,160,137,91,90,15,
   131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
   190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
   88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
   77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
   102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
   135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
   5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
   223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
   129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
   251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
   49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
   138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
   };

void init(void)
{
    int i;
    for (i = 0; i < 256; i++)
        p[256+i] = p[i] = permutation[i];
}

int main(int argc, char **argv)
{
    int n = argc > 1 ? atoi(argv[1]) : 65536;
    unsigned long rounds = argc > 2 ? strtoul(argv[2], NULL, 10) : 16;
    uint32_t seed = argc > 3 ? (uint32_t)strtoul(argv[3], NULL, 10) : 2048;
    uint32_t checksum = 0;
    unsigned long r;
    int i, a, b, t;
    if (n < 0 || n > 1048576 || rounds == 0 || rounds > 1000000) return 2;
    for (r = 0; r < rounds; r++) {
        for (i = 0; i < n; i++) {
            a = seed & 255u;
            b = (seed >> 8) & 255u;
            t = permutation[a];
            permutation[a] = permutation[b];
            permutation[b] = t;
            init();
            checksum += (uint32_t)p[seed & 511u];
            seed = seed * 1664525u + 1013904223u + checksum;
        }
    }
    printf("%u\n", checksum);
    return 0;
}
