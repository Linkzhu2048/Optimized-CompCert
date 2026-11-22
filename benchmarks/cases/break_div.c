/* break_div: one independent control-flow case. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

uint32_t scan(const uint32_t *a, int n, uint32_t seed)
{
    uint32_t value = seed, divisor = seed & 7u;
    int i;
    for (i = 0; i < n; i++) {
        if (i == n / 2) break;
        /* A zero divisor must never be evaluated. */
        if (divisor != 0)
            value += a[i] ^ (seed / divisor);
        else
            value += a[i];
    }
    return value;
}

int main(int argc, char **argv)
{
    int n = argc > 1 ? atoi(argv[1]) : 65536;
    unsigned long rounds = argc > 2 ? strtoul(argv[2], NULL, 10) : 4096;
    uint32_t seed = argc > 3 ? (uint32_t)strtoul(argv[3], NULL, 10) : 2048;
    uint32_t checksum = 0, *a;
    unsigned long r;
    int i;
    if (n < 0 || n > 1048576 || rounds == 0 || rounds > 1000000) return 2;
    a = malloc(((size_t)n + 1) * sizeof(*a));
    if (a == NULL) return 1;
    for (i = 0; i < n; i++) a[i] = (uint32_t)i * 2654435761u + seed;
    for (r = 0; r < rounds; r++) {
        checksum += scan(a, n, seed);
        seed = seed * 1664525u + 1013904223u;
        a[0] = seed;
    }
    printf("%u\n", checksum);
    free(a);
    return 0;
}
