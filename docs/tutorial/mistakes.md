# Mistakes students make

A right answer does not always come from right working. A student who
believes that a product is differentiated factor by factor gets
`x \cdot 0` right, and one who subtracts the smaller number from the larger
gets `7 - 3` right. A grammar can say what a mistake is. `rhema` then shows
what each mistake leads to, and never asks a question in which a mistake
changes the working and the answer still comes out right.

```rhema
--8<-- "mistakes.rhm"
```

```text
$ rhema run mistakes.rhm --set cost=6 --count 4
 1. Differentiate [`\sin\left(x \cdot 5 \cdot x\right)`] with respect to [`x`].
    answer: Formula(cos(x*5*x)*(5*x+x*5))
    mistake factor_by_factor: Formula(cos(x*5*x)*5)
    mistake no_chain: Formula(cos(x*5*x))
 2. Differentiate [`6 \cdot x \cdot x + 6 \cdot x`] with respect to [`x`].
    answer: Formula(6*x+6*x+6)
    mistake factor_by_factor: Formula(12)
 3. Differentiate [`4 \cdot x \cdot \sin\left(x\right)`] with respect to [`x`].
    answer: Formula(4*sin(x)+4*x*cos(x))
    mistake factor_by_factor: Formula(4*cos(x))
 4. Differentiate [`2 \cdot x + 3 \cdot x + x + 4 \cdot x`] with respect to [`x`].
    answer: Formula(10)
```

Under each answer is what each mistake leads to. Question 3 holds a sine
and lists no `no_chain`: the inside of `sin(x)` is `x`, its derivative is 1,
and leaving it out changes nothing. Question 4 has no product and no sine,
so there is no mistake to make.

## Declaring a mistake

```rhema
mistake no_chain "leaves out the derivative of the inside"
```

names a mistake and says, in a few words, what the student does. The text
is for people: it is kept with the mistake and is what a report or a hint
would show.

## Where the mistake is made

A mistake is made at a step of the working, and a step is a production. The
production for a sine computes the derivative, and then says what the
mistaken student computes in its place:

```rhema
F -> "sin" F when cost >= 2 {
  cost = -2
  f = formula_sin($2.f)
  d = formula_multiply(formula_cos($2.f), $2.d)
  mistake no_chain d = formula_cos($2.f)
  latex = formula_latex(f)
}
```

A *mistake line*, `mistake NAME ATTRIBUTE = EXPRESSION`, is no part of the
question. When a question is generated it is skipped, and the node carries
the right `d`. It is read only afterwards, when the finished tree is worked
out again as that student would.

Everything else stays right. A student who leaves out the inside derivative
still adds and multiplies correctly, so in `x \cdot \sin(2x)` the mistaken
`d` of the sine goes up through the product rule as it stands, and the
answer comes out as `sin(2x) + x \cdot cos(2x)`. This is why the grammar
computes the derivative production by production, as an attribute, and does
not call `differentiate` once at the top: a mistake can only travel through
working that the grammar itself spells out.

## What the engine does with it

After a question is built and its answers are known, each mistake that some
production of the tree has a line for is tried. The tree is evaluated again
from the leaves up, reading that mistake's lines, and the answers are read
again. A value is *mistaken* when a line gave it a value other than the
right one, or when it was computed from a mistaken value. Then one of four
things is true:

- **No value changes.** Every line gave the value the production had
  already computed, as in `sin(x)`. The mistake is not made in this
  question, and nothing is listed.
- **The mistaken values never reach an answer.** The mistake says nothing
  about this question either. A file that also asked for the function
  itself, `answer F.f`, would build the same products and sines and list no
  mistakes, since no `d` is read.
- **An answer changes.** The mistake shows, and is listed with what it leads
  to.
- **A mistaken value reaches an answer and every answer is still right.**
  Wrong working would earn full marks, so the question is thrown away and
  built afresh.

Answers are compared as a marker compares them. Two formulas are the same
answer when they are the same function, however they are written.

So in every question `rhema` generates, a mistake that changes the working
changes an answer. The last case is rare in this grammar; it is common in
others. With `mistake smaller_from_larger value = cond(value < 0, -value,
value)` on a difference, `2 - 5 - (1 - 9)` is such a question: the right
working gives `-3 - (-8) = 5`, and the mistaken one `3 - 8`, taken as
`8 - 3 = 5`.

If a mistake changes the working of every question and the answer of none,
generation gives up and names it:

```text
zero.rhm: error: could not generate a question after 200 attempts; the most
frequent failure (200 of 200) was: the mistake 'one_more' gives the right answer
```

## What a line may say

A mistake line gives another value to something the production has already
computed: a synthesized attribute of its symbol, or a local name. It is
evaluated where it is written and may use everything above it, the right
value of its own name included:

```rhema
value = $1.value - $3.value
mistake smaller_from_larger value = cond(value < 0, -value, value)
```

The lines below it then see the mistaken value. A requirement is not
checked again under a mistake; requirements shape the question, and the
question is already built.

A mistake may lead to no value at all, such as a division by zero. The
question is kept, and the listing says `no answer`.

## In the library

Four of the library's grammars declare mistakes: `calculus.rhm`,
`complex.rhm`, `boolean.rhm` and the polynomial expansions. The
[library page](../reference/library.md#mistakes) lists them. Run any of
them to see what they lead to:

```text
$ rhema run calculus.rhm --question derivative
```

## Limits

- A mistake belongs to the file that declares it, and to files that
  `include` that file. A subtree built from an imported module's symbol is
  taken as it is: the importer's mistakes are not looked for inside it, and
  the module's own apply to the module's own questions.
- The mistaken answers are shown by `rhema run`. The WeBWorK and LaTeX
  output of a question is the same as without mistakes.
- A listed mistake says the question *can* tell it apart, not that the
  paper tests it. A paper of questions like `sin(x)` lists no `no_chain`
  and finds no student who makes it; look at the listing to see what a
  paper covers.
