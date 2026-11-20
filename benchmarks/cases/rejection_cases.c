/* Correct rejection is part of correctness: these functions must stay intact. */
#include <stdio.h>

long long wide_sum(int n)
{
  if (n <= 0) return 0x100000000LL;
  return wide_sum(n - 1) + n;
}

int subtract_result(int n)
{
  if (n <= 0) return 7;
  return n - subtract_result(n - 1);
}

int product(int n)
{
  if (n <= 1) return 1;
  return product(n - 1) * n;
}

int mutual_b(int n);
int mutual_a(int n)
{
  if (n <= 0) return 3;
  return mutual_b(n - 1) + n;
}
int mutual_b(int n)
{
  if (n <= 0) return 5;
  return mutual_a(n - 1) + n;
}

int stack_local(int n)
{
  volatile int saved[2];
  saved[0] = n;
  saved[1] = 1;
  if (n <= 0) return saved[1];
  return stack_local(n - 1) + saved[0];
}

int indirect(int n);
int (*recursive_pointer)(int) = indirect;
int indirect(int n)
{
  if (n <= 0) return 9;
  return recursive_pointer(n - 1) + n;
}

int main(void)
{
  int n;
  for (n = 0; n <= 12; n++)
    printf("reject %d %lld %d %d %d %d %d %d\n", n, wide_sum(n),
      subtract_result(n), product(n), mutual_a(n), mutual_b(n), stack_local(n), indirect(n));
  return 0;
}
