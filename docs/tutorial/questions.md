# Several questions in one file

The sequence of chapter 4 can be asked three ways: both parts, the term
alone, or the sum alone. A file can declare all three over the same rules.

```rhema
--8<-- "questions.rhm"
```

```text
$ rhema list questions.rhm
questions:
  main           start Q, context Numeric
  nth            start Q, context Numeric
  sum            start Q, context Numeric

$ rhema run questions.rhm --question sum --count 1
 1. An arithmetic sequence has first term [`a_1 = -2`] and common
difference [`d = 5`]. Find the sum of its first [`14`] terms. [___]
    answer: 427
```

## Named questions

A `question` block declares one more question type:

```rhema
question sum {
  start Q
  prompt "... Find the sum of its first [`{n}`] terms. {answer sum}"
}
```

It holds what a file otherwise says once at the top level: `start`,
`prompt`, `answer`, and optionally `context` and `width`. Everything else,
the productions, attributes, randoms and lets, belongs to the file and is
shared by all its questions. Two questions differ only in where they start
and how they ask.

The top-level `start`, `prompt` and `answer` are themselves a question,
named `main`. That is the one `rhema` generates unless told otherwise:

```text
$ rhema run questions.rhm                      # main
$ rhema run questions.rhm --question nth       # one named question
```

A file made only of `question` blocks has no `main`; its first block is the
default.

## Starting where you need to

A block may start at a different symbol from the file, which is how one
grammar offers its parts separately. The library's `calculus.rhm` builds a
derivative under `D` and an integral under `I`, and declares:

```rhema
question derivative { start D  prompt "{D.text}"  answer D.answer_value }
question integral   { start I  prompt "{I.text}"  answer I.answer_value  cost = 7 }
```

`cost = 7` in a block sets the budget the question starts with, in place of
the file's `attribute cost = ...` line. `--set cost=N` still overrides it.

## Mistakes are reported with the block's name

```text
$ rhema run questions.rhm --question last
questions.rhm: error: 'last' is not a question of this grammar; it has main, nth, sum
```

The checker treats each block as it treats the top level: a missing
`start` or `prompt`, a prompt naming a symbol other than the block's start,
an attribute the file does not declare, are each reported with the name of
the block.

**Next:** chapter 6 uses questions and expressions from the library in a
file of your own.
