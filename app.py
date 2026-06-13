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

def read_config():
    """读取JSON配置文件"""
    try:
        with open(CONFIG_JSON_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"Fail to read JSON configuration: {e}")
        return {}

def write_config(config):
    """写入JSON配置文件"""
    try:
        with open(CONFIG_JSON_PATH, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Fail to write JSON configuration: {e}")
        return False

def generate_ml_config():
    """根据JSON配置生成OCaml配置文件"""
    try:
        config = read_config()
        
        # 读取模板文件
        with open(CONFIG_ML_TEMPLATE_PATH, 'r', encoding='utf-8') as f:
            template = f.read()
        
        # 替换占位符
        ml_content = template
        for key, value in config.items():
            if isinstance(value, bool):
                replacement = str(value).lower()
            elif isinstance(value, list):
                if all(isinstance(item, str) for item in value):
                    replacement = '[' + '; '.join(f'"{item}"' for item in value) + ']'
                else:
                    replacement = '[' + '; '.join(str(item) for item in value) + ']'
            else:
                replacement = str(value)
            
            ml_content = ml_content.replace(f'{{{{ {key} }}}}', replacement)
        
        # 写入最终的config.ml
        ml_path = os.path.join(OCAML_PROJECT_DIR, "config.ml")
        with open(ml_path, 'w', encoding='utf-8') as f:
            f.write(ml_content)
        
        return True
    except Exception as e:
        print(f"Fail to generated OCaml configuration: {e}")
        return False

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
        config_data = {}
        
        # 处理表单数据
        config_data['question_random_amounts'] = request.form.get('question_random_amounts') == 'true'
        config_data['shuffle_questions_for_0_type'] = request.form.get('shuffle_questions_for_0_type') == 'true'
        config_data['allow_float'] = request.form.get('allow_float') == 'true'
        
        # Delete 'max_cfg_depth', 'min_cfg_depth',
        int_params = [
            'min_question_num', 'max_question_num',
            'problem_type', 'max_expr_depth', 'min_set_expr_depth', 'max_set_expr_depth',
            'min_set_element', 'max_set_element', 'max_set_def_num', 'min_set_prob_num',
            'max_set_prob_num', 'vector_dimension', 'min_vector_element', 'max_vector_element',
            'max_vector_def_num', 'min_vector_prob_num', 'max_vector_prob_num',
            'min_fun_expr_depth', 'max_fun_expr_depth',             'min_derivative_prob_num',
            'max_derivative_prob_num', 'boolean_question_mode', 'boolean_eval_weight',
            'boolean_equiv_weight', 'min_bool_expr_depth', 'max_bool_expr_depth',
            'min_bool_var_num', 'max_bool_var_num'
        ]
        
        for param in int_params:
            value = request.form.get(param)
            if value and value.strip():
                config_data[param] = int(value)
        
        # 列表参数
        question_amounts = []
        for i in range(5):
            amount = request.form.get(f'question_type_amounts_{i}')
            if amount and amount.strip():
                question_amounts.append(int(amount))

        if len(question_amounts) != 5:
            question_amounts = [0, 0, 0, 0, 0]
        
        config_data['question_type_amounts'] = question_amounts
        
        set_vars_str = request.form.get('set_variables', '')
        if set_vars_str:
            config_data['set_variables'] = [var.strip() for var in set_vars_str.split(',') if var.strip()]
        
        vector_vars_str = request.form.get('vector_variables', '')
        if vector_vars_str:
            config_data['vector_variables'] = [var.strip() for var in vector_vars_str.split(',') if var.strip()]

        boolean_vars_str = request.form.get('boolean_variables', '')
        if boolean_vars_str:
            config_data['boolean_variables'] = [var.strip() for var in boolean_vars_str.split(',') if var.strip()]
        
        # Difficulty level (string parameter)
        difficulty_level = request.form.get('difficulty_level', 'medium')
        config_data['difficulty_level'] = difficulty_level
        
        # 写入JSON配置并生成OCaml配置
        if write_config(config_data) and generate_ml_config():
            # 在配置更新成功后运行 dune build
            try:
                build_result = subprocess.run(
                    ["dune", "build"],
                    capture_output=True,
                    text=True,
                    timeout=60,  # 设置60秒超时，根据实际情况调整
                    cwd=OCAML_PROJECT_DIR
                )
                
                if build_result.returncode == 0:
                    return jsonify({'success': True, 'message': 'Configs update successful and dune build completed!'})
                else:
                    # 构建失败但仍然配置更新成功
                    return jsonify({
                        'success': True, 
                        'message': 'Configs update successful but dune build failed!',
                        'build_error': build_result.stderr
                    })
                    
            except subprocess.TimeoutExpired:
                return jsonify({
                    'success': True,
                    'message': 'Configs update successful but dune build timed out!'
                })
            except Exception as e:
                return jsonify({
                    'success': True,
                    'message': f'Configs update successful but dune build error: {str(e)}'
                })
        else:
            return jsonify({'success': False, 'error': 'Configs update failed!'})
    
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
