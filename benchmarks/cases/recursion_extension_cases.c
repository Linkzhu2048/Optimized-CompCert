/* Additional coverage: unsigned arithmetic deliberately permits wraparound. */
unsigned repeated_args(unsigned n, unsigned a, unsigned b)
{
  if (!n) return a + b;
  return repeated_args(n - 1U, b, b) + a + b;
}
unsigned unchanged_arg(unsigned n, unsigned a)
{
  if (!n) return a;
  return unchanged_arg(n - 1U, a) + a;
}
unsigned rotate_eight(unsigned n, unsigned a, unsigned b, unsigned c,
                      unsigned d, unsigned e, unsigned f, unsigned g)
{
  if (!n) return a + b + c + d + e + f + g;
  return rotate_eight(n - 1U, b, c, d, e, f, g, a)
    + n + a + b + c + d + e + f + g;
}
unsigned doubled_result(unsigned n)
{
  unsigned r;
  if (!n) return 1U;
  r = doubled_result(n - 1U);
  return r + r + n;
}
unsigned product_control(unsigned n)
{
  if (!n) return 1U;
  return product_control(n - 1U) * n;
}
unsigned nine_parameters(unsigned n, unsigned a, unsigned b, unsigned c,
                        unsigned d, unsigned e, unsigned f, unsigned g, unsigned h)
{
  if (!n) return a + b + c + d + e + f + g + h;
  return nine_parameters(n - 1U, a, b, c, d, e, f, g, h) + n;
}
unsigned nine_additions(unsigned n, unsigned a)
{
  if (!n) return a;
  return nine_additions(n - 1U, a) + a + a + a + a + a + a + a + a + a;
}
volatile unsigned observed;
unsigned effectful(unsigned n, unsigned a)
{
  unsigned r;
  if (!n) return a;
  r = effectful(n - 1U, a) + n;
  observed = observed + 1U;
  return r;
}
unsigned long long wide_control(unsigned n, unsigned long long a)
{
  if (!n) return a;
  return wide_control(n - 1U, a) + n;
}
