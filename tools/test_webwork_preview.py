"""Unit and Flask-route tests for the WeBWorK preview integration."""

import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

import requests


PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT))

from webwork_client import (  # noqa: E402
    WebworkClient,
    WebworkClientError,
    WebworkConfig,
)


APP_SPEC = importlib.util.spec_from_file_location("preview_web_app", PROJECT / "app.py")
web = importlib.util.module_from_spec(APP_SPEC)
sys.modules[APP_SPEC.name] = web
APP_SPEC.loader.exec_module(web)


SOURCE = """DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");
BEGIN_PGML
What is [`1+1`]? [_____]{2}
END_PGML
ENDDOCUMENT();
"""


def response(text="<html><body>Rendered</body></html>", status=200, payload=None):
    result = Mock()
    result.status_code = status
    result.text = text
    result.content = text.encode("utf-8")
    result.json.side_effect = ValueError if payload is None else None
    if payload is not None:
        result.json.return_value = payload
    return result


class WebworkClientTests(unittest.TestCase):
    def test_renderer_connection_does_not_inherit_workstation_proxies(self):
        with patch.dict('os.environ', {'HTTP_PROXY':'http://127.0.0.1:1082',
                                      'ALL_PROXY':'http://127.0.0.1:1082'}):
            client = WebworkClient(WebworkConfig())
            self.assertFalse(client.session.trust_env)
            settings = client.session.merge_environment_settings(client.config.url, {}, None, None, None)
            self.assertEqual(settings['proxies'], {})
            client.session.close()

    def make_client(self, **overrides):
        config = WebworkConfig(
            url=overrides.pop("url", "http://renderer.test/render-api"),
            enabled=overrides.pop("enabled", True),
            timeout_seconds=overrides.pop("timeout_seconds", 3),
            max_source_bytes=overrides.pop("max_source_bytes", 1024),
            max_response_bytes=overrides.pop("max_response_bytes", 4096),
            **overrides,
        )
        session = Mock()
        session.post.return_value = response()
        return WebworkClient(config, session=session), session

    def test_render_posts_source_with_fixed_safe_options(self):
        client, session = self.make_client()

        rendered = client.render(SOURCE, 17)

        self.assertIn("Rendered", rendered)
        session.post.assert_called_once()
        args, kwargs = session.post.call_args
        self.assertEqual(args[0], "http://renderer.test/render-api")
        self.assertEqual(kwargs["timeout"], 3)
        self.assertEqual(kwargs["data"]["problemSource"], SOURCE)
        self.assertEqual(kwargs["data"]["problemSeed"], "17")
        self.assertEqual(kwargs["data"]["outputFormat"], "static")
        self.assertEqual(kwargs["data"]["baseURL"], "http://renderer.test/")
        self.assertEqual(kwargs["data"]["isInstructor"], "0")
        self.assertEqual(kwargs["data"]["showSolutions"], "0")
        self.assertNotIn("problemSourceURL", kwargs["data"])
        self.assertNotIn("sourceFilePath", kwargs["data"])

    def test_rejects_missing_or_incomplete_source_before_network(self):
        client, session = self.make_client()
        for source_value, expected_code in [
            ("", "missing_source"),
            ("BEGIN_PGML\nhello\nEND_PGML", "incomplete_document"),
        ]:
            with self.subTest(source=source_value):
                with self.assertRaises(WebworkClientError) as raised:
                    client.render(source_value)
                self.assertEqual(raised.exception.code, expected_code)
        session.post.assert_not_called()

    def test_rejects_oversized_source_and_invalid_seed(self):
        client, session = self.make_client(max_source_bytes=64)
        with self.assertRaises(WebworkClientError) as raised:
            client.render(SOURCE)
        self.assertEqual(raised.exception.http_status, 413)

        client, session = self.make_client()
        for seed in (0, "not-a-number", True):
            with self.subTest(seed=seed):
                with self.assertRaises(WebworkClientError) as raised:
                    client.render(SOURCE, seed)
                self.assertEqual(raised.exception.code, "invalid_seed")
        session.post.assert_not_called()

    def test_maps_timeout_and_connection_errors(self):
        for upstream_error, expected_code, expected_status in [
            (requests.Timeout(), "renderer_timeout", 504),
            (requests.ConnectionError(), "renderer_unavailable", 502),
        ]:
            with self.subTest(error=type(upstream_error).__name__):
                client, session = self.make_client()
                session.post.side_effect = upstream_error
                with self.assertRaises(WebworkClientError) as raised:
                    client.render(SOURCE)
                self.assertEqual(raised.exception.code, expected_code)
                self.assertEqual(raised.exception.http_status, expected_status)

    def test_maps_upstream_errors_without_returning_markup(self):
        client, session = self.make_client()
        session.post.return_value = response(
            "<h1>PG syntax error</h1><script>ignored()</script>", status=400
        )
        with self.assertRaises(WebworkClientError) as raised:
            client.render(SOURCE)
        self.assertEqual(raised.exception.http_status, 422)
        self.assertNotIn("<h1>", str(raised.exception))
        self.assertIn("PG syntax error", str(raised.exception))

    def test_pg_error_page_is_not_a_successful_render(self):
        client, session = self.make_client()
        session.post.return_value = response('<html><h3>Translator errors</h3><code>bad PG</code></html>')
        with self.assertRaises(WebworkClientError) as raised:
            client.render(SOURCE)
        self.assertEqual(raised.exception.code, 'pg_compile_error')
        self.assertEqual(raised.exception.http_status, 422)

    def test_warnings_do_not_hide_valid_questions(self):
        client, session = self.make_client()
        session.post.return_value = response('<html><h3>Warning messages</h3><div id="problem_body">ok</div></html>')
        self.assertIn('problem_body', client.render(SOURCE))

    def grade_response(self, **overrides):
        return {
            'JWT': {'answer': 'private-token'},
            'renderedHTML': '<html>private grader page</html>',
            'debug': {'pg_warn': []},
            'flags': {'ANSWER_ENTRY_ORDER': ['AnSwEr0001']},
            'problem_result': {'score': 0.5, 'errors': ''},
            'answers': {'AnSwEr0001': {'score': 0.5,
                'correct_ans': 'private-correct-answer', 'correct_value': 'private-value',
                'ans_message': '<span>Check &lt;x&gt;.</span>'}},
            **overrides,
        }

    def test_check_whitelists_scores_and_plain_feedback(self):
        client, session = self.make_client()
        session.post.return_value = response(payload=self.grade_response())
        result = client.check(SOURCE, {'AnSwEr0001': '2'}, 17)
        self.assertEqual(result, {'score': 0.5, 'correct_count': 0, 'answer_count': 1,
            'answers': [{'name': 'AnSwEr0001', 'score': 0.5, 'correct': False,
                         'feedback': 'Check <x>.'}]})
        self.assertNotIn('private', str(result))
        data = session.post.call_args.kwargs['data']
        self.assertEqual(data['submitAnswers'], '1')
        self.assertEqual(data['problemSeed'], '17')
        self.assertEqual(data['AnSwEr0001'], '2')
        self.assertNotIn('showCorrectAnswers', data)

    def test_check_rejects_non_answer_parameters_before_network(self):
        client, session = self.make_client()
        for answers in (None, [], {}, {'isInstructor': '1'}, {'sessionJWT': 'x'},
                        {'AnSwEr0001': 2}, {'AnSwEr0001': ['2']}, {'AnSwEr0001x': '2'}):
            with self.subTest(answers=answers):
                with self.assertRaises(WebworkClientError) as raised:
                    client.check(SOURCE, answers)
                self.assertEqual(raised.exception.code, 'invalid_answers')
        session.post.assert_not_called()

    def test_check_limits_answer_size_and_field_count(self):
        client, session = self.make_client()
        for answers in ({'AnSwEr0001': 'x' * 4097},
                        {f'AnSwEr{i:04d}': '' for i in range(1001)}):
            with self.assertRaises(WebworkClientError):
                client.check(SOURCE, answers)
        session.post.assert_not_called()

    def test_check_does_not_grade_broken_pgml_answer_evaluators(self):
        client, session = self.make_client()
        for payload in (self.grade_response(debug={'pg_warn': ["Error parsing answer: 'Compute' is not defined"]}),
                        self.grade_response(flags={'error_flag': 1}),
                        self.grade_response(problem_result={'errors': 'bad PG'})):
            session.post.return_value = response(payload=payload)
            with self.assertRaises(WebworkClientError) as raised:
                client.check(SOURCE, {'AnSwEr0001': '2'})
            self.assertIn(raised.exception.code, ('pg_answer_error', 'pg_compile_error'))

    def test_check_rejects_unknown_fields_or_missing_grades(self):
        client, session = self.make_client()
        for payload, answers in ((self.grade_response(), {'AnSwEr9999': '2'}),
                                 (self.grade_response(answers={}), {'AnSwEr0001': '2'}),
                                 (self.grade_response(problem_result={'score': 'NaN'}), {'AnSwEr0001': '2'})):
            session.post.return_value = response(payload=payload)
            with self.assertRaises(WebworkClientError):
                client.check(SOURCE, answers)

    def test_check_handles_invalid_json_and_network_errors(self):
        client, session = self.make_client()
        with self.assertRaises(WebworkClientError) as raised:
            client.check(SOURCE, {'AnSwEr0001': '2'})
        self.assertEqual(raised.exception.code, 'invalid_grade')
        session.post.side_effect = requests.Timeout()
        with self.assertRaises(WebworkClientError) as raised:
            client.check(SOURCE, {'AnSwEr0001': '2'})
        self.assertEqual(raised.exception.code, 'renderer_timeout')


class WebworkRouteTests(unittest.TestCase):
    def setUp(self):
        web.app.config.update(TESTING=True)
        self.client = web.app.test_client()

    def test_render_route_returns_html(self):
        with patch.object(web.WEBWORK_CLIENT, "render", return_value="<html>ok</html>") as render:
            result = self.client.post(
                "/api/webwork/render",
                json={"pg_source": SOURCE, "problem_seed": 23},
            )
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.get_json(), {"success": True, "html": "<html>ok</html>"})
        render.assert_called_once_with(SOURCE, 23)

    def test_render_route_preserves_safe_error_status(self):
        error = WebworkClientError(
            "Renderer is offline.", code="renderer_unavailable", http_status=502
        )
        with patch.object(web.WEBWORK_CLIENT, "render", side_effect=error):
            result = self.client.post("/api/webwork/render", json={"pg_source": SOURCE})
        self.assertEqual(result.status_code, 502)
        self.assertEqual(result.get_json()["code"], "renderer_unavailable")
        self.assertFalse(result.get_json()["success"])

    def test_render_route_rejects_non_object_json(self):
        result = self.client.post("/api/webwork/render", json=[SOURCE])
        self.assertEqual(result.status_code, 400)
        self.assertEqual(result.get_json()["code"], "invalid_request")

    def test_check_route_only_forwards_source_seed_and_answers(self):
        with patch.object(web.WEBWORK_CLIENT, 'check', return_value={'score': 1}) as check:
            result = self.client.post('/api/webwork/check', json={
                'pg_source': SOURCE, 'problem_seed': 23, 'answers': {'AnSwEr0001': '2'},
                'isInstructor': 1, 'showCorrectAnswers': 1, 'renderer_url': 'http://example.test'})
        self.assertEqual(result.get_json(), {'success': True, 'score': 1})
        check.assert_called_once_with(SOURCE, {'AnSwEr0001': '2'}, 23)

    def test_check_route_rejects_bad_request_and_preserves_errors(self):
        self.assertEqual(self.client.post('/api/webwork/check', json=[]).status_code, 400)
        with patch.object(web.WEBWORK_CLIENT, 'check', side_effect=WebworkClientError(
                'Bad evaluator', code='pg_answer_error', http_status=422)):
            result = self.client.post('/api/webwork/check', json={'pg_source': SOURCE})
        self.assertEqual(result.status_code, 422)
        self.assertEqual(result.get_json()['code'], 'pg_answer_error')

    def test_status_route_reports_availability(self):
        status = {"available": True, "enabled": True, "message": "Renderer is available."}
        with patch.object(web.WEBWORK_CLIENT, "status", return_value=status):
            result = self.client.get("/api/webwork/status")
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.get_json(), status)

    def test_catalog_preserves_filenames_and_exposes_teacher_titles(self):
        result = self.client.get('/rhema_grammars')
        payload = result.get_json()
        self.assertEqual(result.status_code, 200)
        catalog = {item['name']: item for item in payload['catalog']}
        self.assertEqual(set(catalog), set(payload['grammars']))
        self.assertEqual(catalog['sequence.rhm']['title'], 'Sequences')
        self.assertFalse(catalog['sequence.rhm']['custom'])

    def test_workspace_keeps_source_mode_and_language_switch(self):
        page = self.client.get('/').get_data(as_text=True)
        for identity in ('grammarCatalog', 'languageToggle', 'teacherFormMode',
                         'teacherSourceMode', 'generatedLocalPreview', 'previewPlaceholder'):
            self.assertIn(f'id="{identity}"', page)
        self.assertIn('workspace.js', page)
        self.assertIn('i18n.js', page)

    def test_workspace_has_an_accessible_panel_divider(self):
        page = self.client.get('/').get_data(as_text=True)
        self.assertIn('id="workspaceDivider"', page)
        self.assertIn('role="separator"', page)
        self.assertIn('aria-orientation="vertical"', page)
        self.assertIn('aria-controls="studentForm previewWorkspace"', page)
        self.assertIn('workspace_splitter.js', page)

    def test_answer_bridge_preserves_frame_isolation(self):
        script = (PROJECT / 'static/webwork_preview.js').read_text(encoding='utf-8')
        self.assertIn("event.source !== elements.frame.contentWindow", script)
        self.assertIn("message.token !== state.token", script)
        self.assertIn("fetch('/api/webwork/check'", script)
        self.assertNotIn('contentDocument', script)
        page = self.client.get('/').get_data(as_text=True)
        self.assertNotIn('allow-same-origin', page)
        self.assertNotIn('allow-forms', page)

    def test_main_page_contains_sandboxed_preview_for_both_result_areas(self):
        result = self.client.get("/")
        page = result.get_data(as_text=True)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(page.count('data-view="rendered"'), 2)
        self.assertIn('id="generatedRenderedFrame"', page)
        self.assertIn('id="historyRenderedFrame"', page)
        self.assertEqual(page.count('sandbox="allow-scripts"'), 2)
        self.assertIn('webwork_preview.js', page)
        self.assertIn('id="generatedCheckAnswers"', page)
        self.assertIn('id="historyCheckAnswers"', page)
        script = (PROJECT / 'static/webwork_preview.js').read_text(encoding='utf-8')
        self.assertIn("fetch('/api/webwork/render'", script)


if __name__ == "__main__":
    unittest.main()
