"""Form authoring over the existing Rhema parser, checker and runtime."""
from __future__ import annotations

import hashlib
from datetime import datetime
import io
import json
from pathlib import Path
import re
import subprocess
import tempfile
import uuid
import zipfile

from flask import Blueprint, jsonify, request, send_file


TITLES = {
    "arithmetic": "Arithmetic", "boolean": "Boolean evaluation",
    "boolean_equiv": "Boolean equivalence", "calculus": "Calculus",
    "complex": "Complex numbers", "counting": "Counting and probability",
    "derivative_or_boolean": "Calculus and logic", "determinant": "Determinants",
    "eigen": "Eigenvalues and eigenvectors", "factoring": "Polynomial factoring",
    "inequality": "Inequalities", "library_formula": "Formula operations",
    "library_linear": "Linear equations: fixed forms", "library_polynomial": "Polynomial operations",
    "library_quadratic": "Quadratic equations", "limits": "Limits",
    "linear_equation": "Linear equations: expressions", "linear_system": "Linear systems",
    "logic_forms": "Logic: classification and transformations", "matrix_expr": "Matrix expressions",
    "matrix_inverse": "Matrix inverses", "number_theory": "Number theory",
    "polynomial_expand": "Polynomial expansion", "polynomial_forms": "Expansion and factoring",
    "sequence": "Sequences", "sequence_parts": "Sequences: two-part questions",
    "series": "Series", "set": "Set operations", "vector": "Vector operations",
    "vector_expr": "Vector expressions",
}


class BuilderError(ValueError):
    pass


def register_teacher_routes(app, project_directory):
    root = Path(project_directory)
    generator = root / "generator"
    stdlib = generator / "stdlib"
    grammars = generator / "grammars"
    metadata_dir = grammars / ".teacher"
    bridge = generator / "_build/default/rhema/bin/rhema_builder_main.exe"
    runtime = generator / "_build/install/default/bin/rhema"
    blueprint = Blueprint("teacher", __name__, url_prefix="/teacher")

    def run(command, timeout=20):
        try:
            result = subprocess.run(command, cwd=generator, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired as error:
            raise BuilderError("These settings could not generate a question in time. Reduce the budget or relax the length and rule restrictions.") from error
        except OSError as error:
            raise BuilderError("Build the generator with dune build before opening the form editor.") from error
        if result.returncode:
            message = result.stderr.strip() or result.stdout.strip()
            raise BuilderError(message[-6000:] or "The specification could not be generated.")
        return result.stdout

    def path_for(name):
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.rhm", name):
            raise BuilderError("Choose a valid grammar file.")
        for directory in (grammars, stdlib):
            path = directory / name
            if path.is_file() and not path.is_symlink():
                return path
        raise BuilderError("The selected grammar file no longer exists.")

    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def describe(name):
        path = path_for(name)
        schema = json.loads(run([str(bridge), "describe", str(path), str(stdlib)]))
        schema.update(grammar=name, title=TITLES.get(path.stem, path.stem.replace("_", " ").title()))
        return schema

    def preset(name):
        record = metadata_dir / (name + ".json")
        if not record.exists():
            return None
        data = json.loads(record.read_text())
        for filename, expected in data["hashes"].items():
            path = grammars / filename
            if not path.is_file() or digest(path) != expected:
                raise BuilderError("This saved specification was edited in source mode. Keep using source mode, or create a new form preset from its original grammar.")
        return data

    def integer(value, label, minimum, maximum):
        if type(value) is not int or not minimum <= value <= maximum:
            raise BuilderError(f"{label} must be a whole number between {minimum} and {maximum}.")
        return value

    def configuration(payload):
        name = payload.get("grammar")
        saved = preset(name) if isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.rhm", name) else None
        base = saved["base"] if saved else name
        schema = describe(base)
        config = payload.get("configuration", {})
        if not isinstance(config, dict):
            raise BuilderError("The configuration must be an object.")
        allowed = {"values", "width", "min_length", "max_length", "instruction"}
        if set(config) - allowed:
            raise BuilderError("The configuration contains an unknown setting.")
        values = config.get("values", {})
        if not isinstance(values, dict):
            raise BuilderError("Parameter values must be an object.")
        fields = {f["id"]: f for f in schema["fields"]}
        if set(values) - set(fields):
            raise BuilderError("The specification has changed. Reload its form before generating.")
        normalized = {}
        for key, field in fields.items():
            value = values.get(key, field["value"])
            kind = field["kind"]
            if kind == "boolean":
                if value not in ("random", "true", "false"):
                    raise BuilderError(f"Choose random, true or false for {field['name']}.")
            elif kind == "range":
                if not isinstance(value, list) or len(value) != len(field["value"]):
                    raise BuilderError(f"The range for {field['name']} is incomplete.")
                bound = max(1000, *(abs(n) for n in field["value"]))
                value = [integer(n, field["name"], -bound, bound) for n in value]
                if len(value) == 2:
                    if value[0] > value[1]:
                        raise BuilderError(f"{field['name']}: the minimum cannot exceed the maximum.")
                    if field["generator"].startswith("nonzero") and value == [0, 0]:
                        raise BuilderError(f"{field['name']} must include a nonzero value.")
                elif value and not 1 <= value[0] <= 4:
                    raise BuilderError("Generated integers must have between 1 and 4 digits.")
            else:
                upper = 1000 if kind == "weight" else max(60, field["value"])
                value = integer(value, field["name"], 0, upper)
            normalized[key] = value
        width = config.get("width", schema["width"] or 16)
        integer(width, "Answer width", 1, 100)
        minimum, maximum = config.get("min_length"), config.get("max_length")
        for label, value in (("Minimum expression operators", minimum), ("Maximum expression operators", maximum)):
            if value is not None:
                integer(value, label, 0, 30)
                if not schema["length_supported"]:
                    raise BuilderError("This grammar has no expression operators to constrain.")
        if minimum is not None and maximum is not None and minimum > maximum:
            raise BuilderError("The minimum length cannot exceed the maximum length.")
        instruction = config.get("instruction", "")
        if not isinstance(instruction, str) or len(instruction)>500 or any(
                line.strip() in {"END_PGML", "BEGIN_PGML"} for line in instruction.splitlines()):
            raise BuilderError("Use an instruction of at most 500 characters without PGML block delimiters.")
        return base, schema, {"values": normalized, "width": width, "min_length": minimum, "max_length": maximum,
                              "instruction": instruction}

    def build(base, schema, config):
        command = [str(bridge), "build", str(path_for(base)), str(stdlib), "--width", str(config["width"])]
        if config["instruction"]:
            command.extend(["--instruction", config["instruction"]])
        for field in schema["fields"]:
            value = config["values"][field["id"]]
            if value != field["value"]:
                rendered = ",".join(map(str, value)) if isinstance(value, list) else str(value)
                command.extend(["--value", field["id"], rendered])
        for key, flag in (("min_length", "--min-length"), ("max_length", "--max-length")):
            if config[key] is not None:
                command.extend([flag, str(config[key])])
        return json.loads(run(command))["files"]

    def write_bundle(directory, files):
        for file in files:
            (directory / file["name"]).write_text(file["content"], encoding="utf-8")
        return directory / "main.rhm"

    def generate(specification, base, config, payload, *, trial=False):
        count = integer(payload.get("count", 3), "Question count", 1, 50)
        question = payload.get("question", "") or "main"
        if not isinstance(question, str) or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", question):
            raise BuilderError("Choose a valid question form.")
        student = payload.get("student_id", "")
        if not isinstance(student, str) or (student and not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", student)):
            raise BuilderError("Use letters, numbers, underscores or hyphens for the student ID.")
        identity = base + ":" + question + ":" + hashlib.sha256(json.dumps(config, sort_keys=True).encode()).hexdigest()[:16]
        token = "teacher_" + datetime.now().strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:10]
        relative = {"pgml_path": f"generated_questions/{token}.pg", "ast_path": f"generated_asts/{token}_ast.txt",
                    "visualization_path": f"generated_visualizations/{token}_trees.html"}
        for path in relative.values():
            (generator / path).parent.mkdir(parents=True, exist_ok=True)
        command = [str(runtime), str(specification), "--count", str(count), "--assignment", identity,
                   "--question", question, "-I", str(stdlib), "-o", str(generator / relative["pgml_path"]),
                   "--ast-out", str(generator / relative["ast_path"]),
                   "--visualization-out", str(generator / relative["visualization_path"])]
        if student:
            command.extend(["--student", student])
        try:
            run(command, timeout=25)
            pg = (generator / relative["pgml_path"]).read_text()
        except BuilderError as error:
            raise BuilderError("The chosen settings are not compatible. Try the default budget, enable more rules, or relax the length limits.\n" + str(error)) from error
        if trial:
            for path in relative.values():
                (generator / path).unlink(missing_ok=True)
        preview = [] if trial else json.loads(run([str(bridge), "preview", str(specification), str(stdlib),
                                                  str(count), question, identity, student], timeout=25))
        return {"success": True, **relative, "pgml_code": pg, "original_pgml_content": pg,
                "preview": preview, "visualization_kind": "attribute_grammar"}

    def prepared(payload, *, trial=False):
        base, schema, config = configuration(payload)
        files = build(base, schema, config)
        grammars.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".teacher_check_", dir=grammars) as directory:
            source = write_bundle(Path(directory), files)
            run([str(runtime), "check", str(source), "-I", str(stdlib)])
            result = generate(source, base, config, payload, trial=trial)
        return base, config, files, result

    @blueprint.errorhandler(BuilderError)
    def bad_settings(error):
        return jsonify(success=False, error=str(error)), 400

    @blueprint.get("/schema")
    def schema_endpoint():
        name = request.args.get("grammar", "arithmetic.rhm")
        saved = preset(name) if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.rhm", name) else None
        schema = describe(saved["base"] if saved else name)
        return jsonify(success=True, schema=schema, configuration=saved["configuration"] if saved else None)

    @blueprint.post("/generate")
    def generate_endpoint():
        payload = request.get_json(silent=True)
        if not isinstance(payload, dict):
            raise BuilderError("Send a JSON configuration.")
        base, config, files, result = prepared(payload)
        result.update(source=files[0]["content"], base=base, configuration=config)
        return jsonify(result)

    @blueprint.post("/save")
    def save_endpoint():
        payload = request.get_json(silent=True)
        if not isinstance(payload, dict):
            raise BuilderError("Send a JSON configuration.")
        name = payload.get("name", "")
        if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.rhm", name):
            raise BuilderError("Use a new .rhm file name containing letters, numbers, underscores or hyphens.")
        target = grammars / name
        if target.exists() or target.is_symlink() or (stdlib / name).exists():
            raise BuilderError("This name already exists. Save under a new name.")
        base, config, files, _ = prepared({**payload, "count": 1}, trial=True)
        metadata_dir.mkdir(parents=True, exist_ok=True)
        prefix = "." + name[:-4] + "_"
        hashes = {}
        written = []
        try:
            for file in files[1:] + files[:1]:
                filename = name if file["name"] == "main.rhm" else prefix + file["name"]
                content = file["content"]
                for dependency in files[1:]:
                    content = content.replace('import "' + dependency["name"] + '"', 'import "' + prefix + dependency["name"] + '"')
                path = grammars / filename
                with path.open("x", encoding="utf-8") as handle:
                    handle.write(content)
                written.append(path)
                hashes[filename] = digest(path)
            record = {"version": 1, "base": base, "configuration": config, "hashes": hashes}
            with (metadata_dir / (name + ".json")).open("x", encoding="utf-8") as handle:
                json.dump(record, handle, indent=2)
        except OSError as error:
            for path in written:
                path.unlink(missing_ok=True)
            raise BuilderError("Could not save the preset: " + str(error)) from error
        return jsonify(success=True, name=name)

    @blueprint.post("/export")
    def export_endpoint():
        payload = request.get_json(silent=True)
        if not isinstance(payload, dict):
            raise BuilderError("Send a JSON configuration.")
        base, config, files, _ = prepared({**payload, "count": 1}, trial=True)
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
            for file in files:
                archive.writestr(file["name"], file["content"])
            archive.writestr("configuration.json", json.dumps({"base": base, "configuration": config}, indent=2))
        buffer.seek(0)
        return send_file(buffer, mimetype="application/zip", as_attachment=True, download_name="rhema-specification.zip")

    app.register_blueprint(blueprint)
