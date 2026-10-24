# `.ag` 语言的模块层与组合层——设计方案

状态：第 1、2 步（模块与参数、有名字的题型；第 2、3 节和 7.1、7.2）已实现，说明见 AG_LANGUAGE_EXTENSIONS.zh.md 第 4、5 节；第 3 步（套题）仍是方案。与第 3 节的一处出入：全是块、没有 `main` 的文件以第一个块为默认。对应英文版：AG_MODULES_DESIGN.md。

## 0. 一段话说清楚加了什么

现在一个 `.ag` 文件就是一种题型，复用别的文件只有 `include` 一种办法，而它是把对方的声明原样贴进一个扁平的命名空间。本方案加两层：

- `import "calculus.ag" as calc` 把一个文件作为有名字的模块引入。它的非终结符、属性、随机值、let 都通过 `calc.Q`、`calc.cost`、`calc.given` 访问，不可能撞名。
- 产生式可以带参数地使用引入的非终结符：`M -> calc.Q(cost = cost - 1)`。参数给这棵子树的继承属性设初值，没写的取该模块自己的默认值。
- 一个文件可以声明多个有名字的题型，各有自己的开始符号、题干、答案、context 和宽度：`question derivative { ... }`。
- `set` 声明描述一整份作业：哪些题型、各几道、预算多少、什么顺序，引擎直接写出 PG 文档。"期望控制难度"（一套题的预算均值可选）从 `tools/ag_difficulty.py` 搬进语言里。

`include` 保留。它用于**扩展**一个文法（往它的非终结符 E 上加规则）；`import` 用于**组合**文法。

语言仍然是属性文法。这里不加语句、循环、可变状态，表达式里也不加递归；原有的静态保证（每棵树的属性都有值、预算精确花完、类型在生成前已知）全部保留，并延伸到模块边界之外。

## 1. 为什么现在的语言不够用

已经在组合文法的两个文件把限制暴露出来了：

- `derivative_or_boolean.ag` 整体 include 了 `calculus.ag` 和 `boolean.ag`。两个文法被迫花同一个属性 `cost`，而它们的定价标尺不同，因为被 include 的属性保留原名。文件只好重新声明 `attribute cost = 8 split` 来调和两个默认值。`boolean.ag` 不得不把题目符号改名为 `B`，因为 `calculus.ag` 已经用了 `Q`。
- `logic_forms.ag` include 了 `boolean.ag` 和 `boolean_equiv.ag`，后者只好把随机值 `phrasing` 改名为 `law_phrasing` 才能和前者共存。每次撞名都靠改库解决，对用户没写过的库行不通。
- 预算不能按使用处设定。`--set cost=8` 作用于文件里的所有文法；语言里没法表达"一道 6 分的导数旁边放一道 10 分的命题"。`tools/ag_difficulty.py set` 是在外面反复跑 `agrun` 实现的。
- 一个文件一道题。`calculus.ag` 的导数和积分是同一个开始符号的两种形式，用 `kind` 标记区分；用户没法按名字要"一道积分"。
- 一份作业靠 `tools/ag_set.py` 和 `ag_difficulty.py` 拼装，用正则去识别打印出来的文本的形状。引擎手里有树，比它们都清楚。

## 2. 模块

### 2.1 import

```
import "calculus.ag" as calc
import "lib/boolean.ag" as bool
```

- 路径相对于引入它的文件，和 `include` 一样。
- `as NAME` 必写。别名就是这个模块在本文件里的名字。
- 一次运行里一个模块只加载一次，不管多少文件引入它（和 Python 的规则相同）。同一个文件用两个别名引入两次，指的是同一个模块；它的随机值每道题只画一次，两个别名共享。（第二个别名下的全新副本可以以后再加，这次不提。）
- 引入成环时拒绝，并报出文件链，和 `include` 成环一样。
- 模块自己也可以 `import` 和 `include`；它的引入对外不可见。不允许写 `calc.poly.E`，一个文件只能点名自己引入的东西。

### 2.2 限定名

模块声明的所有东西都通过别名访问：

| 模块内              | 引入方写法                  | 说明                              |
| ------------------- | --------------------------- | --------------------------------- |
| 非终结符 `Q`        | `calc.Q`（产生式右侧）      | 可带参数，见 2.3                  |
| `attribute cost`    | `calc.cost`（参数里）       | 只能作为参数的目标                |
| `random p`、`let given` | `calc.p`、`calc.given`  | 表达式和题干里：`{calc.given}`    |
| `synth value on Q`  | `$1.value`（当 `$1` 是 `calc.Q`） | 不用限定：子节点自己拥有它 |
| 优先级表            | 不可见                      | 只在模块自己的子树内排版          |
| `question derivative` | `calc.derivative`         | 只在 `set` 里用，见第 4 节        |

内置函数（`differentiate`、`matrix_determinant`……）是全局的，从不加限定。模块内部用自己的名字时不加限定，和现在完全一样，所以现有文件的含义一个都不变。

综合属性不需要限定，因为它们通过 `$n` 读取，而子节点属于哪个模块在规则里静态可知。检查器因此知道 `$1.value` 是 `calc` 模块里 `value on Q`，并据此定类型。

### 2.3 带参数地使用引入的非终结符

```
attribute cost = 8 split
start M

M -> calc.F(cost = cost) "derivative" {
  text = "Differentiate [`" ++ $1.latex ++ "`]."
  answer_value = differentiate($1.formula, "x")
}

M -> bool.E(cost = cost - 2, depth = 3) "boolean" { ... }
```

- 参数列表点名被引入模块的继承属性，给它们在这棵子树上的初值。没点名的取模块声明的默认值（`calculus.ag` 里的 `attribute cost = 7`）。
- 参数表达式在父节点的作用域里求值：字面量、父节点自己的继承属性、引入方的随机值和 let、内置函数。不能读子节点（子节点还不存在）。
- 参数里出现父节点的继承属性名，表示**这个子节点应得的份额**：`copy` 下是整个值，`split` 下是它作为本模块子节点本来会分到的那一份。所以 `calc.F(cost = cost)` 交出去的正好是一个本地 `F` 会拿到的，精确花完的保证跨过边界依然成立。
- 引入方的属性到边界为止。`calc.F` 看不见引入方的 `cost`，它看见的是 `calc.cost`，由参数初始化。一个模块的预算永远是它自己的，这正是 `derivative_or_boolean.ag` 两套标尺的问题消失的原因：各文法用各自的"货币"定价，汇率由引入方在参数里决定。
- 对引入的子树调 `Ag_engine.consumption tree "cost"` 报的是该模块的属性，测试照样能检查 `calc.F` 把拿到的预算精确花完。

新增的静态检查：别名不存在、模块里没有这个非终结符、参数点名了模块没声明的属性、参数类型不是整数、对库模块里未定义的非终结符的使用。全部带引入方的位置和模块的文件名报出。

### 2.4 `include` 与 `import` 并存

`include` 保持今天的语义（扁平合并；引入方的单例声明胜出；继承属性第一个声明胜出；相同的随机值和 let 去重）。当一个文件想**往已有的非终结符上加规则**时它仍是正确工具，这一点 `import` 做不到：被 `factoring.ag` 和 `polynomial_expand.ag` include 的 `polynomial_core.ag` 保持原样。

写进指南的原则：扩展用 include，组合用 import。一个文件可以两者都用。

## 3. 有名字的题型

### 3.1 声明

```
question derivative {
  start D
  prompt "Differentiate [`f(x) = {D.latex}`] with respect to x."
  answer D.formula
  context "Numeric"
  width 30
  cost = 7                  # 这道题根节点的默认预算
}

question integral {
  start I
  prompt "Find [`\int {I.latex} \, dx`]."
  answer I.antiderivative
  cost = 5
}
```

- 一个 `question` 块装的就是今天文件级单例声明装的东西（`start`、`prompt`、`answer` 或内联的 `{answer ...}` 空、`context`、`width`），外加可选的属性默认值 `name = value`，作用于这道题根节点上模块的继承属性。
- 非终结符、规则、属性、随机值、let 由文件里所有题型共享。两个题型只在从哪里开始、怎么问上不同。
- 文件级的 `start`/`prompt`/`answer`/`context`/`width` 如果存在，构成一个隐含的、名为 `main` 的题型。所以每个现有文法已经有一道题，对它们没有任何改变。
- 既没有 `main` 也没有任何 `question` 块的文件是库，和现在一样。
- 每道题保留 `pg_context` / `pg_width` 机制：开始符号自己算出它们时，覆盖块里的 `context` / `width`。

### 3.2 运行一道

```
agrun calculus.ag                       # main 题型，和今天一样
agrun calculus.ag --question integral   # 指定名字
agrun calculus.ag --question integral --set cost=6
agcheck calculus.ag                     # 列出找到的题型
```

网页端列出 `文件:题型`，而不是只列文件。

### 3.3 题型可以用在哪

题型用在 `set` 里（第 4 节）。它**不是**产生式里的符号：产生式组合非终结符（`calc.F`），set 组合题型（`calc.derivative`）。两者分开让题干保持简单：嵌入 `calc.F` 的产生式用 `$1.latex` 自己写措辞；列出 `calc.derivative` 的 set 用题型自己的措辞。

## 4. 套题（set）

### 4.1 声明

```
import "calculus.ag" as calc
import "boolean.ag" as bool
import "boolean_equiv.ag" as laws

set homework {
  part "Differentiation"
    4 of calc.derivative(cost ~ 6 spread 2)
    1 of calc.integral(cost = 5)
  part "Propositional logic"
    3 of bool.main(cost in 8, 10, 12)
    2 of laws.main(cost = 6)
  part
    2 of any(calc.derivative(cost = 8), bool.main(cost = 12))

  distinct trees
  balanced answers
  order by budget
}
```

条目：

- `N of 题型(参数)`：该题型 N 道。参数和 2.3 的属性参数相同，值有三种写法：
  - `cost = 5`：每道都是 5。
  - `cost in 8, 10, 12`：每道从列表里抽一个，列表轮完一遍才会重复。
  - `cost ~ 6 spread 2`：围绕均值 6、离散 2 抽预算，再调整到这一部分的均值正好是 6。这就是 `ag_difficulty.py set` 的算法（`draw_targets`），搬进引擎。后面可跟 `low 3` / `allowed 4, 6, 8` 限制抽取范围。
- `any(Q1(参数), Q2(参数), ...)`：这一条目的每道题从列出的题型中均匀选一种。
- `part "标题"`：同一部分的题在一个大题号下按字母编小题，和 `tools/ag_set.py` 一样；没有标题的 part 也是一个部分。没有任何 `part` 行的 set 是平铺列表。

约束（都可选，都是引擎已有数据可以直接判断的）：

- `distinct trees`：整套题里没有两道的推导形状相同（用到的规则及顺序相同、变量重命名后一致）。`ag_set.py` 用对打印文本的正则近似这件事；引擎手里有树。
- `balanced answers`：答案是布尔值或编码选项的题，不出现连续超过两道答案相同。
- `order by budget`：部分内由易到难。默认按抽取顺序。

刻意**不**放进 set 语言的：对特定规则的覆盖（"每条律先各出一次再重复"），因为那是某一个文法自己的事。暂时留在 `ag_set.py`；由文法声明的 `cover` 约束是以后的候选。

### 4.2 运行一套

```
agrun exam.ag --run homework --seed 42 --pg > homework.pg
agrun exam.ag --run homework --seed-from 2330026211 --pg-dir out/
```

- 每道题的种子由套题种子和题号派生，所以一套题可复现，末尾加一道题不会改变前面的题。
- `--pg` 写一个 PG 文档：大题编号、小题字母，相同 context 的连续题放在一个 PGML 块里（`ag_pgml.document` 已有的分组），文件头加载所有用到的 context 宏。
- `--pg-dir` 每道题写一个 `.pg` 文件，和 `ag_difficulty.py set --pg-dir` 一样。
- 不带 `--pg` 时列出每道题的预算和答案，末尾给出每部分的预算均值，这正是期望方法关心的统计量。
- 一个文件可以有多个 set，`--run` 指定一个。只有 set、自己没有题型的文件也可以运行（通过它的 set）。

### 4.3 Python 工具怎么办

- `ag_difficulty.py report` 和 `levels` 保留：它们是测量一个文法，这是工具的事，不是语言的事。
- `ag_difficulty.py set` 改成薄封装（写一个只含一个 set 的 `.ag` 再运行），然后退役。
- `ag_set.py` 在 `cover` 形式出现前保留律覆盖约束；它的其他约束由 `distinct trees` 和 `balanced answers` 取代。
- 网页端加一个"套题"页面，用表单生成 `set` 块。

## 5. 实例：改造后的 `derivative_or_boolean.ag`

现在（37 行，两个 include，共享的 `cost`，改名的 `B`）：

```
include "calculus.ag"
include "boolean.ag"
attribute cost = 8 split
start M
M -> F "derivative" weight 1 { ... }
M -> E "boolean" weight 1 { ... }
prompt "{M.text}"
answer M.answer_value
```

改造后，写成 set（各题型保留自己的措辞和 context）：

```
import "calculus.ag" as calc
import "boolean.ag" as bool

set mixed {
  6 of any(calc.derivative(cost = 7), bool.main(cost = 10))
}
```

改造后，写成仍然构造一道混合题的文法（引入方想自己写措辞时）：

```
import "calculus.ag" as calc
import "boolean.ag" as bool

attribute cost = 8 copy
synth text on M
synth answer_value on M
start M

M -> calc.F(cost = cost) "derivative" weight 1 {
  text = "Differentiate [`f(x) = " ++ $1.latex ++ "`]."
  answer_value = differentiate($1.formula, "x")
  require not formula_is_zero(answer_value)
}

M -> bool.E(cost = cost + 2) "boolean" weight 1 {
  require bool_top($1.f) != "not"
  text = "Evaluate [`" ++ bool_latex($1.f) ++ "`] when " ++ bool.given ++ "."
  answer_value = bool_evaluate($1.f, bool.names, bool.mask)
}

prompt "{M.text}"
answer M.answer_value
```

注意 `cost + 2`：两套标尺之间的汇率写在它该在的地方，引入方。`boolean.ag` 不再需要 `B`；`boolean_equiv.ag` 不再需要 `law_phrasing`。

`logic_forms.ag` 同样改法：`import "boolean.ag" as bool`、`import "boolean_equiv.ag" as laws`、`K -> laws.L(cost = cost) "tautology"`，等式里用 `bool.names`、`bool.mask`。

## 6. 跨模块的静态语义

检查器今天在生成前给每个表达式定型。加上模块后：

- 每个名字在检查期解析为（模块，种类，名字）。解析不了的限定名在引入方的位置报错，并点出模块的文件。
- 每个模块独立检查一次，和今天一样。然后引入方对照模块的**接口**检查：非终结符名及其综合属性和类型、继承属性名、随机值和 let 的名字和类型、题型名。模块的规则从不在引入方的上下文里重新检查。
- 精确花完是按模块成立的：在 `calc.F` 内部用模块自己的预算规则；在边界上参数只是一次赋值。所以"持有预算却没有规则适用的节点是致命错误"这条保证不变，而且诊断信息现在能说出是哪个模块的规则集没有合适的规则、产生这个预算的参数是什么。
- 随机值和 let 对题目文件可达的每个模块每道题画一次，按依赖顺序（模块的引入先于它自己）。set 对每道题重新画。
- 生成期的重试（`require`）和现在一样局限于本次尝试；`calc.F` 深处一个失败的 `require` 重启整道题，和今天被 include 的文法里失败的 `require` 一样。

## 7. 实现提纲

按先后顺序，涉及的文件和改动规模：

1. **模块与参数**（基础步骤，改动最大）
   - `ag_ast.ml`：`Import_decl of string * string * position`；符号形式 `Module_symbol of string * string * (string * expr) list`（别名、非终结符、参数）；表达式形式 `Module_value of string * string` 表示 `calc.given`；题干里的 `{calc.given}`。
   - `ag_lexer.mll` / `ag_parser.mly`：`import`、`as`、带点的名字、带点符号后的参数列表（和生成器区分：生成器没有点）。
   - `ag_load.ml`：以解析后的路径为键的模块表；每个文件只加载一次；成环检测扩展到 import；结果是一个主 spec 加一组模块 spec。
   - `ag_check.ml`：模块接口记录；限定名解析；模块子节点的 `$n.attr` 类型取自该模块接口；参数检查。`spec` 增加 `imports : (string * module_id) list`。
   - `ag_engine.ml`：`expand_symbol` 遇到 `Module_symbol` 时在父环境里求参数（份额语义），然后用该模块的 spec、规则、优先级表和新的继承环境展开；按模块分开的题目级值；`consumption` 不变。
   - `agcheck.ml`：打印解析到的 import。
   - 测试：`ag_modules_test.ml`（解析、撞名不可能发生、参数、split 下的份额、跨边界的 consumption、成环拒绝、诊断）；改造 `derivative_or_boolean.ag` 和 `logic_forms.ag` 并保持它们的测试通过；撤销 `B` 和 `law_phrasing` 的改名。

2. **有名字的题型**（小）
   - `ag_ast.ml`：`Question_decl of string * declaration list * position`。
   - `ag_check.ml`：`spec.questions : question list`，每个含今天单例声明的字段；文件级构成 `main`；`library` 的含义变为没有题型。
   - `ag_engine.ml` / `agrun.ml`：`--question NAME`。
   - `app.py`：列出 `文件:题型`。
   - 把 `calculus.ag` 拆成 `derivative` 和 `integral` 两个题型作为示例；`vector.ag`、`sequence.ag`、`library_*.ag` 可以跟进（它们的固定形式变成有名字的题型）。

3. **套题**（中）
   - `ag_ast.ml`：`Set_decl`，含部分、条目、参数分布、约束。
   - 新文件 `ag_set.ml`：种子派生、预算抽取（从 Python 移植 `draw_targets`）、`any` 选择、树去重与答案平衡约束（有限次重试）、排序、编号。
   - `ag_pgml.ml`：一个文档里的大题编号和小题字母。
   - `agrun.ml`：`--run NAME`、`--pg-dir`；列表末尾的均值。
   - 测试：`ag_sets_test.ml`；`ag_difficulty.py set` 改写为封装；文档。

4. **文档**：`AG_LANGUAGE_GUIDE.md` 新增一组章节，英文语言参考（import、question、set 各一节，带 EBNF），中文版，`QUESTION_TYPES.md` 改为列出 `文件:题型`。

规模估计：第 1 步和 include/pg_context/多空那一批相当（含测试约 40 个文件）；第 2、3 步更小。

## 8. 本次不做、记下以后做的

- 用户自定义纯函数（`function price(n) = ...`）：与模块无关；建议作为 set 之后的下一个语言项。
- 列表值类型及 `sum`/`map`。
- 第二个别名下的全新模块实例。
- 由文法声明的套题覆盖约束（`cover`）。
- 把题干导出为值，让一个产生式能复用另一道题的措辞。
- 语句、循环、可变变量、I/O：不计划做；它们会抹掉这门语言存在的理由——静态保证。

## 9. 待定的决定

1. 参数语法：`calc.F(cost = cost)`（建议）还是 `calc.F with cost = cost`。括号形式读起来像函数调用，是用过其他语言的用户所预期的。
2. 文件级题型叫 `main` 还是用文件名（`calculus`）。`main` 明确，且文件改名后不变。
3. set 能否从外部设定题型的 `width` 或 `context`。建议：不能，这两项属于题型本身。
4. `distinct trees` 比较整棵树还是擦掉叶子值后的树。建议：擦掉，这样"形状相同、数字不同"算重复，符合直觉。
