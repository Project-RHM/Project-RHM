/* parser.mly */
%{
  open Ast
%}

(* -------------------------------------------------------------------------- *)
(* token declarations                                                         *)
(* -------------------------------------------------------------------------- *)
%token EOF
%token NEWLINE

%token DOCUMENT
%token ENDDOCUMENT

%token LOADMACROS
%token PGSTANDARD MATHOBJECTS PGML
%token CONTEXT

(* for context methods *)
%token ADD_METH
%token SET_METH
%token ARE_METH
%token UNDEFINE_METH
%token REDEFINE_METH

%token RANDOM_METH    (* for the word "random" *)
%token FORMULA_METH   (* for the word "Formula" *)
%token REAL_METH      (* for the word "Real" *)
%token D_METH         (* for the word "D" *)
%token EVAL_METH      (* for the word "eval" *)
%token WITH_METH      (* for the word "with" *)
%token SET_DEF_METH   (* for the word "Set" *)
%token COMPUTE_METH   (* for the word "Compute" *)
%token VECTOR_VALUE_OPEN (* explicitly scoped Vector constructor *)
%token COMPLEX_METH   (* for the word "Complex" *)
%token INTERSECT_METH (* for the word "intersect" *)
%token NORM_METH UNIT_METH CMP_1 CMP_2

%token BLANK
%token ANSWER_WORD
%token WIDTH_WORD

%token WHAT_WORD IS_WORD THE_WORD VALUE_WORD OF_WORD EQUAL_WORD TO_WORD QUESTION_MARK
%token GIVEN_PROB COMPUTE_PROB GIVEN_FUN INDEFINITE_INTEGRAL_PROB
%token EVALUATE_BOOL_PROB BOOLEAN_EQUIV_PROB WHEN_WORD BOOL_ANSWER_HINT BOOL_EQUIV_ANSWER_HINT
%token COMPLEX_ARITH_PROB COMPLEX_CONJ_PROB COMPLEX_MOD_PROB COMPLEX_POWER_I_PROB
%token ARITH_SEQ_NTH_PROB GEOM_SEQ_NTH_PROB ARITH_SEQ_SUM_PROB GEOM_SEQ_SUM_PROB
%token TRUE_WORD FALSE_WORD AND_WORD OR_WORD NOT_WORD XOR_WORD IMPLIES_WORD IFF_WORD
%token SUPPOSE_PROB PERIOD VECTOR_UNIT_PROB VECTOR_PARA_PROB VECTOR_SAME_PROB

%token UNION CUP CAP

%token BEGIN_PGML
%token END_PGML

(*%token CORRECT_WORD
%token COLON*)

%token IT_VAR_OPEN IT_MATH_OPEN IT_VAR_CLOSE IT_MATH_CLOSE
(*
%token BEGIN_PGML_SOLUTION
%token END_PGML_SOLUTION
*)
%token EQ

%token DOUBLE_QUOTE
%token SINGLE_QUOTE
%token NAMING
%token ARROW
%token FAT_COMMA

%token COMMA
%token SEMI

%token LPAREN
%token RPAREN

%token LBRACE
%token RBRACE

%token LBRACKET RBRACKET
%token LBRACE_LATEX RBRACE_LATEX PIPE
%token GT LT GEQ_LATEX LEQ_LATEX X_VAR F_FUN NAT_LOG
%token I_UNIT

%token INFINITY NEG_INFINITY

%token VEC_LATEX LANGLE_LATEX RANGLE_LATEX CDOT_LATEX TIMES_LATEX LEFT_NORM_LATEX RIGHT_NORM_LATEX
%token DIV_LATEX

%token ADD_OP
%token SUB_OP
%token MUL_OP
%token DIV_OP
(* ------------------- NEW CODE START ------------------- *)
%token POWER_OP SQRT_OP LN_OP SIN_OP COS_OP
(* ------------------- NEW CODE END ------------------- *)

%token <float> NUMBER
%token <int> INT
%token <string> MACRO
%token <string> ID

%right IFF_WORD
%right IMPLIES_WORD
%left OR_WORD
%left XOR_WORD
%left AND_WORD
%right NOT_WORD

%start <Ast.document> main
%%

(* -------------------------------------------------------------------------- *)
(* document (4 variants)                                                      *)
(* -------------------------------------------------------------------------- *)
main:
  | DOCUMENT; LPAREN; RPAREN; SEMI; NEWLINE;
    hdr   = header;
    ctx   = context_setup_list;
    prob  = problem_section;
    ENDDOCUMENT; LPAREN; RPAREN; SEMI; EOF
      { Doc_No_Sol    (hdr, ctx, prob) }
    [@name doc_no_sol]


(* -------------------------------------------------------------------------- *)
(* header                                                                     *)
(* -------------------------------------------------------------------------- *)
header:
  | LOADMACROS; LPAREN;
    DOUBLE_QUOTE; PGSTANDARD; DOUBLE_QUOTE; COMMA;
    DOUBLE_QUOTE; MATHOBJECTS; DOUBLE_QUOTE; COMMA;
    DOUBLE_QUOTE; PGML; DOUBLE_QUOTE; COMMA;
    mac = macro;
    RPAREN; SEMI; NEWLINE
      { LoadMacros (Some mac) }
    [@name header_with_macro]

  | LOADMACROS; LPAREN;
    DOUBLE_QUOTE; PGSTANDARD; DOUBLE_QUOTE; COMMA;
    DOUBLE_QUOTE; MATHOBJECTS; DOUBLE_QUOTE; COMMA;
    DOUBLE_QUOTE; PGML; DOUBLE_QUOTE;
    RPAREN; SEMI; NEWLINE
      { LoadMacros (None) }
    [@name header_simple]

(* -------------------------------------------------------------------------- *)
(* macro                                                                      *)
(* -------------------------------------------------------------------------- *)
macro:
  | DOUBLE_QUOTE; name  = MACRO; DOUBLE_QUOTE; COMMA; rest = macro
      { Macro_Cons (name, rest) }
    [@name macro_cons]

  | DOUBLE_QUOTE; name  = MACRO; DOUBLE_QUOTE
      { Macro_Atom (name) }
    [@name macro_atom]

(* -------------------------------------------------------------------------- *)
(* context_setup_list                                                         *)
(* -------------------------------------------------------------------------- *)
context_setup_list:
  | csetup = context_setup; NEWLINE; ans_vars = answer_vars; NEWLINE; rest = context_setup_list
      { Context_Setup_Vars_Cons (csetup, ans_vars, rest) }
    [@name ctx_setup_vars_cons]

  | csetup = context_setup; NEWLINE; ans_vars = answer_vars; NEWLINE;
      { Context_Setup_Vars_Last (csetup, ans_vars) }
    [@name ctx_setup_vars_last]

  | csetup = context_setup; NEWLINE; rest = context_setup_list
      { Context_Setup_No_Vars_Cons (csetup, rest) }
    [@name ctx_setup_no_vars_cons]

  | csetup = context_setup; NEWLINE;
      { Context_Setup_No_Vars_Last (csetup) }
    [@name ctx_setup_no_vars_last]

context_setup:
  | CONTEXT; LPAREN; DOUBLE_QUOTE;
    cname = ID; DOUBLE_QUOTE; RPAREN; SEMI; NEWLINE;
    cfg   = context_config
      { Context_With_Config (cname, cfg) }
    [@name ctx_with_cfg]

  | CONTEXT; LPAREN; DOUBLE_QUOTE;
    cname = ID; DOUBLE_QUOTE; RPAREN; SEMI; NEWLINE
      { Context_Only (cname) }
    [@name ctx_only]

(* -------------------------------------------------------------------------- *)
(* context_config                                                             *)
(* -------------------------------------------------------------------------- *)
context_config:
  | CONTEXT; LPAREN; RPAREN; ARROW; modl  = module_; ARROW; cm = context_method; SEMI; NEWLINE; rest = context_config
      { Cfg_Cons  (modl, cm, rest) }
    [@name cfg_cons]

  | CONTEXT; LPAREN; RPAREN; ARROW; modl  = module_; ARROW; cm = context_method; SEMI; NEWLINE
      { Cfg_Last  (modl, cm) }
    [@name cfg_last]

(* -------------------------------------------------------------------------- *)
(* module                                                                     *)
(* -------------------------------------------------------------------------- *)
module_:
  | id = ID
      { match id with
        | "variables" -> Variables
        | "constants" -> Constants
        | "strings"   -> Strings
        | "operators" -> Operators
        | "flags" -> Flags
        | _ -> failwith ("Unknown module: "^id)
      }
    [@name module_]

(* -------------------------------------------------------------------------- *)
(* context_method  (all variants)                                             *)
(* -------------------------------------------------------------------------- *)
context_method:
  | ADD_METH;    LPAREN; entries = entry_list; RPAREN
      { CM_Add       entries }
    [@name cm_add]

  | SET_METH;    LPAREN; entries = entry_list; RPAREN
      { CM_Set       entries }
    [@name cm_set]

  | ARE_METH;    LPAREN; entries = entry_list; RPAREN
      { CM_Are       entries }
    [@name cm_are]

  | UNDEFINE_METH; LPAREN; ops   = operator_list;  RPAREN
      { CM_Undefine   ops     }
    [@name cm_undefine]

  | REDEFINE_METH; LPAREN; ops   = operator_list;  RPAREN
      { CM_Redefine   ops     }
    [@name cm_redefine]

(* -------------------------------------------------------------------------- *)
(* entry_list & entry & properties                                            *)
(* -------------------------------------------------------------------------- *)
entry_list:
  | hd = entry; COMMA; tl = entry_list
      { hd :: tl }
    [@name entry_list]

  | single = entry
      { [single] }
    [@name entry_list_single]

entry:
  | key = key; FAT_COMMA; LBRACE; RBRACE
      { Entry_Map  (key, None) }
    [@name entry_map_none]

  | key = key; FAT_COMMA; LBRACE; props = properties; RBRACE
      { Entry_Map  (key, Some props) }
    [@name entry_map]

  | prop = property
      { Entry_Property prop }
    [@name entry_prop]

property:
  | key = key; FAT_COMMA; value = value
      { Property (key, value) }
    [@name property]

properties:
  | hd = property; COMMA; tl = properties
      { hd :: tl }
    [@name properties]

  | single = property
      { [single] }
    [@name properties_single]

(* -------------------------------------------------------------------------- *)
(* key / value / operators                                                    *)
(* -------------------------------------------------------------------------- *)
key:
  | NAMING; id = ID
      { Ident id }
    [@name key_ident]

  | s = ID
      { Str s }
    [@name key_str]

value:
  | SUB_OP; i = INT
      { VInt (-i) }
    [@name value_int_neg]

  | i = INT
      { VInt i }
    [@name value_int_pos]

  | SUB_OP; n = NUMBER
      { VNum (-.n) }
    [@name value_num_neg]

  | n = NUMBER
      { VNum n }
    [@name value_num_pos]

  | DOUBLE_QUOTE; s = ID; DOUBLE_QUOTE
      { VStr s }
    [@name value_str_dou]

  | SINGLE_QUOTE; s = ID; SINGLE_QUOTE
      { VStr s }
    [@name value_str_sin]

  | NAMING; id = ID
      { VIdent id }
    [@name value_ident]

operator_list:
  | DOUBLE_QUOTE; hd = operator; DOUBLE_QUOTE; COMMA; tl = operator_list
      { hd :: tl }
    [@name operator_list_dou]

  | SINGLE_QUOTE; hd = operator; SINGLE_QUOTE; COMMA; tl = operator_list
      { hd :: tl }
    [@name operator_list_sin]

  | DOUBLE_QUOTE; single = operator; DOUBLE_QUOTE
       { [single] }
     [@name operator_list_single_dou]

  | SINGLE_QUOTE; single = operator; SINGLE_QUOTE
      { [single] }
    [@name operator_list_single_sin]

operator:
  | ADD_OP
      { Add_Op }
    [@name operator_add]

  | SUB_OP
      { Sub_Op }
    [@name operator_sub]

  | MUL_OP
      { Mul_Op }
    [@name operator_mul]

  | DIV_OP
      { Div_Op }
    [@name operator_div]

(* -------------------------------------------------------------------------- *)
(* answer_vars (variable declarations)                                        *)
(* -------------------------------------------------------------------------- *)
answer_vars:
  | vlist = variable_list
      { vlist }
    [@name answer_vars]

variable_list:
  | hd = variable_declaration; NEWLINE; tl = variable_list
      { hd :: tl }
    [@name var_list]

  | single = variable_declaration; NEWLINE
      { [single] }
    [@name var_list_single]

variable_declaration:
  | NAMING; id = ID; EQ; v = variable; SEMI
      { (id, v) }
    [@name var_decl]

variable:
  | v = value
      { Var_Value v }
    [@name var_value]

  | meth = math_object_method
      { Var_Method meth }
    [@name var_meth]

  | NAMING; id = ID; ARROW; meth = math_object_method
      { Var_Field (id, meth) }
    [@name var_field]

  | lhs = math_object_method; ARROW; rhs = math_object_method
      { Var_Chain (lhs, rhs) }
    [@name var_chain]

(* -------------------------------------------------------------------------- *)
(* math_object_method                                                         *)
(* -------------------------------------------------------------------------- *)
math_object_method:
  | RANDOM_METH; LPAREN; i1 = INT; COMMA; i2 = INT; COMMA; i3 = INT; RPAREN
      { M_Random (i1, i2, i3) }
    [@name meth_rand]

  (* To solve shift/reduce conflicts, for parsing:
     - using '' for math_expr in Formula
     - using "" for function_expr in Formula
     *)
  | FORMULA_METH; LPAREN; SINGLE_QUOTE; expr = math_expr; SINGLE_QUOTE; RPAREN
      { M_Formula expr }
    [@name meth_form]

  (* ------------------- NEW CODE START ------------------- *)
  | FORMULA_METH; LPAREN; DOUBLE_QUOTE; expr = function_expr; DOUBLE_QUOTE; RPAREN
      { M_Formula_Fun expr }
    [@name meth_form_fun]
  (* ------------------- NEW CODE END ------------------- *)

  | COMPLEX_METH; LPAREN; re = int_with_sign; COMMA; im = int_with_sign; RPAREN
      { M_Complex (re, im) }
    [@name meth_complex]

  | REAL_METH; LPAREN; n = value; RPAREN
      { M_Real n }
    [@name meth_real]

  | D_METH; LPAREN; RPAREN
      { M_D None }
    [@name meth_d_none]

  | D_METH; LPAREN; SINGLE_QUOTE; unknown = ID; SINGLE_QUOTE; RPAREN
      { M_D (Some unknown) }
    [@name meth_d]

  | EVAL_METH; LPAREN; prop = property; RPAREN
      { M_Eval prop }
    [@name meth_eval]

  | WITH_METH; LPAREN; prop = property; RPAREN
      { M_With prop }
    [@name meth_with]

  | SET_DEF_METH; LPAREN; enum = set_enum; RPAREN
      { M_Set enum }
    [@name meth_set]

  | COMPUTE_METH; LPAREN; DOUBLE_QUOTE; compute = set_compute; DOUBLE_QUOTE; RPAREN
      { M_Compute compute }
    [@name meth_compute]

  | INTERSECT_METH; LPAREN; var = variable; RPAREN
      { M_intersect var }
    [@name meth_intersect]

(* -------------------------------------------------------------------------- *)
(* problem_section & questions                                                *)
(* -------------------------------------------------------------------------- *)
problem_section:
  | BEGIN_PGML; NEWLINE; qlist = question_list; END_PGML; NEWLINE
      { Problem qlist }
    [@name problem_section]

question_list:
  | item = question_item; NEWLINE; NEWLINE; rest = question_list
      { item :: rest }  [@name qlist]

  | item = question_item; NEWLINE
      { [item] }        [@name qlist_single]

question_item:
  | qtxt = question_text; BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Item (qtxt, ans, None) }
    [@name qitem1]

  | qtxt = question_text; BLANK; LBRACE; ANSWER_WORD; FAT_COMMA; ans = answer_item; COMMA; WIDTH_WORD; FAT_COMMA; w = INT; RBRACE
      { Q_Item (qtxt, ans, Some w) }
    [@name qitem2]

  | GIVEN_PROB; NEWLINE; s_list = set_list; NEWLINE; COMPUTE_PROB; NEWLINE; sp_list = set_prob_list
      { Q_Given_Set (s_list, sp_list) }
    [@name qset]

  | SUPPOSE_PROB; NEWLINE; vec_list = vector_list; NEWLINE; COMPUTE_PROB; NEWLINE; vecp_list = vector_prob_list
      { Q_Suppose_Vector (vec_list, vecp_list) }
    [@name qvector]
  (* ------------------- NEW CODE START ------------------- *)
  | GIVEN_FUN; NEWLINE; NEWLINE; IT_VAR_OPEN; NAMING; fun_name = ID; IT_VAR_CLOSE; NEWLINE; NEWLINE; COMPUTE_PROB; NEWLINE; derp_list = derivative_prob_list
      { Q_Given_Function (fun_name, derp_list) }
    [@name qderivative]

  (* ------------------- NEW CODE END ------------------- *)

  | EVALUATE_BOOL_PROB; NEWLINE; IT_MATH_OPEN; expr = bool_expr; IT_MATH_CLOSE; NEWLINE;
    WHEN_WORD; NEWLINE; assignments = bool_assignment_list;
    BOOL_ANSWER_HINT; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Boolean_Eval (expr, assignments, ans, None) }
    [@name qbool_eval]

  | EVALUATE_BOOL_PROB; NEWLINE; IT_MATH_OPEN; expr = bool_expr; IT_MATH_CLOSE; NEWLINE;
    WHEN_WORD; NEWLINE; assignments = bool_assignment_list;
    BOOL_ANSWER_HINT; NEWLINE;
    BLANK; LBRACE; ANSWER_WORD; FAT_COMMA; ans = answer_item; COMMA; WIDTH_WORD; FAT_COMMA; w = INT; RBRACE
      { Q_Boolean_Eval (expr, assignments, ans, Some w) }
    [@name qbool_eval_width]

  | BOOLEAN_EQUIV_PROB; NEWLINE;
    IT_MATH_OPEN; left = bool_expr; IT_MATH_CLOSE; NEWLINE;
    IT_MATH_OPEN; right = bool_expr; IT_MATH_CLOSE; NEWLINE;
    BOOL_EQUIV_ANSWER_HINT; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Boolean_Equiv (left, right, ans, None) }
    [@name qbool_equiv]

  | BOOLEAN_EQUIV_PROB; NEWLINE;
    IT_MATH_OPEN; left = bool_expr; IT_MATH_CLOSE; NEWLINE;
    IT_MATH_OPEN; right = bool_expr; IT_MATH_CLOSE; NEWLINE;
    BOOL_EQUIV_ANSWER_HINT; NEWLINE;
    BLANK; LBRACE; ANSWER_WORD; FAT_COMMA; ans = answer_item; COMMA; WIDTH_WORD; FAT_COMMA; w = INT; RBRACE
      { Q_Boolean_Equiv (left, right, ans, Some w) }
    [@name qbool_equiv_width]

  | COMPLEX_ARITH_PROB; NEWLINE;
    IT_MATH_OPEN; expr = complex_expr; IT_MATH_CLOSE; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Complex_Arithmetic (expr, ans) }
    [@name qcomplex_arith]

  | COMPLEX_CONJ_PROB; NEWLINE;
    IT_MATH_OPEN; num = complex_num; IT_MATH_CLOSE; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Complex_Conjugate (num, ans) }
    [@name qcomplex_conj]

  | COMPLEX_MOD_PROB; NEWLINE;
    IT_MATH_OPEN; num = complex_num; IT_MATH_CLOSE; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Complex_Modulus (num, ans) }
    [@name qcomplex_mod]

  | COMPLEX_POWER_I_PROB; NEWLINE;
    IT_MATH_OPEN; I_UNIT; POWER_OP; exponent = INT; IT_MATH_CLOSE; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Complex_Power_I (exponent, ans) }
    [@name qcomplex_power_i]

  | ARITH_SEQ_NTH_PROB; NEWLINE;
    first = sequence_param; NEWLINE;
    diff = sequence_param; NEWLINE;
    index = sequence_param; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Sequence (Arithmetic_Nth (first, diff, index), ans, None) }
    [@name qsequence_arith_nth]

  | GEOM_SEQ_NTH_PROB; NEWLINE;
    first = sequence_param; NEWLINE;
    ratio = sequence_param; NEWLINE;
    index = sequence_param; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Sequence (Geometric_Nth (first, ratio, index), ans, None) }
    [@name qsequence_geom_nth]

  | ARITH_SEQ_SUM_PROB; NEWLINE;
    first = sequence_param; NEWLINE;
    diff = sequence_param; NEWLINE;
    count = sequence_param; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Sequence (Arithmetic_Sum (first, diff, count), ans, None) }
    [@name qsequence_arith_sum]

  | GEOM_SEQ_SUM_PROB; NEWLINE;
    first = sequence_param; NEWLINE;
    ratio = sequence_param; NEWLINE;
    count = sequence_param; NEWLINE;
    BLANK; LBRACE; ans = answer_item; RBRACE
      { Q_Sequence (Geometric_Sum (first, ratio, count), ans, None) }
    [@name qsequence_geom_sum]

sequence_param:
  | IT_MATH_OPEN; ID; EQ; value = int_with_sign; IT_MATH_CLOSE
      { value }
    [@name sequence_param]

question_text:
  | WHAT_WORD; IS_WORD; THE_WORD; VALUE_WORD; OF_WORD; call = intext_call; QUESTION_MARK
      { Q_Value call }
    [@name qvalue]

  | call = intext_call; IS_WORD; EQUAL_WORD; TO_WORD
      { Q_IsEqual call }
    [@name qis]

answer_item:
  | v = variable
      { A_Var v }
    [@name ans_var]
(*
(* -------------------------------------------------------------------------- *)
(* solution_section & items                                                   *)
(* -------------------------------------------------------------------------- *)
solution_section:
  | BEGIN_PGML_SOLUTION; NEWLINE; slist = solution_list; END_PGML_SOLUTION; NEWLINE
      { Solution slist }
    [@name solution_section]

solution_list:
  | item = solution_item; NEWLINE; NEWLINE; rest = solution_list
      { item :: rest }  [@name slist]

  | item = solution_item; NEWLINE
      { [item] }        [@name slist_single]

solution_item:
  | CORRECT_WORD; ANSWER_WORD; COLON; ans = intext_call; NEWLINE; NEWLINE; text = STRING
      { Sol_Correct (ans, text) }
    [@name sol_item]
*)
(* -------------------------------------------------------------------------- *)
(* inline calls & math expressions                                            *)
(* -------------------------------------------------------------------------- *)
intext_call:
  | IT_VAR_OPEN; v = variable; IT_VAR_CLOSE
      { IC_VarV v }
    [@name ict_varv]

  | IT_MATH_OPEN; expr = math_expr; IT_MATH_CLOSE
      { IC_Math expr }
    [@name ict_math]

math_expr:
  | left = math_expr; op = ADD_OP; t = term
      { ME_Add (left, t) }
    [@name madd]

  | left = math_expr; op = SUB_OP; t = term
      { ME_Sub (left, t) }
    [@name msub]

  | t = term
      { ME_Term t }
    [@name mterm]

term:
  | left = term; op = MUL_OP; f = factor
      { T_Mul (left, f) }
    [@name tmul]

  | left = term; op = DIV_OP; f = factor
      { T_Div (left, f) }
    [@name tdiv]

  (* LaTeX spellings of the same two operators. A question rendered for a
     reader says 3 \cdot 4, not 3 * 4, and both have to be readable. *)
  | left = term; CDOT_LATEX; f = factor
      { T_Mul (left, f) }
    [@name tmul_latex]

  | left = term; DIV_LATEX; f = factor
      { T_Div (left, f) }
    [@name tdiv_latex]

  | f = factor
      { T_Fac f }
    [@name tfac]

factor:
  | LPAREN; e = math_expr; RPAREN
      { F_Paren e }
    [@name fparen]

  | n = NUMBER
      { F_Num n }
    [@name fnum]

  | n = INT
      { F_Int n }
    [@name fint]

  (* A negative literal, mirroring how `value` already handles one. Without
     these, Formula('-5') cannot be parsed, even though the generator emits
     exactly that. F_Num and F_Int already hold signed OCaml numbers, so no
     change to the AST is needed. *)
  | SUB_OP; n = NUMBER
      { F_Num (-.n) }
    [@name fnum_neg]

  | SUB_OP; n = INT
      { F_Int (-n) }
    [@name fint_neg]

(* -------------------------------------------------------------------------- *)
(* Boolean expression evaluation parsing rules                                *)
(* -------------------------------------------------------------------------- *)
bool_assignment_list:
  | assignment = bool_assignment; NEWLINE; rest = bool_assignment_list
      { assignment :: rest }
    [@name bool_assignment_list_cons]

  | assignment = bool_assignment; NEWLINE
      { [assignment] }
    [@name bool_assignment_list_last]

bool_assignment:
  | SUB_OP; name = ID; EQ; TRUE_WORD
      { (name, true) }
    [@name bool_assignment_true]

  | SUB_OP; name = ID; EQ; FALSE_WORD
      { (name, false) }
    [@name bool_assignment_false]

bool_expr:
  | left = bool_expr; AND_WORD; right = bool_expr
      { Bool_And (left, right) }
    [@name bool_and]

  | left = bool_expr; OR_WORD; right = bool_expr
      { Bool_Or (left, right) }
    [@name bool_or]

  | left = bool_expr; XOR_WORD; right = bool_expr
      { Bool_Xor (left, right) }
    [@name bool_xor]

  | left = bool_expr; IMPLIES_WORD; right = bool_expr
      { Bool_Implies (left, right) }
    [@name bool_implies]

  | left = bool_expr; IFF_WORD; right = bool_expr
      { Bool_Iff (left, right) }
    [@name bool_iff]

  | NOT_WORD; expr = bool_expr
      { Bool_Not expr }
    [@name bool_not]

  | LPAREN; expr = bool_expr; RPAREN
      { expr }
    [@name bool_paren]

  | TRUE_WORD
      { Bool_Const true }
    [@name bool_true]

  | FALSE_WORD
      { Bool_Const false }
    [@name bool_false]

  | name = ID
      { Bool_Var name }
    [@name bool_var]

(* -------------------------------------------------------------------------- *)
(* Complex number expression parsing rules                                    *)
(* -------------------------------------------------------------------------- *)
complex_expr:
  | LPAREN; left = complex_expr; RPAREN; ADD_OP; LPAREN; right = complex_expr; RPAREN
      { Complex_Add (left, right) }
    [@name complex_add]

  | LPAREN; left = complex_expr; RPAREN; SUB_OP; LPAREN; right = complex_expr; RPAREN
      { Complex_Sub (left, right) }
    [@name complex_sub]

  | LPAREN; left = complex_expr; RPAREN; MUL_OP; LPAREN; right = complex_expr; RPAREN
      { Complex_Mul (left, right) }
    [@name complex_mul]

  | num = complex_num
      { Complex_Lit num }
    [@name complex_lit]

complex_num:
  | re = int_with_sign; ADD_OP; im = INT; I_UNIT
      { Complex_Num (re, im) }
    [@name complex_num_pos_im]

  | re = int_with_sign; SUB_OP; im = INT; I_UNIT
      { Complex_Num (re, -im) }
    [@name complex_num_neg_im]

  | im = int_with_sign; I_UNIT
      { Complex_Num (0, im) }
    [@name complex_num_imag]

  | re = int_with_sign
      { Complex_Num (re, 0) }
    [@name complex_num_real]

(* -------------------------------------------------------------------------- *)
(* Set-related parsing rules                                                  *)
(* -------------------------------------------------------------------------- *)
set_list:
  | SUB_OP; IT_MATH_OPEN; set_var = ID; EQ; LBRACE_LATEX; expr = set_expr; RBRACE_LATEX; IT_MATH_CLOSE; NEWLINE; rest = set_list
      { Set_List_Cons (set_var, expr, rest) }
    [@name set_list_cons]

  | SUB_OP; IT_MATH_OPEN; set_var = ID; EQ; LBRACE_LATEX; expr = set_expr; RBRACE_LATEX; IT_MATH_CLOSE; NEWLINE
      { Set_List_Last (set_var, expr) }
    [@name set_list_last]

set_expr:
  | enum = set_enum
      { Set_Expr_Enum enum }
    [@name set_expr_enum]

  | interval = set_interval
      { Set_Expr_interval interval }
    [@name set_expr_interval]

set_enum:
  | i = int_with_sign; COMMA; rest = set_enum
      { i :: rest }
    [@name set_enum_cons]

  | i = int_with_sign
      { [i] }
    [@name set_enum_last]

set_interval:
  | X_VAR; PIPE; pred = predicate
      { Set_Interval pred }
    [@name set_interval]

predicate:
  | X_VAR; GT; i = int_with_sign
      { Greater_Than i }
    [@name pred_gt]

  | X_VAR; LT; i = int_with_sign
      { Less_Than i }
    [@name pred_lt]

  | X_VAR; GEQ_LATEX; i = int_with_sign
      { Greater_Equal i }
    [@name pred_geq]

  | X_VAR; LEQ_LATEX; i = int_with_sign
      { Less_Equal i }
    [@name pred_leq]

  | i1 = int_with_sign; LT; X_VAR; LT; i2 = int_with_sign
      { Between_Open (i1, i2) }
    [@name pred_between_open]

  | i1 = int_with_sign; LEQ_LATEX; X_VAR; LT; i2 = int_with_sign
      { Between_Left_Closed (i1, i2) }
    [@name pred_between_left_closed]

  | i1 = int_with_sign; LT; X_VAR; LEQ_LATEX; i2 = int_with_sign
      { Between_Right_Closed (i1, i2) }
    [@name pred_between_right_closed]

  | i1 = int_with_sign; LEQ_LATEX; X_VAR; LEQ_LATEX; i2 = int_with_sign
      { Between_Closed (i1, i2) }
    [@name pred_between_closed]

set_prob_list:
  | SUB_OP; IT_MATH_OPEN; set_op = set_operation; EQ; IT_MATH_CLOSE; BLANK; LBRACE; ans = answer_item; RBRACE; NEWLINE; rest = set_prob_list
      { Set_Prob_List_Cons (set_op, ans, rest) }
    [@name set_prob_list_cons]

  | SUB_OP; IT_MATH_OPEN; set_op = set_operation; EQ; IT_MATH_CLOSE; BLANK; LBRACE; ans = answer_item; RBRACE; NEWLINE
      { Set_Prob_List_Last (set_op, ans) }
    [@name set_prob_list_last]

set_operation:
  | op = set_operation; CUP; term = set_term
      { Set_Op_Union (op, term) }
    [@name set_op_union]

  | term = set_term
      { Set_Op_Term term }
    [@name set_op_term]

set_term:
  | term = set_term; CAP; factor = set_factor
      { Set_Op_Inter (term, factor) }
    [@name set_op_inter]

  | factor = set_factor
      { Set_Op_Factor factor }
    [@name set_op_factor]

set_factor:
  | factor = set_factor; SUB_OP; primary = set_primary
      { Set_Op_Diff (factor, primary) }
    [@name set_op_diff]

  | primary = set_primary
      { Set_Op_Primary primary }
    [@name set_op_primary]

set_primary:
  | var = ID
      { Set_Op_Var var }
    [@name set_primary_var]

  | LPAREN; op = set_operation; RPAREN
      { Set_Op_Paren op }
    [@name set_primary_paren]

set_compute:
  | compute = set_compute; UNION; term = set_compute_term
      { Set_Compute_Union (compute, term) }
    [@name set_compute_union]

  | term = set_compute_term
      { Set_Compute_Term term }
    [@name set_compute_term]

set_compute_term:
  | term = set_compute_term; SUB_OP; factor = set_compute_factor
      { Set_Compute_Diff (term, factor) }
    [@name set_compute_diff]

  | factor = set_compute_factor
      { Set_Compute_Factor factor }
    [@name set_compute_factor]

set_compute_factor:
  | LPAREN; compute = set_compute; RPAREN
      { Set_Compute_Paren compute }
    [@name set_compute_paren]

  | LBRACE; enum = set_enum; RBRACE
      { Set_Compute_Enum enum }
    [@name set_compute_enum]

  | interval = set_compute_interval
      { Set_Compute_Interval interval }
    [@name set_compute_interval]

set_compute_interval:
  | LPAREN; left = interval_value; COMMA; right = interval_value; RPAREN
      { LNEQ_RNEQ (left, right) }
    [@name set_compute_interval_open]

  | LPAREN; left = interval_value; COMMA; right = interval_value; RBRACKET
      { LNEQ_REQ (left, right) }
    [@name set_compute_interval_left_open]

  | LBRACKET; left = interval_value; COMMA; right = interval_value; RPAREN
      { LEQ_RNEQ (left, right) }
    [@name set_compute_interval_right_open]

  | LBRACKET; left = interval_value; COMMA; right = interval_value; RBRACKET
      { LEQ_REQ (left, right) }
    [@name set_compute_interval_closed]

interval_value:
  | i = int_with_sign
      { I_Int i }
    [@name interval_int]

  | INFINITY
      { I_Infinity }
    [@name interval_infinity]

  | NEG_INFINITY
      { I_NegInfinity }
    [@name interval_neg_infinity]

(* -------------------------------------------------------------------------- *)
(* Vector-related parsing rules                                               *)
(* -------------------------------------------------------------------------- *)
vector_list:
  | SUB_OP; IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; EQ; LANGLE_LATEX; expr = set_enum; RANGLE_LATEX; IT_MATH_CLOSE; NEWLINE; rest = vector_list
      { Vector_List_Cons (vec_var, expr, rest) }
    [@name vec_list_cons]

  | SUB_OP; IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; EQ; LANGLE_LATEX; expr = set_enum; RANGLE_LATEX; IT_MATH_CLOSE; NEWLINE
      { Vector_List_Last (vec_var, expr) }
    [@name vec_list_last]

vector_prob_list:
  | SUB_OP; vec_prob = vector_prob; NEWLINE; rest = vector_prob_list
      { Vector_Prob_List_Cons (vec_prob, rest) }
    [@name vec_prob_list_cons]

  | SUB_OP; vec_prob = vector_prob; NEWLINE
      { Vector_Prob_List_Last (vec_prob) }
    [@name vec_prob_list_last]

vector_prob:
  | IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var_1 = ID; RBRACE; CDOT_LATEX; VEC_LATEX; LBRACE; vec_var_2 = ID; RBRACE; EQ; IT_MATH_CLOSE; BLANK; LBRACE; VECTOR_VALUE_OPEN; vec_enum_1 = set_enum; RPAREN; PERIOD; VECTOR_VALUE_OPEN; vec_enum_2 = set_enum; RPAREN; RBRACE
      { Dot_Product (vec_var_1, vec_var_2, vec_enum_1, vec_enum_2) }
    [@name vec_prob_1_typed]

  | IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var_1 = ID; RBRACE; TIMES_LATEX; VEC_LATEX; LBRACE; vec_var_2 = ID; RBRACE; EQ; IT_MATH_CLOSE; BLANK; LBRACE; VECTOR_VALUE_OPEN; vec_enum_1 = set_enum; RPAREN; X_VAR; VECTOR_VALUE_OPEN; vec_enum_2 = set_enum; RPAREN; RBRACE
      { Cross_Product (vec_var_1, vec_var_2, vec_enum_1, vec_enum_2) }
    [@name vec_prob_2_typed]

  | IT_MATH_OPEN; LEFT_NORM_LATEX; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; RIGHT_NORM_LATEX; EQ; IT_MATH_CLOSE; BLANK; LBRACE; VECTOR_VALUE_OPEN; vec_enum = set_enum; RPAREN; ARROW; NORM_METH; LPAREN; RPAREN; RBRACE
      { Vector_Norm (vec_var, vec_enum) }
    [@name vec_prob_3_typed]

  | VECTOR_UNIT_PROB; IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; IT_MATH_CLOSE; PERIOD; BLANK; LBRACE; VECTOR_VALUE_OPEN; vec_enum = set_enum; RPAREN; ARROW; UNIT_METH; LPAREN; RPAREN; RBRACE
      { Unit_Vector (vec_var, vec_enum) }
    [@name vec_prob_4_typed]

  | VECTOR_PARA_PROB; IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; IT_MATH_CLOSE; PERIOD; BLANK; LBRACE; VECTOR_VALUE_OPEN; vec_enum = set_enum; RPAREN; ARROW; CMP_1; RBRACE
      { Parallel_Vectors (vec_var, vec_enum) }
    [@name vec_prob_5_typed]

  | VECTOR_SAME_PROB; IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; IT_MATH_CLOSE; PERIOD; BLANK; LBRACE; VECTOR_VALUE_OPEN; vec_enum = set_enum; RPAREN; ARROW; CMP_2; RBRACE
      { Same_Dir_Vectors (vec_var, vec_enum) }
    [@name vec_prob_6_typed]

  | IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var_1 = ID; RBRACE; CDOT_LATEX; VEC_LATEX; LBRACE; vec_var_2 = ID; RBRACE; EQ; IT_MATH_CLOSE; BLANK; LBRACE; COMPUTE_METH; LPAREN; DOUBLE_QUOTE; LT; vec_enum_1 = set_enum; GT; DOUBLE_QUOTE; RPAREN; PERIOD; COMPUTE_METH; LPAREN; DOUBLE_QUOTE; LT; vec_enum_2 = set_enum; GT; DOUBLE_QUOTE; RPAREN; RBRACE
      { Dot_Product (vec_var_1, vec_var_2, vec_enum_1, vec_enum_2) }
    [@name vec_prob_1]

  | IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var_1 = ID; RBRACE; TIMES_LATEX; VEC_LATEX; LBRACE; vec_var_2 = ID; RBRACE; EQ; IT_MATH_CLOSE; BLANK; LBRACE; COMPUTE_METH; LPAREN; DOUBLE_QUOTE; LT; vec_enum_1 = set_enum; GT; DOUBLE_QUOTE; RPAREN; X_VAR; COMPUTE_METH; LPAREN; DOUBLE_QUOTE; LT; vec_enum_2 = set_enum; GT; DOUBLE_QUOTE; RPAREN; RBRACE
      { Cross_Product (vec_var_1, vec_var_2, vec_enum_1, vec_enum_2) }
    [@name vec_prob_2]

  | IT_MATH_OPEN; LEFT_NORM_LATEX; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; RIGHT_NORM_LATEX; EQ; IT_MATH_CLOSE; BLANK; LBRACE; NORM_METH; LPAREN; COMPUTE_METH; LPAREN; DOUBLE_QUOTE; LT; vec_enum = set_enum; GT; DOUBLE_QUOTE; RPAREN; RPAREN; RBRACE
      { Vector_Norm (vec_var, vec_enum) }
    [@name vec_prob_3]

  | VECTOR_UNIT_PROB; IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; IT_MATH_CLOSE; PERIOD; BLANK; LBRACE; UNIT_METH; LPAREN; COMPUTE_METH; LPAREN; DOUBLE_QUOTE; LT; vec_enum = set_enum; GT; DOUBLE_QUOTE; RPAREN; RPAREN; RBRACE
      { Unit_Vector (vec_var, vec_enum) }
    [@name vec_prob_4]

  | VECTOR_PARA_PROB; IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; IT_MATH_CLOSE; PERIOD; BLANK; LBRACE; COMPUTE_METH; LPAREN; DOUBLE_QUOTE; LT; vec_enum = set_enum; GT; DOUBLE_QUOTE; RPAREN; ARROW; CMP_1; RBRACE
      { Parallel_Vectors (vec_var, vec_enum) }
    [@name vec_prob_5]

  | VECTOR_SAME_PROB; IT_MATH_OPEN; VEC_LATEX; LBRACE; vec_var = ID; RBRACE; IT_MATH_CLOSE; PERIOD; BLANK; LBRACE; COMPUTE_METH; LPAREN; DOUBLE_QUOTE; LT; vec_enum = set_enum; GT; DOUBLE_QUOTE; RPAREN; ARROW; CMP_2; RBRACE
      { Same_Dir_Vectors (vec_var, vec_enum) }
    [@name vec_prob_6]

(* ------------------- NEW CODE START ------------------- *)
(* -------------------------------------------------------------------------- *)
(* Function_Expr-related parsing rules                                        *)
(* -------------------------------------------------------------------------- *)
function_expr:
  | func = linear_function
      { Linear_Fun func }
    [@name linear_fun]

  | func = quadratic_function
      { Quadratic_Fun func }
    [@name quadratic_fun]

  | func = power_function
      { Power_Fun func }
    [@name power_fun]

  | func = radical_function
      { Radical_Fun func }
    [@name radical_fun]

  | func = rational_function
      { Rational_Fun func }
    [@name rational_fun]

  | func = log_function
      { Log_Fun func }
    [@name log_fun]

  | func = trig_function
      { Trig_Fun func }
    [@name trig_fun]

  | func = exp_function
      { Exp_Fun func }
    [@name exp_fun]

linear_function:
  | f_or_v = fun_or_var; ADD_OP; i = INT
      { Fun_Add_Int (f_or_v, i) }
    [@name fun_add_int]

  | f_or_v = fun_or_var; SUB_OP; i = INT
      { Fun_Sub_Int (f_or_v, i) }
    [@name fun_sub_int]

  | i = INT; SUB_OP; f_or_v = fun_or_var
      { Int_Sub_Fun (i, f_or_v) }
    [@name int_sub_fun]

  | i = INT; MUL_OP; f_or_v = fun_or_var
      { Int_Mul_Fun (i, f_or_v) }
    [@name int_mul_fun]

  | f_or_v = fun_or_var; MUL_OP; i = INT
      { Fun_Mul_Int (f_or_v, i) }
    [@name fun_mul_int]

quadratic_function:
  | f_or_v1 = fun_or_var; POWER_OP; i0 = INT; ADD_OP;
    i1 = INT; MUL_OP; f_or_v2 = fun_or_var; ADD_OP; i2 = INT
      { Quad_Add (f_or_v1, i1, f_or_v2, i2) }
    [@name quad_add]

  | f_or_v1 = fun_or_var; POWER_OP; i0 = INT; SUB_OP;
    i1 = INT; MUL_OP; f_or_v2 = fun_or_var; ADD_OP; i2 = INT
      { Quad_Sub (f_or_v1, i1, f_or_v2, i2) }
    [@name quad_sub]

  | LPAREN; f_or_v = fun_or_var; RPAREN; POWER_OP; i0 = INT
      { Quad_Square f_or_v }
    [@name quad_square]

power_function:
  | f_or_v = fun_or_var; POWER_OP; i = INT
      { Power_Fun_Int (f_or_v, i) }
    [@name power_fun_int_expr]

radical_function:
  | SQRT_OP; LPAREN; f_or_v = fun_or_var; RPAREN
      { Radi_Sqrt f_or_v }
    [@name radi_sqrt]

  | LPAREN; f_or_v = fun_or_var; RPAREN; POWER_OP; LPAREN;
    i0 = INT; DIV_OP; i = INT; RPAREN
      { Radi_Root (f_or_v, i) }
    [@name radi_root]

rational_function:
  | f_or_v = fun_or_var; DIV_OP; i = INT
      { Fun_Div_Int (f_or_v, i) }
    [@name fun_div_int]

  | i = INT; DIV_OP; LPAREN; f_or_v = fun_or_var; RPAREN
      { Int_Div_Fun (i, f_or_v) }
    [@name int_div_fun]

log_function:
  | LN_OP; LPAREN; f_or_v = fun_or_var; RPAREN
      { Ln_Fun f_or_v }
    [@name ln_fun]

trig_function:
  | SIN_OP; LPAREN; f_or_v = fun_or_var; RPAREN
      { Trig_Sin f_or_v }
    [@name trig_sin]

  | COS_OP; LPAREN; f_or_v = fun_or_var; RPAREN
      { Trig_Cos f_or_v }
    [@name trig_cos]

exp_function:
  | NAT_LOG; POWER_OP; LPAREN; f_or_v = fun_or_var; RPAREN
      { Exp f_or_v }
    [@name exp]

fun_or_var:
  | X_VAR
      { Var_X }
    [@name var_x]

  | LPAREN; func = function_expr; RPAREN
      { Func func }
    [@name func]

derivative_prob_list:
  | SUB_OP; der_prob = derivative_prob; NEWLINE; rest = derivative_prob_list
      { Derivative_Prob_List_Cons (der_prob, rest) }
    [@name der_prob_list_cons]

  | SUB_OP; der_prob = derivative_prob; NEWLINE
      { Derivative_Prob_List_Last (der_prob) }
    [@name der_prob_list_last]

derivative_prob:
  | IT_MATH_OPEN; F_FUN; SINGLE_QUOTE; LPAREN; X_VAR; RPAREN; EQ; IT_MATH_CLOSE; BLANK; LBRACE; NAMING; fun_name = ID; ARROW; D_METH; LPAREN; RPAREN; RBRACE
      { First_Derivative fun_name }
    [@name der_prob_1]

  | IT_MATH_OPEN; F_FUN; SINGLE_QUOTE; LPAREN; i1 = INT; RPAREN; EQ; IT_MATH_CLOSE; BLANK; LBRACE; NAMING; fun_name = ID; ARROW; D_METH; LPAREN; RPAREN; ARROW; EVAL_METH; LPAREN; X_VAR; FAT_COMMA; i2 = INT; RPAREN; RBRACE
      { Derivative_Algebra (i1, fun_name, i2) }
    [@name der_prob_2]

  | IT_MATH_OPEN; F_FUN; SINGLE_QUOTE; SINGLE_QUOTE; LPAREN; X_VAR; RPAREN; EQ; IT_MATH_CLOSE; BLANK; LBRACE; NAMING; fun_name = ID; ARROW; D_METH; LPAREN; RPAREN; ARROW; D_METH; LPAREN; RPAREN; RBRACE
      { Second_Derivative fun_name }
    [@name der_prob_3]

  | INDEFINITE_INTEGRAL_PROB; BLANK; LBRACE; NAMING; anti_name = ID; RBRACE
      { Indefinite_Integral anti_name }
    [@name integral_prob]

(* ------------------- NEW CODE END ------------------- *)

(* Auxiliary rule: Handling integers with signs *)
int_with_sign:
  | SUB_OP n = INT
      { -n }  (* Return neg *)
    [@name negative_int]

  | n = INT
      { n }   (* Return pos *)
    [@name positive_int]
