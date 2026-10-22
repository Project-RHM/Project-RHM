# Language Extensions: include, a context per question, several blanks

*Three additions to the `.ag` language that let one file hold whatever
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
be included into one file as they are. A library should use nonterminal
names of its own, and a grammar meant to be included should declare its
synthesized attributes per nonterminal (`synth value on E`), since an
unscoped `synth value` asks every nonterminal of the including file to
compute it. The shipped grammars are written that way; the pairs `F`, `T`
(calculus) and `E`, `V` (boolean) do not clash, and
`derivative_or_boolean.ag` includes both grammars whole and asks one
question of either:

```
include "calculus.ag"
include "boolean.ag"
attribute cost = 8 split
synth kind on M  synth text on M  synth answer_value on M
start M
M -> F "derivative" { ... answer_value = differentiate($1.formula, "x") }
M -> E "boolean"    { ... answer_value = $1.value }
prompt "{M.text}"
answer M.answer_value
```

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

## What this allows

One file may now hold several question types that need different contexts,
questions with several parts, and productions shared with other files. What
it still cannot do: give one blank a width of its own, or include two
grammars whose nonterminals share names.
