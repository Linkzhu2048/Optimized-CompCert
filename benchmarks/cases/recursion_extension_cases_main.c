#include <stdio.h>
#include <stdlib.h>
extern unsigned suffix_sum(unsigned), chain_sum(unsigned);
extern unsigned multi_sum(unsigned, unsigned, unsigned), loop_sum(unsigned, unsigned);
extern unsigned repeated_args(unsigned, unsigned, unsigned), unchanged_arg(unsigned, unsigned);
extern unsigned rotate_eight(unsigned, unsigned, unsigned, unsigned, unsigned, unsigned, unsigned, unsigned);
extern unsigned doubled_result(unsigned), product_control(unsigned);
extern unsigned nine_parameters(unsigned, unsigned, unsigned, unsigned, unsigned, unsigned, unsigned, unsigned, unsigned);
extern unsigned nine_additions(unsigned, unsigned), effectful(unsigned, unsigned);
extern unsigned long long wide_control(unsigned, unsigned long long);
extern volatile unsigned observed;
int main(void)
{
  unsigned i, seed = 2048U;
  unsigned *heap = malloc(4U * sizeof(unsigned));
  unsigned (*volatile indirect)(unsigned, unsigned, unsigned) = multi_sum;
  if (!heap) return 2;
  for (i = 0; i < 320U; i++) {
    unsigned n, a, b, v[13];
    seed = seed * 1664525U + 1013904223U;
    n = i < 65U ? i : seed % 65U;
    a = seed; b = seed ^ 0xffffffffU;
    heap[0] = n; heap[1] = a; heap[2] = b; heap[3] = 0xdeadbeefU;
    observed = 0U;
    v[0] = suffix_sum(n); v[1] = chain_sum(n);
    v[2] = multi_sum(n, a, b); v[3] = loop_sum(n, a);
    v[4] = repeated_args(n, a, b); v[5] = unchanged_arg(n, a);
    v[6] = rotate_eight(n, a, b, 3U, 0xfffffffeU, 5U, 6U, 7U);
    v[7] = doubled_result(n); v[8] = product_control(n);
    v[9] = nine_parameters(n, a, b, 3U, 4U, 5U, 6U, 7U, 8U);
    v[10] = nine_additions(n, a); v[11] = effectful(n, a);
    v[12] = indirect(n, a, b);
    printf("case %u %u %u %u", i, n, a, b);
    for (unsigned j = 0; j < 13U; j++) printf(" %u", v[j]);
    printf(" %u %llu %u\n", observed, wide_control(n, 0x100000000ULL + a),
      heap[0] == n && heap[1] == a && heap[2] == b && heap[3] == 0xdeadbeefU);
  }
  free(heap);
  return 0;
}
