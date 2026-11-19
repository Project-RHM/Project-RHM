# The language

This page describes Rhema as the compiler implements it, construct by
construct. The [tutorial](../tutorial/index.md) introduces the same material
in order of use; the [grammar](#grammar) at the end summarises the syntax.

## Files

A Rhema file is a sequence of *declarations*, in any order, encoded as UTF-8
and named with the extension `.rhm`. A file does one or more of three
things:

- declares **questions**: a start symbol, a prompt and an answer, at the top
  level (the question `main`) or in `question` blocks;
- declares **sets**: whole assignments built from questions;
- provides **productions and attributes** for other files to `include` or
  `import`.

A file with neither questions nor sets is a *library*: it can be checked,
included and imported, but not run. `polynomial_core.rhm` and
`matrix_core.rhm` in the standard library are libraries.

## Lexical structure

**Comments** run from `#` to the end of the line.

**Identifiers** are a letter or underscore followed by letters, digits and
underscores. By convention nonterminals start with a capital letter
(`E`, `Q`) and attributes, randoms and lets do not; the language does not
require it.

**Integers** are decimal digits. A minus sign is an operator, except where a
declaration takes a signed integer: the value in `attribute`, starting
values in `question` blocks, and the draws of a `set`.

**Strings** are written in double quotes and may span lines; the line breaks
are part of the string. The only escapes are `\"` (a quote) and `\\` (a
backslash). Any other backslash is kept, so LaTeX is written directly:
`"\cdot"` and `"\\cdot"` are the same string.

**Keywords** are reserved:

```text
answer  as  attribute  boolean  context  copy  import  include  left
let  mistake  nonassoc  on  precedence  prompt  question  random  require
right  set  split  start  synth  weight  when  width  and  or  not  true
false
```

A reserved word cannot be used as a name, also not for a local name in a
production: `let width = ...` is a syntax error.

Inside a `set` block, the words `part`, `of`, `any`, `in`, `spread`, `low`,
`allowed`, `distinct`, `balanced` and `ordered` have a meaning, but they are
not reserved and may be used as names elsewhere.

## Attributes

### Inherited attributes

```rhema
attribute NAME = INTEGER [copy | split]
```

declares an attribute whose value travels *down* the tree. `INTEGER` is its
value at the root of a question, and must not be negative. The distribution
says how a node passes it to its children:

`copy` (the default)
:   every child that is a symbol of the grammar receives the node's value;

`split`
:   the node's value is divided between those children, every division into
    non-negative whole numbers being equally likely.

Leaves (generators and quoted words) receive nothing. A child that is a
module symbol (`alias.F`) counts as a symbol of the grammar.

The starting value can be changed from outside, with `--set NAME=VALUE` on
the command line, an `INTEGER` in a `question` block, or a draw in a `set`.

### Synthesized attributes

```rhema
synth NAME
synth NAME on SYMBOL
```

declares an attribute whose value travels *up* the tree, computed at a node
from its children. `on SYMBOL` restricts it to one nonterminal; without it,
every nonterminal must compute it. The same name may be declared on several
symbols, but not both with and without `on`.

Every production for a symbol must compute every synthesized attribute that
symbol carries. A generator leaf carries one attribute, `value`, the number
it drew; a quoted word carries `value`, its text.

Three names are reserved for the start symbol: `pg_context`, the WeBWorK
context of each question, `pg_width`, the width of its answer blanks, and
`pg_variables`, the variables of its formula and proposition answers. When
the start symbol
computes the first two, they override the file's `context` and `width` for
that question.

`pg_variables` is text naming variables, such as `"x y"`. A formula answer
is written with a context that declares the variables it holds; with
`pg_variables` every formula answer of the question is declared in all the
named ones, so a derivative that comes to `6y` is entered in a blank that
knows `x` too. A proposition answer is declared in them in the same way, as
propositional variables. It may also be a `let` of the file, for all its
questions.

## Productions

```rhema
LHS -> SYMBOL ... [when EXPR] [weight INTEGER] { EQUATION ... }
```

A production says that the nonterminal `LHS` may be made of the symbols on
the right. The braces are required, even when empty.

Each symbol on the right is one of:

| Written | Meaning |
|---|---|
| `E` | a nonterminal, if the file has productions for it; otherwise a terminal that stands for its name |
| `+` `-` `*` `/` `%` `^` | a terminal that stands for the operator |
| `"text"` | a terminal that stands for the text |
| `integer_between(1, 9)` | a generator: a leaf that draws a number (see [builtins](builtins.md)) |
| `calc.F` or `calc.F(cost = cost - 1)` | a nonterminal of an imported module, with starting values for its inherited attributes |

`$1`, `$2`, ... refer to these symbols, counting from 1.

`when EXPR` is the production's *guard*. The production may be chosen only
when it is true. It is evaluated before the children exist, so it may use
inherited attributes and question-level values, but not `$n`.

`weight INTEGER` (a positive integer, 1 by default) is the production's
relative chance of being chosen among those whose guards hold.

### Equations

The body holds equations and requirements, separated by line breaks or
commas:

`NAME = EXPR`, where `NAME` is inherited
:   An *update*, applied before the children are built: the value is added
    to the attribute. It must not make the budget negative, and a positive
    constant is refused, because an update spends a budget. `cost = -2`
    spends 2.

`NAME = EXPR`, where `NAME` is synthesized
:   Computes the attribute, after the children are built. An equation may use
    an attribute computed earlier in the same body by its bare name.

`require EXPR`
:   A condition checked after the children are built and the equations
    above it are computed. When it is false, the node is built again.

`let NAME = EXPR`
:   A *local name*: a value computed after the children are built, for the
    lines below it in the same body. The node does not carry it, so it needs
    no `synth` declaration and no other production sees it. The name must be
    new: an attribute, a random, a file-level let or an earlier local name
    of the same production is refused. Guards, updates and generator
    arguments are evaluated before the children exist and cannot use it.

`mistake NAME ATTRIBUTE = EXPR`
:   A *mistake line*: what a student who makes the [mistake](#mistakes)
    `NAME` computes for `ATTRIBUTE` here. It is skipped when the question is
    generated.

Updates are applied in the order written; equations, local names and
requirements are evaluated in the order written.

```rhema
B -> integer_between(-3, 2) integer_between(1, 4) {
  let upper = $1.value + $2.value
  require upper != 0
  latex = "\int_{" ++ str($1.value) ++ "}^{" ++ str(upper) ++ "}"
  value = upper
}
```

## Expressions

| Form | Meaning |
|---|---|
| `12`, `"text"` | a number, a string |
| `true`, `false` | the two truth values |
| `NAME` | an inherited attribute of the node, a random or let, or an attribute or local name computed earlier in the same production |
| `$2.NAME` | an attribute of the second child |
| `$2` | the second child itself; only as an argument of `infix` and `prefix` |
| `S.NAME` | an attribute of the start symbol `S`; only in `prompt` and `answer` |
| `alias.NAME` | a random or let of an imported module |
| `f(e, ...)` | a builtin function |
| `-e`, `not e` | negation |
| `e + e`, `-`, `*`, `/`, `%`, `^` | arithmetic on numbers |
| `e ++ e` | joining text, or text and answer blanks |
| `e = e`, `!=`, `<`, `<=`, `>`, `>=` | comparison |
| `e and e`, `e or e` | logic |

Numbers are exact rationals: `1 / 3` is one third, not 0.333. `=` and `!=`
on text compare the strings, and on truth values they are the
biconditional and exclusive or; `<`, `<=`, `>` and `>=` order numbers
only.

Operators bind, from loosest to tightest: `or`; `and`; `not`; the
comparisons (which do not chain); `++` (right-associative); `+ -`;
`* / %`; `^` (right-associative); unary `-`. Brackets group.

Every value has a type, and `rhema check` finds the uses no type allows
before anything is generated; see [Types](#types).

## Question-level values

```rhema
random NAME = boolean
random NAME = GENERATOR(INTEGER, ...)
let NAME = EXPR
```

A `random` is drawn once per question, before the tree is built, and has the
same value wherever it is used. Its arguments must be integer literals.

A `let` is computed once per question, after the randoms, from randoms and
earlier lets. It may call any builtin function but may not refer to the
tree.

## Types

Every value has one of these types. Nothing in a file declares a type: the
checker works them out.

| Type | Made by |
|---|---|
| number | a literal, a generator, a budget, arithmetic; exact rationals |
| text | a string, a quoted word in a production, `str`, the `_latex` functions |
| truth value | `true`, `false`, `random NAME = boolean`, comparisons, `and` `or` `not` |
| formula, polynomial, equation | the `formula_`, `polynomial_` and `equation` functions |
| proposition | the `bool_` functions |
| matrix, set, vector, point, complex number | their functions |
| text with answer blanks | `blank`, `blank_wide`, and `++` with one |
| answer wrappers | `exactly`, `plain`, `vector_norm_answer` and its like |

A truth value and a proposition are different things: `p and q` is true or
false now, and `bool_and(bool_var("p"), bool_var("q"))` is a formula that
can be shown, compared and evaluated.

### What the checker infers

For every expression the checker finds the *set* of types it can have:

- A literal, a random, a budget and a generator leaf have one type. A
  quoted word read as `$n.value` is text; a generator read as `$n.value` is
  a number.
- A function gives the type its entry in [the builtins](builtins.md) says.
  `cond(T, A, B)` gives whatever `A` or `B` can be.
- An operator or a function has a type only when each operand can have a
  type it takes. An expression that can never be evaluated has no type, and
  nothing built on it is an error: the mistake is reported where it is, and
  not again where its result is used.
- A synthesized attribute has every type that some production of its
  nonterminal can give it. It is kept by nonterminal: `value` on `E` and
  `value` on `Q` are two attributes and may have two types.
- A module's attributes and values keep the types found when the module was
  checked; `$n.NAME` on `alias.F` and `alias.NAME` read them.

The sets are found by reading the productions until none grows, so a
recursive production and the order of the declarations make no difference.

### What is an error

A use is an error when **no** type its operand can have is allowed:

```rhema
let label = "n = " ++ n
let broken = label + 1
```

```text
quiz.rhm:5:14: error: '+' takes a number on its left, but 'label' is text
```

The rules are the ones the engine applies when it evaluates. For an
`answer` and an `{answer ...}` hole the engine left the rule to the WeBWorK
writer, which stopped on an equation; the checker now applies it.

| Use | Takes |
|---|---|
| `+ - * / % ^`, unary `-`, `< <= > >=` | numbers |
| `and`, `or`, `not`, a `when` guard, a `require` | truth values |
| `=`, `!=` | two values of one type: numbers, text, truth values, formulas, polynomials, equations, propositions, matrices, sets, vectors, points or complex numbers |
| `++` | text, numbers and text with blanks |
| a function argument | what its entry says; where text is wanted a number is written out, and nothing else is converted |
| a budget update, a generator's argument, a module's starting value | a number |
| `{S.NAME}` and `{NAME}` in a prompt | text, a number, or text with blanks |
| `answer`, `{answer ...}`, `blank` | anything but an equation or text that holds a blank |
| `$n` on its own | only `infix` and `prefix` take a child; everywhere else write `$n.NAME` |
| a child given to `infix` or `prefix` | its own copy of the attribute being computed must be text or a number |
| a use read under a mistake | what it takes, with the mistaken values in place: see below |
| `pg_context`, `pg_variables`; `pg_width` | text, or a number, which is written out; a number |

A use that *some* type allows is not an error. If `value` is a number in one
production and a formula in another, `formula_negate($1.value)` is accepted,
and the engine refuses it in the questions where it meets a number.

An expression is checked wherever it is written, also where it would never
be evaluated: the unchosen branch of `cond`, the right side of `and` and
`or`, a production that no question reaches. A file with a wrong type in
such a place could generate before types were checked, and is refused.

A mistake line may give a value of any kind: one root where the set of
roots is the answer, the words "no solution" where a number is. The checker
reads the file once more for each [mistake](#mistakes), as the engine
evaluates a finished tree under it: the lines for that mistake give their
names new values, requirements are not read, and an attribute has, under
the mistake, every type some production then gives it. A use that can take
none of those types is an error, because generation would stop there every
time the mistake was tried:

```rhema
value = $1.value
mistake as_text value = "two"
twice = value * 2
```

```text
quiz.rhm:9:11: error: under the mistake 'as_text', '*' takes a number on its left, but 'value' is text
```

This reading teaches the checker nothing about the right working: an
attribute's own type comes from its equations alone.

Types are checked last, on a file that has passed every other check, so
that a name that does not exist is reported once and not again for the type
it does not have; type errors therefore appear only when the others are
gone. `rhema check` does it, and so does every command that reads a file.

There is one message for each wrong use: an operator with two wrong sides
gives two. A message points at the operand when the operand is a name, a
child or a function call. A literal or an expression in brackets has no
position of its own, and the message then points at the function call
around it, or at the start of its equation.

### What is left to the engine

Whatever depends on the value and not on its type. A file that passes
`rhema check` can still stop while generating on:

- a number that must be whole and is not (`factorial(1 / 2)`, a budget
  update, an index);
- a division by zero, in numbers or in formulas;
- matrices and vectors of sizes that do not fit, a singular matrix to
  invert;
- a function outside its domain: `exact_sin(1, 5)`, a base above 16, a
  variable named `2`;
- an equation with no exact solutions where one is asked for;
- a use that only some of an expression's types allow, as above;
- a number too large to be kept exact: numbers are fractions of 63-bit
  integers, and a sum or product that does not fit stops the question, as a
  division by zero does, where it would otherwise be a wrong number;
- a requirement that cannot be met, or a budget no production can spend.

Each of these stops generation with a message of one line, and the command
ends with status 1.

## Mistakes

```rhema
mistake NAME STRING
```

declares a mistake students make. `STRING` says what the student does and
must not be empty. Mistake names are a namespace of their own: a mistake
may have the name of an attribute.

A production says where the mistake is made, with a mistake line in its
body:

```rhema
F -> "sin" F when cost >= 3 {
  cost = -2
  f = formula_sin($2.f)
  d = formula_multiply(formula_cos($2.f), $2.d)
  mistake no_chain d = formula_cos($2.f)
  latex = formula_latex(f)
}
```

The name after the mistake's must be a synthesized attribute or a local
name that the production has computed above the line. The expression may
use everything an equation at that place may use, the right value of its
own name included. A production has at most one line for the same mistake
and name. Every declared mistake must have a line in some production.

A mistake line takes no part in generation. After a question is built, each
mistake that some production of its tree has a line for is tried:

1. The tree is evaluated again from the leaves up. Each node keeps its
   production and its children; its equations and local names are computed
   in order, and a line for the mistake gives its name the new value, for
   the lines below it and for the node. Requirements are not checked.
   Subtrees of imported modules are left as they are.
2. A value is *mistaken* when a line for the mistake gave it a value other
   than the one it had, or when the expression that computed it read a
   mistaken value. A line that gives the same value changes nothing.
3. The answers are read again. If none was read from a mistaken value, the
   mistake does not concern this question. If one was and some answer is
   now different, the mistake is reported with the answers it leads to. If
   one was and every answer is the same, wrong working would be marked
   right: the question is discarded and generated afresh, as after a
   failed requirement.

Two answers are the same when a marker would take one for the other:
formulas are compared as functions, at fixed points, and other values by
their own equality. A mistake that ends in an arithmetic failure, such as
a division by zero, is reported as leading to no answer, and the question
is kept. A mistake line that cannot be evaluated for another reason, such
as a value of the wrong type, stops generation with a message naming the
mistake.

`rhema run` lists, under each answer, `mistake NAME: ANSWERS` for every
mistake reported. The PG and LaTeX output of a question does not depend on
the file's mistakes.

An `include`d file's mistakes and lines become the including file's. An
`import`ed module's are its own: they apply to the module's questions.

## Precedence and rendering

```rhema
precedence LEVEL left|right|nonassoc OPERATOR ...
```

gives operators a binding strength (higher binds tighter) and an
associativity. A production that has an operator among its symbols takes
that operator's level. The builtins `infix($1, "+", $3)` and
`prefix("\neg", $2)` write their operands, adding brackets exactly where the
levels and associativity require them. The operator's text need not be the
symbol: `E -> E * E` may be written with `"\cdot"`.

## Prompt, answer, context, width

```rhema
prompt STRING
answer EXPR
context STRING
width INTEGER
```

The prompt is PGML with these replacements:

| Written | Becomes |
|---|---|
| `{S.NAME}` | an attribute of the start symbol `S` |
| `{NAME}` | a random or let |
| `{alias.NAME}` | a random or let of an imported module |
| `{answer S.NAME}`, `{answer NAME}` | an answer blank graded against that value |
| `{{`, `}}` | literal braces |

`answer EXPR` adds one blank after the prompt; it may use `S.NAME` and module
values. A question has either `answer` or `{answer ...}` blanks, not both.
`context` names the WeBWorK context (default `Numeric`); `width` sets the
width of every blank.

### Blanks in text

A blank may also be part of the text a production builds:

```rhema
text = "Centre: " ++ blank(point2(h, k)) ++ " Radius: " ++ blank_wide(r, 4)
```

`blank(VALUE)` is an answer blank graded against `VALUE`, and
`blank_wide(VALUE, COLUMNS)` the same with a width of its own. Joined to
text with `++` it makes *text with blanks*; when `{S.NAME}` or `{NAME}` in
the prompt holds such a value, its text and blanks go into the question in
the order written. Each production then says where its own blanks are, so
forms with different numbers of blanks can share a grammar.

- A file whose rules or lets call `blank` needs no `answer` line. A question
  made with no blank at all is refused when it is generated.
- A question with an `answer` line and blanks in its text is refused: its
  blanks come from one place.
- Text with blanks can only be joined with `++` and shown through the
  prompt; `str`, a comparison or a `*_latex` function refuses it.
- A blank cannot be inside mathematics, between `` [` `` and `` `] ``.

### Answers that carry their context

Some answers are written to WeBWorK with a context of their own, so the
question may be in any context and the grammar sets none:

- a point (`point2`, `point3`);
- a formula in variables other than `x`: the context declares the variables
  of every formula answer of the question and those named by
  `pg_variables`, so its blanks accept the same names;
- a proposition (`bool_*`): the context is a copy of WeBWorK's Boolean
  context, which knows `p` and `q` alone, that declares the variables of
  every proposition answer of the question and those named by
  `pg_variables`. The compiled file loads `contextBoolean.pl` for it;
- `plain(VALUE)`, a number or formula that must be worked out: the
  trigonometric, hyperbolic, logarithm and exponential functions are
  switched off (`sqrt` and `abs` stay), so `sin(pi/3)` is not accepted as
  the value of sin(π/3).

WeBWorK compares numbers with a relative tolerance of one part in a
thousand. Up to 1000 that still tells a whole number from its neighbours;
above it, it does not: for the answer 5040 it accepts 5041, and for 10100
it accepts 10110. A whole-number answer of 1000 or more (or -1000 or less)
is therefore written with an absolute tolerance of half a unit, so that no
other whole number passes; smaller ones are written as bare numbers.
A fraction is the same in its numerator: from 1001 on, WeBWorK accepts
`(p + 1)/q` for `p/q`, whatever `q` is. A fraction answer whose numerator is
1000 or more (or -1000 or less) is written with an absolute tolerance of
half a step of its denominator, `1/(2q)`, so that neither neighbour passes;
a decimal typed in its place must then be right to within that. Smaller
fractions are written as before.
`exactly(N)` asks for the exact comparison whatever the size of `N`;
`base_conversion.rhm` uses it where the digits are the answer.

## Questions

```rhema
question NAME {
  start SYMBOL
  prompt STRING
  [answer EXPR]
  [context STRING]
  [width INTEGER]
  [ATTRIBUTE = INTEGER] ...
}
```

declares a named question over the file's productions. The top-level
`start`, `prompt`, `answer`, `context` and `width` form the question `main`.
A block without `context` or `width` takes the file's. `ATTRIBUTE = INTEGER`
starts an inherited attribute at that value for this question. A file of
blocks only has no `main`; its first block is its default question.
`main` cannot be used as a block's name.

## include and import

```rhema
include "FILE.rhm"
import "FILE.rhm" as ALIAS
```

`include` merges the other file's declarations into this one before
checking. Productions, attributes, randoms, lets and precedences add up;
identical declarations in both files are kept once. Of the declarations a
file makes once (`start`, `prompt`, `answer`, `context`, `width`), the
including file's own win. Among inherited attributes, the including file's
declaration wins, then the first included one.

`import` loads the other file as a separate module, checked on its own. Its
nonterminals, randoms, lets and questions are reached as `ALIAS.NAME`; its
synthesized attributes are read through `$n` as usual; its precedences and
productions are not visible. A module is loaded once per run however many
files import it, and its randoms are drawn once per question. A module's own
imports are private to it. A module subtree is atomic to the importer's
`infix`: no brackets are added around it.

Both look for the file beside the file that names it, then in `-I`
directories, `RHEMA_PATH` and the installed library. A file that includes or
imports itself, directly or through others, is refused.

## Sets

```rhema
set NAME {
  part "HEADING"
  COUNT of QUESTION(DRAW, ...)
  COUNT of any(QUESTION(DRAW, ...), ...)
  distinct
  balanced
  ordered
}
```

`QUESTION` is `main`, a question of this file, or `ALIAS.NAME`. Each `DRAW`
starts one inherited attribute of that question:

| Draw | Meaning |
|---|---|
| `cost = 6` | every question starts at 6 |
| `cost in {8, 10, 12}` | values taken in turn, each once before any repeats |
| `cost ~ 6 [spread 2] [low 2] [allowed {4, 6}]` | drawn around the mean and adjusted so the entry's mean is exactly 6 (or as close as `allowed` permits); `spread` defaults to 2, `low` to 0 |

`part` lines group the entries that follow under one number. `distinct`
refuses a question of the same type and tree shape as an earlier one;
`balanced` refuses a third equal coded answer in a row; `ordered` sorts each
part by total budget.

## How a question is generated

1. The paper's *variant* is derived from the assignment's name, and from the
   student's when one is given; it fixes every random choice below.
2. The randoms of the file and of every module it imports are drawn; then
   the lets are computed in order.
3. From the start symbol, with the inherited attributes at their starting
   values, each node is built:
    - the productions for the symbol whose guards hold, and whose updates
      leave every budget non-negative, are the candidates; if there are none,
      generation stops with `no rule for 'E' fits {...}`;
    - one candidate is chosen in proportion to its weight;
    - its updates are applied and the inherited attributes distributed to
      the children, which are built in turn;
    - its equations and requirements are evaluated in order. A failed
      requirement builds the node again, with fresh choices, up to 40 times;
      after that the failure passes to the node above, which tries again in
      the same way. A question that still fails is started afresh, up to 200
      times, before generation gives up and names the requirement that
      failed most often.
4. The prompt, blanks and context are read from the finished tree.
5. Each [mistake](#mistakes) with a line in the tree is tried. A question
   in which one changes the working and leaves every answer right is
   started afresh, within the same 200 attempts.

When a failure could not have gone differently, because no random choice was
involved, it is reported at once instead of retried.

## What the checker guarantees

`rhema check` accepts a file only if:

- it parses, and every name it uses is declared: symbols, attributes,
  randoms, lets, builtins, aliases, questions, modules' names;
- every production computes every synthesized attribute its symbol
  carries, and an update is never a positive constant;
- guards and updates use only what exists before the children are built;
  equations and requirements use children only within range and only
  attributes those children carry;
- every builtin and generator is called with the right number of arguments,
  and random draws have literal arguments;
- no operator, function, guard, requirement, budget update, prompt, answer
  or mistake line is given a value that cannot have a type it takes
  ([Types](#types));
- every nonterminal can finish (some production for it uses only symbols
  that can finish), and every cycle of productions spends an inherited
  attribute, so no derivation can go round for ever without spending;
- prompts, answers, questions and sets refer to things that exist, with the
  right kinds of blank;
- every mistake is declared once, with a description, and is made in some
  production; every mistake line names a declared mistake and a value its
  production has already computed;
- no file includes or imports itself.

What the checker cannot know is left to generation, and reported clearly
when it happens: a budget no production can spend, a requirement that
cannot be met, a value whose type suits in some questions and not in
others, a number that must be whole, a division by zero, a mistake that
always changes the working and never an answer.

## Grammar

The syntax in EBNF. `{ X }` means zero or more, `[ X ]` optional, `|`
alternatives; quoted text is literal, capitalised names are tokens.

```text
file          = { declaration } ;

declaration   = "attribute" IDENT "=" sint [ "copy" | "split" ]
              | "random" IDENT "=" ( "boolean" | IDENT "(" [ exprs ] ")" )
              | "let" IDENT "=" expr
              | "mistake" IDENT STRING
              | "synth" IDENT [ "on" IDENT ]
              | "start" IDENT
              | "context" STRING
              | "precedence" INT ( "left" | "right" | "nonassoc" ) operator { operator }
              | "prompt" STRING
              | "answer" expr
              | "width" INT
              | "include" STRING
              | "import" STRING "as" IDENT
              | "question" IDENT "{" { qitem } "}"
              | "set" IDENT "{" { sitem } "}"
              | production ;

production    = IDENT "->" symbol { symbol } [ "when" expr ] [ "weight" INT ]
                "{" { equation [ "," ] } "}" ;
symbol        = IDENT | IDENT "(" [ exprs ] ")"
              | IDENT "." IDENT [ "(" [ IDENT "=" expr { "," IDENT "=" expr } ] ")" ]
              | STRING | "+" | "-" | "*" | "/" | "%" | "^" ;
equation      = IDENT "=" expr | "require" expr | "let" IDENT "=" expr
              | "mistake" IDENT IDENT "=" expr ;

qitem         = "start" IDENT | "context" STRING | "prompt" STRING
              | "answer" expr | "width" INT | IDENT "=" sint ;

sitem         = "part" [ STRING ] | "distinct" | "balanced" | "ordered"
              | INT "of" choice ;
choice        = squestion | "any" "(" squestion { "," squestion } ")" ;
squestion     = [ IDENT "." ] IDENT [ "(" [ draw { "," draw } ] ")" ] ;
draw          = IDENT "=" sint
              | IDENT "in" "{" sint { "," sint } "}"
              | IDENT "~" sint { "spread" sint | "low" sint | "allowed" "{" sint { "," sint } "}" } ;

expr          = INT | STRING | "true" | "false"
              | IDENT | IDENT "." IDENT | "$" INT | "$" INT "." IDENT
              | IDENT "(" [ exprs ] ")" | "(" expr ")"
              | "-" expr | "not" expr | expr binop expr ;
exprs         = expr { "," expr } ;
binop         = "or" | "and" | "=" | "!=" | "<" | "<=" | ">" | ">="
              | "++" | "+" | "-" | "*" | "/" | "%" | "^" ;
operator      = "+" | "-" | "*" | "/" | "%" | "^" | STRING ;
sint          = [ "-" ] INT ;
```
