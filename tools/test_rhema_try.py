"""The parts of the command that talk with a person: the try session, the
lists a terminal is offered, and the hints. Each is held to the plain
command it stands for, so that nothing interactive can drift from it."""

from errno import EIO
import os
from pathlib import Path
import select
import shlex
import subprocess
import tempfile
import time
import unittest

if os.name == "posix":
    import pty


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "generator/_build/default/rhema/bin/rhema_main.exe"
STDLIB = ROOT / "generator/stdlib"

# A numeric answer, and a mistake that gives another number.
SIGNS = '''attribute cost = 1 split
mistake forgot_sign "forgets the minus sign"
random a = integer_between(2, 9)
random b = integer_between(2, 9)
synth value on Q
start Q
Q -> "product" when cost >= 0 {
  value = 0 - a * b
  mistake forgot_sign value = a * b
}
prompt "What is -{a} times {b}?"
answer Q.value
'''

QUARTER = '''random a = integer_between(2, 9)
synth value on Q
start Q
Q -> "quarter" { value = a / (4 * a) }
prompt "What is {a} over four times {a}?"
answer Q.value
'''


def environment(**overrides):
    env = dict(os.environ)
    for key in ("CI", "NO_COLOR", "LC_ALL", "LC_CTYPE", "VTE_VERSION", "COLORTERM"):
        env.pop(key, None)
    env.update(TERM="xterm-256color", LANG="en_US.UTF-8")
    env.update(overrides)
    return env


class Base(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.folder = Path(temp.name)
        self.signs = self.folder / "signs.rhm"
        self.signs.write_text(SIGNS, encoding="utf-8")
        self.quarter = self.folder / "quarter.rhm"
        self.quarter.write_text(QUARTER, encoding="utf-8")

    def rhema(self, *args, typed=None, cwd=None):
        return subprocess.run([str(CLI), *map(str, args)], cwd=cwd or self.folder, env=environment(),
                              input=typed, capture_output=True, text=True, timeout=30)

    def session(self, file, *commands, options=()):
        """The session's standard output and error for these lines of input."""
        result = self.rhema("try", file, *options, typed="".join(line + "\n" for line in commands))
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout, result.stderr

    def terminal(self, *args, typed=(), cwd=None, person=True):
        """Run with all three streams on a pseudo-terminal, typing the lines
        one by one, each when the command has gone quiet. Without a person,
        the screen is a terminal and the input is empty."""
        if os.name != "posix":
            self.skipTest("pseudo-terminal test requires POSIX")
        master, slave = pty.openpty()
        lines = list(typed)
        try:
            with subprocess.Popen([str(CLI), *map(str, args)], cwd=cwd or self.folder, env=environment(),
                                  stdin=slave if person else subprocess.DEVNULL,
                                  stdout=slave, stderr=slave) as process:
                os.close(slave)
                slave = None
                chunks = []
                deadline = time.monotonic() + 30
                while True:
                    if time.monotonic() > deadline:
                        process.kill()
                        self.fail("the command did not end: " + b"".join(chunks).decode("utf-8", "replace"))
                    if select.select([master], [], [], 0.3)[0]:
                        try:
                            data = os.read(master, 65536)
                        except OSError as error:
                            if error.errno != EIO:
                                raise
                            break
                        if not data:
                            break
                        chunks.append(data)
                    elif process.poll() is not None:
                        break
                    elif person:
                        # quiet and still running: it waits for a line (or for the end)
                        try:
                            os.write(master, (lines.pop(0) + "\n").encode() if lines else b"\x04")
                        except OSError:
                            pass  # it ended between the two looks
                return process.wait(timeout=10), b"".join(chunks).decode("utf-8").replace("\r\n", "\n")
        finally:
            if slave is not None:
                os.close(slave)
            os.close(master)


class TrySessionTests(Base):
    def test_a_session_shows_exactly_what_run_prints(self):
        listing = self.rhema("run", self.signs, "--count", 3)
        self.assertEqual(listing.returncode, 0, listing.stderr)
        out, err = self.session(self.signs, "a", "", "a", "n", "answer")
        status, rest = out.split("\n", 1)
        self.assertRegex(status, r"^-- main, cost = 1, seed \d+$")
        self.assertEqual(rest, listing.stdout)
        self.assertEqual(err, "")
        self.assertIn("mistake forgot_sign: ", rest)

    def test_the_library_grammars_too(self):
        for name in ("calculus.rhm", "boolean.rhm", "sequence.rhm"):
            listing = self.rhema("run", STDLIB / name, "--count", 2)
            out, _ = self.session(STDLIB / name, "a", "", "a")
            self.assertEqual(out.split("\n", 1)[1], listing.stdout, name)

    def test_how_gives_the_command_that_prints_the_questions_shown(self):
        out, _ = self.session(self.signs, "cost = 4", "", "", "how", options=("--student", "s 01"))
        lines = out.splitlines()
        command = shlex.split(lines[-1])
        self.assertEqual(command[:2], ["rhema", "run"])
        self.assertEqual(command[-2:], ["--count", "3"])
        self.assertIn("cost=4", command)
        replay = self.rhema(*command[1:])
        self.assertEqual(replay.returncode, 0, replay.stderr)
        shown = [line for line in lines if line[:3].strip().rstrip(".").isdigit() and line[2] == "."]
        printed = [line for line in replay.stdout.splitlines() if line[2:3] == "."]
        # after the budget change the sequence starts again: 1, 2, 3
        self.assertEqual(shown[-3:], printed)
        self.assertEqual([line[:3] for line in shown], [" 1.", " 1.", " 2.", " 3."])

    def test_the_seed_is_the_one_run_derives(self):
        for options in ((), ("--student", "20261234"), ("--assignment", "week 3"), ("--seed", "42")):
            listing = self.rhema("run", self.signs, "--count", 2, *options)
            out, _ = self.session(self.signs, "a", "", "a", options=options)
            self.assertEqual(out.split("\n", 1)[1], listing.stdout, options)

    def test_a_question_type_and_a_budget_are_those_of_the_options(self):
        calculus = STDLIB / "calculus.rhm"
        listing = self.rhema("run", calculus, "--question", "integral", "--set", "cost=4", "--count", 2)
        self.assertEqual(listing.returncode, 0, listing.stderr)
        out, _ = self.session(calculus, "question integral", "cost=4", "a", "", "a")
        self.assertEqual(out.split("-- integral, cost = 4", 1)[1].split("\n", 1)[1], listing.stdout)
        # and given on the command line instead
        direct, _ = self.session(calculus, "a", "", "a", options=("--question", "integral", "--set", "cost=4"))
        self.assertEqual(direct.split("\n", 1)[1], listing.stdout)

    def test_a_refused_command_changes_nothing(self):
        plain, _ = self.session(self.signs, "", "a", "how")
        out, err = self.session(self.signs, "question nosuch", "nosuch = 3", "cost = -2", "seed many",
                                "sed 4", "", "a", "how")
        self.assertEqual(out, plain)
        errors = err.splitlines()
        self.assertEqual(len(errors), 5, err)
        self.assertIn("'nosuch' is not a question of this grammar; it has main", errors[0])
        self.assertIn("'nosuch' is not an inherited attribute of this grammar; it has cost", errors[1])
        self.assertIn("cannot start negative", errors[2])
        self.assertIn("seed takes a whole number, not many", errors[3])
        self.assertIn("'sed 4' is not a command of the session (did you mean seed?)", errors[4])
        self.assertTrue(all(line.startswith(str(self.signs) + ": error: ") for line in errors))

    def test_reset_and_seed_start_the_sequence_again(self):
        out, _ = self.session(self.signs, "cost = 5", "seed 7", "reset", "seed")
        statuses = [line for line in out.splitlines() if line.startswith("-- ")]
        self.assertRegex(statuses[0], r"^-- main, cost = 1, seed \d+$")
        self.assertRegex(statuses[1], r"^-- main, cost = 5, seed \d+$")
        self.assertEqual(statuses[2], "-- main, cost = 5, seed 7")
        self.assertEqual(statuses[3], "-- main, cost = 1, seed 7")
        self.assertEqual(statuses[4], statuses[0])
        self.assertEqual(out.count(" 1. "), 5)

    def test_a_number_is_compared_exactly_and_a_mistake_is_named(self):
        listing = self.rhema("run", self.signs, "--count", 1).stdout.splitlines()
        right = listing[1].split(": ", 1)[1]
        mistaken = listing[2].split(": ", 1)[1]
        self.assertEqual(right, "-" + mistaken)
        out, err = self.session(self.signs, "= " + right, "=" + mistaken, "= 1000", "= x + 1", "= 1; 2")
        self.assertEqual(out.splitlines()[2:], [
            "    right",
            "    not right: this is the answer of the mistake forgot_sign (forgets the minus sign)",
            "    not right",
        ])
        self.assertIn("type a whole number, a fraction such as 3/4 or a decimal such as 0.75", err.splitlines()[0])
        self.assertIn("this question has 1 answers", err.splitlines()[1])
        # the answer itself is never given away by a comparison
        self.assertNotIn("answer:", out)

    def test_a_fraction_may_be_typed_in_several_ways(self):
        out, err = self.session(self.quarter, "= 1/4", "= 0.25", "= .25", "= 2/8", "= +0.250", "= 0.3",
                                "= -1/4", "= -0.25", "= 1/0", "= 0.2.5", "= 99999999999999999999")
        self.assertEqual(out.splitlines()[2:], ["    right"] * 5 + ["    not right"] * 3)
        self.assertEqual(len(err.splitlines()), 3, err)

    def test_what_is_not_a_number_is_left_to_webwork(self):
        out, err = self.session(STDLIB / "calculus.rhm", "= 2*x")
        self.assertNotIn("    right", out)
        self.assertNotIn("not right", out)
        self.assertIn("only numbers are compared here; WeBWorK grades the rest", err)

    def test_the_tree_the_pg_and_the_list(self):
        out, _ = self.session(self.signs, "pg", "t", "list", "?")
        document = self.rhema(self.signs, "--count", 1, "-o", "-").stdout
        self.assertIn(document, out)
        self.assertIn('  Q -> "product" [line 7]', out)
        self.assertIn("    Inherited: cost=1", out)
        self.assertIn("questions: main\nbudgets: cost = 1\n", out)
        self.assertIn("= NUMBER", out)

    def test_the_end_of_the_input_ends_the_session(self):
        result = self.rhema("try", self.signs, typed="")
        self.assertEqual((result.returncode, result.stderr), (0, ""))
        self.assertEqual(len(result.stdout.splitlines()), 2)
        self.assertEqual(self.session(self.signs, "quit", "a")[0], result.stdout)

    def test_what_a_session_cannot_be_asked(self):
        for options, words in ((("-o", "x.pg"), "try writes no file"),
                               (("--run", "quick"), "try works on a question type"),
                               (("--answers",), "try writes no file")):
            result = self.rhema("try", self.signs, *options, typed="")
            self.assertEqual(result.returncode, 2)
            self.assertIn(words, result.stderr.splitlines()[0])
        for options, words in ((("--question", "nosuch"), "is not a question of this grammar"),
                               (("--set", "nosuch=1"), "is not an inherited attribute")):
            result = self.rhema("try", self.signs, *options, typed="")
            self.assertEqual((result.returncode, result.stdout), (1, ""))
            self.assertIn(words, result.stderr)
        sets = self.rhema("try", STDLIB / "homework_set.rhm", typed="")
        self.assertEqual(sets.returncode, 1)
        self.assertIn("this file has no question of its own", sets.stderr)

    def test_at_a_terminal_the_session_prompts(self):
        code, screen = self.terminal("try", self.signs, "--no-color", typed=("a", "quit"))
        self.assertEqual(code, 0, screen)
        self.assertIn("Enter: the next question.", screen)
        self.assertEqual(screen.count("try> "), 2)
        self.assertIn("    answer: -", screen)


class ChoiceTests(Base):
    def test_a_set_chosen_from_the_list_is_the_set_named(self):
        homework = STDLIB / "homework_set.rhm"
        named = self.rhema(homework, "--run", "quick")
        self.assertEqual(named.returncode, 0, named.stderr)
        expected = (self.folder / "quick.pg").read_bytes()
        (self.folder / "quick.pg").unlink()
        for typed in ("2", "quick"):
            code, screen = self.terminal(homework, "--no-color", typed=(typed,))
            self.assertEqual(code, 0, screen)
            self.assertIn("[1] homework\n", screen)
            self.assertIn("[2] quick\n", screen)
            self.assertIn("The same as giving --run quick.", screen)
            self.assertIn("Assignment      quick", screen)
            self.assertEqual((self.folder / "quick.pg").read_bytes(), expected)
            (self.folder / "quick.pg").unlink()

    def test_a_misspelt_name_is_asked_for_and_never_guessed(self):
        calculus = STDLIB / "calculus.rhm"
        named = self.rhema(calculus, "--question", "derivative", "-o", "named.pg")
        self.assertEqual(named.returncode, 0, named.stderr)
        code, screen = self.terminal(calculus, "--question", "derivativ", "-o", "asked.pg", "--no-color",
                                     typed=("derivativ", "7", "2"))
        self.assertEqual(code, 0, screen)
        self.assertEqual(screen.count("is not one of them."), 2)
        self.assertIn("The same as giving --question derivative.", screen)
        self.assertEqual((self.folder / "asked.pg").read_bytes(), (self.folder / "named.pg").read_bytes())
        # three answers that are not on the list, and the command gives up
        code, screen = self.terminal(calculus, "--question", "derivativ", "-o", "none.pg", typed=("x", "y", "z"))
        self.assertEqual(code, 1, screen)
        self.assertFalse((self.folder / "none.pg").exists())

    def test_no_answer_is_the_error_it_always_was(self):
        homework = STDLIB / "homework_set.rhm"
        piped = self.rhema("run", homework, "--run", "nosuch")
        self.assertEqual(piped.returncode, 1)
        self.assertEqual(piped.stdout, "")
        self.assertEqual(piped.stderr.splitlines(),
                         [f"{homework}: error: 'nosuch' is not a set of this file; it has homework, quick"])
        for typed in ((), ("",)):
            code, screen = self.terminal("run", homework, "--run", "nosuch", typed=typed)
            self.assertEqual(code, 1, screen)
            self.assertIn("Which set?", screen)
            self.assertIn(piped.stderr.strip(), screen)
            self.assertNotIn("[3/4]", screen)

    def test_nothing_is_asked_without_a_person(self):
        homework = STDLIB / "homework_set.rhm"
        piped = self.rhema("run", homework)
        self.assertEqual(piped.returncode, 1)
        self.assertNotIn("Which", piped.stderr)
        self.assertEqual(len(piped.stderr.splitlines()), 1)
        # --plain at a terminal asks nothing either, and says the same
        code, screen = self.terminal("--plain", "run", homework)
        self.assertEqual(code, 1)
        self.assertEqual(screen, piped.stderr)
        # input from a file is not a person, even with the screen a terminal
        code, screen = self.terminal("run", homework, person=False)
        self.assertEqual(code, 1, screen)
        self.assertNotIn("Which", screen)
        self.assertIn("Question generation failed", screen)


class HintTests(Base):
    def test_an_option_that_was_meant(self):
        for typed, hint in (("--studnt", "(did you mean --student?)"),
                            ("--cout", "(did you mean --count or --out?)"),
                            ("--answer", "(did you mean --answers?)")):
            result = self.rhema("run", self.signs, typed, "3")
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stderr.splitlines()[0], f"rhema: unknown option {typed} {hint}")
        far = self.rhema("run", self.signs, "--frobnicate")
        self.assertEqual(far.stderr.splitlines()[0], "rhema: unknown option --frobnicate")

    def test_a_command_that_was_meant(self):
        result = self.rhema("chek", self.signs)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stderr.splitlines()[0],
                         "rhema: 'chek' is neither a command nor a file (did you mean check?)")
        # a file of that name is a file
        (self.folder / "chek").write_text(SIGNS, encoding="utf-8")
        both = self.rhema("chek", self.signs)
        self.assertEqual(both.stderr.splitlines()[0], "rhema: one input file at a time (check takes several)")

    def test_webwork_is_named_only_where_pg_was_written(self):
        code, screen = self.terminal(self.signs, "-o", "out.pg")
        self.assertEqual(code, 0, screen)
        self.assertIn("WeBWorK rendering and grading were not run.", screen)
        code, screen = self.terminal(self.signs, "-o", "out.tex")
        self.assertEqual(code, 0, screen)
        self.assertIn("Export LaTeX", screen)
        self.assertIn("   LaTeX ", screen)
        self.assertNotIn("WeBWorK", screen)
        code, screen = self.terminal("run", self.signs)
        self.assertEqual(code, 0, screen)
        self.assertNotIn("WeBWorK", screen)
        bad = self.folder / "bad.rhm"
        bad.write_text("start Q\n", encoding="utf-8")
        code, screen = self.terminal(bad, "-o", "bad.tex")
        self.assertEqual(code, 1, screen)
        self.assertIn("This run did not write a LaTeX file.", screen)


if __name__ == "__main__":
    unittest.main()
