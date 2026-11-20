/* Exercise optimized callees in callers with stack, heap, global memory,
   indirect calls and external calls; the callee is a separate C file. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int context_fib(int);
int (*entry)(int) = context_fib;
volatile int observations;

static int check_context(int n)
{
  volatile int stack_values[3];
  int source[3];
  int *heap = malloc(3 * sizeof(int));
  int value;
  if (!heap) exit(2);
  stack_values[0] = n;
  stack_values[1] = n + 7;
  stack_values[2] = n - 3;
  source[0] = n + 11;
  source[1] = 2 * n;
  source[2] = -9;
  memcpy(heap, source, sizeof(source));
  observations += 1;
  value = entry(n);
  value += stack_values[0] + stack_values[1] + stack_values[2];
  value += heap[0] + heap[1] + heap[2];
  free(heap);
  return value;
}

int main(void)
{
  int n;
  for (n = -2; n <= 20; n += 2)
    printf("context %d %d\n", n, check_context(n));
  printf("observations %d\n", observations);
  return 0;
}
