"""Exercise grammar creation in an isolated directory with the real checker."""

import importlib.util
import os
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


PROJECT = Path(__file__).resolve().parents[1]
module_spec = importlib.util.spec_from_file_location('grammar_web_app', PROJECT / 'app.py')
web = importlib.util.module_from_spec(module_spec)
sys.modules[module_spec.name] = web
module_spec.loader.exec_module(web)

SOURCE = '''context "Numeric"
random a = integer_between(2, 9)
synth value on Q
start Q
Q -> "number" { value = a }
prompt "Enter the generated value."
answer Q.value
'''


class GrammarCreationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.directory_patch = patch.object(web, 'RHEMA_GRAMMAR_DIR', self.directory.name)
        self.directory_patch.start()
        self.addCleanup(self.directory_patch.stop)
        self.stdlib_patch = patch.object(web, 'RHEMA_STDLIB_DIR', self.directory.name)
        self.stdlib_patch.start()
        self.addCleanup(self.stdlib_patch.stop)
        self.client = web.app.test_client()

    def save(self, name='new_example.rhm', content=SOURCE, create='true'):
        return self.client.post('/rhema_grammar_save', data={
            'name': name, 'content': content, 'create': create,
        })

    def test_create_list_read_and_edit(self):
        response = self.save()
        self.assertTrue(response.json['success'], response.json)
        self.assertEqual((self.root / 'new_example.rhm').read_text(), SOURCE)
        self.assertIn('new_example.rhm', self.client.get('/rhema_grammars').json['grammars'])
        self.assertEqual(self.client.get('/rhema_grammar?name=new_example.rhm').json['content'], SOURCE)
        updated = SOURCE.replace('2, 9', '3, 12')
        self.assertTrue(self.save(content=updated, create='false').json['success'])
        self.assertEqual((self.root / 'new_example.rhm.bak').read_text(), SOURCE)
        self.assertEqual((self.root / 'new_example.rhm').read_text(), updated)

    def test_duplicate_does_not_overwrite(self):
        (self.root / 'new_example.rhm').write_text('original')
        self.assertEqual(self.save().status_code, 409)
        self.assertEqual((self.root / 'new_example.rhm').read_text(), 'original')

    def test_invalid_grammar_creates_nothing(self):
        response = self.save(content='this is not a grammar')
        self.assertFalse(response.json['success'])
        self.assertEqual(list(self.root.iterdir()), [])

    def test_invalid_names(self):
        for name in ('../escape.rhm', '/tmp/escape.rhm', '.hidden.rhm', 'bad/name.rhm',
                     'bad\\name.rhm', 'missing.txt', '', 'a' * 81 + '.rhm'):
            with self.subTest(name=name):
                self.assertEqual(self.save(name=name).status_code, 400)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_create_race_preserves_winner(self):
        real_link = os.link

        def concurrent_create(source, target):
            Path(target).write_text('other request won')
            return real_link(source, target)

        with patch.object(web.os, 'link', side_effect=concurrent_create):
            self.assertEqual(self.save().status_code, 409)
        self.assertEqual((self.root / 'new_example.rhm').read_text(), 'other request won')
        self.assertFalse(list(self.root.glob('.check_*')))

    def test_symlink_cannot_be_overwritten(self):
        original = self.root / 'original.rhm'
        original.write_text('original')
        (self.root / 'new_example.rhm').symlink_to(original)
        self.assertEqual(self.save(create='false').status_code, 400)
        self.assertEqual(original.read_text(), 'original')


if __name__ == '__main__':
    unittest.main()
