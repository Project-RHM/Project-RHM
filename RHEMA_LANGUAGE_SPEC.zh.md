# Rhema 语言使用规范与完整参考

核对日期：2026-10-31。适用代码：`main` / `5545aa182494797ce7d2859bacd15353a620d921`。

本说明依据当前 lexer、Menhir parser、checker、runtime、PGML emitter、CLI 与网页实现编写。它描述**当前已实现的行为**，不把设计提案或未来功能写成现有语法。语言文件使用 `.rhm`；早期 `.ag` / `Ag_engine` 文档不能直接代替本规范。

阅读路线：首次使用读第 1–3、10、18 节；编写 specification 读第 4–13 节；查数学函数读第 14 节；排错读第 20–22 节。标注“完整示例”的 `rhm` 代码块可单独保存运行；其他 `text` 片段只是语法或局部片段。

## 目录

1. [语言定位与运行模型](#purpose)
2. [最小完整示例](#first)
3. [文件、词法与书写规则](#lexical)
4. [全部关键字与上下文词](#keywords)
5. [声明与作用域](#scope)
6. [Inherited / Synthesized Attributes](#attributes)
7. [Production、when、weight、require](#productions)
8. [表达式、运算符与值类型](#expressions)
9. [优先级与表达式显示](#precedence)
10. [prompt、answer、width、context](#prompt)
11. [命名题型 question](#questions)
12. [include 与 import](#modules)
13. [整份作业 set](#assignments)
14. [完整 builtin 目录](#builtins)
15. [可复现生成与 seed](#determinism)
16. [执行顺序、重试与终止限制](#execution)
17. [PGML 与 WeBWorK 输出](#pgml)
18. [网页使用方法](#web)
19. [CLI 完整用法](#cli)
20. [常见错误与修正方法](#errors)
21. [当前能力边界](#limits)
22. [编写和验证检查表](#checklist)
23. [完整示例集](#examples)
24. [语法摘要 EBNF](#ebnf)
25. [实现依据与维护方式](#sources)

<a id="purpose"></a>
## 1. 语言定位与运行模型

Rhema 是用于描述数学题生成过程的 domain-specific language，底层由 OCaml 实现。一个 specification 可以描述：

- 生成哪些表达式或题目结构：production rules。
- 如何限制结构：inherited attributes、预算、guard、weight。
- 如何计算答案与显示内容：synthesized attributes、数学 builtin。
- 如何拒绝不合适的题：`require`。
- 如何提问、放置答案框、选择判分 context。
- 如何复用其他文法、提供多个题型或组合整份作业。

```text
教师配置 / .rhm
  → Lexer + Parser
  → AST + include/import loader
  → Checker
  → 受预算与约束控制的 derivation tree
  → typed answers + prompt + context
  → PGML / .pg + production/attribute visualization
  → WeBWorK 渲染与学生答案判分
```

这里的 Attribute Grammar 是在产生式上附加属性及其计算关系。当前引擎采用固定的执行方向：要求与预算向下传，子树结果向上综合；它不是允许任意循环属性依赖的通用 AG 求解器。

`.rhm` 描述“怎样生成”，`.ml` 提供引擎和可复用数学语义。只要现有 builtin 足够，新增题目变体可以只增加 `.rhm`，不用写新的 OCaml 分支。全新的数学对象或计算能力仍可能需要扩展底层库。

当前执行器直接检查并执行 specification，生成题目文件；**不是一般地将每份 specification 导出成独立 OCaml generator 程序**。

<a id="first"></a>
## 2. 最小完整示例

完整示例：`first.rhm`。

<!-- rhema-example: first.rhm -->
```rhm
synth value on E
synth latex on E

start E

E -> integer_between(10, 99) "+" integer_between(10, 99) {
  value = $1.value + $3.value
  latex = str($1.value) ++ " + " ++ str($3.value)
}

prompt "Compute [`{E.latex}`]."
answer E.value
width 12
```

说明：

- `E` 是入口 nonterminal。
- 第一个和第三个 RHS 符号是随机数字叶子，第二个是终结符 `"+"`。
- `$1.value`、`$3.value` 读取数字；位置从 1 开始，终结符也占位置。
- `value` 保存数值答案，`latex` 保存展示文本，二者不能混为一谈。
- `prompt` 的 `{E.latex}` 插入入口节点的属性；`answer E.value` 在题干后追加一个答案框。
- 该题无递归，不一定需要 `cost`。`cost` 不是必填关键字。

在网页的 **Rhema source → New Grammar** 创建此文件，Check、Save，再 Generate questions。生成不会只显示 AST，而是同时得到可预览的 `.pg`。

CLI 示例假定已经进入项目的 `generator/`，且文法保存在 `grammars/first.rhm`：

```sh
./_build/install/default/bin/rhema check grammars/first.rhm
./_build/install/default/bin/rhema run grammars/first.rhm --count 2 --student DEMO
./_build/install/default/bin/rhema grammars/first.rhm --count 2 --student DEMO -o /tmp/first.pg
```

<a id="lexical"></a>
## 3. 文件、词法与书写规则

| 项目 | 当前规则 |
| --- | --- |
| 文件 | 建议 UTF-8（不带 BOM）、扩展名 `.rhm`；顶层由一系列声明和产生式构成 |
| 标识符 | ASCII 正则 `[A-Za-z_][A-Za-z0-9_]*`；区分大小写 |
| 命名习惯 | nonterminal 用 `E`、`Q`、`F`；属性用 `value`、`latex`；不是强制规则 |
| 注释 | `#` 至行尾；字符串内的 `#` 是普通文本 |
| 整数字面量 | 十进制数字；负号通常是一元运算符；无小数、科学计数法或原生分数字面量 |
| 分数 | 写 `1 / 3`，由精确有理数运算产生 |
| 字符串 | 双引号，可直接跨行；只将 `\"` 和 `\\` 识别为转义 |
| 换行 | 一般是空白，不是必需的语句结束符；推荐一行一个声明/方程 |
| 分号 | 不支持 `;` 作为语句结束符 |
| 块 | 使用 `{ ... }`；产生式必须带块，即使内容为空 |
| 列表/数组 | 没有一般列表字面量；`set` 的 `{4,6,8}` 是专用预算语法 |

### 3.1 字符串与 LaTeX

`"\cdot"` 与 `"\\cdot"` 最终都得到 `\cdot`。`\n`、`\t` **不会**变成换行或 Tab，以免破坏 `\neg`、`\to`、`\times` 等命令。

需要题干换行时，在字符串中实际按回车：

```text
prompt "First paragraph.

Second paragraph."
```

字符串可以包含中文，但标识符必须使用上述 ASCII 形式。Rhema 允许的文本不意味着所有 PGML 特殊字符都自动安全，题干仍需符合 PGML 语法。

### 3.2 没有内置 true / false 字面量

`true`、`false` 既不是 reserved keyword，也不是自动定义的 Truth 常量。需要常量时可以显式定义：

```text
let yes = 1 = 1
let no = 1 = 0
```

或者在参数位置直接使用 `(1 = 1)`、`(1 = 0)`。`random p = boolean` 产生 Truth；`bool_true()` / `bool_false()` 产生的是 **Boolean formula 对象**，不是 Truth，不能互换。

<a id="keywords"></a>
## 4. 全部关键字与上下文词

### 4.1 全部 28 个 reserved keywords

以下词不能直接用作属性、random、let、nonterminal 或模块 alias 的名称。

| Keyword | 作用 | 常用写法 |
| --- | --- | --- |
| `attribute` | 声明 inherited 整数属性 | `attribute cost = 6 split` |
| `copy` | 剩余属性值复制给每个子 nonterminal | `attribute digit = 2 copy` |
| `split` | 将剩余属性值拆分给子 nonterminal | `attribute cost = 6 split` |
| `synth` | 声明 synthesized attribute | `synth value on E` |
| `on` | 限定 synthesized attribute 的所属 nonterminal | `synth text on Q` |
| `random` | 每题只抽一次的随机值 | `random a = integer_between(-3, 3)` |
| `boolean` | random 的 Truth 抽样形式 | `random p = boolean` |
| `let` | 每题计算一次的绑定 | `let total = a + b` |
| `start` | 指定入口 nonterminal | `start Q` |
| `context` | 指定 WeBWorK MathObjects context | `context "Numeric"` |
| `precedence` | 声明产生式显示的运算优先级 | `precedence 1 left + -` |
| `left` | 左结合的显示策略 | `precedence 1 left +` |
| `right` | 右结合的显示策略 | `precedence 2 right ^` |
| `nonassoc` | 同级子式也需括号 | `precedence 1 nonassoc "<"` |
| `when` | 子节点生成前的规则 guard | `when cost >= 1` |
| `weight` | 候选规则相对选择权重 | `weight 3` |
| `require` | 子节点/先前综合属性生成后的约束 | `require $3.value != 0` |
| `prompt` | PGML 题干模板 | `prompt "Evaluate [`{E.latex}`]."` |
| `answer` | 末尾答案或 inline placeholder 标记 | `answer E.value` |
| `width` | 答案框宽度 | `width 16` |
| `include` | 合并其他文件的声明 | `include "polynomial_core.rhm"` |
| `import` | 将其他文件作为独立模块 | `import "calculus.rhm" as calc` |
| `as` | 指定 import alias | `as calc` |
| `question` | 声明命名题型 | `question integral { ... }` |
| `set` | 声明整份作业 | `set homework { ... }` |
| `and` | Truth 逻辑与，短路求值 | `a > 0 and b > 0` |
| `or` | Truth 逻辑或，短路求值 | `a = 0 or b = 0` |
| `not` | Truth 逻辑非 | `not formula_is_zero(f)` |

特别注意：`left`、`right` 是 reserved keywords。方程左右边应命名 `lhs_expr`、`rhs_expr`，不要写 `let left = ...`。

### 4.2 set 的 10 个 contextual words

这些词由 parser 在 `set` 的特定位置识别，**不是全局保留字**。

| Word | 作用 |
| --- | --- |
| `part` | 新建一组题，可带标题 |
| `of` | 指定某题型的数量 |
| `any` | 从多个命名题型轮流均衡选择 |
| `in` | 从离散预算列表均匀覆盖取值 |
| `spread` | 围绕预算均值的抽样幅度 |
| `low` | 连续预算抽样的下界 |
| `allowed` | 预算只落在列出的离散值上 |
| `distinct` | 排除同题型的重复推导形状 |
| `balanced` | 限制连续重复的编码答案 |
| `ordered` | 在 part 内按显式预算总量排序 |

### 4.3 不是关键字的名字

`cost`、`len`、`digit`、`value`、`latex`、`pg_context`、`pg_width`、`main`、`integer_between`、`formula_add` 等都不是 lexer reserved keywords。

但有些名字具有约定或特殊用途：`main` 不能作为 `question` 块名；入口节点的 `pg_context` / `pg_width` 会被 runtime 特殊读取；builtin 名称由 checker 的注册表决定，并不等于任意 OCaml 函数都能调用。

<a id="scope"></a>
## 5. 声明与作用域

### 5.1 顶层可以写什么

```text
attribute NAME = SIGNED_INTEGER [copy | split]
random NAME = boolean
random NAME = GENERATOR(INTEGER_LITERAL, ...)
let NAME = EXPRESSION
synth NAME [on NONTERMINAL]
start NONTERMINAL
context "CONTEXT_NAME"
precedence LEVEL left|right|nonassoc OPERATOR ...
prompt "PGML_TEMPLATE"
answer EXPRESSION
width POSITIVE_INTEGER
include "FILE.rhm"
import "FILE.rhm" as ALIAS
question NAME { ... }
set NAME { ... }
NONTERMINAL -> SYMBOL ... [when CONDITION] [weight POSITIVE_INTEGER] { ... }
```

一般声明无需按固定先后排列，但 `let` 必须按依赖顺序写，include 合并顺序也有实际影响。推荐按“模块 → inherited → random → let → synth → precedence → start → productions → prompt/answer → questions/sets”组织。

### 5.2 每种位置能读什么

| 位置 | 可以读取 | 不可读取 |
| --- | --- | --- |
| `random` 参数 | 整数字面量，包括负整数 | 属性、其他 random、let、孩子 |
| `let` | 所有题级 random、之前的 let、已 import 模块的 random/let | 树节点、inherited、后面的 let |
| `when` | 当前 inherited、题级 random/let、模块题级值 | `$n`、子属性、尚未计算的 synthesized |
| inherited update | 同上；前面已更新的 inherited 值 | 子属性、synthesized 结果 |
| RHS generator / 模块参数 | 分配给该孩子位置的更新后 inherited、题级值 | 子节点结果 |
| synthesized equation | 子属性、更新后的 inherited、题级值、本规则前面已赋值的属性 | 后面才赋值的属性、其他规则的临时结果 |
| `require` | 与所在位置的 synthesized equation 相同 | 后面才生成的值 |
| prompt placeholder | 入口 synthesized、题级 random/let、模块题级值 | 一般表达式、任意子树路径 |
| 顶层/命名题型 `answer` | 入口 `Q.value`、模块题级 `alias.name`、字面量及由这些组成的表达式 | `$n`；当前 checker 不接受裸 `answer total` |

`answer total` 的替代方式：在 prompt 中使用 `{answer total}`，或将 total 赋给入口 `value`，再写 `answer Q.value`。

### 5.3 random 与 RHS generator 不一样

```text
random a = integer_between(1, 9)
```

`a` 在每道题的一次生成尝试中只抽一次，全题引用一致。整体重试时可能重新抽取。

```text
E -> integer_between(1, 9) "+" integer_between(1, 9) { ... }
```

两个叶子分别抽样；同一个 nonterminal 多次展开也分别抽样。命题变量赋值应使用题级 random，否则同名变量的多次出现可能不一致。

`let` 只绑定一次，不是函数定义，也不是可在产生式里反复修改的变量。规则内部不能声明新的 `let`，需要提前 `synth` 后赋值。

<a id="attributes"></a>
## 6. Inherited / Synthesized Attributes

### 6.1 Inherited：非负整数初值

```text
attribute cost = 6 split
attribute digit = 2 copy
attribute mode = 0
```

- 初值必须是非负整数，不支持表达式或 random 作为初值。
- 不写分配模式时默认为 `copy`。
- `cost`、`digit`、`mode` 都是用户声明的名字，不是自动存在的属性。
- 可以用命名题型的 `cost = 4`、CLI `--set cost=4`、set draw 或 Configure 调整根初值。

### 6.2 copy 与 split

假设当前 cost 是 6，规则先消耗 1，剩余 5，RHS 有两个可展开孩子。

| 模式 | 两个孩子得到什么 | 适合什么 |
| --- | --- | --- |
| `copy` | 各得 5 | 深度上限、模式、开关、最大位数等需分别保持的限制 |
| `split` | 得到非负整数对，总和为 5，例如 `(2,3)` | 整棵表达式的总结构预算 |

split 对非负整数分配方案作等概率抽样，不是先随意抽第一个再把余数给最后一个。只给本地 nonterminal 和 module nonterminal 分配；字符串、运算符、随机 generator 叶子不占预算份额。

无子 nonterminal 时，余下预算不会自动报错。若要“恰好花光”，必须用叶子 `when cost = 0` 等规则约束；**仅声明 split 不等于自动验证预算精确耗尽**。

copy 在分支递归中可让两个孩子都继续消耗同一数值，因此不能直接当作整棵树的运算次数。

### 6.3 Inherited update 是增量，不是赋初值

```text
cost = -2
```

表示 `new_cost = current_cost - 2`。同一写法出现在 `question { cost = 2 }` 时却表示根初值为 2，不能混淆。

规则中 `cost = 0` 表示不改变，不是清零。若要消耗全部当前值，可用 `cost = -cost`。正整数字面量更新会被 checker 拒绝；应始终编写不增长预算的更新，不要依赖 checker 为任意复杂表达式证明单调递减。

### 6.4 Synthesized：返回值及其完整性

```text
synth value on E
synth latex on E
synth text on Q
```

`on E` 表示只有 E 的每条规则都必须计算这个属性。无 `on` 的 `synth value` 要求所有本地 nonterminal 的规则都计算 value。

- 同名属性可分别 `on E`、`on Q` 声明。
- 同名属性不可既声明为全局 synthesized，又声明 scoped synthesized。
- 同名属性不可同时 inherited 和 synthesized。
- 每条适用规则必须赋值；同一规则不能重复赋同名属性。
- 属性的值可以是第 8 节的任意 runtime type，并非只能是数字。

generator 和其他终结符叶子只自带 `value`，没有 `latex`。显示随机叶子请写 `str($1.value)`。

<a id="productions"></a>
## 7. Production、when、weight、require

### 7.1 结构

```text
E -> E "+" E when cost >= 1 weight 3 {
  cost = -1
  value = $1.value + $3.value
  latex = infix($1, "+", $3)
}
```

产生式至少有一个 RHS symbol，不支持空产生式。guard 在 weight 前，次序不能交换。多条候选规则要重复写 LHS，不支持 `E -> ... | ...` 的替代缩写。

RHS 支持本地 symbol、裸运算符、字符串终结符、四类 generator、imported `alias.F(...)`。**没有本地参数化 nonterminal**：`F(cost=3)` 不是本地函数调用；命名参数形式只用于 `alias.F(cost=3)`。

### 7.2 子节点编号

对于 `E -> E "+" E`：`$1` 是左 E，`$2` 是加号终结符，`$3` 是右 E。

- `$1.value` 读属性。
- `$1` 是节点，仅在 `infix` / `prefix` 等需要节点的位置使用，不能拿来做加法。
- 在规则内部不能用 `E.value` 代替 `$1.value`，因为一个产生式中可以出现多个 E。
- 单独的字母若没有任何 LHS 定义，会成为文本终结符，**不会自动报告“未定义 nonterminal”**。拼错非终结符尤其需要检查生成树。

### 7.3 when 与 require

| | `when` | `require` |
| --- | --- | --- |
| 时机 | 应用本规则更新、生成孩子之前 | 孩子生成后，按块内顺序检查 |
| 依据 | 当前 inherited、题级值 | 子属性、当前已完成的 synthesized 等 |
| 失败 | 该规则不进入候选集 | 抛出 requirement failure，触发重试 |
| 例子 | `when cost >= 4` | `require $3.value != 0` |

除法必须先 require 再计算：

```text
require $3.value != 0
value = $1.value / $3.value
```

对 random / let 的约束可能要重试整题；只重试树不能改变本次已抽好的题级值。无效类型、未知 context 等错误不应寄希望于 require 重试来掩盖。

### 7.4 weight

默认 1，语法中的 weight 必须为正整数。候选规则权重 3 和 1 表示该步的相对概率约 3:1，不保证一批四道题中严格出现三次和一次；后续 require 过滤和重试也会影响最终分布。

网页允许把规则关闭或把权重设为 0，转换器会移除该 production；这**不意味着手写 `weight 0` 合法**。

<a id="expressions"></a>
## 8. 表达式、运算符与值类型

### 8.1 表达式

支持数字、字符串、名字、子属性、模块题级值、builtin 调用、一元/二元运算和括号。不支持一般函数定义、lambda、for/while、if/else、数组、对象字面量或任意 OCaml 调用。

| 操作 | 行为 |
| --- | --- |
| `+ - * /` | Num 的精确有理数运算，不自动重载成 Formula / Vector / Complex 运算 |
| `%` | 整数余数；两边必须为整数，除数非零；负数行为沿用 OCaml 余数，不保证非负 |
| `^` | Num 的整数幂；支持负整数幂，底数为零时负幂非法 |
| `++` | 拼接 Text 或能按数值文本使用的 Num；不会自动 LaTeX 格式化 |
| `= !=` | 按值类型比较，详见下表；不是赋值 `==`，没有 `==` 运算符 |
| `< <= > >=` | Num 比较；不是一般字符串或矩阵排序 |
| `and or not` | 操作 Truth；and/or 短路，不把数字 0/1 自动视为真假 |
| `cond(test, a, b)` | test 必须 Truth，只计算被选中的分支 |

表达式优先级从低到高：

```text
or
and
not
= != < <= > >=       不可连写 a < b < c
++                   右结合
+ -                  左结合
* / %                左结合
^                    右结合
一元 -               最高
```

尤其注意：当前 parser 把 `-2 ^ 2` 读成 `(-2) ^ 2`，不是通常数学约定的 `-(2 ^ 2)`。需要哪个含义就明确写括号。

### 8.2 Runtime types

| 类型 | 内容 | 正确构造或来源 |
| --- | --- | --- |
| `Num` | 精确有理数 | `3`、`1 / 3`、`polynomial_evaluate(...)` |
| `Text` | 文本/LaTeX | `"text"`、`formula_latex(...)` |
| `Truth` | 单个真假值 | `a > 0`、`random p = boolean`、`bool_equivalent(...)` |
| `Boolean` | 命题表达式 AST | `bool_and(bool_var("p"), bool_var("q"))` |
| `Complex` | 两个精确有理数构成的复数 | `complex(2, -3)` |
| `Formula` | 符号表达式 AST | `formula_power(formula_variable("x"), 2)` |
| `Polynomial` | 单变量、精确有理系数多项式 | `polynomial_quadratic(1, -5, 6, "x")` |
| `Equation` | 左右两个 Formula | `equation(lhs_expr, rhs_expr)` |
| `Matrix` | 精确有理数矩阵 | `matrix2(1,2,3,4)` |
| `Set` | 有限集合/区间/射线/集合运算树 | `set_union(a,b)` |
| `Vector` | 精确有理数分量向量 | `vector3(1,2,3)` |
| `VectorNormAnswer` | 模长答案包装 | `vector_norm_answer(v)` |
| `VectorUnitAnswer` | 单位向量答案包装 | `vector_unit_answer(v)` |
| `VectorDirectionAnswer` | 平行/同向答案包装 | `vector_parallel_answer(v)` 等 |

源码中的 `Rhema_number.t` 表示 `Rhema_number` 模块定义的类型 `t`，**不是 `.t` 文件**。同理适用于 Formula、Polynomial、Vector 等底层类型。

### 8.3 等号并非统一的数学等价判定

| 值 | `=` 的当前含义 |
| --- | --- |
| Num | 精确数值相等 |
| Text | 文本相同，不支持 `<` 等排序 |
| Truth | 真值相同；`!=` 相当于 XOR |
| Complex | 实、虚部都相同 |
| Polynomial | 变量相同，规范化系数相同 |
| Matrix / Vector | 形状及分量相同 |
| Boolean | 枚举相关变量赋值，判断逻辑等价 |
| Formula | 当前构造/简化后的结构相同，不是完整 CAS 等价检查 |
| Equation | 左右表达式结构相同，不是“解集相同” |
| Set | 集合表示树结构相同；有限集构造会去重排序，但一般集合运算不作通用集合等价证明 |

`formula_is_zero` 只识别当前简化器能归约到的零；不能据此声称它识别一切恒等于零的公式。比较一元多项式时，优先转换成 Polynomial。

Num 的分子分母使用 OCaml 原生整数，不是任意精度整数库。精确有理数不等于任意大数都无溢出风险，应控制参数和预算。

<a id="precedence"></a>
## 9. 优先级与表达式显示

必须区分两类优先级：

1. 第 8 节是 **Rhema 属性表达式的 parser 优先级**，由语言实现固定。
2. `precedence` 声明是 **被生成的数学表达式的显示优先级**，供 `infix/prefix` 决定括号，不能改变第 1 类。

```text
precedence 1 left + -
precedence 2 left * /
precedence 3 right ^
precedence 4 right "NOT"
```

level 越高结合越紧。operator 使用支持的裸运算符或字符串；不能在 operator 列表中直接写未加引号的 `AND`。

- `latex = infix($1, "+", $3)` 读取孩子的 `latex`。
- 若写 `text = infix(...)`，则读取孩子的 `text`；目标属性名不是硬编码为 latex。
- `prefix("\\neg", $2)` 同理，按当前规则优先级决定是否给孩子加括号。
- 规则 RHS 若包含多个声明过优先级的符号，当前实现取从左到右遇到的第一个。
- 叶子与没有声明运算优先级的规则视为 atom。
- `paren(text)` 只是给文本加括号；**不是 `paren($1)`，也不是树节点 renderer**。
- import 子树对外视作 atom；若组合运算需要括号，显式写 `"(" ++ $1.latex ++ ")"`。

typed Formula 的 `formula_latex` 使用 Formula 自身的 renderer，与这套 grammar-node 的 precedence 机制分开。

<a id="prompt"></a>
## 10. prompt、answer、width、context

### 10.1 prompt placeholders

prompt 是 PGML 字符串，不是 JavaScript/Python template。只支持下列替换：

| 写法 | 内容 |
| --- | --- |
| `{Q.latex}` | 入口 Q 的 synthesized 属性 |
| `{a}` | 题级 random / let |
| `{calc.given}` | import 模块的题级 random / let |
| `{answer Q.value}` | 此处插入针对该入口属性的答案框 |
| `{answer total}` | 此处插入针对题级 random / let 的答案框 |
| `{answer calc.total}` | 此处插入模块题级值的答案框 |
| `{{`、`}}` | 输出普通的 `{`、`}` |

`{a + b}`、`{formula_latex(Q.formula)}`、`{$1.value}` 不支持。先用 let/synth 计算，再插入名字。

普通文本替换只直接接受 Text / Num。Truth 先通过 `cond(p,"T","F")` 转成 Text；复杂数学对象使用其 `*_latex` builtin，不能直接 `{Q.formula}`。

模板替换只执行一遍。若 `Q.text` 中已经含有字符串 `{answer total}`，插入 `{Q.text}` 后不会再将它识别成答案空。答案空应直接写在 prompt 声明中。

### 10.2 大括号与 LaTeX

例如题级 `n` 的下标：

```text
prompt "Find [`a_{{{n}}}`]. {answer total}"
```

`{{` 输出左括号，`{n}` 插入值，`}}` 输出右括号，得到如 `a_{4}`。固定 LaTeX 的括号同样需要转义，如模板中的 `x^{{2}}`。通过 `formula_latex` 等插入的 Text 不会再次扫描模板括号。

### 10.3 两种答案声明方式互斥

末尾单空：

```text
prompt "Evaluate [`{E.latex}`]."
answer E.value
```

题干 inline 多空：

```text
prompt "(a) {answer Q.nth}

(b) {answer Q.sum}"
```

用了 inline blanks 后，不要再加顶层 `answer`。一题必须至少有一个答案空。多个答案空分别判分，但共享该题的 context 和 width；没有一般的逐空 context 声明。

### 10.4 width

`width 16` 控制输入框宽度，不是题目长度、最大答案位数或生成预算。静态值必须为正整数；未声明时输出标准 `[_____]{...}`。

入口可声明并计算 `synth pg_width on Q`，runtime 将其作为本题宽度；它应返回正整数。当前 runtime 读取它为整数，作者仍需自己保证正值，不要把手写负宽度当作合法用法。

### 10.5 context

默认 `Numeric`。常见 context 与答案类型：

| Context | 常用答案 |
| --- | --- |
| `Numeric` | 数值、Formula、多项式展开、Truth 的 1/0 编码 |
| `Complex` | `complex(re, im)` |
| `Vector` | Vector、单位向量/方向包装、模长 |
| `Matrix` | Matrix |
| `Interval` | finite Set、区间/射线和集合运算答案 |
| `Boolean` | Boolean formula，而不是单个 Truth |
| `PolynomialFactors` / `PolynomialFactors-Strict` | 保留因式结构的 Formula，交给对应 evaluator |

入口 `synth pg_context on Q` 返回 Text 可覆盖本题 context。命名题型自己的 context 次之，顶层 context 再次之。

checker 只检查 context 名称字符是否合法，不会提前连接 WeBWorK 确认它存在。名称允许 ASCII 字母、数字、空格、`_`、`-`，不可为空或带前后空格。数学变量名合法也不代表该 WeBWorK context 自动声明了同名变量；自定义变量需要实际渲染核验。

<a id="questions"></a>
## 11. 命名题型 question

顶层的 start/prompt/answer 形成 `main`。其他命名题型共享 rules、attributes、randoms 和 lets：

```text
question integral {
  start I
  prompt "{I.text}"
  answer I.answer_value
  context "Numeric"
  width 24
  cost = 7
}
```

块内只可放 `start`、`prompt`、`answer`、`context`、`width`、已声明 inherited 的整数初值。不允许在块内定义新的 random、let、synth、production 或 import。

每块需要自己的 start 与 prompt，以及末尾 answer 或 inline blanks；不自动继承 main 的题干和答案。context/width 未写时继承顶层。入口计算的 pg_context/pg_width 仍具有优先权。

`main` 不能作为块名。只有 question blocks 而无顶层题型时，不会凭空生成 main，默认选第一个块。CLI 用 `--question NAME` 指定；网页用 **Question form** 选择。

使用 `--question` 切换题型通常会改变 assignment identity，不保证仍使用相同的随机数学对象。需要同一个对象的多问，请在同一题使用多个答案框。

<a id="modules"></a>
## 12. include 与 import

| | include | import |
| --- | --- | --- |
| 写法 | `include "core.rhm"` | `import "calculus.rhm" as calc` |
| 组织方式 | 合并到当前 specification | 独立加载、检查和命名空间 |
| 调用规则 | 使用合并后的 `E`、`Q` | RHS 使用 `calc.F(...)` |
| 题级值 | 合并后的裸名 | `calc.given` 等模块 random/let |
| 读取子树结果 | `$1.poly` 等 | 同样 `$1.formula` 等 |
| 常见用途 | 在同一组因式树上改问法 | 组合不同领域/不同规则的子树 |

### 12.1 include 的覆盖与重名

当前文件自己的 start/prompt/answer/context/width 覆盖 included 文件对应声明。自身 inherited 声明优先于 included 的同名 inherited；否则先合入的声明优先。

rules、synth、random、let 等合并，部分一致声明按 AST 去重，不一致重名会由 checker 报错。AST 包含位置等信息，不应依赖“看起来相同的复杂 let 在不同文件中一定自动去重”。共享声明最好只定义一次。

include 不是任意覆盖函数/产生式的机制；不能假定再次写一条 LHS 就替换旧规则，通常会追加候选。

### 12.2 import 子树参数

```text
M -> calc.F(cost = cost) {
  answer_value = differentiate($1.formula, "x")
}
```

命名参数是被导入模块已声明 inherited 的根初值。未传的参数使用模块默认值，**不会仅因与父模块同名就自动传过去**。

父模块先更新/拆分 inherited，再在该孩子分到的环境中计算参数。若要传该份预算，写 `calc.F(cost = cost)`；不要在父规则已经扣过成本后又无意再次 `cost - 1`。

`calc.F` 是 nonterminal 子树，不是执行 `question F`。在 `set` 中 `calc.derivative` 则是命名题型。`alias.name(...)` 不能作为一般表达式函数调用，不能绕过 builtin 注册表。

同一模块路径在一次加载中缓存，其 random/let 每题抽/算一次。模块内部的 import 不自动成为外部 alias，不能写任意深的 `a.b.c`。导入树对外显示为 atom，组合时自行补括号。

### 12.3 路径查找与循环

依次查：引用文件旁边、各 `-I` 目录、`RHEMA_PATH`、当前安装/源码树的标准库候选目录。macOS/Linux 的 RHEMA_PATH 用冒号分隔，Windows 用分号。

建议可移植的相对路径；CLI loader 也接受绝对路径。直接或间接循环 include/import 被拒绝。`.rhm` 不是不可信输入的完整安全隔离环境，不要向未授权作者开放任意服务器文件路径。

<a id="assignments"></a>
## 13. 整份作业 set

`set` 是作业规范，不是数学 Set value。它引用本文件或 import 模块的命名题型：

```text
set homework {
  part "Differentiation"
    3 of calc.derivative(cost ~ 6 spread 2 low 2)
  part "Logic"
    3 of logic.main(cost in {8, 10, 12})
    2 of any(calc.derivative(cost = 5), logic.main(cost = 8))
  distinct
  balanced
  ordered
}
```

需要 `--run homework` 执行；只 import 和 set、无本地 rules 的作业文件是合法的，不要求虚构一个本地 synth/start。库文件可以没有自己的 question，但有 rules 的一般库仍需至少一个 synthesized attribute。

### 13.1 数量与预算

| 写法 | 当前含义 |
| --- | --- |
| `4 of calc.derivative(cost = 6)` | 4 个题都从 cost 6 开始 |
| `3 of logic.main(cost in {8,10,12})` | 每轮随机打乱列表，使用一遍后再重复；不是三次独立随意抽样 |
| `cost ~ 6 spread 2 low 2` | 正态抽样、舍入/截断，再有限次调整总和趋近 mean×数量 |
| `allowed {4,6,8}` | 只在离散预算中取值；均值可能无法恰好达到 |
| `2 of any(A, B)` | 题型选择也采用打乱轮次均衡覆盖，不是 weight 语法 |

`~` 的 spread 默认 2、low 默认 0。mean/spread/low/allowed 值必须非负整数。作者应保证 allowed 都满足所需下界，不要假设 low 会替你过滤任意 allowed；当前有限次均值调整也不是全局最优约束求解器。

预算 draw 只能控制 inherited，不能直接给某个 random 赋值，也没有 set 内任意 require 表达式。

### 13.2 作业约束的确切范围

- `part "Heading"`：后续题形成同一编号下的小问；只有一个成员时不加小问字母。没有 part 时每题单独编号。
- `distinct`：比较“题型名 + 应用产生式的树形”，忽略随机叶子的数值。两个只换了数字的相同推导形状仍可能被拒绝；它不是通用题意去重。
- `balanced`：针对第一空是 Truth 或一位非负整数编码的题，避免连续三个同编码。非编码答案不参与该序列；不是对所有答案强制全局频率 50:50。
- `ordered`：生成前在各 part 内按该 slot **显式提供的预算值总和**排序，不是按知识点或经学生表现验证的难度排序。

约束过强、可用形状太少时会失败，不保证总能生成。作业级每题约束重试上限为 60。普通 `--count` 生成没有自动 distinct；需要去重时使用合适的 set 策略。

网页目前没有完整的 set 编排/运行界面。set-only 文件不能按普通题型直接 Generate；使用 CLI `--run`。

<a id="builtins"></a>
## 14. 完整 builtin 目录

当前 checker 注册 **130 个表达式 builtin + 4 个随机 generator，共 134 个**。下表全部列出，函数名和参数顺序区分大小写。类型在 runtime 使用时检查；不是每个调用都经过完整的静态类型推导。

记号：`Num` 精确数，`Int` 要求为整数的 Num，`Text` 字符串，`Truth` 单个真假；`F` Formula，`P` Polynomial，`Eq` Equation，`B` Boolean formula，`M` Matrix，`S` Set，`V` Vector，`Node` 用 `$n` 引用的生成节点。

### 14.1 随机 generator：4 个

它们只能用于 RHS 叶子，或 `random` 的抽样形式，不是一般表达式函数。

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `integer(digits)` | 叶子 value: Num | 正常 digits=1 时 0–9；digits>1 时对应位数正整数；没有随机负号 |
| `nonzero_integer(digits)` | 叶子 value: Num | 同上但拒绝 0 |
| `integer_between(lower, upper)` | 叶子 value: Num | 闭区间整数，允许负数，lower≤upper |
| `nonzero_integer_between(lower, upper)` | 叶子 value: Num | 同闭区间但排除 0，不能仅 `[0,0]` |

建议 digits 使用小的正整数；runtime 的 digits≤1 分支仍是 0–9，而不是“0 位数”。过大位数和区间会触及原生整数/随机函数限制。网页另有安全范围，不代表核心语言也自动限制到同一范围。

RHS 可写 `integer(digit)`，但 `random a = integer(digit)` 不合法，因为 random 参数必须是整数字面量。`random p = boolean` 是另一个专用语法，没有 `boolean()` generator。

### 14.2 通用、显示与整数函数

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `str(value)` | Text | 当前接受 Text / Num；不把任意 typed object 或 Truth 自动转字符串 |
| `paren(text)` | Text | 给 Text / 数字文本加圆括号，不接收 Node |
| `infix(lhs_node, op_text, rhs_node)` | Text | Node 参数写 `$1`、`$3`；按目标属性和规则 precedence 补括号 |
| `prefix(op_text, node)` | Text | Node 参数写 `$2` 等；一元运算显示 |
| `cond(test, yes_value, no_value)` | 分支值的类型 | test: Truth，惰性选择一个分支 |
| `abs(n)` | Num | 数值绝对值，不是复数模长 builtin |
| `min(a, b)` | Num | 较小数 |
| `max(a, b)` | Num | 较大数 |
| `bit_and(a, b)` | Int | 整数按位与 |
| `bit_or(a, b)` | Int | 整数按位或 |
| `bit_xor(a, b)` | Int | 整数按位异或，不是 Truth XOR |
| `number_latex(n)` | Text | 精确数的 LaTeX，分数输出 `\frac` |
| `factorial(n)` | Int | `n!`；0≤n≤20 |
| `choose(n, k)` | Int | 组合数；参数非负，k>n 返回 0；检查过大结果 |
| `permutations(n, k)` | Int | 有序选取数；参数非负，k>n 返回 0 |
| `gcd(a, b)` | Int | 最大公约数 |
| `lcm(a, b)` | Int | 非负最小公倍数；任一为零时返回 0 |
| `pow_mod(a, k, n)` | Int | `a^k mod n`；k≥0，0<n≤3037000499 |
| `mod_inverse(a, n)` | Int | 模逆，n≥2 且 gcd(a,n)=1；否则报错 |

### 14.3 Complex

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `complex(real, imaginary)` | Complex | 两个 Num 分量构造答案对象 |
| `complex_latex(real, imaginary)` | Text | 规范显示 `a+bi`，处理 0、±1 等分量 |

没有 `complex_add`、`complex_multiply`、`complex_abs` 这些 builtin。递归复数题在 grammar 中综合 re/im，再用 `complex(re,im)` 构造最终答案；例如乘法实部 `ar*br-ai*bi`、虚部 `ar*bi+ai*br`。普通 `+` 不直接接受 Complex。

### 14.4 Formula

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `formula_constant(n)` | F | Num 常数 |
| `formula_variable(name)` | F | Text 变量名 |
| `formula_add(a, b)` | F | a+b，参数都是 F |
| `formula_subtract(a, b)` | F | a-b |
| `formula_multiply(a, b)` | F | a×b |
| `formula_divide(a, b)` | F | a/b；已识别的零分母非法 |
| `formula_power(base, exponent)` | F | exponent: Int，可表示整数幂 |
| `formula_negate(body)` | F | 负号 |
| `formula_sin(body)` | F | 正弦 |
| `formula_cos(body)` | F | 余弦 |
| `formula_tan(body)` | F | 正切 |
| `formula_exp(body)` | F | 指数 e^body |
| `formula_ln(body)` | F | 自然对数 |
| `formula_sqrt(body)` | F | 平方根 |
| `formula_substitute(body, variable, replacement)` | F | variable: Text，replacement: F；符号替换，不是返回数值的 eval |
| `differentiate(body, variable)` | F | variable: Text；符号求导 |
| `formula_latex(body)` | Text | 带优先级括号的公式显示 |
| `formula_is_zero(body)` | Truth | 判断当前简化结果是否为零，不是完整恒等式证明 |
| `formula_to_polynomial(body, variable)` | P | 可表示成指定单变量多项式时转换，否则报错 |

目前没有公开 `formula_eval`、`formula_to_pg` 或通用 `integrate` builtin；OCaml 模块里存在的辅助函数不自动成为 DSL API。一般公式数值求值可通过适合的已公开操作设计，Polynomial 则使用 `polynomial_evaluate`。

符号构造并不替作者自动证明定义域。ln、sqrt、商式需要在生成策略中限制参数或明确题目的定义域。

### 14.5 Polynomial

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `polynomial_constant(value, variable)` | P | Num 常数、Text 变量 |
| `polynomial_variable(variable)` | P | 指定变量本身 |
| `polynomial_monomial(coefficient, degree, variable)` | P | degree≥0 的 Int |
| `polynomial_linear(a, b, variable)` | P | a*x+b |
| `polynomial_quadratic(a, b, c, variable)` | P | a*x²+b*x+c |
| `polynomial_add(a, b)` | P | 同变量多项式相加 |
| `polynomial_subtract(a, b)` | P | 相减 |
| `polynomial_multiply(a, b)` | P | 相乘并合并系数 |
| `polynomial_scale(scalar, polynomial)` | P | Num 数乘，scalar 在前 |
| `polynomial_power(polynomial, exponent)` | P | exponent≥0 的 Int |
| `polynomial_derivative(polynomial)` | P | 单变量求导 |
| `polynomial_evaluate(polynomial, point)` | Num | 精确代入 point: Num |
| `polynomial_coefficient(polynomial, degree)` | Num | degree≥0；超过次数返回 0 |
| `polynomial_degree(polynomial)` | Int | 零多项式返回 -1 |
| `polynomial_is_zero(polynomial)` | Truth | 系数规范化后的零判定 |
| `polynomial_formula(polynomial)` | F | 转成 Formula |
| `polynomial_latex(polynomial)` | Text | 多项式 LaTeX |
| `polynomial_equation(lhs_poly, rhs_poly)` | Eq | 同变量 P 构成方程 |

加减乘与构造方程要求变量一致，不能直接混用 x 和 y。该类型是一元多项式，不是通用多元 CAS。

### 14.6 Equation

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `equation(lhs_formula, rhs_formula)` | Eq | 两个 F 构成方程，不接收普通数字或 Text |
| `equation_normal_form(eq)` | F | 左边减右边 |
| `equation_latex(eq)` | Text | 左边 = 右边的显示 |
| `equation_is_satisfied(eq, variable, value)` | Truth | variable: Text，value: Num；多项式路径精确，其他支持的 Formula 路径用浮点容差 |
| `equation_has_exact_solutions(eq, variable)` | Truth | 当前 solver 返回非空有限精确解才为真 |
| `equation_solution_count(eq, variable)` | Int | 有限精确解数量；无解为 0；无限解/不支持则报错 |
| `equation_solution_set(eq, variable)` | S | 有限精确解集；无解为空集；无限解/不支持则报错 |
| `equation_unique_solution(eq, variable)` | Num | 恰有一个精确解时返回，否则报错 |

当前 exact solver 针对可转换的一元多项式、次数≤2。二次的实根还需能表示为精确有理数；一般无理根、复杂超越方程、更高次方程不支持。`equation_has_exact_solutions` 对“无解”“无限解”“不支持”都返回 false，不能把 false 简单解释为“数学上无解”。

Equation 不能直接作为 PGML answer，必须先变成唯一解或解集。`equation_is_satisfied` 的非多项式回退不是严格的符号证明。

### 14.7 Boolean formula

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `bool_var(name)` | B | 命题变量，Text 名称以 ASCII 字母开头 |
| `bool_true()` | B | 真常量公式，不是 Truth |
| `bool_false()` | B | 假常量公式 |
| `bool_not(f)` | B | 否定 |
| `bool_and(f, g)` | B | 合取 |
| `bool_or(f, g)` | B | 析取 |
| `bool_xor(f, g)` | B | 异或 |
| `bool_imp(f, g)` | B | 蕴含 |
| `bool_iff(f, g)` | B | 双条件 |
| `bool_latex(f)` | Text | 命题显示，按本库课程式括号规则 |
| `bool_equivalent(f, g)` | Truth | 穷举两式相关变量的全部赋值 |
| `bool_evaluate(f, names, mask)` | Truth | names: `"p,q,r"`，mask: Int；第 i 个变量对应第 i 个二进制位，从 0 开始 |
| `bool_sensitivity(f, names, mask)` | Int | 该赋值下，单独翻转会改变结果的变量数 |
| `bool_is_tautology(f)` | Truth | 所有赋值为真 |
| `bool_is_contradiction(f)` | Truth | 所有赋值为假 |
| `bool_is_tidy(f)` | Truth | 本库的结构整洁启发式：排除常量、双重否定、部分重复/吸收式结构等；不是通用自然度模型 |
| `bool_is_atom(f)` | Truth | 变量或单次否定变量 |
| `bool_top(f)` | Text | `var/const/not/and/or/xor/imp/iff` |
| `bool_size(f)` | Int | 二元联结词 + 作用于复合式的否定；否定变量不计入 |
| `bool_negations(f)` | Int | 所有 Not 节点数 |
| `bool_depth(f)` | Int | atom 深度 0，每经过一个连接词/Not 加 1 |
| `bool_count(f, top_name)` | Int | 整棵公式中 top 等于给定 Text 的节点数，不只是根节点 |
| `bool_variable_count(f)` | Int | 不同变量数 |
| `bool_model_count(f)` | Int | 该公式自身变量上使公式为真的赋值数 |
| `bool_without_conditionals(f)` | B | 消去 imp/iff/xor，转换为 not/and/or，不是一般逻辑简化器 |

例：`bool_evaluate(f,"p,q,r",5)` 表示 p=true、q=false、r=true。names 应包含公式使用的全部变量；缺少赋值会报错。model count 的宇宙是公式实际出现的变量，不是题干随意列出的更多变量。

等价、重言式、模型计数采用枚举，有指数复杂度。标准题通常只用少量变量；不要将大型命题系统的性能当作已有能力。

### 14.8 Set

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `set_empty()` | S | 空有限集 |
| `set_insert(set, element)` | S | element: Num；只接受 finite set，去重排序 |
| `set_interval(lower, upper, left_closed, right_closed)` | S | lower<upper；两个 closed 参数必须 Truth，不是 0/1 |
| `set_above(bound, closed)` | S | 从 bound 到正无穷的射线，closed: Truth |
| `set_below(bound, closed)` | S | 从负无穷到 bound 的射线 |
| `set_union(a, b)` | S | 构造并集运算树 |
| `set_intersection(a, b)` | S | 构造交集运算树 |
| `set_difference(a, b)` | S | 构造差集运算树 |
| `set_latex(set)` | Text | 按集合运算优先级显示 |

没有通用 `set_contains` / `set_size` DSL builtin。不能向并集/区间树直接 `set_insert`。相交、相差的表达式不必在 OCaml 端自动归约成最简区间，WeBWorK context 负责相应答案解析和比较。

### 14.9 Vector

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `vector2(a, b)` | V | 两个 Num 分量 |
| `vector3(a, b, c)` | V | 三个 Num 分量 |
| `vector4(a, b, c, d)` | V | 四个 Num 分量 |
| `vector_add(a, b)` | V | 同维相加 |
| `vector_subtract(a, b)` | V | 同维相减 |
| `vector_scale(scalar, vector)` | V | Num 数乘，scalar 在前 |
| `vector_dot(a, b)` | Num | 同维点积 |
| `vector_cross(a, b)` | V | 仅两个三维向量 |
| `vector_entry(vector, index)` | Num | index 从 1 开始 |
| `vector_latex(vector)` | Text | 向量显示 |
| `vector_is_zero(vector)` | Truth | 全分量为零 |
| `vector_norm_answer(vector)` | 模长答案包装 | 给 PGML evaluator 使用，不是一般 Num 求根函数 |
| `vector_unit_answer(vector)` | 单位向量答案包装 | 非零向量；不要作为一般 Vector 再进行运算 |
| `vector_parallel_answer(vector)` | 方向答案包装 | 接受与目标平行的向量；作者需排除零参考向量 |
| `vector_same_direction_answer(vector)` | 方向答案包装 | 加 sameDirection comparator |

没有一般 `vector_norm` 或 `vector_unit` DSL builtin。包装类型用于输出答案，不应继续传给 `vector_add` / `str`。

### 14.10 Matrix

| 签名 | 返回 | 说明 |
| --- | --- | --- |
| `matrix2(a, b, c, d)` | M | 按行构造 `[[a,b],[c,d]]` |
| `matrix3(a, b, c, d, e, f, g, h, i)` | M | 按行构造 3×3 矩阵 |
| `matrix_identity(size)` | M | size: Int 的单位矩阵；建议小正整数 |
| `matrix_add(a, b)` | M | 同形矩阵相加 |
| `matrix_subtract(a, b)` | M | 同形相减 |
| `matrix_multiply(a, b)` | M | 矩阵乘法，内维匹配 |
| `matrix_scale(scalar, matrix)` | M | Num 数乘 |
| `matrix_transpose(matrix)` | M | 转置 |
| `matrix_determinant(matrix)` | Num | 方阵行列式 |
| `matrix_inverse(matrix)` | M | 非奇异方阵的精确逆；先检查可逆性 |
| `matrix_is_invertible(matrix)` | Truth | 是否可逆 |
| `matrix_entry(matrix, row, column)` | Num | 行、列均从 1 开始 |
| `matrix_vector(matrix, vector)` | V | 矩阵作用于向量，维度匹配 |
| `matrix_latex(matrix)` | Text | pmatrix 形式 |
| `matrix_row_latex(matrix, row)` | Text | 把指定行写成线性组合，用于方程组；最多 4 个未知数 |

没有通用 `matrix([...])` 字面量接口或 `eigenvalues(matrix)` builtin。标准 eigen 题用构造已知分解等方法出题，不能据题型名称推断任意矩阵特征值求解器已存在。

<a id="determinism"></a>
## 15. 可复现生成与 seed

CLI 优先级：

```text
显式 --seed N
  否则 assignment + "/" + student 的摘要种子（有 --student 时）
  否则 assignment 的摘要种子
```

实现用 OCaml `Digest` 摘要的前 8 个十六进制字符转整数，再初始化伪随机生成器；不是密码学安全的随机机制，也不提供无碰撞保证。

- CLI 默认 assignment 是“输入 basename 去扩展名 + : + question 参数”，set 默认是 set 名；可用 `--assignment` 明确固定。
- 当前网页 source 模式使用带扩展名的 `filename.rhm:question`；因此裸 CLI 默认值与网页不完全相同。对齐时显式传 `--assignment filename.rhm:main`。
- Configure 使用 base grammar、question 及规范化配置摘要形成 assignment；不能假定与原始源码模式逐题相同。
- 重现需要保留引擎/依赖版本、源码、导入模块、参数、命名题型、数量和 identity。文件名/模式/规则顺序变化都可能改变结果。
- 相同结果不要求输出路径时间戳相同；不同学号也不保证绝不撞题。
- 普通 count 是从固定随机状态连续生成；set 则为计划中各位置派生种子，并为约束重试派生变体。

如果把随机范围都固定、只留一条固定规则，无论多少 seed 都可能得到相同题；要增加多样性，应扩大合法空间和结构，而不是单纯改 seed。

<a id="execution"></a>
## 16. 执行顺序、重试与终止限制

1. 解析文件，展开 include，加载并检查 import，检查本文件。
2. 选择 question 或 set，应用根预算覆盖，确定 seed。
3. 为本题抽取模块和本地 random，再依序计算 lets。
4. 节点根据原始 inherited 检查 when；筛除更新后会负预算的规则。
5. 按 weight 选规则，在孩子生成前依序应用所有 inherited updates。
6. copy/split，生成 RHS 孩子；模块参数读取该孩子分得的环境。
7. 按原块内顺序计算 synthesized equations 与 require。即使 inherited update 写在块末尾，它仍在孩子之前处理，别把它当作后置命令。
8. 从最终根节点读取 prompt、答案、pg_context/pg_width，输出 typed question。
9. PGML emitter 转换答案和 context；WeBWorK 在渲染/提交时解析与判分。

当前限制：每个节点 requirement 重试最多 40 次，整题 requirement/可恢复数值错误重试最多 200 次，树构造有 200000 次展开 fuel。没有随机选择可改变结局的确定失败会提前结束。

不是所有异常都可重试：`require false` 与无效类型/不支持数学调用属于不同错误路径。无规则匹配、形状不合法等应修规范，不要依赖“再生成一次”。

checker 对终止性进行保守形状检查：存在终止路径、递归环要显示消耗 inherited。它忽略 guards，部分非字面量更新会被宽松处理；这是检查与安全限制，不是任意 specification 终止性的形式证明。

<a id="pgml"></a>
## 17. PGML 与 WeBWorK 输出

典型输出：

```perl
DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");

BEGIN_PGML
Compute [`2+3`].[_____]{answer=>5,width=>12}
END_PGML
ENDDOCUMENT();
```

| Runtime answer | PG 中的典型形式 |
| --- | --- |
| 整数 Num | `5` |
| 有理数 Num | `Formula('1/3')` |
| Truth | `1` 或 `0` |
| Complex | `Complex(re,im)` |
| Formula / Polynomial | `Formula('...')` |
| Boolean | `Compute("...")`，需要 Boolean context |
| Set | `Compute("...")`，使用相应 Interval context |
| Vector | 向量 Compute 和相应包装/comparator，使用 Vector context |
| Matrix | Matrix MathObject 表示 |
| Equation | 不可直接输出，先求解 |
| Text | 当前按 `Formula('text')` 发出，不是任意自然语言答案的 String evaluator |

不同题 context 不同时，emitter 分成多个 BEGIN_PGML/END_PGML 块，在块间切换 Context；Boolean 和 PolynomialFactors context 会追加所需 macro。**同一题内部仍只有一个 context**。

WeBWorK Formula 比较通常接受代数等价输入，不代表自动强制“展开/因式分解/无条件连接词”等书写形式。若这些是考核要求，要选择对应 context/comparator，或明确说明当前只判等价。

Rhema 对任意自定义题干的 PGML 兼容性不作静态完整证明，也不保证所有 Rhema 输出都能被 Classic 的固定 PGML parser 读回。成功 `rhema check` 不等于已通过真实 WeBWorK 渲染与判分。

<a id="web"></a>
## 18. 网页使用方法

### 18.1 已有题型：Configure

1. 在 **Question library** 选题型，默认进入 Configure。
2. 选择 Question form、Number of questions，调整题级随机范围和其他暴露参数。
3. 展开 Advanced settings 设置预算、规则开关、weight/price、叶子范围。
4. 支持表达式 operator-count 的文法可限制数量；它不是字符数、深度或题数。
5. Output settings 调整答案框宽度或附加说明。
6. Generate questions，查看 Questions、PGML、Productions / Attributes。
7. Generated Rhema 显示本次表单真正生成的源码。Save preset 另存用户文法，Export specification 导出含依赖的材料。

表单派生自 parsed AST 和导入库，不另写一套数学答案计算。固定形式题的可用成本是离散的，不能随意设一个 cost 期待自动生成更长问题。

### 18.2 新建/编辑题型：Rhema source

1. 切换 Rhema source，New Grammar，填写未占用的 `.rhm` 文件名，Create Draft。
2. 写完整 specification，Check 查看位置错误，Save 成功后再 Generate。
3. 标准题库与自定义文件可选；新保存的命名题型未出现时刷新并重选。
4. 用户文法放 `generator/grammars/`，标准库在 `generator/stdlib/`。本地自定义文法通常在 My presets 列表。

新建/Configure 文件名有网页自己的更严格限制：主体 1–80 字符、ASCII 字母数字开头，由字母数字、`_`、`-` 构成，扩展名 `.rhm`；不要把操作系统允许的任意文件名当作网页可接受的名字。

手工修改已保存 form preset 或其依赖后，Configure 会拒绝不安全地重建；继续源码模式，或从原标准题型新建 preset，不会静默覆盖手写逻辑。

### 18.3 预览、判分与语言

- Questions 中真实 WeBWorK inputs 可输入答案，点击 Check answers 查看总分和逐空反馈。
- 需要 Docker renderer 在线；Local preview 是本地 KaTeX fallback，不能判分。
- 这不是课程 gradebook 集成，不向真实课程自动记录分数。
- Productions / Attributes 是 AG 推导和属性树，不是 Classic parser 的 AST/DCST。
- UI 的 English/中文切换只翻译界面，不翻译 specification、题干和数学内容。
- settings/preview 分隔线可拖动，窄屏改为上下布局。

### 18.4 本机启动

在项目根目录先启动 Docker Desktop，然后：

```sh
docker compose -p rhema-workspace-local up -d --wait webwork-renderer
```

依赖尚未安装时按项目 README 建立 `.venv` 并安装 requirements；引擎更新后在 `generator/` 运行 `dune build`。回到根目录：

```sh
APP_PORT=5003 .venv/bin/python app.py
```

打开 <http://127.0.0.1:5003/>。端口是运行配置，不是 Rhema 语法。已经启动同一项目时不要重复起服务；多个旧 checkout 的页面可能导致“改了文件但 UI 没变”的误判。

### 18.5 VS Code 扩展入口

项目还提供 `rhema.rhema-language` 扩展，当前仓库版本为 0.1.1。它支持 `.rhm` 高亮、折叠、snippets、checker 诊断，以及 **Rhema: Check File / Run Question / Compile to PG**。

- Check 调用 `rhema check`，默认停止输入约 400 ms 后检查，错误放入 Problems。
- Run 先 `rhema list` 选择 question/set，再调用 `rhema run`，题面和答案显示在 Output → Rhema。
- Compile UI 调用普通 `rhema FILE.rhm` 编译入口，不存在 `rhema compile FILE.rhm` 子命令；输出放源文件旁，set 按其名称命名。
- 按钮流程默认 count=5、没有 student 参数；预算 override、学生、数量和树输出等完整控制可在 VS Code 集成终端执行 CLI。
- 编辑支持不是另一套生成器，也不应描述为已实现完整 LSP/所有语义补全。

可用 [专用 demo 工作区](deliverables/fyp_demo_20261031/Rhema-Demo.code-workspace) 指定本项目引擎路径；详细步骤和每阶段输入/输出见 [VS Code / CLI 操作稿](deliverables/fyp_demo_20261031/VSCODE_CLI_DEMO.md)。原生编辑器操作需要用户允许相应电脑控制；本说明核验的是实现和实际 CLI 调用，不冒称已经点击验证当前 VS Code 窗口。

<a id="cli"></a>
## 19. CLI 完整用法

以下用 `rhema` 表示已安装的命令。在当前源码仓库的 generator 目录可替换为 `./_build/install/default/bin/rhema`；未构建先 `dune build`。

```sh
rhema FILE.rhm [-o OUT.pg] [options]
rhema check FILE1.rhm FILE2.rhm
rhema run FILE.rhm [options]
rhema list FILE.rhm
rhema doc
rhema doc differentiate
rhema --version
rhema --help
```

| 参数 | 作用 |
| --- | --- |
| `-o FILE` / `--out FILE` | PG 输出路径；`-o -` 写 stdout |
| `--question NAME` | 选择命名题型；默认 main 或文件第一个 question block |
| `--run SET` | 执行文件声明的作业 set |
| `--count N` | 普通题生成数，CLI 默认 5，必须正整数 |
| `--assignment NAME` | 固定作业 identity |
| `--student ID` | 学生 identity，用于派生种子 |
| `--set NAME=VALUE` | 覆盖选中题的 inherited 初值，只接受非负整数及已声明属性 |
| `-I DIR` | include/import 搜索目录，可重复 |
| `--ast-out FILE` | 导出 derivation / attribute 文本，不是源文件 parser AST |
| `--visualization-out FILE` | 导出交互式 production/attribute HTML |
| `--pg-dir DIR` | 只用于 `--run`，额外逐题生成 question01.pg 等 |
| `--seed N` | 实现支持的测试/工具选项，优先于 assignment/student；未列在普通 help 中 |

`run` 打印题面与标准答案，不默认写 PG；`check` 只检查；`list` 查看 imports、questions、budgets、sets；`doc` 列 builtin 分类与 arity，当前单个 doc 调用也不是完整的带类型教程。

默认 PG 输出在当前工作目录，以输入文件 basename 或 set 名命名。输出父目录应已存在，不要假设所有 FILE 参数都自动递归建目录。

运行 set 时不要与 `--question` 混用，会报错；`--count` / `--set` 也不负责覆盖 set 内定义的数量和 draw。作业应在 `.rhm` 内改，不能依赖这些普通题参数。

示例：

```sh
rhema run stdlib/calculus.rhm -I stdlib --question integral --set cost=5 --count 2 --student DEMO
rhema stdlib/homework_set.rhm -I stdlib --run homework --student DEMO -o /tmp/homework.pg
rhema stdlib/arithmetic.rhm -I stdlib --count 2 --visualization-out /tmp/trees.html -o /tmp/paper.pg
```

输入文件本身若使用简写 basename，需要它在当前目录，或使用明确的 stdlib/FILE.rhm 路径；`-I` 主要用于载入依赖，不应把所有顶层路径查找都想当然地当作 import 搜索。

退出码：成功 0；文件检查/生成失败 1；命令行用法错误 2。

<a id="errors"></a>
## 20. 常见错误与修正方法

| 现象 | 原因 / 修正 |
| --- | --- |
| `unexpected left` / `unexpected right` | 用了保留字做名字；改 lhs_expr / rhs_expr |
| `unknown name 'true'` | 没有 Truth 字面量；定义 `let yes = 1 = 1` 或使用比较 |
| `unknown function 'equation'` | 旧引擎或错误 checkout；当前版本已注册，检查执行路径并重建，不能只更新网页文件 |
| generator 不能在 equation 中用 | `value = integer_between(...)` 不合法；使用题级 random 或 RHS generator |
| random 参数必须 literal | 不能 `random a = integer_between(1,max_value)`；将可变范围用 RHS generator 描述 |
| `$3.latex` leaf 错误 | 叶子只有 value；用 `str($3.value)` |
| guard 中 child 不存在 | when 只看向下信息，把子结果条件放 require |
| synth 缺失 | 某条规则漏算适用属性；补全或改为 scoped synth |
| 属性重复赋值 | 每条规则同名只能赋一次；需要中间量时另声明 synth |
| no rule fits | 当前预算/模式与规则 guards 不兼容；先检查叶子和成本组合 |
| recursion without spending | 缺 base case 或递归没有消耗 inherited；不是加大 retries 能解决 |
| repeated require failure | 合法空间太小、约束矛盾、前置 random 固定；先手工找一个满足例子 |
| expected true/false | 把 Num、Boolean formula 当作 Truth；用比较或 bool_evaluate |
| expected text | typed 对象直接插模板或 str；改为对应 *_latex，Truth 用 cond |
| prompt 显示 `{answer ...}` 字样 | 把 placeholder 放在合成 text 内；模板不二次解释，直接写在 prompt |
| template 的 unclosed brace | LaTeX 括号没转义；固定括号写 {{ 和 }} |
| answer total 报 ambiguous | 顶层 answer 不接受裸题级变量；用 `{answer total}` 或入口 synth |
| equation finite exact set 错误 | 无限解/无理根/次数>2/非多项式；先检查求解支持范围 |
| 类型正确但 WeBWorK 报错 | context/macro/变量/PGML 不兼容；check 不等于 PG 翻译测试 |
| 一个新题生成多次一样 | 参数固定或结构空间小；不是 seed 保证唯一，检查 random 和规则 |
| 同学号 CLI 与网页不同 | assignment identity、模式、配置、源码/依赖版本不同；显式对齐 |
| 元数据 preset 无法重开 Configure | 已手工改源码/依赖，避免覆盖逻辑；继续 source 模式 |

Rhema 错误通常包含 `file:line:column`，新版 AST 保留引用位置；生成阶段某些消息仍以规则/require 行号为主，不能保证每个 runtime 异常都指向最细表达式。

<a id="limits"></a>
## 21. 当前能力边界

本语言已有 arithmetic、Boolean、calculus、complex、sequence、set、vector 及后续 algebra/matrix/counting/number theory/series/limits/eigen/inequality 等标准 specification。但它不是“任意数学题输入就自动理解”。

- 没有自然语言 specification parser、一般自定义函数、任意类型声明、循环脚本或任意 OCaml FFI。
- 没有通用积分、任意方程求解、任意矩阵特征分解或全功能 CAS。
- Formula 与 Set 的当前 equality 不是一般语义等价证明。
- 逻辑枚举、递归生成与约束重试有性能边界，预算不宜无上限增大。
- cost 是可控制结构成本，不是经学生数据校准的心理/教学难度；width 也不代表题目长度。
- `require` 是运行时拒绝采样，不是完整 SMT/constraint solver，不保证可满足。
- 数学正确性依赖 builtin、specification 的答案关系与独立测试；成功渲染只表示 PG 接受，成功判分只表示 evaluator 接受该提交。
- 当前网页没有完整 set 编辑器、课程成绩册集成或学习者表现驱动的自适应出题。
- DSL 和 PGML 输入不应视作服务器安全沙箱，部署时仍需鉴权、路径与执行隔离。

<a id="checklist"></a>
## 22. 编写和验证检查表

1. 先定义题目：已知量、未知量、标准答案类型、合法定义域、可接受的学生输入形式。
2. 判断需要递归结构还是固定题型：固定题可不声明 cost；递归题设计 base case 和消耗。
3. 选择题级 random 与叶级 generator，确保重复变量赋值一致。
4. 用 typed value 保存数学对象；不要拿显示字符串冒充答案语义。
5. 每条规则计算完整属性，require 放在危险运算之前。
6. 检查不会过度简化成无意义题；按需要限制零、相同两式、重复因式、奇异矩阵等。
7. 选择正确 context，若要求具体形式，确认 evaluator 是否真强制该形式。
8. `rhema check`，再用多组 seed/budget 实际 `run`。
9. 导出 PGML 与树，确认实际选择的规则、预算、题干和答案关系。
10. 用独立计算、枚举或已知构造关系核验答案，不只重用同一 evaluator 当 oracle。
11. 在真实 WeBWorK 测正确答案、明显错误、等价写法、边界和多答案部分得分。
12. 保存引擎 commit、specification/依赖、seed identity 与失败输入，便于复现。

完整示例的验证范围和结果见第 25 节。以下新增示例用于学习语法，不等于覆盖所有 builtin 的全部边界测试。

<a id="examples"></a>
## 23. 完整示例集

每个带文件名的 rhm 块均可保存为独立文件。已提取的 18 份文件也在 [学习示例目录](deliverables/rhema_language_spec_20261031/examples)，无需重新手动整理。第 23.16 节的作业 import 依赖第 23.13 节文件，保存时将它们放在同一目录；其他标准库依赖使用 `-I stdlib`。注释中的 example 标记仅供本说明的验证提取，不是 Rhema 语法。

### 23.1 递归算术：总预算、guard、precedence

完整示例：`recursive_arithmetic.rhm`。

<!-- rhema-example: recursive_arithmetic.rhm -->
```rhm
attribute cost = 4 split

synth value on E
synth latex on E

precedence 1 left + -
precedence 2 left * /
start E

E -> E "+" E when cost >= 1 weight 3 {
  cost = -1
  value = $1.value + $3.value
  latex = infix($1, "+", $3)
}

E -> E "-" E when cost >= 1 weight 2 {
  cost = -1
  require $1.value != $3.value
  value = $1.value - $3.value
  latex = infix($1, "-", $3)
}

E -> E "*" E when cost >= 2 weight 2 {
  cost = -2
  value = $1.value * $3.value
  latex = infix($1, "\\cdot", $3)
}

E -> E "/" E when cost >= 3 weight 1 {
  cost = -3
  require $3.value != 0
  value = $1.value / $3.value
  latex = infix($1, "/", $3)
}

E -> integer_between(1, 9) when cost = 0 {
  value = $1.value
  latex = str($1.value)
}

prompt "Evaluate [`{E.latex}`]."
answer E.value
width 16
```

这里所有递归都消费 cost，叶子只接受 0，因此整棵树恰好花光该预算。题目不必总是整数答案，因为除法保留有理数。

### 23.2 数列：题级随机、多问、模板括号

完整示例：`sequence_two_parts.rhm`。

<!-- rhema-example: sequence_two_parts.rhm -->
```rhm
random first = integer_between(-5, 8)
random difference = nonzero_integer_between(-4, 5)
random n = integer_between(3, 8)

let nth = first + (n - 1) * difference
let total = n * (2 * first + (n - 1) * difference) / 2

synth kind on Q
start Q
Q -> "arithmetic_sequence" {
  kind = "arithmetic_sequence"
}

prompt "An arithmetic sequence has [`a_1 = {first}`] and [`d = {difference}`].

(a) Find [`a_{{{n}}}`]: {answer nth}

(b) Find [`S_{{{n}}}`]: {answer total}"
width 12
```

两个空共享同一题级随机值，不是独立生成两条数列。该题结构固定，无需为了“显得灵活”强加递归。

### 23.3 Boolean evaluation：Truth 与 Boolean formula 协作

完整示例：`boolean_evaluation.rhm`。

<!-- rhema-example: boolean_evaluation.rhm -->
```rhm
random p_value = boolean
random q_value = boolean

let p = bool_var("p")
let q = bool_var("q")
let proposition = bool_and(bool_or(p, q), bool_not(q))
let mask = cond(p_value, 1, 0) + cond(q_value, 2, 0)
let p_text = cond(p_value, "T", "F")
let q_text = cond(q_value, "T", "F")
let expression_text = bool_latex(proposition)

synth value on Q
start Q
Q -> "evaluation" {
  value = bool_evaluate(proposition, "p,q", mask)
}

prompt "Evaluate [`{expression_text}`] when [`p = {p_text}`] and [`q = {q_text}`]. Enter 1 for true and 0 for false."
answer Q.value
```

答案是 Truth，所以 Numeric context 下输出 1/0；不是要求学生输入命题表达式。

### 23.4 Boolean equivalence：随机选择正确/错误关系

完整示例：`boolean_equivalence.rhm`。

<!-- rhema-example: boolean_equivalence.rhm -->
```rhm
random use_equivalent = boolean

let a = bool_var("A")
let b = bool_var("B")
let lhs_expr = bool_or(a, bool_and(a, b))
let rhs_expr = cond(use_equivalent, a, bool_not(a))
let lhs_text = bool_latex(lhs_expr)
let rhs_text = bool_latex(rhs_expr)

synth value on Q
start Q
Q -> "equivalence" {
  value = bool_equivalent(lhs_expr, rhs_expr)
}

prompt "Are [`{lhs_text}`] and [`{rhs_text}`] equivalent? Enter 1 for yes and 0 for no."
answer Q.value
```

若要学生提交一个等价命题，答案类型应为 Boolean，使用 `context "Boolean"`；这与本例的真假选择不是同一种 evaluator。

完整示例：`boolean_transformation.rhm`。本例的答案就是一个 Boolean formula。

<!-- rhema-example: boolean_transformation.rhm -->
```rhm
context "Boolean"
let p = bool_var("p")
let q = bool_var("q")
let original = bool_imp(p, q)
let original_text = bool_latex(original)

synth value on Q
start Q
Q -> "remove_implication" {
  value = bool_without_conditionals(original)
  require bool_equivalent(value, original)
}

prompt "Give a formula equivalent to [`{original_text}`] using only NOT, AND and OR."
answer Q.value
width 24
```

当前 Boolean context 判逻辑等价，不单独强制学生避开 imp/iff 等符号。上面的题干约束表达了教学目标，但严格形式验证仍需额外 comparator，不能把它说成已经自动验证。

### 23.5 Complex：计算分量，typed answer 输出

完整示例：`complex_product.rhm`。

<!-- rhema-example: complex_product.rhm -->
```rhm
context "Complex"
random ar = integer_between(-4, 4)
random ai = nonzero_integer_between(-4, 4)
random br = integer_between(-4, 4)
random bi = nonzero_integer_between(-4, 4)

let a_text = complex_latex(ar, ai)
let b_text = complex_latex(br, bi)

synth value on Q
start Q
Q -> "multiply" {
  value = complex(ar * br - ai * bi, ar * bi + ai * br)
}

prompt "Compute [`({a_text})({b_text})`]."
answer Q.value
width 20
```

递归复数表达式可将 ar/ai 改成孩子综合的 re/im；相同分量公式仍然复用。

### 23.6 Formula：构造函数并求导

完整示例：`formula_derivative.rhm`。

<!-- rhema-example: formula_derivative.rhm -->
```rhm
random coefficient = nonzero_integer_between(-5, 5)
random exponent = integer_between(2, 5)

let x = formula_variable("x")
let function_expr = formula_add(
  formula_multiply(formula_constant(coefficient), formula_power(x, exponent)),
  formula_sin(x)
)

synth text on Q
synth value on Q
start Q
Q -> "derivative" {
  text = formula_latex(function_expr)
  value = differentiate(function_expr, "x")
}

prompt "Differentiate [`f(x) = {Q.text}`] with respect to x."
answer Q.value
width 24
```

### 23.7 反向构造积分，而不是调用不存在的 integrate

完整示例：`reverse_integral.rhm`。

<!-- rhema-example: reverse_integral.rhm -->
```rhm
random coefficient = nonzero_integer_between(-5, 5)
random exponent = integer_between(2, 5)

let x = formula_variable("x")
let antiderivative = formula_add(
  formula_multiply(formula_constant(coefficient), formula_power(x, exponent)),
  formula_sin(x)
)
let integrand = differentiate(antiderivative, "x")

synth text on Q
synth value on Q
start Q
Q -> "integral" {
  require not formula_is_zero(integrand)
  text = formula_latex(integrand)
  value = antiderivative
}

prompt "Find an antiderivative of [`{Q.text}`] with respect to x, with C = 0."
answer Q.value
width 24
```

本例选择的原函数没有独立加法常数，且在 x=0 取 0。对于更一般的原函数家族，不能把“C=0”和任意函数的“F(0)=0”混为一谈；若要求初值，应单独设计归一化及其计算能力。

### 23.8 Polynomial library：同一对象的展开与取值

完整示例：`polynomial_composition.rhm`。

<!-- rhema-example: polynomial_composition.rhm -->
```rhm
include "polynomial_core.rhm"
attribute cost = 3 split
random point = integer_between(-3, 3)

synth text on Q
synth expanded on Q
synth at_point on Q
start Q

Q -> E {
  require $1.factors >= 2
  text = $1.latex
  expanded = $1.poly
  at_point = polynomial_evaluate($1.poly, point)
}

prompt "Let [`P(x) = {Q.text}`].

(a) Give an expanded equivalent expression: {answer Q.expanded}

(b) Evaluate [`P({point})`]: {answer Q.at_point}"
width 24
```

该 Numeric evaluator 判代数等价，不严格要求第一空以展开形式书写。要求严格形式时另选 evaluator，不应只靠题干措辞宣称已强制。

### 23.9 Equation：先选唯一解，再构造题目

完整示例：`linear_equation.rhm`。

<!-- rhema-example: linear_equation.rhm -->
```rhm
random root = integer_between(-5, 5)
random a = nonzero_integer_between(-4, 4)
random b = integer_between(-4, 4)
random gap = nonzero_integer_between(-3, 3)

let c = a + gap
let d = (a - c) * root + a * b
let x = formula_variable("x")
let lhs_expr = formula_multiply(
  formula_constant(a), formula_add(x, formula_constant(b))
)
let rhs_expr = formula_add(
  formula_multiply(formula_constant(c), x), formula_constant(d)
)
let problem = equation(lhs_expr, rhs_expr)

synth text on Q
synth value on Q
start Q
Q -> "linear" {
  require equation_has_exact_solutions(problem, "x")
  require equation_solution_count(problem, "x") = 1
  value = equation_unique_solution(problem, "x")
  require value = root
  text = equation_latex(problem)
}

prompt "Solve [`{Q.text}`] for x."
answer Q.value
```

a 与 c 不同，所以只有一个解；d 使选定 root 满足题目。不要直接 `answer Q.equation`。

### 23.10 Set：有限集与区间组合

完整示例：`set_union.rhm`。

<!-- rhema-example: set_union.rhm -->
```rhm
context "Interval"
random element = integer_between(-3, 3)

let a = set_insert(set_insert(set_empty(), element), 5)
let b = set_interval(-2, 4, (1 = 1), (1 = 0))
let a_text = set_latex(a)
let b_text = set_latex(b)

synth value on Q
start Q
Q -> "union" {
  value = set_union(a, b)
}

prompt "Given [`A = {a_text}`] and [`B = {b_text}`], find [`A \cup B`]."
answer Q.value
width 24
```

closed 参数使用 Truth。这里 B 是 `[-2,4)`；A 的显示文本中的集合括号由 `set_latex` 产生，不需要模板二次转义。

### 23.11 Vector：一题两个 typed answers

完整示例：`vector_products.rhm`。

<!-- rhema-example: vector_products.rhm -->
```rhm
context "Vector"
random k = integer_between(-3, 3)
let u = vector3(1, k, 2)
let v = vector3(3, 1, -1)
let u_text = vector_latex(u)
let v_text = vector_latex(v)

synth dot_value on Q
synth cross_value on Q
start Q
Q -> "products" {
  dot_value = vector_dot(u, v)
  cross_value = vector_cross(u, v)
}

prompt "Given [`u = {u_text}`] and [`v = {v_text}`]:

(a) Find [`u \cdot v`]: {answer Q.dot_value}

(b) Find [`u \times v`]: {answer Q.cross_value}"
width 24
```

两个空分别为 Num 与 Vector，均在兼容的 Vector context 中判分。

### 23.12 Matrix：先检查，再取逆

完整示例：`matrix_inverse.rhm`。

<!-- rhema-example: matrix_inverse.rhm -->
```rhm
context "Matrix"
random k = nonzero_integer_between(-4, 4)
let a = matrix2(1, k, 0, 1)
let a_text = matrix_latex(a)

synth value on Q
start Q
Q -> "inverse" {
  require matrix_is_invertible(a)
  value = matrix_inverse(a)
}

prompt "Find the inverse of [`A = {a_text}`]."
answer Q.value
width 30
```

本例从单位三角矩阵构造，天然可逆。对随机一般矩阵，require 应在 inverse 调用之前。

### 23.13 命名题型：共享声明，不共享一次生成实例

完整示例：`named_questions.rhm`。

<!-- rhema-example: named_questions.rhm -->
```rhm
random a = integer_between(2, 9)
random b = integer_between(2, 9)
synth sum on Q
synth product on Q
start Q

Q -> "pair" {
  sum = a + b
  product = a * b
}

prompt "Find the sum of {a} and {b}."
answer Q.sum

question multiplication {
  start Q
  prompt "Find the product of {a} and {b}."
  answer Q.product
  width 12
}
```

`--question multiplication` 只选择乘法题型。若想同一组 a/b 同时问加法和乘法，应将两个答案空放入同一个 prompt。

### 23.14 import：在既有函数文法上问二阶导数

完整示例：`import_second_derivative.rhm`。

<!-- rhema-example: import_second_derivative.rhm -->
```rhm
import "calculus.rhm" as calc
attribute cost = 4 copy
synth text on Q
synth value on Q
start Q

Q -> calc.F(cost = cost) {
  value = differentiate(differentiate($1.formula, "x"), "x")
  require not formula_is_zero(value)
  text = $1.latex
}

prompt "Find the second derivative of [`f(x) = {Q.text}`]."
answer Q.value
width 24
```

与原函数文法共享 typed Formula，不需要从 LaTeX 文本反向解析。该题可能因二阶导数为零而重试。

### 23.15 动态 context / width

完整示例：`dynamic_context.rhm`。

<!-- rhema-example: dynamic_context.rhm -->
```rhm
random complex_mode = boolean
synth value on Q
synth text on Q
synth pg_context on Q
synth pg_width on Q
start Q

Q -> "numeric" when not complex_mode {
  value = 5
  text = "Compute [`2+3`]."
  pg_context = "Numeric"
  pg_width = 10
}

Q -> "complex" when complex_mode {
  value = complex(3, 2)
  text = "Compute [`(1+i)+(2+i)`]."
  pg_context = "Complex"
  pg_width = 20
}

prompt "{Q.text}"
answer Q.value
```

同批题可有不同 context，PGML emitter 按需要分块，不是在所有答案创建完成后只切一次全局 context。

### 23.16 set：引用其他题型并控制分布

完整示例：`assignment.rhm`。本地依赖为本说明的 `named_questions.rhm`，其余从标准库查找。

<!-- rhema-example: assignment.rhm -->
```rhm
import "named_questions.rhm" as pairs
import "calculus.rhm" as calc
import "boolean.rhm" as logic

set practice {
  part "Warm-up"
    1 of pairs.main
    1 of pairs.multiplication
  part "Differentiation"
    2 of calc.derivative(cost in {4, 6})
  part "Logic"
    2 of logic.main(cost ~ 9 spread 1 low 8 allowed {8, 10})
  distinct
  balanced
  ordered
}
```

执行：`rhema assignment.rhm -I /path/to/project/generator/stdlib --run practice --student DEMO -o /tmp/practice.pg`。不要省略 --run。

### 23.17 标准题库完整入口索引

以下 30 个可运行文件位于 `generator/stdlib/`。默认预算仅是文件默认值；调整后必须符合该文法自己的规则。除表中注明外，命名题型为 main。

| 文件 | 内容 | 默认 cost / 主要 context |
| --- | --- | --- |
| `arithmetic.rhm` | 递归四则与精确分数 | 12 / Numeric |
| `boolean.rhm` | 命题表达式求值 | 10 / Numeric |
| `boolean_equiv.rhm` | 定律/变体的等价判断 | 6 / Numeric |
| `calculus.rhm` | main、derivative、integral | 7 / Numeric |
| `complex.rhm` | 复数表达式、共轭、模、i 的幂 | 4 / Complex |
| `sequence.rhm` | 等差/等比第 n 项和有限和 | 2 / Numeric |
| `sequence_parts.rhm` | 同数列第 n 项与和，两个空 | 2 / Numeric |
| `set.rhm` | 集合表达式 | 7 / Interval |
| `vector.rhm` | 点积、叉积、模、单位/方向向量 | 2 / Vector |
| `vector_expr.rhm` | 递归向量表达式及组合问题 | 4 / Vector |
| `linear_equation.rhm` | 反向构造的一次方程表达式 | 5 / Numeric |
| `library_linear.rhm` | 固定形式一次方程 | 3 / Numeric |
| `library_quadratic.rhm` | 二次方程有限有理根/无实根 | 3 / Interval |
| `library_polynomial.rhm` | 多项式求值、次数、展开、系数、求导 | 3 / Numeric |
| `library_formula.rhm` | 公式复合、ln/sqrt/tan、商等 | 3 / Numeric |
| `polynomial_expand.rhm` | 从因式树生成展开题 | 5 / Numeric |
| `factoring.rhm` | 从因式构造展开式，要求因式答案 | 5 / PolynomialFactors |
| `polynomial_forms.rhm` | 展开或因式分解 | 5 / 动态 Numeric、PolynomialFactors |
| `derivative_or_boolean.rhm` | import 组合导数与逻辑 | 8 / Numeric |
| `logic_forms.rhm` | 分类、model count、消去条件连接词 | 6 / 动态 Numeric、Boolean |
| `matrix_expr.rhm` | 矩阵表达式 | 4 / Matrix |
| `determinant.rhm` | 行列式与矩阵运算组合 | 3 / Numeric |
| `matrix_inverse.rhm` | 可逆矩阵求逆 | 2 / Matrix |
| `linear_system.rhm` | 三元方程组，三个空 | 5 / Numeric |
| `counting.rhm` | main、counting、probability | 2 / Numeric |
| `number_theory.rhm` | gcd/lcm、模幂、模逆、一次同余 | 2 / Numeric |
| `series.rhm` | 有限求和及受控无穷级数 | 2 / Numeric |
| `limits.rhm` | 已知极限结构的伸缩/构造 | 2 / Numeric |
| `eigen.rhm` | 特征值、特征多项式、特征向量 | 2 / 动态 Interval、Numeric、Vector |
| `inequality.rhm` | 一次、二次、绝对值、分式不等式 | 2 / Interval |

另有 `polynomial_core.rhm`、`matrix_core.rhm` 两个共享库，以及声明 homework/quick 作业的 `homework_set.rhm`。它们不是额外三个普通可运行题型文件。

同一文件里的 mode 属性是文法自己的设计，不是全语言统一的 question_mode。想知道可用模式和预算，先 `rhema list FILE`、查看其注释和 guards，或使用 Configure 读取暴露参数；不要猜所有文件都支持相同的 0/1/2 含义。

<a id="ebnf"></a>
## 24. 语法摘要 EBNF

下述 `[...]` 表示可选，`{...}` 表示零到多次；引号内才是字面字符。表达式优先级以第 8 节为准，类型/作用域/终止等还需 checker 与 runtime 检查。

```ebnf
file        = { declaration } ;
declaration = "attribute" IDENT "=" sint [ "copy" | "split" ]
            | "random" IDENT "=" ("boolean" | IDENT "(" [exprs] ")")
            | "let" IDENT "=" expr
            | "synth" IDENT ["on" IDENT]
            | "start" IDENT
            | "context" STRING
            | "precedence" INT ("left" | "right" | "nonassoc") operator {operator}
            | "prompt" STRING | "answer" expr | "width" INT
            | "include" STRING | "import" STRING "as" IDENT
            | "question" IDENT "{" {qitem} "}"
            | "set" IDENT "{" {sitem} "}"
            | production ;

production  = IDENT "->" symbol {symbol} ["when" expr] ["weight" INT]
              "{" {equation [","]} "}" ;
symbol      = IDENT | IDENT "(" [exprs] ")" | STRING
            | "+" | "-" | "*" | "/" | "%" | "^"
            | IDENT "." IDENT ["(" [named_args] ")"] ;
named_args  = IDENT "=" expr {"," IDENT "=" expr} ;
equation    = IDENT "=" expr | "require" expr ;

qitem       = "start" IDENT | "prompt" STRING | "answer" expr
            | "context" STRING | "width" INT | IDENT "=" sint ;
sitem       = "part" [STRING] | "distinct" | "balanced" | "ordered"
            | INT "of" choice ;
choice      = sq | "any" "(" sq {"," sq} ")" ;
sq          = [IDENT "."] IDENT ["(" [draw {"," draw}] ")"] ;
draw        = IDENT "=" sint
            | IDENT "in" "{" sint {"," sint} "}"
            | IDENT "~" sint {around_opt} ;
around_opt  = "spread" sint | "low" sint
            | "allowed" "{" sint {"," sint} "}" ;

expr        = INT | STRING | IDENT | IDENT "." IDENT
            | "$" POSITIVE_INT | "$" POSITIVE_INT "." IDENT
            | IDENT "(" [exprs] ")" | "(" expr ")"
            | "-" expr | "not" expr | expr binop expr ;
exprs       = expr {"," expr} ;
binop       = "or" | "and" | "=" | "!=" | "<" | "<=" | ">" | ">="
            | "++" | "+" | "-" | "*" | "/" | "%" | "^" ;
operator    = "+" | "-" | "*" | "/" | "%" | "^" | STRING ;
sint        = ["-"] INT ;
```

词法上的 `$` 和正整数必须连在一起，如 `$1`，不是 `$ 1`；上面分写只是展示其结构。signed integer 的可解析性不代表所有位置允许负值，如 inherited 初值仍不得为负。

<a id="sources"></a>
## 25. 实现依据与维护方式

### 25.1 本规范对应代码

| 依据 | 核对内容 |
| --- | --- |
| [rhema_lexer.mll](generator/rhema/lib/rhema_lexer.mll) | 全部 28 关键字、标识符、注释、整数、字符串 |
| [rhema_parser.mly](generator/rhema/lib/rhema_parser.mly) | 声明、productions、表达式优先级、question、set、模块语法 |
| [rhema_ast.ml](generator/rhema/lib/rhema_ast.ml) | AST 结构及位置记录 |
| [rhema_check.ml](generator/rhema/lib/rhema_check.ml) | 134 builtin/generator 的名字与 arity、作用域、模板和保守终止检查 |
| [rhema_engine.ml](generator/rhema/lib/rhema_engine.ml) | 值类型、builtin 实际参数类型、分配、执行顺序与重试 |
| [rhema_load.ml](generator/rhema/lib/rhema_load.ml) | include/import 合并、缓存、搜索与循环检测 |
| [rhema_sets.ml](generator/rhema/lib/rhema_sets.ml) | 预算 draws、distinct/balanced/ordered 的实际定义 |
| [rhema_cli.ml](generator/rhema/lib/rhema_cli.ml) / [rhema_main.ml](generator/rhema/bin/rhema_main.ml) | seed、CLI 路径、参数和退出码 |
| [rhema_pgml.ml](generator/rhema/lib/rhema_pgml.ml) | 答案类型降低、宏和 context 分块 |
| [rhema_formula.ml](generator/rhema/lib/rhema_formula.ml) / [rhema_equation.ml](generator/rhema/lib/rhema_equation.ml) / 其他数学模块 | 简化、等号、solver 范围、数值与维度约束 |
| [标准库](generator/stdlib) | 30 个 runnable grammars、2 个 core 库和作业示例 |
| [teacher_builder.py](teacher_builder.py) / [app.py](app.py) / [TEACHER_MODE.md](TEACHER_MODE.md) | Configure、source 模式、导出与 WeBWorK preview 集成 |

旧 [RHEMA_LANGUAGE_GUIDE.md](RHEMA_LANGUAGE_GUIDE.md) 和 [docs/reference/language.md](docs/reference/language.md) 可补充阅读；若措辞与当前代码不同，以本规范对应版本的实际实现为准。这里的源码链接是维护依据，不是论文参考文献。

### 25.2 本次验证

本次在上述 commit 的已构建引擎上完成以下检查，详情见 [verification.json](deliverables/rhema_language_spec_20261031/verification.json)：

- 逐项比对 checker 注册表，134 个 builtin/generator 的名称与参数数量在本说明均有对应条目；lexer 的 28 个 reserved keywords 均已列出。
- 提取 18 份完整 `.rhm`；所有文件通过 check，并对各命名题型及作业分别使用 seed 1、17、20261031 验证，共 57 个生成场景。
- 普通题每场景生成 5 题，同时核对 PG 输出重放一致；作业每次生成其声明的完整 6 题。
- 11 个专门探针验证本说明强调的实现行为，包括保留字、Truth 字面量、裸 answer、random 参数、paren/str 类型、负号优先级、Formula/Set equality 和 split 不自动耗尽预算。
- 由这些示例导出的 19 份 PG 文件全部通过本机 Docker WeBWorK 渲染。**本项只验证渲染，不是对这些示例全部学生答案组合的判分测试，也不是独立数学正确性证明。**

上述核验不是重新执行仓库全部 tests；现有 test suite 仍需在变更引擎/数学库后执行。本次只增加本说明及学习示例材料，不修改引擎、标准库、业务逻辑或个人配置，不推送 GitHub。

复核脚本在 [示例材料目录](deliverables/rhema_language_spec_20261031)。从项目根目录执行：

```sh
.venv/bin/python deliverables/rhema_language_spec_20261031/verify_language_spec.py
.venv/bin/python deliverables/rhema_language_spec_20261031/check_runtime_notes.py
.venv/bin/python deliverables/rhema_language_spec_20261031/check_live_rendering.py
```

第一项重建示例与基础报告；第二项补充 11 个探针结果；第三项需要本机 renderer 在线，并补充真实渲染结果。按顺序执行。它们只写该材料目录；如果换了引擎版本而探针失败，应检查说明是否过时，而不是修改引擎来迎合旧文档。

### 25.3 后续维护

新增 keyword 时同步第 4、24 节；新增 builtin 时同步第 14 节的精确函数名、arity、类型与限制；改预算/seed/输出时同步相应行为说明，并重新运行完整示例。

不要只靠 `rhema --version` 判断本规范适用性：package version 未必随每次 main 合并更新，应同时记录 commit。
