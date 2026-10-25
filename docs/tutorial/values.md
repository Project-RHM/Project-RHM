# Values and answers

The answer to a differentiation question is a function, not a number. Rhema
computes it, symbolically, from the same object the question shows.

```rhema
--8<-- "values.rhm"
```

```text
$ rhema run values.rhm --count 3
 1. Differentiate [`f(x) = 5 \cdot x^{3} - 8 \cdot x`] with respect to [`x`].
    answer: Formula(5*3*x^2-8)
 2. Differentiate [`f(x) = 6 \cdot x^{6} - 8 \cdot x`] with respect to [`x`].
    answer: Formula(6*6*x^5-8)
 3. Differentiate [`f(x) = 5 \cdot x^{4} + 5 \cdot x`] with respect to [`x`].
    answer: Formula(5*4*x^3+5)
```

## Values drawn once per question

```rhema
random a = integer_between(2, 9)
random n = integer_between(2, 6)
random b = nonzero_integer_between(-9, 9)
```

A `random` is drawn once for each question, before any tree is built, and
has the same value everywhere it is used. Use one when several parts of a
question must agree: the coefficients here, or the truth values of `p`, `q`
and `r` in a logic question, which must be the same at every occurrence.

`random NAME = boolean` draws true or false; the other draws are the four
generators `integer(DIGITS)`, `nonzero_integer(DIGITS)`,
`integer_between(LOW, HIGH)` and `nonzero_integer_between(LOW, HIGH)`, with
whole-number literals as arguments.

## Values computed once per question

```rhema
let x = formula_variable("x")
let f = formula_add(formula_multiply(formula_constant(a), formula_power(x, n)),
                    formula_multiply(formula_constant(b), x))
let f_latex = formula_latex(f)
```

A `let` is computed once per question, from the randoms and the lets above
it. It may call any builtin function. `{f_latex}` in the prompt is replaced
by its value, just as `{E.latex}` was replaced by an attribute.

## Types of value

`f` is not text: it is a *formula*, a value the engine can differentiate,
substitute into, compare and write out as LaTeX or for WeBWorK. Every
attribute, random and let holds one of these:

| Value | Made by | Graded by WeBWorK as |
|---|---|---|
| Number | literals, arithmetic, generators | an exact number, or a fraction |
| Text | strings, `++`, `str`, the `*_latex` functions | (not an answer) |
| Truth | comparisons, `and`, `or`, `not`, `random ... = boolean` | 1 or 0 |
| Formula | `formula_*`, `differentiate` | a formula, by equivalence |
| Polynomial | `polynomial_*` | a formula |
| Equation | `equation_*` | not directly: `equation_solution_set` gives a Set |
| Boolean | `bool_*` | a proposition (Boolean context) |
| Matrix | `matrix_*` | a matrix (Matrix context) |
| Set | `set_*` | an interval or union (Interval context) |
| Vector | `vector_*` | a vector (Vector context) |
| Complex | `complex` | a complex number (Complex context) |

The [builtin functions](../reference/builtins.md) are listed by value type.
A function given the wrong kind of value stops generation with a message
that names both:

```text
values.rhm: error: formula_power expected a number but received "Formula(3)"
```

(This is what happens if the exponent is written `formula_constant(n)`:
`formula_power` takes its exponent as a plain number.)

## The answer is computed, not typed

```rhema
Q -> "derivative" {
  derivative = differentiate(f, "x")
}
answer Q.derivative
```

The prompt shows `f`; the answer is `differentiate(f, "x")`. Both come from
the one value `f`, so a question cannot be printed with one function and
graded against the derivative of another.

The answer is not simplified (`5*3*x^2-8` rather than `15*x^2-8`), and it
does not need to be: WeBWorK compares formulas by evaluating them, so a
student who types `15x^2 - 8` is marked right.

`Q -> "derivative"` is a production whose only symbol is a quoted word. It
gives the question a tree to hang `derivative` on; a file needs a start
symbol even when everything interesting happens in `let`s.

**Next:** chapter 4 gives one question several answer blanks.
