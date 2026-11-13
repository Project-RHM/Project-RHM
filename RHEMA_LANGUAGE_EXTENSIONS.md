# Language Extensions: include, import, named questions, sets, a context per question, several blanks

*Six additions to the Rhema language that let one file hold whatever
question types its author wants, four smaller ones (section 7), and blanks
in text with formulas beyond x (section 8). A Chinese version is in
`RHEMA_LANGUAGE_EXTENSIONS.zh.md`; the language itself is described in
`RHEMA_LANGUAGE_GUIDE.md`.*

## 1. `include "file.rhm"`: reuse between files

```
include "polynomial_core.rhm"

context "PolynomialFactors"
synth text on Q
synth answer_value on Q
start Q
Q -> E { ... }
prompt "{Q.text}"
answer Q.answer_value
```

The loader reads the included file (relative to the including one, and
recursively) and places its declarations before the including file's own.
Rules, `synth` and `attribute` declarations, randoms, lets and precedences
add up; an identical `synth` or `attribute` declared by both files is kept
once. Of the declarations a grammar makes once — `start`, `context`,
`prompt`, `answer`, `width` — the including file's own wins, so a grammar
may include another grammar and re-ask its question with a new prompt. A
file that includes itself, directly or through others, is refused, and an
error inside an included file is reported with that file's name.

A file without `start`, `prompt` and `answer` is a **library**: `rhema check`
accepts it and says so, `rhema` refuses to generate from it, and the web
page leaves it out of the grammar list. `polynomial_core.rhm` is one; it
holds the tree of factors that `factoring.rhm`, `polynomial_expand.rhm` and
`polynomial_forms.rhm` build on, each adding its own question and, in the
expansion's case, one extra factor rule.

An `attribute` declared by the including file wins over the included ones,
and when two included files declare the same attribute the first wins, so
two grammars with different default budgets can be included together and
the including file can set the budget both spend. Randoms and lets with the
same name in two files are still an error.

Nonterminals are shared by name, so two grammars that both use `E` cannot
be included into one file as they are, and two files with a random of the
same name clash. `include` is the tool for **extending** a grammar: adding
rules to its nonterminals, re-asking its question. To put two grammars side
by side, **import** them (section 4): each keeps its names behind an alias.

## 2. A context and a width per question

A grammar whose start symbol computes the synthesized attribute
`pg_context` gives each question its own WeBWorK context; `pg_width` does
the same for the answer width.

```
synth pg_context on Q

Q -> E "expand" { pg_context = "Numeric"  ... answer_value = $1.poly }
Q -> E "factor" { pg_context = "PolynomialFactors"  ... answer_value = $1.factored }
```

The `.pg` file loads the macros of every context it uses and writes
questions that share a context in one PGML block, switching `Context()`
between blocks. A file whose questions all use the file's `context` reads
exactly as before. `polynomial_forms.rhm` shows one tree asked two ways,
each in its own context.

## 3. Several answer blanks: `{answer ...}` in the prompt

```
prompt "{Q.text}
(a) Find [`a_{{{index_text}}}`]: {answer Q.nth}
(b) Find the sum [`S_{{{index_text}}}`]: {answer Q.sum}"
```

`{answer Q.nth}` places an answer blank at that point of the prompt, graded
against that attribute of the start symbol; `{answer total}` grades against
a random or let. Each blank is graded on its own in WeBWorK, which is how
a question in parts (a), (b), (c) is written. A prompt that places its own
blanks has no trailing `answer` declaration; one that does not keeps it,
and the blank follows the text as before. `sequence_parts.rhm` asks for the
nth term and the sum of one sequence.

In the readable listing an inline blank shows as `[___]` and the answers
are listed in order; a generated question carries them as `answers`, with
`answer` still the first for the tools that read one.

## 4. `import "file.rhm" as name`: modules

```
import "calculus.rhm" as calc
import "boolean.rhm" as bool

attribute cost = 8 copy
synth kind on M  synth text on M  synth answer_value on M
start M

M -> calc.F(cost = cost) "derivative" {
  kind = "derivative"
  text = "Differentiate [`f(x) = " ++ $1.latex ++ "`]."
  answer_value = differentiate($1.formula, "x")
}
M -> bool.E(cost = cost + 2) "boolean" {
  kind = "boolean"
  text = "Evaluate [`" ++ bool_latex($1.f) ++ "`] when " ++ bool.given ++ "."
  answer_value = bool_evaluate($1.f, bool.names, bool.mask)
}

prompt "{M.text}"
answer M.answer_value
```

`import` brings another file in as a **module**: the file is loaded and
checked on its own, and everything it declares is reached through the
alias, so nothing in it can clash with the importer or with another
module. `derivative_or_boolean.rhm` above is the shipped example;
`logic_forms.rhm` imports `boolean.rhm` and `boolean_equiv.rhm`, which both
have a `Q`, an `E`, a `cost` and a `phrasing`, and uses both.

**Names.** A module's nonterminal is written `calc.F` on the right-hand
side of a rule; its randoms and lets are `bool.given`, `bool.mask` in
expressions and `{bool.given}` or `{answer bool.total}` in a prompt. Its
synthesized attributes need no alias: `$1.latex` is read from the child,
and the checker knows the child is `calc.F`, so it checks the name against
that module (`$1 is calc.F, which does not carry 'value'`). Inherited
attributes are named only in arguments. The module's precedence table and
rules are not visible. Builtins are global and never qualified. Inside the
module its own names stay unqualified, so no existing file changes meaning.

**Arguments.** `calc.F(cost = cost - 1, advanced = 1)` gives the module's
inherited attributes their starting values for that subtree; any not named
take the module's declared defaults (`calc.F` alone starts at
`calculus.rhm`'s `attribute cost = 7`). The expressions are evaluated at the
parent, before the child exists: literals, the parent's inherited
attributes, the importer's randoms and lets, module values, builtins. The
value must be a whole number and may not be negative.

The parent's attribute name inside an argument means **this child's
share**: under `copy` the whole value, under `split` the part this child
would have received as a local nonterminal. So in
`M -> bool.E(cost = cost) "," laws.L(cost = cost + 1)` with
`attribute cost = 6 split`, the two modules spend 7 between them, and
`Rhema_engine.consumption` on each subtree reports what that module spent. A
module's budget is its own: `calc.F` never sees the importer's `cost`, and
two grammars that price on different scales meet at the boundary, where the
importer writes the exchange rate (`cost + 2` above).

**One module per file.** A file imported twice, under two aliases or from
two importers, is one module: its randoms are drawn once per question and
both aliases see the same values (`a.p = b.p`). A module may import and
include files of its own; those are private to it (`forms.bool.E` is not a
name). A library (no `start`) can be imported like any grammar:
`import "polynomial_core.rhm" as poly` and `poly.E(cost = 5)`. A file that
imports itself, directly or through others, is refused with the chain of
files.

**Brackets.** The importer's precedence table says nothing about a module's
operators, so a module subtree is an atom to the importer: `infix()` puts no
brackets around it. A rule that embeds `calc.F` in a larger expression
writes the brackets itself (`"(" ++ $1.latex ++ ")"`) or uses an attribute
the module provides for the purpose.

**Errors** are reported at the importer: unknown alias, a nonterminal the
module does not have, an argument naming an attribute the module does not
declare or set twice, a synthesized attribute the module child does not
carry, a random or let the module does not have, two imports with one
alias, an import cycle. An error inside the module itself comes with the
module's file name, after a line at the `import` saying which import
brought it in. `rhema list` shows the imports it resolved.

**include or import?** Include to extend, import to compose. A file may do
both: `factoring.rhm` includes `polynomial_core.rhm` to add a question to its
tree of factors; `derivative_or_boolean.rhm` imports two whole grammars.

## 5. `question NAME { ... }`: several named questions in one file

```
start Q
prompt "{Q.text}"
answer Q.answer_value
width 24

question derivative {
  start D
  prompt "{D.text}"
  answer D.answer_value
}

question integral {
  start I
  prompt "{I.text}"
  answer I.answer_value
  cost = 7
}
```

A file may ask more than one question of its rules. The file-level `start`,
`prompt`, `answer`, `context` and `width` form the question **`main`**;
each `question NAME { ... }` block adds another, with its own start symbol,
prompt and answer, and optionally its own `context` and `width`. A block
that leaves `context` or `width` out takes the file-level ones. All the
questions of a file share its rules, attributes, randoms and lets: they
differ only in where they start and how they ask.

A block may also start the inherited attributes elsewhere for its root:
`cost = 7` means this question begins with that budget, whatever the
`attribute` line says; `--set` still overrides it from outside. Only the
file's inherited attributes may be set, and not below zero.

`calculus.rhm` is the shipped example: `main` (start `Q`) draws a derivative
or an integral, `derivative` (start `D`) and `integral` (start `I`) ask one
form only, and the three share the forms `D` and `I` and the expression
grammar under them. A file whose questions are all blocks has no `main`;
the first block is then the default. A file with neither is a library.

```
rhema run calculus.rhm                                   main
rhema run calculus.rhm --question integral --set cost=5  one named question
rhema list calculus.rhm                                  lists the questions
```

`rhema list` shows every question with its start symbol and context when there
is more than one; the web page offers a question menu for such files. A
question is selected before `--set` is applied, so a block's starting
budgets can be overridden. Mistakes inside a block are reported with the
block's name: a missing `start`, `prompt` or `answer`, a start symbol
without rules, a prompt that names another symbol, a `context` or `width`
that is invalid, an attribute the file does not declare, a negative start,
anything declared twice, a block named `main`, two blocks with one name.

## 6. `set NAME { ... }`: a whole assignment in one file

```
import "calculus.rhm" as calc
import "boolean.rhm" as bool
import "boolean_equiv.rhm" as laws

set homework {
  part "Differentiation"
    3 of calc.derivative(cost ~ 6 spread 2 low 2)
    1 of calc.integral(cost in {5, 7})
  part "Propositional logic"
    3 of bool.main(cost in {8, 10, 12})
    2 of laws.main(cost = 6)
  part "Mixed"
    2 of any(forms.main(cost = 6), calc.derivative(cost = 8))
  distinct
  balanced
  ordered
}
```

A `set` describes an assignment: which questions, how many of each, with
what budgets, in what order. `homework_set.rhm` is the shipped example; a
file may hold several sets, beside its own questions or, as there, alone.

```
rhema run homework_set.rhm --run homework             the assignment, as a listing with budgets and means
rhema homework_set.rhm --run homework                 the same, compiled to homework.pg
rhema homework_set.rhm --run homework --student 2330026211 -o hw_2330026211.pg   one student's own paper
rhema homework_set.rhm --run quick --pg-dir out/      one .pg file per question
rhema list homework_set.rhm                           lists the sets
```

**Entries.** `N of QUESTION(draws)` asks for N questions of one type:
`main` or a block of this file, or `alias.name` from an imported module.
`N of any(Q1(...), Q2(...))` draws each of the N from the listed types
evenly. The draws give the starting values of the question's inherited
attributes, three ways:

- `cost = 5`: every question of the entry starts there.
- `cost in {8, 10, 12}`: each question draws one of the values; the list is
  used evenly, every value once before any repeats.
- `cost ~ 6 spread 2`: the budgets are drawn around the mean and adjusted
  so that the entry's mean is exactly 6 (`low 2` keeps every budget at or
  above 2; `allowed {4, 6, 8}` restricts the draw to those values, for a
  grammar of fixed forms, and the mean is then as close as they permit).
  This is the algorithm of `tools/rhema_difficulty.py set`, moved into the
  language: the expectation method of difficulty control lives here.

**Parts.** `part "Heading"` opens a part; the entries that follow are
lettered under one number, `1(a)`, `1(b)`, with the heading printed before
them. A set without `part` lines is flat: each question has its own number.

**Constraints**, each one word: `distinct` refuses a question whose tree has
the shape of an earlier one (rules used, leaves erased: 3 + 4 and 7 + 2 are
one shape); `balanced` refuses a third equal coded answer in a row (true /
false, or a one-digit code); `ordered` puts the questions of a part in order
of total budget, easier first. A constraint that cannot be met -- two
copies of a one-rule question under `distinct` -- is reported after a
bounded number of attempts, naming the question.

**One assignment, one paper.** The set is the assignment, and generating it
gives the same paper every time: `rhema homework_set.rhm --run homework`
today and next month are the same questions. `--assignment NAME` names it
otherwise. A question added at the end of the set leaves the earlier ones as
they were. Nobody chooses or sees a seed: the variant is derived from the
assignment's name inside the engine. `--student ID` is optional: with it the
paper is that student's own, the same every time and different from the
other students' and from the assignment's single paper. `--set`, `--count`
and `--question` do not apply with `--run`: the set carries its own.

**Output.** The listing shows each question with its type and budgets, and
ends with the mean of each budget per part. `--pg` writes one document:
headings as paragraphs, `1(a).` before each prompt, one PGML block per run
of equal contexts with `Context()` switched between. `--pg-dir` writes one
`.pg` file per question.

**Words, not keywords.** Only `set` is reserved. `part`, `of`, `any`, `in`,
`spread`, `low`, `allowed`, `distinct`, `balanced`, `ordered` are ordinary
identifiers that mean something inside a set block, so a grammar may still
call an attribute `low`; a wrong word is reported as the word expected there.

**Errors** are reported at the set: a question the file or module does not
have, an alias not imported, an attribute the grammar does not declare or
drawn twice, a negative value, a count of zero, a set with no entries, two
sets with one name, a constraint said twice.

A file of imports and sets alone has no question of its own: `rhema` says
so and names the sets, and the web page leaves it out of the grammar list.

## 7. Smaller additions: truth literals, local names, points, matrices of any shape

Four additions that change no existing grammar and remove workarounds the
library had collected.

**`true` and `false`** are the two truth values, where a grammar used to
write `0 = 1`. Both are reserved words.

```
answer_value = set_interval($2.first, $2.second, false, false)
```

**A local name in a production**, `let NAME = EXPR` inside the braces. It is
computed where it is written, after the children exist, and the lines below
it may use it. The node does not carry it: no `synth` declaration, and no
other production sees it. Before this, a value needed twice was written out
twice or moved into a helper nonterminal.

```
Q -> "line_two_points" P P when cost = 2 {
  cost = -2
  let slope = ($3.y - $2.y) / ($3.x - $2.x)
  answer_value = polynomial_linear(slope, $2.y - $2.x * slope, "x")
  ...
}
```

The name must be new. A local name that would hide an inherited attribute,
a synthesized attribute, a random or a file-level `let`, or that is given
twice in one production, is refused, and so is a reserved word (`left`,
`width`). A guard, a budget update and a generator's arguments are
evaluated before the children exist, so they cannot use it. The file-level
`let` is unchanged: it is computed once per question, before any tree.

**A point** is a value: `point2(x, y)` and `point3(x, y, z)`, with
`point_latex`. As an answer it is written to PG as a Point object that
carries WeBWorK's Point context with it, so the student enters `(3, -2)`
and it is graded as a point whatever context the question is in. A grammar
does not set `pg_context` for it; `analytic_geometry.rhm` mixes numbers,
formulas and points in one context.

**Matrices of any shape.** `matrix_row(v)` and `matrix_column(v)` turn a
vector into a matrix of one row or one column; `matrix_stack(A, B)` puts
`A` above `B` and `matrix_augment(A, B)` puts `B` to the right of `A`, so
an augmented matrix `[A | b]` is
`matrix_augment(A, matrix_column(b))`. `matrix_rows` and `matrix_columns`
give the shape. `matrix_rref` is the reduced row echelon form, computed by
Gauss-Jordan elimination on exact rationals, and `matrix_rank` the number
of its pivots.

## 8. Blanks in text, and formulas beyond x

The proposal and what was tried on WeBWorK are in
`RHEMA_ADDITIONS_DESIGN.md`; this is what was built.

**Blanks in text.** `blank(VALUE)` is an answer blank that is joined to
text with `++`, and `blank_wide(VALUE, COLUMNS)` one with a width of its
own. A production writes its blanks into its own text, and a prompt hole
that holds such text brings the blanks into the question:

```
Q -> "circle" nonzero_integer_between(-9, 9) nonzero_integer_between(-9, 9) integer_between(1, 9) when cost = 3 {
  cost = -3
  ...
  text = "Find the centre and the radius of the circle [`...`]. Centre: "
         ++ blank(point2($2.value, $3.value)) ++ " Radius: " ++ blank($4.value)
}

prompt "{Q.text}"
```

Forms with one blank and forms with several can now share a grammar;
before, the blanks were fixed by the prompt, one prompt per question. A
file whose rules or lets call `blank` needs no `answer` line. Refused: a
question that ends up with no blank; an `answer` line together with blanks
in the text; text with blanks given to anything but `++` and the prompt; a
blank inside mathematics (between `` [` `` and `` `] ``).
`{answer ...}` in a prompt and the `answer` line are unchanged.

**Formulas in any variables.** `formula_variable("y")` and
`differentiate(f, "y")` were always there, but WeBWorK's Numeric context
knows only `x`, so such an answer did not compile. A formula answer with
other variables is now written with a context of its own that declares
them; the variables of all the formula answers of one question are
declared together, so its blanks accept the same names. A formula in `x`
alone is written as before. `formula_value(f)` is the exact number a
formula without variables comes to.

A grammar may name the variables itself: `pg_variables`, text such as
`"x y"`, as a `let` of the file or as an attribute the start symbol
computes for each question. Every formula answer is then declared in all of
them. Without it an answer that comes to `6y` would be entered in a blank
that does not know `x`, and a student who typed one would be told that
instead of being marked wrong. `partial_derivatives.rhm` declares `"x y"`.

**Propositions in any variables.** A proposition answer had the same fault:
it was written for the Boolean context in force, and the Boolean context of
`contextBoolean.pl` knows `p` and `q` alone, so WeBWorK could not read an
answer that holds `r` ("Variable 'r' is not defined in this context"). Most
rewriting questions of `logic_forms.rhm` were affected. A proposition answer
is now written with a copy of the Boolean context that declares its
variables, those of the other proposition answers of the question, and
those named by `pg_variables`. It carries that context, so the grammar need
not set `context "Boolean"`; the compiled file loads `contextBoolean.pl`
whenever a document holds a proposition answer.

**π and exact values.** `formula_pi()` is the constant, written `pi` for
WeBWorK and `\pi`, `2\pi`, `\frac{5\pi}{6}` in LaTeX. `exact_sin(p, q)`,
`exact_cos(p, q)` and `exact_tan(p, q)` give the value at `p π / q` as a
formula such as `sqrt(3)/2`, for multiples of π/6 and π/4.

**Answers that must be worked out.** `plain(VALUE)` is a number or formula
graded with the trigonometric, hyperbolic, logarithm and exponential
functions switched off (`sqrt` and `abs` stay). Without it WeBWorK accepts
`sin(pi/3)` as the value of sin(π/3), and accepted `log(625)/log(5)` for
log₅(625) in `exponential_log.rhm`, which now uses `plain`.

**Whole numbers graded exactly.** WeBWorK compares numbers with a relative
tolerance of one part in a thousand. Measured on the renderer, it tells a
whole number from its neighbours up to 1000 and not above: it accepts 5041
for 5040 and 10110 for 10100. A whole-number answer of 1000 or more (or
-1000 or less) is now written
`Real(n)->cmp(tolType=>"absolute",tolerance=>0.5)`, an absolute tolerance of
half a unit, so no other whole number passes; a smaller one stays a bare
number, and every document without such an answer is written as before.
In the library this reaches `arithmetic.rhm`, `counting.rhm`,
`sequence.rhm` and `series.rhm`, whose large answers used to accept their
neighbours. `exactly(N)` asks for the same comparison whatever the size;
`base_conversion.rhm` uses it for a number written in binary or octal.

**A correction.** A fraction in a formula is written as a quotient, `2/3`,
and is now bracketed where a quotient must be: `x/(2/3)` and `(2/3)^2`
were written `x/2/3` and `2/3^2`. No library grammar produced either.

## What this allows

One file may now hold several question types that need different contexts,
questions with several parts, productions shared with other files, and
whole grammars from other files used side by side without renaming anything
in them, several named questions over one set of rules, a whole assignment
described and generated from one file, forms with different numbers of
blanks, and a blank with a width of its own. What it still cannot do: ask
for several solutions in one blank, or let a grammar declare a coverage
constraint for sets ("each law once before any repeats"); see
`RHEMA_MODULES_DESIGN.md` section 8.
