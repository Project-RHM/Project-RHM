# 语言扩展：include、import、有名字的题型、每题一个上下文、多个答案空

*`.ag` 语言的五项新增，让一个文件可以容纳作者想要的任何题型。英文原版见 `AG_LANGUAGE_EXTENSIONS.md`，以英文版为准；语言本身见 `AG_LANGUAGE_GUIDE.md`。*

## 1. `include "file.ag"`：文件之间的复用

```
include "polynomial_core.ag"

context "PolynomialFactors"
synth text on Q
synth answer_value on Q
start Q
Q -> E { ... }
prompt "{Q.text}"
answer Q.answer_value
```

加载器读入被包含的文件（路径相对于包含方，可递归），把它的声明放在包含方自己的声明之前。规则、`synth` 和 `attribute` 声明、random、let、precedence 累加；两个文件都声明的完全相同的 `synth` 或 `attribute` 只保留一份。文法只能声明一次的那些——`start`、`context`、`prompt`、`answer`、`width`——以包含方自己的为准，所以一个文法可以包含另一个文法并用新的题干重新提问。直接或间接包含自己的文件会被拒绝；被包含文件内部的错误会带着该文件的名字报告。

没有 `start`、`prompt` 和 `answer` 的文件是**库**：`agcheck` 接受它并说明这一点，`agrun` 拒绝用它生成，网页的文法列表不显示它。`polynomial_core.ag` 就是一个库；它存放因式树，`factoring.ag`、`polynomial_expand.ag` 和 `polynomial_forms.ag` 都建立在它上面，各自加上自己的问题，展开那个文件还多加了一条因式规则。

包含方声明的 `attribute` 优先于被包含文件的，两个被包含文件声明同一个属性时以先到的为准，所以默认预算不同的两个文法可以一起包含，由包含方统一设定两者花的预算。两个文件里同名的 random 和 let 仍然报错。

非终结符按名字共享，所以两个都用 `E` 的文法不能原样包含进同一个文件，两个文件里同名的 random 也会冲突。`include` 是**扩展**一个文法的工具：往它的非终结符上加规则、重新提问。要把两个文法并排放在一起，用 **import**（第 4 节）：每个文法的名字都留在自己的别名后面。

## 2. 每道题自己的上下文和答案宽度

开始符号计算综合属性 `pg_context` 的文法，每道题有自己的 WeBWorK 上下文；`pg_width` 同样决定答案宽度。

```
synth pg_context on Q

Q -> E "expand" { pg_context = "Numeric"  ... answer_value = $1.poly }
Q -> E "factor" { pg_context = "PolynomialFactors"  ... answer_value = $1.factored }
```

`.pg` 文件加载它用到的每个上下文的宏，同一上下文的题目写在同一个 PGML 块里，块与块之间切换 `Context()`。所有题目都用文件级 `context` 的文件，输出和以前完全一样。`polynomial_forms.ag` 展示了同一棵树问两种问题，各在自己的上下文中。

## 3. 多个答案空：题干中的 `{answer ...}`

```
prompt "{Q.text}
(a) Find [`a_{{{index_text}}}`]: {answer Q.nth}
(b) Find the sum [`S_{{{index_text}}}`]: {answer Q.sum}"
```

`{answer Q.nth}` 在题干的这个位置放一个答案空，按开始符号的该属性判分；`{answer total}` 按某个 random 或 let 判分。每个空在 WeBWorK 中单独判分，这就是 (a)(b)(c) 分小问的写法。自己放置了答案空的题干不再写末尾的 `answer` 声明；没有放置的仍然保留它，答案空像以前一样跟在题干后面。`sequence_parts.ag` 对同一个数列问第 n 项和前 n 项和。

可读的文本输出中，内联的空显示为 `[___]`，答案按顺序列出；生成的题目把它们放在 `answers` 里，`answer` 仍是第一个，供只读一个答案的工具使用。

## 4. `import "file.ag" as name`：模块

```
import "calculus.ag" as calc
import "boolean.ag" as bool

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

`import` 把另一个文件作为**模块**引入：该文件单独加载、单独检查，它声明的一切都通过别名访问，所以它和引入方、和其他模块之间不可能撞名。上面就是随库发布的 `derivative_or_boolean.ag`；`logic_forms.ag` 引入 `boolean.ag` 和 `boolean_equiv.ag`，这两个文件都有 `Q`、`E`、`cost` 和 `phrasing`，照样一起用。

**名字。** 模块的非终结符在规则右侧写成 `calc.F`；它的 random 和 let 在表达式里写 `bool.given`、`bool.mask`，在题干里写 `{bool.given}` 或 `{answer bool.total}`。综合属性不用别名：`$1.latex` 从子节点读，检查器知道这个子节点是 `calc.F`，就按那个模块检查名字（`$1 is calc.F, which does not carry 'value'`）。继承属性只在参数里点名。模块的优先级表和规则对外不可见。内置函数是全局的，从不加限定。模块内部自己的名字仍然不加限定，所以现有文件的含义一个都不变。

**参数。** `calc.F(cost = cost - 1, advanced = 1)` 给模块的继承属性设这棵子树上的初值；没点名的取模块声明的默认值（单写 `calc.F` 时从 `calculus.ag` 的 `attribute cost = 7` 开始）。参数表达式在父节点求值，此时子节点还不存在：可以用字面量、父节点的继承属性、引入方的 random 和 let、模块的值、内置函数。结果必须是整数，不能为负。

参数里出现父节点的属性名，表示**这个子节点应得的份额**：`copy` 下是整个值，`split` 下是它作为本地非终结符本来会分到的那份。所以在 `attribute cost = 6 split` 下写 `M -> bool.E(cost = cost) "," laws.L(cost = cost + 1)`，两个模块合计花 7，对每棵子树调 `Ag_engine.consumption` 报的就是该模块花掉的数。模块的预算是它自己的：`calc.F` 永远看不见引入方的 `cost`；定价标尺不同的两个文法在边界相遇，汇率由引入方写在参数里（上面的 `cost + 2`）。

**一个文件一个模块。** 同一个文件被引入两次，无论是两个别名还是两个引入方，都是同一个模块：它的 random 每道题只画一次，两个别名看到同样的值（`a.p = b.p`）。模块自己也可以 import 和 include 文件，那些对外不可见（`forms.bool.E` 不是一个名字）。库（没有 `start`）也可以像文法一样引入：`import "polynomial_core.ag" as poly`，然后 `poly.E(cost = 5)`。直接或间接引入自己的文件会被拒绝，并报出文件链。

**括号。** 引入方的优先级表对模块的运算符一无所知，所以模块子树在引入方眼里是一个原子：`infix()` 不会在它外面加括号。把 `calc.F` 嵌进更大表达式的规则要自己写括号（`"(" ++ $1.latex ++ ")"`），或者用模块为此提供的属性。

**错误**都在引入方报出：别名不存在、模块没有这个非终结符、参数点名了模块没有的属性或设了两次、模块子节点没有这个综合属性、模块没有这个 random 或 let、两个 import 用了同一个别名、引入成环。模块自身内部的错误带着模块的文件名报出，前面先有一行指在 `import` 处说明是哪个引入带进来的。`agcheck` 会列出解析到的 import。

**include 还是 import？** 扩展用 include，组合用 import。一个文件可以两者都用：`factoring.ag` include `polynomial_core.ag` 以在它的因式树上加一道题；`derivative_or_boolean.ag` import 两个完整的文法。

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

`calculus.ag` 是随库发布的示例：`main`（start `Q`）在导数和积分之间随机，`derivative`（start `D`）和 `integral`（start `I`）各只问一种形式，三者共享形式 `D`、`I` 以及它们之下的表达式文法。全是块、没有 `main` 的文件以第一个块为默认；两者都没有的文件是库。

```
agrun calculus.ag                                   main
agrun --question integral --set cost=5 calculus.ag  指定一个题型
agcheck calculus.ag                                 列出题型
```

题型多于一个时 `agcheck` 列出每个题型及其开始符号和上下文；网页端对这样的文件多出一个题型下拉框。题型在 `--set` 之前选定，所以块里的初始预算可以被覆盖。块内的错误带着块名报出：缺 `start`、`prompt` 或 `answer`，开始符号没有规则，题干引用了别的符号，`context` 或 `width` 不合法，设了文件没声明的属性，初值为负，同一项声明两次，块叫 `main`，两个块同名。

## 这带来了什么

一个文件现在可以容纳需要不同上下文的多种题型、分成几个小问的题目、与其他文件共享的产生式，并排使用来自其他文件的完整文法而不必改动它们的任何名字，以及在一套规则上定义多个有名字的题型。还做不到的：给单个答案空单独设宽度，描述一整套题；后者是 `AG_MODULES_DESIGN.md` 里的下一步。
