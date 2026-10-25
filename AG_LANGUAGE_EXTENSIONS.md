# Language Extensions: include, import, named questions, sets, a context per question, several blanks

*Six additions to the `.ag` language that let one file hold whatever
question types its author wants. A Chinese version is in
`AG_LANGUAGE_EXTENSIONS.zh.md`; the language itself is described in
`AG_LANGUAGE_GUIDE.md`.*

## 1. `include "file.ag"`: reuse between files

```
include "polynomial_core.ag"

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

A file without `start`, `prompt` and `answer` is a **library**: `agcheck`
accepts it and says so, `agrun` refuses to generate from it, and the web
page leaves it out of the grammar list. `polynomial_core.ag` is one; it
holds the tree of factors that `factoring.ag`, `polynomial_expand.ag` and
`polynomial_forms.ag` build on, each adding its own question and, in the
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
exactly as before. `polynomial_forms.ag` shows one tree asked two ways,
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
and the blank follows the text as before. `sequence_parts.ag` asks for the
nth term and the sum of one sequence.

In the readable listing an inline blank shows as `[___]` and the answers
are listed in order; a generated question carries them as `answers`, with
`answer` still the first for the tools that read one.

## 4. `import "file.ag" as name`: modules

```
import "calculus.ag" as calc
import "boolean.ag" as bool

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
module. `derivative_or_boolean.ag` above is the shipped example;
`logic_forms.ag` imports `boolean.ag` and `boolean_equiv.ag`, which both
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
`calculus.ag`'s `attribute cost = 7`). The expressions are evaluated at the
parent, before the child exists: literals, the parent's inherited
attributes, the importer's randoms and lets, module values, builtins. The
value must be a whole number and may not be negative.

The parent's attribute name inside an argument means **this child's
share**: under `copy` the whole value, under `split` the part this child
would have received as a local nonterminal. So in
`M -> bool.E(cost = cost) "," laws.L(cost = cost + 1)` with
`attribute cost = 6 split`, the two modules spend 7 between them, and
`Ag_engine.consumption` on each subtree reports what that module spent. A
module's budget is its own: `calc.F` never sees the importer's `cost`, and
two grammars that price on different scales meet at the boundary, where the
importer writes the exchange rate (`cost + 2` above).

**One module per file.** A file imported twice, under two aliases or from
two importers, is one module: its randoms are drawn once per question and
both aliases see the same values (`a.p = b.p`). A module may import and
include files of its own; those are private to it (`forms.bool.E` is not a
name). A library (no `start`) can be imported like any grammar:
`import "polynomial_core.ag" as poly` and `poly.E(cost = 5)`. A file that
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
brought it in. `agcheck` lists the imports it resolved.

**include or import?** Include to extend, import to compose. A file may do
both: `factoring.ag` includes `polynomial_core.ag` to add a question to its
tree of factors; `derivative_or_boolean.ag` imports two whole grammars.

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

`calculus.ag` is the shipped example: `main` (start `Q`) draws a derivative
or an integral, `derivative` (start `D`) and `integral` (start `I`) ask one
form only, and the three share the forms `D` and `I` and the expression
grammar under them. A file whose questions are all blocks has no `main`;
the first block is then the default. A file with neither is a library.

```
agrun calculus.ag                                   main
agrun --question integral --set cost=5 calculus.ag  one named question
agcheck calculus.ag                                 lists the questions
```

`agcheck` lists every question with its start symbol and context when there
is more than one; the web page offers a question menu for such files. A
question is selected before `--set` is applied, so a block's starting
budgets can be overridden. Mistakes inside a block are reported with the
block's name: a missing `start`, `prompt` or `answer`, a start symbol
without rules, a prompt that names another symbol, a `context` or `width`
that is invalid, an attribute the file does not declare, a negative start,
anything declared twice, a block named `main`, two blocks with one name.

## 6. `set NAME { ... }`: a whole assignment in one file

```
import "calculus.ag" as calc
import "boolean.ag" as bool
import "boolean_equiv.ag" as laws

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
what budgets, in what order. `homework_set.ag` is the shipped example; a
file may hold several sets, beside its own questions or, as there, alone.

```
agrun --run homework homework_set.ag                      a sample, as a listing with budgets and means
agrun --run homework --student 2330026211 --pg homework_set.ag   that student's paper, one PG document
agrun --run quick --student 2330026211 --pg-dir out/ homework_set.ag
agcheck homework_set.ag                                   lists the sets
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
  This is the algorithm of `tools/ag_difficulty.py set`, moved into the
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

**Whose paper.** `--student ID` names the student and `--assignment NAME`
the assignment (default: the set's name); the same student gets the same
paper every time, another student or another assignment another one, and a
question added at the end of the set leaves the earlier ones as they were.
Nobody chooses or sees a seed: the variant is derived from the two names
inside the engine. Without `--student` the run is a sample. `--set`,
`--count` and `--question` do not apply with `--run`: the set carries its
own.

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

A file of imports and sets alone has no question of its own: `agrun` says
so and names the sets, and the web page leaves it out of the grammar list.

## What this allows

One file may now hold several question types that need different contexts,
questions with several parts, productions shared with other files, and
whole grammars from other files used side by side without renaming anything
in them, several named questions over one set of rules, and a whole
assignment described and generated from one file. What it still cannot do:
give one blank a width of its own, or let a grammar declare a coverage
constraint for sets ("each law once before any repeats"); see
`AG_MODULES_DESIGN.md` section 8.
