# The question library

Rhema is installed with a library of grammars, in `share/rhema` beside the
command (in the repository, `generator/stdlib`). Every file can be run as it
is, imported into a file of your own (chapter 6 of the tutorial), or used in
a set. `rhema list FILE` shows what a file offers; the files themselves are
commented, and are the best examples of the language there are.

```text
$ rhema run calculus.rhm --question integral --set cost=5
$ rhema list logic_forms.rhm
```

The tables give, for each grammar, what it asks, what its difficulty budget
`cost` pays for, its default budget and the WeBWorK context of its answers.
Prices are per production: a sum that costs 1 and a product that costs 3
make `x + 2x \cdot \sin x` cost at least 4.

--8<-- "QUESTION_TYPES.md:tables"

## Mistakes

Twenty-seven grammars say what common mistakes lead to (chapter 9 of the tutorial).
`rhema run` lists them under each answer, and none of these grammars asks a
question in which a mistake changes the working and still gives the right
answer.

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

The mistakes of `calculus.rhm` concern its derivative questions; an
integral question lists none. `power_term_by_term` is declared in
`polynomial_core.rhm` and concerns a question that asks for the expansion;
`factoring.rhm` is built on the same productions and lists none. A modulus
question of `complex.rhm` lists none. In `probability.rhm` and
`binomial_theorem.rhm` a mistake is listed with the forms it can be made
in: a product of two independent probabilities, for one, has nothing to
count twice. The same holds for `implicit_differentiation.rhm`,
`markov_chain.rhm`, `regression.rhm` and `relations.rhm`: a curve with no
product term has no product rule to miss, and only the question that shows
a transition matrix can have it read the wrong way round.

## Libraries and examples

`polynomial_core.rhm`
:   The tree of polynomial factors that `factoring.rhm`,
    `polynomial_expand.rhm` and `polynomial_forms.rhm` are built on. It has
    no question of its own.

`matrix_core.rhm`
:   The matrices `A`, `B` and `C` that the linear algebra grammars use, in 2
    by 2 and 3 by 3 sizes.

`homework_set.rhm`
:   An assignment: two sets over four of the grammars above. Run it with
    `rhema run homework_set.rhm --run homework`.

## Named questions

Most grammars have one question, `main`. `calculus.rhm` also offers
`derivative` and `integral` separately, so that a set can ask for one
kind:

```rhema
3 of calc.derivative(cost ~ 6 spread 2)
1 of calc.integral(cost = 5)
```
