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
| `random_variables.rhm` | 1 `E(aX + b)` from `E(X)`, the mean of a binomial variable, a probability of a uniform variable, the expected number of attempts up to the first success; 2 `Var(aX + b)` from `Var(X)`, a variance from `E(X)` and `E(X^2)`, the variance of a binomial variable, the variance of `aX + bY` or `aX - bY` for independent `X` and `Y`, the probability that the first success comes at a given attempt; 3 a density `c x^n` on `[0, b]`: its constant, a probability, its mean and its variance; the covariance of two variables that take the values 0 and 1 | 2 | Numeric |
| `laplace_transform.rhm` | 1 the transform of `k t^n`, of `k e^(at)`; 2 the transform of `k sin(bt)` or `k cos(bt)`, of `p + q t + k e^(at)`, the inverse of `c / s^n` and of `k / (s - a)`; 3 the transform of `k t^n e^(at)`, of `e^(at) sin(bt)` or `e^(at) cos(bt)`, the inverse of `(p s + q) / ((s - a)(s - b))`, shown multiplied out, and of `(p s + q) / (s^2 + b^2)` | 2 | Numeric (answers in `s` and `t`) |
| `automata.rhm` | 1 the state a three-state automaton reaches on a word of four letters, the number of words of a length (or up to a length) over an alphabet; 2 the number of words of length 3 an automaton accepts, the words with no two `a`s next to each other, the least number of states for counting `a`s and `b`s modulo two numbers, and for the words that contain a given word; 3 the number of words of length 4 or 5 an automaton accepts, the words with two `a`s next to each other somewhere, the least number of states for the words with a given letter in a given place from the end | 2 | Numeric |
| `power_series.rhm` | 1 the radius of convergence of a geometric series in `p (x - c) / q`, the interval of convergence of a geometric series; 2 the radius of a series in `(p x + q)^n / r^n` with a power of `n` in front, the radius of a series in even powers, the interval of convergence of the series of `(x - c)^n / (n r^n)`; 3 an interval of convergence with `(-1)^n`, with `n^2` or `sqrt(n)` below the line or `n` above it, the radius of a series with `(2n)!` and `(n!)^2`, the sum of `n p^n / q^n` | 2 | Numeric / Interval |
| `optimization.rhm` | 1 `D = f_xx f_yy - f_xy^2` of a quadratic, the least or greatest value of a quadratic with no term in `x y`; 2 the least or greatest value of a quadratic with a term in `x y`, the greatest value of `x y` under `p x + q y = c`, the least value of `x^2 + y^2` on a line; 3 the greatest or least value of `a x + b y` on a circle, the local extreme value of `x^3 + y^3 - 3k x y + c`, the greatest value of `x y z` under `p x + q y + r z = c` | 2 | Numeric |
| `linear_transformations.rhm` | 1 the image of a vector, the matrix from the images of `(1, 0)` and `(0, 1)`; 2 the matrix of one transformation after another, the area of the image of a region, the dimension of the kernel or of the image of a transformation of space, the vector sent to a given one; 3 the matrix from the images of two other vectors, the matrix in another basis, the matrix of a reflection in a line | 2 | Numeric / Vector / Matrix |
| `fourier_series.rhm` | 1 `b_n` of `k x` on `(-pi, pi)`, `a_0` of a step; 2 `b_n` of a square wave, `a_0` or `a_n` of `k x^2`, the value of the series at a jump; 3 `a_n` of `k |x|`, `a_0`, `a_n` or `b_n` of `k x` on `(0, pi)` and 0 on `(-pi, 0)`, `b_n` of `k x` on an interval from `-L` to `L` | 2 | Numeric (plain answers) |
| `integral_applications.rhm` | 1 the volume of a solid of revolution by discs, the work done in stretching a spring; 2 a volume by washers, a volume by shells, the length of a curve; 3 the area of a surface of revolution, the centroid of the region under `c x^n`, the work done in pumping a cylindrical tank empty | 2 | Numeric (multiples of pi are plain answers; a centroid carries the Point context) |
| `parametric_polar.rhm` | 1 the slope of a parametric curve at a point, a point in polar coordinates in Cartesian ones (two blanks); 2 the tangent line to a parametric curve, the area of a petal of a rose, the area inside a cardioid or a circle through the pole; 3 the second derivative of a parametric curve, the length of a parametric curve, the area inside `r = 2b cos(theta)` and outside `r = b` | 2 | Numeric (plain answers) |
| `hypothesis_testing.rhm` | 1 the `z` statistic for a mean, the degrees of freedom of a test; 2 the `t` statistic for a mean, a 95% confidence interval for a mean (two blanks), the `z` statistic for a proportion; 3 the chi-square statistic for a die, the chi-square statistic of a two-by-two table, the `z` statistic for the difference of two means | 2 | Numeric |
| `group_theory.rhm` | 1 the order of `k` in `Z_n`, the order of a product of disjoint cycles; 2 the order of `(a, b)` in `Z_m x Z_n`, the number of elements of order `d` in `Z_n`, the order of a unit modulo a prime; 3 the number of generators of `Z_n`, the index of the subgroup generated by `(a, b)` in `Z_m x Z_n`, the number of primitive roots of a prime | 2 | Numeric |
| `conic_sections.rhm` | 1 the eccentricity of an ellipse, the focus of a parabola; 2 a focus of an ellipse, the slope of an asymptote of a hyperbola, the eccentricity of a hyperbola; 3 the centre and the length of the major axis of an ellipse given expanded (two blanks), the parabola with a given focus and directrix, the length of a latus rectum | 2 | Numeric (a focus or a centre carries the Point context) |
| `normal_distribution.rhm` | 1 the `z` score of a value, the probability above a value; 2 the probability within `z` standard deviations of the mean, between two values on one side of the mean, the value with a given share of the distribution below it; 3 the probability between two values on opposite sides of the mean, that the mean of a sample is above a value, that one normal variable is below another | 2 | Numeric |
| `graph_coloring.rhm` | 1 the colourings of a tree and of a complete graph with `k` colours; 2 the colourings of a cycle and of a complete bipartite graph `K_{2,n}`, the chromatic number of a cycle, a wheel, a complete graph with some disjoint edges removed, or two cycles that share a vertex; 3 the colourings of a wheel, of two cycles that share a vertex, of two cycles that share an edge | 2 | Numeric |
| `vector_spaces.rhm` | 1 the coordinates of a vector of the plane relative to a basis, the dimension of a standard space, the dimension of a sum of subspaces; 2 the entry that makes three vectors dependent, the coordinates of a polynomial relative to `1`, `x - r`, `(x - r)^2`; 3 the coordinates of a vector of space relative to a basis, the matrix that changes coordinates from one basis to another, the dimension of the intersection of two subspaces of `R^4` | 2 | Numeric / Vector / Matrix |
| `integral_coordinates.rhm` | 1 a triple integral of a monomial over a box, the integral of a power of the distance from the origin over a disc; 2 the same over a ring, the integral of `x`, `y`, `x y` or `x^2` over a quarter of a disc, the volume under a paraboloid or a cone; 3 the integral of a power of the distance from the origin over a ball or between two spheres, of `z` over half a ball, and of `x^2 + y^2`, `z` or their product over a cylinder | 2 | Numeric (plain answers) |
| `integration_techniques.rhm` | 1 `k sin^2(mx)` or `k cos^2(mx)` over a multiple of a quarter period, `k / (x^2 + a^2)` from 0 to `a`, `k / sqrt(a^2 - x^2)` from 0 to `a / 2`; 2 by parts: `k x e^(ax)`, `k x^n ln x`, `k x sin(mx)` or `k x cos(mx)`, and `k sin^a(x) cos^b(x)` with an odd power; 3 `k sin^n(x)` or `k cos^n(x)` by the reduction formula, a trigonometric substitution, `k x^2 e^(ax)` by parts twice, `k / ((x + a)(x + b))` by partial fractions | 2 | Numeric (fractions and multiples of pi are plain answers) |
| `nonhomogeneous_ode.rhm` | 1 a particular solution of `y'' + p y' + q y = c e^(kx)`, of `y'' + q y = c sin(kx)` or `c cos(kx)`; 2 of `y'' + p y' + q y = m x + n`, of the same with `c e^(rx)` in resonance, and `y' + a y = c e^(kx)` with an initial value; 3 of `y'' + p y' + q y = alpha cos(kx) + beta sin(kx)`, and initial value problems of the second order with a constant or an exponential on the right | 2 | Numeric |
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

## The ninth batch: random variables, Laplace transforms, finite automata, power series, optimisation, linear transformations

Six more fixed-form grammars with a default budget of 2, built answer first
wherever there is something to find. None needed a change to the engine,
and all six declare mistakes.

- **Random variables** (`random_variables.rhm`) goes on from
  `statistics.rhm`, which reads a mean and a variance off a table of
  probabilities. It asks for the rules: the mean and the variance of
  `aX + b`, a variance from `E(X)` and `E(X^2)`, the variance of
  `aX + bY` and of `aX - bY` for independent variables; for the mean and
  the variance of a binomial variable, the expected number of attempts up
  to a first success and the chance that it comes at a given attempt, and
  a probability of a uniform variable. A density is `c x^n` on the
  interval from 0 to `b`, with the constant that makes its integral 1, so
  its probabilities, its mean and its variance are fractions. A covariance
  is asked of two variables that take the values 0 and 1, from the four
  probabilities of their outcomes.
- **Laplace transforms** (`laplace_transform.rhm`) asks for the transform
  of a power of `t`, of an exponential, of a sine and a cosine, of a sum
  of such functions and of a function multiplied by an exponential (the
  shift), and for the way back. An inverse is built from its answer: the
  constants and the rates of `A e^(at) + B e^(bt)` are chosen first, and
  the fraction shown is what `A / (s - a) + B / (s - b)` adds up to, with
  its denominator multiplied out. A transform is a formula in `s` and an
  inverse a formula in `t`; the file says `let pg_variables = "s t"`, so
  every blank knows both.
- **Finite automata** (`automata.rhm`) shows a deterministic automaton
  with three states over the letters `a` and `b` as a transition table.
  The table is kept when the two letters do different things, neither
  sends every state to the same one, and every state can be reached from
  the first. The moves of a letter are a matrix of 0s and 1s, so the state
  after a word is read off a product of matrices, and the words of a
  length that the automaton accepts are counted by a power of the sum of
  the two; some word is accepted and some is not. The words with no two
  `a`s next to each other are counted the same way, by an automaton with
  two states that is not shown. The least number of states is asked for
  three families of languages in which it is known: the numbers of `a`s
  and `b`s divisible by two numbers, the words that contain a given word,
  and the words with a given letter in place `k` from the end, which need
  `2^k` states.
- **Power series** (`power_series.rhm`) goes on from `series.rhm` and
  `taylor.rhm` with the radius and the interval of convergence. A series
  is made from its radius, so the ratio test ends in a fraction: a
  geometric series in `p (x - c) / q`, a series in `(p x + q)^n / r^n`
  with a power of `n` beside it, a series in even powers whose radius is a
  square root, and a series with `(2n)!` and `(n!)^2`, whose ratio tends
  to 4. Where an interval is asked for, its ends are known from the kind
  of series: with `1/n` or `1/sqrt(n)` one end belongs to it and the other
  does not, and `(-1)^n` changes which; with `1/n^2` both belong, and with
  `n` neither. An interval is an answer in the Interval context, entered
  with round and square brackets.
- **Optimisation** (`optimization.rhm`) goes on from
  `partial_derivatives.rhm`, which asks for a critical point; here the
  value there is asked for. A quadratic is built from its critical point
  and has a second-degree part that is positive or negative definite, so
  that value is the least or the greatest of all. The cubic
  `x^3 + y^3 - 3k x y + c` has a saddle at the origin and one local
  extreme at `(k, k)`. The constrained questions are those a Lagrange
  multiplier solves in closed form: `x y` under `p x + q y = c`,
  `x^2 + y^2` on a line, `a x + b y` on a circle, where `a` and `b` are the
  legs of a right triangle with whole sides, and `x y z` under
  `p x + q y + r z = c`.
- **Linear transformations** (`linear_transformations.rhm`) goes on from
  `matrix_expr.rhm` and `row_reduction.rhm` with what a matrix does: the
  image of a vector, the matrix from the images of the standard basis and
  from the images of two other vectors, the matrix of one transformation
  after another, the area of an image, the dimensions of the kernel and
  the image of a transformation of space, the vector that is sent to a
  given one, the matrix in another basis and the matrix of a reflection.
  What is to be found is chosen first, and the two vectors of a question,
  or of a new basis, are the columns of a matrix of determinant 1, so that
  nothing found has a fraction in it; only a reflection has fractions.

```
cost 3   the density 3/8 x^2 on [0, 2]: Var(X)                                               3/20
cost 3   the function whose Laplace transform is (7s + 3) / (s^2 - 1)                        2e^{-t} + 5e^{t}
cost 3   the least number of states for the words with a in place 5 from the end             32
cost 3   the interval of convergence of the sum of (x - 1)^n / (sqrt(n) 3^n)                 [-2, 4)
cost 3   the local minimum value of x^3 + y^3 - 6xy + 7                                      -1
cost 3   the matrix of the reflection in the line along (3, -4)                              [[-7/25, -24/25], [-24/25, 7/25]]
```

Each grammar has a test, written apart from it, that reads the numbers
back from the printed question and finds the answer again in its own way:
a rule for means and variances on tables of outcomes built to have the
printed mean or variance and transformed outcome by outcome, a binomial
variable trial by trial with no binomial coefficient, a first success by
writing out every sequence of draws, and a density by integrating its own
polynomial; a transform by the integral that defines it, taken numerically
at several values of `s`, and an inverse by putting the answer through the
same integral, which must give the printed fraction back; an automaton by
running the printed table letter by letter on every word, a count of words
by writing them all out, and a least number of states by building a
wasteful automaton, minimising it, and counting the classes of words that
no continuation tells apart; a radius from the growth of the terms read
off the printed series, with each end of an interval decided by how the
terms behave there (not tending to 0, alternating and decreasing, or like
a power of `n`); an extreme value by solving for the critical points and
classifying them, with a grid of points round it that must do worse, and
a constrained one by a search along the line, the circle or the plane,
with the Lagrange condition checked exactly where the search ends; and a
matrix by the property that defines it: it sends the printed vectors to
their printed images, `A b_j` is the combination of the new basis that
its column says, a reflection keeps its line and turns the normal over.
The mistaken answers are found again from what each mistake says.

These tests found no wrong answer and no mistake that gives the right
answer. They found one weak form, put right in the grammar: the rows of a
kernel or image question were drawn apart from one another, so the rank
was 1 in fewer than one question in a hundred and the dimension could be
given without looking; one time in three the second row is now a multiple
of the first.

## The tenth batch: Fourier series, applications of integration, parametric and polar curves, hypothesis tests, groups, conic sections

Six more fixed-form grammars with a default budget of 2, built answer first
wherever there is something to find. None needed a change to the engine,
and all six declare mistakes.

- **Fourier series** (`fourier_series.rhm`) asks for a coefficient of a
  function on the interval from `-pi` to `pi`, extended with period
  `2 pi`: a straight line, a step, a square wave, a parabola, an absolute
  value and a line on half the interval, and of a line on an interval from
  `-L` to `L`. The convention, `a_0 / 2` for the constant term and `1 / pi`
  in front of each integral, is written in every question. Where a
  coefficient is 0 for every even `n` only an odd `n` is asked for. One
  form asks for the value the series converges to at a jump, at 0 or at
  `pi`, where it is the average of the two sides. The answers are `plain`.
- **Applications of integration** (`integral_applications.rhm`) goes on
  from `definite_integral.rhm` with volumes of solids of revolution by
  discs, washers and shells, the length of a curve, the area of a surface
  of revolution, the work done in stretching a spring and in pumping a
  cylindrical tank empty, and the centroid of a region, a point. A curve
  whose length is asked for is one whose square root comes out, such as
  `y = x^3 / 6 + 1 / (2x)`, and a surface is the parabola `y = sqrt(x)` up
  between two points where `4x + 1` is a square or a cone whose slope is the ratio
  of two sides of a right triangle with whole sides.
- **Parametric and polar curves** (`parametric_polar.rhm`) asks for the
  slope, the tangent line and the second derivative of a curve whose
  coordinates are polynomials in `t`, and for the length of
  `x = k (t^3 - 3t)`, `y = 3k t^2` (moved), whose speed is `3k (t^2 + 1)`.
  In polar coordinates it asks for a point in Cartesian coordinates, in
  two blanks, and for areas: a petal of a rose, a cardioid, a circle
  through the pole, and the region inside `r = 2b cos(theta)` and outside
  `r = b`, which comes to a multiple of `pi` and one of `sqrt(3)`.
- **Hypothesis tests** (`hypothesis_testing.rhm`) asks for the statistic of
  a test, not its decision, which would be read off a table: `z` and `t`
  for a mean, `z` for a proportion and for the difference of two means,
  chi-square for a die and for a two-by-two table, and the degrees of
  freedom of a test; and for a 95% confidence interval for a mean, in two
  blanks. A sample size is a square, so its square root is whole, and the
  standard errors of two means are the legs of a right triangle with whole
  sides, so every statistic is a fraction.
- **Groups** (`group_theory.rhm`) goes on from `number_theory.rhm` and
  `modular_arithmetic.rhm` with orders: of an element of `Z_n`, of a pair
  in `Z_m x Z_n`, of a unit modulo a prime and of a product of disjoint
  cycles; with the number of elements of a given order and of generators
  of `Z_n`, the index of a cyclic subgroup of `Z_m x Z_n`, and the number
  of primitive roots of a prime. The two orders of a pair share a factor,
  so the order of the pair is not their product.
- **Conic sections** (`conic_sections.rhm`) goes on from
  `analytic_geometry.rhm` with ellipses, hyperbolas and parabolas: an
  eccentricity, a focus, the slope of an asymptote, the centre and the
  major axis of an ellipse given expanded, the parabola with a given focus
  and directrix, and the length of a latus rectum. An ellipse whose foci
  are asked for, and a hyperbola whose eccentricity is, are built on a
  right triangle with whole sides, so a focus has whole coordinates. A
  conic may open along either axis, and the question does not say which.

```
cost 3   a_5 of 3x on (0, pi) and 0 on (-pi, 0)                                         -6/(25 pi)
cost 3   the surface swept by y = sqrt(x) from 0 to 12 turned about the x-axis           57 pi
cost 3   the area inside r = 4 cos(theta) and outside r = 2                              4 pi / 3 + 2 sqrt(3)
cost 3   chi-square for a die thrown 96 times: 10, 10, 18, 22, 15, 21                    69/8
cost 3   the index of the subgroup generated by (9, 7) in Z_15 x Z_10                    15
cost 3   the parabola with focus (5, 4) and directrix y = 6                              -x^2/4 + 5x/2 - 5/4
```

Each grammar has a test, written apart from it, that reads the numbers
back from the printed question and finds the answer again in its own way:
a Fourier coefficient by integrating the printed definition numerically,
piece by piece, and the value at a jump both by the two one-sided limits
and by partial sums of the series; a volume, a length, a surface, a
centroid or a work by integrating what the question describes, slice by
slice or layer by layer, with the meeting points of the curves found by a
scan, and a polyline or a pile of frustums beside the integral; a slope
and a second derivative by difference quotients along the curve, a length
by a polyline, and a polar area by integrating `r^2 / 2` between zeros
found by a scan, with the period of the curve found by tracing it; a test
statistic from its definition with exact square roots, and a chi-square
statistic from expected counts worked out from the totals; an order by
adding or multiplying an element to itself until the identity comes back,
a permutation by composing it with itself, and a count by going through
every element; and a focus by the property that defines it, the sum or the
difference of the distances to the points of the curve, or the distance to
the directrix, with an asymptote as `y / x` far out on the curve. The
mistaken answers are found again from what each mistake says.

What these tests found was put right in the grammars: about one curve in
fifty of a slope or a tangent question was part of a straight line, which
needs no calculus; dividing by the observed counts came, in one die
question in a hundred thousand, to the right answer, and in one table in
twenty to within WeBWorK's tolerance of one part in a thousand, so that
mistake is now kept more than 1% away from the answer; the value of the
mistake of taking every element but the identity for a primitive root
counted the identity as well; and
grading in the renderer showed that a multiple of pi worth more than about
1000 accepted an answer off by one, so every such answer is now kept below
1000 (the work of pumping a tank is given in kilojoules). Several forms
of the applications of integration asked fewer than five different
questions, and were widened.

## The eleventh batch: the normal distribution, graph colouring, vector spaces, integrals in other coordinates, techniques of integration, non-homogeneous equations

Six more fixed-form grammars with a default budget of 2, built answer first
wherever there is something to find. None needed a change to the engine,
and all six declare mistakes.

- **The normal distribution** (`normal_distribution.rhm`) comes between
  `random_variables.rhm` and `hypothesis_testing.rhm`. No table is needed:
  a question gives the values of the standard normal distribution function
  that it uses, to four decimal places, and leaves the standardising, the
  symmetry and the complement to be done. The values of `z` are 0.5, 1,
  1.5, 2 and 2.5 and the standard deviation is even, so every value of the
  variable is whole and every answer is an exact decimal. The question on
  the mean of a sample prints the value of the function for `z / k` as
  well, the one whoever does not divide by `sqrt(n)` would reach for.
- **Graph colouring** (`graph_coloring.rhm`) goes on from `graph_theory.rhm`
  and `graph_algorithms.rhm`. It counts the ways to colour the vertices of
  a graph with `k` colours so that the two ends of every edge differ, for
  families whose count is known in closed form: a tree, a complete graph,
  a cycle, a complete bipartite graph with two vertices on one side, a
  wheel, and two cycles that share a vertex or an edge. An odd cycle with
  two colours has no colouring, and is asked. One form asks for the least
  number of colours that will do: for a cycle, a wheel, a complete graph
  with some edges removed that share no vertex, and two cycles joined at a
  vertex.
- **Vector spaces** (`vector_spaces.rhm`) goes on from `row_reduction.rhm`
  and `linear_transformations.rhm`: coordinates relative to a basis, in the
  plane, in space and for polynomials relative to `1`, `x - r`,
  `(x - r)^2`; the dimension of some standard spaces of polynomials and
  matrices, of a sum and of an intersection of subspaces; the entry that
  makes three vectors dependent; and the matrix that changes coordinates
  from one basis to another. Coordinates are chosen first, and a basis is
  the columns of a matrix of determinant 1. Two subspaces of `R^4` are
  each spanned by two vectors, the second built from the first in one of
  three ways, so that the intersection has dimension 0, 1 or 2.
- **Integrals in other coordinates** (`integral_coordinates.rhm`) goes on
  from `double_integral.rhm`, which integrates in `x` and `y`: a triple
  integral over a box, and integrals that ask for polar, cylindrical or
  spherical coordinates, over a disc, a ring, a quarter of a disc, under a
  paraboloid or a cone, over a ball, a shell between two spheres, half a
  ball and a cylinder. An integrand is a power of the distance from the
  origin or from the axis, or a coordinate, so every integral separates.
- **Techniques of integration** (`integration_techniques.rhm`) goes on from
  `definite_integral.rhm`, whose integrands are polynomials: a half-angle
  formula, an inverse tangent or sine, integration by parts once and
  twice, powers of sine and cosine, a reduction formula, a trigonometric
  substitution, and partial fractions with a logarithm at the end. Every
  integral is definite, so no constant of integration has to be graded.
  An answer with `e` or a logarithm may be entered as it stands, such as
  `2e^3/3 + 1/3` or `5 ln(5/3) / 4`.
- **Non-homogeneous equations** (`nonhomogeneous_ode.rhm`) goes on from
  `differential_equation.rhm`: a particular solution by undetermined
  coefficients, for a right-hand side that is an exponential, a sine or a
  cosine, or a linear function, with and without resonance, and initial
  value problems. A question is built from its answer and names the form
  of the solution asked for, such as `y = A e^(2x)`, so that there is one
  answer. An answer is a formula in `x`.

```
cost 3   X is N(40, 6^2): P(25 < X < 49), with Phi(2.5) = 0.9938 and Phi(1.5) = 0.9332           0.927
cost 3   the colourings with 4 colours of a 4-cycle and a 5-cycle that share an edge              1680
cost 3   the matrix from the basis (1, 3), (-3, -8) to the basis (1, -1), (-2, 3)                 [[9, -25], [4, -11]]
cost 3   the integral of 3 sqrt(x^2 + y^2 + z^2) between the spheres of radius 1 and 3            240 pi
cost 3   the integral of 5 / ((x + 1)(x + 5)) from 0 to 1                                         5 ln(5/3) / 4
cost 3   y'' - 5y' + 6y = -24, y(0) = -2, y'(0) = 3                                               3e^{2x} - e^{3x} - 4
```

Each grammar has a test, written apart from it, that reads the numbers
back from the printed question and finds the answer again in its own way:
a normal probability by integrating the density of the stated
distribution, with every value of the distribution function that a
question prints checked against that integral and the answer required to
be the combination of the printed values that the right working gives; a
number of colourings by building the graph as a list of edges and going
through every assignment of colours, a tree in every shape it can have,
and a chromatic number as the least number of colours with a colouring;
coordinates by solving for them and putting them back, a dimension by
writing a basis out and by the rank of the conditions, and an
intersection of subspaces three ways that must agree; a multiple integral
in Cartesian coordinates, where no factor of a change of variables enters,
with a grid of midpoints beside it; a definite integral by Gaussian
quadrature of the printed integrand, with the two halves of an
integration by parts chosen and checked by the test; and a solution of a
differential equation by putting it back into the equation, exactly with
the test's own derivative and numerically, and by solving the problem
again by elimination. The mistaken answers are found again from what each
mistake says, and every one must be more than 1% away from the right
answer.

What these tests found was put right in the grammars: about one question
in 285 on coordinates in space was one where using the vector's entries as
coefficients gives the coordinates back, and in some the answer was the
vector printed; one paraboloid's volume, 384 pi, was beyond the size at
which WeBWorK tells an answer from its neighbour; the chromatic number of
a complete graph was the number printed in the question and that of a
complete bipartite graph always 2, and both gave way to a complete graph
with some edges removed and two cycles joined at a vertex; a few normal
questions printed a value of 0 or below, and the means now start at 50;
and the reduction formula was asked for the power 2, which the half-angle
formula does at price 1. Four forms of the integration techniques were
widened.

## Mistakes the library looks for

Thirty-three grammars say what common mistakes lead to. `rhema run` lists them
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
| `random_variables.rhm` | `not_squared` | multiplies a variance by the factor in front of the variable where the square of the factor belongs |
| | `variances_subtracted` | subtracts the variances of a difference of independent variables where they are added |
| | `mean_not_squared` | takes the mean off `E(X^2)` where the square of the mean belongs |
| `laplace_transform.rhm` | `factorial_forgotten` | writes `1 / s^(n+1)` for the transform of `t^n` and leaves out the factorial |
| | `shift_sign` | shifts the wrong way: `s + a` where `s - a` belongs, or `e^(-at)` where `e^(at)` belongs |
| | `sine_cosine_swapped` | gives the transform of the cosine for the sine, or the other way round |
| `automata.rhm` | `read_backwards` | reads the word from its last letter to its first |
| | `one_state_per_letter` | counts one state for each letter to remember, where every combination of those letters needs its own |
| `power_series.rhm` | `reciprocal_taken` | gives the limit found by the ratio test, which is the reciprocal of the radius |
| | `inner_factor_ignored` | ignores the number in front of `x` inside the bracket |
| | `root_not_taken` | leaves the radius squared: with only even powers the ratio test gives the square of the radius |
| | `ends_not_tested` | gives the open interval and does not test its two ends |
| `optimization.rhm` | `coefficients_for_derivatives` | takes the coefficients of `x^2` and `y^2` for the second derivatives, which are twice as large |
| | `saddle_taken` | takes the value at the saddle point for the local extreme value |
| `linear_transformations.rhm` | `images_as_rows` | writes the images of the basis vectors as the rows of the matrix, where they are its columns |
| | `order_swapped` | multiplies the two matrices in the order the transformations are applied, the first on the left |
| | `basis_wrong_way` | changes basis the wrong way round: `P A P^(-1)` where `P^(-1) A P` belongs |
| `fourier_series.rhm` | `half_factor` | puts `1 / (2 pi)` in front of the integral where `1 / pi` belongs |
| | `constant_term_given` | gives the constant term `a_0 / 2` of the series where `a_0` is asked for |
| | `one_sided` | takes the value of the function on one side of a jump, where the series takes the average of the two sides |
| | `pi_for_length` | uses the coefficients of the interval from `-pi` to `pi` for an interval from `-L` to `L` |
| `integral_applications.rhm` | `radius_not_squared` | takes the area of a disc to be `pi` times its radius, where the radius is squared |
| | `radii_subtracted_first` | squares the difference of the outer and inner radius, where the difference of their squares belongs |
| | `shell_radius_forgotten` | leaves out the radius `x` of a shell: `2 pi` times the integral of the height alone |
| | `constant_force` | takes the force given for one stretch to act all the way, where the force grows with the stretch |
| | `lift_full_height` | lifts all the water through the whole height of the tank, where a layer only rises from where it is |
| `parametric_polar.rhm` | `inverted_slope` | takes `dx/dt` over `dy/dt` for the slope |
| | `sine_cosine_swapped` | takes `r sin(theta)` for `x` and `r cos(theta)` for `y` |
| | `half_forgotten` | leaves out the `1/2` of the area in polar coordinates, the integral of `r^2 / 2` |
| | `second_over_second` | takes `y''(t) / x''(t)` for the second derivative |
| `hypothesis_testing.rhm` | `not_scaled` | divides by the standard deviation itself, where the standard error, divided by `sqrt(n)`, belongs |
| | `divided_by_observed` | divides each squared difference by the observed count, where the expected count belongs |
| | `standard_errors_added` | adds the two standard errors, where their squares are added and the square root taken |
| | `cells_minus_one` | takes one less than the number of cells of a table, where `(rows - 1)(columns - 1)` belongs |
| `group_theory.rhm` | `gcd_ignored` | takes `n` for the order of `k` in `Z_n`, where `n / gcd(n, k)` belongs |
| | `lengths_added` | adds the lengths of the cycles, where their least common multiple belongs |
| | `orders_multiplied` | multiplies the orders of the two parts of a pair, where their least common multiple belongs |
| | `all_nonzero` | counts every element other than the identity, where only the generators count |
| | `fermat_bound` | takes `p - 1` for the order of every unit modulo `p` |
| `conic_sections.rhm` | `minor_axis_used` | divides the semi-minor axis by the semi-major one for an eccentricity |
| | `four_p_confused` | confuses `p`, the distance from the vertex to the focus, with `4p`, the number in the equation |
| | `axes_swapped` | puts the foci of an ellipse on its minor axis |
| | `ratio_inverted` | turns the slope of an asymptote over |
| | `ellipse_rule` | takes `c^2 = a^2 - b^2` for a hyperbola, the rule of an ellipse |
| | `semi_axis_given` | gives the semi-major axis, where the whole major axis is asked for |
| | `not_doubled` | gives half the latus rectum, `b^2 / a`, where `2 b^2 / a` belongs |
| `normal_distribution.rhm` | `complement_forgotten` | gives the probability below a value, where the probability above it is asked for |
| | `one_side_only` | gives the area between the mean and one of the two values, where the area between both is asked for |
| | `sign_lost` | places a value that lies below the mean as far above it |
| | `not_scaled` | uses the standard deviation of one value for the mean of a sample, where it is divided by `sqrt(n)` |
| `graph_coloring.rhm` | `only_previous_vertex` | makes each vertex differ from the one before it only, so an edge that closes a cycle is forgotten |
| | `sides_always_differ` | takes the two vertices on the small side of a bipartite graph to have different colours always |
| | `shared_part_counted_twice` | multiplies the counts of two joined cycles and does not divide by the ways to colour what they share |
| `vector_spaces.rhm` | `basis_applied` | uses the entries of a vector as the coefficients of the basis vectors, where its coordinates are asked for |
| | `degree_for_dimension` | takes the degree `n` for the dimension of the polynomials of degree at most `n` |
| | `intersection_not_removed` | adds the dimensions of two subspaces and does not take off what they share |
| | `standard_coordinates` | gives the coefficients of a polynomial as they stand, where another basis is asked about |
| | `direction_reversed` | changes basis the wrong way: the matrix from the second basis to the first |
| `integral_coordinates.rhm` | `jacobian_forgotten` | leaves out the factor `r` of the area element `r dr d(theta)` |
| | `sine_forgotten` | leaves out the `sin(phi)` of the volume element in spherical coordinates |
| `integration_techniques.rhm` | `half_forgotten` | takes the integral of `sin^2` or `cos^2` to be the length of the interval, where it is half of it |
| | `scale_forgotten` | leaves out the `1 / a` in front of the inverse tangent of `x / a` |
| | `plus_for_minus` | adds the second integral of an integration by parts, where it is subtracted |
| | `logs_added` | adds the logarithms of two partial fractions, where one is subtracted from the other |
| `nonhomogeneous_ode.rhm` | `chain_factor_forgotten` | differentiates `e^(kx)` without the factor `k` |
| | `second_derivative_sign` | takes the second derivative of `sin(kx)` or `cos(kx)` with a plus sign |
| | `first_derivative_forgotten` | leaves the `y'` term out when the constant of the trial solution `A x + B` is found |
| | `constants_before_particular` | fits the constants of the homogeneous solution to the initial values before the particular solution is added |

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
