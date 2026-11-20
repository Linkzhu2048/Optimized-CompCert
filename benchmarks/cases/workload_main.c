#include <stdio.h>
#include <stdlib.h>

extern unsigned workload_sum(unsigned);
extern unsigned workload_branch(unsigned);
extern unsigned workload_product(unsigned);

int main(int argc, char **argv)
{
  unsigned seed = 2048U, checksum = 0U, i, n;
  unsigned rounds = argc > 2 ? (unsigned)strtoul(argv[2], 0, 10) : 200000U;
  int mode = argc > 1 ? atoi(argv[1]) : 0;
  unsigned low = argc > 3 ? (unsigned)strtoul(argv[3], 0, 10) : 128U;
  unsigned width = argc > 4 ? (unsigned)strtoul(argv[4], 0, 10) : 128U;
  if (mode < 0 || mode > 2 || width == 0U || (width & (width - 1U)) != 0U ||
      low > 4096U || width > 4096U - low) return 2;
  for (i = 0; i < rounds; i++) {
    seed = seed * 1664525U + 1013904223U;
    n = low + (seed & (width - 1U));
    if (mode == 0) checksum += workload_sum(n);
    else if (mode == 1) checksum += workload_branch(n);
    else checksum += workload_product(n % 12U + 1U);
  }
  printf("workload %d %u %u\n", mode, rounds, checksum);
  return 0;
}
