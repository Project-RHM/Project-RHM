# `.ag` 题目文法语言指南（Attribute Grammar Language Guide）

本文档介绍项目中新加入的 `.ag` 题目文法语言。它面向希望新增或修改题型的文法作者（grammar author），重点说明 `.ag` 文件怎么写、每个关键字表示什么，以及通用生成引擎（generic generation engine）如何执行这些规则。

当前通用引擎主要通过以下三个示例进行验证：

- `generator/ag/arithmetic.ag`：四则运算（arithmetic）
- `generator/ag/boolean.ag`：布尔表达式求值（Boolean evaluation）
- `generator/ag/boolean_equiv.ag`：布尔等价判断（Boolean equivalence）

## 1. `.ag` 文件是什么

一份 `.ag` 文件是一份声明式出题规格（declarative question specification）。它可以定义：

- 题目的语法树形状（tree shape）；
- 难度和生成预算（generation budget）；
- 产生式及其选择概率（production and weight）；
- 生成后必须满足的约束（constraint）；
- 每棵子树的值和显示文本（value and rendering）；
- 最终题干（prompt）和答案（answer）。

可以把它理解成一段由通用引擎解释执行的“出题程序”：

```text
.ag 文本
   ↓ 词法分析（lexical analysis）
token 流
   ↓ 语法分析（parsing）
Ag_ast
   ↓ 语义检查（semantic checking）
Ag_check.spec
   ↓ 执行（execution）
生成树 + 题干 + 答案
   ↓ PGML 输出（PGML rendering）
WeBWorK .pg 文件
```

前三个阶段负责读取、理解和检查规格；只有检查通过以后，执行器才会随机生成具体题目。

## 2. 最小完整示例（Minimal complete example）

下面的文法生成恰好包含一个加号、且操作数均为两位整数的题目：

```ag
attribute len = 1 split
attribute digit = 2 copy

synth value
synth latex

start E

precedence 1 left +

E -> E + E when len > 0 {
  len = -1
  value = $1.value + $3.value
  latex = infix($1, "+", $3)
}

E -> num when len = 0 {
  value = $1.value
  latex = $1.latex
}

num -> integer(digit) {
  value = $1.value
  latex = str($1.value)
}

prompt "Calculate [`{E.latex}`]."
answer E.value
```

它可能生成：

```text
Calculate 37 + 52.
answer: 89
```

## 3. 两类属性（Two kinds of attributes）

属性文法的核心是两种流动方向相反的属性。

### 3.1 继承属性（Inherited attribute）

继承属性由父节点向子节点传播，用来控制“接下来允许生成什么”。声明格式为：

```ag
attribute NAME = INITIAL [copy|split]
```

例如：

```ag
attribute len = 3 split
attribute digit = 2 copy
```

- `len` 是运算符预算（operator budget）；
- `digit` 是每个整数的位数（digit count）。

如果省略传播方式，默认为 `copy`。

#### `copy`：完整复制（Copy distribution）

`copy` 会把更新后的属性值完整传给每一个子非终结符（child nonterminal）。

```text
父节点 digit=2
  ├── 左孩子 digit=2
  └── 右孩子 digit=2
```

因此：

```ag
attribute digit = 2 copy
```

表示每个数字叶子都使用两位数，而不是整棵树共享两位数的总预算。

#### `split`：预算拆分（Split distribution）

`split` 会把更新后的总预算随机拆分给所有子非终结符，并保证各份都是非负整数。

假设规则是：

```ag
E -> E + E when len > 0 {
  len = -1
  ...
}
```

父节点从 `len=3` 开始，当前 `+` 先消耗一个单位：

```text
3 + (-1) = 2
```

剩余的 2 可能被分成：

```text
[0, 2]、[1, 1] 或 [2, 0]
```

终结符（terminal）如 `+` 不参与拆分，只有 RHS 中的非终结符参与。

可以这样记忆：

```text
copy  = 广播配置（broadcast a setting）
split = 分配资源（partition a resource）
```

### 3.2 综合属性（Synthesized attribute）

综合属性由子节点向父节点返回，用来描述“已经生成的子树是什么”。声明格式为：

```ag
synth NAME
synth NAME on NONTERMINAL
```

例如：

```ag
synth value
synth latex
```

- `value` 保存子树的数学或逻辑值；
- `latex` 保存子树的显示文本。

不带 `on` 时，该综合属性属于所有非终结符；带 `on` 时，它只属于指定非终结符：

```ag
synth holds on Q
```

每条产生式必须计算其左侧非终结符所需的全部综合属性，否则语义检查会报错。

## 4. 产生式（Production rule）

完整格式为：

```ag
LHS -> RHS [when CONDITION] [weight INTEGER] {
  EQUATIONS
}
```

例如：

```ag
E -> E + E when len > 0 weight 3 {
  len = -1
  value = $1.value + $3.value
  latex = infix($1, "+", $3)
}
```

各部分含义如下：

- `LHS`：左侧非终结符（left-hand-side nonterminal）；
- `RHS`：右侧符号序列（right-hand-side symbols）；
- `when`：生成前守卫条件（guard）；
- `weight`：候选规则的相对权重（relative weight），省略时为 1；
- `{ ... }`：属性方程和运行时约束（attribute equations and requirements）。

规则体的花括号不能省略，即使里面没有内容也要写 `{}`。

## 5. 右侧符号（RHS symbols）

RHS 可以包含三种符号。

### 5.1 非终结符或裸终结符（Nonterminal or bare terminal）

```ag
E -> num
E -> E + E
```

如果某个名称出现在其他规则的 LHS 上，引擎会把它视为非终结符；否则将其视为普通终结符文本。

### 5.2 字符串终结符（Literal terminal）

```ag
E -> "\neg" E
V -> "A"
```

字符串通常用于 LaTeX 运算符、变量名或固定文本。

### 5.3 随机生成器（Value generator）

```ag
num -> integer(digit)
num -> nonzero_integer(digit)
```

当前支持：

| 生成器（Generator） | 含义 |
|---|---|
| `integer(digits)` | 生成指定十进制位数的整数 |
| `nonzero_integer(digits)` | 生成指定十进制位数的非零整数 |

生成器叶子携带一个 `value` 属性。例如 `integer(2)` 可能得到 `value=47`。

## 6. `$n` 子节点引用（Child reference）

在规则体中：

```text
$n           = RHS 第 n 个符号生成的节点
$n.attribute = 该节点的综合属性
```

例如：

```ag
E -> E + E {
  value = $1.value + $3.value
}
```

RHS 的编号包括所有符号：

```text
E -> E   +   E
     $1  $2  $3
```

所以：

- `$1.value` 是左子表达式的值；
- `$3.value` 是右子表达式的值；
- `$2` 是终结符 `+`。

一元规则也要按照实际位置编号：

```ag
E -> "\neg" E {
  value = not $2.value
  latex = prefix("\neg", $2)
}
```

这里 `$1` 是 `"\neg"`，`$2` 才是子表达式 `E`。

`$n` 表示整个节点，主要传给 `infix`、`prefix` 等需要读取节点优先级的函数；`$n.attribute` 表示一个具体属性值。

## 7. 继承属性更新（Inherited attribute update）

规则体中对继承属性的方程表示增量更新（delta update），不是普通覆盖赋值。

```ag
len = -1
```

实际含义是：

```text
new_len = old_len + (-1)
```

例如：

```text
old_len = 3
delta   = -1
new_len = 2
```

同理：

```ag
len = 0
```

表示不消耗该属性。继承属性不能通过规则增大，也不能被更新成负预算。

执行顺序是：

```text
选择规则
  ↓
应用继承属性更新
  ↓
按 copy/split 传播给孩子
  ↓
递归生成孩子
```

## 8. `when` 与 `require`

二者都是条件，但检查时间不同。

| 关键字 | 中文 | 检查时间 | 失败结果 |
|---|---|---|---|
| `when` | 守卫条件（guard） | 生成孩子之前 | 当前规则不进入候选集 |
| `require` | 生成后约束（requirement） | 孩子和综合属性生成之后 | 重试当前节点 |

### 8.1 `when`：生成前筛选

```ag
E -> E + E when len > 0 { ... }
E -> num when len = 0 { ... }
```

`when` 只能读取此时已经存在的信息，例如继承属性、题目级随机值和题目级 `let`。它不能读取 `$1.value`，因为孩子尚未生成。

### 8.2 `require`：生成后检查

```ag
E -> E / E when len > 0 {
  len = -1
  require $3.value != 0
  value = $1.value / $3.value
  latex = infix($1, "\div", $3)
}
```

只有右子树生成以后，执行器才知道 `$3.value` 是否为零。如果条件不满足，引擎会重试当前节点。

Boolean 文法中的例子：

```ag
require $1.latex != $3.latex
```

它用于避免生成 `A \land A` 之类左右完全相同的表达式。

## 9. 权重（Weight）

`weight` 控制当前所有合法候选规则之间的相对概率。

```ag
E -> E + E when len > 0 weight 3 { ... }
E -> E - E when len > 0 weight 3 { ... }
E -> E * E when len > 0 weight 2 { ... }
E -> E / E when len > 0 weight 1 { ... }
```

当四条规则都合法时，总权重为 9，因此概率分别约为：

```text
+ : 3/9
- : 3/9
* : 2/9
/ : 1/9
```

`weight` 必须是正整数。它不会绕过 `when`，也不会让非法预算规则重新变得可用。

## 10. 运算符优先级（Operator precedence）

声明格式为：

```ag
precedence LEVEL ASSOCIATIVITY OPERATORS...
```

例如：

```ag
precedence 1 left + -
precedence 2 left * /
precedence 3 right "\neg"
```

优先级数字越大，结合强度越高。

结合性（associativity）可以是：

- `left`：左结合（left-associative）；
- `right`：右结合（right-associative）；
- `nonassoc`：不可结合（non-associative）。

优先级信息主要由 `infix` 和 `prefix` 用来自动添加必要括号。

## 11. 显示函数（Rendering builtins）

### 11.1 `infix(left, operator, right)`

生成中缀表达式（infix expression），并根据优先级和结合性自动决定括号：

```ag
latex = infix($1, "+", $3)
```

如果语法树表示 `(2 + 3) * 4`，`infix` 会保留必要括号，而不会错误显示成 `2 + 3 * 4`。

传入的是整个节点 `$1` 和 `$3`，不是 `$1.latex` 和 `$3.latex`，因为函数还需要读取节点的运算符优先级。

### 11.2 `prefix(operator, operand)`

生成前缀表达式（prefix expression）：

```ag
latex = prefix("\neg", $2)
```

它可能输出：

```text
\neg A
\neg (A \lor B)
```

### 11.3 其他显示函数

| 函数 | 中文说明 | 示例 |
|---|---|---|
| `str(value)` | 将数字转为文本（convert to text） | `str($1.value)` |
| `paren(text)` | 强制添加括号（force parentheses） | `paren(latex)` |
| `left ++ right` | 文本连接（text concatenation） | `"A" ++ "B"` |

显示属性通常命名为 `latex`，但 `infix` 并没有硬编码该名字；它会使用当前正在计算的目标属性。

## 12. 表达式和值类型（Expressions and value types）

当前运行时支持三类值：

| 类型（Type） | 说明 | 示例 |
|---|---|---|
| `Num` | 精确有理数（exact rational number） | `3`、`7/2` |
| `Text` | 文本（text） | `"A \land B"` |
| `Truth` | 布尔值（Boolean value） | `true`、`false` |

支持的主要运算符包括：

```text
算术（arithmetic）:       + - * / % ^
比较（comparison）:       = != < <= > >=
逻辑（Boolean logic）:    and or not
文本（text）:             ++
```

数值使用精确分数计算。例如 `7 / 2` 保留为 `7/2`，不会变成不稳定的浮点近似。

### 12.1 通用表达式函数（Expression builtins）

| 函数 | 参数数 | 作用 |
|---|---:|---|
| `cond(test, yes, no)` | 3 | 条件选择（conditional choice） |
| `abs(x)` | 1 | 绝对值（absolute value） |
| `min(a, b)` | 2 | 较小值（minimum） |
| `max(a, b)` | 2 | 较大值（maximum） |
| `bit_and(a, b)` | 2 | 按位与（bitwise AND） |
| `bit_or(a, b)` | 2 | 按位或（bitwise OR） |
| `bit_xor(a, b)` | 2 | 按位异或（bitwise XOR） |

位运算主要用于把 Boolean 表达式的完整真值表编码成整数。

## 13. 题目级随机值（Question-level random value）

声明格式为：

```ag
random NAME = boolean
random NAME = integer(CONSTANT_DIGITS)
random NAME = nonzero_integer(CONSTANT_DIGITS)
```

例如：

```ag
random A = boolean
random B = boolean
random C = boolean
```

这些值在每道题开始时只抽取一次，并在整道题中保持不变。这样同一道表达式中每次出现 `A` 都对应同一个真值。

## 14. 题目级计算值（Question-level `let` binding）

`let` 在每道题开始时计算一次：

```ag
let ta = cond(A, "\mathsf{T}", "\mathsf{F}")
```

它常用于把随机值转成适合题干显示的文本。`let` 按声明顺序执行，后面的 `let` 可以引用前面的 `random` 或 `let`，但不能引用尚未生成的树节点。

## 15. 开始符号（Start symbol）

每份文法必须且只能声明一个开始符号：

```ag
start E
```

或者：

```ag
start Q
```

执行器从该非终结符开始生成整棵题目树。

## 16. 题干、答案和输入宽度（Prompt, answer, and width）

### 16.1 `prompt`

```ag
prompt "What is the value of [`{E.latex}`]?"
```

`{E.latex}` 表示读取开始符号根节点的 `latex` 综合属性。

题目级随机值和 `let` 可以直接使用名称：

```ag
prompt "A = {ta}"
```

若要在题干中显示字面花括号，使用双花括号：

```text
{{  显示为 {
}}  显示为 }
```

### 16.2 `answer`

```ag
answer E.value
```

答案通常引用开始符号的综合属性，也可以是基于根属性的表达式。

### 16.3 `width`

```ag
width 8
```

它设置生成的 PGML 答案输入框宽度。该值必须为正整数。

## 17. 一道题的执行顺序（Execution order）

文法检查通过后，每道题按以下顺序生成：

```text
1. 初始化随机种子（random seed）
2. 抽取 random 值
3. 按顺序计算 let 值
4. 从 start 非终结符开始
5. 用 when 筛选合法产生式
6. 按 weight 随机选择一条规则
7. 应用继承属性更新
8. 用 copy/split 生成子节点环境
9. 递归生成所有孩子
10. 按书写顺序计算综合属性
11. 检查 require；失败则重试
12. 使用根属性生成 prompt 和 answer
13. 输出 PGML
```

可以进一步概括为：

```text
属性向下（inherited）决定题目长什么样；
属性向上（synthesized）计算题目是什么意思。
```

## 18. 静态错误与运行时问题（Static errors and runtime failures）

前三个阶段可以发现：

- 未知关键字或非法字符；
- `.ag` 语法错误；
- 重复声明；
- 不存在的开始符号；
- `$n` 越界；
- 在 `when` 中读取尚未生成的孩子；
- 漏算综合属性；
- 未知函数或生成器；
- 非正数 `weight`；
- 负的初始预算。

只有生成后才能发现的问题包括：

- `require` 不成立；
- 除数为零；
- 某个随机组合无法满足业务约束；
- 某个属性表达式在实际值上发生算术错误。

引擎采用“生成、检查、失败后重试”的策略：

- 每个节点最多重试 40 次；
- 每道题最多重试 200 次；
- 整个生成过程有总步骤安全上限。

超过上限后会停止并报告错误，不会无限递归。

## 19. 如何新增题型（Adding a question type）

如果新题能由现有类型、运算符、生成器和 builtin 表达，通常只需要新增一个 `.ag` 文件，不需要修改引擎。例如：

- 修改产生式组合；
- 修改规则权重；
- 增加非终结符；
- 增加 `value`、`latex` 或真值表属性；
- 增加 `when` 或 `require`；
- 修改题干和答案公式。

如果题目需要 DSL 当前不存在的底层能力，则需要扩展通用引擎。例如：

```text
prime(digit)
random_real(...)
gcd(...)
sqrt(...)
differentiate(...)
集合、向量或符号表达式类型
```

通常需要：

1. 在 `ag_check.ml` 中登记并检查新 builtin；
2. 在 `ag_engine.ml` 中实现它；
3. 如果引入新的答案类型，再扩展 `ag_pgml.ml`；
4. 只有新增语言语法时，才需要改 lexer、parser 或 `Ag_ast`。

判断原则是：

```text
新增一种现有能力的组合 → 写新的 .ag
新增一种语言底层能力   → 扩展 checker/engine
```

## 20. 关键字速查（Keyword reference）

| 关键字 | 英文术语 | 作用 |
|---|---|---|
| `attribute` | inherited attribute declaration | 声明继承属性及初始值 |
| `copy` | copy distribution | 向每个子非终结符复制完整属性值 |
| `split` | split distribution | 把属性预算拆分给子非终结符 |
| `synth` | synthesized attribute declaration | 声明综合属性 |
| `on` | scoped attribute owner | 将综合属性限制在指定非终结符 |
| `random` | question-level random declaration | 声明每道题只抽取一次的随机值 |
| `boolean` | Boolean draw | 抽取布尔值 |
| `let` | question-level binding | 声明每道题计算一次的值 |
| `start` | start symbol | 指定生成入口非终结符 |
| `when` | guard | 在生成前筛选规则 |
| `weight` | production weight | 设置规则相对选择权重 |
| `require` | runtime requirement | 在生成后检查约束 |
| `precedence` | operator precedence | 声明运算符优先级 |
| `left` | left associativity | 声明左结合 |
| `right` | right associativity | 声明右结合 |
| `nonassoc` | non-associativity | 声明不可结合 |
| `prompt` | question prompt template | 声明题干模板 |
| `answer` | answer expression | 声明正确答案表达式 |
| `width` | answer field width | 设置答案输入框宽度 |
| `and` | Boolean AND | 逻辑与 |
| `or` | Boolean OR | 逻辑或 |
| `not` | Boolean NOT | 逻辑非 |

## 21. 注释和字符串（Comments and strings）

单行注释以 `#` 开始：

```ag
attribute len = 3 split  # exactly three operators
```

字符串使用双引号：

```ag
"A"
"What is [`{E.latex}`]?"
```

字符串可以跨行，便于书写多行题干。`.ag` 中经常包含 LaTeX，因此一般的反斜杠会被保留；双引号和反斜杠本身可以分别写成 `\"` 和 `\\`。

## 22. 命令行使用（Command-line usage）

先在 `generator` 目录构建：

```bash
dune build
```

检查文法：

```bash
dune exec ag/agcheck.exe -- ag/arithmetic.ag
```

生成可读题目：

```bash
dune exec ag/agrun.exe -- --count 5 --seed 21 ag/arithmetic.ag
```

生成 PGML：

```bash
dune exec ag/agrun.exe -- --pg --count 5 --seed 21 ag/arithmetic.ag
```

覆盖继承属性初始值：

```bash
dune exec ag/agrun.exe -- --set len=4 --set digit=3 ag/arithmetic.ag
```

用字符串稳定派生随机种子：

```bash
dune exec ag/agrun.exe -- --seed-from STUDENT_ID ag/arithmetic.ag
```

相同 `.ag`、相同 seed 和相同覆盖值会得到可复现的随机序列。

## 23. 实践建议（Authoring recommendations）

- 用 `split` 表示整棵树共享的总复杂度预算；
- 用 `copy` 表示每个子树都必须遵守的配置；
- 用 `when` 表达生成前就能判断的规则适用条件；
- 用 `require` 表达必须看到生成结果才能判断的条件；
- 为递归规则设置会递减的非负预算，并提供预算耗尽时的终止规则；
- 用 `infix` 和 `prefix` 生成运算符表达式，避免手工拼接导致括号含义错误；
- 尽量让答案由综合属性计算，而不是根据选中的规则名称写死；
- 给复杂文法固定 seed 测试，便于复现生成错误；
- 避免只能靠极低概率满足的 `require`，否则生成会频繁重试甚至失败。

