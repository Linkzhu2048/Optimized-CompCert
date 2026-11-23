#!/usr/bin/env python3
"""Whole-program benchmark: original CompCert, CompCert with LICM, and Clang.
Run ./run.py from benchmarks, or python3 benchmarks/run.py from the root.
Plotting requires matplotlib. Timing uses official xtime.ml;
Official-derived kernels and synthetic boundary cases are plotted separately;
the complete official applications are not measured.
"""
import argparse
from bisect import bisect_left
import csv
from functools import cache
import hashlib
import math
import os
from pathlib import Path
import platform
import shlex
import shutil
import statistics
import subprocess
import tempfile
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FixedLocator, FuncFormatter, NullLocator

SUITE = Path(__file__).resolve().parent
ROOT = SUITE.parent
BUILD = SUITE / '_build'
RESULTS = SUITE / 'results'
XTIME = ROOT / 'test/tools/xtime.ml'
ENV = {**os.environ, 'COMPCERT_CONFIG': str(ROOT / 'compcert.ini')}
CONFIGS = [('compcert_O2', 'ccomp', ('-O2',)),
           ('compcert_O4', 'ccomp', ('-O4',)),
           ('clang_O2', 'clang', ('-O2',))]
LABELS = {'compcert_O2': 'CompCert -O2', 'compcert_O4': 'CompCert -O4 (LICM)',
          'clang_O2': 'Clang -O2'}
COLORS = {'compcert_O2': '#8b95a5', 'compcert_O4': '#18866b', 'clang_O2': '#3976c5'}
COMPILED = RESULTS / 'compiled'
OFFICIAL = {'knucleotide_lookup': (65536, 256), 'sha1_expand': (4096, 256),
            'perlin_init': (65536, 16), 'fftw_init': (65536, 4),
            'arcode_model': (65536, 1024), 'spass_stamp': (65536, 256)}
SYNTHETIC = {'guarded_div': 4096, 'div64': 4096, 'float_div': 4096,
            'shift': 4096, 'store_mul': 4096, 'large_body': 341,
            'middle_div': 4096, 'dependent_div': 4096, 'inline_div': 4096,
            'nested_div': 1024, 'inline_variant': 4096,
            'conditional_div': 4096, 'break_div': 4096, 'continue_div': 4096,
            'changing_div': 4096, 'alias_div': 4096, 'volatile_div': 4096,
            'call_div': 4096}
PROGRAMS = {**OFFICIAL, **{name: (65536, rounds) for name, rounds in SYNTHETIC.items()}}
GROUPS = {'official': OFFICIAL, 'synthetic': SYNTHETIC}
MASK = (1 << 32) - 1
# Capacity choices from the original knucleotide hash table.
PRIMES = (53, 97, 193, 389, 769, 1543, 3079,
          6151, 12289, 24593, 49157, 98317, 196613, 393241,
          786433, 1572869, 3145739, 6291469, 12582917, 25165843, 50331653,
          100663319, 201326611, 402653189, 805306457, 1610612741, 3221225473, 4294967291)
# The reference permutation is part of the Perlin algorithm, not compiler output.
PERMUTATION = (
    151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,
    37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,
    57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,134,139,48,27,
    166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
    102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,200,196,135,130,
    116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,250,124,123,5,202,38,147,
    118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,223,183,170,213,
    119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,129,22,39,253,19,98,108,
    110,79,113,224,232,178,185,112,104,218,246,97,228,251,34,242,193,238,210,144,12,
    191,179,162,241,81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,184,84,
    204,176,115,121,50,45,127,4,150,254,138,236,205,93,222,114,67,29,24,72,243,141,
    128,195,78,66,215,61,156,180)


def log(message):
    print(message, flush=True)


def run(command, directory):
    command = [str(x) for x in command]
    result = subprocess.run(command, cwd=directory, env=ENV,
                            capture_output=True, text=True, timeout=300)
    if result.returncode:
        raise RuntimeError(f'Command failed ({result.returncode}): {shlex.join(command)}\n'
                           f'{result.stdout}{result.stderr}')
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_csv(path, rows):
    with path.open('w', newline='') as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def prepare(clang, timing):
    targets = {'ccomp': ROOT / 'ccomp', 'clang': Path(shutil.which(clang) or clang)}
    for name, target in targets.items():
        if not target.is_file():
            raise RuntimeError(f'Missing {name}: {target}; build CompCert with make -j4 all.')
    if timing and (not XTIME.is_file() or not shutil.which('ocaml')):
        raise RuntimeError('Timing requires test/tools/xtime.ml and ocaml on PATH.')
    BUILD.mkdir(exist_ok=True)
    for name, target in targets.items():
        link = BUILD / name
        link.unlink(missing_ok=True)
        link.symlink_to(os.path.relpath(target.resolve(), BUILD))


def boundary_expected(name, n, rounds, seed):
    """Python arithmetic model; no compiled C program is the small-input oracle."""
    a = [(i * 2654435761 + seed) & MASK for i in range(n + 1)]
    checksum = 0
    for _ in range(rounds):
        value, current = seed, seed
        if name == 'nested_div':
            for j in range(4):
                for item in a[:n]:
                    value = (value + (item ^ (((seed + j) & MASK) // n))) & MASK
        else:
            divisor = seed & 7
            for i in range(n):
                if name in {'conditional_div', 'break_div', 'continue_div', 'changing_div'}:
                    if name == 'break_div' and i == n // 2:
                        break
                    if name == 'continue_div' and i % 2 == 0:
                        continue
                    if name == 'changing_div':
                        current = (current * 1664525 + 1013904223) & MASK
                        divisor = n
                    q = current // divisor if divisor else 0
                else:
                    if name == 'alias_div':
                        a[0] = (a[0] * 1664525 + 1013904223) & MASK
                        divisor = a[0] | 1
                    elif name == 'volatile_div':
                        divisor = current | 1
                        current = (current * 1664525 + 1013904223) & MASK
                    else:
                        current = (current * 1664525 + 1013904223) & MASK
                        divisor = current | 1
                    q = seed // divisor
                value = (value + (a[i] ^ q)) & MASK
        checksum = (checksum + value) & MASK
        seed = (seed * 1664525 + 1013904223) & MASK
        a[0] = seed
    return f'{checksum}\n'


def official_expected(name, n, rounds, seed):
    """Reference models for the extracted algorithms and their repetition harnesses."""
    checksum = 0
    permutation = list(PERMUTATION)
    data = [((i + seed) & 255) if i < 128 or not (seed & 1) else 0 for i in range(n + 1)]
    pending = [False] * 20
    for _ in range(rounds):
        if name in {'sha1_expand', 'perlin_init', 'fftw_init', 'spass_stamp'}:
            for _ in range(n):
                if name == 'sha1_expand':
                    data = [(seed + i * 2654435761) & MASK for i in range(16)]
                    for i in range(16, 80):
                        t = data[i-3] ^ data[i-8] ^ data[i-14] ^ data[i-16]
                        data.append(((t << 1) | (t >> 31)) & MASK)
                    value = data[16] ^ data[79]
                elif name == 'perlin_init':
                    a, b = seed & 255, (seed >> 8) & 255
                    permutation[a], permutation[b] = permutation[b], permutation[a]
                    value = permutation[a]
                elif name == 'fftw_init':
                    value = (seed & 1023) + (seed & 65535)
                else:
                    if seed & 3 == 0:
                        pending = [True] * 20
                    value = int(pending[seed % 20])
                    pending[seed % 20] = False
                checksum = (checksum + value) & MASK
                seed = (seed * 1664525 + 1013904223 +
                        (0 if name == 'spass_stamp' else checksum)) & MASK
            continue
        counts = [0] * 256
        for byte in data[:n]:
            counts[byte] += 1
        if n >= 16384:
            scale = n // 16384 + 1
            counts = [c // scale if c > scale else int(c != 0) for c in counts]
        upper = 0
        checksum = (checksum * 33) & MASK  # ranges[0]
        for count in counts + [1]:  # EOF has count 1
            upper += count
            checksum = (checksum * 33 + upper) & MASK
        seed = (seed * 1664525 + 1013904223) & MASK
        data[0] = seed & 255
    return f'{checksum}\n'


@cache
def expected(name, n, rounds, seed):
    """Independent small-input oracle, including whole-program initialization."""
    if name == 'knucleotide_lookup':
        a = [(i * 2654435761 + seed) & MASK for i in range(n + 1)]
        checksum = 0
        for _ in range(rounds):
            checksum = (checksum + sum(PRIMES[bisect_left(PRIMES, x & 0x7fffffff)]
                                       for x in a[:n])) & MASK
            seed = (seed * 1664525 + 1013904223) & MASK
            a[0] = seed
        return f'{checksum}\n'
    if name in OFFICIAL:
        return official_expected(name, n, rounds, seed)
    if name in {'conditional_div', 'break_div', 'continue_div', 'changing_div',
                'alias_div', 'volatile_div', 'call_div', 'nested_div'}:
        return boundary_expected(name, n, rounds, seed)
    a = [(i * 2654435761 + seed) & MASK for i in range(n + 1)]
    b, checksum = [0] * n, 0
    for _ in range(rounds):
        value = seed
        if n:
            if name in {'guarded_div', 'large_body', 'middle_div', 'dependent_div', 'inline_div', 'inline_variant'}:
                invariant = seed // n
            elif name == 'div64':
                invariant = (((seed << 32) | seed) // n) & MASK
            elif name == 'float_div':
                invariant = int(float(seed) / float(n))
            elif name == 'shift':
                invariant = (seed << (n & 31)) & MASK
            else:
                invariant = (seed * n) & MASK
            for i in range(n):
                item = a[i] ^ ((((seed + a[i]) & MASK) // n)
                               if name == 'inline_variant' else invariant)
                if name in {'middle_div', 'dependent_div'}:
                    value = ((value + a[i]) & MASK) ^ invariant
                    if name == 'dependent_div':
                        value = (value + invariant // (n + 1)) & MASK
                elif name == 'large_body':
                    for _ in range(12):
                        value = ((value ^ item) * 1664525 + 1013904223) & MASK
                else:
                    value = (value + item) & MASK
                    b[i] = item
        checksum = (checksum + value) & MASK
        seed = (seed * 1664525 + 1013904223) & MASK
        a[0] = seed
    if name == 'store_mul':
        for item in b:
            checksum = (checksum * 33 + item) & MASK
    return f'{checksum}\n'


def build_and_check(directory):
    binaries, metadata = {}, {}
    for config, compiler, options in CONFIGS:
        executable = BUILD / compiler
        version = run([executable, '--version' if compiler == 'clang' else '-version'],
                      directory).stdout.splitlines()[0]
        flags = list(options)
        if compiler == 'ccomp':
            flags += ['-stdlib', str(ROOT / 'runtime'), '-drtl', '-dasm']
        output = COMPILED / config
        output.mkdir(parents=True, exist_ok=True)
        common = dict(compiler=str(executable.resolve()), compiler_version=version, link_flags='-lm',
                      compiler_sha256=digest(executable), flags=shlex.join(flags))
        for name in PROGRAMS:
            binary, assembly = output / name, output / f'{name}.s'
            source = SUITE / 'cases' / f'{name}.c'
            if compiler == 'ccomp':
                run([executable, *flags, '-o', binary, source, '-lm'], directory)
                # CompCert dumps beside the current working directory, not the C source.
                shutil.move(directory / f'{name}.s', assembly)
                for stage in (8, 9):
                    shutil.move(directory / f'{name}.rtl.{stage}', output)
                for dump in directory.glob(f'{name}.rtl.*'):
                    dump.unlink()
            else:
                run([executable, *flags, '-S', '-o', assembly, source], directory)
                # Measure the executable linked from the assembly retained as evidence.
                run([executable, *flags, '-o', binary, assembly, '-lm'], directory)
            binaries[name, config] = binary
            checks = 0
            # Empty / single iteration; shift count wrap; odd lengths and tails.
            lengths = [0, 1, 2, 31, 32, 33, 127, 128, 129]
            if name == 'arcode_model':
                lengths += [16383, 16384, 16385]  # rescaling threshold
            for n in lengths:
                for seed in [0, 1, 0x80000000, MASK]:
                    for rounds in [1, 3]:
                        arguments = [n, rounds, seed]
                        actual = run([binary, *arguments], directory).stdout
                        reference = expected(name, n, rounds, seed)
                        if actual != reference:
                            raise RuntimeError(f'Incorrect result: {name}/{config}/{arguments}: '
                                               f'expected {reference.strip()}, got {actual.strip()}')
                        checks += 1
            metadata[name, config] = dict(**common, correctness_checks=checks,
                correctness_passed=True, binary=str(binary.relative_to(RESULTS)),
                binary_sha256=digest(binary), assembly=str(assembly.relative_to(RESULTS)),
                assembly_sha256=digest(assembly),
                rtl_stages='8;9' if compiler == 'ccomp' else '')
        log(f'PASS {config}: {len(PROGRAMS)} programs, '
            f'{sum(metadata[n, config]["correctness_checks"] for n in PROGRAMS)} oracle checks')
    return binaries, metadata


def measure(binaries, metadata, directory, min_time, environment):
    rows = []
    for name in PROGRAMS:
        arguments = [*PROGRAMS[name], 2048]
        reference = run([binaries[name, 'compcert_O2'], *arguments], directory).stdout
        for config, _, _ in CONFIGS:
            if run([binaries[name, config], *arguments], directory).stdout != reference:
                raise RuntimeError(f'Full-workload result mismatch: {name}/{config}')
        samples = {config: [] for config, _, _ in CONFIGS}
        output_file = directory / 'timed-output.txt'
        for trial in range(3):
            # Each configuration starts one of the three trials.
            offset = trial % len(CONFIGS)
            for config, _, _ in CONFIGS[offset:] + CONFIGS[:offset]:
                result = run(['ocaml', 'unix.cma', XTIME, '-o', output_file,
                              '-mintime', min_time, '-minruns', 3, '-name', 'sample',
                              '--', binaries[name, config], *arguments], directory)
                if result.stderr or output_file.read_text() != reference:
                    raise RuntimeError(f'Timed execution failed: {name}/{config}: {result.stderr}')
                seconds = float(result.stdout.split()[0])
                if seconds <= 0:
                    raise RuntimeError(f'Insufficient timing resolution: {name}/{config}')
                samples[config].append(seconds)
        baseline = statistics.mean(samples['compcert_O2'])
        for config, _, _ in CONFIGS:
            mean = statistics.mean(samples[config])
            rows.append(dict(program=name, group='official' if name in OFFICIAL else 'synthetic',
                             source=name + '.c', configuration=config,
                             arguments=' '.join(map(str, arguments)), checksum=reference.strip(),
                             sample1_user_s=samples[config][0], sample2_user_s=samples[config][1],
                             sample3_user_s=samples[config][2], mean_user_s=mean,
                             stdev_user_s=statistics.stdev(samples[config]),
                             speedup=baseline / mean, runtime_change_percent=(mean / baseline - 1) * 100,
                             min_user_s_per_sample=min_time, min_runs_per_sample=3,
                             source_sha256=digest(SUITE / 'cases' / f'{name}.c'),
                             **environment, **metadata[name, config]))
            log(f'{name:18} {config:12} {mean:.3f} user s  {baseline / mean:.2f}x')
        # Preserve completed workloads if a later command fails.
        write_csv(RESULTS / 'result.csv', rows)
    return rows


def plot(rows, group):
    """A vector PDF suitable for direct inclusion in a LaTeX report."""
    programs = list(GROUPS[group])
    values = {(r['program'], r['configuration']): float(r['speedup'])
              for r in rows if r['group'] == group}
    title = 'Official-derived kernels' if group == 'official' else 'Synthetic coverage cases'
    low = min(0.5, min(values.values()) * .7)
    high = 2 ** math.ceil(math.log2(max(2, max(values.values()) * 1.12)))
    ticks = [2 ** k for k in range(math.ceil(math.log2(low)), int(math.log2(high)) + 1)]
    with plt.rc_context({'font.size': 8, 'pdf.fonttype': 42}):
        fig, ax = plt.subplots(figsize=(7.2, 4.6))
        for i, (config, _, _) in enumerate(CONFIGS):
            positions = [j + (i - 1) * .25 for j in range(len(programs))]
            ax.bar(positions, [values[name, config] for name in programs],
                   width=.24, color=COLORS[config], label=LABELS[config], zorder=2)
        ax.set_yscale('log', base=2)
        ax.set_ylim(low, high)
        ax.yaxis.set_major_locator(FixedLocator(ticks))
        ax.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f'{value:g}'))
        ax.yaxis.set_minor_locator(NullLocator())
        ax.set_xlim(-.6, len(programs) - .4)
        ax.set_xticks(range(len(programs)), programs, rotation=60, ha='right',
                      fontsize=7.5 if group == 'official' else 6)
        ax.set_ylabel('Speedup vs CompCert -O2 (higher is faster)')
        ax.set_title(title, fontsize=10, pad=34)
        ax.grid(axis='y', color='#dddddd', linewidth=.5, zorder=0)
        ax.axhline(1, color='#444444', linestyle='--', linewidth=.7, zorder=3)
        ax.legend(loc='lower center', bbox_to_anchor=(.5, 1.01), ncol=3,
                  frameon=False, fontsize=8)
        ax.spines[['top', 'right']].set_visible(False)
        fig.tight_layout()
        fig.savefig(RESULTS / f'{group}.pdf', bbox_inches='tight')
        plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--clang', default='clang', help='Clang executable')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check-only', action='store_true', help='validate without timing')
    mode.add_argument('--plot-only', action='store_true', help='redraw PDFs from existing result.csv')
    parser.add_argument('--min-time', type=float, default=1.0,
                        help='minimum cumulative user CPU seconds per measurement (default: 1)')
    args = parser.parse_args()
    if not 0 < args.min_time <= 30:
        parser.error('--min-time must be greater than zero and at most 30')
    RESULTS.mkdir(exist_ok=True)
    try:
        if args.plot_only:
            with (RESULTS / 'result.csv').open(newline='') as source:
                rows = list(csv.DictReader(source))
            for group in GROUPS:
                plot(rows, group)
            for group in GROUPS:
                (RESULTS / f'{group}.svg').unlink(missing_ok=True)
            log(f'Done. PDF charts: {RESULTS}')
            return
        prepare(args.clang, not args.check_only)
        # Replace the results generated by the previous run.
        for name in ['result.csv', 'result.svg', 'official.svg', 'synthetic.svg',
                     'official.pdf', 'synthetic.pdf']:
            (RESULTS / name).unlink(missing_ok=True)
        if COMPILED.exists():
            shutil.rmtree(COMPILED)
        cpu = None
        if hasattr(os, 'sched_setaffinity'):
            cpu = min(os.sched_getaffinity(0))
            os.sched_setaffinity(0, {cpu})
        log(f'CPU affinity: {cpu}; measuring complete programs, not isolated functions')
        environment = dict(platform=platform.platform(), cpu=cpu,
                           script_sha256=digest(Path(__file__)),
                           xtime_sha256=digest(XTIME) if XTIME.exists() else '')
        with tempfile.TemporaryDirectory(prefix='.work-', dir=RESULTS) as temporary:
            directory = Path(temporary)
            binaries, metadata = build_and_check(directory)
            if not args.check_only:
                rows = measure(binaries, metadata, directory, args.min_time, environment)
                for group in GROUPS:
                    plot(rows, group)
        log(f'Done. Results: {RESULTS}')
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        log(f'FAILED: {error}')
        parser.exit(1)


if __name__ == '__main__':
    main()
