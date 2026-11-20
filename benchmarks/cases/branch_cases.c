/* Different base returns, non-unit recursion steps and multiple kept calls. */
#include <stdio.h>

/* Unstaged expression: frontend emits two additions after the last call. */
int three_calls_expression(int n)
{
  if (n <= 0) return 2;
  if (n == 1) return 3;
  if (n == 2) return 5;
  return three_calls_expression(n - 1) + three_calls_expression(n - 2)
       + three_calls_expression(n - 3);
}

/* Explicit full-expression boundary computes the saved sum before call 3. */
int three_calls(int n)
{
  int a, b, saved;
  if (n <= 0) return 2;
  if (n == 1) return 3;
  if (n == 2) return 5;
  a = three_calls(n - 1);
  b = three_calls(n - 2);
  saved = a + b;
  return saved + three_calls(n - 3);
}

int alternating(int n)
{
  int saved;
  if (n <= 0) return -11;
  if (n < 40) {
    saved = n - 80;
    return alternating(n - 1) + saved;
  }
  if (n < 80) return n + alternating(n - 3);
  saved = n * n;
  return alternating(n - 7) + saved;
}

int main(void)
{
  unsigned seed = 2048U;
  int i, n;
  for (n = -2; n <= 18; n++)
    printf("three %d %d %d\n", n, three_calls(n), three_calls_expression(n));
  for (n = 0; n <= 100; n++)
    printf("branch %d %d\n", n, alternating(n));
  /* Fixed seed: reproducible wider inputs, independent Python oracle. */
  for (i = 0; i < 128; i++) {
    seed = seed * 1664525U + 1013904223U;
    n = (int)(seed % 1001U);
    printf("sample %d %d\n", n, alternating(n));
  }
  return 0;
}
