/* Positive and negative cases for the verified accumulator transform.
   Inputs below avoid signed C overflow. Unsigned wraparound is deliberate. */
#include <limits.h>
#include <stdio.h>

int fib(int n)
{
  if (n < 2) return 1;
  return fib(n - 1) + fib(n - 2);
}

/* The parameter itself is the saved addend: accumulation must precede
   the assignment that updates the loop parameter. */
int sum_right(int n)
{
  if (n <= 0) return -7;
  return sum_right(n - 1) + n;
}

int sum_left(int n)
{
  if (n <= 0) return -7;
  return n + sum_left(n - 1);
}

/* Two separate candidate call sites in the same function. */
int branched(int n)
{
  if (n <= 0) return 3;
  if (n < 5) return branched(n - 1) + n;
  return branched(n - 2) + n;
}

unsigned int unsigned_wrap(unsigned int n)
{
  if (n == 0) return 0xfffffff0U;
  return unsigned_wrap(n - 1) + n;
}

/* These yield scaled/immediate addition operations instead of the exact
   two-register add recognized by the first implementation. */
int scaled_add(int n)
{
  if (n <= 0) return 3;
  return scaled_add(n - 1) + n * 2;
}

unsigned int immediate_add(unsigned int n)
{
  if (n == 0) return 0xfffffff0U;
  return immediate_add(n - 1) + 0x70000001U;
}

volatile int observations;
int side_effect(int n)
{
  observations++;
  if (n <= 0) return 0;
  return side_effect(n - 1) + n;
}

double floating(int n)
{
  if (n <= 0) return 0.5;
  return floating(n - 1) + 0.25;
}

int two_args(int n, int bias)
{
  if (n <= 0) return 0;
  return two_args(n - 1, bias) + bias;
}

int mixed_calls(int n)
{
  if (n <= 0) return 1;
  return mixed_calls(n - 1) + fib(n - 1);
}

int doubled(int n)
{
  int result;
  if (n <= 0) return 1;
  result = doubled(n - 1);
  return result + result;
}

int main(void)
{
  int n;
  for (n = -2; n <= 20; n++)
    printf("%d %d %d %d %d\n", n, fib(n), sum_right(n), sum_left(n), branched(n));
  for (n = 0; n <= 16; n++)
    printf("unsigned %d %u\n", n, unsigned_wrap((unsigned int)n));
  printf("minimum %d %d\n", fib(INT_MIN), sum_left(INT_MIN));
  n = side_effect(10);
  printf("rejected %d %d %.2f %d %d %d\n", n, observations,
    floating(8), two_args(8, 3), mixed_calls(8), doubled(8));
  printf("unsupported %d %u\n", scaled_add(8), immediate_add(8));
  return 0;
}
