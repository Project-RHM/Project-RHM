"""Small, policy-enforcing client for the standalone WeBWorK renderer."""

from __future__ import annotations

from dataclasses import dataclass
from html.parser import HTMLParser
import math
import os
import re
from urllib.parse import urlparse

import requests


DEFAULT_RENDERER_URL = "http://127.0.0.1:3000/render-api"
ANSWER_NAME = re.compile(r"AnSwEr[0-9]{4,}(?:_[0-9]+)*\Z")
HEALTH_CHECK_SOURCE = """DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");
BEGIN_PGML
Renderer health check: [`1+1`]
END_PGML
ENDDOCUMENT();
"""


def _env_bool(name: str, default: bool) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() not in {"0", "false", "no", "off", ""}


def _env_int(name: str, default: int, minimum: int) -> int:
    try:
        value = int(os.environ.get(name, str(default)))
    except ValueError:
        return default
    return max(minimum, value)


def _env_float(name: str, default: float, minimum: float) -> float:
    try:
        value = float(os.environ.get(name, str(default)))
    except ValueError:
        return default
    return max(minimum, value)


@dataclass(frozen=True)
class WebworkConfig:
    url: str = DEFAULT_RENDERER_URL
    public_base_url: str = ""
    enabled: bool = True
    timeout_seconds: float = 10.0
    max_source_bytes: int = 262_144
    max_response_bytes: int = 4_194_304

    @classmethod
    def from_env(cls) -> "WebworkConfig":
        return cls(
            url=os.environ.get("WEBWORK_RENDERER_URL", DEFAULT_RENDERER_URL).strip(),
            public_base_url=os.environ.get(
                "WEBWORK_RENDERER_PUBLIC_BASE_URL", ""
            ).strip(),
            enabled=_env_bool("WEBWORK_RENDER_ENABLED", True),
            timeout_seconds=_env_float("WEBWORK_RENDER_TIMEOUT_SECONDS", 10.0, 0.1),
            max_source_bytes=_env_int("WEBWORK_RENDER_MAX_BYTES", 262_144, 1_024),
            max_response_bytes=_env_int(
                "WEBWORK_RENDER_MAX_RESPONSE_BYTES", 4_194_304, 16_384
            ),
        )


class WebworkClientError(Exception):
    """An error that can safely be translated into an API response."""

    def __init__(self, message: str, *, code: str, http_status: int):
        super().__init__(message)
        self.code = code
        self.http_status = http_status


class _RenderDiagnostics(HTMLParser):
    """The renderer can put PG translator errors in an HTTP 200 response."""

    def __init__(self):
        super().__init__()
        self.heading = False
        self.heading_parts = []
        self.has_translator_errors = False

    def handle_starttag(self, tag, attrs):
        if tag in {"h1", "h2", "h3"}:
            self.heading = True
            self.heading_parts = []

    def handle_data(self, data):
        if self.heading:
            self.heading_parts.append(data)

    def handle_endtag(self, tag):
        if tag in {"h1", "h2", "h3"} and self.heading:
            title = " ".join("".join(self.heading_parts).split()).lower()
            if title in {"translator errors", "internal errors"}:
                self.has_translator_errors = True
            self.heading = False


class _PlainFeedback(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []

    def handle_data(self, data):
        self.parts.append(data)


def _plain_feedback(value) -> str:
    parser = _PlainFeedback()
    parser.feed(str(value or "")[:16_384])
    return " ".join(" ".join(parser.parts).split())[:2_000]


class WebworkClient:
    def __init__(self, config: WebworkConfig | None = None, session=None):
        self.config = config or WebworkConfig.from_env()
        if session is None:
            # This is a configured service connection, not general web traffic.
            # Workstation proxies must not intercept local PG source requests.
            session = requests.Session()
            session.trust_env = False
        self.session = session

    def _validate_configuration(self) -> None:
        if not self.config.enabled:
            raise WebworkClientError(
                "WeBWorK preview is disabled.",
                code="renderer_disabled",
                http_status=503,
            )

        parsed = urlparse(self.config.url)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise WebworkClientError(
                "WEBWORK_RENDERER_URL must be an absolute HTTP(S) URL.",
                code="renderer_misconfigured",
                http_status=503,
            )

        public_parsed = urlparse(self.public_base_url())
        if public_parsed.scheme not in {"http", "https"} or not public_parsed.netloc:
            raise WebworkClientError(
                "WEBWORK_RENDERER_PUBLIC_BASE_URL must be an absolute HTTP(S) URL.",
                code="renderer_misconfigured",
                http_status=503,
            )

    def public_base_url(self) -> str:
        configured = self.config.public_base_url.strip()
        if configured:
            return configured.rstrip("/") + "/"
        parsed = urlparse(self.config.url)
        return f"{parsed.scheme}://{parsed.netloc}/"

    def _validate_source(self, source: str) -> None:
        if not isinstance(source, str) or not source.strip():
            raise WebworkClientError(
                "PG source is required.", code="missing_source", http_status=400
            )
        if len(source.encode("utf-8")) > self.config.max_source_bytes:
            raise WebworkClientError(
                f"PG source exceeds the {self.config.max_source_bytes}-byte preview limit.",
                code="source_too_large",
                http_status=413,
            )
        if "DOCUMENT();" not in source or "ENDDOCUMENT();" not in source:
            raise WebworkClientError(
                "Preview expects a complete .pg document.",
                code="incomplete_document",
                http_status=422,
            )

    @staticmethod
    def _validate_seed(seed) -> int:
        if isinstance(seed, bool):
            raise WebworkClientError(
                "problem_seed must be an integer.",
                code="invalid_seed",
                http_status=400,
            )
        try:
            normalized = int(seed)
        except (TypeError, ValueError):
            raise WebworkClientError(
                "problem_seed must be an integer.",
                code="invalid_seed",
                http_status=400,
            ) from None
        if not 1 <= normalized <= 2_147_483_647:
            raise WebworkClientError(
                "problem_seed must be between 1 and 2147483647.",
                code="invalid_seed",
                http_status=400,
            )
        return normalized

    @staticmethod
    def _upstream_error(response) -> str:
        try:
            payload = response.json()
        except (ValueError, TypeError):
            payload = None
        if isinstance(payload, dict):
            for key in ("error", "errors", "message", "detail"):
                if payload.get(key):
                    return str(payload[key])[:1_000]

        text = re.sub(r"<[^>]+>", " ", response.text or "")
        text = " ".join(text.split())
        return text[:1_000] or f"Renderer returned HTTP {response.status_code}."

    def _request(self, source: str, seed=1, *, answers=None):
        self._validate_configuration()
        self._validate_source(source)
        seed = self._validate_seed(seed)

        # Options are fixed here, never merged from caller-supplied renderer flags.
        # The grading request needs the server-only answer hash. check() returns
        # only scores and plain feedback, never that hash, HTML, or JWTs.
        data = {
            "problemSource": source,
            "problemSeed": str(seed),
            "_format": "html" if answers is None else "json",
            "outputFormat": "static",
            "displayMode": "MathJax",
            "baseURL": self.public_base_url(),
            "isInstructor": "0" if answers is None else "1",
            "showSolutions": "0",
            "showHints": "0",
            "showFooter": "0",
        }
        if answers is not None:
            data.update(answers)
            data["submitAnswers"] = "1"

        try:
            response = self.session.post(
                self.config.url,
                data=data,
                timeout=self.config.timeout_seconds,
            )
        except requests.Timeout as error:
            raise WebworkClientError(
                "WeBWorK Renderer timed out.",
                code="renderer_timeout",
                http_status=504,
            ) from error
        except requests.ConnectionError as error:
            raise WebworkClientError(
                "WeBWorK Renderer is unavailable.",
                code="renderer_unavailable",
                http_status=502,
            ) from error
        except requests.RequestException as error:
            raise WebworkClientError(
                "WeBWorK Renderer request failed.",
                code="renderer_request_failed",
                http_status=502,
            ) from error

        if response.status_code >= 400:
            upstream_status = 422 if response.status_code < 500 else 502
            raise WebworkClientError(
                self._upstream_error(response),
                code="renderer_rejected_source",
                http_status=upstream_status,
            )

        body = response.content
        if len(body) > self.config.max_response_bytes:
            raise WebworkClientError(
                "Renderer response exceeded the configured size limit.",
                code="renderer_response_too_large",
                http_status=502,
            )
        if not body.strip():
            raise WebworkClientError(
                "Renderer returned an empty response.",
                code="renderer_empty_response",
                http_status=502,
            )

        response.encoding = response.encoding or "utf-8"
        return response

    def render(self, source: str, seed=1) -> str:
        response = self._request(source, seed)
        html = response.text
        diagnostics = _RenderDiagnostics()
        diagnostics.feed(html)
        if diagnostics.has_translator_errors:
            raise WebworkClientError(
                "WeBWorK could not compile this PG document. Check the PGML source and answer evaluators.",
                code="pg_compile_error", http_status=422,
            )
        return html

    @staticmethod
    def _validate_answers(answers) -> dict:
        if not isinstance(answers, dict) or not answers or len(answers) > 1_000:
            raise WebworkClientError(
                "answers must contain between 1 and 1000 answer fields.",
                code="invalid_answers", http_status=400,
            )
        total_bytes = 0
        for name, value in answers.items():
            if not isinstance(name, str) or not ANSWER_NAME.fullmatch(name) or not isinstance(value, str):
                raise WebworkClientError(
                    "Only named WeBWorK answer fields with string values are allowed.",
                    code="invalid_answers", http_status=400,
                )
            size = len(value.encode("utf-8"))
            total_bytes += size
            if size > 4_096 or total_bytes > 262_144:
                raise WebworkClientError(
                    "Submitted answers exceed the size limit.",
                    code="answers_too_large", http_status=413,
                )
        return answers

    @staticmethod
    def _score(value) -> float:
        try:
            score = float(value)
        except (TypeError, ValueError):
            score = float("nan")
        if not math.isfinite(score) or not 0 <= score <= 1:
            raise WebworkClientError(
                "WeBWorK did not return a valid grade.",
                code="invalid_grade", http_status=502,
            )
        return score

    def check(self, source: str, answers, seed=1) -> dict:
        answers = self._validate_answers(answers)
        response = self._request(source, seed, answers=answers)
        try:
            payload = response.json()
        except ValueError:
            payload = None
        if not isinstance(payload, dict):
            raise WebworkClientError(
                "WeBWorK returned an invalid grading response.",
                code="invalid_grade", http_status=502,
            )
        flags = payload.get("flags") or {}
        result = payload.get("problem_result") or {}
        debug = payload.get("debug") or {}
        if not isinstance(flags, dict) or not isinstance(result, dict) or not isinstance(debug, dict):
            raise WebworkClientError("Invalid grading response.", code="invalid_grade", http_status=502)
        warnings = debug.get("pg_warn") or []
        if not isinstance(warnings, list):
            warnings = [warnings]
        diagnostics = _RenderDiagnostics()
        diagnostics.feed(str(payload.get("renderedHTML") or ""))
        if flags.get("error_flag") or result.get("errors") or diagnostics.has_translator_errors:
            raise WebworkClientError(
                "WeBWorK could not compile the question. No grade was accepted.",
                code="pg_compile_error", http_status=422,
            )
        if any("Errors parsing PGML" in str(w) or "Error parsing answer:" in str(w) for w in warnings):
            raise WebworkClientError(
                "The PGML answer evaluator has errors. Regenerate the question before checking answers.",
                code="pg_answer_error", http_status=422,
            )
        raw_answers = payload.get("answers")
        if not isinstance(raw_answers, dict) or not raw_answers:
            raise WebworkClientError(
                "WeBWorK returned no answer evaluators.", code="invalid_grade", http_status=502,
            )
        allowed = set(raw_answers) | set(flags.get("KEPT_EXTRA_ANSWERS") or [])
        if set(answers) - allowed:
            raise WebworkClientError(
                "Submitted answer fields do not match this question.",
                code="invalid_answer_field", http_status=422,
            )
        order = flags.get("ANSWER_ENTRY_ORDER") or list(raw_answers)
        entries = []
        for name in dict.fromkeys([*order, *raw_answers]):
            if name not in raw_answers or not ANSWER_NAME.fullmatch(name):
                continue
            answer = raw_answers[name]
            if not isinstance(answer, dict):
                raise WebworkClientError("Invalid answer grade.", code="invalid_grade", http_status=502)
            score = self._score(answer.get("score"))
            entries.append({
                "name": name, "score": score, "correct": score == 1,
                "feedback": _plain_feedback(answer.get("ans_message") or answer.get("error_message")),
            })
        if not entries:
            raise WebworkClientError("No graded answers found.", code="invalid_grade", http_status=502)
        return {
            "score": self._score(result.get("score")),
            "correct_count": sum(entry["correct"] for entry in entries),
            "answer_count": len(entries),
            "answers": entries,
        }

    def status(self) -> dict:
        status = {
            "enabled": self.config.enabled,
            "available": False,
        }
        try:
            self.render(HEALTH_CHECK_SOURCE, 1)
        except WebworkClientError as error:
            status.update({"code": error.code, "message": str(error)})
        else:
            status.update({"available": True, "message": "Renderer is available."})
        return status
