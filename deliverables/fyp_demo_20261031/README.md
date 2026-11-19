# Rhema FYP Demo · 2026-10-31

本材料是旧版 `fyp_demo_20261027` 的更新版，对应项目提交 `5545aa1`。保留旧预算与多项式示例，新增教师无代码配置、网页 WeBWorK 判分和新建数列题型的演示。

## 从这里开始

1. 阅读 [现场速查卡](DEMO_CHEATSHEET.md)，熟悉约 9 分钟的演示顺序。
2. 详细操作、讲解和追问见 [完整操作稿](FYP_DEMO_GUIDE.md)。
3. 网页使用 <http://127.0.0.1:5003/>。确认启动的是 `Project-RHM_latest 2`，右上角显示 **WeBWorK connected**。
4. 需要展示开发者工具时，使用 [VS Code + CLI 操作稿](VSCODE_CLI_DEMO.md) 的约 10–12 分钟综合路线；用 VS Code 打开 [专用工作区](Rhema-Demo.code-workspace)，无需改全局设置。

## 文件

| 材料 | 用途 |
| --- | --- |
| `demo_budget.rhm` | 递归算术规则、预算 4 / 10、inherited / synthesized attributes |
| `demo_sequence_gap.rhm` | 新题型：给定数列两项，求公差；无需新 OCaml 数学函数 |
| `demo_polynomial.rhm` | include 数学库，同一多项式的两个答案空及命名题型 |
| `demo_assignment.rhm` | 可选 CLI 整份作业，不是网页的作业编辑功能 |
| `verify_demo.py` | 只复核本套 demo，生成备用输出与验证记录 |
| `VSCODE_CLI_DEMO.md` | 扩展使用、集成终端命令、每阶段输入输出及真实样本 |
| `Rhema-Demo.code-workspace` | 指向当前项目构建结果的独立 VS Code demo 设置 |
| `verify_cli_demo.py` | 复核扩展等价调用、CLI 参数、树、重放与 set |
| `output/cli/` | 新增 CLI 实际记录和输出；原 output 材料保留 |
| `output/verification.json` | 本次实际生成、重放、WeBWorK 判分记录 |
| `output/*.pg` | 当前版本生成的 PGML 备用材料 |
| `output/*_trees.html` | 可直接用浏览器打开的生成树备用材料 |
| `output/*.txt` | 对应题面与答案，供讲解者核对 |
| `output/teacher_sequence_request.json` | 无代码数列例题的确切参数 |
| `output/teacher_sequence_generated.rhm` | 该表单生成的真实 Rhema specification |
| `screenshots/` | 当前网页的真实操作截图，不是设计预览图 |

## 重新核验

在项目根目录运行：

```sh
.venv/bin/python deliverables/fyp_demo_20261031/verify_demo.py
```

需要已构建的引擎、5003 上的本项目网页及 Docker WeBWorK renderer。可用 `--app-url` 指向其他本项目端口；离线时用 `--offline`，报告会明确写明未执行判分。

脚本只写本材料的 `output/` 和临时目录，不修改应用源码、标准库、个人配置或已保存的 preset。网页操作本身会正常保存生成记录。没有推送到 GitHub。
