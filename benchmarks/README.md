# Benchmark 说明文档

## 1. 目标优化程序

目标是包含**循环不变量**的程序，例如带固定系数、固定除数的数组处理。表达式可以位于循环体开头或中间，也可以依赖另一个不变表达式。测试点围绕该目标优化程序进行设计。

一个典型例子如下：

```c
uint32_t scan(const uint32_t *a, int n, uint32_t seed)
{
    uint32_t value = seed;
    int i;
    for (i = 0; i < n; i++) {
        uint32_t invariant = seed / (uint32_t)n; // 循环不变量
        value += a[i] ^ invariant;
    }
    return value;
}
```


## 2. 项目结构与测试覆盖

```text
benchmarks/
├── README.md
├── run.py                      # 运行实验的全自动脚本
├── _build/                     # 存放两个编译器的符号链接
│   ├── ccomp                   # 指向项目根目录的 ccomp
│   └── clang                   # 指向本机 Clang
├── cases/
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
    ├── result.svg
    └── compiled/               # 各程序的编译结果
        ├── compcert_O2/
        ├── compcert_O4/
        └── clang_O2/
```

18 个程序采用相同流程：**先用多组边界输入检查正确性，再用固定性能输入分别测量三个编译配置，生成平均耗时和加速比。**

性能测量固定在同一逻辑 CPU 上，每个配置计时三组，每组运行至少三遍、累计至少一秒用户 CPU 时间，最终取三组平均耗时。

| 实验 | 输入与方法 |
|---|---|
| 正确性检查 | 长度 `0, 1, 2, 31, 32, 33, 127, 128, 129` × 初始值 `0, 1, 2147483648, 4294967295` × 重复轮数 `1, 3`；与 Python 独立计算的结果比较 |
| 性能测量 | 长度 `65536`、初始值 `2048`；通常重复 `4096` 轮，`large_body` 为 `341` 轮，`nested_div` 为 `1024` 轮；测量整个程序 |



## 3. 结果内容

| 文件 | 内容 |
|---|---|
| `result.csv` | 18 项 × 3 种配置，共 54 行；输入参数、校验和、三组计时、均值、标准差、加速比、耗时变化百分比、正确性检查数量及通过状态，以及环境、编译参数、版本、产物路径和文件哈希 |
| `result.svg` | 主对比图：每项三根柱子，展示原版、LICM、Clang 的加速比 |
| `compiled/` | 按配置保存各程序的可执行文件、汇编 `.s`；两种 CompCert 配置另存新增 pass 前后的关键 RTL |

三种配置使用同一个 `ccomp` 和本机 Clang：

| 配置目录 | 编译选项 | 含义 |
|---|---|---|
| `compcert_O2` | `ccomp -O2` | 原版行为 |
| `compcert_O4` | `ccomp -O4` | 开启 LICM |
| `clang_O2` | `clang -O2` | Clang 对照 |

基线为`ccomp` 的 `-O2`（原版行为），加速比 = `CompCert -O2 平均耗时 / 当前配置平均耗时`。

## 4. 实验步骤

### Step 1：完成依赖与环境配置

先按 CompCert 构建要求准备 Coq、OCaml、Menhir、Make 和系统 C 工具链，并完成项目配置。

确保 `clang` 可以在终端中直接执行；脚本会从当前 `PATH` 自动查找它并创建符号链接。

### Step 2：构建当前编译器

需要先完成配置，再执行下述代码构建编译器：
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

完整实验结束后，结果位于 `benchmarks/results/`。每次运行会替换此前生成的结果；`--check-only` 仅保留编译产物并在终端报告检查结果，不生成性能表格和图片。
