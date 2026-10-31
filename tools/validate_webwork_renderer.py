"""Render every shipped teacher grammar and named question using real WeBWorK.

Run in the application container: python3 tools/validate_webwork_renderer.py
Test specifications and generated output live in a disposable directory.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys
import tempfile

from flask import Flask

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from teacher_builder import TITLES, register_teacher_routes
from webwork_client import WebworkClient, WebworkConfig


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--renderer-url', default='http://webwork-renderer:3000/render-api')
    args = parser.parse_args()
    renderer = WebworkClient(WebworkConfig(url=args.renderer_url, timeout_seconds=30))
    passed = 0
    failures = []
    with tempfile.TemporaryDirectory(prefix='rhema_render_') as temporary:
        root = Path(temporary)
        (root / 'static').symlink_to(ROOT / 'static', target_is_directory=True)
        (root / 'generator').mkdir()
        for name in ('stdlib', '_build'):
            (root / 'generator' / name).symlink_to(ROOT / 'generator' / name,
                                                  target_is_directory=True)
        app = Flask(__name__)
        register_teacher_routes(app, root)
        client = app.test_client()
        for stem in TITLES:
            grammar = stem + '.rhm'
            result = client.get('/teacher/schema', query_string={'grammar': grammar})
            if result.status_code != 200:
                failures.append((grammar, str(result.get_json())))
                continue
            questions = result.get_json()['schema']['questions'] or [{'name': '', 'initials': {}}]
            for question in questions:
                name = grammar + ':' + (question['name'] or 'default')
                try:
                    result = client.post('/teacher/generate', json={
                        'grammar': grammar, 'count': 1, 'student_id': 'renderer_validation',
                        'question': question['name'],
                        'configuration': {'values': {
                            'root:a:' + key: value
                            for key, value in question['initials'].items()
                        }}
                    })
                    payload = result.get_json()
                    if result.status_code != 200 or not payload.get('success'):
                        raise RuntimeError(str(payload))
                    html = renderer.render(payload['pgml_code'], 1)
                    if 'PGML' in html and 'Error caught by' in html:
                        raise RuntimeError('WeBWorK returned a PG error page.')
                    passed += 1
                    print(f'PASS {name} ({len(html)} HTML chars)', flush=True)
                except Exception as error:
                    failures.append((name, str(error)))
                    print(f'FAIL {name}: {error}', flush=True)
    print(f'Rendered {passed}/{passed + len(failures)} cases successfully.')
    for name, error in failures:
        print(f'- {name}: {error}')
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
