(* print_pprint.ml *)
open PPrint
open Parser   (* bring DCST, CST, Settle into scope *)

class print = object (self)
  inherit [document] CST.reduce as super
  method zero = empty
  method cat  = (^^)
  method text s = string s

  (*───────────────────────────────────────────────────────────────────────*)
  (* basic combinators and defaults                                        *)
  method visit_DOCUMENT               = string "DOCUMENT"
  method visit_ENDDOCUMENT            = string "ENDDOCUMENT"

  method visit_LOADMACROS             = string "loadMacros"
  method visit_PGSTANDARD             = string "PGstandard.pl"
  method visit_MATHOBJECTS            = string "MathObjects.pl"
  method visit_PGML                   = string "PGML.pl"

  method visit_CONTEXT                = string "Context"

  method visit_BEGIN_PGML             = string "BEGIN_PGML"
  method visit_END_PGML               = string "END_PGML"
(*
  method visit_BEGIN_PGML_SOLUTION    = string "BEGIN_PGML_SOLUTION"
  method visit_END_PGML_SOLUTION      = string "END_PGML_SOLUTION"
*)
  method visit_COMMA                  = comma
  method visit_SEMI                   = semi
  method visit_LPAREN                 = lparen
  method visit_RPAREN                 = rparen

  method visit_LBRACE                 = string "{"
  method visit_RBRACE                 = string "}"

  method visit_NEWLINE                = hardline

  method visit_INT (i : int)          = string (string_of_int i)
  method visit_ID (id : string)       = string id
  method visit_NUMBER (n : float)     = let s =
                                          if n = floor n then
                                            (* no fractional part, print as integer *)
                                            string_of_int (int_of_float n)
                                          else
                                            (* has fractional part, print full float *)
                                            string_of_float n
                                        in
                                        string s
  method visit_MACRO (macro : string) = string macro

  method visit_WHAT_WORD           = string "What"
  method visit_VALUE_WORD          = string "value"
  method visit_OF_WORD             = string "of"
  method visit_TO_WORD             = string "to"
  method visit_THE_WORD            = string "the"
  method visit_IS_WORD             = string "is"
  method visit_EQUAL_WORD          = string "equal"
  method visit_ANSWER_WORD         = string "answer"
  method visit_WIDTH_WORD          = string "width"
  (*method visit_CORRECT_WORD   = string "Correct"*)

  method visit_SET_METH            = string "set"
  method visit_ADD_METH            = string "add"
  method visit_ARE_METH            = string "are"
  method visit_UNDEFINE_METH       = string "undefine"
  method visit_REDEFINE_METH       = string "redefine"

  method visit_RANDOM_METH         = string "random"
  method visit_FORMULA_METH        = string "Formula"
  method visit_REAL_METH           = string "Real"
  method visit_D_METH              = string "D"
  method visit_EVAL_METH           = string "eval"
  method visit_WITH_METH           = string "with"
  method visit_SET_DEF_METH        = string "Set"
  method visit_COMPUTE_METH        = string "Compute"
  method visit_INTERSECT_METH      = string "intersect"
  method visit_NORM_METH      = string "norm"
  method visit_UNIT_METH      = string "unit"

  method visit_NAMING         = string "$"
  method visit_COLON          = string ":"
  method visit_QUESTION_MARK  = string "?"
  method visit_FAT_COMMA      = string "=>"
  method visit_ARROW          = string "->"

  method visit_DOUBLE_QUOTE   = string "\"" 
  method visit_SINGLE_QUOTE   = string "\'"

  method visit_ADD_OP         = string "+"
  method visit_SUB_OP         = string "-"
  method visit_MUL_OP         = string "*"
  method visit_DIV_OP         = string "/"
  (* ------------------- NEW CODE START ------------------- *)
  method visit_POWER_OP       = string "^"
  method visit_SQRT_OP        = string "sqrt"
  method visit_LN_OP          = string "ln"
  method visit_SIN_OP         = string "sin"
  method visit_COS_OP         = string "cos"
  (* ------------------- NEW CODE END ------------------- *)

  method visit_EQ             = string "="
  
  method visit_EOF            = string ""

  method visit_BLANK          = string "[_____]"

  method visit_IT_VAR_OPEN    = string "[`["
  method visit_IT_VAR_CLOSE   = string "]`]"
  method visit_IT_MATH_OPEN   = string "[`"
  method visit_IT_MATH_CLOSE  = string "`]"
  
  method visit_GIVEN_PROB     = string "Given the sets:"
  method visit_COMPUTE_PROB   = string "Compute:"
  method visit_EVALUATE_BOOL_PROB = string "Evaluate the Boolean expression:"
  method visit_WHEN_WORD      = string "When:"
  method visit_BOOL_ANSWER_HINT = string "Enter 1 for True and 0 for False."

  method visit_SUPPOSE_PROB       = string "Suppose the vectors:"
  method visit_PERIOD             = string "."
  method visit_VECTOR_UNIT_PROB   = string "Enter a unit vector in the direction of "
  method visit_VECTOR_PARA_PROB   = string "Enter a vector parallel to "
  method visit_VECTOR_SAME_PROB   = string "Enter a vector in the same direction as "
  (* ------------------- NEW CODE START ------------------- *)
  method visit_GIVEN_FUN          = string "Given this function:"
  (* ------------------- NEW CODE END ------------------- *)

  method visit_UNION          = string "U"
  method visit_CUP            = string "\\cup"
  method visit_CAP            = string "\\cap"
  method visit_GT             = string ">"
  method visit_LT             = string "<"
  method visit_GEQ_LATEX      = string "\\geq"
  method visit_LEQ_LATEX      = string "\\leq"
  method visit_X_VAR          = string "x"
  (* ------------------- NEW CODE START ------------------- *)
  method visit_F_FUN          = string "f"
  method visit_NAT_LOG        = string "e"
  (* ------------------- NEW CODE END ------------------- *)
  method visit_LBRACE_LATEX   = string "\\{"
  method visit_RBRACE_LATEX   = string "\\}"
  method visit_PIPE           = string "|"
  method visit_LBRACKET       = string "["
  method visit_RBRACKET       = string "]"
  method visit_INFINITY       = string "infinity"
  method visit_NEG_INFINITY   = string "-infinity"

  method visit_VEC_LATEX      = string "\\vec"
  method visit_LANGLE_LATEX   = string "\\langle"
  method visit_RANGLE_LATEX   = string "\\rangle"
  method visit_CDOT_LATEX     = string "\\cdot"
  method visit_TIMES_LATEX    = string "\\times"
  method visit_LEFT_NORM_LATEX   = string "\\left\\|"
  method visit_RIGHT_NORM_LATEX  = string "\\right\\|"

  method visit_CMP_1          = string "cmp(parallel=>1)"
  method visit_CMP_2          = string "cmp(parallel=>1,sameDirection=>1)"
  method visit_TRUE_WORD      = string "True"
  method visit_FALSE_WORD     = string "False"
  method visit_AND_WORD       = string "AND"
  method visit_OR_WORD        = string "OR"
  method visit_NOT_WORD       = string "NOT"
  method visit_XOR_WORD       = string "XOR"
  method visit_IMPLIES_WORD   = string "IMPLIES"
  method visit_IFF_WORD       = string "IFF"

  (*────────────────────────────────────────────────────────────────────────*)
  (* document variants                                                      *)
  method! case_doc_no_sol
      hdr ctx prob =
    let hdr_doc  = super#visit_header hdr in
    let ctx_doc  = super#visit_context_setup_list ctx in
    let prob_doc = super#visit_problem_section prob in
    group (
      self#visit_DOCUMENT ^^ lparen ^^ rparen ^^ semi ^^ hardline
      ^^ hdr_doc
      ^^ ctx_doc
      ^^ prob_doc
      ^^ self#visit_ENDDOCUMENT ^^ lparen ^^ rparen ^^ semi ^^ hardline
    )

  (*─────────────────────────────────────────────────────────────────────────*)
  (* header                                                                  *)
  method! case_header_simple 
      () = 
    string "loadMacros(" ^^ hardline
    ^^ self#visit_DOUBLE_QUOTE ^^ self#visit_PGSTANDARD ^^ self#visit_DOUBLE_QUOTE ^^ comma ^^ hardline
    ^^ self#visit_DOUBLE_QUOTE ^^ self#visit_MATHOBJECTS ^^ self#visit_DOUBLE_QUOTE ^^ comma ^^ hardline
    ^^ self#visit_DOUBLE_QUOTE ^^ self#visit_PGML ^^ self#visit_DOUBLE_QUOTE ^^ hardline
    ^^ string ");" ^^ hardline

  method! case_header_with_macro
      mac =
    let mac_doc = super#visit_macro mac in
    string "loadMacros(" ^^ hardline
    ^^ self#visit_DOUBLE_QUOTE ^^ self#visit_PGSTANDARD ^^ self#visit_DOUBLE_QUOTE ^^ comma ^^ hardline
    ^^ self#visit_DOUBLE_QUOTE ^^ self#visit_MATHOBJECTS ^^ self#visit_DOUBLE_QUOTE ^^ comma ^^ hardline
    ^^ self#visit_DOUBLE_QUOTE ^^ self#visit_PGML ^^ self#visit_DOUBLE_QUOTE ^^ comma ^^ hardline
    ^^ mac_doc
    ^^ string ");" ^^ hardline

  (*─────────────────────────────────────────────────────────────────────────*)
  (* macro                                                                   *)
  method! case_macro_atom
      name =
    string ("\"" ^ name ^ "\"") ^^ hardline

  method! case_macro_cons
      name rest =
    let rest_doc = super#visit_macro rest in
    string ("\"" ^ name ^ "\"") ^^ comma ^^ hardline ^^ rest_doc

  (*─────────────────────────────────────────────────────────────────────────*)
  (* context_setup_list                                                      *)
  method! case_ctx_setup_vars_last
      ctx ansv =
    super#visit_context_setup ctx ^^ hardline
    ^^ super#visit_answer_vars ansv ^^ hardline

  method! case_ctx_setup_vars_cons
      ctx ansv ctx_list =
    super#visit_context_setup ctx ^^ hardline
    ^^ super#visit_answer_vars ansv ^^ hardline
    ^^ super#visit_context_setup_list ctx_list
  
  method! case_ctx_setup_no_vars_last
      ctx =
    super#visit_context_setup ctx ^^ hardline

  method! case_ctx_setup_no_vars_cons
      ctx ctx_list =
    super#visit_context_setup ctx ^^ hardline 
    ^^ super#visit_context_setup_list ctx_list

  method! case_ctx_only
      cname =
    string "Context(" ^^ string ("\"" ^ cname ^ "\"") ^^ string ");" ^^ hardline

  method! case_ctx_with_cfg
      cname cfg =
    let cfg_doc = super#visit_context_config cfg in
    string "Context(" 
    ^^ string ("\"" ^ cname ^ "\"") 
    ^^ string ");" ^^ hardline
    ^^ cfg_doc

  (*─────────────────────────────────────────────────────────────────────────*)
  (* context_config                                                          *)
  method! case_cfg_last
      modl cm =
    let modl_doc = super#visit_module_ modl in
    let cm_doc   = super#visit_context_method cm in
    string "Context()->" 
    ^^ modl_doc
    ^^ string "->"
    ^^ cm_doc
    ^^ semi ^^ hardline

  method! case_cfg_cons
      modl cm rest =
    let modl_doc = super#visit_module_ modl in
    let cm_doc   = super#visit_context_method cm in
    let rest_doc = super#visit_context_config rest in
    string "Context()->" 
    ^^ modl_doc
    ^^ string "->"
    ^^ cm_doc
    ^^ semi ^^ hardline
    ^^ rest_doc

  (*─────────────────────────────────────────────────────────────────────────*)
  (* context_method                                                          *)
  method! case_cm_add
      entries =
    string "add(" ^^ super#visit_entry_list entries ^^ string ")"

  method! case_cm_set
      entries =
    string "set(" ^^ super#visit_entry_list entries ^^ string ")"

  method! case_cm_are 
      entries = 
    string "are(" ^^ super#visit_entry_list entries ^^ string ")"

  method! case_cm_undefine 
      ops = 
    string "undefine(" ^^ super#visit_operator_list ops ^^ string ")"

  method! case_cm_redefine 
      ops = 
    string "redefine(" ^^ super#visit_operator_list ops ^^ string ")"

  (*─────────────────────────────────────────────────────────────────────────*)
  (* entry, properties, property                                             *)
  method! case_entry_prop
      prop =
    super#visit_property prop

  method! case_entry_map_none
      key = 
    let key_doc   = super#visit_key        key   in
    key_doc ^^ string "=>" ^^ string "{}"

  method! case_entry_map
      key props =
    let key_doc   = super#visit_key        key   in
    let props_doc = super#visit_properties props in
    key_doc ^^ string "=>" ^^ lbrace
    ^^ props_doc
    ^^ rbrace

  method! case_property
      key value =
    super#visit_key   key   ^^
    string "=>"             ^^
    super#visit_value value
  
  (*─────────────────────────────────────────────────────────────────────────*)
  (* key & value                                                             *)
  method! case_key_ident  id    = string id
  method! case_key_str s        = string s

  method! case_value_int_pos i     = string (string_of_int i)
  method! case_value_int_neg i     = string (string_of_int i)
  method! case_value_num_pos n     = string (string_of_float n)
  method! case_value_num_neg n     = string (string_of_float n)
  method! case_value_str_dou s     = string ("\"" ^ s ^ "\"")
  method! case_value_ident   id    = string "$" ^^ string id

  (*─────────────────────────────────────────────────────────────────────────*)
  (* answer_vars & variable_list                                             *)
  method! case_answer_vars
      vlist =
    super#visit_variable_list vlist

  method! case_var_list
      hd tl =
    let hd_doc = super#visit_variable_declaration hd in
    let tl_doc = super#visit_variable_list tl in
    hd_doc ^^ hardline ^^ tl_doc

  method! case_var_list_single
      vd =
    super#visit_variable_declaration vd ^^ hardline

  method! case_var_decl
      id v =
    string "$" ^^ string id ^^ string " = " ^^ super#visit_variable v ^^ semi
    
  method! case_var_value
      v =
    super#visit_value v

  method! case_var_meth 
      m =
    super#visit_math_object_method m

  method! case_var_field 
      id m =
    string "$" ^^ string id ^^ string "->" ^^ super#visit_math_object_method m

  method! case_var_chain 
      m1 m2 =
    super#visit_math_object_method m1 ^^ string "->" ^^ super#visit_math_object_method m2

  (*─────────────────────────────────────────────────────────────────────────*)
  (* math object methods                                                     *)
  method! case_meth_rand
      a b c =
    string "random(" ^^ string (string_of_int a) ^^ comma
    ^^ string (string_of_int b) ^^ comma
    ^^ string (string_of_int c) ^^ string ")"

  method! case_meth_form
      s    = 
      string "Formula(" ^^ string "\'" ^^ (super#visit_math_expr s) ^^ string "\'" ^^ string ")"

  (* ------------------- NEW CODE START ------------------- *)
  method! case_meth_form_fun
      s    = 
      string "Formula(" ^^ string "\"" ^^ (super#visit_function_expr s) ^^ string "\"" ^^ string ")"
  (* ------------------- NEW CODE END ------------------- *)

  method! case_meth_real
      v    = 
      string "Real(" ^^ self#visit_value v ^^ string ")"

  method! case_meth_d_none
      ()   = 
      string "D()"

  method! case_meth_d
      u    = 
      string "D('" ^^ string u ^^ string "')"

  method! case_meth_eval
      p    = 
      string "eval(" ^^ super#visit_property p ^^ string ")"

  method! case_meth_with
      p    = 
      string "with(" ^^ super#visit_property p ^^ string ")"

  method! case_meth_set
      enum =
    string "Set(" ^^ super#visit_set_enum enum ^^ string ")"

  method! case_meth_compute
      comp =
    string "Compute(" ^^ string "\"" ^^ super#visit_set_compute comp ^^ string "\"" ^^ string ")"

  method! case_meth_intersect
      var =
    string "intersect(" ^^ super#visit_variable var ^^ string ")"

  (*─────────────────────────────────────────────────────────────────────────*)
  (* problem_section & questions                                             *)
  method! case_problem_section
      qs =
    string "BEGIN_PGML" ^^ hardline
    ^^ string "# Questions:" ^^ hardline ^^ hardline
    ^^ string "- _For arithmetic problems, if the result is not an integer, then retain *three significant digits*._" ^^ hardline
    ^^ string "- _For derivative problems, if the result is undefined, then *leave the blank empty*._" ^^ hardline ^^ hardline
    ^^ super#visit_question_list qs
    ^^ string "END_PGML" ^^ hardline

  method! case_qlist
      head tail =
    let head_doc = super#visit_question_item head in
    let tail_doc = super#visit_question_list tail in
    head_doc ^^ hardline ^^ hardline ^^ tail_doc

  method! case_qlist_single
      item = 
    super#visit_question_item item ^^ hardline

  method! case_qitem1
      qt   (* : CST.question_text *)
      ans  (* : CST.answer_item  *) =
    super#visit_question_text qt
    ^^ self#visit_BLANK
    ^^ string "{"
    ^^ super#visit_answer_item  ans
    ^^ string "}"
    ^^ hardline ^^ string "---"

  method! case_qitem2
      qt   (* : CST.question_text *)
      ans  (* : CST.answer_item  *)
      w    (* : float            *) =
    super#visit_question_text qt
    ^^ self#visit_BLANK
    ^^ string "{answer=>"
    ^^ super#visit_answer_item ans
    ^^ string ",width=>"
    ^^ string (string_of_int w)
    ^^ string "}"
    ^^ hardline ^^ string "---"

  method! case_qset
      s_list sp_list =
    self#visit_GIVEN_PROB ^^ hardline
    ^^ super#visit_set_list s_list ^^ hardline
    ^^ self#visit_COMPUTE_PROB ^^ hardline
    ^^ super#visit_set_prob_list sp_list

  method! case_qvector
      vec_list vecp_list =
    self#visit_SUPPOSE_PROB ^^ hardline
    ^^ super#visit_vector_list vec_list ^^ hardline
    ^^ self#visit_COMPUTE_PROB ^^ hardline
    ^^ super#visit_vector_prob_list vecp_list

  (* ------------------- NEW CODE START ------------------- *)
  method! case_qderivative
      fun_name derp_list =
    self#visit_GIVEN_FUN ^^ hardline ^^ hardline
     ^^ string ">> [`[$" ^^ string fun_name ^^ string "]`] <<" ^^ hardline ^^ hardline
    ^^ self#visit_COMPUTE_PROB ^^ hardline
    ^^ super#visit_derivative_prob_list derp_list
  (* ------------------- NEW CODE END ------------------- *)

  method! case_qbool_eval
      expr assignments ans =
    self#visit_EVALUATE_BOOL_PROB ^^ hardline
    ^^ self#visit_IT_MATH_OPEN ^^ super#visit_bool_expr expr ^^ self#visit_IT_MATH_CLOSE ^^ hardline
    ^^ self#visit_WHEN_WORD ^^ hardline
    ^^ super#visit_bool_assignment_list assignments
    ^^ self#visit_BOOL_ANSWER_HINT ^^ hardline
    ^^ self#visit_BLANK
    ^^ string "{"
    ^^ super#visit_answer_item ans
    ^^ string "}"
    ^^ hardline ^^ string "---"

  method! case_qbool_eval_width
      expr assignments ans w =
    self#visit_EVALUATE_BOOL_PROB ^^ hardline
    ^^ self#visit_IT_MATH_OPEN ^^ super#visit_bool_expr expr ^^ self#visit_IT_MATH_CLOSE ^^ hardline
    ^^ self#visit_WHEN_WORD ^^ hardline
    ^^ super#visit_bool_assignment_list assignments
    ^^ self#visit_BOOL_ANSWER_HINT ^^ hardline
    ^^ self#visit_BLANK
    ^^ string "{answer=>"
    ^^ super#visit_answer_item ans
    ^^ string ",width=>"
    ^^ string (string_of_int w)
    ^^ string "}"
    ^^ hardline ^^ string "---"

  method! case_qvalue
      call =
    let call_doc = super#visit_intext_call call in
    string "What is the value of " ^^ call_doc ^^ string "? "

  method! case_qis
      call =
    let call_doc = super#visit_intext_call call in
    call_doc ^^ string " is equal to "

  (*─────────────────────────────────────────────────────────────────────────*)
  (* answer_item                                                             *)
  method! case_ans_var
      v = super#visit_variable v

  (*──────────────────────────────────────────────────────────────────────────*)
  (* solution_section & items                                                 *)
(*
  method! case_solution_section
      items =
    string "BEGIN_PGML_SOLUTION" ^^ hardline
    ^^ super#visit_solution_list items
    ^^ hardline ^^ string "END_PGML_SOLUTION"

  method! case_slist
      item rest =
    super#visit_solution_item item
    ^^ hardline ^^ hardline
    ^^ super#visit_solution_list rest

  method! case_slist_single
      item =
    super#visit_solution_item item

  method! case_sol_item
      (ans  : CST.intext_call)
      (txt  : string) =
      string "Correct answer: "
      ^^ super#visit_intext_call ans
      ^^ hardline
      ^^ string txt
*)
  (*─────────────────────────────────────────────────────────────────────────*)
  (* intext_call                                                             *)
  method! case_ict_varv
      v =
    string "[`[" ^^ super#visit_variable v ^^ string "]`]"

  method! case_ict_math
      expr =
    string "[`" ^^ super#visit_math_expr expr ^^ string "`]"

  (*─────────────────────────────────────────────────────────────────────────*)
  (* Boolean expression evaluation printing methods                          *)
  method! case_bool_assignment_list_cons
      assignment rest =
    super#visit_bool_assignment assignment ^^ hardline
    ^^ super#visit_bool_assignment_list rest

  method! case_bool_assignment_list_last
      assignment =
    super#visit_bool_assignment assignment ^^ hardline

  method! case_bool_assignment_true
      name =
    string "- " ^^ string name ^^ string " = True"

  method! case_bool_assignment_false
      name =
    string "- " ^^ string name ^^ string " = False"

  method! case_bool_and
      left right =
    lparen ^^ super#visit_bool_expr left ^^ string " AND " ^^ super#visit_bool_expr right ^^ rparen

  method! case_bool_or
      left right =
    lparen ^^ super#visit_bool_expr left ^^ string " OR " ^^ super#visit_bool_expr right ^^ rparen

  method! case_bool_xor
      left right =
    lparen ^^ super#visit_bool_expr left ^^ string " XOR " ^^ super#visit_bool_expr right ^^ rparen

  method! case_bool_implies
      left right =
    lparen ^^ super#visit_bool_expr left ^^ string " IMPLIES " ^^ super#visit_bool_expr right ^^ rparen

  method! case_bool_iff
      left right =
    lparen ^^ super#visit_bool_expr left ^^ string " IFF " ^^ super#visit_bool_expr right ^^ rparen

  method! case_bool_not
      expr =
    lparen ^^ string "NOT " ^^ super#visit_bool_expr expr ^^ rparen

  method! case_bool_paren
      expr =
    lparen ^^ super#visit_bool_expr expr ^^ rparen

  method! case_bool_true
      () =
    string "True"

  method! case_bool_false
      () =
    string "False"

  method! case_bool_var
      name =
    string name

  (*─────────────────────────────────────────────────────────────────────────*)
  (* math_expr, term, factor                                                 *)
  method! case_madd
      l r =
    super#visit_math_expr l
    ^^ string "+"
    ^^ super#visit_term r

  method! case_msub
      l r =
    super#visit_math_expr l
    ^^ string "-"
    ^^ super#visit_term r

  method! case_mterm
      t =
    super#visit_term t

  method! case_tmul
      l f =
    super#visit_term l
    ^^ string "*"
    ^^ super#visit_factor f

  method! case_tdiv
      l f =
    super#visit_term l
    ^^ string "/"
    ^^ super#visit_factor f

  method! case_tfac
      f =
    super#visit_factor f

  method! case_fparen
      e =
    lparen ^^ super#visit_math_expr e ^^ rparen

  method! case_fnum
      n =
    string (string_of_float n)

  method! case_fint
      i =
    string (string_of_int i)

(*─────────────────────────────────────────────────────────────────────────*)
(* Set-related printing methods                                            *)
  method! case_set_list_cons
      var expr rest =
    string "- [`" ^^ string var ^^ string " = \\{" ^^ super#visit_set_expr expr ^^ string "\\}`]" ^^ hardline
    ^^ super#visit_set_list rest

  method! case_set_list_last
      var expr =
    string "- [`" ^^ string var ^^ string " = \\{" ^^ super#visit_set_expr expr ^^ string "\\}`]" ^^ hardline

  method! case_set_expr_enum
      enum =
    super#visit_set_enum enum

  method! case_set_expr_interval
      interval =
    super#visit_set_interval interval

  method! case_set_enum_cons
      i rest =
    super#visit_int_with_sign i ^^ string "," ^^ space ^^ super#visit_set_enum rest

  method! case_set_enum_last
      i =
    super#visit_int_with_sign i

  method! case_set_interval
      pred =
    string "x | " ^^ super#visit_predicate pred

  method! case_pred_gt
      i =
    string "x > " ^^ super#visit_int_with_sign i

  method! case_pred_lt
      i =
    string "x < " ^^ super#visit_int_with_sign i

  method! case_pred_geq
      i =
    string "x \\geq " ^^ super#visit_int_with_sign i

  method! case_pred_leq
      i =
    string "x \\leq " ^^ super#visit_int_with_sign i

  method! case_pred_between_open
      i1 i2 =
    super#visit_int_with_sign i1 ^^ string " < x < " ^^ super#visit_int_with_sign i2

  method! case_pred_between_left_closed
      i1 i2 =
    super#visit_int_with_sign i1 ^^ string " \\leq x < " ^^ super#visit_int_with_sign i2

  method! case_pred_between_right_closed
      i1 i2 =
    super#visit_int_with_sign i1 ^^ string " < x \\leq " ^^ super#visit_int_with_sign i2

  method! case_pred_between_closed
      i1 i2 =
    super#visit_int_with_sign i1 ^^ string " \\leq x \\leq " ^^ super#visit_int_with_sign i2

  method! case_set_prob_list_cons
      op ans rest =
    string "- [`" ^^ super#visit_set_operation op ^^ string " = `] [_____]{" ^^ super#visit_answer_item ans ^^ string "}" ^^ hardline
    ^^ super#visit_set_prob_list rest

  method! case_set_prob_list_last
      op ans =
    string "- [`" ^^ super#visit_set_operation op ^^ string " = `] [_____]{" ^^ super#visit_answer_item ans ^^ string "}" ^^ hardline
    ^^ hardline ^^ string "---"

  method! case_set_op_union
      op term =
    super#visit_set_operation op ^^ string " \\cup " ^^ super#visit_set_term term

  method! case_set_op_term
      term =
    super#visit_set_term term

  method! case_set_op_inter
      term factor =
    super#visit_set_term term ^^ string " \\cap " ^^ super#visit_set_factor factor

  method! case_set_op_factor
      factor =
    super#visit_set_factor factor

  method! case_set_op_diff
      factor primary =
    super#visit_set_factor factor ^^ string " - " ^^ super#visit_set_primary primary

  method! case_set_op_primary
      primary =
    super#visit_set_primary primary

  method! case_set_primary_paren
      op =
    string "(" ^^ super#visit_set_operation op ^^ string ")"

  method! case_set_primary_var
      var =
    string var

  method! case_set_compute_union
      comp term =
    super#visit_set_compute comp ^^ string " U " ^^ super#visit_set_compute_term term

  method! case_set_compute_term
      term =
    super#visit_set_compute_term term

  method! case_set_compute_diff
      term factor =
    super#visit_set_compute_term term ^^ string " - " ^^ super#visit_set_compute_factor factor

  method! case_set_compute_factor
      factor =
    super#visit_set_compute_factor factor

  method! case_set_compute_paren
      comp =
    string "(" ^^ super#visit_set_compute comp ^^ string ")"

  method! case_set_compute_enum
      enum =
    string "{" ^^ super#visit_set_enum enum ^^ string "}"

  method! case_set_compute_interval
      interval =
    super#visit_set_compute_interval interval

  method! case_set_compute_interval_open
      l r =
    string "(" ^^ super#visit_interval_value l ^^ string "," ^^ space ^^ super#visit_interval_value r ^^ string ")"

  method! case_set_compute_interval_left_open
      l r =
    string "(" ^^ super#visit_interval_value l ^^ string "," ^^ space ^^ super#visit_interval_value r ^^ string "]"

  method! case_set_compute_interval_right_open
      l r =
    string "[" ^^ super#visit_interval_value l ^^ string "," ^^ space ^^ super#visit_interval_value r ^^ string ")"

  method! case_set_compute_interval_closed
      l r =
    string "[" ^^ super#visit_interval_value l ^^ string "," ^^ space ^^ super#visit_interval_value r ^^ string "]"

  method! case_interval_int
      i =
    super#visit_int_with_sign i

  method! case_interval_infinity
      () =
    string "infinity"

  method! case_interval_neg_infinity
      () =
    string "-infinity"

(*─────────────────────────────────────────────────────────────────────────*)
(* Vector-related printing methods                                         *)
  method! case_vec_list_cons
      var expr rest =
    string "- [` \\vec{" ^^ string var ^^ string "} = \\langle " ^^ super#visit_set_enum expr ^^ string " \\rangle `]" ^^ hardline
    ^^ super#visit_vector_list rest

  method! case_vec_list_last
      var expr =
    string "- [` \\vec{" ^^ string var ^^ string "} = \\langle " ^^ super#visit_set_enum expr ^^ string " \\rangle `]" ^^ hardline

  method! case_vec_prob_list_cons
      vec_prob rest =
    string "- " ^^ super#visit_vector_prob vec_prob ^^ hardline
    ^^ super#visit_vector_prob_list rest

  method! case_vec_prob_list_last
      vec_prob =
    string "- " ^^ super#visit_vector_prob vec_prob ^^ hardline
    ^^ hardline ^^ string "---"

  method! case_vec_prob_1
      var1 var2 vec1 vec2 =
    string "[` \\vec{" 
    ^^ string var1 
    ^^ string "} \\cdot \\vec{" 
    ^^ string var2 
    ^^ string "} = `] [_____]{Compute(\"<" 
    ^^ super#visit_set_enum vec1 ^^ string ">\") . Compute(\"<" 
    ^^ super#visit_set_enum vec2 ^^ string ">\")}"

  method! case_vec_prob_2
      var1 var2 vec1 vec2 =
    string "[` \\vec{" 
    ^^ string var1 
    ^^ string "} \\times \\vec{" 
    ^^ string var2 
    ^^ string "} = `] [_____]{Compute(\"<" 
    ^^ super#visit_set_enum vec1 ^^ string ">\") x Compute(\"<" 
    ^^ super#visit_set_enum vec2 ^^ string ">\")}"

  method! case_vec_prob_3
      var vec =
    string "[` \\left\\| \\vec{" 
    ^^ string var 
    ^^ string "} \\right\\| = `] [_____]{norm(Compute(\"<" 
    ^^ super#visit_set_enum vec 
    ^^ string ">\"))}"

  method! case_vec_prob_4
      var vec =
    string "Enter a unit vector in the direction of [` \\vec{" 
    ^^ string var 
    ^^ string "} `]. [_____]{unit(Compute(\"<" 
    ^^ super#visit_set_enum vec 
    ^^ string ">\"))}"

  method! case_vec_prob_5
      var vec =
    string "Enter a vector parallel to [` \\vec{" 
    ^^ string var 
    ^^ string "} `]. [_____]{Compute(\"<" 
    ^^ super#visit_set_enum vec  
    ^^ string ">\")->cmp(parallel=>1)}"
  
  method! case_vec_prob_6
      var vec =
    string "Enter a vector in the same direction as [` \\vec{" 
    ^^ string var 
    ^^ string "} `]. [_____]{Compute(\"<" 
    ^^ super#visit_set_enum vec  
    ^^ string ">\")->cmp(parallel=>1,sameDirection=>1)}"

  method! case_negative_int
      i = string (string_of_int i)

  method! case_positive_int
      i = string (string_of_int i)

(* ------------------- NEW CODE START ------------------- *)
(*─────────────────────────────────────────────────────────────────────────*)
(* Function (Derivative)-related printing methods                          *)
  method! case_linear_fun func =
    super#visit_linear_function func

  method! case_quadratic_fun func =
    super#visit_quadratic_function func

  method! case_power_fun func =
    super#visit_power_function func

  method! case_radical_fun func =
    super#visit_radical_function func

  method! case_rational_fun func =
    super#visit_rational_function func

  method! case_trig_fun func =
    super#visit_trig_function func

  method! case_log_fun func =
    super#visit_log_function func

  method! case_exp_fun func =
    super#visit_exp_function func

  method! case_fun_add_int 
    f_or_v i = 
      self#visit_fun_or_var f_or_v ^^ self#visit_ADD_OP ^^ self#visit_INT i
  
  method! case_fun_sub_int 
    f_or_v i = 
      self#visit_fun_or_var f_or_v ^^ self#visit_SUB_OP ^^ self#visit_INT i
  
  method! case_int_sub_fun 
    i f_or_v = 
      self#visit_INT i ^^ self#visit_SUB_OP ^^ self#visit_fun_or_var f_or_v

  method! case_int_mul_fun 
    i f_or_v = 
      self#visit_INT i ^^ self#visit_MUL_OP ^^ self#visit_fun_or_var f_or_v

  method! case_fun_mul_int 
    f_or_v i = 
      self#visit_fun_or_var f_or_v ^^ self#visit_MUL_OP ^^ self#visit_INT i

  method! case_quad_add 
    f_or_v1 i1 i0 f_or_v2 i2 = 
      self#visit_fun_or_var f_or_v1 ^^ self#visit_POWER_OP ^^ string "2" 
      ^^ self#visit_ADD_OP ^^ self#visit_INT i1 ^^ self#visit_MUL_OP 
      ^^ self#visit_fun_or_var f_or_v2 ^^ self#visit_ADD_OP ^^ self#visit_INT i2

  method! case_quad_sub 
    f_or_v1 i1 i0 f_or_v2 i2 = 
      self#visit_fun_or_var f_or_v1 ^^ self#visit_POWER_OP ^^ string "2" 
      ^^ self#visit_SUB_OP ^^ self#visit_INT i1 ^^ self#visit_MUL_OP 
      ^^ self#visit_fun_or_var f_or_v2 ^^ self#visit_ADD_OP ^^ self#visit_INT i2

  method! case_quad_square
    f_or_v i0 =
      lparen ^^ self#visit_fun_or_var f_or_v ^^ rparen ^^ self#visit_POWER_OP ^^ string "2"

  method! case_power_fun_int_expr 
    f_or_v i = 
      self#visit_fun_or_var f_or_v ^^ self#visit_POWER_OP ^^ self#visit_INT i

  method! case_radi_sqrt 
    f_or_v = 
      self#visit_SQRT_OP ^^ lparen ^^ self#visit_fun_or_var f_or_v ^^ rparen

  method! case_radi_root 
    f_or_v i0 i = 
        lparen ^^ self#visit_fun_or_var f_or_v ^^ rparen ^^ self#visit_POWER_OP 
        ^^ lparen ^^ string "1" ^^ self#visit_DIV_OP ^^ self#visit_INT i ^^ rparen

  method! case_fun_div_int 
    f_or_v i =
      self#visit_fun_or_var f_or_v ^^ self#visit_DIV_OP ^^ self#visit_INT i

  method! case_int_div_fun 
    i f_or_v =
      self#visit_INT i ^^ self#visit_DIV_OP ^^ lparen ^^ self#visit_fun_or_var f_or_v ^^ rparen

  method! case_ln_fun 
    f_or_v = 
      self#visit_LN_OP ^^ lparen ^^ self#visit_fun_or_var f_or_v ^^ rparen

  method! case_trig_sin 
    f_or_v = 
      self#visit_SIN_OP ^^ lparen ^^ self#visit_fun_or_var f_or_v ^^ rparen
    
  method! case_trig_cos 
    f_or_v = 
      self#visit_COS_OP ^^ lparen ^^ self#visit_fun_or_var f_or_v ^^ rparen

  method! case_exp 
    f_or_v = 
      self#visit_NAT_LOG ^^ self#visit_POWER_OP ^^ lparen ^^ self#visit_fun_or_var f_or_v ^^ rparen

  method! case_var_x () = self#visit_X_VAR

  method! case_func func = 
    lparen ^^ self#visit_function_expr func ^^ rparen
  
  method! case_der_prob_list_cons
      der_prob rest =
    string "- " ^^ super#visit_derivative_prob der_prob ^^ hardline
    ^^ super#visit_derivative_prob_list rest

  method! case_der_prob_list_last
      der_prob =
    string "- " ^^ super#visit_derivative_prob der_prob ^^ hardline
    ^^ hardline ^^ string "---"

  method! case_der_prob_1
      fun_name =
    string "[`f\'(x) =`] [_____]{$" 
    ^^ string fun_name 
    ^^ string "->D()}" 

  method! case_der_prob_2
      i1 fun_name i2 =
    string "[`f\'(" 
    ^^ string (string_of_int i1) 
    ^^ string ") =`] [_____]{$" 
    ^^ string fun_name 
    ^^ string "->D()->eval(x=>" 
    ^^ string (string_of_int i2) 
    ^^ string ")}"

  method! case_der_prob_3
      fun_name =
    string "[`f\'\'(x) =`] [_____]{$" 
    ^^ string fun_name 
    ^^ string "->D()->D()}"
(* ------------------- NEW CODE END ------------------- *)

end

let to_doc (cst : CST.main) : PPrint.document =
  (new print)#visit_main cst
