"""Measure how the questions of one grammar are distributed.

The OCaml tests say whether every question is correct. This says whether a
*set* of them looks like a set a person would hand out: how many are
distinct, how the answers split, how long the expressions are, how often the
rarer connectives appear, and how the wording varies. Numbers, not
impressions, so a change to a grammar can be judged before and after.

    python3 tools/ag_stats.py generator/ag/boolean.ag
    python3 tools/ag_stats.py generator/ag/boolean_equiv.ag --count 5000
    python3 tools/ag_stats.py generator/ag/boolean.ag --set extras=0 --samples 8

Run `dune build` in generator/ first; this drives the built agrun.exe.
"""

from __future__ import annotations

import argparse
import collections
import re
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
AGRUN = PROJECT / "generator" / "_build" / "default" / "ag" / "agrun.exe"

QUESTION_START = re.compile(r"^\s*(\d+)\. (.*)$")
ANSWER_LINE = re.compile(r"^\s+answer: (.*)$")
MATH_BLOCK = re.compile(r"\[`(.*?)`\]")
ASSIGNMENT = re.compile(r"^[A-Za-z] = \\mathsf\{[TF]\}(,\\; [A-Za-z] = \\mathsf\{[TF]\})*$")
BINARY = re.compile(r"\\(land|lor|to|leftrightarrow|oplus)\b")
EXTRA = re.compile(r"\\(to|leftrightarrow|oplus)\b")
COMPOUND_NEGATION = re.compile(r"\\neg \(")


def run_agrun(grammar: Path, count: int, seed: int, settings: list[str]) -> str:
    if not AGRUN.exists():
        sys.exit(f"{AGRUN} not found; run `dune build` in generator/ first")
    command = [str(AGRUN), "--count", str(count), "--seed", str(seed)]
    for setting in settings:
        command += ["--set", setting]
    command.append(str(grammar))
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(result.stderr.strip() or f"agrun exited with {result.returncode}")
    return result.stdout


def parse_questions(output: str) -> list[tuple[str, str]]:
    """Split agrun's numbered listing into (prompt, answer) pairs."""
    questions: list[tuple[str, str]] = []
    prompt_lines: list[str] = []
    for line in output.splitlines():
        started = QUESTION_START.match(line)
        answered = ANSWER_LINE.match(line)
        if started:
            prompt_lines = [started.group(2)]
        elif answered:
            questions.append(("\n".join(prompt_lines), answered.group(1).strip()))
            prompt_lines = []
        elif prompt_lines is not None:
            prompt_lines.append(line)
    return questions


def expressions_of(prompt: str) -> list[str]:
    """The math blocks that are expressions rather than truth assignments."""
    blocks = MATH_BLOCK.findall(prompt)
    expressions = [block for block in blocks if not ASSIGNMENT.match(block)]
    # An equivalence written as one block: split it into its two sides.
    split: list[str] = []
    for expression in expressions:
        split.extend(part.strip() for part in expression.split(r" \equiv "))
    return split


def size_of(expression: str) -> int:
    """Connectives as a course counts them: binary ones plus negated compounds."""
    return len(BINARY.findall(expression)) + len(COMPOUND_NEGATION.findall(expression))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("grammar", type=Path)
    parser.add_argument("--count", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--set", dest="settings", action="append", default=[],
                        metavar="NAME=VALUE", help="override an inherited attribute")
    parser.add_argument("--samples", type=int, default=5, help="questions to print")
    args = parser.parse_args()

    questions = parse_questions(run_agrun(args.grammar, args.count, args.seed, args.settings))
    if not questions:
        sys.exit("no questions were parsed from agrun's output")

    total = len(questions)
    distinct_prompts = len({prompt for prompt, _ in questions})
    distinct_expressions = len({tuple(expressions_of(prompt)) for prompt, _ in questions})
    answers = collections.Counter(answer for _, answer in questions)
    sizes = collections.Counter()
    extras = collections.Counter()
    openings = collections.Counter()
    for prompt, _ in questions:
        for expression in expressions_of(prompt):
            sizes[size_of(expression)] += 1
            extras[len(EXTRA.findall(expression))] += 1
        openings[" ".join(prompt.split()[:2])] += 1

    print(f"grammar            : {args.grammar}")
    print(f"questions          : {total} (seed {args.seed}"
          + (", " + ", ".join(args.settings) if args.settings else "") + ")")
    print(f"distinct prompts   : {distinct_prompts} ({100 * distinct_prompts / total:.1f}%)")
    print(f"distinct expressions: {distinct_expressions} ({100 * distinct_expressions / total:.1f}%)")
    print("answers            : "
          + ", ".join(f"{answer} {count} ({100 * count / total:.1f}%)"
                      for answer, count in sorted(answers.items())))
    print("connectives        : "
          + ", ".join(f"{size}: {count}" for size, count in sorted(sizes.items())))
    print("extras per expr    : "
          + ", ".join(f"{n}: {count}" for n, count in sorted(extras.items())))
    print("wording            : "
          + ", ".join(f"'{opening}' {count}" for opening, count in openings.most_common()))
    if args.samples:
        print()
        for prompt, answer in questions[: args.samples]:
            print(prompt.replace("\n", "\n    "))
            print(f"    -> {answer}")
            print()


if __name__ == "__main__":
    main()
