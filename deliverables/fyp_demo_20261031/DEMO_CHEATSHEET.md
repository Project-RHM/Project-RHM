# FYP 现场速查卡

项目：`/Users/ray/Desktop/Project-RHM_latest 2`；网页：<http://127.0.0.1:5003/>。
本卡对应 `5545aa1`，Student ID 固定 `FYP2026`，界面用 English。

**新增推荐路线：网页 + VS Code + CLI，约 10–12 分钟。** 详见 [VSCODE_CLI_DEMO.md](VSCODE_CLI_DEMO.md)。打开 [Rhema-Demo.code-workspace](Rhema-Demo.code-workspace)，先展示扩展 Check/Run/Compile，再用集成终端展示 seed、预算和树。下面仍保留原 9 分钟纯网页路线，二选一，不要全程重复。

| 时间 | 操作 | 需要说明的成果 |
| --- | --- | --- |
| 0:00–0:30 | 展示题库与界面 | Stage 1 扩题型；Stage 2 用 Rhema specification 描述生成规则 |
| 0:30–2:00 | Sequences → Configure；设置下面的数值，Generate | 不写代码也能配置已有题型；表单仍使用同一 Rhema 引擎 |
| 2:00–2:40 | 在题目输入 0，再输入 11，分别 Check answers | 真实 WeBWorK 渲染、判错与判对，不只是显示 PGML |
| 2:40–4:30 | My presets → demo_budget.rhm → Rhema source；count 2；cost 4 改 10，Save、Generate；打开树 | 规则价格和预算控制结构，预算向下、答案向上 |
| 4:30–6:00 | New Grammar 新建数列公差题；Check、Save、Generate | 复用已有计算能力，只加 `.rhm` 即可描述新变体 |
| 6:00–7:40 | demo_polynomial.rhm → count 1、main；查看两空、PGML；提交一对一错，再全对 | include 库、共享数学对象、分开评分、多答案 |
| 7:40–8:40 | 相同 Student ID 重生成，再改 FYP2027 | 可复现和个性化；不承诺不同学号绝不重复 |
| 8:40–9:00 | 总结并说明边界 | 全新数学语义仍需底层库；cost 尚未以教学数据校准 |

## 无代码例题的参数

选择 **Sequences**，不是 **Sequences: two-part questions**。

| 设置 | 值 |
| --- | --- |
| Number of questions | 1 |
| First term Minimum / Maximum | 2 / 2 |
| Common difference Minimum / Maximum | 3 / 3 |
| Term index Minimum / Maximum | 4 / 4 |
| Advanced settings → Complexity budget | 1 |
| 其他设置 | 保留默认 |

题目：`a₁=2, d=3, 求 a₄`；答案 **11**。这里故意固定参数，count 不要设成 6。

## 源码模式的答案

仅适用于原文件名、当前源码、`FYP2026` 和本次版本；使用 **Rhema source**，不要混用 Configure 结果。

| 文件 / 设置 | 正确答案 |
| --- | --- |
| demo_budget.rhm，cost 4，count 2 | 27；84 |
| 同文件，cost 10，count 2 | 2；1 |
| demo_sequence_gap.rhm，count 1 | 1（`a₃=3, a₆=6`） |
| demo_polynomial.rhm，main，count 1 | `x^3+7*x^2-24*x-180`；`-72` |
| 同文件，value，count 1 | 30 |

多项式先输入正确公式和 `0`，显示 **50%**；第二空改 `-72` 后显示 **100%**。

## 不要忘记

- 修改源码后先 Save，成功后再 Generate。
- 已保存 demo 在 **My presets**；新建题使用未占用的名称，名称变化会影响 seeded 结果，不要照抄旧答案。
- 为重复演练新建流程，可以先用新名字建立，再按实际题面计算答案；正式演示的固定文件不要随手覆盖。
- 完整新建流程可用数列公差题；时间紧时选已经保存的文件演示。
- 树是 Applied Production Tree / Attributed Derivation Tree，不是 Classic 的 DCST。
- Local preview 只用于排版兜底，不能判分。Docker renderer 离线时改展示截图和备用 `.pg` / 树，并明确说明。
- 纯网页路线中 set defense 是额外 CLI 项目；综合路线可以在 VS Code 扩展或集成终端展示 set。
