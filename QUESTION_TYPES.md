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

<!-- --8<-- [start:tables] -->
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
| `counting.rhm` | 1 a row, a ranked choice, a committee; 2 arrangements of a word, at least one of a kind, two people not together, the probability of a dice sum; 3 drawing all of one colour, at least one six, exactly k heads; the questions `counting` and `probability` ask one family | 2 | Numeric |
| `number_theory.rhm` | 1 gcd, lcm; 2 the remainder of a power, an inverse modulo n; 3 a linear congruence | 2 | Numeric |
| `series.rhm` | 1 an infinite geometric series, a sum of squares; 2 a geometric series in sigma notation, the sum of a quadratic, a telescoping sum; 3 a telescoping sum with a gap (finite or infinite), the sum of two geometric series | 2 | Numeric |
| `limits.rhm` | 1 a removable discontinuity, a ratio of quadratics at infinity; 2 a factor shared above and below, `sin(kx)/(mx)`, `(e^{kx} - 1)/(mx)`; 3 a ratio of two sines, `(1 - cos(kx))/(mx^2)` | 2 | Numeric |
| `eigen.rhm` | 1 the eigenvalues of a triangular matrix; 2 the eigenvalues of a 2 by 2, its characteristic polynomial; 3 an eigenvector, the eigenvalues of a 3 by 3 | 2 | Interval / Numeric / Vector |
| `inequality.rhm` | 1 linear; 2 quadratic, the absolute value of `x - a`; 3 the absolute value of `px - q`, rational; 4 to 8 a sign chart of two to five factors: a factor of the numerator 1, of the denominator 2, a squared factor 3 | 2 | Interval |
| `definite_integral.rhm` | 1 `k x^n` from 0 to q, a quadratic between two bounds; 2 a product of two linear factors to expand first, the area between a parabola and the x-axis; 3 the area between a parabola and a line, `k x (a x^2 + c)^n` by substitution; 4 to 8 the integral of a sum of two or three pieces, no two of a kind: a quadratic 1, a product 2, a substitution 3, `k |x - m|` 3 | 2 | Numeric |
| `derivative_applications.rhm` | 1 the slope of a tangent to a cubic, where a parabola has a horizontal tangent; 2 the tangent line to a parabola, the critical points of a cubic; 3 the absolute maximum or minimum of a cubic on a closed interval, the interval on which it decreases or increases | 2 | Numeric / Interval |
| `exponential_log.rhm` | 1 the logarithm of a power of its base, `b^(x + c) = b^k`; 2 two bases that are powers of one number, `log_b(p x + q) = k`; 3 a sum of two logarithms with one root rejected, a quadratic in `b^x` | 2 | Numeric |
| `analytic_geometry.rhm` | 1 the distance between two points, their midpoint, the slope through them; 2 the line through two points, the perpendicular to a line through a point; 3 the centre and the radius of a circle given expanded (two blanks), the intersection of two lines | 2 | Numeric (a point answer carries the Point context) |
| `differential_equation.rhm` | initial value problems: 1 `y' = 2a x + b`, `y' = k y`; 2 `y' + a y = b`, `y' = 2k x y`; 3 `y'' + p y' + q y = 0` with two real roots or one repeated | 2 | Numeric |
| `statistics.rhm` | 1 the mean, median or range of a data set; 2 the variance of a data set, a value missing from a known mean, the expectation of a random variable; 3 the variance of a random variable, at least two successes in n trials | 2 | Numeric |
| `partial_fractions.rhm` | the constants of a decomposition, one blank each: 1 two different factors; 2 a factor `p x + q`, a numerator of the denominator's degree with the quotient given; 3 three factors, a repeated factor; 4 to 8 built term by term, up to five constants: each further factor 2, a factor `p x + q` 1, a repeated factor 2, a quotient 1 | 2 | Numeric |
| `recurrence.rhm` | 1 a term of a first-order or a second-order recurrence; 2 `A` and `B` in the solution `A r^n + B`, the roots of a characteristic equation; 3 `r`, `s`, `A`, `B` in `A r^n + B s^n`, and `r`, `A`, `B` in `(A + B n) r^n` | 2 | Numeric / Interval |
| `taylor.rhm` | the Taylor polynomial at 0: 1 `e^(kx)`, `1/(1 - kx)`; 2 `sin(kx)`, `cos(kx)`, `ln(1 + kx)`; 3 `(a + bx) e^(kx)`, `e^(k x^2)`; 4 to 8 functions built from those: the argument `k x^2` 2, a linear factor 2, a sum 1, a product 3 | 2 | Numeric |
| `row_reduction.rhm` | 1 the rank of a 3 by 3 matrix; 2 the reduced row echelon form of a 2 by 3 matrix; 3 the reduced form of a 3 by 4 matrix, a vector of a null space; 4 to 8 the same of 3 by 4 to 3 by 6 matrices: each column beyond the third 1, each free variable of a null space beyond the first 1 | 2 | Numeric / Matrix / Vector |
| `base_conversion.rhm` | 1 binary to decimal and back; 2 hexadecimal to decimal, decimal to octal, binary to octal; 3 a sum in binary, hexadecimal to binary; 4 to 8 sums and differences of two to four numbers in binary, octal and hexadecimal: a number 1 (hexadecimal 2), adding one 1, subtracting one 2, an answer in another base 1 | 2 | Numeric |
| `trigonometry.rhm` | 1 degrees and radians, an exact value in the first quadrant; 2 an exact value in any quadrant, the other functions from one and the quadrant; 3 the two solutions of `sin x = v`, `cos x = v` or `tan x = v` on one turn, with argument `x` or `2x` | 2 | Numeric (plain answers) |
| `partial_derivatives.rhm` | 1 a first partial derivative; 2 both, the mixed second derivative, the gradient at a point; 3 a tangent plane, the critical point of a quadratic; 4 to 8 the same derivatives (first 1, both or a second one 2) of a function with sin, cos and e: of `ax + by` 2 each, of a product such as `x^2 y` 3, times a power of `x` or `y` 5 | 2 | Numeric (answers in `x` and `y`) |
| `probability.rhm` | 1 `P(A or B)` from `P(A)`, `P(B)` and `P(A and B)`, two independent events both happening; 2 a conditional probability from a table of counts, `P(A given B)` from `P(A)`, `P(B)` and `P(A or B)`, at least one of two independent events; 3 a ball drawn from one of two bags chosen by a die: the probability of its colour, the probability of the bag given the colour | 2 | Numeric |
| `modular_arithmetic.rhm` | 1 Euler's function of `p q` or of a prime power, the number of divisors of `p^a q^b`; 2 two simultaneous congruences, the sum of the divisors of `p^a q^b`; 3 three simultaneous congruences, an RSA key: its private exponent and a message deciphered (two blanks) | 2 | Numeric |
| `graph_theory.rhm` | 1 the edges of a graph from its degrees, of `K_n`, of `K_{m,n}`, of a forest; 2 a degree missing from a list, the leaves of a tree, the walks of length 2 between two vertices; 3 the faces of a regular planar graph, the walks of length 3 between two vertices | 2 | Numeric |
| `binomial_theorem.rhm` | 1 a coefficient of `(1 + x)^n`, of `(x + b)^n`; 2 a coefficient of `(ax + b)^n`, of `(ax + by)^n`, the sum of the coefficients of `(ax + b)^n`; 3 the term independent of `x` in `(a x^p + b/x^q)^n`, a coefficient of `(c + dx)(1 + ax)^n` | 2 | Numeric |
| `numerical_methods.rhm` | 1 one step of Newton's method for `x^2 - a = 0`, the trapezoidal rule with two strips; 2 two steps of Newton's method, the third midpoint of a bisection, the trapezoidal rule with four strips, two steps of Euler's method for `y' = ax + by`; 3 Simpson's rule with four strips, two steps of Euler's method for `y' = ax + y^2` or `ax - y^2` | 2 | Numeric |
| `lines_planes.rhm` | 1 the constant of a plane through a point with a given normal, the point of a line at a value of its parameter; 2 the distance from a point to a plane, the point where a line meets a plane, the cosine of the angle between two planes; 3 the foot of the perpendicular from a point to a plane, the reflection of a point in a plane | 2 | Numeric (a point answer carries the Point context) |
| `double_integral.rhm` | 1 a monomial `c x^m y^n` or `p x + q y` over a rectangle; 2 an inner limit that is `x` or `k x`, the average value of a function over a rectangle; 3 a region given in words: the triangle cut off by the axes and a line, the region between `y = x^2` and `y = k x` | 2 | Numeric |
| `implicit_differentiation.rhm` | 1 the slope of a circle or of `p x^2 + q y^2 = c` at a point; 2 the slope of `x^2 + k x y + y^2 = c` or of `x^3 + y^3 = k x y + c` at a point, `dy/dt` from `dx/dt` for a point moving on a circle; 3 where the tangent at a point meets the `y`-axis, the second derivative at a point | 2 | Numeric |
| `markov_chain.rhm` | 1 the probability of the next two days in order, tomorrow from a forecast for today; 2 the weather two days ahead, the long-run share of sunny days, the expected length of a run of days of one kind; 3 the weather three days ahead, two steps of a chain with three states from its matrix, the chance that a walk on a line reaches the top before the bottom | 2 | Numeric |
| `regression.rhm` | 1 the slope from `S_xx`, `S_yy` and `S_xy`, the intercept from the slope and the two means, a residual; 2 the slope from five data points, and from the sums of `x`, `y`, `x^2` and `x y`; 3 a prediction from five data points, the coefficient of determination `r^2` | 2 | Numeric |
| `complex_polar.rhm` | 1 the modulus and argument of a product or a quotient of two numbers in polar form, a number in polar form written as `a + bi`; 2 the modulus and principal argument of `a + bi`, and of a power of a number in polar form; 3 a power of `a + bi` by De Moivre's theorem, the modulus and the two smallest arguments of the roots of `z^n = w` | 2 | Numeric (plain answers) |
| `relations.rhm` | 1 the number of relations, of functions and of one-to-one functions from one set to another; 2 the number of reflexive and of symmetric relations on a set, the functions onto a set of two or three, the pairs missing from a symmetric relation, the pairs of an equivalence relation from the sizes of its classes; 3 the pairs of a composite and of a transitive closure, the equivalence relations with exactly two classes | 2 | Numeric |
| `vector_calculus.rhm` | 1 the gradient of a function at a point, the divergence of a field at a point; 2 the curl of a field at a point, a directional derivative, the Laplacian at a point; 3 the work of a field along a straight segment, a circulation round a rectangle by Green's theorem | 2 | Numeric / Vector |
| `improper_integral.rhm` | 1 `k / x^p` from `a` to infinity, an exponential tail; 2 `k / (x + a)^p` and `k x e^(-ax)` from 0 to infinity, `k / sqrt(x)` from 0 to `b`; 3 `k x^2 e^(-ax)` and `k x e^(-a x^2)` from 0 to infinity, `k / (x^2 + a^2)` over a half line or the whole line (a multiple of pi) | 2 | Numeric (the multiple of pi is a plain answer) |
| `linear_programming.rhm` | 1 the greatest value of `p x + q y` over a region given by its corners; 2 the greatest value under `x + y <= s`, `x <= a`, `y <= b`, and under `x + 2y <= c`, `2x + y <= d`; 3 the greatest value under two constraints with other slopes, the corner at which it is taken, the least value over the region above two lines | 2 | Numeric (a point answer carries the Point context) |
| `graph_algorithms.rhm` | 1 a minimum spanning tree of a weighted cycle, the edges an Euler circuit still needs from a list of degrees; 2 a shortest path and a minimum spanning tree in a weighted graph on four vertices with every edge; 3 a shortest path in a weighted graph on five vertices with seven edges, the number of spanning trees of a graph on four vertices | 2 | Numeric |
| `orthogonality.rhm` | 1 the component of one vector along another, the entry that makes two vectors orthogonal; 2 the projection of one vector onto another, the part of a vector orthogonal to another; 3 the second vector of a Gram-Schmidt process, the projection of a vector onto a plane, the matrix of the projection onto a line | 2 | Numeric / Vector / Matrix |
| `counting_principles.rhm` | 1 the size of a union of two sets, the pigeonhole principle; 2 the numbers up to `N` divisible by one of two numbers, the size of a union of three sets, the solutions of `x_1 + ... + x_k = n` in non-negative whole numbers; 3 the numbers up to `N` divisible by none of three primes, the solutions of `x_1 + x_2 + x_3 = n` with an upper limit on each, letters in envelopes with none, exactly one or at least one in its own | 2 | Numeric |
<!-- --8<-- [end:tables] -->

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

## The third batch: counting, number theory, series, limits, eigenvalues, inequalities

All six are fixed-form grammars with a default budget of 2, and all six are
built **answer first**: the answer is drawn, and the question is made from
it, so nothing is ever solved and every question has the answer it claims.

- **Counting and probability** (`counting.rhm`) computes its answers with
  the new whole-number builtins `factorial`, `permutations` and `choose`; a
  probability is an exact fraction. The named questions `counting` and
  `probability` ask one family only.
- **Number theory** (`number_theory.rhm`) builds a gcd question from `g m`
  and `g n` with `m`, `n` coprime, a congruence from its solution, and
  computes powers and inverses with `pow_mod` and `mod_inverse`.
- **Series** (`series.rhm`) draws the ratio of a geometric series as a
  fraction `p/q` with `|p| < q`, so the series converges; a telescoping sum
  is a sum of `1/((k+c)(k+c+g))`, whose surviving terms are the answer.
- **Limits** (`limits.rhm`) makes a removable discontinuity by multiplying
  above and below by the same `x - a` and showing both expanded, and scales
  the standard limits of `sin x / x`, `(e^x - 1)/x` and `(1 - cos x)/x^2`.
- **Eigenvalues** (`eigen.rhm`) builds `A = P D P^{-1}` with `P` of
  determinant 1, so `A` has whole entries, its eigenvalues are `D`'s and
  the columns of `P` are eigenvectors. The eigenvalues are graded as a set
  (order does not matter), an eigenvector as any vector parallel to the
  right one.
- **Inequalities** (`inequality.rhm`) chooses the roots, then reads the
  inside or the outside of them, and which ends are closed, from the
  comparison and the sign of the leading coefficient. Its answers use two
  new set values, the rays `set_above(a, closed)` and `set_below(a, closed)`.
  From budget 4 it builds a sign chart from the largest root down: each
  factor reverses the sign or, when squared, keeps it, and an interval is
  written down when its lower end is reached, so the answer comes out in
  its shortest form. A squared factor gives a point left out of an interval
  under `<` and `>`, and a solution on its own, `{r}`, under `<=` and `>=`.

```
cost 2   eigenvalues of [[-20, 21], [-14, 15]]   {-6, 1}
cost 3   |3x - 5| > 1                              (-infinity, 4/3) U (2, infinity)
cost 3   x / (x - 6) <= 0                          [0, 6)
```

The engine gained the builtins above, `gcd`, `lcm` and `number_latex` (a
number in LaTeX, fractions as `\frac`); a polynomial with a negative
leading term is now printed as `-5x^2 + 4x + 9` rather than as a
difference. Each grammar has a test that checks its answers independently:
by brute-force enumeration, by search, by numeric summation or evaluation,
by `det(A - tI) = 0` and `Av = tv`, or by testing points on either side of
every end of the interval.

## The fourth batch: integrals, derivatives at work, exponentials, geometry, differential equations, statistics

Six more fixed-form grammars with a default budget of 2, built answer first
wherever there is something to find. None needed a change to the engine;
they were later rewritten with local names, `true`/`false` and the point
value (`RHEMA_LANGUAGE_EXTENSIONS.md` section 7), asking the same questions.

- **Definite integrals** (`definite_integral.rhm`) are of polynomials, so
  the antiderivative is known from the numbers that built the integrand and
  the answer is an exact fraction. An area is built from the crossing
  points: `k (x - r1)(x - r2)` encloses `|k| (r2 - r1)^3 / 6` with the axis,
  and a parabola and a line that differ by it enclose the same. Both are
  shown expanded. From budget 4 the integrand is a sum of pieces, each
  integrated between the bounds as it is added; `k |x - m|` is new there,
  integrated on the two sides of `m`. Answers are kept below 1000.
- **Applications of the derivative** (`derivative_applications.rhm`) builds
  a cubic from its critical points `r1 < r2`: the derivative is
  `6k (x - r1)(x - r2)` and the function is
  `2k x^3 - 3k (r1 + r2) x^2 + 6k r1 r2 x + d`, with whole coefficients. The
  critical points are graded as a set, the interval of decrease (or
  increase) as an open interval, and a tangent line as the right-hand side
  of `y = mx + b`. An extreme value on a closed interval is sometimes at an
  end and sometimes at a critical point, depending on how far the ends are.
- **Exponentials and logarithms** (`exponential_log.rhm`) keeps every
  equation to powers of one base. The two hardest forms have a second
  candidate to reject: `log_b(x) + log_b(x - d) = log_b(N)` leads to a
  quadratic whose other root is negative, and `(b^x - b^m)(b^x + c) = 0`,
  shown expanded, has a factor that is never zero. The value of a logarithm
  is a `plain` answer, graded with the logarithm functions switched off, so
  `log(625)/log(5)` is not accepted for log₅(625).
- **Lines and circles** (`analytic_geometry.rhm`) takes a distance from a
  Pythagorean triple, expands a circle from its centre and radius, and
  draws two lines through a chosen point. A point is answered as `(3, -2)`:
  the answer is a point value (`point2`), which WeBWorK grades as a point
  whatever context the question is in. Every form places its blanks in its
  own text with `blank(...)`, so the circle can ask for its centre and its
  radius in two blanks while the other forms have one.
- **Differential equations** (`differential_equation.rhm`) asks initial
  value problems only, so the solution is one function and no constant of
  integration has to be graded. The rate, the equilibrium, or the roots of
  the characteristic equation and the two constants are chosen first; the
  equation and the initial values are read off them. The answer is a
  formula in `x`.
- **Statistics** (`statistics.rhm`) draws a data set in increasing order and
  lists it in a mixed order, so the median and the range are known without
  sorting; a data set for a variance is its mean plus deviations that add
  up to zero; probabilities are whole weights over their total. Variances
  divide by the number of values, and the question says so.

```
cost 3   area between y = x^2 + 10x + 2 and y = 4x - 3      32/3
cost 3   log_2(x) + log_2(x - 7) = log_2(18)                 9
cost 3   y'' - 5y' + 6y = 0, y(0) = -2, y'(0) = -2           2e^{3x} - 4e^{2x}
cost 3   centre of x^2 + y^2 - 16x - 4y - 13 = 0             (8, 2)
```

Each grammar has a test that checks its answers independently: by
numerical integration (Simpson's rule, between crossing points found from
the printed coefficients), by differentiating the printed polynomial
numerically and scanning the interval, by putting the answer back into the
equation and counting the sign changes of "left minus right" over a wide
range (exactly one, so a rejected root is really outside the domain), by
the definitions of midpoint, perpendicular and circle, by differentiating
the answer numerically and putting it into the differential equation, and
by recomputing every summary from the printed data, with a binomial
probability summed over all sequences of outcomes.

## The fifth batch: partial fractions, recurrences, Taylor polynomials, row reduction, bases, trigonometry, partial derivatives

Seven fixed-form grammars with a default budget of 2. They are the first
written for the additions of `RHEMA_LANGUAGE_EXTENSIONS.md` sections 7 and
8, and most could not have been written before them.

- **Partial fractions** (`partial_fractions.rhm`) chooses the constants and
  the factors, adds the fractions up and shows the result; the constants
  are asked for, one blank each, two or three by the form. The
  decomposition is unique, so they are the only answer. From budget 4 the
  decomposition is built term by term, with up to four different factors
  and five constants: adding `A / f` to `N / D` gives `(N f + A D) / (D f)`.
- **Recurrences** (`recurrence.rhm`) asks for a term, or for a solution in
  closed form built from its answer: the roots of the characteristic
  equation and the constants come first, the coefficients and the first
  terms follow. The hardest form has four blanks, `r`, `s`, `A` and `B` of
  `A r^n + B s^n`.
- **Taylor polynomials** (`taylor.rhm`) writes the coefficients from the
  known series as exact fractions. The answer is a polynomial; the function
  itself is a different function and is not accepted in its place. From
  budget 4 the function is a sum or a product of such functions: every part
  carries its series to degree 6, the series are added or multiplied, and
  `polynomial_truncate` cuts the result at the degree asked for.
- **Row reduction** (`row_reduction.rhm`) builds `A = M R` from a reduced
  form `R` and a matrix `M` of determinant 1, so `R` is the reduced form of
  `A`, the pivots of `R` count its rank and its free column gives the null
  space. It uses the matrices of any shape (`matrix_row`, `matrix_stack`).
  From budget 4 the reduced form is built column by column, a pivot column
  or a free one, up to six columns. A null space of dimension two or three
  is one matrix, `matrix_null_space(A)`: its columns are the basis read off
  the reduced form, the solution for each free variable in which it is 1 and
  the others are 0, which is the only such basis.
- **Number bases** (`base_conversion.rhm`) writes a number in another base
  with `base_digits`; an answer in binary or octal is the number with those
  decimal digits (`base_number`), typed as `1011`, and graded with
  `exactly(...)`: WeBWorK's usual tolerance of one part in a thousand would
  accept 10110 for 10100. Hexadecimal is given, never asked for: its digits
  are not a number WeBWorK reads. From budget 4 the question is a sum or
  difference of numbers in several bases, built number by number; questions
  wholly in binary or in octal have a chain of their own, so that they are
  as common as their weight says.
- **Trigonometry** (`trigonometry.rhm`) counts angles in twelfths of π and
  takes its values from `exact_sin`, `exact_cos` and `exact_tan`. An
  equation is built from its two solutions on the interval, asked for as
  the smaller and the larger. Values and angles are `plain` answers:
  `sin(pi/3)` and `asin(1/2)` are not accepted.
- **Partial derivatives** (`partial_derivatives.rhm`) differentiates a
  polynomial in `x` and `y` with respect to either. The file says
  `let pg_variables = "x y"`, so every formula answer is entered in a blank
  that knows both, also a derivative that comes to `6y`. A critical point
  is built from its answer and is a point value. From budget 4 the function
  holds sin, cos and e as well, at most three such terms and no two of a
  kind, and a second derivative may be asked twice in `x` or in `y`.

```
cost 3   (6x^2 + 66x + 182) / ((x + 5)^2 (x + 6)) = A/(x + 5) + B/(x + 5)^2 + C/(x + 6)   4; 2; 2
cost 3   a_0 = 2, a_1 = 10, a_n = 7a_(n-1) - 12a_(n-2);  a_n = A r^n + B s^n              3; 4; -2; 4
cost 3   Taylor polynomial of degree 3 of (2 + 4x) e^(2x)                                 2 + 8x + 12x^2 + 32/3 x^3
cost 3   cos 2x = sqrt(3)/2 on [0, pi)                                                    pi/12; 11pi/12
```

Each grammar has a test that checks its answers independently: the two
sides of a decomposition compared as numbers away from the poles; the
sequence computed term by term against the closed form; `f - T` shown to
vanish faster than `x^n` on both sides of 0; elimination on exact fractions
written apart from the engine's; digits converted one by one; angles and
values recomputed in floating point and an equation's interval scanned for
exactly the two solutions; and difference quotients of the function read
back by a small parser for the LaTeX the engine writes.

## The sixth batch: probability, modular arithmetic, graphs, the binomial theorem, numerical methods, lines and planes

Six fixed-form grammars with a default budget of 2, built answer first
wherever there is something to find. None needed a change to the engine,
and two of them declare mistakes.

- **Probability** (`probability.rhm`) counts everything out before it shows
  a probability: two events are the four regions of a Venn diagram, a class
  is the four cells of its table, and a bag is the balls in it. The
  probabilities of one question therefore agree with one another, and every
  answer is an exact fraction. The hardest forms choose one of two bags
  with a die and ask for the colour of the ball drawn, or, the ball being
  red, for the bag (Bayes' rule); the two bags hold red in different
  shares, so the colour says something about the bag. A question in which
  a conditional probability taken the wrong way round comes to the same
  number is not asked. `counting.rhm` and
  `statistics.rhm` ask for probabilities found by counting outcomes and for
  random variables; this grammar asks for the rules that combine events.
- **Modular arithmetic** (`modular_arithmetic.rhm`) goes on from
  `number_theory.rhm`. Euler's function and the number and the sum of the
  divisors are read off a prime factorisation that is chosen first. A
  system of two or three congruences is built from its solution, with
  moduli that are coprime in pairs, so it has exactly one solution below
  their product. An RSA key has two blanks: the private exponent, and a
  message that was chosen and enciphered with the public one, so that
  deciphering gives it back.
- **Graphs** (`graph_theory.rhm`) asks for counts. A list of degrees is
  read off a graph on five vertices that was built edge by edge, so there
  is a graph with those degrees. Walks are counted between two vertices of
  a connected graph on four vertices, given by its adjacency matrix: an
  entry of the matrix squared or cubed. The planar graphs are regular ones
  that exist (the prisms and the antiprisms, the octahedron among them),
  and the number of their faces follows from Euler's formula.
- **The binomial theorem** (`binomial_theorem.rhm`) asks for one
  coefficient: of `(ax + b)^n`, of `(ax + by)^n`, the term independent of
  `x` in `(a x^p + b/x^q)^n`, where `n` is a multiple of `p + q` so that
  there is one, and a coefficient of `(c + dx)(1 + ax)^n`, which has two
  terms to add; the two never cancel, so the coefficient asked for is not
  zero.
- **Numerical methods** (`numerical_methods.rhm`) works a few steps
  exactly: the steps are 1 or one half, nothing is rounded on the way, and
  the answer is an exact fraction or whole number. Newton's method and
  bisection look for a square root. The trapezoidal rule is asked of a quadratic or a cubic and
  Simpson's rule of `c / (x + d)`; in both the estimate is not the
  integral, so integrating gives another number. Euler's method takes two
  steps of one half.
- **Lines and planes** (`lines_planes.rhm`) is geometry in space with whole
  coordinates. A line is drawn through the point where it is to meet the
  plane; the point a perpendicular is dropped from is the foot plus a
  multiple of the normal, and its reflection is the foot minus the same. A
  distance and the cosine of an angle are taken with normals of whole
  length, such as `(1, 2, 2)` and `(2, 3, 6)`, so they are fractions with
  no square root. A point is answered as `(3, -2, 1)`, a point value
  (`point3`).

```
cost 3   bag 1: 5 red, 6 blue; bag 2: 2 red, 5 blue; a die showing 2 or less picks bag 1; the ball is red: P(bag 1)   35/79
cost 3   x = 1 (mod 4), x = 2 (mod 5), x = 1 (mod 7), 0 <= x < 140                                                    57
cost 3   the term independent of x in (x + 2/x^2)^9                                                                   672
cost 3   Simpson's rule with 4 strips for the integral of 6/(x + 2) from -1 to 3                                      146/15
cost 3   the reflection of (0, -5, 2) in the plane x - 3y + 3z = -17                                                  (-4, 7, -10)
```

Each grammar has a test that checks its answers independently, from the
numbers printed in the question: probabilities by counting equally likely
outcomes; Euler's function, divisors and congruences by going through
every number of the range, where a system must have exactly one solution
and a deciphered message must encipher to the cipher shown; a list of
degrees by deciding whether a graph has it, and walks by listing every
sequence of vertices; a coefficient by multiplying the bracket out; a
numerical method by running it as a loop on exact fractions; and a point
or a distance by the definition of what was asked, on the plane and along
the normal.

## The seventh batch: double integrals, implicit differentiation, Markov chains, regression, polar form, relations

Six more fixed-form grammars with a default budget of 2, built answer first
wherever there is something to find. None needed a change to the engine,
and four of them declare mistakes.

- **Double integrals** (`double_integral.rhm`) integrates a monomial
  `c x^m y^n` or a sum `p x + q y`, so every answer is an exact fraction.
  The cheapest forms are over a rectangle; then the inner limit is `x` or a
  multiple of it; the hardest give the region in words, the triangle cut
  off by the axes and a line or the region between `y = x^2` and `y = k x`,
  and the limits have to be set up first. An integral of `p x + q y` that
  comes to 0 is not asked.
- **Implicit differentiation** (`implicit_differentiation.rhm`) builds a
  curve from one of its points: the point is chosen first, and the constant
  of the equation is what the left side comes to there. It asks for the
  slope of a circle, of `p x^2 + q y^2 = c` and of two curves with a
  product term, for `dy/dt` from `dx/dt` on a circle, for the height at
  which a tangent meets the `y`-axis, and for the second derivative. A
  point where the tangent of a curve with a product term is level or
  upright is not asked, and neither is an equation that only looks like a
  curve: `x^2 + 2xy + y^2 = c` is a pair of lines, and
  `x^3 + y^3 = 3xy - 1` is the line `x + y + 1 = 0` with one point beside
  it. A slope with the wrong sign is carried into the tangent and into the
  second derivative, so those forms list the mistake too.
- **Markov chains** (`markov_chain.rhm`) tells a chain with two states as a
  story: a day is sunny or rainy, and tomorrow depends on today alone. The
  two probabilities are different, so today's weather says something about
  tomorrow's. It asks for a sequence of days, the weather two and three
  days ahead, the long-run share of sunny days and the expected length of a
  run. A chain with three states is given by its matrix, each row three
  numbers of quarters that add up to one, with the reading of rows and
  columns said in the question; a two-step probability that is the entry of
  the matrix itself is not asked, since reading one step off the matrix
  would be marked right. A counter that moves up or down a short line and
  stops at either end is asked for the chance of stopping at the top.
- **Linear regression** (`regression.rhm`) fits the least-squares line of
  `y` on `x`. The data are five points at `x`-values one apart, with
  `y`-values that are a trend and a small whole disturbance on each, so the
  slope is a number of tenths. It asks for the slope from `S_xx`, `S_yy` and
  `S_xy` (the three are possible together: `S_xy^2` is at most
  `S_xx S_yy`), for the intercept, for a residual that was chosen before
  its point, for the slope from the data and from their sums, for a
  prediction beyond the data and for `r^2`, of data that are neither on one
  line nor without a trend, and only where its denominator in lowest terms
  has at most two digits. The two mistakes of a slope question never lead
  to the same number, so a wrong answer says which was made.
- **Complex numbers in polar form** (`complex_polar.rhm`) goes on from
  `complex.rhm`. Angles are counted in twelfths of pi, and only the
  multiples of pi/6 and pi/4 are used. A number given as `a + bi` points in
  one of those directions: its parts are `k` and `k`, or `k sqrt(3)` and
  `k` in either order, with any signs. A power for De Moivre's theorem is
  chosen so that it lands on an axis and the answer is a whole number or a
  whole multiple of `i`; the roots of `z^n = w` are asked by their modulus
  and their two smallest arguments. An argument is asked with its range
  written out, `-pi < theta <= pi`, so that a number on the negative real
  axis has the argument pi and not `-pi`. Every answer is a `plain` answer,
  so `2 cos(pi/3)` is not accepted for 1, nor `atan(1)` for pi/4, and a part
  with a square root is kept in its simplest form, `2 sqrt(2)`.
- **Relations and functions** (`relations.rhm`) counts the relations, the
  functions, the one-to-one and the onto functions between two finite sets,
  and the reflexive and the symmetric relations on one. A relation on
  `{1, 2, 3}` is drawn pair by pair and kept when it has three to six
  pairs; its pairs are listed in order, and its matrix of 0s and 1s does
  the work: the pairs missing from a symmetric relation, the composite of
  two relations (a product) and the transitive closure (a sum of powers). A
  relation that is transitive already is not asked for its closure.

```
cost 3   the integral of -4x - y over the region between y = x^2 and y = 2x                -112/15
cost 3   the tangent to 3x^2 + 2y^2 = 66 at (-4, -3) meets the y-axis at (0, h)            -11
cost 3   a counter on 0..4, up with probability 1/5, starts at 3: P(it stops at 4)          21/85
cost 3   r^2 for the data (2, 3), (3, 3), (4, 7), (5, 9), (6, 9)                           81/92
cost 3   (sqrt(3) - i)^3 as a + bi                                                         0; -8
cost 3   the pairs of the transitive closure of {(1, 2), (2, 3), (3, 3)} on {1, 2, 3}      4
```

Each grammar has a test, written apart from it, that reads the numbers
back from the printed question and finds the answer again in its own way:
a double integral by integrating the polynomial symbolically between
limits it derives itself from the corners or the curves printed; a slope
from the partial derivatives of the equation read term by term, with the
point checked to lie on the curve and a difference quotient along the
curve beside it; a chain by listing every sequence of days or of steps,
the long-run share by solving the balance equation, and the walk by
solving its linear system; a regression line by solving the normal
equations and checking that the residuals add up to 0 and are orthogonal
to `x`, with `r^2` as 1 - SSE/SST; a complex number by multiplying it out
in floating point, with every argument required to be a multiple of
pi/24 inside the range printed and the roots listed in full; and a count
of relations or functions by brute force, every relation, function or
partition written out and tested by the definition. The mistaken answers
are found again from what each mistake says, and must be the ones the
engine reports.

What these tests found was put right in the grammars: a third of the
product curves and a few cubics were straight lines; one matrix question
in ten had the one-step entry as its answer; two mistakes of a regression
question could give the same number, and half of the `r^2` answers had a
denominator of three or four digits; an argument of pi was asked "between
-pi and pi", and the parts of a De Moivre answer were not `plain`.

## The eighth batch: vector calculus, improper integrals, linear programming, graph algorithms, projections, counting principles

Six more fixed-form grammars with a default budget of 2, built answer first
wherever there is something to find. None needed a change to the engine,
and five of them declare mistakes.

- **Vector calculus** (`vector_calculus.rhm`) makes a field of monomials
  `c x^i y^j z^k`, differentiates it with the engine's `differentiate` and
  puts the point in afterwards, so a gradient or a curl is a vector of
  whole numbers. A direction has whole length, such as `(1, 2, 2)`, so a
  directional derivative has no square root. The work along a straight
  segment is asked of a field that is linear in `x` and `y`, and a
  circulation by Green's theorem round a rectangle with a corner at the
  origin. A question is asked only where the point matters and every part
  of the field takes part: a gradient of a function that is not linear, a
  Laplacian of two terms that each have a square in them, a circulation in
  which both `P` and `Q` contribute; and an answer of 0 is not asked.
- **Improper integrals** (`improper_integral.rhm`) asks only integrals that
  converge: a power of `x` beyond a positive number, an exponential along
  the side on which it decays, a power of `x` times an exponential (by
  parts, or by `u = x^2`), and `k / sqrt(x)` down to 0, where the integrand
  is unbounded and its antiderivative is not. All of these come to a whole
  number or a fraction; `k / (x^2 + a^2)` comes to a multiple of pi and is
  answered so, as a `plain` answer in which `atan` is not accepted.
- **Linear programming** (`linear_programming.rhm`) asks for the greatest
  or least value of `p x + q y` over a region of the first quadrant. A
  region is built from its corner: the point where two slanted lines are
  to cross is chosen first, and each right-hand side is what its left side
  comes to there; one line is flatter than the other, so that point is a
  corner and the lines meet the axes on either side of it. The corner at
  which the value is taken is asked only where one corner alone takes it
  and its coordinates are whole. The mistake of trying the points where a
  line meets an axis outside the region gives a greatest value that is too
  large, a least value that is too small, or a point outside the region.
- **Graph algorithms** (`graph_algorithms.rhm`) goes on from
  `graph_theory.rhm` with weighted graphs. The graphs are small enough to
  be gone through in full: a shortest path is the least of every path
  between its ends, and a minimum spanning tree the least of the sixteen
  spanning trees of four vertices joined in pairs. The number of spanning
  trees of a graph is a determinant (the matrix-tree theorem), and the
  edges an Euler circuit still needs are half the vertices of odd degree,
  read off a list of degrees that a connected graph has.
- **Orthogonality and projections** (`orthogonality.rhm`) goes on from
  `vector.rhm`: the component of a vector along another, the projection
  onto a line and onto a plane through the origin, the part of a vector
  orthogonal to another, one step of the Gram-Schmidt process and the
  matrix of a projection. A vector that is projected onto has whole
  length where its length is divided by, so the mistake of dividing by
  the length once is a vector that can be told from the right one. A
  vector or a matrix answer may have fractions among its entries.
- **Counting principles** (`counting_principles.rhm`) goes on from
  `counting.rhm`: inclusion and exclusion for two and three sets, the
  pigeonhole principle, stars and bars with and without an upper limit,
  and letters put into envelopes with none, exactly one or at least one in
  its own (derangements). The sets of a question are counted out region by
  region before their sizes are shown, so an intersection is never larger
  than a set it lies in; the numbers up to `N` that a number divides are
  the whole part of a quotient.

```
cost 3   the circulation of (x^2, 4x^2) round the rectangle 0 <= x <= 3, 0 <= y <= 1          36
cost 3   the integral of 4/(x^2 + 4) from 0 to infinity                                      pi
cost 3   maximise 5x + 3y under x + 2y <= 8, 3x + y <= 19, x >= 0, y >= 0: where?            (6, 1)
cost 3   the spanning trees of the graph with the edges {1,2}, {1,3}, {2,4}, {3,4}           4
cost 3   Gram-Schmidt on (4, -4, -1) and (1, 2, -1): the second vector                       (15/11, 18/11, -12/11)
cost 3   the solutions of x_1 + x_2 + x_3 = 9 with 0 <= x_i <= 4                             10
```

Each grammar has a test, written apart from it, that reads the numbers
back from the printed question and finds the answer again in its own way:
a field by differentiating its own polynomial term by term, with the work
along a segment as an integral in the parameter and a circulation as four
line integrals along the sides, no theorem used; an improper integral
twice, numerically after a change of variable that brings infinity in, and
exactly by an antiderivative or a reduction formula that refuses an
integral that diverges; a linear programme by intersecting every two
boundary lines, keeping the feasible points and trying each, with a grid
of points inside the region that none may beat; a shortest path by
Dijkstra's algorithm and by listing every path, a spanning tree by
Kruskal's algorithm and by trying every set of edges, and a list of
degrees by finding a connected graph that has it; a projection by the
properties that define it (the answer is along the vector and what is left
is orthogonal to it), not by the formula; and a count by brute force,
every sock, number, solution or permutation written out. The mistaken
answers are found again from what each mistake says.

What these tests found was put right in the grammars: a Laplacian
question whose answer is 0 at every point (`4x^2 y - 4y z^2`), a
divergence that is the same at every point because two parts cancel, and
many vector questions in which the point or one part of the field played
no part; a projection onto a parallel vector, which is the vector itself; a
bounded count with the single solution `(m, m, m)`, and only three
different derangement questions; an example point, `(3, 2)`, that was
sometimes the answer, and a quarter of the points to enter with awkward
fractions; and a multiple of pi in which `atan` was accepted.

## Mistakes the library looks for

Fifteen grammars say what common mistakes lead to. `rhema run` lists them
under each answer, and none of these grammars asks a question in which a
mistake changes the working and still gives the right answer (section 9 of
`RHEMA_LANGUAGE_EXTENSIONS.md`).

| Grammar | Mistake | What the student does |
|---|---|---|
| `calculus.rhm` | `factor_by_factor` | differentiates a product factor by factor |
| | `no_chain` | leaves out the derivative of the inside |
| | `top_and_bottom` | differentiates the top and the bottom of a quotient separately |
| `complex.rhm` | `i_squared_one` | takes `i` squared to be 1 |
| | `minus_real_only` | subtracts the real parts but adds the imaginary parts |
| `boolean.rhm` | `false_antecedent` | takes a conditional with a false antecedent to be false |
| | `exclusive_or` | reads "or" as one or the other but not both |
| `polynomial_expand.rhm`, `polynomial_forms.rhm` | `power_term_by_term` | raises each term of a bracket to the power on its own |
| `probability.rhm` | `overlap_counted_twice` | adds two probabilities and does not take off what both share |
| | `wrong_way_round` | takes a conditional probability the wrong way round: of B given A where A given B was asked |
| `binomial_theorem.rhm` | `bare_coefficient` | gives the binomial coefficient alone, without the powers of the numbers in the bracket |
| | `powers_swapped` | puts each power on the other number of the bracket |
| `implicit_differentiation.rhm` | `sign_dropped` | takes `dy/dx` to be `F_x / F_y` and leaves out the minus sign |
| | `product_rule_missed` | differentiates `x y` as if `x` were a constant factor, so the term `x dy/dx` is lost |
| `markov_chain.rhm` | `transposed` | reads the transition matrix the wrong way round: a column for where the chain goes from a state |
| `regression.rhm` | `x_on_y` | divides by the spread of `y` in place of that of `x`: `S_xy / S_yy` |
| | `through_origin` | fits a line through the origin: the sum of `x y` over the sum of `x^2` |
| `relations.rhm` | `sets_swapped` | takes the two sets the wrong way round: `m^n` functions where there are `n^m` |
| | `diagonal_forgotten` | counts the pairs of two different elements only, and forgets that each pair `(a, a)` is free as well |
| `vector_calculus.rhm` | `not_normalised` | takes the direction of a directional derivative as it is given and does not divide by its length |
| `linear_programming.rhm` | `intercepts_outside` | tries every point where a line meets an axis, also those that lie outside the region |
| `graph_algorithms.rhm` | `direct_edge` | takes the edge that joins the two ends, though a path through another vertex is shorter |
| | `cheapest_three` | takes the three cheapest edges for a spanning tree, though they close a triangle |
| `orthogonality.rhm` | `not_divided` | gives the dot product for a component and does not divide by the length |
| | `length_not_squared` | divides a projection by the length where the square of the length belongs |
| `counting_principles.rhm` | `overlap_counted_twice` | adds the sizes of sets and does not take off what they share |
| | `triple_left_out` | corrects for what each two of three sets share and leaves out what all three share |

An integral question of `calculus.rhm`, a modulus question of `complex.rhm`
and a factoring question list none: their answers are not computed from the
values these mistakes change. In the grammars from the sixth batch on a
mistake is listed with the forms it can be made in: a curve with
no product term has no product rule to miss, and only the question that
shows a transition matrix can have it read the wrong way round.

## What a user can write in one file

Several question forms sharing the question-level randoms, as every grammar
with more than one `Q ->` rule shows; forms that need different WeBWorK
contexts (`pg_context`); questions with several answer blanks (`{answer
...}` in the prompt); and productions shared with other files (`include`).
`polynomial_core.rhm` is a library of productions with no question of its
own; `factoring.rhm`, `polynomial_expand.rhm` and `polynomial_forms.rhm` include
it. See `RHEMA_LANGUAGE_EXTENSIONS.md`.
