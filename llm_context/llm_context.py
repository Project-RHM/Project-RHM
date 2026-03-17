import re
import json
import os
import sys
from api_call import batch_call_deepseek_api, save_results_to_json

def read_pg_file(filename):
    """Read .pg file content"""
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    return content

def extract_pgml_content(content):
    """Extract content between BEGIN_PGML and END_PGML"""
    pattern = r'BEGIN_PGML(.*?)END_PGML'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        return match.group(1).strip()
    return ""

def extract_arithmetic_problems(pgml_content):
    """Extract arithmetic problems and their solutions"""
    problems = []
    
    # Macth arithmetic problem patterns
    patterns = [
        # Pattern 1: What is the value of [`expression`]? [_____]{answer}
        r"What is the value of \[`([^`]+)`\]\?\s*\[_{5}\]\{([^}]+)\}",
        # Pattern 2: [`expression`] is equal to [_____]{answer}
        r"\[`([^`]+)`\]\s+is equal to\s*\[_{5}\]\{([^}]+)\}"
    ]
    
    for pattern in patterns:
        matches = re.finditer(pattern, pgml_content)
        for match in matches:
            question = match.group(1).strip()
            answer_raw = match.group(2).strip()
            answer = extract_answer_value(answer_raw)
            
            if answer is not None:
                problems.append({
                    "question": question,
                    "answer": answer
                })
    
    return problems

def extract_answer_value(answer_raw):
    """Extract numerical values from the original answer string"""
    # Handle various answer formats
    if answer_raw.startswith('answer=>'):
        # Format: answer=>163,width=>4 or answer=>Formula('111'),width=>9
        if 'Formula' in answer_raw:
            # Extract the value from Formula
            match = re.search(r"Formula\('([^']+)'\)", answer_raw)
            if match:
                return match.group(1)
        elif 'Real' in answer_raw:
            # Extract the value from Real
            match = re.search(r"Real\(([^)]+)\)", answer_raw)
            if match:
                value = match.group(1).rstrip('.')
                return value
        else:
            # Extract the value directly
            match = re.search(r'answer=>([^,]+)', answer_raw)
            if match:
                return match.group(1)
    elif answer_raw.startswith('Formula'):
        # Format: Formula('4')
        match = re.search(r"Formula\('([^']+)'\)", answer_raw)
        if match:
            return match.group(1)
    elif answer_raw.startswith('Real'):
        # Format: Real(124.)
        match = re.search(r"Real\(([^)]+)\)", answer_raw)
        if match:
            value = match.group(1).rstrip('.')
            return value
    else:
        # Format: 6.66666666667
        # Check if it is a number (including decimals and negative numbers)
        try:
            float(answer_raw)
            return answer_raw
        except ValueError:
            return None
    
    return None

def wrap_numbers_in_text(text):
    """Wrap the numbers in the text with [` `]"""
    # Match the regular expression for numbers (including decimals and negative numbers)
    def replace_match(match):
        number = match.group(0)
        return f"[`{number}`]"
    
    # Match integers, decimals and negative numbers, but avoid matching numbers that are already in [` `]
    pattern = r'(?<!\[`)\b(-?\d+\.?\d*)\b(?!`\])'
    result = re.sub(pattern, replace_match, text)
    return result

def replace_arithmetic_problems(pgml_content, api_results):
    """Replace the original arithmetic problems with generated application problems"""
    modified_content = pgml_content
    
    for result in api_results:
        original_expression = result['original_expression']
        word_problem = result['word_problem']
        answer = result['answer']
        analysis = result['analysis']
        
        # Handling the numbers in word_problem
        processed_word_problem = wrap_numbers_in_text(word_problem)
        
        # Construct replacement content - Escape special characters
        replacement = f"{processed_word_problem}\n\n[_____]{{{answer}}}\n[%\n{original_expression}\n\n{analysis}\n%]"
        
        # Build matching patterns (considering two formats)
        patterns = [
            f"What is the value of \\[`{re.escape(original_expression)}`\\]\\?\\s*\\[_{{5}}\\]\\{{[^}}]+\\}}",
            f"\\[`{re.escape(original_expression)}`\\]\\s+is equal to\\s*\\[_{{5}}\\]\\{{[^}}]+\\}}"
        ]
        
        for pattern in patterns:
            if re.search(pattern, modified_content):
                # Use re.escape to handle the special characters
                safe_replacement = re.escape(replacement)
                # Retain the line breaks and other elements
                safe_replacement = replacement.replace('\\', '\\\\').replace('$', '\\$')
                modified_content = re.sub(pattern, safe_replacement, modified_content)
                break
    
    return modified_content

def create_contextual_pg_file(original_content, modified_pgml, output_filename):
    """Create a new.pg file containing contextual application questions"""
    # Replace the original PGML content with the modified PGML content.
    # Use a more secure method to construct the replacement.
    begin_index = original_content.find("BEGIN_PGML")
    end_index = original_content.find("END_PGML")
    
    if begin_index != -1 and end_index != -1:
        # Calculate the end position of END_PGML
        end_index += len("END_PGML")
        
        # Construct new content
        new_content = (
            original_content[:begin_index] + 
            "BEGIN_PGML\n" + 
            modified_pgml + 
            "\nEND_PGML" + 
            original_content[end_index:]
        )
        
        # Write to a new file
        with open(output_filename, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print(f"The contextualized question file has been created: {output_filename}")
    else:
        print("Error: Unable to find the BEGIN_PGML or END_PGML tags.")

def process_pg_file_with_api_key(input_file, api_key, student_id=""):
    """Handle .pg file with API key"""
    print(f"Processing file: {input_file}")
    
    # 1. Read the original file
    original_content = read_pg_file(input_file)
    
    # 2. Extract the PGML content
    pgml_content = extract_pgml_content(original_content)
    if not pgml_content:
        print("Error: PGML content unfound.")
        return False
    
    # 3. Extract arithmetic problems
    problems = extract_arithmetic_problems(pgml_content)
    print(f"{len(problems)} arithmetic problems found.")
    
    if not problems:
        print("Failed to find processable arithmetic problems.")
        return False
    
    # Print extracted questions
    for i, problem in enumerate(problems, 1):
        print(f"Problem {i}: {problem['question']} = {problem['answer']}")
    
    # 4. Call the API to generate situational application questions
    print("API is invoking for generating contextual application problems...")
    api_results = batch_call_deepseek_api(problems, api_key)
    
    if isinstance(api_results, dict) and "error" in api_results:
        print("Failed to invoke API:", api_results)
        return False
    
    # 5. Create an output folder and save the API results
    base_name = os.path.splitext(os.path.basename(input_file))[0]
    output_dir = os.path.join(os.path.dirname(input_file), f"{base_name}_context")
    
    # Make sure the output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Save the API results to a JSON file
    json_filename = os.path.join(output_dir, f"{base_name}_context.json")
    save_results_to_json(api_results, json_filename)
    
    # 6. Replace the arithmetic problems in PGML
    modified_pgml = replace_arithmetic_problems(pgml_content, api_results)
    
    # 7. Create a new .pg file
    output_file = os.path.join(output_dir, f"{base_name}_context.pg")
    create_contextual_pg_file(original_content, modified_pgml, output_file)
    
    print("Processing completed.")
    return True

def main():
    if len(sys.argv) >= 3:
        input_file = sys.argv[1]
        api_key = sys.argv[2]
        student_id = sys.argv[3] if len(sys.argv) > 3 else ""
        
        success = process_pg_file_with_api_key(input_file, api_key, student_id)
        sys.exit(0 if success else 1)
    else:
        print("Usage: python llm_context.py <input_file> <api_key> [student_id]")

if __name__ == "__main__":
    main()