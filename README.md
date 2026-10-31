# Project-RHM

[![CI](https://github.com/Project-RHM/Project-RHM/actions/workflows/ci.yml/badge.svg)](https://github.com/Project-RHM/Project-RHM/actions/workflows/ci.yml)

Project-RHM is a mathematical question generator implemented in OCaml, with a
Flask web interface.

## AST and DCST

An **Abstract Syntax Tree (AST)** represents the meaning and structure of a
problem after parsing. It removes concrete punctuation and formatting details.
For example, `1 + 2 * 3` is represented using nodes such as `ME_Add`, `T_Mul`,
and `F_Int`, so operator precedence is explicit in the tree.

A **Disjunctive Concrete Syntax Tree (DCST)** is Menhir's intermediate
unparsing representation. In this project, `describe.ml` converts the AST into
a DCST by selecting grammar productions such as `doc_no_sol`, `qitem1`, and
`madd`. A DCST can contain alternative concrete forms. `Parser.Settle.main`
chooses a valid alternative and produces a Concrete Syntax Tree (CST), which
`print_pprint.ml` renders as PG code.

The complete pipeline is:

```text
PG source -> Lexer -> Parser -> AST -> Describe -> DCST -> Settle -> CST -> PG source
```

## Rhema: the attribute-grammar generator

The library of grammars lives in `generator/stdlib/`, the user's own files in
`generator/grammars/`, and the compiler in `generator/rhema/` (`lib`, `bin`,
`test`). The language, Rhema (`.rhm` files),
defines production rules, random parameters, inherited and synthesized
attributes, constraints, wording, and answers. The shipped specifications are:

- `arithmetic.rhm`
- `boolean.rhm`
- `boolean_equiv.rhm`
- `sequence.rhm`
- `complex.rhm`
- `calculus.rhm`
- `set.rhm`
- `vector.rhm`
- `factoring.rhm`, `polynomial_expand.rhm`, `vector_expr.rhm`, `linear_equation.rhm`
- `polynomial_forms.rhm`, `sequence_parts.rhm`, on the library `polynomial_core.rhm`
- `derivative_or_boolean.rhm`, which imports `calculus.rhm` and `boolean.rhm` as modules
- `logic_forms.rhm`, three more questions on the Boolean grammars
- `matrix_expr.rhm`, `determinant.rhm`, `matrix_inverse.rhm`, `linear_system.rhm`, on the
  library `matrix_core.rhm` and the Matrix value type (`rhema_matrix.ml`)
- `counting.rhm`, `number_theory.rhm`, `series.rhm`, `limits.rhm`, `eigen.rhm`,
  `inequality.rhm`, each built from its answer
  (see `QUESTION_TYPES.md` for every grammar, its prices and its context)

### The `rhema` command

```bash
cd generator && dune build && dune install --prefix ~/.local rhema

rhema check calculus.rhm                 # file:line:col: error: ... or OK
rhema calculus.rhm -o calculus.pg        # compile: generate, write WeBWorK PG
rhema homework_set.rhm --run homework    # a whole assignment -> homework.pg
rhema run boolean.rhm --set cost=6       # see questions and answers in the terminal
rhema list calculus.rhm                  # questions, budgets, sets, imports
rhema doc                                # the builtin functions
```

One assignment is one paper, the same every time it is generated;
`--student ID` gives a student a paper of their own. Imported files are
found beside the importer, then in `-I` directories, `RHEMA_PATH` and the
installed library (`share/rhema`). `rhema` and `rhema check` remain as
the entry points the web app and the Python tools drive. Versions follow
`CHANGELOG.md`; `rhema --version` prints the one built.

Propositions are a value type of their own (`rhema_boolean.ml`, the `bool_*`
builtins): the engine renders, evaluates and compares them, so a Boolean
grammar writes formulas, not truth tables.

A grammar may `include` another file to extend it, `import` other files as
modules (`import "calculus.rhm" as calc`, then `calc.F(cost = cost)`), declare
several named questions over one set of rules (`question integral { ... }`,
run with `rhema run calculus.rhm --question integral`), describe a whole assignment as a
`set` (`3 of calc.derivative(cost ~ 6 spread 2)`, run with
`rhema homework_set.rhm --run homework`; see `homework_set.rhm`), give each question form
its own WeBWorK context, and place several answer blanks in one prompt; see
`RHEMA_LANGUAGE_EXTENSIONS.md`.

`sequence.rhm` covers arithmetic/geometric nth-term and finite-sum questions.
It also exercises the signed inclusive range generators `integer_between` and
`nonzero_integer_between`. `complex.rhm` uses recursive expression productions
for arithmetic, together with conjugate, modulus, and powers of `i`; typed
complex answers are rendered in WeBWorK's `Complex` context. See
`RHEMA_LANGUAGE_GUIDE.md` for the language and CLI. `calculus.rhm` shares a typed
symbolic Formula AST between derivative questions and reverse-generated
indefinite integrals, with mixed and single-question modes.
`set.rhm` recursively composes union, intersection, and difference over stable
finite-set or interval definitions. `vector.rhm` covers dot product, cross
product, norm, unit-vector, parallel-vector, and same-direction questions with
typed Vector answers and comparators.

Difficulty is a budget the grammar spends. `boolean.rhm` prices each
connective (conjunction 2, conditional 4, biconditional 6, and so on) and
`arithmetic.rhm` prices its operations and the digits of its numbers;
`calculus.rhm` prices the differentiation rules a function calls for;
`complex.rhm` and `set.rhm` price their expressions, `boolean_equiv.rhm` its
laws, and the grammars of fixed forms (`vector.rhm`, `sequence.rhm`, the
`library_*.rhm` files) offer each form at its price. Every grammar spends
an operator-cost budget exactly, so `--set cost=6` and
`--set cost=14` ask for an easy and a hard question of the same type.
`tools/rhema_difficulty.py` reports what each budget buys, suggests levels, and
builds a set whose mean budget is a chosen value. See `DIFFICULTY_BUDGET.md`
(English) and `DIFFICULTY_BUDGET.zh.md` (Chinese).

Attribute Grammar generation also writes a native visualization. Its applied
production tree shows which weighted rule was selected at each nonterminal;
its attributed derivation tree shows question-level values plus inherited and
synthesized attributes. The Flask UI exposes these views for newly generated
and historical Attribute Grammar question sets.

## Classic Arithmetic Attribute Grammar

Arithmetic expressions are generated by a small attribute-grammar engine in
`generator/attribute_grammar.ml`. Its default declarative grammar is
`generator/arithmetic.rhm`.

For the implementation rationale, migration details, testing record, known
limitations, and team handoff notes, see
[`ATTRIBUTE_GRAMMAR_IMPROVEMENT.md`](ATTRIBUTE_GRAMMAR_IMPROVEMENT.md).

```text
attribute len = 2 split
attribute digit = 2 copy

start E

E -> E + E { len = -1 } when len > 0 weight 3
E -> E - E { len = -1 } when len > 0 weight 3
E -> E * E { len = -1 } when len > 0 weight 2
E -> E / E { len = -1 } when len > 0 weight 1
E -> num { len = -0 } when len = 0 weight 1
num -> integer { digit = -0 } when digit > 0 weight 1
```

`len` is a split inherited attribute: every operator consumes one unit and the
remaining budget is divided between its child expressions. Therefore an input
budget of `n` produces exactly `n` arithmetic operators and generation must
terminate. `digit` is copied to every number leaf and controls the number of
digits in generated integers. Rule weights choose among rules that satisfy the
current guard; they do not override attribute constraints.

The existing `max_expr_depth` configuration currently supplies the initial
`len` budget. The initial `digit` value and rule weights can be edited in
`generator/arithmetic.rhm`. Set `ATTRIBUTE_GRAMMAR_FILE` to load a different
grammar file.

Run the focused tests with:

```powershell
cd generator
dune runtest
```

These tests verify exact operator budgets, digit limits, termination, valid
evaluation, and one paper per assignment, the same every time it is generated.

## Visualize the AST and DCST

Requirements:

- OCaml
- Dune 3.5 or later
- The project dependencies: `menhir`, `menhirCST`, and `pprint`

Build the OCaml tools:

```powershell
cd generator
dune build
```

If Dune is installed in an OPAM switch but is not on `PATH`, use:

```powershell
opam exec -- dune build
```

Visualize an existing PG file:

```powershell
dune exec ./visualize.exe -- examples/sample.pg ast_dcst_visualization.html
```

The equivalent OPAM command is:

```powershell
opam exec -- dune exec ./visualize.exe -- examples/sample.pg ast_dcst_visualization.html
```

The output path is optional. When omitted, the tool writes
`ast_dcst_visualization.html`:

```powershell
dune exec ./visualize.exe -- examples/sample.pg
```

The tool also accepts PG source from standard input:

```powershell
Get-Content -Raw examples/sample.pg | dune exec ./visualize.exe -- - ast_dcst_visualization.html
```

Open the generated self-contained HTML file in a browser:

```powershell
Start-Process .\ast_dcst_visualization.html
```

The page displays:

- A separate semantic AST constructor tree for every generated question.
- The actual Menhir DCST, including nonterminal production IDs, concrete
  terminal tokens, and any `Choice` alternatives for every question.
- Interactive D3 horizontal tree diagrams with pan, zoom, node folding,
  fit-to-view controls, and question navigation.
- The original PG input.
- The PG source reprinted after settling the DCST into a CST. This may differ
  from the input because `print_pprint.ml` applies the project's output format.

## Web Application

### Docker: Flask, Rhema and WeBWorK together (recommended)

#### macOS / teacher workspace

On Apple Silicon, install and open [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/)
first. Both Compose services explicitly use `linux/amd64`: the pinned
renderer image and its bundled opam installer target x86_64. Docker Desktop
runs them using emulation. The published ports remain local to this computer.

For a quick development loop with the existing local OCaml toolchain, start
only the real renderer and run Flask natively:

```sh
docker compose -p rhema-workspace-local up -d --wait webwork-renderer
python3 -m venv .venv                  # once, not a venv copied from another machine
.venv/bin/python -m pip install -r requirements.txt
cd generator
dune build
cd ..
APP_PORT=5003 .venv/bin/python app.py
```

Open <http://127.0.0.1:5003>. Port 5003 avoids an older checkout on 5001.
The default host-native renderer address is `http://127.0.0.1:3000/render-api`.
To check every shipped teacher grammar and named question against the live
renderer from this host-native setup, run:

```sh
.venv/bin/python tools/validate_webwork_renderer.py --renderer-url http://127.0.0.1:3000/render-api
```

The alternative full-container stack is:

```sh
APP_PORT=5003 docker compose -p rhema-workspace-local up --build -d
```

The workspace opens in English. Its header language button switches the
interface between English and Chinese and remembers the choice locally;
question wording, mathematical content, answers, grammar source and the
isolated WeBWorK document are not machine-translated. Choose a type from
the library, configure parameters in the middle and inspect questions,
PGML or production trees on the right. Classic and Rhema source modes
remain available. Budget controls keep their original semantics; they are
not renamed as educational difficulty levels.

The Questions tab renders the complete PG document using WeBWorK, not a
reconstruction of its HTML in the application. Renderer HTML runs inside
a sandboxed iframe. Service failures and PG translator errors are reported
instead of being labelled successful. For teacher-form results, **Local
preview** is an explicitly labelled fallback, and **Standard answers** are
collapsed by default. Enter answers in the WeBWorK inputs and use **Check
answers** to see per-answer feedback and the total score. Changing an answer
invalidates the displayed grade. Local preview cannot grade answers.

The checker evaluates student submissions against the PG answer evaluators;
it does not independently prove that the generated standard answers are correct.
Previously saved Classic mixed files with context-dependent vector answers
should be regenerated to use the corrected evaluators.

The renderer client connects directly to its configured service rather than
inheriting workstation proxy variables. Static iframe previews omit the
renderer's optional parent-frame interaction tracker and MathQuill editor
initializer, which require same-origin access or localStorage. MathJax,
ordinary answer inputs and the `sandbox="allow-scripts"` isolation remain.
An answer-only `postMessage` bridge connects these inputs to
`POST /api/webwork/check`. The parent checks the frame identity and a per-render
token; it does not enable same-origin iframe access or native form submission.
The server validates answer field names and sizes. Its internal grading request
uses the renderer's answer hash, but only scores and plain feedback are returned,
not correct-answer objects, renderer HTML, or session JWTs.

Stop the renderer without deleting data with
`docker compose -p rhema-workspace-local stop webwork-renderer`.

Start Docker Desktop in Linux/WSL2 mode, then run in PowerShell:

```powershell
cd F:\Project-RHM_latest\Project-RHM_latest
docker compose up --build -d
docker compose ps
```

Open <http://127.0.0.1:5001> after both services show `healthy`. Python,
OCaml, opam, Dune, Menhir and PPrint are installed inside the application
image; no host installation or host `dune build` is needed. The first build
downloads the toolchain; subsequent starts reuse the image:

```powershell
docker compose up -d
docker compose logs -f app
docker compose down
```

The application image builds the current Rhema CLI, its installed standard
library and the teacher-mode bridge. `generator/rhema/`, `generator/stdlib/`,
`generator/grammars/`, `config_setting/` and the three `generator/generated_*`
directories are mounted from this checkout. Generated files, saved grammars
and teacher presets survive container replacement. The Linux `_build` stays
inside the container and does not use Windows build artifacts. Keys saved
in Docker mode live in the ignored `.project-rhm-data/` directory; existing
host-mode keys are not copied into the image.

New question definitions go in `generator/grammars/*.rhm` and new library
modules in `generator/stdlib/`. They are read at run time; reload the grammar
list/page after adding a file. After changing the OCaml implementation in
`generator/rhema/`, run `docker compose restart app` to trigger its incremental
build. Changes to Python, templates, CSS, `generator/dune-project`, other
OCaml sources or dependencies require `docker compose up --build -d`.

If the earlier checkout is still running on ports 5001/3000, stop it from
that checkout with `docker compose down` before starting this one. To run
both checkouts at once, choose different published ports here:

```powershell
$env:APP_PORT = '5002'
$env:WEBWORK_PORT = '3001'
docker compose up --build -d
```

In that case open <http://127.0.0.1:5002>. The browser-visible Renderer asset
URL follows `WEBWORK_PORT`. Stop with `docker compose down`; generated files
and saved definitions remain on the host. This is a local development stack,
with both published ports bound to `127.0.0.1`.

### Rendered Preview and API

Classic, Rhema source and teacher form generation share the same `Question
preview` cards above the result tabs. Classic/source previews use WeBWorK to
resolve PG variables and functions before rendering the math with KaTeX.
Teacher form previews retain their supplied standard answers. The PGML,
tree and full WeBWorK tabs remain available below the common preview.

Generated results and History each have a `Rendered Preview` tab. It sends
the current complete `.pg` document to Flask, which calls the official,
digest-pinned WeBWorK Renderer over the Compose network. The HTML is shown in
a sandboxed iframe with MathJax. Requests use static, non-instructor output
without solutions or hints. Errors, timeouts and unavailable services appear
in the preview panel. Editing the source marks the preview as stale.

Flask uses `http://webwork-renderer:3000/render-api` inside Compose; the
browser loads CSS/JS from `http://127.0.0.1:3000/`. For host-native Flask,
the defaults and optional environment settings are listed in `.env.example`.
That file is a configuration reference: export the variables in your shell
when using host-native Flask. `GET /api/webwork/status` checks a real render.

Generate and render a Rhema definition through Flask (use your selected app
port if different):

```powershell
$paper = Invoke-RestMethod -Uri http://127.0.0.1:5001/run_rhema -Method Post `
  -Body @{ grammar = 'arithmetic.rhm'; count = 2; student_id = 'demo' }
$body = @{ pg_source = $paper.pgml_code; problem_seed = 1 } | ConvertTo-Json
$preview = Invoke-RestMethod -Uri http://127.0.0.1:5001/api/webwork/render `
  -Method Post -ContentType application/json -Body $body
# $preview.html contains the rendered document.
```

Run preview tests and live validation inside the application container:

```powershell
docker compose exec -T app python3 -m unittest tools.test_webwork_preview -v
docker compose exec -T app python3 -m unittest discover -s tools -p test_teacher_builder.py -v
docker compose exec -T app python3 tools/validate_webwork_renderer.py
docker compose exec -T app python3 tools/test_webwork_grading_live.py
```

### Host-native Flask (requires a local OCaml toolchain)

Install the Python dependencies:

```powershell
python -m pip install -r requirements.txt
```

Start the Flask application from the project root:

```powershell
python app.py
```

Open `http://127.0.0.1:5001`. After generating a question set, use the
`PGML / Tree View / Rendered Preview` switch above the result. Tree View contains one AST/DCST
pair for each generated question. The same switch is available when opening a
question set from History.
