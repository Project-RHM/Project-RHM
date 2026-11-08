"""Exercise the formal Boolean demo through the same routes as Configure."""
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from flask import Flask

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from teacher_builder import register_teacher_routes


class BooleanDemoTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / 'static').symlink_to(ROOT / 'static', target_is_directory=True)
        generator = self.root / 'generator'
        grammars = generator / 'grammars'
        grammars.mkdir(parents=True)
        for name in ('stdlib', '_build'):
            (generator / name).symlink_to(ROOT / 'generator' / name, target_is_directory=True)
        self.grammar = 'boolean_demo_flexible.rhm'
        shutil.copyfile(ROOT / 'generator/grammars' / self.grammar, grammars / self.grammar)
        application = Flask(__name__)
        register_teacher_routes(application, self.root)
        self.client = application.test_client()
        self.schema = self.client.get('/teacher/schema', query_string={'grammar': self.grammar}).json['schema']

    def generate(self, values=None, **configuration):
        return self.client.post('/teacher/generate', json={
            'grammar': self.grammar, 'count': 3, 'student_id': 'DEMO',
            'configuration': {'values': values or {}, **configuration}})

    def test_schema_exposes_real_ranges_and_english_operator_lengths(self):
        fields = {field['name']: field for field in self.schema['fields'] if field['kind'] == 'integer'}
        self.assertEqual((fields['cost']['minimum'], fields['cost']['maximum']), (1, 10))
        self.assertEqual(fields['variables_mode']['allowed'], [2, 3, 4])
        self.assertEqual(fields['quality_mode']['allowed'], [0, 1])
        self.assertTrue(self.schema['length_supported'])
        self.assertTrue(all(field['minimum'] == 1 for field in self.schema['fields'] if field['kind'] == 'price'))

    def test_default_budgets_variable_pools_and_replay(self):
        for variables in (2, 3, 4):
            for cost in (1, 3, 6, 10):
                with self.subTest(variables=variables, cost=cost):
                    response = self.generate({'root:a:cost': cost, 'root:a:variables_mode': variables},
                                             min_length=cost, max_length=cost)
                    self.assertEqual(response.status_code, 200, response.json)
                    self.assertEqual([q['operator_count'] for q in response.json['preview']], [cost] * 3)
                    expected = [q['answer'] for q in response.json['preview']]
                    self.assertTrue(all(answer in ('0', '1') for answer in expected))
        first = self.generate()
        second = self.generate()
        self.assertEqual(first.json['pgml_code'], second.json['pgml_code'])

    def test_restrictions_and_fixed_truth_assignments_are_respected(self):
        values = {'root:a:cost': 6, 'root:a:variables_mode': 4, 'root:a:negation_limit': 0,
                  'root:b:p_value': 'true', 'root:b:q_value': 'false'}
        result = self.generate(values, min_length=6, max_length=6)
        self.assertEqual(result.status_code, 200, result.json)
        self.assertEqual([q['operator_count'] for q in result.json['preview']], [6] * 3)
        self.assertIn('p = 1', result.json['pgml_code'])
        self.assertIn('q = 0', result.json['pgml_code'])
        self.assertNotIn('\\neg', result.json['pgml_code'])
        for operator in ('XOR', 'NOT'):
            rule = next(field for field in self.schema['fields'] if field['kind'] == 'weight'
                        and operator in field['rule'].split())
            values[rule['id']] = 0
        values['root:a:cost'] = 2
        values['root:a:variables_mode'] = 3
        result = self.generate(values)
        self.assertEqual(result.status_code, 200, result.json)
        self.assertNotIn('"XOR"', result.json['source'])
        self.assertNotIn('"NOT"', result.json['source'])
        self.assertNotIn('\\oplus', result.json['pgml_code'])

    def test_incompatible_settings_fail_without_silent_changes(self):
        for values in ({'root:a:cost': 0}, {'root:a:cost': 11}, {'root:a:variables_mode': 5}):
            with self.subTest(values=values):
                response = self.generate(values)
                self.assertEqual(response.status_code, 400, response.json)
        response = self.generate({'root:a:cost': 2}, min_length=3, max_length=3)
        self.assertEqual(response.status_code, 400, response.json)
        self.assertIn('not compatible', response.json['error'])
        self.assertIn('Constraint:', response.json['error'])


if __name__ == '__main__':
    unittest.main()
