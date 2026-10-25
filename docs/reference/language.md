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
let  nonassoc  on  precedence  prompt  question  random  require  right
set  split  start  synth  weight  when  width  and  or  not
```

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

Two names are reserved for the start symbol: `pg_context`, the WeBWorK
context of each question, and `pg_width`, the width of its answer blanks.
When the start symbol computes them, they override the file's `context` and
`width` for that question.

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

Updates are applied in the order written; equations and requirements are
evaluated in the order written.

## Expressions

| Form | Meaning |
|---|---|
| `12`, `"text"` | a number, a string |
| `NAME` | an inherited attribute of the node, a random or let, or an attribute computed earlier in the same production |
| `$2.NAME` | an attribute of the second child |
| `$2` | the second child itself; only as an argument of `infix` and `prefix` |
| `S.NAME` | an attribute of the start symbol `S`; only in `prompt` and `answer` |
| `alias.NAME` | a random or let of an imported module |
| `f(e, ...)` | a builtin function |
| `-e`, `not e` | negation |
| `e + e`, `-`, `*`, `/`, `%`, `^` | arithmetic on numbers |
| `e ++ e` | joining text |
| `e = e`, `!=`, `<`, `<=`, `>`, `>=` | comparison |
| `e and e`, `e or e` | logic |

Numbers are exact rationals: `1 / 3` is one third, not 0.333. Comparisons
of text compare the strings; `=` and `!=` on truth values are the
biconditional and exclusive or.

Operators bind, from loosest to tightest: `or`; `and`; `not`; the
comparisons (which do not chain); `++` (right-associative); `+ -`;
`* / %`; `^` (right-associative); unary `-`. Brackets group.

Every value has a type: number, text, truth, formula, polynomial,
equation, Boolean formula, matrix, set, vector or complex number. Types are
checked when a value is used; a function given the wrong type stops
generation with a message naming both.

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
- every nonterminal can finish (some production for it uses only symbols
  that can finish), and every cycle of productions spends an inherited
  attribute, so no derivation can go round for ever without spending;
- prompts, answers, questions and sets refer to things that exist, with the
  right kinds of blank;
- no file includes or imports itself.

What the checker cannot know is left to generation, and reported clearly
when it happens: a budget no production can spend, a requirement that
cannot be met, a value of the wrong type for a function.

## Grammar

The syntax in EBNF. `{ X }` means zero or more, `[ X ]` optional, `|`
alternatives; quoted text is literal, capitalised names are tokens.

```text
file          = { declaration } ;

declaration   = "attribute" IDENT "=" sint [ "copy" | "split" ]
              | "random" IDENT "=" ( "boolean" | IDENT "(" [ exprs ] ")" )
              | "let" IDENT "=" expr
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
equation      = IDENT "=" expr | "require" expr ;

qitem         = "start" IDENT | "context" STRING | "prompt" STRING
              | "answer" expr | "width" INT | IDENT "=" sint ;

sitem         = "part" [ STRING ] | "distinct" | "balanced" | "ordered"
              | INT "of" choice ;
choice        = squestion | "any" "(" squestion { "," squestion } ")" ;
squestion     = [ IDENT "." ] IDENT [ "(" [ draw { "," draw } ] ")" ] ;
draw          = IDENT "=" sint
              | IDENT "in" "{" sint { "," sint } "}"
              | IDENT "~" sint { "spread" sint | "low" sint | "allowed" "{" sint { "," sint } "}" } ;

expr          = INT | STRING | IDENT | IDENT "." IDENT | "$" INT | "$" INT "." IDENT
              | IDENT "(" [ exprs ] ")" | "(" expr ")"
              | "-" expr | "not" expr | expr binop expr ;
exprs         = expr { "," expr } ;
binop         = "or" | "and" | "=" | "!=" | "<" | "<=" | ">" | ">="
              | "++" | "+" | "-" | "*" | "/" | "%" | "^" ;
operator      = "+" | "-" | "*" | "/" | "%" | "^" | STRING ;
sint          = [ "-" ] INT ;
```
