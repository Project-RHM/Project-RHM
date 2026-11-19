"""Rehearse these demo specifications without changing application source/settings.

Run using the project's virtualenv. Only --output (default: this folder/output)
and disposable temporary directories are written. Live checks use the existing
Flask render/check endpoints, never an external WeBWorK course or gradebook.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent / "output")
    parser.add_argument("--app-url", default="http://127.0.0.1:5003")
    parser.add_argument("--offline", action="store_true", help="Skip live rendering/grading; record this explicitly.")
    args = parser.parse_args()
    project = args.project.resolve()
    sources = Path(__file__).resolve().parent
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    generator = project / "generator"
    runtime = generator / "_build/install/default/bin/rhema"
    stdlib = generator / "stdlib"
    sys.path.insert(0, str(project))
    from flask import Flask
    from teacher_builder import register_teacher_routes
    import requests

    def run(command):
        result = subprocess.run([str(x) for x in command], cwd=generator,
                                capture_output=True, text=True, timeout=45)
        if result.returncode:
            raise RuntimeError(result.stderr or result.stdout)
        return result.stdout

    report = {
        "status": "running",
        "time_utc": datetime.now(timezone.utc).isoformat(),
        "commit": run(["git", "rev-parse", "HEAD"]).strip(),
        "project": str(project), "student": "FYP2026",
        "scope": "Demo fixtures only; not a rerun of every project test.",
        "cases": [], "live": {"status": "skipped" if args.offline else "pending"},
    }
    # A failed rerun must not leave a previous successful report looking fresh.
    (output / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
    session = requests.Session()
    session.trust_env = False

    def endpoint(path, payload=None):
        url = args.app_url.rstrip("/") + path
        response = session.get(url, timeout=20) if payload is None else session.post(url, json=payload, timeout=30)
        data = response.json()
        if not response.ok or data.get("success") is False:
            raise RuntimeError(f"{path}: {response.status_code}: {data}")
        return data

    def grade_source(label, source, answers, wrong_answers=None):
        if args.offline:
            return
        rendered = endpoint("/api/webwork/render", {"pg_source": source})
        if not rendered.get("html"):
            raise AssertionError(f"{label}: empty renderer HTML")
        good = endpoint("/api/webwork/check", {"pg_source": source, "answers": answers})
        wrong = endpoint("/api/webwork/check", {"pg_source": source,
                         "answers": wrong_answers or {name: "0" for name in answers}})
        if good["score"] != 1 or wrong["score"] != 0:
            raise AssertionError(f"{label}: unexpected grading: {good}, {wrong}")
        report["live"].setdefault("graded", []).append({
            "case": label, "answers": answers, "correct": good, "wrong": wrong,
        })

    def cli_case(filename, label, *, count=1, question="main", cost=None, run_set=None):
        source = sources / filename
        check = run([runtime, "check", source, "-I", stdlib])
        identity = filename + ":" + question
        options = ["-I", stdlib, "--student", "FYP2026", "--assignment", identity]
        if run_set:
            options += ["--run", run_set]
        else:
            options += ["--count", count, "--question", question]
        if cost is not None:
            options += ["--set", f"cost={cost}"]
        pg = output / (label + ".pg")
        run([runtime, source, *options, "-o", pg,
             "--ast-out", output / (label + "_ast.txt"),
             "--visualization-out", output / (label + "_trees.html")])
        listing = run([runtime, "run", source, *options])
        (output / (label + ".txt")).write_text(listing, encoding="utf-8")
        repeated = run([runtime, source, *options, "-o", "-"])
        if pg.read_text() != repeated:
            raise AssertionError(f"{label}: deterministic replay failed")
        other_options = list(options)
        other_options[other_options.index("FYP2026")] = "FYP2027"
        other_student = run([runtime, source, *other_options, "-o", "-"])
        case = {"case": label, "source": filename, "check": check.strip(),
                "count": count, "question": question, "cost_override": cost,
                "assignment": identity, "listing": listing,
                "pg": pg.name, "replay_identical": True,
                "other_student_changed_this_sample": other_student != repeated}
        report["cases"].append(case)
        print(f"PASS {label}\n{listing}", flush=True)
        return pg.read_text()

    # Model the actual no-code route with a disposable project: personal presets
    # and the real generated-question/history folders are left alone.
    with tempfile.TemporaryDirectory(prefix="rhema-demo-teacher-") as temp:
        root = Path(temp)
        (root / "static").symlink_to(project / "static", target_is_directory=True)
        (root / "generator").mkdir()
        (root / "generator/stdlib").symlink_to(stdlib, target_is_directory=True)
        (root / "generator/_build").symlink_to(generator / "_build", target_is_directory=True)
        app = Flask(__name__)
        register_teacher_routes(app, root)
        client = app.test_client()
        payload = {"grammar": "sequence.rhm", "count": 1, "student_id": "FYP2026",
                   "configuration": {"values": {"root:a:cost": 1,
                       "root:r:first": [2, 2], "root:r:difference": [3, 3],
                       "root:r:index": [4, 4]}}}
        response = client.post("/teacher/generate", json=payload)
        teacher = response.get_json()
        if response.status_code != 200 or teacher["preview"][0]["answer"] != "11":
            raise AssertionError(teacher)
        again = client.post("/teacher/generate", json=payload).get_json()
        if teacher["pgml_code"] != again["pgml_code"]:
            raise AssertionError("teacher fixed-sequence replay failed")
        (output / "teacher_sequence_request.json").write_text(json.dumps(payload, indent=2) + "\n")
        (output / "teacher_sequence_generated.rhm").write_text(teacher["source"])
        (output / "teacher_sequence.pg").write_text(teacher["pgml_code"])
        (output / "teacher_sequence_trees.html").write_bytes(
            (root / "generator" / teacher["visualization_path"]).read_bytes())
        report["cases"].append({"case": "teacher_sequence", "answer": "11",
                                  "replay_identical": True, "preview": teacher["preview"]})
        teacher_source = teacher["pgml_code"]

    if not args.offline:
        status = endpoint("/api/webwork/status")
        if not status.get("available"):
            raise AssertionError(status)
        grade_source("teacher_sequence", teacher_source, {"AnSwEr0001": "11"})
    low = cli_case("demo_budget.rhm", "budget_4", count=2)
    high = cli_case("demo_budget.rhm", "budget_10", count=2, cost=10)
    # Independently calculate the visible arithmetic expression with a bounded
    # AST walk; never evaluate specification text as Python code.
    import ast
    import operator
    operations = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul}

    def numeric(node):
        if isinstance(node, ast.Expression):
            return numeric(node.body)
        if isinstance(node, ast.Constant) and type(node.value) is int:
            return node.value
        if isinstance(node, ast.BinOp) and type(node.op) in operations:
            return operations[type(node.op)](numeric(node.left), numeric(node.right))
        raise AssertionError("Unexpected expression in arithmetic fixture")

    for label, source in (("budget_4", low), ("budget_10", high)):
        case = next(c for c in report["cases"] if c["case"] == label)
        givens = re.findall(r"Evaluate \[`(.*?)`\]", case["listing"])
        listed = re.findall(r"answer:\s*(-?\d+)", case["listing"])
        expected = [numeric(ast.parse(s.replace(r"\cdot", "*"), mode="eval")) for s in givens]
        if expected != list(map(int, listed)) or len(expected) != 2:
            raise AssertionError(f"{label}: arithmetic correctness mismatch")
        case["independent_answers"] = expected
        grade_source(label, source, {f"AnSwEr{i:04d}": str(n) for i, n in enumerate(expected, 1)})
    gap = cli_case("demo_sequence_gap.rhm", "sequence_gap")
    gap_listing = report["cases"][-1]["listing"]
    # Check two displayed indices and their values, rather than copying the
    # engine's own answer and calling that an independent correctness test.
    pairs = re.findall(r"a_\{+(\d+)\}+\s*=\s*(-?\d+)", gap_listing)
    if len(pairs) != 2:
        raise AssertionError(f"Cannot inspect sequence givens: {gap_listing}")
    (i, ai), (j, aj) = [(int(i), int(a)) for i, a in pairs]
    from fractions import Fraction
    expected = Fraction(aj - ai, j - i)
    answer = re.search(r"answer:\s*([^\n]+)", gap_listing).group(1).strip()
    if Fraction(answer) != expected:
        raise AssertionError(f"sequence answer {answer} != independently computed {expected}")
    report["cases"][-1]["independent_answer"] = str(expected)
    grade_source("sequence_gap", gap, {"AnSwEr0001": str(expected)})
    polynomial = cli_case("demo_polynomial.rhm", "polynomial_main")
    # Fixed seed/assignment witnesses: (x+6)^2(x-5), evaluated at -3, and
    # (2x+3)(x+5), evaluated at 1. These are checked fixtures, not promises
    # for arbitrary filenames, seeds, specification edits or future engines.
    if "Polynomial(x^3+7*x^2-24*x-180); -72" not in report["cases"][-1]["listing"]:
        raise AssertionError("Polynomial fixture changed; review the new question before rehearsing")
    grade_source("polynomial_main", polynomial,
                 {"AnSwEr0001": "x^3+7*x^2-24*x-180", "AnSwEr0002": "-72"})
    if not args.offline:
        partial = endpoint("/api/webwork/check", {"pg_source": polynomial,
                           "answers": {"AnSwEr0001": "x^3+7*x^2-24*x-180", "AnSwEr0002": "0"}})
        if partial["score"] != .5:
            raise AssertionError(partial)
        report["live"]["polynomial_partial_credit"] = partial
    value = cli_case("demo_polynomial.rhm", "polynomial_value", question="value")
    grade_source("polynomial_value", value, {"AnSwEr0001": "30"})
    assignment = cli_case("demo_assignment.rhm", "assignment", run_set="defense")
    grade_source("assignment", assignment,
                 {"AnSwEr0001": "-31", "AnSwEr0002": "-95", "AnSwEr0003": "1",
                  "AnSwEr0004": "1", "AnSwEr0005": "0", "AnSwEr0006": "{-4,0}"},
                 {"AnSwEr0001": "0", "AnSwEr0002": "0", "AnSwEr0003": "0",
                  "AnSwEr0004": "0", "AnSwEr0005": "1", "AnSwEr0006": "{999}"})

    if not args.offline:
        report["live"]["status"] = "passed"
        report["live"]["app_url"] = args.app_url
        report["live"]["limits"] = "Local Docker WeBWorK rendering/grading; no course gradebook integration."
    report["source_sha256"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in sources.glob("*.rhm")}
    report["status"] = "passed"
    (output / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"Verification saved to {output / 'verification.json'}", flush=True)


if __name__ == "__main__":
    main()
