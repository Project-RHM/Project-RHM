# Rhema for Visual Studio Code

Support for [Rhema](https://project-rhm.github.io/), the language in which
RHM describes families of mathematics questions. Files ending in `.rhm` open
as Rhema.

[中文说明](README.zh.md)

## What it does

- **Problems as you type.** The extension runs `rhema check` after a short
  pause in typing, and when a file is opened or saved, and lists what it
  reports in the Problems panel. Each problem underlines the name it is
  about. A problem in an imported module is shown on that module's file.
- **Run and Compile.** **Rhema: Run Question** (the ▷ button above the
  editor) prints generated questions and their answers in the Rhema output
  panel; **Rhema: Compile to PG** writes the WeBWorK file beside the source,
  named after the file or the set. When a file declares several questions
  or sets, you are asked which one. Both are also on the editor's and the
  Explorer's context menus.
- **Highlighting** that follows the compiler: declarations, productions and
  their equations, child references such as `$1.value`, builtin calls, and
  qualified names such as `calc.F` and `E.latex`. In prompts, the fill-ins
  `{first}`, `{E.latex}` and `{answer nth}`, the literal braces `{{` and
  `}}`, and PGML mathematics ``[`...`]``; braces in other strings are LaTeX
  and are left alone. The set words (`part`, `of`, `any`, `spread` and so
  on) are keywords only inside a `set` block, as the compiler reads them.
  Fenced code blocks tagged `rhema` or `rhm` in Markdown are highlighted
  too.
- **Folding** of rule bodies, `question` and `set` blocks, prompts that run
  over several lines, runs of comments, and `# region` ... `# endregion`.
- **Editing**: `#` comments with the toggle-comment command, bracket
  matching, automatic closing of `{`, `(` and `"`, and indentation after `{`.
- **Snippets**: `rule`, `rulew`, `attribute`, `synth`, `random`, `let`,
  `precedence`, `import`, `prompt`, `{answer`, ``[` ``, `question`, `set` and
  `part`.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| `rhema.path` | `rhema` | The `rhema` command. A bare name is looked up on `PATH`; a path with a separator is relative to the workspace folder. |
| `rhema.includePaths` | `[]` | Extra directories for imported and included files, passed as `-I`. |
| `rhema.check.trigger` | `onType` | When to check: `onType`, `onSave` or `off`. |

Highlighting, folding and snippets work without the `rhema` command; the
problems and the two commands need it. Install it with `opam install rhema`
(see [Install](https://project-rhm.github.io/#install)). In a clone of this
repository, the development build can be used directly:

```json
{ "rhema.path": "generator/_build/install/default/bin/rhema" }
```

In an untrusted workspace, `rhema.path` and `rhema.includePaths` are taken
from your user settings only, so a workspace cannot choose the command that
runs.

## How checking works

A saved file is checked where it is, so its imports resolve as they do on
the command line. Unsaved text is written to a temporary file, and the
file's own directory is searched first for what it imports (`-I`). The
temporary file is removed after each check.

## Installing

In VS Code, search for **Rhema Language** in the Extensions view, or run:

```bash
code --install-extension rhema.rhema-language
```

Cursor, VSCodium and other editors built on VS Code install it from
[Open VSX](https://open-vsx.org/extension/rhema/rhema-language) the same way.

To build the package from source instead, in `editors/vscode/` of the
repository:

```bash
npm run package
```

```bash
code --install-extension rhema-language-0.1.0.vsix
```

`npm run package` fetches the `vsce` packaging tool with `npx` the first
time. [PUBLISHING.md](PUBLISHING.md) describes a release.

## Developing

The extension is plain JavaScript with type annotations, so there is no
build step. `src/extension.js` is the entry point; `src/messages.js` reads
rhema's output and `src/folding.js` computes folds, and neither depends on
VS Code. The grammar is `syntaxes/rhema.tmLanguage.json`.

```bash
npm ci
```

```bash
npm run check
```

```bash
npm test
```

`npm run check` type-checks the sources. `npm test` runs the unit tests:
the grammar's tests read the keyword table from
`generator/rhema/lib/rhema_lexer.mll` and the set words from
`generator/rhema/lib/rhema_parser.mly` and tokenize every `.rhm` file in the
repository, so a keyword added to the compiler fails them until the grammar
knows it. CI runs both as the `editor` job.

The integration tests start VS Code with the extension, open the files in
`integration/workspace`, and check the problems, Run and Compile against a
real `rhema`:

```bash
npm run test:integration
```

They use the development build of `rhema` unless `RHEMA` names another, and
download VS Code into `.vscode-test/` unless `VSCODE_PATH` names an
installed one (on macOS,
`/Applications/Visual Studio Code.app/Contents/MacOS/Code`).
