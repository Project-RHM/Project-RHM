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

Four grammars say what common mistakes lead to (chapter 9 of the tutorial).
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

The mistakes of `calculus.rhm` concern its derivative questions; an
integral question lists none. `power_term_by_term` is declared in
`polynomial_core.rhm` and concerns a question that asks for the expansion;
`factoring.rhm` is built on the same productions and lists none. A modulus
question of `complex.rhm` lists none.

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
