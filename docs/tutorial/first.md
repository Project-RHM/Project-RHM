# A first question

Here is a complete Rhema file. Save it as `first.rhm`.

```rhema
--8<-- "first.rhm"
```

Check it, then ask for three questions:

```text
$ rhema check first.rhm
first.rhm: OK (1 rules; questions: main; sets: none)

$ rhema run first.rhm --count 3
 1. What is [`82 + 40`]?
    answer: 122
 2. What is [`83 + 52`]?
    answer: 135
 3. What is [`36 + 76`]?
    answer: 112
```

## Productions

A Rhema file is a grammar. Its rules, called *productions*, say what a
symbol may be made of. This file has one:

```rhema
E -> integer_between(10, 99) "+" integer_between(10, 99) { ... }
```

Read it as: *an `E` is a number from 10 to 99, a plus sign, and another such
number.* `start E` says that a question is an `E`. To make a question, the
compiler starts from `E`, picks a production for it, and builds whatever the
production asks for, which is how a question becomes a tree:

```text
E
├── integer_between(10, 99)   82
├── "+"
└── integer_between(10, 99)   40
```

`integer_between(10, 99)` is a *generator*: a leaf that draws a value. A
quoted string such as `"+"` is a leaf that stands for itself.

## Attributes

A tree on its own is not a question. The braces after a production say what
to compute at that node, from its children:

```rhema
value = $1.value + $3.value
latex = str($1.value) ++ " + " ++ str($3.value)
```

`$1` is the first symbol on the right of the arrow, `$3` the third. Every
generator leaf carries its drawn number as `value`; `str` turns a number into
text and `++` joins text. So at the `E` above, `value` is 122 and `latex` is
`82 + 40`.

These are *synthesized attributes*: computed from the children, on the way
back up the tree. Each has to be declared, with the symbol that carries it:

```rhema
synth value on E
synth latex on E
```

The compiler checks that every production for `E` says how to compute both.
Leave one out and it will not compile:

```text
$ rhema check first.rhm
first.rhm:8:1: error: rule 'E' does not say how to compute 'latex'; add 'latex = ...' inside its braces
```

## The prompt and the answer

The last two lines turn the finished tree into a question:

```rhema
prompt "What is [`{E.latex}`]?"
answer E.value
```

`{E.latex}` in the prompt is replaced by the `latex` attribute of the start
symbol. The prompt is written in WeBWorK's PGML, so ``[`...`]`` marks
mathematics. `answer` names the attribute the student's answer is graded
against.

This is the point of writing questions this way. The text the student reads
and the answer the grader expects are two attributes of one tree, computed
from the same drawn numbers, so they cannot drift apart. There is no answer
key to keep in step with the questions.

## What the compiler checks

Before any question is generated, `rhema check` makes sure that

- every symbol used has productions or is a leaf,
- every synthesized attribute is computed by every production that must
  carry it,
- the prompt and answer name attributes that exist,
- every builtin function is called with the right number of arguments.

These are checked once, for the file, not for each question drawn. A file
that checks will not fail half way through a paper for one of these reasons.

**Next:** the questions above are all equally hard. Chapter 2 gives a grammar
a budget, so that one file can ask easy and hard questions of the same kind.
