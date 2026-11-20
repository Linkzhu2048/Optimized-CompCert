# 递归求和优化实验

## 1. 新增 pass 与适用程序

- **AccumRec**：把直接自递归返回后的整数加法移入累加器，减少递归调用；支持连续加法和多参数递归，并整理返回后缀与循环控制流。适用于 fib、递归求和、分支求和等纯整数计算；fib 仍保留部分递归。
- **SumClosed**：将匹配的单位步长循环变为 O(1) 计算：普通求和 `base + n*(n+1)/2`、平方和 `base + n*(n+1)*(2*n+1)/6`，以及 `f(n,a)=f(n-1,a+n)+n` 的 `a+n*(n+1)`。支持加法操作数交换、无符号 `n==0` / `n<1` 及对应反向条件；有符号单参数形式支持 `n<=0` / `n>0`。公式按 32 位整数语义实现，平方和避免计算可能溢出的 64 位三次乘积。

SumClosed 内部的 `Basic`、`Affine`、`Square` 是三种已证明的识别规则，仍只有一个 SumClosed pass、一个实现文件和一个证明文件。目前 `chain_sum` 的混合多项式与 `multi_sum` 的参数交替尚未闭式化；任意循环形状也不保证识别。

目标平台为 x86-64 Linux。浮点、乘法归约、间接/互递归和带内存副作用的递归不做累加器优化；测试保留这些负例。两份完整正确性证明随编译器构建。

## 2. Benchmark 目录

```text
benchmarks/
├── README.md
├── run.py                         编译、核对、计时、表格与绘图
├── cases/                         15 个 C 文件，组成 10 组程序
│   ├── accumrec_cases.c            基本正反例
│   ├── fib_bench.c                 Fibonacci
│   ├── boundary_cases.c            整数边界
│   ├── branch_cases.c              分支递归
│   ├── rejection_cases.c           不适用的递归形式
│   ├── context_cases.c             调用环境测试入口
│   ├── context_recursive.c         被调用的递归函数
│   ├── workload_main.c             基础性能入口，支持输入规模
│   ├── workload_functions.c        求和、分支、乘法负对照
│   ├── sumclosed_main.c            参数组合、signed/unsigned 边界检查
│   ├── sumclosed_functions.c       普通/平方/双参数闭式与近似反例
│   ├── recursion_extension_main.c  扩展与平方和性能入口，支持输入规模
│   ├── recursion_extension_functions.c  后缀、连续加法、多参数、循环
│   ├── recursion_extension_cases_main.c 扩展边界测试入口
│   └── recursion_extension_cases.c      参数与副作用边界
├── results/                       当前结果
│   ├── result.csv                 五种配置的详细耗时与加速比
│   └── workloads.svg              加速比图，每项负载五根柱
└── _build/                        可执行文件、对象文件和临时输出
    ├── ccomp.baseline             原版 CompCert 可执行文件
    ├── ccomp.optimized → ../../ccomp  当前 CompCert 入口
    └── clang.bin → 系统 Clang     Clang 入口
```

## 3. CompCert 根目录下的新增与修改

下面列出新增的 21 个源码/测试/脚本/说明文件，以及修改的 7 个原有编译与构建文件。

```text
CompCert-3.17/
├── Makefile                           [修改] 注册新增模块
├── backend/
│   ├── AccumRec.v                     [新增] 累加器递归优化
│   ├── AccumRecproof.v                [新增] 对应完整证明
│   ├── SumClosed.v                    [新增] 普通、双参数、平方求和闭式
│   └── SumClosedproof.v               [新增] 三种规则及组合的完整证明
├── driver/
│   ├── Compiler.v                     [修改] 流水线与正确性组合
│   ├── Compopts.v                     [修改] 优化开关接口
│   ├── Clflags.ml                     [修改] 开关默认值
│   └── Driver.ml                      [修改] 命令行选项
├── extraction/
│   └── extraction.v                   [修改] 开关的 OCaml 映射
├── x86/
│   └── PrintOp.ml                     [修改] 64 位立即数加法的 RTL 打印
└── benchmarks/           [新增] 详见上节
    ├── README.md
    ├── run.py
    └── cases/                         15 个 C 文件
```

## 4. 人工实验操作指南

以下命令均在 **CompCert 根目录**执行，使用已经配置好的构建环境。构建方式与原版相同：

```bash
make all
# 或并行构建，例如使用 4 个任务：
make -j4 all
```

实验使用的三个编译器入口统一放在 `benchmarks/_build/`：`ccomp.baseline` 是原版可执行文件，`ccomp.optimized` 链接到根目录的 `ccomp`，`clang.bin` 链接到系统安装的 Clang。当前版三种 pass 配置共用 `ccomp.optimized`。重新执行 `make all` 后，入口会指向更新后的编译器；脚本自动准备链接，只编译 C 测试程序，不构建编译器。

安装好 Python 与 matplotlib 后运行：

```bash
python3 benchmarks/run.py -O2
```

当前 Python 没有 matplotlib 时，可使用已有的 uv 环境：

```bash
uv run --no-project --with matplotlib python benchmarks/run.py -O2
```

`-O2` 可替换为 `-O0`、`-O1`、`-O3` 或 `-Os`，对五种配置统一生效。CompCert 原有的 `-O1/-O2/-O3` 含义相同。脚本在 `-O` 之后显式设置新增 pass 的开关，因此即便选 `-O0`，下表中指定开启的新增 pass 仍开启。

| 对比配置 | 新增 pass 的设置 |
|---|---|
| 原版 CompCert | 原版可执行文件，无新增 pass |
| 当前 CompCert：两个 pass | `-faccumrec -fsumclosed` |
| 当前 CompCert：仅 AccumRec | `-faccumrec -fno-sumclosed` |
| 当前 CompCert：仅 SumClosed | `-fno-accumrec -fsumclosed` |
| Clang | 同一 `-O` 级别 |

正确性检查在五种配置下各核对 1,910 行输出，并仅对两个 pass 开启版本检查 1,855 行全宽无符号输入，合计 11,405 行。覆盖独立的 `n/a` 组合、signed 平方和（正输入不超过 1860）、unsigned 平方和首次回绕附近的 2343/2344/2345、等价写法、非单位步长和近似反例；预期值由 Python 独立计算。巨大输入不运行原版递归。

脚本还检查 23 个函数的 `.rtl.9` / `.rtl.10`：14 个正例须消除可达循环，9 个反例须保持 SumClosed 前后函数体相同。RTL 文件仅在 `_build/both/` 中生成。上述检查均包含在 `--check-only` 中，不代替两份完整证明。

实验顺序：编译 C 程序 → 核对输出 → 每项性能负载在每种配置下独立运行 **3 次** → 取算术平均值 → 生成一个表格和一张图片。正确性检查不计入性能测量。共 15 项性能负载：原有八项、新增平方和，以及普通求和/双参数累加/平方和各自的小、大输入。三种求和的输入范围为 16…31、128…255、1024…2047。fib 输入为 35，只调用一次；其余每次进程均调用计算函数 200 万次，因此同类不同规模可以直接比较进程总耗时。

运行时间是进程从启动到结束的实际耗时，单位为毫秒，包含测试程序自身的循环和校验和开销，不含编译及 Python 预期值计算。**加速比 = 原版平均耗时 ÷ 对应配置平均耗时**，原版为 1。仅 SumClosed 不负责消除递归，因此在仍为递归形式的程序上可能没有收益。

最终结果：

- `benchmarks/results/result.csv`：75 行（15 项 × 5 配置），包含输入范围、调用次数、源码、编译选项、三次运行时间、平均时间及加速比。
- `benchmarks/results/workloads.svg`：一张图，每项负载五根柱，仅展示加速比。

当前 `-O2` 实验完成：11,405 行输出与 23 项 RTL 检查通过，225 次计时生成 75 行表格。普通求和三个规模的本轮均值均优于 Clang，速度比约 1.10…1.13；平方和三个规模均快于原版，但均慢于 Clang。三次样本不能用于断言普遍或统计显著的优势，详细分析见 Assignment 目录的 `TEST_REPORT.md`。

每次完整运行覆盖这两个结果文件。基线位置不同时追加 `--baseline /path/to/original/ccomp`；只核对输出可使用 `python3 benchmarks/run.py -O2 --check-only`。
