# Project-RHM

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

Install the Python dependencies:

```powershell
python -m pip install -r requirements.txt
```

Start the Flask application from the project root:

```powershell
python app.py
```

Open `http://127.0.0.1:5000`. After generating a question set, use the
`PGML / Tree View` switch above the result. Tree View contains one AST/DCST
pair for each generated question. The same switch is available when opening a
question set from History.
