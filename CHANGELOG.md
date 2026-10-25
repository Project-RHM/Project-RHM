# Changelog

Rhema follows semantic versioning: the language's syntax, the builtin
functions' names and arguments, and the `rhema` command's options are the
public interface. A breaking change raises the major version; a deprecation
is announced one version before the removal.

## Unreleased

- **CI**: GitHub Actions builds the package from a clean export on OCaml
  4.14 and 5, Linux and macOS, exactly as opam does, installs it into a
  prefix and runs the command; a second job builds the whole tree with every
  suite and the Python checks.

## 0.1.1 (2026-10-25)

Packaging only. The classic generator and its PG parser, which need
`pprint` and `menhirCST`, are built in the development profile only, so the
package's tests no longer fail on a machine without them (`dune build -p
rhema @runtest`). No change to the language or the command.

## 0.1.0 (2026-10-24)

The first version with a name.

- **Language**: Rhema, files `.rhm`. Attribute grammars with inherited budgets
  and synthesized attributes; `include`; `import "file.rhm" as name` with
  arguments at the boundary; `question NAME { ... }` blocks; `set NAME { ... }`
  declarations with budgets drawn fixed, from a list, or around a mean;
  `pg_context` / `pg_width` per question; `{answer ...}` blanks.
- **Values**: Number, Formula, Polynomial, Equation, Boolean, Matrix, Set,
  Vector, Complex, with their builtin functions (`rhema doc`).
- **Difficulty**: every library grammar spends a cost budget exactly;
  `--set cost=N`; sets fix the mean of a part.
- **Command**: `rhema FILE.rhm [-o OUT.pg]`, `check`, `run`, `list`, `doc`;
  GNU error format and exit codes; `-I` and `RHEMA_PATH`; one assignment is
  one paper, `--student` for a student's own.
- **Library**: 24 question grammars, 2 grammar libraries, 1 example set file,
  installed to `share/rhema` by `dune install`.
- **Layout**: `generator/rhema/{lib,bin,test}`, `generator/stdlib`,
  `generator/grammars` for the user's own files.
- **Packaging**: opam metadata in `generator/dune-project` (generated
  `rhema.opam`, MIT, tests run with `--with-test`); `RELEASING.md` describes
  tagging, the source archive and the opam-repository entry.
