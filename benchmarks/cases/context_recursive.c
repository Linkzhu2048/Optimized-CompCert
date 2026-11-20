/* Compiled separately from context_cases.c, including a public recursive entry. */
int context_fib(int n)
{
  if (n < 2) return 1;
  return context_fib(n - 1) + context_fib(n - 2);
}
