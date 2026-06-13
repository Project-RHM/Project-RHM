open Ast
open Parser        (* bring DCST, CST, Settle, etc. into scope *)

let print_describe = false

(* convert AST.module_ to DCST.module_ *)
let describe_module modu = 
  if print_describe then prerr_endline "→ describe_module";
  match modu with
  | Variables -> DCST.module_ "variables"
  | Constants -> DCST.module_ "constants"
  | Strings   -> DCST.module_ "strings"
  | Operators -> DCST.module_ "operators"
  (* ------------------- NEW CODE START ------------------- *)
  | Flags     -> DCST.module_ "flags"
  (* ------------------- NEW CODE END ------------------- *)

let rec dcst_of_entries = function
  | [x]       -> DCST.entry_list_single x
  | x :: xs   -> DCST.entry_list x (dcst_of_entries xs)
  | []        -> invalid_arg "entry_list must be non‐empty"

let dcst_of_operator (s : operator) : DCST.operator =
  match s with
  | Add_Op   -> DCST.operator_add ()
  | Sub_Op   -> DCST.operator_sub ()
  | Mul_Op   -> DCST.operator_mul ()
  | Div_Op   -> DCST.operator_div ()

let rec dcst_of_operator_list = function
  | [s]    -> DCST.operator_list_single_sin (dcst_of_operator s)
  | s::ss  -> DCST.operator_list_sin (dcst_of_operator s) (dcst_of_operator_list ss)
  | []     -> invalid_arg "operator_list must be non‐empty"

let rec dcst_of_properties = function
  | [p]      -> DCST.properties_single p
  | p :: ps  -> DCST.properties p (dcst_of_properties ps)
  | []       -> invalid_arg "describe: empty properties"

let rec dcst_of_var_list = function
  | [v]    -> DCST.var_list_single v
  | v::vs  -> DCST.var_list v (dcst_of_var_list vs)
  | []     -> invalid_arg "describe: empty variable_list"
  
let rec dcst_of_question_list = function
  | [q]     -> DCST.qlist_single q
  | q :: qs -> DCST.qlist q (dcst_of_question_list qs)
  | []      -> invalid_arg "describe: empty question_list"
(*
let rec dcst_of_solution_list = function
  | [x]    -> DCST.slist_single x
  | x::xs  -> DCST.slist x (dcst_of_solution_list xs)
  | []     -> invalid_arg "empty solution_list"
*)
let rec describe_document doc = 
  if print_describe then prerr_endline "→ describe_document";
  match doc with
  | Doc_No_Sol (hdr, ctx, prob) ->
      DCST.doc_no_sol
        (describe_header hdr)
        (describe_context_setup_list ctx)
        (describe_problem_section prob)

and describe_header header = 
  if print_describe then prerr_endline "→ describe_header";
  match header with
  | LoadMacros (None) -> DCST.header_simple ()
  | LoadMacros (Some mac) -> DCST.header_with_macro (describe_macro mac)

and describe_macro macro = 
  if print_describe then prerr_endline "→ describe_macro";
  match macro with
  | Macro_Atom name       -> DCST.macro_atom name
  | Macro_Cons (n, rest)  -> DCST.macro_cons n (describe_macro rest)

and describe_context_setup_list context_setup = 
  if print_describe then prerr_endline "→ describe_context_setup_list";
  match context_setup with
  | Context_Setup_Vars_Last (ctx, ans)      -> 
    DCST.ctx_setup_vars_last (describe_context_setup ctx) (describe_answer_vars ans)
  | Context_Setup_Vars_Cons (ctx, ans, cfg) -> 
    DCST.ctx_setup_vars_cons (describe_context_setup ctx) (describe_answer_vars ans) (describe_context_setup_list cfg)
  | Context_Setup_No_Vars_Last ctx        -> 
    DCST.ctx_setup_no_vars_last (describe_context_setup ctx)
  | Context_Setup_No_Vars_Cons (ctx, cfg) -> 
    DCST.ctx_setup_no_vars_cons (describe_context_setup ctx) (describe_context_setup_list cfg)

and describe_context_setup context_setup = 
  if print_describe then prerr_endline "→ describe_context_setup";
  match context_setup with
  | Context_Only name            -> DCST.ctx_only name
  | Context_With_Config (n, cfg) -> DCST.ctx_with_cfg n (describe_context_config cfg)

and describe_context_config context_config = 
  if print_describe then prerr_endline "→ describe_context_config";
  match context_config with
  | Cfg_Last (m, cm)       ->
      DCST.cfg_last (describe_module m) (describe_context_method cm)
  | Cfg_Cons (m, cm, rest) ->
      DCST.cfg_cons (describe_module m)
                  (describe_context_method cm)
                  (describe_context_config rest)

and describe_context_method context_method = 
  if print_describe then prerr_endline "→ describe_context_method";
  match context_method with
  | CM_Add entries      -> DCST.cm_add (dcst_of_entries (List.map describe_entry entries))
  | CM_Set entries      -> DCST.cm_set (dcst_of_entries (List.map describe_entry entries))
  | CM_Are entries      -> DCST.cm_are (dcst_of_entries (List.map describe_entry entries))
  | CM_Undefine ops     -> DCST.cm_undefine (dcst_of_operator_list ops)
  | CM_Redefine ops     -> DCST.cm_redefine (dcst_of_operator_list ops)

and describe_property prop =
  if print_describe then prerr_endline "→ describe_property";
  match prop with
  | Property (k,v) -> DCST.property (describe_key k) (describe_value v)

and describe_entry entry = 
  if print_describe then prerr_endline "→ describe_entry";
  match entry with
  | Entry_Property prop -> DCST.entry_prop (describe_property prop)
  | Entry_Map  (k, ps)  -> begin match (k, ps) with
                          | (k, None)  -> DCST.entry_map_none (describe_key k)
                          | (k, Some ps) -> let props = List.map describe_property ps in
                                            DCST.entry_map
                                              (describe_key k)
                                              (dcst_of_properties props)
                        end

and describe_key key = 
  if print_describe then prerr_endline "→ describe_key";
  match key with
  | Ident id           -> DCST.key_ident id
  | Str   s            -> DCST.key_str s

and describe_value value = 
  if print_describe then prerr_endline "→ describe_value";
  match value with
  | VInt i             -> if i < 0 then DCST.value_int_neg i else DCST.value_int_pos i
  | VNum n             -> if n < 0. then DCST.value_num_neg n else DCST.value_num_pos n
  | VStr s             -> DCST.value_str_dou s
  | VIdent id          -> DCST.value_ident id

and describe_answer_vars vars =
  if print_describe then prerr_endline "→ describe_answer_vars";
  let vdecls = List.map describe_var_decl vars in
  DCST.answer_vars (dcst_of_var_list vdecls)

and describe_var_decl (id, v) =
  if print_describe then prerr_endline "→ describe_var_decl";
  DCST.var_decl id (describe_variable v)
  
and describe_variable variable = 
  if print_describe then prerr_endline "→ describe_variable";
  match variable with
  | Var_Value v         -> DCST.var_value (describe_value v)
  | Var_Method (m)      -> DCST.var_meth (describe_math_object_method m)
  | Var_Field (id,m)    -> DCST.var_field id (describe_math_object_method m)
  | Var_Chain (l,r)     -> DCST.var_chain (describe_math_object_method l) (describe_math_object_method r)

and describe_math_object_method mometh = 
  if print_describe then prerr_endline "→ describe_math_object_method";
  match mometh with
  | M_Random       (a,b,c) -> DCST.meth_rand a b c
  | M_Formula      s       -> DCST.meth_form (describe_math_expr s)
  (* ------------------- NEW CODE START ------------------- *)
  | M_Formula_Fun  s       -> DCST.meth_form_fun (describe_function_expr s)
  (* ------------------- NEW CODE END ------------------- *)
  | M_Real         v       -> DCST.meth_real (describe_value v)
  | M_D            u       -> begin match u with 
                              | None   -> DCST.meth_d_none ()
                              | Some u -> DCST.meth_d u
                            end
  | M_Eval         p       -> DCST.meth_eval (describe_property p)
  | M_With         p       -> DCST.meth_with (describe_property p)
  | M_Set          enum    -> DCST.meth_set (describe_set_enum enum)
  | M_Compute      comp    -> DCST.meth_compute (describe_set_compute comp)
  | M_intersect    var     -> DCST.meth_intersect (describe_variable var)

and describe_set_enum enum =
  if print_describe then prerr_endline "→ describe_set_enum";
  let rec dcst_of_set_enum = function
    | [x] -> DCST.set_enum_last (describe_int_with_sign x)
    | x :: xs -> DCST.set_enum_cons (describe_int_with_sign x) (dcst_of_set_enum xs)
    | [] -> invalid_arg "empty set_enum"
  in
  dcst_of_set_enum enum

and describe_set_compute comp =
  if print_describe then prerr_endline "→ describe_set_compute";
  match comp with
  | Set_Compute_Union (c, t) -> DCST.set_compute_union (describe_set_compute c) (describe_set_compute_term t)
  | Set_Compute_Term t -> DCST.set_compute_term (describe_set_compute_term t)

and describe_set_compute_term term =
  if print_describe then prerr_endline "→ describe_set_compute_term";
  match term with
  | Set_Compute_Diff (t, f) -> DCST.set_compute_diff (describe_set_compute_term t) (describe_set_compute_factor f)
  | Set_Compute_Factor f -> DCST.set_compute_factor (describe_set_compute_factor f)

and describe_set_compute_factor factor =
  if print_describe then prerr_endline "→ describe_set_compute_factor";
  match factor with
  | Set_Compute_Paren c -> DCST.set_compute_paren (describe_set_compute c)
  | Set_Compute_Enum e -> DCST.set_compute_enum (describe_set_enum e)
  | Set_Compute_Interval i -> DCST.set_compute_interval (describe_set_compute_interval i)

and describe_set_compute_interval interval =
  if print_describe then prerr_endline "→ describe_set_compute_interval";
  match interval with
  | LNEQ_RNEQ (l, r) -> DCST.set_compute_interval_open (describe_interval_value l) (describe_interval_value r)
  | LNEQ_REQ (l, r) -> DCST.set_compute_interval_left_open (describe_interval_value l) (describe_interval_value r)
  | LEQ_RNEQ (l, r) -> DCST.set_compute_interval_right_open (describe_interval_value l) (describe_interval_value r)
  | LEQ_REQ (l, r) -> DCST.set_compute_interval_closed (describe_interval_value l) (describe_interval_value r)

and describe_interval_value ival =
  if print_describe then prerr_endline "→ describe_interval_value";
  match ival with
  | I_Int i -> DCST.interval_int (describe_int_with_sign i)
  | I_Infinity -> DCST.interval_infinity ()
  | I_NegInfinity -> DCST.interval_neg_infinity ()

and describe_problem_section problem_section = 
  if print_describe then prerr_endline "→ describe_problem_section";
  match problem_section with
  | Problem qs ->
      let qds = List.map describe_question_item qs in
      DCST.problem_section (dcst_of_question_list qds)

and describe_question_item question_item = 
  if print_describe then prerr_endline "→ describe_question_item";
  match question_item with
  | Q_Item (qt, a, Some w) ->
      DCST.qitem2 (describe_question_text qt)
                  (describe_answer_item a) w
  | Q_Item (qt, a, None ) ->
      DCST.qitem1 (describe_question_text qt)
                  (describe_answer_item a)
  | Q_Given_Set (s_list, sp_list) ->
      DCST.qset (describe_set_list s_list) (describe_set_prob_list sp_list)
  | Q_Suppose_Vector (vec_list, vecp_list) ->
      DCST.qvector (describe_vector_list vec_list) (describe_vector_prob_list vecp_list)
  (* ------------------- NEW CODE START ------------------- *)
  | Q_Given_Function (fun_name, derp_list) ->
      DCST.qderivative fun_name (describe_derivative_prob_list derp_list)
  | Q_Given_Prop_Equiv prob_list ->
      DCST.qprop_equiv (describe_prop_equiv_prob_list prob_list)
  (* ------------------- NEW CODE END ------------------- *)
  | Q_Boolean_Eval (expr, assignments, ans, None) ->
	      DCST.qbool_eval
	        (describe_bool_expr expr)
	        (describe_bool_assignment_list assignments)
	        (describe_answer_item ans)
	  | Q_Boolean_Eval (expr, assignments, ans, Some width) ->
	      DCST.qbool_eval_width
	        (describe_bool_expr expr)
	        (describe_bool_assignment_list assignments)
	        (describe_answer_item ans)
	        width
and describe_set_list s_list =
  if print_describe then prerr_endline "→ describe_set_list";
  match s_list with
  | Set_List_Cons (var, expr, rest) -> 
      DCST.set_list_cons var (describe_set_expr expr) (describe_set_list rest)
  | Set_List_Last (var, expr) ->
      DCST.set_list_last var (describe_set_expr expr)

and describe_set_expr expr =
  if print_describe then prerr_endline "→ describe_set_expr";
  match expr with
  | Set_Expr_Enum e -> DCST.set_expr_enum (describe_set_enum e)
  | Set_Expr_interval i -> DCST.set_expr_interval (describe_set_interval i)

and describe_set_interval interval =
  if print_describe then prerr_endline "→ describe_set_interval";
  match interval with
  | Set_Interval p -> DCST.set_interval (describe_predicate p)

and describe_predicate pred =
  if print_describe then prerr_endline "→ describe_predicate";
  match pred with
  | Greater_Than i -> DCST.pred_gt (describe_int_with_sign i)
  | Less_Than i -> DCST.pred_lt (describe_int_with_sign i)
  | Greater_Equal i -> DCST.pred_geq (describe_int_with_sign i)
  | Less_Equal i -> DCST.pred_leq (describe_int_with_sign i)
  | Between_Open (i1, i2) -> DCST.pred_between_open (describe_int_with_sign i1) (describe_int_with_sign i2)
  | Between_Left_Closed (i1, i2) -> DCST.pred_between_left_closed (describe_int_with_sign i1) (describe_int_with_sign i2)
  | Between_Right_Closed (i1, i2) -> DCST.pred_between_right_closed (describe_int_with_sign i1) (describe_int_with_sign i2)
  | Between_Closed (i1, i2) -> DCST.pred_between_closed (describe_int_with_sign i1) (describe_int_with_sign i2)

and describe_set_prob_list sp_list =
  if print_describe then prerr_endline "→ describe_set_prob_list";
  match sp_list with
  | Set_Prob_List_Cons (op, ans, rest) ->
      DCST.set_prob_list_cons (describe_set_operation op) (describe_answer_item ans) (describe_set_prob_list rest)
  | Set_Prob_List_Last (op, ans) ->
      DCST.set_prob_list_last (describe_set_operation op) (describe_answer_item ans)

and describe_set_operation op =
  if print_describe then prerr_endline "→ describe_set_operation";
  match op with
  | Set_Op_Union (o, t) -> DCST.set_op_union (describe_set_operation o) (describe_set_term t)
  | Set_Op_Term t -> DCST.set_op_term (describe_set_term t)

and describe_set_term term =
  if print_describe then prerr_endline "→ describe_set_term";
  match term with
  | Set_Op_Inter (t, f) -> DCST.set_op_inter (describe_set_term t) (describe_set_factor f)
  | Set_Op_Factor f -> DCST.set_op_factor (describe_set_factor f)

and describe_set_factor factor =
  if print_describe then prerr_endline "→ describe_set_factor";
  match factor with
  | Set_Op_Diff (f, p) -> DCST.set_op_diff (describe_set_factor f) (describe_set_primary p)
  | Set_Op_Primary p -> DCST.set_op_primary (describe_set_primary p)

and describe_set_primary primary =
  if print_describe then prerr_endline "→ describe_set_primary";
  match primary with
  | Set_Op_Paren op -> DCST.set_primary_paren (describe_set_operation op)
  | Set_Op_Var var -> DCST.set_primary_var var

and describe_question_text question_text =
  if print_describe then prerr_endline "→ describe_question_text";
  match question_text with
	  | Q_Value    c  -> DCST.qvalue    (describe_intext_call c)
	  | Q_IsEqual  c  -> DCST.qis       (describe_intext_call c)

and describe_bool_assignment_list assignments =
  if print_describe then prerr_endline "→ describe_bool_assignment_list";
  match assignments with
  | [assignment] ->
      DCST.bool_assignment_list_last (describe_bool_assignment assignment)
  | assignment :: rest ->
      DCST.bool_assignment_list_cons
        (describe_bool_assignment assignment)
        (describe_bool_assignment_list rest)
  | [] ->
      invalid_arg "describe: empty bool_assignment_list"

and describe_bool_assignment (name, value) =
  if print_describe then prerr_endline "→ describe_bool_assignment";
  if value then
    DCST.bool_assignment_true name
  else
    DCST.bool_assignment_false name

and describe_bool_expr expr =
  if print_describe then prerr_endline "→ describe_bool_expr";
  match expr with
  | Bool_Const true -> DCST.bool_true ()
  | Bool_Const false -> DCST.bool_false ()
  | Bool_Var name -> DCST.bool_var name
  | Bool_Not inner -> DCST.bool_not (describe_bool_expr inner)
  | Bool_And (left, right) ->
      DCST.bool_and (describe_bool_expr left) (describe_bool_expr right)
  | Bool_Or (left, right) ->
      DCST.bool_or (describe_bool_expr left) (describe_bool_expr right)
  | Bool_Xor (left, right) ->
      DCST.bool_xor (describe_bool_expr left) (describe_bool_expr right)
  | Bool_Implies (left, right) ->
      DCST.bool_implies (describe_bool_expr left) (describe_bool_expr right)
  | Bool_Iff (left, right) ->
      DCST.bool_iff (describe_bool_expr left) (describe_bool_expr right)

and describe_answer_item answer_item =
  if print_describe then prerr_endline "→ describe_answer_item";
  match answer_item with
  | A_Var var     -> DCST.ans_var (describe_variable var)

and describe_vector_list vec_list =
  if print_describe then prerr_endline "→ describe_vector_list";
  match vec_list with
  | Vector_List_Cons (var, expr, rest) -> 
      DCST.vec_list_cons var (describe_set_enum expr) (describe_vector_list rest)
  | Vector_List_Last (var, expr) ->
      DCST.vec_list_last var (describe_set_enum expr)

and describe_vector_prob_list vecp_list =
  if print_describe then prerr_endline "→ describe_vector_prob_list";
  match vecp_list with
  | Vector_Prob_List_Cons (vecp, rest) ->
      DCST.vec_prob_list_cons (describe_vector_prob vecp) (describe_vector_prob_list rest)
  | Vector_Prob_List_Last (vecp) ->
      DCST.vec_prob_list_last (describe_vector_prob vecp)

and describe_vector_prob vec_prob =
  if print_describe then prerr_endline "→ describe_vector_prob";
  match vec_prob with
  | Dot_Product (var1, var2, vec1, vec2) ->
      DCST.vec_prob_1 var1 var2 (describe_set_enum vec1) (describe_set_enum vec2)
  | Cross_Product (var1, var2, vec1, vec2) ->
      DCST.vec_prob_2 var1 var2 (describe_set_enum vec1) (describe_set_enum vec2)
  | Vector_Norm (var, vec) ->
      DCST.vec_prob_3 var (describe_set_enum vec)
  | Unit_Vector (var, vec) ->
      DCST.vec_prob_4 var (describe_set_enum vec)
  | Parallel_Vectors (var, vec) ->
      DCST.vec_prob_5 var (describe_set_enum vec)
  | Same_Dir_Vectors (var, vec) ->
      DCST.vec_prob_6 var (describe_set_enum vec)

(* ------------------- NEW CODE START ------------------- *)
and describe_function_expr func_expr = 
  if print_describe then prerr_endline "→ describe_function_expr";
  match func_expr with
  | Linear_Fun func -> 
      DCST.linear_fun (describe_linear_function func)
  | Quadratic_Fun func -> 
      DCST.quadratic_fun (describe_quadratic_function func)
  | Power_Fun func -> 
      DCST.power_fun (describe_power_function func)
  | Radical_Fun func -> 
      DCST.radical_fun (describe_radical_function func)
  | Rational_Fun func -> 
      DCST.rational_fun (describe_rational_function func)
  | Log_Fun func -> 
      DCST.log_fun (describe_log_function func)
  | Trig_Fun func -> 
      DCST.trig_fun (describe_trig_function func)
  | Exp_Fun func -> 
      DCST.exp_fun (describe_exp_function func)

and describe_linear_function = function
  | Fun_Add_Int (f_or_v, i) -> 
      DCST.fun_add_int (describe_fun_or_var f_or_v) i
  | Fun_Sub_Int (f_or_v, i) -> 
      DCST.fun_sub_int (describe_fun_or_var f_or_v) i
  | Int_Sub_Fun (i, f_or_v) -> 
      DCST.int_sub_fun i (describe_fun_or_var f_or_v)
  | Int_Mul_Fun (i, f_or_v) -> 
      DCST.int_mul_fun i (describe_fun_or_var f_or_v)
  | Fun_Mul_Int (f_or_v, i) -> 
      DCST.fun_mul_int (describe_fun_or_var f_or_v) i

and describe_quadratic_function = function
  | Quad_Add (f_or_v1, i1, f_or_v2, i2) -> 
      DCST.quad_add 
        (describe_fun_or_var f_or_v1) i1 2 (describe_fun_or_var f_or_v2) i2
  | Quad_Sub (f_or_v1, i1, f_or_v2, i2) -> 
      DCST.quad_sub 
        (describe_fun_or_var f_or_v1) i1 2 (describe_fun_or_var f_or_v2) i2
  | Quad_Square f_or_v -> 
      DCST.quad_square (describe_fun_or_var f_or_v) 2

and describe_power_function = function
  | Power_Fun_Int (f_or_v, i) -> 
      DCST.power_fun_int_expr (describe_fun_or_var f_or_v) i

and describe_radical_function = function
  | Radi_Sqrt f_or_v -> 
      DCST.radi_sqrt (describe_fun_or_var f_or_v)
  | Radi_Root (f_or_v, i) -> 
      DCST.radi_root (describe_fun_or_var f_or_v) 1 i

and describe_rational_function = function
  | Fun_Div_Int (f_or_v, i) -> 
      DCST.fun_div_int (describe_fun_or_var f_or_v) i
  | Int_Div_Fun (i, f_or_v) -> 
      DCST.int_div_fun i (describe_fun_or_var f_or_v)

and describe_log_function = function
  | Ln_Fun f_or_v -> 
      DCST.ln_fun (describe_fun_or_var f_or_v)

and describe_trig_function = function
  | Trig_Sin f_or_v -> 
      DCST.trig_sin (describe_fun_or_var f_or_v)
  | Trig_Cos f_or_v -> 
      DCST.trig_cos (describe_fun_or_var f_or_v)

and describe_exp_function = function
  | Exp f_or_v -> 
      DCST.exp (describe_fun_or_var f_or_v)

and describe_fun_or_var = function
  | Func func -> 
      DCST.func (describe_function_expr func)
  | Var_X -> 
      DCST.var_x ()

and describe_derivative_prob_list derp_list =
  if print_describe then prerr_endline "→ describe_derivative_prob_list";
  match derp_list with
  | Derivative_Prob_List_Cons (der_prob, rest) ->
      DCST.der_prob_list_cons (describe_derivative_prob der_prob) (describe_derivative_prob_list rest)
  | Derivative_Prob_List_Last der_prob ->
      DCST.der_prob_list_last (describe_derivative_prob der_prob)

and describe_derivative_prob = function
  | First_Derivative fun_name ->
      DCST.der_prob_1 fun_name
  | Derivative_Algebra (i1, fun_name, i2) ->
      DCST.der_prob_2 i1 fun_name i2
  | Second_Derivative fun_name ->
      DCST.der_prob_3 fun_name

(* ================================================================ *)
(* ============== Propositional Logic Describe =================== *)
(* ================================================================ *)

and describe_prop_expr expr =
  match expr with
  | Prop_Var v -> DCST.prop_var v
  | Prop_True -> DCST.prop_true ()
  | Prop_False -> DCST.prop_false ()
  | Prop_Not e -> DCST.prop_not (describe_prop_expr e)
  | Prop_And (l, r) -> DCST.prop_and (describe_prop_expr l) (describe_prop_expr r)
  | Prop_Or (l, r) -> DCST.prop_or (describe_prop_expr l) (describe_prop_expr r)
  | Prop_Imp (l, r) -> DCST.prop_imp (describe_prop_expr l) (describe_prop_expr r)
  | Prop_Equiv (l, r) -> DCST.prop_equiv (describe_prop_expr l) (describe_prop_expr r)

and describe_prop_equiv_question q =
  match q with
  | Prop_Equiv_Judge (e1, e2, is_equiv) ->
      DCST.prop_equiv_judge (describe_prop_expr e1) (describe_prop_expr e2) is_equiv
  | Prop_Equiv_Choice (e1, correct, wrongs, idx) ->
      let wrongs_dcst = List.map describe_prop_expr wrongs in
      DCST.prop_equiv_choice (describe_prop_expr e1) (describe_prop_expr correct) wrongs_dcst idx

and describe_prop_equiv_prob_list plist =
  match plist with
  | Prop_Equiv_Prob_List_Cons (q, rest) ->
      DCST.prop_equiv_prob_list_cons (describe_prop_equiv_question q) (describe_prop_equiv_prob_list rest)
  | Prop_Equiv_Prob_List_Last q ->
      DCST.prop_equiv_prob_list_last (describe_prop_equiv_question q)

(* ------------------- NEW CODE END ------------------- *)

(*
and describe_solution_section solution_sec = 
  if print_describe then prerr_endline "→ describe_solution_section";
  match solution_sec with
  | Solution items ->
      let sdocs = List.map describe_solution_item items in
      DCST.solution_section (dcst_of_solution_list sdocs)

and describe_solution_item solution_item = 
  if print_describe then prerr_endline "→ describe_solution_item";
  match solution_item with
  | Sol_Correct (ans, txt) ->
      DCST.sol_item (describe_intext_call ans) txt
*)
and describe_intext_call intext_call = 
  if print_describe then prerr_endline "→ describe_intext_call";
  match intext_call with
  | IC_VarV  v     -> DCST.ict_varv (describe_variable v)
  | IC_Math  e     -> DCST.ict_math (describe_math_expr e)

and describe_math_expr math_expr = 
  if print_describe then prerr_endline "→ describe_math_expr";
  match math_expr with
  | ME_Add (l,r)  -> DCST.madd (describe_math_expr l) (describe_term r)
  | ME_Sub (l,r)  -> DCST.msub (describe_math_expr l) (describe_term r)
  | ME_Term t     -> DCST.mterm (describe_term t)

and describe_term term = 
  if print_describe then prerr_endline "→ describe_term";
  match term with
  | T_Mul (l,r)   -> DCST.tmul (describe_term l) (describe_factor r)
  | T_Div (l,r)   -> DCST.tdiv (describe_term l) (describe_factor r)
  | T_Fac f       -> DCST.tfac (describe_factor f)

and describe_factor factor = 
  if print_describe then prerr_endline "→ describe_factor";
  match factor with
  | F_Paren e     -> DCST.fparen (describe_math_expr e)
  | F_Num   n     -> DCST.fnum n
  | F_Int   i     -> DCST.fint i

and describe_int_with_sign i =
  if print_describe then prerr_endline "→ describe_int_with_sign";
  if i < 0 then DCST.negative_int i else DCST.positive_int i
