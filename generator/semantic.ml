(* semantic.ml: semantic analysis for PGML AST *)
open Ast

exception Semantic_error of string

(* Allowed context names *)
let allowed_contexts = [
  "Numeric"; "Complex"; "Point"; "Vector"; "Vector2D";
  "Matrix"; "Interval"; "Complex-Point"; "Complex-Vector";
  "Complex-Matrix"; "Full"
]

(* Allowed macro files *)
let allowed_macros = ["PGcourse.pl"; "parserRadioButtons.pl"]

let check_answer_item = function
  | Ast.A_Var var -> ()  (* Basic check - we assume variables are valid *)

(* Convert AST constructors to strings for error messages *)
let string_of_module = function
  | Variables -> "variables"
  | Constants -> "constants"
  | Strings   -> "strings"
  | Operators -> "operators"
  | Flags     -> "flags"

let string_of_context_method = function
  | CM_Add _      -> "add"
  | CM_Set _      -> "set"
  | CM_Are _      -> "are"
  | CM_Undefine _ -> "undefine"
  | CM_Redefine _ -> "redefine"

let string_of_value = function
  | VInt i   -> string_of_int i
  | VNum f   -> string_of_float f
  | VStr s   -> s
  | VIdent s -> s

(* Forward declarations for math_expr semantic checks *)
let rec check_math_expr : Ast.math_expr -> unit = function
  | Ast.ME_Add (lhs, term) ->
      check_math_expr lhs;
      check_term term
  | Ast.ME_Sub (lhs, term) ->
      check_math_expr lhs;
      check_term term
  | Ast.ME_Term term ->
      check_term term

and check_term : Ast.term -> unit = function
  | Ast.T_Mul (t, f) ->
      check_term t;
      check_factor f
  | Ast.T_Div (t, f) ->
      check_term t;
      check_factor f;
      (* prevent literal zero division *)
      (match f with
       | Ast.F_Num 0.0 | Ast.F_Int 0 ->
           raise (Semantic_error "Division by zero literal in formula")
       | _ -> ())
  | Ast.T_Fac f -> check_factor f

and check_factor : Ast.factor -> unit = function
  | Ast.F_Paren expr -> check_math_expr expr
  | Ast.F_Num _ | Ast.F_Int _ -> ()

(* Forward declarations for function_expr semantic checks *)
and check_function_expr : Ast.function_expr -> unit = function
  | Ast.Linear_Fun func -> 
      check_linear_function func
  | Ast.Quadratic_Fun func -> 
      check_quadratic_function func
  | Ast.Power_Fun func -> 
      check_power_function func
  | Ast.Radical_Fun func -> 
      check_radical_function func
  | Ast.Rational_Fun func -> 
      check_rational_function func
  | Ast.Log_Fun func -> 
      check_log_function func
  | Ast.Trig_Fun func -> 
      check_trig_function func
  | Ast.Exp_Fun func -> 
      check_exp_function func

and check_linear_function = function
  | Ast.Fun_Add_Int (f_or_v, i)
  | Ast.Fun_Sub_Int (f_or_v, i)
  | Ast.Fun_Mul_Int (f_or_v, i) ->
      check_fun_or_var f_or_v
  | Ast.Int_Sub_Fun (i, f_or_v)
  | Ast.Int_Mul_Fun (i, f_or_v) ->
      check_fun_or_var f_or_v

and check_quadratic_function = function
  | Ast.Quad_Add (f_or_v1, i1, f_or_v2, i2)
  | Ast.Quad_Sub (f_or_v1, i1, f_or_v2, i2) ->
      check_fun_or_var f_or_v1;
      check_fun_or_var f_or_v2
  | Ast.Quad_Square f_or_v ->
      check_fun_or_var f_or_v

and check_power_function = function
  | Ast.Power_Fun_Int (f_or_v, i) ->
      check_fun_or_var f_or_v;
      if i <= 1 then
        raise (Semantic_error "Exponential function: for f(x)=a^x, it must be a>1.")

and check_radical_function = function
  | Ast.Radi_Sqrt f_or_v ->
      check_fun_or_var f_or_v
      (* Need to check the value inside square root: it should be non-negative *)
  | Ast.Radi_Root (f_or_v, i) ->
      check_fun_or_var f_or_v;
      if i <= 1 then
        raise (Semantic_error "Radical Function: Root index must be greater than 1 for safety.")

and check_rational_function = function
  | Ast.Fun_Div_Int (f_or_v, i) ->
      check_fun_or_var f_or_v;
      if i = 0 then
        raise (Semantic_error "Rational Function: Division by zero in rational function.")
  | Ast.Int_Div_Fun (i, f_or_v) ->
      check_fun_or_var f_or_v;
      (* Need to check the denominator: it should not be zero *)

and check_log_function = function
  | Ast.Ln_Fun f_or_v ->
      check_fun_or_var f_or_v
      (* Need to check the value inside log: it should be greater than 0 *)

and check_trig_function = function
  | Ast.Trig_Sin f_or_v
  | Ast.Trig_Cos f_or_v ->
      check_fun_or_var f_or_v

and check_exp_function = function
  | Ast.Exp f_or_v ->
      check_fun_or_var f_or_v

and check_fun_or_var = function
  | Ast.Func func -> check_function_expr func
  | Ast.Var_X -> () 

(* Convert math_object_method to string for variable printing *)
let string_of_math_object_method = function
  | M_Random (low, high, step) -> Printf.sprintf "random(%d,%d,%d)" low high step
  | M_Formula expr             -> check_math_expr expr; "<formula>"
  | M_Formula_Fun expr         -> check_function_expr expr; "<formula_fun>"
  | M_Real v                   -> string_of_value v
  | M_D s                      -> begin match s with
                                    | Some s -> s
                                    | None -> "" end
  | M_Eval _                   -> "<eval>"
  | M_With _                   -> "<with>"
  | M_Set enum                 -> Printf.sprintf "Set(%s)" (String.concat "," (List.map string_of_int enum))
  | M_Compute comp             -> "<compute>"
  | M_intersect var            -> Printf.sprintf "intersect(%s)" "<variable>"

(* Convert variable to string, handling all cases *)
let string_of_variable = function
  | Var_Value v          -> string_of_value v
  | Var_Method m         -> string_of_math_object_method m
  | Var_Field (name, m)  -> name ^ "->" ^ string_of_math_object_method m
  | Var_Chain (m1, m2)   ->
      string_of_math_object_method m1 ^ "->" ^ string_of_math_object_method m2

(* Check that context name is valid *)
let check_context_name name =
  if not (List.mem name allowed_contexts) then
    raise (Semantic_error ("Invalid context name: " ^ name))

(* Check loaded macros are in the allowed list *)
let rec collect_macros = function
  | Macro_Atom s     -> [s]
  | Macro_Cons (s,m) -> s :: collect_macros m

let check_macro_option = function
  | None -> ()
  | Some m ->
      let names = collect_macros m in
      List.iter (fun s ->
        if not (List.mem s allowed_macros) then
          raise (Semantic_error ("Invalid macro file: " ^ s))
      ) names

(* Check module-method combinations according to semantics rules *)
let check_module_method m meth =
  match m, meth with
  | Variables, CM_Are _ -> ()
  | Constants, CM_Add _ -> ()
  | Strings,   CM_Add _ -> ()
  | Operators, (CM_Undefine _ | CM_Redefine _) -> ()
  | Flags, (CM_Set _) -> ()
  | _ ->
      let m_str = string_of_module m in
      let meth_str = string_of_context_method meth in
      raise (Semantic_error
        (Printf.sprintf
          "Context method '%s' is not allowed in module '%s'" meth_str m_str))

(* Traverse context configuration list *)
let rec check_context_config = function
  | Cfg_Last (m, meth) -> check_module_method m meth
  | Cfg_Cons (m, meth, rest) ->
      check_module_method m meth;
      check_context_config rest

(* Check the context setup section *)
let check_context_setup = function
  | Context_Only name ->
      check_context_name name
  | Context_With_Config (name, cfg) ->
      check_context_name name;
      check_context_config cfg

(* Evaluate a math_expr to a float *)
let rec eval_math_expr = function
  | Ast.ME_Add (lhs, t) -> eval_math_expr lhs +. eval_term t
  | Ast.ME_Sub (lhs, t) -> eval_math_expr lhs -. eval_term t
  | Ast.ME_Term t       -> eval_term t

and eval_term = function
  | Ast.T_Mul (t, f) -> eval_term t *. eval_factor f
  | Ast.T_Div (t, f) -> 
      let dv = eval_factor f in
      if dv = 0. then raise (Semantic_error "Division by zero in evaluation");
      eval_term t /. dv
  | Ast.T_Fac f      -> eval_factor f

and eval_factor = function
  | Ast.F_Paren e -> eval_math_expr e
  | Ast.F_Num n   -> n
  | Ast.F_Int i   -> float_of_int i

let value_of_float f =
  VNum f

let float_of_value = function
  | VInt i -> float_of_int i
  | VNum f -> f
  | _ -> raise (Semantic_error "Cannot convert strings or variables to float")

let float_of_variable = function
  | Var_Value (VInt i)      -> float_of_int i
  | Var_Value (VNum f)      -> f
  | Var_Method (M_Real v)   -> float_of_value v
  | Var_Method (M_Formula e) -> eval_math_expr e  (* if you allow formulas as answers *)
  | Var_Method (M_Set _)    -> raise (Semantic_error "Cannot convert set to float")
  | Var_Method (M_Compute _) -> raise (Semantic_error "Cannot convert set computation to float")
  | Var_Method (M_intersect _) -> raise (Semantic_error "Cannot convert set intersection to float")
  | _ ->
      raise (Semantic_error
        "Cannot compare non-numeric in-text call / answer")

(* Check set-related expressions *)
let rec check_set_operation = function
  | Ast.Set_Op_Union (op, term) ->
      check_set_operation op;
      check_set_term term
  | Ast.Set_Op_Term term -> check_set_term term

and check_set_term = function
  | Ast.Set_Op_Inter (term, factor) ->
      check_set_term term;
      check_set_factor factor
  | Ast.Set_Op_Factor factor -> check_set_factor factor

and check_set_factor = function
  | Ast.Set_Op_Diff (factor, primary) ->
      check_set_factor factor;
      check_set_primary primary
  | Ast.Set_Op_Primary primary -> check_set_primary primary

and check_set_primary = function
  | Ast.Set_Op_Paren op -> check_set_operation op
  | Ast.Set_Op_Var var -> ()  (* Assume variable is defined elsewhere *)

(* Check set computation expressions *)
let rec check_set_compute = function
  | Ast.Set_Compute_Union (comp, term) ->
      check_set_compute comp;
      check_set_compute_term term
  | Ast.Set_Compute_Term term -> check_set_compute_term term

and check_set_compute_term = function
  | Ast.Set_Compute_Diff (term, factor) ->
      check_set_compute_term term;
      check_set_compute_factor factor
  | Ast.Set_Compute_Factor factor -> check_set_compute_factor factor

and check_set_compute_factor = function
  | Ast.Set_Compute_Paren comp -> check_set_compute comp
  | Ast.Set_Compute_Enum _ -> ()  (* Enum is just a list of integers *)
  | Ast.Set_Compute_Interval interval -> check_set_compute_interval interval

and check_set_compute_interval = function
  | Ast.LNEQ_RNEQ (left, right)
  | Ast.LNEQ_REQ (left, right)
  | Ast.LEQ_RNEQ (left, right)
  | Ast.LEQ_REQ (left, right) ->
      check_interval_value left;
      check_interval_value right

and check_interval_value = function
  | Ast.I_Int _ -> ()
  | Ast.I_Infinity -> ()
  | Ast.I_NegInfinity -> ()

(* Check set definitions in "Given the sets" section *)
let rec check_set_list = function
  | Ast.Set_List_Cons (var, expr, rest) ->
      check_set_expr expr;
      check_set_list rest
  | Ast.Set_List_Last (var, expr) -> check_set_expr expr

and check_set_expr = function
  | Ast.Set_Expr_Enum enum -> ()  (* Enum is just a list of integers *)
  | Ast.Set_Expr_interval interval -> check_set_interval interval

and check_set_interval = function
  | Ast.Set_Interval pred -> check_predicate pred

and check_predicate = function
  | Ast.Greater_Than i
  | Ast.Less_Than i
  | Ast.Greater_Equal i
  | Ast.Less_Equal i -> ()
  | Ast.Between_Open (i1, i2)
  | Ast.Between_Left_Closed (i1, i2)
  | Ast.Between_Right_Closed (i1, i2)
  | Ast.Between_Closed (i1, i2) ->
      if i1 >= i2 then
        raise (Semantic_error (Printf.sprintf "Invalid interval: %d is not less than %d" i1 i2))

(* Check set problems in "Compute" section *)
let rec check_set_prob_list = function
  | Ast.Set_Prob_List_Cons (op, ans, rest) ->
      check_set_operation op;
      check_answer_item ans;
      check_set_prob_list rest
  | Ast.Set_Prob_List_Last (op, ans) ->
      check_set_operation op;
      check_answer_item ans

(* Check that the math object method is valid *)
let check_math_object_method = function
  | M_Random (low, high, step) ->
      if low >= high then
        raise (Semantic_error "Random range: low must be less than high")
      else if step <= 0 then
        raise (Semantic_error "Random step must be positive")
  | M_Formula expr ->
      check_math_expr expr
  | M_Formula_Fun expr ->
      check_function_expr expr
  | M_Real f -> () 
  | M_D s -> ()
  | M_Eval prop -> ()
  | M_With prop -> ()
  | M_Set enum -> ()
  | M_Compute comp ->
      check_set_compute comp
  | M_intersect var -> ()

(* Check that the variable list is valid *)
let check_variable_list varlist =
  let seen_names = Hashtbl.create 10 in
  List.iter (fun (name, var) ->
    (* variable name must be unique *)
    if Hashtbl.mem seen_names name then
      raise (Semantic_error (Printf.sprintf "Duplicate variable declaration: $%s" name))
    else
      Hashtbl.add seen_names name true;
    
    match var with
    | Var_Value v -> ()
    | Var_Method meth -> check_math_object_method meth
    | Var_Field (field_name, meth) -> 
        check_math_object_method meth
    | Var_Chain (meth1, meth2) ->
        check_math_object_method meth1;
        check_math_object_method meth2
  ) varlist

(* Check a list of context setups *)
let rec check_context_setup_list = function
  | Context_Setup_Vars_Last (cfg, ans_vars) -> 
    check_context_setup cfg;
    check_variable_list ans_vars
  | Context_Setup_Vars_Cons (cfg, ans_vars, rest) ->
      check_context_setup cfg;
      check_variable_list ans_vars;
      check_context_setup_list rest
  | Context_Setup_No_Vars_Last cfg -> check_context_setup cfg
  | Context_Setup_No_Vars_Cons (cfg, rest) ->
      check_context_setup cfg;
      check_context_setup_list rest

(* Check consistency between intext_call and answer_item *)
let check_question_item = function
  | Q_Item (q_text, answer, _) ->
      let var_of_icall = function
        | IC_VarV v -> Var_Value (value_of_float (float_of_variable v))
        | IC_Math expr -> (* first run the structural checks: *)
                          check_math_expr expr;
                          (* then evaluate and wrap into a variable: *)
                          let f = eval_math_expr expr in
                          Var_Value (value_of_float f)
      in
      let v1 = match q_text with
        | Q_Value ic | Q_IsEqual ic -> var_of_icall ic
      in
      (match answer with
      | A_Var v2 -> let f1 = float_of_variable v1 in
                    let f2 = float_of_variable v2 in 
                    if f1 = f2 then ()
                    else
                      let s1 = string_of_variable v1 in
                      let s2 = string_of_variable v2 in
                      raise (Semantic_error
                        (Printf.sprintf
                          "Mismatch: intext call '%s' does not match answer '%s'" s1 s2))
      )
  | Q_Given_Set _ -> ()  (* Skip numeric comparison for set problems *)
  | Q_Suppose_Vector _ -> ()  (* Skip numeric comparison for vector problems *)
  | Q_Given_Function _ -> ()  (* Skip numeric comparison for derivative problems *)

(* Entry point for semantic checking of the problem section *)
let check_problem_section = function
  | Problem qlist -> List.iter check_question_item qlist

(* Main entry point: validate an entire document *)
let validate = function
  | Doc_No_Sol (LoadMacros opt, ctx_setup, prob_sec) ->
      (* Header *)
      check_macro_option opt;
      (* Context setup *)
      check_context_setup_list ctx_setup;
      (* Problem section *)
      check_problem_section prob_sec

(* TODO: handle variable_declaration nodes when available *)
