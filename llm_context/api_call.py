import json
import requests
from datetime import datetime

def batch_call_deepseek_api(problems, api_key, model="deepseek-chat"):
    """
    Batch call the DeepSeek API to generate math word problems
    
    Args:
        problems: list of dict, each dict contains 'question' and 'answer'
        api_key: str, DeepSeek API key
        model: str, model name
    
    Returns:
        dict: API response
    """

    full_prompt = f"""
# Role
You are a Mathematical Contextual Content Generator. Your task is to transform mathematical problems into real-life scenario-based word problems that are familiar to elementary school students, and then provide analytical solutions.

# Task
For each given Question-Answer Pair, you must complete the following three parts, but before generating, you must first perform a Priority Analysis:
Step 0: Priority Analysis
Identify all operators in the given expression.
Determine the order of operations according to the rule: {{ *, / }} > {{ +, - }}.
Output analysis result: Use concise symbolic expressions to clearly mark the parts that should be calculated first. For example, for 2 + 3 * 4, output 3 * 4.
Step 1: Generate Problem
Based on the question and priority analysis results, generate a scenario-based word problem.
Step 2: Provide Answer
Directly provide the correct answer to the original question.
Step 3: Write Analysis
Provide clear and concise step-by-step solutions to the mathematical problem within the scenario.

# Requirements & Constraints
1. Real-life Context: Scenarios must be closely related to elementary students' daily life experiences (e.g., school life, family activities, hobbies, games, shopping, sharing food).
2. Length: Problem description should be between 60-110 words.
3. Clear Problem Statement: The scenario must contain a clear mathematical problem. Do not reveal the answer within the scenario description.
4. Hide Calculations: Avoid directly describing calculation processes (e.g., 'he added...', 'he multiplied...'). The need for calculation should arise naturally from the situation.
5. Handling Special Values:
   - For zero values: Ignore zero values directly if it's not necessary (do not even mention it in the scenario), or assign reasonable context if it's necessary (e.g., "started with none", "used up", "reset to zero", etc.), avoiding blunt mentions like "0 objects".
   - For negative results: Must be designed as reasonable scenarios of debt, shortage, or deficit (e.g., "how many more are needed", "how much money is owed", "how much less than before", etc.), ensuring negative numbers make sense in real-world contexts.
6. Priority Rules:
Operation priority strictly follows: {{ *, / }} > {{+, - }}.
* (Multiplication) and / (Division) have the same highest priority.
+ (Addition) and - (Subtraction) have the same lowest priority.
Associativity: For operations of the same priority (e.g., consecutive + and -), default to left-to-right order.
7. Vocabulary Restriction: The word "stickers" is prohibited.

IMPORTANT: YOU MUST GIVE THE OUTPUT IN JSON FORMAT!!!

# Example
Input (JSON format):
[
  {{
    "question": "(10 - 2) * 3 + 20 / 4",
    "answer": "29"
  }},
  {{
    "question": "5 + 3 * 2",
    "answer": "11"
  }}
]
Output (JSON format):
[
  {{
    "original_expression": "(10 - 2) * 3 + 20 / 4",
    "priority_analysis": "(10 - 2) -> 20 / 4 -> 8 * 3 -> 24 + 5",
    "word_problem": "Xiao Ming had 10 yuan in his piggy bank. He spent 2 yuan on stationery. His mother saw this and decided to reward him with triple the amount of money he had left. Meanwhile, his grandmother gave him 20 yuan, telling him to spend it equally over 4 days. How much money does Xiao Ming have now?",
    "answer": "29",
    "analysis": "First, calculate the money Xiao Ming had left after buying stationery: 10 - 2 = 8 yuan. Then, calculate his mother's reward: 8 × 3 = 24 yuan. Next, calculate the amount from his grandmother for daily use: 20 ÷ 4 = 5 yuan (but this money is received now). Finally, calculate the total amount: 24 + 5 = 29 yuan."
  }},
  {{
    "original_expression": "5 + 3 * 2",
    "priority_analysis": "3 * 2 -> 5 + 6",
    "word_problem": "Jay had 5 marbles. His friend gave him 3 bags of marbles, with each bag containing 2 marbles. How many marbles does Jay have now?",
    "answer": "11",
    "analysis": "First, calculate the marbles from the bags: 3 × 2 = 6 marbles. Then, add the marbles he originally had: 5 + 6 = 11 marbles."
  }}
]

# Problems and Answers
You will receive a problem and its answer (or a list of problems and answers) in JSON format:
```json
{json.dumps(problems, ensure_ascii=False, indent=2)}
"""
    
    # API request
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    # API payload
    payload = {
        "model": model,
        "messages": [
            {
                "role": "user", 
                "content": full_prompt
            }
        ],
        "temperature": 0.3,
        "max_tokens": 4000
    }
    
    try:
        # Call the API
        response = requests.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=60
        )
        response.raise_for_status()
        
        # Extract the response
        result = response.json()
        content = result["choices"][0]["message"]["content"]
        
        # Try to parse JSON
        try:
            # Extract the JSON string
            if "```json" in content:
                json_str = content.split("```json")[1].split("```")[0].strip()
            elif "```" in content:
                json_str = content.split("```")[1].split("```")[0].strip()
            else:
                json_str = content.strip()
                
            parsed_result = json.loads(json_str)
            
            # Check if the result is a list
            if isinstance(parsed_result, list):
                return parsed_result
            else:
                print("The returned result is not in list format; it returns the original parsing result.")
                return parsed_result
                
        except json.JSONDecodeError as e:
            print("JSON parsing error. Returning original content.:")
            print(content)
            return {"error": "JSON parsing failed", "raw_content": content}
            
    except requests.exceptions.RequestException as e:
        print(f"API call error: {e}")
        return {"error": str(e)}

def save_results_to_json(results, filename=None):
    """
    Save the result as a JSON file
    Args:
        results: The data to be saved
        filename: File name: If it is None, it will be automatically generated

    Returns:
        str: Saved file path
    """
    if filename is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"math_problems_{timestamp}.json"

    # Make sure the file extension is .json
    if not filename.endswith('.json'):
        filename += '.json'

    # Save to file
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"The result has been saved to: {filename}")
    return filename
