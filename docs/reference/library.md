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

!!! note
    `counting.rhm`, `number_theory.rhm`, `series.rhm`, `limits.rhm`,
    `eigen.rhm` and `inequality.rhm` are in the repository, not in the 0.1.1
    package. To use them before the next release, build `rhema` from a
    clone of the repository.

--8<-- "QUESTION_TYPES.md:tables"

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
