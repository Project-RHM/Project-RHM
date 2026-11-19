"""DeepSeek credential validation and atomic local storage. Never return keys."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import tempfile
from threading import RLock

import requests

LOCK = RLock()
DEFAULT_MODEL = 'deepseek-flash'
MODELS = (DEFAULT_MODEL, 'deepseek-v4-pro')


class ApiKeyError(ValueError):
    def __init__(self, message, code, status=400):
        super().__init__(message)
        self.code, self.status = code, status


def parse_key_config(raw):
    if not raw or len(raw) > 8192:
        raise ApiKeyError('Choose a JSON configuration file of at most 8 KB.', 'invalid_config')
    def unique(pairs):
        result = {}
        for name, value in pairs:
            if name in result:
                raise ValueError()
            result[name] = value
        return result
    try:
        data = json.loads(raw.decode('utf-8-sig'), object_pairs_hook=unique)
    except (ValueError, UnicodeError):
        raise ApiKeyError('Choose a valid UTF-8 JSON configuration file.', 'invalid_config') from None
    if not isinstance(data, dict) or set(data) - {'provider', 'api_key', 'model'} or data.get('provider', 'DeepSeek') != 'DeepSeek':
        raise ApiKeyError('Use the DeepSeek configuration template without extra fields.', 'invalid_config')
    key, model = data.get('api_key'), data.get('model', DEFAULT_MODEL)
    if not isinstance(model, str) or model not in MODELS:
        raise ApiKeyError('Choose deepseek-flash or deepseek-v4-pro.', 'invalid_model')
    if not isinstance(key, str) or key == 'PASTE_YOUR_KEY_HERE':
        raise ApiKeyError('Replace the API key placeholder in your configuration file.', 'invalid_key_format')
    return key, model


class DeepSeekKeyValidator:
    def __init__(self, session=None):
        self.session = session or requests.Session()

    def validate(self, key):
        if not isinstance(key, str) or not 8 <= len(key) <= 512 or not key.isascii() or any(c.isspace() or ord(c) < 33 for c in key):
            raise ApiKeyError("Enter a complete DeepSeek API key without spaces.", "invalid_key_format")
        try:
            response = self.session.get("https://api.deepseek.com/user/balance",
                headers={"Authorization": "Bearer " + key}, timeout=(3, 8), allow_redirects=False)
        except requests.RequestException:
            raise ApiKeyError("Could not reach DeepSeek. Your saved key has not been changed.", "validation_unavailable", 503) from None
        if response.status_code in (401, 403):
            raise ApiKeyError("DeepSeek rejected this API key. Your saved key has not been changed.", "invalid_api_key", 400)
        if response.status_code == 402:
            raise ApiKeyError("DeepSeek reports insufficient balance. Validation could not be completed.", "insufficient_balance", 400)
        if response.status_code == 429:
            raise ApiKeyError("DeepSeek is rate limiting requests. Try again later.", "validation_rate_limited", 503)
        if response.status_code != 200:
            raise ApiKeyError("DeepSeek validation is temporarily unavailable. Your saved key has not been changed.", "validation_unavailable", 503)
        try:
            payload = response.json()
            available = payload["is_available"]
            if type(available) is not bool:
                raise ValueError()
        except (ValueError, KeyError, TypeError):
            raise ApiKeyError("DeepSeek returned an unexpected validation response.", "validation_unavailable", 503) from None
        return {"provider": "DeepSeek", "available": available,
                "verified_at": datetime.now(timezone.utc).isoformat()}


def read_keys(filename):
    try:
        data = json.loads(Path(filename).read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def write_keys(filename, data):
    path = Path(filename)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".api_keys_", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(data, handle, indent=2)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def key_status(data):
    key = data.get("default_user")
    record = data.get("default_user_validation", {})
    verified = (isinstance(key, str) and bool(key) and isinstance(record, dict)
                and record.get("provider") == "DeepSeek"
                and record.get("fingerprint") == hashlib.sha256(key.encode()).hexdigest()
                and type(record.get("available")) is bool and bool(record.get("verified_at")))
    model = data.get('default_user_model', DEFAULT_MODEL)
    if not isinstance(model, str) or model not in MODELS:
        model = DEFAULT_MODEL
    return {"has_api_key": bool(key), "verified": bool(verified),
            "available": record["available"] if verified else False,
            "verified_at": record["verified_at"] if verified else None,
            "provider": "DeepSeek", "model": model}


def save_verified(filename, key, validation, model=None):
    with LOCK:
        data = read_keys(filename)
        data["default_user"] = key
        if model is not None:
            if model not in MODELS:
                raise ApiKeyError('Choose deepseek-flash or deepseek-v4-pro.', 'invalid_model')
            data['default_user_model'] = model
        data["default_user_validation"] = {**validation, "fingerprint": hashlib.sha256(key.encode()).hexdigest()}
        write_keys(filename, data)
        return key_status(data)


def remove_key(filename):
    with LOCK:
        data = read_keys(filename)
        data.pop("default_user", None)
        data.pop("default_user_validation", None)
        data.pop('default_user_model', None)
        write_keys(filename, data)
        return key_status(data)
