"""Markup contracts for the presentation-only editor restyle."""
import importlib.util
from html.parser import HTMLParser
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
spec = importlib.util.spec_from_file_location('editor_test_app', ROOT / 'app.py')
web = importlib.util.module_from_spec(spec)
spec.loader.exec_module(web)


class Markup(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.ids = {}
        self.stylesheets = []
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            assert attrs['id'] not in self.ids, attrs['id']
            self.ids[attrs['id']] = (tag, attrs)
        if tag == 'link' and attrs.get('rel') == 'stylesheet':
            self.stylesheets.append(attrs['href'])


class EditorUiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.page = web.app.test_client().get('/').get_data(as_text=True)
        cls.markup = Markup(cls.page)

    def test_existing_commands_remain_real_buttons_with_labels(self):
        for name, label in [('rhemaReloadBtn', 'Reload'), ('rhemaCheckBtn', 'Check'), ('rhemaSaveBtn', 'Save')]:
            tag, attrs = self.markup.ids[name]
            self.assertEqual(tag, 'button')
            self.assertEqual(attrs['type'], 'button')
            self.assertRegex(self.page, rf'id="{name}"[^>]*>.*?<span>{label}</span></button>')

    def test_student_identity_and_generation_controls_are_preserved(self):
        tag, attrs = self.markup.ids['studentId']
        self.assertEqual(tag, 'input')
        self.assertEqual(attrs['name'], 'student_id')
        for name in ('studentForm', 'generateQuestionsBtn', 'teacherSave', 'rhemaCount'):
            self.assertIn(name, self.markup.ids)

    def test_editing_and_read_only_surfaces_keep_their_original_ids(self):
        for name in ('rhemaGrammarText', 'output', 'historyOutput', 'originalOutput',
                     'historyOriginalOutput', 'teacherSource', 'pgImportSource'):
            self.assertEqual(self.markup.ids[name][0], 'textarea')
        for name in ('teacherSource', 'pgImportSource', 'output'):
            self.assertIn('readonly', self.markup.ids[name][1])

    def test_runtime_status_and_accessibility_hooks_remain(self):
        for name in ('rhemaSaveState', 'rhemaSaveStateText', 'rhemaCursorPosition',
                     'rhemaDocumentStats', 'rhemaGrammarMessage', 'rhemaLineNumbers', 'rhemaHighlight'):
            self.assertIn(name, self.markup.ids)
        self.assertEqual(self.markup.ids['rhemaGrammarText'][1]['aria-describedby'], 'rhemaEditorHelp')
        self.assertEqual(self.markup.ids['rhemaSaveState'][1]['role'], 'status')

    def test_scoped_theme_loads_after_the_legacy_styles(self):
        sheets = self.markup.stylesheets
        self.assertGreater(sheets.index('/static/code_editor.css'), sheets.index('/static/workspace.css'))
        css = (ROOT / 'static/code_editor.css').read_text()
        for selector in ('.workspace-app .rhema-editor', '.workspace-app textarea.output-textarea',
                         '.workspace-app #teacherGeneratedSource textarea', '.workspace-app #pgImportSource'):
            self.assertIn(selector, css)


if __name__ == '__main__':
    unittest.main()
