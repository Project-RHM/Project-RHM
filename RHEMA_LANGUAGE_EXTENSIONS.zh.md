# 语言扩展：include、import、有名字的题型、套题、每题一个上下文、多个答案空

*Rhema 语言的六项新增，让一个文件可以容纳作者想要的任何题型；另有几处小的补充（第 7 节）、文本中的答案空（第 8 节）、错误规则（第 9 节）和静态类型（第 10 节）。英文原版见 `RHEMA_LANGUAGE_EXTENSIONS.md`，以英文版为准；语言本身见 `RHEMA_LANGUAGE_GUIDE.md`。*

## 1. `include "file.rhm"`：文件之间的复用

```
include "polynomial_core.rhm"

context "PolynomialFactors"
synth text on Q
synth answer_value on Q
start Q
Q -> E { ... }
prompt "{Q.text}"
answer Q.answer_value
```

加载器读入被包含的文件（路径相对于包含方，可递归），把它的声明放在包含方自己的声明之前。规则、`synth` 和 `attribute` 声明、random、let、precedence 累加；两个文件都声明的完全相同的 `synth` 或 `attribute` 只保留一份。文法只能声明一次的那些——`start`、`context`、`prompt`、`answer`、`width`——以包含方自己的为准，所以一个文法可以包含另一个文法并用新的题干重新提问。直接或间接包含自己的文件会被拒绝；被包含文件内部的错误会带着该文件的名字报告。

没有 `start`、`prompt` 和 `answer` 的文件是**库**：`rhema check` 接受它并说明这一点，`rhema` 拒绝用它生成，网页的文法列表不显示它。`polynomial_core.rhm` 就是一个库；它存放因式树，`factoring.rhm`、`polynomial_expand.rhm` 和 `polynomial_forms.rhm` 都建立在它上面，各自加上自己的问题，展开那个文件还多加了一条因式规则。

包含方声明的 `attribute` 优先于被包含文件的，两个被包含文件声明同一个属性时以先到的为准，所以默认预算不同的两个文法可以一起包含，由包含方统一设定两者花的预算。两个文件里同名的 random 和 let 仍然报错。

非终结符按名字共享，所以两个都用 `E` 的文法不能原样包含进同一个文件，两个文件里同名的 random 也会冲突。`include` 是**扩展**一个文法的工具：往它的非终结符上加规则、重新提问。要把两个文法并排放在一起，用 **import**（第 4 节）：每个文法的名字都留在自己的别名后面。

## 2. 每道题自己的上下文和答案宽度

开始符号计算综合属性 `pg_context` 的文法，每道题有自己的 WeBWorK 上下文；`pg_width` 同样决定答案宽度。

```
synth pg_context on Q

Q -> E "expand" { pg_context = "Numeric"  ... answer_value = $1.poly }
Q -> E "factor" { pg_context = "PolynomialFactors"  ... answer_value = $1.factored }
```

`.pg` 文件加载它用到的每个上下文的宏，同一上下文的题目写在同一个 PGML 块里，块与块之间切换 `Context()`。所有题目都用文件级 `context` 的文件，输出和以前完全一样。`polynomial_forms.rhm` 展示了同一棵树问两种问题，各在自己的上下文中。

## 3. 多个答案空：题干中的 `{answer ...}`

```
prompt "{Q.text}
(a) Find [`a_{{{index_text}}}`]: {answer Q.nth}
(b) Find the sum [`S_{{{index_text}}}`]: {answer Q.sum}"
```

`{answer Q.nth}` 在题干的这个位置放一个答案空，按开始符号的该属性判分；`{answer total}` 按某个 random 或 let 判分。每个空在 WeBWorK 中单独判分，这就是 (a)(b)(c) 分小问的写法。自己放置了答案空的题干不再写末尾的 `answer` 声明；没有放置的仍然保留它，答案空像以前一样跟在题干后面。`sequence_parts.rhm` 对同一个数列问第 n 项和前 n 项和。

可读的文本输出中，内联的空显示为 `[___]`，答案按顺序列出；生成的题目把它们放在 `answers` 里，`answer` 仍是第一个，供只读一个答案的工具使用。

## 4. `import "file.rhm" as name`：模块

```
import "calculus.rhm" as calc
import "boolean.rhm" as bool

attribute cost = 8 copy
synth kind on M  synth text on M  synth answer_value on M
start M

M -> calc.F(cost = cost) "derivative" {
  kind = "derivative"
  text = "Differentiate [`f(x) = " ++ $1.latex ++ "`]."
  answer_value = differentiate($1.formula, "x")
}
M -> bool.E(cost = cost + 2) "boolean" {
  kind = "boolean"
  text = "Evaluate [`" ++ bool_latex($1.f) ++ "`] when " ++ bool.given ++ "."
  answer_value = bool_evaluate($1.f, bool.names, bool.mask)
}

prompt "{M.text}"
answer M.answer_value
```

`import` 把另一个文件作为**模块**引入：该文件单独加载、单独检查，它声明的一切都通过别名访问，所以它和引入方、和其他模块之间不可能撞名。上面就是随库发布的 `derivative_or_boolean.rhm`；`logic_forms.rhm` 引入 `boolean.rhm` 和 `boolean_equiv.rhm`，这两个文件都有 `Q`、`E`、`cost` 和 `phrasing`，照样一起用。

**名字。** 模块的非终结符在规则右侧写成 `calc.F`；它的 random 和 let 在表达式里写 `bool.given`、`bool.mask`，在题干里写 `{bool.given}` 或 `{answer bool.total}`。综合属性不用别名：`$1.latex` 从子节点读，检查器知道这个子节点是 `calc.F`，就按那个模块检查名字（`$1 is calc.F, which does not carry 'value'`）。继承属性只在参数里点名。模块的优先级表和规则对外不可见。内置函数是全局的，从不加限定。模块内部自己的名字仍然不加限定，所以现有文件的含义一个都不变。

**参数。** `calc.F(cost = cost - 1, advanced = 1)` 给模块的继承属性设这棵子树上的初值；没点名的取模块声明的默认值（单写 `calc.F` 时从 `calculus.rhm` 的 `attribute cost = 7` 开始）。参数表达式在父节点求值，此时子节点还不存在：可以用字面量、父节点的继承属性、引入方的 random 和 let、模块的值、内置函数。结果必须是整数，不能为负。

参数里出现父节点的属性名，表示**这个子节点应得的份额**：`copy` 下是整个值，`split` 下是它作为本地非终结符本来会分到的那份。所以在 `attribute cost = 6 split` 下写 `M -> bool.E(cost = cost) "," laws.L(cost = cost + 1)`，两个模块合计花 7，对每棵子树调 `Rhema_engine.consumption` 报的就是该模块花掉的数。模块的预算是它自己的：`calc.F` 永远看不见引入方的 `cost`；定价标尺不同的两个文法在边界相遇，汇率由引入方写在参数里（上面的 `cost + 2`）。

**一个文件一个模块。** 同一个文件被引入两次，无论是两个别名还是两个引入方，都是同一个模块：它的 random 每道题只画一次，两个别名看到同样的值（`a.p = b.p`）。模块自己也可以 import 和 include 文件，那些对外不可见（`forms.bool.E` 不是一个名字）。库（没有 `start`）也可以像文法一样引入：`import "polynomial_core.rhm" as poly`，然后 `poly.E(cost = 5)`。直接或间接引入自己的文件会被拒绝，并报出文件链。

**括号。** 引入方的优先级表对模块的运算符一无所知，所以模块子树在引入方眼里是一个原子：`infix()` 不会在它外面加括号。把 `calc.F` 嵌进更大表达式的规则要自己写括号（`"(" ++ $1.latex ++ ")"`），或者用模块为此提供的属性。

**错误**都在引入方报出：别名不存在、模块没有这个非终结符、参数点名了模块没有的属性或设了两次、模块子节点没有这个综合属性、模块没有这个 random 或 let、两个 import 用了同一个别名、引入成环。模块自身内部的错误带着模块的文件名报出，前面先有一行指在 `import` 处说明是哪个引入带进来的。`rhema list` 会列出解析到的 import。

**include 还是 import？** 扩展用 include，组合用 import。一个文件可以两者都用：`factoring.rhm` include `polynomial_core.rhm` 以在它的因式树上加一道题；`derivative_or_boolean.rhm` import 两个完整的文法。

## 5. `question NAME { ... }`：一个文件里多个有名字的题型

```
start Q
prompt "{Q.text}"
answer Q.answer_value
width 24

question derivative {
  start D
  prompt "{D.text}"
  answer D.answer_value
}

question integral {
  start I
  prompt "{I.text}"
  answer I.answer_value
  cost = 7
}
```

一个文件可以对它的规则问不止一道题。文件级的 `start`、`prompt`、`answer`、`context`、`width` 构成名为 **`main`** 的题型；每个 `question NAME { ... }` 块再加一个，有自己的开始符号、题干和答案，可选地有自己的 `context` 和 `width`。块里没写 `context` 或 `width` 时取文件级的。一个文件的所有题型共享它的规则、属性、random 和 let：它们只在从哪里开始、怎么问上不同。

块还可以给它的根节点另设继承属性的初值：`cost = 7` 表示这道题从这个预算开始，不管 `attribute` 行写的是多少；`--set` 仍然可以从外部覆盖它。只能设文件声明过的继承属性，不能为负。

`calculus.rhm` 是随库发布的示例：`main`（start `Q`）在导数和积分之间随机，`derivative`（start `D`）和 `integral`（start `I`）各只问一种形式，三者共享形式 `D`、`I` 以及它们之下的表达式文法。全是块、没有 `main` 的文件以第一个块为默认；两者都没有的文件是库。

```
rhema run calculus.rhm                                   main
rhema run calculus.rhm --question integral --set cost=5  指定一个题型
rhema list calculus.rhm                                  列出题型
```

`rhema list` 列出每个题型及其开始符号和上下文；网页端对这样的文件多出一个题型下拉框。题型在 `--set` 之前选定，所以块里的初始预算可以被覆盖。块内的错误带着块名报出：缺 `start`、`prompt` 或 `answer`，开始符号没有规则，题干引用了别的符号，`context` 或 `width` 不合法，设了文件没声明的属性，初值为负，同一项声明两次，块叫 `main`，两个块同名。

## 6. `set NAME { ... }`：一个文件描述整份作业

```
import "calculus.rhm" as calc
import "boolean.rhm" as bool
import "boolean_equiv.rhm" as laws

set homework {
  part "Differentiation"
    3 of calc.derivative(cost ~ 6 spread 2 low 2)
    1 of calc.integral(cost in {5, 7})
  part "Propositional logic"
    3 of bool.main(cost in {8, 10, 12})
    2 of laws.main(cost = 6)
  part "Mixed"
    2 of any(forms.main(cost = 6), calc.derivative(cost = 8))
  distinct
  balanced
  ordered
}
```

`set` 描述一份作业：哪些题型、各几道、预算多少、什么顺序。随库发布的示例是 `homework_set.rhm`；一个文件可以有多个 set，可以和自己的题型放在一起，也可以像它那样只有 set。

```
rhema run homework_set.rhm --run homework             这份作业，带预算和均值的列表
rhema homework_set.rhm --run homework                 同一份，编译成 homework.pg
rhema homework_set.rhm --run homework --student 2330026211 -o hw_2330026211.pg   某个学生自己的卷子
rhema homework_set.rhm --run quick --pg-dir out/      每题一个 .pg 文件
rhema list homework_set.rhm                           列出 set
```

**条目。** `N of 题型(抽取)` 要 N 道某种题型：本文件的 `main` 或某个块，或引入模块的 `alias.name`。`N of any(Q1(...), Q2(...))` 让 N 道题在列出的题型间均匀分配。抽取给题型继承属性设初值，有三种写法：

- `cost = 5`：这一条目的每道题都从 5 开始。
- `cost in {8, 10, 12}`：每道题抽列表中的一个值；列表均匀使用，每个值都用过一次才会重复。
- `cost ~ 6 spread 2`：围绕均值抽预算，再调整到这一条目的均值正好是 6（`low 2` 保证每个预算不低于 2；`allowed {4, 6, 8}` 把抽取限制在这些值里，用于只有固定形式的文法，此时均值尽量接近）。这就是 `tools/rhema_difficulty.py set` 的算法搬进语言：期望控制难度住在这里。

**部分。** `part "标题"` 开始一个部分；之后的条目在一个大题号下按字母编号，`1(a)`、`1(b)`，标题印在前面。没有 `part` 行的 set 是平铺的：每道题自己一个号。

**约束**，各一个词：`distinct` 拒绝和前面某道题树形相同的题（用到的规则相同、叶子擦掉：3 + 4 和 7 + 2 是同一个形状）；`balanced` 拒绝连续第三个相同的编码答案（真/假，或一位数编码）；`ordered` 把部分内的题按总预算从易到难排。满足不了的约束——`distinct` 下两道只有一条规则的题——在有限次尝试后报出，并点名那道题。

**一份作业一张卷子。** set 就是作业，每次生成都是同一份：今天跑 `rhema homework_set.rhm --run homework` 和下个月跑得到同样的题。`--assignment NAME` 可以另起名字。在 set 末尾加一道题不会改变前面的题。没有人选择或看到种子：变体由作业名在引擎内部派生。`--student ID` 是可选的：加上后是这个学生自己的卷子，每次相同，和其他学生的、和作业本身那一份都不同。`--set`、`--count`、`--question` 对 `--run` 不起作用：set 自带这些。

**输出。** 列表给出每道题的题型和预算，末尾是每部分各预算的均值。`--pg` 写一个文档：标题作为段落，每道题干前有 `1(a).`，相同上下文的连续题在一个 PGML 块里，中间切换 `Context()`。`--pg-dir` 每道题写一个 `.pg` 文件。

**是词不是关键字。** 只有 `set` 是保留字。`part`、`of`、`any`、`in`、`spread`、`low`、`allowed`、`distinct`、`balanced`、`ordered` 都是普通标识符，只在 set 块内有含义，所以文法仍可以把属性叫 `low`；写错的词按"此处应为某词"报出。

**错误**都在 set 处报出：文件或模块没有这个题型、别名没有引入、文法没有这个属性或同一属性抽两次、负值、数量为零、没有条目的 set、两个 set 同名、同一约束写两次。

只有 import 和 set 的文件没有自己的题：`rhema` 会说明并列出 set，网页端的文法列表不显示它。

## 7. 几处小的补充：真值字面量、局部名字、点、任意形状的矩阵

这四处补充不改变任何已有文法，只是去掉了文法库里积累下来的几种绕路写法。

**`true` 和 `false`** 是两个真值；以前文法只能写 `0 = 1`。两者都是保留字。

```
answer_value = set_interval($2.first, $2.second, false, false)
```

**产生式里的局部名字**：在花括号内写 `let NAME = EXPR`。它在所写的位置求值，此时子结点已经建好，它下面的各行都可以使用它。结点不携带它：不需要 `synth` 声明，其他产生式也看不到它。以前，一个要用两次的值只能写两遍，或者挪到一个辅助非终结符里。

```
Q -> "line_two_points" P P when cost = 2 {
  cost = -2
  let slope = ($3.y - $2.y) / ($3.x - $2.x)
  answer_value = polynomial_linear(slope, $2.y - $2.x * slope, "x")
  ...
}
```

名字必须是新的。局部名字如果会遮住继承属性、综合属性、random 或文件级的 `let`，或者在同一个产生式里出现两次，都会被拒绝；保留字（如 `left`、`width`）也不能用作名字。守卫条件、预算更新和生成器的参数在子结点建好之前求值，所以不能使用局部名字。文件级的 `let` 不变：它每道题只算一次，在建树之前。

**点**是一种值：`point2(x, y)` 和 `point3(x, y, z)`，配有 `point_latex`。作为答案时，它在 PG 中写成一个自带 WeBWorK Point 上下文的 Point 对象，所以学生输入 `(3, -2)`，无论题目处在哪个上下文，都按点来判分。文法不必为它设置 `pg_context`；`analytic_geometry.rhm` 就在同一个上下文里混用了数、式子和点。

**任意形状的矩阵。** `matrix_row(v)` 和 `matrix_column(v)` 把向量变成只有一行或只有一列的矩阵；`matrix_stack(A, B)` 把 `A` 放在 `B` 的上面，`matrix_augment(A, B)` 把 `B` 放在 `A` 的右边，所以增广矩阵 `[A | b]` 就是 `matrix_augment(A, matrix_column(b))`。`matrix_rows` 和 `matrix_columns` 给出行数和列数。`matrix_rref` 是行最简形，用精确有理数做高斯–若尔当消元得到；`matrix_rank` 是其中主元的个数，即矩阵的秩。

## 8. 文本中的答案空，以及不止含 x 的式子

提案和在 WeBWorK 上做过的试验见 `RHEMA_ADDITIONS_DESIGN.zh.md`；这里写的是实际实现的内容。

**文本中的答案空。** `blank(VALUE)` 是一个答案空，用 `++` 接到文本上；`blank_wide(VALUE, COLUMNS)` 是带有自己宽度的答案空。产生式把答案空写进自己的文本里，题干中取到这种文本的填充位置会把其中的答案空带进题目：

```
Q -> "circle" nonzero_integer_between(-9, 9) nonzero_integer_between(-9, 9) integer_between(1, 9) when cost = 3 {
  cost = -3
  ...
  text = "Find the centre and the radius of the circle [`...`]. Centre: "
         ++ blank(point2($2.value, $3.value)) ++ " Radius: " ++ blank($4.value)
}

prompt "{Q.text}"
```

只有一个空的题型和有多个空的题型现在可以放在同一个文法里；以前，答案空由题干决定，而每个题型只有一个题干。只要文件的规则或 let 中调用了 `blank`，就不需要 `answer` 行。以下情况会被拒绝：生成出来的题一个空也没有；既有 `answer` 行、文本里又有答案空；把带空文本交给 `++` 和题干以外的地方；答案空落在数学公式里面（在 `` [` `` 和 `` `] `` 之间）。题干里的 `{answer ...}` 和 `answer` 行不变。

**任意变量的式子。** `formula_variable("y")` 和 `differentiate(f, "y")` 一直都有，但 WeBWorK 的 Numeric 上下文只认识 `x`，所以这样的答案无法编译。现在，含有其他变量的式子答案会连同一个声明了这些变量的上下文一起写出；同一道题里所有式子答案的变量会一并声明，所以这道题的各个空接受同样的变量名。只含 `x` 的式子写法不变。`formula_value(f)` 给出不含变量的式子所等于的精确数值。

文法也可以自己指明变量：`pg_variables` 是一段写明变量名的文本，例如 `"x y"`，既可以是文件里的一个 `let`，也可以是开始符号为每道题计算的属性。这样，每个式子答案都会声明其中所有的变量。否则，求出来是 `6y` 的答案所在的空就不认识 `x`，学生如果输入了 `x`，得到的会是“变量未定义”的提示，而不是判错。`partial_derivatives.rhm` 声明了 `"x y"`。

**任意变量的命题。** 命题答案原来有同样的毛病：它是按当前的 Boolean 上下文写出的，而 `contextBoolean.pl` 的 Boolean 上下文只认识 `p` 和 `q`，所以含有 `r` 的答案 WeBWorK 读不了（“Variable 'r' is not defined in this context”）。`logic_forms.rhm` 的改写题大多受此影响。现在，命题答案会连同一份 Boolean 上下文的副本一起写出，副本里声明了它自己的变量、同一道题里其他命题答案的变量，以及 `pg_variables` 指明的变量。答案自带这个上下文，所以文法不必再声明 `context "Boolean"`；只要文档里有命题答案，生成的文件就会加载 `contextBoolean.pl`。

**π 和精确值。** `formula_pi()` 是常数 π，写给 WeBWorK 时是 `pi`，在 LaTeX 中是 `\pi`、`2\pi`、`\frac{5\pi}{6}`。`exact_sin(p, q)`、`exact_cos(p, q)`、`exact_tan(p, q)` 给出在 `p π / q` 处的函数值，结果是 `sqrt(3)/2` 这样的式子，支持 π/6 和 π/4 的整数倍。

**必须算出来的答案。** `plain(VALUE)` 是一个数或式子，判分时关闭三角函数、双曲函数、对数函数和指数函数（保留 `sqrt` 和 `abs`）。不用它的话，WeBWorK 会把 `sin(pi/3)` 当作 sin(π/3) 的值接受；`exponential_log.rhm` 中的 log₅(625) 以前也会接受 `log(625)/log(5)`，现在它改用了 `plain`。

**分子很大的分数。** 分数也有同样的问题，只看分子，与分母无关：在渲染器上实测，分子从 1001 起，WeBWorK 会把 `(p + 1)/q` 和 `(p - 1)/q` 当作 `p/q` 接受；分子不超过 999 时从不接受。因此，分子的绝对值不小于 1000 的分数答案现在写成 `Compute("p/q")->cmp(tolType=>"absolute",tolerance=>1/(2q))`：容差是分母的半步，相邻的两个分数都不会通过，显示的标准答案仍是这个分数。学生如果用小数代替分数作答，小数必须精确到这半步之内，这比以前至少严格一倍；较小的分数仍然写成 `Formula('p/q')`，与以前相同。文法库中受影响的是 `arithmetic.rhm` 的较大答案（默认预算下 300 题中有 70 个），以及 `definite_integral.rhm` 和 `statistics.rhm` 的少数答案。下面整数的规则就是这条规则在分母为 1 时的情形。

**精确判分的整数。** WeBWorK 比较数值时使用千分之一的相对容差。在渲染器上实测：1000 以内，它还能把一个整数和相邻的整数区分开；超过 1000 就不能了，答案是 5040 时会接受 5041，答案是 10100 时会接受 10110。因此，绝对值不小于 1000 的整数答案现在写成 `Real(n)->cmp(tolType=>"absolute",tolerance=>0.5)`，即半个单位的绝对容差，其他任何整数都不会通过；较小的整数仍然写成普通的数，不含这类答案的文档写法与以前完全相同。文法库中受影响的是 `arithmetic.rhm`、`counting.rhm`、`sequence.rhm` 和 `series.rhm`：它们较大的答案以前会接受相邻的整数。`exactly(N)` 则不论数值大小都要求这样比较；`base_conversion.rhm` 对写成二进制或八进制的数使用它。

**一处更正。** 式子里的分数写成商的形式 `2/3`，现在在必须加括号的地方会加上括号：`x/(2/3)` 和 `(2/3)^2` 以前被写成 `x/2/3` 和 `2/3^2`。文法库里没有文法会产生这两种写法。

## 9. 错误规则：错误的演算不会得到正确的答案

答案正确，并不说明演算正确：习惯“大数减小数”的学生，做 `7 - 3` 照样是对的。现在文法可以说明一种错误是什么。引擎会给出每种错误导致的答案，并且绝不生成这样的题目：错误已经改变了演算过程，最后的答案却仍然正确。

**声明一种错误。** 在文件级写出它的名字，以及学生是怎么做的：

```
mistake factor_by_factor "differentiates a product factor by factor"
mistake no_chain "leaves out the derivative of the inside"
```

（说明文字是给人看的，按代码规范用英文书写。）

**说明错误出在哪一步。** 错误出在演算的某一步，而一步就是一条产生式。在花括号内，产生式算出一个值之后，用一行*错误行*写出犯这种错误的学生在这里算出的是什么：

```
F -> "sin" F when cost >= 2 {
  cost = -2
  f = formula_sin($2.f)
  d = formula_multiply(formula_cos($2.f), $2.d)
  mistake no_chain d = formula_cos($2.f)
  latex = formula_latex(f)
}
```

生成题目时这一行被跳过。它可以给上方已经算出的综合属性或局部名字换一个值，并且可以使用它上方的一切，包括同名的正确值（`mistake smaller_from_larger value = cond(value < 0, -value, value)`）。

**引擎做了什么。** 一道题建好之后，凡是它的树中有产生式为之写了错误行的错误，都要试一遍：从叶子向上把树重新求值一次，这次读入该错误的错误行；其余的值仍由正确的方程计算，所以在树的低处犯的错误会沿着正确的演算一路传上去，和学生在纸上的情形一样。`require` 不再重新检查。一个值是*错误值*，当且仅当错误行给它的值与正确值不同，或者计算它时读到了错误值；为此引擎记录了每个方程实际读过哪些值。然后：

| 发生了什么 | 结果 |
|---|---|
| 没有任何错误行改变了值（例如 `no_chain` 之于 `sin(x)`） | 这道题里没有犯这种错误 |
| 没有任何答案读到错误值 | 这种错误与这道题无关 |
| 有答案读到了错误值，并且某个答案变了 | 报告这种错误，以及它导致的答案 |
| 有答案读到了错误值，但所有答案都没变 | 丢弃这道题，重新生成 |

因此，在生成出来的题目里，只要错误改变了演算，就一定会改变答案。`rhema run` 会显示结果：

```
 3. Differentiate [`4 \cdot x \cdot \sin\left(x\right)`] with respect to [`x`].
    answer: Formula(4*sin(x)+4*x*cos(x))
    mistake factor_by_factor: Formula(4*cos(x))
```

**答案按阅卷的方式比较。** 两个式子只要是同一个函数，就算同一个答案：引擎在七个固定的点上分别求值再比较，WeBWorK 的做法相同，只是它用随机点。这里的点是固定的，这样比较答案时不会动用决定试卷内容的随机数序列。其他类型的值用各自的相等判断（命题用逻辑等价，矩阵用各元素相等，等等）。

**几项设计决定。**

- *答案必须由文法一步一步算出来。* 错误只能沿着文法写明的演算传递。如果文法只在根结点调用一次 `differentiate`，错误就无处可犯；`calculus.rhm` 现在把导数作为属性，逐条产生式计算。
- *错误只在它改变了某个值的地方才算数。* 最初的版本把每一行错误行都算作犯错，于是凡是含有 `sin(x)`、又没有别的正弦来弥补的题目都会被丢弃，文法库连最基本的题都出不了。改为“只有改变了值才算”之后，这些题得以保留，文法也不必为“此处不可能犯错”的情形另写一条产生式。
- *这个筛选保证的是判分，不是覆盖。* 它保证错误的演算不会被判为正确；它并不保证每道题都考查每种错误：一份全是 `sin(x)` 这类题的试卷会被接受，却考查不到 `no_chain`。一份试卷覆盖了哪些错误，要看输出的列表；让套题提出覆盖要求是以后的工作。
- *导致无值的错误*（例如除以零）报告为 `no answer`，题目保留：这名学生得不到正确答案。错误行因其他原因无法求值，则是文法本身的问题，生成会停止，并在报错信息中指出是哪一种错误。
- *模块的错误属于模块自己。* 由导入模块的符号建出的子树，不会在导入方的错误下重新求值；模块自己声明的错误只作用于模块自己的题目。`include` 则像合并其他声明一样合并错误声明和错误行。
- *`mistake` 是保留字*，与 `require`、`let` 相同。

**文法库中的错误。** 有四个文法声明了错误。

| 文法 | 错误 | 文法的改动 |
|---|---|---|
| `calculus.rhm` | `factor_by_factor`（乘积逐个因子求导）、`no_chain`（漏掉内层函数的导数）、`top_and_bottom`（商的分子、分母分别求导） | 每条产生式增加导数属性 `d`；求导题用它作答案 |
| `complex.rhm` | `i_squared_one`（把 i 的平方当作 1）、`minus_real_only`（实部相减而虚部相加） | 增加两行；实部和虚部原本就是逐条产生式计算的 |
| `boolean.rhm` | `false_antecedent`（前件为假时把条件命题当作假）、`exclusive_or`（把“或”理解为二者只居其一） | 每条产生式增加真值属性 `v`；题目用它作答案 |
| `polynomial_core.rhm` | `power_term_by_term`（括号里的各项分别乘方） | 在平方和立方两条产生式上各加一行 |

与不带错误的同一文法相比，在同样的 500 道题的试卷上：

| 题型 | 相同的题目 | 其余题目不同的原因 |
|---|---|---|
| `calculus.rhm` 求导 | 前 244 道 | 有一道题掩盖了错误而被重新生成，其后每次抽取都随之改变 |
| `calculus.rhm` 积分 | 全部 500 道 | 没有哪种错误与积分题有关 |
| `boolean.rhm` | 前 24 道 | 答案只有两种取值时，错误被掩盖的情况很常见 |
| `complex.rhm` | 前 66 道 | |
| `polynomial_expand.rhm`、`factoring.rhm`、`polynomial_forms.rhm` | 全部 500 道 | 各项分别乘方的错误总会显现 |

试卷的整体面貌没有变化：`boolean.rhm` 在预算 4 到 14 下，互不相同的题目所占比例精确到百分位都相同，答案为真的比例保持在 49% 到 54% 之间；生成 2000 道题用时 4.9 秒，原来是 4.6 秒。`calculus.rhm` 求导题的答案与原来是同一个函数，大约每一百道题里有一道的写法不同。

**目前还没有做的。** WeBWorK 和 LaTeX 输出没有变化：错误答案还没有用于提示，也没有用作干扰项。套题还不能要求覆盖某种错误。`linear_equation.rhm` 没有声明错误：它的答案就是构造方程时选定的根，要表达展开时的失误，需要把方程左边按学生看到的样子再算一遍。

测试：`rhema_mistakes_test.ml`（检查器拒绝的各种写法；用独立的读取程序核对报告的错误答案；错误恰好在它改变了值的地方被报告；没有一道题会掩盖错误，而去掉错误声明的同一文法确实会生成这样的题；错误值到达不了的答案；模块与 include；局部名字与答案空；式子按函数比较；对文法库中的每个文法，逐条产生式算出的值是正确的，并且报告的每种错误都导致不同的答案）。面向文法作者的说明见教程第 9 章和语言参考中的 “Mistakes” 一节。

## 10. 静态类型：由 `rhema check` 发现，而不是在生成试卷的中途

在此之前，值的类型只在使用它的那一刻、也就是生成题目的过程中才被检查。一个把文本和数相加的文件可以通过 `rhema check`，直到某道题执行到那一行才停下；如果那一行只有部分题目会执行到，试卷就会生成到一半才失败。现在检查器会推断类型，并自己报告这类用法。

```
let label = "n = " ++ n
let broken = label + 1
```

```
quiz.rhm:5:14: error: '+' takes a number on its left, but 'label' is text
```

**没有新的语法。** 没有任何地方需要声明类型。语言里原本没有参数声明、用户自定义函数和列表，这次也没有增加。

**一张表。** `rhema_types.ml` 列出值的十八种类型，并说明每个运算符和 154 个函数各自接受什么、给出什么。检查器从这张表读取函数的名字、参数个数和类型；`rhema doc` 和网站上的内建函数页面也把它打印出来。四个生成器是叶子而不是函数，仍在检查器里保留自己的一张短表。引擎保留自己的运行时检查，并由一项测试保证两者一致（见下文）。

**类型是一个集合。** 同一个非终结符的两条产生式可以把一个属性分别算成数和式子，`cond` 的两个分支也可以不同；文法库里这两种情况都有。因此检查器为每个表达式推断它*可能具有的类型的集合*：

- 字面量、random、预算、生成器叶子：一种类型；
- 函数：表中给出的类型；`cond`：两个分支的并集；
- 综合属性：它所属非终结符的所有产生式给出的类型的并集，按“（非终结符，名字）”区分，所以 `E` 上的 `value` 和 `Q` 上的 `value` 互不相干；
- 模块的属性和值：检查该模块时得到的集合，保存在它的规格里，由导入它的文件读取。

运算符或函数只有在每个操作数都可能具有它所接受的类型时，才给出结果类型；否则这个表达式没有类型，因为它永远无法求值。这些集合从空集开始，反复读取所有产生式，直到没有集合再增大为止。由于一个集合所依赖的集合增大时，它自己不会丢失任何类型，所以结果与声明的先后顺序无关；又因为类型的种类是有限的，这个过程一定会结束。

最初的版本有两处错误，现已修正，并各有一项测试。其一，它在拒绝某个操作数之后仍然认定运算符会给出结果，于是在 `E -> E + E` 中，如果叶子的 `value` 是文本，求和这条产生式自己就把“数”加进了 `E.value`，写错的叶子因而蒙混过关。其二，在集合还在增大的过程中，它把 `++` 被拒绝的一侧当作文本，结果三条产生式的书写顺序会影响检查的结论。

**报告什么。** 只有当操作数的集合里*没有任何一种*类型被允许时，才算错误。只要有某种类型被允许，就留给引擎处理。凡是在生成之前无法判定的情况都按这条规则办。

表达式写在哪里就在哪里被检查，即使它永远不会被求值：`cond` 里没被选中的分支，`and`、`or` 的右侧，任何题目都到达不了的产生式。

**检查哪些地方。** `when` 条件和 `require`（必须是真值）；预算更新、生成器的参数、模块的起始值（必须是数）；每个运算符和函数的参数；把 `$n` 当作值使用，或者在 `infix`、`prefix` 需要子结点的位置给了一个值（子结点上同名的属性必须是文本）；题干显示的内容，以及答案空和 `answer` 用来判分的值；`pg_context`、`pg_width`、`pg_variables`；还有错误行。

**错误行**可以给出任何种类的值：题目要的是全部根的集合，学生只写出一个根；题目要的是一个数，学生写的是“无解”。最初的版本要求错误行给出与正确值同一种类的值；独立核查表明，这会拒绝原本可以正常使用的、真实的错误，而引擎从来没有这样的规则。现在只拒绝必定失败的写法。检查器为每一种错误把文件再读一遍，读法与引擎在该错误下重新求值一棵已建好的树相同：该错误的错误行给各自的名字换上新值，`require` 不读，一个属性在该错误下具有的类型，是各条产生式在这种读法下给出的类型的并集。如果某处用法对这些类型一种也不接受，就报告为 `under the mistake 'NAME', ...`，因为每次尝试这种错误时生成都会停在那里。这一遍读取不参与对正确演算的类型推断。

**报错信息。** 类型检查放在最后，只对已经通过其他全部检查的文件进行，所以一个未声明的名字不会因为“没有类型”而被再报一次；这也意味着类型错误要等其他错误都消除之后才会出现。每一处错误的用法给出一条信息（一个运算符两侧都错就是两条），而建立在错误用法之上的表达式不再报错。操作数是名字、子结点或函数调用时，信息指向这个操作数；字面量和带括号的表达式没有自己的位置，这时信息指向包住它的函数调用，或者这一行的开头。

**对已有文件的影响。** 不含上述用法的文件，检查和生成都与以前相同：文法库的输出逐字节一致。以前能够生成题目、现在被拒绝的文件有两种情况：

- 类型错误写在从未被求值的地方：没被选中的分支，被短路的一侧，从未被选中的产生式，永远不成立的 `require` 下面的各行，被 include 或 import 的文件里没有用到的符号，或者类型不对的预算更新（引擎以前会悄悄地永不选用这条产生式）；
- 答案是方程，或者是带有答案空的文本：`rhema run` 以前会列出这样的题目，而 PG 输出会因异常而中止。

在这台机器上，文法库之外还有 98 个 `.rhm` 文件（内容互不相同的有 66 个：以前写的文法、为撰写语言说明而写的探测文件、编辑器扩展的测试工作区、其他工作树里的示例）。新旧检查器对其中 95 个的结论相同；新检查器多拒绝的 3 个，以前都是在第一道题上因同样的原因失败的。

**不检查的内容**（它们仍然会让生成停下并给出信息）：一个数是否为整数，除数是否为零，矩阵和向量的形状，函数的定义域，方程是否有精确解，只有部分类型允许的用法（无论是在正确的演算中还是在某种错误之下），以及无法满足的 `require` 和花不掉的预算。通过 `rhema check` 并不意味着文件不会失败。

**顺带发现、未作改动的问题。** 有九个函数在变量名不合法时，会把底层库的异常原样抛出，而其他函数会报告为错误：`polynomial_variable`、`polynomial_constant`、`polynomial_linear`、`polynomial_quadratic`、`formula_to_polynomial`，以及 `equation_has_exact_solutions`、`equation_solution_count`、`equation_solution_set`、`equation_unique_solution`。凡是接受文本的地方，数都能通过检查（因为引擎会把它写成文本），所以 `polynomial_variable(2)` 会被接受，并以这种方式终止。另外，方程经由 `cond` 成为答案时，PG 输出仍会因异常而中止，这是检查器无法排除的。

测试：`rhema_types_test.ml`。（1）用引擎核对类型表：148 个带参数的函数，每个参数位置分别代入十八种类型中的每一种，其余参数保持正确，共 4662 次调用；检查器拒绝某次调用，当且仅当表拒绝它；引擎从不接受表所拒绝的调用，也不会因为类型而拒绝表所允许的调用；调用成功时得到的类型是表中列出的类型。以子结点为参数的 `infix` 和 `prefix`，以及四个无参数的函数另行测试；每个运算符与每种类型、每一对类型都试过，检查器的结论必须与引擎一致。（2）用生成结果核对推断：文法库每种题型各生成 25 道题，由产生式建出的每个结点（无论在文件本身还是在模块里）的每个综合属性，以及文件自己的每个 random 和 let，其实际类型都在为它推断出的集合之内（分别约 20000 个和 7700 个值）。（3）在小文法上测试检查器本身：各种错误的措辞，其中三处还核对了位置；每种必须接受的写法（因产生式或 `cond` 而具有多种类型、把数当文本用、答案包装、取决于值的错误）；递归、写错的叶子和产生式的顺序；导入；错误行。原有四个测试期望这些错误在生成时出现，现在改为期望由检查器报告，并各保留一个经由 `cond` 书写、仍会到达引擎的版本。

生成结果没有变化：文法库的 47 种题型（各 40 道题）、文法库里的套题（指定和不指定学生两种情况）、七个 PG 文件和一份 LaTeX 试卷，与改动之前的提交逐字节相同。

## 这带来了什么

一个文件现在可以容纳需要不同上下文的多种题型、分成几个小问的题目、与其他文件共享的产生式，并排使用来自其他文件的完整文法而不必改动它们的任何名字，在一套规则上定义多个有名字的题型，在一个文件里描述并生成整份作业，让答案空个数不同的题型共处一个文法，以及给单个答案空单独设宽度。还做不到的：在一个空里填多个解，让文法为套题声明覆盖约束（“每条律先各出一次再重复”）；见 `RHEMA_MODULES_DESIGN.md` 第 8 节。
