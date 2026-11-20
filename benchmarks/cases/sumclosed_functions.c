/* Separate translation unit: no LTO or caller-side constant folding. */
unsigned sum_zero(unsigned n)
{
  if (n == 0U) return 0U;
  return sum_zero(n - 1U) + n;
}
unsigned sum_base(unsigned n)
{
  if (n == 0U) return 13U;
  return sum_base(n - 1U) + n;
}
unsigned sum_wrap(unsigned n)
{
  if (n != 0U) return n + sum_wrap(n - 1U);
  return 0xfffffff0U;
}
int sum_signed(int n)
{
  if (n <= 0) return 0;
  return sum_signed(n - 1) + n;
}
int sum_negative_base(int n)
{
  if (n > 0) return n + sum_negative_base(n - 1);
  return -7;
}
unsigned sum_stride_two(unsigned n)
{
  if (n < 2U) return 3U;
  return sum_stride_two(n - 2U) + n;
}
unsigned sum_squares(unsigned n)
{
  unsigned saved;
  if (n == 0U) return 5U;
  saved = n * n;
  return sum_squares(n - 1U) + saved;
}
unsigned sum_carry(unsigned n, unsigned a)
{
  if (n == 0U) return a;
  return sum_carry(n - 1U, a + n) + n;
}
unsigned sum_carry_commuted(unsigned n, unsigned a)
{
  if (n >= 1U) return n + sum_carry_commuted(n - 1U, n + a);
  return a;
}
unsigned sum_squares_less(unsigned n)
{
  unsigned saved;
  if (n < 1U) return 11U;
  saved = n * n;
  return saved + sum_squares_less(n - 1U);
}
/* Defined signed arithmetic for the tested positive inputs n <= 1860. */
int sum_squares_signed(int n)
{
  int saved;
  if (n <= 0) return 5;
  saved = n * n;
  return sum_squares_signed(n - 1) + saved;
}
int sum_squares_signed_reverse(int n)
{
  int saved;
  if (n > 0) {
    saved = n * n;
    return saved + sum_squares_signed_reverse(n - 1);
  }
  return 5;
}
/* Near misses must not receive the carry/square closed forms. */
unsigned sum_carry_near(unsigned n, unsigned a)
{
  if (n == 0U) return a;
  return sum_carry_near(n - 1U, a + n - 1U) + n;
}
unsigned sum_product_near(unsigned n)
{
  unsigned saved;
  if (n == 0U) return 5U;
  saved = n * (n + 1U);
  return sum_product_near(n - 1U) + saved;
}
/* Negative control: the stride is two, so unit-stride rules must reject it. */
unsigned sum_carry_stride(unsigned n, unsigned a)
{
  if (n < 2U) return a;
  return sum_carry_stride(n - 2U, a + n) + n;
}
volatile unsigned sum_observations;
unsigned sum_observed(unsigned n)
{
  sum_observations++;
  if (n == 0U) return 7U;
  return sum_observed(n - 1U) + n;
}
