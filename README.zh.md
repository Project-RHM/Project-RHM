# RHM — Reversible Hierarchical Mathesis

**Math Question Generation（数学题目生成）** · *Regula · Hierarchia · Mathesis*

[![CI](https://github.com/Project-RHM/Project-RHM/actions/workflows/ci.yml/badge.svg)](https://github.com/Project-RHM/Project-RHM/actions/workflows/ci.yml)

[文档站](https://project-rhm.github.io/) ·
[opam 包](https://opam.ocaml.org/packages/rhema/) ·
[VS Code 扩展](https://marketplace.visualstudio.com/items?itemName=rhema.rhema-language) ·
[更新日志](CHANGELOG.md) ·
[English](README.md)

*英文原版见 `README.md`，以英文版为准。*

RHM 为 [WeBWorK](https://openwebwork.org/) 生成数学题目，由三部分组成：

- **Rhema**：一门语言，用属性文法描述一类题目：题目可以有哪些形状、有多难、
  答案是什么、读起来是什么样。
- **`rhema`**：编译器，附带一个从四则运算到线性代数的文法库。
- 一个 **Flask Web 应用**：用来生成、编辑和浏览题目集。

题目和答案出自同一棵树，因此两者不可能不一致。难度是文法要恰好花完的预算。
一个文件还可以描述一整份作业，无论编译多少次，得到的都是同一份试卷。

## 第一道题

把下面的内容保存为 `first.rhm`：

```text
# The smallest useful question: the sum of two numbers.

synth value on E
synth latex on E

start E

E -> integer_between(10, 99) "+" integer_between(10, 99) {
  value = $1.value + $3.value
  latex = str($1.value) ++ " + " ++ str($3.value)
}

prompt "What is [`{E.latex}`]?"
answer E.value
```

```text
$ rhema run first.rhm --count 2
 1. What is [`82 + 40`]?
    answer: 122
 2. What is [`83 + 52`]?
    answer: 135
```

文法之间可以互相导入，所以一份作业可以直接使用文法库，不必复制其中的内容。
把下面的文件保存为 `quiz.rhm`（放在任何目录都可以），它出四道微积分题，其中
三道的平均花费为 6：

```text
import "calculus.rhm" as calc

set quiz {
  3 of calc.derivative(cost ~ 6 spread 2)
  1 of calc.integral(cost = 5)
}
```

```bash
rhema quiz.rhm --run quiz
```

这条命令写出 `quiz.pg`，可以直接用于 WeBWorK。

## 安装

编译器和文法库（需要 OCaml 4.14 或更新版本）：

```bash
opam install rhema
```

这样安装的是当前发布版 0.1.1。仓库中的代码比它新，新增内容见
[更新日志](CHANGELOG.md)的 Unreleased 一节。

使用 VS Code 时，从
[Marketplace](https://marketplace.visualstudio.com/items?itemName=rhema.rhema-language)
安装 **Rhema Language**。它会在输入时运行 `rhema check`，并提供语法高亮以及运行、
编译命令，详见 [`editors/vscode`](editors/vscode/README.zh.md)。

如需从源码工作（使用 Web 应用或最新的文法时必须这样做）：

```bash
git clone https://github.com/Project-RHM/Project-RHM.git
cd Project-RHM/generator
opam install dune menhir menhirCST pprint
dune build
```

构建出的命令位于 `generator/_build/install/default/bin/rhema`。

## `rhema` 命令

下面的命令在文法库所在的 `generator/stdlib` 目录中运行。`rhema` 按路径读取命令行
上给出的文件；下文所说的查找顺序只适用于被导入的文件。

```bash
rhema check calculus.rhm                  # file:line:col: error: ... or OK
rhema calculus.rhm -o calculus.pg         # compile to WeBWorK PG
rhema homework_set.rhm --run homework     # a whole assignment -> homework.pg
rhema run boolean.rhm --set cost=6        # questions and answers in the terminal
rhema run calculus.rhm --question integral  # one named question of the file
rhema list calculus.rhm                   # questions, budgets, sets, imports
rhema doc                                 # the builtin functions
```

一份作业对应一份试卷，每次生成的结果都相同；`--student ID` 为某位学生单独生成
一份试卷。被导入的文件依次在以下位置查找：导入它的文件所在目录、`-I` 指定的目录、
`RHEMA_PATH`，以及已安装的文法库（`share/rhema`）。

## 文法库

0.1.1 软件包安装 27 个文法文件。`generator/stdlib/` 中除这些之外，还有标 † 的六个
文法，它们要到下一个版本才会进入 opam，在此之前需要从源码使用。每个文法的题目、
价格和 WeBWorK 上下文见 [`QUESTION_TYPES.zh.md`](QUESTION_TYPES.zh.md)。

| 领域 | 文法 |
| --- | --- |
| 四则运算 | `arithmetic` |
| 代数 | `polynomial_expand`、`factoring`、`polynomial_forms`、`linear_equation`、`inequality`†、`library_linear`、`library_quadratic`、`library_polynomial` |
| 数列与级数 | `sequence`、`sequence_parts`、`series`† |
| 微积分 | `calculus`、`limits`†、`library_formula` |
| 逻辑 | `boolean`、`boolean_equiv`、`logic_forms` |
| 集合 | `set` |
| 向量 | `vector`、`vector_expr` |
| 复数 | `complex` |
| 线性代数 | `matrix_expr`、`determinant`、`matrix_inverse`、`linear_system`、`eigen`† |
| 计数与数论 | `counting`†、`number_theory`† |
| 组合 | `derivative_or_boolean`（一道题，来自两个被导入的文法）、`homework_set`（一整份作业） |
| 共享规则，本身不出题 | `polynomial_core`、`matrix_core` |

新题型是一个新的 `.rhm` 文件，不需要修改引擎。你自己的文件放在
`generator/grammars/` 中。

## 难度

难度是文法要花掉的预算。`boolean.rhm` 为每种联结词定价（合取 2、条件 4、
双条件 6，等等），`calculus.rhm` 为函数用到的求导法则定价，固定题型的文法则为
每种题型标一个价格。每个文法都恰好花完预算，所以 `--set cost=6` 和
`--set cost=14` 分别得到同一题型中较容易和较难的题目。

一份作业中的预算有三种写法：固定值（`cost = 6`）、平均使用一个列表
（`cost in {8, 10, 12}`）、保持一个平均值（`cost ~ 6 spread 2`）。
`tools/rhema_difficulty.py` 可以报告每个预算能买到什么，并给出难度分级建议。
详见 [`DIFFICULTY_BUDGET.zh.md`](DIFFICULTY_BUDGET.zh.md)。

## Web 应用

在源码目录中完成 `dune build` 后运行：

```bash
python3 -m pip install -r requirements.txt
python3 app.py
```

然后打开 <http://127.0.0.1:5001>。这个应用可以生成题目集、保存历史记录，并提供
文法编辑器，保存前会先用 `rhema check` 检查文件。每个结果上方的
`AST / DCST Trees` 开关用来查看题目背后的树；对 Rhema 文法，显示的是实际应用的
产生式树和带属性的推导树。配置 DeepSeek API 密钥后，可以选用 Add Context 功能，
由大语言模型为四则运算题写一段情境。

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `generator/rhema/` | 编译器：`lib`、`bin`、`test` |
| `generator/stdlib/` | 文法库，随软件包一起安装 |
| `generator/grammars/` | 你自己的文法 |
| `generator/*.ml`、`*.mly` | 经典 PG 生成器，见下文 |
| `docs/`、`mkdocs.yml` | 文档站 |
| `editors/vscode/` | VS Code 扩展 |
| `tools/` | 难度、统计和组卷工具，以及测试脚本 |
| `app.py`、`templates/`、`static/`、`llm_context/` | Web 应用 |

## 测试

```bash
cd generator
dune build
dune runtest --force
cd ..
python3 tools/test_grammar_creation.py
tools/check_doc_examples.sh generator/_build/install/default/bin/rhema
```

有几组测试会读回生成的题目，用独立于文法的方式重新计算答案。CI 会运行这些测试，
并在 Linux 和 macOS 上用 OCaml 4.14 与 5 从干净的导出目录构建软件包。

## 经典流水线

RHM 最初的做法是让解析器反向运行，那个生成器至今仍在 `generator/` 中。它解析 PG
源码，再通过 Menhir 的反解析（unparsing）接口重新打印：

```text
PG source -> Lexer -> Parser -> AST -> Describe -> DCST -> Settle -> CST -> PG source
```

**抽象语法树（AST）** 表示题目的含义和结构，不含标点和排版。`1 + 2 * 3` 会变成
`ME_Add`、`T_Mul`、`F_Int` 这样的节点，运算符优先级在树中是显式的。

**析取具体语法树（DCST）** 是 Menhir 反解析时使用的中间表示，可以同时容纳多种
候选的具体形式。`describe.ml` 通过选择文法产生式把 AST 转换为 DCST，
`Parser.Settle.main` 从中选出一种有效形式，得到具体语法树（CST），最后由
`print_pprint.ml` 把 CST 渲染为 PG。

要查看某个 PG 文件的这些树，在 `generator/` 中运行：

```bash
dune exec ./visualize.exe -- examples/sample.pg ast_dcst_visualization.html
```

结果是一个自包含的 HTML 页面，其中有每道题可交互的 AST 和 DCST、原始 PG，以及由
CST 重新打印的 PG。输入文件参数可以写 `-` 表示标准输入，输出路径可以省略。

这条流水线中的算术表达式来自一个小型属性文法引擎
`generator/attribute_grammar.ml`，默认文法是 `generator/arithmetic.ag`；设置
`ATTRIBUTE_GRAMMAR_FILE` 可以加载其他文法。它是 Rhema 的前身，使用自己的、更简单
的格式，详见
[`ATTRIBUTE_GRAMMAR_IMPROVEMENT.md`](ATTRIBUTE_GRAMMAR_IMPROVEMENT.md)（英文）。

## 文档

- [文档站](https://project-rhm.github.io/)（英文）：八章教程和语言参考
- [`RHEMA_LANGUAGE_GUIDE.md`](RHEMA_LANGUAGE_GUIDE.md)（英文）：语言和命令
- [`RHEMA_LANGUAGE_EXTENSIONS.zh.md`](RHEMA_LANGUAGE_EXTENSIONS.zh.md)：`include`、
  `import`、有名字的题型、套题、每题一个上下文和多个答案空
- [`RHEMA_MODULES_DESIGN.zh.md`](RHEMA_MODULES_DESIGN.zh.md)：模块层的设计
- [`QUESTION_TYPES.zh.md`](QUESTION_TYPES.zh.md)：文法库中的每个文法
- [`DIFFICULTY_BUDGET.zh.md`](DIFFICULTY_BUDGET.zh.md)：价格、预算和套题
- [`RELEASING.md`](RELEASING.md)（英文）：版本发布流程

## 名字的含义

- **Reversible（可逆）**：解析器把文本读成树。RHM 把这个方向倒过来，先构造树，
  再由树写出题目。
- **Hierarchical（层级）**：题目是由产生式构成的树。难度沿树向下传递，结果沿树
  向上计算，文法再组合成作业。
- **Mathesis**：取自莱布尼茨的 *mathesis universalis*（普遍数学），即一种通过
  计算来推理的普遍方法。

这三个字母同时也是 *Menhir* 去掉元音后倒读的结果，以及莱茵金属（Rheinmetall）的
股票代码。**Rhema**（希腊语 ῥῆμα，意为“所说的话”）的字母就藏在 RHM 之中，也说出了
文法所做的事：它把一道题说出来。

## 作者与许可证

Jingming Zhang、Jiaming Lei、Xiaobo Huang、Jiesen Long、Zhiyuan Li，
[北师香港浸会大学](https://www.bnbu.edu.cn/en/)（Beijing Normal-Hong Kong Baptist University）。
本项目以 [MIT 许可证](LICENSE)发布。
