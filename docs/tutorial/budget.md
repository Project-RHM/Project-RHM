# Difficulty is a budget

The questions of chapter 1 are all equally hard. This file asks sums,
differences and products of any length, and how long they are is decided
when the questions are generated.

```rhema
--8<-- "budget.rhm"
```

```text
$ rhema run budget.rhm --set cost=2 --count 3
 1. What is the value of [`4 + (4 + 6)`]?
    answer: 14
 2. What is the value of [`3 - 4`]?
    answer: -1
 3. What is the value of [`8 + 2 + 3`]?
    answer: 13

$ rhema run budget.rhm --set cost=8 --count 3
 1. What is the value of [`(4 - 6 + (3 + 4)) \cdot (5 + 8)`]?
    answer: 65
 2. What is the value of [`3 + (7 + 7 + (5 + 7) + (4 - 2 + 5))`]?
    answer: 36
 3. What is the value of [`(6 + 2 - (8 + 5)) \cdot (7 + 8)`]?
    answer: -75
```

## Productions that refer to themselves

`E -> E + E` says that an `E` may be two smaller `E`s with a plus between
them. A grammar like this can make expressions of any size; on its own it
would never stop. Something has to say how far to go.

## Inherited attributes

That something is an *inherited attribute*, declared with `attribute`:

```rhema
attribute cost = 4 split
```

Synthesized attributes, from chapter 1, travel up the tree: a node computes
them from its children. Inherited attributes travel down: a node receives
one from its parent before its children exist. `cost` starts at 4 at the
root (or at whatever `--set cost=N` says) and is handed down.

`split` says how it is handed down. At each production, what is left of the
budget is divided between the children that are symbols of the grammar, in
every possible way with equal chance. The other choice, `copy`, gives every
child the whole value; it suits settings that are not spent, such as a limit
on the number of digits.

## Spending

Each production says what it costs:

```rhema
E -> E + E   when cost >= 1   weight 3 {
  cost  = -1
  ...
}
```

`cost = -1` takes one from the budget before it is divided between the two
`E`s. So a sum costs 1, a difference 2 and a product 3, and a number costs
nothing. Whatever budget the root starts with, the finished question has
spent exactly that much: `--set cost=2` gives one difference or two sums,
never a product.

`when cost >= 1` is a *guard*: the production may only be chosen when it
holds. A guard can only look at inherited attributes, because the children
do not exist yet when the choice is made. The number production says
`when cost = 0`, so a number appears exactly where the budget has run out.

Among the productions whose guards hold, one is chosen at random,
in proportion to its `weight` (1 when not given). The weights here make sums
more common than products.

## Every budget must be spendable

When a node receives a budget that no production can take, generation
stops. Remove the sum production and ask for a budget of 1, which only a sum
could spend:

```text
$ rhema run gap.rhm --set cost=1
gap.rhm: error: no rule for 'E' fits {cost=1}
```

This is not retried, because no amount of retrying could help: the grammar
has no way to spend 1. A grammar that spends a budget should be able to
spend every whole number from its smallest question upwards. With prices 1,
2 and 3 and a leaf at 0, this one can.

The compiler also refuses a recursion that does not spend. Delete the
`cost = -1` line from the sum production and check the file:

```text
$ rhema check loop.rhm
loop.rhm:13:1: error: this rule can reach 'E' again without spending any inherited attribute, so a derivation could circle forever; make the loop consume a budget, for example 'cost = -1'
```

## Requirements

The difference production says

```rhema
require $1.value != $3.value
```

A `require` is checked after the children are built. When it fails, that
subtree is built again with fresh random choices. Here it rules out
differences of zero, such as `7 - 7`, which would make a question cheaper
than its price.

Prefer guards to requirements where you can: a guard prevents a bad choice,
a requirement discards one after the work is done.

## Brackets come from precedence

```rhema
precedence 1 left + -
precedence 2 left *
```

`infix($1, "+", $3)` writes its operands with brackets only where the
precedence table needs them, which is why the questions above read
`4 + (4 + 6)` and `(6 + 2 - (8 + 5)) \cdot (7 + 8)` with no extra brackets.
The operator's text may differ from its symbol: the product is the symbol
`*` in the grammar and `\cdot` in the question.

## Choosing a difficulty

The budget is how a teacher asks for an easier or a harder question of the
same kind:

```text
$ rhema run budget.rhm --set cost=3
$ rhema run budget.rhm --set cost=12
```

Every grammar in the library spends a budget called `cost` in this way, with
prices chosen for its subject; the [difficulty page](../reference/difficulty.md)
lists them. Chapter 7 shows how a whole assignment fixes the *average*
budget of its questions rather than each one.

**Next:** chapter 3 looks at what the attributes can hold besides numbers and
text.
