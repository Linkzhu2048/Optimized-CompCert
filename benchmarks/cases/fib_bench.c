/* Standalone benchmark: same recurrence and default input as test/c/fib.c. */
#include <stdio.h>
#include <stdlib.h>

int fib(int n)
{
  if (n < 2) return 1;
  return fib(n - 1) + fib(n - 2);
}

int main(int argc, char **argv)
{
  int n = argc > 1 ? atoi(argv[1]) : 35;
  printf("fib(%d) = %d\n", n, fib(n));
  return 0;
}
