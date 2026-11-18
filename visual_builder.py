"""Compile structured question definitions into Rhema, never executable Python."""
from __future__ import annotations

import copy
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import threading
import uuid

from flask import jsonify, request
from visual_library import BY_ID, CONTEXTS, OPERATIONS, RENDERERS

NAME = re.compile(r"[A-Za-z][A-Za-z0-9_]{0,31}")
FILENAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.rhm")
TOKEN = re.compile(r"\{([A-Za-z][A-Za-z0-9_]{0,31})\}")
SAVE_LOCK = threading.Lock()


@contextmanager
def storage_errors():
    try:
        yield
    except OSError as error:
        raise VisualError("The visual definition could not be saved. Check the folder permissions and available disk space.", 500) from error


class VisualError(ValueError):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def object_fields(value, allowed, label):
    if not isinstance(value, dict) or set(value) - set(allowed):
        raise VisualError(f"{label} contains unsupported fields.")
    return value


def integer(value, label, lower=-1000, upper=1000):
    if type(value) is not int or not lower <= value <= upper:
        raise VisualError(f"{label} must be a whole number between {lower} and {upper}.")
    return value


def quoted(value):
    return json.dumps(value, ensure_ascii=False)


def pgml_literal(value):
    return re.sub(r"([\\\[\]{}$@_*#%<>])", r"\\\1", value)


def compile_spec(definition):
    spec = copy.deepcopy(object_fields(definition, {"version", "title", "parameters", "steps", "prompt", "answer", "constraints", "width"}, "Question definition"))
    if spec.get("version") != 1 or type(spec.get("version")) is not int:
        raise VisualError("Unsupported visual definition version.")
    title = spec.get("title")
    if not isinstance(title, str) or not title.strip() or len(title) > 100 or any(ord(c) < 32 for c in title):
        raise VisualError("Enter a question type name of 1 to 100 characters.")
    parameters, steps = spec.get("parameters"), spec.get("steps")
    if not isinstance(parameters, list) or len(parameters) > 12:
        raise VisualError("Use at most 12 random parameters.")
    if not isinstance(steps, list) or not 1 <= len(steps) <= 30:
        raise VisualError("Add between 1 and 30 mathematical steps.")
    width = integer(spec.get("width", 12), "Answer box width", 1, 100)
    symbols, nodes, declarations = {}, {}, []

    def add_symbol(node, kind):
        name = node.get("name")
        if not isinstance(name, str) or not NAME.fullmatch(name):
            raise VisualError("Names must start with a letter and use at most 32 letters, numbers or underscores.")
        if name in symbols:
            raise VisualError(f"The name '{name}' is used more than once.")
        symbols[name] = kind
        nodes[name] = node
        return "vb_" + name

    for parameter in parameters:
        object_fields(parameter, {"name", "kind", "min", "max", "mode"}, "Random parameter")
        kind = parameter.get("kind")
        if kind == "boolean":
            mode = parameter.get("mode", "random")
            if mode not in ("random", "true", "false"):
                raise VisualError("Choose random, true or false for a Boolean parameter.")
            name = add_symbol(parameter, "Truth")
            expression = "boolean" if mode == "random" else "(1 = " + ("1" if mode == "true" else "0") + ")"
            declarations.append(("random " if mode == "random" else "let ") + name + " = " + expression)
        elif kind in ("integer", "nonzero_integer"):
            lower = integer(parameter.get("min"), "Parameter minimum")
            upper = integer(parameter.get("max"), "Parameter maximum")
            if lower > upper or (kind == "nonzero_integer" and lower == upper == 0):
                raise VisualError("Parameter ranges must be ordered and contain an allowed value.")
            name = add_symbol(parameter, "Number")
            declarations.append(f"random {name} = {kind}_between({lower}, {upper})")
        else:
            raise VisualError("Choose an integer, nonzero integer or Boolean random parameter.")

    def argument(value, expected, label):
        object_fields(value, {"ref", "literal"}, label)
        if set(value) == {"ref"}:
            name = value["ref"]
            if not isinstance(name, str) or name not in symbols:
                raise VisualError(f"{label}: select an earlier parameter or step; forward and circular references are not allowed.")
            if symbols[name] != expected and not (expected == "Set" and symbols[name] == "FiniteSet"):
                raise VisualError(f"{label} needs {expected}, but '{name}' is {symbols[name]}.")
            return "vb_" + name
        if set(value) != {"literal"}:
            raise VisualError(f"{label}: choose a reference or a literal value.")
        literal = value["literal"]
        if expected == "Number":
            return str(integer(literal, label))
        if expected == "Truth" and type(literal) is bool:
            return "(1 = 1)" if literal else "(1 = 0)"
        if expected == "Text" and isinstance(literal, str) and re.fullmatch(r"[A-Za-z][A-Za-z0-9_, ]{0,79}", literal):
            return quoted(literal)
        raise VisualError(f"{label}: use a compatible {expected} value.")

    expressions = {}
    for index, step in enumerate(steps):
        object_fields(step, {"name", "operation", "arguments"}, "Mathematical step")
        op = BY_ID.get(step.get("operation")) if isinstance(step.get("operation"), str) else None
        if op is None:
            raise VisualError("Choose a supported library operation.")
        args = step.get("arguments")
        if not isinstance(args, list) or len(args) != len(op["arguments"]):
            raise VisualError(f"{op['label']} needs {len(op['arguments'])} inputs.")
        rendered = [argument(value, field["type"], f"Step {index + 1}, {field['name']}") for value, field in zip(args, op["arguments"])]
        if op["operator"]:
            expression = f"(not {rendered[0]})" if op["operator"] == "not" else f"({rendered[0]} {op['operator']} {rendered[1]})"
        else:
            expression = op["id"] + "(" + ", ".join(rendered) + ")"
        name = add_symbol(step, op["output"])
        expressions[step["name"]] = rendered
        declarations.append(f"let {name} = {expression}")

    answer = spec.get("answer")
    if not isinstance(answer, str) or answer not in symbols or symbols[answer] not in CONTEXTS:
        raise VisualError("Select a computed answer. Equations and display text are not direct answer types.")
    context = CONTEXTS[symbols[answer]]
    constraints = spec.get("constraints", [])
    if not isinstance(constraints, list) or len(constraints) > 12:
        raise VisualError("Use at most 12 semantic constraints.")
    requirements = []
    for constraint in constraints:
        object_fields(constraint, {"ref", "expected"}, "Constraint")
        ref = constraint.get("ref")
        if not isinstance(ref, str) or symbols.get(ref) != "Truth" or type(constraint.get("expected")) is not bool:
            raise VisualError("A constraint must reference a true/false result and specify its expected value.")
        requirements.append("  require " + ("" if constraint["expected"] else "not ") + "vb_" + ref)

    prompt = spec.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip() or len(prompt) > 2000 or any(ord(c) < 32 and c not in "\n\r\t" for c in prompt):
        raise VisualError("Enter question wording of 1 to 2000 characters.")
    if re.search(r"^\s*(?:BEGIN_PGML|END_PGML)\s*$", prompt, re.M):
        raise VisualError("PGML block delimiters cannot appear in question wording.")
    fragments, last, display = [], 0, {}
    for match in TOKEN.finditer(prompt):
        literal = prompt[last:match.start()]
        if "{" in literal or "}" in literal:
            raise VisualError("Insert values using the value selector; a reference must be written as {name}.")
        fragments.append(pgml_literal(literal))
        name = match[1]
        kind = symbols.get(name)
        if kind is None:
            raise VisualError(f"Question wording refers to unknown value '{name}'.")
        if name not in display:
            reference = "vb_" + name
            if kind in RENDERERS:
                rendering = RENDERERS[kind] + "(" + reference + ")"
            elif kind == "Truth":
                rendering = f'cond({reference}, "1", "0")'
            elif kind == "MathText":
                rendering = reference
            elif kind == "Complex":
                rendering = "complex_latex(" + ", ".join(expressions[name]) + ")"
            else:
                raise VisualError(f"'{name}' is an answer evaluator, not a displayable mathematical object. Insert its input vector instead.")
            display[name] = "vb_display_" + str(len(display) + 1)
            declarations.append("let " + display[name] + " = " + rendering)
        fragments.append("[`{" + display[name] + "}`]")
        last = match.end()
    tail = prompt[last:]
    if "{" in tail or "}" in tail:
        raise VisualError("Question wording contains an incomplete value reference.")
    fragments.append(pgml_literal(tail))
    source = '\n'.join(['# Created with the Rhema visual question builder.', f'context "{context}"', '', *declarations,
                         '', 'synth value on Q', 'start Q', '', 'Q -> "visual_question" {', *requirements,
                         '  value = vb_' + answer, '}', '', 'prompt ' + quoted(''.join(fragments)), 'answer Q.value', f'width {width}', ''])
    spec.update(title=title.strip(), width=width, constraints=constraints)
    return {"specification": spec, "source": source, "context": context, "types": symbols}


def ref(name):
    return {"ref": name}


def literal(value):
    return {"literal": value}


def step(name, operation, *arguments):
    return {"name": name, "operation": operation, "arguments": list(arguments)}


def starter(title, parameters, steps, prompt, answer):
    return {"version": 1, "title": title, "parameters": parameters, "steps": steps,
            "prompt": prompt, "answer": answer, "constraints": [], "width": 12}


def number(name, lower, upper, nonzero=False):
    return {"name": name, "kind": "nonzero_integer" if nonzero else "integer", "min": lower, "max": upper}


STARTERS = {
    "polynomial": starter("Derivative at a point", [number("a", -3, 3, True), number("b", -5, 5), number("c", -5, 5), number("k", -2, 2)],
        [step("p", "polynomial_quadratic", ref("a"), ref("b"), ref("c"), literal("x")),
         step("d", "polynomial_derivative", ref("p")), step("result", "polynomial_evaluate", ref("d"), ref("k"))],
        "Given P(x) = {p}, find P'({k}).", "result"),
    "boolean": starter("Boolean expression evaluation", [{"name": "p", "kind": "boolean", "mode": "random"}, {"name": "q", "kind": "boolean", "mode": "random"}],
        [step("left", "bool_var", literal("p")), step("right", "bool_var", literal("q")),
         step("expression", "bool_and", ref("left"), ref("right")),
         step("p_bit", "cond", ref("p"), literal(1), literal(0)), step("q_bit", "cond", ref("q"), literal(2), literal(0)),
         step("mask", "add", ref("p_bit"), ref("q_bit")), step("result", "bool_evaluate", ref("expression"), literal("p,q"), ref("mask"))],
        "Given p = {p} and q = {q}, evaluate {expression}. Enter 1 for true and 0 for false.", "result"),
    "sequence": starter("Arithmetic sequence: missing difference", [number("first", -5, 5), number("difference", -4, 4, True), number("index", 2, 6)],
        [step("offset", "subtract", ref("index"), literal(1)), step("increase", "multiply", ref("offset"), ref("difference")),
         step("last", "add", ref("first"), ref("increase"))],
        "An arithmetic sequence has first term {first} and term a({index}) = {last}. Find its common difference.", "difference"),
    "vector": starter("Dot product of two vectors", [number("a", -4, 4), number("b", -4, 4), number("c", -4, 4), number("d", -4, 4)],
        [step("u", "vector2", ref("a"), ref("b")), step("v", "vector2", ref("c"), ref("d")), step("result", "vector_dot", ref("u"), ref("v"))],
        "Given u = {u} and v = {v}, find their dot product.", "result"),
    "complex": starter("Complex conjugate", [number("real", -5, 5), number("imaginary", -5, 5, True)],
        [step("z", "complex", ref("real"), ref("imaginary")), step("negative", "subtract", literal(0), ref("imaginary")), step("result", "complex", ref("real"), ref("negative"))],
        "Find the complex conjugate of {z}.", "result"),
    "set": starter("Union of intervals", [number("a", -5, -1), number("b", 1, 5)],
        [step("first", "set_interval", ref("a"), literal(2), literal(True), literal(True)),
         step("second", "set_interval", literal(0), ref("b"), literal(False), literal(True)),
         step("result", "set_union", ref("first"), ref("second"))],
        "Find the union of {first} and {second}.", "result"),
}


def visual_record(grammar_directory, name):
    if not isinstance(name, str) or not FILENAME.fullmatch(name):
        return None
    path = Path(grammar_directory) / ".visual" / (name + ".json")
    try:
        if path.parent.is_symlink() or path.is_symlink() or path.stat().st_size > 131072:
            return None
        record = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(record, dict) or record.get("version") != 1 or record.get("name") != name:
            return None
        return record
    except (OSError, ValueError, TypeError):
        return None


def register_visual_routes(blueprint, generator, stdlib, grammars, runtime, run, generate):
    @blueprint.before_request
    def protect_visual_requests():
        if request.path.startswith("/teacher/visual/") and request.method == "POST":
            origin = request.headers.get("Origin")
            if origin and origin.rstrip("/") != request.host_url.rstrip("/"):
                raise VisualError("Visual builder requests must come from this page.", 403)

    @blueprint.errorhandler(VisualError)
    def visual_error(error):
        return jsonify(success=False, error=str(error)), error.status

    def payload():
        if request.content_length and request.content_length > 131072:
            raise VisualError("The visual definition is too large.", 413)
        try:
            data = request.get_json(silent=True)
        except RecursionError as error:
            raise VisualError("The visual definition is too deeply nested.") from error
        object_fields(data, {"specification", "name", "student_id", "count", "revision"}, "Request")
        return data

    def name_for(data):
        name = data.get("name", "visual_question.rhm")
        if not isinstance(name, str) or not FILENAME.fullmatch(name):
            raise VisualError("Choose a .rhm file name using letters, numbers, underscores or hyphens.")
        return name

    def prepare(data, *, trial):
        compiled = compile_spec(data.get("specification"))
        name = name_for(data)
        if grammars.is_symlink():
            raise VisualError("Cannot write to a linked grammar directory.")
        grammars.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".visual_check_", dir=grammars) as directory:
            source = Path(directory) / "main.rhm"
            source.write_text(compiled["source"], encoding="utf-8")
            run([str(runtime), "check", str(source), "-I", str(stdlib)])
            if trial:
                for student in ("VISUAL_CHECK_A", "VISUAL_CHECK_B"):
                    generate(source, name, compiled["specification"], {"grammar": name, "count": 1, "student_id": student}, trial=True)
                result = {"success": True}
            else:
                result = generate(source, name, compiled["specification"], {"grammar": name, "count": data.get("count", 2), "student_id": data.get("student_id", "")})
        result.update(source=compiled["source"], context=compiled["context"], types=compiled["types"])
        return compiled, result

    @blueprint.get("/visual/catalog")
    def catalog():
        return jsonify(success=True, version=1, operations=OPERATIONS, answer_types=list(CONTEXTS),
                       display_types=list(RENDERERS) + ["Truth", "Complex", "MathText"], starters=STARTERS)

    @blueprint.post("/visual/check")
    def check():
        _, result = prepare(payload(), trial=True)
        return jsonify(result)

    @blueprint.post("/visual/source")
    def source_endpoint():
        compiled = compile_spec(payload().get("specification"))
        return jsonify(success=True, **compiled)

    @blueprint.post("/visual/preview")
    def preview():
        _, result = prepare(payload(), trial=False)
        return jsonify(result)

    @blueprint.get("/visual/definition")
    def definition():
        name = name_for({"name": request.args.get("name", "")})
        path = grammars / name
        record = visual_record(grammars, name)
        if not record or not path.is_file() or path.is_symlink():
            raise VisualError("This question type has no visual definition.", 404)
        revision = hashlib.sha256(path.read_bytes()).hexdigest()
        if record.get("revision") != revision:
            raise VisualError("This source was changed outside Visual builder. Use Rhema source, or create a new visual question type; the existing source will not be overwritten.", 409)
        compiled = compile_spec(record.get("specification"))
        if hashlib.sha256(compiled["source"].encode()).hexdigest() != revision:
            raise VisualError("The visual definition and source no longer agree. Keep using Source mode or create a new definition.", 409)
        return jsonify(success=True, name=name, revision=revision, **compiled)

    @blueprint.post("/visual/save")
    def save():
        data = payload()
        name = name_for(data)
        compiled, result = prepare(data, trial=True)
        target, directory = grammars / name, grammars / ".visual"
        if directory.is_symlink() or (stdlib / name).exists():
            raise VisualError("Choose a new name; standard-library specifications cannot be overwritten.", 409)
        metadata = directory / (name + ".json")
        revision = hashlib.sha256(compiled["source"].encode()).hexdigest()
        record = {"version": 1, "name": name, "revision": revision, "specification": compiled["specification"]}
        with SAVE_LOCK, storage_errors():
            directory.mkdir(parents=True, exist_ok=True)
            if target.is_symlink() or metadata.is_symlink():
                raise VisualError("Cannot save a linked file.", 409)
            old = visual_record(grammars, name)
            updating = target.exists()
            if updating:
                actual = hashlib.sha256(target.read_bytes()).hexdigest()
                if not old or old.get("revision") != actual or data.get("revision") != actual:
                    raise VisualError("This name exists or its source has changed. Reload the visual definition or save under a new name.", 409)
            elif data.get("revision") or metadata.exists():
                raise VisualError("This definition has changed. Reload or choose a new name.", 409)
            with tempfile.TemporaryDirectory(prefix=".visual_save_", dir=grammars) as temporary:
                pending = Path(temporary)
                new_source, new_record = pending / "source.rhm", pending / "definition.json"
                new_source.write_text(compiled["source"], encoding="utf-8")
                new_record.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
                if updating:
                    history = directory / "history" / name / uuid.uuid4().hex
                    if (directory / "history").is_symlink() or (directory / "history" / name).is_symlink():
                        raise VisualError("Cannot save a linked backup directory.")
                    history.mkdir(parents=True)
                    old_source, old_metadata = target.read_bytes(), metadata.read_bytes()
                    (history / "source.rhm").write_bytes(old_source)
                    (history / "definition.json").write_bytes(old_metadata)
                    os.replace(new_source, target)
                    try:
                        os.replace(new_record, metadata)
                    except OSError:
                        rollback = pending / "rollback.rhm"
                        rollback.write_bytes(old_source)
                        os.replace(rollback, target)
                        raise
                else:
                    published = []
                    try:
                        os.link(new_record, metadata)
                        published.append(metadata)
                        os.link(new_source, target)
                        published.append(target)
                    except FileExistsError as error:
                        for path in reversed(published):
                            path.unlink(missing_ok=True)
                        raise VisualError("This name was just created. Choose another name.", 409) from error
                    except OSError:
                        for path in reversed(published):
                            path.unlink(missing_ok=True)
                        raise
        return jsonify(success=True, name=name, revision=revision, source=compiled["source"], context=compiled["context"])
