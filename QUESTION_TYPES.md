# Question Types

*Every grammar shipped in `generator/ag/`, what it asks, how its difficulty
budget is spent, and what WeBWorK context its answer needs. A Chinese
version is in `QUESTION_TYPES.zh.md`; the budget mechanism itself is
described in `DIFFICULTY_BUDGET.md`.*

Every grammar is a single `.ag` file: its shape, its prices, its wording
and its answer. The engine is the same for all of them, and a new type is a
new file, not a change to the engine. A file may hold several question
forms (`complex.ag` has four, `vector_expr.ag` four); each form is a `Q ->`
rule with its own text, answer and price, selected by weight, by a mode
attribute, or by the budget.

## Expressions: a recursive tree spends the budget

| grammar | asks for | the budget buys | default | context |
| --- | --- | --- | --- | --- |
| `arithmetic.ag` | the value of a four-operation expression | `+` 1, `-` 2, `*` 3, `/` 4; a number pays one per digit beyond its first | 12 | Numeric |
| `boolean.ag` | the truth value of a proposition in p, q, r under an assignment; propositions are the engine's Boolean type | and/or 2, conditional 4, biconditional and xor 6, a negated variable 1, a negated compound 3 | 10 | Numeric |
| `boolean_equiv.ag` | whether one of thirty laws, stated correctly or with a classic mistake, holds; decided by enumeration | the law 1–3, the parts as in `boolean.ag` | 6 | Numeric |
| `calculus.ag` | a derivative, or an antiderivative built by differentiating | sum 1, product 3, quotient 4; a power or function of a leaf 1, of a compound 3 (chain rule); an integral pays 2 up front | 7 | Numeric |
| `complex.ag` | a complex expression, its conjugate, a modulus, a power of `i` | sum 1, product 3; modulus and power of `i` are fixed at 2 and 1 | 4 | Complex |
| `set.ag` | a set expression over three given sets | union 1, intersection and difference 2, an interval leaf 1 | 7 | Interval |
| `polynomial_expand.ag` | the expansion of a product of factors | product 2, square 1, cube 2, factor `x + b` 0, `ax + b` 1, quadratic 2 | 5 | Numeric |
| `factoring.ag` | the factored form of a polynomial built from its factors | the same prices as the expansion; the factors are distinct and primitive | 5 | PolynomialFactors |
| `vector_expr.ag` | a vector expression, or a dot product, cross product or norm of expressions | sum 1, a multiple of a bracket 1; dot 2, norm 2, cross 4 on top | 4 | Vector |
| `linear_equation.ag` | the solution of a linear equation whose left side is built from a chosen root | sum 1, a multiple of a bracket 1, a fraction 2 | 5 | Numeric |
| `polynomial_forms.ag` | the same tree of factors, expanded or factored, each form in its own context | as `factoring.ag` | 5 | Numeric / PolynomialFactors |
| `sequence_parts.ag` | one sequence, two blanks: its nth term and the sum of its first n terms | arithmetic 2, geometric 3 (fixed) | 2 | Numeric |
| `derivative_or_boolean.ag` | a derivative or a Boolean evaluation, from the two grammars included whole | each grammar's own prices | 8 | Numeric |

## Fixed forms: each form is a price

| grammar | forms by price | default | context |
| --- | --- | --- | --- |
| `vector.ag` | 1 parallel vector; 2 dot product, norm, same direction; 3 unit vector; 4 cross product | 2 | Vector |
| `sequence.ag` | 1 arithmetic nth term; 2 geometric nth term, arithmetic sum; 3 geometric sum | 2 | Numeric |
| `library_linear.ag` | 2 one bracket; 3 brackets on both sides; 4 a fraction | 3 | Numeric |
| `library_quadratic.ag` | 2 two integer roots; 3 repeated root, no real root; 4 two rational roots | 3 | Interval |
| `library_polynomial.ag` | 1 evaluation; 2 degree; 3 expansion, coefficient; 4 derivative | 3 | Numeric |
| `library_formula.ag` | 2 composition; 3 logarithm, radical, tangent; 4 quotient, combined | 3 | Numeric |

## The five general types added on this branch

**Factoring** (`factoring.ag`). The factors come first: primitive linear
factors `ax + b` (gcd 1, `a` in 1..3), squares and cubes of them, and
irreducible quadratics `x^2 + c`. The Polynomial library multiplies them
out; the student sees the expansion and gives the factors. Every factor is
distinct (a bit mask per factor, disjoint across a product), so the
factored form is the complete one. The answer is a product of factors in
WeBWorK's `PolynomialFactors` context, which refuses the expanded form; the
`.pg` file loads `contextPolynomialFactors.pl` for it. The least budget is 1.

```
cost 2   x^2 + x - 12             (x-3)(x+4)
cost 5   x^5 - 3x^4 + 14x^3 - 42x^2 + 49x - 147   (x-3)(x^2+7)^2
```

**Expansion** (`polynomial_expand.ag`). The same factors read the other
way, with quadratics `ax^2 + bx + c` as well; the answer is the expanded
polynomial. A linear factor appears once in a product; twice is a power.

**Calculus, extended** (`calculus.ag`). Derivative questions may now use
`ln`, `sqrt`, `tan` and quotients, each on a leaf (1) or a compound (3 plus
the compound), the quotient at 4 plus both sides. `ln` and `sqrt` take a
leaf with a positive coefficient. Integral questions keep to sums,
products, powers, `sin`, `cos` and `exp`, whose reverse is within the
course's methods; the `advanced` attribute switches the rest off for them.
Powers do not nest, and `e^{...}` under a power is bracketed in LaTeX.

**Vector expressions** (`vector_expr.ag`). Sums, differences and multiples
of `u`, `v`, `w`, asked for as they are (price 0 on top), under a norm (2),
a dot product (2) or a cross product (4). Within one sum each vector
appears once, so nothing cancels; a bracketed multiple starts a new sum,
a multiple is never taken of a multiple, and a sum used as an
operand of a dot or cross product is bracketed.

```
cost 4   ||w - u - v||
cost 7   5(u + 3(w - u)) . (w + v)
```

**Linear equations** (`linear_equation.ag`). The root is chosen first. The
left side is a tree of sums, bracketed multiples and fractions in `x`,
which is linear, so its slope and intercept are computed alongside it; the
right side is `cx + k` with `c` different from the slope and `k` chosen so
both sides agree at the root. A chain of sums holds at most one number and
two `x` terms, a sum never folds to zero, and a fraction is never taken of
a fraction.

```
cost 2   4(x + 3x) = 17x - 2                              x = 2
cost 8   (5(8 + x) - 5*5(3 + 2x)) / 2 = -(39/2 + 43/2 x)  x = 2
```

## What a user can write in one file

Several question forms sharing the question-level randoms, as every grammar
with more than one `Q ->` rule shows; forms that need different WeBWorK
contexts (`pg_context`); questions with several answer blanks (`{answer
...}` in the prompt); and productions shared with other files (`include`).
`polynomial_core.ag` is a library of productions with no question of its
own; `factoring.ag`, `polynomial_expand.ag` and `polynomial_forms.ag` include
it. See `AG_LANGUAGE_EXTENSIONS.md`.
