# VS Code 扩展与 Rhema CLI：答辩操作稿及完整编译流程

适用：`main` / `5545aa1`，VS Code 扩展 `rhema.rhema-language` 0.1.1。

这里按“编译与生成流程”说明；如果说的是题目“变异”，见第 6 节的 seed / variant 对照。

## 1. 为什么值得加入 demo

网页展示教师端，VS Code 展示 specification 作者的开发端，CLI 展示完整控制能力：

```text
教师：Configure / Web ──────────┐
开发者：VS Code 扩展 ───────────┼─→ 同一 Rhema CLI / engine → PGML / .pg
脚本和批处理：集成终端里的 CLI ──┘
```

不是三套数学生成器。扩展没有另外实现 parser、属性计算或答案推导，而是调用 `rhema check/list/run` 及默认编译入口，并把结果放回编辑器。

VS Code 的集成终端只是终端；运行 `rhema` 的是 OCaml 构建产物，不是 `code` 命令本身。`code` 用来打开编辑器/工作区或管理扩展。

## 2. 已准备好的工作区

用 VS Code 打开同目录的 **Rhema-Demo.code-workspace**。也可自己运行：

```sh
code "/Users/ray/Desktop/Project-RHM_latest 2/deliverables/fyp_demo_20261031/Rhema-Demo.code-workspace"
```

此文件打开当前项目根目录，并仅为这个工作区指定：

```json
{
  "rhema.path": "generator/_build/install/default/bin/rhema",
  "rhema.includePaths": ["generator/stdlib"],
  "rhema.check.trigger": "onType"
}
```

不会修改用户全局设置。当前机器已安装 0.1.1，已检查安装版本的 extension.js 与仓库版本相同；但本次没有控制 VS Code 窗口的权限，所以**下文 GUI 操作尚未由代理实际点击验证**。CLI 命令与扩展调用方式已实际执行核验。

如果 VS Code 显示 Workspace Trust，需要你确认这是自己项目的可信目录；本次没有自动更改信任或安全设置。不受信任的工作区不会采用这里的可执行文件路径设置。

终端 PATH 当前没有 `rhema`，所以使用明确的构建路径；无需因此重新安装或更新系统配置。

## 3. VS Code 扩展：约 90 秒

打开：

```text
deliverables/fyp_demo_20261031/demo_budget.rhm
```

### 3.1 高亮与错误定位

1. 展示 attribute、productions、`$1.value`、prompt placeholders 的语法高亮与折叠。
2. 可在这份演示文件的某个 `value = $1.value + $3.value` 中，将一个 `value` 暂改成 `valeu`。
3. 停止输入约 400 ms，扩展运行 checker，并在 Problems 中显示错误与波浪线。
4. Undo 恢复，等诊断消失；不要保留故意破坏的源码。

扩展的 onType 检查不是运行生成器出题。未保存文本会写入临时文件供 `rhema check` 检查，诊断再映射回原文件。这里只展示“语言前端反馈”。

没有原生 LSP 服务器的完整智能补全承诺；当前支持高亮、snippets、诊断和命令集成。

### 3.2 Rhema: Check File

在 Command Palette 执行 **Rhema: Check File**，Problems 面板可见当前文件问题。无错误时没有题目输出，也不会生成 `.pg`。

### 3.3 Rhema: Run Question

点击编辑器的 Run Question 或 Command Palette 的同名命令。文件只有 main 时自动选择；有多个 question 或 set 时先弹 Quick Pick。

已保存文件的等价命令，从文法所在目录执行：

```sh
"/Users/ray/Desktop/Project-RHM_latest 2/generator/_build/install/default/bin/rhema" \
  run --question main \
  -I "/Users/ray/Desktop/Project-RHM_latest 2/generator/stdlib" \
  demo_budget.rhm
```

扩展打开的是 **Output → Rhema**，不是自动往集成终端键入命令。它会显示命令、题目与答案。本文件默认 cost 4、count 5、没有 student；本次实际结果：

```text
1. Evaluate 8 + 3 + (2 - 7).             answer: 6
2. Evaluate 2 + (3 - 7 + 4).             answer: 2
3. Evaluate (9 + 3) * 2.                 answer: 24
4. Evaluate 4 + 4 + 4 + (8 + 6).         answer: 26
5. Evaluate 3 + 5 + 5 - 9.               answer: 4
```

本段为方便阅读去掉 PGML 数学分隔符；原始 stdout 保存在 output/cli/extension_default.txt。

### 3.4 Rhema: Compile to PG

执行 **Rhema: Compile to PG**，默认在文法旁写出 `demo_budget.pg`，并提供 Open。

**注意：CLI 没有 `rhema compile FILE` 这个子命令。** 扩展的 Compile 名称是 UI 名称，实际调用：

```sh
rhema --question main -I /path/to/stdlib demo_budget.rhm
```

编译成功时引擎可不打印 stdout；扩展自己追加 `Wrote .../demo_budget.pg`。该文件包含默认五题，与上面 Run 使用相同 identity 时一致。

如果选中 set，文件按 set 名命名，如 `defense.pg`，而不是固定取源文件名。扩展本身支持执行 set，这是与当前网页普通生成入口的重要区别。

扩展当前按钮流程不询问学生、数量、budget override，也不自动导出树；需要这些控制时进入集成终端。不应宣称扩展按钮已经暴露所有 CLI 参数。

## 4. 集成终端：可直接执行的完整流程

在 VS Code 的 **Terminal → New Terminal** 中执行。以下均从项目根目录开始，不依赖 PATH 中的 rhema。

### 4.1 环境与输入文件

```sh
cd "/Users/ray/Desktop/Project-RHM_latest 2"
RHEMA="$PWD/generator/_build/install/default/bin/rhema"
DEMO="$PWD/deliverables/fyp_demo_20261031"
```

如引擎未构建，先在 generator 目录 `dune build` 后回到根目录；答辩前完成，不必现场等整套工具链构建。

输入是现有 `demo_budget.rhm`，它包含 4 条规则：加法成本 1、减法成本 2、乘法成本 3、cost=0 的数字叶子。文件默认 cost=4，这次用命令覆盖到 10，无需改文件。

### 4.2 Check：源代码是否合法

```sh
"$RHEMA" check "$DEMO/demo_budget.rhm"
```

实际输出的关键部分：

```text
.../demo_budget.rhm: OK (4 rules; questions: main; sets: none)
```

输入：`.rhm` 文本。内部：lex/parse/load/check。对外输出：检查结果与 exit code 0。**不是检查后自动生成题目，也不打印全部 token、源文件 AST 或 checked spec。**

### 4.3 List：文件提供什么

```sh
"$RHEMA" list "$DEMO/demo_budget.rhm"
```

实际输出：

```text
questions:
  main           start E, context Numeric
budgets: cost = 4
```

这证明入口、可选题型和默认预算，不是完整 IR dump。

### 4.4 Run：生成并显示具体题目与标准答案

```sh
"$RHEMA" run "$DEMO/demo_budget.rhm" \
  --question main --count 1 \
  --assignment demo_budget.rhm:main --student FYP2026 \
  --set cost=10
```

实际 stdout：

```text
1. Evaluate [`3 + 9 + (4 - (8 + 6)) \cdot (9 - 8)`].
   answer: 2
```

输入：checked spec + 指定题型/数量/预算/identity。输出：一题的具体题面和答案。**Run 不默认写 `.pg` 文件。**

### 4.5 Compile：输出 PG、属性记录和生成树

output/cli 已随材料提供；在干净环境可先 `mkdir -p "$DEMO/output/cli"`。

```sh
"$RHEMA" "$DEMO/demo_budget.rhm" \
  --question main --count 1 \
  --assignment demo_budget.rhm:main --student FYP2026 \
  --set cost=10 \
  -o "$DEMO/output/cli/cost10.pg" \
  --ast-out "$DEMO/output/cli/cost10_ast.txt" \
  --visualization-out "$DEMO/output/cli/cost10_trees.html"
```

成功返回 0，通常没有额外 stdout。最终三个文件：

| 文件 | 内容 |
| --- | --- |
| `cost10.pg` | 完整 WeBWorK problem，题干和标准答案 evaluator |
| `cost10_ast.txt` | 本次生成的 production/attribute derivation 文本 |
| `cost10_trees.html` | 同一 derivation 的交互式图，可用浏览器打开 |

**`--ast-out` 不是 `.rhm` 源文件的 parser AST，也不是 Menhir DCST。** 它的名称容易误导，应称“generated derivation/attribute record”。

`--visualization-out` 当前需要从工作目录附近找到 static/vendor/d3.v7.min.js，因此这里固定从项目根目录运行，而不是声称从任意目录一定能输出 HTML。

最终 PG 的实际内容：

```perl
DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");

BEGIN_PGML
Evaluate [`3 + 9 + (4 - (8 + 6)) \cdot (9 - 8)`].[_____]{2}
END_PGML
ENDDOCUMENT();
```

## 5. 同一个例子内部究竟经过哪些阶段

下面的 token / source AST / spec / Question IR 是**依据代码与真实例题整理的简化结构示意**，不是声称 CLI 已有逐阶段 dump 命令。真实可读取的输出是前面的 listing、PG、属性文本和 HTML。

| 阶段 | 输入 | 输出 | 是否普通 CLI 直接打印 |
| --- | --- | --- | --- |
| 1. Lexer | `.rhm` 文本 | Rhema tokens | 否 |
| 2. Parser | token 流 | `Rhema_ast.file` 声明/规则 AST | 否 |
| 3. Loader | AST 与依赖路径 | 展开 include、加载 import 的声明与模块 | 否；失败会报告路径 |
| 4. Checker | 解析和加载后的结构 | `Rhema_check.spec` | 否；check 输出 OK/错误，list 输出摘要 |
| 5. Driver | spec + main + override + assignment/student | 选定题型、cost=10、确定的 seed | 通常不打印 seed |
| 6. Engine 向下展开 | 起点 E、inherited cost=10 | 选规则、扣成本、拆预算、生成孩子 | 在生成后树记录中可看 |
| 7. Engine 向上综合 | 孩子的 typed values / latex | 根 value=2、最终 latex、满足 require 的树 | run/属性记录可看结果 |
| 8. Question IR | 根、题级值、模板、答案声明 | `Rhema_engine.question` | run 是面向人的投影，不是完整 IR dump |
| 9. PG Backend | Question IR | 数学答案 lowering、context/macros、PGML blanks、`.pg` | 编译写文件 |
| 10. Visualization | 同一组生成后的 questions | 属性文本与 HTML | 仅给相应参数时写文件 |
| 11. WeBWorK | `.pg`，随后可带学生输入 | 排版的题目；提交后评分 | 不是普通 Rhema CLI 的一部分 |

### 5.1 Lexer / Parser

源片段：

```rhm
E -> E + E when cost >= 1 weight 3 {
  cost = -1
  value = $1.value + $3.value
  latex = infix($1, "+", $3)
}
```

Lexer 产生的 token 开头为：

```text
IDENT("E") ARROW IDENT("E") PLUS IDENT("E")
WHEN IDENT("cost") GE INT(1) WEIGHT INT(3) LBRACE ... RBRACE
```

Parser 将它构造成 Rule_decl，大意如下，省略 position 和 At 位置包装：

```text
lhs       = "E"
rhs       = [Symbol "E"; Symbol "+"; Symbol "E"]
guard     = cost >= 1
weight    = 3
equations = [cost 的增量 -1;
             value = child1.value + child3.value;
             latex = infix(child1, "+", child3)]
```

这是“文法源代码的 AST”，里面的 E 仍是规则符号，**还没有选中 3、9 等具体随机数**。

### 5.2 Checker 输出的 checked spec

本例不含 include/import，Loader 不需要额外读取模块。Checker 整理并检查：

```text
inherited   : cost, initial 4, split
synthesized : value on E, latex on E
start       : E
rules       : 4 条
precedence  : + / - 在一级，* 在二级
question    : main
context     : Numeric
prompt      : Text("Evaluate [`"), Hole(E,latex), Text("`].")
answer      : E.value
```

然后 driver 才为这次命令应用 `--set cost=10`。check 默认预算仍为 4，不意味着 CLI 忽略了 override。

### 5.3 Seed / variant

输入：

```text
assignment = demo_budget.rhm:main
student    = FYP2026
combined   = demo_budget.rhm:main/FYP2026
```

当前实现的摘要和种子：

```text
Digest hex = 727e5037a05fff12fecef00f15d63c67
取前 8 位  = 727e5037
整数 seed  = 1920880695
```

种子决定可重复的随机选择顺序，不代表每题唯一，也不是先生成一份题后再随机“改几个字”。

### 5.4 向下的预算与向上的答案

本次实际树的根：

```text
E(cost=10) 选择 E -> E + E，支付 1
  剩余 9，split 为 1 + 8
  ├─ E(cost=1) → 3 + 9                       value = 12
  └─ E(cost=8) → (4 - (8 + 6)) * (9 - 8)    value = -10

根 value = 12 + (-10) = 2
```

这里非终结符 E 出现很多次，每个节点有自己的 inherited 和 synthesized。AST 中同一条 production 可以在树上应用多次。

打开 `cost10_ast.txt` 可核对真实记录，节选：

```text
production: E -> E + E [line 12]
inherited:
  cost = 10
synthesized:
  value = 2
  latex = 3 + 9 + (4 - (8 + 6)) \cdot (9 - 8)
```

### 5.5 Question IR → PGML

生成后内部对象的大意：

```text
Rhema_engine.question {
  prompt  = "Evaluate [`...`]."
  answers = [Num(2)]
  pieces  = [题干文本; 数值答案框]
  context = "Numeric"
  globals = []
  tree    = 已具体生成并计算属性的树
}
```

Backend 把 `Num(2)` lowering 为 PG 数值答案 `2`，选择 Numeric context 与基础 macros，生成 `[_____]{2}`。复杂类型会选择 Formula、Complex、Set、Vector、Matrix 等不同目标表达。

最终是**可被 WeBWorK 执行的 problem file**，不是 OCaml 可执行文件，也不是截图。

## 6. 同一输入与题目变体

保持上述命令所有参数相同重新运行，输出内容相同；本次已核对重复 PG 完全一致。

只把 `--student FYP2026` 改成 `--student FYP2027`，本次实际变为：

```text
Evaluate [`(7 - 6) \cdot (4 - 5 \cdot 3)`].
answer: -11
```

这就是不同学生的 variant。不能保证任意两个学号的任何题都不同；相同引擎、源码、参数与 identity 才是可复现边界。

扩展默认 Run 没有指定 student，CLI 默认 assignment 是 `demo_budget:main`，而本段显式 `demo_budget.rhm:main` 是为了与网页 source 路径对齐。因此扩展默认五题与个人化例题不同，**不是出错**。

## 7. 加分项：在 VS Code 展示整份作业

打开 `demo_assignment.rhm` 后运行扩展 Run/Compile，它会选择 defense set；多个 set 时弹选单。扩展支持这一点，网页普通 Generate 还没有完整 set 入口。

终端中如需对齐固定样本，执行：

```sh
"$RHEMA" run "$DEMO/demo_assignment.rhm" \
  -I "$PWD/generator/stdlib" --run defense \
  --assignment demo_assignment.rhm:main --student FYP2026
```

输出 3 个 part、5 道题、6 个答案空：Sequences、Logic、Linear algebra。标准答案依次为 `-31`、`-95`、`1`、`1`、`0`、`{-4,0}`。输出中的 `true/false` 在 PGML Numeric 中转换成 1/0。

讲明 import、part、题目数量、预算分布与 distinct 即可；不要在这一步解释所有数学题的解法。

## 8. 如何接进现有网页 demo

建议总计 10–12 分钟，不要把所有功能重复一遍：

| 时间 | 演示 |
| --- | --- |
| 0:00–0:30 | 项目目标、两个阶段、三种入口共享引擎 |
| 0:30–2:30 | Web Configure 数列 + 正误答案判分 |
| 2:30–4:00 | VS Code 高亮、错误定位、Run、Compile |
| 4:00–6:30 | 集成终端 check/list/run/compile + 一条预算/答案树路径 |
| 6:30–8:00 | 多项式 include、多答案，回网页展示部分得分 |
| 8:00–9:00 | 同 seed 重放、换 student 的变体 |
| 9:00–10:00 | set 作业；时间紧可跳过 |
| 10:00–10:30 | 总结成果与限制 |

原来的 9 分钟纯网页路线仍可用。展示 VS Code 后，可以省略网页里重复的新建源码和手动改预算步骤。

## 9. 验证范围与材料

在项目根目录重跑：

```sh
.venv/bin/python deliverables/fyp_demo_20261031/verify_cli_demo.py
```

它实际复现扩展使用的 check/list/run/default compile 命令，并验证命令行 overrides、生成树、同 seed 重放及 set；默认 compile 在临时目录模拟，避免覆盖演示源文件旁的结果。

- `output/cli/CLI_TRANSCRIPT.md`：每条真实命令、cwd、stdout 和退出码。
- `output/cli/verification.json`：版本、seed 与核验记录。
- `output/cli/cost10.pg` / `cost10_ast.txt` / `cost10_trees.html`：完整输出。
- `output/cli/extension_default.pg` / `extension_default.txt`：扩展默认五题的等价命令结果。

本次没有操作 VS Code 的按钮，没有声称已验证原生窗口里的诊断截图；只是代码核对和实际 CLI 执行。没有修改扩展或引擎实现，没有改全局设置，也没有推送 GitHub。
