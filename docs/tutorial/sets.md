# A whole assignment

An assignment is more than questions drawn one at a time. It has parts, a
range of difficulty, no two questions alike. A `set` says all of that in the
file, and `rhema` turns it into one paper.

```rhema
--8<-- "assignment.rhm"
```

The file has no question of its own. It imports the sequence question of
chapter 5 and two library grammars, and declares a set:

```text
$ rhema run assignment.rhm --run week3
week3: 8 questions in 3 parts

1. Sequences

1  [seq.main; ]
An arithmetic sequence has first term [`a_1 = 0`] and common
difference [`d = 5`].

(a) Find [`a_{14}`]. [___]

(b) Find the sum of its first [`14`] terms. [___]
    answers: 65; 455

2. Differentiation
  2(a)  [calc.derivative; cost 5]
Differentiate the function with respect to x:
[`f(x) = \tan\left(\ln\left(x\right) + x\right)`].
    answer: Formula((1/x+1)/cos(ln(x)+x)^2)
  ...

budget means:
  part 1 Sequences:
  part 2 Differentiation: cost 5.75 over 4
  part 3 Logic: cost 10.00 over 3
```

## Entries

```rhema
3 of calc.derivative(cost ~ 6 spread 2 low 2)
```

An entry asks for a number of questions of one type: `main` or a named
question of this file, or `alias.name` from an imported module. In
brackets, it says how to start the question's budgets, in one of three
ways:

`cost = 6`
:   Every question of the entry starts at 6.

`cost in {8, 10, 12}`
:   Each question takes one of the values, and the list is used up before
    any value repeats: three questions get 8, 10 and 12 in some order.

`cost ~ 6 spread 2`
:   Budgets are drawn around 6, with a spread of about 2, and then adjusted
    so that their mean is exactly 6. `low 2` keeps every budget at 2 or
    above. `allowed {4, 6, 8}` restricts the draw to those values, for a
    grammar whose forms only exist at certain prices; the mean is then as
    close to 6 as they allow.

The last form is how difficulty is meant to be set for an assignment: not
"every derivative costs 6", which makes them all alike, but "the
derivatives average 6", which gives some easier and some harder, at a known
level overall. The listing ends with the mean of each part's budgets to show
it.

`N of any(A, B)` draws each of the `N` questions from the listed types
evenly.

## Parts and numbering

`part "Heading"` starts a part. Its questions are numbered `1(a)`, `1(b)`
and so on, under the heading. A set without `part` lines numbers each
question on its own: `1`, `2`, `3`.

## Constraints

`distinct`
:   No two questions have the same shape: the same productions, in the same
    places, with only the numbers different. `3 + 4` and `7 + 2` are one
    shape. Questions of different types are never repeats of each other,
    with one exception in the 0.1.1 release: two named questions on the same
    rule, such as `seq.nth` and `seq.sum`, count as repeats there. The
    repository has the fix.

`balanced`
:   No three questions in a row with the same coded answer, for questions
    answered with true/false or a small code such as 0, 1, 2.

`ordered`
:   Within a part, easier questions first, by total budget.

When a constraint cannot be met, such as `distinct` over more questions than
a grammar has shapes, `rhema` says which question it could not place
instead of trying for ever.

## The same paper every time

The set's name is the assignment's name, and the paper is fixed by it:
running `week3` today and next month gives the same questions. Chapter 8
covers giving each student a paper of their own, and getting the paper into
WeBWorK.

**Next:** chapter 8.
