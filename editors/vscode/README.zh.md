# Visual Studio Code 的 Rhema 扩展

本扩展为 [Rhema](https://project-rhm.github.io/) 提供编辑支持。Rhema 是 RHM
用来描述“一类数学题”的语言。以 `.rhm` 结尾的文件会自动按 Rhema 打开。

[English](README.md)

## 功能

- **边写边查错。** 停止输入片刻后，以及打开或保存文件时，扩展会运行
  `rhema check`，并把报告的问题列在“问题”（Problems）面板中。每条问题的波浪线
  标在它所指的名字下面。被导入的模块自身有问题时，问题显示在那个模块的文件上。
- **运行与编译。** **Rhema: Run Question**（编辑器上方的 ▷ 按钮）在 Rhema
  输出面板中打印生成的题目和答案；**Rhema: Compile to PG** 在源文件旁边写出
  WeBWorK 文件，文件名取自源文件名或习题集名。文件中声明了多个题目或习题集时，
  会先询问用哪一个。这两个命令也出现在编辑器和资源管理器的右键菜单中。
- **语法高亮**，规则与编译器一致：各类声明、产生式及其属性方程、`$1.value`
  这样的子节点引用、内建函数调用，以及 `calc.F`、`E.latex` 这样带限定前缀的
  名字。题面中的填充位 `{first}`、`{E.latex}`、`{answer nth}`，表示字面花括号的
  `{{` 与 `}}`，以及 PGML 数学公式 ``[`...`]`` 都单独高亮；其他字符串里的花括号
  是 LaTeX，不做处理。习题集用词（`part`、`of`、`any`、`spread` 等）只在 `set`
  块内部作为关键字高亮，这与编译器的读法一致。Markdown 中标注为 `rhema` 或
  `rhm` 的围栏代码块也会高亮。
- **折叠**：规则体、`question` 和 `set` 块、跨多行的题面、连续的注释行，以及
  `# region` 与 `# endregion` 之间的内容。
- **编辑**：`#` 注释（可用“切换行注释”命令）、括号配对、自动补全 `{`、`(`
  和 `"`，以及在 `{` 之后自动缩进。
- **代码片段**：`rule`、`rulew`、`attribute`、`synth`、`random`、`let`、
  `precedence`、`import`、`prompt`、`{answer`、``[` ``、`question`、`set` 和
  `part`。

## 设置

| 设置项 | 默认值 | 含义 |
|---|---|---|
| `rhema.path` | `rhema` | `rhema` 命令。只写命令名时在 `PATH` 中查找；含路径分隔符时按相对于工作区文件夹的路径解析。 |
| `rhema.includePaths` | `[]` | 额外的导入与包含文件搜索目录，以 `-I` 传给 `rhema`。 |
| `rhema.check.trigger` | `onType` | 何时检查：`onType`（输入时）、`onSave`（保存时）或 `off`（关闭）。 |

语法高亮、折叠和代码片段不需要 `rhema` 命令；查错和两个命令需要。安装方法是
`opam install rhema`（见[安装说明](https://project-rhm.github.io/#install)）。
在本仓库的克隆中，可以直接使用开发构建：

```json
{ "rhema.path": "generator/_build/install/default/bin/rhema" }
```

在不受信任的工作区中，`rhema.path` 和 `rhema.includePaths` 只从用户设置读取，
因此工作区无法指定要运行的命令。

## 检查是怎样进行的

已保存的文件在原位置检查，因此其中的导入与在命令行中一样解析。未保存的内容
会先写入一个临时文件，并把原文件所在目录作为首个导入搜索目录（`-I`）。每次
检查结束后，临时文件即被删除。

## 安装

在 VS Code 的扩展视图中搜索 **Rhema**，或者运行：

```bash
code --install-extension rhema.rhema-language
```

Cursor、VSCodium 等基于 VS Code 的编辑器，可以用同样的方式从
[Open VSX](https://open-vsx.org/extension/rhema/rhema-language) 安装。

如果要从源码打包，请在仓库的 `editors/vscode/` 目录中运行：

```bash
npm run package
```

```bash
code --install-extension rhema-language-0.1.0.vsix
```

第一次运行 `npm run package` 时，`npx` 会下载打包工具 `vsce`。发布流程见
[PUBLISHING.zh.md](PUBLISHING.zh.md)。

## 开发

扩展用带类型注解的纯 JavaScript 编写，没有构建步骤。入口是
`src/extension.js`；`src/messages.js` 解析 `rhema` 的输出，`src/folding.js`
计算折叠范围，这两个文件都不依赖 VS Code。语法定义在
`syntaxes/rhema.tmLanguage.json`。

```bash
npm ci
```

```bash
npm run check
```

```bash
npm test
```

`npm run check` 对源码做类型检查。`npm test` 运行单元测试：语法测试从
`generator/rhema/lib/rhema_lexer.mll` 读取关键字表，从
`generator/rhema/lib/rhema_parser.mly` 读取习题集用词，并对仓库中所有 `.rhm`
文件做一次词法着色检查。因此，编译器新增关键字而语法定义没有跟上时，测试会
失败。CI 中的 `editor` 任务运行这两项。

集成测试会启动装有本扩展的 VS Code，打开 `integration/workspace` 中的文件，
用真实的 `rhema` 检验查错、运行与编译：

```bash
npm run test:integration
```

除非用 `RHEMA` 指定其他命令，集成测试使用 `rhema` 的开发构建；除非用
`VSCODE_PATH` 指定已安装的 VS Code（macOS 上为
`/Applications/Visual Studio Code.app/Contents/MacOS/Code`），它会把 VS Code
下载到 `.vscode-test/` 中。
