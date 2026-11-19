(* rhema_types.ml -- the types of Rhema values, and what every operator and
   builtin function takes and gives.

   The engine checks types when a value is used, in the middle of generating
   a question. The checker uses this module to find the same mistakes before
   anything is generated. To keep the two from drifting apart, this is the
   one place that says what a function accepts: the checker reads its arity
   and its types from here, and rhema_types_test.ml calls the engine with
   every function, every argument and every type, so an entry that is
   stricter or looser than the engine fails a test. The four generators
   (integer_between and its like) are leaves, not functions, and are not
   here: Rhema_check.generator_builtins lists them, and their arguments and
   their value are numbers.

   A static type is a *set* of the types a value may have. Two productions of
   one nonterminal may compute an attribute as a number and as a formula, and
   the two branches of `cond` may differ; the set holds both. The checker
   reports a use only when no type in the set is accepted: what might go
   right is left to the engine. *)

type ty =
  | Number
  | Text
  | Truth
  | Complex
  | Formula
  | Polynomial
  | Equation
  | Proposition  (* a Boolean formula, made with bool_var and its like *)
  | Matrix
  | Set
  | Vector
  | Point
  | Norm_answer  (* vector_norm_answer *)
  | Unit_answer  (* vector_unit_answer *)
  | Direction_answer  (* vector_parallel_answer, vector_same_direction_answer *)
  | Blanked  (* text with answer blanks in it *)
  | Exactly  (* exactly(n): a whole number graded without tolerance *)
  | Plain  (* plain(v): a number or formula that must be worked out *)

let all =
  [
    Number; Text; Truth; Complex; Formula; Polynomial; Equation; Proposition; Matrix; Set;
    Vector; Point; Norm_answer; Unit_answer; Direction_answer; Blanked; Exactly; Plain;
  ]

let name = function
  | Number -> "a number"
  | Text -> "text"
  | Truth -> "a truth value"
  | Complex -> "a complex number"
  | Formula -> "a formula"
  | Polynomial -> "a polynomial"
  | Equation -> "an equation"
  | Proposition -> "a proposition"
  | Matrix -> "a matrix"
  | Set -> "a set"
  | Vector -> "a vector"
  | Point -> "a point"
  | Norm_answer -> "a norm answer"
  | Unit_answer -> "a unit-vector answer"
  | Direction_answer -> "a direction answer"
  | Blanked -> "text with answer blanks"
  | Exactly -> "an exactly() answer"
  | Plain -> "a plain() answer"

(* ------------------------------------------------------------------ *)
(* Sets of types                                                       *)
(* ------------------------------------------------------------------ *)

(* In the order of [all], without repeats. The empty set means that nothing
   is known yet: it is where inference starts, and it is never an error. *)
type set = ty list

let of_list types : set = List.filter (fun candidate -> List.mem candidate types) all
let unknown : set = []
let any : set = all
let union (left : set) (right : set) : set = of_list (left @ right)
let inter (left : set) (right : set) : set = List.filter (fun ty -> List.mem ty right) left
let without (types : set) (removed : ty list) : set =
  List.filter (fun ty -> not (List.mem ty removed)) types

let subset (left : set) (right : set) = List.for_all (fun ty -> List.mem ty right) left

(* ------------------------------------------------------------------ *)
(* What the engine converts on its own                                 *)
(* ------------------------------------------------------------------ *)

(* Wherever text is wanted a number is written out, so `"n = " ++ n` and
   str(3) work. Nothing else is converted. *)
let textual : set = of_list [ Text; Number ]

(* What `++` joins: text, numbers, and text that already holds blanks. *)
let joinable : set = of_list [ Text; Number; Blanked ]

(* What `=` and `!=` compare, a value with another of the same type. The
   ordering comparisons take numbers only. *)
let comparable : set =
  of_list
    [ Number; Text; Truth; Complex; Formula; Polynomial; Equation; Matrix; Proposition; Set;
      Vector; Point ]

(* What can be graded: everything but an equation, whose solutions are the
   answer, and text that itself holds a blank. *)
let answerable : set = without any [ Equation; Blanked ]

(* What a prompt shows in a {hole}: text, a number, or text with blanks. *)
let showable : set = joinable

(* No type the value may have is accepted. An unknown value is never
   refused. *)
let never (actual : set) (accepted : set) = actual <> [] && inter actual accepted = []

let describe (types : set) =
  if types = [] then "of unknown type"
  else if subset any types then "a value of any type"
  else if types = answerable then "a value that can be graded"
  else
    match List.rev_map name types with
    | [] -> "of unknown type"
    | [ only ] -> only
    | last :: earlier -> String.concat ", " (List.rev earlier) ^ " or " ^ last

(* ------------------------------------------------------------------ *)
(* Builtin functions                                                   *)
(* ------------------------------------------------------------------ *)

type parameter =
  | Takes of set  (* a value of one of these types *)
  | Node  (* a child written $n, for infix and prefix *)

type result =
  | Gives of set
  | Either  (* cond: whichever of its second and third arguments is chosen *)

type signature = { builtin : string; parameters : parameter list; result : result }

let builtins : signature list =
  let n = Takes [ Number ]
  and t = Takes textual
  and x = Takes [ Truth ]
  and c = Takes any
  and f = Takes [ Formula ]
  and p = Takes [ Polynomial ]
  and e = Takes [ Equation ]
  and b = Takes [ Proposition ]
  and m = Takes [ Matrix ]
  and s = Takes [ Set ]
  and v = Takes [ Vector ] in
  let gives builtin parameters result = { builtin; parameters; result = Gives [ result ] } in
  [
    (* ---- text ---- *)
    gives "str" [ t ] Text;
    gives "paren" [ t ] Text;
    gives "infix" [ Node; t; Node ] Text;
    gives "prefix" [ t; Node ] Text;
    (* Only the chosen branch is evaluated, so both are allowed any type. *)
    { builtin = "cond"; parameters = [ x; c; c ]; result = Either };
    (* ---- numbers ---- *)
    gives "abs" [ n ] Number;
    gives "min" [ n; n ] Number;
    gives "max" [ n; n ] Number;
    gives "complex" [ n; n ] Complex;
    gives "complex_latex" [ n; n ] Text;
    (* ---- formulas ---- *)
    gives "formula_constant" [ n ] Formula;
    gives "formula_variable" [ t ] Formula;
    gives "formula_add" [ f; f ] Formula;
    gives "formula_subtract" [ f; f ] Formula;
    gives "formula_multiply" [ f; f ] Formula;
    gives "formula_divide" [ f; f ] Formula;
    gives "formula_power" [ f; n ] Formula;
    gives "formula_negate" [ f ] Formula;
    gives "formula_sin" [ f ] Formula;
    gives "formula_cos" [ f ] Formula;
    gives "formula_tan" [ f ] Formula;
    gives "formula_exp" [ f ] Formula;
    gives "formula_ln" [ f ] Formula;
    gives "formula_sqrt" [ f ] Formula;
    gives "formula_substitute" [ f; t; f ] Formula;
    gives "differentiate" [ f; t ] Formula;
    gives "formula_latex" [ f ] Text;
    gives "formula_is_zero" [ f ] Truth;
    gives "formula_pi" [] Formula;
    gives "formula_value" [ f ] Number;
    gives "exact_sin" [ n; n ] Formula;
    gives "exact_cos" [ n; n ] Formula;
    gives "exact_tan" [ n; n ] Formula;
    gives "formula_to_polynomial" [ f; t ] Polynomial;
    (* ---- polynomials ---- *)
    gives "polynomial_constant" [ n; t ] Polynomial;
    gives "polynomial_variable" [ t ] Polynomial;
    gives "polynomial_monomial" [ n; n; t ] Polynomial;
    gives "polynomial_linear" [ n; n; t ] Polynomial;
    gives "polynomial_quadratic" [ n; n; n; t ] Polynomial;
    gives "polynomial_add" [ p; p ] Polynomial;
    gives "polynomial_subtract" [ p; p ] Polynomial;
    gives "polynomial_multiply" [ p; p ] Polynomial;
    gives "polynomial_scale" [ n; p ] Polynomial;
    gives "polynomial_power" [ p; n ] Polynomial;
    gives "polynomial_derivative" [ p ] Polynomial;
    gives "polynomial_evaluate" [ p; n ] Number;
    gives "polynomial_coefficient" [ p; n ] Number;
    gives "polynomial_degree" [ p ] Number;
    gives "polynomial_truncate" [ p; n ] Polynomial;
    gives "polynomial_is_zero" [ p ] Truth;
    gives "polynomial_formula" [ p ] Formula;
    gives "polynomial_latex" [ p ] Text;
    (* ---- equations ---- *)
    gives "equation" [ f; f ] Equation;
    gives "polynomial_equation" [ p; p ] Equation;
    gives "equation_normal_form" [ e ] Formula;
    gives "equation_latex" [ e ] Text;
    gives "equation_is_satisfied" [ e; t; n ] Truth;
    gives "equation_has_exact_solutions" [ e; t ] Truth;
    gives "equation_solution_count" [ e; t ] Number;
    gives "equation_solution_set" [ e; t ] Set;
    gives "equation_unique_solution" [ e; t ] Number;
    (* ---- propositions ---- *)
    gives "bool_var" [ t ] Proposition;
    gives "bool_true" [] Proposition;
    gives "bool_false" [] Proposition;
    gives "bool_not" [ b ] Proposition;
    gives "bool_and" [ b; b ] Proposition;
    gives "bool_or" [ b; b ] Proposition;
    gives "bool_xor" [ b; b ] Proposition;
    gives "bool_imp" [ b; b ] Proposition;
    gives "bool_iff" [ b; b ] Proposition;
    gives "bool_latex" [ b ] Text;
    gives "bool_equivalent" [ b; b ] Truth;
    gives "bool_evaluate" [ b; t; n ] Truth;
    gives "bool_sensitivity" [ b; t; n ] Number;
    gives "bool_is_tautology" [ b ] Truth;
    gives "bool_is_contradiction" [ b ] Truth;
    gives "bool_is_tidy" [ b ] Truth;
    gives "bool_is_atom" [ b ] Truth;
    gives "bool_top" [ b ] Text;
    gives "bool_size" [ b ] Number;
    gives "bool_negations" [ b ] Number;
    gives "bool_depth" [ b ] Number;
    gives "bool_count" [ b; t ] Number;
    gives "bool_variable_count" [ b ] Number;
    gives "bool_model_count" [ b ] Number;
    gives "bool_without_conditionals" [ b ] Proposition;
    (* ---- matrices ---- *)
    gives "matrix2" [ n; n; n; n ] Matrix;
    gives "matrix3" [ n; n; n; n; n; n; n; n; n ] Matrix;
    gives "matrix_identity" [ n ] Matrix;
    gives "matrix_add" [ m; m ] Matrix;
    gives "matrix_subtract" [ m; m ] Matrix;
    gives "matrix_multiply" [ m; m ] Matrix;
    gives "matrix_scale" [ n; m ] Matrix;
    gives "matrix_transpose" [ m ] Matrix;
    gives "matrix_determinant" [ m ] Number;
    gives "matrix_inverse" [ m ] Matrix;
    gives "matrix_is_invertible" [ m ] Truth;
    gives "matrix_entry" [ m; n; n ] Number;
    gives "matrix_vector" [ m; v ] Vector;
    gives "matrix_latex" [ m ] Text;
    gives "matrix_row_latex" [ m; n ] Text;
    gives "matrix_row" [ v ] Matrix;
    gives "matrix_column" [ v ] Matrix;
    gives "matrix_stack" [ m; m ] Matrix;
    gives "matrix_augment" [ m; m ] Matrix;
    gives "matrix_rows" [ m ] Number;
    gives "matrix_columns" [ m ] Number;
    gives "matrix_rank" [ m ] Number;
    gives "matrix_rref" [ m ] Matrix;
    gives "matrix_null_space" [ m ] Matrix;
    (* ---- points ---- *)
    gives "point2" [ n; n ] Point;
    gives "point3" [ n; n; n ] Point;
    gives "point_latex" [ Takes [ Point ] ] Text;
    (* ---- a whole number written in another base ---- *)
    gives "base_digits" [ n; n ] Text;
    gives "base_number" [ n; n ] Number;
    (* ---- answers ---- *)
    gives "blank" [ Takes answerable ] Blanked;
    gives "blank_wide" [ Takes answerable; n ] Blanked;
    gives "plain" [ Takes [ Number; Formula; Polynomial ] ] Plain;
    gives "exactly" [ n ] Exactly;
    (* ---- one component of a vector ---- *)
    gives "vector_entry" [ v; n ] Number;
    (* ---- sets ---- *)
    gives "set_empty" [] Set;
    gives "set_insert" [ s; n ] Set;
    gives "set_interval" [ n; n; x; x ] Set;
    gives "set_above" [ n; x ] Set;
    gives "set_below" [ n; x ] Set;
    gives "set_union" [ s; s ] Set;
    gives "set_intersection" [ s; s ] Set;
    gives "set_difference" [ s; s ] Set;
    gives "set_latex" [ s ] Text;
    (* ---- vectors ---- *)
    gives "vector2" [ n; n ] Vector;
    gives "vector3" [ n; n; n ] Vector;
    gives "vector4" [ n; n; n; n ] Vector;
    gives "vector_add" [ v; v ] Vector;
    gives "vector_subtract" [ v; v ] Vector;
    gives "vector_scale" [ n; v ] Vector;
    gives "vector_dot" [ v; v ] Number;
    gives "vector_cross" [ v; v ] Vector;
    gives "vector_latex" [ v ] Text;
    gives "vector_is_zero" [ v ] Truth;
    gives "vector_norm_answer" [ v ] Norm_answer;
    gives "vector_unit_answer" [ v ] Unit_answer;
    gives "vector_parallel_answer" [ v ] Direction_answer;
    gives "vector_same_direction_answer" [ v ] Direction_answer;
    (* ---- whole numbers ----
       Bitwise operations. A question that asks whether two expressions are
       equivalent has to compare them under every assignment, not just one;
       the usual way to carry that is a truth table, and a truth table over
       n variables is exactly a 2^n-bit number. *)
    gives "bit_and" [ n; n ] Number;
    gives "bit_or" [ n; n ] Number;
    gives "bit_xor" [ n; n ] Number;
    (* Counting and number theory. They work on exact integers and stop
       generation, with a message, outside their range (a factorial above
       20!, a modulus that is not positive, an inverse that does not exist):
       the type is a number, and whether it is whole is the engine's to say. *)
    gives "number_latex" [ n ] Text;
    gives "factorial" [ n ] Number;
    gives "choose" [ n; n ] Number;
    gives "permutations" [ n; n ] Number;
    gives "gcd" [ n; n ] Number;
    gives "lcm" [ n; n ] Number;
    gives "pow_mod" [ n; n; n ] Number;
    gives "mod_inverse" [ n; n ] Number;
  ]

let signature builtin = List.find_opt (fun entry -> entry.builtin = builtin) builtins

(* A signature in words, for `rhema doc`: what it takes, and what it gives.
   Text that also takes a number is listed as text, as the reference says:
   a number is written out wherever text is wanted. *)
let signature_words entry =
  let bare ty =
    let named = name ty in
    let without prefix =
      let length = String.length prefix in
      if String.length named > length && String.sub named 0 length = prefix then
        Some (String.sub named length (String.length named - length))
      else None
    in
    match (without "a ", without "an ") with
    | Some rest, _ | None, Some rest -> rest
    | None, None -> named
  in
  let words (types : set) =
    if subset any types then "any value"
    else if types = textual then "text"
    else if types = answerable then "any answer"
    else String.concat " or " (List.map bare types)
  in
  let takes =
    match entry.parameters with
    | [] -> "nothing"
    | parameters ->
        parameters
        |> List.map (function Takes types -> words types | Node -> "a child $n")
        |> String.concat ", "
  in
  (takes, match entry.result with Gives types -> words types | Either -> "its second or third argument")

(* ------------------------------------------------------------------ *)
(* Operators                                                           *)
(* ------------------------------------------------------------------ *)

(* What a unary operator takes and gives. *)
let unary = function
  | "-" -> Some ([ Number ], [ Number ])
  | "not" -> Some ([ Truth ], [ Truth ])
  | _ -> None

type operator =
  | Both of set * set
      (* each side one of the first set, giving the second: + - * / % ^ on
         numbers, `and` and `or` on truth values, < <= > >= on numbers *)
  | Join  (* ++ : text, numbers and text with blanks; blanks if either has them *)
  | Same  (* = and != : two values of one comparable type, giving a truth value *)

let binary = function
  | "+" | "-" | "*" | "/" | "%" | "^" -> Some (Both ([ Number ], [ Number ]))
  | "and" | "or" -> Some (Both ([ Truth ], [ Truth ]))
  | "<" | "<=" | ">" | ">=" -> Some (Both ([ Number ], [ Truth ]))
  | "++" -> Some Join
  | "=" | "!=" -> Some Same
  | _ -> None

(* ------------------------------------------------------------------ *)
(* Leaves                                                              *)
(* ------------------------------------------------------------------ *)

(* A generator leaf draws a number; a quoted word or a bare terminal carries
   its text. Both are read as $n.value. *)
let generator_value : set = [ Number ]
let terminal_value : set = [ Text ]
