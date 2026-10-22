# 题型总览（Question Types）

*`generator/ag/` 中的每个文法：它问什么，难度预算花在哪里，答案需要哪个 WeBWorK 上下文。英文原版见 `QUESTION_TYPES.md`，以英文版为准；预算机制本身见 `DIFFICULTY_BUDGET.md`。*

每个文法就是一个 `.ag` 文件：形状、价格、措辞和答案都在里面。引擎对所有文法都一样，新题型是一个新文件，不是改引擎。一个文件可以放多种题型（`complex.ag` 有四种，`vector_expr.ag` 四种）；每种题型是一条 `Q ->` 规则，有自己的题干、答案和价格，由权重、模式属性或预算来选择。

## 表达式类：递归树把预算花掉

| 文法 | 问什么 | 预算买什么 | 默认 | 上下文 |
| --- | --- | --- | --- | --- |
| `arithmetic.ag` | 四则运算表达式的值 | `+` 1，`-` 2，`*` 3，`/` 4；数字首位以外每位 1 | 12 | Numeric |
| `boolean.ag` | p、q、r 上的命题在赋值下的真值；命题是引擎的 Boolean 值类型 | 与、或 2，条件 4，双条件和异或 6，否定变量 1，否定复合式 3 | 10 | Numeric |
| `boolean_equiv.ag` | 三十条定律之一（写对或带经典错误）是否成立，由枚举判定 | 定律 1–3，各部分按 `boolean.ag` | 6 | Numeric |
| `calculus.ag` | 导数，或由求导反向构造的原函数 | 和 1，积 3，商 4；叶子的幂或函数 1，复合式的 3（链式法则）；积分先付 2 | 7 | Numeric |
| `complex.ag` | 复数表达式、共轭、模、`i` 的幂 | 和 1，积 3；求模和 `i` 的幂固定为 2 和 1 | 4 | Complex |
| `set.ag` | 三个给定集合上的集合表达式 | 并 1，交和差 2，区间叶子 1 | 7 | Interval |
| `polynomial_expand.ag` | 因式乘积的展开式 | 乘积 2，平方 1，立方 2，因式 `x + b` 0，`ax + b` 1，二次 2 | 5 | Numeric |
| `factoring.ag` | 由因式构造的多项式的因式分解 | 与展开同价；因式互不相同且本原 | 5 | PolynomialFactors |
| `vector_expr.ag` | 向量表达式，或表达式的点积、叉积、模 | 和 1，括号的倍数 1；顶层点积 2、模 2、叉积 4 | 4 | Vector |
| `linear_equation.ag` | 由选定的根构造的一元一次方程的解 | 和 1，括号的倍数 1，分式 2 | 5 | Numeric |
| `polynomial_forms.ag` | 同一棵因式树，展开或分解，两种题型各在自己的上下文 | 同 `factoring.ag` | 5 | Numeric / PolynomialFactors |
| `sequence_parts.ag` | 一个数列，两个空：第 n 项和前 n 项和 | 等差 2，等比 3（固定） | 2 | Numeric |
| `derivative_or_boolean.ag` | 求导或布尔求值，整个包含两个文法 | 各文法自己的价格 | 8 | Numeric |

## 固定形式类：每种形式是一个价格

| 文法 | 按价格列出的形式 | 默认 | 上下文 |
| --- | --- | --- | --- |
| `vector.ag` | 1 平行向量；2 点积、模、同方向；3 单位向量；4 叉积 | 2 | Vector |
| `sequence.ag` | 1 等差第 n 项；2 等比第 n 项、等差和；3 等比和 | 2 | Numeric |
| `library_linear.ag` | 2 一个括号；3 两边括号；4 分式 | 3 | Numeric |
| `library_quadratic.ag` | 2 两整数根；3 重根、无实根；4 两有理根 | 3 | Interval |
| `library_polynomial.ag` | 1 求值；2 次数；3 展开、系数；4 求导 | 3 | Numeric |
| `library_formula.ag` | 2 复合；3 对数、根式、正切；4 商、组合 | 3 | Numeric |

## 本分支新增的五种通用题型

**因式分解**（`factoring.ag`）。先有因式：本原的一次因式 `ax + b`（最大公因数为 1，`a` 取 1 到 3）、它们的平方和立方、不可约二次式 `x^2 + c`。多项式库把它们乘开；学生看到展开式，给出因式。每个因式互不相同（每个因式一个比特位，乘积两侧的位集不相交），所以因式分解是完全的。答案是 WeBWorK `PolynomialFactors` 上下文中的因式乘积，该上下文拒绝直接填展开式；`.pg` 文件为此加载 `contextPolynomialFactors.pl`。最小预算为 1。

```
cost 2   x^2 + x - 12             (x-3)(x+4)
cost 5   x^5 - 3x^4 + 14x^3 - 42x^2 + 49x - 147   (x-3)(x^2+7)^2
```

**展开**（`polynomial_expand.ag`）。同样的因式反过来读，另加二次因式 `ax^2 + bx + c`；答案是展开后的多项式。一次因式在乘积中只出现一次，出现两次就是幂。

**微积分扩展**（`calculus.ag`）。求导题现在可以用 `ln`、`sqrt`、`tan` 和商，各自作用在叶子上 1、复合式上 3 加内层，商 4 加两边。`ln` 和 `sqrt` 只作用在系数为正的叶子上。积分题仍限于和、积、幂、`sin`、`cos`、`exp`，它们的逆运算在课程方法范围内；`advanced` 属性为积分题关闭其余构造。幂不嵌套，`e^{...}` 在幂下面在 LaTeX 中加括号。

**向量表达式**（`vector_expr.ag`）。`u`、`v`、`w` 的和、差与倍数，直接求（顶层 0）、求模（2）、点积（2）或叉积（4）。同一个和里每个向量只出现一次，所以不会抵消；括号的倍数开始一个新的和，倍数不套倍数，作为点积或叉积操作数的和会加括号。

```
cost 4   ||w - u - v||
cost 7   5(u + 3(w - u)) . (w + v)
```

**一元一次方程**（`linear_equation.ag`）。先选根。左边是关于 `x` 的和、括号倍数和分式构成的树，它是线性的，所以斜率和截距随树一起算出；右边是 `cx + k`，`c` 与斜率不同，`k` 使两边在根处相等。一条加法链最多一个数和两个 `x` 项，和永远不会折叠成零，分式不套分式。

```
cost 2   4(x + 3x) = 17x - 2                              x = 2
cost 8   (5(8 + x) - 5*5(3 + 2x)) / 2 = -(39/2 + 43/2 x)  x = 2
```

## 用户能在一个文件里写什么

共享题目级随机值的多种题型，每个有多条 `Q ->` 规则的文法都是例子；需要不同 WeBWorK 上下文的题型（`pg_context`）；有多个答案空的题目（题干里的 `{answer ...}`）；以及与其他文件共享的产生式（`include`）。`polynomial_core.ag` 是一个只有产生式、没有自己问题的库，`factoring.ag`、`polynomial_expand.ag` 和 `polynomial_forms.ag` 都包含它。见 `AG_LANGUAGE_EXTENSIONS.md`。
