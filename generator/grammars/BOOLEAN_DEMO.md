# Boolean Demo: Source and Configure

正式演示文件：`boolean_demo_flexible.rhm`。它是独立的新题型，不会覆盖原来的 `bool.rhm`、学习示例或用户预设。

## 在网页中使用

1. 启动项目的 `app.py`，打开网页，选择 **Question library → Boolean Demo Flexible**。
2. 在 **Configure** 设置题数；建议现场只生成 3 道。Student ID 可填写 `DEMO`。
3. 展开 **Advanced settings**，修改 **Complexity budget**。
4. 点击 **Generate questions**。在 WeBWorK 已连接时，可填写 0/1 并点击 **Check answers**。

## 可以修改的内容

| Configure 项目 | 含义 | 演示用法 |
|---|---|---|
| Complexity budget | 运算预算；所有默认规则的单次消耗都是 1，因此等于运算符总数，不等于嵌套深度或考试难度 | 依次改成 1、3、6；支持范围为 1–10 |
| Available variables | 允许使用的变量池，不是要求每道题必须用完所有变量 | 在 p,q / p,q,r / p,q,r,s 之间切换 |
| Maximum negations | 整道题最多出现几个 NOT | 设为 0 可排除 NOT，设为 2 可允许最多两个 |
| Question quality | 是否排除恒真、恒假子表达式以及部分冗余运算 | 正式演示保留 Exclude constant answers |
| P/Q/R/S value | 随机赋值或固定 true/false | 将 P 设为 True、Q 设为 False，确认题面同步显示 1、0 |
| Expression operators: Minimum / Maximum | 运算符数量上下限；不是字符数 | 默认规则下，预算 3 可设置最小值和最大值都为 3；也可以留空 |
| Question forms and rule settings | 启用规则、调整选择权重和每次预算消耗 | 可关闭 XOR，或增加 AND 的权重；不要关闭所有必要规则 |
| Answer box width / Additional instruction | 答案框宽度及附加说明 | 不影响正确答案的计算 |

变量覆盖要求为 `min(cost + 1, variables_mode)`。预算 1 的二元运算只能容纳两个变量；即便变量池是四个，也不会强求表达式同时使用四个。预算至少为 3 时，四变量池会要求表达式包含四个变量。

`quality_mode=1` 不再调用整体的 `bool_is_tidy`。它保留有针对性的检查：AND/OR 结果不能等价于单个操作数；各二元分支不得恒真或恒假；NOT 不连续重复；题目满足变量覆盖和否定数上限。它允许变量在不同分支再次出现，从而支持较长表达式。它不保证每个表达式都是最简式，也不保证不同题目的 Boolean function 永不相同。

## 建议的现场顺序

1. 预算 1、变量池 p,q：先展示可以手算的简单题，并验证答案。
2. 保留同一文件，改预算为 3、变量池 p,q,r：展示递归规则自动产生不同结构。
3. 改预算为 6、变量池 p,q,r,s：展示更多嵌套；无需修改 OCaml 或重写 production rules。
4. 将 Maximum negations 改为 0，再生成；展示题目不再出现 NOT。
5. 展开规则设置，关闭 XOR，在预算 2、三变量池下生成；展示运算选择也由配置控制。
6. 切到 Rhema source，展示 `attribute`、`random`、`synth`、`when`、`require`、`cost = -1` 和 `prompt "{Q.text}"` 的作用。

不要把高预算称为“更高数学难度”的保证：这里直接控制的是结构大小。两变量的 Boolean function 数量有限，长表达式仍可能等价于某个短表达式。

## Source 修改后继续 Configure

对于已有表单预设，Source 修改通过检查并 **Save** 后，系统以保存的当前源码为新基准重新生成配置表单，不再把旧表单覆盖回去。它会在 **Question library → My question types** 中出现；旧表单记录和修改前源码保存在 `.teacher/history/`，常规 `.rhm.bak` 备份仍保留。

Source 中的声明决定能配置什么。新增 `random`、整数 `attribute`、production rule 后，表单会重新识别这些设置；任意函数体不会自动变成可视化控件。Check 只证明语法和静态检查通过，不证明所有可能的配置都能满足数学约束。实际生成仍会检查 `when` 和 `require`。

## 编辑器补全

输入 `bool_` 会显示实际编译器登记的函数，继续输入 `bool_v` 可找到 `bool_var`。方向键选择，Enter 或 Tab 插入；Escape 关闭；Ctrl+Space 手动唤起。函数插入时会带上括号。注释和字符串中不会自动弹出候选。Reload、Check、Save 和 Student ID 输入不变。

## 哪些组合不能生成

“可配置”不是“任意互相矛盾的参数都可生成”。例如：

- 预算为 3，但运算符上限为 1。
- 禁用全部二元规则，却要求至少两个不同变量。
- 改成四变量池，只保留变量 p 的叶子规则。
- 同时提高规则消耗、降低预算，并要求很长的表达式。

这些情况应明确失败，不应静默修改预算、删掉约束或返回旧题。修改规则消耗后，预算不再等于运算符数；相应调整长度限制，或先留空。预算 1–10 是本示例默认根规则的范围，不是 Rhema 引擎对所有题型的统一上限。

## 本次验证范围

- Dune 回归包含 600 道独立检查：变量池 2–4、预算 1–10、每组 20 个随机种子；从显示的题面重新读取赋值和公式，独立计算答案、检查运算数量及变量覆盖。
- 网页 Configure 路由测试涵盖多个预算和变量池、固定赋值、否定上限、关闭 XOR/NOT、长度约束、同 seed 重放，以及拒绝不兼容参数。
- Source 保存的回归测试检查新源码生效、旧基准不被重新套用、备份保留、非法保存不破坏文件。

这些测试是具体范围的回归证据，不是所有 seed、所有规则组合必定成功的证明。
