# RHM — Reversible Hierarchical Mathesis

**Math Question Generation** · *Regula · Hierarchia · Mathesis*

[![CI](https://github.com/Project-RHM/Project-RHM/actions/workflows/ci.yml/badge.svg)](https://github.com/Project-RHM/Project-RHM/actions/workflows/ci.yml)

[Documentation](https://project-rhm.github.io/) ·
[opam package](https://opam.ocaml.org/packages/rhema/) ·
[VS Code extension](https://marketplace.visualstudio.com/items?itemName=rhema.rhema-language) ·
[Changelog](CHANGELOG.md) ·
[中文说明](README.zh.md)

RHM generates mathematics questions for [WeBWorK](https://openwebwork.org/).
It has three parts:

- **Rhema**, a language that describes a kind of question as an attribute
  grammar: what shapes it may take, how hard it is, what its answer is and
  how it reads.
- **`rhema`**, the compiler, with a library of grammars from arithmetic to
  linear algebra.
- A **Flask web application** for generating, editing and browsing question
  sets.

The question and its answer come from the same tree, so they cannot disagree.
Difficulty is a budget the grammar spends exactly, and a file can describe a
whole assignment, which compiles to the same paper every time.

## A first question

Save this as `first.rhm`:

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

Grammars import one another, so an assignment can draw on the library
without copying it. This file, saved as `quiz.rhm` in any directory, asks for
four calculus questions, three of them at a mean cost of 6:

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

That writes `quiz.pg`, ready for WeBWorK.

## Install

The compiler and its library, on OCaml 4.14 or later:

```bash
opam install rhema
```

This installs 0.1.1, the current release. The repository is ahead of it: the
Unreleased section of the [changelog](CHANGELOG.md) lists what is newer.

For VS Code, install **Rhema Language** from the
[Marketplace](https://marketplace.visualstudio.com/items?itemName=rhema.rhema-language).
It runs `rhema check` as you type, and adds highlighting and commands to run
and compile; see [`editors/vscode`](editors/vscode/README.md).

To work from a clone, which the web application and the newest grammars
need:

```bash
git clone https://github.com/Project-RHM/Project-RHM.git
cd Project-RHM/generator
opam install dune menhir menhirCST pprint
dune build
```

The command is then at `generator/_build/install/default/bin/rhema`.

## The `rhema` command

These lines run in `generator/stdlib`, where the library lives. `rhema` takes
a file by its path; the search below applies to the files it imports.

```bash
rhema check calculus.rhm                  # file:line:col: error: ... or OK
rhema calculus.rhm -o calculus.pg         # compile to WeBWorK PG
rhema homework_set.rhm --run homework     # a whole assignment -> homework.pg
rhema run boolean.rhm --set cost=6        # questions and answers in the terminal
rhema run calculus.rhm --question integral  # one named question of the file
rhema list calculus.rhm                   # questions, budgets, sets, imports
rhema doc                                 # the builtin functions
```

One assignment is one paper, the same every time it is generated;
`--student ID` gives a student a paper of their own. Imported files are found
beside the importing file, then in `-I` directories, `RHEMA_PATH` and the
installed library (`share/rhema`).

## The question library

The 0.1.1 package installs 27 grammar files. `generator/stdlib/` holds those
and the six marked †, which will reach opam with the next release; until
then they need a clone. [`QUESTION_TYPES.md`](QUESTION_TYPES.md) gives each
grammar's questions, prices and WeBWorK context.

| Area | Grammars |
| --- | --- |
| Arithmetic | `arithmetic` |
| Algebra | `polynomial_expand`, `factoring`, `polynomial_forms`, `linear_equation`, `inequality`†, `library_linear`, `library_quadratic`, `library_polynomial` |
| Sequences and series | `sequence`, `sequence_parts`, `series`† |
| Calculus | `calculus`, `limits`†, `library_formula` |
| Logic | `boolean`, `boolean_equiv`, `logic_forms` |
| Sets | `set` |
| Vectors | `vector`, `vector_expr` |
| Complex numbers | `complex` |
| Linear algebra | `matrix_expr`, `determinant`, `matrix_inverse`, `linear_system`, `eigen`† |
| Counting and number theory | `counting`†, `number_theory`† |
| Combined | `derivative_or_boolean` (one question, two imported grammars), `homework_set` (a whole assignment) |
| Shared rules, no questions of their own | `polynomial_core`, `matrix_core` |

A new question type is a new `.rhm` file, not a change to the engine. Your
own files belong in `generator/grammars/`.

## Difficulty

Difficulty is a budget the grammar spends. `boolean.rhm` prices each
connective (conjunction 2, conditional 4, biconditional 6 and so on),
`calculus.rhm` prices the differentiation rules a function calls for, and
grammars of fixed forms offer each form at its price. Every grammar spends
its budget exactly, so `--set cost=6` and `--set cost=14` ask for an easy and
a hard question of the same type.

A set can fix a budget (`cost = 6`), use a list evenly
(`cost in {8, 10, 12}`), or hold a mean (`cost ~ 6 spread 2`).
`tools/rhema_difficulty.py` reports what each budget buys and suggests
levels. See [`DIFFICULTY_BUDGET.md`](DIFFICULTY_BUDGET.md).

## Web application

From a clone, after `dune build`:

```bash
python3 -m pip install -r requirements.txt
python3 app.py
```

Then open <http://127.0.0.1:5001>. The application generates question sets,
keeps their history, and has an editor for grammars, which checks a file with
`rhema check` before saving it. Above each result, the
`AST / DCST Trees` switch shows the trees behind the questions. For Rhema
grammars these are the applied production tree and the attributed derivation
tree. With a DeepSeek API key, the optional Add Context feature puts
arithmetic questions into a context written by an LLM.

The teacher workspace adds a **Configure** form for existing question types,
alongside the **Rhema source** editor and Classic generator. It supports saved
presets, English/Chinese interface switching, and resizable settings/preview
panels. Generated PG can be rendered by the official WeBWorK Renderer, with
**Check answers** for feedback on student inputs. This checks submissions
against the PG evaluators, not an independent proof of the standard answers.

For Docker setup, local ports, form controls, preview isolation and tests, see
[`TEACHER_MODE.md`](TEACHER_MODE.md). Start Docker Desktop, then start the
renderer with `docker compose up -d --wait webwork-renderer`. The renderer is
optional for generation and PGML export; WeBWorK preview and grading need it.

## Repository layout

| Path | Contents |
| --- | --- |
| `generator/rhema/` | The compiler: `lib`, `bin`, `test` |
| `generator/stdlib/` | The library of grammars, installed with the package |
| `generator/grammars/` | Your own grammars |
| `generator/*.ml`, `*.mly` | The classic PG generator, described below |
| `docs/`, `mkdocs.yml` | The documentation site |
| `editors/vscode/` | The VS Code extension |
| `tools/` | Difficulty, statistics and set tools; test scripts |
| `app.py`, `templates/`, `static/`, `llm_context/` | The web application |

## Testing

```bash
cd generator
dune build
dune runtest --force
cd ..
python3 tools/test_grammar_creation.py
python3 tools/test_teacher_builder.py
python3 tools/test_webwork_preview.py
tools/check_doc_examples.sh generator/_build/install/default/bin/rhema
```

Several suites read a generated question back and recompute its answer
independently of the grammar. CI runs these, and builds the package from a
clean export on OCaml 4.14 and 5, on Linux and macOS.

## The classic pipeline

RHM began by running a parser backwards, and that generator is still in
`generator/`. It parses PG source and reprints it through Menhir's unparsing
API:

```text
PG source -> Lexer -> Parser -> AST -> Describe -> DCST -> Settle -> CST -> PG source
```

An **Abstract Syntax Tree (AST)** represents the meaning and structure of a
problem, without punctuation or formatting. `1 + 2 * 3` becomes nodes such as
`ME_Add`, `T_Mul` and `F_Int`, so operator precedence is explicit in the tree.

A **Disjunctive Concrete Syntax Tree (DCST)** is Menhir's intermediate
unparsing representation, which can hold alternative concrete forms.
`describe.ml` turns the AST into a DCST by selecting grammar productions,
`Parser.Settle.main` chooses a valid alternative to give a Concrete Syntax
Tree (CST), and `print_pprint.ml` renders the CST as PG.

To see these trees for a PG file, run this in `generator/`:

```bash
dune exec ./visualize.exe -- examples/sample.pg ast_dcst_visualization.html
```

The result is a self-contained HTML page with an interactive AST and DCST for
each question, the original PG, and the PG reprinted from the CST. The file
argument may be `-` for standard input, and the output path is optional.

Arithmetic expressions in this pipeline come from a small attribute-grammar
engine, `generator/attribute_grammar.ml`, whose default grammar is
`generator/arithmetic.ag`. Set `ATTRIBUTE_GRAMMAR_FILE` to load another. This
is the ancestor of Rhema and uses its own, simpler format; see
[`ATTRIBUTE_GRAMMAR_IMPROVEMENT.md`](ATTRIBUTE_GRAMMAR_IMPROVEMENT.md).

## Documentation

- [The documentation site](https://project-rhm.github.io/): an eight-chapter
  tutorial and the language reference
- [`RHEMA_LANGUAGE_GUIDE.md`](RHEMA_LANGUAGE_GUIDE.md): the language and the
  command
- [`RHEMA_LANGUAGE_EXTENSIONS.md`](RHEMA_LANGUAGE_EXTENSIONS.md): `include`,
  `import`, named questions, sets, per-question contexts and multiple answer
  blanks
- [`RHEMA_MODULES_DESIGN.md`](RHEMA_MODULES_DESIGN.md): the design of the
  module layer
- [`QUESTION_TYPES.md`](QUESTION_TYPES.md): every grammar in the library
- [`DIFFICULTY_BUDGET.md`](DIFFICULTY_BUDGET.md): prices, budgets and sets
- [`RELEASING.md`](RELEASING.md): how a version is released

## The name

- **Reversible**: a parser reads text into a tree. RHM runs that direction
  backwards, building the tree first and writing the question from it.
- **Hierarchical**: questions are trees of productions. Difficulty is passed
  down the tree, results are computed back up it, and grammars compose into
  assignments.
- **Mathesis**: after Leibniz's *mathesis universalis*, a universal method of
  reasoning by calculation.

The letters are also *Menhir* read backwards without its vowels, and
Rheinmetall's stock ticker. **Rhema** (Greek ῥῆμα, *an utterance*) sits
inside RHM and names what a grammar does: it says a question.

## Authors and licence

Jingming Zhang, Jiaming Lei, Xiaobo Huang, Jiesen Long and Zhiyuan Li, at
[Beijing Normal-Hong Kong Baptist University](https://www.bnbu.edu.cn/en/).
Released under the [MIT licence](LICENSE).
