"""Explicit worksheet identity, with read-only fallback for legacy filenames."""
from datetime import datetime, timezone, timedelta
import json
import os
from pathlib import Path
import re
import tempfile
import uuid

DISPLAY_ZONE = timezone(timedelta(hours=8))
IDENTIFIER = re.compile(r'[A-Za-z0-9_-]{1,64}')
LEGACY_NAME = re.compile(r'(?P<identity>.+)_(?P<date>\d{8})_(?P<time>\d{6})(?:_[0-9a-f]{8,32})?\.pg', re.I)


def output_stem(student_id):
    if student_id and not IDENTIFIER.fullmatch(student_id):
        raise ValueError('Invalid student ID for generation history.')
    stamp = datetime.now(DISPLAY_ZONE).strftime('%Y%m%d_%H%M%S')
    return f"{student_id or 'worksheet'}_{stamp}_{uuid.uuid4().hex[:10]}"


def _date(value):
    date = datetime.fromisoformat(value)
    return date.replace(tzinfo=DISPLAY_ZONE) if date.tzinfo is None else date


def write_record(generator_directory, pg_path, *, student_id, generator, grammar, question, count):
    root = Path(generator_directory) / 'generated_questions'
    pg = Path(pg_path)
    if pg.parent.resolve() != root.resolve() or not pg.is_file() or pg.is_symlink() or pg.suffix != '.pg':
        raise ValueError('History records belong beside generated PG files.')
    if student_id and not IDENTIFIER.fullmatch(student_id):
        raise ValueError('Invalid student ID for generation history.')
    record = {'version': 1, 'filename': pg.name, 'student_id': student_id or None,
              'generator': generator, 'grammar': grammar, 'question': question,
              'count': count, 'created_at': datetime.now(timezone.utc).isoformat()}
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=root,
                                         prefix='.history_', delete=False) as handle:
            temporary = handle.name
            json.dump(record, handle, ensure_ascii=False, indent=2)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, pg.with_suffix('.meta.json'))
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


def _metadata(pg):
    path = pg.with_suffix('.meta.json')
    if path.is_symlink():
        return None
    try:
        with path.open('rb') as handle:
            raw = handle.read(16385)
        if len(raw) > 16384:
            return None
        data = json.loads(raw)
        if not isinstance(data, dict) or data.get('version') != 1 or data.get('filename') != pg.name:
            return None
        student = data.get('student_id')
        if student is not None and (not isinstance(student, str) or not IDENTIFIER.fullmatch(student)):
            return None
        if data.get('generator') not in {'rhema_configure', 'rhema_source', 'classic'}:
            return None
        grammar = data.get('grammar')
        if grammar is not None and (not isinstance(grammar, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.rhm', grammar)):
            return None
        if not isinstance(data.get('created_at'), str) or len(data['created_at']) > 64:
            return None
        _date(data['created_at'])
        return data
    except (OSError, ValueError, TypeError, UnicodeError, OverflowError):
        return None


def record_for(generator_directory, filename):
    root = Path(generator_directory)
    if not isinstance(filename, str) or Path(filename).name != filename:
        return None
    pg = root / 'generated_questions' / filename
    if pg.suffix != '.pg' or not pg.is_file() or pg.is_symlink():
        return None
    data = _metadata(pg)
    grammar, generator = None, None
    if data:
        student = data['student_id']
        date = _date(data['created_at'])
        identity_status = 'recorded'
        grammar, generator = data.get('grammar'), data['generator']
    else:
        date = datetime.fromtimestamp(pg.stat().st_mtime, timezone.utc)
        student, identity_status = None, 'unknown'
        match = LEGACY_NAME.fullmatch(filename)
        if match:
            try:
                date = datetime.strptime(match['date'] + match['time'], '%Y%m%d%H%M%S').replace(tzinfo=DISPLAY_ZONE)
            except ValueError:
                pass
            identity = match['identity']
            if identity in {'assignment', 'worksheet'}:
                identity_status = 'legacy'
            elif identity != 'teacher' and IDENTIFIER.fullmatch(identity):
                student, identity_status = identity, 'legacy'
    display_date = date.astimezone(DISPLAY_ZONE)
    stem = pg.stem
    visualization = stem + '_trees.html'
    return {'filename': filename, 'student_id': student, 'identity_status': identity_status,
            'display_name': student or ('Legacy worksheet' if identity_status == 'unknown' else 'Shared worksheet'),
            'grammar': grammar, 'generator': generator,
            'timestamp': display_date.strftime('%Y-%m-%d %H:%M:%S'),
            'raw_timestamp': display_date.strftime('%Y%m%d_%H%M%S'),
            'sort_timestamp': date.timestamp(),
            'has_ast': (root / 'generated_asts' / (stem + '_ast.txt')).is_file(),
            'has_visualization': (root / 'generated_visualizations' / visualization).is_file(),
            'visualization_filename': visualization}


def list_records(generator_directory):
    root = Path(generator_directory) / 'generated_questions'
    records = []
    for pg in root.glob('*.pg'):
        try:
            record = record_for(generator_directory, pg.name)
        except OSError:
            continue
        if record is not None:
            records.append(record)
    return sorted(records, key=lambda record: (record['sort_timestamp'], record['filename']), reverse=True)
