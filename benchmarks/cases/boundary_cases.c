/* Signed arithmetic stays representable, including both extreme base values. */
#include <limits.h>
#include <stdio.h>

int from_min(int n)
{
  if (n <= 0) return INT_MIN;
  if (n > 64) return 17;
  return from_min(n - 1) + n;
}

int from_max(int n)
{
  int saved;
  if (n <= 0) return INT_MAX;
  if (n > 64) return -17;
  saved = n - 65;
  return from_max(n - 1) + saved;
}

/* Includes UINT_MAX without attempting billions of recursive calls. */
unsigned near_max(unsigned n)
{
  if (n <= UINT_MAX - 32U) return 0xfffffff0U;
  return near_max(n - 1U) + n;
}

/* A larger finite chain: sum(65535) still fits signed 32-bit int. */
int triangular(int n)
{
  if (n <= 0) return 0;
  return triangular(n - 1) + n;
}

int main(void)
{
  int ns[] = {INT_MIN, -1, 0, 1, 2, 31, 32, 63, 64, 65, INT_MAX};
  int i;
  for (i = 0; i < 11; i++)
    printf("signed %d %d %d\n", ns[i], from_min(ns[i]), from_max(ns[i]));
  printf("unsigned-zero %u\n", near_max(0U));
  for (i = 32; i >= 0; i--)
    printf("unsigned-high %d %u\n", i, near_max(UINT_MAX - (unsigned)i));
  printf("deep %d\n", triangular(65535));
  return 0;
}
