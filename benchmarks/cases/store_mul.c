/* An invariant multiplication in a loop that also writes an array.
   Standalone program: [length [rounds [seed]]]; prints a deterministic checksum. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

/* Public linkage keeps CompCert's called-once inliner from merging this loop into main. */
uint32_t scan(const uint32_t *a, uint32_t *b, int n, uint32_t seed)
{
    uint32_t value = seed;
    int i;
    for (i = 0; i < n; i++) {
        uint32_t invariant = seed * (uint32_t)n;
        b[i] = a[i] ^ invariant;
        value += b[i];
    }
    return value;
}

int main(int argc, char **argv)
{
    int n = argc > 1 ? atoi(argv[1]) : 65536;
    unsigned long rounds = argc > 2 ? strtoul(argv[2], NULL, 10) : 4096;
    uint32_t seed = argc > 3 ? (uint32_t)strtoul(argv[3], NULL, 10) : 2048;
    uint32_t checksum = 0, *a, *b;
    unsigned long r;
    int i;
    if (n < 0 || n > 1048576 || rounds == 0 || rounds > 1000000) return 2;
    a = malloc(((size_t)n + 1) * sizeof(*a));
    b = malloc(((size_t)n + 1) * sizeof(*b));
    if (a == NULL || b == NULL) { free(a); free(b); return 1; }
    for (i = 0; i < n; i++) a[i] = (uint32_t)i * 2654435761u + seed;
    for (r = 0; r < rounds; r++) {
        checksum += scan(a, b, n, seed);
        seed = seed * 1664525u + 1013904223u;
        a[0] = seed;
    }
    /* Make the final array contents observable as well as the sum. */
    for (i = 0; i < n; i++) checksum = checksum * 33u + b[i];
    free(b);
    printf("%u\n", checksum);
    free(a);
    return 0;
}
