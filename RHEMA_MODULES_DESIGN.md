# Modules and sets for the Rhema language — design proposal

Status: all three steps (modules and arguments, named questions, sets) are
implemented and documented in RHEMA_LANGUAGE_EXTENSIONS.md sections 4 to 6.
Departures from the text below: a file whose questions are all blocks has no
`main` and its first block is the default; the constraints are the single
words `distinct`, `balanced`, `ordered`; a list of budgets is written in
braces (`cost in {8, 10, 12}`, `allowed {4, 6, 8}`); the mean of `~` is a
whole number; `rhema_difficulty.py set` is kept for `--targets` rather than
rewritten as a wrapper. Companion: RHEMA_MODULES_DESIGN.zh.md.

## 0. What this adds, in one paragraph

Today a `.rhm` file is one question type, and the only way to reuse another
file is `include`, which pastes its declarations into a flat namespace. This
proposal adds a module layer and a composition layer:

- `import "calculus.rhm" as calc` brings a file in as a named module. Its
  nonterminals, attributes, randoms and lets are reached as `calc.Q`,
  `calc.cost`, `calc.given`; nothing can clash.
- A production may use an imported nonterminal with arguments:
  `M -> calc.Q(cost = cost - 1)`. The arguments set the inherited attributes
  the subtree starts with; anything not named takes the module's default.
- A file may declare several named question types, each with its own start
  symbol, prompt, answer, context and width: `question derivative { ... }`.
- A `set` declaration describes a whole assignment: which questions, how
  many of each, with what budgets, in what order. The engine writes the PG
  document. The expectation method of difficulty control (a set whose mean
  budget is chosen) moves from `tools/rhema_difficulty.py` into the language.

`include` stays. It is the way to extend a grammar (add rules to its
nonterminal E); `import` is the way to compose grammars.

The language remains an attribute grammar. Nothing here adds statements,
loops, mutable state or recursion in expressions; the static guarantees
(every tree has its attributes, budgets are spent exactly, types are known
before generation) are kept, and extended across module boundaries.

## 1. Why the current language is not enough

The two files that already compose grammars show the limits:

- `derivative_or_boolean.rhm` includes `calculus.rhm` and `boolean.rhm` whole.
  Both must spend the same attribute `cost` on their own scales, because an
  included attribute keeps its name. The file re-declares
  `attribute cost = 8 split` to settle the two defaults. `boolean.rhm` had to
  rename its question symbol to `B` because `calculus.rhm` uses `Q`.
- `logic_forms.rhm` includes `boolean.rhm` and `boolean_equiv.rhm`; the latter
  had to rename its random `phrasing` to `law_phrasing` so the two files
  could sit together. Every such clash is fixed by editing the library, which
  does not scale to a library a user did not write.
- Budgets cannot be set per use. `--set cost=8` reaches every grammar in the
  file; there is no way to say "a derivative of 6 beside a proposition of
  10" inside the language. `tools/rhema_difficulty.py set` does it from outside
  by running `rhema` many times.
- One file, one question. `calculus.rhm` offers derivatives and integrals as
  two forms of one start symbol with a `kind` flag; a user cannot ask for
  "an integral" by name.
- An assignment is assembled by `tools/rhema_set.py` and `rhema_difficulty.py`,
  with regexes over printed text to recognise shapes. The engine, which has
  the trees, knows all of that better.

## 2. Modules

### 2.1 Import

```
import "calculus.rhm" as calc
import "lib/boolean.rhm" as bool
```

- The path is relative to the importing file, as for `include`.
- `as NAME` is required. The alias is the module's name in this file.
- A module is loaded once per run, however many files import it (the same
  rule as Python). Two imports of the same file under two aliases name the
  same module; its randoms are drawn once per question and shared. (A fresh
  copy under a second alias is a possible later addition, not proposed now.)
- Import cycles are refused with the chain of files, as `include` cycles are.
- A module may itself `import` and `include`; its imports are private to it.
  `calc.poly.E` is not allowed; a file names only what it imports itself.

### 2.2 Qualified names

Everything a module declares is reached through its alias:

| In the module      | From the importer         | Notes                                 |
| ------------------ | ------------------------- | ------------------------------------- |
| nonterminal `Q`    | `calc.Q` (in a rhs)       | with optional arguments, see 2.3      |
| `attribute cost`   | `calc.cost` (in arguments)| only as the target of an argument     |
| `random p`, `let given` | `calc.p`, `calc.given` | in expressions, prompts: `{calc.given}` |
| `synth value on Q` | `$1.value` when `$1` is `calc.Q` | no qualification: the child owns it |
| precedence table   | not visible               | rendering inside the module's subtree |
| `question derivative` | `calc.derivative`      | only inside `set`, see 4              |

Builtins (`differentiate`, `matrix_determinant`, ...) are global and never
qualified. A module's own names are unqualified inside it, exactly as today,
so no existing file changes meaning.

Synthesized attributes need no qualification because they are read through
`$n`, and the child's module is known statically from the rule. The checker
therefore knows `$1.value` is `calc`'s `value on Q` and types it from there.

### 2.3 Using an imported nonterminal, with arguments

```
attribute cost = 8 split
start M

M -> calc.F(cost = cost) "derivative" {
  text = "Differentiate [`" ++ $1.latex ++ "`]."
  answer_value = differentiate($1.formula, "x")
}

M -> bool.E(cost = cost - 2, depth = 3) "boolean" { ... }
```

- The argument list names inherited attributes of the imported module and
  gives each a starting value for that subtree. Unnamed attributes take the
  module's declared default (`attribute cost = 7` in `calculus.rhm`).
- Argument expressions are evaluated in the parent's scope: literals, the
  parent's own inherited attributes, the importer's randoms and lets, and
  builtins. They cannot read the child (the child does not exist yet).
- The parent's inherited attribute name in an argument means **this child's
  share**: under `copy` the whole value, under `split` the part this child
  would have received had it been a same-module child. So `calc.F(cost =
  cost)` hands over exactly what a local `F` would get, and the exact-spend
  guarantee carries across the boundary.
- The importer's attributes stop at the boundary. `calc.F` does not see the
  importer's `cost`; it sees `calc.cost`, initialised by the argument. A
  module's budget is always its own, which is what makes the two scales in
  `derivative_or_boolean.rhm` a non-problem: each grammar prices in its own
  currency, and the importer decides the exchange rate in the argument.
- `Rhema_engine.consumption tree "cost"` on the imported subtree reports the
  module's attribute, so a test can still check that `calc.F` spent exactly
  what it was given.

Static checks added: unknown alias, unknown nonterminal in the module,
argument naming an attribute the module does not declare, argument whose
type is not a whole number, a module nonterminal used where the module is a
library and the nonterminal is undefined. All are reported with the
importer's position and the module's file.

### 2.4 `include` beside `import`

`include` keeps today's semantics (flat merge; the includer's singletons win;
first inherited declaration wins; identical randoms and lets deduplicated).
It remains the right tool when a file wants to **add rules to an existing
nonterminal**, which `import` cannot do: `polynomial_core.rhm` included by
`factoring.rhm` and `polynomial_expand.rhm` stays as it is.

Guidance for the guide: include to extend, import to compose. A file may do
both.

## 3. Named question types

### 3.1 Declaration

```
question derivative {
  start D
  prompt "Differentiate [`f(x) = {D.latex}`] with respect to x."
  answer D.formula
  context "Numeric"
  width 30
  cost = 7                  # default for this question's root
}

question integral {
  start I
  prompt "Find [`\int {I.latex} \, dx`]."
  answer I.antiderivative
  cost = 5
}
```

- A `question` block holds exactly what the file-level singletons hold today
  (`start`, `prompt`, `answer` or inline `{answer ...}` blanks, `context`,
  `width`) plus optional attribute defaults `name = value` for the
  module's inherited attributes at this question's root.
- Nonterminals, rules, attributes, randoms and lets are shared by all the
  questions in the file. Two questions differ only in where they start and
  how they ask.
- The file-level `start`/`prompt`/`answer`/`context`/`width`, when present,
  form an implicit question named `main`. Every existing grammar therefore
  already has one question, and nothing changes for it.
- A file with neither a `main` nor any `question` block is a library, as now.
- Each question keeps the `pg_context` / `pg_width` mechanism: a start
  symbol that computes them overrides the block's `context` / `width`.

### 3.2 Running one

```
rhema run calculus.rhm                       # the main question, as today
rhema run calculus.rhm --question integral   # a named one
rhema run calculus.rhm --question integral --set cost=6
rhema list calculus.rhm                  # lists the questions it found
```

The web app lists `file:question` pairs instead of files.

### 3.3 Where questions may be used

A question is used in a `set` (section 4). It is **not** a symbol in a
production: productions compose nonterminals (`calc.F`), sets compose
questions (`calc.derivative`). Keeping the two apart keeps prompts simple:
a production that embeds `calc.F` writes its own wording from `$1.latex`; a
set that lists `calc.derivative` uses the question's own wording.

## 4. Sets

### 4.1 Declaration

```
import "calculus.rhm" as calc
import "boolean.rhm" as bool
import "boolean_equiv.rhm" as laws

set homework {
  part "Differentiation"
    4 of calc.derivative(cost ~ 6 spread 2)
    1 of calc.integral(cost = 5)
  part "Propositional logic"
    3 of bool.main(cost in 8, 10, 12)
    2 of laws.main(cost = 6)
  part
    2 of any(calc.derivative(cost = 8), bool.main(cost = 12))

  distinct trees
  balanced answers
  order by budget
}
```

Entries:

- `N of QUESTION(args)`: N questions of that type. Arguments are the same
  attribute arguments as in 2.3, with three forms of value:
  - `cost = 5`: every question gets 5.
  - `cost in 8, 10, 12`: each question draws one of the listed budgets,
    the list used evenly before any value repeats.
  - `cost ~ 6 spread 2`: budgets are drawn around a mean of 6 with spread 2
    and then adjusted so the mean of the part is exactly 6. This is the
    algorithm of `rhema_difficulty.py set` (`draw_targets`), moved into the
    engine. `low 3` / `allowed 4, 6, 8` can follow to restrict the draw.
- `any(Q1(args), Q2(args), ...)`: each question of the entry is one of the
  listed types, chosen evenly.
- `part "Heading"`: questions in a part are lettered under one number, as
  `tools/rhema_set.py` does; a part without a heading is still a part. A set
  with no `part` lines is a flat list.

Constraints (each optional, each a word the engine already has the data for):

- `distinct trees`: no two questions in the set have the same derivation
  shape (rules used, in order, variables renamed). `rhema_set.py` approximates
  this with a regex over the printed text; the engine has the tree.
- `balanced answers`: for questions whose answer is a Boolean or a coded
  choice, no run of more than two equal answers.
- `order by budget`: within a part, easier first. Default is draw order.

What is deliberately **not** in the set language: coverage of specific rules
("each law once before any repeats"), because it is one grammar's concern.
It stays in `rhema_set.py` for now; a grammar-declared `cover` constraint is a
candidate later addition.

### 4.2 Running a set

```
rhema run exam.rhm --run homework --seed 42 --pg > homework.pg
rhema run exam.rhm --run homework --seed-from 2330026211 --pg-dir out/
```

- Each question's seed is derived from the set seed and its index, so a set
  is reproducible and adding a question at the end does not change the
  earlier ones.
- `--pg` writes one PG document: numbered questions, lettered parts, one
  PGML block per run of equal contexts (the grouping `rhema_pgml.document`
  already does), header loading the union of context macros.
- `--pg-dir` writes one `.pg` file per question, as `rhema_difficulty.py set
  --pg-dir` does.
- Without `--pg` the listing shows each question with its budget and answer,
  and a footer with the mean budget per part, which is the statistic the
  expectation method is about.
- A file may hold several sets; `--run` names one. A file with sets and no
  question of its own is still runnable (through its sets).

### 4.3 What happens to the Python tools

- `rhema_difficulty.py report` and `levels` stay: they measure a grammar, which
  is a tool's job, not a language's.
- `rhema_difficulty.py set` becomes a thin wrapper that writes a one-set `.rhm`
  and runs it, then is retired.
- `rhema_set.py` keeps the law-coverage constraint until a `cover` form exists;
  its other constraints are superseded by `distinct trees` and
  `balanced answers`.
- The web app gains a "set" page that writes a `set` block from a form.

## 5. Worked example: `derivative_or_boolean.rhm` after

Today (37 lines, two includes, a shared `cost`, a renamed `B`):

```
include "calculus.rhm"
include "boolean.rhm"
attribute cost = 8 split
start M
M -> F "derivative" weight 1 { ... }
M -> E "boolean" weight 1 { ... }
prompt "{M.text}"
answer M.answer_value
```

After, as a set (the questions keep their own wording and contexts):

```
import "calculus.rhm" as calc
import "boolean.rhm" as bool

set mixed {
  6 of any(calc.derivative(cost = 7), bool.main(cost = 10))
}
```

After, as a grammar that still builds one hybrid question (when the
importer wants its own wording):

```
import "calculus.rhm" as calc
import "boolean.rhm" as bool

attribute cost = 8 copy
synth text on M
synth answer_value on M
start M

M -> calc.F(cost = cost) "derivative" weight 1 {
  text = "Differentiate [`f(x) = " ++ $1.latex ++ "`]."
  answer_value = differentiate($1.formula, "x")
  require not formula_is_zero(answer_value)
}

M -> bool.E(cost = cost + 2) "boolean" weight 1 {
  require bool_top($1.f) != "not"
  text = "Evaluate [`" ++ bool_latex($1.f) ++ "`] when " ++ bool.given ++ "."
  answer_value = bool_evaluate($1.f, bool.names, bool.mask)
}

prompt "{M.text}"
answer M.answer_value
```

Note `cost + 2`: the exchange rate between the two scales is written where it
belongs, in the importer. `boolean.rhm` no longer needs `B`; `boolean_equiv.rhm`
no longer needs `law_phrasing`.

`logic_forms.rhm` converts the same way: `import "boolean.rhm" as bool`,
`import "boolean_equiv.rhm" as laws`, `K -> laws.L(cost = cost) "tautology"`,
and `bool.names`, `bool.mask` in the equations.

## 6. Static semantics across modules

The checker today types every expression before generation. With modules:

- Every name resolves at check time to (module, kind, name). An unresolved
  qualified name is an error at the importer's position, with the module's
  file named.
- Each module is checked once, on its own, as today. The importer is then
  checked against the modules' **interfaces**: nonterminal names and their
  synthesized attributes with types, inherited attribute names, random and
  let names with types, question names. A module's rules are never
  re-checked in the importer's context.
- The exact-spend property is per module: inside `calc.F` the module's own
  budget rules apply; at the boundary the argument is a plain assignment.
  So the guarantee "a node holding a budget no rule fits is a fatal error"
  is unchanged, and the diagnostic can now say which module's rule set had
  no fit, with the argument that produced the budget.
- Randoms and lets are drawn once per question for every module reachable
  from the question's file, in dependency order (a module's imports before
  it). A set draws them afresh for each question.
- Generation-time retries (`require`) stay local to the attempt, as now; a
  failed `require` deep inside `calc.F` restarts the whole question, as a
  failed `require` inside an included grammar does today.

## 7. Implementation outline

Files and the size of change, in the order to do them:

1. **Modules and arguments** (the enabling step; the largest)
   - `rhema_ast.ml`: `Import_decl of string * string * position`; a symbol form
     `Module_symbol of string * string * (string * expr) list` (alias,
     nonterminal, arguments); expression forms `Module_value of string *
     string` for `calc.given`; prompt holes `{calc.given}`.
   - `rhema_lexer.mll` / `rhema_parser.mly`: `import`, `as`, dotted names,
     argument lists after a dotted symbol (distinguished from generators,
     which have no dot).
   - `rhema_load.ml`: a module table keyed by resolved path; load each file
     once; cycle detection extended to imports; the result is a main spec
     plus a list of module specs.
   - `rhema_check.ml`: a module interface record; resolution of qualified names;
     type of `$n.attr` for a module child from that module's interface;
     argument checks. `spec` gains `imports : (string * module_id) list`.
   - `rhema_engine.ml`: `expand_symbol` on a `Module_symbol` evaluates the
     arguments in the parent environment (share semantics), then expands
     with the module's spec, rules, precedence table and a fresh inherited
     environment; per-module globals; `consumption` unchanged.
   - `rhema list`: print the imports it resolved.
   - Tests: `rhema_modules_test.ml` (resolution, clashes impossible, arguments,
     share under split, consumption across the boundary, cycle refused,
     diagnostics); convert `derivative_or_boolean.rhm` and `logic_forms.rhm`
     and keep their suites green; revert `B` and `law_phrasing` renames.

2. **Named questions** (small)
   - `rhema_ast.ml`: `Question_decl of string * declaration list * position`.
   - `rhema_check.ml`: `spec.questions : question list`, each with the fields
     the singletons hold today; `main` from the file level; `library` means
     no questions.
   - `rhema_engine.ml` / `rhema.ml`: `--question NAME`.
   - `app.py`: list `file:question`.
   - Split `calculus.rhm` into `derivative` and `integral` questions as the
     example; `vector.rhm`, `sequence.rhm`, `library_*.rhm` could follow (their
     fixed forms become named questions).

3. **Sets** (medium)
   - `rhema_ast.ml`: `Set_decl` with parts, entries, argument distributions,
     constraints.
   - New `rhema_set.ml`: seed derivation, budget drawing (`draw_targets` ported
     from Python), `any` choice, distinct-tree and balanced-answer
     constraints with bounded retries, ordering, numbering.
   - `rhema_pgml.ml`: numbered questions and lettered parts in one document.
   - `rhema.ml`: `--run NAME`, `--pg-dir`; listing footer with means.
   - Tests: `rhema_sets_test.ml`; `rhema_difficulty.py set` rewritten as the
     wrapper; docs.

4. **Docs**: a new section group in `RHEMA_LANGUAGE_GUIDE.md`, an English
   language reference (sections for import, question, set with EBNF), the
   Chinese version, `QUESTION_TYPES.md` listing `file:question`.

Estimated size: step 1 is comparable to the include/pg_context/blanks work
(about 40 files touched including tests); steps 2 and 3 are smaller.

## 8. Out of scope here, noted for later

- User-defined pure functions (`function price(n) = ...`): independent of
  modules; proposed as the next language item after sets.
- Lists as a value type with `sum`/`map`.
- A fresh module instance under a second alias.
- Grammar-declared coverage constraints for sets (`cover`).
- Exporting a prompt as a value, so one production could reuse another
  question's wording.
- Statements, loops, mutable variables, I/O: not planned; they would remove
  the static guarantees the language exists for.

## 9. Open decisions

1. Argument syntax: `calc.F(cost = cost)` (proposed) versus
   `calc.F with cost = cost`. The parenthesised form reads like a call and
   is what users of other languages expect.
2. Whether `main` is the right name for the file-level question, or the
   file's base name (`calculus`). `main` is explicit and does not change
   when the file is renamed.
3. Whether a set may set a question's `width` or `context` from outside.
   Proposed: no; those belong to the question.
4. Whether `distinct trees` should compare whole trees or trees with leaf
   values erased. Proposed: erased, which matches "same shape, different
   numbers" being a repeat.
