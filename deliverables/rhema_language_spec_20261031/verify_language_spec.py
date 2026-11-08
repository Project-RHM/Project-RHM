"""Extract and verify the complete examples in the new language manual."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
MANUAL = ROOT / "RHEMA_LANGUAGE_SPEC.zh.md"
OUT = Path(__file__).resolve().parent
EXAMPLES = OUT / "examples"
EXAMPLES.mkdir(parents=True, exist_ok=True)
RUNTIME = ROOT / "generator/_build/install/default/bin/rhema"
STDLIB = ROOT / "generator/stdlib"


def invoke(arguments):
    result = subprocess.run([str(x) for x in arguments], cwd=ROOT / "generator",
                            text=True, capture_output=True, timeout=60)
    return result


def require_success(result):
    if result.returncode:
        raise AssertionError(result.stderr or result.stdout)
    return result.stdout


def main():
    manual = MANUAL.read_text()
    source = (ROOT / "generator/rhema/lib/rhema_check.ml").read_text()
    block = source.split("let expression_builtins =", 1)[1].split("let integer_literal", 1)[0]
    builtins = dict((name, int(arity)) for name, arity in re.findall(r'\("([a-z_0-9]+)",\s*(\d+)\)', block))
    signatures = re.findall(r'^\| `([a-z_0-9]+)\(([^`]*?)\)` \|', manual, re.M)
    rows = {name: 0 if not args.strip() else len(args.split(",")) for name, args in signatures}
    missing = set(builtins) - set(rows)
    wrong = {n: (arity, rows.get(n)) for n, arity in builtins.items() if n in rows and arity != rows[n]}
    if missing or wrong:
        raise AssertionError({"missing_builtin_rows": sorted(missing), "wrong_arities": wrong})
    keyword_source = (ROOT / "generator/rhema/lib/rhema_lexer.mll").read_text().split("let keywords =", 1)[1].split("let identifier", 1)[0]
    keywords = re.findall(r'"([a-z]+)",', keyword_source)
    if any(f"| `{k}` |" not in manual for k in keywords):
        raise AssertionError("Keyword table is incomplete")
    snippets = re.findall(r'<!-- rhema-example: ([a-z_0-9]+\.rhm) -->\s*```rhm\n(.*?)\n```', manual, re.S)
    for name, content in snippets:
        (EXAMPLES / name).write_text(content + "\n")
    report = {
        "status": "running", "time_utc": datetime.now(timezone.utc).isoformat(),
        "commit": require_success(invoke(["git", "rev-parse", "HEAD"])).strip(),
        "builtin_count": len(builtins), "keyword_count": len(keywords),
        "cases": [], "scope": "Complete manual examples and signature coverage; not all project tests.",
    }
    (OUT / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
    for name, _ in snippets:
        path = EXAMPLES / name
        check = require_success(invoke([RUNTIME, "check", path, "-I", STDLIB]))
        listing = require_success(invoke([RUNTIME, "list", path, "-I", STDLIB]))
        questions = re.findall(r'^  ([A-Za-z_][A-Za-z_0-9]*)\s+start\s', listing, re.M)
        # The CLI prints a column for start symbol without the word "start".
        if not questions:
            section = listing.split("questions:\n", 1)[1].split("\n\n", 1)[0] if "questions:\n" in listing else ""
            questions = re.findall(r'^  ([A-Za-z_][A-Za-z_0-9]*)\s', section, re.M)
        sets = ["practice"] if name == "assignment.rhm" else []
        case = {"file": name, "check": check.strip(), "listing": listing, "runs": []}
        for question in questions:
            for seed in (1, 17, 20261031):
                args = ["-I", STDLIB, "--question", question, "--count", "5", "--seed", seed]
                text = require_success(invoke([RUNTIME, "run", path, *args]))
                pg = require_success(invoke([RUNTIME, path, *args, "-o", "-"]))
                replay = require_success(invoke([RUNTIME, path, *args, "-o", "-"]))
                if pg != replay or "BEGIN_PGML" not in pg:
                    raise AssertionError(f"{name}:{question}:{seed}: replay/PG failed")
                case["runs"].append({"question": question, "seed": seed, "count": 5,
                                     "pg_sha256": hashlib.sha256(pg.encode()).hexdigest(), "replay_identical": True})
                if seed == 1:
                    (OUT / (Path(name).stem + "_" + question + ".pg")).write_text(pg)
                    (OUT / (Path(name).stem + "_" + question + ".txt")).write_text(text)
        for set_name in sets:
            for seed in (1, 17, 20261031):
                args = ["-I", STDLIB, "--run", set_name, "--seed", seed]
                text = require_success(invoke([RUNTIME, "run", path, *args]))
                pg = require_success(invoke([RUNTIME, path, *args, "-o", "-"]))
                if seed == 1:
                    (OUT / "assignment_practice.pg").write_text(pg)
                    (OUT / "assignment_practice.txt").write_text(text)
                case["runs"].append({"set": set_name, "seed": seed, "listing": text})
        if not case["runs"]:
            raise AssertionError(f"{name}: did not find any question/set to run; inspect CLI list format")
        report["cases"].append(case)
        print(f"PASS {name}: {len(case['runs'])} scenarios", flush=True)
    report["status"] = "passed"
    report["example_count"] = len(snippets)
    report["generation_scenario_count"] = sum(len(c["runs"]) for c in report["cases"])
    (OUT / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"PASS {len(builtins)} signatures; {len(keywords)} keywords; {len(snippets)} complete examples", flush=True)


if __name__ == "__main__":
    main()
