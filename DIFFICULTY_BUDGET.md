# Difficulty as a Budget

*How a grammar prices its questions, how a caller chooses a difficulty, and
how a set of questions is held to a chosen average.* A Chinese version of
this document is in `DIFFICULTY_BUDGET.zh.md`.

## 0. Where each grammar stands

| grammar | budget spent on | default | section |
| --- | --- | --- | --- |
| `boolean.ag` | connectives, priced by kind and by what they negate | 10 | 2–4 |
| `arithmetic.ag` | operations and the digits of the numbers | 12 | 6 |
| `calculus.ag` | the differentiation rules a function calls for, plus 2 for an integral | 7 | 7 |
| `complex.ag` | operations; modulus and power of `i` are fixed forms | 4 | 8 |
| `set.ag` | operations and whether a leaf is an interval | 7 | 9 |
| `boolean_equiv.ag` | the law plus its subexpressions | 6 | 10 |
| `vector.ag`, `sequence.ag`, `library_*.ag` | fixed forms, each at its price | 2, 2, 3 | 10 |

## 1. The problem with a length budget

Every grammar so far controlled difficulty with a length budget: `len` is the
number of operators, handed down the tree with `split` and spent one unit per
production. Length is a poor measure of difficulty. In `boolean.ag` the old
setting `len = 3` produced questions whose operator cost (defined below)
ranged from 4 to 18 with a mean of 10.2: a biconditional nested in a
conditional and three conjunctions both counted as three operators, and a
"medium" set mixed the two freely.

## 2. Operator cost

The teacher's first method: treat each operator as a function from the
difficulty of its operands to the difficulty of the compound it builds. In
`boolean.ag` the prices are

| construct | price |
| --- | --- |
| negated variable, `\neg A` | 1 |
| conjunction, disjunction | 2 plus the operands |
| negated compound, `\neg (...)` | 3 plus the compound |
| conditional | 4 plus the operands |
| biconditional, exclusive or | 6 plus the operands |

So `A \land B` costs 2, `\neg \neg C` costs 4 (a negated compound whose
compound is a negated variable), and `(A \leftrightarrow B) \lor (A \to B)`
costs 2 + 6 + 4 = 12. The prices are starting values chosen by judgement; they
have not been fitted to student results. They live in the productions of the
grammar, so revising them is an edit to one file.

## 3. Cost as a budget: construct, do not filter

The cost is not computed after generation and then filtered. It is the budget
itself. `boolean.ag` declares

```
attribute cost = 10 split
```

and every production pays its price and splits what is left between its
operands:

```
E -> E "\to" E   when cost >= 4  weight 2 { cost = -4  ... }
E -> "\neg" V    when cost = 1   weight 2 { cost = -1  ... }
E -> "\neg" E    when cost >= 4  weight 2 { cost = -3  ... }
E -> V           when cost = 0             { ... }
```

Three rules make this work:

1. **The guard is the least a production can spend.** `\to` needs at least
   its own price, 4. Negating a compound needs 3 for itself plus at least 1
   for the operand, so its guard is 4; with at least 1 left the operand is
   never a bare variable, which is what makes it a compound.
2. **A variable stands only where nothing is left**, so the budget is always
   spent exactly.
3. **Every whole number can be spent.** 0 is a variable, 1 a negated variable,
   2 and 3 a conjunction or disjunction, 4 and above anything. A node never
   finds itself holding a budget no rule can take, so the budget never causes
   a retry.

The engine needed no change: inherited attributes already support `split`,
per-production deductions and `--set`. The difference from the old grammar is
only in what the productions deduct and when they are allowed.

## 4. Choosing a difficulty

```bash
cd generator
_build/default/ag/agrun.exe --set cost=6  ag/boolean.ag    # easy
_build/default/ag/agrun.exe --set cost=10 ag/boolean.ag    # medium, the default
_build/default/ag/agrun.exe --set cost=14 ag/boolean.ag    # hard
```

Measured on 1000 questions per budget (seed 7):

| budget | distinct questions | operators | questions using →, ↔, ⊕ | answer true |
| --- | --- | --- | --- | --- |
| 4 | 16% | 1–3 | 20% | 57% |
| 6 | 50% | 1–4 | 39% | 58% |
| 8 | 80% | 2–5 | 58% | 54% |
| 10 | 95% | 2–7 | 70% | 55% |
| 12 | 99% | 2–8 | 78% | 56% |
| 16 | 100% | 3–10 | 86% | 51% |

Two things to read off this table. Cost is not length: at budget 10 the
operator count runs from 2 to 7. And small budgets buy few distinct
questions, so a set should not be built below about 6.

## 5. The tool: `tools/ag_difficulty.py`

The tool drives the built `agrun.exe` and works for any grammar whose
difficulty is a budget; `--budget NAME` names the attribute (default `cost`,
and `--budget len` measures the old length budgets the same way).

```bash
python3 tools/ag_difficulty.py report generator/ag/boolean.ag --at 6,10,14
python3 tools/ag_difficulty.py levels generator/ag/boolean.ag
python3 tools/ag_difficulty.py set generator/ag/boolean.ag --mean 10 --spread 2 --count 10
python3 tools/ag_difficulty.py set generator/ag/boolean.ag --targets 6,8,10,12 --pg-dir out/
```

- `report` prints, for each budget, the share of distinct questions, the
  share of the most common answer, the length of the displayed expression,
  and the node count and depth of the derivation tree. The last two come from
  `--ast-out`, so they are available for every grammar.
- `levels` suggests three budgets: easy is the least budget at which at least
  half of the generated questions are distinct, medium is the grammar's
  default, hard is as far above medium as easy is below it. It is a
  suggestion to start from, not a rule.
- `set` is the expectation method (the teacher's second method): the mean
  budget of a set is the standard. It draws one budget per question around
  `--mean` with spread `--spread`, adjusts them so that the mean is met
  exactly, and generates each question at its own budget. With `--pg-dir` it
  also writes one `.pg` file per question.

## 6. A second grammar: arithmetic

`arithmetic.ag` prices two things from one budget, because the difficulty of
a sum depends as much on the size of the numbers as on the operations:

| construct | price |
| --- | --- |
| addition | 1 plus the operands |
| subtraction | 2 plus the operands |
| multiplication | 3 plus the operands |
| division | 4 plus the operands |
| a number | one per digit beyond the first: 1 digit 0, 2 digits 1, 3 digits 2, 4 digits 3 |

So `98 \cdot 347` costs 3 + 1 + 2 = 6 and `(25 + 536) \div 7` costs
4 + 1 + 0 + 2 = 7. An operation pays its price and splits the rest between
its operands; a number stands wherever the rest of the budget buys its digits
(`when cost <= 3`), and spends it on them. A one-digit number is drawn from 2
to 9, since 0 and 1 make an operation trivial. `digit` remains as a cap on
the number of digits (default 4, which is also the most that is priced). The
default budget is 12; the old default, eight operations on four-digit
numbers, produced answers of a dozen digits and was not kept.

The weights matter more here than in `boolean.ag`. Operations are cheap and
numbers are capped at 3, so with the old weights (addition 10, number 1) a
budget of 18 became a chain of a dozen one-digit additions. With the number
rule at weight 15 and the operations at 6, 4, 3 and 2, a budget is as likely
to go into bigger numbers as into more operations. Samples at budgets 6, 12
and 18:

```
98 \cdot 347                              7 \cdot (7 + 4) - 9
(347 - (6 + 7)) \cdot (102 + 55)          589 \div (825 - 8) - 7
825 - 8 - (9029 - 4) \cdot (7 \cdot 18)    (25 + 536) \div ((6 + 5) \cdot 3 - 2) + 6203
```

Division still allows a fractional answer, as before. Requiring exact
division is a type-specific factor for later; with random operands it would
reject most candidates.

A known approximation: multiplying two four-digit numbers costs 3 + 3 + 3 = 9,
the same as nine one-digit additions, although by hand it is much harder. A
budget is spent top-down, so an operation pays before its operands' sizes are
known; the true work of a multiplication (roughly the product of the digit
counts) cannot be priced this way. A bottom-up `work` attribute, computed
from the finished tree and used for reports and calibration, would capture
it without changing the budget mechanism.

## 7. A third grammar: calculus

In `calculus.ag` the operators are differentiation rules, and the price of a
construct is the rule it makes the student apply:

| construct | price | rule |
| --- | --- | --- |
| sum, difference | 1 plus the operands | sum rule |
| product | 3 plus the operands | product rule |
| power of a leaf, `x^n` or `(cx)^n` | 1 plus the leaf | power rule |
| power of a compound | 3 plus the compound | chain rule |
| sin, cos, exp of a leaf | 1 plus the leaf | the table of derivatives |
| sin, cos, exp of a compound | 3 plus the compound | chain rule |
| leaf `x`, a constant | 0 | |
| leaf `cx` | 1 | a coefficient to carry |

As with negation in `boolean.ag`, a power or a function has two productions:
one on a leaf, allowed while the budget is 1 or 2, and one on a compound,
which needs 3 for itself and at least 2 inside. No leaf can spend 2, so the
operand of the compound rule is always a compound, and every printed
expression has exactly one price.

An integral question is built from the same F but is harder for the same F:
a chain becomes a substitution, a product an integration by parts. The
integral form therefore pays 2 before F is built and needs at least 1 left
for F, so that the integrand is never the derivative of a bare `x`. Below a
budget of 3 only derivative questions are generated.

Two details keep the pricing unambiguous. A synthesized flag `constant`
marks a bare constant leaf; a product refuses a constant operand (a constant
times `x` would print like the leaf `cx`), and a sum, power or function
refuses operands that would fold into a constant. The coefficient of a `cx`
leaf is never 1 or -1, which the formula library would simplify away.

The default budget is 7. Priced with this table, the old grammar's questions
(`len = 3`) had a mean of 5.0 with mode 7 and range 0 to 9. Measured on 500
questions per budget:

| budget | distinct | samples |
| --- | --- | --- |
| 3 | 45% | `e^{4x} + x`, `x + \cos x - 7`, `\int (-4)\,dx` |
| 4 | 59% | `\sin(x) \cdot x`, `\cos(4x) - x^2`, `\int \sin(4x) \cdot 4\,dx` |
| 7 | 95% | `\cos(x - (4x + x) - x)`, `((4x)^5 - 4x)^3`, `\int 2(x + 2x) \cdot 3\,dx` |
| 9 | 99% | |
| 12 | 100% | |

The test re-prices the finished formula tree (`Ag_formula.t`) rather than the
derivation, with `Negate` costing nothing since it only renders a negative
coefficient.

Three habits of the old grammar were removed while pricing it, because each
made a question cheaper than its price: a sum or difference whose derivative
is zero (`x - (7 + x)`) is refused; a product of two monomials (`x^5 \cdot x`)
is refused, since it collects into one; a sum with two linear terms
(`x^4 - x + x`, `3x + x`) is refused, and a derivative question carries at
most one additive constant. A negative coefficient now prints as
`-5 \cdot x` rather than `-(5 \cdot x)`: the formula renderer drops the
brackets around a negated product or quotient, which changes nothing in the
value.

## 8. A fourth grammar: complex numbers, with fixed forms

`complex.ag` mixes two kinds of question: recursive expressions (arithmetic
and conjugate) and two fixed forms (modulus of a Pythagorean-triple number,
and a power of `i`). The expression is priced as before:

| construct | price |
| --- | --- |
| sum, difference | 1 plus the operands (each component once) |
| product | 3 plus the operands (four products and `i^2 = -1`) |
| leaf `a + bi` | 0 |

The question forms decide what the budget may buy:

| form | price | budget |
| --- | --- | --- |
| arithmetic | the expression's cost | at least 1: computing a bare leaf is no question |
| conjugate | the expression's cost, no premium | any, 0 is the conjugate of a leaf |
| modulus | fixed 2 | exactly 2 |
| power of `i` | fixed 1 | exactly 1 |

A fixed form does not scale with anything, so it is a price, not a budget to
spend. To keep the budget spent exactly, such a form is offered only when the
budget equals its price. The consequence is deliberate: at the default budget
of 4 a mixed run produces arithmetic and conjugate questions only; a set drawn
around a mean (`ag_difficulty.py set --mean 4 --spread 2`) brings the fixed
forms in at its low end, where a power of `i` belongs. Making them scale (a
modulus with an integer factor, a power of `i` times an expression) would be a
change of question, not of price.

The product carries the heavier weight (3 against 2 for sum and difference);
with the old weights half the questions at budget 4 were chains of four sums.
The default budget is 4; priced with this table the old grammar's arithmetic
questions (`len = 2`) had a mean of 3.1 and its conjugates 2.9.

| budget | distinct | samples |
| --- | --- | --- |
| 0 | 30% | the conjugate of `(4 - 6i)` |
| 1 | 80% | `(6 + 2i) + (-2 + 2i)`, `i^{n}` |
| 2 | 86% | the modulus of `8 + 6i`, `(5i) + (-3 + 2i) + (-2 + 6i)` |
| 3 | 100% | `(6 + 2i) \cdot (-2 + 2i)` |
| 4 | 100% | `(6 + 2i) \cdot ((-6 + i) + (-2 + i))` |
| 6 | 100% | `((-2 + 6i) + (4 + 4i) - (1 - 4i)) \cdot ((5 - 3i) + (3 + 2i))` |

The test re-prices the printed expression: every leaf is an innermost
bracketed group, so after removing those, each remaining `+` or `-` is a
binary operator worth 1 and each `\cdot` worth 3; a fixed form is priced by
its kind.

## 9. A fifth grammar: sets, and a rule the engine imposes

`set.ag` computes unions, intersections and differences of three sets, each
of which is a finite set or an interval. Both the operation and the kind of
operand are priced:

| construct | price |
| --- | --- |
| union | 1 plus the operands |
| intersection, difference | 2 plus the operands |
| leaf that is a finite set, `{3, 5, 10}` | 0 |
| leaf that is an interval, `(-5, -1]` | 1 |

Pricing the leaf by its kind is the type-specific factor here: an interval
against a finite set, `[1, 6) \setminus \{3\}`, is the hard case, and how
often each set is used is decided by the expression, so the price belongs on
the leaf rather than on the question.

Two things the engine imposes. First, **a node left with a budget that no
rule can take is an error, not a retry** (`no rule for 'E' fits`): the
grammar must make every budget a node can receive spendable, in every mode.
With the difference priced at 3, the difference-only mode would strand a node
holding 2, so the difference is priced at 2. Second, a leaf rule guarded by
the kind of its set (`when cost = 1 and a_uses_interval`) only exists when
such a set was drawn, so the grammar guarantees that at least one set is
finite and at least one is an interval: `C` is finite when `A` and `B` are
both intervals, an interval when both are finite, and random otherwise. The
old grammar drew the three kinds independently.

The default budget is 7; priced with this table the old grammar's questions
(`len = 3`) had a mean of 6.9 and a range of 3 to 10. The test sweeps every
mode against every budget from 0 to 12 and re-prices the printed expression,
with each leaf letter priced by the kind of the set the question defines
under it.

| budget | samples |
| --- | --- |
| 1 | `B \cup A` |
| 2 | `B \cap A`, `C \cup (C \cup A)` |
| 4 | `(C \cup A) \setminus B`, `A \cap B \cap A` |
| 7 | `A \setminus (B \cup (A \cup B) \cap (B \cup A))` |
| 10 | `(B \cup B \cap C \setminus (C \cap B)) \cap (C \cup B)` |

## 10. The remaining grammars

**Boolean equivalence** (`boolean_equiv.ag`, default 6). A claim is a law
stated over one or two subexpressions. The law pays its price, double
negation 1, biconditional 3, every other law 2 (the deliberately broken
variants cost the same as the law they break, since the student cannot tell
them apart in advance), and the rest is split between the subexpressions,
priced as in `boolean.ag`: and/or 2, a negated variable 1, a negated compound
3 plus the compound. The least budget is 1, since there is no law for
nothing. Priced with this table, the old grammar's claims (`len = 2`) had a
mean of 5.8 and range 4 to 8. The test reads the law off the left-hand side
and re-prices each subexpression from its printed form. At budget 1 only
double negation fits and every claim holds; at 2 the share of claims that
hold is 71%, and from 4 upwards it settles between 60% and 70%, so a set
should not be built below about 3.

**Grammars of fixed forms.** `vector.ag`, `sequence.ag` and the four
`library_*.ag` grammars have no recursion: each question form is a fixed
shape with random numbers in it. A form is therefore a price, not a budget to
spend, and is offered only when the budget equals its price, as the fixed
forms of `complex.ag` are. A single mode (`vector_mode`, `question_mode`)
must be run at the price of its form; a mixed run at one budget shows the
forms of that price; a set drawn around a mean (`ag_difficulty.py set
--allowed ...`) mixes them.

| grammar (default) | price 1 | price 2 | price 3 | price 4 |
| --- | --- | --- | --- | --- |
| `vector.ag` (2) | parallel vector | dot product, norm, same direction | unit vector | cross product |
| `sequence.ag` (2) | arithmetic nth term | geometric nth term, arithmetic sum | geometric sum | |
| `library_linear.ag` (3) | | one bracket | brackets on both sides | fraction |
| `library_quadratic.ag` (3) | | two integer roots | repeated root, no real roots | two rational roots |
| `library_polynomial.ag` (3) | evaluation | degree | expansion, coefficient | derivative |
| `library_formula.ag` (3) | | composition | logarithm, radical, tangent | quotient, combined |

Two smaller cleanups came with the pricing: `boolean.ag` and
`boolean_equiv.ag` no longer negate a negation (`\neg \neg C` read as a
slip, and a negated variable needs no brackets when spliced into a law), and
`arithmetic.ag` no longer subtracts equal values (`6 - 6`).

These prices rank the forms within one grammar by the work they ask for;
they are not comparable across grammars. What the budget cannot buy in a
fixed form is the size of its numbers, which stays random: a sequence with
`n = 8` costs the same as one with `n = 2`. Giving such a form a scalable
part (a larger index, a bigger exponent) would be a change of question.

`tools/ag_difficulty.py` reports `no question at this budget` for a budget a
grammar has nothing at, and `set --allowed 1,2,3,4` draws only from the
budgets a grammar of fixed forms accepts.

## 11. Giving another grammar a cost budget

1. Decide the price of each production. Price an operator by what it asks of
   the reader, and let the price depend on the operands where that matters
   (negation is the example above).
2. Replace the length budget with `attribute cost = D split`, where `D` is the
   budget of a typical question.
3. In every production, deduct the price (`cost = -p`) and guard it with the
   least it can spend (`when cost >= p + least operand cost`).
4. Make the leaf rule the only rule allowed at `cost = 0`.
5. Check that every whole number from 0 upwards can be spent, at every node
   and in every mode the grammar offers. A node holding a budget that no rule
   fits is an error, not a retry, so a gap is a failing seed, not a rarer
   question. If some values cannot be spent, add a rule for the gap or lower
   a price; a rule whose guard depends on a random value must be backed by a
   guarantee that the value it needs is always drawn.
6. Add a test like section 3 of `ag_boolean_test.ml`, section 2b of `ag_engine_test.ml` or `check_cost_budget` in `ag_calculus_test.ml` and `ag_set_test.ml`: generation succeeds at
   every budget in range, `Ag_engine.consumption tree "cost"` equals the
   budget, and an independent reader re-prices the printed expression to the
   same number.
7. Run `tools/ag_difficulty.py report` and look at the distinct share before
   choosing levels.

## 12. What this does not do

- It prices the expression, not the wording. The wording is held constant.
- It does not compare question types: a cost of 10 in `boolean.ag` and a cost
  of 10 in another grammar are not the same difficulty.
- It does not know whether the prices match what students find hard. That
  needs results from a class, and is the next step once the course test has
  been run.
