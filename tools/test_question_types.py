#!/usr/bin/env python3
"""
End-to-end question generation tester.

This script intentionally treats the existing generator as a black box:
it rewrites only local generated config files, runs dune/unparser, validates
the generated PGML, and restores the original config files before exiting.

Online WeBWorK validation is optional. Set WEBWORK_VALIDATE_URL to a custom
endpoint that accepts JSON:
  { "case": "...", "seed": "...", "filename": "...", "pgml": "..." }
and returns JSON containing at least:
  { "ok": true/false, "expected": "...", "actual": "...", "message": "..." }
Optionally set WEBWORK_API_TOKEN for a Bearer token.
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
import os
import re
import shutil
import subprocess
import sys
import time
import traceback
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GENERATOR_DIR = ROOT / "generator"
CONFIG_JSON = ROOT / "config_setting" / "config.json"
CONFIG_TEMPLATE = ROOT / "config_setting" / "config.ml.template"
GENERATOR_CONFIG = GENERATOR_DIR / "config.ml"
REPORT_DIR = ROOT / "test_reports"


DEFAULT_CONFIG: dict[str, Any] = {
    "question_random_amounts": False,
    "shuffle_questions_for_0_type": False,
    "allow_float": False,
    "min_question_num": 4,
    "max_question_num": 4,
    "problem_type": 1,
    "max_expr_depth": 2,
    "min_set_expr_depth": 1,
    "max_set_expr_depth": 2,
    "min_set_element": -10,
    "max_set_element": 10,
    "max_set_def_num": 3,
    "min_set_prob_num": 2,
    "max_set_prob_num": 3,
    "vector_dimension": 3,
    "min_vector_element": -10,
    "max_vector_element": 10,
    "max_vector_def_num": 3,
    "min_vector_prob_num": 4,
    "max_vector_prob_num": 6,
    "min_fun_expr_depth": 2,
    "max_fun_expr_depth": 3,
    "calculus_question_mode": 0,
    "derivative_weight": 1,
    "integral_weight": 1,
    "min_derivative_prob_num": 2,
    "max_derivative_prob_num": 4,
    "integral_expr_depth": 2,
    "boolean_question_mode": 0,
    "boolean_eval_weight": 1,
    "boolean_equiv_weight": 1,
    "min_bool_expr_depth": 2,
    "max_bool_expr_depth": 3,
    "min_bool_var_num": 2,
    "max_bool_var_num": 3,
    "complex_question_mode": 0,
    "complex_arithmetic_weight": 2,
    "complex_conjugate_weight": 1,
    "complex_modulus_weight": 1,
    "complex_power_i_weight": 1,
    "min_complex_component": -8,
    "max_complex_component": 8,
    "min_complex_power": 0,
    "max_complex_power": 12,
    "question_type_amounts": [1, 1, 1, 2, 2, 4],
    "set_variables": ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"],
    "vector_variables": ["u", "v", "w", "x", "y", "z", "a", "b", "c", "d"],
    "boolean_variables": ["A", "B", "C", "D", "E"],
    "difficulty_level": "medium",
}


@dataclass
class TestCase:
    name: str
    description: str
    overrides: dict[str, Any]
    expected_kinds: set[str]
    forbidden_kinds: set[str] = field(default_factory=set)


@dataclass
class Bug:
    case: str
    seed: str
    category: str
    input_data: str
    output: str
    expected: str
    actual: str
    description: str


@dataclass
class RunResult:
    case: str
    seed: str
    status: str
    pgml_path: str = ""
    ast_path: str = ""
    detected_kinds: set[str] = field(default_factory=set)
    bugs: list[Bug] = field(default_factory=list)
    webwork_status: str = "SKIPPED"
    webwork_message: str = "WEBWORK_VALIDATE_URL is not set"


def load_base_config() -> dict[str, Any]:
    if CONFIG_JSON.exists():
        try:
            with CONFIG_JSON.open("r", encoding="utf-8") as f:
                loaded = json.load(f)
            cfg = DEFAULT_CONFIG.copy()
            cfg.update(loaded)
            return cfg
        except Exception:
            return DEFAULT_CONFIG.copy()
    return DEFAULT_CONFIG.copy()


def format_ocaml_value(value: Any) -> str:
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, list):
        if all(isinstance(item, str) for item in value):
            return "[" + "; ".join(json.dumps(item) for item in value) + "]"
        return "[" + "; ".join(str(item).lower() if isinstance(item, bool) else str(item) for item in value) + "]"
    if isinstance(value, str):
        return json.dumps(value)
    return str(value)


def write_config_files(config: dict[str, Any]) -> None:
    CONFIG_JSON.parent.mkdir(parents=True, exist_ok=True)
    with CONFIG_JSON.open("w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)

    template = CONFIG_TEMPLATE.read_text(encoding="utf-8")
    ml = template
    for key, value in config.items():
        ml = ml.replace("{{ " + key + " }}", format_ocaml_value(value))
    unreplaced = sorted(set(re.findall(r"\{\{\s*([A-Za-z0-9_]+)\s*\}\}", ml)))
    if unreplaced:
        raise RuntimeError("Unreplaced config template variables: " + ", ".join(unreplaced))
    GENERATOR_CONFIG.write_text(ml, encoding="utf-8")


def run_cmd(cmd: list[str], cwd: Path, timeout: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        text=True,
        capture_output=True,
        timeout=timeout,
    )


def extract_saved_paths(output: str) -> tuple[str, str]:
    ast_match = re.search(r"AST saved to:\s*(generated_asts/.*?\.txt)", output)
    pgml_match = re.search(r"PGML code saved to:\s*(generated_questions/.*?\.pg)", output)
    ast_path = str(GENERATOR_DIR / ast_match.group(1)) if ast_match else ""
    pgml_path = str(GENERATOR_DIR / pgml_match.group(1)) if pgml_match else ""
    return ast_path, pgml_path


def answer_payload(block: str) -> str | None:
    match = re.search(r"\[_____\]\{([^{}]*)\}", block)
    if not match:
        return None
    payload = match.group(1).strip()
    if payload.startswith("answer=>"):
        payload = payload[len("answer=>") :]
        payload = payload.split(",width=>", 1)[0].strip()
    return payload


def split_blocks(pgml: str) -> list[str]:
    return [part.strip() for part in pgml.split("---") if part.strip()]


def parse_definitions(pgml: str) -> dict[str, str]:
    definitions: dict[str, str] = {}
    for match in re.finditer(r"\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?);", pgml):
        definitions[match.group(1)] = match.group(2).strip()
    return definitions


def detect_kinds(pgml: str) -> set[str]:
    kinds: set[str] = set()
    if "What is the value of" in pgml or re.search(r"\[`[^`]+`\]\s+is equal to", pgml):
        kinds.add("arithmetic")
    if "Given the sets:" in pgml:
        kinds.add("set")
    if "Suppose the vectors:" in pgml:
        kinds.add("vector")
    if "Given this function:" in pgml:
        kinds.add("calculus")
    if "f'(x)" in pgml or "f''(x)" in pgml:
        kinds.add("calculus_derivative")
    if "Find an antiderivative F(x) with C = 0:" in pgml:
        kinds.add("calculus_integral")
    if "Evaluate the Boolean expression:" in pgml:
        kinds.add("boolean")
        kinds.add("boolean_eval")
    if "Determine whether the Boolean expressions are equivalent:" in pgml:
        kinds.add("boolean")
        kinds.add("boolean_equiv")
    if "Compute the complex number expression:" in pgml:
        kinds.add("complex")
        kinds.add("complex_arithmetic")
    if "Find the conjugate of:" in pgml:
        kinds.add("complex")
        kinds.add("complex_conjugate")
    if "Find the modulus of:" in pgml:
        kinds.add("complex")
        kinds.add("complex_modulus")
    if "Simplify the power of i:" in pgml:
        kinds.add("complex")
        kinds.add("complex_power_i")
    return kinds


def bug(case: str, seed: str, category: str, input_data: str, output: str, expected: str, actual: str, description: str) -> Bug:
    return Bug(case, seed, category, input_data, output, expected, actual, description)


def validate_static(pgml: str, case: str, seed: str) -> list[Bug]:
    bugs: list[Bug] = []
    required = ["DOCUMENT();", "loadMacros(", "BEGIN_PGML", "END_PGML", "ENDDOCUMENT();"]
    for marker in required:
        if marker not in pgml:
            bugs.append(bug(case, seed, "pgml_structure", marker, pgml[:400], "marker present", "marker missing", "Generated PGML is missing a required wrapper marker."))

    if "{{" in pgml or "}}" in pgml:
        bugs.append(bug(case, seed, "template_leak", "{{...}}", pgml[:400], "no unreplaced template token", "found {{ or }}", "A template placeholder leaked into generated PGML."))
    if re.search(r"\bnan\b", pgml, re.IGNORECASE):
        bugs.append(bug(case, seed, "numeric_validity", "PGML", pgml[:400], "no NaN", "NaN present", "Generated answer/question contains NaN."))
    if "[_____]{}" in pgml:
        bugs.append(bug(case, seed, "answer_blank", "[_____]", "[_____]{}", "non-empty answer evaluator", "empty answer evaluator", "An answer blank has no answer evaluator."))

    definitions = parse_definitions(pgml)
    for payload in re.findall(r"\[_____\]\{([^{}]*)\}", pgml):
        for ref in re.findall(r"\$([A-Za-z_][A-Za-z0-9_]*)", payload):
            if ref not in definitions:
                bugs.append(bug(case, seed, "undefined_answer_ref", payload, pgml[:400], f"${ref} defined before use", f"${ref} is not defined", "Answer blank references an undefined variable."))
    return bugs


def safe_eval_numeric(expr: str) -> float:
    expr = expr.strip()
    expr = expr.replace("^", "**")
    if not re.fullmatch(r"[0-9eE\.\s+\-*/()]+", expr):
        raise ValueError(f"unsafe or unsupported numeric expression: {expr}")
    return float(eval(expr, {"__builtins__": {}}, {}))


def parse_numeric_answer(payload: str, definitions: dict[str, str]) -> float:
    payload = payload.strip()
    if payload.startswith("$"):
        name = re.match(r"\$([A-Za-z_][A-Za-z0-9_]*)", payload)
        if not name or name.group(1) not in definitions:
            raise ValueError(f"unknown answer variable: {payload}")
        return parse_numeric_answer(definitions[name.group(1)], definitions)
    real_match = re.fullmatch(r"Real\((.*?)\)", payload)
    if real_match:
        return parse_numeric_answer(real_match.group(1), definitions)
    formula_match = re.fullmatch(r"Formula\(['\"](.*?)['\"]\)", payload)
    if formula_match:
        return safe_eval_numeric(formula_match.group(1))
    return float(payload)


def validate_arithmetic(pgml: str, case: str, seed: str) -> list[Bug]:
    bugs: list[Bug] = []
    definitions = parse_definitions(pgml)
    for block in split_blocks(pgml):
        if "What is the value of" not in block and not re.search(r"\[`[^`]+`\]\s+is equal to", block):
            continue
        expr_match = re.search(r"\[`([^`]+)`\]", block)
        payload = answer_payload(block)
        if not expr_match or payload is None:
            bugs.append(bug(case, seed, "arithmetic_parse", block[:300], block, "parsable expression and answer", "parse failed", "Could not parse an arithmetic question block."))
            continue
        expr = expr_match.group(1)
        try:
            expected = safe_eval_numeric(expr)
            actual = parse_numeric_answer(payload, definitions)
            if not math.isclose(expected, actual, rel_tol=1e-8, abs_tol=1e-8):
                bugs.append(bug(case, seed, "arithmetic_answer", expr, payload, str(expected), str(actual), "Arithmetic answer does not match expression evaluation."))
        except Exception as exc:
            bugs.append(bug(case, seed, "arithmetic_exception", expr, payload, "numeric expression can be evaluated", repr(exc), "Arithmetic validator could not evaluate the generated question."))
    return bugs


def strip_outer_parens(expr: str) -> str:
    expr = expr.strip()
    changed = True
    while changed and expr.startswith("(") and expr.endswith(")"):
        changed = False
        depth = 0
        ok = True
        for i, ch in enumerate(expr):
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0 and i != len(expr) - 1:
                    ok = False
                    break
        if ok:
            expr = expr[1:-1].strip()
            changed = True
    return expr


def find_top_bool_op(expr: str) -> tuple[str, int] | None:
    ops = [r"\leftrightarrow", r"\to", r"\lor", r"\oplus", r"\land"]
    depth = 0
    i = 0
    while i < len(expr):
        ch = expr[i]
        if ch == "(":
            depth += 1
            i += 1
            continue
        if ch == ")":
            depth -= 1
            i += 1
            continue
        if depth == 0:
            for op in ops:
                if expr.startswith(op, i):
                    return op, i
        i += 1
    return None


def eval_bool_expr(expr: str, assignments: dict[str, bool]) -> bool:
    expr = strip_outer_parens(expr)
    if expr == r"\mathsf{T}":
        return True
    if expr == r"\mathsf{F}":
        return False
    if re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", expr):
        if expr not in assignments:
            raise ValueError(f"boolean variable has no assignment: {expr}")
        return assignments[expr]
    if expr.startswith(r"\neg"):
        return not eval_bool_expr(expr[len(r"\neg") :].strip(), assignments)

    op_at = find_top_bool_op(expr)
    if not op_at:
        raise ValueError(f"cannot parse boolean expression: {expr}")

    op, index = op_at
    left = expr[:index].strip()
    right = expr[index + len(op) :].strip()
    lval = eval_bool_expr(left, assignments)
    rval = eval_bool_expr(right, assignments)
    if op == r"\land":
        return lval and rval
    if op == r"\lor":
        return lval or rval
    if op == r"\oplus":
        return lval != rval
    if op == r"\to":
        return (not lval) or rval
    if op == r"\leftrightarrow":
        return lval == rval
    raise ValueError(f"unknown boolean operator: {op}")


def bool_variables(expr: str) -> list[str]:
    cleaned = expr
    for token in [r"\mathsf{T}", r"\mathsf{F}", r"\land", r"\lor", r"\oplus", r"\to", r"\leftrightarrow", r"\neg"]:
        cleaned = cleaned.replace(token, " ")
    return sorted(set(re.findall(r"\b[A-Za-z][A-Za-z0-9_]*\b", cleaned)))


def split_top_level_comma(expr: str) -> tuple[str, str]:
    depth = 0
    for i, ch in enumerate(expr):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "," and depth == 0:
            return expr[:i].strip(), expr[i + 1 :].strip()
    raise ValueError(f"could not split boolean pair: {expr}")


def parse_bool_answer(payload: str) -> int:
    payload = payload.strip()
    if payload.startswith("answer=>"):
        payload = payload[len("answer=>") :].split(",width=>", 1)[0].strip()
    return int(payload)


def validate_boolean(pgml: str, case: str, seed: str) -> list[Bug]:
    bugs: list[Bug] = []
    for block in split_blocks(pgml):
        if "Evaluate the Boolean expression:" in block:
            expr_match = re.search(r"Evaluate the Boolean expression:\s*\n\[`([^`]+)`\]", block)
            payload = answer_payload(block)
            if not expr_match or payload is None:
                bugs.append(bug(case, seed, "boolean_eval_parse", block[:300], block, "parsable Boolean evaluation block", "parse failed", "Could not parse Boolean evaluation question."))
                continue
            expr = expr_match.group(1)
            assignments: dict[str, bool] = {}
            for var, value in re.findall(r"-\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s*\\mathsf\{([TF])\}", block):
                assignments[var] = value == "T"
            try:
                expected = 1 if eval_bool_expr(expr, assignments) else 0
                actual = parse_bool_answer(payload)
                if expected != actual:
                    bugs.append(bug(case, seed, "boolean_eval_answer", f"{expr} with {assignments}", payload, str(expected), str(actual), "Boolean evaluation answer is incorrect."))
            except Exception as exc:
                bugs.append(bug(case, seed, "boolean_eval_exception", expr, payload, "truth-value evaluation succeeds", repr(exc), "Boolean evaluation validator failed."))

        if "Determine whether the Boolean expressions are equivalent:" in block:
            pair_match = re.search(r"Determine whether the Boolean expressions are equivalent:\s*\n\[`([^`]+)`\]", block)
            payload = answer_payload(block)
            if not pair_match or payload is None:
                bugs.append(bug(case, seed, "boolean_equiv_parse", block[:300], block, "parsable Boolean equivalence block", "parse failed", "Could not parse Boolean equivalence question."))
                continue
            pair = pair_match.group(1)
            try:
                left, right = split_top_level_comma(pair)
                variables = sorted(set(bool_variables(left) + bool_variables(right)))
                equivalent = True
                for values in itertools.product([False, True], repeat=len(variables)):
                    env = dict(zip(variables, values))
                    if eval_bool_expr(left, env) != eval_bool_expr(right, env):
                        equivalent = False
                        break
                expected = 1 if equivalent else 0
                actual = parse_bool_answer(payload)
                if expected != actual:
                    bugs.append(bug(case, seed, "boolean_equiv_answer", pair, payload, str(expected), str(actual), "Boolean equivalence answer is incorrect by truth-table evaluation."))
                if left.strip() == right.strip():
                    bugs.append(bug(case, seed, "boolean_equiv_low_value", pair, payload, "non-identical expressions", "identical expressions", "Equivalence question is mathematically true but too trivial."))
            except Exception as exc:
                bugs.append(bug(case, seed, "boolean_equiv_exception", pair, payload, "truth-table equivalence check succeeds", repr(exc), "Boolean equivalence validator failed."))
    return bugs


def safe_eval_complex(expr: str) -> complex:
    py = expr.replace("^", "**").replace("i", "j")
    if not re.fullmatch(r"[0-9jJ\.\s+\-*/()]+", py):
        raise ValueError(f"unsafe or unsupported complex expression: {expr}")
    return complex(eval(py, {"__builtins__": {}}, {}))


def parse_complex_or_numeric(payload: str, definitions: dict[str, str]) -> complex | float:
    payload = payload.strip()
    if payload.startswith("$"):
        name = re.match(r"\$([A-Za-z_][A-Za-z0-9_]*)", payload)
        if not name or name.group(1) not in definitions:
            raise ValueError(f"unknown answer variable: {payload}")
        return parse_complex_or_numeric(definitions[name.group(1)], definitions)
    complex_match = re.fullmatch(r"Complex\(([-+]?\d+),([-+]?\d+)\)", payload.replace(" ", ""))
    if complex_match:
        return complex(int(complex_match.group(1)), int(complex_match.group(2)))
    return float(payload)


def complex_equal(a: complex | float, b: complex | float) -> bool:
    ca = complex(a)
    cb = complex(b)
    return math.isclose(ca.real, cb.real, abs_tol=1e-8) and math.isclose(ca.imag, cb.imag, abs_tol=1e-8)


def validate_complex(pgml: str, case: str, seed: str) -> list[Bug]:
    bugs: list[Bug] = []
    definitions = parse_definitions(pgml)
    for block in split_blocks(pgml):
        payload = answer_payload(block)
        if "Compute the complex number expression:" in block:
            expr_match = re.search(r"Compute the complex number expression:\s*\n\[`([^`]+)`\]", block)
            if not expr_match or payload is None:
                bugs.append(bug(case, seed, "complex_arith_parse", block[:300], block, "parsable complex arithmetic block", "parse failed", "Could not parse complex arithmetic question."))
                continue
            expr = expr_match.group(1)
            try:
                expected = safe_eval_complex(expr)
                actual = parse_complex_or_numeric(payload, definitions)
                if not complex_equal(expected, actual):
                    bugs.append(bug(case, seed, "complex_arith_answer", expr, payload, str(expected), str(actual), "Complex arithmetic answer is incorrect."))
            except Exception as exc:
                bugs.append(bug(case, seed, "complex_arith_exception", expr, payload, "complex expression can be evaluated", repr(exc), "Complex arithmetic validator failed."))

        if "Find the conjugate of:" in block:
            num_match = re.search(r"Find the conjugate of:\s*\n\[`([^`]+)`\]", block)
            if not num_match or payload is None:
                bugs.append(bug(case, seed, "complex_conj_parse", block[:300], block, "parsable complex conjugate block", "parse failed", "Could not parse complex conjugate question."))
                continue
            num = num_match.group(1)
            try:
                expected = safe_eval_complex(num).conjugate()
                actual = parse_complex_or_numeric(payload, definitions)
                if not complex_equal(expected, actual):
                    bugs.append(bug(case, seed, "complex_conj_answer", num, payload, str(expected), str(actual), "Complex conjugate answer is incorrect."))
            except Exception as exc:
                bugs.append(bug(case, seed, "complex_conj_exception", num, payload, "complex number can be evaluated", repr(exc), "Complex conjugate validator failed."))

        if "Find the modulus of:" in block:
            num_match = re.search(r"Find the modulus of:\s*\n\[`([^`]+)`\]", block)
            if not num_match or payload is None:
                bugs.append(bug(case, seed, "complex_mod_parse", block[:300], block, "parsable complex modulus block", "parse failed", "Could not parse complex modulus question."))
                continue
            num = num_match.group(1)
            try:
                expected = abs(safe_eval_complex(num))
                actual = parse_complex_or_numeric(payload, definitions)
                if not math.isclose(float(actual.real if isinstance(actual, complex) else actual), expected, abs_tol=1e-8):
                    bugs.append(bug(case, seed, "complex_mod_answer", num, payload, str(expected), str(actual), "Complex modulus answer is incorrect."))
            except Exception as exc:
                bugs.append(bug(case, seed, "complex_mod_exception", num, payload, "modulus can be evaluated", repr(exc), "Complex modulus validator failed."))

        if "Simplify the power of i:" in block:
            power_match = re.search(r"Simplify the power of i:\s*\n\[`i\^(\d+)`\]", block)
            if not power_match or payload is None:
                bugs.append(bug(case, seed, "complex_power_parse", block[:300], block, "parsable i^n block", "parse failed", "Could not parse i^n question."))
                continue
            exponent = int(power_match.group(1))
            try:
                expected = complex(0, 1) ** exponent
                actual = parse_complex_or_numeric(payload, definitions)
                if not complex_equal(expected, actual):
                    bugs.append(bug(case, seed, "complex_power_answer", f"i^{exponent}", payload, str(expected), str(actual), "Power of i answer is incorrect."))
            except Exception as exc:
                bugs.append(bug(case, seed, "complex_power_exception", f"i^{exponent}", payload, "power can be evaluated", repr(exc), "Power-of-i validator failed."))
    return bugs


def validate_calculus_static(pgml: str, case: str, seed: str) -> list[Bug]:
    bugs: list[Bug] = []
    definitions = parse_definitions(pgml)
    for ref in re.findall(r"\$([A-Za-z_][A-Za-z0-9_]*)(?:->D\(\)|->D\(\)->D\(\)|->D\(\)->eval)", pgml):
        if ref not in definitions:
            bugs.append(bug(case, seed, "calculus_undefined_function", ref, pgml[:400], f"${ref} definition", "missing", "Calculus question references an undefined function."))
    for ref in re.findall(r"\[_____\]\{\$([A-Za-z_][A-Za-z0-9_]*)\}", pgml):
        if ref.startswith("anti_") and ref not in definitions:
            bugs.append(bug(case, seed, "calculus_undefined_antiderivative", ref, pgml[:400], f"${ref} definition", "missing", "Integral question references an undefined antiderivative."))
    return bugs


def call_webwork(pgml: str, case: str, seed: str, pgml_path: str, timeout: int) -> tuple[str, str, list[Bug]]:
    url = os.environ.get("WEBWORK_VALIDATE_URL", "").strip()
    if not url:
        return "SKIPPED", "WEBWORK_VALIDATE_URL is not set", []
    payload = json.dumps(
        {
            "case": case,
            "seed": seed,
            "filename": Path(pgml_path).name if pgml_path else "",
            "pgml": pgml,
        }
    ).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    token = os.environ.get("WEBWORK_API_TOKEN", "").strip()
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=payload, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8", errors="replace")
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return "FAIL", "WebWork endpoint did not return JSON", [
                bug(case, seed, "webwork_response", url, raw[:1000], "JSON with ok=true/false", "non-JSON response", "Configured WebWork validation endpoint returned a non-JSON response.")
            ]
        ok = bool(data.get("ok"))
        status = "PASS" if ok else "FAIL"
        message = str(data.get("message", ""))
        if ok:
            return status, message, []
        return status, message, [
            bug(
                case,
                seed,
                "webwork_validation",
                url,
                data.get("output", raw) if isinstance(data, dict) else raw,
                str(data.get("expected", "WeBWorK accepts and grades correctly")),
                str(data.get("actual", "WeBWorK validation failed")),
                message or "Online WeBWorK validation reported a failure.",
            )
        ]
    except urllib.error.URLError as exc:
        return "FAIL", repr(exc), [
            bug(case, seed, "webwork_connection", url, "", "reachable WebWork validation endpoint", repr(exc), "Could not reach configured WebWork validation endpoint.")
        ]


def local_validate(pgml: str, case: str, seed: str) -> list[Bug]:
    bugs: list[Bug] = []
    bugs.extend(validate_static(pgml, case, seed))
    bugs.extend(validate_arithmetic(pgml, case, seed))
    bugs.extend(validate_boolean(pgml, case, seed))
    bugs.extend(validate_complex(pgml, case, seed))
    bugs.extend(validate_calculus_static(pgml, case, seed))
    return bugs


def test_cases() -> list[TestCase]:
    common = {
        "allow_float": False,
        "min_question_num": 6,
        "max_question_num": 6,
        "min_fun_expr_depth": 2,
        "max_fun_expr_depth": 3,
        "integral_expr_depth": 2,
        "min_bool_expr_depth": 2,
        "max_bool_expr_depth": 3,
        "min_bool_var_num": 2,
        "max_bool_var_num": 3,
        "min_complex_component": -8,
        "max_complex_component": 8,
        "min_complex_power": 0,
        "max_complex_power": 12,
    }
    return [
        TestCase(
            "all_mixed",
            "All major question families in one document.",
            {**common, "problem_type": 0, "question_random_amounts": False, "question_type_amounts": [1, 1, 1, 2, 2, 4], "shuffle_questions_for_0_type": True, "calculus_question_mode": 0, "boolean_question_mode": 0, "complex_question_mode": 0},
            {"arithmetic", "set", "vector", "calculus", "boolean", "complex"},
        ),
        TestCase("arithmetic_only", "Arithmetic only.", {**common, "problem_type": 1}, {"arithmetic"}, {"set", "vector", "boolean", "complex"}),
        TestCase("set_only", "Set only.", {**common, "problem_type": 2}, {"set"}, {"arithmetic", "vector", "boolean", "complex"}),
        TestCase("vector_only", "Vector only.", {**common, "problem_type": 3}, {"vector"}, {"arithmetic", "set", "boolean", "complex"}),
        TestCase("calculus_mixed", "Derivative and integral mixed.", {**common, "problem_type": 4, "min_question_num": 8, "max_question_num": 8, "calculus_question_mode": 0, "derivative_weight": 1, "integral_weight": 1}, {"calculus_derivative", "calculus_integral"}),
        TestCase("calculus_derivative_only", "Derivative only.", {**common, "problem_type": 4, "calculus_question_mode": 1}, {"calculus_derivative"}, {"calculus_integral"}),
        TestCase("calculus_integral_only", "Integral only.", {**common, "problem_type": 4, "calculus_question_mode": 2}, {"calculus_integral"}, {"calculus_derivative"}),
        TestCase("boolean_mixed", "Boolean evaluation and equivalence mixed.", {**common, "problem_type": 5, "min_question_num": 8, "max_question_num": 8, "boolean_question_mode": 0, "boolean_eval_weight": 1, "boolean_equiv_weight": 1}, {"boolean_eval", "boolean_equiv"}),
        TestCase("boolean_evaluation_only", "Boolean expression evaluation only.", {**common, "problem_type": 5, "boolean_question_mode": 1}, {"boolean_eval"}, {"boolean_equiv"}),
        TestCase("boolean_equivalence_only", "Boolean expression equivalence only.", {**common, "problem_type": 5, "boolean_question_mode": 2}, {"boolean_equiv"}, {"boolean_eval"}),
        TestCase("complex_mixed", "Complex arithmetic, conjugate, modulus, and i^n mixed.", {**common, "problem_type": 6, "min_question_num": 12, "max_question_num": 12, "complex_question_mode": 0, "complex_arithmetic_weight": 2, "complex_conjugate_weight": 2, "complex_modulus_weight": 2, "complex_power_i_weight": 2}, {"complex_arithmetic", "complex_conjugate", "complex_modulus", "complex_power_i"}),
        TestCase("complex_arithmetic_only", "Complex arithmetic only.", {**common, "problem_type": 6, "complex_question_mode": 1}, {"complex_arithmetic"}, {"complex_conjugate", "complex_modulus", "complex_power_i"}),
        TestCase("complex_conjugate_only", "Complex conjugate only.", {**common, "problem_type": 6, "complex_question_mode": 2}, {"complex_conjugate"}, {"complex_arithmetic", "complex_modulus", "complex_power_i"}),
        TestCase("complex_modulus_only", "Complex modulus only.", {**common, "problem_type": 6, "complex_question_mode": 3}, {"complex_modulus"}, {"complex_arithmetic", "complex_conjugate", "complex_power_i"}),
        TestCase("complex_power_i_only", "Powers of i only.", {**common, "problem_type": 6, "complex_question_mode": 4}, {"complex_power_i"}, {"complex_arithmetic", "complex_conjugate", "complex_modulus"}),
    ]


def run_one_case(case: TestCase, seed: str, base_config: dict[str, Any], args: argparse.Namespace) -> RunResult:
    result = RunResult(case=case.name, seed=seed, status="FAIL")
    config = base_config.copy()
    config.update(case.overrides)
    try:
        write_config_files(config)
    except Exception as exc:
        result.bugs.append(bug(case.name, seed, "config_render", json.dumps(config, indent=2), "", "config.ml renders", repr(exc), "Failed to render temporary OCaml config."))
        return result

    if not args.skip_build:
        build = run_cmd(["dune", "build"], GENERATOR_DIR, args.build_timeout)
        if build.returncode != 0:
            result.bugs.append(bug(case.name, seed, "dune_build", json.dumps(config, indent=2), build.stdout + build.stderr, "dune build succeeds", f"exit {build.returncode}", "Generator failed to build with this test config."))
            return result

    proc = run_cmd(["dune", "exec", "./unparser.exe", "--", seed], GENERATOR_DIR, args.run_timeout)
    if proc.returncode != 0:
        result.bugs.append(bug(case.name, seed, "generation", json.dumps(config, indent=2), proc.stdout + proc.stderr, "unparser.exe exits 0", f"exit {proc.returncode}", "Generator failed while producing a question document."))
        return result

    ast_path, pgml_path = extract_saved_paths(proc.stdout + proc.stderr)
    result.ast_path = ast_path
    result.pgml_path = pgml_path
    if not pgml_path or not Path(pgml_path).exists():
        result.bugs.append(bug(case.name, seed, "missing_output", seed, proc.stdout + proc.stderr, "PGML output file exists", pgml_path or "no path found", "Generator did not report/create a PGML file."))
        return result

    pgml = Path(pgml_path).read_text(encoding="utf-8", errors="replace")
    result.detected_kinds = detect_kinds(pgml)
    result.bugs.extend(local_validate(pgml, case.name, seed))

    missing = case.expected_kinds - result.detected_kinds
    if missing:
        result.bugs.append(bug(case.name, seed, "coverage_missing", json.dumps(config, indent=2), pgml[:1200], ", ".join(sorted(case.expected_kinds)), ", ".join(sorted(result.detected_kinds)), "Generated document did not include all expected question subtypes."))
    forbidden = case.forbidden_kinds & result.detected_kinds
    if forbidden:
        result.bugs.append(bug(case.name, seed, "coverage_forbidden", json.dumps(config, indent=2), pgml[:1200], "no forbidden kinds", ", ".join(sorted(forbidden)), "A single-mode test generated a forbidden question subtype."))

    web_status, web_message, web_bugs = call_webwork(pgml, case.name, seed, pgml_path, args.webwork_timeout)
    result.webwork_status = web_status
    result.webwork_message = web_message
    result.bugs.extend(web_bugs)
    result.status = "PASS" if not result.bugs else "FAIL"
    return result


def report_markdown(results: list[RunResult], started: str, finished: str, args: argparse.Namespace) -> str:
    bugs = [b for result in results for b in result.bugs]
    passed = sum(1 for result in results if result.status == "PASS")
    failed = sum(1 for result in results if result.status == "FAIL")
    web_skipped = sum(1 for result in results if result.webwork_status == "SKIPPED")

    lines: list[str] = []
    lines.append("# Question Generator Test Report")
    lines.append("")
    lines.append(f"- Started: `{started}`")
    lines.append(f"- Finished: `{finished}`")
    lines.append(f"- Cases run: `{len(results)}`")
    lines.append(f"- Passed: `{passed}`")
    lines.append(f"- Failed: `{failed}`")
    lines.append(f"- Bugs found: `{len(bugs)}`")
    lines.append(f"- WeBWorK skipped: `{web_skipped}`")
    lines.append(f"- Seeds per case: `{args.seeds_per_case}`")
    lines.append("")
    if web_skipped:
        lines.append("> Online WeBWorK validation was skipped for some/all cases because `WEBWORK_VALIDATE_URL` was not set. Local PGML/static/semantic checks still ran.")
        lines.append("")

    lines.append("## Case Summary")
    lines.append("")
    lines.append("| Case | Seed | Status | Detected Kinds | WeBWorK | PGML File |")
    lines.append("|---|---|---:|---|---|---|")
    for result in results:
        pgml_rel = str(Path(result.pgml_path).relative_to(ROOT)) if result.pgml_path else ""
        kinds = ", ".join(sorted(result.detected_kinds)) or "-"
        lines.append(f"| `{result.case}` | `{result.seed}` | `{result.status}` | {kinds} | `{result.webwork_status}` | `{pgml_rel}` |")

    lines.append("")
    lines.append("## Bugs")
    lines.append("")
    if not bugs:
        lines.append("No bugs found by the configured tests.")
    else:
        for i, item in enumerate(bugs, 1):
            lines.append(f"### Bug {i}: `{item.category}` in `{item.case}`")
            lines.append("")
            lines.append(f"- Seed: `{item.seed}`")
            lines.append(f"- Description: {item.description}")
            lines.append("")
            lines.append("**Input**")
            lines.append("")
            lines.append("```text")
            lines.append(item.input_data[:4000])
            lines.append("```")
            lines.append("")
            lines.append("**Output**")
            lines.append("")
            lines.append("```text")
            lines.append(item.output[:4000])
            lines.append("```")
            lines.append("")
            lines.append("**Expected Output**")
            lines.append("")
            lines.append("```text")
            lines.append(item.expected)
            lines.append("```")
            lines.append("")
            lines.append("**Actual Output**")
            lines.append("")
            lines.append("```text")
            lines.append(item.actual)
            lines.append("```")
            lines.append("")

    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- Boolean evaluation/equivalence answers are rechecked locally with direct evaluation/truth tables.")
    lines.append("- Complex arithmetic/conjugate/modulus/i^n answers are rechecked locally with Python complex arithmetic.")
    lines.append("- Arithmetic answers are rechecked locally for generated numeric expressions.")
    lines.append("- Set, Vector, and Calculus checks are structural locally; full answer grading for those should be delegated to a configured WeBWorK endpoint.")
    lines.append("- The script restores `config_setting/config.json` and `generator/config.ml` after running.")
    lines.append("")
    return "\n".join(lines)


def save_json_report(results: list[RunResult], path: Path) -> None:
    data = []
    for result in results:
        data.append(
            {
                "case": result.case,
                "seed": result.seed,
                "status": result.status,
                "pgml_path": result.pgml_path,
                "ast_path": result.ast_path,
                "detected_kinds": sorted(result.detected_kinds),
                "webwork_status": result.webwork_status,
                "webwork_message": result.webwork_message,
                "bugs": [item.__dict__ for item in result.bugs],
            }
        )
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate and validate all supported question types.")
    parser.add_argument("--seeds-per-case", type=int, default=1, help="Number of deterministic seeds to run for each case.")
    parser.add_argument("--case", action="append", default=[], help="Run only matching case name(s). Can be passed multiple times.")
    parser.add_argument("--report", default="", help="Markdown report path. Defaults to test_reports/question_type_report_<timestamp>.md")
    parser.add_argument("--build-timeout", type=int, default=90)
    parser.add_argument("--run-timeout", type=int, default=90)
    parser.add_argument("--webwork-timeout", type=int, default=60)
    parser.add_argument("--skip-build", action="store_true", help="Skip dune build before generation.")
    parser.add_argument("--keep-config", action="store_true", help="Do not restore config files at the end. Useful only for debugging.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_path = Path(args.report) if args.report else REPORT_DIR / f"question_type_report_{timestamp}.md"
    if not report_path.is_absolute():
        report_path = ROOT / report_path
    json_report_path = report_path.with_suffix(".json")

    original_json = CONFIG_JSON.read_bytes() if CONFIG_JSON.exists() else None
    original_ml = GENERATOR_CONFIG.read_bytes() if GENERATOR_CONFIG.exists() else None
    base_config = load_base_config()
    started = datetime.now().isoformat(timespec="seconds")
    results: list[RunResult] = []

    try:
        cases = test_cases()
        if args.case:
            selected = set(args.case)
            cases = [case for case in cases if case.name in selected]
            missing = selected - {case.name for case in cases}
            if missing:
                print("Unknown case(s): " + ", ".join(sorted(missing)), file=sys.stderr)
                return 2

        for case in cases:
            for i in range(args.seeds_per_case):
                seed = f"test_{case.name}_{i + 1}"
                print(f"[RUN] {case.name} seed={seed}")
                try:
                    results.append(run_one_case(case, seed, base_config, args))
                except Exception as exc:
                    tb = traceback.format_exc()
                    results.append(
                        RunResult(
                            case=case.name,
                            seed=seed,
                            status="FAIL",
                            bugs=[
                                bug(
                                    case.name,
                                    seed,
                                    "script_exception",
                                    case.description,
                                    tb,
                                    "test runner completes",
                                    repr(exc),
                                    "The test runner itself crashed for this case.",
                                )
                            ],
                        )
                    )
    finally:
        if not args.keep_config:
            if original_json is None:
                try:
                    CONFIG_JSON.unlink()
                except FileNotFoundError:
                    pass
            else:
                CONFIG_JSON.write_bytes(original_json)
            if original_ml is None:
                try:
                    GENERATOR_CONFIG.unlink()
                except FileNotFoundError:
                    pass
            else:
                GENERATOR_CONFIG.write_bytes(original_ml)

    finished = datetime.now().isoformat(timespec="seconds")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(report_markdown(results, started, finished, args), encoding="utf-8")
    save_json_report(results, json_report_path)

    print(f"Report written to: {report_path}")
    print(f"JSON report written to: {json_report_path}")
    failures = sum(1 for item in results if item.status == "FAIL")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
