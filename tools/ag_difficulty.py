#!/usr/bin/env python3
"""Difficulty control for a grammar whose difficulty is a budget.

A grammar such as boolean.ag spends a difficulty budget exactly: each
production pays its price and the rest goes to its operands. The caller then
chooses the difficulty with `agrun --set cost=N`. This tool answers the
questions that come before and after that choice:

    report   what questions each budget buys: variety, answer balance, size
    levels   suggest an easy, medium and hard budget for the grammar
    set      build a set of questions whose mean budget is a chosen value

    python3 tools/ag_difficulty.py report generator/ag/boolean.ag
    python3 tools/ag_difficulty.py report generator/ag/boolean.ag --at 6,10,14
    python3 tools/ag_difficulty.py levels generator/ag/boolean.ag
    python3 tools/ag_difficulty.py set generator/ag/boolean.ag --mean 10 --spread 2 --count 10
    python3 tools/ag_difficulty.py set generator/ag/boolean.ag --targets 6,8,10,12 --pg-dir out/
    python3 tools/ag_difficulty.py set generator/ag/vector.ag --mean 2.5 --allowed 1,2,3,4

`--budget NAME` names the inherited attribute that is the budget (default
`cost`); a length budget such as `len` works the same way. The `set` command
is the expectation method: the set's mean budget is the standard, and each
question is generated at its own exact budget, so the mean is met exactly
rather than approximately. Nothing here depends on the question type.

Run `dune build` in generator/ first; this drives the built agrun.exe.
"""

from __future__ import annotations

import argparse
import collections
import random
import re
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
AGRUN = PROJECT / "generator" / "_build" / "default" / "ag" / "agrun.exe"

QUESTION_START = re.compile(r"^\s*\d+\.\s", re.M)
ANSWER_LINE = re.compile(r"^\s*answer:\s*(.*)$", re.M)
DERIVATION_START = re.compile(r"^Question \d+", re.M)
PRODUCTION_LINE = re.compile(r"^( *)production:", re.M)
EXPRESSION = re.compile(r"\[`(.*?)`\]", re.S)


# ---------------------------------------------------------------------------
# Running the generator
# ---------------------------------------------------------------------------

def budget_default(grammar: Path, budget: str) -> int:
    """The initial value the grammar declares for its budget attribute."""
    declaration = re.compile(rf"^\s*attribute\s+{re.escape(budget)}\s*=\s*(\d+)", re.M)
    found = declaration.search(grammar.read_text())
    if found is None:
        sys.exit(f"{grammar} declares no inherited attribute named '{budget}'; "
                 "name the budget with --budget")
    return int(found.group(1))


class NoQuestion(Exception):
    """agrun could not generate at this budget (a grammar of fixed forms has
    no form at that price, or the budget is below the grammar's least)."""


def run_agrun(grammar: Path, count: int, seed: int, settings: list[str],
              as_pg: bool = False) -> tuple[str, str]:
    """Run agrun; return its question listing and its derivation listing."""
    if not AGRUN.exists():
        sys.exit(f"{AGRUN} not found; run `dune build` in generator/ first")
    with tempfile.TemporaryDirectory() as directory:
        derivations = Path(directory) / "derivations.txt"
        command = [str(AGRUN), "--count", str(count), "--seed", str(seed),
                   "--ast-out", str(derivations)]
        if as_pg:
            command.append("--pg")
        for setting in settings:
            command += ["--set", setting]
        command.append(str(grammar))
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            message = result.stderr.strip() or f"agrun exited with {result.returncode}"
            if "no rule for" in message or "could not generate" in message:
                raise NoQuestion(message)
            sys.exit(message)
        return result.stdout, derivations.read_text()


def parse_questions(listing: str) -> list[tuple[str, str]]:
    """(prompt, answer) pairs from agrun's readable listing."""
    questions = []
    for block in QUESTION_START.split(listing)[1:]:
        answer = ANSWER_LINE.search(block)
        if answer is None:
            continue
        prompt = block[: answer.start()].strip()
        questions.append((prompt, answer.group(1).strip()))
    return questions


def parse_shapes(derivations: str) -> list[tuple[int, int]]:
    """(node count, depth) of each question's derivation tree."""
    shapes = []
    for block in DERIVATION_START.split(derivations)[1:]:
        indents = [len(indent) for indent in PRODUCTION_LINE.findall(block)]
        if not indents:
            continue
        base = min(indents)
        shapes.append((len(indents), max((i - base) // 2 + 1 for i in indents)))
    return shapes


def expression_length(prompt: str) -> int:
    """Characters of the first displayed expression, or of the whole prompt."""
    found = EXPRESSION.search(prompt)
    return len(found.group(1)) if found else len(prompt)


# ---------------------------------------------------------------------------
# Measuring one budget
# ---------------------------------------------------------------------------

class Level:
    """What a sample of questions at one budget looks like."""

    def __init__(self, budget: int, questions: list[tuple[str, str]],
                 shapes: list[tuple[int, int]], seconds: float):
        prompts = [prompt for prompt, _ in questions]
        answers = collections.Counter(answer for _, answer in questions)
        self.budget = budget
        self.count = len(questions)
        self.seconds = seconds
        self.distinct = len(set(prompts)) / len(prompts)
        self.top_answer, top_count = answers.most_common(1)[0]
        self.top_share = top_count / len(questions)
        self.length = statistics.mean(expression_length(p) for p in prompts)
        nodes = [n for n, _ in shapes] or [0]
        depths = [d for _, d in shapes] or [0]
        self.nodes = (statistics.mean(nodes), min(nodes), max(nodes))
        self.depth = (statistics.mean(depths), min(depths), max(depths))

    def row(self) -> str:
        return (f"{self.budget:>6} | {self.distinct:7.0%} | "
                f"{self.top_share:4.0%} {self.top_answer[:10]:<10} | {self.length:6.1f} | "
                f"{self.nodes[0]:5.1f} {self.nodes[1]:>2}-{self.nodes[2]:<2} | "
                f"{self.depth[0]:4.1f} {self.depth[1]:>2}-{self.depth[2]:<2} | "
                f"{self.seconds:4.1f}s")

    @staticmethod
    def header() -> str:
        return ("budget | distinct | top answer      | length | nodes mean range | "
                "depth mean range | time\n"
                "-------+----------+-----------------+--------+------------------+"
                "------------------+------")


def measure(grammar: Path, budget: str, value: int, count: int, seed: int) -> Level | None:
    """The sample at one budget, or None when the grammar has nothing at it."""
    started = time.time()
    try:
        listing, derivations = run_agrun(grammar, count, seed, [f"{budget}={value}"])
    except NoQuestion:
        return None
    questions = parse_questions(listing)
    if not questions:
        sys.exit(f"no questions were parsed from agrun's output at {budget}={value}")
    return Level(value, questions, parse_shapes(derivations), time.time() - started)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def parse_list(text: str) -> list[int]:
    return [int(item) for item in text.split(",") if item.strip()]


def command_report(args: argparse.Namespace) -> None:
    default = budget_default(args.grammar, args.budget)
    budgets = parse_list(args.at) if args.at else list(range(2, 2 * default + 1, 2))
    print(f"{args.grammar.name}: budget '{args.budget}', default {default}, "
          f"{args.count} questions per budget, seed {args.seed}")
    print(Level.header())
    for value in budgets:
        level = measure(args.grammar, args.budget, value, args.count, args.seed)
        print(level.row() if level else f"{value:>6} | no question at this budget")


def command_levels(args: argparse.Namespace) -> None:
    """Easy is the least budget with enough variety for a set; medium is the
    grammar's default; hard is as far above medium as easy is below it."""
    default = budget_default(args.grammar, args.budget)
    levels = [measure(args.grammar, args.budget, value, args.count, args.seed)
              for value in range(0, default + 1)]
    levels = [level for level in levels if level is not None]
    easy = next((level.budget for level in levels if level.distinct >= args.min_distinct),
                default)
    hard = default + (default - easy)
    print(f"{args.grammar.name}: budget '{args.budget}'")
    print(f"  easy   {easy:>3}   least budget with at least {args.min_distinct:.0%} "
          f"distinct questions in {args.count}")
    print(f"  medium {default:>3}   the grammar's default")
    print(f"  hard   {hard:>3}   as far above medium as easy is below it")
    print()
    print(Level.header())
    for value in (easy, default, hard):
        level = measure(args.grammar, args.budget, value, args.count, args.seed)
        print(level.row() if level else f"{value:>6} | no question at this budget")


def draw_targets(mean: float, spread: float, count: int, low: int,
                 rng: random.Random, allowed: list[int] | None = None) -> list[int]:
    """Whole-number budgets around `mean`, adjusted so that their mean is as
    close to `mean` as the allowed values permit (exact when every whole
    number is allowed), and none below `low`. With `allowed`, each budget is
    one of those values: a grammar of fixed forms has nothing between them."""
    values = sorted(set(allowed)) if allowed else None

    def nearest(x: float) -> int:
        if values is None:
            return max(low, round(x))
        return min(values, key=lambda value: (abs(value - x), value))

    def step(value: int, up: bool) -> int | None:
        if values is None:
            return value + 1 if up else (value - 1 if value > low else None)
        index = values.index(value) + (1 if up else -1)
        return values[index] if 0 <= index < len(values) else None

    targets = [nearest(rng.gauss(mean, spread)) for _ in range(count)]
    wanted = round(mean * count)
    for _ in range(100 * count):
        if sum(targets) == wanted:
            break
        index = rng.randrange(count)
        moved = step(targets[index], up=sum(targets) < wanted)
        if moved is not None and abs(sum(targets) - targets[index] + moved - wanted) <= abs(sum(targets) - wanted):
            targets[index] = moved
    return targets


def command_set(args: argparse.Namespace) -> None:
    rng = random.Random(args.seed)
    if args.targets:
        targets = parse_list(args.targets)
    else:
        if args.mean is None:
            args.mean = budget_default(args.grammar, args.budget)
        allowed = parse_list(args.allowed) if args.allowed else None
        targets = draw_targets(args.mean, args.spread, args.count, args.low, rng, allowed)
    if args.pg_dir:
        args.pg_dir.mkdir(parents=True, exist_ok=True)
    print(f"{args.grammar.name}: {len(targets)} questions, budget '{args.budget}' "
          f"mean {statistics.mean(targets):.2f}, sd {statistics.pstdev(targets):.2f}, "
          f"targets {targets}")
    for index, target in enumerate(targets, start=1):
        seed = args.seed * 1000 + index
        settings = [f"{args.budget}={target}"]
        try:
            listing, _ = run_agrun(args.grammar, 1, seed, settings)
        except NoQuestion as reason:
            sys.exit(f"no question at {args.budget}={target}: {reason}\n"
                     "Run `report` to see the budgets this grammar accepts and pass them "
                     "with --allowed, e.g. --allowed 1,2,3,4.")
        questions = parse_questions(listing)
        if not questions:
            sys.exit(f"no question was parsed at {args.budget}={target}")
        prompt, answer = questions[0]
        print()
        print(f"Question {index}  ({args.budget} {target}, seed {seed})")
        print(prompt)
        print(f"    answer: {answer}")
        if args.pg_dir:
            document, _ = run_agrun(args.grammar, 1, seed, settings, as_pg=True)
            (args.pg_dir / f"question{index:02d}.pg").write_text(document)
    if args.pg_dir:
        print(f"\nPG files written to {args.pg_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    commands = parser.add_subparsers(dest="command", required=True)

    def common(sub: argparse.ArgumentParser) -> None:
        sub.add_argument("grammar", type=Path)
        sub.add_argument("--budget", default="cost",
                         help="the budget attribute (default cost)")
        sub.add_argument("--seed", type=int, default=7)

    report = commands.add_parser("report", help="what each budget buys")
    common(report)
    report.add_argument("--at", help="budgets to measure, e.g. 6,10,14 "
                        "(default: even values up to twice the default)")
    report.add_argument("--count", type=int, default=1000, help="questions per budget")
    report.set_defaults(run=command_report)

    levels = commands.add_parser("levels", help="suggest easy, medium and hard budgets")
    common(levels)
    levels.add_argument("--count", type=int, default=500, help="questions per budget")
    levels.add_argument("--min-distinct", type=float, default=0.5,
                        help="variety the easy level must reach (default 0.5)")
    levels.set_defaults(run=command_levels)

    build = commands.add_parser("set", help="a set whose mean budget is chosen")
    common(build)
    build.add_argument("--mean", type=float,
                       help="target mean budget (default: the grammar's default)")
    build.add_argument("--spread", type=float, default=2.0,
                       help="standard deviation of the budgets drawn")
    build.add_argument("--count", type=int, default=10, help="questions in the set")
    build.add_argument("--low", type=int, default=0, help="smallest budget allowed")
    build.add_argument("--targets",
                       help="explicit budgets, e.g. 6,8,10,12, instead of drawing them")
    build.add_argument("--allowed",
                       help="the only budgets to draw from, e.g. 1,2,3,4 for a grammar of fixed forms")
    build.add_argument("--pg-dir", type=Path, help="write one .pg file per question here")
    build.set_defaults(run=command_set)

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
