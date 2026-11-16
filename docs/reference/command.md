# The rhema command

```text
rhema FILE.rhm [-o OUT.pg] [options]    compile FILE to WeBWorK PG
rhema FILE.rhm -o OUT.tex | OUT.pdf     the same questions as a paper
rhema check FILE...                     check only
rhema run FILE [options]                show the questions and answers
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

!!! note
    LaTeX and PDF output is in the repository, not in the 0.1.1 package.

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
:   Checks each file and prints `OK` with what it declares, or its problems.

`rhema run FILE`
:   Generates and prints questions with their answers, instead of writing
    PG. With `--run SET`, prints the set part by part, followed by the mean
    of each budget in each part.

`rhema list FILE`
:   The file's imports, questions (with start symbol and context), budgets
    and sets.

`rhema doc [NAME]`
:   Lists the builtin functions grouped by value type, or describes one.
