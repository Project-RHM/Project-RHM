from flask import Flask, render_template, request, jsonify
import subprocess
import os
import json
import sys
import re
import glob
from datetime import datetime
import shutil
from threading import Thread

# 获取当前文件所在的绝对路径
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 将项目根目录添加到Python路径
sys.path.insert(0, BASE_DIR)

app = Flask(__name__)

# 配置OCaml程序路径 - 使用绝对路径
OCAML_PROJECT_DIR = os.path.join(BASE_DIR, "generator")
OCAML_PROGRAM_PATH = os.path.join(OCAML_PROJECT_DIR, "_build/default/unparser.exe")
CONFIG_JSON_PATH = os.path.join(BASE_DIR, "config_setting/config.json")
CONFIG_ML_TEMPLATE_PATH = os.path.join(BASE_DIR, "config_setting/config.ml.template")

LLM_CONTEXT_DIR = os.path.join(BASE_DIR, "llm_context")
LLM_CONTEXT_SCRIPT = os.path.join(LLM_CONTEXT_DIR, "llm_context.py")
API_CALL_SCRIPT = os.path.join(LLM_CONTEXT_DIR, "api_call.py")

# 添加用户API密钥存储
USER_API_KEYS_FILE = os.path.join(BASE_DIR, "user_api_keys.json")

# 设置工作目录
os.chdir(BASE_DIR)

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
    "question_type_amounts": [1, 1, 1, 2, 2, 1],
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
    "min_complex_power", "max_complex_power"
]

INT_RANGES = {
    "min_question_num": (1, 20),
    "max_question_num": (1, 20),
    "problem_type": (0, 6),
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
    for i in range(6):
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
    for i in range(6):
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
    
    return pgml_code, ast_path, pgml_path

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
                ["dune", "build"],
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
            ["dune", "exec", "./unparser.exe", "--", student_id],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=OCAML_PROJECT_DIR
        )
        
        if result.returncode == 0:
            # 提取PGML代码和文件路径
            pgml_code, ast_path, pgml_path = extract_pgml_and_paths(result.stdout)
            
            return jsonify({
                'success': True,
                'output': result.stdout,
                'pgml_code': pgml_code,
                'ast_path': ast_path,
                'pgml_path': pgml_path,
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
                    ast_filename = f"{student_id}_{date_str}_{time_str}_ast.txt"
                    ast_path = os.path.join(OCAML_PROJECT_DIR, "generated_asts", ast_filename)
                    has_ast = os.path.exists(ast_path)
                    
                    history.append({
                        'filename': filename,
                        'student_id': student_id,
                        'timestamp': formatted_time,
                        'has_ast': has_ast,
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
        
        ast_content = ""
        if os.path.exists(ast_path):
            with open(ast_path, 'r', encoding='utf-8') as f:
                ast_content = f.read()
        
        return jsonify({
            'success': True,
            'pgml_content': full_content,
            'ast_content': ast_content,
            'has_ast': bool(ast_content)
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': f'Failed to load content: {str(e)}'})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
