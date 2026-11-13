# Design: answer blanks in text, and formulas beyond x

*Proposed and built on 2026-11-13, with the defaults of section 6; what was
built is described in `RHEMA_LANGUAGE_EXTENSIONS.md` section 8. A Chinese
version is in `RHEMA_ADDITIONS_DESIGN.zh.md`. It follows the four smaller
additions of section 7 there and comes before the fifth batch of question
types, which needs both parts.*

*Where the build differs from the text below: the variables declared for a
formula answer are those of every formula answer of its question, so that
its blanks accept the same names (3.1); `plain` also switches off the
hyperbolic functions, by disabling whole categories and enabling `sqrt` and
`abs` again (3.4); and a fraction in a formula is now bracketed as a
divisor and under a power, a mistake found on the way. Added after the
first grammars were written with it: `pg_variables`, by which a grammar
names the variables of its formula answers, so that an answer holding only
one of them is still entered in a blank that knows them all.*

## 1. What cannot be written today

1. **Forms with different numbers of blanks in one grammar.** The blanks of
   a question are fixed by its `prompt`, and a file has one prompt per
   question. So `analytic_geometry.rhm` asks for the centre *or* the radius
   of a circle, never both, and "find A and B" of a partial fraction would
   need a file of its own.
2. **A formula answer in any variable but x.** WeBWorK's Numeric context
   knows only `x`. `Formula('2*x*y+y^2')` is refused when the problem is
   compiled, so partial derivatives cannot be asked, although
   `differentiate(f, "y")` already works in the engine.
3. **π and exact trigonometric values.** Numbers are rationals and a
   formula has no constant π, so `5π/6` or `√3/2` cannot be an answer.
4. **An answer that must not repeat the question.** To "Evaluate
   sin(π/3)" WeBWorK accepts the answer `sin(pi/3)`. The same hole is
   already in the library: `exponential_log.rhm` asks for `log_5(625)` and
   WeBWorK accepts `log(625)/log(5)`.

## 2. Answer blanks in text

### 2.1 The proposal

Two builtins make a blank a value that is joined to text with `++`:

```
blank(VALUE)                 an answer blank graded against VALUE
blank_wide(VALUE, COLUMNS)   the same, with a width of its own
```

```rhema
Q -> "circle" nonzero_integer_between(-9, 9) nonzero_integer_between(-9, 9) integer_between(1, 9) when cost = 3 {
  cost = -3
  kind = "circle"
  let circle = ...   # the expanded equation, written as it is today
  text = "The circle [`" ++ circle ++ "`] has centre " ++ blank(point2($2.value, $3.value))
         ++ " and radius " ++ blank($4.value) ++ "."
}

prompt "{Q.text}"
```

Text joined with a blank is *text with blanks*. When a prompt hole
(`{Q.text}`, or `{name}` for a random or let) holds such a value, its text
and blanks go into the question in the order written. A form with one
blank and a form with three can then live in the same grammar, because
each form's own text says where its blanks are.

### 2.2 Rules

- A question needs at least one blank. The `answer` line is no longer
  required when the file calls `blank` somewhere; a question generated
  with no blank at all stops with "the question has no answer blank", as
  it does today.
- A question has its blanks in one place: an `answer` line, or `{answer
  ...}` in the prompt, or `blank(...)` in its text. A question that ends
  up with an `answer` line *and* blanks in its text is an error, reported
  with the production that made the text.
- Text with blanks can only be joined with `++` and passed to the prompt.
  `str`, a comparison, or a `*_latex` function given such a value stops
  with a message that says so.
- A blank cannot sit inside mathematics: PGML has no blank between
  `` [` `` and `` `] ``. The engine counts the delimiters before each blank
  and reports a blank placed inside them.
- `blank_wide` gives one blank its own width, which the language cannot
  do today (`RHEMA_LANGUAGE_EXTENSIONS.md`, "What this allows"); a plain
  `blank` takes the question's width.

### 2.3 What does not change

`{answer Q.attr}` in a prompt and the `answer` line keep working as they
do; every existing grammar is unchanged. A question already carries its
text and blanks as a list of pieces (`Rhema_engine.question.pieces`), which
the listing, the PG writer, the sets and the teacher workspace read, so
those need no change beyond accepting the new value.

## 3. Formulas beyond x

### 3.1 Any variables

No change to the language: `formula_variable("y")` and
`differentiate(f, "y")` exist. The change is in the PG writer. A formula
answer whose variables are not just `x` is written with a context of its
own that declares them:

```perl
do { my $c = Parser::Context->getCopy("Numeric");
     $c->variables->are(x=>"Real", y=>"Real"); Formula($c, "2*x*y+y^2") }
```

This is the rule the point value already follows: the answer carries its
context, so the grammar sets none and the question may sit in any context.
A formula in `x` alone is written as today, `Formula('...')`, so no
existing output changes.

One builtin is added, `formula_value(f)`: the number a formula without
variables comes to, so that a gradient at a point can be a vector of
numbers. It stops with a message when the formula still holds a variable
or is not rational.

### 3.2 π

`formula_pi()` is a new constant of formulas. It is written `pi` for
WeBWorK and `\pi` in LaTeX, and a rational multiple is written as a
fraction is read: `\pi`, `2\pi`, `\frac{5\pi}{6}`, `-\frac{\pi}{4}`.
Evaluation uses the floating-point value; arithmetic keeps it symbolic.

### 3.3 Exact values of sine, cosine and tangent

```
exact_sin(p, q)    sin(p π / q) as a formula without variables
exact_cos(p, q)
exact_tan(p, q)
```

for `q` in 1, 2, 3, 4, 6, the angles whose values a first course knows.
The result is one of 0, ±1/2, ±√2/2, ±√3/2, ±1, ±√3, ±√3/3. Another `q`,
or a tangent that is not defined, stops generation with a message; a
grammar avoids those by its choice of `p` and `q`.

### 3.4 An answer that must be worked out: `plain`

```
plain(VALUE)    VALUE as an answer in which functions are switched off
```

The answer is written with a context of its own in which the
trigonometric, inverse trigonometric, logarithm and exponential functions
are disabled; arithmetic, powers and `sqrt` stay. `sin(pi/3)` is then
refused as an answer to "Evaluate sin(π/3)", and `√3/2` (or its decimal
value) is accepted. `exponential_log.rhm` would use it for its
`log_value` form.

### 3.5 Left out of this round

Several solutions in one blank, such as "all solutions in [0, 2π)". With
section 2 a grammar asks for the smaller and the larger in two blanks. An
unordered list answer works in WeBWorK (probe 6 below) and can be added
later as a value of its own.

## 4. What was tried on the WeBWorK renderer

Each line is a PG document sent to the local renderer on 2026-11-13, with
right and wrong student answers.

| # | PG answer | Accepted | Rejected |
|---|---|---|---|
| 1 | `Formula('2*x*y+y^2')`, Numeric context | (the problem does not compile) | |
| 2 | the same formula in a context of its own with `x`, `y`; question in Numeric, Vector or Interval | `2*x*y+y^2`, `y*(2x+y)` | `2*x*y`, `2*x*y+x^2` |
| 3 | `sqrt(3)/2` in a context with `Trig` disabled | `sqrt(3)/2`, `3^(1/2)/2`, `0.8660254` | `sin(pi/3)`, `cos(pi/6)`, `1/2` |
| 4 | `Formula('sqrt(3)/2')`, plain Numeric | `sqrt(3)/2`, and also `sin(pi/3)` | |
| 5 | `Formula('5*pi/6')` | `5pi/6`, `5*pi/6`, `2.618` | `pi/6`, `150` |
| 6 | `List(Formula("pi/6"), Formula("5*pi/6"))` | both orders | one missing, one extra |
| 7 | three blanks in one question: a point, a number, a two-variable formula | each graded on its own | |
| 8 | two blanks with widths 3 and 30 | both graded | |

Tried while building: with `Trig`, `Hyperbolic` and `Numeric` disabled and
`sqrt` and `abs` enabled again, `4`, `2^2` and `sqrt(16)` are accepted for
4 and `log(625)/log(5)`, `ln(e^4)`, `exp(0)*4` and `asin(1)*8/pi` are
refused; a formula in `t` alone is graded with `t` declared. The project's
own PG reader is not in the way: its test reads back one arithmetic grammar
only, which has none of these answers.

## 5. Order of work

1. Blanks in text (section 2): a new value in the engine, two builtins,
   the checker's rule for `answer`, the delimiter check, tests, documents.
2. Formulas in any variables and `formula_value` (3.1).
3. π, the exact values and `plain` (3.2 to 3.4).

Each step is additive and is committed on its own. The fifth batch then
uses them: centre and radius of a circle and partial fractions (blanks),
partial derivatives and gradients (3.1), exact values and trigonometric
equations (3.2 to 3.4, with two blanks).

## 6. Decisions

The defaults below are what I would build unless you choose otherwise.

| Question | Default |
|---|---|
| Names of the two blank builtins | `blank`, `blank_wide` |
| An `answer` line and blanks in the text of one question | an error |
| Name of the "worked out" wrapper | `plain` |
| What `plain` disables | trigonometric, inverse trigonometric, logarithm, exponential; `sqrt` stays |
| Angles of the exact values | multiples of π/6 and π/4 only |
| Several solutions in one blank | not now; two blanks |
