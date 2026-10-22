# 语言扩展：include、每题一个上下文、多个答案空

*`.ag` 语言的三项新增，让一个文件可以容纳作者想要的任何题型。英文原版见 `AG_LANGUAGE_EXTENSIONS.md`，以英文版为准；语言本身见 `AG_LANGUAGE_GUIDE.md`。*

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

非终结符按名字共享，所以两个都用 `E` 的文法不能原样包含进同一个文件。库应当使用自己专用的非终结符名；打算被包含的文法应当按非终结符声明综合属性（`synth value on E`），因为不带 `on` 的 `synth value` 会要求包含方的每个非终结符都计算它。随库发布的文法都已这样写；calculus 的 `F`、`T` 和 boolean 的 `E`、`V` 互不冲突，`derivative_or_boolean.ag` 把两个文法整个包含进来，每道题问其中之一：

```
include "calculus.ag"
include "boolean.ag"
attribute cost = 8 split
synth kind on M  synth text on M  synth answer_value on M
start M
M -> F "derivative" { ... answer_value = differentiate($1.formula, "x") }
M -> E "boolean"    { ... answer_value = $1.value }
prompt "{M.text}"
answer M.answer_value
```

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

## 这带来了什么

一个文件现在可以容纳需要不同上下文的多种题型、分成几个小问的题目，以及与其他文件共享的产生式。还做不到的：给单个答案空单独设宽度，以及包含两个非终结符同名的文法。
