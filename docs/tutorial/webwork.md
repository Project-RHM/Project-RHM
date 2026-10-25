# Into WeBWorK

`rhema` compiles a file to a WeBWorK problem file (`.pg`), ready to upload to
a course.

## Compiling

```text
$ rhema assignment.rhm --run week3
```

writes `week3.pg` in the current directory. The output is named after the
set with `--run`, otherwise after the input file (`quiz.rhm` gives
`quiz.pg`); `-o NAME.pg` names it, and `-o -` prints it.

A single question type compiles the same way. `--count` says how many
questions to put in the file:

```text
$ rhema values.rhm --count 10 -o derivatives.pg
$ rhema questions.rhm --question sum --count 5 -o sums.pg
```

## What the file contains

```text
$ rhema assignment.rhm --run week3 -o - | head
DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");

BEGIN_PGML
Sequences

1(a). An arithmetic sequence has first term [`a_1 = 0`] and common
difference [`d = 5`]. Find [`a_{14}`]. [_____]{65}
```

It is ordinary PG: the macros it needs, the context, and the questions in
PGML with their answers in the blanks. Questions that need a different
context, such as a proposition to rewrite in the Boolean context, are put in
their own PGML block with the context switched before it.

## One paper per assignment

Compiling `week3` again gives the same file, today or next term. The paper
is fixed by the assignment's name, which is the set's name unless you give
another:

```text
$ rhema assignment.rhm --run week3 --assignment "MATH2003 HW3"
```

Two assignments with different names are different papers, even from the
same file. Nothing about the paper depends on when or where it was compiled.

## A paper for each student

When every student should have different numbers, name the student:

```text
$ rhema assignment.rhm --run week3 --student 2330026211 -o week3_2330026211.pg
```

Each student's paper is fixed in the same way: the same student and
assignment always give the same paper, so it can be regenerated for marking
or a resit. Most assignments do not need this; one paper for the whole
class is the default for a reason.

## One file per question

```text
$ rhema assignment.rhm --run week3 --pg-dir week3/
```

writes `week3.pg` and also `week3/question01.pg`, `question02.pg` and so on,
for courses that prefer one problem per file.

## Uploading

In the WeBWorK course:

1. **File Manager**: open `templates`, make a folder for the assignment if
   you like, and upload the `.pg` files.
2. **Homework Sets Editor**: create the set, or open an existing one.
3. **Library Browser**: choose the course's local problems, browse to the
   uploaded files, and add them to the set.
4. Open a problem as a student to check that it displays and accepts the
   answer.

The files are plain text and can also be copied into the course's
`templates` directory by anyone with access to the server.

## Before you upload

`rhema run` shows exactly the questions and answers that will be in the
file, so read the paper there first:

```text
$ rhema run assignment.rhm --run week3
```

That is the end of the tutorial. The [reference](../reference/command.md)
describes the command in full; the library's grammars, under
`share/rhema` where Rhema is installed, are worked examples of everything
above.
