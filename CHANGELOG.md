# Changelog

Rhema follows semantic versioning: the language's syntax, the builtin
functions' names and arguments, and the `rhema` command's options are the
public interface. A breaking change raises the major version; a deprecation
is announced one version before the removal.

## Unreleased

- **Mistakes.** A grammar can declare a mistake students make,
  `mistake NAME "what the student does"`, and say in a production what such
  a student computes, with a line `mistake NAME ATTRIBUTE = EXPRESSION`.
  After a question is built its tree is evaluated again under each mistake.
  A question in which a mistake changes the working and still gives the
  right answers is built afresh, so wrong working is never marked right;
  `rhema run` lists what each mistake leads to under the answer. Formulas
  are compared as functions. See chapter 9 of the tutorial and "Mistakes"
  in the language reference.
- **Four library grammars declare mistakes:** `calculus.rhm` (a product
  differentiated factor by factor, the chain rule left out, a quotient
  differentiated top and bottom), `complex.rhm` (`i` squared taken to be 1,
  a minus sign kept from the imaginary part), `boolean.rhm` (a conditional
  with a false antecedent taken to be false, "or" read as exclusive) and
  the polynomial expansions (each term raised to the power on its own).
  Their papers change where a question hid a mistake: such a question is
  replaced, and the draws after it move. On a 500-question paper the first
  different question is number 245 for `calculus.rhm` derivatives, 67 for
  `complex.rhm` and 25 for `boolean.rhm`; integrals, factorings and
  expansions are the same questions as in 0.2.0. A derivative answer of
  `calculus.rhm` is the same function as before and is sometimes written
  differently in PG.
- **Failures end with a message.** Several things a grammar can ask for
  ended the command with OCaml's `Fatal error: exception ...` and status 2.
  Each now stops with a message of one line and status 1: a name that is
  not a variable name given to `polynomial_variable`,
  `polynomial_constant`, `polynomial_linear`, `polynomial_quadratic`,
  `formula_to_polynomial` or one of the four functions that solve an
  equation; a zero divisor met inside `differentiate` or
  `formula_substitute`; a negative size for `matrix_identity`; an equation,
  or text holding a blank, that reaches an `answer` through `cond`, which
  `rhema run` listed and the PG writer stopped on. Whatever else is raised
  while a paper is generated or written is reported the same way.
- **Generators draw from a range of any width.** A range of more than
  1073741823 values, such as `integer(10)` or
  `integer_between(0, 2000000000)`, ended in the same fatal error. It is
  now drawn from; `integer(DIGITS)` takes up to 18 digits and says so
  beyond. A narrower range is drawn exactly as before.
- **Exact numbers no longer wrap round.** A number is a fraction of two
  63-bit integers, and a sum or product that did not fit gave a wrong
  number without a word, or, as in
  `polynomial_power(polynomial_linear(1, 2, "x"), 100)`, a stack overflow.
  Every operation is now checked; one that does not fit stops the question
  like a division by zero, with "a number grew too large to be kept exact".
  No question of the library is affected: its output is byte-identical.
- **Static types.** `rhema check`, and every command that reads a file, now
  infers the types every expression can have and reports a use that none of
  them allows: text in arithmetic, a number where a formula is wanted, a
  guard or requirement that is not a truth value, a budget update that is
  not a number, an equation as an answer, a child written `$n` where a
  value is wanted, a mistake line whose value the lines after it cannot
  take. Such
  a file used to pass the check and stop while generating. Nothing is
  declared: an attribute has the types its productions give it, by
  nonterminal, and a module's types cross an import. A use that only some
  types allow is still left to the engine, and so is everything that
  depends on the value (a whole number, a zero divisor, the shape of a
  matrix). See "Types" in the language reference.
  For a file without such a use nothing changes: every question type of
  the library, its set, and PG and LaTeX output are byte-identical.
  A file that generated before is refused now in two cases: a wrong type
  where nothing was ever evaluated (the unchosen branch of `cond`, the
  right side of `and` or `or`, a production no question reaches, the lines
  below a requirement that never holds, or a budget update, whose
  production the engine silently never chose); an answer that is an
  equation or text holding a blank, which `rhema run` listed and the PG
  writer could not write.
- `rhema doc` prints what each function takes and gives, and the builtins
  page of the site, generated from it, shows the same.
- `mistake` is now a reserved word. A grammar that used it as a name must
  rename it.
- **A presentation at a terminal.** When `rhema` writes to a terminal,
  compiling and running show the file, the assignment and the seed, the
  steps as they are reached, the progress of the generation and a summary
  of what was written; a problem is shown with its line of the file and a
  mark under the column. It all goes to standard error, and it is off when
  anything is redirected or piped, when `CI` is set and when PG goes to
  standard output, so what a program reads from `rhema` has not changed.
  `--plain` turns it off, `--no-color` (or `NO_COLOR`) and `--no-emoji`
  tone it down, and `-v` / `--verbose` adds each question's derivation.
  It has a few jokes in it, and three hidden options (`--hello`,
  `--nailong`, `--coffee`).
- **`rhema try FILE`.** A session that shows the questions of a file one
  at a time and takes a command a line: `a` for the answer and what each
  mistake gives, `= NUMBER` to compare a number with the answer exactly
  (a number that is the answer of a declared mistake is told so),
  `BUDGET = N`, `question NAME` and `seed N` to change what is generated,
  `t` and `pg` to look at the derivation and the PG, and `how` for the
  `rhema run` command that prints the questions shown so far. A session
  shows exactly the questions that command does. It reads standard input,
  from a terminal or not.
- **A missing name is asked for, at a terminal.** A file of sets run
  without `--run`, a `--run` that names no set and a `--question` that
  names no question list the file's own names and ask which is meant. The
  answer is a number or a name of the list, never a guess, and the run is
  the one the same command gives with that name on it. Without somebody to
  ask (a pipe, a redirection, `--plain`) these are the errors they were.
- **Hints.** An unknown option or command is reported with the one it is
  nearest to: `unknown option --studnt (did you mean --student?)`.
- **Six question types.** `probability.rhm` (the addition rule,
  independent events, conditional probability, total probability and
  Bayes' rule), `modular_arithmetic.rhm` (Euler's function, divisors,
  simultaneous congruences, an RSA key), `graph_theory.rhm` (edges from
  degrees, trees and forests, walks from the adjacency matrix, the faces of
  a planar graph), `binomial_theorem.rhm` (a coefficient of a power of a
  bracket, a term independent of `x`, a product), `numerical_methods.rhm`
  (Newton's method, bisection, the trapezoidal rule, Simpson's rule and
  Euler's method, worked exactly) and `lines_planes.rhm` (planes, lines,
  distances, feet of perpendiculars and reflections in space). Each has
  fixed forms at prices 1 to 3 and a default budget of 2, uses the existing
  builtins only, and has a test that recomputes its answers from the
  printed question. `probability.rhm` and `binomial_theorem.rhm` declare
  two mistakes each. The library now has 52 files.
- **Six more question types.** `double_integral.rhm` (iterated integrals
  over a rectangle, with an inner limit that depends on `x`, and over a
  region described in words), `implicit_differentiation.rhm` (the slope of
  a curve at a point, a related rate, a tangent, the second derivative),
  `markov_chain.rhm` (a chain with two states told as a story, two steps
  of a chain with three states from its matrix, the long-run share, a walk
  that stops at either end of a line), `regression.rhm` (the least-squares
  line from summary numbers and from five data points, a residual, a
  prediction, the coefficient of determination), `complex_polar.rhm`
  (modulus and argument, products, quotients and powers in polar form, De
  Moivre's theorem, the roots of `z^n = w`) and `relations.rhm` (counting
  relations and functions between finite sets, the composite and the
  closures of a relation given by its pairs, equivalence relations). Each
  has fixed forms at prices 1 to 3 and a default budget of 2, uses the
  existing builtins only, and has a test that recomputes its answers from
  the printed question. `implicit_differentiation.rhm`, `regression.rhm`
  and `relations.rhm` declare two mistakes each and `markov_chain.rhm`
  one. The library now has 58 files.
- **Six more question types (an eighth batch).** `vector_calculus.rhm`
  (the gradient, divergence, curl and Laplacian at a point, a directional
  derivative, the work along a segment, Green's theorem round a
  rectangle), `improper_integral.rhm` (integrals over an unbounded
  interval of powers and of exponentials, one with a singularity at an
  end, one that comes to a multiple of pi), `linear_programming.rhm` (the
  greatest or least value of `p x + q y` over a region of the first
  quadrant, and the corner at which it is taken), `graph_algorithms.rhm`
  (a shortest path and a minimum spanning tree in a weighted graph, the
  number of spanning trees, the edges an Euler circuit still needs),
  `orthogonality.rhm` (components, projections onto a line and a plane, a
  Gram-Schmidt step, the matrix of a projection) and
  `counting_principles.rhm` (inclusion and exclusion for two and three
  sets, the pigeonhole principle, stars and bars, derangements). Each has
  fixed forms at prices 1 to 3 and a default budget of 2, uses the
  existing builtins only, and has a test that recomputes its answers from
  the printed question. Five of the six declare mistakes, eight in all.
  The library now has 64 files.
- **Six more question types (a ninth batch).** `random_variables.rhm`
  (the mean and the variance of `aX + b` and of sums of independent
  variables, binomial, geometric and uniform variables, a density
  `c x^n`, a covariance), `laplace_transform.rhm` (the transform of
  powers, exponentials, sines and cosines, the shift, and inverse
  transforms, one by partial fractions; answers in `s` and in `t`),
  `automata.rhm` (the state a three-state automaton reaches on a word, the
  words of a length it accepts, the words with no two `a`s together, the
  least number of states for three families of languages),
  `power_series.rhm` (the radius and the interval of convergence, with the
  ends of the interval tested), `optimization.rhm` (the second-derivative
  test, the least or greatest value of a quadratic in two variables, a
  local extreme of a cubic, extremes on a line, a circle and a plane) and
  `linear_transformations.rhm` (images, the matrix from images, one
  transformation after another, areas, the dimensions of kernel and image,
  the matrix in another basis, a reflection). Each has fixed forms at
  prices 1 to 3 and a default budget of 2, uses the existing builtins
  only, and has a test that recomputes its answers from the printed
  question. All six declare mistakes, seventeen in all. The library now
  has 70 files.
- **Six more question types (a tenth batch).** `fourier_series.rhm`
  (Fourier coefficients of a line, a step, a square wave, a parabola, an
  absolute value and a line on half the interval, on `(-pi, pi)` and on
  `(-L, L)`, and the value of a series at a jump),
  `integral_applications.rhm` (volumes by discs, washers and shells, the
  length of a curve, the area of a surface of revolution, the work done on
  a spring and in pumping a tank, a centroid), `parametric_polar.rhm` (the
  slope, tangent line, second derivative and length of a parametric curve,
  a polar point in Cartesian coordinates, areas bounded by polar curves),
  `hypothesis_testing.rhm` (`z`, `t` and chi-square statistics, a
  confidence interval, degrees of freedom), `group_theory.rhm` (orders of
  elements of cyclic groups, of pairs, of units and of permutations,
  generators, an index, primitive roots) and `conic_sections.rhm`
  (eccentricities, foci, asymptotes, an ellipse given expanded, a parabola
  from its focus and directrix, a latus rectum). Each has fixed forms at
  prices 1 to 3 and a default budget of 2, uses the existing builtins
  only, and has a test that recomputes its answers from the printed
  question. All six declare mistakes, twenty-nine in all. The library now
  has 76 files.
- **Six more question types (an eleventh batch).**
  `normal_distribution.rhm` (probabilities of a normal variable, of a
  sample mean and of a difference, from values of the distribution
  function given in the question), `graph_coloring.rhm` (the colourings
  with `k` colours of trees, complete graphs, cycles, wheels and joined
  cycles, and chromatic numbers), `vector_spaces.rhm` (coordinates
  relative to a basis, dimensions of standard spaces, of sums and of
  intersections, a change of basis), `integral_coordinates.rhm` (a triple
  integral over a box, and integrals in polar, cylindrical and spherical
  coordinates), `integration_techniques.rhm` (half-angle formulas, inverse
  trigonometric integrals, integration by parts, powers of sine and
  cosine, a trigonometric substitution, partial fractions) and
  `nonhomogeneous_ode.rhm` (particular solutions by undetermined
  coefficients, with and without resonance, and initial value problems).
  Each has fixed forms at prices 1 to 3 and a default budget of 2, uses
  the existing builtins only, and has a test that recomputes its answers
  from the printed question. All six declare mistakes, twenty-two in all.
  The library now has 82 files.
- **Six more question types (a twelfth batch).**
  `indeterminate_limits.rhm` (limits by l'Hopital's rule, a Taylor
  expansion or a conjugate: 0/0, 0 times infinity, 1 to the power
  infinity, infinity minus infinity), `financial_maths.rhm` (simple and
  compound interest, present value, an effective rate, depreciation,
  series of payments, the payment that repays a loan), `diophantine.rhm`
  (the equation `a x + b y = c` in whole numbers, the amounts two stamps
  cannot make, continued fractions, Pell's equation),
  `related_rates.rhm` (rates of areas and volumes, a ladder, a balloon,
  two travellers, a cone, a shadow, and tangent-line estimates of roots),
  `matrix_powers.rhm` (eigenvalues of powers, a power of a matrix that
  can be diagonalised, the Cayley-Hamilton theorem, a power applied to
  eigenvectors) and `triangles.rhm` (the laws of sines and cosines,
  areas, Heron's formula, the circles round and inside a triangle, the
  ambiguous case). Each has fixed forms at prices 1 to 3 and a default
  budget of 2, uses the existing builtins only, and has a test that
  recomputes its answers from the printed question. All six declare
  mistakes, twenty-six in all. The library now has 88 files.
- **Changed.** `--count` with a negative number is an error of the command
  line (status 2); it was `rhema: error: List.init`. The "not run through
  WeBWorK" line of the summary is said only where PG was written. In the
  OCaml library, the record `Rhema_load.failure` has a third field,
  `kind`, which says whether a failure is of the syntax, of the meaning or
  of something else; code that builds such a record must give it.

## 0.2.0 (2026-11-16)

The library grows from 27 grammar files to 46, seven of the new question
types scale with the budget, and a paper can be written as LaTeX or PDF as
well as WeBWorK PG.

Coming from 0.1.1:

- `true` and `false` are now reserved words. A grammar that used either as a
  name must rename it; nothing else in the language or the command changed
  meaning.
- The 27 grammar files of 0.1.1 ask the same questions for the same seed
  (compared on 30 questions of each question type and on the library's
  set). Four of them write some answers differently in PG, so that WeBWorK
  grades them correctly: `arithmetic.rhm` and `sequence.rhm` (whole numbers
  and fractions of 1000 or more), `set.rhm` (unions without brackets around
  their parts) and `logic_forms.rhm` (propositions with their own context).
  The entries below give the reasons.

- **A paper to print: LaTeX and PDF output.** `rhema FILE -o OUT.tex` writes
  the same questions as a LaTeX document, and `-o OUT.pdf` compiles it with
  a TeX engine found on the machine (`pdflatex`, `xelatex`, `lualatex`,
  `tectonic`, or the one `RHEMA_LATEX` names). `--answers` adds an answer
  key on a last page and `--title` sets the title. A set keeps its labels
  and headings, a blank becomes a rule to write on, and a formula too wide
  for the line is scaled down to it. The same assignment and student give
  the same questions as the `.pg` file. An output with any other extension
  is WeBWorK PG, as before.
- **Seven question types scale with the budget.** `partial_fractions.rhm`,
  `taylor.rhm`, `inequality.rhm`, `partial_derivatives.rhm`,
  `row_reduction.rhm`, `base_conversion.rhm` and `definite_integral.rhm`
  refused every budget above 3. They now go on to 8, building the question
  from priced parts: more factors and constants, sums and products of
  series, sign charts of up to five factors, functions of two variables
  with sin, cos and e, matrices of up to six columns and null spaces of
  dimension two and three, sums and differences across number bases, and
  integrals of sums of pieces. Budgets 1 to 3 give the same questions as
  before, seed for seed. A budget above 8 is refused.
  `DIFFICULTY_BUDGET.md` section 12 has the prices and what a grammar
  written this way must get right.
- **Builtins**: `polynomial_truncate(p, n)`, the terms of a polynomial of
  degree at most `n`, and `matrix_null_space(A)`, the basis of a null space
  read off the reduced form, as the columns of a matrix.
- **Fixed**: the WeBWorK renderer of the Docker stack could restart for
  ever after Docker itself was restarted (exit code 140). Its process id
  file outlived the container, and a new process with the same id took
  itself for a running server. `compose.yml` now empties that file before
  the renderer starts.
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
- **Fixed**: a fraction answer whose numerator is 1000 or more accepted the
  neighbouring fractions, for the same reason: 4923/4 passed for 4922/4.
  Such an answer is now written
  `Compute("p/q")->cmp(tolType=>"absolute",tolerance=>1/(2q))`, half a step
  of its denominator; a decimal typed in its place must be right to within
  that. Smaller fractions stay `Formula('p/q')`. This changes the PG of
  `arithmetic.rhm` for its large answers, and of a few answers of
  `definite_integral.rhm` and `statistics.rhm`.
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
  Visual Studio Marketplace as `rhema.rhema-language` (a preview).
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
