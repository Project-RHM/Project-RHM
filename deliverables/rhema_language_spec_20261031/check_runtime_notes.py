"""Verify the implementation-specific caveats documented in the manual."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
TARGET = HERE / "probes"
TARGET.mkdir(exist_ok=True)
RHEMA = ROOT / "generator/_build/install/default/bin/rhema"


def question(body, prelude="", rhs='"marker"', answer="Q.value"):
    return (prelude + "\nsynth value on Q\nstart Q\nQ -> " + rhs + " {\n" + body
            + '\n}\nprompt "Answer the question."\nanswer ' + answer + "\n")


cases = [
    ("reserved_left", "check", question("value = 1", "let left = 3"), False, "unexpected left"),
    ("no_truth_literal", "check", question("value = true"), False, "unknown name 'true'"),
    ("bare_answer_global", "check", question("value = total", "let total = 5", answer="total"), False, "ambiguous"),
    ("random_needs_literal", "check", question("value = n", "let maximum = 5\nrandom n = integer_between(1, maximum)"), False, "integer literals"),
    ("paren_node_not_text", "run", question("value = paren($1)"), False, "is a node"),
    ("str_truth_not_text", "run", question("value = str(1 = 1)"), False, "expected text"),
    ("unary_minus_precedence", "run", question("value = -2 ^ 2"), True, "answer: 4"),
    ("formula_equality_structural", "run", question("value = formula_add(x,x) = formula_multiply(formula_constant(2),x)", 'let x = formula_variable("x")'), True, "answer: false"),
    ("set_equality_structural", "run", question("value = set_union(a,set_empty()) = a", "let a = set_insert(set_empty(),1)"), True, "answer: false"),
    ("split_not_exact_by_itself", "run", question("value = cost", "attribute cost = 10 split"), True, "answer: 10"),
    ("scalar_arithmetic_not_complex", "run", question("value = complex(1,2) + complex(3,4)"), False, "expected a number"),
]
results = []
for name, action, source, expected_success, expected_text in cases:
    path = TARGET / (name + ".rhm")
    path.write_text(source)
    args = [str(RHEMA), action, str(path)]
    if action == "run":
        args += ["--count", "1", "--seed", "1"]
    result = subprocess.run(args, text=True, capture_output=True, timeout=15)
    text = result.stdout + result.stderr
    passed = (result.returncode == 0) == expected_success and expected_text in text
    if not passed:
        raise AssertionError((name, result.returncode, text))
    results.append({"case": name, "expected_success": expected_success,
                    "expected_message": expected_text, "actual": text, "passed": passed})
    print("PASS", name)
report_path = HERE / "verification.json"
report = json.loads(report_path.read_text())
report["runtime_caveat_probes"] = results
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
