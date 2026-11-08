"""Record the exact CLI steps used for the VS Code and terminal demo.

Writes only output/cli. The extension's default compile is simulated in a
temporary folder, so the original specification is never overwritten.
"""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    demo = Path(__file__).resolve().parent
    root = demo.parents[1]
    engine = root / "generator/_build/install/default/bin/rhema"
    stdlib = root / "generator/stdlib"
    source = demo / "demo_budget.rhm"
    output = demo / "output/cli"
    output.mkdir(parents=True, exist_ok=True)
    records = []

    def run(label, args, cwd=demo):
        command = [str(engine), *map(str, args)]
        result = subprocess.run(command, cwd=cwd, text=True, capture_output=True, timeout=45)
        records.append({"step": label, "cwd": str(cwd), "command": command,
                        "exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
        if result.returncode:
            raise RuntimeError(result.stderr or result.stdout)
        print(f"PASS {label}\n{result.stdout}", flush=True)
        return result.stdout

    run("check", ["check", source.name, "-I", stdlib])
    run("list", ["list", source.name, "-I", stdlib])
    default = run("extension_run_equivalent", ["run", "--question", "main", "-I", stdlib, source.name])
    (output / "extension_default.txt").write_text(default)
    with tempfile.TemporaryDirectory(prefix="rhema-extension-compile-") as temp:
        directory = Path(temp)
        (directory / source.name).write_bytes(source.read_bytes())
        run("extension_compile_equivalent", ["--question", "main", "-I", stdlib, source.name], directory)
        (output / "extension_default.pg").write_bytes((directory / "demo_budget.pg").read_bytes())
    common = [source.name, "-I", stdlib, "--question", "main", "--count", "1",
              "--assignment", "demo_budget.rhm:main", "--student", "FYP2026", "--set", "cost=10"]
    listing = run("personalized_run", ["run", *common])
    assert "answer: 2" in listing
    (output / "cost10.txt").write_text(listing)
    run("compile_with_debug_artifacts", [*common, "-o", output / "cost10.pg",
        "--ast-out", output / "cost10_ast.txt", "--visualization-out", output / "cost10_trees.html"])
    pg = (output / "cost10.pg").read_text()
    assert "[_____]{2}" in pg
    replay = run("reproducible_replay", [*common, "-o", "-"])
    assert replay == pg
    changed = ["FYP2027" if arg == "FYP2026" else arg for arg in common]
    other = run("other_student_variant", ["run", *changed])
    assert "answer: -11" in other
    (output / "other_student.txt").write_text(other)
    assignment = run("assignment_set", ["run", "demo_assignment.rhm", "-I", stdlib,
        "--run", "defense", "--assignment", "demo_assignment.rhm:main", "--student", "FYP2026"])
    assert "5 questions in 3 parts" in assignment
    (output / "assignment.txt").write_text(assignment)
    seed_identity = "demo_budget.rhm:main/FYP2026"
    digest = hashlib.md5(seed_identity.encode()).hexdigest()
    report = {
        "time_utc": datetime.now(timezone.utc).isoformat(),
        "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "extension": {"id": "rhema.rhema-language", "version": "0.1.1",
                      "gui_verified_this_run": False,
                      "note": "Installed extension code was inspected and its CLI invocations reproduced. Native VS Code UI control permission was unavailable."},
        "seed": {"identity": seed_identity, "digest": digest, "first_eight_hex": digest[:8],
                 "integer": int(digest[:8], 16)},
        "records": records, "replay_identical": True, "answer": "2", "other_student_answer": "-11",
        "scope": "CLI behavior and extension-equivalent invocations, not native VS Code button execution or source-token/AST dumps.",
    }
    (output / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    lines = ["# Actual CLI demo transcript", "", "Generated: " + report["time_utc"], "",
             "Commit: `" + report["commit"] + "`", "",
             "The extension's compile command was reproduced in a disposable directory; its absolute temp path is historical evidence, not a reusable demo path.", ""]
    import shlex
    for record in records:
        lines += ["## " + record["step"], "", "Working directory: `" + record["cwd"] + "`", "",
                  "```sh", shlex.join(record["command"]), "```", "",
                  "Exit status: " + str(record["exit_code"]), "", "```text",
                  record["stdout"] or "(No standard output; inspect the generated files.)", "```", ""]
    (output / "CLI_TRANSCRIPT.md").write_text("\n".join(lines))
    print("Verified CLI demo:", output / "verification.json")


if __name__ == "__main__":
    main()
