# Benchmark 说明文档

## 1. 目标优化程序

目标是包含**循环不变量**的程序，例如带固定系数、固定除数的数组处理。表达式可以位于循环体开头或中间，也可以依赖另一个不变表达式。测试点围绕该目标优化程序进行设计；循环内重复形成的数组基地址也是不变表达式。

## 2. 项目结构与测试覆盖

```text
benchmarks/
├── README.md
├── run.py                      # 运行实验的全自动脚本
├── _build/                     # 存放两个编译器的符号链接
│   ├── ccomp                   # 指向项目根目录的 ccomp
│   └── clang                   # 指向本机 Clang
├── cases/
│   ├── knucleotide_lookup.c    # 官方片段：哈希表容量查找
│   ├── sha1_expand.c           # 官方片段：SHA-1 消息展开
│   ├── perlin_init.c           # 官方片段：Perlin 置换表复制
│   ├── fftw_init.c             # 官方片段：FFTW 浮点输入初始化
│   ├── arcode_model.c          # 官方片段：算术编码概率模型构建
│   ├── spass_stamp.c           # 官方片段：SPASS 时间戳溢出标记
│   ├── guarded_div.c           # 测试循环开头的不变除法
│   ├── middle_div.c            # 测试循环中间的不变除法
│   ├── dependent_div.c         # 测试相互依赖的不变表达式
│   ├── inline_div.c            # 测试内联函数中的不变表达式
│   ├── inline_variant.c        # 测试内联函数中随元素变化的表达式
│   ├── div64.c                 # 测试 64 位整数的不变除法
│   ├── float_div.c             # 测试浮点数的不变除法
│   ├── shift.c                 # 测试不变移位表达式
│   ├── store_mul.c             # 测试包含数组写入时的不变乘法
│   ├── large_body.c            # 测试较大循环体中的不变表达式
│   ├── nested_div.c            # 测试嵌套循环中的内层不变表达式
│   ├── conditional_div.c       # 测试条件保护下的不变除法
│   ├── break_div.c             # 测试提前退出循环时的不变除法
│   ├── continue_div.c          # 测试跳过部分迭代时的不变除法
│   ├── changing_div.c          # 测试分子每次迭代都变化的除法
│   ├── alias_div.c             # 测试通过别名写入后重新读取的除数
│   ├── volatile_div.c          # 测试通过 volatile 读写的除数
│   └── call_div.c              # 测试通过有副作用调用更新的除数
└── results/                    # 实验结果
    ├── result.csv
    ├── official.pdf            # 6 个官方来源片段
    ├── synthetic.pdf           # 18 个自制测试点
    └── compiled/               # 各程序的编译结果
        ├── compcert_O2/
        ├── compcert_O4/
        └── clang_O2/
```

测试分两组，所有测试点都参与正确性检查和完整程序计时：

- **官方来源组（6 个）**：来自官方测试仓库的 6 个不同程序，保留原片段的主要计算，补充输入、重复执行及校验和。6 项均核对了原函数及提取程序中实际发生的优化；它们用于检验命中后的程序级收益，不代表整个官方应用的性能，也不是命中率调查。
- **自制测试组（18 个）**：保留原有测试点，用于观察表达式类型、位置、依赖、控制流与内存副作用边界，以及收益和局限。

## 3. 结果内容

| 文件 | 内容 |
|---|---|
| `result.csv` | 完整实验为 24 项 × 3 种配置，共 72 行；包含输入、三组计时、均值、标准差、加速比及正确性检查记录 |
| `official.pdf` | 官方来源组：6 项，每项三根柱子，反映 6 个已命中实际片段的收益情况 |
| `synthetic.pdf` | 自制测试组：18 项，每项三根柱子，反映收益与局限 |
| `compiled/` | 按配置保存各程序的可执行文件、汇编 `.s`；两种 CompCert 配置另存新增 pass 前后的关键 RTL |

三种配置使用同一个 `ccomp` 和本机 Clang：

| 配置目录 | 编译选项 | 含义 |
|---|---|---|
| `compcert_O2` | `ccomp -O2` | 原版行为（基线） |
| `compcert_O4` | `ccomp -O4` | 开启 LICM |
| `clang_O2` | `clang -O2` | Clang 对照 |

## 4. 实验步骤

### Step 1：完成依赖与环境配置

先按 CompCert 构建要求准备 Coq、OCaml、Menhir、Make 和系统 C 工具链，并完成项目配置。

确保 `python3`、`ocaml` 和 `clang` 可以在终端中直接执行，并已有官方 `test/tools/xtime.ml`（仅使用计时工具）。脚本会从当前 `PATH` 查找 Clang 并创建符号链接。

```bash
python3 -m pip install matplotlib
```

### Step 2：构建当前编译器

在 CompCert 根目录下，完成配置后构建编译器：

```bash
make -j4 all
```

### Step 3：运行全部实验

脚本自动创建编译器链接、编译全部样例、检查结果并计时：

```bash
cd benchmarks
./run.py
```

仅检查正确性、不计时：

```bash
./run.py --check-only
```

完整实验结束后，结果位于 `benchmarks/results/`。完整实验会替换旧结果；`--check-only` 也会清理旧 CSV、图片和编译产物，重新编译并检查后仅保留编译产物，在终端报告检查结果。

```bash
./run.py --plot-only
```

将 `results/official.pdf` 和 `results/synthetic.pdf` 放在 `.tex` 文件的同一目录下，即可直接插入报告。
