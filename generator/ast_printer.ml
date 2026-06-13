(* ast_printer.ml *)

open Format

(* Helper to print OCaml‐style lists *)
let pp_list pp fmt lst =
  fprintf fmt "[";
  let rec aux = function
    | []    -> ()
    | [x]   -> pp fmt x
    | x::xs ->
        fprintf fmt "%a;@ " pp x;
        aux xs
  in
  aux lst;
  fprintf fmt "]"

let pp_int fmt i = fprintf fmt "%d" i

let rec pp_document fmt = function
  | Ast.Doc_No_Sol (hdr, ctx, prob) ->
      fprintf fmt "Doc_No_Sol(%a,@ %a,@ %a)"
        pp_header hdr
        pp_context_setup_list ctx
        pp_problem_section prob

and pp_header fmt = function
  | Ast.LoadMacros mopt ->
      fprintf fmt "LoadMacros(%a)" pp_macro_option mopt

and pp_macro_option fmt = function
  | None   -> fprintf fmt "None"
  | Some m -> fprintf fmt "Some(%a)" pp_macro m

and pp_macro fmt = function
  | Ast.Macro_Atom s       -> fprintf fmt "Macro_Atom(%S)" s
  | Ast.Macro_Cons (s, m2) -> fprintf fmt "Macro_Cons(%S,@ %a)" s pp_macro m2

and pp_context_setup_list fmt = function
  | Ast.Context_Setup_Vars_Last (ctx_setup, ans_vars) ->
      fprintf fmt "Context_Setup_Vars_Last(%a,@ %a)" pp_context_setup ctx_setup pp_answer_vars ans_vars
  | Ast.Context_Setup_Vars_Cons (ctx_setup, ans_vars, rest) ->
      fprintf fmt "Context_Setup_Vars_Cons(%a,@ %a,@ %a)" pp_context_setup ctx_setup pp_answer_vars ans_vars pp_context_setup_list rest
  | Ast.Context_Setup_No_Vars_Cons (ctx_setup, rest) ->
      fprintf fmt "Context_Setup_No_Vars_Cons(%a,@ %a)" pp_context_setup ctx_setup pp_context_setup_list rest
  | Ast.Context_Setup_No_Vars_Last ctx_setup ->
      fprintf fmt "Context_Setup_No_Vars_Last(%a)" pp_context_setup ctx_setup

and pp_context_setup fmt = function
  | Ast.Context_Only s ->
      fprintf fmt "Context_Only(%S)" s
  | Ast.Context_With_Config (s, cfg) ->
      fprintf fmt "Context_With_Config(%S,@ %a)" s pp_context_config cfg

and pp_context_config fmt = function
  | Ast.Cfg_Last (m, cm) ->
      fprintf fmt "Cfg_Last(%a,@ %a)" pp_module_ m pp_context_method cm
  | Ast.Cfg_Cons (m, cm, rest) ->
      fprintf fmt "Cfg_Cons(%a,@ %a,@ %a)"
        pp_module_ m
        pp_context_method cm
        pp_context_config rest

and pp_module_ fmt = function
  | Ast.Variables -> fprintf fmt "Variables"
  | Ast.Constants -> fprintf fmt "Constants"
  | Ast.Strings   -> fprintf fmt "Strings"
  | Ast.Operators -> fprintf fmt "Operators"
  | Ast.Flags     -> fprintf fmt "flags"

and pp_context_method fmt = function
  | Ast.CM_Add      es   -> fprintf fmt "CM_Add(%a)"      pp_entry_list es
  | Ast.CM_Set      es   -> fprintf fmt "CM_Set(%a)"      pp_entry_list es
  | Ast.CM_Are      es   -> fprintf fmt "CM_Are(%a)"      pp_entry_list es
  | Ast.CM_Undefine ops -> fprintf fmt "CM_Undefine(%a)" pp_operator_list ops
  | Ast.CM_Redefine ops -> fprintf fmt "CM_Redefine(%a)" pp_operator_list ops

and pp_string_opt fmt = function
  | None   -> fprintf fmt "None"
  | Some s -> fprintf fmt "Some(%S)" s

and pp_entry_list fmt = pp_list pp_entry fmt

and pp_entry fmt = function
  | Ast.Entry_Property p -> fprintf fmt "Entry_Property(%a)" pp_property p
  | Ast.Entry_Map (k, ps) -> fprintf fmt "Entry_Map(%a,@ %a)" pp_key k pp_properties_opt ps

and pp_property fmt (Ast.Property (k, v)) =
  fprintf fmt "Property(%a,@ %a)" pp_key k pp_value v

and pp_properties_opt fmt = function
  | None -> fprintf fmt "None"
  | Some props ->
      Format.fprintf fmt "Some [%a]" pp_properties props

and pp_properties fmt = pp_list pp_property fmt

and pp_key fmt = function
  | Ast.Ident s -> fprintf fmt "Ident(%S)" s
  | Ast.Str   s -> fprintf fmt "Str(%S)"   s

and pp_value fmt = function
  | Ast.VInt   i -> fprintf fmt "VInt(%d)"   i
  | Ast.VNum   f -> fprintf fmt "VNum(%f)"   f
  | Ast.VStr   s -> fprintf fmt "VStr(%S)"   s
  | Ast.VIdent s -> fprintf fmt "VIdent(%S)" s

and pp_operator_list fmt = pp_list pp_operator fmt

and pp_operator fmt = function
  | Ast.Add_Op -> fprintf fmt "Add_Op"
  | Ast.Sub_Op -> fprintf fmt "Sub_Op"
  | Ast.Mul_Op -> fprintf fmt "Mul_Op"
  | Ast.Div_Op -> fprintf fmt "Div_Op"

and pp_answer_vars fmt vl = 
  fprintf fmt "AnswerVars(%a)" pp_variable_list vl

and pp_variable_list fmt vl = 
  pp_list pp_variable_declaration fmt vl

and pp_variable_declaration fmt (id, var) =
  fprintf fmt "VarDecl(%S,@ %a)" id pp_variable var

and pp_variable fmt = function
  | Ast.Var_Value v       -> fprintf fmt "Var_Value(%a)"      pp_value v
  | Ast.Var_Method m      -> fprintf fmt "Var_Method(%a)"     pp_math_object_method m
  | Ast.Var_Field (s, m)  -> fprintf fmt "Var_Field(%S,@ %a)" s pp_math_object_method m
  | Ast.Var_Chain (m1,m2) -> fprintf fmt "Var_Chain(%a,@ %a)"  pp_math_object_method m1 pp_math_object_method m2

and pp_math_object_method fmt = function
  | Ast.M_Random (a,b,c)    -> fprintf fmt "M_Random(%d,@ %d,@ %d)" a b c
  | Ast.M_Formula expr      -> fprintf fmt "M_Formula(%a)"     pp_math_expr expr
  | Ast.M_Formula_Fun expr  -> fprintf fmt "M_Formula_Fun(%a)" pp_function_expr expr
  | Ast.M_Real v            -> fprintf fmt "M_Real(%a)"        pp_value v
  | Ast.M_D s               -> fprintf fmt "M_D(@ %a)"         pp_string_opt s
  | Ast.M_Eval p            -> fprintf fmt "M_Eval(%a)"        pp_property p
  | Ast.M_With p            -> fprintf fmt "M_With(%a)"        pp_property p
  | Ast.M_Set enum          -> fprintf fmt "M_Set(%a)"         pp_set_enum enum
  | Ast.M_Compute comp      -> fprintf fmt "M_Compute(%a)"     pp_set_compute comp
  | Ast.M_intersect var     -> fprintf fmt "M_intersect(%a)"   pp_variable var

and pp_set_enum fmt lst = pp_list pp_int fmt lst

and pp_set_compute fmt = function
  | Ast.Set_Compute_Union (comp, term) -> 
      fprintf fmt "Set_Compute_Union(%a,@ %a)" pp_set_compute comp pp_set_compute_term term
  | Ast.Set_Compute_Term term -> 
      fprintf fmt "Set_Compute_Term(%a)" pp_set_compute_term term

and pp_set_compute_term fmt = function
  | Ast.Set_Compute_Diff (term, factor) -> 
      fprintf fmt "Set_Compute_Diff(%a,@ %a)" pp_set_compute_term term pp_set_compute_factor factor
  | Ast.Set_Compute_Factor factor -> 
      fprintf fmt "Set_Compute_Factor(%a)" pp_set_compute_factor factor

and pp_set_compute_factor fmt = function
  | Ast.Set_Compute_Paren comp -> 
      fprintf fmt "Set_Compute_Paren(%a)" pp_set_compute comp
  | Ast.Set_Compute_Enum enum -> 
      fprintf fmt "Set_Compute_Enum(%a)" pp_set_enum enum
  | Ast.Set_Compute_Interval interval -> 
      fprintf fmt "Set_Compute_Interval(%a)" pp_set_compute_interval interval

and pp_set_compute_interval fmt = function
  | Ast.LNEQ_RNEQ (left, right) -> 
      fprintf fmt "LNEQ_RNEQ(%a,@ %a)" pp_interval_value left pp_interval_value right
  | Ast.LNEQ_REQ (left, right) -> 
      fprintf fmt "LNEQ_REQ(%a,@ %a)" pp_interval_value left pp_interval_value right
  | Ast.LEQ_RNEQ (left, right) -> 
      fprintf fmt "LEQ_RNEQ(%a,@ %a)" pp_interval_value left pp_interval_value right
  | Ast.LEQ_REQ (left, right) -> 
      fprintf fmt "LEQ_REQ(%a,@ %a)" pp_interval_value left pp_interval_value right

and pp_interval_value fmt = function
  | Ast.I_Int i -> fprintf fmt "I_Int(%d)" i
  | Ast.I_Infinity -> fprintf fmt "I_Infinity"
  | Ast.I_NegInfinity -> fprintf fmt "I_NegInfinity"

and pp_set_list fmt = function
  | Ast.Set_List_Cons (var, expr, rest) -> 
      fprintf fmt "Set_List_Cons(%S,@ %a,@ %a)" var pp_set_expr expr pp_set_list rest
  | Ast.Set_List_Last (var, expr) -> 
      fprintf fmt "Set_List_Last(%S,@ %a)" var pp_set_expr expr

and pp_set_expr fmt = function
  | Ast.Set_Expr_Enum enum -> 
      fprintf fmt "Set_Expr_Enum(%a)" pp_set_enum enum
  | Ast.Set_Expr_interval interval -> 
      fprintf fmt "Set_Expr_interval(%a)" pp_set_interval interval

and pp_set_interval fmt = function
  | Ast.Set_Interval pred -> 
      fprintf fmt "Set_Interval(%a)" pp_predicate pred

and pp_predicate fmt = function
  | Ast.Greater_Than i -> 
      fprintf fmt "Greater_Than(%d)" i
  | Ast.Less_Than i -> 
      fprintf fmt "Less_Than(%d)" i
  | Ast.Greater_Equal i -> 
      fprintf fmt "Greater_Equal(%d)" i
  | Ast.Less_Equal i -> 
      fprintf fmt "Less_Equal(%d)" i
  | Ast.Between_Open (i1, i2) -> 
      fprintf fmt "Between_Open(%d,@ %d)" i1 i2
  | Ast.Between_Left_Closed (i1, i2) -> 
      fprintf fmt "Between_Left_Closed(%d,@ %d)" i1 i2
  | Ast.Between_Right_Closed (i1, i2) -> 
      fprintf fmt "Between_Right_Closed(%d,@ %d)" i1 i2
  | Ast.Between_Closed (i1, i2) -> 
      fprintf fmt "Between_Closed(%d,@ %d)" i1 i2

and pp_set_prob_list fmt = function
  | Ast.Set_Prob_List_Cons (op, ans, rest) -> 
      fprintf fmt "Set_Prob_List_Cons(%a,@ %a,@ %a)" pp_set_operation op pp_answer_item ans pp_set_prob_list rest
  | Ast.Set_Prob_List_Last (op, ans) -> 
      fprintf fmt "Set_Prob_List_Last(%a,@ %a)" pp_set_operation op pp_answer_item ans

and pp_set_operation fmt = function
  | Ast.Set_Op_Union (op, term) -> 
      fprintf fmt "Set_Op_Union(%a,@ %a)" pp_set_operation op pp_set_term term
  | Ast.Set_Op_Term term -> 
      fprintf fmt "Set_Op_Term(%a)" pp_set_term term

and pp_set_term fmt = function
  | Ast.Set_Op_Inter (term, factor) -> 
      fprintf fmt "Set_Op_Inter(%a,@ %a)" pp_set_term term pp_set_factor factor
  | Ast.Set_Op_Factor factor -> 
      fprintf fmt "Set_Op_Factor(%a)" pp_set_factor factor

and pp_set_factor fmt = function
  | Ast.Set_Op_Diff (factor, primary) -> 
      fprintf fmt "Set_Op_Diff(%a,@ %a)" pp_set_factor factor pp_set_primary primary
  | Ast.Set_Op_Primary primary -> 
      fprintf fmt "Set_Op_Primary(%a)" pp_set_primary primary

and pp_set_primary fmt = function
  | Ast.Set_Op_Paren op -> 
      fprintf fmt "Set_Op_Paren(%a)" pp_set_operation op
  | Ast.Set_Op_Var var -> 
      fprintf fmt "Set_Op_Var(%S)" var

and pp_vector_list fmt = function
  | Ast.Vector_List_Cons (var, expr, rest) -> 
      fprintf fmt "Vector_List_Cons(%S,@ %a,@ %a)" var pp_set_enum expr pp_vector_list rest
  | Ast.Vector_List_Last (var, expr) -> 
      fprintf fmt "Vector_List_Last(%S,@ %a)" var pp_set_enum expr

and pp_vector_prob_list fmt = function
  | Ast.Vector_Prob_List_Cons (vec_prob, rest) -> 
      fprintf fmt "Vector_Prob_List_Cons(%a,@ %a)" pp_vector_prob vec_prob pp_vector_prob_list rest
  | Ast.Vector_Prob_List_Last (vec_prob) -> 
      fprintf fmt "Vector_Prob_List_Last(%a)" pp_vector_prob vec_prob

and pp_vector_prob fmt = function
  | Ast.Dot_Product (vec_var_1, vec_var_2, vec_enum_1, vec_enum_2) -> 
      fprintf fmt "Dot_Product(%S,%S,@ %a,@ %a)" vec_var_1 vec_var_2 pp_set_enum vec_enum_1 pp_set_enum vec_enum_2
  | Ast.Cross_Product (vec_var_1, vec_var_2, vec_enum_1, vec_enum_2) ->
      fprintf fmt "Cross_Product(%S,%S,@ %a,@ %a)" vec_var_1 vec_var_2 pp_set_enum vec_enum_1 pp_set_enum vec_enum_2
  | Ast.Vector_Norm (vec_var, vec_enum) ->
      fprintf fmt "Vector_Norm(%S,@ %a)" vec_var pp_set_enum vec_enum
  | Ast.Unit_Vector (vec_var, vec_enum) ->
      fprintf fmt "Unit_Vector(%S,@ %a)" vec_var pp_set_enum vec_enum
  | Ast.Parallel_Vectors (vec_var, vec_enum) ->
      fprintf fmt "Parallel_Vectors(%S,@ %a)" vec_var pp_set_enum vec_enum
  | Ast.Same_Dir_Vectors (vec_var, vec_enum) ->
      fprintf fmt "Same_Dir_Vectors(%S,@ %a)" vec_var pp_set_enum vec_enum

and pp_function_expr fmt = function
  | Ast.Linear_Fun func -> 
      fprintf fmt "Linear_Fun(%a)" pp_linear_function func
  | Ast.Quadratic_Fun func -> 
      fprintf fmt "Quadratic_Fun(%a)" pp_quadratic_function func
  | Ast.Power_Fun func -> 
      fprintf fmt "Power_Fun(%a)" pp_power_function func
  | Ast.Radical_Fun func -> 
      fprintf fmt "Radical_Fun(%a)" pp_radical_function func
  | Ast.Rational_Fun func -> 
      fprintf fmt "Rational_Fun(%a)" pp_rational_function func
  | Ast.Log_Fun func -> 
      fprintf fmt "Log_Fun(%a)" pp_log_function func
  | Ast.Trig_Fun func -> 
      fprintf fmt "Trig_Fun(%a)" pp_trig_function func
  | Ast.Exp_Fun func -> 
      fprintf fmt "Exp_Fun(%a)" pp_exp_function func

and pp_linear_function fmt = function
  | Ast.Fun_Add_Int (f_or_v, i) -> 
      fprintf fmt "Fun_Add_Int(%a, %d)" pp_fun_or_var f_or_v i
  | Ast.Fun_Sub_Int (f_or_v, i) -> 
      fprintf fmt "Fun_Sub_Int(%a, %d)" pp_fun_or_var f_or_v i
  | Ast.Int_Sub_Fun (i, f_or_v) -> 
      fprintf fmt "Int_Sub_Fun(%d, %a)" i pp_fun_or_var f_or_v
  | Ast.Int_Mul_Fun (i, f_or_v) -> 
      fprintf fmt "Int_Mul_Fun(%d, %a)" i pp_fun_or_var f_or_v
  | Ast.Fun_Mul_Int (f_or_v, i) -> 
      fprintf fmt "Fun_Mul_Int(%a, %d)" pp_fun_or_var f_or_v i

and pp_quadratic_function fmt = function
  | Ast.Quad_Add (f_or_v1, i1, f_or_v2, i2) -> 
      fprintf fmt "Quad_Add(%a, %d, %a, %d)" 
        pp_fun_or_var f_or_v1 i1 pp_fun_or_var f_or_v2 i2
  | Ast.Quad_Sub (f_or_v1, i1, f_or_v2, i2) -> 
      fprintf fmt "Quad_Sub(%a, %d, %a, %d)" 
        pp_fun_or_var f_or_v1 i1 pp_fun_or_var f_or_v2 i2
  | Ast.Quad_Square f_or_v -> 
      fprintf fmt "Quad_Square(%a)" pp_fun_or_var f_or_v

and pp_power_function fmt = function
  | Ast.Power_Fun_Int (f_or_v, i) -> 
      fprintf fmt "Power_Fun_Int(%a, %d)" pp_fun_or_var f_or_v i

and pp_radical_function fmt = function
  | Ast.Radi_Sqrt f_or_v -> 
      fprintf fmt "Radi_Sqrt(%a)" pp_fun_or_var f_or_v
  | Ast.Radi_Root (f_or_v, i) -> 
      fprintf fmt "Radi_Root(%a, %d)" pp_fun_or_var f_or_v i

and pp_rational_function fmt = function
  | Ast.Fun_Div_Int (f_or_v, i) -> 
      fprintf fmt "Fun_Div_Int(%a, %d)" pp_fun_or_var f_or_v i
  | Ast.Int_Div_Fun (i, f_or_v) -> 
      fprintf fmt "Int_Div_Fun(%d, %a)" i pp_fun_or_var f_or_v

and pp_log_function fmt = function
  | Ast.Ln_Fun f_or_v -> 
      fprintf fmt "Ln_Fun(%a)" pp_fun_or_var f_or_v

and pp_trig_function fmt = function
  | Ast.Trig_Sin f_or_v -> 
      fprintf fmt "Trig_Sin(%a)" pp_fun_or_var f_or_v
  | Ast.Trig_Cos f_or_v -> 
      fprintf fmt "Trig_Cos(%a)" pp_fun_or_var f_or_v

and pp_exp_function fmt = function
  | Ast.Exp f_or_v -> 
      fprintf fmt "Exp(%a)" pp_fun_or_var f_or_v

and pp_fun_or_var fmt = function
  | Ast.Func func -> 
      fprintf fmt "Func(%a)" pp_function_expr func
  | Ast.Var_X -> 
      fprintf fmt "Var_X"

and pp_derivative_prob_list fmt = function
  | Ast.Derivative_Prob_List_Cons (der_prob, rest) -> 
      fprintf fmt "Derivative_Prob_List_Cons(%a,@ %a)" pp_derivative_prob der_prob pp_derivative_prob_list rest
  | Ast.Derivative_Prob_List_Last (der_prob) -> 
      fprintf fmt "Derivative_Prob_List_Last(%a)" pp_derivative_prob der_prob

and pp_derivative_prob fmt = function
  | Ast.First_Derivative fun_name -> 
      fprintf fmt "First_Derivative(%S)" fun_name
  | Ast.Derivative_Algebra (i1, fun_name, i2) ->
      fprintf fmt "Derivative_Algebra(%d,%S,%d)" i1 fun_name i2
  | Ast.Second_Derivative fun_name ->
      fprintf fmt "Second_Derivative(%S)" fun_name

and pp_problem_section fmt = function
  | Ast.Problem ql ->
      fprintf fmt "Problem(%a)" pp_question_list ql

and pp_question_list fmt = pp_list pp_question_item fmt

and pp_question_item fmt = function
  | Ast.Q_Item (qt, ai, oi) ->
      fprintf fmt "Q_Item(%a,@ %a,@ %a)"
        pp_question_text qt
        pp_answer_item  ai
        pp_int_option   oi
  | Ast.Q_Given_Set (s_list, sp_list) -> 
    fprintf fmt "Q_Given_Set(%a,@ %a)" pp_set_list s_list pp_set_prob_list sp_list
  | Ast.Q_Suppose_Vector (vec_list, vecp_list) -> 
    fprintf fmt "Q_Suppose_Vector(%a,@ %a)" pp_vector_list vec_list pp_vector_prob_list vecp_list
  | Ast.Q_Given_Function (fun_name, derp_list) ->
    fprintf fmt "Q_Given_Function(%S,@ %a)" fun_name pp_derivative_prob_list derp_list
  | Ast.Q_Boolean_Eval (expr, assignments, ans, oi) ->
    fprintf fmt "Q_Boolean_Eval(%a,@ %a,@ %a,@ %a)"
      pp_bool_expr expr
      pp_bool_assignments assignments
      pp_answer_item ans
      pp_int_option oi

and pp_question_text fmt = function
  | Ast.Q_Value  ic -> fprintf fmt "Q_Value(%a)"   pp_intext_call ic
  | Ast.Q_IsEqual ic -> fprintf fmt "Q_IsEqual(%a)" pp_intext_call ic

and pp_answer_item fmt = function
  | Ast.A_Var v -> fprintf fmt "A_Var(%a)" pp_variable v

and pp_intext_call fmt = function
  | Ast.IC_VarV v -> fprintf fmt "IC_VarV(%a)" pp_variable v
  | Ast.IC_Math e -> fprintf fmt "IC_Math(%a)" pp_math_expr e

and pp_math_expr fmt = function
  | Ast.ME_Add  (e,t) -> fprintf fmt "ME_Add(%a,@ %a)" pp_math_expr e pp_term t
  | Ast.ME_Sub  (e,t) -> fprintf fmt "ME_Sub(%a,@ %a)" pp_math_expr e pp_term t
  | Ast.ME_Term t     -> fprintf fmt "ME_Term(%a)"     pp_term t

and pp_term fmt = function
  | Ast.T_Mul (t,f) -> fprintf fmt "T_Mul(%a,@ %a)" pp_term t pp_factor f
  | Ast.T_Div (t,f) -> fprintf fmt "T_Div(%a,@ %a)" pp_term t pp_factor f
  | Ast.T_Fac f     -> fprintf fmt "T_Fac(%a)"       pp_factor f

and pp_factor fmt = function
  | Ast.F_Paren e -> fprintf fmt "F_Paren(%a)" pp_math_expr e
  | Ast.F_Num   f -> fprintf fmt "F_Num(%f)"   f
  | Ast.F_Int   i -> fprintf fmt "F_Int(%d)"   i

and pp_int_option fmt = function
  | None   -> fprintf fmt "None"
  | Some i -> fprintf fmt "Some(%d)" i

and pp_bool_assignments fmt assignments =
  pp_list pp_bool_assignment fmt assignments

and pp_bool_assignment fmt (name, value) =
  fprintf fmt "(%S,@ %B)" name value

and pp_bool_expr fmt = function
  | Ast.Bool_Const b ->
      fprintf fmt "Bool_Const(%B)" b
  | Ast.Bool_Var name ->
      fprintf fmt "Bool_Var(%S)" name
  | Ast.Bool_Not expr ->
      fprintf fmt "Bool_Not(%a)" pp_bool_expr expr
  | Ast.Bool_And (left, right) ->
      fprintf fmt "Bool_And(%a,@ %a)" pp_bool_expr left pp_bool_expr right
  | Ast.Bool_Or (left, right) ->
      fprintf fmt "Bool_Or(%a,@ %a)" pp_bool_expr left pp_bool_expr right
  | Ast.Bool_Xor (left, right) ->
      fprintf fmt "Bool_Xor(%a,@ %a)" pp_bool_expr left pp_bool_expr right
  | Ast.Bool_Implies (left, right) ->
      fprintf fmt "Bool_Implies(%a,@ %a)" pp_bool_expr left pp_bool_expr right
  | Ast.Bool_Iff (left, right) ->
      fprintf fmt "Bool_Iff(%a,@ %a)" pp_bool_expr left pp_bool_expr right
