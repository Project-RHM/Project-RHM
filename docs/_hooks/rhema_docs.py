"""MkDocs hooks for the Rhema site.

Registers a Pygments lexer so that ```rhema code blocks are highlighted as
Rhema. (The lexer lives here rather than in a package so the site needs
nothing installed beyond MkDocs Material.)
"""

import re
import sys

from pygments.lexer import RegexLexer, bygroups, words
from pygments.token import Comment, Keyword, Name, Number, Operator, Punctuation, String, Text


class RhemaLexer(RegexLexer):
    name = "Rhema"
    aliases = ["rhema", "rhm"]
    filenames = ["*.rhm"]

    keywords = (
        "attribute", "random", "let", "synth", "on", "start", "context", "precedence",
        "left", "right", "nonassoc", "copy", "split", "when", "weight", "require",
        "prompt", "answer", "width", "include", "import", "as", "question", "set",
    )
    operators_words = ("and", "or", "not", "boolean")
    set_words = ("part", "of", "any", "in", "spread", "low", "allowed", "distinct", "balanced", "ordered")

    tokens = {
        "root": [
            (r"\s+", Text),
            (r"#.*$", Comment.Single),
            (r'"', String.Double, "string"),
            (words(keywords, suffix=r"\b"), Keyword),
            (words(operators_words, suffix=r"\b"), Operator.Word),
            (words(set_words, suffix=r"\b"), Keyword.Pseudo),
            (r"\$\d+", Name.Variable.Magic),
            (r"\d+", Number.Integer),
            (r"->|\+\+|!=|<=|>=|[=<>+\-*/%^~]", Operator),
            (r"[A-Z][A-Za-z0-9_]*", Name.Class),           # nonterminals
            (r"[a-z_][A-Za-z0-9_]*(?=\s*\()", Name.Function),  # builtins and generators
            (r"[a-z_][A-Za-z0-9_]*", Name),
            (r"[{}(),.]", Punctuation),
        ],
        "string": [
            (r'\\[\\"]', String.Escape),
            (r"\{\{|\}\}", String.Escape),
            (r"\{[^{}]*\}", String.Interpol),               # prompt holes {E.latex}
            (r'[^"\\{]+', String.Double),
            (r"\\", String.Double),
            (r'"', String.Double, "#pop"),
        ],
    }


def _register_lexer():
    import pygments.lexers as lexers

    module = sys.modules[__name__]
    sys.modules.setdefault("rhema_docs_lexer", module)
    lexers.LEXERS["RhemaLexer"] = ("rhema_docs_lexer", "Rhema", ("rhema", "rhm"), ("*.rhm",), ())
    lexers._lexer_cache["Rhema"] = RhemaLexer


def on_startup(command, dirty):
    _register_lexer()


def on_config(config):
    _register_lexer()
    # Snippet paths are relative to the working directory; make them relative
    # to mkdocs.yml instead, so the site builds from anywhere.
    import os

    root = os.path.dirname(os.path.abspath(config.config_file_path))
    options = config.mdx_configs.get("pymdownx.snippets", {})
    options["base_path"] = [
        path if os.path.isabs(path) else os.path.join(root, path)
        for path in options.get("base_path", ["."])
    ]
    config.mdx_configs["pymdownx.snippets"] = options
    return config


# ---------------------------------------------------------------------------
# The builtin functions page, generated from `rhema doc` so that it lists
# exactly what the compiler accepts.
# ---------------------------------------------------------------------------

GROUPS = [
    ("general", "Numbers, text and rendering",
     "Functions on numbers and text, and the two that write operators with the "
     "right brackets."),
    ("generators", "Generators",
     "Leaves that draw a whole number. They appear on the right of a production, "
     "or after `random NAME =`; their arguments are whole numbers."),
    ("integers", "Whole numbers",
     "Counting and number theory on whole numbers: factorials, binomial "
     "coefficients and permutations, greatest common divisors and least common "
     "multiples, powers and inverses modulo n. A result too large for a 63-bit "
     "integer, or an inverse that does not exist, stops generation with a "
     "message."),
    ("formula", "Formulas",
     "Symbolic expressions in named variables: constants, variables, the four "
     "operations and powers, `sin`, `cos`, `tan`, `exp`, `ln` and `sqrt`, with "
     "differentiation, substitution, a zero test and LaTeX. A formula answer is "
     "graded by WeBWorK as a formula."),
    ("polynomial", "Polynomials",
     "Polynomials in one variable with exact coefficients: building from "
     "monomials, linear and quadratic factors, arithmetic, expansion, evaluation, "
     "coefficients and degree, factored forms for the PolynomialFactors context, "
     "and LaTeX."),
    ("equation", "Equations",
     "Equations between two formulas, solved exactly where possible. An equation "
     "is not itself an answer: `equation_solution_set` and "
     "`equation_unique_solution` give one."),
    ("bool", "Propositions",
     "Propositional formulas over named variables, built from `bool_var` and the "
     "connectives, and decided by enumerating every assignment: evaluation under an "
     "assignment, equivalence, tautology and contradiction tests, model counting, "
     "rewriting without the conditional connectives, and shape inspection "
     "(top connective, counts of connectives and negations). A proposition answer "
     "is graded in the Boolean context."),
    ("matrix", "Matrices",
     "Matrices with exact rational entries: 2 by 2 and 3 by 3 construction, the "
     "identity, sum, difference, product, scalar multiple, transpose, determinant, "
     "inverse, entries, a matrix times a vector, and LaTeX (a whole matrix, or a "
     "row written as a linear equation). A matrix answer is graded in the Matrix "
     "context."),
    ("set", "Sets",
     "Finite sets, intervals and rays of real numbers, with union, intersection "
     "and difference, and LaTeX. A set answer is graded in the Interval context."),
    ("vector", "Vectors",
     "Vectors with exact entries: sums, multiples, dot and cross products, norms, "
     "unit vectors, parallel and direction tests, and the answer forms WeBWorK's "
     "Vector context needs."),
    ("complex", "Complex numbers",
     "A complex number from its real and imaginary parts, and its LaTeX. Complex "
     "arithmetic is written with the ordinary operators on the parts."),
]

DESCRIPTIONS = {
    "str": "The text of a number or other value.",
    "paren": "Its argument with brackets around it.",
    "infix": "`infix($1, \"+\", $3)`: the two children joined by the operator text, bracketed as the precedence table requires.",
    "prefix": "`prefix(\"\\neg\", $2)`: the operator text before the child, bracketed as the precedence table requires.",
    "cond": "`cond(c, a, b)`: `a` when `c` is true, `b` otherwise.",
    "abs": "The absolute value of a number.",
    "min": "The smaller of two numbers.",
    "max": "The larger of two numbers.",
    "bit_and": "Bitwise and of two whole numbers; with `bit_or`, a way to track which of several items a subtree has used.",
    "bit_or": "Bitwise or of two whole numbers.",
    "bit_xor": "Bitwise exclusive or of two whole numbers.",
    "integer": "`integer(n)`: a whole number with exactly `n` digits.",
    "nonzero_integer": "`nonzero_integer(n)`: as `integer`, never 0.",
    "integer_between": "`integer_between(a, b)`: a whole number from `a` to `b` inclusive.",
    "nonzero_integer_between": "`nonzero_integer_between(a, b)`: as `integer_between`, never 0.",
    "number_latex": "A number in LaTeX: a whole number as it is, a fraction as `\\frac{p}{q}` with its sign in front.",
    "factorial": "`factorial(n)`: n!, for n from 0 to 20.",
    "choose": "`choose(n, k)`: the number of ways to choose k of n; 0 when k is out of range.",
    "permutations": "`permutations(n, k)`: the number of ordered choices of k of n.",
    "gcd": "The greatest common divisor of two whole numbers.",
    "lcm": "The least common multiple of two whole numbers.",
    "pow_mod": "`pow_mod(a, k, n)`: the remainder of a^k on division by n, for k >= 0 and n > 0.",
    "mod_inverse": "`mod_inverse(a, n)`: the x in 0..n-1 with a x = 1 (mod n); an error unless a and n are coprime.",
    "set_above": "`set_above(a, closed)`: the numbers above a, `(a, \\infty)`, or from a, `[a, \\infty)`, when `closed` is true.",
    "set_below": "`set_below(a, closed)`: the numbers below a, `(-\\infty, a)`, or up to a, `(-\\infty, a]`.",
    "differentiate": "`differentiate(f, \"x\")`: the derivative of formula `f` with respect to `x`.",
}


def _find_rhema():
    import os
    import shutil

    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    for candidate in (
        os.environ.get("RHEMA"),
        os.path.join(root, "generator", "_build", "install", "default", "bin", "rhema"),
        shutil.which("rhema"),
    ):
        if candidate and os.path.exists(candidate):
            return candidate
    raise RuntimeError(
        "the rhema command was not found: build it (cd generator && dune build) "
        "or set RHEMA to its path"
    )


def _builtins_markdown():
    import subprocess

    listing = subprocess.run(
        [_find_rhema(), "doc"], capture_output=True, text=True, check=True
    ).stdout
    entries = {}
    group = None
    for line in listing.splitlines():
        if not line.strip() or line.startswith("What each one does"):
            continue
        if not line.startswith(" "):
            group = line.strip()
            entries.setdefault(group, [])
            continue
        parts = line.split()
        name, count = parts[0], int(parts[1])
        entries[group].append((name, count))

    out = [
        "# Builtin functions",
        "",
        "The functions an expression may call, grouped by the kind of value they work",
        "on. This page is generated from `rhema doc`, so it lists exactly what the",
        "compiler accepts; calling one with the wrong number of arguments is an",
        "error the checker reports. A function given the wrong kind of value stops",
        "generation with a message naming both.",
        "",
    ]
    known = [key for key, _, _ in GROUPS]
    for key, title, intro in GROUPS + [(g, g.capitalize(), "") for g in entries if g not in known]:
        names = entries.get(key)
        if not names:
            continue
        out += [f"## {title}", ""]
        if intro:
            out += [intro, ""]
        out += ["| Function | Arguments | |", "|---|---|---|"]
        for name, count in names:
            out.append(f"| `{name}` | {count} | {DESCRIPTIONS.get(name, '')} |")
        out.append("")
    total = sum(len(v) for v in entries.values())
    out.append(f"{total} functions in all.")
    return "\n".join(out) + "\n"


def on_files(files, config):
    from mkdocs.structure.files import File

    files.append(File.generated(config, "reference/builtins.md", content=_builtins_markdown()))
    return files
