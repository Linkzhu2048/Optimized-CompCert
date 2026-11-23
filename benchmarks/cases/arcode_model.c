/* SPDX-License-Identifier: LGPL-3.0-or-later
 * Adapted from CompCert-small-tests compression/arcode.c,
 * BuildProbabilityRangeList and SymbolCountToProbabilityRanges.
 * Copyright (C) 2004, 2006-2007 Michael Dipperstein.
 * The LGPL permits redistribution and modification; this code comes without
 * warranty. License: https://www.gnu.org/licenses/lgpl-3.0.html
 * File input is replaced by a byte buffer; counting, rescaling, and cumulative
 * ranges retain the original algorithm and widths. The harness is new.
 * Source: https://github.com/AbsInt/CompCert-small-tests/blob/081175df374260304a5cd78dd3dfaded93dceb41/compression/arcode.c
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

typedef unsigned short probability_t;
#define EOF_CHAR (UCHAR_MAX + 1)
#define MAX_PROBABILITY (1 << (8 * sizeof(probability_t) - 2))
#define UPPER(c) ((c) + 1)
probability_t ranges[UPPER(EOF_CHAR) + 1];
probability_t cumulativeProb;

void SymbolCountToProbabilityRanges(void)
{
    int c;
    ranges[0] = 0;
    ranges[UPPER(EOF_CHAR)] = 1;
    cumulativeProb++;
    for (c = 1; c <= UPPER(EOF_CHAR); c++)
        ranges[c] += ranges[c - 1];
}

void BuildProbabilityRangeList(const unsigned char *input, int n)
{
    int c, i;
    unsigned long countArray[EOF_CHAR];
    unsigned long totalCount = 0;
    unsigned long rescaleValue;
    for (c = 0; c < EOF_CHAR; c++) countArray[c] = 0;
    for (i = 0; i < n; i++) {
        countArray[input[i]]++;
        totalCount++;
    }
    if (totalCount >= MAX_PROBABILITY) {
        rescaleValue = (totalCount / MAX_PROBABILITY) + 1;
        for (c = 0; c < EOF_CHAR; c++) {
            if (countArray[c] > rescaleValue)
                countArray[c] /= rescaleValue;
            else if (countArray[c] != 0)
                countArray[c] = 1;
        }
    }
    ranges[0] = 0;
    cumulativeProb = 0;
    for (c = 0; c < EOF_CHAR; c++) {
        ranges[UPPER(c)] = countArray[c];
        cumulativeProb += countArray[c];
    }
    SymbolCountToProbabilityRanges();
}

int main(int argc, char **argv)
{
    int n = argc > 1 ? atoi(argv[1]) : 65536;
    unsigned long rounds = argc > 2 ? strtoul(argv[2], NULL, 10) : 1024;
    uint32_t seed = argc > 3 ? (uint32_t)strtoul(argv[3], NULL, 10) : 2048;
    uint32_t checksum = 0;
    unsigned long r;
    unsigned char *input;
    int i;
    if (n < 0 || n > 1048576 || rounds == 0 || rounds > 1000000) return 2;
    input = malloc((size_t)n + 1);
    if (input == NULL) return 1;
    for (i = 0; i < n; i++)
        input[i] = (i < 128 || !(seed & 1u)) ? (unsigned char)((uint32_t)i + seed) : 0;
    for (r = 0; r < rounds; r++) {
        BuildProbabilityRangeList(input, n);
        for (i = 0; i <= UPPER(EOF_CHAR); i++)
            checksum = checksum * 33u + ranges[i];
        seed = seed * 1664525u + 1013904223u;
        input[0] = (unsigned char)seed;
    }
    printf("%u\n", checksum);
    free(input);
    return 0;
}
