"""History identity tests use disposable output folders and the real Rhema runtime."""
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch

from flask import Flask

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from generation_history import list_records, output_stem, record_for, write_record
from teacher_builder import register_teacher_routes

spec = importlib.util.spec_from_file_location('history_test_app', ROOT / 'app.py')
web = importlib.util.module_from_spec(spec)
spec.loader.exec_module(web)


class HistoryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.generator = self.root / 'generator'
        self.output = self.generator / 'generated_questions'
        self.output.mkdir(parents=True)

    def pg(self, name):
        file = self.output / name
        file.write_text('DOCUMENT();\nENDDOCUMENT();\n')
        return file

    def metadata(self, file, student):
        write_record(self.generator, file, student_id=student, generator='rhema_configure',
                     grammar='boolean.rhm', question='main', count=2)

    def test_explicit_student_overrides_any_internal_filename(self):
        file = self.pg('teacher_20261107_120000_abcdef1234.pg')
        before = file.read_bytes()
        self.metadata(file, 'DEMO_STUDENT_01')
        record = record_for(self.generator, file.name)
        self.assertEqual(record['student_id'], 'DEMO_STUDENT_01')
        self.assertEqual(record['display_name'], 'DEMO_STUDENT_01')
        self.assertEqual(record['grammar'], 'boolean.rhm')
        self.assertEqual(file.read_bytes(), before)
        self.assertEqual(stat.S_IMODE(file.with_suffix('.meta.json').stat().st_mode), 0o600)

    def test_explicit_no_student_is_shared_not_teacher(self):
        file = self.pg('teacher_20261107_120000_abcdef1234.pg')
        self.metadata(file, '')
        record = record_for(self.generator, file.name)
        self.assertIsNone(record['student_id'])
        self.assertEqual(record['display_name'], 'Shared worksheet')
        self.assertEqual(record['identity_status'], 'recorded')

    def test_reserved_filename_words_are_valid_explicit_student_ids(self):
        for identity in ('teacher', 'assignment', 'worksheet'):
            file = self.pg(f'{identity}_20261107_120000.pg')
            self.metadata(file, identity)
            self.assertEqual(record_for(self.generator, file.name)['student_id'], identity)

    def test_legacy_names_preserve_underscores_and_sort_by_real_time(self):
        self.pg('FYP_STYLE_TEST_20261102_232709.pg')
        self.pg('234567891_20261107_150342.pg')
        records = list_records(self.generator)
        self.assertEqual(records[0]['student_id'], '234567891')
        self.assertEqual(records[1]['student_id'], 'FYP_STYLE_TEST')
        self.assertEqual(records[1]['timestamp'], '2026-11-02 23:27:09')

    def test_legacy_teacher_identity_is_not_invented(self):
        file = self.pg('teacher_20261107_120000_abcdef1234.pg')
        record = record_for(self.generator, file.name)
        self.assertIsNone(record['student_id'])
        self.assertEqual(record['display_name'], 'Legacy worksheet')

    def test_legacy_assignment_is_shared_and_classic_id_is_unchanged(self):
        for prefix, expected in [('assignment', None), ('worksheet', None), ('2330026069', '2330026069')]:
            file = self.pg(f'{prefix}_20261107_120000.pg')
            record = record_for(self.generator, file.name)
            self.assertEqual(record['student_id'], expected)
            if expected is None:
                self.assertEqual(record['display_name'], 'Shared worksheet')

    def test_bad_metadata_falls_back_without_breaking_history(self):
        file = self.pg('2330026069_20261107_120000.pg')
        self.metadata(file, '2330026069')
        valid = json.loads(file.with_suffix('.meta.json').read_text())
        cases = ['{', '[]', 'x' * 16385]
        for changes in ({'student_id': '../../private'}, {'created_at': 'invalid'},
                        {'filename': 'other.pg'}, {'generator': 'unknown'}):
            cases.append(json.dumps({**valid, **changes}))
        for raw in cases:
            file.with_suffix('.meta.json').write_text(raw)
            self.assertEqual(list_records(self.generator)[0]['student_id'], '2330026069')

    def test_files_without_valid_dates_use_numeric_mtime(self):
        file = self.pg('export.pg')
        os.utime(file, (1767225600, 1767225600))
        record = record_for(self.generator, file.name)
        self.assertIsInstance(record['sort_timestamp'], float)
        self.assertEqual(record['display_name'], 'Legacy worksheet')

    def test_output_names_are_unique_without_touching_seed_inputs(self):
        first, second = output_stem('STUDENT_A_01'), output_stem('STUDENT_A_01')
        self.assertNotEqual(first, second)
        self.assertTrue(first.startswith('STUDENT_A_01_'))
        self.assertTrue(output_stem('').startswith('worksheet_'))

    def test_symlinks_and_paths_outside_output_are_not_followed(self):
        file = self.pg('2330026069_20261107_120000.pg')
        outside = self.root / 'outside.pg'
        outside.write_text('not a history record')
        (self.output / 'link.pg').symlink_to(outside)
        file.with_suffix('.meta.json').symlink_to(outside)
        self.assertEqual(len(list_records(self.generator)), 1)
        self.assertIsNone(record_for(self.generator, '../outside.pg'))
        with self.assertRaises(ValueError):
            write_record(self.generator, outside, student_id='', generator='rhema_source',
                         grammar='arithmetic.rhm', question='main', count=1)


class HistoryRouteTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / 'static').symlink_to(ROOT / 'static', target_is_directory=True)
        self.generator = self.root / 'generator'
        self.generator.mkdir()
        (self.generator / 'grammars').mkdir()
        for name in ('stdlib', '_build'):
            (self.generator / name).symlink_to(ROOT / 'generator' / name, target_is_directory=True)
        values = {'OCAML_PROJECT_DIR': str(self.generator),
                  'RHEMA_GRAMMAR_DIR': str(self.generator / 'grammars'),
                  'RHEMA_STDLIB_DIR': str(self.generator / 'stdlib'),
                  'RHEMA_COMMAND': str(ROOT / 'generator/_build/install/default/bin/rhema')}
        for name, value in values.items():
            active = patch.object(web, name, value)
            active.start()
            self.addCleanup(active.stop)
        active = patch.object(web, 'read_config', return_value={})
        active.start(); self.addCleanup(active.stop)
        app = Flask(__name__)
        register_teacher_routes(app, self.root)
        app.add_url_rule('/run_rhema', view_func=web.run_rhema, methods=['POST'])
        app.add_url_rule('/history', view_func=web.get_history)
        app.add_url_rule('/history_content', view_func=web.get_history_content)
        self.client = app.test_client()

    def generate(self, route, student):
        payload = {'grammar': 'arithmetic.rhm', 'student_id': student, 'count': 2}
        response = self.client.post(route, **({'json': payload} if route.startswith('/teacher') else {'data': payload}))
        self.assertEqual(response.status_code, 200, response.json)
        self.assertTrue(response.json['success'], response.json)
        return response.json

    def test_configure_and_source_store_and_display_student_or_shared(self):
        for route in ('/teacher/generate', '/run_rhema'):
            for student in ('STUDENT_A_01', ''):
                with self.subTest(route=route, student=student):
                    result = self.generate(route, student)
                    filename = Path(result['pgml_path']).name
                    history = self.client.get('/history').json['history']
                    record = next(item for item in history if item['filename'] == filename)
                    self.assertEqual(record['student_id'], student or None)
                    self.assertEqual(record['display_name'], student or 'Shared worksheet')
                    self.assertEqual(record['grammar'], 'arithmetic.rhm')
                    detail = self.client.get('/history_content', query_string={'filename': filename}).json
                    self.assertEqual(detail['history']['student_id'], student or None)
                    self.assertTrue(detail['has_ast'])
                    self.assertTrue(detail['has_visualization'])

    def test_new_output_names_do_not_change_deterministic_generation(self):
        for route in ('/teacher/generate', '/run_rhema'):
            first = self.generate(route, 'STUDENT_A_01')
            second = self.generate(route, 'STUDENT_A_01')
            self.assertEqual(first['pgml_code'], second['pgml_code'])
            self.assertNotEqual(first['pgml_path'], second['pgml_path'])

    def test_saving_a_preset_does_not_leave_trial_history(self):
        response = self.client.post('/teacher/save', json={'grammar': 'arithmetic.rhm', 'name': 'trial.rhm', 'count': 1})
        self.assertEqual(response.status_code, 200, response.json)
        self.assertEqual(self.client.get('/history').json['history'], [])
        self.assertEqual(list((self.generator / 'generated_questions').glob('*.meta.json')), [])


if __name__ == '__main__':
    unittest.main()
