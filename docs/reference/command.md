# The rhema command

```text
rhema FILE.rhm [-o OUT.pg] [options]    compile FILE to WeBWorK PG
rhema FILE.rhm -o OUT.tex | OUT.pdf     the same questions as a paper
rhema check FILE...                     check only
rhema run FILE [options]                show the questions and answers
rhema try FILE [options]                try the file out, a question at a time
rhema list FILE                         the questions and sets FILE declares
rhema doc [NAME]                        the builtin functions (or one of them)
rhema --version | --help
```

## Compiling

`rhema FILE.rhm` checks the file, generates questions and writes them as a
WeBWorK problem file. The output is named after the input (`quiz.rhm` gives
`quiz.pg`), or after the set with `--run SET`; `-o OUT.pg` names it, and
`-o -` writes to standard output.

```text
$ rhema calculus.rhm --question integral -o integral.pg
$ rhema homework_set.rhm --run homework          # homework.pg
$ rhema homework_set.rhm --run quick --pg-dir out/
```

`--pg-dir DIR`, with `--run`, also writes one file per question, named
`question01.pg`, `question02.pg` and so on.

## A paper: LaTeX and PDF

The extension of the output says what is written. `-o OUT.tex` writes the
same questions as a LaTeX document, and `-o OUT.pdf` compiles that document
to a PDF:

```text
$ rhema homework_set.rhm --run homework -o homework.tex
$ rhema homework_set.rhm --run homework -o homework.pdf --answers
$ rhema calculus.rhm --count 10 --set cost=6 -o quiz.pdf --title "Quiz 2"
```

The paper has a title, the questions numbered as the set numbers them
(`1(a).`, `2.`), the headings of its parts, and a rule to write on where
each answer blank stands. The same assignment and the same `--student` give
the same questions in all three formats.

`--answers`
:   An answer key on a last page: one entry for each question, one answer
    for each blank.

`--title TEXT`
:   The paper's title. The default is the set's name, the assignment's with
    `--assignment`, or the file's name.

A `.pdf` needs a TeX engine on the machine. `rhema` uses the first of
`pdflatex`, `xelatex`, `lualatex` and `tectonic` that it finds, or the one
the environment variable `RHEMA_LATEX` names. When there is none, or the
engine fails, it says so, writes no PDF and leaves the LaTeX beside where
the PDF would be. The document needs only `amsmath`, `amssymb`, `graphicx`
and `geometry`.

The LaTeX is meant to be edited. Every question is set through four
commands defined at the top of the file (`\rhemaquestion`, `\rhemablank`,
`\rhemaheading`, `\rhemamath`), so another layout is a change to those
lines. `\rhemamath` keeps a formula whole and scales it down when it is
wider than the line, so that a long derivative or a wide matrix stays on
the page.

In the text of a question, `` [`...`] `` and ``` [``...``] ``` are
mathematics, two spaces at the end of a line are a line break, and every
other character is printed as it is. Other PGML markup, such as `*bold*`,
is not interpreted.

## Options

`--question NAME`
:   One of the file's named questions. The default is `main`, the question
    the file declares outside any `question` block.

`--run SET`
:   The set `SET` declared in the file. A set names its own questions,
    counts and budgets, so `--question`, `--count` and `--set` do not apply.

`--count N`
:   How many questions to generate, when not running a set. Default 5.

`--assignment NAME`
:   The assignment this paper is. One assignment is one paper: generating
    it again gives the same questions. The default is the set's name, or
    `FILE:QUESTION`.

`--student ID`
:   A paper of this student's own for the assignment, the same every time
    and different from the other students' and from the assignment's.

`--set NAME=VALUE`
:   Start an inherited attribute of the question at `VALUE`, usually the
    difficulty budget: `--set cost=6`.

`-I DIR`
:   Also look for imported and included files in `DIR`.

`--ast-out FILE`, `--visualization-out FILE`
:   Save the derivation trees as text, or as an interactive HTML page.

## In a terminal

When `rhema` writes to a terminal, compiling and running show more than the
result: the file, the assignment and the seed, the four steps as they are
reached, the progress of the generation, and at the end how many questions
were made and which files were written. A problem is shown with its line of
the file and a mark under the column.

All of this goes to standard error and none of it is part of the result.
It is off whenever the output or the errors are redirected or piped, when
the environment variable `CI` is set, and when PG is written to standard
output; what an editor, a script or another program reads is the same as
without it.

`--plain`
:   No presentation at a terminal either.

`--no-color`
:   No colors. The environment variable `NO_COLOR` does the same.

`--no-emoji`
:   Marks and the progress bar in ASCII.

`-v`, `--verbose`
:   Also print, on standard error, the derivation of each question: the
    rules that were accepted and the attribute values at each node.

### Being asked

A command that cannot go on for want of a name asks for it, when there is
somebody to ask: the presentation is on and the input is a terminal too.
This happens in three cases: a file that holds only sets and no `--run`, a
`--run` that names no set of the file, and a `--question` that names no
question of it.

```text
$ rhema run homework_set.rhm
   homework_set.rhm: this file has no question of its own; it holds the sets homework, quick, run one with --run NAME
   [1] homework
   [2] quick
   Which set? A number or a name; Enter alone stops: 2
   The same as giving --run quick.
```

The answer is a number of the list or a name on it, and nothing else is
taken for one: a name that is nearly right is asked for again. What follows
is the run the same command gives with that name on it, the same paper and
the same default output file. Enter alone, the end of the input, or three
answers that are not on the list end the command with the error it gives
everywhere else, and status 1.

### Hints

An option or a command that is not known is reported with the one it is
nearest to, when one is near:

```text
$ rhema run quiz.rhm --studnt 20261234
rhema: unknown option --studnt (did you mean --student?)
$ rhema chek quiz.rhm
rhema: 'chek' is neither a command nor a file (did you mean check?)
```

A hint is only said. The command still stops with status 2.

## Trying a file out

`rhema try FILE` shows the questions of a file one at a time and takes a
command a line: look at the answer, compare a number with it, change a
budget and see what the questions become.

```text
$ rhema try arithmetic.rhm
-- main, cost = 12, digit = 4, seed 1851610664
 1. What is the value of [`5 \div 6 - (8 - 65 + (3 - 7))`]?
try> a
    answer: 371/6
try> cost = 3
-- main, cost = 3, digit = 4, seed 1851610664
 1. What is the value of [`8033`]?
try>
 2. What is the value of [`4595`]?
try> how
rhema run arithmetic.rhm --set cost=3 --seed 1851610664 --count 2
```

| Command | What it does |
| --- | --- |
| Enter alone, `n` | The next question. |
| `a` | The answer, and what each [mistake](language.md#mistakes) that can be made in the question leads to: the lines `rhema run` prints. |
| `= NUMBER` | Compares a number with the answer. Several answers are separated by `;`. |
| `t` | The derivation: the rules accepted and the attribute values. |
| `pg` | The question as WeBWorK PG. |
| `how` | The command that prints the questions shown so far. |
| `question NAME` | Another question of the file. |
| `BUDGET = N` | Starts a budget at `N`, as `--set BUDGET=N` does. |
| `reset` | The budgets as the file sets them. |
| `seed N`, `seed` | Starts from seed `N`; alone, from the seed `rhema run` derives. |
| `list` | The questions and budgets of the file. |
| `?` | These commands. |
| `quit` | Ends the session. So does the end of the input. |

**A session shows what a command would.** The questions of a session are
the questions of `rhema run`: the first one is the first question of
`rhema run FILE` with the same options, and the Nth one since the last
change is the Nth of the command `how` prints. To keep that true, changing
the question, a budget or the seed starts again at question 1, and the line
beginning with `--` says where the session stands. A command that is
refused, such as a budget the file does not have, changes nothing.

**`=` compares numbers, exactly.** A whole number, a fraction (`3/4`) or a
decimal (`0.75`) is compared with the answer as an exact number: `0.33` is
not `1/3`. This is stricter than WeBWorK, which accepts a number within one
part in a thousand. The reply is `right`, or `not right`, or, when the
number is what one of the grammar's mistakes gives, the mistake:

```text
try> = 12
    not right: this is the answer of the mistake forgot_sign (forgets the minus sign)
```

The answer itself is not given away. An answer that is not a number (a
formula, a set, a matrix) is not compared: when two of those are the same
is for WeBWorK to say, and `a` shows the answer.

A session takes `--question`, `--set`, `--assignment`, `--student` and `-I`
as `rhema run` does, and works on one question of a file, not on a set. It
writes no file. It reads its commands from standard input, a terminal or
not, so a file of commands gives a transcript:

```text
$ printf 'a\n\na\n' | rhema try quiz.rhm
```

Questions and replies go to standard output; the prompt and the errors go
to standard error. An error does not end the session.

## Finding imported files

A file named in `import` or `include` is looked for, in order:

1. beside the file that names it;
2. in each `-I` directory, in the order given;
3. in each directory of the `RHEMA_PATH` environment variable
   (colon-separated);
4. in the installed library, `share/rhema` beside the command.

So `import "calculus.rhm" as calc` works from any directory once Rhema is
installed. When a file cannot be found, the message lists every place that
was searched.

## Messages and exit status

Problems are reported one per line, as
`file:line:column: error: message`, the form editors and terminals
recognise. The exit status is 0 when everything succeeded, 1 when a file has
problems or a paper could not be generated, and 2 when the command line
itself is wrong.

## Other commands

`rhema check FILE...`
:   Checks each file and prints `OK` with what it declares, or its problems,
    each as `FILE:LINE:COLUMN: error: ...`. The check includes the
    [types](language.md#types) of every expression, so a text added to a
    number is found here and not in the middle of generating a paper.

`rhema run FILE`
:   Generates and prints questions with their answers, instead of writing
    PG. With `--run SET`, prints the set part by part, followed by the mean
    of each budget in each part.

`rhema try FILE`
:   The same questions one at a time, in a session:
    see [Trying a file out](#trying-a-file-out).

`rhema list FILE`
:   The file's imports, questions (with start symbol and context), budgets
    and sets.

`rhema doc [NAME]`
:   Lists the builtin functions grouped by value type, each with the types
    it takes and gives (`formula, formula -> formula`), or describes one.
