/* SPDX-License-Identifier: GPL-2.0-or-later
 * Extracted from CompCert-small-tests spass/term.c, term_StampOverflow.
 * Copyright (C) 1996-2001 MPI fuer Informatik.
 * The GPL permits redistribution and modification; this code comes without
 * warranty. License: https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
 * The function and its 20-user bound are retained. The CHECK-only invalid-ID
 * diagnostic is omitted, as in the original release build; all IDs are valid.
 * The harness supplies overflow and pending-flag states explicitly; it does not
 * model how frequently a complete theorem prover actually overflows its stamp.
 * Source: https://github.com/AbsInt/CompCert-small-tests/blob/081175df374260304a5cd78dd3dfaded93dceb41/spass/term.c
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

typedef enum { FALSE=0, TRUE=1 } BOOL;
typedef unsigned int NAT;
#define NAT_MAX UINT_MAX
#define term_MAXSTAMPUSERS 20
NAT term_STAMP;
static BOOL term_STAMPOVERFLOW[term_MAXSTAMPUSERS];

BOOL term_StampOverflow(NAT ID)
{
    BOOL Result = FALSE;
    NAT i;
    if (term_STAMP == NAT_MAX) {
        term_STAMP = 0;
        for (i = 0; i < term_MAXSTAMPUSERS; i++)
            term_STAMPOVERFLOW[i] = TRUE;
        term_STAMPOVERFLOW[ID] = FALSE;
        Result = TRUE;
    } else if (term_STAMPOVERFLOW[ID]) {
        term_STAMPOVERFLOW[ID] = FALSE;
        Result = TRUE;
    }
    return Result;
}

int main(int argc, char **argv)
{
    int n = argc > 1 ? atoi(argv[1]) : 65536;
    unsigned long rounds = argc > 2 ? strtoul(argv[2], NULL, 10) : 256;
    uint32_t seed = argc > 3 ? (uint32_t)strtoul(argv[3], NULL, 10) : 2048;
    uint32_t checksum = 0;
    unsigned long r;
    int i;
    if (n < 0 || n > 1048576 || rounds == 0 || rounds > 1000000) return 2;
    for (r = 0; r < rounds; r++) {
        for (i = 0; i < n; i++) {
            term_STAMP = (seed & 3u) == 0 ? NAT_MAX : 0;
            checksum += (uint32_t)term_StampOverflow(seed % term_MAXSTAMPUSERS);
            seed = seed * 1664525u + 1013904223u;
        }
    }
    printf("%u\n", checksum);
    return 0;
}
