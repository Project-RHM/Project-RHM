"""Assemble a homework set from a grammar's questions the way a person would.

A person does not hand out independent draws. A set has parts of one type
under one heading, runs from easier to harder, never asks the same shape
twice, covers each law once before repeating one, and does not answer the
same way four times running. This tool generates a pool with agrun and
picks a set that satisfies those constraints, deterministically for a seed.

    python3 tools/ag_set.py generator/ag/boolean.ag:3 generator/ag/boolean_equiv.ag:3
    python3 tools/ag_set.py generator/ag/boolean.ag:4 --seed 2330026211 --pg > set.pg

Each GRAMMAR:COUNT becomes one numbered question with COUNT lettered parts.
Run `dune build` in generator/ first; this drives the built agrun.exe.
"""

from __future__ import annotations

import argparse
import random
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ag_stats import AGRUN, MATH_BLOCK, expressions_of, parse_questions, size_of  # noqa: E402

# The production that decides which law or rule a question states: an L rule
# in the equivalence grammars, an R or T rule in the table grammars.
PRODUCTION = re.compile(r"production: [LRT] -> .*\[line (\d+)\]")
VARIABLE = re.compile(r"(?<![A-Za-z\\])[A-Za-z](?![A-Za-z])")


class Question:
    def __init__(self, prompt: str, answer: str, law: int | None, index: int = 0):
        self.index = index  # 1-based position in the pool, for agrun --pick
        self.prompt = prompt
        self.answer = answer
        self.law = law
        self.expressions = expressions_of(prompt)
        self.size = max((size_of(e) for e in self.expressions), default=0)
        self.skeleton = tuple(skeleton(e) for e in self.expressions)
        # The wording, so one numbered question keeps to one instruction.
        self.opening = " ".join(prompt.split()[:2])
        # The sentence with its numbers taken out: two parts with the same
        # shape ("Is [`a + b = c`] true?" twice) read as a template.
        self.shape = re.sub(r"\d+", "#", prompt)
        # The words of the sentence, math and numbers blanked out, for
        # judging whether two sentences are built on one template.
        self.words = set(re.sub(r"\[`.*?`\]", "M", self.shape).split())


def skeleton(expression: str) -> str:
    """The expression with variables renamed in order of first appearance,
    so p \\to (q \\lor r) and r \\to (p \\lor q) count as the same shape."""
    names: dict[str, str] = {}

    def rename(match: re.Match[str]) -> str:
        letter = match.group(0)
        names.setdefault(letter, f"v{len(names) + 1}")
        return names[letter]

    return VARIABLE.sub(rename, expression)


def generate_pool(grammar: Path, count: int, seed: int, settings: list[str]) -> tuple[list[Question], bool]:
    if not AGRUN.exists():
        sys.exit(f"{AGRUN} not found; run `dune build` in generator/ first")
    with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as handle:
        ast_path = Path(handle.name)
    command = [str(AGRUN), "--count", str(count), "--seed", str(seed), "--ast-out", str(ast_path)]
    for setting in settings:
        command += ["--set", setting]
    command.append(str(grammar))
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(result.stderr.strip() or f"agrun exited with {result.returncode}")
    # The derivation text names, per question, the law production that was
    # applied (equivalence grammar only); its line number identifies the law.
    laws: list[int | None] = []
    for block in re.split(r"^Question \d+", ast_path.read_text(), flags=re.M)[1:]:
        found = PRODUCTION.search(block)
        laws.append(int(found.group(1)) if found else None)
    ast_path.unlink()
    questions = parse_questions(result.stdout)
    if len(laws) != len(questions):
        laws = [None] * len(questions)
    has_stem = result.stdout.startswith("Stem: ")
    return [Question(prompt, answer, law, index + 1)
            for index, ((prompt, answer), law) in enumerate(zip(questions, laws))], has_stem


def ramp(sizes: list[int], count: int) -> list[int]:
    """`count` target sizes running from the pool's easiest to its hardest."""
    distinct = sorted(set(sizes))
    return [distinct[min(len(distinct) - 1, index * len(distinct) // count)] for index in range(count)]


def answer_pattern(answers: list[str], count: int, rng: random.Random) -> list[str | None]:
    """A balanced sequence of answers with no run longer than two.

    Only for answers that are categories (1/0, true/false, the four kinds of
    sentence). A truth table or a formula is its own answer; those are not
    balanced, so the pattern is all None."""
    values = sorted(set(answers))
    if len(values) < 2 or len(values) > 6:
        return [None] * count
    for _ in range(1000):
        pattern = [values[index % len(values)] for index in range(count)]
        rng.shuffle(pattern)
        if all(not (pattern[i] == pattern[i + 1] == pattern[i + 2]) for i in range(count - 2)):
            return pattern
    return [values[index % len(values)] for index in range(count)]


def choose(pool: list[Question], count: int, rng: random.Random, has_stem: bool) -> list[Question]:
    """Pick `count` questions a person would put under one heading.

    Hard, relaxed only if the pool cannot satisfy them: no repeated shape,
    and the answer pattern. Soft, relaxed in order: the size ramp, each law
    once, and the wording -- one instruction throughout when every part
    carries its own instruction, a different opening each time when the
    parts share a stem and are only the sentences themselves."""
    order = pool[:]
    rng.shuffle(order)
    sizes = ramp([q.size for q in pool], count)
    answers = answer_pattern([q.answer for q in pool], count, rng)
    chosen: list[Question] = []
    seen_shapes: set[tuple[str, ...]] = set()
    seen_laws: set[int | None] = set()
    all_laws = {q.law for q in pool if q.law is not None}
    opening: str | None = None
    for size, answer in zip(sizes, answers):
        def fits(q: Question, exact_size: bool, fresh_law: bool, wording: bool) -> bool:
            if has_stem:
                # Sentences share a stem, so each should read differently
                # from the two before it: under 60% of words in common.
                similarity = lambda c: len(q.words & c.words) / max(1, len(q.words | c.words))
                good_wording = all(similarity(c) < 0.6 for c in chosen[-2:]) and all(
                    similarity(c) < 0.85 for c in chosen
                )
            else:
                good_wording = opening is None or q.opening == opening
            return (
                (answer is None or q.answer == answer)
                and q.skeleton not in seen_shapes
                and q.shape not in {c.shape for c in chosen}
                and (not exact_size or q.size == size)
                and (not fresh_law or q.law is None or q.law not in seen_laws)
                and (not wording or good_wording)
            )
        pick = None
        for wording in (True, False):
            for exact_size, fresh_law in ((True, True), (True, False), (False, True), (False, False)):
                pick = next((q for q in order if fits(q, exact_size, fresh_law, wording)), None)
                if pick:
                    break
            if pick:
                break
        if pick is None:
            sys.exit("the pool is too small to fill the set; raise --pool")
        chosen.append(pick)
        opening = pick.opening
        if not has_stem or pick.size:
            seen_shapes.add(pick.skeleton)
        if pick.law is not None:
            seen_laws.add(pick.law)
            if seen_laws >= all_laws:
                seen_laws.clear()
    # Easier before harder, but sentences keep the order that spread their
    # answers and openings out.
    if any(q.size for q in chosen):
        chosen.sort(key=lambda q: q.size)
    return chosen


def pg_document(parts: list[tuple[Path, int, int, list[Question], list[str]]]) -> str:
    """One WeBWorK document for the whole set. Each numbered question is
    asked of agrun again with --pick, so its answers are built exactly as a
    single-grammar document builds them; the pieces are then merged: macros
    united, answer objects renamed per question, bodies under headings."""
    macros: list[str] = []
    setups: list[str] = []
    bodies: list[str] = []
    for number, (grammar, pool, seed, group, settings) in enumerate(parts, 1):
        # --weights: every numbered question is then worth 100, and every
        # part of one worth the same, whether or not its grammar asks for
        # weights, so a weighted group cannot drown an unweighted one.
        command = [str(AGRUN), "--pg", "--weights", "--count", str(pool), "--seed", str(seed),
                   "--pick", ",".join(str(q.index) for q in group)]
        for setting in settings:
            command += ["--set", setting]
        command.append(str(grammar))
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            sys.exit(result.stderr.strip())
        document = result.stdout
        found = re.search(r"loadMacros\((.*?)\);", document)
        for macro in re.findall(r'"([^"]+)"', found.group(1) if found else ""):
            if macro not in macros:
                macros.append(macro)
        head, _, rest = document.partition("BEGIN_PGML\n")
        body, _, _ = rest.partition("\nEND_PGML")
        setup = head.split(");\n", 2)[-1] if head.count(");\n") >= 2 else ""
        setup = re.sub(r"^Context\(\"[^\"]*\"\);\n\n", "", setup)
        rename = lambda text: re.sub(r"\$ans(\d+)", lambda m: f"$q{number}_{m.group(1)}", text)
        setups.append(rename(setup).strip())
        bodies.append(f"**Question {number}.**\n\n" + rename(body).strip())
    quoted = ", ".join(f'"{macro}"' for macro in macros)
    return "\n".join(
        ["DOCUMENT();", f"loadMacros({quoted});", 'Context("Numeric");', ""]
        + [setup + "\n" for setup in setups if setup]
        + ["BEGIN_PGML", "\n\n".join(bodies), "END_PGML", "ENDDOCUMENT();"]
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("groups", nargs="+", metavar="GRAMMAR:COUNT")
    parser.add_argument("--seed", type=int, default=1, help="student id or any number")
    parser.add_argument("--pool", type=int, default=0, help="pool size per group (default 40 x COUNT)")
    parser.add_argument("--set", dest="settings", action="append", default=[], metavar="NAME=VALUE")
    parser.add_argument("--pg", action="store_true", help="write a WeBWorK .pg document")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    groups: list[list[Question]] = []
    parts = []
    for index, group in enumerate(args.groups):
        grammar, _, count_text = group.rpartition(":")
        if not grammar:
            sys.exit(f"write GRAMMAR:COUNT, not {group!r}")
        count = int(count_text)
        pool_size = args.pool or 40 * count
        pool, has_stem = generate_pool(Path(grammar), pool_size, args.seed + index, args.settings)
        chosen = choose(pool, count, rng, has_stem)
        groups.append(chosen)
        parts.append((Path(grammar), pool_size, args.seed + index, chosen, args.settings))

    if args.pg:
        print(pg_document(parts))
        return
    for number, group in enumerate(groups, 1):
        print(f"Question {number}.")
        for letter, question in zip("abcdefghij", group):
            lines = question.prompt.split("\n")
            print(f"  {letter}) {lines[0]}")
            for line in lines[1:]:
                print(f"     {line}")
            print(f"     answer: {question.answer}")
        print()


if __name__ == "__main__":
    main()
