#include <stdio.h>
#include <stdlib.h>
extern unsigned suffix_sum(unsigned), chain_sum(unsigned);
extern unsigned multi_sum(unsigned, unsigned, unsigned), loop_sum(unsigned, unsigned);
extern unsigned sum_squares(unsigned);
int main(int argc, char **argv)
{
  unsigned seed = 2048U, checksum = 0U, i;
  unsigned mode = argc > 1 ? (unsigned)strtoul(argv[1], 0, 10) : 0U;
  unsigned rounds = argc > 2 ? (unsigned)strtoul(argv[2], 0, 10) : 200000U;
  unsigned low = argc > 3 ? (unsigned)strtoul(argv[3], 0, 10) : 128U;
  unsigned width = argc > 4 ? (unsigned)strtoul(argv[4], 0, 10) : 128U;
  if (mode > 4U || width == 0U || (width & (width - 1U)) != 0U ||
      low > 4096U || width > 4096U - low) return 2;
  for (i = 0; i < rounds; i++) {
    unsigned n, a, b;
    seed = seed * 1664525U + 1013904223U;
    n = low + (seed & (width - 1U));
    a = 3U + seed % 17U;
    b = 5U + seed % 23U;
    if (mode == 0U) checksum += suffix_sum(n);
    else if (mode == 1U) checksum += chain_sum(n);
    else if (mode == 2U) checksum += multi_sum(n, a, b);
    else if (mode == 3U) checksum += loop_sum(n, a);
    else checksum += sum_squares(n);
  }
  printf("extension %u %u %u\n", mode, rounds, checksum);
  return 0;
}
