# Difficulty budgets

Every grammar in the library sets its difficulty the same way: a budget,
an inherited attribute called `cost`, that the question spends exactly.
Chapter 2 of the tutorial explains the mechanism; this page is about using
it.

## What a budget pays for

A production pays its price and divides the rest between its parts, and a
leaf stands only where the rest of the budget buys it. Prices are chosen so
that a harder operation costs more: in `arithmetic.rhm` a sum costs 1 and a
quotient 4, and each digit beyond the first costs 1; in `calculus.rhm` a
product costs 3 because it calls for the product rule, and a function of a
compound costs 3 more than a function of `x` because it calls for the chain
rule. The price of every grammar is in the [library tables](library.md).

Cost is not length. One budget buys questions of several sizes, so two
questions at the same budget may look different and ask for the same amount
of work.

Grammars whose questions come in a few fixed forms (a dot product, a cross
product, a unit vector) give each form a price and offer it only at exactly
that budget.

## Choosing a budget

The default in each file is a middle difficulty. For a single question type:

```text
$ rhema run boolean.rhm --set cost=6      # easy
$ rhema run boolean.rhm --set cost=10     # medium, the default
$ rhema run boolean.rhm --set cost=14     # hard
```

Small budgets buy few different questions. For `boolean.rhm`, measured on
500 questions at each budget:

| Budget | Distinct questions | Answer true |
|---|---|---|
| 4 | 34% | 52% |
| 6 | 63% | 54% |
| 8 | 87% | 50% |
| 10 | 97% | 53% |
| 14 | 100% | 53% |

A set drawn at a budget where few questions are distinct will repeat
itself, or fail under `distinct`, so stay above about 6 for this grammar.

## An assignment's difficulty is a mean

For an assignment, fix the average rather than every question:

```rhema
3 of calc.derivative(cost ~ 6 spread 2 low 2)
```

draws three budgets around 6 and adjusts them so that their mean is exactly
6: some easier, some harder, at a known level overall. `rhema run` reports
the mean of each part. See chapter 7 of the tutorial.

## Measuring a grammar

`tools/rhema_difficulty.py` in the repository measures what each budget buys:

```text
$ python3 tools/rhema_difficulty.py report generator/stdlib/boolean.rhm --at 6,10,14
$ python3 tools/rhema_difficulty.py levels generator/stdlib/boolean.rhm
```

`report` prints, for each budget, the share of distinct questions, the share
of the most common answer, the length of the displayed expression and the
size of the derivation tree. `levels` suggests an easy, a medium and a hard
budget: easy is the least budget at which at least half the questions are
distinct, medium is the default, hard is as far above medium as easy is
below.

## Giving your own grammar a budget

1. Declare `attribute cost = N split`, with `N` a middle difficulty.
2. Give each production a price with `cost = -PRICE` and a guard
   `when cost >= PRICE`; give each leaf the guard `when cost = 0` (or the
   price of the leaf, if a leaf has one).
3. Make every budget spendable: from the smallest question upwards, every
   whole number must be the total price of some tree, or a node will receive
   a budget no production can take.
4. Check with `rhema run --set cost=N` over a range of `N`; a gap shows as
   `no rule for 'E' fits`.
