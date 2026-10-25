"""Assemble a homework set from a grammar's questions the way a person would.

A person does not hand out independent draws. A set has parts of one type
under one heading, runs from easier to harder, never asks the same shape
twice, covers each law once before repeating one, and does not answer the
same way four times running. This tool generates a pool with rhema and
picks a set that satisfies those constraints, deterministically for a seed.

    python3 tools/rhema_set.py generator/stdlib/boolean.rhm:3 generator/stdlib/boolean_equiv.rhm:3
    python3 tools/rhema_set.py generator/stdlib/boolean.rhm:4 --seed 2330026211 --pg > set.pg

Each GRAMMAR:COUNT becomes one numbered question with COUNT lettered parts.
Run `dune build` in generator/ first; this drives the built rhema.
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
from rhema_stats import RHEMA, MATH_BLOCK, expressions_of, parse_questions, size_of  # noqa: E402

PRODUCTION = re.compile(r"production: L -> .*\[line (\d+)\]")
VARIABLE = re.compile(r"(?<![A-Za-z\\])[A-Za-z](?![A-Za-z])")


class Question:
    def __init__(self, prompt: str, answer: str, law: int | None):
        self.prompt = prompt
        self.answer = answer
        self.law = law
        self.expressions = expressions_of(prompt)
        self.size = max((size_of(e) for e in self.expressions), default=0)
        self.skeleton = tuple(skeleton(e) for e in self.expressions)
        # The wording, so one numbered question keeps to one instruction.
        self.opening = " ".join(prompt.split()[:2])


def skeleton(expression: str) -> str:
    """The expression with variables renamed in order of first appearance,
    so p \\to (q \\lor r) and r \\to (p \\lor q) count as the same shape."""
    names: dict[str, str] = {}

    def rename(match: re.Match[str]) -> str:
        letter = match.group(0)
        names.setdefault(letter, f"v{len(names) + 1}")
        return names[letter]

    return VARIABLE.sub(rename, expression)


def generate_pool(grammar: Path, count: int, seed: int, settings: list[str]) -> list[Question]:
    if not RHEMA.exists():
        sys.exit(f"{RHEMA} not found; run `dune build` in generator/ first")
    with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as handle:
        ast_path = Path(handle.name)
    command = [str(RHEMA), "run", "--count", str(count), "--seed", str(seed), "--ast-out", str(ast_path)]
    for setting in settings:
        command += ["--set", setting]
    command.append(str(grammar))
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(result.stderr.strip() or f"rhema exited with {result.returncode}")
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
    return [Question(prompt, answer, law) for (prompt, answer), law in zip(questions, laws)]


def ramp(sizes: list[int], count: int) -> list[int]:
    """`count` target sizes running from the pool's easiest to its hardest."""
    distinct = sorted(set(sizes))
    return [distinct[min(len(distinct) - 1, index * len(distinct) // count)] for index in range(count)]


def answer_pattern(answers: list[str], count: int, rng: random.Random) -> list[str]:
    """A balanced sequence of answers with no run longer than two."""
    values = sorted(set(answers))
    if len(values) != 2:
        return [rng.choice(values) for _ in range(count)]
    for _ in range(1000):
        pattern = [values[index % 2] for index in range(count)]
        rng.shuffle(pattern)
        if all(not (pattern[i] == pattern[i + 1] == pattern[i + 2]) for i in range(count - 2)):
            return pattern
    return [values[index % 2] for index in range(count)]


def choose(pool: list[Question], count: int, rng: random.Random) -> list[Question]:
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
        def fits(q: Question, exact_size: bool, fresh_law: bool, same_opening: bool) -> bool:
            return (
                q.answer == answer
                and q.skeleton not in seen_shapes
                and (not exact_size or q.size == size)
                and (not fresh_law or q.law is None or q.law not in seen_laws)
                and (not same_opening or opening is None or q.opening == opening)
            )
        pick = None
        for exact_size, fresh_law, same_opening in (
            (True, True, True), (True, False, True), (False, True, True), (False, False, True),
            (True, True, False), (True, False, False), (False, True, False), (False, False, False),
        ):
            pick = next((q for q in order if fits(q, exact_size, fresh_law, same_opening)), None)
            if pick:
                break
        if pick is None:
            sys.exit("the pool is too small to fill the set; raise --pool")
        chosen.append(pick)
        opening = pick.opening
        seen_shapes.add(pick.skeleton)
        if pick.law is not None:
            seen_laws.add(pick.law)
            if seen_laws >= all_laws:
                seen_laws.clear()
    chosen.sort(key=lambda q: q.size)
    return chosen


def pg_document(groups: list[list[Question]]) -> str:
    parts = ["DOCUMENT();", 'loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");',
             'Context("Numeric");', "", "BEGIN_PGML"]
    for number, group in enumerate(groups, 1):
        parts.append(f"**Question {number}.**\n")
        for letter, question in zip("abcdefghij", group):
            answer = {"true": "1", "false": "0"}.get(question.answer, question.answer)
            parts.append(f"{letter}) {question.prompt} [_____]{{{answer}}}\n")
    parts += ["END_PGML", "ENDDOCUMENT();"]
    return "\n".join(parts)


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
    for index, group in enumerate(args.groups):
        grammar, _, count_text = group.rpartition(":")
        if not grammar:
            sys.exit(f"write GRAMMAR:COUNT, not {group!r}")
        count = int(count_text)
        pool = generate_pool(Path(grammar), args.pool or 40 * count, args.seed + index, args.settings)
        groups.append(choose(pool, count, rng))

    if args.pg:
        print(pg_document(groups))
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
