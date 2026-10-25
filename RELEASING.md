# Releasing Rhema

The package `rhema` is defined in `generator/dune-project`; `generator/rhema.opam`
is generated from it (edit the project file, then `dune build`). The package
installs the `rhema` command and the library grammars (`share/rhema`), and
its tests run with `--with-test`. The classic generator in `generator/`
(`pg_core`, `unparser`, `visualize`, the PG read-back test) is built in the
development profile only (`enabled_if (= %{profile} dev)`): it needs
`pprint` and `menhirCST`, which the package does not depend on, and opam's
`dune build -p rhema @runtest` must not reach it.

## Before the first public release

1. Revoke the API key that is in the git history and issue a new one; a
   public repository is read by everyone, history included.
2. Make the repository public (the licence is MIT, `LICENSE` at the root and
   a copy in `generator/`, which the package installs).

## Each release

1. Set the version in `generator/dune-project` (`(version X.Y.Z)`), move the
   `CHANGELOG.md` entry from "unreleased" to the version and date, and
   commit.
2. Check locally, in `generator/`:

   ```bash
   dune build && dune build -p rhema @install @runtest && opam lint rhema.opam
   ```

3. Build the package from a clean export of the commit, exactly as opam
   will, before tagging; a file that is tracked by mistake or ignored by
   mistake shows up here and nowhere else. CI (`.github/workflows/ci.yml`)
   does the same on every push, so a green `package` job on the commit is
   this step done; locally:

   ```bash
   rm -rf /tmp/rhema-export && mkdir /tmp/rhema-export && git archive HEAD:generator | tar x -C /tmp/rhema-export && (cd /tmp/rhema-export && dune build -p rhema @install @runtest --force && opam lint rhema.opam)
   ```

4. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`.
5. Make the source archive. Because the dune project lives in `generator/`,
   the release archive is that directory, not the repository: install
   `dune-release` (`opam install dune-release`) and run, in `generator/`:

   ```bash
   dune-release distrib
   ```

   It writes `_build/rhema-X.Y.Z.tbz`. Upload it as an asset of the GitHub
   release for the tag (`dune-release publish distrib` does this with a
   GitHub token, or do it by hand).
6. Submit to opam: `dune-release opam pkg` writes the entry, `dune-release
   opam submit` opens the pull request against ocaml/opam-repository. By
   hand, the entry is `packages/rhema/rhema.X.Y.Z/opam`: the generated
   `rhema.opam` with the `version:` line removed and this appended:

   ```
   url {
     src: "https://github.com/Project-RHM/Project-RHM/releases/download/vX.Y.Z/rhema-X.Y.Z.tbz"
     checksum: [
       "sha256=..."
       "sha512=..."
     ]
   }
   ```

   (`sha256sum`/`sha512sum` of the archive.) The opam CI builds the package
   on several OCaml versions and platforms; a maintainer merges once it is
   green, usually within days.

## Without the opam repository

Anyone with access to the repository can install the current development
version by pinning the `generator` directory (a pin looks for the opam file
at the root of what it is given, and ours is in `generator/`):

```bash
git clone https://github.com/Project-RHM/Project-RHM.git
opam pin add rhema ./Project-RHM/generator
```

`opam upgrade rhema` after a `git pull` picks up new commits.
