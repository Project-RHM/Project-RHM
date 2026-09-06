# Mathematical library specifications

These four files exercise the Formula, Polynomial and Equation library through
the existing AG language. The UI discovers `.ag` files in this directory.
Refresh the browser to refresh its grammar list.

Every file declares `attribute question_mode = 0 copy`. Zero selects mixed
generation; a positive value selects the corresponding single question form.
Edit this declaration in the UI, or use `--set question_mode=N` on the CLI.
Mixed mode uses equal production weights; a small batch need not contain every
form. Select each mode separately when checking full coverage.

| File | Mode | Question |
| --- | --- | --- |
| `library_formula.ag` | 1 | Differentiate a quotient with denominator `x^2+b`, b positive |
| | 2 | Differentiate `ln(x^2+b)` using the chain rule |
| | 3 | Differentiate `sqrt(x^2+b)` using the chain rule |
| | 4 | Differentiate `tan(ax)` on its domain |
| | 5 | Find a composite function `f(g(x))` by symbolic substitution |
| | 6 | Differentiate an exponential/trigonometric expression |
| `library_polynomial.ag` | 1 | Evaluate a quadratic at a specified point |
| | 2 | Expand `(ax+b)^n(x+c)` and collect terms |
| | 3 | Extract the coefficient of `x^n` from that product |
| | 4 | Differentiate the product, with a Polynomial/Formula cross-check |
| | 5 | Find the degree after cancellation of fourth-degree terms |
| `library_linear.ag` | 1 | Solve an equation with one bracket and variables on both sides |
| | 2 | Solve an equation with brackets on both sides |
| | 3 | Solve an equation containing a fractional expression |
| `library_quadratic.ag` | 1 | Solve a quadratic with two distinct integer roots |
| | 2 | Solve a quadratic with a repeated root |
| | 3 | Solve a quadratic with two distinct non-integer rational roots |
| | 4 | Identify a quadratic with no real solutions |

## Usage

From the project's `generator` directory:

```sh
dune build ag/agcheck.exe ag/agrun.exe
dune exec ag/agcheck.exe -- ag/library_formula.ag
dune exec ag/agrun.exe -- --pg --count 5 --seed 21 --set question_mode=2 ag/library_formula.ag
dune exec ag/agrun.exe -- --pg --count 5 --seed 21 --set question_mode=3 ag/library_polynomial.ag
dune exec ag/agrun.exe -- --pg --count 5 --seed 21 --set question_mode=3 ag/library_linear.ag
dune exec ag/agrun.exe -- --pg --count 5 --seed 21 --set question_mode=3 ag/library_quadratic.ag
dune runtest
```

The first three specifications use Numeric context. The quadratic specification
uses Interval context and expects a finite set, for example `{2,3}`, `{2}` or
`{}`. Equation values are intermediate values; final answers use the unique
solution or solution set builtins.

## Verification and boundaries

`ag_library_specs_test.ml` checks 100 seeds for each of 22 configurations
(18 single forms and four mixed modes): 2,200 primary questions plus deterministic
replays. It checks single-mode selection, coverage of mixed modes, independent
mathematical answers, PGML structure and native tree JSON generation.

Formula derivatives are compared with independently written analytic formulas
at several points. Polynomial results are checked against evaluation of the
unexpanded product and independent coefficient and derivative formulas. Linear
and quadratic solutions are compared with the roots used to construct the
problems. This is finite test evidence, not a proof for arbitrary specifications.

The run on 2026-09-06 passed all 22 configurations. One generated PGML example
per configuration (seed 21) is in `test_reports/ag_library_examples/` at the
repository root. To export them again after building, run from `generator/ag`:

```sh
../../generator/_build/default/ag/ag_library_specs_test.exe ../../test_reports/ag_library_examples
```

The checks are local. No remote WeBWorK server was contacted. In particular,
successful local PGML output is not evidence of live WeBWorK grading.

The expansion question uses the existing Formula comparator: it checks algebraic
equivalence but does not enforce expanded input form. The degree question in this
example always reduces to degree two; it exercises cancellation and degree
calculation rather than a broad difficulty distribution. Tangent questions are
restricted to the function's domain. General transcendental equations, irrational
quadratic solution sets, complex roots and multivariate polynomial solving are
outside these examples.
