#!/usr/bin/env python3
"""Compile C benchmarks with five configurations, run each workload three times,
and write a detailed timing table and a speedup chart. Does not build CompCert.
"""
import argparse
import csv
import math
import os
import re
from pathlib import Path
import shutil
import statistics
import subprocess
import time

SUITE = Path(__file__).resolve().parent
ROOT = SUITE.parent
CASES = SUITE / 'cases'
BUILD = SUITE / '_build'
RESULTS = SUITE / 'results'
BASELINE = BUILD / 'ccomp.baseline'
CURRENT = BUILD / 'ccomp.optimized'
CLANG = BUILD / 'clang.bin'
ENV = {**os.environ, 'COMPCERT_CONFIG': str(ROOT / 'compcert.ini')}
MASK = (1 << 32) - 1
# Apply explicit pass switches after -O so all five configurations keep their meaning.
CONFIGS = {
    'baseline': [],
    'both': ['-faccumrec', '-fsumclosed'],
    'accumrec': ['-faccumrec', '-fno-sumclosed'],
    'sumclosed': ['-fno-accumrec', '-fsumclosed'],
    'clang': [],
}
LABELS = ['Original', 'Both passes', 'AccumRec', 'SumClosed', 'Clang']


# Independent expected values: formulas, dynamic programming and iteration.

def fib(n):
    if n < 2:
        return 1
    previous, current = 1, 1
    for _ in range(2, n + 1):
        previous, current = current, previous + current
    return current

def branched(n):
    total = 3
    while n > 0:
        if n < 5:
            total += n
            n -= 1
        else:
            total += n
            n -= 2
    return total

def expected_cases():
    lines = []
    for n in range(-2, 21):
        total = (n * (n + 1) // 2 if n > 0 else 0) - 7
        lines.append(f"{n} {fib(n)} {total} {total} {branched(n)}")
    for n in range(17):
        wrapped = (0xfffffff0 + n * (n + 1) // 2) % (2 ** 32)
        lines.append(f"unsigned {n} {wrapped}")
    lines += ["minimum 1 -7",
              f"rejected 55 11 2.50 24 {1 + sum(fib(n) for n in range(8))} 256",
              f"unsupported 75 {(0xfffffff0 + 8 * 0x70000001) % (2 ** 32)}"]
    return "\n".join(lines) + "\n"

def boundary_output():
    low, high = -(1 << 31), (1 << 31) - 1
    lines = []
    for n in [low, -1, 0, 1, 2, 31, 32, 63, 64, 65, high]:
        add = max(n, 0) * (max(n, 0) + 1) // 2 if n <= 64 else 0
        a, b = (low + add, high + add - 65 * max(n, 0)) if n <= 64 else (17, -17)
        lines.append(f"signed {n} {a} {b}")
    lines.append(f"unsigned-zero {0xfffffff0}")
    for distance in range(32, -1, -1):
        value = (0xfffffff0 + sum(range(MASK - 31, MASK - distance + 1))) & MASK
        lines.append(f"unsigned-high {distance} {value}")
    lines.append(f"deep {65535 * 65536 // 2}")
    return "\n".join(lines) + "\n"

def alternating(n):
    total = -11
    while n > 0:
        if n < 40:
            total += n - 80
            n -= 1
        elif n < 80:
            total += n
            n -= 3
        else:
            total += n * n
            n -= 7
    return total

def branch_output():
    values = [2, 3, 5]
    for n in range(3, 19):
        values.append(sum(values[n - 3:n]))
    lines = [f"three {n} {2 if n < 0 else values[n]} {2 if n < 0 else values[n]}" for n in range(-2, 19)]
    lines += [f"branch {n} {alternating(n)}" for n in range(101)]
    seed = 2048
    for _ in range(128):
        seed = (seed * 1664525 + 1013904223) & MASK
        n = seed % 1001
        lines.append(f"sample {n} {alternating(n)}")
    return "\n".join(lines) + "\n"

def rejection_output():
    lines, sub = [], 7
    for n in range(13):
        total = n * (n + 1) // 2
        if n:
            sub = n - sub
        # Alternating definitions select the base from the parity of depth.
        a, b = ((3, 5) if n % 2 == 0 else (5, 3))
        lines.append(f"reject {n} {(1 << 32) + total} {sub} {math.factorial(n)} "
                     f"{a + total} {b + total} {1 + total} {9 + total}")
    return "\n".join(lines) + "\n"

def workload_value(mode, n):
    if mode == 0:
        return 13 + n * (n + 1) // 2
    if mode == 2:
        return math.factorial(n % 12 + 1)
    total = 19
    while n >= 128:
        total += n * n
        n -= 3
    return (total + n * (n + 1) // 2) & MASK

def workload_output(mode, rounds, low=128, width=128):
    # Cache the input window; use a closed sum for the tail.
    values = {n: workload_value(mode, n) for n in range(low, low + width)}
    seed, checksum = 2048, 0
    for _ in range(rounds):
        seed = (seed * 1664525 + 1013904223) & MASK
        checksum = (checksum + values[low + seed % width]) & MASK
    return f"workload {mode} {rounds} {checksum}\n"

def sumclosed_output(extreme=False):
    def unsigned_line(n):
        tri = n * (n + 1) // 2
        return f"u {n} {tri & MASK} {(tri + 13) & MASK} {(tri + 0xfffffff0) & MASK}"

    def expanded_lines(n, a):
        carry = (a + n * (n + 1)) & MASK
        square = n * (n + 1) * (2 * n + 1) // 6
        result = [f"expanded {n} {a} {carry} {carry} {(square + 5) & MASK} {(square + 11) & MASK}"]
        if not extreme:
            stride = (a + 2 * sum(range(n, 1, -2))) & MASK
            result.append(f"stride {n} {a} {stride}")
        return result

    def carry_lines(n):
        return [f"carry {n} {a} {(a + n*(n+1)) & MASK} {(a + n*(n+1)) & MASK}"
                for a in [0, 1, 0x7fffffff, 0x80000000, MASK]]

    lines, seed = [], 2048
    if extreme:
        numbers = [65537, 92681, 92682, 0x7ffffffe, 0x7fffffff,
                   0x80000000, 0x80000001, 0xfffffffe, 0xffffffff]
        for n in numbers:
            lines += [unsigned_line(n), *expanded_lines(n, MASK - n), *carry_lines(n)]
        for _ in range(256):
            seed = (seed * 1664525 + 1013904223) & MASK
            lines += [unsigned_line(seed), *expanded_lines(seed, seed ^ MASK), *carry_lines(seed)]
        return "\n".join(lines) + "\n"

    numbers = [0, 1, 2, 3, 31, 32, 63, 64, 127, 128, 255, 256, 1000, 65535, 65536]
    for n in numbers:
        lines += [unsigned_line(n), *expanded_lines(n, MASK - n)]
    for n in [-(1 << 31), -65536, -1, 0, 1, 2, 31, 255, 1000, 65535]:
        tri = max(n, 0) * (max(n, 0) + 1) // 2
        lines.append(f"s {n} {tri} {tri - 7}")
    for _ in range(256):
        seed = (seed * 1664525 + 1013904223) & MASK
        n = seed % 1001
        lines += [unsigned_line(n), *expanded_lines(n, seed)]
    for n in range(129):
        stride = 3 + sum(range(n, 1, -2))
        squares = 5 + n * (n + 1) * (2 * n + 1) // 6
        lines.append(f"control {n} {stride} {squares} {7 + n * (n + 1) // 2} {n + 1}")
    for n in [0, 1, 2, 31, 256, 1000, 2343, 2344, 2345]:
        square = n * (n + 1) * (2*n + 1) // 6
        lines += carry_lines(n)
        lines.append(f"square-boundary {n} {(square + 5) & MASK} {(square + 11) & MASK}")
    for n in [-(1 << 31), -65536, -1, 0, 1, 2, 31, 1000, 1859, 1860]:
        k = max(n, 0)
        square = 5 + k * (k + 1) * (2*k + 1) // 6
        lines.append(f"square-signed {n} {square} {square}")
    for n in range(129):
        carry = (0xfffffff0 + n*n) & MASK
        product = (5 + n*(n+1)*(n+2)//3) & MASK
        lines.append(f"near {n} {carry} {product}")
    return "\n".join(lines) + "\n"

def extension_values(n, a, b):
    tri = n * (n + 1) // 2
    square = n * (n + 1) * (2 * n + 1) // 6
    # Alternating parameters: sum odd/even positions independently.
    first, second = (n + 1) // 2, n // 2
    multi = a * first * (n - first + 1) + b * second * (n - second)
    multi += first*b + second*a + a+b
    return [v & MASK for v in [17 + tri, 19 + square + 2 * tri - 10*n, multi, a + 2*tri]]

def extension_output(mode, rounds, low=128, width=128):
    seed, checksum = 2048, 0
    for _ in range(rounds):
        seed = (seed * 1664525 + 1013904223) & MASK
        n, a, b = low + seed % width, 3 + seed % 17, 5 + seed % 23
        value = 5 + n*(n+1)*(2*n+1)//6 if mode == 4 else extension_values(n, a, b)[mode]
        checksum = (checksum + value) & MASK
    return f'extension {mode} {rounds} {checksum}\n'

def extension_cases_output():
    seed, lines = 2048, []
    for i in range(320):
        seed = (seed * 1664525 + 1013904223) & MASK
        n, a, b = i if i < 65 else seed % 65, seed, seed ^ MASK
        tri = n * (n + 1) // 2
        repeated = a + b if n == 0 else a + (2*n + 1)*b
        total_params = a + b + 3 + 0xfffffffe + 5 + 6 + 7
        doubled, product = 1, 1
        for j in range(1, n+1):
            doubled = 2*doubled + j
            product *= j
        vs = extension_values(n, a, b) + [repeated, (n+1)*a, (n+1)*total_params + tri,
             doubled, product, a+b+3+4+5+6+7+8+tri, a+9*n*a, a+tri,
             extension_values(n, a, b)[2]]
        fields = [i, n, a, b, *(v & MASK for v in vs), n, (1<<32)+a+tri, 1]
        lines.append('case ' + ' '.join(map(str, fields)))
    return '\n'.join(lines) + '\n'

# Suites retain separate translation units where calling-context coverage matters.
SUITES = {
    'basic': ['accumrec_cases.c'],
    'fib': ['fib_bench.c'],
    'context': ['context_cases.c', 'context_recursive.c'],
    'boundary': ['boundary_cases.c'],
    'branches': ['branch_cases.c'],
    'rejection': ['rejection_cases.c'],
    'workload': ['workload_main.c', 'workload_functions.c'],
    'closed': ['sumclosed_main.c', 'sumclosed_functions.c'],
    'extension': ['recursion_extension_main.c', 'recursion_extension_functions.c',
                  'sumclosed_functions.c'],
    'coverage': ['recursion_extension_cases_main.c', 'recursion_extension_cases.c',
                 'recursion_extension_functions.c'],
}
def checks():
    return {
        'basic': [([], expected_cases())],
        'fib': [([n], f'fib({n}) = {fib(n)}\n') for n in [-2147483648, -2, -1, *range(26), 30, 35]],
        'context': [([], ''.join(f'context {n} {fib(n)+6*n+6}\n' for n in range(-2,21,2))+'observations 12\n')],
        'boundary': [([], boundary_output())],
        'branches': [([], branch_output())],
        'rejection': [([], rejection_output())],
        'workload': [([m,n], workload_output(m,n)) for m in range(3) for n in [0,1,2,127,4096,200000]]
            + [([0,257,low,width], workload_output(0,257,low,width))
               for low,width in [(16,16), (1024,1024)]],
        'closed': [([], sumclosed_output())],
        'extension': [([m,n], extension_output(m,n)) for m in range(5) for n in [0,1,2,17,1024]]
            + [([m,257,low,width], extension_output(m,257,low,width))
               for m in [3,4] for low,width in [(16,16), (1024,1024)]],
        'coverage': [([], extension_cases_output())],
    }


def run(command, cwd=ROOT):
    return subprocess.run(list(map(str, command)), cwd=cwd, env=ENV, check=True,
                          timeout=120, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE)


def prepare_compilers():
    """Keep local compiler entry points current without copying installed tools."""
    clang = shutil.which('clang')
    if clang is None:
        raise FileNotFoundError('clang not found on PATH')
    BUILD.mkdir(parents=True, exist_ok=True)
    targets = [(CURRENT, Path('../../ccomp')), (CLANG, Path(clang).resolve())]
    for entry, target in targets:
        if entry.is_symlink():
            if entry.readlink() == target:
                continue
            entry.unlink()
        elif entry.exists():
            raise FileExistsError(f'{entry} must be a compiler symlink; existing file left unchanged')
        entry.symlink_to(target)


RTL_CASES = {
    'sumclosed_functions': (
        ['sum_zero', 'sum_base', 'sum_wrap', 'sum_signed', 'sum_negative_base',
         'sum_squares', 'sum_carry', 'sum_carry_commuted', 'sum_squares_less',
         'sum_squares_signed', 'sum_squares_signed_reverse'],
        ['sum_stride_two', 'sum_carry_stride', 'sum_carry_near',
         'sum_product_near', 'sum_observed']),
    'recursion_extension_functions': (['suffix_sum', 'loop_sum'], ['chain_sum', 'multi_sum']),
    'workload_functions': (['workload_sum'], ['workload_branch', 'workload_product']),
}


def rtl_functions(path):
    return dict(re.findall(r'^([A-Za-z_]\w*)\([^\n]*\) \{\n(.*?)^\}',
                           path.read_text(), re.MULTILINE | re.DOTALL))


def rtl_has_cycle(body):
    """Read the printed RTL's explicit edges and fall-through successors."""
    labels = list(re.finditer(r'^\s*(\d+):', body, re.MULTILINE))
    if not labels:
        raise AssertionError('RTL function has no labeled nodes')
    graph = {}
    for i, label in enumerate(labels):
        block = body[label.end():labels[i+1].start() if i+1 < len(labels) else len(body)]
        successors = [int(n) for n in re.findall(r'\bgoto\s+(\d+)', block)]
        if not successors and not re.search(r'\breturn\b', block) and i+1 < len(labels):
            successors = [int(labels[i+1].group(1))]
        graph[int(label.group(1))] = successors
    entry = re.search(r'\bgoto\s+(\d+)', body[:labels[0].start()])
    entry = int(entry.group(1)) if entry else int(labels[0].group(1))
    visited, active = set(), set()

    def visit(node):
        if node in active:
            return True
        if node in visited:
            return False
        if node not in graph:
            raise AssertionError(f'unknown RTL successor {node}')
        visited.add(node)
        active.add(node)
        cyclic = any(visit(next_node) for next_node in graph[node])
        active.remove(node)
        return cyclic

    return visit(entry)


def validate_rtl():
    count = 0
    for source, (positive, negative) in RTL_CASES.items():
        before = rtl_functions(BUILD/'both'/f'{source}.rtl.9')
        after = rtl_functions(BUILD/'both'/f'{source}.rtl.10')
        for name in positive + negative:
            if name not in before or name not in after:
                raise AssertionError(f'missing RTL function: {name}')
        for name in positive:
            if before[name] == after[name] or not rtl_has_cycle(before[name]) or rtl_has_cycle(after[name]):
                raise AssertionError(f'expected SumClosed to eliminate loop: {name}')
            if f'"{name}"(' in after[name]:
                raise AssertionError(f'recursion remains after SumClosed: {name}')
            count += 1
        for name in negative:
            if before[name] != after[name]:
                raise AssertionError(f'unexpected SumClosed rewrite: {name}')
            count += 1
    print(f'PASS RTL: {count} function expectations (14 optimized, 9 unchanged)', flush=True)


def compile_all(baseline, level):
    binaries, commands = {}, {}
    for config, flags in CONFIGS.items():
        directory = BUILD/config
        directory.mkdir(parents=True, exist_ok=True)
        compiler = CLANG if config == 'clang' else baseline if config == 'baseline' else CURRENT
        opts = [str(compiler), level, *flags]
        if config != 'clang':
            opts += ['-stdlib', str(ROOT/'runtime')]
        commands[config] = opts
        objects = {}
        for source in sorted(CASES.glob('*.c')):
            obj = directory/(source.stem+'.o')
            dump = ['-drtl'] if config == 'both' and source.stem in RTL_CASES else []
            run([*opts, *dump, '-c', '-o', obj, source], cwd=directory)
            if dump:
                for stage in range(9):
                    (directory/f'{source.stem}.rtl.{stage}').unlink(missing_ok=True)
            objects[source.name] = obj
        binaries[config] = {}
        for suite, sources in SUITES.items():
            binary = directory/suite
            run([*opts, '-o', binary, *[objects[s] for s in sources]], cwd=directory)
            binaries[config][suite] = binary
    return binaries, commands


def validate(binaries):
    oracle = checks()
    for config, suites in binaries.items():
        count = 0
        for suite, examples in oracle.items():
            for args, expected in examples:
                actual = run([suites[suite], *args]).stdout
                if actual != expected:
                    raise AssertionError(f'output mismatch: {config}/{suite}, args={args}')
                count += len(expected.splitlines())
        print(f'PASS {config}: {count} output rows', flush=True)
    # The unoptimized recursive versions cannot execute full-width counters
    # within a practical test budget. Check closed forms against Python's
    # unbounded-integer oracle, separately from the five-way small-input tests.
    expected = sumclosed_output(extreme=True)
    if run([binaries['both']['closed'], 1]).stdout != expected:
        raise AssertionError('output mismatch: both/closed, full-width inputs')
    print(f'PASS both/full-width: {len(expected.splitlines())} output rows', flush=True)



def benchmark(binaries, commands, level):
    rounds = 2000000
    # Same call count at all scales; each row compares identical inputs across compilers.
    workloads = [('fib', 'Fibonacci (35)', 'fib', [35], f'fib(35) = {fib(35)}\n')]
    workloads += [(name, title, 'workload', [mode, rounds], workload_output(mode, rounds))
                  for mode, name, title in [(0, 'sum', 'Sum: n=128..255'),
                      (1, 'branch', 'Branched sum'), (2, 'product_control', 'Product control')]]
    workloads += [(name, title, 'extension', [mode, rounds], extension_output(mode, rounds))
                  for mode, name, title in [(0, 'suffix', 'Return-copy suffix'),
                      (1, 'chain', 'Successive additions'), (2, 'multi', 'Parameter exchange'),
                      (3, 'loop', 'Carry: n=128..255'), (4, 'squares', 'Squares: n=128..255')]]
    for label, low, width in [('small', 16, 16), ('large', 1024, 1024)]:
        for name, title, suite, mode, oracle in [
                ('sum', 'Sum', 'workload', 0, workload_output),
                ('loop', 'Carry', 'extension', 3, extension_output),
                ('squares', 'Squares', 'extension', 4, extension_output)]:
            workloads.append((f'{name}_{label}', f'{title}: n={low}..{low+width-1}',
                              suite, [mode, rounds, low, width], oracle(mode, rounds, low, width)))
    rows = []
    for work, title, suite, args, expected in workloads:
        group = []
        for config in CONFIGS:
            elapsed_ms = []
            for trial in range(3):
                start = time.perf_counter()
                completed = run([binaries[config][suite], *args])
                elapsed_ms.append((time.perf_counter() - start) * 1000)
                if completed.stdout != expected:
                    raise AssertionError(f'timing output mismatch: {config}/{work}, trial={trial+1}')
            mean = statistics.mean(elapsed_ms)
            group.append({
                'workload': work, 'title': title, 'configuration': config, 'optimization': level,
                'compiler': commands[config][0], 'flags': ' '.join(commands[config][1:]),
                'sources': ' '.join(SUITES[suite]), 'arguments': ' '.join(map(str, args)),
                'calls_per_process': 1 if work == 'fib' else rounds,
                'input_min': 35 if work == 'fib' else 1 if work == 'product_control' else args[2] if len(args) > 2 else 128,
                'input_max': 35 if work == 'fib' else 12 if work == 'product_control' else args[2]+args[3]-1 if len(args) > 2 else 255,
                'run1_ms': elapsed_ms[0], 'run2_ms': elapsed_ms[1], 'run3_ms': elapsed_ms[2],
                'mean_ms': mean, 'speedup': 0.0,
            })
        baseline_mean = group[0]['mean_ms']
        for row in group:
            row['speedup'] = baseline_mean / row['mean_ms']
            print(f"{work:16} {row['configuration']:10} {row['mean_ms']:10.3f} ms "
                  f"{row['speedup']:7.2f}x", flush=True)
        rows.extend(group)
    return rows


def report(rows, level):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    titles = [r['title'] for r in rows if r['configuration'] == 'baseline']
    colors = ['#7f8c8d', '#17a589', '#2980b9', '#e67e22', '#af7ac5']
    columns = 3
    fig, axes = plt.subplots(math.ceil(len(titles)/columns), columns,
                             figsize=(16, 3.8*math.ceil(len(titles)/columns)),
                             squeeze=False, layout='constrained')
    for ax in list(axes.flat)[len(titles):]:
        ax.set_visible(False)
    for index, (ax, title) in enumerate(zip(axes.flat, titles)):
        group = rows[index*5:(index+1)*5]
        values = [r['speedup'] for r in group]
        bars = ax.bar(range(5), values, color=colors)
        ax.bar_label(bars, labels=[f'{v:.2f}x' for v in values], padding=3, fontsize=8)
        ax.axhline(1, color='#555555', linestyle='--', linewidth=.8)
        ax.set_xticks(range(5), LABELS, rotation=30, ha='right')
        ax.set_ylabel('Speedup vs original CompCert')
        ax.set_ylim(0, max(values)*1.2)
        ax.set_title(title)
        ax.grid(axis='y', alpha=.2)
        ax.set_axisbelow(True)
    fig.suptitle(f'Recursive benchmarks {level}: mean of 3 independent runs', fontsize=14)
    RESULTS.mkdir(exist_ok=True)
    fig.savefig(RESULTS/'workloads.svg')
    plt.close(fig)
    with (RESULTS/'result.csv').open('w', newline='') as out:
        writer = csv.DictWriter(out, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f'Results: {RESULTS / "result.csv"} and {RESULTS / "workloads.svg"}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-O', choices=['0', '1', '2', '3', 's'], default='2',
                        help='optimization level for all compilers (default: 2); pass switches override -O')
    parser.add_argument('--baseline', type=Path, default=BASELINE)
    parser.add_argument('--check-only', action='store_true', help='check outputs without timing or plotting')
    args = parser.parse_args()
    baseline = args.baseline.resolve()
    if not baseline.is_file():
        parser.error('original baseline required; pass --baseline PATH')
    if not (ROOT/'ccomp').is_file():
        parser.error('build current CompCert first: make all')
    try:
        prepare_compilers()
    except OSError as error:
        parser.error(str(error))
    if not args.check_only:
        try:
            import matplotlib
        except ImportError:
            parser.error('matplotlib required; run with: uv run --no-project --with matplotlib python benchmarks/run.py')
    level = '-O' + args.O
    binaries, commands = compile_all(baseline, level)
    validate(binaries)
    validate_rtl()
    if not args.check_only:
        rows = benchmark(binaries, commands, level)
        report(rows, level)


if __name__ == '__main__':
    main()
