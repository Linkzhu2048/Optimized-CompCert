/* SPDX-License-Identifier: GPL-2.0-or-later
 * Derived from CompCert-small-tests c/sha1.c.
 * The 16-to-80-word message expansion in SHA1_transform is unchanged.
 * The harness supplies decoded words and consumes expanded words; hash rounds are omitted.
 * Source: https://github.com/AbsInt/CompCert-small-tests/blob/081175df374260304a5cd78dd3dfaded93dceb41/c/sha1.c
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define rol1(x) (((x) << 1) | ((x) >> 31))

uint32_t expand(uint32_t seed)
{
    uint32_t data[80], t;
    int i;
    for (i = 0; i < 16; i++) data[i] = seed + (uint32_t)i * 2654435761u;
    for (i = 16; i < 80; i++) {
        t = data[i-3] ^ data[i-8] ^ data[i-14] ^ data[i-16];
        data[i] = rol1(t);
    }
    return data[16] ^ data[79];
}

int main(int argc, char **argv)
{
    int n = argc > 1 ? atoi(argv[1]) : 4096;
    unsigned long rounds = argc > 2 ? strtoul(argv[2], NULL, 10) : 256;
    uint32_t seed = argc > 3 ? (uint32_t)strtoul(argv[3], NULL, 10) : 2048;
    uint32_t checksum = 0;
    unsigned long r;
    int i;
    if (n < 0 || n > 1048576 || rounds == 0 || rounds > 1000000) return 2;
    for (r = 0; r < rounds; r++) {
        for (i = 0; i < n; i++) {
            checksum += expand(seed);
            seed = seed * 1664525u + 1013904223u + checksum;
        }
    }
    printf("%u\n", checksum);
    return 0;
}
