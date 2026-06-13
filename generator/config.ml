(* config.ml *)
(* Global difficulty parameters *)

(* The list of allowed macros *)
let allowed_macros = ["parserRadioButtons.pl"; "PGcourse.pl"]

(* ================================================================ *)
(* ============== These could be difficulty levels ================ *)
(* ================================================================ *)

(* ============================================== *)
(* ============= General Difficulty ============= *)
(* ============================================== *)
(* The max depth of the context configuration *)
(*
let max_cfg_depth = 3
let min_cfg_depth = 1
*)
(* The maximum amount of questions *)
let min_question_num = 4
let max_question_num = 10

(* Problem type: 
    0 = all question type, 
    1 = arithmetic only, 
    2 = set only, 
	    3 = vector only
	    4 = derivative only
	    5 = Boolean expression evaluation only
	    6 = Propositional Logic Equivalence only *)
let problem_type = 0

(* Difficulty level:
    "easy"   = Basic level (depth 1-2, simple expressions)
    "medium" = Intermediate level (depth 2-4, moderate complexity)
    "hard"   = Advanced level (depth 3-5, complex expressions) *)
let difficulty_level = "medium"

(* For problem type is 0 (all question type):
   you can set the amount of each question type.
   - Set question_random_amounts as true if you want the amount of each question type to be random.
   - Set question_random_amounts as false and set question_type_amounts as the amount of each question type.
   *)
let question_random_amounts = false
(* The amount of each question type:
	   - [arithmetic_amount; set_amount; vector_amount; derivative_amount; boolean_amount]
   - the total amount of questions should be within the interval [min_question_num, max_question_num]
   *)
let question_type_amounts = [4; 2; 2; 2; 2]
(* Set shuffle_questions_for_0_type as true if you want to shuffle the order of the questions. *)
let shuffle_questions_for_0_type = false

(* ----------------------------------------------- *)

(* ============================================== *)
(* ======= Arithmetic Question Difficulty ======= *)
(* ============================================== *)
(* The absolute max depth of a math expression *)
let max_expr_depth = 2

(* Control whether to generate floats *)
let allow_float = false (* Set to false to generate only integers *)

(* ----------------------------------------------- *)

(* ======================================= *)
(* ======= Set Question Difficulty ======= *)
(* ======================================= *)
(* The max depth of a set expression *)
let min_set_expr_depth = 1
let max_set_expr_depth = 2

(* The range of set elements *)
let min_set_element = -10
let max_set_element = 10

(* The maximum amount of set definitions in set questions *)
(* !!! It must be greater than 2 and leq than the length of set_variables !!! *)
let max_set_def_num = 3
(* The set variable names used in set questions *)
let set_variables = ["A"; "B"; "C"; "D"; "E"; "F"; "G"; "H"; "I"; "J"]

(* The number of questions in a set problem *)
let min_set_prob_num = 2
let max_set_prob_num = 3

(* ----------------------------------------------- *)

(* ========================================== *)
(* ======= Vector Question Difficulty ======= *)
(* ========================================== *)
(* The number of vector components *)
let vector_dimension = 3  (* Generate 3D vectors *)

(* The range of vector components *)
let min_vector_element = -10
let max_vector_element = 10

(* The maximum amount of vector definitions in vector questions *)
(* !!! It must be greater than 2 and leq than the length of vector_variables !!! *)
let max_vector_def_num = 3
(* The vector variable names used in vector questions *)
let vector_variables = ["u"; "v"; "w"; "x"; "y"; "z"; "a"; "b"; "c"; "d"]

(* The number of questions in a vector problem *)
let min_vector_prob_num = 4
let max_vector_prob_num = 6

(* ----------------------------------------------- *)

(* ============================================== *)
(* ======= Derivative Question Difficulty ======= *)
(* ============================================== *)
(* The max depth of a function expression:
   - Set min_fun_expr_depth and max_fun_expr_depth both as 1 to generate only basic functions *)
let min_fun_expr_depth = 3
let max_fun_expr_depth = 5

(* Derivative problem configuration *)
let min_derivative_prob_num = 2
let max_derivative_prob_num = 4

(* ----------------------------------------------- *)

(* ============================================== *)
(* === Boolean Expression Evaluation Difficulty == *)
(* ============================================== *)
(* The min and max depth of a Boolean expression. *)
let min_bool_expr_depth = 2
let max_bool_expr_depth = 4

(* The number of Boolean variables used in one problem. *)
let min_bool_var_num = 2
let max_bool_var_num = 4

(* The Boolean variable names used in Boolean expression questions. *)
let boolean_variables = ["A"; "B"; "C"; "D"; "E"]

(* ----------------------------------------------- *)

(* ====================================================== *)
(* ======= Propositional Logic Equivalence Difficulty ======= *)
(* ====================================================== *)
(* The depth of propositional logic expressions:
   - Depth 0-1: P, Q, ¬P, P ∧ Q, P ∨ Q (simple)
   - Depth 2-3: P ∧ (Q ∨ R), ¬(P ∧ Q), P → Q (moderate)
   - Depth 3-5: Complex nested expressions (advanced) *)
let min_prop_expr_depth = 1
let max_prop_expr_depth = 2

(* Number of propositional logic equivalence questions per problem *)
let min_prop_equiv_prob_num = 2
let max_prop_equiv_prob_num = 4

(* Propositional variables to use *)
let prop_variables = ["P"; "Q"; "R"; "S"]

(* ----------------------------------------------- *)
