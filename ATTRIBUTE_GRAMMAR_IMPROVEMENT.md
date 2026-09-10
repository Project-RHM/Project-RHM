# Arithmetic Attribute Grammar 改进说明

## 1. 改进背景

原来的算术题生成器通过 OCaml 递归函数直接控制表达式结构：

```ocaml
gen_math_expr_root depth
gen_term depth
gen_factor depth
```

这些函数在递归时手动执行 `depth - 1`。这种方法可以生成表达式，但生成规则、复杂度控制和 OCaml 实现耦合在一起：

- 修改表达式结构需要修改并重新编译 OCaml；
- `depth` 只能表达固定的递归深度概念；
- 很难增加数字位数、分支数、运算符数等独立约束；
- 随着题型增加，约束逻辑容易散落在不同生成函数中。

本次改进引入了一个小型 Attribute Grammar（属性文法）引擎，并首先将算术题迁移到该引擎。现有 AST、答案计算、PGML 输出和树形可视化流程保持不变。

## 2. 本次实现范围

本次是 Attribute Grammar 的第一阶段 MVP，主要完成：

1. 定义可编辑的算术属性文法文件；
2. 解析属性、产生式、guard 和权重；
3. 根据属性预算筛选合法产生式；
4. 将剩余预算分配给子表达式；
5. 保证递归生成可以终止；
6. 将生成树转换成现有的 `Ast.math_expr`；
7. 继续使用现有语义模块计算答案；
8. 增加属性文法专项测试；
9. 验证全部已有题型没有受到影响。

目前只迁移了算术表达式生成。集合、向量、微积分、布尔代数、复数和数列仍使用原有生成逻辑。

## 3. 新的生成流程

```text
config_setting/config.json
        │
        │ max_expr_depth 作为初始 len
        ▼
generator/arithmetic.ag
        │
        │ 解析属性、产生式、guard、weight
        ▼
Attribute Grammar Engine
        │
        │ 属性预算传递与分配
        ▼
Generic Generated Tree
        │
        │ lowering
        ▼
Ast.math_expr
        │
        ├── Semantic.eval_math_expr：计算答案
        ├── Describe：AST → DCST
        ├── Settle：DCST → CST
        └── Print_pprint：输出 PGML
```

## 4. 主要文件

### `generator/attribute_grammar.ml`

属性文法核心模块，负责：

- 解析 `.ag` 文法；
- 校验属性名、初始值、规则权重和更新值；
- 维护生成时的属性环境；
- 根据 guard 筛选合法规则；
- 根据 weight 随机选择规则；
- 对 `split` 属性进行子树预算分配；
- 对 `copy` 属性进行继承；
- 生成通用语法树；
- 将算术生成树转换为 `Ast.math_expr`；
- 避免生成除零表达式；
- 提供操作符计数和表达式求值函数供测试使用。

### `generator/arithmetic.ag`

算术题的声明式属性文法。默认内容：

```text
attribute len = 2 split
attribute digit = 2 copy

start E

E -> E + E { len = -1 } when len > 0 weight 3
E -> E - E { len = -1 } when len > 0 weight 3
E -> E * E { len = -1 } when len > 0 weight 2
E -> E / E { len = -1 } when len > 0 weight 1
E -> num { len = -0 } when len = 0 weight 1

num -> integer { digit = -0 } when digit > 0 weight 1
```

### `generator/generator.ml`

原来的手写算术递归生成函数已被替换。算术入口现在调用：

```ocaml
Attribute_grammar.generate_math_expr
  ~len:max_expr_depth
  ~allow_float
  ()
```

其他题型生成代码未迁移，也未改变。

### `generator/attribute_grammar_test.ml`

属性文法专项测试，检查：

- 不同 `len` 预算能否生成准确数量的运算符；
- `digit` 是否限制数字位数；
- 生成是否正常终止；
- 生成表达式能否正常求值；
- 是否避免除零；
- 相同随机 seed 是否生成相同 AST；
- `generator/arithmetic.ag` 是否能被正确加载。

### `generator/dune`

将 `attribute_grammar` 加入 `pg_core`，并注册 `attribute_grammar_test`。

### `README.md`

增加了 Attribute Grammar 的基本说明和测试命令。

## 5. 属性语义

### 5.1 `len`

`len` 是一个使用 `split` 分配方式的继承属性：

```text
attribute len = 3 split
```

每生成一个运算符，当前规则消耗一个单位：

```text
E -> E + E { len = -1 }
```

剩余预算随机分配给两个子表达式。例如：

```text
E {len=3}
    ↓
E {len=1} + E {len=1}
```

因此：

- `len=0`：生成纯数字；
- `len=1`：生成恰好一个运算符；
- `len=3`：生成恰好三个运算符；
- 任意合法 `len=n`：生成恰好 `n` 个运算符。

当 `len=0` 时，递归规则的 guard 不成立：

```text
when len > 0
```

此时只能选择终止规则：

```text
E -> num { len = -0 } when len = 0
```

这保证生成过程一定终止，不依赖概率碰巧选择终止规则。

### 5.2 `digit`

`digit` 使用 `copy`：

```text
attribute digit = 2 copy
```

该值会原样传给所有数字叶子。目前 `digit=2` 会生成两位整数，例如：

```text
25
67
93
```

修改成：

```text
attribute digit = 3 copy
```

即可生成三位整数。修改 `.ag` 文件后不需要重新编译 OCaml，下一次生成时会重新读取文法。

### 5.3 `guard`

guard 决定一条规则在当前属性环境下是否合法：

```text
when len > 0
when len = 0
when digit > 0
```

当前支持：

```text
=
>
>=
```

如果某个非终结符在当前属性值下没有合法规则，生成器会返回明确错误，而不是无限递归。

### 5.4 `weight`

权重只作用于当前所有合法规则：

```text
weight 3
weight 2
weight 1
```

默认配置中：

- 加法权重为 3；
- 减法权重为 3；
- 乘法权重为 2；
- 除法权重为 1。

例如希望明显增加加法，可以修改为：

```text
E -> E + E { len = -1 } when len > 0 weight 10
E -> E - E { len = -1 } when len > 0 weight 1
E -> E * E { len = -1 } when len > 0 weight 1
E -> E / E { len = -1 } when len > 0 weight 1
```

权重不会绕过 guard，也不会让属性预算变成负数。

## 6. 与原配置的关系

当前为了保持 Web 配置兼容，原来的：

```text
max_expr_depth
```

现在作为 Attribute Grammar 的初始 `len` 使用。

这意味着它的语义发生了变化：

| 配置值 | 原含义 | 新含义 |
|---:|---|---|
| `1` | 最大递归深度约为 1 | 恰好 1 个运算符 |
| `2` | 最大递归深度约为 2 | 恰好 2 个运算符 |
| `3` | 最大递归深度约为 3 | 恰好 3 个运算符 |

字段名暂时没有修改，以避免同时改动 Flask 配置、HTML 表单和已有 JSON。后续可以将其重命名为 `arithmetic_operator_budget` 或 `arithmetic_len`。

`.ag` 文件里的默认 `len` 会被 `max_expr_depth` 覆盖；默认 `digit` 仍从 `.ag` 文件读取。

## 7. 示例结果

当：

```text
max_expr_depth = 3
attribute digit = 2 copy
```

可能生成：

```text
97-(85-25+17)
76*33-(25+59)
17-((93+39)*31)
63/(15)+(65/(96))
```

每个表达式：

- 都包含恰好 3 个运算符；
- 每个整数都是两位数；
- 可以转换成现有 AST；
- 可以由现有语义模块计算答案；
- 可以继续输出为 WeBWorK PGML。

## 8. 如何测试

### 8.1 构建和属性文法专项测试

在项目根目录执行：

```bash
cd generator
dune build
dune runtest
```

预期结果：

```text
Attribute grammar tests passed.
```

### 8.2 算术题端到端测试

```bash
cd ..
python3 tools/test_question_types.py \
  --case arithmetic_only \
  --seeds-per-case 10
```

本次实际测试结果：

```text
Cases run: 10
Passed: 10
Failed: 0
Bugs found: 0
```

报告文件：

```text
test_reports/question_type_report_20260727_114031.md
test_reports/question_type_report_20260727_114031.json
```

### 8.3 全题型回归测试

```bash
python3 tools/test_question_types.py --seeds-per-case 1
```

本次回归测试结果：

```text
Cases run: 20
Passed: 20
Failed: 0
Bugs found: 0
```

这说明此次算术生成器替换没有破坏其他题型的本地测试。

### 8.4 Web 页面测试

如果 macOS 的 AirPlay Receiver 占用了 5000 端口，可以使用：

```bash
python3 -m flask --app app run \
  --debug \
  --host 127.0.0.1 \
  --port 5001
```

打开：

```text
http://127.0.0.1:5001
```

在配置页面选择 Arithmetic，并修改 `Max Expression Depth`，即可观察不同 `len` 预算生成的表达式。

## 9. 自定义文法文件

默认情况下，程序会依次查找：

```text
arithmetic.ag
generator/arithmetic.ag
```

也可以通过环境变量指定其他文件：

```bash
ATTRIBUTE_GRAMMAR_FILE=/absolute/path/custom_arithmetic.ag \
python3 -m flask --app app run --port 5001
```

如果显式指定的文法存在语法或属性错误，生成器会报告错误，不会静默退回默认规则。

## 10. 已知限制

### 10.1 目前只迁移了算术题

Attribute Grammar 引擎已经是独立模块，但当前 lowering 逻辑只负责把算术生成树转换成 `Ast.math_expr`。其他题型尚未使用该引擎。

### 10.2 文法 DSL 仍是 MVP

目前支持：

- 整数属性；
- `copy` 和 `split`；
- 单个 guard；
- 属性减量；
- 正整数权重。

目前尚未支持：

- 一条规则上的多个 guard；
- 属性之间的算术表达式；
- 显式指定每一个子节点的属性公式；
- 综合属性的通用声明；
- 通用 semantic action；
- 文法静态终止性证明。

引擎内部保留了生成步数安全上限，以便错误文法能够及时失败。

### 10.3 `max_expr_depth` 名称与新语义不完全一致

它现在是精确运算符预算，而不是最大深度。需要在后续 UI/config 清理中重命名。

### 10.4 三位有效数字提示尚未完全落实

PGML 中目前仍会显示：

```text
if the result is not an integer, then retain three significant digits
```

但非整数答案可能仍以较长的精确小数或 `Formula` 保存，例如：

```text
Formula('4.87708333333')
```

如果学生输入三位有效数字 `4.88`，真实 WeBWorK 是否接受取决于答案 checker 和 tolerance 配置。后续应当选择一种统一策略：

1. 删除三位有效数字提示，要求精确答案；或者
2. 按三位有效数字生成答案，并明确设置 WeBWorK tolerance。

### 10.5 尚未进行在线 WeBWorK 验证

本地测试覆盖：

- PGML 静态结构；
- AST/语义检查；
- 算术答案复算；
- Attribute Grammar 预算检查。

由于没有设置 `WEBWORK_VALIDATE_URL`，测试报告中的在线 WeBWorK 状态为 `SKIPPED`。这不代表测试失败，但 push 前需要让团队知道尚未完成真实 WeBWorK 环境验证。

## 11. 后续建议

建议按以下顺序继续：

1. 将 `max_expr_depth` 重命名为更准确的运算符预算字段；
2. 解决三位有效数字和 WeBWorK tolerance 不一致的问题；
3. 增加 `.ag` 文件语法错误测试；
4. 增加生成结果分布测试，验证 weight 是否符合预期；
5. 将 Boolean Expression 作为第二个 Attribute Grammar 迁移对象；
6. 增加综合属性，用声明式规则计算表达式值；
7. 最后再评估集合、微积分等复杂题型的迁移。

Boolean Expression 适合作为下一步，因为它同样具有清晰的递归结构，并且可以使用：

```text
depth
branch
variable_count
```

等属性验证当前设计是否足够通用。

## 12. Push 前建议检查

```bash
cd generator
dune build
dune runtest

cd ..
python3 tools/test_question_types.py \
  --case arithmetic_only \
  --seeds-per-case 10
```

确认测试通过后，将以下核心文件一起提交：

```text
ATTRIBUTE_GRAMMAR_IMPROVEMENT.md
README.md
generator/arithmetic.ag
generator/attribute_grammar.ml
generator/attribute_grammar_test.ml
generator/dune
generator/generator.ml
```

测试生成的 `.pg`、AST、HTML 和 `_build` 目录通常不应该作为本次功能提交的核心内容，是否提交取决于团队现有仓库规范。

## 13. 布尔题的「手写感」改造（2026-09-09）

求值题（`boolean.ag`）和判等价题（`boolean_equiv.ag`）要直接放进学生作业，
所以除了答案正确，还要求一套题看起来和老师手出的没有区别。本节记录为此做的
改动、检查手段和验收数字。改动全部在 `.ag` 文件和测试里，引擎没有动。

### 13.1 原来的题哪里像机器出的

用 `agrun` 各生成 12 道对照，问题集中在四处：

1. 冗余子式：`A \land (A \land B)`、`C \lor (C \lor B)`、`B \land (B \lor C)`。
   原来的 `require $1.latex != $3.latex` 只拦完全相同的两边。
2. 连接词混搭：`B \oplus C \leftrightarrow B \lor A`，教材题不会把 ⊕、→、↔
   塞进同一道题。
3. 括号只按优先级加：`C \lor B \land C \to A`、`B \to A \to A \land C`，
   出题人恰恰会避免让学生猜优先级和结合性。
4. 题干：`- A = \mathsf{T}` 写在数学模式外面（WeBWorK 会显示成原文）；
   每题恰好 3 个连接词；等价题两个式子用逗号挤在一个数学块里，
   错误项全是「同一条定律换一个连接词」，成立/不成立的比例 60/40。

### 13.2 表达式规则

两份文法的二元规则共用三条 `require`，靠三个综合属性实现：
`vars`（用到的变量，位掩码 A=1 B=2 C=4）、`atom`（是否为变量或带否定的变量）、
`chain`（在同一连接词的平铺链里「单独出现」的变量）。

```text
require $1.vars != $3.vars                     # 两边不得覆盖同一组变量
require bit_and(chain_from($1), $3.vars) = 0   # 链里单独出现的变量不得再出现在另一操作数里
require bit_and(chain_from($3), $1.vars) = 0
```

其中 `chain_from($n)` 在文法里写作 `cond($n.atom = 1 or $n.op = X, $n.chain, 0)`，
X 是本条规则的连接词。效果：

- 拦掉 `A \land A`、`A \lor \neg A`、`(A \land B) \lor (B \land A)`；
- 拦掉 `A \land (A \land B)`、`\neg B \lor (B \lor C)`、`A \lor C \lor C \lor \neg B`；
- 保留 `(A \lor B) \land (\neg A \lor C)` 这种两个复合操作数共用变量的写法，
  这正是人复用变量的方式。

其余规则：

- 括号：`\land`/`\lor` 同连接词的链平铺（`A \land B \land C`），混合连接词、
  `\to`/`\leftrightarrow`/`\oplus` 的非原子操作数一律加括号，否定式不加括号。
  括号由规则里的 `cond(...)` 手工决定，不再依赖 `infix` 的优先级判断。
- 否定：`E -> "\neg" V when len = 0` 让带否定的变量作为叶子免费出现
  （不占连接词预算），`E -> "\neg" E when len > 1` 只对复合式取反，
  不会产生 `\neg \neg`。
- 规模：`len` 改为上限，`S` 层按 1:2:1 削去 2/1/0 个预算，默认 `len = 4`
  得到 2、3、4 个连接词。预算只能减不能加，所以只能从上限往下削。
- 稀有连接词：新增预算 `extras`（默认 1），`\to`/`\leftrightarrow`/`\oplus`
  共用，一题最多一个；`T` 层再以 50% 概率放弃这个预算。
  `--set extras=0` 得到只有 ¬ ∧ ∨ 的基础题。
- 赋值：`require ta != tb or tb != tc`，不出全真或全假的赋值。
- 题干：三种问法轮换，赋值写在数学模式内；等价题分两行或写成 `\equiv` 一行，
  `flip` 随机决定哪一边先出现。

### 13.3 等价题的定律

19 条：成立 10 条（De Morgan ×2、蕴含改析取、蕴含改否定合取、逆否、双重否定、
吸收、分配、双条件拆两个蕴含、换序重排），常见错误 9 条（De Morgan 不换连接词 ×2、
De Morgan 漏否定、逆命题、否命题、蕴含否定放错边、分配漏一半、吸收反写、
双条件只留一个蕴含）。`holds` 一律由真值表比较得出，不是断言。

各定律的出现频率不等于 weight：`require` 拒绝率高的定律会被稀释，
所以 weight 是按 `--ast-out` 统计的实际频率反推调的。

### 13.4 测试

`ag_boolean_reader.ml` 是两套测试共用的独立读回器：把题干里的表达式解析成树，
自行求值、自行按上面的括号策略重新渲染。测试项：

| 检查 | 求值题 | 等价题 |
|---|---|---|
| 答案与题面一致 | 300 seeds | 300 seeds，8 组赋值逐一比较 |
| 预算含义：`len` 上限、`extras` 上限 | 每个 len 0..6 各 40 seeds | — |
| 不出现冗余子式、`\neg \neg`、全同赋值 | 500 seeds | 500 seeds（吸收律除外） |
| 重新渲染等于原文（括号策略） | 500 seeds | 500 seeds |
| 答案比例在 40%–60% | 1000 seeds | 1000 seeds |
| 各种问法都出现 | 100 seeds | 100 seeds |

### 13.5 度量工具

```bash
cd generator && dune build && cd ..
python3 tools/ag_stats.py generator/ag/boolean.ag --count 3000
python3 tools/ag_stats.py generator/ag/boolean_equiv.ag --count 3000 --samples 8
python3 tools/ag_stats.py generator/ag/boolean.ag --set extras=0
```

输出不重复率、答案比例、连接词数分布、稀有连接词分布和问法分布。
改文法前后各跑一次对照。

### 13.6 验收数字（3000 道，seed 1）

| | 改前 | 改后 |
|---|---|---|
| 求值题答案为 1 | 54% | 53% |
| 求值题连接词数 | 全部 3 | 2 / 3 / 4 = 731 / 1533 / 736 |
| 求值题含 →/↔/⊕ | 77% | 34% |
| 等价题答案为 1 | 64% | 49% |
| 等价题 3000 道中不重复 | 71% | 65% |

### 13.7 已知限制

- 等价题的空间只有几千道：三个变量、定律模板固定。按学号播种一个班没问题，
  做整学期题库会撞题。扩空间要加第四个变量，而真值表现在是硬编码的 8 位整数
  （`V -> "A" { table = 240 }`），需要引擎侧加一个布尔公式值类型由引擎算真值表。
- 解答步骤：推导树上每个节点的 `value` 已经算出，按顺序输出就是解题过程，
  但需要 `agrun`/`ag_pgml` 支持 PGML solution 块，是引擎工作。
- `ag_pgml.ml` 把 `Context("Numeric")` 写死，答案只能是 1/0。
- 变量名沿用 A、B、C；命题逻辑教材常用 p、q、r，只需改 `V` 规则。
