
(* The type of tokens. *)

type token = 
  | X_VAR
  | XOR_WORD
  | WITH_METH
  | WIDTH_WORD
  | WHEN_WORD
  | WHAT_WORD
  | VEC_LATEX
  | VECTOR_UNIT_PROB
  | VECTOR_SAME_PROB
  | VECTOR_PARA_PROB
  | VALUE_WORD
  | UNIT_METH
  | UNION
  | UNDEFINE_METH
  | TRUE_WORD
  | TO_WORD
  | TIMES_LATEX
  | THE_WORD
  | SUPPOSE_PROB
  | SUB_OP
  | SQRT_OP
  | SIN_OP
  | SINGLE_QUOTE
  | SET_METH
  | SET_DEF_METH
  | SEMI
  | RPAREN
  | RIGHT_NORM_LATEX
  | REDEFINE_METH
  | REAL_METH
  | RBRACKET
  | RBRACE_LATEX
  | RBRACE
  | RANGLE_LATEX
  | RANDOM_METH
  | QUESTION_MARK
  | POWER_OP
  | PIPE
  | PGSTANDARD
  | PGML
  | PERIOD
  | OR_WORD
  | OF_WORD
  | NUMBER of (float)
  | NOT_WORD
  | NORM_METH
  | NEWLINE
  | NEG_INFINITY
  | NAT_LOG
  | NAMING
  | MUL_OP
  | MATHOBJECTS
  | MACRO of (string)
  | LT
  | LPAREN
  | LOADMACROS
  | LN_OP
  | LEQ_LATEX
  | LEFT_NORM_LATEX
  | LBRACKET
  | LBRACE_LATEX
  | LBRACE
  | LANGLE_LATEX
  | I_UNIT
  | IT_VAR_OPEN
  | IT_VAR_CLOSE
  | IT_MATH_OPEN
  | IT_MATH_CLOSE
  | IS_WORD
  | INTERSECT_METH
  | INT of (int)
  | INFINITY
  | INDEFINITE_INTEGRAL_PROB
  | IMPLIES_WORD
  | IFF_WORD
  | ID of (string)
  | GT
  | GIVEN_PROB
  | GIVEN_FUN
  | GEQ_LATEX
  | F_FUN
  | FORMULA_METH
  | FAT_COMMA
  | FALSE_WORD
  | EVAL_METH
  | EVALUATE_BOOL_PROB
  | EQUAL_WORD
  | EQ
  | EOF
  | END_PGML
  | ENDDOCUMENT
  | D_METH
  | DOUBLE_QUOTE
  | DOCUMENT
  | DIV_OP
  | CUP
  | COS_OP
  | CONTEXT
  | COMPUTE_PROB
  | COMPUTE_METH
  | COMPLEX_POWER_I_PROB
  | COMPLEX_MOD_PROB
  | COMPLEX_METH
  | COMPLEX_CONJ_PROB
  | COMPLEX_ARITH_PROB
  | COMMA
  | CMP_2
  | CMP_1
  | CDOT_LATEX
  | CAP
  | BOOL_EQUIV_ANSWER_HINT
  | BOOL_ANSWER_HINT
  | BOOLEAN_EQUIV_PROB
  | BLANK
  | BEGIN_PGML
  | ARROW
  | ARE_METH
  | ANSWER_WORD
  | AND_WORD
  | ADD_OP
  | ADD_METH

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val main: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (Ast.document)

module MenhirInterpreter : sig
  
  (* The incremental API. *)
  
  include MenhirLib.IncrementalEngine.INCREMENTAL_ENGINE
    with type token = token
  
  (* The indexed type of terminal symbols. *)
  
  type _ terminal = 
    | T_error : unit terminal
    | T_X_VAR : unit terminal
    | T_XOR_WORD : unit terminal
    | T_WITH_METH : unit terminal
    | T_WIDTH_WORD : unit terminal
    | T_WHEN_WORD : unit terminal
    | T_WHAT_WORD : unit terminal
    | T_VEC_LATEX : unit terminal
    | T_VECTOR_UNIT_PROB : unit terminal
    | T_VECTOR_SAME_PROB : unit terminal
    | T_VECTOR_PARA_PROB : unit terminal
    | T_VALUE_WORD : unit terminal
    | T_UNIT_METH : unit terminal
    | T_UNION : unit terminal
    | T_UNDEFINE_METH : unit terminal
    | T_TRUE_WORD : unit terminal
    | T_TO_WORD : unit terminal
    | T_TIMES_LATEX : unit terminal
    | T_THE_WORD : unit terminal
    | T_SUPPOSE_PROB : unit terminal
    | T_SUB_OP : unit terminal
    | T_SQRT_OP : unit terminal
    | T_SIN_OP : unit terminal
    | T_SINGLE_QUOTE : unit terminal
    | T_SET_METH : unit terminal
    | T_SET_DEF_METH : unit terminal
    | T_SEMI : unit terminal
    | T_RPAREN : unit terminal
    | T_RIGHT_NORM_LATEX : unit terminal
    | T_REDEFINE_METH : unit terminal
    | T_REAL_METH : unit terminal
    | T_RBRACKET : unit terminal
    | T_RBRACE_LATEX : unit terminal
    | T_RBRACE : unit terminal
    | T_RANGLE_LATEX : unit terminal
    | T_RANDOM_METH : unit terminal
    | T_QUESTION_MARK : unit terminal
    | T_POWER_OP : unit terminal
    | T_PIPE : unit terminal
    | T_PGSTANDARD : unit terminal
    | T_PGML : unit terminal
    | T_PERIOD : unit terminal
    | T_OR_WORD : unit terminal
    | T_OF_WORD : unit terminal
    | T_NUMBER : (float) terminal
    | T_NOT_WORD : unit terminal
    | T_NORM_METH : unit terminal
    | T_NEWLINE : unit terminal
    | T_NEG_INFINITY : unit terminal
    | T_NAT_LOG : unit terminal
    | T_NAMING : unit terminal
    | T_MUL_OP : unit terminal
    | T_MATHOBJECTS : unit terminal
    | T_MACRO : (string) terminal
    | T_LT : unit terminal
    | T_LPAREN : unit terminal
    | T_LOADMACROS : unit terminal
    | T_LN_OP : unit terminal
    | T_LEQ_LATEX : unit terminal
    | T_LEFT_NORM_LATEX : unit terminal
    | T_LBRACKET : unit terminal
    | T_LBRACE_LATEX : unit terminal
    | T_LBRACE : unit terminal
    | T_LANGLE_LATEX : unit terminal
    | T_I_UNIT : unit terminal
    | T_IT_VAR_OPEN : unit terminal
    | T_IT_VAR_CLOSE : unit terminal
    | T_IT_MATH_OPEN : unit terminal
    | T_IT_MATH_CLOSE : unit terminal
    | T_IS_WORD : unit terminal
    | T_INTERSECT_METH : unit terminal
    | T_INT : (int) terminal
    | T_INFINITY : unit terminal
    | T_INDEFINITE_INTEGRAL_PROB : unit terminal
    | T_IMPLIES_WORD : unit terminal
    | T_IFF_WORD : unit terminal
    | T_ID : (string) terminal
    | T_GT : unit terminal
    | T_GIVEN_PROB : unit terminal
    | T_GIVEN_FUN : unit terminal
    | T_GEQ_LATEX : unit terminal
    | T_F_FUN : unit terminal
    | T_FORMULA_METH : unit terminal
    | T_FAT_COMMA : unit terminal
    | T_FALSE_WORD : unit terminal
    | T_EVAL_METH : unit terminal
    | T_EVALUATE_BOOL_PROB : unit terminal
    | T_EQUAL_WORD : unit terminal
    | T_EQ : unit terminal
    | T_EOF : unit terminal
    | T_END_PGML : unit terminal
    | T_ENDDOCUMENT : unit terminal
    | T_D_METH : unit terminal
    | T_DOUBLE_QUOTE : unit terminal
    | T_DOCUMENT : unit terminal
    | T_DIV_OP : unit terminal
    | T_CUP : unit terminal
    | T_COS_OP : unit terminal
    | T_CONTEXT : unit terminal
    | T_COMPUTE_PROB : unit terminal
    | T_COMPUTE_METH : unit terminal
    | T_COMPLEX_POWER_I_PROB : unit terminal
    | T_COMPLEX_MOD_PROB : unit terminal
    | T_COMPLEX_METH : unit terminal
    | T_COMPLEX_CONJ_PROB : unit terminal
    | T_COMPLEX_ARITH_PROB : unit terminal
    | T_COMMA : unit terminal
    | T_CMP_2 : unit terminal
    | T_CMP_1 : unit terminal
    | T_CDOT_LATEX : unit terminal
    | T_CAP : unit terminal
    | T_BOOL_EQUIV_ANSWER_HINT : unit terminal
    | T_BOOL_ANSWER_HINT : unit terminal
    | T_BOOLEAN_EQUIV_PROB : unit terminal
    | T_BLANK : unit terminal
    | T_BEGIN_PGML : unit terminal
    | T_ARROW : unit terminal
    | T_ARE_METH : unit terminal
    | T_ANSWER_WORD : unit terminal
    | T_AND_WORD : unit terminal
    | T_ADD_OP : unit terminal
    | T_ADD_METH : unit terminal
  
  (* The indexed type of nonterminal symbols. *)
  
  type _ nonterminal = 
    | N_vector_prob_list : (Ast.vector_prob_list) nonterminal
    | N_vector_prob : (Ast.vector_prob) nonterminal
    | N_vector_list : (Ast.vector_list) nonterminal
    | N_variable_list : (Ast.answer_vars) nonterminal
    | N_variable_declaration : (Ast.variable_declaration) nonterminal
    | N_variable : (Ast.variable) nonterminal
    | N_value : (Ast.value) nonterminal
    | N_trig_function : (Ast.trig_function) nonterminal
    | N_term : (Ast.term) nonterminal
    | N_set_term : (Ast.set_term) nonterminal
    | N_set_prob_list : (Ast.set_prob_list) nonterminal
    | N_set_primary : (Ast.set_primary) nonterminal
    | N_set_operation : (Ast.set_operation) nonterminal
    | N_set_list : (Ast.set_list) nonterminal
    | N_set_interval : (Ast.set_interval) nonterminal
    | N_set_factor : (Ast.set_factor) nonterminal
    | N_set_expr : (Ast.set_expr) nonterminal
    | N_set_enum : (Ast.set_enum) nonterminal
    | N_set_compute_term : (Ast.set_compute_term) nonterminal
    | N_set_compute_interval : (Ast.set_compute_interval) nonterminal
    | N_set_compute_factor : (Ast.set_compute_factor) nonterminal
    | N_set_compute : (Ast.set_compute) nonterminal
    | N_rational_function : (Ast.rational_function) nonterminal
    | N_radical_function : (Ast.radical_function) nonterminal
    | N_question_text : (Ast.question_text) nonterminal
    | N_question_list : (Ast.question_list) nonterminal
    | N_question_item : (Ast.question_item) nonterminal
    | N_quadratic_function : (Ast.quadratic_function) nonterminal
    | N_property : (Ast.property) nonterminal
    | N_properties : (Ast.properties) nonterminal
    | N_problem_section : (Ast.problem_section) nonterminal
    | N_predicate : (Ast.predicate) nonterminal
    | N_power_function : (Ast.power_function) nonterminal
    | N_operator_list : (Ast.operator_list) nonterminal
    | N_operator : (Ast.operator) nonterminal
    | N_module_ : (Ast.module_) nonterminal
    | N_math_object_method : (Ast.math_object_method) nonterminal
    | N_math_expr : (Ast.math_expr) nonterminal
    | N_main : (Ast.document) nonterminal
    | N_macro : (Ast.macro) nonterminal
    | N_log_function : (Ast.log_function) nonterminal
    | N_linear_function : (Ast.linear_function) nonterminal
    | N_key : (Ast.key) nonterminal
    | N_intext_call : (Ast.intext_call) nonterminal
    | N_interval_value : (Ast.interval_value) nonterminal
    | N_int_with_sign : (int) nonterminal
    | N_header : (Ast.header) nonterminal
    | N_function_expr : (Ast.function_expr) nonterminal
    | N_fun_or_var : (Ast.fun_or_var) nonterminal
    | N_factor : (Ast.factor) nonterminal
    | N_exp_function : (Ast.exp_function) nonterminal
    | N_entry_list : (Ast.entry_list) nonterminal
    | N_entry : (Ast.entry) nonterminal
    | N_derivative_prob_list : (Ast.derivative_prob_list) nonterminal
    | N_derivative_prob : (Ast.derivative_prob) nonterminal
    | N_context_setup_list : (Ast.context_setup_list) nonterminal
    | N_context_setup : (Ast.context_setup) nonterminal
    | N_context_method : (Ast.context_method) nonterminal
    | N_context_config : (Ast.context_config) nonterminal
    | N_complex_num : (Ast.complex_num) nonterminal
    | N_complex_expr : (Ast.complex_expr) nonterminal
    | N_bool_expr : (Ast.bool_expr) nonterminal
    | N_bool_assignment_list : (Ast.bool_assignment list) nonterminal
    | N_bool_assignment : (Ast.bool_assignment) nonterminal
    | N_answer_vars : (Ast.answer_vars) nonterminal
    | N_answer_item : (Ast.answer_item) nonterminal
  
  (* The inspection API. *)
  
  include MenhirLib.IncrementalEngine.INSPECTION
    with type 'a lr1state := 'a lr1state
    with type production := production
    with type 'a terminal := 'a terminal
    with type 'a nonterminal := 'a nonterminal
    with type 'a env := 'a env
  
end

(* The entry point(s) to the incremental API. *)

module Incremental : sig
  
  val main: Lexing.position -> (Ast.document) MenhirInterpreter.checkpoint
  
end

(* The unparsing API. *)

(* Constructing disjunctive concrete syntax trees (DCSTs). *)

module DCST : sig
  
  (* The type of DCSTs for the nonterminal symbol [vector_prob_list]. *)
  
  type vector_prob_list
  
  (* The type of DCSTs for the nonterminal symbol [vector_prob]. *)
  
  type vector_prob
  
  (* The type of DCSTs for the nonterminal symbol [vector_list]. *)
  
  type vector_list
  
  (* The type of DCSTs for the nonterminal symbol [variable_list]. *)
  
  type variable_list
  
  (* The type of DCSTs for the nonterminal symbol [variable_declaration]. *)
  
  type variable_declaration
  
  (* The type of DCSTs for the nonterminal symbol [variable]. *)
  
  type variable
  
  (* The type of DCSTs for the nonterminal symbol [value]. *)
  
  type value
  
  (* The type of DCSTs for the nonterminal symbol [trig_function]. *)
  
  type trig_function
  
  (* The type of DCSTs for the nonterminal symbol [term]. *)
  
  type term
  
  (* The type of DCSTs for the nonterminal symbol [set_term]. *)
  
  type set_term
  
  (* The type of DCSTs for the nonterminal symbol [set_prob_list]. *)
  
  type set_prob_list
  
  (* The type of DCSTs for the nonterminal symbol [set_primary]. *)
  
  type set_primary
  
  (* The type of DCSTs for the nonterminal symbol [set_operation]. *)
  
  type set_operation
  
  (* The type of DCSTs for the nonterminal symbol [set_list]. *)
  
  type set_list
  
  (* The type of DCSTs for the nonterminal symbol [set_interval]. *)
  
  type set_interval
  
  (* The type of DCSTs for the nonterminal symbol [set_factor]. *)
  
  type set_factor
  
  (* The type of DCSTs for the nonterminal symbol [set_expr]. *)
  
  type set_expr
  
  (* The type of DCSTs for the nonterminal symbol [set_enum]. *)
  
  type set_enum
  
  (* The type of DCSTs for the nonterminal symbol [set_compute_term]. *)
  
  type set_compute_term
  
  (* The type of DCSTs for the nonterminal symbol [set_compute_interval]. *)
  
  type set_compute_interval
  
  (* The type of DCSTs for the nonterminal symbol [set_compute_factor]. *)
  
  type set_compute_factor
  
  (* The type of DCSTs for the nonterminal symbol [set_compute]. *)
  
  type set_compute
  
  (* The type of DCSTs for the nonterminal symbol [rational_function]. *)
  
  type rational_function
  
  (* The type of DCSTs for the nonterminal symbol [radical_function]. *)
  
  type radical_function
  
  (* The type of DCSTs for the nonterminal symbol [question_text]. *)
  
  type question_text
  
  (* The type of DCSTs for the nonterminal symbol [question_list]. *)
  
  type question_list
  
  (* The type of DCSTs for the nonterminal symbol [question_item]. *)
  
  type question_item
  
  (* The type of DCSTs for the nonterminal symbol [quadratic_function]. *)
  
  type quadratic_function
  
  (* The type of DCSTs for the nonterminal symbol [property]. *)
  
  type property
  
  (* The type of DCSTs for the nonterminal symbol [properties]. *)
  
  type properties
  
  (* The type of DCSTs for the nonterminal symbol [problem_section]. *)
  
  type problem_section
  
  (* The type of DCSTs for the nonterminal symbol [predicate]. *)
  
  type predicate
  
  (* The type of DCSTs for the nonterminal symbol [power_function]. *)
  
  type power_function
  
  (* The type of DCSTs for the nonterminal symbol [operator_list]. *)
  
  type operator_list
  
  (* The type of DCSTs for the nonterminal symbol [operator]. *)
  
  type operator
  
  (* The type of DCSTs for the nonterminal symbol [module_]. *)
  
  type module_
  
  (* The type of DCSTs for the nonterminal symbol [math_object_method]. *)
  
  type math_object_method
  
  (* The type of DCSTs for the nonterminal symbol [math_expr]. *)
  
  type math_expr
  
  (* The type of DCSTs for the nonterminal symbol [main]. *)
  
  type main
  
  (* The type of DCSTs for the nonterminal symbol [macro]. *)
  
  type macro
  
  (* The type of DCSTs for the nonterminal symbol [log_function]. *)
  
  type log_function
  
  (* The type of DCSTs for the nonterminal symbol [linear_function]. *)
  
  type linear_function
  
  (* The type of DCSTs for the nonterminal symbol [key]. *)
  
  type key
  
  (* The type of DCSTs for the nonterminal symbol [intext_call]. *)
  
  type intext_call
  
  (* The type of DCSTs for the nonterminal symbol [interval_value]. *)
  
  type interval_value
  
  (* The type of DCSTs for the nonterminal symbol [int_with_sign]. *)
  
  type int_with_sign
  
  (* The type of DCSTs for the nonterminal symbol [header]. *)
  
  type header
  
  (* The type of DCSTs for the nonterminal symbol [function_expr]. *)
  
  type function_expr
  
  (* The type of DCSTs for the nonterminal symbol [fun_or_var]. *)
  
  type fun_or_var
  
  (* The type of DCSTs for the nonterminal symbol [factor]. *)
  
  type factor
  
  (* The type of DCSTs for the nonterminal symbol [exp_function]. *)
  
  type exp_function
  
  (* The type of DCSTs for the nonterminal symbol [entry_list]. *)
  
  type entry_list
  
  (* The type of DCSTs for the nonterminal symbol [entry]. *)
  
  type entry
  
  (* The type of DCSTs for the nonterminal symbol [derivative_prob_list]. *)
  
  type derivative_prob_list
  
  (* The type of DCSTs for the nonterminal symbol [derivative_prob]. *)
  
  type derivative_prob
  
  (* The type of DCSTs for the nonterminal symbol [context_setup_list]. *)
  
  type context_setup_list
  
  (* The type of DCSTs for the nonterminal symbol [context_setup]. *)
  
  type context_setup
  
  (* The type of DCSTs for the nonterminal symbol [context_method]. *)
  
  type context_method
  
  (* The type of DCSTs for the nonterminal symbol [context_config]. *)
  
  type context_config
  
  (* The type of DCSTs for the nonterminal symbol [complex_num]. *)
  
  type complex_num
  
  (* The type of DCSTs for the nonterminal symbol [complex_expr]. *)
  
  type complex_expr
  
  (* The type of DCSTs for the nonterminal symbol [bool_expr]. *)
  
  type bool_expr
  
  (* The type of DCSTs for the nonterminal symbol [bool_assignment_list]. *)
  
  type bool_assignment_list
  
  (* The type of DCSTs for the nonterminal symbol [bool_assignment]. *)
  
  type bool_assignment
  
  (* The type of DCSTs for the nonterminal symbol [answer_vars]. *)
  
  type answer_vars
  
  (* The type of DCSTs for the nonterminal symbol [answer_item]. *)
  
  type answer_item
  
  (* The binary choice constructor at type [vector_prob_list]. *)
  
  val vector_prob_list_choice: vector_prob_list -> vector_prob_list -> vector_prob_list
  
  (* vector_prob_list -> SUB_OP vector_prob NEWLINE vector_prob_list *)
  
  val vec_prob_list_cons: vector_prob -> vector_prob_list -> vector_prob_list
  
  (* vector_prob_list -> SUB_OP vector_prob NEWLINE *)
  
  val vec_prob_list_last: vector_prob -> vector_prob_list
  
  (* The binary choice constructor at type [vector_prob]. *)
  
  val vector_prob_choice: vector_prob -> vector_prob -> vector_prob
  
  (* vector_prob -> IT_MATH_OPEN VEC_LATEX LBRACE ID RBRACE CDOT_LATEX VEC_LATEX LBRACE ID RBRACE EQ IT_MATH_CLOSE BLANK LBRACE COMPUTE_METH LPAREN DOUBLE_QUOTE LT set_enum GT DOUBLE_QUOTE RPAREN PERIOD COMPUTE_METH LPAREN DOUBLE_QUOTE LT set_enum GT DOUBLE_QUOTE RPAREN RBRACE *)
  
  val vec_prob_1: (string) -> (string) -> set_enum -> set_enum -> vector_prob
  
  (* vector_prob -> IT_MATH_OPEN VEC_LATEX LBRACE ID RBRACE TIMES_LATEX VEC_LATEX LBRACE ID RBRACE EQ IT_MATH_CLOSE BLANK LBRACE COMPUTE_METH LPAREN DOUBLE_QUOTE LT set_enum GT DOUBLE_QUOTE RPAREN X_VAR COMPUTE_METH LPAREN DOUBLE_QUOTE LT set_enum GT DOUBLE_QUOTE RPAREN RBRACE *)
  
  val vec_prob_2: (string) -> (string) -> set_enum -> set_enum -> vector_prob
  
  (* vector_prob -> IT_MATH_OPEN LEFT_NORM_LATEX VEC_LATEX LBRACE ID RBRACE RIGHT_NORM_LATEX EQ IT_MATH_CLOSE BLANK LBRACE NORM_METH LPAREN COMPUTE_METH LPAREN DOUBLE_QUOTE LT set_enum GT DOUBLE_QUOTE RPAREN RPAREN RBRACE *)
  
  val vec_prob_3: (string) -> set_enum -> vector_prob
  
  (* vector_prob -> VECTOR_UNIT_PROB IT_MATH_OPEN VEC_LATEX LBRACE ID RBRACE IT_MATH_CLOSE PERIOD BLANK LBRACE UNIT_METH LPAREN COMPUTE_METH LPAREN DOUBLE_QUOTE LT set_enum GT DOUBLE_QUOTE RPAREN RPAREN RBRACE *)
  
  val vec_prob_4: (string) -> set_enum -> vector_prob
  
  (* vector_prob -> VECTOR_PARA_PROB IT_MATH_OPEN VEC_LATEX LBRACE ID RBRACE IT_MATH_CLOSE PERIOD BLANK LBRACE COMPUTE_METH LPAREN DOUBLE_QUOTE LT set_enum GT DOUBLE_QUOTE RPAREN ARROW CMP_1 RBRACE *)
  
  val vec_prob_5: (string) -> set_enum -> vector_prob
  
  (* vector_prob -> VECTOR_SAME_PROB IT_MATH_OPEN VEC_LATEX LBRACE ID RBRACE IT_MATH_CLOSE PERIOD BLANK LBRACE COMPUTE_METH LPAREN DOUBLE_QUOTE LT set_enum GT DOUBLE_QUOTE RPAREN ARROW CMP_2 RBRACE *)
  
  val vec_prob_6: (string) -> set_enum -> vector_prob
  
  (* The binary choice constructor at type [vector_list]. *)
  
  val vector_list_choice: vector_list -> vector_list -> vector_list
  
  (* vector_list -> SUB_OP IT_MATH_OPEN VEC_LATEX LBRACE ID RBRACE EQ LANGLE_LATEX set_enum RANGLE_LATEX IT_MATH_CLOSE NEWLINE vector_list *)
  
  val vec_list_cons: (string) -> set_enum -> vector_list -> vector_list
  
  (* vector_list -> SUB_OP IT_MATH_OPEN VEC_LATEX LBRACE ID RBRACE EQ LANGLE_LATEX set_enum RANGLE_LATEX IT_MATH_CLOSE NEWLINE *)
  
  val vec_list_last: (string) -> set_enum -> vector_list
  
  (* The binary choice constructor at type [variable_list]. *)
  
  val variable_list_choice: variable_list -> variable_list -> variable_list
  
  (* variable_list -> variable_declaration NEWLINE variable_list *)
  
  val var_list: variable_declaration -> variable_list -> variable_list
  
  (* variable_list -> variable_declaration NEWLINE *)
  
  val var_list_single: variable_declaration -> variable_list
  
  (* The binary choice constructor at type [variable_declaration]. *)
  
  val variable_declaration_choice: variable_declaration -> variable_declaration -> variable_declaration
  
  (* variable_declaration -> NAMING ID EQ variable SEMI *)
  
  val var_decl: (string) -> variable -> variable_declaration
  
  (* The binary choice constructor at type [variable]. *)
  
  val variable_choice: variable -> variable -> variable
  
  (* variable -> value *)
  
  val var_value: value -> variable
  
  (* variable -> math_object_method *)
  
  val var_meth: math_object_method -> variable
  
  (* variable -> NAMING ID ARROW math_object_method *)
  
  val var_field: (string) -> math_object_method -> variable
  
  (* variable -> math_object_method ARROW math_object_method *)
  
  val var_chain: math_object_method -> math_object_method -> variable
  
  (* The binary choice constructor at type [value]. *)
  
  val value_choice: value -> value -> value
  
  (* value -> SUB_OP INT *)
  
  val value_int_neg: (int) -> value
  
  (* value -> INT *)
  
  val value_int_pos: (int) -> value
  
  (* value -> SUB_OP NUMBER *)
  
  val value_num_neg: (float) -> value
  
  (* value -> NUMBER *)
  
  val value_num_pos: (float) -> value
  
  (* value -> DOUBLE_QUOTE ID DOUBLE_QUOTE *)
  
  val value_str_dou: (string) -> value
  
  (* value -> SINGLE_QUOTE ID SINGLE_QUOTE *)
  
  val value_str_sin: (string) -> value
  
  (* value -> NAMING ID *)
  
  val value_ident: (string) -> value
  
  (* The binary choice constructor at type [trig_function]. *)
  
  val trig_function_choice: trig_function -> trig_function -> trig_function
  
  (* trig_function -> SIN_OP LPAREN fun_or_var RPAREN *)
  
  val trig_sin: fun_or_var -> trig_function
  
  (* trig_function -> COS_OP LPAREN fun_or_var RPAREN *)
  
  val trig_cos: fun_or_var -> trig_function
  
  (* The binary choice constructor at type [term]. *)
  
  val term_choice: term -> term -> term
  
  (* term -> term MUL_OP factor *)
  
  val tmul: term -> factor -> term
  
  (* term -> term DIV_OP factor *)
  
  val tdiv: term -> factor -> term
  
  (* term -> factor *)
  
  val tfac: factor -> term
  
  (* The binary choice constructor at type [set_term]. *)
  
  val set_term_choice: set_term -> set_term -> set_term
  
  (* set_term -> set_term CAP set_factor *)
  
  val set_op_inter: set_term -> set_factor -> set_term
  
  (* set_term -> set_factor *)
  
  val set_op_factor: set_factor -> set_term
  
  (* The binary choice constructor at type [set_prob_list]. *)
  
  val set_prob_list_choice: set_prob_list -> set_prob_list -> set_prob_list
  
  (* set_prob_list -> SUB_OP IT_MATH_OPEN set_operation EQ IT_MATH_CLOSE BLANK LBRACE answer_item RBRACE NEWLINE set_prob_list *)
  
  val set_prob_list_cons: set_operation -> answer_item -> set_prob_list -> set_prob_list
  
  (* set_prob_list -> SUB_OP IT_MATH_OPEN set_operation EQ IT_MATH_CLOSE BLANK LBRACE answer_item RBRACE NEWLINE *)
  
  val set_prob_list_last: set_operation -> answer_item -> set_prob_list
  
  (* The binary choice constructor at type [set_primary]. *)
  
  val set_primary_choice: set_primary -> set_primary -> set_primary
  
  (* set_primary -> ID *)
  
  val set_primary_var: (string) -> set_primary
  
  (* set_primary -> LPAREN set_operation RPAREN *)
  
  val set_primary_paren: set_operation -> set_primary
  
  (* The binary choice constructor at type [set_operation]. *)
  
  val set_operation_choice: set_operation -> set_operation -> set_operation
  
  (* set_operation -> set_operation CUP set_term *)
  
  val set_op_union: set_operation -> set_term -> set_operation
  
  (* set_operation -> set_term *)
  
  val set_op_term: set_term -> set_operation
  
  (* The binary choice constructor at type [set_list]. *)
  
  val set_list_choice: set_list -> set_list -> set_list
  
  (* set_list -> SUB_OP IT_MATH_OPEN ID EQ LBRACE_LATEX set_expr RBRACE_LATEX IT_MATH_CLOSE NEWLINE set_list *)
  
  val set_list_cons: (string) -> set_expr -> set_list -> set_list
  
  (* set_list -> SUB_OP IT_MATH_OPEN ID EQ LBRACE_LATEX set_expr RBRACE_LATEX IT_MATH_CLOSE NEWLINE *)
  
  val set_list_last: (string) -> set_expr -> set_list
  
  (* The binary choice constructor at type [set_interval]. *)
  
  val set_interval_choice: set_interval -> set_interval -> set_interval
  
  (* set_interval -> X_VAR PIPE predicate *)
  
  val set_interval: predicate -> set_interval
  
  (* The binary choice constructor at type [set_factor]. *)
  
  val set_factor_choice: set_factor -> set_factor -> set_factor
  
  (* set_factor -> set_factor SUB_OP set_primary *)
  
  val set_op_diff: set_factor -> set_primary -> set_factor
  
  (* set_factor -> set_primary *)
  
  val set_op_primary: set_primary -> set_factor
  
  (* The binary choice constructor at type [set_expr]. *)
  
  val set_expr_choice: set_expr -> set_expr -> set_expr
  
  (* set_expr -> set_enum *)
  
  val set_expr_enum: set_enum -> set_expr
  
  (* set_expr -> set_interval *)
  
  val set_expr_interval: set_interval -> set_expr
  
  (* The binary choice constructor at type [set_enum]. *)
  
  val set_enum_choice: set_enum -> set_enum -> set_enum
  
  (* set_enum -> int_with_sign COMMA set_enum *)
  
  val set_enum_cons: int_with_sign -> set_enum -> set_enum
  
  (* set_enum -> int_with_sign *)
  
  val set_enum_last: int_with_sign -> set_enum
  
  (* The binary choice constructor at type [set_compute_term]. *)
  
  val set_compute_term_choice: set_compute_term -> set_compute_term -> set_compute_term
  
  (* set_compute_term -> set_compute_term SUB_OP set_compute_factor *)
  
  val set_compute_diff: set_compute_term -> set_compute_factor -> set_compute_term
  
  (* set_compute_term -> set_compute_factor *)
  
  val set_compute_factor: set_compute_factor -> set_compute_term
  
  (* The binary choice constructor at type [set_compute_interval]. *)
  
  val set_compute_interval_choice: set_compute_interval -> set_compute_interval -> set_compute_interval
  
  (* set_compute_interval -> LPAREN interval_value COMMA interval_value RPAREN *)
  
  val set_compute_interval_open: interval_value -> interval_value -> set_compute_interval
  
  (* set_compute_interval -> LPAREN interval_value COMMA interval_value RBRACKET *)
  
  val set_compute_interval_left_open: interval_value -> interval_value -> set_compute_interval
  
  (* set_compute_interval -> LBRACKET interval_value COMMA interval_value RPAREN *)
  
  val set_compute_interval_right_open: interval_value -> interval_value -> set_compute_interval
  
  (* set_compute_interval -> LBRACKET interval_value COMMA interval_value RBRACKET *)
  
  val set_compute_interval_closed: interval_value -> interval_value -> set_compute_interval
  
  (* The binary choice constructor at type [set_compute_factor]. *)
  
  val set_compute_factor_choice: set_compute_factor -> set_compute_factor -> set_compute_factor
  
  (* set_compute_factor -> LPAREN set_compute RPAREN *)
  
  val set_compute_paren: set_compute -> set_compute_factor
  
  (* set_compute_factor -> LBRACE set_enum RBRACE *)
  
  val set_compute_enum: set_enum -> set_compute_factor
  
  (* set_compute_factor -> set_compute_interval *)
  
  val set_compute_interval: set_compute_interval -> set_compute_factor
  
  (* The binary choice constructor at type [set_compute]. *)
  
  val set_compute_choice: set_compute -> set_compute -> set_compute
  
  (* set_compute -> set_compute UNION set_compute_term *)
  
  val set_compute_union: set_compute -> set_compute_term -> set_compute
  
  (* set_compute -> set_compute_term *)
  
  val set_compute_term: set_compute_term -> set_compute
  
  (* The binary choice constructor at type [rational_function]. *)
  
  val rational_function_choice: rational_function -> rational_function -> rational_function
  
  (* rational_function -> fun_or_var DIV_OP INT *)
  
  val fun_div_int: fun_or_var -> (int) -> rational_function
  
  (* rational_function -> INT DIV_OP LPAREN fun_or_var RPAREN *)
  
  val int_div_fun: (int) -> fun_or_var -> rational_function
  
  (* The binary choice constructor at type [radical_function]. *)
  
  val radical_function_choice: radical_function -> radical_function -> radical_function
  
  (* radical_function -> SQRT_OP LPAREN fun_or_var RPAREN *)
  
  val radi_sqrt: fun_or_var -> radical_function
  
  (* radical_function -> LPAREN fun_or_var RPAREN POWER_OP LPAREN INT DIV_OP INT RPAREN *)
  
  val radi_root: fun_or_var -> (int) -> (int) -> radical_function
  
  (* The binary choice constructor at type [question_text]. *)
  
  val question_text_choice: question_text -> question_text -> question_text
  
  (* question_text -> WHAT_WORD IS_WORD THE_WORD VALUE_WORD OF_WORD intext_call QUESTION_MARK *)
  
  val qvalue: intext_call -> question_text
  
  (* question_text -> intext_call IS_WORD EQUAL_WORD TO_WORD *)
  
  val qis: intext_call -> question_text
  
  (* The binary choice constructor at type [question_list]. *)
  
  val question_list_choice: question_list -> question_list -> question_list
  
  (* question_list -> question_item NEWLINE NEWLINE question_list *)
  
  val qlist: question_item -> question_list -> question_list
  
  (* question_list -> question_item NEWLINE *)
  
  val qlist_single: question_item -> question_list
  
  (* The binary choice constructor at type [question_item]. *)
  
  val question_item_choice: question_item -> question_item -> question_item
  
  (* question_item -> question_text BLANK LBRACE answer_item RBRACE *)
  
  val qitem1: question_text -> answer_item -> question_item
  
  (* question_item -> question_text BLANK LBRACE ANSWER_WORD FAT_COMMA answer_item COMMA WIDTH_WORD FAT_COMMA INT RBRACE *)
  
  val qitem2: question_text -> answer_item -> (int) -> question_item
  
  (* question_item -> GIVEN_PROB NEWLINE set_list NEWLINE COMPUTE_PROB NEWLINE set_prob_list *)
  
  val qset: set_list -> set_prob_list -> question_item
  
  (* question_item -> SUPPOSE_PROB NEWLINE vector_list NEWLINE COMPUTE_PROB NEWLINE vector_prob_list *)
  
  val qvector: vector_list -> vector_prob_list -> question_item
  
  (* question_item -> GIVEN_FUN NEWLINE NEWLINE IT_VAR_OPEN NAMING ID IT_VAR_CLOSE NEWLINE NEWLINE COMPUTE_PROB NEWLINE derivative_prob_list *)
  
  val qderivative: (string) -> derivative_prob_list -> question_item
  
  (* question_item -> EVALUATE_BOOL_PROB NEWLINE IT_MATH_OPEN bool_expr IT_MATH_CLOSE NEWLINE WHEN_WORD NEWLINE bool_assignment_list BOOL_ANSWER_HINT NEWLINE BLANK LBRACE answer_item RBRACE *)
  
  val qbool_eval: bool_expr -> bool_assignment_list -> answer_item -> question_item
  
  (* question_item -> EVALUATE_BOOL_PROB NEWLINE IT_MATH_OPEN bool_expr IT_MATH_CLOSE NEWLINE WHEN_WORD NEWLINE bool_assignment_list BOOL_ANSWER_HINT NEWLINE BLANK LBRACE ANSWER_WORD FAT_COMMA answer_item COMMA WIDTH_WORD FAT_COMMA INT RBRACE *)
  
  val qbool_eval_width: bool_expr -> bool_assignment_list -> answer_item -> (int) -> question_item
  
  (* question_item -> BOOLEAN_EQUIV_PROB NEWLINE IT_MATH_OPEN bool_expr IT_MATH_CLOSE NEWLINE IT_MATH_OPEN bool_expr IT_MATH_CLOSE NEWLINE BOOL_EQUIV_ANSWER_HINT NEWLINE BLANK LBRACE answer_item RBRACE *)
  
  val qbool_equiv: bool_expr -> bool_expr -> answer_item -> question_item
  
  (* question_item -> BOOLEAN_EQUIV_PROB NEWLINE IT_MATH_OPEN bool_expr IT_MATH_CLOSE NEWLINE IT_MATH_OPEN bool_expr IT_MATH_CLOSE NEWLINE BOOL_EQUIV_ANSWER_HINT NEWLINE BLANK LBRACE ANSWER_WORD FAT_COMMA answer_item COMMA WIDTH_WORD FAT_COMMA INT RBRACE *)
  
  val qbool_equiv_width: bool_expr -> bool_expr -> answer_item -> (int) -> question_item
  
  (* question_item -> COMPLEX_ARITH_PROB NEWLINE IT_MATH_OPEN complex_expr IT_MATH_CLOSE NEWLINE BLANK LBRACE answer_item RBRACE *)
  
  val qcomplex_arith: complex_expr -> answer_item -> question_item
  
  (* question_item -> COMPLEX_CONJ_PROB NEWLINE IT_MATH_OPEN complex_num IT_MATH_CLOSE NEWLINE BLANK LBRACE answer_item RBRACE *)
  
  val qcomplex_conj: complex_num -> answer_item -> question_item
  
  (* question_item -> COMPLEX_MOD_PROB NEWLINE IT_MATH_OPEN complex_num IT_MATH_CLOSE NEWLINE BLANK LBRACE answer_item RBRACE *)
  
  val qcomplex_mod: complex_num -> answer_item -> question_item
  
  (* question_item -> COMPLEX_POWER_I_PROB NEWLINE IT_MATH_OPEN I_UNIT POWER_OP INT IT_MATH_CLOSE NEWLINE BLANK LBRACE answer_item RBRACE *)
  
  val qcomplex_power_i: (int) -> answer_item -> question_item
  
  (* The binary choice constructor at type [quadratic_function]. *)
  
  val quadratic_function_choice: quadratic_function -> quadratic_function -> quadratic_function
  
  (* quadratic_function -> fun_or_var POWER_OP INT ADD_OP INT MUL_OP fun_or_var ADD_OP INT *)
  
  val quad_add: fun_or_var -> (int) -> (int) -> fun_or_var -> (int) -> quadratic_function
  
  (* quadratic_function -> fun_or_var POWER_OP INT SUB_OP INT MUL_OP fun_or_var ADD_OP INT *)
  
  val quad_sub: fun_or_var -> (int) -> (int) -> fun_or_var -> (int) -> quadratic_function
  
  (* quadratic_function -> LPAREN fun_or_var RPAREN POWER_OP INT *)
  
  val quad_square: fun_or_var -> (int) -> quadratic_function
  
  (* The binary choice constructor at type [property]. *)
  
  val property_choice: property -> property -> property
  
  (* property -> key FAT_COMMA value *)
  
  val property: key -> value -> property
  
  (* The binary choice constructor at type [properties]. *)
  
  val properties_choice: properties -> properties -> properties
  
  (* properties -> property COMMA properties *)
  
  val properties: property -> properties -> properties
  
  (* properties -> property *)
  
  val properties_single: property -> properties
  
  (* The binary choice constructor at type [problem_section]. *)
  
  val problem_section_choice: problem_section -> problem_section -> problem_section
  
  (* problem_section -> BEGIN_PGML NEWLINE question_list END_PGML NEWLINE *)
  
  val problem_section: question_list -> problem_section
  
  (* The binary choice constructor at type [predicate]. *)
  
  val predicate_choice: predicate -> predicate -> predicate
  
  (* predicate -> X_VAR GT int_with_sign *)
  
  val pred_gt: int_with_sign -> predicate
  
  (* predicate -> X_VAR LT int_with_sign *)
  
  val pred_lt: int_with_sign -> predicate
  
  (* predicate -> X_VAR GEQ_LATEX int_with_sign *)
  
  val pred_geq: int_with_sign -> predicate
  
  (* predicate -> X_VAR LEQ_LATEX int_with_sign *)
  
  val pred_leq: int_with_sign -> predicate
  
  (* predicate -> int_with_sign LT X_VAR LT int_with_sign *)
  
  val pred_between_open: int_with_sign -> int_with_sign -> predicate
  
  (* predicate -> int_with_sign LEQ_LATEX X_VAR LT int_with_sign *)
  
  val pred_between_left_closed: int_with_sign -> int_with_sign -> predicate
  
  (* predicate -> int_with_sign LT X_VAR LEQ_LATEX int_with_sign *)
  
  val pred_between_right_closed: int_with_sign -> int_with_sign -> predicate
  
  (* predicate -> int_with_sign LEQ_LATEX X_VAR LEQ_LATEX int_with_sign *)
  
  val pred_between_closed: int_with_sign -> int_with_sign -> predicate
  
  (* The binary choice constructor at type [power_function]. *)
  
  val power_function_choice: power_function -> power_function -> power_function
  
  (* power_function -> fun_or_var POWER_OP INT *)
  
  val power_fun_int_expr: fun_or_var -> (int) -> power_function
  
  (* The binary choice constructor at type [operator_list]. *)
  
  val operator_list_choice: operator_list -> operator_list -> operator_list
  
  (* operator_list -> DOUBLE_QUOTE operator DOUBLE_QUOTE COMMA operator_list *)
  
  val operator_list_dou: operator -> operator_list -> operator_list
  
  (* operator_list -> SINGLE_QUOTE operator SINGLE_QUOTE COMMA operator_list *)
  
  val operator_list_sin: operator -> operator_list -> operator_list
  
  (* operator_list -> DOUBLE_QUOTE operator DOUBLE_QUOTE *)
  
  val operator_list_single_dou: operator -> operator_list
  
  (* operator_list -> SINGLE_QUOTE operator SINGLE_QUOTE *)
  
  val operator_list_single_sin: operator -> operator_list
  
  (* The binary choice constructor at type [operator]. *)
  
  val operator_choice: operator -> operator -> operator
  
  (* operator -> ADD_OP *)
  
  val operator_add: unit -> operator
  
  (* operator -> SUB_OP *)
  
  val operator_sub: unit -> operator
  
  (* operator -> MUL_OP *)
  
  val operator_mul: unit -> operator
  
  (* operator -> DIV_OP *)
  
  val operator_div: unit -> operator
  
  (* The binary choice constructor at type [module_]. *)
  
  val module__choice: module_ -> module_ -> module_
  
  (* module_ -> ID *)
  
  val module_: (string) -> module_
  
  (* The binary choice constructor at type [math_object_method]. *)
  
  val math_object_method_choice: math_object_method -> math_object_method -> math_object_method
  
  (* math_object_method -> RANDOM_METH LPAREN INT COMMA INT COMMA INT RPAREN *)
  
  val meth_rand: (int) -> (int) -> (int) -> math_object_method
  
  (* math_object_method -> FORMULA_METH LPAREN SINGLE_QUOTE math_expr SINGLE_QUOTE RPAREN *)
  
  val meth_form: math_expr -> math_object_method
  
  (* math_object_method -> FORMULA_METH LPAREN DOUBLE_QUOTE function_expr DOUBLE_QUOTE RPAREN *)
  
  val meth_form_fun: function_expr -> math_object_method
  
  (* math_object_method -> COMPLEX_METH LPAREN int_with_sign COMMA int_with_sign RPAREN *)
  
  val meth_complex: int_with_sign -> int_with_sign -> math_object_method
  
  (* math_object_method -> REAL_METH LPAREN value RPAREN *)
  
  val meth_real: value -> math_object_method
  
  (* math_object_method -> D_METH LPAREN RPAREN *)
  
  val meth_d_none: unit -> math_object_method
  
  (* math_object_method -> D_METH LPAREN SINGLE_QUOTE ID SINGLE_QUOTE RPAREN *)
  
  val meth_d: (string) -> math_object_method
  
  (* math_object_method -> EVAL_METH LPAREN property RPAREN *)
  
  val meth_eval: property -> math_object_method
  
  (* math_object_method -> WITH_METH LPAREN property RPAREN *)
  
  val meth_with: property -> math_object_method
  
  (* math_object_method -> SET_DEF_METH LPAREN set_enum RPAREN *)
  
  val meth_set: set_enum -> math_object_method
  
  (* math_object_method -> COMPUTE_METH LPAREN DOUBLE_QUOTE set_compute DOUBLE_QUOTE RPAREN *)
  
  val meth_compute: set_compute -> math_object_method
  
  (* math_object_method -> INTERSECT_METH LPAREN variable RPAREN *)
  
  val meth_intersect: variable -> math_object_method
  
  (* The binary choice constructor at type [math_expr]. *)
  
  val math_expr_choice: math_expr -> math_expr -> math_expr
  
  (* math_expr -> math_expr ADD_OP term *)
  
  val madd: math_expr -> term -> math_expr
  
  (* math_expr -> math_expr SUB_OP term *)
  
  val msub: math_expr -> term -> math_expr
  
  (* math_expr -> term *)
  
  val mterm: term -> math_expr
  
  (* The binary choice constructor at type [main]. *)
  
  val main_choice: main -> main -> main
  
  (* main -> DOCUMENT LPAREN RPAREN SEMI NEWLINE header context_setup_list problem_section ENDDOCUMENT LPAREN RPAREN SEMI EOF *)
  
  val doc_no_sol: header -> context_setup_list -> problem_section -> main
  
  (* The binary choice constructor at type [macro]. *)
  
  val macro_choice: macro -> macro -> macro
  
  (* macro -> DOUBLE_QUOTE MACRO DOUBLE_QUOTE COMMA macro *)
  
  val macro_cons: (string) -> macro -> macro
  
  (* macro -> DOUBLE_QUOTE MACRO DOUBLE_QUOTE *)
  
  val macro_atom: (string) -> macro
  
  (* The binary choice constructor at type [log_function]. *)
  
  val log_function_choice: log_function -> log_function -> log_function
  
  (* log_function -> LN_OP LPAREN fun_or_var RPAREN *)
  
  val ln_fun: fun_or_var -> log_function
  
  (* The binary choice constructor at type [linear_function]. *)
  
  val linear_function_choice: linear_function -> linear_function -> linear_function
  
  (* linear_function -> fun_or_var ADD_OP INT *)
  
  val fun_add_int: fun_or_var -> (int) -> linear_function
  
  (* linear_function -> fun_or_var SUB_OP INT *)
  
  val fun_sub_int: fun_or_var -> (int) -> linear_function
  
  (* linear_function -> INT SUB_OP fun_or_var *)
  
  val int_sub_fun: (int) -> fun_or_var -> linear_function
  
  (* linear_function -> INT MUL_OP fun_or_var *)
  
  val int_mul_fun: (int) -> fun_or_var -> linear_function
  
  (* linear_function -> fun_or_var MUL_OP INT *)
  
  val fun_mul_int: fun_or_var -> (int) -> linear_function
  
  (* The binary choice constructor at type [key]. *)
  
  val key_choice: key -> key -> key
  
  (* key -> NAMING ID *)
  
  val key_ident: (string) -> key
  
  (* key -> ID *)
  
  val key_str: (string) -> key
  
  (* The binary choice constructor at type [intext_call]. *)
  
  val intext_call_choice: intext_call -> intext_call -> intext_call
  
  (* intext_call -> IT_VAR_OPEN variable IT_VAR_CLOSE *)
  
  val ict_varv: variable -> intext_call
  
  (* intext_call -> IT_MATH_OPEN math_expr IT_MATH_CLOSE *)
  
  val ict_math: math_expr -> intext_call
  
  (* The binary choice constructor at type [interval_value]. *)
  
  val interval_value_choice: interval_value -> interval_value -> interval_value
  
  (* interval_value -> int_with_sign *)
  
  val interval_int: int_with_sign -> interval_value
  
  (* interval_value -> INFINITY *)
  
  val interval_infinity: unit -> interval_value
  
  (* interval_value -> NEG_INFINITY *)
  
  val interval_neg_infinity: unit -> interval_value
  
  (* The binary choice constructor at type [int_with_sign]. *)
  
  val int_with_sign_choice: int_with_sign -> int_with_sign -> int_with_sign
  
  (* int_with_sign -> SUB_OP INT *)
  
  val negative_int: (int) -> int_with_sign
  
  (* int_with_sign -> INT *)
  
  val positive_int: (int) -> int_with_sign
  
  (* The binary choice constructor at type [header]. *)
  
  val header_choice: header -> header -> header
  
  (* header -> LOADMACROS LPAREN DOUBLE_QUOTE PGSTANDARD DOUBLE_QUOTE COMMA DOUBLE_QUOTE MATHOBJECTS DOUBLE_QUOTE COMMA DOUBLE_QUOTE PGML DOUBLE_QUOTE COMMA macro RPAREN SEMI NEWLINE *)
  
  val header_with_macro: macro -> header
  
  (* header -> LOADMACROS LPAREN DOUBLE_QUOTE PGSTANDARD DOUBLE_QUOTE COMMA DOUBLE_QUOTE MATHOBJECTS DOUBLE_QUOTE COMMA DOUBLE_QUOTE PGML DOUBLE_QUOTE RPAREN SEMI NEWLINE *)
  
  val header_simple: unit -> header
  
  (* The binary choice constructor at type [function_expr]. *)
  
  val function_expr_choice: function_expr -> function_expr -> function_expr
  
  (* function_expr -> linear_function *)
  
  val linear_fun: linear_function -> function_expr
  
  (* function_expr -> quadratic_function *)
  
  val quadratic_fun: quadratic_function -> function_expr
  
  (* function_expr -> power_function *)
  
  val power_fun: power_function -> function_expr
  
  (* function_expr -> radical_function *)
  
  val radical_fun: radical_function -> function_expr
  
  (* function_expr -> rational_function *)
  
  val rational_fun: rational_function -> function_expr
  
  (* function_expr -> log_function *)
  
  val log_fun: log_function -> function_expr
  
  (* function_expr -> trig_function *)
  
  val trig_fun: trig_function -> function_expr
  
  (* function_expr -> exp_function *)
  
  val exp_fun: exp_function -> function_expr
  
  (* The binary choice constructor at type [fun_or_var]. *)
  
  val fun_or_var_choice: fun_or_var -> fun_or_var -> fun_or_var
  
  (* fun_or_var -> X_VAR *)
  
  val var_x: unit -> fun_or_var
  
  (* fun_or_var -> LPAREN function_expr RPAREN *)
  
  val func: function_expr -> fun_or_var
  
  (* The binary choice constructor at type [factor]. *)
  
  val factor_choice: factor -> factor -> factor
  
  (* factor -> LPAREN math_expr RPAREN *)
  
  val fparen: math_expr -> factor
  
  (* factor -> NUMBER *)
  
  val fnum: (float) -> factor
  
  (* factor -> INT *)
  
  val fint: (int) -> factor
  
  (* The binary choice constructor at type [exp_function]. *)
  
  val exp_function_choice: exp_function -> exp_function -> exp_function
  
  (* exp_function -> NAT_LOG POWER_OP LPAREN fun_or_var RPAREN *)
  
  val exp: fun_or_var -> exp_function
  
  (* The binary choice constructor at type [entry_list]. *)
  
  val entry_list_choice: entry_list -> entry_list -> entry_list
  
  (* entry_list -> entry COMMA entry_list *)
  
  val entry_list: entry -> entry_list -> entry_list
  
  (* entry_list -> entry *)
  
  val entry_list_single: entry -> entry_list
  
  (* The binary choice constructor at type [entry]. *)
  
  val entry_choice: entry -> entry -> entry
  
  (* entry -> key FAT_COMMA LBRACE RBRACE *)
  
  val entry_map_none: key -> entry
  
  (* entry -> key FAT_COMMA LBRACE properties RBRACE *)
  
  val entry_map: key -> properties -> entry
  
  (* entry -> property *)
  
  val entry_prop: property -> entry
  
  (* The binary choice constructor at type [derivative_prob_list]. *)
  
  val derivative_prob_list_choice: derivative_prob_list -> derivative_prob_list -> derivative_prob_list
  
  (* derivative_prob_list -> SUB_OP derivative_prob NEWLINE derivative_prob_list *)
  
  val der_prob_list_cons: derivative_prob -> derivative_prob_list -> derivative_prob_list
  
  (* derivative_prob_list -> SUB_OP derivative_prob NEWLINE *)
  
  val der_prob_list_last: derivative_prob -> derivative_prob_list
  
  (* The binary choice constructor at type [derivative_prob]. *)
  
  val derivative_prob_choice: derivative_prob -> derivative_prob -> derivative_prob
  
  (* derivative_prob -> IT_MATH_OPEN F_FUN SINGLE_QUOTE LPAREN X_VAR RPAREN EQ IT_MATH_CLOSE BLANK LBRACE NAMING ID ARROW D_METH LPAREN RPAREN RBRACE *)
  
  val der_prob_1: (string) -> derivative_prob
  
  (* derivative_prob -> IT_MATH_OPEN F_FUN SINGLE_QUOTE LPAREN INT RPAREN EQ IT_MATH_CLOSE BLANK LBRACE NAMING ID ARROW D_METH LPAREN RPAREN ARROW EVAL_METH LPAREN X_VAR FAT_COMMA INT RPAREN RBRACE *)
  
  val der_prob_2: (int) -> (string) -> (int) -> derivative_prob
  
  (* derivative_prob -> IT_MATH_OPEN F_FUN SINGLE_QUOTE SINGLE_QUOTE LPAREN X_VAR RPAREN EQ IT_MATH_CLOSE BLANK LBRACE NAMING ID ARROW D_METH LPAREN RPAREN ARROW D_METH LPAREN RPAREN RBRACE *)
  
  val der_prob_3: (string) -> derivative_prob
  
  (* derivative_prob -> INDEFINITE_INTEGRAL_PROB BLANK LBRACE NAMING ID RBRACE *)
  
  val integral_prob: (string) -> derivative_prob
  
  (* The binary choice constructor at type [context_setup_list]. *)
  
  val context_setup_list_choice: context_setup_list -> context_setup_list -> context_setup_list
  
  (* context_setup_list -> context_setup NEWLINE answer_vars NEWLINE context_setup_list *)
  
  val ctx_setup_vars_cons: context_setup -> answer_vars -> context_setup_list -> context_setup_list
  
  (* context_setup_list -> context_setup NEWLINE answer_vars NEWLINE *)
  
  val ctx_setup_vars_last: context_setup -> answer_vars -> context_setup_list
  
  (* context_setup_list -> context_setup NEWLINE context_setup_list *)
  
  val ctx_setup_no_vars_cons: context_setup -> context_setup_list -> context_setup_list
  
  (* context_setup_list -> context_setup NEWLINE *)
  
  val ctx_setup_no_vars_last: context_setup -> context_setup_list
  
  (* The binary choice constructor at type [context_setup]. *)
  
  val context_setup_choice: context_setup -> context_setup -> context_setup
  
  (* context_setup -> CONTEXT LPAREN DOUBLE_QUOTE ID DOUBLE_QUOTE RPAREN SEMI NEWLINE context_config *)
  
  val ctx_with_cfg: (string) -> context_config -> context_setup
  
  (* context_setup -> CONTEXT LPAREN DOUBLE_QUOTE ID DOUBLE_QUOTE RPAREN SEMI NEWLINE *)
  
  val ctx_only: (string) -> context_setup
  
  (* The binary choice constructor at type [context_method]. *)
  
  val context_method_choice: context_method -> context_method -> context_method
  
  (* context_method -> ADD_METH LPAREN entry_list RPAREN *)
  
  val cm_add: entry_list -> context_method
  
  (* context_method -> SET_METH LPAREN entry_list RPAREN *)
  
  val cm_set: entry_list -> context_method
  
  (* context_method -> ARE_METH LPAREN entry_list RPAREN *)
  
  val cm_are: entry_list -> context_method
  
  (* context_method -> UNDEFINE_METH LPAREN operator_list RPAREN *)
  
  val cm_undefine: operator_list -> context_method
  
  (* context_method -> REDEFINE_METH LPAREN operator_list RPAREN *)
  
  val cm_redefine: operator_list -> context_method
  
  (* The binary choice constructor at type [context_config]. *)
  
  val context_config_choice: context_config -> context_config -> context_config
  
  (* context_config -> CONTEXT LPAREN RPAREN ARROW module_ ARROW context_method SEMI NEWLINE context_config *)
  
  val cfg_cons: module_ -> context_method -> context_config -> context_config
  
  (* context_config -> CONTEXT LPAREN RPAREN ARROW module_ ARROW context_method SEMI NEWLINE *)
  
  val cfg_last: module_ -> context_method -> context_config
  
  (* The binary choice constructor at type [complex_num]. *)
  
  val complex_num_choice: complex_num -> complex_num -> complex_num
  
  (* complex_num -> int_with_sign ADD_OP INT I_UNIT *)
  
  val complex_num_pos_im: int_with_sign -> (int) -> complex_num
  
  (* complex_num -> int_with_sign SUB_OP INT I_UNIT *)
  
  val complex_num_neg_im: int_with_sign -> (int) -> complex_num
  
  (* complex_num -> int_with_sign I_UNIT *)
  
  val complex_num_imag: int_with_sign -> complex_num
  
  (* complex_num -> int_with_sign *)
  
  val complex_num_real: int_with_sign -> complex_num
  
  (* The binary choice constructor at type [complex_expr]. *)
  
  val complex_expr_choice: complex_expr -> complex_expr -> complex_expr
  
  (* complex_expr -> LPAREN complex_expr RPAREN ADD_OP LPAREN complex_expr RPAREN *)
  
  val complex_add: complex_expr -> complex_expr -> complex_expr
  
  (* complex_expr -> LPAREN complex_expr RPAREN SUB_OP LPAREN complex_expr RPAREN *)
  
  val complex_sub: complex_expr -> complex_expr -> complex_expr
  
  (* complex_expr -> LPAREN complex_expr RPAREN MUL_OP LPAREN complex_expr RPAREN *)
  
  val complex_mul: complex_expr -> complex_expr -> complex_expr
  
  (* complex_expr -> complex_num *)
  
  val complex_lit: complex_num -> complex_expr
  
  (* The binary choice constructor at type [bool_expr]. *)
  
  val bool_expr_choice: bool_expr -> bool_expr -> bool_expr
  
  (* bool_expr -> bool_expr AND_WORD bool_expr *)
  
  val bool_and: bool_expr -> bool_expr -> bool_expr
  
  (* bool_expr -> bool_expr OR_WORD bool_expr *)
  
  val bool_or: bool_expr -> bool_expr -> bool_expr
  
  (* bool_expr -> bool_expr XOR_WORD bool_expr *)
  
  val bool_xor: bool_expr -> bool_expr -> bool_expr
  
  (* bool_expr -> bool_expr IMPLIES_WORD bool_expr *)
  
  val bool_implies: bool_expr -> bool_expr -> bool_expr
  
  (* bool_expr -> bool_expr IFF_WORD bool_expr *)
  
  val bool_iff: bool_expr -> bool_expr -> bool_expr
  
  (* bool_expr -> NOT_WORD bool_expr *)
  
  val bool_not: bool_expr -> bool_expr
  
  (* bool_expr -> LPAREN bool_expr RPAREN *)
  
  val bool_paren: bool_expr -> bool_expr
  
  (* bool_expr -> TRUE_WORD *)
  
  val bool_true: unit -> bool_expr
  
  (* bool_expr -> FALSE_WORD *)
  
  val bool_false: unit -> bool_expr
  
  (* bool_expr -> ID *)
  
  val bool_var: (string) -> bool_expr
  
  (* The binary choice constructor at type [bool_assignment_list]. *)
  
  val bool_assignment_list_choice: bool_assignment_list -> bool_assignment_list -> bool_assignment_list
  
  (* bool_assignment_list -> bool_assignment NEWLINE bool_assignment_list *)
  
  val bool_assignment_list_cons: bool_assignment -> bool_assignment_list -> bool_assignment_list
  
  (* bool_assignment_list -> bool_assignment NEWLINE *)
  
  val bool_assignment_list_last: bool_assignment -> bool_assignment_list
  
  (* The binary choice constructor at type [bool_assignment]. *)
  
  val bool_assignment_choice: bool_assignment -> bool_assignment -> bool_assignment
  
  (* bool_assignment -> SUB_OP ID EQ TRUE_WORD *)
  
  val bool_assignment_true: (string) -> bool_assignment
  
  (* bool_assignment -> SUB_OP ID EQ FALSE_WORD *)
  
  val bool_assignment_false: (string) -> bool_assignment
  
  (* The binary choice constructor at type [answer_vars]. *)
  
  val answer_vars_choice: answer_vars -> answer_vars -> answer_vars
  
  (* answer_vars -> variable_list *)
  
  val answer_vars: variable_list -> answer_vars
  
  (* The binary choice constructor at type [answer_item]. *)
  
  val answer_item_choice: answer_item -> answer_item -> answer_item
  
  (* answer_item -> variable *)
  
  val ans_var: variable -> answer_item
  
end

(* Deconstructing concrete syntax trees (CSTs). *)

module CST : sig
  
  (* The type of CSTs for the nonterminal symbol [vector_prob_list]. *)
  
  type vector_prob_list
  
  (* The type of CSTs for the nonterminal symbol [vector_prob]. *)
  
  type vector_prob
  
  (* The type of CSTs for the nonterminal symbol [vector_list]. *)
  
  type vector_list
  
  (* The type of CSTs for the nonterminal symbol [variable_list]. *)
  
  type variable_list
  
  (* The type of CSTs for the nonterminal symbol [variable_declaration]. *)
  
  type variable_declaration
  
  (* The type of CSTs for the nonterminal symbol [variable]. *)
  
  type variable
  
  (* The type of CSTs for the nonterminal symbol [value]. *)
  
  type value
  
  (* The type of CSTs for the nonterminal symbol [trig_function]. *)
  
  type trig_function
  
  (* The type of CSTs for the nonterminal symbol [term]. *)
  
  type term
  
  (* The type of CSTs for the nonterminal symbol [set_term]. *)
  
  type set_term
  
  (* The type of CSTs for the nonterminal symbol [set_prob_list]. *)
  
  type set_prob_list
  
  (* The type of CSTs for the nonterminal symbol [set_primary]. *)
  
  type set_primary
  
  (* The type of CSTs for the nonterminal symbol [set_operation]. *)
  
  type set_operation
  
  (* The type of CSTs for the nonterminal symbol [set_list]. *)
  
  type set_list
  
  (* The type of CSTs for the nonterminal symbol [set_interval]. *)
  
  type set_interval
  
  (* The type of CSTs for the nonterminal symbol [set_factor]. *)
  
  type set_factor
  
  (* The type of CSTs for the nonterminal symbol [set_expr]. *)
  
  type set_expr
  
  (* The type of CSTs for the nonterminal symbol [set_enum]. *)
  
  type set_enum
  
  (* The type of CSTs for the nonterminal symbol [set_compute_term]. *)
  
  type set_compute_term
  
  (* The type of CSTs for the nonterminal symbol [set_compute_interval]. *)
  
  type set_compute_interval
  
  (* The type of CSTs for the nonterminal symbol [set_compute_factor]. *)
  
  type set_compute_factor
  
  (* The type of CSTs for the nonterminal symbol [set_compute]. *)
  
  type set_compute
  
  (* The type of CSTs for the nonterminal symbol [rational_function]. *)
  
  type rational_function
  
  (* The type of CSTs for the nonterminal symbol [radical_function]. *)
  
  type radical_function
  
  (* The type of CSTs for the nonterminal symbol [question_text]. *)
  
  type question_text
  
  (* The type of CSTs for the nonterminal symbol [question_list]. *)
  
  type question_list
  
  (* The type of CSTs for the nonterminal symbol [question_item]. *)
  
  type question_item
  
  (* The type of CSTs for the nonterminal symbol [quadratic_function]. *)
  
  type quadratic_function
  
  (* The type of CSTs for the nonterminal symbol [property]. *)
  
  type property
  
  (* The type of CSTs for the nonterminal symbol [properties]. *)
  
  type properties
  
  (* The type of CSTs for the nonterminal symbol [problem_section]. *)
  
  type problem_section
  
  (* The type of CSTs for the nonterminal symbol [predicate]. *)
  
  type predicate
  
  (* The type of CSTs for the nonterminal symbol [power_function]. *)
  
  type power_function
  
  (* The type of CSTs for the nonterminal symbol [operator_list]. *)
  
  type operator_list
  
  (* The type of CSTs for the nonterminal symbol [operator]. *)
  
  type operator
  
  (* The type of CSTs for the nonterminal symbol [module_]. *)
  
  type module_
  
  (* The type of CSTs for the nonterminal symbol [math_object_method]. *)
  
  type math_object_method
  
  (* The type of CSTs for the nonterminal symbol [math_expr]. *)
  
  type math_expr
  
  (* The type of CSTs for the nonterminal symbol [main]. *)
  
  type main
  
  (* The type of CSTs for the nonterminal symbol [macro]. *)
  
  type macro
  
  (* The type of CSTs for the nonterminal symbol [log_function]. *)
  
  type log_function
  
  (* The type of CSTs for the nonterminal symbol [linear_function]. *)
  
  type linear_function
  
  (* The type of CSTs for the nonterminal symbol [key]. *)
  
  type key
  
  (* The type of CSTs for the nonterminal symbol [intext_call]. *)
  
  type intext_call
  
  (* The type of CSTs for the nonterminal symbol [interval_value]. *)
  
  type interval_value
  
  (* The type of CSTs for the nonterminal symbol [int_with_sign]. *)
  
  type int_with_sign
  
  (* The type of CSTs for the nonterminal symbol [header]. *)
  
  type header
  
  (* The type of CSTs for the nonterminal symbol [function_expr]. *)
  
  type function_expr
  
  (* The type of CSTs for the nonterminal symbol [fun_or_var]. *)
  
  type fun_or_var
  
  (* The type of CSTs for the nonterminal symbol [factor]. *)
  
  type factor
  
  (* The type of CSTs for the nonterminal symbol [exp_function]. *)
  
  type exp_function
  
  (* The type of CSTs for the nonterminal symbol [entry_list]. *)
  
  type entry_list
  
  (* The type of CSTs for the nonterminal symbol [entry]. *)
  
  type entry
  
  (* The type of CSTs for the nonterminal symbol [derivative_prob_list]. *)
  
  type derivative_prob_list
  
  (* The type of CSTs for the nonterminal symbol [derivative_prob]. *)
  
  type derivative_prob
  
  (* The type of CSTs for the nonterminal symbol [context_setup_list]. *)
  
  type context_setup_list
  
  (* The type of CSTs for the nonterminal symbol [context_setup]. *)
  
  type context_setup
  
  (* The type of CSTs for the nonterminal symbol [context_method]. *)
  
  type context_method
  
  (* The type of CSTs for the nonterminal symbol [context_config]. *)
  
  type context_config
  
  (* The type of CSTs for the nonterminal symbol [complex_num]. *)
  
  type complex_num
  
  (* The type of CSTs for the nonterminal symbol [complex_expr]. *)
  
  type complex_expr
  
  (* The type of CSTs for the nonterminal symbol [bool_expr]. *)
  
  type bool_expr
  
  (* The type of CSTs for the nonterminal symbol [bool_assignment_list]. *)
  
  type bool_assignment_list
  
  (* The type of CSTs for the nonterminal symbol [bool_assignment]. *)
  
  type bool_assignment
  
  (* The type of CSTs for the nonterminal symbol [answer_vars]. *)
  
  type answer_vars
  
  (* The type of CSTs for the nonterminal symbol [answer_item]. *)
  
  type answer_item
  
  (* This visitor helps transform concrete syntax trees into something else. *)
  
  class virtual ['r] reduce : object
    
    (* [zero] is an empty piece of output. *)
    
    method virtual zero : 'r
    
    (* [cat] concatenates two pieces of output. *)
    
    method virtual cat : 'r -> 'r -> 'r
    
    (* [text] transforms a string into a piece of output. *)
    
    method virtual text : string -> 'r
    
    (* One method per terminal symbol. *)
    
    method virtual visit_X_VAR : 'r
    
    method virtual visit_XOR_WORD : 'r
    
    method virtual visit_WITH_METH : 'r
    
    method virtual visit_WIDTH_WORD : 'r
    
    method virtual visit_WHEN_WORD : 'r
    
    method virtual visit_WHAT_WORD : 'r
    
    method virtual visit_VEC_LATEX : 'r
    
    method virtual visit_VECTOR_UNIT_PROB : 'r
    
    method virtual visit_VECTOR_SAME_PROB : 'r
    
    method virtual visit_VECTOR_PARA_PROB : 'r
    
    method virtual visit_VALUE_WORD : 'r
    
    method virtual visit_UNIT_METH : 'r
    
    method virtual visit_UNION : 'r
    
    method virtual visit_UNDEFINE_METH : 'r
    
    method virtual visit_TRUE_WORD : 'r
    
    method virtual visit_TO_WORD : 'r
    
    method virtual visit_TIMES_LATEX : 'r
    
    method virtual visit_THE_WORD : 'r
    
    method virtual visit_SUPPOSE_PROB : 'r
    
    method virtual visit_SUB_OP : 'r
    
    method virtual visit_SQRT_OP : 'r
    
    method virtual visit_SIN_OP : 'r
    
    method virtual visit_SINGLE_QUOTE : 'r
    
    method virtual visit_SET_METH : 'r
    
    method virtual visit_SET_DEF_METH : 'r
    
    method virtual visit_SEMI : 'r
    
    method virtual visit_RPAREN : 'r
    
    method virtual visit_RIGHT_NORM_LATEX : 'r
    
    method virtual visit_REDEFINE_METH : 'r
    
    method virtual visit_REAL_METH : 'r
    
    method virtual visit_RBRACKET : 'r
    
    method virtual visit_RBRACE_LATEX : 'r
    
    method virtual visit_RBRACE : 'r
    
    method virtual visit_RANGLE_LATEX : 'r
    
    method virtual visit_RANDOM_METH : 'r
    
    method virtual visit_QUESTION_MARK : 'r
    
    method virtual visit_POWER_OP : 'r
    
    method virtual visit_PIPE : 'r
    
    method virtual visit_PGSTANDARD : 'r
    
    method virtual visit_PGML : 'r
    
    method virtual visit_PERIOD : 'r
    
    method virtual visit_OR_WORD : 'r
    
    method virtual visit_OF_WORD : 'r
    
    method virtual visit_NUMBER : (float) -> 'r
    
    method virtual visit_NOT_WORD : 'r
    
    method virtual visit_NORM_METH : 'r
    
    method virtual visit_NEWLINE : 'r
    
    method virtual visit_NEG_INFINITY : 'r
    
    method virtual visit_NAT_LOG : 'r
    
    method virtual visit_NAMING : 'r
    
    method virtual visit_MUL_OP : 'r
    
    method virtual visit_MATHOBJECTS : 'r
    
    method virtual visit_MACRO : (string) -> 'r
    
    method virtual visit_LT : 'r
    
    method virtual visit_LPAREN : 'r
    
    method virtual visit_LOADMACROS : 'r
    
    method virtual visit_LN_OP : 'r
    
    method virtual visit_LEQ_LATEX : 'r
    
    method virtual visit_LEFT_NORM_LATEX : 'r
    
    method virtual visit_LBRACKET : 'r
    
    method virtual visit_LBRACE_LATEX : 'r
    
    method virtual visit_LBRACE : 'r
    
    method virtual visit_LANGLE_LATEX : 'r
    
    method virtual visit_I_UNIT : 'r
    
    method virtual visit_IT_VAR_OPEN : 'r
    
    method virtual visit_IT_VAR_CLOSE : 'r
    
    method virtual visit_IT_MATH_OPEN : 'r
    
    method virtual visit_IT_MATH_CLOSE : 'r
    
    method virtual visit_IS_WORD : 'r
    
    method virtual visit_INTERSECT_METH : 'r
    
    method virtual visit_INT : (int) -> 'r
    
    method virtual visit_INFINITY : 'r
    
    method virtual visit_INDEFINITE_INTEGRAL_PROB : 'r
    
    method virtual visit_IMPLIES_WORD : 'r
    
    method virtual visit_IFF_WORD : 'r
    
    method virtual visit_ID : (string) -> 'r
    
    method virtual visit_GT : 'r
    
    method virtual visit_GIVEN_PROB : 'r
    
    method virtual visit_GIVEN_FUN : 'r
    
    method virtual visit_GEQ_LATEX : 'r
    
    method virtual visit_F_FUN : 'r
    
    method virtual visit_FORMULA_METH : 'r
    
    method virtual visit_FAT_COMMA : 'r
    
    method virtual visit_FALSE_WORD : 'r
    
    method virtual visit_EVAL_METH : 'r
    
    method virtual visit_EVALUATE_BOOL_PROB : 'r
    
    method virtual visit_EQUAL_WORD : 'r
    
    method virtual visit_EQ : 'r
    
    method virtual visit_EOF : 'r
    
    method virtual visit_END_PGML : 'r
    
    method virtual visit_ENDDOCUMENT : 'r
    
    method virtual visit_D_METH : 'r
    
    method virtual visit_DOUBLE_QUOTE : 'r
    
    method virtual visit_DOCUMENT : 'r
    
    method virtual visit_DIV_OP : 'r
    
    method virtual visit_CUP : 'r
    
    method virtual visit_COS_OP : 'r
    
    method virtual visit_CONTEXT : 'r
    
    method virtual visit_COMPUTE_PROB : 'r
    
    method virtual visit_COMPUTE_METH : 'r
    
    method virtual visit_COMPLEX_POWER_I_PROB : 'r
    
    method virtual visit_COMPLEX_MOD_PROB : 'r
    
    method virtual visit_COMPLEX_METH : 'r
    
    method virtual visit_COMPLEX_CONJ_PROB : 'r
    
    method virtual visit_COMPLEX_ARITH_PROB : 'r
    
    method virtual visit_COMMA : 'r
    
    method virtual visit_CMP_2 : 'r
    
    method virtual visit_CMP_1 : 'r
    
    method virtual visit_CDOT_LATEX : 'r
    
    method virtual visit_CAP : 'r
    
    method virtual visit_BOOL_EQUIV_ANSWER_HINT : 'r
    
    method virtual visit_BOOL_ANSWER_HINT : 'r
    
    method virtual visit_BOOLEAN_EQUIV_PROB : 'r
    
    method virtual visit_BLANK : 'r
    
    method virtual visit_BEGIN_PGML : 'r
    
    method virtual visit_ARROW : 'r
    
    method virtual visit_ARE_METH : 'r
    
    method virtual visit_ANSWER_WORD : 'r
    
    method virtual visit_AND_WORD : 'r
    
    method virtual visit_ADD_OP : 'r
    
    method virtual visit_ADD_METH : 'r
    
    (* One method per nonterminal symbol. *)
    
    method visit_vector_prob_list : vector_prob_list -> 'r
    
    method visit_vector_prob : vector_prob -> 'r
    
    method visit_vector_list : vector_list -> 'r
    
    method visit_variable_list : variable_list -> 'r
    
    method visit_variable_declaration : variable_declaration -> 'r
    
    method visit_variable : variable -> 'r
    
    method visit_value : value -> 'r
    
    method visit_trig_function : trig_function -> 'r
    
    method visit_term : term -> 'r
    
    method visit_set_term : set_term -> 'r
    
    method visit_set_prob_list : set_prob_list -> 'r
    
    method visit_set_primary : set_primary -> 'r
    
    method visit_set_operation : set_operation -> 'r
    
    method visit_set_list : set_list -> 'r
    
    method visit_set_interval : set_interval -> 'r
    
    method visit_set_factor : set_factor -> 'r
    
    method visit_set_expr : set_expr -> 'r
    
    method visit_set_enum : set_enum -> 'r
    
    method visit_set_compute_term : set_compute_term -> 'r
    
    method visit_set_compute_interval : set_compute_interval -> 'r
    
    method visit_set_compute_factor : set_compute_factor -> 'r
    
    method visit_set_compute : set_compute -> 'r
    
    method visit_rational_function : rational_function -> 'r
    
    method visit_radical_function : radical_function -> 'r
    
    method visit_question_text : question_text -> 'r
    
    method visit_question_list : question_list -> 'r
    
    method visit_question_item : question_item -> 'r
    
    method visit_quadratic_function : quadratic_function -> 'r
    
    method visit_property : property -> 'r
    
    method visit_properties : properties -> 'r
    
    method visit_problem_section : problem_section -> 'r
    
    method visit_predicate : predicate -> 'r
    
    method visit_power_function : power_function -> 'r
    
    method visit_operator_list : operator_list -> 'r
    
    method visit_operator : operator -> 'r
    
    method visit_module_ : module_ -> 'r
    
    method visit_math_object_method : math_object_method -> 'r
    
    method visit_math_expr : math_expr -> 'r
    
    method visit_main : main -> 'r
    
    method visit_macro : macro -> 'r
    
    method visit_log_function : log_function -> 'r
    
    method visit_linear_function : linear_function -> 'r
    
    method visit_key : key -> 'r
    
    method visit_intext_call : intext_call -> 'r
    
    method visit_interval_value : interval_value -> 'r
    
    method visit_int_with_sign : int_with_sign -> 'r
    
    method visit_header : header -> 'r
    
    method visit_function_expr : function_expr -> 'r
    
    method visit_fun_or_var : fun_or_var -> 'r
    
    method visit_factor : factor -> 'r
    
    method visit_exp_function : exp_function -> 'r
    
    method visit_entry_list : entry_list -> 'r
    
    method visit_entry : entry -> 'r
    
    method visit_derivative_prob_list : derivative_prob_list -> 'r
    
    method visit_derivative_prob : derivative_prob -> 'r
    
    method visit_context_setup_list : context_setup_list -> 'r
    
    method visit_context_setup : context_setup -> 'r
    
    method visit_context_method : context_method -> 'r
    
    method visit_context_config : context_config -> 'r
    
    method visit_complex_num : complex_num -> 'r
    
    method visit_complex_expr : complex_expr -> 'r
    
    method visit_bool_expr : bool_expr -> 'r
    
    method visit_bool_assignment_list : bool_assignment_list -> 'r
    
    method visit_bool_assignment : bool_assignment -> 'r
    
    method visit_answer_vars : answer_vars -> 'r
    
    method visit_answer_item : answer_item -> 'r
    
    (* One method per production. *)
    
    method case_vec_prob_list_cons : vector_prob -> vector_prob_list -> 'r
    
    method case_vec_prob_list_last : vector_prob -> 'r
    
    method case_vec_prob_1 : (string) -> (string) -> set_enum -> set_enum -> 'r
    
    method case_vec_prob_2 : (string) -> (string) -> set_enum -> set_enum -> 'r
    
    method case_vec_prob_3 : (string) -> set_enum -> 'r
    
    method case_vec_prob_4 : (string) -> set_enum -> 'r
    
    method case_vec_prob_5 : (string) -> set_enum -> 'r
    
    method case_vec_prob_6 : (string) -> set_enum -> 'r
    
    method case_vec_list_cons : (string) -> set_enum -> vector_list -> 'r
    
    method case_vec_list_last : (string) -> set_enum -> 'r
    
    method case_var_list : variable_declaration -> variable_list -> 'r
    
    method case_var_list_single : variable_declaration -> 'r
    
    method case_var_decl : (string) -> variable -> 'r
    
    method case_var_value : value -> 'r
    
    method case_var_meth : math_object_method -> 'r
    
    method case_var_field : (string) -> math_object_method -> 'r
    
    method case_var_chain : math_object_method -> math_object_method -> 'r
    
    method case_value_int_neg : (int) -> 'r
    
    method case_value_int_pos : (int) -> 'r
    
    method case_value_num_neg : (float) -> 'r
    
    method case_value_num_pos : (float) -> 'r
    
    method case_value_str_dou : (string) -> 'r
    
    method case_value_str_sin : (string) -> 'r
    
    method case_value_ident : (string) -> 'r
    
    method case_trig_sin : fun_or_var -> 'r
    
    method case_trig_cos : fun_or_var -> 'r
    
    method case_tmul : term -> factor -> 'r
    
    method case_tdiv : term -> factor -> 'r
    
    method case_tfac : factor -> 'r
    
    method case_set_op_inter : set_term -> set_factor -> 'r
    
    method case_set_op_factor : set_factor -> 'r
    
    method case_set_prob_list_cons : set_operation -> answer_item -> set_prob_list -> 'r
    
    method case_set_prob_list_last : set_operation -> answer_item -> 'r
    
    method case_set_primary_var : (string) -> 'r
    
    method case_set_primary_paren : set_operation -> 'r
    
    method case_set_op_union : set_operation -> set_term -> 'r
    
    method case_set_op_term : set_term -> 'r
    
    method case_set_list_cons : (string) -> set_expr -> set_list -> 'r
    
    method case_set_list_last : (string) -> set_expr -> 'r
    
    method case_set_interval : predicate -> 'r
    
    method case_set_op_diff : set_factor -> set_primary -> 'r
    
    method case_set_op_primary : set_primary -> 'r
    
    method case_set_expr_enum : set_enum -> 'r
    
    method case_set_expr_interval : set_interval -> 'r
    
    method case_set_enum_cons : int_with_sign -> set_enum -> 'r
    
    method case_set_enum_last : int_with_sign -> 'r
    
    method case_set_compute_diff : set_compute_term -> set_compute_factor -> 'r
    
    method case_set_compute_factor : set_compute_factor -> 'r
    
    method case_set_compute_interval_open : interval_value -> interval_value -> 'r
    
    method case_set_compute_interval_left_open : interval_value -> interval_value -> 'r
    
    method case_set_compute_interval_right_open : interval_value -> interval_value -> 'r
    
    method case_set_compute_interval_closed : interval_value -> interval_value -> 'r
    
    method case_set_compute_paren : set_compute -> 'r
    
    method case_set_compute_enum : set_enum -> 'r
    
    method case_set_compute_interval : set_compute_interval -> 'r
    
    method case_set_compute_union : set_compute -> set_compute_term -> 'r
    
    method case_set_compute_term : set_compute_term -> 'r
    
    method case_fun_div_int : fun_or_var -> (int) -> 'r
    
    method case_int_div_fun : (int) -> fun_or_var -> 'r
    
    method case_radi_sqrt : fun_or_var -> 'r
    
    method case_radi_root : fun_or_var -> (int) -> (int) -> 'r
    
    method case_qvalue : intext_call -> 'r
    
    method case_qis : intext_call -> 'r
    
    method case_qlist : question_item -> question_list -> 'r
    
    method case_qlist_single : question_item -> 'r
    
    method case_qitem1 : question_text -> answer_item -> 'r
    
    method case_qitem2 : question_text -> answer_item -> (int) -> 'r
    
    method case_qset : set_list -> set_prob_list -> 'r
    
    method case_qvector : vector_list -> vector_prob_list -> 'r
    
    method case_qderivative : (string) -> derivative_prob_list -> 'r
    
    method case_qbool_eval : bool_expr -> bool_assignment_list -> answer_item -> 'r
    
    method case_qbool_eval_width : bool_expr -> bool_assignment_list -> answer_item -> (int) -> 'r
    
    method case_qbool_equiv : bool_expr -> bool_expr -> answer_item -> 'r
    
    method case_qbool_equiv_width : bool_expr -> bool_expr -> answer_item -> (int) -> 'r
    
    method case_qcomplex_arith : complex_expr -> answer_item -> 'r
    
    method case_qcomplex_conj : complex_num -> answer_item -> 'r
    
    method case_qcomplex_mod : complex_num -> answer_item -> 'r
    
    method case_qcomplex_power_i : (int) -> answer_item -> 'r
    
    method case_quad_add : fun_or_var -> (int) -> (int) -> fun_or_var -> (int) -> 'r
    
    method case_quad_sub : fun_or_var -> (int) -> (int) -> fun_or_var -> (int) -> 'r
    
    method case_quad_square : fun_or_var -> (int) -> 'r
    
    method case_property : key -> value -> 'r
    
    method case_properties : property -> properties -> 'r
    
    method case_properties_single : property -> 'r
    
    method case_problem_section : question_list -> 'r
    
    method case_pred_gt : int_with_sign -> 'r
    
    method case_pred_lt : int_with_sign -> 'r
    
    method case_pred_geq : int_with_sign -> 'r
    
    method case_pred_leq : int_with_sign -> 'r
    
    method case_pred_between_open : int_with_sign -> int_with_sign -> 'r
    
    method case_pred_between_left_closed : int_with_sign -> int_with_sign -> 'r
    
    method case_pred_between_right_closed : int_with_sign -> int_with_sign -> 'r
    
    method case_pred_between_closed : int_with_sign -> int_with_sign -> 'r
    
    method case_power_fun_int_expr : fun_or_var -> (int) -> 'r
    
    method case_operator_list_dou : operator -> operator_list -> 'r
    
    method case_operator_list_sin : operator -> operator_list -> 'r
    
    method case_operator_list_single_dou : operator -> 'r
    
    method case_operator_list_single_sin : operator -> 'r
    
    method case_operator_add : unit -> 'r
    
    method case_operator_sub : unit -> 'r
    
    method case_operator_mul : unit -> 'r
    
    method case_operator_div : unit -> 'r
    
    method case_module_ : (string) -> 'r
    
    method case_meth_rand : (int) -> (int) -> (int) -> 'r
    
    method case_meth_form : math_expr -> 'r
    
    method case_meth_form_fun : function_expr -> 'r
    
    method case_meth_complex : int_with_sign -> int_with_sign -> 'r
    
    method case_meth_real : value -> 'r
    
    method case_meth_d_none : unit -> 'r
    
    method case_meth_d : (string) -> 'r
    
    method case_meth_eval : property -> 'r
    
    method case_meth_with : property -> 'r
    
    method case_meth_set : set_enum -> 'r
    
    method case_meth_compute : set_compute -> 'r
    
    method case_meth_intersect : variable -> 'r
    
    method case_madd : math_expr -> term -> 'r
    
    method case_msub : math_expr -> term -> 'r
    
    method case_mterm : term -> 'r
    
    method case_doc_no_sol : header -> context_setup_list -> problem_section -> 'r
    
    method case_macro_cons : (string) -> macro -> 'r
    
    method case_macro_atom : (string) -> 'r
    
    method case_ln_fun : fun_or_var -> 'r
    
    method case_fun_add_int : fun_or_var -> (int) -> 'r
    
    method case_fun_sub_int : fun_or_var -> (int) -> 'r
    
    method case_int_sub_fun : (int) -> fun_or_var -> 'r
    
    method case_int_mul_fun : (int) -> fun_or_var -> 'r
    
    method case_fun_mul_int : fun_or_var -> (int) -> 'r
    
    method case_key_ident : (string) -> 'r
    
    method case_key_str : (string) -> 'r
    
    method case_ict_varv : variable -> 'r
    
    method case_ict_math : math_expr -> 'r
    
    method case_interval_int : int_with_sign -> 'r
    
    method case_interval_infinity : unit -> 'r
    
    method case_interval_neg_infinity : unit -> 'r
    
    method case_negative_int : (int) -> 'r
    
    method case_positive_int : (int) -> 'r
    
    method case_header_with_macro : macro -> 'r
    
    method case_header_simple : unit -> 'r
    
    method case_linear_fun : linear_function -> 'r
    
    method case_quadratic_fun : quadratic_function -> 'r
    
    method case_power_fun : power_function -> 'r
    
    method case_radical_fun : radical_function -> 'r
    
    method case_rational_fun : rational_function -> 'r
    
    method case_log_fun : log_function -> 'r
    
    method case_trig_fun : trig_function -> 'r
    
    method case_exp_fun : exp_function -> 'r
    
    method case_var_x : unit -> 'r
    
    method case_func : function_expr -> 'r
    
    method case_fparen : math_expr -> 'r
    
    method case_fnum : (float) -> 'r
    
    method case_fint : (int) -> 'r
    
    method case_exp : fun_or_var -> 'r
    
    method case_entry_list : entry -> entry_list -> 'r
    
    method case_entry_list_single : entry -> 'r
    
    method case_entry_map_none : key -> 'r
    
    method case_entry_map : key -> properties -> 'r
    
    method case_entry_prop : property -> 'r
    
    method case_der_prob_list_cons : derivative_prob -> derivative_prob_list -> 'r
    
    method case_der_prob_list_last : derivative_prob -> 'r
    
    method case_der_prob_1 : (string) -> 'r
    
    method case_der_prob_2 : (int) -> (string) -> (int) -> 'r
    
    method case_der_prob_3 : (string) -> 'r
    
    method case_integral_prob : (string) -> 'r
    
    method case_ctx_setup_vars_cons : context_setup -> answer_vars -> context_setup_list -> 'r
    
    method case_ctx_setup_vars_last : context_setup -> answer_vars -> 'r
    
    method case_ctx_setup_no_vars_cons : context_setup -> context_setup_list -> 'r
    
    method case_ctx_setup_no_vars_last : context_setup -> 'r
    
    method case_ctx_with_cfg : (string) -> context_config -> 'r
    
    method case_ctx_only : (string) -> 'r
    
    method case_cm_add : entry_list -> 'r
    
    method case_cm_set : entry_list -> 'r
    
    method case_cm_are : entry_list -> 'r
    
    method case_cm_undefine : operator_list -> 'r
    
    method case_cm_redefine : operator_list -> 'r
    
    method case_cfg_cons : module_ -> context_method -> context_config -> 'r
    
    method case_cfg_last : module_ -> context_method -> 'r
    
    method case_complex_num_pos_im : int_with_sign -> (int) -> 'r
    
    method case_complex_num_neg_im : int_with_sign -> (int) -> 'r
    
    method case_complex_num_imag : int_with_sign -> 'r
    
    method case_complex_num_real : int_with_sign -> 'r
    
    method case_complex_add : complex_expr -> complex_expr -> 'r
    
    method case_complex_sub : complex_expr -> complex_expr -> 'r
    
    method case_complex_mul : complex_expr -> complex_expr -> 'r
    
    method case_complex_lit : complex_num -> 'r
    
    method case_bool_and : bool_expr -> bool_expr -> 'r
    
    method case_bool_or : bool_expr -> bool_expr -> 'r
    
    method case_bool_xor : bool_expr -> bool_expr -> 'r
    
    method case_bool_implies : bool_expr -> bool_expr -> 'r
    
    method case_bool_iff : bool_expr -> bool_expr -> 'r
    
    method case_bool_not : bool_expr -> 'r
    
    method case_bool_paren : bool_expr -> 'r
    
    method case_bool_true : unit -> 'r
    
    method case_bool_false : unit -> 'r
    
    method case_bool_var : (string) -> 'r
    
    method case_bool_assignment_list_cons : bool_assignment -> bool_assignment_list -> 'r
    
    method case_bool_assignment_list_last : bool_assignment -> 'r
    
    method case_bool_assignment_true : (string) -> 'r
    
    method case_bool_assignment_false : (string) -> 'r
    
    method case_answer_vars : variable_list -> 'r
    
    method case_ans_var : variable -> 'r
    
  end
  
end

(* Transforming DCSTs to CSTs. *)

module Settle : sig
  
  val main: DCST.main -> CST.main option
  
end

(* The parse tables. *)

(* Warning: this submodule is undocumented. In the future,
   its type could change, or it could disappear altogether. *)

module Tables : MenhirLib.TableFormat.TABLES
  with type token = token
