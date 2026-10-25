# Question Types

*Every grammar shipped in `generator/stdlib/`, what it asks, how its difficulty
budget is spent, and what WeBWorK context its answer needs. A Chinese
version is in `QUESTION_TYPES.zh.md`; the budget mechanism itself is
described in `DIFFICULTY_BUDGET.md`.*

Every grammar is a single `.rhm` file: its shape, its prices, its wording
and its answer. The engine is the same for all of them, and a new type is a
new file, not a change to the engine. A file may hold several question
forms (`complex.rhm` has four, `vector_expr.rhm` four); each form is a `Q ->`
rule with its own text, answer and price, selected by weight, by a mode
attribute, or by the budget.

## Expressions: a recursive tree spends the budget

| grammar | asks for | the budget buys | default | context |
| --- | --- | --- | --- | --- |
| `arithmetic.rhm` | the value of a four-operation expression | `+` 1, `-` 2, `*` 3, `/` 4; a number pays one per digit beyond its first, a fraction in lowest terms 2 | 12 | Numeric |
| `boolean.rhm` | the truth value of a proposition in p, q, r under an assignment; propositions are the engine's Boolean type | and/or 2, conditional 4, biconditional and xor 6, a negated variable 1, a negated compound 3 | 10 | Numeric |
| `boolean_equiv.rhm` | whether one of thirty laws, stated correctly or with a classic mistake, holds; decided by enumeration | the law 1–3, the parts as in `boolean.rhm` | 6 | Numeric |
| `calculus.rhm` | a derivative, or an antiderivative built by differentiating; the named questions `derivative` and `integral` ask one form only | sum 1, product 3, quotient 4; a power or function of a leaf 1, of a compound 3 (chain rule); an integral pays 2 up front | 7 | Numeric |
| `complex.rhm` | a complex expression, its conjugate, the modulus of a product / conjugate / multiple of Pythagorean-triple numbers, or `i^n` times an expression | sum 1, product 3; modulus 2 plus its expression (product 2, conjugate 1, multiple 1); power of `i` 1 plus its expression | 4 | Complex |
| `set.rhm` | a set expression over three given sets | union 1, intersection and difference 2, an interval leaf 1 | 7 | Interval |
| `polynomial_expand.rhm` | the expansion of a product of factors | product 2, square 1, cube 2, factor `x + b` 0, `ax + b` 1, quadratic 2 | 5 | Numeric |
| `factoring.rhm` | the factored form of a polynomial built from its factors | the same prices as the expansion; the factors are distinct and primitive | 5 | PolynomialFactors |
| `vector_expr.rhm` | a vector expression, or a dot product, cross product or norm of expressions | sum 1, a multiple of a bracket 1; dot 2, norm 2, cross 4 on top | 4 | Vector |
| `linear_equation.rhm` | the solution of a linear equation whose left side is built from a chosen root | sum 1, a multiple of a bracket 1, a fraction 2 | 5 | Numeric |
| `polynomial_forms.rhm` | the same tree of factors, expanded or factored, each form in its own context | as `factoring.rhm` | 5 | Numeric / PolynomialFactors |
| `sequence_parts.rhm` | one sequence, two blanks: its nth term and the sum of its first n terms | arithmetic 2, geometric 3 (fixed) | 2 | Numeric |
| `derivative_or_boolean.rhm` | a derivative or a Boolean evaluation, from the two grammars imported as modules | each grammar's own prices | 8 | Numeric |
| `logic_forms.rhm` | classify a proposition (tautology / contradiction / neither), count its models, or rewrite it without the conditional family; built on `boolean.rhm` and `boolean_equiv.rhm` | the law's or expression's own price | 6 | Numeric / Boolean |
| `matrix_expr.rhm` | compute an expression in the matrices A, B, C of `matrix_core.rhm` | sum 1, multiple 1, transpose 1, product 3; 3 by 3 matrices 2 | 4 | Matrix |
| `determinant.rhm` | the determinant of a matrix or of a product, transpose or multiple | 2 by 2 1, 3 by 3 3; product 2, transpose 1, multiple 1 | 3 | Numeric |

## Fixed forms: each form is a price

| grammar | forms by price | default | context |
| --- | --- | --- | --- |
| `vector.rhm` | 1 parallel vector; 2 dot product, norm, same direction; 3 unit vector; 4 cross product | 2 | Vector |
| `sequence.rhm` | 1 arithmetic nth term; 2 geometric nth term, arithmetic sum; 3 geometric sum | 2 | Numeric |
| `library_linear.rhm` | 2 one bracket; 3 brackets on both sides; 4 a fraction | 3 | Numeric |
| `library_quadratic.rhm` | 2 two integer roots; 3 repeated root, no real root; 4 two rational roots | 3 | Interval |
| `library_polynomial.rhm` | 1 evaluation; 2 degree; 3 expansion, coefficient; 4 derivative | 3 | Numeric |
| `library_formula.rhm` | 2 composition; 3 logarithm, radical, tangent; 4 quotient, combined | 3 | Numeric |
| `matrix_inverse.rhm` | 2 a 2 by 2 with whole inverse; 3 the same scaled (fractions); 5 a 3 by 3; 6 scaled | 2 | Matrix |
| `linear_system.rhm` | 3 a triangular system in three unknowns; 5 a full one; three answer blanks | 5 | Numeric |

## The five general types added on this branch

**Factoring** (`factoring.rhm`). The factors come first: primitive linear
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

**Expansion** (`polynomial_expand.rhm`). The same factors read the other
way, with quadratics `ax^2 + bx + c` as well; the answer is the expanded
polynomial. A linear factor appears once in a product; twice is a power.

**Calculus, extended** (`calculus.rhm`). Derivative questions may now use
`ln`, `sqrt`, `tan` and quotients, each on a leaf (1) or a compound (3 plus
the compound), the quotient at 4 plus both sides. `ln` and `sqrt` take a
leaf with a positive coefficient. Integral questions keep to sums,
products, powers, `sin`, `cos` and `exp`, whose reverse is within the
course's methods; the `advanced` attribute switches the rest off for them.
Powers do not nest, and `e^{...}` under a power is bracketed in LaTeX.

**Vector expressions** (`vector_expr.rhm`). Sums, differences and multiples
of `u`, `v`, `w`, asked for as they are (price 0 on top), under a norm (2),
a dot product (2) or a cross product (4). Within one sum each vector
appears once, so nothing cancels; a bracketed multiple starts a new sum,
a multiple is never taken of a multiple, and a sum used as an
operand of a dot or cross product is bracketed.

```
cost 4   ||w - u - v||
cost 7   5(u + 3(w - u)) . (w + v)
```

**Linear equations** (`linear_equation.rhm`). The root is chosen first. The
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

## The second batch: logic, linear algebra, and two grammars made scalable

**A whole assignment** (`homework_set.rhm`) asks for no question of its own: it
imports four grammars and declares two `set`s, run with `rhema homework_set.rhm --run homework`;
see `RHEMA_LANGUAGE_EXTENSIONS.md` section 6.

**Logic** (`logic_forms.rhm`) imports both Boolean grammars as modules and asks
three further questions of their laws and expressions: classification
(coded 1, 2, 0 as the evaluation questions code true and false), model
counting, and rewriting without the conditional family, whose answer is a
proposition graded in WeBWorK's Boolean context (`contextBoolean.pl` is
loaded for it; WeBWorK accepts any equivalent proposition, so the form
itself is not enforced).

**Linear algebra** rests on a new value type, `Matrix` (`rhema_matrix.ml`:
exact rational entries, sum, multiple, transpose, product, cofactor
determinant, adjugate inverse, application to a vector, LaTeX and PG
rendering, and `matrix_row_latex` for writing a row as an equation).
`matrix_core.rhm` draws A, B and C once, in a 2 by 2 and a 3 by 3 version,
and the inherited attribute `dim` says which a question uses. The inverse
and the system are built from products of unit triangular matrices, so the
inverse has whole entries and the chosen solution is the only one; the
system places three answer blanks in its prompt.

**Complex numbers** gained scalable modulus and power forms, and
**arithmetic** a fraction leaf in lowest terms.

## What a user can write in one file

Several question forms sharing the question-level randoms, as every grammar
with more than one `Q ->` rule shows; forms that need different WeBWorK
contexts (`pg_context`); questions with several answer blanks (`{answer
...}` in the prompt); and productions shared with other files (`include`).
`polynomial_core.rhm` is a library of productions with no question of its
own; `factoring.rhm`, `polynomial_expand.rhm` and `polynomial_forms.rhm` include
it. See `RHEMA_LANGUAGE_EXTENSIONS.md`.
