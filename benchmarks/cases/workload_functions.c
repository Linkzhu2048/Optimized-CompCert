/* Separate compilation prevents the benchmark caller from precomputing calls.
   All arithmetic is unsigned; wraparound is defined. No LTO is used. */
unsigned workload_sum(unsigned n)
{
  if (n == 0) return 13U;
  return workload_sum(n - 1U) + n;
}

unsigned workload_branch(unsigned n)
{
  unsigned saved;
  if (n == 0) return 19U;
  if (n < 128U) return workload_branch(n - 1U) + n;
  saved = n * n;
  return workload_branch(n - 3U) + saved;
}

/* Negative control: post-call multiplication is outside AccumRec's pattern. */
unsigned workload_product(unsigned n)
{
  if (n <= 1U) return 1U;
  return workload_product(n - 1U) * n;
}
