# Rhema 编译与题目生成 Pipeline

本文从经典编译器的三阶段架构出发，说明 Rhema 如何把 `.rhm` 文法转换为可以在 WeBWorK 中运行和判分的 `.pg` 文件。

## 总览

```text
.rhm 源文件
   │
   ▼
Frontend 前端
Lexer → Parser → AST → Loader → Checker
   │
   ▼
Rhema_check.spec（Checked IR）
   │
   ▼
Middle-end 中端
Question/Set 选择 → Seed → 难度预算 → 规则展开
→ 属性计算 → Derivation Tree
   │
   ▼
Rhema_engine.question（Question IR）
   │
   ▼
Backend 后端
Typed Answer Lowering → Context/Macro 选择 → PGML 排版
   │
   ▼
WeBWorK .pg + AST 文本 + 可视化 HTML
```

三个阶段最重要的输出边界是：

```text
Frontend 输出：Rhema_check.spec
Middle-end 输出：Rhema_engine.question
Backend 输出：WeBWorK .pg
```

## 1. Frontend：读取并检查 `.rhm`

前端负责把用户编写的 Rhema 文法转换成生成引擎可以安全使用的内部表示。

### 1.1 Lexer：词法分析

Lexer 把 `.rhm` 文本拆成 token，例如：

- `attribute`、`synth`、`start`、`question`、`set`
- 标识符、整数和字符串
- `$1`、`$1.value`
- `->`、`+`、`-`、`and`、`or`

对应实现为 `generator/rhema/lib/rhema_lexer.mll`。

### 1.2 Parser：语法分析

Menhir Parser 根据 Rhema 语言语法构造 `Rhema_ast.file`。

例如：

```rhema
E -> E + E when cost > 0 {
  cost = -1
  value = $1.value + $3.value
}
```

会被解析成一条 AST rule，其中保存：

- 左侧 nonterminal `E`
- 右侧 symbols
- guard
- attribute equations
- 源文件位置

AST 表示“源文件写了什么”，但此时还不能保证这些内容在语义上合法。

### 1.3 Loader：模块与文件加载

Loader 负责处理文件之间的关系：

- `include "core.rhm"`：把另一个文件的声明合并到当前命名空间。
- `import "calculus.rhm" as calc`：把另一个文件加载成独立模块。
- 搜索当前目录、`-I`、`RHEMA_PATH` 和安装后的 `share/rhema`。
- 检测循环 include/import。
- 缓存已经加载和检查的模块。

对应实现为 `generator/rhema/lib/rhema_load.ml`。

### 1.4 Checker：语义分析

Checker 验证 AST 是否满足 Rhema 的语义规则，包括：

- start symbol 和 production 是否存在；
- attribute 是否已经声明；
- inherited/synthesized attribute 的使用方向是否正确；
- `$1.value` 等 child reference 是否越界；
- guard、require 和 builtin 调用是否合法；
- named question 是否包含完整的 start、prompt 和 answer；
- set 引用的 module、question 和 budget 是否存在。

检查完成后，Checker 生成：

```text
Rhema_check.spec
```

它是 Rhema 的 **Checked IR（经过检查的中间表示）**，包含：

- inherited attributes 及初始值；
- random、let 和 synthesized attributes；
- checked production rules；
- precedence；
- imports；
- named questions；
- sets；
- prompt、answer、context 和 width。

对应实现为 `generator/rhema/lib/rhema_check.ml`。

## 2. Middle-end：把文法实例化成具体题目

传统编译器的中端通常负责优化 IR。Rhema 的中端有所不同：它是一个 **generative middle-end**，负责根据 seed、难度预算和生成规则，把声明式文法实例化成具体题目。

### 2.1 输入

中端主要接收：

```text
Rhema_check.spec
+ question 或 set 名称
+ assignment/student seed
+ inherited attribute 初值
```

### 2.2 Seed 与可复现性

Rhema 根据 assignment 和 student ID 生成稳定 seed：

```text
assignment
→ 一份固定题卷

assignment + student
→ 该学生固定的个性化题卷
```

显式的 `--seed` 可以覆盖自动 seed，主要用于工具和测试。

因此相同 assignment/student 输入会生成相同题目，便于重新生成、测试和调试。

### 2.3 单题生成

`Rhema_engine` 的主要流程是：

1. 生成 question-level random values。
2. 按声明顺序计算 `let`。
3. 从 start symbol 开始递归展开。
4. 使用 `when` guard 过滤 production。
5. 排除会使 difficulty budget 变成负数的 production。
6. 在合法 production 中按照 `weight` 随机选择。
7. 应用 budget 消耗。
8. 将 `split` budget 分配给可递归 child nodes。
9. 递归生成 children。
10. 自底向上计算 synthesized attributes。
11. 检查 `require`。
12. 必要时执行局部或整题重试。

难度预算不是在题目生成之后计算的分数，而是在生成树中必须实际消耗的资源。例如 `cost = 8` 会影响哪些 production 合法，以及各个 child 能获得多少预算。

### 2.4 Question IR

单题生成完成后得到：

```text
Rhema_engine.question
```

其中包含：

- `prompt`；
- 一个或多个 typed answers；
- WeBWorK context；
- answer width；
- question-level globals；
- attributed derivation tree。

Derivation tree 记录了本次生成真正使用的信息：

- 每个 nonterminal 选择了哪条 production；
- 每个节点接收到的 inherited attributes；
- 每个节点计算出的 synthesized attributes；
- generator 实际抽到的值。

对应实现为 `generator/rhema/lib/rhema_engine.ml`。

### 2.5 Set 作业生成

如果生成目标是 `set`，`Rhema_sets` 会先把 set declaration 规划成题目 slots。

预算支持：

- `cost = 5`：固定预算；
- `cost in {6, 8, 10}`：均匀轮换预算；
- `cost ~ 6 spread 2`：围绕指定均值抽样；
- `allowed {...}`：限制合法预算集合。

Set 还可以应用：

- `distinct`：避免重复的题型和 production shape；
- `balanced`：避免真假或小整数答案连续多次相同；
- `ordered`：在同一个 part 中按预算从易到难排列；
- `part "Heading"`：生成分组标题和小题编号。

之后，`Rhema_sets` 调用同一个 `Rhema_engine` 逐题生成。

对应实现为 `generator/rhema/lib/rhema_sets.ml`。

## 3. Backend：生成 WeBWorK PG

后端负责把 `Rhema_engine.question` 转换成 WeBWorK 可以执行和判分的 `.pg` 文件。

### 3.1 Typed Answer Lowering

Rhema Engine 中的答案带有明确类型。后端根据答案类型选择对应的 WeBWorK 表达。

| Rhema 内部类型 | WeBWorK 表示 | 说明 |
| --- | --- | --- |
| 整数 `Num` | `7` | 直接输出整数 |
| 分数 `Num` | `Formula('2/3')` | 保留精确分数 |
| `Text` | `Formula('...')` | 作为数学文本解析 |
| `Truth` | `1` 或 `0` | 用于真假题 |
| `Formula` | `Formula('...')` | 符号表达式 |
| `Polynomial` | `Formula('...')` | 转成 PG 多项式表达式 |
| `Complex` | `Complex(real,imaginary)` | Complex MathObject |
| `Boolean` | `Compute("...")` | 配合 Boolean context |
| `Matrix` | Matrix MathObject | 矩阵答案 |
| `Set` | `Compute("...")` | 集合或区间答案 |
| `Vector` | Vector MathObject | 向量答案 |
| `VectorNormAnswer` | `norm(vector)` | 向量模比较器 |
| `VectorUnitAnswer` | `unit(vector)` | 单位向量比较器 |
| `VectorDirectionAnswer` | `vector->cmp(...)` | 平行或同方向比较器 |
| `Equation` | 不直接输出 | 需要先转成解集或唯一解 |

这套转换目前不是外部 JSON/CSV 表格，而是 `rhema_pgml.ml` 中 `answer_of_value` 函数的 OCaml pattern matching。

### 3.2 Context 与 `.pl` 宏库

`.pl` 是 WeBWorK 使用的 Perl 宏库，例如：

- `PGstandard.pl`：基础 PG 功能；
- `MathObjects.pl`：Formula、Matrix、Vector、Set 等数学对象；
- `PGML.pl`：PGML 题面和答案框；
- `contextBoolean.pl`：布尔表达式解析和判分；
- `contextPolynomialFactors.pl`：多项式因式分解判分。

后端根据题目的 context 选择数学解析环境和额外宏库：

| Context | 额外宏库 |
| --- | --- |
| `Numeric` | 通常不需要额外 context 宏库 |
| `Interval` | 由 MathObjects 支持 |
| `Vector` | 由 MathObjects 支持 |
| `Complex` | 由 MathObjects 支持 |
| `Boolean` | `contextBoolean.pl` |
| `PolynomialFactors` | `contextPolynomialFactors.pl` |

因此 Typed Answer Lowering 和 Context 选择是两个相关但不同的步骤：

```text
Rhema typed value
→ 选择 WeBWorK MathObject 或 comparator
→ 根据 context 加载所需 .pl
→ 生成答案框
→ 由 WeBWorK 解析和判分
```

### 3.3 PGML 输出

后端把题面、答案框、题号、part heading 和 context 切换组织成 PGML：

```perl
DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");

BEGIN_PGML
Find the value of [`2+3`].

[_____]{5}
END_PGML

ENDDOCUMENT();
```

如果一份作业中的题目使用不同 context，后端会将它们分成多个连续 PGML block，并在 block 之间切换 `Context(...)`。

对应实现为 `generator/rhema/lib/rhema_pgml.ml`。

## 4. 三种入口与核心 pipeline 的关系

CLI、VS Code 和 Flask Web 不是三套生成器，而是同一个 Rhema 核心的不同入口：

```text
CLI ──────────┐
VS Code ──────┼──→ rhema command → Frontend → Middle-end → Backend
Flask Web ────┘
```

- **CLI**：功能最完整，支持 named question、set、budget override、include path 和多种输出。
- **VS Code**：调用 `rhema check/list/run/compile`，提供诊断、运行、编译、语法高亮和折叠。
- **Flask Web**：调用同一个 `rhema` 可执行文件，提供文法编辑、检查、生成、历史记录和可视化；当前主要暴露单题生成，尚未接入完整 set 入口。

## 5. 与经典编译器概念的对应

| 经典编译器概念 | Rhema 项目 |
| --- | --- |
| Source language | `.rhm` |
| Lexer | `Rhema_lexer` |
| Parser | Menhir `Rhema_parser` |
| AST | `Rhema_ast.file` |
| Module resolution | `Rhema_load` |
| Semantic analysis | `Rhema_check` |
| Checked/typed IR | `Rhema_check.spec` |
| Middle-end transformation | budget-driven generation、set planning |
| Question IR | `Rhema_engine.question` + derivation tree |
| Code generation | `Rhema_pgml` |
| Target language | WeBWorK PG/PGML |
| Debug information | AST 文本、derivation-tree HTML |
| Compiler driver | `rhema` CLI |

## 6. 一句话总结

> Rhema 前端把 `.rhm` 编译成经过语义检查的 `Rhema_check.spec`；中端根据 seed、难度预算和作业约束，将 spec 实例化成带 typed answers 和 derivation tree 的 `Rhema_engine.question`；后端再把 typed answers lowering 成 WeBWorK MathObjects、context 和 comparator，最终输出可执行、可判分的 `.pg` 文件。
