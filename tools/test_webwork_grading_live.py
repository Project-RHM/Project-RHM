"""Opt-in regression tests against the locally running official renderer.

Run from the repository root: python tools/test_webwork_grading_live.py
No project configuration is rewritten. Classic output is generated in a temp directory.
"""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT))
from webwork_client import WebworkClient, WebworkClientError  # noqa: E402


def document(body, prelude='Context("Complex");'):
    return ('DOCUMENT();\nloadMacros("PGstandard.pl","MathObjects.pl","PGML.pl");\n'
            + prelude + '\nBEGIN_PGML\n' + body + '\nEND_PGML\nENDDOCUMENT();\n')


VECTOR = 'Vector(Parser::Context->getCopy("Vector"),1,2,3)'
OTHER = 'Vector(Parser::Context->getCopy("Vector"),4,5,6)'
VECTORS = [
    (f'{VECTOR} . {OTHER}', '32', '31'),
    (f'{VECTOR} x {OTHER}', '<-3,6,-3>', '<3,6,-3>'),
    (f'{VECTOR}->norm()', 'sqrt(14)', '14'),
    (f'{VECTOR}->unit()', '<1/sqrt(14),2/sqrt(14),3/sqrt(14)>', '<1,2,3>'),
    (f'{VECTOR}->cmp(parallel=>1)', '<-2,-4,-6>', '<1,2,4>'),
    (f'{VECTOR}->cmp(parallel=>1,sameDirection=>1)', '<2,4,6>', '<-2,-4,-6>'),
]


class LiveGradingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = WebworkClient()

    def assert_no_pg_warnings(self, source):
        payload = self.client._request(source, answers={}).json()
        self.assertFalse(payload.get('flags', {}).get('error_flag'))
        self.assertEqual(payload.get('debug', {}).get('pg_warn'), [])
        return payload

    def test_all_six_vectors_are_context_independent_and_actually_graded(self):
        for context in ('Numeric', 'Interval', 'Vector', 'Complex'):
            for expression, correct, wrong in VECTORS:
                with self.subTest(context=context, expression=expression):
                    source = document('Answer: [_____]{' + expression + '}', f'Context("{context}");')
                    self.assert_no_pg_warnings(source)
                    self.assertEqual(self.client.check(source, {'AnSwEr0001': correct})['score'], 1)
                    self.assertEqual(self.client.check(source, {'AnSwEr0001': wrong})['score'], 0)

    def test_mixed_answer_types_keep_their_own_evaluators(self):
        prelude = '''Context("Numeric");
$derivative = Formula("2*x");
$integral = Formula("x^3");
Context("Interval");
$set_answer = Set(1,2,3);
Context("Complex");
$complex_answer = Complex(2,3);'''
        cases = [('$derivative', 'x+x'), ('$integral', 'x*x*x'),
                 ('$set_answer', '{3,2,1}'), ('$complex_answer', '3i+2'),
                 ('5', '2+3'), ('1', '1'), ('9', '9')]
        cases += [(expression, correct) for expression, correct, _ in VECTORS]
        source = document('\n\n'.join('Answer: [_____]{' + expr + '}' for expr, _ in cases), prelude)
        self.assert_no_pg_warnings(source)
        answers = {f'AnSwEr{i:04d}': correct for i, (_, correct) in enumerate(cases, 1)}
        result = self.client.check(source, answers)
        self.assertEqual(result['score'], 1)
        self.assertEqual(result['correct_count'], len(cases))
        self.assertEqual(self.client.check(source, {name: '0' for name in answers})['score'], 0)

    def test_legacy_broken_mixed_evaluator_is_not_silently_graded(self):
        source = document('Answer: [_____]{Compute("<1,2,3>") . Compute("<4,5,6>")}')
        with self.assertRaises(WebworkClientError) as raised:
            self.client.check(source, {'AnSwEr0001': '32'})
        self.assertEqual(raised.exception.code, 'pg_answer_error')

    def test_actual_classic_mixed_seed_outputs_have_no_pg_warnings(self):
        executable = PROJECT / 'generator/_build/default/unparser.exe'
        for seed in ('12345', '2026103001', '2026103002', '2026103003', '2026103004'):
            with self.subTest(seed=seed), tempfile.TemporaryDirectory(prefix='classic-grading-') as temp:
                (Path(temp) / 'static').symlink_to(PROJECT / 'static', target_is_directory=True)
                subprocess.run([str(executable), seed], cwd=temp, check=True,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=30)
                source = next(Path(temp).glob('generated_questions/*.pg')).read_text()
                self.assert_no_pg_warnings(source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
