# Prompts, contexts, blanks

A question can have several parts, each with its own answer blank. This one
asks two things about one sequence.

```rhema
--8<-- "prompts.rhm"
```

```text
$ rhema run prompts.rhm --count 1
 1. An arithmetic sequence has first term [`a_1 = -2`] and common
difference [`d = 1`].

(a) Find [`a_{12}`]. [___]

(b) Find the sum of its first [`12`] terms. [___]
    answers: 9; 42
```

Compiled, each `{answer ...}` becomes a WeBWorK answer blank graded on its
own:

```text
$ rhema prompts.rhm --count 1 -o -
DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");

BEGIN_PGML
An arithmetic sequence has first term [`a_1 = -2`] and common
difference [`d = 1`].

(a) Find [`a_{12}`]. [_____]{9}

(b) Find the sum of its first [`12`] terms. [_____]{42}
END_PGML
ENDDOCUMENT();
```

## What a prompt may contain

A prompt is a string, and a string may run over several lines; the line
breaks are kept. Inside it, braces mark the places Rhema fills in:

| Written | Becomes |
|---|---|
| `{E.latex}` | an attribute of the start symbol |
| `{first}` | a random or a let |
| `{answer E.value}` | an answer blank graded against an attribute of the start symbol |
| `{answer sum}` | an answer blank graded against a random or a let |
| `{{` and `}}` | a literal `{` and `}` |
| `{calc.given}` | a random or let of an imported module (chapter 6) |

Everything else is passed to WeBWorK as written. Prompts are PGML, so
``[`...`]`` is mathematics and a blank line starts a new paragraph.

The doubled braces matter in LaTeX. `a_{12}` needs braces around `12`, and
`n` must be filled in between them, so the prompt says `a_{{{n}}}`: a literal
`{`, then the value of `n`, then a literal `}`.

Inside a string only two escapes exist, `\"` and `\\`. Every other backslash
is kept as it is, so LaTeX such as `\cdot`, `\to` and `\neg` can be written
directly.

## One blank or several

A file with a single answer uses `answer`, as in the earlier chapters, and
the blank goes after the prompt. A file that places its blanks with
`{answer ...}` leaves `answer` out; writing both is an error, because it
would not be clear where the blank goes.

## Contexts

WeBWorK grades an answer according to a *context*: `Numeric` for numbers and
formulas, `Complex`, `Interval`, `Vector`, `Matrix`, `PolynomialFactors` for
a polynomial that must be factored, `Boolean` for propositions. A file names
the context its questions need:

```rhema
context "Interval"
```

The default is `Numeric`. The compiled file selects the context, and loads
the macro file a context needs (`contextPolynomialFactors.pl`,
`contextBoolean.pl`) when it is one that WeBWorK does not load by default.

When the forms of one question type need different contexts, such as a
polynomial to expand (`Numeric`) and one to factor (`PolynomialFactors`),
the start symbol can compute the context itself, as the library's
`polynomial_forms.rhm` does:

```rhema
synth pg_context on Q

Q -> E "expand" { pg_context = "Numeric"            ... }
Q -> E "factor" { pg_context = "PolynomialFactors"  ... }
```

`pg_context` and `pg_width` (the width of the answer box) are reserved
names: computed by the start symbol, they apply to each question
separately, and the compiled document switches context between questions
that need different ones. `width 30` at the top level sets one width for
every blank.

**Next:** chapter 5 asks the parts of this question separately, from the
same file.
