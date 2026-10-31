from flask import Flask, render_template, request, jsonify, send_from_directory
import subprocess
import os
import json
import sys
import re
import glob
import time
import webbrowser
from datetime import datetime
import shutil
import tempfile
from threading import Thread

from webwork_client import WebworkClient, WebworkClientError
from teacher_builder import TITLES, register_teacher_routes

# 获取当前文件所在的绝对路径
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 将项目根目录添加到Python路径
sys.path.insert(0, BASE_DIR)

app = Flask(__name__)
WEBWORK_CLIENT = WebworkClient()

# 配置OCaml程序路径 - 使用绝对路径
OCAML_PROJECT_DIR = os.path.join(BASE_DIR, "generator")
OCAML_PROGRAM_PATH = os.path.join(OCAML_PROJECT_DIR, "_build/default/unparser.exe")

# The attribute-grammar path. Unlike the generator above, this one is driven by
# a .rhm file: what a question looks like, what it asks, and how hard it is all
# come from that file, so changing any of it means editing the file rather than
# rebuilding OCaml.
RHEMA_COMMAND = os.path.join(OCAML_PROJECT_DIR, "_build/install/default/bin/rhema")
# Grammars a user writes or edits in the browser live here; the shipped
# library is read from RHEMA_STDLIB_DIR beside it. Both are offered in the list.
RHEMA_GRAMMAR_DIR = os.path.join(OCAML_PROJECT_DIR, "grammars")
RHEMA_STDLIB_DIR = os.path.join(OCAML_PROJECT_DIR, "stdlib")
RHEMA_DEFAULT_GRAMMAR = "arithmetic.rhm"
CONFIG_JSON_PATH = os.path.join(BASE_DIR, "config_setting/config.json")
CONFIG_ML_TEMPLATE_PATH = os.path.join(BASE_DIR, "config_setting/config.ml.template")

LLM_CONTEXT_DIR = os.path.join(BASE_DIR, "llm_context")
LLM_CONTEXT_SCRIPT = os.path.join(LLM_CONTEXT_DIR, "llm_context.py")
API_CALL_SCRIPT = os.path.join(LLM_CONTEXT_DIR, "api_call.py")

# 添加用户API密钥存储
USER_API_KEYS_FILE = os.environ.get(
    "USER_API_KEYS_FILE", os.path.join(BASE_DIR, "user_api_keys.json")
)

# 设置工作目录
os.chdir(BASE_DIR)

def dune_command(*args):
    """Use dune directly when available, otherwise run it through opam."""
    if shutil.which("dune"):
        return ["dune", *args]
    if shutil.which("opam"):
        return ["opam", "exec", "--", "dune", *args]
    return ["dune", *args]

DEFAULT_CONFIG = {
    "question_random_amounts": False,
    "shuffle_questions_for_0_type": False,
    "allow_float": False,
    "min_question_num": 4,
    "max_question_num": 10,
    "problem_type": 1,
    "max_expr_depth": 2,
    "min_set_expr_depth": 1,
    "max_set_expr_depth": 2,
    "min_set_element": -10,
    "max_set_element": 10,
    "max_set_def_num": 3,
    "min_set_prob_num": 2,
    "max_set_prob_num": 3,
    "vector_dimension": 3,
    "min_vector_element": -10,
    "max_vector_element": 10,
    "max_vector_def_num": 3,
    "min_vector_prob_num": 4,
    "max_vector_prob_num": 6,
    "min_fun_expr_depth": 3,
    "max_fun_expr_depth": 5,
    "calculus_question_mode": 0,
    "derivative_weight": 1,
    "integral_weight": 1,
    "min_derivative_prob_num": 2,
    "max_derivative_prob_num": 4,
    "integral_expr_depth": 3,
    "boolean_question_mode": 0,
    "boolean_eval_weight": 1,
    "boolean_equiv_weight": 1,
    "min_bool_expr_depth": 2,
    "max_bool_expr_depth": 3,
    "min_bool_var_num": 2,
    "max_bool_var_num": 3,
    "complex_question_mode": 0,
    "complex_arithmetic_weight": 2,
    "complex_conjugate_weight": 1,
    "complex_modulus_weight": 1,
    "complex_power_i_weight": 1,
    "min_complex_component": -8,
    "max_complex_component": 8,
    "min_complex_power": 1,
    "max_complex_power": 40,
    "sequence_question_mode": 0,
    "arithmetic_sequence_weight": 1,
    "geometric_sequence_weight": 1,
    "arithmetic_sequence_sum_weight": 1,
    "geometric_sequence_sum_weight": 1,
    "min_sequence_index": 2,
    "max_sequence_index": 8,
    "min_sequence_term": -10,
    "max_sequence_term": 10,
    "min_sequence_difference": -8,
    "max_sequence_difference": 8,
    "min_sequence_ratio": -5,
    "max_sequence_ratio": 5,
    "question_type_amounts": [1, 1, 1, 2, 2, 1, 1],
    "set_variables": ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"],
    "vector_variables": ["u", "v", "w", "x", "y", "z", "a", "b", "c", "d"],
    "boolean_variables": ["A", "B", "C", "D", "E"],
    "difficulty_level": "medium",
}

BOOL_PARAMS = [
    "question_random_amounts",
    "shuffle_questions_for_0_type",
    "allow_float",
]

INT_PARAMS = [
    "min_question_num", "max_question_num",
    "problem_type", "max_expr_depth", "min_set_expr_depth", "max_set_expr_depth",
    "min_set_element", "max_set_element", "max_set_def_num", "min_set_prob_num",
    "max_set_prob_num", "vector_dimension", "min_vector_element", "max_vector_element",
    "max_vector_def_num", "min_vector_prob_num", "max_vector_prob_num",
    "min_fun_expr_depth", "max_fun_expr_depth", "calculus_question_mode",
    "derivative_weight", "integral_weight", "min_derivative_prob_num",
    "max_derivative_prob_num", "integral_expr_depth",
    "boolean_question_mode", "boolean_eval_weight",
    "boolean_equiv_weight", "min_bool_expr_depth", "max_bool_expr_depth",
    "min_bool_var_num", "max_bool_var_num", "complex_question_mode",
    "complex_arithmetic_weight", "complex_conjugate_weight",
    "complex_modulus_weight", "complex_power_i_weight",
    "min_complex_component", "max_complex_component",
    "min_complex_power", "max_complex_power",
    "sequence_question_mode", "arithmetic_sequence_weight",
    "geometric_sequence_weight", "arithmetic_sequence_sum_weight",
    "geometric_sequence_sum_weight", "min_sequence_index",
    "max_sequence_index", "min_sequence_term", "max_sequence_term",
    "min_sequence_difference", "max_sequence_difference",
    "min_sequence_ratio", "max_sequence_ratio"
]

INT_RANGES = {
    "min_question_num": (1, 20),
    "max_question_num": (1, 20),
    "problem_type": (0, 7),
    "max_expr_depth": (1, 100),
    "min_set_expr_depth": (1, 100),
    "max_set_expr_depth": (1, 100),
    "min_set_element": (-1000, 1000),
    "max_set_element": (-1000, 1000),
    "max_set_def_num": (2, 100),
    "min_set_prob_num": (1, 100),
    "max_set_prob_num": (1, 100),
    "vector_dimension": (2, 10),
    "min_vector_element": (-1000, 1000),
    "max_vector_element": (-1000, 1000),
    "max_vector_def_num": (2, 100),
    "min_vector_prob_num": (1, 100),
    "max_vector_prob_num": (1, 100),
    "min_fun_expr_depth": (1, 100),
    "max_fun_expr_depth": (1, 100),
    "calculus_question_mode": (0, 2),
    "derivative_weight": (0, 20),
    "integral_weight": (0, 20),
    "min_derivative_prob_num": (1, 12),
    "max_derivative_prob_num": (1, 12),
    "integral_expr_depth": (0, 20),
    "boolean_question_mode": (0, 2),
    "boolean_eval_weight": (0, 20),
    "boolean_equiv_weight": (0, 20),
    "min_bool_expr_depth": (1, 20),
    "max_bool_expr_depth": (1, 20),
    "min_bool_var_num": (1, 10),
    "max_bool_var_num": (1, 10),
    "complex_question_mode": (0, 4),
    "complex_arithmetic_weight": (0, 20),
    "complex_conjugate_weight": (0, 20),
    "complex_modulus_weight": (0, 20),
    "complex_power_i_weight": (0, 20),
    "min_complex_component": (-100, 100),
    "max_complex_component": (-100, 100),
    "min_complex_power": (0, 1000),
    "max_complex_power": (0, 1000),
    "sequence_question_mode": (0, 4),
    "arithmetic_sequence_weight": (0, 20),
    "geometric_sequence_weight": (0, 20),
    "arithmetic_sequence_sum_weight": (0, 20),
    "geometric_sequence_sum_weight": (0, 20),
    "min_sequence_index": (1, 20),
    "max_sequence_index": (1, 20),
    "min_sequence_term": (-100, 100),
    "max_sequence_term": (-100, 100),
    "min_sequence_difference": (-100, 100),
    "max_sequence_difference": (-100, 100),
    "min_sequence_ratio": (-20, 20),
    "max_sequence_ratio": (-20, 20),
}

LIST_PARAMS = ["set_variables", "vector_variables", "boolean_variables"]
IDENT_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")
RESERVED_VAR_NAMES = {"TRUE", "FALSE", "AND", "OR", "NOT", "XOR", "IMPLIES", "IFF"}

def read_config():
    """读取JSON配置文件"""
    try:
        with open(CONFIG_JSON_PATH, 'r', encoding='utf-8') as f:
            return normalize_config(json.load(f))
    except Exception as e:
        print(f"Fail to read JSON configuration: {e}")
        return DEFAULT_CONFIG.copy()

def normalize_config(config):
    """Merge missing values with defaults so the template always has safe values."""
    merged = DEFAULT_CONFIG.copy()
    if isinstance(config, dict):
        merged.update(config)

    amounts = merged.get("question_type_amounts", DEFAULT_CONFIG["question_type_amounts"])
    normalized_amounts = []
    if not isinstance(amounts, list):
        amounts = []
    for i in range(7):
        try:
            normalized_amounts.append(int(amounts[i]))
        except (IndexError, TypeError, ValueError):
            normalized_amounts.append(DEFAULT_CONFIG["question_type_amounts"][i])
    merged["question_type_amounts"] = normalized_amounts

    for key in LIST_PARAMS:
        value = merged.get(key, DEFAULT_CONFIG[key])
        if not isinstance(value, list):
            value = DEFAULT_CONFIG[key]
        merged[key] = [str(item) for item in value if str(item).strip()]

    for key in BOOL_PARAMS:
        merged[key] = bool(merged.get(key, DEFAULT_CONFIG[key]))

    for key in INT_PARAMS:
        try:
            merged[key] = int(merged.get(key, DEFAULT_CONFIG[key]))
        except (TypeError, ValueError):
            merged[key] = DEFAULT_CONFIG[key]

    return merged

def write_config(config):
    """写入JSON配置文件"""
    try:
        os.makedirs(os.path.dirname(CONFIG_JSON_PATH), exist_ok=True)
        with open(CONFIG_JSON_PATH, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Fail to write JSON configuration: {e}")
        return False

def ocaml_string_literal(value):
    """Render a Python string as a safe OCaml string literal."""
    text = str(value)
    text = (
        text.replace("\\", "\\\\")
            .replace('"', '\\"')
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
    )
    return f'"{text}"'

def format_ocaml_value(value):
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, list):
        return "[" + "; ".join(format_ocaml_value(item) for item in value) + "]"
    if isinstance(value, int):
        return str(value)
    return ocaml_string_literal(value)

def render_ml_config(config):
    """Render config.ml content without writing it to disk."""
    normalized = normalize_config(config)
    with open(CONFIG_ML_TEMPLATE_PATH, 'r', encoding='utf-8') as f:
        ml_content = f.read()

    for key, value in normalized.items():
        ml_content = ml_content.replace(f'{{{{ {key} }}}}', format_ocaml_value(value))

    missing = sorted(set(re.findall(r'{{\s*([A-Za-z0-9_]+)\s*}}', ml_content)))
    if missing:
        raise ValueError("Missing values for config placeholders: " + ", ".join(missing))

    return ml_content

def generate_ml_config(config=None):
    """根据JSON配置生成OCaml配置文件"""
    try:
        normalized = normalize_config(config if config is not None else read_config())
        errors = validate_config_data(normalized)
        if errors:
            raise ValueError("; ".join(errors))
        ml_content = render_ml_config(normalized)
        ml_path = os.path.join(OCAML_PROJECT_DIR, "config.ml")
        with open(ml_path, 'w', encoding='utf-8') as f:
            f.write(ml_content)
        
        return True
    except Exception as e:
        print(f"Fail to generated OCaml configuration: {e}")
        return False

def parse_int_field(form, name, errors, default=None):
    raw_value = form.get(name, "")
    if raw_value is None or str(raw_value).strip() == "":
        return DEFAULT_CONFIG[name] if default is None else default
    try:
        return int(str(raw_value).strip())
    except ValueError:
        errors.append(f"{name} must be an integer.")
        return DEFAULT_CONFIG[name] if default is None else default

def parse_variable_list(form, name, errors):
    raw_value = form.get(name, "")
    values = [item.strip() for item in raw_value.split(",") if item.strip()]
    if not values:
        errors.append(f"{name} must contain at least one variable name.")
        return []

    seen = set()
    parsed = []
    for value in values:
        upper_value = value.upper()
        if not IDENT_RE.fullmatch(value):
            errors.append(f"{name} contains invalid variable name '{value}'. Use letters, digits, and underscores, starting with a letter.")
            continue
        if upper_value in RESERVED_VAR_NAMES:
            errors.append(f"{name} contains reserved keyword '{value}'.")
            continue
        if value in seen:
            errors.append(f"{name} contains duplicate variable name '{value}'.")
            continue
        seen.add(value)
        parsed.append(value)

    return parsed

def parse_config_form(form):
    errors = []
    config_data = {}

    for name in BOOL_PARAMS:
        config_data[name] = form.get(name) == "true"

    for name in INT_PARAMS:
        config_data[name] = parse_int_field(form, name, errors)

    question_amounts = []
    for i in range(7):
        field_name = f"question_type_amounts_{i}"
        question_amounts.append(parse_int_field(form, field_name, errors, default=0))
    config_data["question_type_amounts"] = question_amounts

    for name in LIST_PARAMS:
        config_data[name] = parse_variable_list(form, name, errors)

    difficulty_level = form.get("difficulty_level", "medium").strip() or "medium"
    config_data["difficulty_level"] = difficulty_level

    return normalize_config(config_data), errors

def validate_range(config, key, errors):
    low, high = INT_RANGES[key]
    value = config[key]
    if value < low or value > high:
        if low == high:
            errors.append(f"{key} must be {low}.")
        else:
            errors.append(f"{key} must be between {low} and {high}.")

def validate_min_max(config, min_key, max_key, errors):
    if config[min_key] > config[max_key]:
        errors.append(f"{min_key} must be less than or equal to {max_key}.")

def has_complex_modulus_candidate(low, high):
    triples = [
        (3, 4, 5), (5, 12, 13), (8, 15, 17), (7, 24, 25),
        (6, 8, 10), (9, 12, 15), (12, 16, 20)
    ]
    signed_options = []
    for a, b, c in triples:
        signed_options.extend([
            (a, b, c), (-a, b, c), (a, -b, c), (-a, -b, c),
            (b, a, c), (-b, a, c), (b, -a, c), (-b, -a, c)
        ])
    return any(low <= re_part <= high and low <= im_part <= high for re_part, im_part, _ in signed_options)

def range_has_nonzero_candidate(low, high):
    return low < 0 or high > 0

def validate_config_data(config):
    errors = []

    for key in INT_PARAMS:
        validate_range(config, key, errors)

    for min_key, max_key in [
        ("min_question_num", "max_question_num"),
        ("min_set_expr_depth", "max_set_expr_depth"),
        ("min_set_element", "max_set_element"),
        ("min_set_prob_num", "max_set_prob_num"),
        ("min_vector_element", "max_vector_element"),
        ("min_vector_prob_num", "max_vector_prob_num"),
        ("min_fun_expr_depth", "max_fun_expr_depth"),
        ("min_derivative_prob_num", "max_derivative_prob_num"),
        ("min_bool_expr_depth", "max_bool_expr_depth"),
        ("min_bool_var_num", "max_bool_var_num"),
        ("min_complex_component", "max_complex_component"),
        ("min_complex_power", "max_complex_power"),
        ("min_sequence_index", "max_sequence_index"),
        ("min_sequence_term", "max_sequence_term"),
        ("min_sequence_difference", "max_sequence_difference"),
        ("min_sequence_ratio", "max_sequence_ratio"),
    ]:
        validate_min_max(config, min_key, max_key, errors)

    if config["problem_type"] == 0 and not config["question_random_amounts"]:
        total_questions = sum(config["question_type_amounts"])
        if any(amount < 0 or amount > 10 for amount in config["question_type_amounts"]):
            errors.append("Each question_type_amounts value must be between 0 and 10.")
        if total_questions <= 0:
            errors.append("At least one question must be requested when All Types uses fixed amounts.")
        if total_questions < config["min_question_num"] or total_questions > config["max_question_num"]:
            errors.append("The total fixed All Types amount must be within min_question_num and max_question_num.")

    if config["max_set_def_num"] > len(config["set_variables"]):
        errors.append("max_set_def_num must be less than or equal to the number of set_variables.")

    if config["max_vector_def_num"] > len(config["vector_variables"]):
        errors.append("max_vector_def_num must be less than or equal to the number of vector_variables.")

    if config["vector_dimension"] != 3:
        errors.append("vector_dimension must be 3 because the current vector generator includes cross product questions.")

    if config["calculus_question_mode"] == 0 and config["derivative_weight"] + config["integral_weight"] <= 0:
        errors.append("At least one calculus weight must be positive in mixed mode.")

    if config["boolean_question_mode"] == 0 and config["boolean_eval_weight"] + config["boolean_equiv_weight"] <= 0:
        errors.append("At least one Boolean Algebra weight must be positive in mixed mode.")

    if config["max_bool_var_num"] > len(config["boolean_variables"]):
        errors.append("max_bool_var_num must be less than or equal to the number of boolean_variables.")

    if config["complex_question_mode"] == 0:
        total_complex_weight = (
            config["complex_arithmetic_weight"] +
            config["complex_conjugate_weight"] +
            config["complex_modulus_weight"] +
            config["complex_power_i_weight"]
        )
        if total_complex_weight <= 0:
            errors.append("At least one complex-number weight must be positive in mixed mode.")

    if config["sequence_question_mode"] == 0:
        total_sequence_weight = (
            config["arithmetic_sequence_weight"] +
            config["geometric_sequence_weight"] +
            config["arithmetic_sequence_sum_weight"] +
            config["geometric_sequence_sum_weight"]
        )
        if total_sequence_weight <= 0:
            errors.append("At least one sequence weight must be positive in mixed mode.")

    arithmetic_sequence_enabled = (
        config["sequence_question_mode"] in [1, 3] or
        (
            config["sequence_question_mode"] == 0 and
            (config["arithmetic_sequence_weight"] > 0 or config["arithmetic_sequence_sum_weight"] > 0)
        )
    )
    geometric_sequence_enabled = (
        config["sequence_question_mode"] in [2, 4] or
        (
            config["sequence_question_mode"] == 0 and
            (config["geometric_sequence_weight"] > 0 or config["geometric_sequence_sum_weight"] > 0)
        )
    )
    if arithmetic_sequence_enabled and not range_has_nonzero_candidate(
        config["min_sequence_difference"], config["max_sequence_difference"]
    ):
        errors.append("The sequence difference range must include at least one non-zero value.")
    if geometric_sequence_enabled and not range_has_nonzero_candidate(
        config["min_sequence_ratio"], config["max_sequence_ratio"]
    ):
        errors.append("The sequence ratio range must include at least one non-zero value.")

    modulus_enabled = (
        config["complex_question_mode"] == 3 or
        (config["complex_question_mode"] == 0 and config["complex_modulus_weight"] > 0)
    )
    if modulus_enabled and config["min_complex_component"] <= config["max_complex_component"]:
        if not has_complex_modulus_candidate(config["min_complex_component"], config["max_complex_component"]):
            errors.append("The complex component range must include one supported Pythagorean pair for modulus questions, such as 3 and 4.")

    return errors

def read_file_bytes(path):
    if not os.path.exists(path):
        return None
    with open(path, "rb") as f:
        return f.read()

def restore_file(path, content):
    if content is None:
        if os.path.exists(path):
            os.remove(path)
    else:
        with open(path, "wb") as f:
            f.write(content)

def extract_pgml_and_paths(output):
    """从输出中提取PGML代码和文件路径"""
    pgml_code = ""
    ast_path = ""
    pgml_path = ""
    visualization_path = ""
    
    # 提取PGML代码部分
    pgml_match = re.search(r'Generated PGML code:\s*\n(.*?\nENDDOCUMENT\(\);)', output, re.DOTALL)
    if pgml_match:
        pgml_code = pgml_match.group(1).strip()
    
    # 提取AST文件路径
    ast_match = re.search(r'AST saved to:\s*(generated_asts/.*?\.txt)', output)
    if ast_match:
        ast_path = ast_match.group(1)
    
    # 提取PGML文件路径
    pgml_match_path = re.search(r'PGML code saved to:\s*(generated_questions/.*?\.pg)', output)
    if pgml_match_path:
        pgml_path = pgml_match_path.group(1)

    visualization_match = re.search(
        r'Tree visualization saved to:\s*(generated_visualizations/.*?\.html)',
        output
    )
    if visualization_match:
        visualization_path = visualization_match.group(1)

    return pgml_code, ast_path, pgml_path, visualization_path

def read_ast_file(ast_path):
    """读取AST文件内容"""
    try:
        full_ast_path = os.path.join(OCAML_PROJECT_DIR, ast_path)
        with open(full_ast_path, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        return f"Fail to read AST file: {str(e)}"

@app.route('/')
def index():
    config = read_config()
    return render_template('index.html', config=config)

@app.route('/api/webwork/status')
def webwork_status():
    status = WEBWORK_CLIENT.status()
    return jsonify(status), 200 if status.get('available') else 503


@app.route('/api/webwork/render', methods=['POST'])
def webwork_render():
    payload = request.get_json(silent=True)
    if payload is None:
        payload = request.form
    if not hasattr(payload, 'get'):
        return jsonify(success=False, error='Request body must be a JSON object or form data.',
                       code='invalid_request'), 400
    try:
        html = WEBWORK_CLIENT.render(payload.get('pg_source', ''), payload.get('problem_seed', 1))
    except WebworkClientError as error:
        return jsonify(success=False, error=str(error), code=error.code), error.http_status
    return jsonify(success=True, html=html)


@app.route('/api/webwork/check', methods=['POST'])
def webwork_check():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify(success=False, error='Request body must be a JSON object.',
                       code='invalid_request'), 400
    try:
        grade = WEBWORK_CLIENT.check(payload.get('pg_source', ''), payload.get('answers'),
                                     payload.get('problem_seed', 1))
    except WebworkClientError as error:
        return jsonify(success=False, error=str(error), code=error.code), error.http_status
    return jsonify(success=True, **grade)


@app.route('/config', methods=['GET', 'POST'])
def config():
    if request.method == 'POST':
        config_data, parse_errors = parse_config_form(request.form)
        validation_errors = validate_config_data(config_data)
        errors = parse_errors + validation_errors

        if errors:
            return jsonify({
                'success': False,
                'error': 'Config validation failed.',
                'errors': errors
            })

        try:
            ml_content = render_ml_config(config_data)
        except Exception as e:
            return jsonify({
                'success': False,
                'error': f'Failed to render OCaml config: {str(e)}'
            })

        ml_path = os.path.join(OCAML_PROJECT_DIR, "config.ml")
        previous_json = read_file_bytes(CONFIG_JSON_PATH)
        previous_ml = read_file_bytes(ml_path)

        def rollback_config_files():
            restore_file(CONFIG_JSON_PATH, previous_json)
            restore_file(ml_path, previous_ml)

        if not write_config(config_data):
            rollback_config_files()
            return jsonify({'success': False, 'error': 'Configs update failed!'})

        try:
            with open(ml_path, 'w', encoding='utf-8') as f:
                f.write(ml_content)

            build_result = subprocess.run(
                dune_command("build"),
                capture_output=True,
                text=True,
                timeout=60,
                cwd=OCAML_PROJECT_DIR
            )

            if build_result.returncode == 0:
                return jsonify({'success': True, 'message': 'Configs update successful and dune build completed!'})

            rollback_config_files()
            return jsonify({
                'success': False,
                'error': 'Dune build failed. Previous config has been restored.',
                'build_error': build_result.stderr
            })

        except subprocess.TimeoutExpired:
            rollback_config_files()
            return jsonify({
                'success': False,
                'error': 'Dune build timed out. Previous config has been restored.'
            })
        except Exception as e:
            rollback_config_files()
            return jsonify({
                'success': False,
                'error': f'Dune build error. Previous config has been restored: {str(e)}'
            })

    else:
        config = read_config()
        return render_template('config.html', config=config)

def read_user_api_keys():
    """读取用户API密钥"""
    try:
        if os.path.exists(USER_API_KEYS_FILE):
            with open(USER_API_KEYS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        return {}
    except Exception as e:
        print(f"Fail to read user API keys: {e}")
        return {}

def write_user_api_keys(api_keys):
    """写入用户API密钥"""
    try:
        with open(USER_API_KEYS_FILE, 'w', encoding='utf-8') as f:
            json.dump(api_keys, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Fail to write user API keys: {e}")
        return False

def has_arithmetic_problems(pgml_content):
    """检查PGML内容是否包含算术问题"""
    import re
    patterns = [
        r"What is the value of \[`([^`]+)`\]\?\s*\[_{5}\]\{([^}]+)\}",
        r"\[`([^`]+)`\]\s+is equal to\s*\[_{5}\]\{([^}]+)\}"
    ]
    
    for pattern in patterns:
        if re.search(pattern, pgml_content):
            return True
    return False

def run_llm_context_generation(original_pg_path, api_key, student_id):
    """在后台线程中运行LLM语境生成"""
    try:
        # 检查文件是否存在
        if not os.path.exists(original_pg_path):
            return False, "", f"File not found: {original_pg_path}"
        
        # 检查Python脚本是否存在
        if not os.path.exists(LLM_CONTEXT_SCRIPT):
            return False, "", f"LLM context script not found: {LLM_CONTEXT_SCRIPT}"
        
        print(f"Running LLM context generation for: {original_pg_path}")
        
        # 构建命令
        cmd = [
            sys.executable,  # 使用当前Python解释器
            LLM_CONTEXT_SCRIPT,
            original_pg_path,
            api_key
        ]
        
        # 运行LLM语境生成
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,  # 2分钟超时
            cwd=LLM_CONTEXT_DIR
        )
        
        print(f"LLM context generation completed with return code: {result.returncode}")
        if result.stdout:
            print(f"STDOUT: {result.stdout}")
        if result.stderr:
            print(f"STDERR: {result.stderr}")
        
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        print(f"Error in run_llm_context_generation: {str(e)}")
        return False, "", str(e)

# 添加新的路由
@app.route('/save_api_key', methods=['POST'])
def save_api_key():
    """保存用户API密钥"""
    try:
        api_key = request.form.get('api_key', '').strip()
        
        if not api_key:
            return jsonify({'success': False, 'error': 'API key cannot be empty'})
        
        # 读取现有密钥
        api_keys = read_user_api_keys()
        # 这里可以添加用户识别，目前先简单存储
        api_keys['default_user'] = api_key
        
        if write_user_api_keys(api_keys):
            return jsonify({'success': True, 'message': 'API key saved successfully'})
        else:
            return jsonify({'success': False, 'error': 'Failed to save API key'})
            
    except Exception as e:
        return jsonify({'success': False, 'error': f'Error saving API key: {str(e)}'})

@app.route('/api_key_status')
def api_key_status():
    """检查API密钥状态"""
    api_keys = read_user_api_keys()
    has_api_key = bool(api_keys.get('default_user'))
    return jsonify({'has_api_key': has_api_key})

@app.route('/generate_context', methods=['POST'])
def generate_context():
    """为生成的题目生成语境"""
    try:
        student_id = request.form.get('student_id', '').strip()
        original_pg_path = request.form.get('original_pg_path', '').strip()
        
        if not student_id or not original_pg_path:
            return jsonify({'success': False, 'error': 'Missing student ID or file path'})
        
        # 检查API密钥
        api_keys = read_user_api_keys()
        api_key = api_keys.get('default_user', '')
        
        if not api_key:
            return jsonify({'success': False, 'error': 'No API key found. Please set your DeepSeek API key first.'})
        
        # 检查原始文件是否存在
        full_original_path = os.path.join(OCAML_PROJECT_DIR, original_pg_path)
        if not os.path.exists(full_original_path):
            return jsonify({'success': False, 'error': 'Original PG file not found'})
        
        # 读取PGML内容检查是否有算术问题
        with open(full_original_path, 'r', encoding='utf-8') as f:
            pgml_content = f.read()
        
        pgml_match = re.search(r'BEGIN_PGML(.*?)END_PGML', pgml_content, re.DOTALL)
        if pgml_match:
            pgml_content_only = pgml_match.group(1)
            if not has_arithmetic_problems(pgml_content_only):
                return jsonify({'success': False, 'error': 'No arithmetic problems found in the generated questions'})
        
        # 在后台线程中运行语境生成
        def run_context_generation():
            success, stdout, stderr = run_llm_context_generation(full_original_path, api_key, student_id)
            # 这里可以添加结果处理逻辑，比如更新数据库或发送通知
        
        thread = Thread(target=run_context_generation)
        thread.daemon = True
        thread.start()
        
        # 构建预期的上下文文件路径
        base_name = os.path.splitext(os.path.basename(original_pg_path))[0]
        context_dir = f"{base_name}_context"
        context_pg_path = os.path.join("generated_questions", context_dir, f"{base_name}_context.pg")
        full_context_path = os.path.join(OCAML_PROJECT_DIR, context_pg_path)
        
        return jsonify({
            'success': True, 
            'message': 'Context generation started in background',
            'context_pg_path': context_pg_path,
            'original_pg_path': original_pg_path
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': f'Error generating context: {str(e)}'})

@app.route('/check_context_status', methods=['POST'])
def check_context_status():
    """检查语境生成状态"""
    try:
        context_pg_path = request.form.get('context_pg_path', '').strip()
        
        if not context_pg_path:
            return jsonify({'success': False, 'error': 'No context path provided'})
        
        full_context_path = os.path.join(OCAML_PROJECT_DIR, context_pg_path)
        
        if os.path.exists(full_context_path):
            # 读取完整的上下文PG文件内容
            with open(full_context_path, 'r', encoding='utf-8') as f:
                full_content = f.read()
            
            return jsonify({
                'success': True,
                'completed': True,
                'pgml_code': full_content,
                'context_pg_path': context_pg_path
            })
        
        return jsonify({
            'success': True,
            'completed': False,
            'message': 'Context generation in progress...'
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': f'Error checking context status: {str(e)}'})

def is_rhema_library(path):
    """A .rhm file without a `start` declaration is a library: it is meant to
    be included by a grammar and cannot generate questions on its own."""
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return not re.search(r'^\s*start\s+[A-Za-z_]', f.read(), re.M)
    except OSError:
        return False


def rhema_grammar_dirs():
    """The user's directory first, then the shipped library."""
    return [d for d in (RHEMA_GRAMMAR_DIR, RHEMA_STDLIB_DIR) if os.path.isdir(d)]


def rhema_grammar_path(name):
    """Where a grammar of that name lives: the user's copy wins over the
    library's. None when no such file exists."""
    for directory in rhema_grammar_dirs():
        path = os.path.join(directory, name)
        if os.path.isfile(path):
            return path
    return None


def list_rhema_grammars():
    """The .rhm files a user can choose from: grammars, not libraries."""
    names = set()
    for directory in rhema_grammar_dirs():
        for name in os.listdir(directory):
            # a leading dot marks the temporary file a check writes
            if name.endswith(".rhm") and not name.startswith(".") \
                    and not is_rhema_library(os.path.join(directory, name)):
                names.add(name)
    return sorted(names)


RHEMA_QUESTION_BLOCK = re.compile(r'^\s*question\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{', re.M)


def list_rhema_questions(name):
    """The question types a .rhm file declares: `main` for its file-level
    start, prompt and answer, plus one per `question NAME { ... }` block.
    A file without blocks has just `main`, so the list is left empty."""
    path = rhema_grammar_path(name)
    if path is None:
        return []
    try:
        with open(path, 'r', encoding='utf-8') as f:
            text = f.read()
    except OSError:
        return []
    blocks = RHEMA_QUESTION_BLOCK.findall(text)
    if not blocks:
        return []
    has_main = re.search(r'^\s*start\s+[A-Za-z_]', text, re.M) is not None
    return (['main'] if has_main else []) + blocks




@app.route('/rhema_grammars')
def rhema_grammars():
    grammars = list_rhema_grammars()
    return jsonify({
        'success': True,
        'grammars': grammars,
        'catalog': [{
            'name': name,
            'title': TITLES.get(name[:-4], name[:-4].replace('_', ' ').title()),
            'custom': os.path.isfile(os.path.join(RHEMA_GRAMMAR_DIR, name)),
        } for name in grammars],
        # file -> its named questions, for the files that have more than main
        'questions': {name: questions for name in grammars
                      for questions in [list_rhema_questions(name)] if questions},
    })


@app.route('/rhema_grammar')
def rhema_grammar():
    """Return the text of a .rhm file so it can be edited in the browser."""
    name = os.path.basename(request.args.get('name', '').strip() or RHEMA_DEFAULT_GRAMMAR)
    if name not in list_rhema_grammars():
        return jsonify({'success': False, 'error': f'Unknown grammar file: {name}'}), 400
    try:
        with open(rhema_grammar_path(name), 'r', encoding='utf-8') as f:
            return jsonify({'success': True, 'name': name, 'content': f.read()})
    except OSError as e:
        return jsonify({'success': False, 'error': str(e)}), 500


def check_rhema_source(path, display_name=None):
    """Run `rhema check` on a .rhm file. Returns (ok, message).

    Checking happens in a temporary file so that a broken edit never reaches
    disk, but rhema reports problems as "<path>:line:column: ...". Rewriting
    that path to the grammar the user is actually editing keeps the message
    readable; otherwise it points at a scratch name like .check_ab12cd.rhm.
    """
    if not os.path.exists(RHEMA_COMMAND):
        return False, ('rhema was not found. Run "dune build" in the '
                       'generator directory first.')
    try:
        result = subprocess.run(
            [RHEMA_COMMAND, "check", path],
            capture_output=True, text=True, timeout=20, cwd=OCAML_PROJECT_DIR,
        )
    except subprocess.TimeoutExpired:
        return False, 'Checking the grammar timed out.'

    def readable(text):
        if not display_name:
            return text
        # rhema is run with cwd=generator, so it may print either form.
        for written in (path, os.path.relpath(path, OCAML_PROJECT_DIR)):
            text = text.replace(written, display_name)
        return text

    if result.returncode == 0:
        return True, readable(result.stdout.strip())
    return False, readable(
        result.stderr.strip() or result.stdout.strip() or 'Invalid grammar.')


@app.route('/rhema_grammar_check', methods=['POST'])
def rhema_grammar_check():
    """Check submitted grammar text without saving it."""
    content = request.form.get('content', '')
    display = os.path.basename(request.form.get('name', '').strip() or RHEMA_DEFAULT_GRAMMAR)
    os.makedirs(RHEMA_GRAMMAR_DIR, exist_ok=True)
    handle, temporary = tempfile.mkstemp(prefix='.check_', suffix='.rhm', dir=RHEMA_GRAMMAR_DIR)
    try:
        with os.fdopen(handle, 'w', encoding='utf-8') as f:
            f.write(content)
        ok, message = check_rhema_source(temporary, display_name=display)
    finally:
        if os.path.exists(temporary):
            os.remove(temporary)
    return jsonify({'success': ok, 'message' if ok else 'error': message})


@app.route('/rhema_grammar_save', methods=['POST'])
def rhema_grammar_save():
    """Save grammar text, but only if it checks out.

    A broken .rhm file would make every later generation fail, so the new text
    is validated in a temporary file first and only moved into place once it
    passes.
    """
    name = request.form.get('name', '').strip()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.rhm', name):
        return jsonify({'success': False, 'error':
                        'Use 1-80 letters, numbers, underscores or hyphens, starting '
                        'with a letter or number, followed by .rhm.'}), 400
    create = request.form.get('create') == 'true'
    os.makedirs(RHEMA_GRAMMAR_DIR, exist_ok=True)
    # A new file is the user's; an existing one is saved where it lives.
    target = (rhema_grammar_path(name) if not create else None) or os.path.join(RHEMA_GRAMMAR_DIR, name)
    if os.path.islink(target):
        return jsonify({'success': False, 'error': 'Cannot save a symbolic link.'}), 400
    if create and os.path.lexists(target):
        return jsonify({'success': False, 'error': f'{name} already exists. Choose another name.'}), 409
    content = request.form.get('content', '')

    handle, temporary = tempfile.mkstemp(prefix='.check_', suffix='.rhm', dir=os.path.dirname(target))
    try:
        with os.fdopen(handle, 'w', encoding='utf-8') as f:
            f.write(content)
        ok, message = check_rhema_source(temporary, display_name=name)
        if not ok:
            return jsonify({'success': False, 'error': message})
        if create:
            # Publish the checked file atomically without replacing another file.
            try:
                os.link(temporary, target)
            except FileExistsError:
                return jsonify({'success': False, 'error':
                                f'{name} already exists. Choose another name.'}), 409
        else:
            # Keep one backup so an edit can be undone from the shell.
            if os.path.exists(target):
                shutil.copyfile(target, target + '.bak')
            shutil.move(temporary, target)
            temporary = None
    except OSError as error:
        return jsonify({'success': False, 'error': str(error)}), 500
    finally:
        if temporary and os.path.exists(temporary):
            os.remove(temporary)

    return jsonify({'success': True, 'name': name, 'message': message})


@app.route('/run_rhema', methods=['POST'])
def run_rhema():
    """Generate a paper from a .rhm grammar file.

    No dune build is needed here: the grammar is read at run time, so editing
    the .rhm file is enough to change what comes out.
    """
    # An assignment is one paper, the same every time; a student number is
    # optional and gives that student a paper of their own.
    student_id = request.form.get('student_id', '').strip()
    if student_id and not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', student_id):
        return jsonify({
            'error': ('Student number may contain only letters, numbers, '
                      'underscores, and hyphens.')
        }), 400

    grammar = request.form.get('grammar', '').strip() or RHEMA_DEFAULT_GRAMMAR
    # Keep the choice inside the grammar directory.
    grammar = os.path.basename(grammar)
    if grammar not in list_rhema_grammars():
        return jsonify({'error': f'Unknown grammar file: {grammar}'}), 400
    # One of the file's named questions; empty means the file's default.
    question = request.form.get('question', '').strip()
    if question and not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', question):
        return jsonify({'error': f'Invalid question name: {question}'}), 400

    if not os.path.exists(RHEMA_COMMAND):
        return jsonify({
            'error': 'rhema was not found. Run "dune build" in the generator '
                     'directory first.'
        }), 500

    config = read_config()
    try:
        count = int(request.form.get('count', config.get('max_question_num', 6)))
    except (TypeError, ValueError):
        count = 6
    count = max(1, min(count, 50))

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    base_name = f"{student_id or 'assignment'}_{timestamp}"
    relative_output = f"generated_questions/{base_name}.pg"
    relative_ast = f"generated_asts/{base_name}_ast.txt"
    relative_visualization = f"generated_visualizations/{base_name}_trees.html"
    output_path = os.path.join(OCAML_PROJECT_DIR, relative_output)
    ast_path = os.path.join(OCAML_PROJECT_DIR, relative_ast)
    visualization_path = os.path.join(OCAML_PROJECT_DIR, relative_visualization)
    for path in (output_path, ast_path, visualization_path):
        os.makedirs(os.path.dirname(path), exist_ok=True)

    command = [
        RHEMA_COMMAND,
        os.path.relpath(rhema_grammar_path(grammar), OCAML_PROJECT_DIR),
        "-o", relative_output,
        "--count", str(count),
        "--assignment", f"{grammar}:{question or 'main'}",
        *(["--student", student_id] if student_id else []),
        # Difficulty is left to the .rhm file. Overriding len from config.json
        # here would silently ignore what the user just typed into the grammar
        # editor, which defeats the point of the file being the definition.
        "--ast-out", relative_ast,
        "--visualization-out", relative_visualization,
        *(["--question", question] if question else []),
    ]

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=OCAML_PROJECT_DIR,
        )
    except subprocess.TimeoutExpired:
        return jsonify({'error': 'Generation timed out.'}), 500
    except Exception as e:
        return jsonify({'error': f'Generation failed: {e}'}), 500

    if result.returncode != 0:
        # rhema reports grammar problems with file:line:column on stderr.
        return jsonify({
            'success': False,
            'error': result.stderr.strip() or 'Generation failed.'
        })

    try:
        with open(output_path, 'r', encoding='utf-8') as f:
            pgml_code = f.read()
    except OSError as e:
        return jsonify({'error': f'Could not read the generated file: {e}'}), 500

    return jsonify({
        'success': True,
        'grammar': grammar,
        'pgml_code': pgml_code,
        'pgml_path': relative_output,
        'ast_path': relative_ast,
        'visualization_path': relative_visualization,
        'visualization_kind': 'attribute_grammar',
        'original_pgml_content': pgml_code,
    })


@app.route('/run', methods=['POST'])
def run_program():
    # 在运行前确保配置是最新的
    if not generate_ml_config():
        return jsonify({'error': 'Configuration generation failed.'}), 500
        
    student_id = request.form.get('student_id', '').strip()
    
    if not student_id:
        return jsonify({'error': 'Please enter a student number.'}), 400
    
    try:
        result = subprocess.run(
            dune_command("exec", "./unparser.exe", "--", student_id),
            capture_output=True,
            text=True,
            timeout=30,
            cwd=OCAML_PROJECT_DIR
        )
        
        if result.returncode == 0:
            # 提取PGML代码和文件路径
            pgml_code, ast_path, pgml_path, visualization_path = extract_pgml_and_paths(result.stdout)
            
            return jsonify({
                'success': True,
                'output': result.stdout,
                'pgml_code': pgml_code,
                'ast_path': ast_path,
                'pgml_path': pgml_path,
                'visualization_path': visualization_path,
                'original_pgml_content': pgml_code  # 添加原始PGML内容
            })
        else:
            return jsonify({
                'success': False,
                'error': f"Program execution error: {result.stderr}"
            })
            
    except subprocess.TimeoutExpired:
        return jsonify({'error': 'Program execution has timed out.'}), 500
    except FileNotFoundError:
        return jsonify({'error': 'The OCaml program cannot be found. Please ensure that the path is correct.'}), 500
    except Exception as e:
        return jsonify({'error': f'An error occurred during the execution process: {str(e)}'}), 500

@app.route('/get_ast', methods=['POST'])
def get_ast():
    """获取AST文件内容"""
    ast_path = request.form.get('ast_path', '').strip()
    
    if not ast_path:
        return jsonify({'error': 'No path for the AST file was provided.'}), 400
    
    try:
        ast_content = read_ast_file(ast_path)
        return jsonify({
            'success': True,
            'ast_content': ast_content
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Failed to read the AST file: {str(e)}'
        })

@app.route('/tree_visualization')
def tree_visualization():
    filename = os.path.basename(request.args.get('filename', '').strip())
    if not filename:
        return "No visualization filename provided.", 400

    visualization_dir = os.path.join(OCAML_PROJECT_DIR, "generated_visualizations")
    if not os.path.exists(os.path.join(visualization_dir, filename)):
        return "Tree visualization not found.", 404

    return send_from_directory(visualization_dir, filename)

@app.route('/save_pgml', methods=['POST'])
def save_pgml():
    """保存修改后的PGML代码"""
    try:
        filename = request.form.get('filename', '').strip()
        content = request.form.get('content', '').strip()
        
        if not filename:
            return jsonify({'success': False, 'error': 'No filename provided'})
        
        if not content:
            return jsonify({'success': False, 'error': 'No content provided'})
        
        # 保存到原来的PG文件
        pg_path = os.path.join(OCAML_PROJECT_DIR, "generated_questions", filename)
        with open(pg_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return jsonify({'success': True, 'message': 'PGML code saved successfully'})
        
    except Exception as e:
        return jsonify({'success': False, 'error': f'Failed to save PGML code: {str(e)}'})

@app.route('/history')
def get_history():
    """获取历史生成记录"""
    try:
        history = []
        # 读取所有生成的PG文件
        pg_files = glob.glob(os.path.join(OCAML_PROJECT_DIR, "generated_questions", "*.pg"))
        
        for file_path in pg_files:
            filename = os.path.basename(file_path)
            # 解析文件名：学号_年月日_时分秒.pg
            if '_' in filename:
                parts = filename.replace('.pg', '').split('_')
                if len(parts) >= 3:
                    student_id = parts[0]
                    date_str = parts[1]
                    time_str = parts[2]
                    
                    # 格式化时间显示
                    try:
                        date_obj = datetime.strptime(f"{date_str}{time_str}", "%Y%m%d%H%M%S")
                        formatted_time = date_obj.strftime("%Y-%m-%d %H:%M:%S")
                    except:
                        formatted_time = f"{date_str}_{time_str}"
                    
                    # 检查是否存在对应的AST文件
                    stem = filename[:-3]
                    ast_filename = f"{stem}_ast.txt"
                    ast_path = os.path.join(OCAML_PROJECT_DIR, "generated_asts", ast_filename)
                    has_ast = os.path.exists(ast_path)
                    visualization_filename = f"{stem}_trees.html"
                    visualization_path = os.path.join(
                        OCAML_PROJECT_DIR,
                        "generated_visualizations",
                        visualization_filename
                    )
                    
                    history.append({
                        'filename': filename,
                        'student_id': student_id,
                        'timestamp': formatted_time,
                        'has_ast': has_ast,
                        'has_visualization': os.path.exists(visualization_path),
                        'visualization_filename': visualization_filename,
                        'raw_timestamp': f"{date_str}_{time_str}"
                    })
        
        # 按时间倒序排列
        history.sort(key=lambda x: x.get('raw_timestamp', ''), reverse=True)
        return jsonify({'success': True, 'history': history})
        
    except Exception as e:
        return jsonify({'success': False, 'error': f'Failed to load history: {str(e)}'})

@app.route('/history_content')
def get_history_content():
    """获取历史记录的内容"""
    try:
        filename = request.args.get('filename', '').strip()
        if not filename:
            return jsonify({'success': False, 'error': 'No filename provided'})
        
        # 首先尝试在 generated_questions 目录中查找
        pg_path = os.path.join(OCAML_PROJECT_DIR, "generated_questions", filename)
        
        # 如果找不到，尝试在语境目录中查找
        if not os.path.exists(pg_path):
            # 检查是否是语境文件
            if '_context.pg' in filename:
                # 直接从语境目录查找
                base_name = filename.replace('_context.pg', '')
                context_dir = f"{base_name}_context"
                pg_path = os.path.join(OCAML_PROJECT_DIR, "generated_questions", context_dir, filename)
            else:
                # 尝试在语境目录中查找对应的语境文件
                base_name = filename.replace('.pg', '')
                context_filename = f"{base_name}_context.pg"
                context_dir = f"{base_name}_context"
                pg_path = os.path.join(OCAML_PROJECT_DIR, "generated_questions", context_dir, context_filename)
        
        if not os.path.exists(pg_path):
            return jsonify({'success': False, 'error': 'PG file not found'})
        
        # 读取完整的PG文件内容
        with open(pg_path, 'r', encoding='utf-8') as f:
            full_content = f.read()
        
        # 尝试读取对应的AST文件
        base_name = filename.replace('.pg', '').replace('_context', '')
        ast_filename = f"{base_name}_ast.txt"
        ast_path = os.path.join(OCAML_PROJECT_DIR, "generated_asts", ast_filename)
        visualization_filename = f"{base_name}_trees.html"
        visualization_path = os.path.join(
            OCAML_PROJECT_DIR,
            "generated_visualizations",
            visualization_filename
        )
        
        ast_content = ""
        if os.path.exists(ast_path):
            with open(ast_path, 'r', encoding='utf-8') as f:
                ast_content = f.read()
        visualization_kind = (
            'attribute_grammar'
            if ast_content.startswith('Attribute Grammar Generated Derivations')
            else 'ast_dcst'
        )

        return jsonify({
            'success': True,
            'pgml_content': full_content,
            'ast_content': ast_content,
            'has_ast': bool(ast_content),
            'has_visualization': os.path.exists(visualization_path),
            'visualization_filename': visualization_filename,
            'visualization_kind': visualization_kind
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': f'Failed to load content: {str(e)}'})

register_teacher_routes(app, BASE_DIR)


def open_browser_when_ready(url):
    """Open the local UI after Flask has had time to start listening."""
    time.sleep(1)
    webbrowser.open_new_tab(url)


if __name__ == '__main__':
    host = '0.0.0.0'
    port = int(os.environ.get('APP_PORT', '5001'))
    browser_url = f'http://127.0.0.1:{port}'

    # Werkzeug starts this file twice in debug mode. Only the reloader parent
    # should launch the browser, otherwise two tabs are opened.
    if os.environ.get('WERKZEUG_RUN_MAIN') != 'true':
        Thread(
            target=open_browser_when_ready,
            args=(browser_url,),
            daemon=True
        ).start()

    app.run(debug=True, host=host, port=port)
