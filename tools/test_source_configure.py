"""Source edits become independent, editable form baselines after Save."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from flask import Flask

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from teacher_builder import register_teacher_routes
spec = importlib.util.spec_from_file_location('source_configure_app', ROOT / 'app.py')
web = importlib.util.module_from_spec(spec)
spec.loader.exec_module(web)

SOURCE = '''attribute cost = 1 split
random a = integer_between(2, 9)
synth value on Q
start Q
Q -> "number" when cost = 1 { cost = -1 value = a }
prompt "Original wording."
answer Q.value
width 8
'''


class SourceConfigureTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / 'static').symlink_to(ROOT / 'static', target_is_directory=True)
        generator = self.root / 'generator'
        generator.mkdir()
        self.grammars = generator / 'grammars'
        self.grammars.mkdir()
        (generator / 'stdlib').symlink_to(ROOT / 'generator/stdlib', target_is_directory=True)
        (generator / '_build').symlink_to(ROOT / 'generator/_build', target_is_directory=True)
        (self.grammars / 'base.rhm').write_text(SOURCE)
        for name, value in [('RHEMA_GRAMMAR_DIR', str(self.grammars)),
                            ('RHEMA_STDLIB_DIR', str(generator / 'stdlib'))]:
            active = patch.object(web, name, value)
            active.start()
            self.addCleanup(active.stop)
        application = Flask(__name__)
        register_teacher_routes(application, self.root)
        application.add_url_rule('/rhema_grammar_save', view_func=web.rhema_grammar_save, methods=['POST'])
        application.add_url_rule('/rhema_grammars', view_func=web.rhema_grammars)
        self.client = application.test_client()

    def preset(self):
        result = self.client.post('/teacher/save', json={
            'grammar': 'base.rhm', 'name': 'saved.rhm', 'count': 1,
            'configuration': {'values': {'root:r:a': [2, 2]}}})
        self.assertEqual(result.status_code, 200, result.json)
        return self.grammars / 'saved.rhm'

    def save(self, source):
        return self.client.post('/rhema_grammar_save', data={
            'name': 'saved.rhm', 'create': 'false', 'content': source})

    def test_source_save_rebuilds_form_without_reapplying_old_base(self):
        file = self.preset()
        previous = file.read_text()
        edited = previous.replace('Original wording.', 'Edited wording.').replace('value = a', 'value = a + 1')
        result = self.save(edited)
        self.assertTrue(result.json['success'], result.json)
        self.assertTrue(result.json['configure_ready'])
        schema = self.client.get('/teacher/schema?grammar=saved.rhm')
        self.assertEqual(schema.status_code, 200, schema.json)
        self.assertIsNone(schema.json['configuration'])
        field = next(f for f in schema.json['schema']['fields'] if f['id'] == 'root:r:a')
        self.assertEqual(field['value'], [2, 2])
        (self.grammars / 'base.rhm').write_text(SOURCE.replace('value = a', 'value = a + 99'))
        generated = self.client.post('/teacher/generate', json={'grammar': 'saved.rhm', 'configuration': {}, 'count': 1})
        self.assertEqual(generated.status_code, 200, generated.json)
        self.assertEqual(generated.json['preview'][0]['answer'], '3')
        self.assertIn('Edited wording.', generated.json['pgml_code'])
        self.assertEqual((self.grammars / 'saved.rhm.bak').read_text(), previous)
        self.assertTrue(list((self.grammars / '.teacher/history/saved.rhm').glob('*/configuration.json')))
        self.assertTrue(list((self.grammars / '.teacher/history/saved.rhm').glob('*/source.rhm')))

    def test_invalid_save_preserves_source_and_metadata(self):
        file = self.preset()
        record = self.grammars / '.teacher/saved.rhm.json'
        before = file.read_bytes(), record.read_bytes()
        self.assertFalse(self.save('not a grammar').json['success'])
        self.assertEqual((file.read_bytes(), record.read_bytes()), before)

    def test_external_edits_still_require_explicit_source_save(self):
        file = self.preset()
        edited = file.read_text() + '\n# External edit\n'
        file.write_text(edited)
        self.assertEqual(self.client.get('/teacher/schema?grammar=saved.rhm').status_code, 400)
        self.assertTrue(self.save(edited).json['success'])
        self.assertEqual(self.client.get('/teacher/schema?grammar=saved.rhm').status_code, 200)

    def test_refresh_failure_rolls_back_source(self):
        file = self.preset()
        before = file.read_bytes()
        with patch.object(web, 'refresh_source_configuration', side_effect=OSError('disk full')):
            self.assertEqual(self.save(file.read_text() + '\n# Change\n').status_code, 500)
        self.assertEqual(file.read_bytes(), before)

    def test_catalog_distinguishes_source_types_and_presets(self):
        file = self.preset()
        catalog = {x['name']: x for x in self.client.get('/rhema_grammars').json['catalog']}
        self.assertFalse(catalog['base.rhm']['preset'])
        self.assertTrue(catalog['saved.rhm']['preset'])
        self.assertTrue(self.save(file.read_text() + '\n# New source baseline\n').json['success'])
        catalog = {x['name']: x for x in self.client.get('/rhema_grammars').json['catalog']}
        self.assertFalse(catalog['saved.rhm']['preset'])

    def test_completion_inventory_comes_from_compiler(self):
        response = self.client.get('/teacher/completions')
        self.assertEqual(response.status_code, 200, response.json)
        self.assertEqual(len(response.json['keywords']), 28)
        functions = {x['name']: x for x in response.json['functions']}
        self.assertEqual(functions['bool_and']['arity'], 2)
        self.assertEqual(functions['bool_var']['arity'], 1)
        self.assertIn('matrix_inverse', functions)
        self.assertIn('integer_between', functions)


if __name__ == '__main__':
    unittest.main()
