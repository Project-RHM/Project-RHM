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

Fifteen grammars say what common mistakes lead to (chapter 9 of the tutorial).
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
