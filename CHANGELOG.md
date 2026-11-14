# Changelog

Rhema follows semantic versioning: the language's syntax, the builtin
functions' names and arguments, and the `rhema` command's options are the
public interface. A breaking change raises the major version; a deprecation
is announced one version before the removal.

## Unreleased

- **Four question types scale with the budget.** `partial_fractions.rhm`,
  `taylor.rhm`, `inequality.rhm` and `partial_derivatives.rhm` refused
  every budget above 3. They now go on to 8, building the question from
  priced parts: more factors and constants, sums and products of series,
  sign charts of up to five factors, and functions of two variables with
  sin, cos and e. Budgets 1 to 3 give the same questions as before, seed
  for seed. A budget above 8 is refused. `DIFFICULTY_BUDGET.md` section 12
  has the prices and what a grammar written this way must get right.
- **Builtin**: `polynomial_truncate(p, n)`, the terms of a polynomial of
  degree at most `n`.
- **Seven more question types**, fixed forms at prices 1 to 3:
  `partial_fractions.rhm` (the constants, one blank each),
  `recurrence.rhm` (terms, characteristic roots and closed forms, up to
  four blanks), `taylor.rhm`, `row_reduction.rhm` (rank, reduced row
  echelon form, a vector of a null space), `base_conversion.rhm`,
  `trigonometry.rhm` (exact values and equations, answered as `plain`
  values) and `partial_derivatives.rhm` (answers in `x` and `y`). Each has
  a test that checks its answers independently, and the teacher workspace
  lists them.
- **`pg_variables`**: a grammar names the variables of its formula answers,
  as a `let` of the file or as an attribute of the start symbol, so an
  answer that holds only one of them is entered in a blank that knows all.
- **Builtins**: `base_digits(n, b)`, a whole number written in base 2 to 16,
  and `base_number(n, b)`, the number with those digits in decimal, for
  answers in binary and octal.
- **Fixed**: a whole-number answer of 1000 or more accepted its neighbours.
  WeBWorK compares numbers with a relative tolerance of one part in a
  thousand, so 5041 passed for 5040. Such an answer is now written
  `Real(n)->cmp(tolType=>"absolute",tolerance=>0.5)`; smaller whole numbers
  stay bare numbers. This changes the PG written by `arithmetic.rhm`,
  `counting.rhm`, `sequence.rhm` and `series.rhm` for their large answers,
  and by any grammar of your own with such answers.
- **Fixed**: WeBWorK could not read a proposition answer that holds a
  variable other than `p` and `q`, the two its Boolean context knows
  ("Variable 'r' is not defined in this context"); most rewriting questions
  of `logic_forms.rhm` were affected. A proposition answer is now written
  with a copy of the Boolean context that declares its variables and those
  named by `pg_variables`, so a grammar need not set `context "Boolean"`
  for it. `tools/validate_webwork_renderer.py` now compiles ten questions
  for each case and has WeBWorK build their answer evaluators, which is
  where such a fault shows.
- **`exactly(N)`**: a whole number graded that way whatever its size;
  `base_conversion.rhm` uses it for its binary and octal answers.
- **Blanks in text**: `blank(VALUE)` and `blank_wide(VALUE, COLUMNS)` make an
  answer blank that is joined to a production's text with `++`, so forms
  with different numbers of blanks can share a grammar and one blank can
  have a width of its own. A file that calls `blank` needs no `answer`
  line; an `answer` line together with blanks in the text is refused.
  `analytic_geometry.rhm` now asks for the centre and the radius of a
  circle in two blanks.
- **Formulas in any variables**: a formula answer with variables other than
  `x` is written with a context that declares them, so partial derivatives
  can be asked; before, such a problem did not compile in WeBWorK.
  `formula_value` gives the exact number a formula without variables
  comes to.
- **π and exact values**: `formula_pi()`, and `exact_sin`, `exact_cos`,
  `exact_tan` at multiples of π/6 and π/4.
- **`plain(VALUE)`**: an answer graded with the trigonometric, hyperbolic,
  logarithm and exponential functions switched off, so a question cannot be
  typed back as its own answer. `exponential_log.rhm` uses it for the value
  of a logarithm, where `log(625)/log(5)` used to be accepted.
- **Fixed**: a fraction in a formula is bracketed as a divisor and under a
  power, `x/(2/3)` and `(2/3)^2`; they were written `x/2/3` and `2/3^2`,
  which WeBWorK reads as other numbers. No library grammar was affected.
- **Language**: `true` and `false` are the two truth values (both are now
  reserved words; a grammar that used either as a name must rename it).
- **Language**: a local name in a production, `let NAME = EXPR` inside the
  braces. It is computed after the children are built, is visible to the
  lines below it, and is not carried by the node, so it needs no `synth`.
  A name that would hide an attribute, a random or a file-level `let` is
  refused.
- **Points**: `point2(x, y)`, `point3(x, y, z)` and `point_latex`. A point
  answer is entered as `(3, -2)` and graded as a point in any context; the
  grammar does not set one. `analytic_geometry.rhm` uses it in place of a
  text answer in the Point context.
- **Matrices of any shape**: `matrix_row`, `matrix_column`, `matrix_stack`,
  `matrix_augment`, `matrix_rows`, `matrix_columns`, and `matrix_rref` and
  `matrix_rank` by exact Gauss-Jordan elimination.
- The six grammars of the batch below are rewritten with these; they ask
  the same questions.
- **Documentation**: a tutorial page, *Installing with opam*, that goes from
  a machine without opam to a working `rhema`: installing opam, `opam init`,
  `opam install rhema`, updating, removing, and what to do when a step
  fails.
- **VS Code extension** in `editors/vscode`: highlighting, problems from
  `rhema check` as you type, Run and Compile commands, folding and snippets
  for `.rhm` files. Its tests check the grammar against the compiler's
  keywords and every `.rhm` file in the repository (CI job `editor`), and
  drive the extension in VS Code against a real `rhema`. Published on the
  Visual Studio Marketplace as `rhema.rhema-language` (0.1.1, preview).
- **Fixed**: a problem with a name, a child reference or a call was reported
  at the start of the equation or declaration holding it, so
  `value = foo` gave the column of `value` for "unknown name 'foo'". Every
  such message now points at the name itself. The parser records where each
  one is written (`At` in `rhema_ast.ml`); generation is unchanged.
- **Six more question types**, fixed forms at prices 1 to 3 and built
  answer first: `definite_integral.rhm` (integrals of polynomials and the
  areas they measure), `derivative_applications.rhm` (tangent lines,
  critical points, extreme values, intervals of increase),
  `exponential_log.rhm`, `analytic_geometry.rhm` (lines and circles; a
  point is answered as `(3, -2)`),
  `differential_equation.rhm` (initial value problems, answered by a
  formula) and `statistics.rhm`. They use the existing builtins only, and
  each has a test that checks its answers independently. The teacher
  workspace lists them.
- **Six new question types**, all built answer first: `counting.rhm`
  (arrangements, selections and probabilities, with named questions
  `counting` and `probability`), `number_theory.rhm`, `series.rhm`,
  `limits.rhm`, `eigen.rhm` and `inequality.rhm`. Each has a test that
  checks its answers independently.
- **Builtins**: `factorial`, `choose`, `permutations`, `gcd`, `lcm`,
  `pow_mod` and `mod_inverse` on whole numbers (`rhema_integers.ml`, with
  overflow checks); `number_latex`, a number in LaTeX with fractions as
  `\frac`; and the rays `set_above` and `set_below`, rendered `(a, \infty)`
  and `(-infinity, a]`. A union of sets is written `A U B` in PG without
  brackets around its parts.
- A leaf (a generator, a literal or a terminal) may be read as `$n.value`
  without a `synth value` declaration; anything else on a leaf is refused
  with a hint to write `str($n.value)`.
- **Fixed**: a polynomial with a negative leading term was printed as a
  difference, `9 - (5 \cdot x^{2} + 4 \cdot x)`; it is now
  `-5 \cdot x^{2} + 4 \cdot x + 9`.
- **Documentation site** (`docs/`, `mkdocs.yml`): a home page, an
  eight-chapter tutorial, the language reference with its grammar in EBNF,
  the command, the builtin functions (generated from `rhema doc`), the
  library and difficulty budgets. Every example file is checked and run in
  CI, and the site must build without warnings.
- **Fixed**: `distinct` in a set counted two different named questions built
  on the same rule as repeats, and could confuse rules of two files at the
  same line; it now compares the question type and the rule's file too.
- `rhema doc` groups functions by value type (`matrix2` with the matrices,
  `differentiate` with the formulas, the generators on their own) and points
  to the website. The set listing no longer prints an empty budget list.
- **CI**: GitHub Actions builds the package from a clean export on OCaml
  4.14 and 5, Linux and macOS, exactly as opam does, installs it into a
  prefix and runs the command; a second job builds the whole tree with every
  suite, the documentation examples and site, and the Python checks.

## 0.1.1 (2026-10-25)

Packaging only. The classic generator and its PG parser, which need
`pprint` and `menhirCST`, are built in the development profile only, so the
package's tests no longer fail on a machine without them (`dune build -p
rhema @runtest`). No change to the language or the command.

## 0.1.0 (2026-10-24)

The first version with a name.

- **Language**: Rhema, files `.rhm`. Attribute grammars with inherited budgets
  and synthesized attributes; `include`; `import "file.rhm" as name` with
  arguments at the boundary; `question NAME { ... }` blocks; `set NAME { ... }`
  declarations with budgets drawn fixed, from a list, or around a mean;
  `pg_context` / `pg_width` per question; `{answer ...}` blanks.
- **Values**: Number, Formula, Polynomial, Equation, Boolean, Matrix, Set,
  Vector, Complex, with their builtin functions (`rhema doc`).
- **Difficulty**: every library grammar spends a cost budget exactly;
  `--set cost=N`; sets fix the mean of a part.
- **Command**: `rhema FILE.rhm [-o OUT.pg]`, `check`, `run`, `list`, `doc`;
  GNU error format and exit codes; `-I` and `RHEMA_PATH`; one assignment is
  one paper, `--student` for a student's own.
- **Library**: 24 question grammars, 2 grammar libraries, 1 example set file,
  installed to `share/rhema` by `dune install`.
- **Layout**: `generator/rhema/{lib,bin,test}`, `generator/stdlib`,
  `generator/grammars` for the user's own files.
- **Packaging**: opam metadata in `generator/dune-project` (generated
  `rhema.opam`, MIT, tests run with `--with-test`); `RELEASING.md` describes
  tagging, the source archive and the opam-repository entry.
