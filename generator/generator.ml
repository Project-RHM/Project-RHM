(* generator.ml *)
open Ast
open Semantic
open Config

(** Compute an int32 random seed from an id string *)
let seed_of_id (id:string) : int =
  let hex = Digest.to_hex (Digest.string id) in
  (* Take the first 8 hex digits and treat them as a 32-bit hex number *)
  let sub = String.sub hex 0 8 in
  (* Convert it to an int *)
  int_of_string ("0x" ^ sub)

(** Randomly select an element from a list *)
let pick lst =
  List.nth lst (Random.int (List.length lst))

(* pick one name out of a nonempty list *)
let pick_one lst =
  List.nth lst (Random.int (List.length lst))

let nth_or_default lst index default =
  try List.nth lst index with _ -> default

(* generate a macro‐tree without repeats *)
let rec gen_macro_from = function
  | [] -> failwith "internal error: no more macros to pick"
  | [x] ->
      (* only one left, must end here *)
      Macro_Atom x
  | choices ->
      let x = pick_one choices in
      (* remove x from the leftover choices *)
      let rest = List.filter ((<>) x) choices in
      if Random.bool () then
        (* stop here with a leaf *)
        Macro_Atom x
      else
        (* cons this one on and recurse on the remainder *)
        Macro_Cons (x, gen_macro_from rest)

(* Global counter for function names *)
let fun_counter = ref 0
let complex_counter = ref 0

(* Reset function counter *)
let reset_fun_counter () = fun_counter := 0
let reset_complex_counter () = complex_counter := 0

let rec int_pow base exponent =
  if exponent <= 0 then 1 else base * int_pow base (exponent - 1)

let random_between low high =
  if low > high then low else low + Random.int (high - low + 1)

let random_nonzero_between low high =
  if low = 0 && high = 0 then 1
  else
    let rec pick attempts =
      let value = random_between low high in
      if value <> 0 then value
      else if attempts > 100 then
        if low < 0 then low else high
      else
        pick (attempts + 1)
    in
    pick 0

let weighted_pick weighted_items =
  let positive_items = List.filter (fun (weight, _) -> weight > 0) weighted_items in
  match positive_items with
  | [] -> snd (List.hd weighted_items)
  | _ ->
      let total = List.fold_left (fun acc (weight, _) -> acc + weight) 0 positive_items in
      let target = Random.int total in
      let rec choose offset = function
        | [] -> snd (List.hd positive_items)
        | (weight, value) :: rest ->
            if target < offset + weight then value else choose (offset + weight) rest
      in
      choose 0 positive_items

(* ============================================================= *)
(* ============== Recursive Auxiliary Functions ================ *)
(* ============================================================= *)
(* For Math Expressions: *)
let rec gen_math_expr_root depth : math_expr =
  if depth <= 0 then
    (* Force at least two numbers by creating a simple addition *)
    ME_Add (ME_Term (gen_term 0), gen_term 0)
  else
    (* still allowed to nest one level deeper *)
    match Random.int 3 with
    | 0 -> ME_Add (gen_math_expr_root (depth-1), gen_term (depth-1))
    | 1 -> ME_Sub (gen_math_expr_root (depth-1), gen_term (depth-1))
    | _ ->
        (* Ensure we don't generate single-term expressions here either *)
        ME_Add (ME_Term (gen_term (depth-1)), gen_term (depth-1))

and gen_term depth : term =
  if depth <= 0 then
    T_Fac (gen_factor 0)
  else
    match Random.int 3 with
    | 0 -> T_Mul (gen_term (depth-1), gen_factor (depth-1))
    | 1 ->
        let divisor = gen_factor (depth-1) in
        if is_zero_factor divisor then
         (* re-generate both term and factor to avoid stuck in zero forever *)
          let t = gen_term (depth-1) in
          let d = gen_factor (depth-1) in
          T_Div (t, d)
        else
          T_Div (gen_term (depth-1), divisor)
    | _ -> T_Fac (gen_factor (depth-1))

and is_zero_factor = function
  | F_Int 0       -> true
  | F_Num x       -> x = 0.0
  | _             -> false

and gen_factor depth : factor =
  if depth <= 0 then
    (* force a non‐nested leaf: *)
    if allow_float then
      match Random.int 2 with
      | 0 -> F_Int (Random.int 20)
      | _ ->
          (* generate [0.0,20.0), then round to 2 decimals *)
          let raw = Random.float 20.0 in
          let two_dp = floor (raw *. 100. +. 0.5) /. 100. in
          F_Num two_dp
    else
      F_Int (Random.int 20)  (* Only generate integers if allow_float is false *)
  else
    (* could even avoid parentheses at max depth if wanted *)
    if allow_float then
      match Random.int 3 with
      | 0 when max_expr_depth > 0 -> F_Paren (gen_math_expr_root (max_expr_depth-1))
      | 1 -> F_Int   (Random.int 20)
      | _ ->
          (* generate [0.0,20.0), then round to 2 decimals *)
          let raw   = Random.float 20.0 in
          let two_dp = floor (raw *. 100.0 +. 0.5) /. 100.0 in
          F_Num two_dp
    else
      match Random.int 2 with
      | 0 when max_expr_depth > 0 -> F_Paren (gen_math_expr_root (max_expr_depth-1))
      | _ -> F_Int (Random.int 20)

(* For Set (Compute Method): *)
(* Transform set_expr to set_compute AST *)
let rec set_expr_to_set_compute (expr : set_expr) : set_compute_factor =
  match expr with
  | Set_Expr_Enum enum ->
      Set_Compute_Enum enum
  | Set_Expr_interval interval ->
      Set_Compute_Interval (set_interval_to_set_compute_interval interval)

and set_interval_to_set_compute_interval (interval : set_interval) : set_compute_interval =
  match interval with
  | Set_Interval pred -> predicate_to_set_compute_interval pred

and predicate_to_set_compute_interval (pred : predicate) : set_compute_interval =
  match pred with
  | Greater_Than i ->
      LNEQ_RNEQ (I_Int (i + 1), I_Infinity)
  | Less_Than i ->
      LNEQ_RNEQ (I_NegInfinity, I_Int i)
  | Greater_Equal i ->
      LEQ_RNEQ (I_Int i, I_Infinity)
  | Less_Equal i ->
      LNEQ_REQ (I_NegInfinity, I_Int i)
  | Between_Open (i1, i2) ->
      LNEQ_RNEQ (I_Int i1, I_Int i2)
  | Between_Left_Closed (i1, i2) ->
      LEQ_RNEQ (I_Int i1, I_Int i2)
  | Between_Right_Closed (i1, i2) ->
      LNEQ_REQ (I_Int i1, I_Int i2)
  | Between_Closed (i1, i2) ->
      LEQ_REQ (I_Int i1, I_Int i2)

let rec set_operation_to_set_compute (op : set_operation) (env : (string * set_expr) list) : set_compute =
  match op with
  | Set_Op_Union (left, right) ->
      let left_compute = set_operation_to_set_compute left env in
      let right_compute = set_term_to_set_compute_term right env in
      Set_Compute_Union (left_compute, right_compute)
  | Set_Op_Term term ->
      Set_Compute_Term (set_term_to_set_compute_term term env)

and set_term_to_set_compute_term (term : set_term) (env : (string * set_expr) list) : set_compute_term =
  match term with
  | Set_Op_Inter (left, right) ->
      (* Change intersection A ∩ B into A - (R - B) *)
      let left_compute = set_term_to_set_compute_term left env in
      let right_compute = set_factor_to_set_compute_factor right env in

      (* Define universal set R = (-∞, ∞) *)
      let universal_set = Set_Compute_Interval (LNEQ_RNEQ (I_NegInfinity, I_Infinity)) in

      (* R - B *)
      let universal_minus_b =
        Set_Compute_Diff (
          Set_Compute_Factor universal_set,
          right_compute
        )
      in

      (* A - (R - B) *)
      Set_Compute_Diff (left_compute, Set_Compute_Paren (Set_Compute_Term universal_minus_b))
  | Set_Op_Factor factor ->
      Set_Compute_Factor (set_factor_to_set_compute_factor factor env)

and set_factor_to_set_compute_factor (factor : set_factor) (env : (string * set_expr) list) : set_compute_factor =
  match factor with
  | Set_Op_Diff (left, right) ->
      let left_compute = set_factor_to_set_compute_factor left env in
      let right_compute = set_primary_to_set_compute_factor right env in
      Set_Compute_Paren (Set_Compute_Term (Set_Compute_Diff (
        Set_Compute_Factor left_compute,
        right_compute
      )))
  | Set_Op_Primary primary ->
      set_primary_to_set_compute_factor primary env

and set_primary_to_set_compute_factor (primary : set_primary) (env : (string * set_expr) list) : set_compute_factor =
  match primary with
  | Set_Op_Paren op ->
      Set_Compute_Paren (set_operation_to_set_compute op env)
  | Set_Op_Var var_name ->
      try
        let set_expr = List.assoc var_name env in
        set_expr_to_set_compute set_expr
      with Not_found ->
        (* If the variable is not in env, return an empty set *)
        Set_Compute_Enum []

(* Build an environment mapping from variable names to set expressions *)
let build_env_from_set_list (set_list : set_list) : (string * set_expr) list =
  let rec extract_env sl acc =
    match sl with
    | Set_List_Last (var_name, expr) -> (var_name, expr) :: acc
    | Set_List_Cons (var_name, expr, rest) -> extract_env rest ((var_name, expr) :: acc)
  in
  extract_env set_list []

(** Convert context_setup_list to include answer variables *)
and convert_context_setup_list (context_setup_list : context_setup_list) (answer_vars : answer_vars) : context_setup_list =
  match problem_type with
    | 1 -> (* arithmetic only *)
      context_setup_list
    | 2 -> (* set only *)
      (match context_setup_list with
      | Context_Setup_No_Vars_Last csetup ->
        (* Convert the last context setup without vars to one with vars *)
        Context_Setup_Vars_Last (csetup, answer_vars)
      | other -> other)
    | 3 -> (* vector only *)
      context_setup_list
    | 4 -> (* calculus only *)
      (match context_setup_list with
      | Context_Setup_No_Vars_Last csetup ->
        (* Convert the last context setup without vars to one with vars *)
        Context_Setup_Vars_Last (csetup, answer_vars)
      | other -> other)
    | 6 -> (* complex number only *)
      (match context_setup_list with
      | Context_Setup_No_Vars_Last csetup ->
        Context_Setup_Vars_Last (csetup, answer_vars)
      | other -> other)
    | _ -> (* all type of questions only *)
      (* Split answer_vars into function definitions and set answer variables *)
      let function_vars =
        List.filter
          (fun (name, _) ->
            (String.length name >= 4 && String.sub name 0 4 = "fun_")
            || (String.length name >= 5 && String.sub name 0 5 = "anti_"))
          answer_vars
      in
      let set_vars = List.filter (fun (name, _) -> String.length name >= 8 && String.sub name 0 8 = "set_ans_") answer_vars in
      let complex_vars = List.filter (fun (name, _) -> String.length name >= 12 && String.sub name 0 12 = "complex_ans_") answer_vars in

      (match context_setup_list with
      | Context_Setup_No_Vars_Cons (csetup1, Context_Setup_No_Vars_Cons (csetup2, Context_Setup_No_Vars_Cons (csetup3, Context_Setup_No_Vars_Last csetup4))) ->
        let complex_context =
          if complex_vars = [] then
            Context_Setup_No_Vars_Last csetup4
          else
            Context_Setup_Vars_Last (csetup4, complex_vars)
        in
        let vector_context = Context_Setup_No_Vars_Cons (csetup3, complex_context) in
        let set_context =
          if set_vars = [] then
            Context_Setup_No_Vars_Cons (csetup2, vector_context)
          else
            Context_Setup_Vars_Cons (csetup2, set_vars, vector_context)
        in
        if function_vars = [] then
          Context_Setup_No_Vars_Cons (csetup1, set_context)
        else
          Context_Setup_Vars_Cons (csetup1, function_vars, set_context)
      | other -> other)

(* ============================================================= *)
(* ============================================================= *)

(* ================================================================ *)
(** Generate a random AST for your <document> nonterminal *)
let rec gen_document () : document =
  (* Reset function counter for each new document *)
  reset_fun_counter ();
  reset_complex_counter ();

  match problem_type with
    | 0 -> (* all type of questions *)
      let header = gen_header () in
      let context_setup_list = gen_context_setup_list () in
      let problem_section = gen_problem_section () in
      let (modified_problem_section, answer_vars) = convert_problem_section problem_section in
      let modified_context_setup_list = convert_context_setup_list context_setup_list answer_vars in
        Doc_No_Sol (header, modified_context_setup_list, modified_problem_section)
    | 1 -> (* arithmetic only *)
      let header = gen_header () in
      let context_setup_list = gen_context_setup_list () in
      let problem_section = gen_problem_section () in
        Doc_No_Sol (header, context_setup_list, problem_section)
    | 2 -> (* set only *)
      let header = gen_header () in
      let context_setup_list = gen_context_setup_list () in
      let problem_section = gen_problem_section () in
      let (modified_problem_section, answer_vars) = convert_problem_section problem_section in
      let modified_context_setup_list = convert_context_setup_list context_setup_list answer_vars in
        Doc_No_Sol (header, modified_context_setup_list, modified_problem_section)
    | 3 -> (* vector only *)
      let header = gen_header () in
      let context_setup_list = gen_context_setup_list () in
      let problem_section = gen_problem_section () in
        Doc_No_Sol (header, context_setup_list, problem_section)
    | 4 -> (* calculus only *)
      let header = gen_header () in
      let context_setup_list = gen_context_setup_list () in
      let (problem_section, answer_vars) = gen_calculus_problem_section () in
      let modified_context_setup_list = convert_context_setup_list context_setup_list answer_vars in
        Doc_No_Sol (header, modified_context_setup_list, problem_section)
    | 5 -> (* Boolean Algebra only *)
	      let header = gen_header () in
	      let context_setup_list = gen_context_setup_list () in
	      let problem_section = gen_problem_section () in
	        Doc_No_Sol (header, context_setup_list, problem_section)
    | 6 -> (* complex number only *)
      let header = gen_header () in
      let context_setup_list = gen_context_setup_list () in
      let problem_section = gen_problem_section () in
      let (modified_problem_section, answer_vars) = convert_problem_section problem_section in
      let modified_context_setup_list = convert_context_setup_list context_setup_list answer_vars in
        Doc_No_Sol (header, modified_context_setup_list, modified_problem_section)
    | _ -> (* all type of questions only *)
      let header = gen_header () in
      let context_setup_list = gen_context_setup_list () in
      let problem_section = gen_problem_section () in
      let (modified_problem_section, answer_vars) = convert_problem_section problem_section in
      let modified_context_setup_list = convert_context_setup_list context_setup_list answer_vars in
        Doc_No_Sol (header, modified_context_setup_list, modified_problem_section)

and gen_header () : header =
  (*if Random.bool () then
    LoadMacros (Some (gen_macro ()))
  else*)
    LoadMacros (None)

(* public entry point *)
and gen_macro () : macro =
  gen_macro_from allowed_macros

and gen_context_setup_list () : context_setup_list =
    match problem_type with
    | 1 -> (* arithmetic only *)
      Context_Setup_No_Vars_Last (Context_With_Config ("Numeric", Cfg_Last(Operators, CM_Undefine([Add_Op; Sub_Op; Mul_Op; Div_Op]))))
    | 2 -> (* set only *)
      Context_Setup_No_Vars_Last (Context_Only "Interval")
    | 3 -> (* vector only *)
      Context_Setup_No_Vars_Last (Context_Only "Vector")
    | 4 -> (* calculus only *)
      Context_Setup_No_Vars_Last (Context_With_Config ("Numeric", Cfg_Cons(Flags, CM_Set([Entry_Property(Property(Str("reduceConstantFunctions"),VInt(0)))]), Cfg_Last(Flags, CM_Set([Entry_Property(Property(Str("reduceConstants"),VInt(0)))])))))
    | 5 -> (* Boolean Algebra only *)
	      Context_Setup_No_Vars_Last (Context_Only "Numeric")
    | 6 -> (* complex number only *)
      Context_Setup_No_Vars_Last (Context_Only "Complex")
    | _ -> (* all type of questions only *)
      Context_Setup_No_Vars_Cons (Context_With_Config ("Numeric", Cfg_Cons(Flags, CM_Set([Entry_Property(Property(Str("reduceConstantFunctions"),VInt(0)))]), Cfg_Last(Flags, CM_Set([Entry_Property(Property(Str("reduceConstants"),VInt(0)))])))), Context_Setup_No_Vars_Cons (Context_Only "Interval", Context_Setup_No_Vars_Cons (Context_Only "Vector", Context_Setup_No_Vars_Last (Context_Only "Complex"))))
(*
and gen_context_config () : context_config =
  let modules = [ Variables; Constants; Strings; Operators; Flags ] in

  (* pick a random total depth between min and max *)
  let depth = min_cfg_depth + Random.int (max_cfg_depth - min_cfg_depth + 1) in

  (* now build exactly [depth] levels, with the last being Cfg_Last *)
  let rec build i =
    let m  = pick modules in
    let cm = gen_context_method m in
    if i = 1 then
      Cfg_Last (m, cm)
    else
      Cfg_Cons (m, cm, build (i - 1))
  in
  build depth
*)
and gen_context_method cmodu : context_method =
  match cmodu with
  | Variables -> pick [
                        (fun () -> CM_Are      (gen_entry_list ()));
                      ] ()
  | Constants -> pick [
                        (fun () -> CM_Add      (gen_entry_list ()));
                      ] ()
  | Strings   -> pick [
                        (fun () -> CM_Add      (gen_entry_list ()));
                      ] ()
  | Operators -> pick [
                        (fun () -> CM_Undefine (gen_operator_list ()));
                        (fun () -> CM_Redefine (gen_operator_list ()));
                      ] ()
  | Flags     -> pick [
                        (fun () -> CM_Set (gen_entry_list ()));
                      ] ()

and gen_entry_list () : entry list =
  let n = 1 + Random.int 2 in
  let rec aux i acc =
    if i = 0 then acc
    else aux (i - 1) (gen_entry () :: acc)
  in
  aux n []

and gen_entry () : entry =
  if Random.bool () then
    Entry_Property (gen_property ())
  else
    if Random.bool () then
      Entry_Map (gen_key (), Some (gen_properties ()))
    else
      Entry_Map (gen_key (), None)

and gen_properties () : property list =
  let n = 1 + Random.int 2 in
  let rec aux i acc =
    if i = 0 then acc
    else aux (i - 1) ((gen_property ()) :: acc)
  in
  aux n []

and gen_property () : property =
  Property (gen_key (), gen_value ())

and gen_key () : key =
  match Random.int 2 with
  | 0 -> Ident (pick ["x"; "y"; "z"])
  | _ -> Str   (pick ["True"; "False"; "hello"; "world"])

and gen_value () : value =
  if allow_float then
    match Random.int 2 (*4*) with
    | 0 -> VInt (Random.int 20)
    | _ (*1*) -> (* generate [0.0,20.0), then round to 2 decimals *)
            let raw = Random.float 20.0 in
            let two_dp = floor (raw *. 100.0 +. 0.5) /. 100.0 in
            VNum two_dp
    (*| 2 -> VStr (pick ["alpha"; "beta"; "gamma"])
    | _ -> VIdent (pick ["x"; "y"; "z"])*)
  else
    VInt (Random.int 20)  (* Only generate integers if allow_float is false *)

and gen_operator_list () : operator list =
  let opts =
    [Add_Op; Sub_Op; Mul_Op; Div_Op]
  in
  let n = 1 + Random.int 3 in
  let rec aux i acc =
    if i = 0 then acc
    else aux (i - 1) (pick opts :: acc)
  in
  aux n []

and gen_variable () : variable =
  if allow_float then
    match Random.int 2 (*4*) with
    | 0 -> Var_Value (gen_value ())
    | _ (*1*) -> Var_Method (gen_math_object_method ())
    (*| 2 -> let id = pick ["x"; "y"; "z"] in
            Var_Field (id, gen_math_object_method ())
    | _ -> Var_Chain (gen_math_object_method (), gen_math_object_method ())*)
  else
    Var_Value (VInt (Random.int 20))  (* Only generate integers if allow_float is false *)

and gen_math_object_method () : math_object_method =
  if allow_float then
    match Random.int 5 with
    (*| 0 ->
        (* pick low ∈ [0..9] *)
        let low = Random.int 10 in
        (* then pick high ∈ [low+1..10] *)
        let high = low + 1 + Random.int (10 - low) in
        (* now pick step ∈ [low..high] *)
        let step = low + Random.int (high - low + 1) in
        M_Random (low, high, step)*)
    | 0 (*1*) ->
        M_Formula    (gen_math_expr ())
    | 1 (*2*) ->
        (* generate [0.0,20.0), then round to 2 decimals *)
        let raw = Random.float 20.0 in
        let two_dp = floor (raw *. 100.0 +. 0.5) /. 100.0 in
        M_Real (VNum two_dp)
    | 2 -> M_Set (gen_set_enum ())
    | 3 -> M_Compute (gen_set_compute ())
    | _ -> M_intersect (gen_variable ())
    (*| 3 ->
        if Random.bool () then
          M_D        (Some (pick ["t"; "x"; "y"]))
        else
          M_D        (None)
    | 4 ->
        M_Eval       (gen_property ())
    | _ ->
        M_With       (gen_property ())*)
  else
    match Random.int 4 with
    | 0 -> M_Formula (gen_math_expr ())  (* Only generate integer expressions if allow_float is false *)
    | 1 -> M_Set (gen_set_enum ())
    | 2 -> M_Compute (gen_set_compute ())
    | _ -> M_intersect (gen_variable ())

and gen_set_enum () : set_enum =
  let n = 2 + Random.int 5 in  (* Generate 2-6 elements *)
  let rec aux i acc =
    if i = 0 then acc
    else
      (* Only consider integer elements *)
      let elem = min_set_element + Random.int (max_set_element - min_set_element + 1) in
      if List.mem elem acc then
        aux i acc  (* Element already exists, try again *)
      else
        aux (i - 1) (elem :: acc)
  in
  List.sort compare (aux n [])

and gen_set_compute () : set_compute =
  let depth = 1 + Random.int 2 in
  gen_set_compute_root depth

and gen_set_compute_root depth : set_compute =
  if depth <= 0 then
    Set_Compute_Term (gen_set_compute_term 0)
  else
    match Random.int 3 with
    | 0 -> Set_Compute_Union (gen_set_compute_root (depth-1), gen_set_compute_term (depth-1))
    | _ -> Set_Compute_Term (gen_set_compute_term (depth-1))

and gen_set_compute_term depth : set_compute_term =
  if depth <= 0 then
    Set_Compute_Factor (gen_set_compute_factor 0)
  else
    match Random.int 3 with
    | 0 -> Set_Compute_Diff (gen_set_compute_term (depth-1), gen_set_compute_factor (depth-1))
    | _ -> Set_Compute_Factor (gen_set_compute_factor (depth-1))

and gen_set_compute_factor depth : set_compute_factor =
  if depth <= 0 then
    match Random.int 2 with
    | 0 -> Set_Compute_Enum (gen_set_enum ())
    | _ -> Set_Compute_Interval (gen_set_compute_interval ())
  else
    match Random.int 3 with
    | 0 -> Set_Compute_Paren (gen_set_compute_root (depth-1))
    | 1 -> Set_Compute_Enum (gen_set_enum ())
    | _ -> Set_Compute_Interval (gen_set_compute_interval ())

and gen_set_compute_interval () : set_compute_interval =
  match Random.int 4 with
  | 0 ->
      let left = I_Int (Random.int 10) in
      let right = I_Int (10 + Random.int 10) in
      LNEQ_RNEQ (left, right)
  | 1 ->
      let left = I_Int (Random.int 10) in
      let right = I_Int (10 + Random.int 10) in
      LNEQ_REQ (left, right)
  | 2 ->
      let left = I_Int (Random.int 10) in
      let right = I_Int (10 + Random.int 10) in
      LEQ_RNEQ (left, right)
  | _ ->
      let left = I_Int (Random.int 10) in
      let right = I_Int (10 + Random.int 10) in
      LEQ_REQ (left, right)

and gen_problem_section () : problem_section =
  Problem (gen_question_list ())

and gen_question_list () : question_item list =
  match problem_type with
  | 0 ->  (* All type of questions *)
    if question_random_amounts = false then
      (* List: [arithmetic_amount; set_amount; vector_amount; calculus_amount; boolean_amount; complex_amount; sequence_amount] *)
      let arithmetic_count = nth_or_default question_type_amounts 0 0 in
      let set_count = nth_or_default question_type_amounts 1 0 in
      let vector_count = nth_or_default question_type_amounts 2 0 in
      let calculus_count = nth_or_default question_type_amounts 3 0 in
      let boolean_count = nth_or_default question_type_amounts 4 0 in
      let complex_count = nth_or_default question_type_amounts 5 0 in
      let sequence_count = nth_or_default question_type_amounts 6 0 in

      (* Generate each question type *)
      let arithmetic_questions =
        List.init arithmetic_count (fun _ -> gen_arithmetic_question ())
      in
      let set_questions =
        List.init set_count (fun _ -> gen_set_question ())
      in
      let vector_questions =
        List.init vector_count (fun _ -> gen_vector_question ())
      in
      let calculus_questions =
        List.init calculus_count (fun _ ->
          let (q, _) = gen_calculus_question () in
          q
        )
      in
      let boolean_questions =
        List.init boolean_count (fun _ -> gen_boolean_question ())
      in
      let complex_questions =
        List.init complex_count (fun _ -> gen_complex_question ())
      in
      let sequence_questions =
        List.init sequence_count (fun _ -> gen_sequence_question ())
      in
      let all_questions = arithmetic_questions @ set_questions @ vector_questions @ calculus_questions @ boolean_questions @ complex_questions @ sequence_questions in
        if shuffle_questions_for_0_type = true then
          shuffle_list all_questions
        else
          all_questions
    else
      let n = min_question_num + Random.int (max_question_num - min_question_num + 1) in
      let rec aux i acc =
        if i = 0 then acc
        else aux (i - 1) (gen_question_item () :: acc)
      in
      aux n []
  | _ ->  (* Single type of questions *)
    let n = min_question_num + Random.int (max_question_num - min_question_num + 1) in
    let rec aux i acc =
      if i = 0 then acc
      else aux (i - 1) (gen_question_item () :: acc)
    in
    aux n []

(* Auxiliary function: to shuffle a list *)
and shuffle_list lst =
  let arr = Array.of_list lst in
  let len = Array.length arr in
  for i = 0 to len - 1 do
    let j = i + Random.int (len - i) in
    let temp = arr.(i) in
    arr.(i) <- arr.(j);
    arr.(j) <- temp
  done;
  Array.to_list arr

and gen_question_item () : question_item =
  match problem_type with
  | 0 ->  (* All type of questions *)
      (* if randomly choose *)
      (match Random.int 7 with
          | 0 -> gen_arithmetic_question ()
          | 1 -> gen_set_question ()
          | 2 -> gen_vector_question ()
          | 3 ->
              let (q, _) = gen_calculus_question () in
              q
          | 4 -> gen_boolean_question ()
          | 5 -> gen_complex_question ()
          | _ -> gen_sequence_question ())
  | 1 ->  (* Arithmetic only *)
      gen_arithmetic_question ()
  | 2 ->  (* Set only *)
      gen_set_question ()
  | 3 ->  (* Vector only *)
      gen_vector_question ()
	  | 4 ->  (* Calculus only *)
	      let (q, _) = gen_calculus_question () in
	      q
	  | 5 ->  (* Boolean Algebra only *)
	      gen_boolean_question ()
    | 6 ->  (* Complex Number only *)
      gen_complex_question ()
    | 7 ->  (* Sequence only *)
      gen_sequence_question ()
	  | _ -> gen_arithmetic_question ()  (* Default to arithmetic *)

and gen_arithmetic_question () : question_item =
  (* 1) pick exactly one in-text call *)
  let icall = gen_intext_call () in

  (* 2) evaluate it into a variable v_answer *)
  let v_answer =
    match icall with
    | IC_VarV v -> v
    | IC_Math expr ->
        (* run the structural checks on the formula *)
        check_math_expr expr;
        (* evaluate to a float *)
        let f = eval_math_expr expr in
        if f = floor f then
          (* if it’s an exact integer, emit VInt *)
          match Random.int 3 with
          | 0 -> Var_Value (VInt (int_of_float f))
          | 1 -> Var_Method (M_Real (VNum f))
          | _ -> Var_Method (M_Formula (ME_Term(T_Fac(F_Int(int_of_float f)))))
        else
          match Random.int 3 with
          | 0 -> Var_Value (VNum f)
          | 1 -> Var_Method (M_Real (VNum f))
          | _ -> Var_Method (M_Formula (ME_Term(T_Fac(F_Num f))))
  in

  (* 3) answer is always A_Var v_answer *)
  let ans = A_Var v_answer in

  (* 4) width as before *)
  let width = if Random.bool () then Some (1 + Random.int 10) else None in

  (* 5) choose whether to render Q_Value or Q_IsEqual *)
  let qtext =
    if Random.bool ()
    then Q_Value   icall
    else Q_IsEqual icall
  in

	  Q_Item (qtext, ans, width)

and gen_sequence_question () : question_item =
  let first = random_between min_sequence_term max_sequence_term in
  let index = random_between min_sequence_index max_sequence_index in
  let make_answer value = A_Var (Var_Value (VInt value)) in
  let mode =
    match sequence_question_mode with
    | 1 -> `Arithmetic_Nth
    | 2 -> `Geometric_Nth
    | 3 -> `Arithmetic_Sum
    | 4 -> `Geometric_Sum
    | _ ->
        weighted_pick
          [ (arithmetic_sequence_weight, `Arithmetic_Nth);
            (geometric_sequence_weight, `Geometric_Nth);
            (arithmetic_sequence_sum_weight, `Arithmetic_Sum);
            (geometric_sequence_sum_weight, `Geometric_Sum) ]
  in
  match mode with
  | `Arithmetic_Nth ->
      let diff = random_nonzero_between min_sequence_difference max_sequence_difference in
      let answer = first + ((index - 1) * diff) in
      Q_Sequence (Arithmetic_Nth (first, diff, index), make_answer answer, None)
  | `Geometric_Nth ->
      let ratio = random_nonzero_between min_sequence_ratio max_sequence_ratio in
      let answer = first * int_pow ratio (index - 1) in
      Q_Sequence (Geometric_Nth (first, ratio, index), make_answer answer, None)
  | `Arithmetic_Sum ->
      let diff = random_nonzero_between min_sequence_difference max_sequence_difference in
      let last = first + ((index - 1) * diff) in
      let answer = index * (first + last) / 2 in
      Q_Sequence (Arithmetic_Sum (first, diff, index), make_answer answer, None)
  | `Geometric_Sum ->
      let ratio = random_nonzero_between min_sequence_ratio max_sequence_ratio in
      let answer =
        if ratio = 1 then first * index
        else first * ((int_pow ratio index) - 1) / (ratio - 1)
      in
      Q_Sequence (Geometric_Sum (first, ratio, index), make_answer answer, None)

and take_string_list n lst =
  let rec aux i acc rest =
    if i = 0 then List.rev acc
    else
      match rest with
      | [] -> List.rev acc
      | x :: xs -> aux (i - 1) (x :: acc) xs
  in
  aux n [] lst

and dedupe_string_list names =
  List.fold_right
    (fun name acc -> if List.mem name acc then acc else name :: acc)
    names []

and shuffle_string_list names =
  let arr = Array.of_list names in
  let len = Array.length arr in
  for i = 0 to len - 1 do
    let j = i + Random.int (len - i) in
    let temp = arr.(i) in
    arr.(i) <- arr.(j);
    arr.(j) <- temp
  done;
  Array.to_list arr

and gen_boolean_vars () =
  let available_vars =
    match dedupe_string_list boolean_variables with
    | [] -> ["A"; "B"; "C"; "D"]
    | vars -> vars
  in
  let available_count = List.length available_vars in
  let max_vars = max 1 (min max_bool_var_num available_count) in
  let min_vars = max 1 (min min_bool_var_num max_vars) in
  let var_count = min_vars + Random.int (max_vars - min_vars + 1) in
  take_string_list var_count (shuffle_string_list available_vars)

and gen_boolean_depth () =
  let min_depth = max 0 min_bool_expr_depth in
  let max_depth = max min_depth max_bool_expr_depth in
  min_depth + Random.int (max_depth - min_depth + 1)

and gen_boolean_leaf vars =
  if Random.int 12 = 0 then
    Bool_Const (Random.bool ())
  else
    Bool_Var (pick_one vars)

and gen_boolean_expr_at_depth vars depth =
  if depth <= 0 then gen_boolean_leaf vars
  else
    match Random.int 100 with
    | n when n < 14 ->
        Bool_Not (gen_boolean_expr_at_depth vars (depth - 1))
    | n when n < 34 ->
        Bool_And (
          gen_boolean_expr_at_depth vars (depth - 1),
          gen_boolean_expr_at_depth vars (depth - 1)
        )
    | n when n < 54 ->
        Bool_Or (
          gen_boolean_expr_at_depth vars (depth - 1),
          gen_boolean_expr_at_depth vars (depth - 1)
        )
    | n when n < 70 ->
        Bool_Xor (
          gen_boolean_expr_at_depth vars (depth - 1),
          gen_boolean_expr_at_depth vars (depth - 1)
        )
    | n when n < 85 ->
        Bool_Implies (
          gen_boolean_expr_at_depth vars (depth - 1),
          gen_boolean_expr_at_depth vars (depth - 1)
        )
    | _ ->
        Bool_Iff (
          gen_boolean_expr_at_depth vars (depth - 1),
          gen_boolean_expr_at_depth vars (depth - 1)
        )

and bool_expr_stats expr =
  match expr with
  | Bool_Const _ -> (0, [])
  | Bool_Var name -> (0, [name])
  | Bool_Not inner ->
      let (ops, names) = bool_expr_stats inner in
      (ops + 1, names)
  | Bool_And (left, right)
  | Bool_Or (left, right)
  | Bool_Xor (left, right)
  | Bool_Implies (left, right)
  | Bool_Iff (left, right) ->
      let (left_ops, left_names) = bool_expr_stats left in
      let (right_ops, right_names) = bool_expr_stats right in
      (left_ops + right_ops + 1, left_names @ right_names)

and gen_boolean_expr vars =
  let depth = gen_boolean_depth () in
  let min_distinct_vars = min 2 (List.length vars) in
  let rec choose_expr attempts =
    let expr = gen_boolean_expr_at_depth vars depth in
    let (op_count, used_vars) = bool_expr_stats expr in
    let distinct_var_count = List.length (dedupe_string_list used_vars) in
    if attempts <= 0 || (op_count >= 2 && distinct_var_count >= min_distinct_vars) then
      expr
    else
      choose_expr (attempts - 1)
  in
  choose_expr 30

and gen_boolean_atom_or_small_expr vars preferred_var =
  if Random.int 3 = 0 then
    gen_boolean_expr_at_depth vars 1
  else
    Bool_Var preferred_var

and pick_distinct_bool_vars vars =
  match shuffle_string_list vars with
  | a :: b :: c :: _ -> (a, b, c)
  | a :: b :: [] -> (a, b, a)
  | a :: [] -> (a, a, a)
  | [] -> ("A", "A", "A")

and gen_boolean_equiv_pair vars =
  let (v1, v2, v3) = pick_distinct_bool_vars vars in
  let p = gen_boolean_atom_or_small_expr vars v1 in
  let q = gen_boolean_atom_or_small_expr vars v2 in
  let r = gen_boolean_atom_or_small_expr vars v3 in
  match Random.int 14 with
  | 0 -> (Bool_Implies (p, q), Bool_Or (Bool_Not p, q))
  | 1 -> (Bool_Not (Bool_And (p, q)), Bool_Or (Bool_Not p, Bool_Not q))
  | 2 -> (Bool_Not (Bool_Or (p, q)), Bool_And (Bool_Not p, Bool_Not q))
  | 3 -> (Bool_Not (Bool_Not p), p)
  | 4 -> (Bool_And (p, p), p)
  | 5 -> (Bool_Or (p, p), p)
  | 6 -> (Bool_And (p, q), Bool_And (q, p))
  | 7 -> (Bool_Or (p, q), Bool_Or (q, p))
  | 8 -> (Bool_And (Bool_And (p, q), r), Bool_And (p, Bool_And (q, r)))
  | 9 -> (Bool_Or (Bool_Or (p, q), r), Bool_Or (p, Bool_Or (q, r)))
  | 10 -> (Bool_And (p, Bool_Or (p, q)), p)
  | 11 -> (Bool_Or (p, Bool_And (p, q)), p)
  | 12 -> (Bool_Iff (p, q), Bool_And (Bool_Implies (p, q), Bool_Implies (q, p)))
  | _ ->
      (Bool_Xor (p, q), Bool_And (Bool_Or (p, q), Bool_Not (Bool_And (p, q))))

and make_boolean_non_equiv expr =
  match expr with
  | Bool_Const value -> Bool_Const (not value)
  | Bool_Var name -> Bool_Not (Bool_Var name)
  | Bool_Not inner -> inner
  | Bool_And (left, right) -> Bool_Or (left, right)
  | Bool_Or (left, right) -> Bool_And (left, right)
  | Bool_Xor (left, right) -> Bool_Iff (left, right)
  | Bool_Implies (left, right) -> Bool_Implies (right, left)
  | Bool_Iff (left, right) -> Bool_Xor (left, right)

and gen_boolean_non_equiv_pair vars =
  let rec try_generate attempts =
    if attempts <= 0 then
      match vars with
      | name :: _ -> (Bool_Var name, Bool_Not (Bool_Var name))
      | [] -> (Bool_Const true, Bool_Const false)
    else
      let (left, right) =
        if Random.bool () then
          let (l, r) = gen_boolean_equiv_pair vars in
          (l, make_boolean_non_equiv r)
        else
          let expr = gen_boolean_expr vars in
          (expr, make_boolean_non_equiv expr)
      in
      if bool_expr_equivalent left right then
        try_generate (attempts - 1)
      else
        (left, right)
  in
  try_generate 40

and gen_boolean_question () : question_item =
  match boolean_question_mode with
  | 1 -> gen_boolean_eval_question ()
  | 2 -> gen_boolean_equiv_question ()
  | _ ->
      let eval_weight = max 0 boolean_eval_weight in
      let equiv_weight = max 0 boolean_equiv_weight in
      let total = eval_weight + equiv_weight in
      if total = 0 then
        if Random.bool () then gen_boolean_eval_question () else gen_boolean_equiv_question ()
      else
        let r = Random.int total in
        if r < eval_weight then
          gen_boolean_eval_question ()
        else
          gen_boolean_equiv_question ()

and gen_boolean_eval_question () : question_item =
  let vars = gen_boolean_vars () in
  let expr = gen_boolean_expr vars in
  let assignments = List.map (fun name -> (name, Random.bool ())) vars in
  let answer = if eval_bool_expr assignments expr then 1 else 0 in
  let width = if Random.bool () then Some 1 else None in
  Q_Boolean_Eval (expr, assignments, A_Var (Var_Value (VInt answer)), width)

and gen_boolean_equiv_question () : question_item =
  let vars = gen_boolean_vars () in
  let want_equiv = Random.bool () in
  let rec choose_equiv attempts =
    let (left, right) = gen_boolean_equiv_pair vars in
    if attempts <= 0 || bool_expr_equivalent left right then
      (left, right)
    else
      choose_equiv (attempts - 1)
  in
  let (left, right) =
    if want_equiv then choose_equiv 20 else gen_boolean_non_equiv_pair vars
  in
  let answer = if bool_expr_equivalent left right then 1 else 0 in
  let width = if Random.bool () then Some 1 else None in
  Q_Boolean_Equiv (left, right, A_Var (Var_Value (VInt answer)), width)

and gen_complex_question () : question_item =
  match complex_question_mode with
  | 1 -> gen_complex_arithmetic_question ()
  | 2 -> gen_complex_conjugate_question ()
  | 3 -> gen_complex_modulus_question ()
  | 4 -> gen_complex_power_i_question ()
  | _ ->
      let weights = [
        (max 0 complex_arithmetic_weight, gen_complex_arithmetic_question);
        (max 0 complex_conjugate_weight, gen_complex_conjugate_question);
        (max 0 complex_modulus_weight, gen_complex_modulus_question);
        (max 0 complex_power_i_weight, gen_complex_power_i_question);
      ] in
      let total = List.fold_left (fun acc (weight, _) -> acc + weight) 0 weights in
      if total = 0 then
        (match Random.int 4 with
        | 0 -> gen_complex_arithmetic_question ()
        | 1 -> gen_complex_conjugate_question ()
        | 2 -> gen_complex_modulus_question ()
        | _ -> gen_complex_power_i_question ())
      else
        let r = Random.int total in
        let rec pick_weighted remaining = function
          | [] -> gen_complex_arithmetic_question ()
          | (weight, gen) :: rest ->
              if remaining < weight then gen ()
              else pick_weighted (remaining - weight) rest
        in
        pick_weighted r weights

and gen_complex_part () =
  let low = min_complex_component in
  let high = max low max_complex_component in
  low + Random.int (high - low + 1)

and gen_complex_num () : complex_num =
  let rec choose attempts =
    let re = gen_complex_part () in
    let im = gen_complex_part () in
    if attempts <= 0 || im <> 0 then
      Complex_Num (re, im)
    else
      choose (attempts - 1)
  in
  choose 20

and complex_answer (re, im) =
  A_Var (Var_Method (M_Complex (re, im)))

and gen_complex_arithmetic_question () : question_item =
  let left = Complex_Lit (gen_complex_num ()) in
  let right = Complex_Lit (gen_complex_num ()) in
  let expr =
    match Random.int 3 with
    | 0 -> Complex_Add (left, right)
    | 1 -> Complex_Sub (left, right)
    | _ -> Complex_Mul (left, right)
  in
  let answer = complex_answer (eval_complex_expr expr) in
  Q_Complex_Arithmetic (expr, answer)

and gen_complex_conjugate_question () : question_item =
  let num = gen_complex_num () in
  let (re, im) = complex_num_to_pair num in
  Q_Complex_Conjugate (num, complex_answer (re, -im))

and gen_complex_modulus_question () : question_item =
  let triples = [
    (3, 4, 5); (5, 12, 13); (8, 15, 17); (7, 24, 25);
    (6, 8, 10); (9, 12, 15); (12, 16, 20)
  ] in
  let low = min_complex_component in
  let high = max low max_complex_component in
  let signed_options =
    List.concat_map
      (fun (a, b, c) ->
        [(a, b, c); (-a, b, c); (a, -b, c); (-a, -b, c);
         (b, a, c); (-b, a, c); (b, -a, c); (-b, -a, c)])
      triples
  in
  let candidates =
    List.filter
      (fun (re, im, _) -> re >= low && re <= high && im >= low && im <= high)
      signed_options
  in
  let (re, im, magnitude) =
    match candidates with
    | [] -> (3, 4, 5)
    | _ -> pick_one candidates
  in
  Q_Complex_Modulus (Complex_Num (re, im), A_Var (Var_Value (VInt magnitude)))

and gen_complex_power_i_question () : question_item =
  let min_power = max 0 min_complex_power in
  let max_power = max min_power max_complex_power in
  let exponent = min_power + Random.int (max_power - min_power + 1) in
  let answer =
    match exponent mod 4 with
    | 0 -> (1, 0)
    | 1 -> (0, 1)
    | 2 -> (-1, 0)
    | _ -> (0, -1)
  in
  Q_Complex_Power_I (exponent, complex_answer answer)

and gen_set_question () : question_item =
  let set_list = gen_set_list () in
  let set_vars = get_set_vars_from_set_list set_list in
  let set_prob_list = gen_set_prob_list set_vars set_list in
  Q_Given_Set (set_list, set_prob_list)

and get_set_vars_from_set_list set_list =
  let rec extract_vars sl acc =
    match sl with
    | Set_List_Last (var_name, _) -> var_name :: acc
    | Set_List_Cons (var_name, _, rest) -> extract_vars rest (var_name :: acc)
  in
  extract_vars set_list []

and gen_set_list () : set_list =
  let n = 2 + Random.int (max_set_def_num - 1) in  (* at least 2, at most 10 sets *)
  let rec aux i remaining_vars =
    if i <= 0 then
      failwith "Should not happen: i <= 0"
    else if i = 1 then
      match remaining_vars with
      | [] -> failwith "Not enough variables"
      | var :: _ ->
          let set_expr = gen_set_expr () in
          Set_List_Last (var, set_expr)
    else
      match remaining_vars with
      | [] -> failwith "Not enough variables"
      | var :: rest_vars ->
          let set_expr = gen_set_expr () in
          let rest_list = aux (i - 1) rest_vars in
          Set_List_Cons (var, set_expr, rest_list)
  in
  aux n set_variables

and gen_set_expr () : set_expr =
  match Random.int 2 with
  | 0 -> Set_Expr_Enum (gen_set_enum ())
  | _ -> Set_Expr_interval (gen_set_interval ())

and gen_set_interval () : set_interval =
  Set_Interval (gen_predicate ())

and gen_predicate () : predicate =
  match Random.int 6 with
  | 0 -> Greater_Than (Random.int 10)
  | 1 -> Less_Than (10 + Random.int 10)
  | 2 -> Greater_Equal (Random.int 10)
  | 3 -> Less_Equal (10 + Random.int 10)
  | 4 ->
      let i1 = Random.int 5 in
      let i2 = 5 + Random.int 10 in
      Between_Open (i1, i2)
  | _ ->
      let i1 = Random.int 5 in
      let i2 = 5 + Random.int 10 in
      Between_Closed (i1, i2)

and gen_set_prob_list (available_vars : string list) (set_list : set_list) : set_prob_list =
  let env = build_env_from_set_list set_list in
  let n = min_set_prob_num + Random.int (max_set_prob_num - min_set_prob_num + 1) in  (* generate 2-3 set questions (by default) *)

  (* track generated set operations to avoid duplicates *)
  let used_set_ops = ref [] in

  let rec aux i =
    if i <= 0 then
      failwith "Should not happen: i <= 0"
    else
      let set_op = gen_unique_set_operation_non_trivial available_vars used_set_ops in
      let set_compute_ast = set_operation_to_set_compute set_op env in
      let ans = A_Var (Var_Method (M_Compute set_compute_ast)) in
      if i = 1 then
        Set_Prob_List_Last (set_op, ans)
      else
        let rest_list = aux (i - 1) in
        Set_Prob_List_Cons (set_op, ans, rest_list)
  in
  aux n

(* Generate a non-duplicate set_operation *)
and gen_unique_set_operation_non_trivial (available_vars : string list) (used_set_ops : set_operation list ref) : set_operation =
  let rec try_generate attempts =
    if attempts <= 0 then
      (* if the number of attempts is exceeded, return a random set_operation *)
      gen_set_operation_non_trivial available_vars
    else
      let candidate = gen_set_operation_non_trivial available_vars in
      if List.exists (fun used -> set_operation_equal used candidate) !used_set_ops then
        try_generate (attempts - 1)  (* if the candidate is a duplicate, try again *)
      else
        begin
          used_set_ops := candidate :: !used_set_ops;  (* record the generated set_operation *)
          candidate
        end
  in
  try_generate 10  (* at most 10 attempts *)

(* Compare two set_operations *)
and set_operation_equal (op1 : set_operation) (op2 : set_operation) : bool =
  match (op1, op2) with
  | (Set_Op_Union (left1, right1), Set_Op_Union (left2, right2)) ->
      set_operation_equal left1 left2 && set_term_equal right1 right2
  | (Set_Op_Term term1, Set_Op_Term term2) ->
      set_term_equal term1 term2
  | _ -> false

and set_term_equal (term1 : set_term) (term2 : set_term) : bool =
  match (term1, term2) with
  | (Set_Op_Inter (left1, right1), Set_Op_Inter (left2, right2)) ->
      set_term_equal left1 left2 && set_factor_equal right1 right2
  | (Set_Op_Factor factor1, Set_Op_Factor factor2) ->
      set_factor_equal factor1 factor2
  | _ -> false

and set_factor_equal (factor1 : set_factor) (factor2 : set_factor) : bool =
  match (factor1, factor2) with
  | (Set_Op_Diff (left1, right1), Set_Op_Diff (left2, right2)) ->
      set_factor_equal left1 left2 && set_primary_equal right1 right2
  | (Set_Op_Primary primary1, Set_Op_Primary primary2) ->
      set_primary_equal primary1 primary2
  | _ -> false

and set_primary_equal (primary1 : set_primary) (primary2 : set_primary) : bool =
  match (primary1, primary2) with
  | (Set_Op_Paren op1, Set_Op_Paren op2) ->
      set_operation_equal op1 op2
  | (Set_Op_Var var1, Set_Op_Var var2) ->
      var1 = var2
  | _ -> false

(* Generate non-trivial set operations (make sure it is not a single variable) *)
and gen_set_operation_non_trivial (available_vars : string list) : set_operation =
  let depth = min_set_expr_depth + Random.int (max_set_expr_depth - min_set_expr_depth + 1) in
  gen_set_operation_root_non_trivial available_vars depth

(* Non-trivial root node set operation generation *)
and gen_set_operation_root_non_trivial (available_vars : string list) depth : set_operation =
  if depth <= 1 then
    (* When the depth is 1, a union operation is forcibly generated *)
    let left = gen_set_operation available_vars in
    let right = gen_set_term available_vars 0 in
    Set_Op_Union (left, right)
  else
    (* When the depth is greater than 1, randomly select the operation type *)
    match Random.int 2 with
    | 0 ->
        let left = gen_set_operation_root_non_trivial available_vars (depth-1) in
        let right = gen_set_term available_vars (depth-1) in
        Set_Op_Union (left, right)
    | _ ->
        (* Generate an item that includes an intersection or a difference set *)
        Set_Op_Term (gen_set_term_non_trivial available_vars (depth-1))

(* Generate non-trivial set terms (including intersection or difference sets) *)
and gen_set_term_non_trivial (available_vars : string list) depth : set_term =
  if depth <= 0 then
    (* When the depth is 0, forcibly generate an intersection operation *)
    let left = gen_set_term available_vars 0 in
    let right = gen_set_factor available_vars 0 in
    Set_Op_Inter (left, right)
  else
    match Random.int 2 with
    | 0 ->
        let left = gen_set_term_non_trivial available_vars (depth-1) in
        let right = gen_set_factor available_vars (depth-1) in
        Set_Op_Inter (left, right)
    | _ ->
        (* Generate a factor that includes the difference set *)
        Set_Op_Factor (gen_set_factor_non_trivial available_vars (depth-1))

(* Generate non-trivial set factors (including difference sets) *)
and gen_set_factor_non_trivial (available_vars : string list) depth : set_factor =
  if depth <= 0 then
    (* When the depth is 0, forcibly generate a set difference operation *)
    let left = gen_set_factor available_vars 0 in
    let right = gen_set_primary available_vars in
    Set_Op_Diff (left, right)
  else
    match Random.int 3 with
    | 0 ->
        let left = gen_set_factor_non_trivial available_vars (depth-1) in
        let right = gen_set_primary available_vars in
        Set_Op_Diff (left, right)
    | _ ->
        (* Generate an operation with parentheses *)
        Set_Op_Primary (Set_Op_Paren (gen_set_operation_non_trivial available_vars))

(* using generated variables *)
and gen_set_operation (available_vars : string list) : set_operation =
  let depth = 1 + Random.int 2 in
  gen_set_operation_root available_vars depth

and gen_set_operation_root (available_vars : string list) depth : set_operation =
  if depth <= 0 then
    Set_Op_Term (gen_set_term available_vars 0)
  else
    match Random.int 3 with
    | 0 ->
        let left = gen_set_operation_root available_vars (depth-1) in
        let right = gen_set_term available_vars (depth-1) in
        Set_Op_Union (left, right)
    | _ -> Set_Op_Term (gen_set_term available_vars (depth-1))

and gen_set_term (available_vars : string list) depth : set_term =
  if depth <= 0 then
    Set_Op_Factor (gen_set_factor available_vars 0)
  else
    match Random.int 3 with
    | 0 ->
        let left = gen_set_term available_vars (depth-1) in
        let right = gen_set_factor available_vars (depth-1) in
        Set_Op_Inter (left, right)
    | _ -> Set_Op_Factor (gen_set_factor available_vars (depth-1))

and gen_set_factor (available_vars : string list) depth : set_factor =
  if depth <= 0 then
    Set_Op_Primary (gen_set_primary available_vars)
  else
    match Random.int 3 with
    | 0 ->
        let left = gen_set_factor available_vars (depth-1) in
        let right = gen_set_primary available_vars in
        Set_Op_Diff (left, right)
    | _ -> Set_Op_Primary (gen_set_primary available_vars)

and gen_set_primary (available_vars : string list) : set_primary =
  match Random.int 4 with
  | 0 -> Set_Op_Paren (gen_set_operation available_vars)
  | _ ->
      (* Randomly select one from the available variables *)
      let var = List.nth available_vars (Random.int (List.length available_vars)) in
      Set_Op_Var var

and gen_question_text () : question_text =
  if Random.bool () then
    Q_Value   (gen_intext_call ())
  else
    Q_IsEqual (gen_intext_call ())

and gen_answer_item () : answer_item =
  match Random.int 2 with
  | _ -> A_Var (gen_variable ())
(*
and gen_solution_section () : solution_section =
  Solution (gen_solution_list ())

and gen_solution_list () : solution_item list =
  let n = 1 + Random.int 2 in
  let rec aux i acc =
    if i = 0 then acc
    else aux (i - 1) (gen_solution_item () :: acc)
  in
  aux n []

and gen_solution_item () : solution_item =
  Sol_Correct (gen_intext_call (), "Solution Text Here.")
*)
and gen_intext_call () : intext_call =
  match Random.int 2 with
  (*| 0 -> IC_VarV (gen_variable ())*)
  | _ -> IC_Math (gen_math_expr ())

(* public entry point: always start at full depth *)
and gen_math_expr () : math_expr =
  gen_math_expr_root max_expr_depth

(** Convert problem section to use answer variables for set computations *)
and convert_problem_section (problem_section : problem_section) : problem_section * answer_vars =
  match problem_section with
  | Problem question_list ->
      let counter = ref 0 in
      let complex_answer_counter = ref 0 in
      let answer_vars = ref [] in

      (* Helper function to convert set_prob_list *)
      let rec convert_set_prob_list set_prob_list counter_ref =
        match set_prob_list with
        | Set_Prob_List_Last (set_op, ans_item) ->
            let (modified_ans, var_name, var_decl) = convert_answer_item ans_item counter_ref in
            (Set_Prob_List_Last (set_op, modified_ans), [var_decl])
        | Set_Prob_List_Cons (set_op, ans_item, rest) ->
            let (modified_ans, var_name, var_decl) = convert_answer_item ans_item counter_ref in
            let (modified_rest, rest_vars) = convert_set_prob_list rest counter_ref in
            (Set_Prob_List_Cons (set_op, modified_ans, modified_rest), var_decl :: rest_vars)

      (* Helper function to convert answer_item *)
      and convert_answer_item ans_item counter_ref =
        match ans_item with
        | A_Var (Var_Method (M_Compute set_compute)) ->
            incr counter_ref;
            let var_name = Printf.sprintf "set_ans_%d" !counter_ref in
            (* Create variable declaration *)
            let var_decl = (var_name, Var_Method (M_Compute set_compute)) in
            (* Replace answer with variable reference *)
            let modified_ans = A_Var (Var_Value (VIdent var_name)) in
            (modified_ans, var_name, var_decl)
        | other_ans ->
            (* Keep other answer types unchanged *)
            let var_name = Printf.sprintf "set_ans_%d" !counter_ref in
            incr counter_ref;
            let var_decl = (var_name, gen_variable ()) in (* Fallback variable *)
            (other_ans, var_name, var_decl)
      in

      let convert_complex_answer_item ans_item counter_ref =
        incr counter_ref;
        let var_name = Printf.sprintf "complex_ans_%d" !counter_ref in
        match ans_item with
        | A_Var var ->
            let var_decl = (var_name, var) in
            let modified_ans = A_Var (Var_Value (VIdent var_name)) in
            (modified_ans, var_decl)
      in

      (* Convert each question item *)
      let rec collect_integral_answers = function
        | Derivative_Prob_List_Last (Indefinite_Integral anti_name) ->
            [anti_name]
        | Derivative_Prob_List_Last _ ->
            []
        | Derivative_Prob_List_Cons (Indefinite_Integral anti_name, rest) ->
            anti_name :: collect_integral_answers rest
        | Derivative_Prob_List_Cons (_, rest) ->
            collect_integral_answers rest
      in

      let convert_question_item = function
        | Q_Given_Set (set_list, set_prob_list) ->
            let (modified_set_prob_list, new_vars) = convert_set_prob_list set_prob_list counter in
            answer_vars := new_vars @ !answer_vars;
            Q_Given_Set (set_list, modified_set_prob_list)
        | Q_Given_Function (fun_name, derivative_prob_list) ->
            let integral_answers = collect_integral_answers derivative_prob_list in
            let var_decls =
              match integral_answers with
              | [] ->
                  [(fun_name, Var_Method (M_Formula_Fun (gen_function_expr ()))) ]
              | anti_name :: _ ->
                  [
                    (anti_name, Var_Method (M_Formula_Fun (gen_integral_antiderivative_expr ())));
                    (fun_name, Var_Field (anti_name, M_D None));
                  ]
            in
            answer_vars := var_decls @ !answer_vars;
            Q_Given_Function (fun_name, derivative_prob_list)
        | Q_Item (qtext, ans, width) as item ->
            item (* Keep arithmetic questions unchanged *)
	        | Q_Suppose_Vector (_, _) as item ->
	            item (* Keep vector questions unchanged *)
	        | Q_Boolean_Eval (_, _, _, _) as item ->
	            item (* Keep Boolean evaluation questions unchanged *)
	        | Q_Boolean_Equiv (_, _, _, _) as item ->
	            item (* Keep Boolean equivalence questions unchanged *)
        | Q_Complex_Arithmetic (expr, ans) ->
            let (modified_ans, var_decl) = convert_complex_answer_item ans complex_answer_counter in
            answer_vars := var_decl :: !answer_vars;
            Q_Complex_Arithmetic (expr, modified_ans)
        | Q_Complex_Conjugate (num, ans) ->
            let (modified_ans, var_decl) = convert_complex_answer_item ans complex_answer_counter in
            answer_vars := var_decl :: !answer_vars;
            Q_Complex_Conjugate (num, modified_ans)
        | Q_Complex_Modulus (num, ans) ->
            let (modified_ans, var_decl) = convert_complex_answer_item ans complex_answer_counter in
            answer_vars := var_decl :: !answer_vars;
            Q_Complex_Modulus (num, modified_ans)
        | Q_Complex_Power_I (exponent, ans) ->
            let (modified_ans, var_decl) = convert_complex_answer_item ans complex_answer_counter in
            answer_vars := var_decl :: !answer_vars;
            Q_Complex_Power_I (exponent, modified_ans)
        | Q_Sequence (_, _, _) as item ->
            item
	      in

      let modified_question_list = List.map convert_question_item question_list in
      (Problem modified_question_list, !answer_vars)

(* ============================================================= *)
(* ================ Vector Generation Functions ================ *)
(* ============================================================= *)
(* Generate a vector (list of integers) *)
and gen_vector_enum () : set_enum =
  let n = vector_dimension in
  let rec aux i acc =
    if i = 0 then acc
    else
      let elem = min_vector_element + Random.int (max_vector_element - min_vector_element + 1) in  (* Generate numbers from -10 to 10 (by default) *)
      aux (i - 1) (elem :: acc)
  in
  aux n []

(* Generate vector list with variable names *)
and gen_vector_list () : vector_list =
  let n = 2 + Random.int (max_vector_def_num - 1) in  (* at least 2, at most 10 vectors *)
  let rec aux i remaining_vars =
    if i <= 0 then
      failwith "Should not happen: i <= 0"
    else if i = 1 then
      match remaining_vars with
      | [] -> failwith "Not enough variables"
      | var :: _ ->
          let vec_enum = gen_vector_enum () in
          Vector_List_Last (var, vec_enum)
    else
      match remaining_vars with
      | [] -> failwith "Not enough variables"
      | var :: rest_vars ->
          let vec_enum = gen_vector_enum () in
          let rest_list = aux (i - 1) rest_vars in
          Vector_List_Cons (var, vec_enum, rest_list)
  in
  aux n vector_variables

(* Get vector variables from vector list *)
and get_vector_vars_from_vector_list vec_list =
  let rec extract_vars vl acc =
    match vl with
    | Vector_List_Last (var_name, _) -> var_name :: acc
    | Vector_List_Cons (var_name, _, rest) -> extract_vars rest (var_name :: acc)
  in
  extract_vars vec_list []

(* Generate vector problem list using the actual vector definitions, avoiding duplicates *)
and gen_vector_prob_list (available_vars : string list) (env : (string * set_enum) list) : vector_prob_list =
  let n = min_vector_prob_num + Random.int (max_vector_prob_num - min_vector_prob_num + 1) in  (* generate 4-6 vector questions (by default) *)

  (* Track generated problem types to avoid duplicates *)
  let used_problem_types = ref [] in

  let rec aux i =
    if i <= 0 then
      failwith "Should not happen: i <= 0"
    else
      let vec_prob = gen_vector_prob available_vars env used_problem_types in
      if i = 1 then
        Vector_Prob_List_Last vec_prob
      else
        let rest_list = aux (i - 1) in
        Vector_Prob_List_Cons (vec_prob, rest_list)
  in
  aux n

(* Generate a random vector problem using the actual vectors from the environment, avoiding duplicates *)
and gen_vector_prob (available_vars : string list) (env : (string * set_enum) list) (used_types : string list ref) : vector_prob =
  let get_vector_enum var_name =
    try List.assoc var_name env
    with Not_found ->
      (* Fallback: generate a random vector if not found (shouldn't happen) *)
      gen_vector_enum ()
  in

  (* Helper function to check if a problem type with the same vectors has been used *)
  let is_duplicate problem_type vec1 vec2 =
    let key =
      match problem_type with
      | "Dot_Product" | "Cross_Product" -> problem_type ^ ":" ^ vec1 ^ ":" ^ vec2
      | _ -> problem_type ^ ":" ^ vec1
    in
    List.mem key !used_types
  in

  (* Helper function to mark a problem type as used *)
  let mark_used problem_type vec1 vec2 =
    let key =
      match problem_type with
      | "Dot_Product" | "Cross_Product" -> problem_type ^ ":" ^ vec1 ^ ":" ^ vec2
      | _ -> problem_type ^ ":" ^ vec1
    in
    used_types := key :: !used_types
  in

  (* Try to generate a non-duplicate problem *)
  let rec try_generate attempts =
    if attempts <= 0 then
      (* After too many attempts, just generate any problem *)
      let vec = pick_one available_vars in
      let enum = get_vector_enum vec in
      Same_Dir_Vectors (vec, enum)
    else
      match Random.int 6 with
      | 0 ->
          (* Dot Product *)
          let vec1 = pick_one available_vars in
          let vec2 = pick_one (List.filter ((<>) vec1) available_vars) in
          if is_duplicate "Dot_Product" vec1 vec2 then
            try_generate (attempts - 1)
          else
            let enum1 = get_vector_enum vec1 in
            let enum2 = get_vector_enum vec2 in
            mark_used "Dot_Product" vec1 vec2;
            Dot_Product (vec1, vec2, enum1, enum2)
      | 1 ->
          (* Cross Product *)
          let vec1 = pick_one available_vars in
          let vec2 = pick_one (List.filter ((<>) vec1) available_vars) in
          if is_duplicate "Cross_Product" vec1 vec2 then
            try_generate (attempts - 1)
          else
            let enum1 = get_vector_enum vec1 in
            let enum2 = get_vector_enum vec2 in
            mark_used "Cross_Product" vec1 vec2;
            Cross_Product (vec1, vec2, enum1, enum2)
      | 2 ->
          (* Vector Norm *)
          let vec = pick_one available_vars in
          if is_duplicate "Vector_Norm" vec "" then
            try_generate (attempts - 1)
          else
            let enum = get_vector_enum vec in
            mark_used "Vector_Norm" vec "";
            Vector_Norm (vec, enum)
      | 3 ->
          (* Unit Vector *)
          let vec = pick_one available_vars in
          if is_duplicate "Unit_Vector" vec "" then
            try_generate (attempts - 1)
          else
            let enum = get_vector_enum vec in
            mark_used "Unit_Vector" vec "";
            Unit_Vector (vec, enum)
      | 4 ->
          (* Parallel Vectors *)
          let vec = pick_one available_vars in
          if is_duplicate "Parallel_Vectors" vec "" then
            try_generate (attempts - 1)
          else
            let enum = get_vector_enum vec in
            mark_used "Parallel_Vectors" vec "";
            Parallel_Vectors (vec, enum)
      | _ ->
          (* Same Direction Vectors *)
          let vec = pick_one available_vars in
          if is_duplicate "Same_Dir_Vectors" vec "" then
            try_generate (attempts - 1)
          else
            let enum = get_vector_enum vec in
            mark_used "Same_Dir_Vectors" vec "";
            Same_Dir_Vectors (vec, enum)
  in

  try_generate 10  (* Try up to 10 times to generate a non-duplicate problem *)

(* Build an environment mapping from vector variable names to their enums *)
and build_env_from_vector_list (vec_list : vector_list) : (string * set_enum) list =
  let rec extract_env vl acc =
    match vl with
    | Vector_List_Last (var_name, enum) -> (var_name, enum) :: acc
    | Vector_List_Cons (var_name, enum, rest) -> extract_env rest ((var_name, enum) :: acc)
  in
  extract_env vec_list []

(* Generate vector question *)
and gen_vector_question () : question_item =
  let vector_list = gen_vector_list () in
  let vector_vars = get_vector_vars_from_vector_list vector_list in
  let env = build_env_from_vector_list vector_list in
  let vector_prob_list = gen_vector_prob_list vector_vars env in
  Q_Suppose_Vector (vector_list, vector_prob_list)

(* ============================================================= *)
(* ============== Derivative Generation Functions ============== *)
(* ============================================================= *)
and gen_calculus_question () : question_item * answer_vars =
  match calculus_question_mode with
  | 1 -> gen_derivative_question ()
  | 2 -> gen_integral_question ()
  | _ ->
      let der_weight = max 0 derivative_weight in
      let int_weight = max 0 integral_weight in
      let total = der_weight + int_weight in
      if total = 0 then
        if Random.bool () then gen_derivative_question () else gen_integral_question ()
      else if Random.int total < der_weight then
        gen_derivative_question ()
      else
        gen_integral_question ()

and gen_integral_question () : question_item * answer_vars =
  incr fun_counter;
  let index = !fun_counter in
  let fun_name = Printf.sprintf "fun_%d" index in
  let anti_name = Printf.sprintf "anti_%d" index in
  let anti_expr = gen_integral_antiderivative_expr () in
  let answer_vars = [
    (anti_name, Var_Method (M_Formula_Fun anti_expr));
    (fun_name, Var_Field (anti_name, M_D None));
  ] in
  let integral_prob_list = Derivative_Prob_List_Last (Indefinite_Integral anti_name) in
  (Q_Given_Function (fun_name, integral_prob_list), answer_vars)

and gen_integral_antiderivative_expr () : function_expr =
  let depth = max 0 integral_expr_depth in
  gen_integral_antiderivative_expr_root depth

and gen_integral_antiderivative_expr_root depth : function_expr =
  if depth <= 0 then
    gen_integral_antiderivative_base ()
  else
    match Random.int 8 with
    | 0 ->
        Linear_Fun (Int_Mul_Fun (1 + Random.int 6, gen_integral_fun_or_var (depth - 1)))
    | 1 ->
        Power_Fun (Power_Fun_Int (gen_integral_fun_or_var (depth - 1), 2 + Random.int 4))
    | 2 ->
        Quadratic_Fun (Quad_Square (gen_integral_fun_or_var (depth - 1)))
    | 3 ->
        let coeff = 1 + Random.int 5 in
        Quadratic_Fun (Quad_Add (gen_integral_fun_or_var (depth - 1), coeff, gen_integral_fun_or_var (depth - 1), 0))
    | 4 ->
        Trig_Fun (Trig_Sin (gen_integral_fun_or_var (depth - 1)))
    | 5 ->
        Trig_Fun (Trig_Cos (gen_integral_fun_or_var (depth - 1)))
    | 6 ->
        Exp_Fun (Exp (gen_integral_fun_or_var (depth - 1)))
    | _ ->
        gen_integral_antiderivative_base ()

and gen_integral_antiderivative_base () : function_expr =
  match Random.int 7 with
  | 0 -> Linear_Fun (Int_Mul_Fun (1 + Random.int 8, Var_X))
  | 1 -> Linear_Fun (Fun_Mul_Int (Var_X, 1 + Random.int 8))
  | 2 -> Quadratic_Fun (Quad_Add (Var_X, 1 + Random.int 6, Var_X, 0))
  | 3 -> Quadratic_Fun (Quad_Sub (Var_X, 1 + Random.int 6, Var_X, 0))
  | 4 -> Power_Fun (Power_Fun_Int (Var_X, 2 + Random.int 5))
  | 5 -> Trig_Fun (if Random.bool () then Trig_Sin Var_X else Trig_Cos Var_X)
  | _ -> Exp_Fun (Exp Var_X)

and gen_integral_fun_or_var depth : fun_or_var =
  if depth <= 0 || Random.int 3 = 0 then
    Var_X
  else
    Func (gen_integral_antiderivative_expr_root (depth - 1))

(* Generate derivative question with answer_vars *)
and gen_derivative_question () : question_item * answer_vars =
  incr fun_counter;
  let fun_name = Printf.sprintf "fun_%d" !fun_counter in
  let func_expr = gen_function_expr () in

  (* Create the variable declaration for answer_vars *)
  let answer_var = (fun_name, Var_Method (M_Formula_Fun func_expr)) in

  (* Generate derivative problem list using the function name *)
  let derivative_prob_list = gen_derivative_prob_list fun_name in

  (* Create the question item *)
  let question_item = Q_Given_Function (fun_name, derivative_prob_list) in

  (question_item, [answer_var])

(* Generate derivative problem list with first problem always being First_Derivative and no duplicates *)
and gen_derivative_prob_list (fun_name : string) : derivative_prob_list =
  let n = min_derivative_prob_num + Random.int (max_derivative_prob_num - min_derivative_prob_num + 1) in

  (* Ensure first problem is always First_Derivative *)
  let first_prob = First_Derivative fun_name in

  if n = 1 then
    Derivative_Prob_List_Last first_prob
  else
    (* Generate the rest questions *)
    let rest_count = n - 1 in
    let rec gen_rest i used_types =
      if i <= 0 then
        failwith "Should not happen: i <= 0"
      else if i = 1 then
        let next_prob = gen_derivative_prob_non_repeat fun_name (first_prob :: used_types) in
        Derivative_Prob_List_Last next_prob
      else
        let next_prob = gen_derivative_prob_non_repeat fun_name (first_prob :: used_types) in
        let rest_list = gen_rest (i - 1) (next_prob :: used_types) in
        Derivative_Prob_List_Cons (next_prob, rest_list)
    in

    (* Let First_Derivative be the first question *)
    Derivative_Prob_List_Cons (first_prob, gen_rest rest_count [])

(* Generate a derivative problem that is not in the used_types list *)
and gen_derivative_prob_non_repeat (fun_name : string) (used_types : derivative_prob list) : derivative_prob =
  let rec try_generate attempts =
    if attempts <= 0 then
      (* Fallback if we can't find a non-duplicate after many attempts *)
      let rec find_unique_point used_points =
        let point = Random.int 10 in
        if List.mem point used_points then
          find_unique_point used_points
        else
          point
      in
      let used_points =
        List.fold_left (fun acc used ->
          match used with
          | Derivative_Algebra (p, _, _) -> p :: acc
          | _ -> acc
        ) [] used_types
      in
      let point = find_unique_point used_points in
      Derivative_Algebra (point, fun_name, point)
    else
      let candidate =
        match Random.int 3 with
        | 0 -> First_Derivative fun_name
        | 1 ->
            let point = Random.int 10 in
            Derivative_Algebra (point, fun_name, point)
        | _ -> Second_Derivative fun_name
      in
      (* Check if this problem has already been used *)
      if List.exists (fun used ->
           match (used, candidate) with
           | (First_Derivative _, First_Derivative _) -> true
           | (Second_Derivative _, Second_Derivative _) -> true
           | (Derivative_Algebra (p1, _, _), Derivative_Algebra (p2, _, _)) -> p1 = p2
           | _ -> false
         ) used_types then
        try_generate (attempts - 1)  (* Try again if duplicate *)
      else
        candidate
  in
  try_generate 10  (* Try up to 10 times to find a non-duplicate *)

(* Generate function expression *)
and gen_function_expr () : function_expr =
  let depth = min_fun_expr_depth + Random.int (max_fun_expr_depth - min_fun_expr_depth + 1) in
  gen_function_expr_root depth

and gen_function_expr_root depth : function_expr =
  if depth <= 0 then
    match Random.int 8 with
    | 0 -> Linear_Fun (gen_linear_function 0)
    | 1 -> Quadratic_Fun (gen_quadratic_function 0)
    | 2 -> Power_Fun (gen_power_function 0)
    | 3 -> Radical_Fun (gen_radical_function 0)
    | 4 -> Rational_Fun (gen_rational_function 0)
    | 5 -> Log_Fun (gen_log_function 0)
    | 6 -> Trig_Fun (gen_trig_function 0)
    | _ -> Exp_Fun (gen_exp_function 0)
  else
    match Random.int 8 with
    | 0 -> Linear_Fun (gen_linear_function (depth-1))
    | 1 -> Quadratic_Fun (gen_quadratic_function (depth-1))
    | 2 -> Power_Fun (gen_power_function (depth-1))
    | 3 -> Radical_Fun (gen_radical_function (depth-1))
    | 4 -> Rational_Fun (gen_rational_function (depth-1))
    | 5 -> Log_Fun (gen_log_function (depth-1))
    | 6 -> Trig_Fun (gen_trig_function (depth-1))
    | _ -> Exp_Fun (gen_exp_function (depth-1))

(* Generate linear function *)
and gen_linear_function depth : linear_function =
  if depth <= 0 then
    match Random.int 5 with
    | 0 -> Fun_Add_Int (Var_X, 1 + Random.int 10)
    | 1 -> Fun_Sub_Int (Var_X, 1 + Random.int 10)
    | 2 -> Int_Sub_Fun (1 + Random.int 10, Var_X)
    | 3 -> Int_Mul_Fun (1 + Random.int 5, Var_X)
    | _ -> Fun_Mul_Int (Var_X, 1 + Random.int 5)
  else
    match Random.int 5 with
    | 0 -> Fun_Add_Int (gen_fun_or_var (depth-1), 1 + Random.int 10)
    | 1 -> Fun_Sub_Int (gen_fun_or_var (depth-1), 1 + Random.int 10)
    | 2 -> Int_Sub_Fun (1 + Random.int 10, gen_fun_or_var (depth-1))
    | 3 -> Int_Mul_Fun (1 + Random.int 5, gen_fun_or_var (depth-1))
    | _ -> Fun_Mul_Int (gen_fun_or_var (depth-1), 1 + Random.int 5)

(* Generate quadratic function *)
and gen_quadratic_function depth : quadratic_function =
  if depth <= 0 then
    match Random.int 3 with
    | 0 ->
        let coeff1 = 1 + Random.int 5 in
        let coeff2 = 1 + Random.int 5 in
        Quad_Add (Var_X, coeff1, Var_X, coeff2)
    | 1 ->
        let coeff1 = 1 + Random.int 5 in
        let coeff2 = 1 + Random.int 5 in
        Quad_Sub (Var_X, coeff1, Var_X, coeff2)
    | _ -> Quad_Square Var_X
  else
    match Random.int 3 with
    | 0 ->
        let coeff1 = 1 + Random.int 5 in
        let coeff2 = 1 + Random.int 5 in
        Quad_Add (gen_fun_or_var (depth-1), coeff1, gen_fun_or_var (depth-1), coeff2)
    | 1 ->
        let coeff1 = 1 + Random.int 5 in
        let coeff2 = 1 + Random.int 5 in
        Quad_Sub (gen_fun_or_var (depth-1), coeff1, gen_fun_or_var (depth-1), coeff2)
    | _ -> Quad_Square (gen_fun_or_var (depth-1))

(* Generate power function *)
and gen_power_function depth : power_function =
  if depth <= 0 then
    Power_Fun_Int (Var_X, 2 + Random.int 4)  (* Powers from 2 to 5 *)
  else
    Power_Fun_Int (gen_fun_or_var (depth-1), 2 + Random.int 4)

(* Generate radical function *)
and gen_radical_function depth : radical_function =
  if depth <= 0 then
    match Random.int 2 with
    | 0 -> Radi_Sqrt Var_X
    | _ -> Radi_Root (Var_X, 2 + Random.int 3)  (* Roots from 2 to 4 *)
  else
    match Random.int 2 with
    | 0 -> Radi_Sqrt (gen_fun_or_var (depth-1))
    | _ -> Radi_Root (gen_fun_or_var (depth-1), 2 + Random.int 3)

(* Generate rational function *)
and gen_rational_function depth : rational_function =
  if depth <= 0 then
    match Random.int 2 with
    | 0 -> Fun_Div_Int (Var_X, 1 + Random.int 10)
    | _ -> Int_Div_Fun (1 + Random.int 10, Var_X)
  else
    match Random.int 2 with
    | 0 -> Fun_Div_Int (gen_fun_or_var (depth-1), 1 + Random.int 10)
    | _ -> Int_Div_Fun (1 + Random.int 10, gen_fun_or_var (depth-1))

(* Generate logarithmic function *)
and gen_log_function depth : log_function =
  if depth <= 0 then
    Ln_Fun Var_X
  else
    Ln_Fun (gen_fun_or_var (depth-1))

(* Generate trigonometric function *)
and gen_trig_function depth : trig_function =
  if depth <= 0 then
    match Random.int 2 with
    | 0 -> Trig_Sin Var_X
    | _ -> Trig_Cos Var_X
  else
    match Random.int 2 with
    | 0 -> Trig_Sin (gen_fun_or_var (depth-1))
    | _ -> Trig_Cos (gen_fun_or_var (depth-1))

(* Generate exponential function *)
and gen_exp_function depth : exp_function =
  if depth <= 0 then
    Exp Var_X
  else
    Exp (gen_fun_or_var (depth-1))

(* Generate function or variable *)
and gen_fun_or_var depth : fun_or_var =
  if depth <= 0 then
    Var_X
  else
    Func (gen_function_expr_root (depth-1))

(* Generate derivative problem section with answer_vars *)
and gen_derivative_problem_section () : problem_section * answer_vars =
  let (question_list, answer_vars) = gen_derivative_question_list () in
  (Problem question_list, answer_vars)

(* Generate derivative question list with accumulated answer_vars *)
and gen_derivative_question_list () : question_list * answer_vars =
  let n = min_question_num + Random.int (max_question_num - min_question_num + 1) in
  let rec aux i acc_questions acc_vars =
    if i = 0 then (List.rev acc_questions, List.rev acc_vars)
    else
      let (question, vars) = gen_derivative_question () in
      aux (i - 1) (question :: acc_questions) (List.rev_append vars acc_vars)
  in
  aux n [] []

and gen_calculus_problem_section () : problem_section * answer_vars =
  let (question_list, answer_vars) = gen_calculus_question_list () in
  (Problem question_list, answer_vars)

and gen_calculus_question_list () : question_list * answer_vars =
  let n = min_question_num + Random.int (max_question_num - min_question_num + 1) in
  let rec aux i acc_questions acc_vars =
    if i = 0 then (List.rev acc_questions, List.rev acc_vars)
    else
      let (question, vars) = gen_calculus_question () in
      aux (i - 1) (question :: acc_questions) (List.rev_append vars acc_vars)
  in
  aux n [] []
