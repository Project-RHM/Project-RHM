"""Exercise form authoring against the real Rhema runtime in disposable folders.

Run after dune build: python -m unittest discover -s tools -p test_teacher_builder.py -v
"""
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

from flask import Flask

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from teacher_builder import TITLES, register_teacher_routes


class TeacherBuilderTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'static').symlink_to(ROOT / 'static', target_is_directory=True)
        generator = self.root / 'generator'
        generator.mkdir()
        (generator / 'stdlib').symlink_to(ROOT / 'generator/stdlib', target_is_directory=True)
        (generator / '_build').symlink_to(ROOT / 'generator/_build', target_is_directory=True)
        application = Flask(__name__)
        application.config['TESTING'] = True
        register_teacher_routes(application, self.root)
        self.client = application.test_client()

    def generate(self, grammar='arithmetic.rhm', configuration=None, **extra):
        response = self.client.post('/teacher/generate', json={
            'grammar': grammar, 'configuration': configuration or {}, 'count': 2,
            'student_id': 'TEST', **extra})
        self.assertEqual(response.status_code, 200, response.get_json())
        return response.get_json()

    def test_all_standard_grammars_and_named_questions(self):
        before = {p.name: p.read_bytes() for p in (ROOT / 'generator/stdlib').glob('*.rhm')}
        for name in TITLES:
            grammar = name + '.rhm'
            with self.subTest(grammar=grammar):
                result = self.client.get('/teacher/schema', query_string={'grammar': grammar})
                self.assertEqual(result.status_code, 200, result.get_json())
                schema = result.get_json()['schema']
                self.assertTrue(schema['fields'])
                for question in schema['questions']:
                    values = {'root:a:' + n: v for n, v in question['initials'].items()}
                    data = self.generate(grammar, {'values': values}, count=1, question=question['name'])
                    self.assertIn('BEGIN_PGML', data['pgml_code'])
                    self.assertTrue(data['preview'][0]['pieces'])
        self.assertEqual(before, {p.name: p.read_bytes() for p in (ROOT / 'generator/stdlib').glob('*.rhm')})

    def test_length_bounds_and_typed_preview(self):
        data = self.generate(configuration={'min_length': 3, 'max_length': 3}, count=4)
        self.assertEqual([q['operator_count'] for q in data['preview']], [3] * 4)
        self.assertIn('Teacher_E', data['source'])
        imported = self.generate('derivative_or_boolean.rhm', {'min_length': 0, 'max_length': 30})
        self.assertTrue(all(q['operator_count'] is not None for q in imported['preview']))

    def test_ranges_weights_and_assignments_change_actual_generation(self):
        schema = self.client.get('/teacher/schema?grammar=sequence.rhm').get_json()['schema']
        value = self.generate('sequence.rhm', {'values': {
            'root:a:cost': 1, 'root:r:first': [2, 2], 'root:r:difference': [3, 3], 'root:r:index': [4, 4]}})
        self.assertEqual(value['preview'][0]['answer'], '11')
        repriced=self.generate('sequence.rhm', {'values': {
            'root:a:cost':5,'root:rule:0:cost':5,'root:r:first':[2,2],
            'root:r:difference':[3,3],'root:r:index':[4,4]}})
        self.assertEqual(repriced['preview'][0]['answer'],'11')
        self.assertTrue(next(f for f in schema['fields'] if f['id']=='root:a:cost')['allowed'])
        schema = self.client.get('/teacher/schema?grammar=arithmetic.rhm').get_json()['schema']
        values = {f['id']: 0 for f in schema['fields'] if f['kind']=='weight' and any(
            op in f['rule'].split() for op in ['-', '*', '/'])}
        result = self.generate(configuration={'values': values}, count=4)
        self.assertNotIn('E - E', result['source'])
        self.assertNotIn('E * E', result['source'])
        repeat = self.generate(configuration={'values': values}, count=4)
        self.assertEqual(result['pgml_code'], repeat['pgml_code'])

    def test_save_reopen_export_and_source_edit_detection(self):
        payload = {'grammar':'logic_forms.rhm', 'configuration':{}, 'name':'my_logic.rhm', 'count':1}
        response = self.client.post('/teacher/save', json=payload)
        self.assertEqual(response.status_code, 200, response.get_json())
        saved = self.client.get('/teacher/schema?grammar=my_logic.rhm').get_json()
        self.assertTrue(saved['success'])
        self.assertIsNotNone(saved['configuration'])
        self.generate('my_logic.rhm', saved['configuration'], count=1)
        exported = self.client.post('/teacher/export', json={'grammar':'my_logic.rhm','configuration':saved['configuration']})
        self.assertEqual(exported.status_code, 200)
        with zipfile.ZipFile(io.BytesIO(exported.data)) as bundle:
            self.assertIn('main.rhm', bundle.namelist())
            self.assertTrue(any(n.startswith('module_') for n in bundle.namelist()))
        duplicate = self.client.post('/teacher/save', json=payload)
        self.assertEqual(duplicate.status_code, 400)
        with (self.root / 'generator/grammars/my_logic.rhm').open('a') as source:
            source.write('\n# Edited by the author\n')
        edited = self.client.get('/teacher/schema?grammar=my_logic.rhm')
        self.assertEqual(edited.status_code, 400)
        self.assertIn('source mode', edited.get_json()['error'])

    def test_invalid_or_impossible_settings_are_rejected(self):
        for config in [
            {'min_length':5, 'max_length':2}, {'width':0},
            {'values':{'unknown':3}}, {'values':{'root:a:cost':True}},
        ]:
            with self.subTest(config=config):
                response=self.client.post('/teacher/generate',json={'grammar':'arithmetic.rhm','configuration':config})
                self.assertEqual(response.status_code,400)
                self.assertFalse(response.get_json()['success'])
        response=self.client.post('/teacher/generate',json={'grammar':'sequence.rhm','configuration':{
            'values':{'root:r:difference':[0,0]}}})
        self.assertEqual(response.status_code,400)
        response=self.client.post('/teacher/generate',json={'grammar':'sequence.rhm','configuration':{
            'values':{'root:a:cost':4}}})
        self.assertEqual(response.status_code,400)
        response=self.client.post('/teacher/generate',json={'grammar':'../app.py','configuration':{}})
        self.assertEqual(response.status_code,400)


if __name__ == '__main__':
    unittest.main()
