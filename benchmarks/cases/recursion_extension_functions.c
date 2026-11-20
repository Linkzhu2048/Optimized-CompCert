/* Pure arithmetic kernels, compiled separately from their callers. */
unsigned suffix_sum(unsigned n)
{
  unsigned result, copy;
  if (n == 0U) return 17U;
  result = suffix_sum(n - 1U) + n;
  copy = result;
  goto finished;
finished:
  return copy;
}
unsigned chain_sum(unsigned n)
{
  unsigned a, b, c;
  if (n == 0U) return 19U;
  a = n * n;
  b = n - 7U;
  c = n - 3U;
  return ((chain_sum(n - 1U) + a) + b) + c;
}
unsigned multi_sum(unsigned n, unsigned a, unsigned b)
{
  unsigned saved;
  if (n == 0U) return a + b;
  saved = n * a + b;
  return multi_sum(n - 1U, b, a) + saved;
}
unsigned loop_sum(unsigned n, unsigned a)
{
  if (n == 0U) return a;
  if (n == 0U) return 13U; /* Redundant guard: exercise conditional threading. */
  return loop_sum(n - 1U, a + n) + n;
}
