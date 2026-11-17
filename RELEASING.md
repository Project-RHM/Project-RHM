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

1. Set the version in `generator/dune-project` (`(version X.Y.Z)`), run
   `dune build` so that `rhema.opam` follows, and give the `CHANGELOG.md`
   entry its version and date. Where `README.md`, `README.zh.md` and the
   pages under `docs/` name the release that opam installs, name the new
   one, with a note that opam has the old one until the opam repository
   accepts the new (step 7 removes the note). Commit.
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

4. Tag the commit on `main` and push the tag:
   `git tag vX.Y.Z && git push origin vX.Y.Z`.
5. Make the source archive. Because the dune project lives in `generator/`,
   the release archive is that directory, not the repository:

   ```bash
   git archive --format=tar.gz --prefix=rhema-X.Y.Z/ -o rhema-X.Y.Z.tar.gz vX.Y.Z:generator
   ```

   Make it once. An archive of a directory carries the time it was made, so
   a second run gives a file with other checksums; the file that is uploaded
   is the one the checksums of step 6 are taken from. Publish a GitHub
   release for the tag with the archive as its asset, so that it is at
   `https://github.com/Project-RHM/Project-RHM/releases/download/vX.Y.Z/rhema-X.Y.Z.tar.gz`.
6. Submit to opam. The entry is `packages/rhema/rhema.X.Y.Z/opam` in a
   branch of a fork of
   [ocaml/opam-repository](https://github.com/ocaml/opam-repository) (ours
   is `Project-RHM/opam-repository`): the generated `rhema.opam` without its
   first line (the comment) and its `version:` line, and with this appended:

   ```
   x-maintenance-intent: ["(latest)"]
   url {
     src: "https://github.com/Project-RHM/Project-RHM/releases/download/vX.Y.Z/rhema-X.Y.Z.tar.gz"
     checksum: [
       "sha256=..."
       "sha512=..."
     ]
   }
   ```

   (`shasum -a 256` and `shasum -a 512` of the archive.) Once the release
   is published, `opam lint --check-upstream packages/rhema/rhema.X.Y.Z/opam`
   downloads the archive and compares the checksums. Open the pull request
   against `ocaml/opam-repository`; its CI builds the package on several
   OCaml versions and platforms, and a maintainer merges once it is green,
   usually within days.
7. When opam has the release (`opam update && opam show rhema`), remove the
   note of step 1 from the READMEs and the site.

## Without the opam repository

Anyone with access to the repository can install the current development
version by pinning the `generator` directory (a pin looks for the opam file
at the root of what it is given, and ours is in `generator/`):

```bash
git clone https://github.com/Project-RHM/Project-RHM.git
opam pin add rhema ./Project-RHM/generator
```

`opam upgrade rhema` after a `git pull` picks up new commits.

## The VS Code extension

The extension in `editors/vscode` has its own version and is released
separately, to the Visual Studio Marketplace and Open VSX, with tags named
`vscode-vX.Y.Z`; `editors/vscode/PUBLISHING.md` (Chinese:
`PUBLISHING.zh.md`) gives the steps.
