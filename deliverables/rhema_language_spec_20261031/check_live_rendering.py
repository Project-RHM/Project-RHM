"""Opt-in local renderer check of PG output extracted from the manual."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
sys.path.insert(0, str(ROOT))
from webwork_client import WebworkClient

client = WebworkClient()
status = client.status()
if not status.get("available"):
    raise AssertionError(status)
checks = []
for pg in sorted(HERE.glob("*.pg")):
    source = pg.read_text()
    html = client.render(source)
    if not html.strip():
        raise AssertionError(f"{pg.name}: empty preview")
    checks.append({"pg_file": pg.name, "rendered": True})
    print("PASS render", pg.name, flush=True)
report_path = HERE / "verification.json"
report = json.loads(report_path.read_text())
report["webwork_rendering"] = {"status": "passed", "scope": "Local Docker renderer; rendering only, not student submission grading or mathematical proof.", "cases": checks}
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
