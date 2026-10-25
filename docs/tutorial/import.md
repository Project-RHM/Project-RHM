# Building on the library

Rhema comes with grammars for most of first-year mathematics. A file can use
their parts without copying them. This one asks for second derivatives,
using the expressions of the library's calculus grammar.

```rhema
--8<-- "import.rhm"
```

```text
$ rhema run import.rhm --count 3
 1. Find the second derivative of [`f(x) = x^{3} - (\ln\left(x\right) - x)`].
    answer: Formula(3*2*x--1/x^2)
 2. Find the second derivative of [`f(x) = x \cdot \sin\left(x\right)`].
    answer: Formula(cos(x)+cos(x)-x*sin(x))
 3. Find the second derivative of [`f(x) = 5 - x - e^{3 \cdot x}`].
    answer: Formula(-(exp(3*x)*3*3))
```

## import

```rhema
import "calculus.rhm" as calc
```

`import` loads another file as a *module*: it is checked on its own, and
everything it declares is reached through the name after `as`.

| In `calculus.rhm` | From this file |
|---|---|
| the nonterminal `F` | `calc.F`, on the right of a production |
| its randoms and lets | `calc.NAME` in an expression, `{calc.NAME}` in a prompt |
| its questions | `calc.derivative`, in a set (chapter 7) |

Nothing in the module can clash with this file. The library's two Boolean
grammars both have a start symbol `Q`, an attribute `cost` and a random
`phrasing`, drawn differently; imported as `bool` and `laws` they sit side
by side.

The file is looked for beside this one, then in the installed library, so
`calculus.rhm` needs no path. ([The rhema command](../reference/command.md#finding-imported-files)
lists every place searched.)

## Using an imported symbol

```rhema
M -> calc.F(cost = cost) {
  answer_value = differentiate(differentiate($1.formula, "x"), "x")
  ...
}
```

`calc.F` is expanded with the module's own productions. `$1` is that
subtree, and its synthesized attributes are read as usual: `$1.formula` and
`$1.latex` are what `calculus.rhm` computes at `F`. The checker knows `$1`
is a `calc.F` and checks the names against the module. Write `$1.value` for
`$1.latex` and it says:

```text
$ rhema check import_bad.rhm
import_bad.rhm:15:3: error: $1 is calc.F, which does not carry 'value'; it has formula, latex, constant, monomial, constants_used, linear_terms, power
```

## Arguments at the boundary

`calc.F(cost = cost)` sets the module's inherited attribute `cost` for that
subtree. An attribute not named takes the module's own default; `calc.F`
alone would start at `calculus.rhm`'s `attribute cost = 7`.

The argument is computed in this file, before the subtree exists, and the
module's budget is its own: the module never sees this file's `cost`, only
the value handed to it. That is what lets grammars priced on different
scales work together. A derivative of 8 is harder than a proposition of 8,
so a file that offers either writes the exchange rate where they meet:

```rhema
M -> calc.F(cost = cost)     "derivative" { ... }
M -> bool.E(cost = cost + 2) "boolean"    { ... }
```

When this file's attribute is `split`, `cost = cost` hands the module the
share a local symbol would have received, so the budget is still spent
exactly across the boundary.

## include, for extending

`include "file.rhm"` is the older, simpler mechanism: it pastes the other
file's declarations into this one, with no prefix. Use it to *extend* a
grammar, adding productions to its symbols or asking its question with a
different prompt. Use `import` to *combine* grammars.

**Next:** chapter 7 puts questions from several files into one assignment.
