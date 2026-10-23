# Language Extensions: include, import, a context per question, several blanks

*Four additions to the `.ag` language that let one file hold whatever
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

## What this allows

One file may now hold several question types that need different contexts,
questions with several parts, productions shared with other files, and
whole grammars from other files used side by side without renaming anything
in them. What it still cannot do: give one blank a width of its own, name a
question type (a file is one question), or describe a whole set of
questions; those are the next steps in `AG_MODULES_DESIGN.md`.
