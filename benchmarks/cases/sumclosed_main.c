#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
extern unsigned sum_zero(unsigned), sum_base(unsigned), sum_wrap(unsigned);
extern int sum_signed(int), sum_negative_base(int);
extern unsigned sum_stride_two(unsigned), sum_squares(unsigned), sum_observed(unsigned);
extern unsigned sum_carry(unsigned, unsigned), sum_carry_commuted(unsigned, unsigned);
extern unsigned sum_squares_less(unsigned), sum_carry_stride(unsigned, unsigned);
extern int sum_squares_signed(int), sum_squares_signed_reverse(int);
extern unsigned sum_carry_near(unsigned, unsigned), sum_product_near(unsigned);
extern volatile unsigned sum_observations;

static void unsigned_case(unsigned n)
{
  printf("u %u %u %u %u\n", n, sum_zero(n), sum_base(n), sum_wrap(n));
}
static void expanded_case(unsigned n, unsigned a, int extreme)
{
  printf("expanded %u %u %u %u %u %u\n", n, a,
    sum_carry(n, a), sum_carry_commuted(n, a), sum_squares(n),
    sum_squares_less(n));
  if (!extreme) printf("stride %u %u %u\n", n, a, sum_carry_stride(n, a));
}
static void carry_matrix(unsigned n)
{
  const unsigned values[] = {0U, 1U, 0x7fffffffU, 0x80000000U, 0xffffffffU};
  unsigned j;
  for (j = 0; j < sizeof(values) / sizeof(values[0]); j++)
    printf("carry %u %u %u %u\n", n, values[j],
      sum_carry(n, values[j]), sum_carry_commuted(n, values[j]));
}
int main(int argc, char **argv)
{
  unsigned i, seed = 2048U;
  const unsigned small[] = {0, 1, 2, 3, 31, 32, 63, 64, 127, 128, 255, 256, 1000, 65535, 65536};
  const int signed_inputs[] = {INT_MIN, -65536, -1, 0, 1, 2, 31, 255, 1000, 65535};
  const unsigned large[] = {65537U, 92681U, 92682U, 0x7ffffffeU, 0x7fffffffU,
    0x80000000U, 0x80000001U, 0xfffffffeU, 0xffffffffU};
  const unsigned matrix_n[] = {0U, 1U, 2U, 31U, 256U, 1000U, 2343U, 2344U, 2345U};
  const int square_signed_n[] = {INT_MIN, -65536, -1, 0, 1, 2, 31, 1000, 1859, 1860};
  int extreme = argc > 1 && atoi(argv[1]) == 1;
  if (extreme) {
    for (i = 0; i < sizeof(large) / sizeof(large[0]); i++) {
      unsigned_case(large[i]);
      expanded_case(large[i], 0xffffffffU - large[i], 1);
      carry_matrix(large[i]);
    }
    for (i = 0; i < 256; i++) {
      seed = seed * 1664525U + 1013904223U;
      unsigned_case(seed);
      expanded_case(seed, seed ^ 0xffffffffU, 1);
      carry_matrix(seed);
    }
    return 0;
  }
  for (i = 0; i < sizeof(small) / sizeof(small[0]); i++) {
    unsigned_case(small[i]);
    expanded_case(small[i], 0xffffffffU - small[i], 0);
  }
  for (i = 0; i < sizeof(signed_inputs) / sizeof(signed_inputs[0]); i++) {
    int n = signed_inputs[i];
    printf("s %d %d %d\n", n, sum_signed(n), sum_negative_base(n));
  }
  for (i = 0; i < 256; i++) {
    seed = seed * 1664525U + 1013904223U;
    unsigned_case(seed % 1001U);
    expanded_case(seed % 1001U, seed, 0);
  }
  for (i = 0; i <= 128; i++) {
    unsigned observed;
    sum_observations = 0;
    observed = sum_observed(i);
    printf("control %u %u %u %u %u\n", i, sum_stride_two(i), sum_squares(i),
      observed, sum_observations);
  }
  for (i = 0; i < sizeof(matrix_n) / sizeof(matrix_n[0]); i++) {
    carry_matrix(matrix_n[i]);
    printf("square-boundary %u %u %u\n", matrix_n[i],
      sum_squares(matrix_n[i]), sum_squares_less(matrix_n[i]));
  }
  for (i = 0; i < sizeof(square_signed_n) / sizeof(square_signed_n[0]); i++) {
    int n = square_signed_n[i];
    printf("square-signed %d %d %d\n", n,
      sum_squares_signed(n), sum_squares_signed_reverse(n));
  }
  for (i = 0; i <= 128U; i++)
    printf("near %u %u %u\n", i,
      sum_carry_near(i, 0xfffffff0U), sum_product_near(i));
  return 0;
}
