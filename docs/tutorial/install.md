# Installing with opam

`rhema` is written in OCaml and published through
[opam](https://opam.ocaml.org/), OCaml's package manager. Installing it takes
three steps: install opam, let opam set itself up, and ask it for `rhema`.
You do not need to know OCaml, and nothing here asks you to write any.

The steps are for Linux and macOS, where `rhema` is built and tested on every
change. On Windows, install
[WSL](https://learn.microsoft.com/windows/wsl/install) and follow the Linux
steps inside it.

If you already use opam, go straight to [step 3](#3-install-rhema).

## 1. Install opam

Use your system's package manager:

| System | Command |
| --- | --- |
| macOS, with [Homebrew](https://brew.sh/) | `brew install opam` |
| macOS, with [MacPorts](https://www.macports.org/) | `sudo port install opam` |
| Debian and Ubuntu | `sudo apt install opam` |
| Fedora | `sudo dnf install opam` |
| Arch Linux | `sudo pacman -S opam` |

On any other system, or to have the newest opam, use opam's own installer.
It downloads one program and asks where to put it:

```text
$ bash -c "sh <(curl -fsSL https://opam.ocaml.org/install.sh)"
```

The installer brings opam alone, not the tools opam works with: a C
compiler, `make`, `curl`, `unzip` and, on Linux, `bubblewrap`. Install those
first. On Debian and Ubuntu that is
`sudo apt install build-essential curl unzip bubblewrap`; on macOS,
`xcode-select --install` provides the compiler and `make`, and the rest are
already there. [opam's install page](https://opam.ocaml.org/doc/Install.html)
covers more systems.

Check that opam is there:

```text
$ opam --version
2.4.1
```

Any version 2 will do. If opam later warns that a newer version has security
fixes, the installer above replaces the old one.

## 2. Set opam up

Run this as yourself, without `sudo`:

```text
$ opam init
```

It downloads the list of packages, asks one question, and then gives you an
OCaml compiler: the system's own if there is one, otherwise one it builds,
which takes a few minutes. Everything it installs goes into `~/.opam`.

The question is whether opam may add a line to your shell's startup file:

```text
Do you want opam to configure zsh?
> 1. Yes, update ~/.zshrc
  2. Yes, but don't setup any hooks. You'll have to run eval $(opam env) whenever you change your current 'opam switch'
  3. Select a different shell
  4. Specify another config file to update instead
  5. No, I'll remember to run eval $(opam env) when I need opam

[1/2/3/4/5]
```

Choose `1`: that line is how every new terminal finds the commands opam
installs. (An older opam asks the same thing as a yes-or-no question; answer
`y`.) For the terminal you are in now, run:

```text
$ eval $(opam env)
```

!!! note "In a container"
    opam builds packages in a sandbox, which does not work inside Docker and
    similar containers. There, run `opam init --disable-sandboxing` instead.

## 3. Install rhema

```text
$ opam update
$ opam install rhema
```

`opam update` fetches the current list of packages; straight after
`opam init` the list is already current and the command does no harm. opam
then says what it is about to install, `rhema` and the tools it is built
with, and asks whether to go on:

```text
The following actions will be performed:
=== install 7 packages
  - install dune      3.24.2   [required by rhema]
  - install menhir    20260209 [required by rhema]
  - install menhirCST 20260209 [required by menhir]
  - install menhirGLR 20260209 [required by menhir]
  - install menhirLib 20260209 [required by menhir]
  - install menhirSdk 20260209 [required by menhir]
  - install rhema     0.1.1
```

Answer `y`. Building takes a minute or two. Then:

```text
$ rhema --version
rhema 0.1.1 (the Rhema language, RHM project)
```

The package holds the `rhema` command and the library of grammars. The
library is in the directory `opam var rhema:share` prints, and `rhema` looks
there by itself, so an `import` of a library file works from any directory.

That is everything the tutorial needs. Go on to
[A first question](first.md).

## Updating and removing

To move to a new release of `rhema` when one is published:

```text
$ opam update
$ opam upgrade rhema
```

To remove it:

```text
$ opam remove rhema
```

## If something goes wrong

`rhema: command not found`
:   The terminal does not have opam's settings. Run `eval $(opam env)`. If
    every new terminal needs this, the line from step 2 was not added: run
    `opam init` again and choose `1` this time.

opam finds no package named `rhema`
:   Its list of packages is older than `rhema`. Run `opam update` and try
    again.

opam says `rhema` cannot be installed with your version of OCaml
:   `rhema` needs OCaml 4.14 or later, and an opam set up some years ago may
    hold an older compiler; `ocaml -version` shows which. Build a newer one
    beside it, then install `rhema` there:

    ```text
    $ opam switch create rhema 5.5.2
    $ eval $(opam env --switch=rhema)
    $ opam install rhema
    ```

A build stops because `cc`, `gcc` or `make` is missing
:   The build tools named in step 1 are not installed. Install them and run
    `opam install rhema` again.

For anything else, open an issue on
[GitHub](https://github.com/Project-RHM/Project-RHM/issues) with the last
lines opam printed.
