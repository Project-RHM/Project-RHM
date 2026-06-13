(** The type of the abstract syntax tree (AST). *)
type document =
  | Doc_No_Sol    of header * context_setup_list * problem_section

and header =
  | LoadMacros of macro option

and macro =
  | Macro_Cons of string * macro
  | Macro_Atom of string

and context_setup_list =
  | Context_Setup_Vars_Cons of context_setup * answer_vars * context_setup_list
  | Context_Setup_Vars_Last of context_setup * answer_vars
  | Context_Setup_No_Vars_Cons of context_setup * context_setup_list
  | Context_Setup_No_Vars_Last of context_setup

and context_setup =
  | Context_Only of string
  | Context_With_Config of string * context_config

and context_config =
  | Cfg_Cons of module_ * context_method * context_config
  | Cfg_Last of module_ * context_method

(* ------------------- NEW CODE START ------------------- *)
and module_ = Variables | Constants | Strings | Operators | Flags
(* ------------------- NEW CODE END ------------------- *)

and context_method =
  | CM_Add      of entry_list
  | CM_Set      of entry_list
  | CM_Are      of entry_list
  | CM_Undefine of operator_list
  | CM_Redefine of operator_list

and entry_list = entry list
and entry =
  | Entry_Property of property
  | Entry_Map      of key * properties option

and property = Property of key * value
and properties = property list

and key = Ident of string | Str of string
and value = VInt of int | VNum of float | VStr of string | VIdent of string

and operator_list = operator list
and operator = 
  | Add_Op
  | Sub_Op
  | Mul_Op
  | Div_Op

and answer_vars = variable_list
and variable_list = variable_declaration list
and variable_declaration = string * variable   (* $ <identifier> = <variable> ; *)

and variable =
  | Var_Value   of value
  | Var_Method  of math_object_method
  | Var_Field   of string * math_object_method
  | Var_Chain   of math_object_method * math_object_method

and math_object_method =
  | M_Random   of int * int * int
  | M_Formula  of math_expr
  (* ------------------- NEW CODE START ------------------- *)
  | M_Formula_Fun of function_expr
  (* ------------------- NEW CODE END ------------------- *)
  | M_Real     of value
  | M_D        of string option
  | M_Eval     of property
  | M_With     of property
  | M_Set      of set_enum
  | M_Compute  of set_compute
  | M_intersect  of variable

and set_enum = int list

and set_compute =
  | Set_Compute_Union of set_compute * set_compute_term
  | Set_Compute_Term  of set_compute_term

and set_compute_term =
  | Set_Compute_Diff   of set_compute_term * set_compute_factor
  | Set_Compute_Factor of set_compute_factor

and set_compute_factor =
  | Set_Compute_Paren     of set_compute
  | Set_Compute_Enum      of set_enum
  | Set_Compute_Interval  of set_compute_interval

and set_compute_interval =
  | LNEQ_RNEQ of interval_value * interval_value
  | LNEQ_REQ  of interval_value * interval_value
  | LEQ_RNEQ  of interval_value * interval_value
  | LEQ_REQ   of interval_value * interval_value

and interval_value =
  | I_Int of int
  | I_Infinity
  | I_NegInfinity

and problem_section = Problem of question_list
and question_list = question_item list
and question_item =
  | Q_Item of question_text * answer_item * int option
  | Q_Given_Set of set_list * set_prob_list
  | Q_Suppose_Vector of vector_list * vector_prob_list
(* ------------------- NEW CODE START ------------------- *)
  | Q_Given_Function of string * derivative_prob_list
  | Q_Given_Prop_Equiv of prop_equiv_prob_list
(* ------------------- NEW CODE END ------------------- *)*

and question_text =
  | Q_Value     of intext_call
  | Q_IsEqual   of intext_call

and set_list = 
  | Set_List_Cons of string * set_expr * set_list
  | Set_List_Last of string * set_expr

and set_expr =
  | Set_Expr_Enum     of set_enum
  | Set_Expr_interval of set_interval

and set_interval =
  | Set_Interval of predicate

and predicate =
  | Greater_Than          of int
  | Less_Than             of int
  | Greater_Equal         of int
  | Less_Equal            of int
  | Between_Open          of int * int
  | Between_Left_Closed   of int * int
  | Between_Right_Closed  of int * int
  | Between_Closed        of int * int

and set_prob_list =
  | Set_Prob_List_Cons of set_operation * answer_item * set_prob_list
  | Set_Prob_List_Last of set_operation * answer_item

and set_operation =
  | Set_Op_Union of set_operation * set_term
  | Set_Op_Term  of set_term

and set_term =
  | Set_Op_Inter  of set_term * set_factor
  | Set_Op_Factor of set_factor

and set_factor = 
  | Set_Op_Diff    of set_factor * set_primary
  | Set_Op_Primary of set_primary

and set_primary =
  | Set_Op_Paren   of set_operation
  | Set_Op_Var     of string

and answer_item =
  | A_Var   of variable

and vector_list = 
  | Vector_List_Cons of string * set_enum * vector_list
  | Vector_List_Last of string * set_enum

and vector_prob_list =
  | Vector_Prob_List_Cons of vector_prob * vector_prob_list
  | Vector_Prob_List_Last of vector_prob

and vector_prob =
  | Dot_Product of string * string * set_enum * set_enum
  | Cross_Product of string * string * set_enum * set_enum
  | Vector_Norm of string * set_enum
  | Unit_Vector of string * set_enum
  | Parallel_Vectors of string * set_enum
  | Same_Dir_Vectors of string * set_enum

(* ------------------- NEW CODE START ------------------- *)
and function_expr =
  | Linear_Fun     of linear_function
  | Quadratic_Fun  of quadratic_function
  | Power_Fun      of power_function
  | Radical_Fun    of radical_function
  | Rational_Fun   of rational_function
  | Log_Fun        of log_function
  | Trig_Fun       of trig_function
  | Exp_Fun        of exp_function

and linear_function =
  | Fun_Add_Int     of fun_or_var * int
  | Fun_Sub_Int     of fun_or_var * int
  | Int_Sub_Fun     of int * fun_or_var
  | Int_Mul_Fun     of int * fun_or_var
  | Fun_Mul_Int     of fun_or_var * int

and quadratic_function =
  | Quad_Add    of fun_or_var * int * fun_or_var * int
  | Quad_Sub    of fun_or_var * int * fun_or_var * int
  | Quad_Square of fun_or_var

and power_function = Power_Fun_Int of fun_or_var * int

and radical_function =
  | Radi_Sqrt of fun_or_var
  | Radi_Root of fun_or_var * int

and rational_function =
  | Fun_Div_Int   of fun_or_var * int
  | Int_Div_Fun   of int * fun_or_var

and log_function = Ln_Fun of fun_or_var

and trig_function =
  | Trig_Sin of fun_or_var
  | Trig_Cos of fun_or_var

and exp_function = Exp of fun_or_var

and fun_or_var =
  | Func of function_expr
  | Var_X

and derivative_prob_list =
  | Derivative_Prob_List_Cons of derivative_prob * derivative_prob_list
  | Derivative_Prob_List_Last of derivative_prob

and derivative_prob =
  | First_Derivative    of string
  | Derivative_Algebra  of int * string * int
  | Second_Derivative   of string

(* ------------------- NEW CODE END ------------------- *)

(* ================================================================ *)
(* ============== Propositional Logic Types ======================== *)
(* ================================================================ *)

and prop_variable = string  (* "P", "Q", "R", "S" *)

and prop_expr =
  | Prop_Var        of prop_variable
  | Prop_True
  | Prop_False
  | Prop_Not        of prop_expr
  | Prop_And        of prop_expr * prop_expr
  | Prop_Or         of prop_expr * prop_expr
  | Prop_Imp        of prop_expr * prop_expr  (* Implication: P -> Q *)
  | Prop_Equiv      of prop_expr * prop_expr  (* Equivalence: P <-> Q *)

and prop_equiv_rule =
  | Rule_Implication       (* P -> Q  <->  ¬P ∨ Q *)
  | Rule_DeMorgan_And     (* ¬(P ∧ Q)  <->  ¬P ∨ ¬Q *)
  | Rule_DeMorgan_Or      (* ¬(P ∨ Q)  <->  ¬P ∧ ¬Q *)
  | Rule_Double_Neg       (* ¬¬P  <->  P *)
  | Rule_Idempotent_And   (* P ∧ P  <->  P *)
  | Rule_Idempotent_Or    (* P ∨ P  <->  P *)
  | Rule_Comm_And         (* P ∧ Q  <->  Q ∧ P *)
  | Rule_Comm_Or          (* P ∨ Q  <->  Q ∨ P *)
  | Rule_Assoc_And        (* (P ∧ Q) ∧ R  <->  P ∧ (Q ∧ R) *)
  | Rule_Assoc_Or         (* (P ∨ Q) ∨ R  <->  P ∨ (Q ∨ R) *)
  | Rule_Distrib_And_Or   (* P ∧ (Q ∨ R)  <->  (P ∧ Q) ∨ (P ∧ R) *)
  | Rule_Distrib_Or_And   (* P ∨ (Q ∧ R)  <->  (P ∨ Q) ∧ (P ∨ R) *)
  | Rule_Absorption_And   (* P ∧ (P ∨ Q)  <->  P *)
  | Rule_Absorption_Or    (* P ∨ (P ∧ Q)  <->  P *)
  | Rule_Contrapositive   (* P -> Q  <->  ¬Q -> ¬P *)
  | Rule_Equiv_Def        (* (P -> Q) ∧ (Q -> P)  <->  P <-> Q *)

and prop_equiv_question =
  | Prop_Equiv_Judge of prop_expr * prop_expr * bool  (* judge if two exprs are equivalent, bool = answer (true/false) *)
  | Prop_Equiv_Choice of prop_expr * prop_expr * prop_expr list * int
                        (* given expr, equivalent expr, list of 3 wrong options, correct index *)

and prop_equiv_prob_list =
  | Prop_Equiv_Prob_List_Cons of prop_equiv_question * prop_equiv_prob_list
  | Prop_Equiv_Prob_List_Last of prop_equiv_question

(*
and solution_section = Solution of solution_list
and solution_list = solution_item list
and solution_item =
  | Sol_Correct of intext_call * string
*)
and intext_call =
  | IC_VarV  of variable
  | IC_Math  of math_expr

and math_expr =
  | ME_Add  of math_expr * term
  | ME_Sub  of math_expr * term
  | ME_Term of term

and term =
  | T_Mul of term * factor
  | T_Div of term * factor
  | T_Fac of factor

and factor =
  | F_Paren of math_expr
  | F_Num   of float
  | F_Int   of int
