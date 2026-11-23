/* SPDX-License-Identifier: GPL-2.0-or-later
 * Derived from CompCert-small-tests c/knucleotide.c, ht_create(),
 * contributed by Josh Goldfoot to The Computer Language Shootout.
 * The prime table and lookup condition are retained; allocation and hash-table
 * bookkeeping are omitted. The argument handling and repetition harness are new.
 * Source: https://github.com/AbsInt/CompCert-small-tests/blob/081175df374260304a5cd78dd3dfaded93dceb41/c/knucleotide.c
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

enum { ht_num_primes = 28 };
static unsigned long ht_prime_list[ht_num_primes] = {
    53ul,         97ul,         193ul,       389ul,       769ul,
    1543ul,       3079ul,       6151ul,      12289ul,     24593ul,
    49157ul,      98317ul,      196613ul,    393241ul,    786433ul,
    1572869ul,    3145739ul,    6291469ul,   12582917ul,  25165843ul,
    50331653ul,   100663319ul,  201326611ul, 402653189ul, 805306457ul, 
    1610612741ul, 3221225473ul, 4294967291ul
};

unsigned long prime_capacity(int size)
{
    int i = 0;
    while (ht_prime_list[i] < size) { i++; }
    return ht_prime_list[i];
}

int main(int argc, char **argv)
{
    int n = argc > 1 ? atoi(argv[1]) : 65536;
    unsigned long rounds = argc > 2 ? strtoul(argv[2], NULL, 10) : 256;
    uint32_t seed = argc > 3 ? (uint32_t)strtoul(argv[3], NULL, 10) : 2048;
    uint32_t checksum = 0, *a;
    unsigned long r;
    int i;
    if (n < 0 || n > 1048576 || rounds == 0 || rounds > 1000000) return 2;
    a = malloc(((size_t)n + 1) * sizeof(*a));
    if (a == NULL) return 1;
    for (i = 0; i < n; i++) a[i] = (uint32_t)i * 2654435761u + seed;
    for (r = 0; r < rounds; r++) {
        for (i = 0; i < n; i++)
            checksum += (uint32_t)prime_capacity((int)(a[i] & 0x7fffffffU));
        seed = seed * 1664525u + 1013904223u;
        a[0] = seed;
    }
    printf("%u\n", checksum);
    free(a);
    return 0;
}
