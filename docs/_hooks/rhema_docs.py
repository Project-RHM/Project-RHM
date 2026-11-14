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
    constants = ("true", "false")
    set_words = ("part", "of", "any", "in", "spread", "low", "allowed", "distinct", "balanced", "ordered")

    tokens = {
        "root": [
            (r"\s+", Text),
            (r"#.*$", Comment.Single),
            (r'"', String.Double, "string"),
            (words(keywords, suffix=r"\b"), Keyword),
            (words(operators_words, suffix=r"\b"), Operator.Word),
            (words(constants, suffix=r"\b"), Keyword.Constant),
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
     "Symbolic expressions in named variables: constants, the constant pi, "
     "variables, the four operations and powers, `sin`, `cos`, `tan`, `exp`, `ln` "
     "and `sqrt`, with differentiation, substitution, a zero test and LaTeX, and "
     "the exact values of sine, cosine and tangent at multiples of pi/6 and pi/4. "
     "A formula answer is graded by WeBWorK as a formula; one in variables other "
     "than `x` is written with a context that declares them."),
    ("answers", "Answers",
     "Functions that say how something is asked for, not what it is: an answer "
     "blank as part of a production's text, and an answer that must be worked "
     "out."),
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
     "row written as a linear equation). A matrix of any shape is built from "
     "vectors as rows or columns, put one above or beside another; such a matrix "
     "has a reduced row echelon form and a rank. A matrix answer is graded in the "
     "Matrix context."),
    ("set", "Sets",
     "Finite sets, intervals and rays of real numbers, with union, intersection "
     "and difference, and LaTeX. A set answer is graded in the Interval context."),
    ("vector", "Vectors",
     "Vectors with exact entries: sums, multiples, dot and cross products, norms, "
     "unit vectors, parallel and direction tests, and the answer forms WeBWorK's "
     "Vector context needs."),
    ("point", "Points",
     "A point of the plane or of space with exact coordinates, and its LaTeX. A "
     "point answer is entered as `(3, -2)` and is graded as a point whatever "
     "context the question is in: the answer carries WeBWorK's Point context "
     "with it."),
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
    "formula_pi": "The constant pi, kept as a symbol: `formula_multiply(formula_constant(5 / 6), formula_pi())` is written `\\frac{5\\pi}{6}` and graded as `5pi/6`.",
    "formula_value": "The number a formula without variables comes to, exactly; an error when it holds a variable, pi or a value of a function that is not rational.",
    "exact_sin": "`exact_sin(p, q)`: the value of sin(p pi / q) as a formula, such as `sqrt(3)/2`, for multiples of pi/6 and pi/4; an error for other angles.",
    "exact_cos": "`exact_cos(p, q)`: the value of cos(p pi / q), as `exact_sin`.",
    "exact_tan": "`exact_tan(p, q)`: the value of tan(p pi / q), as `exact_sin`; an error where the tangent is not defined.",
    "polynomial_truncate": "`polynomial_truncate(p, n)`: the terms of `p` of degree at most `n`, which is what is left of a series written out to a higher degree.",
    "base_digits": "`base_digits(n, b)`: the whole number `n` written in base `b` (2 to 16) as text, with the digits 0-9 and A-F.",
    "base_number": "`base_number(n, b)`: the number whose decimal digits are the digits of `n` in base `b` (2 to 10), so that eleven in binary is an answer typed as `1011`.",
    "blank": "`blank(v)`: an answer blank graded against `v`, to be joined to a production's text with `++`.",
    "blank_wide": "`blank_wide(v, columns)`: as `blank`, with a width of its own, from 1 to 200.",
    "exactly": "`exactly(n)`: the whole number `n` as an answer graded without WeBWorK's relative tolerance, so that no other whole number is accepted. A whole-number answer of 1000 or more is graded this way without being asked.",
    "plain": "`plain(v)`: the number or formula `v` as an answer that must be worked out: graded with the trigonometric, hyperbolic, logarithm and exponential functions switched off; `sqrt` and `abs` stay.",
    "matrix_row": "`matrix_row(v)`: the vector `v` as a matrix of one row.",
    "matrix_column": "`matrix_column(v)`: the vector `v` as a matrix of one column.",
    "matrix_stack": "`matrix_stack(A, B)`: `A` above `B`; they must have the same number of columns.",
    "matrix_augment": "`matrix_augment(A, B)`: `A` with `B` to its right, the augmented matrix `[A | B]`; they must have the same number of rows.",
    "matrix_rows": "The number of rows of a matrix.",
    "matrix_columns": "The number of columns of a matrix.",
    "matrix_rank": "The rank of a matrix of any shape: the number of pivots of its reduced row echelon form.",
    "matrix_rref": "The reduced row echelon form of a matrix of any shape, with exact entries.",
    "point2": "`point2(x, y)`: a point of the plane.",
    "point3": "`point3(x, y, z)`: a point of space.",
    "point_latex": "A point in LaTeX, `\\left(3, -\\frac{1}{2}\\right)`.",
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
        "The site is built from the repository, which is ahead of the 0.1.1 release:",
        "`choose`, `factorial`, `gcd`, `lcm`, `mod_inverse`, `number_latex`,",
        "`permutations`, `pow_mod`, `set_above`, `set_below`, the `point` functions,",
        "`matrix_row`, `matrix_column`, `matrix_stack`, `matrix_augment`,",
        "`matrix_rows`, `matrix_columns`, `matrix_rank`, `matrix_rref`, `blank`,",
        "`blank_wide`, `plain`, `exactly`, `formula_pi`, `formula_value`, the `exact_`",
        "functions, `base_digits`, `base_number` and `polynomial_truncate` are not in",
        "that package;",
        "neither are `true`, `false`, `let` inside a production and `pg_variables`.",
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
