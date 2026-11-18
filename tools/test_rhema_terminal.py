"""Exercise the built CLI on both pipes and a real pseudo-terminal."""

from errno import EIO
import os
from pathlib import Path
import re
import select
import subprocess
import tempfile
import time
import unittest

if os.name == "posix":
    import pty


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "generator/_build/default/rhema/bin/rhema_main.exe"
STDLIB = ROOT / "generator/stdlib"


def environment(**overrides):
    env = dict(os.environ)
    for key in ("CI", "NO_COLOR", "LC_ALL", "LC_CTYPE", "VTE_VERSION", "COLORTERM"):
        env.pop(key, None)
    env.update(TERM="xterm-256color", TERM_PROGRAM="vscode", LANG="en_US.UTF-8")
    env.update(overrides)
    return env


class RhemaTerminalTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.folder = Path(temp.name)
        self.boolean = STDLIB / "boolean.rhm"
        self.bad = self.folder / "bad:spec.rhm"
        self.bad.write_text('synth value\nstart Q\nQ -> "example" {\n\tvalue = nope(1)\n}\n'
                            'prompt "Example"\nanswer Q.value\n', encoding="utf-8")

    def command(self, *args):
        return [str(CLI), *map(str, args)]

    def pipes(self, *args):
        return subprocess.run(self.command(*args), cwd=ROOT, env=environment(),
                              capture_output=True, text=True, timeout=20)

    def terminal(self, *args, env=None):
        if os.name != "posix":
            self.skipTest("pseudo-terminal test requires POSIX")
        master, slave = pty.openpty()
        try:
            with subprocess.Popen(self.command(*args), cwd=ROOT, env=env or environment(),
                                  stdin=subprocess.DEVNULL, stdout=slave, stderr=slave) as process:
                os.close(slave)
                slave = None
                chunks = []
                deadline = time.monotonic() + 20
                while True:
                    remaining = max(0, deadline - time.monotonic())
                    if not select.select([master], [], [], remaining)[0]:
                        process.kill()
                        raise subprocess.TimeoutExpired(self.command(*args), 20)
                    try:
                        data = os.read(master, 65536)
                    except OSError as error:
                        if error.errno != EIO:
                            raise
                        break
                    if not data:
                        break
                    chunks.append(data)
                return process.wait(timeout=20), b"".join(chunks).decode("utf-8").replace("\r\n", "\n")
        finally:
            if slave is not None:
                os.close(slave)
            os.close(master)

    def test_compile_reports_real_count_and_artifacts(self):
        pg, ast = self.folder / "a #.pg", self.folder / "out.ast"
        code, terminal = self.terminal(self.boolean, "--count", 6, "--seed", 42,
                                       "-o", pg, "--ast-out", ast)
        self.assertEqual(code, 0, terminal)
        self.assertIn("Math problem generator", terminal)
        self.assertIn("0 / 6", terminal)
        self.assertIn("6 / 6", terminal)
        self.assertIn("Generated 6 questions", terminal)
        self.assertIn("(seed 42)", terminal)
        self.assertIn("Rhema brought the questions.", terminal)
        self.assertIn("a%20%23.pg", terminal)
        self.assertIn(str(ast), terminal)
        self.assertNotIn("   Tree ", terminal)
        self.assertIn("WeBWorK rendering and grading were not run.", terminal)
        self.assertTrue(pg.is_file())
        self.assertTrue(ast.is_file())
        piped = self.pipes(self.boolean, "--count", 6, "--seed", 42, "-o", "-")
        self.assertEqual(piped.returncode, 0, piped.stderr)
        self.assertEqual(piped.stderr, "")
        self.assertEqual(piped.stdout, pg.read_text(encoding="utf-8"))

    def test_set_progress_uses_set_size_not_count(self):
        code, terminal = self.terminal("run", STDLIB / "homework_set.rhm", "--run", "quick", "--count", 25)
        self.assertEqual(code, 0, terminal)
        self.assertIn("0 / 4", terminal)
        self.assertIn("4 / 4", terminal)
        self.assertIn("Generated 4 questions", terminal)
        self.assertNotIn("/ 25", terminal)

    def test_error_excerpt_only_in_interactive_mode(self):
        piped = self.pipes("check", self.bad)
        self.assertEqual(piped.returncode, 1)
        self.assertEqual(piped.stdout, "")
        self.assertRegex(piped.stderr, re.escape(str(self.bad)) + r":4:\d+: error: .*nope")
        self.assertEqual(len(piped.stderr.splitlines()), 1)
        output = self.folder / "bad.pg"
        code, terminal = self.terminal(self.bad, "-o", output, "--no-color")
        self.assertEqual(code, 1, terminal)
        self.assertIn("Specification check failed", terminal)
        self.assertIn("value = nope(1)", terminal)
        self.assertIn("^", terminal)
        self.assertIn("This run did not write a PG file.", terminal)
        self.assertNotIn("[3/4]", terminal)
        self.assertFalse(output.exists())
        code, terminal = self.terminal("--plain", "check", self.bad)
        self.assertEqual(code, 1)
        self.assertEqual(terminal, piped.stderr)

    def test_generation_failure_has_no_spurious_progress_or_success(self):
        spec = self.folder / "impossible.rhm"
        spec.write_text('synth value\nstart Q\nQ -> "example" {\n  require (1 = 0)\n  value = 1\n}\n'
                        'prompt "Example"\nanswer Q.value\n', encoding="utf-8")
        code, terminal = self.terminal("run", spec, "--count", 2)
        self.assertEqual(code, 1, terminal)
        self.assertIn("0 / 2\n", terminal)
        self.assertIn("Question generation failed", terminal)
        self.assertIn("can never satisfy its own constraints", terminal)
        self.assertNotIn("2 / 2", terminal)
        self.assertNotIn("[4/4]", terminal)

    def test_set_failure_reports_questions_accepted_before_failure(self):
        question = self.folder / "one.rhm"
        question.write_text('synth value\nstart Q\nQ -> "example" { value = 1 }\n'
                            'prompt "Example"\nanswer Q.value\n', encoding="utf-8")
        spec = self.folder / "paper.rhm"
        spec.write_text('import "one.rhm" as one\nset test {\n  2 of one.main()\n  distinct\n}\n',
                        encoding="utf-8")
        code, terminal = self.terminal("run", spec, "--run", "test")
        self.assertEqual(code, 1, terminal)
        self.assertIn("1 / 2\n", terminal)
        self.assertIn("question 2 (one.main) could not satisfy the set's constraints", terminal)
        self.assertNotIn("2 / 2", terminal)

    def test_output_failure_does_not_show_success_summary(self):
        code, terminal = self.terminal(self.boolean, "--count", 1, "--seed", 42,
                                       "-o", self.folder / "missing" / "a.pg")
        self.assertEqual(code, 1, terminal)
        self.assertIn("Output failed", terminal)
        self.assertNotIn("Generated 1 question", terminal)
        self.assertNotIn("Rhema brought the questions.", terminal)

    def test_fallback_and_verbose_output(self):
        args = ("run", self.boolean, "--count", 1, "--seed", 7)
        normal = self.pipes(*args)
        self.assertEqual(normal.returncode, 0, normal.stderr)
        self.assertEqual(normal.stderr, "")
        trace = self.pipes("--verbose", *args)
        self.assertEqual(trace.returncode, 0, trace.stderr)
        self.assertEqual(trace.stdout, normal.stdout)
        for text in ("accepted derivation", " -> ", "Inherited:", "Synthesized:"):
            self.assertIn(text, trace.stderr)
        code, terminal = self.terminal(*args, env=environment(CI="true"))
        self.assertEqual(code, 0, terminal)
        self.assertEqual(terminal, normal.stdout)
        code, terminal = self.terminal(*args, "--no-emoji", env=environment(NO_COLOR="1"))
        self.assertEqual(code, 0, terminal)
        self.assertIn("[################]", terminal)
        self.assertIn("OK Generated", terminal)
        self.assertNotIn("\x1b[", terminal)

    def test_help_and_pg_to_stdout(self):
        code, terminal = self.terminal("--help")
        self.assertEqual(code, 0, terminal)
        self.assertIn("Math problem generator", terminal)
        self.assertIn("--verbose", terminal)
        code, terminal = self.terminal(self.boolean, "--count", 1, "-o", "-")
        self.assertEqual(code, 0, terminal)
        self.assertTrue(terminal.startswith("DOCUMENT();"), terminal)
        self.assertNotIn("\x1b", terminal)

    def test_banner_uses_brand_orange_and_preserves_terminal_fallbacks(self):
        code, terminal = self.terminal("--help", env=environment(COLORTERM="truecolor"))
        self.assertEqual(code, 0, terminal)
        self.assertIn("\x1b[38;2;231;117;0m", terminal)
        self.assertIn("\u2588\u2588\u2588", terminal)
        self.assertIn("\u255a\u2550\u255d", terminal)
        code, terminal = self.terminal("--help")
        self.assertEqual(code, 0, terminal)
        self.assertIn("\x1b[38;5;208m", terminal)
        self.assertNotIn("\x1b[38;2;", terminal)
        code, terminal = self.terminal("--no-color", "--help")
        self.assertEqual(code, 0, terminal)
        self.assertIn("\u2588\u2588\u2588", terminal)
        self.assertNotIn("\x1b", terminal)
        for flags, env in ((("--no-emoji",), environment()), ((), environment(LC_ALL="C"))):
            code, terminal = self.terminal(*flags, "--help", env=env)
            self.assertEqual(code, 0, terminal)
            self.assertIn("RHEMA", terminal)
            self.assertTrue(terminal.isascii())

    def test_hello_is_opt_in_and_plain_when_redirected(self):
        help_output = self.pipes("--help")
        self.assertNotIn("--hello", help_output.stdout)
        hello = self.pipes("--hello")
        self.assertEqual(hello.returncode, 0, hello.stderr)
        self.assertIn('Q -> "What if?"', hello.stdout)
        self.assertIn("curiosity = 1", hello.stdout)
        self.assertTrue(hello.stdout.isascii())
        self.assertNotIn("\x1b", hello.stdout)
        self.assertEqual(hello.stderr, "")

    def test_seed_egg_is_only_for_an_explicit_interactive_seed_42(self):
        message = "Rhema brought the questions."
        args = ("run", self.boolean, "--count", 1)
        code, terminal = self.terminal(*args, "--seed", 42)
        self.assertEqual(code, 0, terminal)
        self.assertIn(message, terminal)
        for flags, env in ((("--seed", 41), environment()),
                           (("--seed", 42, "--plain"), environment()),
                           (("--seed", 42), environment(CI="true"))):
            code, terminal = self.terminal(*args, *flags, env=env)
            self.assertEqual(code, 0, terminal)
            self.assertNotIn(message, terminal)
        piped = self.pipes(*args, "--seed", 42)
        self.assertEqual(piped.returncode, 0, piped.stderr)
        self.assertNotIn(message, piped.stdout)
        self.assertEqual(piped.stderr, "")

    def test_checker_jokes_match_real_failure_stage(self):
        syntax = self.folder / "syntax.rhm"
        syntax.write_text("start Q\nQ -> )\n", encoding="utf-8")
        cases = [
            (syntax, "You shall not parse!", "Not even wrong"),
            (self.bad, "Not even wrong", "You shall not parse!"),
        ]
        for path, expected, absent in cases:
            with self.subTest(path=path):
                code, terminal = self.terminal("check", path)
                self.assertEqual(code, 1, terminal)
                self.assertIn(": error: ", terminal)
                self.assertIn(expected, terminal)
                self.assertNotIn(absent, terminal)
                self.assertLess(terminal.index(": error:"), terminal.index(expected))
                self.assertNotIn(expected, self.pipes("check", path).stderr)
        code, terminal = self.terminal("check", self.folder / "missing.rhm")
        self.assertEqual(code, 1, terminal)
        self.assertIn("cannot find", terminal)
        for _, joke, _ in cases:
            self.assertNotIn(joke, terminal)

    def test_batch_quips_only_at_their_own_events(self):
        check_args = ("check", self.boolean, STDLIB / "arithmetic.rhm")
        code, terminal = self.terminal(*check_args)
        self.assertEqual(code, 0, terminal)
        self.assertIn("Oh, that will be great!", terminal)
        self.assertIn("All specifications checked out.", terminal)
        code, terminal = self.terminal("check", self.boolean, self.bad)
        self.assertEqual(code, 1, terminal)
        self.assertNotIn("Oh, that will be great!", terminal)
        code, terminal = self.terminal(STDLIB / "arithmetic.rhm", "--count", 100,
                                       "-o", self.folder / "batch.pg")
        self.assertEqual(code, 0, terminal)
        self.assertIn("Are you sure? That's 100 questions. Continuing.", terminal)
        self.assertIn("100 / 100", terminal)
        code, terminal = self.terminal("run", self.boolean, "--count", 0)
        self.assertEqual(code, 0, terminal)
        self.assertIn("Off-by-one avoided: exactly zero questions.", terminal)
        individual = self.folder / "individual"
        code, terminal = self.terminal(STDLIB / "homework_set.rhm", "--run", "quick", "--seed", 42,
                                       "--pg-dir", individual, "-o", self.folder / "set.pg")
        self.assertEqual(code, 0, terminal)
        self.assertIn("Rush B!", terminal)
        self.assertNotIn("Rhema brought the questions.", terminal)
        self.assertEqual(len(list(individual.glob("*.pg"))), 4)

    def test_nailong_runs_a_hidden_smoke_test(self):
        result = self.pipes("--nailong")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Nailong Harness: PASS", result.stdout)
        self.assertIn("answer = 42", result.stdout)
        self.assertEqual(result.stderr, "")
        code, terminal = self.terminal("--nailong")
        self.assertEqual(code, 0, terminal)
        self.assertIn("Works on my machine.", terminal)
        self.assertNotIn("--nailong", self.pipes("--help").stdout)

    def test_404_quip_only_for_an_unknown_question_in_a_terminal(self):
        spec = STDLIB / "calculus.rhm"
        args = ("run", spec, "--question", "not_a_question", "--count", 1)
        code, terminal = self.terminal(*args)
        self.assertEqual(code, 1, terminal)
        self.assertIn("404: question not found.", terminal)
        self.assertIn("is not a question of this grammar; it has", terminal)
        self.assertIn("integral", terminal)
        piped = self.pipes(*args)
        self.assertEqual(piped.returncode, 1)
        self.assertEqual(piped.stdout, "")
        self.assertNotIn("404:", piped.stderr)
        code, terminal = self.terminal("--plain", *args)
        self.assertEqual(code, 1)
        self.assertEqual(terminal, piped.stderr)
        code, terminal = self.terminal("run", spec, "--question", "integral", "--count", 1)
        self.assertEqual(code, 0, terminal)
        self.assertNotIn("404:", terminal)

    def test_coffee_is_hidden_and_prints_one_line(self):
        result = self.pipes("--coffee")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "418: I'm a teapot. I compile questions, not coffee.\n")
        self.assertEqual(result.stderr, "")
        self.assertNotIn("--coffee", self.pipes("--help").stdout)

if __name__ == "__main__":
    unittest.main()
