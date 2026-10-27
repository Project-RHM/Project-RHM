# 题型总览（Question Types）

*`generator/stdlib/` 中的每个文法：它问什么，难度预算花在哪里，答案需要哪个 WeBWorK 上下文。英文原版见 `QUESTION_TYPES.md`，以英文版为准；预算机制本身见 `DIFFICULTY_BUDGET.md`。*

每个文法就是一个 `.rhm` 文件：形状、价格、措辞和答案都在里面。引擎对所有文法都一样，新题型是一个新文件，不是改引擎。一个文件可以放多种题型（`complex.rhm` 有四种，`vector_expr.rhm` 四种）；每种题型是一条 `Q ->` 规则，有自己的题干、答案和价格，由权重、模式属性或预算来选择。

## 表达式类：递归树把预算花掉

| 文法 | 问什么 | 预算买什么 | 默认 | 上下文 |
| --- | --- | --- | --- | --- |
| `arithmetic.rhm` | 四则运算表达式的值 | `+` 1，`-` 2，`*` 3，`/` 4；数字首位以外每位 1，最简分数 2 | 12 | Numeric |
| `boolean.rhm` | p、q、r 上的命题在赋值下的真值；命题是引擎的 Boolean 值类型 | 与、或 2，条件 4，双条件和异或 6，否定变量 1，否定复合式 3 | 10 | Numeric |
| `boolean_equiv.rhm` | 三十条定律之一（写对或带经典错误）是否成立，由枚举判定 | 定律 1–3，各部分按 `boolean.rhm` | 6 | Numeric |
| `calculus.rhm` | 导数，或由求导反向构造的原函数；有名字的题型 `derivative`、`integral` 各只问一种 | 和 1，积 3，商 4；叶子的幂或函数 1，复合式的 3（链式法则）；积分先付 2 | 7 | Numeric |
| `complex.rhm` | 复数表达式、共轭、勾股三元组数的乘积 / 共轭 / 整数倍的模、`i^n` 乘一个表达式 | 和 1，积 3；求模 2 加其表达式（乘积 2、共轭 1、倍数 1）；`i` 的幂 1 加其表达式 | 4 | Complex |
| `set.rhm` | 三个给定集合上的集合表达式 | 并 1，交和差 2，区间叶子 1 | 7 | Interval |
| `polynomial_expand.rhm` | 因式乘积的展开式 | 乘积 2，平方 1，立方 2，因式 `x + b` 0，`ax + b` 1，二次 2 | 5 | Numeric |
| `factoring.rhm` | 由因式构造的多项式的因式分解 | 与展开同价；因式互不相同且本原 | 5 | PolynomialFactors |
| `vector_expr.rhm` | 向量表达式，或表达式的点积、叉积、模 | 和 1，括号的倍数 1；顶层点积 2、模 2、叉积 4 | 4 | Vector |
| `linear_equation.rhm` | 由选定的根构造的一元一次方程的解 | 和 1，括号的倍数 1，分式 2 | 5 | Numeric |
| `polynomial_forms.rhm` | 同一棵因式树，展开或分解，两种题型各在自己的上下文 | 同 `factoring.rhm` | 5 | Numeric / PolynomialFactors |
| `sequence_parts.rhm` | 一个数列，两个空：第 n 项和前 n 项和 | 等差 2，等比 3（固定） | 2 | Numeric |
| `derivative_or_boolean.rhm` | 求导或布尔求值，把两个文法作为模块引入 | 各文法自己的价格 | 8 | Numeric |
| `logic_forms.rhm` | 命题分类（重言式 / 矛盾式 / 两者皆非）、模型计数、消去条件联结词；建立在 `boolean.rhm` 和 `boolean_equiv.rhm` 之上 | 定律或表达式自己的价格 | 6 | Numeric / Boolean |
| `matrix_expr.rhm` | 计算 `matrix_core.rhm` 中矩阵 A、B、C 的表达式 | 和 1，倍数 1，转置 1，乘积 3；3 阶矩阵 2 | 4 | Matrix |
| `determinant.rhm` | 矩阵或其乘积、转置、倍数的行列式 | 2 阶 1，3 阶 3；乘积 2，转置 1，倍数 1 | 3 | Numeric |

## 固定形式类：每种形式是一个价格

| 文法 | 按价格列出的形式 | 默认 | 上下文 |
| --- | --- | --- | --- |
| `vector.rhm` | 1 平行向量；2 点积、模、同方向；3 单位向量；4 叉积 | 2 | Vector |
| `sequence.rhm` | 1 等差第 n 项；2 等比第 n 项、等差和；3 等比和 | 2 | Numeric |
| `library_linear.rhm` | 2 一个括号；3 两边括号；4 分式 | 3 | Numeric |
| `library_quadratic.rhm` | 2 两整数根；3 重根、无实根；4 两有理根 | 3 | Interval |
| `library_polynomial.rhm` | 1 求值；2 次数；3 展开、系数；4 求导 | 3 | Numeric |
| `library_formula.rhm` | 2 复合；3 对数、根式、正切；4 商、组合 | 3 | Numeric |
| `matrix_inverse.rhm` | 2 逆为整数矩阵的 2 阶；3 同样但乘了倍数（出分数）；5 3 阶；6 乘了倍数 | 2 | Matrix |
| `linear_system.rhm` | 3 三元三角形方程组；5 完整方程组；三个答案空 | 5 | Numeric |
| `counting.rhm` | 1 排成一行、有序选取、选委员会；2 单词的排列、至少一个某类、两人不相邻、骰子点数和的概率；3 全部抽到同一颜色、至少一个六点、恰好 k 次正面；有名字的题型 `counting` 和 `probability` 各只问一类 | 2 | Numeric |
| `number_theory.rhm` | 1 最大公约数、最小公倍数；2 幂的余数、模 n 的逆；3 一次同余方程 | 2 | Numeric |
| `series.rhm` | 1 写开的无穷等比级数、平方和；2 求和号表示的等比级数、二次式求和、裂项求和；3 带间隔的裂项求和（有限或无穷）、两个等比级数之和 | 2 | Numeric |
| `limits.rhm` | 1 可去间断点、无穷远处二次式之比；2 分子分母共有一个因式、`sin(kx)/(mx)`、`(e^{kx} - 1)/(mx)`；3 两个正弦之比、`(1 - cos(kx))/(mx^2)` | 2 | Numeric |
| `eigen.rhm` | 1 三角矩阵的特征值；2 2 阶矩阵的特征值、特征多项式；3 特征向量、3 阶矩阵的特征值 | 2 | Interval / Numeric / Vector |
| `inequality.rhm` | 1 一次；2 二次、`x - a` 的绝对值；3 `px - q` 的绝对值、分式 | 2 | Interval |

## 本分支新增的五种通用题型

**因式分解**（`factoring.rhm`）。先有因式：本原的一次因式 `ax + b`（最大公因数为 1，`a` 取 1 到 3）、它们的平方和立方、不可约二次式 `x^2 + c`。多项式库把它们乘开；学生看到展开式，给出因式。每个因式互不相同（每个因式一个比特位，乘积两侧的位集不相交），所以因式分解是完全的。答案是 WeBWorK `PolynomialFactors` 上下文中的因式乘积，该上下文拒绝直接填展开式；`.pg` 文件为此加载 `contextPolynomialFactors.pl`。最小预算为 1。

```
cost 2   x^2 + x - 12             (x-3)(x+4)
cost 5   x^5 - 3x^4 + 14x^3 - 42x^2 + 49x - 147   (x-3)(x^2+7)^2
```

**展开**（`polynomial_expand.rhm`）。同样的因式反过来读，另加二次因式 `ax^2 + bx + c`；答案是展开后的多项式。一次因式在乘积中只出现一次，出现两次就是幂。

**微积分扩展**（`calculus.rhm`）。求导题现在可以用 `ln`、`sqrt`、`tan` 和商，各自作用在叶子上 1、复合式上 3 加内层，商 4 加两边。`ln` 和 `sqrt` 只作用在系数为正的叶子上。积分题仍限于和、积、幂、`sin`、`cos`、`exp`，它们的逆运算在课程方法范围内；`advanced` 属性为积分题关闭其余构造。幂不嵌套，`e^{...}` 在幂下面在 LaTeX 中加括号。

**向量表达式**（`vector_expr.rhm`）。`u`、`v`、`w` 的和、差与倍数，直接求（顶层 0）、求模（2）、点积（2）或叉积（4）。同一个和里每个向量只出现一次，所以不会抵消；括号的倍数开始一个新的和，倍数不套倍数，作为点积或叉积操作数的和会加括号。

```
cost 4   ||w - u - v||
cost 7   5(u + 3(w - u)) . (w + v)
```

**一元一次方程**（`linear_equation.rhm`）。先选根。左边是关于 `x` 的和、括号倍数和分式构成的树，它是线性的，所以斜率和截距随树一起算出；右边是 `cx + k`，`c` 与斜率不同，`k` 使两边在根处相等。一条加法链最多一个数和两个 `x` 项，和永远不会折叠成零，分式不套分式。

```
cost 2   4(x + 3x) = 17x - 2                              x = 2
cost 8   (5(8 + x) - 5*5(3 + 2x)) / 2 = -(39/2 + 43/2 x)  x = 2
```

## 第二批：逻辑、线性代数，以及两个文法的可伸缩化

**整份作业**（`homework_set.rhm`）自己不出题：它引入四个文法并声明两个 `set`，用 `rhema homework_set.rhm --run homework` 生成；见 `RHEMA_LANGUAGE_EXTENSIONS.zh.md` 第 6 节。

**逻辑**（`logic_forms.rhm`）把两个布尔文法作为模块引入，对它们的定律和表达式再问三种问题：分类（像求值题用 1、0 一样，用 1、2、0 编码）、模型计数，以及消去条件联结词——答案是一个命题，在 WeBWorK 的 Boolean 上下文中判分（为此加载 `contextBoolean.pl`；WeBWorK 接受任何等价命题，所以形式本身不被强制）。

**线性代数**建立在新的值类型 `Matrix` 上（`rhema_matrix.ml`：精确有理数元素、和、倍数、转置、乘积、余子式行列式、伴随矩阵求逆、作用于向量、LaTeX 和 PG 渲染，以及把一行写成方程的 `matrix_row_latex`）。`matrix_core.rhm` 每题抽一次 A、B、C，各有 2 阶和 3 阶版本，继承属性 `dim` 决定题目用哪个。求逆和方程组由单位三角矩阵的乘积构造，所以逆矩阵元素是整数、选定的解是唯一解；方程组在题干里放三个答案空。

**复数**的求模和幂变得可伸缩，**算术**加了最简分数叶子。

## 第三批：计数、数论、级数、极限、特征值、不等式

六个都是固定形式的文法，默认预算 2，而且都是**先定答案**：先抽出答案，再由答案构造题目，所以从不需要求解，每道题的答案都确实是它声称的那个。

- **计数与概率**（`counting.rhm`）用新的整数内建函数 `factorial`、`permutations`、`choose` 计算答案；概率是精确分数。有名字的题型 `counting` 和 `probability` 各只问一类。
- **数论**（`number_theory.rhm`）用 `g m` 和 `g n`（`m`、`n` 互素）构造最大公约数题，由解构造同余方程，用 `pow_mod` 和 `mod_inverse` 计算幂的余数和逆元。
- **级数**（`series.rhm`）把等比级数的公比抽成分数 `p/q`，且 `|p| < q`，所以级数收敛；裂项求和是 `1/((k+c)(k+c+g))` 之和，剩下的项就是答案。
- **极限**（`limits.rhm`）把分子分母同乘一个 `x - a` 并都展开显示，得到可去间断点；对 `sin x / x`、`(e^x - 1)/x`、`(1 - cos x)/x^2` 这几个标准极限做伸缩。
- **特征值**（`eigen.rhm`）构造 `A = P D P^{-1}`，`P` 的行列式为 1，所以 `A` 的元素是整数，特征值就是 `D` 的，`P` 的各列是特征向量。特征值按集合判分（与顺序无关），特征向量接受任何与正确向量平行的向量。
- **不等式**（`inequality.rhm`）先选定根，再由比较符号和首项系数的符号决定答案是根之间还是根之外、哪些端点闭合。答案用到两种新的集合值：射线 `set_above(a, closed)` 和 `set_below(a, closed)`。

```
cost 2   eigenvalues of [[-20, 21], [-14, 15]]   {-6, 1}
cost 3   |3x - 5| > 1                              (-infinity, 4/3) U (2, infinity)
cost 3   x / (x - 6) <= 0                          [0, 6)
```

引擎新增了上面这些内建函数，以及 `gcd`、`lcm` 和 `number_latex`（把数写成 LaTeX，分数写成 `\frac`）；首项为负的多项式现在打印成 `-5x^2 + 4x + 9`，而不是一个差式。每个文法都有一个独立检验答案的测试：穷举、搜索、数值求和或求值、检验 `det(A - tI) = 0` 和 `Av = tv`，或在区间每个端点两侧取点检验。

## 用户能在一个文件里写什么

共享题目级随机值的多种题型，每个有多条 `Q ->` 规则的文法都是例子；需要不同 WeBWorK 上下文的题型（`pg_context`）；有多个答案空的题目（题干里的 `{answer ...}`）；以及与其他文件共享的产生式（`include`）或整个引入的文法（`import`）。`polynomial_core.rhm` 是一个只有产生式、没有自己问题的库，`factoring.rhm`、`polynomial_expand.rhm` 和 `polynomial_forms.rhm` 都包含它。见 `RHEMA_LANGUAGE_EXTENSIONS.md`。
