# Rhema

<p class="rhema-lede">
Rhema is a language for writing mathematics questions. A file describes a
kind of question as a grammar: what shapes it may take, how hard it is, what
its answer is and how it reads. The <code>rhema</code> compiler checks the
file and writes the questions out for WeBWorK.
</p>

```rhema
--8<-- "first.rhm"
```

```text
$ rhema run first.rhm --count 2
 1. What is [`82 + 40`]?
    answer: 122
 2. What is [`83 + 52`]?
    answer: 135
```

The question and its answer come from the same tree, so they cannot
disagree. Difficulty is a budget the grammar spends exactly, chosen when the
questions are generated. Grammars import one another, and a file can describe
a whole assignment, which compiles to the same paper every time.

## Install

```text
opam install rhema
```

This installs the `rhema` command and a library of grammars for arithmetic,
algebra, calculus, limits, series, propositional logic, sets and
inequalities, vectors, complex numbers, sequences, linear algebra and
eigenvalues, counting and probability, and number theory. Until the package reaches the opam repository:

```text
opam pin add rhema https://github.com/Project-RHM/Project-RHM.git#v0.1.1 --subpath generator
```

## Where to go next

[The tutorial](tutorial/index.md)
:   Eight short chapters, from the file above to a complete assignment in
    WeBWorK. Every example on the site is checked by the compiler on each
    change to the repository.

[The rhema command](reference/command.md)
:   Compiling, checking, running and listing files, and how imported files
    are found.

## The name

**RHM**, the project Rhema belongs to, stands for *Reversible Hierarchical
Mathesis*, with the motto <span class="rhema-motto">Regula · Hierarchia ·
Mathesis</span>.

*Reversible*
:   A parser reads text into a tree. RHM runs that direction backwards: it
    builds the tree first and writes the question from it, so the question
    and its answer are two readings of one object. The first version did
    this literally, running the Menhir parser's grammar in reverse; the
    letters R-H-M are *Menhir* read backwards without its vowels.

*Hierarchical*
:   Questions are trees of productions. Difficulty is a budget passed down
    the tree, results are computed back up it, and grammars compose into
    assignments by import.

*Mathesis*
:   After Leibniz's *mathesis universalis*, a universal method of reasoning
    by calculation: here, a method of producing mathematics questions by
    rule.

**Rhema** (Greek ῥῆμα, *that which is said, an utterance*) is the name of the
language. Its letters sit inside RHM, and it names what a grammar does: it
says a question.

## Authors

Jingming Zhang, Jiaming Lei, Xiaobo Huang, Jiesen Long and Zhiyuan Li, at
[Beijing Normal-Hong Kong Baptist University](https://www.bnbu.edu.cn/en/);
see [Authors](authors.md). Rhema is free software under the MIT licence; the
source is on [GitHub](https://github.com/Project-RHM/Project-RHM).
