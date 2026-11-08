# Rhema 语言规范验证材料

主文档位于项目根目录 `RHEMA_LANGUAGE_SPEC.zh.md`。此目录提供文档内全部 18 份完整 specification、实际生成的 PG/题面以及验证报告。

- `examples/`：每份可单独 check/run 的 `.rhm`，assignment.rhm 依赖同目录 named_questions.rhm。
- `*_main.pg` 等：seed 1 的实际输出，不是任意学号下的固定答案。
- `*.txt`：对应题面和标准答案，学习/排查用。
- `verification.json`：关键字/builtin 覆盖、57 个场景、11 个实现行为探针和 19 份 WeBWorK 渲染记录。
- `verify_language_spec.py`：从主文档重新提取并测试完整代码块。
- `check_runtime_notes.py`：测试需要特别说明的运行行为；部分输入有意不合法，expected_success=false 表示正确地拒绝了它们。
- `check_live_rendering.py`：可选的本机 Docker renderer 测试，只渲染，不提交真实课程成绩。

在项目根目录按此顺序运行：

```sh
.venv/bin/python deliverables/rhema_language_spec_20261031/verify_language_spec.py
.venv/bin/python deliverables/rhema_language_spec_20261031/check_runtime_notes.py
.venv/bin/python deliverables/rhema_language_spec_20261031/check_live_rendering.py
```

需要已构建的 Rhema；最后一项还需本机 WeBWorK renderer 在线。只写本材料目录，不修改应用源码、标准库或个人配置。不需要将 examples 复制进用户题库即可用 CLI 测试；要在网页使用，可通过 New Grammar 建立相应文件。

验证脚本基于本说明的当前文件布局，移动整个项目没有问题；单独移动脚本时需保留其相对项目根目录的关系。
