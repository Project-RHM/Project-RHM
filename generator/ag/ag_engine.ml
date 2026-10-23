(* ag_engine.ml — generate a question from a checked .ag specification.

   Generation is a single recursive walk that carries information in both
   directions, which is exactly the two-pass model the checker enforces:

     going down   inherited attributes (len, digit) choose the shape
     coming back  synthesized attributes (value, latex) compute the result

   Because a node's synthesized attributes depend only on its children, they
   are evaluated as soon as those children are built. A [require] clause is
   therefore checked while the engine is still standing at that node, so a
   violation retries just that subtree instead of discarding the whole
   expression and starting over. *)

open Ag_ast

exception Generation_error of string

let error message = raise (Generation_error message)

(* ------------------------------------------------------------------ *)
(* Runtime values                                                      *)
(* ------------------------------------------------------------------ *)

type value =
  | Num of Ag_number.t
  | Text of string
  | Truth of bool
  | Complex of Ag_number.t * Ag_number.t
  | Formula of Ag_formula.t
  | Polynomial of Ag_polynomial.t
  | Equation of Ag_equation.t
  | Boolean of Ag_boolean.t
  | Matrix of Ag_matrix.t
  | Set of Ag_set.t
  | Vector of Ag_vector.t
  | VectorNormAnswer of Ag_vector.t
  | VectorUnitAnswer of Ag_vector.t
  | VectorDirectionAnswer of Ag_vector.t * bool

let describe_value = function
  | Num number -> Ag_number.to_string number
  | Text text -> text
  | Truth true -> "true"
  | Truth false -> "false"
  | Complex (real, imaginary) ->
      Printf.sprintf "Complex(%s,%s)" (Ag_number.to_string real)
        (Ag_number.to_string imaginary)
  | Formula expression -> "Formula(" ^ Ag_formula.to_pg expression ^ ")"
  | Matrix matrix -> Ag_matrix.to_pg matrix
  | Polynomial polynomial -> "Polynomial(" ^ Ag_polynomial.to_pg polynomial ^ ")"
  | Equation equation -> "Equation(" ^ Ag_equation.to_pg equation ^ ")"
  | Boolean formula -> "Boolean(" ^ Ag_boolean.to_latex formula ^ ")"
  | Set set -> "Set(" ^ Ag_set.to_pg set ^ ")"
  | Vector vector -> "Vector(" ^ Ag_vector.component_text vector ^ ")"
  | VectorNormAnswer vector -> "VectorNorm(" ^ Ag_vector.component_text vector ^ ")"
  | VectorUnitAnswer vector -> "VectorUnit(" ^ Ag_vector.component_text vector ^ ")"
  | VectorDirectionAnswer (vector, same_direction) ->
      Printf.sprintf "VectorDirection(%s,sameDirection=%b)"
        (Ag_vector.component_text vector) same_direction

let as_number context = function
  | Num number -> number
  | other ->
      error
        (Printf.sprintf "%s expected a number but received \"%s\"" context
           (describe_value other))

let as_text context = function
  | Text text -> text
  | Num number -> Ag_number.to_string number
  | Truth _ | Complex _ | Formula _ | Polynomial _ | Equation _ | Boolean _ | Matrix _ | Set _
  | Vector _ | VectorNormAnswer _
  | VectorUnitAnswer _ | VectorDirectionAnswer _ ->
      error
        (Printf.sprintf "%s expected text but received a non-text value" context)

let as_truth context = function
  | Truth truth -> truth
  | other ->
      error
        (Printf.sprintf "%s expected a true/false value but received \"%s\"" context
           (describe_value other))

let as_formula context = function
  | Formula expression -> expression
  | other ->
      error
        (Printf.sprintf "%s expected a formula but received \"%s\"" context
           (describe_value other))

let as_polynomial context = function
  | Polynomial polynomial -> polynomial
  | other ->
      error
        (Printf.sprintf "%s expected a polynomial but received \"%s\"" context
           (describe_value other))

let as_equation context = function
  | Equation equation -> equation
  | other ->
      error
        (Printf.sprintf "%s expected an equation but received \"%s\"" context
           (describe_value other))

let as_matrix context = function
  | Matrix matrix -> matrix
  | other ->
      error
        (Printf.sprintf "%s expected a matrix but received \"%s\"" context
           (describe_value other))

let as_boolean context = function
  | Boolean formula -> formula
  | other ->
      error
        (Printf.sprintf "%s expected a propositional formula but received \"%s\"" context
           (describe_value other))

let as_set context = function
  | Set set -> set
  | other ->
      error
        (Printf.sprintf "%s expected a set but received \"%s\"" context
           (describe_value other))

let as_vector context = function
  | Vector vector -> vector
  | other ->
      error
        (Printf.sprintf "%s expected a vector but received \"%s\"" context
           (describe_value other))

let format_complex_latex real imaginary =
  let zero = Ag_number.zero and one = Ag_number.of_int 1 in
  let real_is_zero = Ag_number.equal real zero in
  let imaginary_is_zero = Ag_number.equal imaginary zero in
  let imaginary_is_negative = Ag_number.compare imaginary zero < 0 in
  let magnitude = Ag_number.absolute imaginary in
  let imaginary_term =
    if Ag_number.equal magnitude one then "i"
    else Ag_number.to_string magnitude ^ "i"
  in
  if imaginary_is_zero then Ag_number.to_string real
  else if real_is_zero then
    (if imaginary_is_negative then "-" else "") ^ imaginary_term
  else
    Ag_number.to_string real
    ^ (if imaginary_is_negative then " - " else " + ")
    ^ imaginary_term

(* ------------------------------------------------------------------ *)
(* Generated trees                                                     *)
(* ------------------------------------------------------------------ *)

(* [level] is the binding strength of the operator a node was built with,
   taken from the grammar's precedence table. Leaves, and rules that name no
   declared operator, are atoms and never need parentheses around them. *)
let atom_level = max_int

type node = {
  symbol : string;
  applied_rule : rule option;
  children : node list;
  inherited_attributes : (string * int) list;
  attributes : (string * value) list;
  level : int;
}

let attribute node name =
  match List.assoc_opt name node.attributes with
  | Some value -> value
  | None ->
      error
        (Printf.sprintf "'%s' has no attribute '%s'%s" node.symbol name
           (if node.applied_rule = None then
              " — it is a leaf, which carries only 'value'; write str($n.value) to \
               render it"
            else ""))

(* How much a budget was decreased across the whole tree. The tests use this to
   confirm that a budget of n really does produce n operators. *)
let rec consumption node name =
  let here =
    match node.applied_rule with
    | None -> 0
    | Some rule ->
        List.fold_left
          (fun total equation ->
            match equation with
            | Assign (assigned, Unary ("-", Int amount), _) when assigned = name ->
                total + amount
            | Assign (assigned, Int amount, _) when assigned = name && amount < 0 ->
                total - amount
            | _ -> total)
          0 rule.equations
  in
  List.fold_left (fun total child -> total + consumption child name) here node.children

(* ------------------------------------------------------------------ *)
(* Budgets                                                             *)
(* ------------------------------------------------------------------ *)

type environment = (string * int) list

let lookup environment name =
  match List.assoc_opt name environment with
  | Some value -> value
  | None -> error (Printf.sprintf "attribute '%s' is not in scope" name)

let bind environment name value = (name, value) :: List.remove_assoc name environment

(* Every random decision that could have gone another way bumps this counter.
   The retry loops compare it before and after a failed attempt: if nothing
   was drawn, the exact same failure would repeat forever, so they stop
   immediately instead of burning the remaining retries. A draw whose range
   holds a single value does not count — it could not have gone differently. *)
let choice_points = ref 0

let chose () = incr choice_points

(* Tag a failure message as unfixable-by-retry, once, no matter how many
   retry loops it bubbles up through on the way out. *)
let deterministic_tag = "; retrying cannot help, no random choice was involved"

let mark_deterministic message =
  let tag_length = String.length deterministic_tag in
  let message_length = String.length message in
  if
    message_length >= tag_length
    && String.sub message (message_length - tag_length) tag_length = deterministic_tag
  then message
  else message ^ deterministic_tag

(* Split [total] into [count] non-negative parts, uniformly across every way of
   doing so. Drawing each part in turn and shuffling, as an earlier version
   did, favours lopsided splits once there are more than two parts. *)
let random_partition total count =
  if count <= 0 then []
  else if count = 1 then [ total ]
  else begin
    if total > 0 then chose ();
    (* Stars and bars: pick count-1 distinct bar positions among
       total + count - 1 slots; the gaps between the bars are the parts. *)
    let slots = total + count - 1 in
    let bars = Array.make (count - 1) 0 in
    let chosen = Hashtbl.create (count - 1) in
    for index = 0 to count - 2 do
      let rec draw () =
        let candidate = Random.int slots in
        if Hashtbl.mem chosen candidate then draw ()
        else (
          Hashtbl.add chosen candidate ();
          candidate)
      in
      bars.(index) <- draw ()
    done;
    Array.sort Stdlib.compare bars;
    let parts = Array.make count 0 in
    let previous = ref (-1) in
    for index = 0 to count - 2 do
      parts.(index) <- bars.(index) - !previous - 1;
      previous := bars.(index)
    done;
    parts.(count - 1) <- slots - !previous - 1;
    Array.to_list parts
  end

let weighted_pick rules =
  let total = List.fold_left (fun sum rule -> sum + rule.weight) 0 rules in
  if total <= 0 then error "no candidate rule has a positive weight";
  if List.length rules > 1 then chose ();
  let target = Random.int total in
  let rec choose offset = function
    | [] -> error "internal: ran off the end of the candidate list"
    | rule :: rest ->
        if target < offset + rule.weight then rule else choose (offset + rule.weight) rest
  in
  choose 0 rules

let draw_integer digits =
  chose ();
  if digits <= 1 then Random.int 10
  else
    let rec power_of_ten accumulator exponent =
      if exponent <= 0 then accumulator
      else power_of_ten (accumulator * 10) (exponent - 1)
    in
    let lower = power_of_ten 1 (digits - 1) in
    let upper = (power_of_ten 1 digits) - 1 in
    lower + Random.int (upper - lower + 1)

let draw_integer_between name lower upper =
  if lower > upper then
    error
      (Printf.sprintf "%s lower bound %d is greater than upper bound %d" name lower
         upper);
  let width = upper - lower + 1 in
  if width <= 0 then error (Printf.sprintf "%s range is too wide" name);
  if width > 1 then chose ();
  lower + Random.int width

let draw_nonzero_integer_between lower upper =
  if lower > upper then
    error
      (Printf.sprintf
         "nonzero_integer_between lower bound %d is greater than upper bound %d"
         lower upper);
  if lower = 0 && upper = 0 then
    error "nonzero_integer_between(0, 0) has no non-zero value to draw";
  if upper < 0 || lower > 0 then
    draw_integer_between "nonzero_integer_between" lower upper
  else
    let negative_count = -lower in
    let positive_count = upper in
    if negative_count + positive_count > 1 then chose ();
    let choice = Random.int (negative_count + positive_count) in
    if choice < negative_count then lower + choice
    else 1 + (choice - negative_count)

let draw_generator name arguments =
  match (name, arguments) with
  | "integer", [ digits ] -> draw_integer digits
  | "nonzero_integer", [ digits ] ->
      let rec attempt remaining =
        if remaining <= 0 then error "nonzero_integer could not find a value"
        else
          let candidate = draw_integer digits in
          if candidate = 0 then attempt (remaining - 1) else candidate
      in
      attempt 50
  | "integer_between", [ lower; upper ] ->
      draw_integer_between name lower upper
  | "nonzero_integer_between", [ lower; upper ] ->
      draw_nonzero_integer_between lower upper
  | _ ->
      error
        (Printf.sprintf "cannot apply generator '%s' to %d argument(s)" name
           (List.length arguments))

(* ------------------------------------------------------------------ *)
(* Evaluating the right-hand side of an equation                       *)
(* ------------------------------------------------------------------ *)

(* [target] is the attribute currently being computed. [infix] renders its
   operands with that same attribute, so `latex = infix($1, "+", $3)` joins the
   children's `latex`, and a grammar that names its rendering attribute
   something else behaves identically without the engine hard-coding a name. *)
let rec evaluate ?(self = []) ~globals ~is_inherited ~rule_precedence ~environment
    ~children ~rule ~target expression =
  let recurse =
    evaluate ~self ~globals ~is_inherited ~rule_precedence ~environment ~children ~rule
      ~target
  in
  let child_at index =
    match List.nth_opt children (index - 1) with
    | Some node -> node
    | None ->
        error
          (Printf.sprintf "$%d is out of range: this rule has %d symbols on the right"
             index (List.length children))
  in
  let node_argument context = function
    | Child index -> child_at index
    | _ ->
        error
          (Printf.sprintf "%s needs its operands written as $n, for example %s($1, \"+\", $3)"
             context context)
  in
  match expression with
  | Int number -> Num (Ag_number.of_int number)
  | Str text -> Text text
  | Attr_here name -> (
      (* An attribute this rule computed earlier wins, so a rule can build on
         its own work; then a question-level random or let. The checker has
         already made sure those two sets of names do not overlap. *)
      match List.assoc_opt name self with
      | Some value -> value
      | None -> (
          match List.assoc_opt name globals with
          | Some value -> value
          | None ->
              if is_inherited name then Num (Ag_number.of_int (lookup environment name))
              else error (Printf.sprintf "'%s' is not in scope" name)))
  | Attr_child (index, name) -> attribute (child_at index) name
  | Attr_child_named (owner, name) -> (
      (* calc.given: a random or let of an imported module, kept under its
         qualified name among this question's values. *)
      match List.assoc_opt (owner ^ "." ^ name) globals with
      | Some value -> value
      | None ->
          error
            (Printf.sprintf "%s.%s cannot be used inside a rule; write $n.%s instead" owner
               name name))
  | Child index ->
      error
        (Printf.sprintf
           "$%d is a node, not a value; write $%d.value, or pass it to infix()" index
           index)
  | Unary ("-", body) -> Num (Ag_number.negate (as_number "-" (recurse body)))
  | Unary ("not", body) -> Truth (not (as_truth "not" (recurse body)))
  | Unary (operator, _) -> error (Printf.sprintf "unknown operator '%s'" operator)
  | Binary ("and", left, right) ->
      Truth (as_truth "and" (recurse left) && as_truth "and" (recurse right))
  | Binary ("or", left, right) ->
      Truth (as_truth "or" (recurse left) || as_truth "or" (recurse right))
  | Binary ("++", left, right) ->
      Text (as_text "++" (recurse left) ^ as_text "++" (recurse right))
  | Binary (operator, left, right) -> (
      let left = recurse left and right = recurse right in
      let arithmetic apply = Num (apply (as_number operator left) (as_number operator right)) in
      let comparison apply =
        match (left, right) with
        | Text left, Text right ->
            if operator = "=" then Truth (left = right)
            else if operator = "!=" then Truth (left <> right)
            else error (Printf.sprintf "'%s' cannot compare text" operator)
        (* Equality on truth values is how a biconditional is written, and
           inequality is exclusive or. *)
        | Truth left, Truth right ->
            if operator = "=" then Truth (left = right)
            else if operator = "!=" then Truth (left <> right)
            else
              error
                (Printf.sprintf "'%s' cannot order true/false values" operator)
        | Complex (left_real, left_imaginary), Complex (right_real, right_imaginary) ->
            let equal =
              Ag_number.equal left_real right_real
              && Ag_number.equal left_imaginary right_imaginary
            in
            if operator = "=" then Truth equal
            else if operator = "!=" then Truth (not equal)
            else error (Printf.sprintf "'%s' cannot order complex values" operator)
        | Formula left, Formula right ->
            if operator = "=" then Truth (Ag_formula.equal left right)
            else if operator = "!=" then Truth (not (Ag_formula.equal left right))
            else error (Printf.sprintf "'%s' cannot order formulas" operator)
        | Polynomial left, Polynomial right ->
            if operator = "=" then Truth (Ag_polynomial.equal left right)
            else if operator = "!=" then Truth (not (Ag_polynomial.equal left right))
            else error (Printf.sprintf "'%s' cannot order polynomials" operator)
        | Equation left, Equation right ->
            if operator = "=" then Truth (Ag_equation.equal left right)
            else if operator = "!=" then Truth (not (Ag_equation.equal left right))
            else error (Printf.sprintf "'%s' cannot order equations" operator)
        | Matrix left, Matrix right ->
            if operator = "=" then Truth (Ag_matrix.equal left right)
            else if operator = "!=" then Truth (not (Ag_matrix.equal left right))
            else error (Printf.sprintf "'%s' cannot order matrices" operator)
        | Boolean left, Boolean right ->
            (* Two formulas are equal when they are logically equivalent. *)
            if operator = "=" then Truth (Ag_boolean.equivalent left right)
            else if operator = "!=" then Truth (not (Ag_boolean.equivalent left right))
            else error (Printf.sprintf "'%s' cannot order propositional formulas" operator)
        | Set left, Set right ->
            if operator = "=" then Truth (Ag_set.equal left right)
            else if operator = "!=" then Truth (not (Ag_set.equal left right))
            else error (Printf.sprintf "'%s' cannot order sets" operator)
        | Vector left, Vector right ->
            if operator = "=" then Truth (Ag_vector.equal left right)
            else if operator = "!=" then Truth (not (Ag_vector.equal left right))
            else error (Printf.sprintf "'%s' cannot order vectors" operator)
        | _ ->
            Truth
              (apply
                 (Ag_number.compare (as_number operator left) (as_number operator right)))
      in
      match operator with
      | "+" -> arithmetic Ag_number.add
      | "-" -> arithmetic Ag_number.subtract
      | "*" -> arithmetic Ag_number.multiply
      | "/" -> arithmetic Ag_number.divide
      | "%" -> arithmetic Ag_number.modulo
      | "^" -> arithmetic Ag_number.power
      | "=" -> comparison (fun result -> result = 0)
      | "!=" -> comparison (fun result -> result <> 0)
      | "<" -> comparison (fun result -> result < 0)
      | "<=" -> comparison (fun result -> result <= 0)
      | ">" -> comparison (fun result -> result > 0)
      | ">=" -> comparison (fun result -> result >= 0)
      | _ -> error (Printf.sprintf "unknown operator '%s'" operator))
  | Call ("infix", [ left; operator; right ]) ->
      let left = node_argument "infix" left and right = node_argument "infix" right in
      let operator = as_text "infix" (recurse operator) in
      let my_level, associativity =
        match rule with
        | Some rule -> (
            match rule_precedence rule with
            | Some (_, level, associativity) -> (level, associativity)
            | None -> (atom_level, Left))
        | None -> (atom_level, Left)
      in
      let render node ~is_left =
        let text = as_text "infix" (attribute node target) in
        let needs_parentheses =
          node.level < my_level
          || node.level = my_level
             && (match associativity with
                | Nonassoc -> true
                | Left -> not is_left
                | Right -> is_left)
        in
        if needs_parentheses then "(" ^ text ^ ")" else text
      in
      Text
        (String.concat " " [ render left ~is_left:true; operator; render right ~is_left:false ])
  | Call ("prefix", [ operator; operand ]) ->
      let operand = node_argument "prefix" operand in
      let operator = as_text "prefix" (recurse operator) in
      let my_level =
        match rule with
        | Some rule -> (
            match rule_precedence rule with
            | Some (_, level, _) -> level
            | None -> atom_level)
        | None -> atom_level
      in
      let text = as_text "prefix" (attribute operand target) in
      (* A prefix operator binds looser than anything tighter than itself, so
         its operand needs brackets only when the operand binds less tightly. *)
      Text (operator ^ " " ^ (if operand.level < my_level then "(" ^ text ^ ")" else text))
  | Call ("cond", [ test; consequence; alternative ]) ->
      if as_truth "cond" (recurse test) then recurse consequence
      else recurse alternative
  | Call ("paren", [ body ]) -> Text ("(" ^ as_text "paren" (recurse body) ^ ")")
  | Call ("str", [ body ]) -> Text (as_text "str" (recurse body))
  | Call ("complex", [ real; imaginary ]) ->
      Complex
        (as_number "complex" (recurse real), as_number "complex" (recurse imaginary))
  | Call ("complex_latex", [ real; imaginary ]) ->
      Text
        (format_complex_latex
           (as_number "complex_latex" (recurse real))
           (as_number "complex_latex" (recurse imaginary)))
  | Call ("formula_constant", [ number ]) ->
      Formula (Ag_formula.constant (as_number "formula_constant" (recurse number)))
  | Call ("formula_variable", [ name ]) ->
      let name = as_text "formula_variable" (recurse name) in
      (try Formula (Ag_formula.variable name)
       with Invalid_argument message -> error message)
  | Call ("formula_add", [ left; right ]) ->
      Formula
        (Ag_formula.add
           (as_formula "formula_add" (recurse left))
           (as_formula "formula_add" (recurse right)))
  | Call ("formula_subtract", [ left; right ]) ->
      Formula
        (Ag_formula.subtract
           (as_formula "formula_subtract" (recurse left))
           (as_formula "formula_subtract" (recurse right)))
  | Call ("formula_multiply", [ left; right ]) ->
      Formula
        (Ag_formula.multiply
           (as_formula "formula_multiply" (recurse left))
           (as_formula "formula_multiply" (recurse right)))
  | Call ("formula_divide", [ left; right ]) ->
      (try
         Formula
           (Ag_formula.divide
              (as_formula "formula_divide" (recurse left))
              (as_formula "formula_divide" (recurse right)))
       with Invalid_argument message -> error message)
  | Call ("formula_power", [ base; exponent ]) ->
      let exponent =
        Ag_number.require_integer "formula_power"
          (as_number "formula_power" (recurse exponent))
      in
      Formula
        (Ag_formula.power (as_formula "formula_power" (recurse base)) exponent)
  | Call ("formula_negate", [ body ]) ->
      Formula (Ag_formula.negate (as_formula "formula_negate" (recurse body)))
  | Call ("formula_sin", [ body ]) ->
      Formula (Ag_formula.sin (as_formula "formula_sin" (recurse body)))
  | Call ("formula_cos", [ body ]) ->
      Formula (Ag_formula.cos (as_formula "formula_cos" (recurse body)))
  | Call ("formula_tan", [ body ]) ->
      Formula (Ag_formula.tan (as_formula "formula_tan" (recurse body)))
  | Call ("formula_exp", [ body ]) ->
      Formula (Ag_formula.exp (as_formula "formula_exp" (recurse body)))
  | Call ("formula_ln", [ body ]) ->
      Formula (Ag_formula.ln (as_formula "formula_ln" (recurse body)))
  | Call ("formula_sqrt", [ body ]) ->
      Formula (Ag_formula.sqrt (as_formula "formula_sqrt" (recurse body)))
  | Call ("formula_substitute", [ body; variable; replacement ]) ->
      let body = as_formula "formula_substitute" (recurse body)
      and variable = as_text "formula_substitute" (recurse variable)
      and replacement = as_formula "formula_substitute" (recurse replacement) in
      Formula (Ag_formula.substitute ~variable ~replacement body)
  | Call ("differentiate", [ body; variable ]) ->
      let expression = as_formula "differentiate" (recurse body) in
      let variable = as_text "differentiate" (recurse variable) in
      Formula (Ag_formula.differentiate ~variable expression)
  | Call ("formula_latex", [ body ]) ->
      Text (Ag_formula.to_latex (as_formula "formula_latex" (recurse body)))
  | Call ("formula_is_zero", [ body ]) ->
      Truth (Ag_formula.is_zero (as_formula "formula_is_zero" (recurse body)))
  | Call ("formula_to_polynomial", [ body; variable ]) ->
      let body = as_formula "formula_to_polynomial" (recurse body)
      and variable = as_text "formula_to_polynomial" (recurse variable) in
      (match Ag_polynomial.of_formula ~variable body with
      | Some polynomial -> Polynomial polynomial
      | None -> error "formula_to_polynomial received a non-polynomial formula")
  | Call ("polynomial_constant", [ value; variable ]) ->
      Polynomial
        (Ag_polynomial.constant
           ~variable:(as_text "polynomial_constant" (recurse variable))
           (as_number "polynomial_constant" (recurse value)))
  | Call ("polynomial_variable", [ variable ]) ->
      Polynomial (Ag_polynomial.variable (as_text "polynomial_variable" (recurse variable)))
  | Call ("polynomial_monomial", [ coefficient; degree; variable ]) ->
      let degree =
        Ag_number.require_integer "polynomial_monomial"
          (as_number "polynomial_monomial" (recurse degree))
      in
      (try
         Polynomial
           (Ag_polynomial.monomial
              ~variable:(as_text "polynomial_monomial" (recurse variable))
              (as_number "polynomial_monomial" (recurse coefficient)) degree)
       with Invalid_argument message -> error message)
  | Call ("polynomial_linear", [ coefficient; constant_term; variable ]) ->
      Polynomial
        (Ag_polynomial.linear
           ~variable:(as_text "polynomial_linear" (recurse variable))
           (as_number "polynomial_linear" (recurse coefficient))
           (as_number "polynomial_linear" (recurse constant_term)))
  | Call
      ( "polynomial_quadratic",
        [ quadratic_coefficient; linear_coefficient; constant_term; variable ] ) ->
      Polynomial
        (Ag_polynomial.quadratic
           ~variable:(as_text "polynomial_quadratic" (recurse variable))
           (as_number "polynomial_quadratic" (recurse quadratic_coefficient))
           (as_number "polynomial_quadratic" (recurse linear_coefficient))
           (as_number "polynomial_quadratic" (recurse constant_term)))
  | Call ("polynomial_add", [ left; right ]) ->
      (try
         Polynomial
           (Ag_polynomial.add (as_polynomial "polynomial_add" (recurse left))
              (as_polynomial "polynomial_add" (recurse right)))
       with Invalid_argument message -> error message)
  | Call ("polynomial_subtract", [ left; right ]) ->
      (try
         Polynomial
           (Ag_polynomial.subtract (as_polynomial "polynomial_subtract" (recurse left))
              (as_polynomial "polynomial_subtract" (recurse right)))
       with Invalid_argument message -> error message)
  | Call ("polynomial_multiply", [ left; right ]) ->
      (try
         Polynomial
           (Ag_polynomial.multiply (as_polynomial "polynomial_multiply" (recurse left))
              (as_polynomial "polynomial_multiply" (recurse right)))
       with Invalid_argument message -> error message)
  | Call ("polynomial_scale", [ scalar; polynomial ]) ->
      Polynomial
        (Ag_polynomial.scale (as_number "polynomial_scale" (recurse scalar))
           (as_polynomial "polynomial_scale" (recurse polynomial)))
  | Call ("polynomial_power", [ polynomial; exponent ]) ->
      let exponent =
        Ag_number.require_integer "polynomial_power"
          (as_number "polynomial_power" (recurse exponent))
      in
      (try
         Polynomial
           (Ag_polynomial.power (as_polynomial "polynomial_power" (recurse polynomial))
              exponent)
       with Invalid_argument message -> error message)
  | Call ("polynomial_derivative", [ polynomial ]) ->
      Polynomial
        (Ag_polynomial.derivative
           (as_polynomial "polynomial_derivative" (recurse polynomial)))
  | Call ("polynomial_evaluate", [ polynomial; value ]) ->
      Num
        (Ag_polynomial.evaluate (as_polynomial "polynomial_evaluate" (recurse polynomial))
           (as_number "polynomial_evaluate" (recurse value)))
  | Call ("polynomial_coefficient", [ polynomial; degree ]) ->
      let degree =
        Ag_number.require_integer "polynomial_coefficient"
          (as_number "polynomial_coefficient" (recurse degree))
      in
      (try
         Num
           (Ag_polynomial.coefficient
              (as_polynomial "polynomial_coefficient" (recurse polynomial)) degree)
       with Invalid_argument message -> error message)
  | Call ("polynomial_degree", [ polynomial ]) ->
      let degree =
        match Ag_polynomial.degree (as_polynomial "polynomial_degree" (recurse polynomial)) with
        | Some degree -> degree
        | None -> -1
      in
      Num (Ag_number.of_int degree)
  | Call ("polynomial_is_zero", [ polynomial ]) ->
      Truth (Ag_polynomial.is_zero (as_polynomial "polynomial_is_zero" (recurse polynomial)))
  | Call ("polynomial_formula", [ polynomial ]) ->
      Formula (Ag_polynomial.to_formula (as_polynomial "polynomial_formula" (recurse polynomial)))
  | Call ("polynomial_latex", [ polynomial ]) ->
      Text (Ag_polynomial.to_latex (as_polynomial "polynomial_latex" (recurse polynomial)))
  | Call ("equation", [ left; right ]) ->
      Equation
        (Ag_equation.make (as_formula "equation" (recurse left))
           (as_formula "equation" (recurse right)))
  | Call ("polynomial_equation", [ left; right ]) ->
      (try
         Equation
           (Ag_equation.of_polynomials
              (as_polynomial "polynomial_equation" (recurse left))
              (as_polynomial "polynomial_equation" (recurse right)))
       with Invalid_argument message -> error message)
  | Call ("equation_normal_form", [ equation ]) ->
      Formula (Ag_equation.normal_form (as_equation "equation_normal_form" (recurse equation)))
  | Call ("equation_latex", [ equation ]) ->
      Text (Ag_equation.to_latex (as_equation "equation_latex" (recurse equation)))
  | Call ("equation_is_satisfied", [ equation; variable; value ]) ->
      (try
         Truth
           (Ag_equation.satisfies
              ~variable:(as_text "equation_is_satisfied" (recurse variable))
              ~value:(as_number "equation_is_satisfied" (recurse value))
              (as_equation "equation_is_satisfied" (recurse equation)))
       with Invalid_argument message -> error message)
  | Call ("equation_has_exact_solutions", [ equation; variable ]) ->
      let equation = as_equation "equation_has_exact_solutions" (recurse equation)
      and variable = as_text "equation_has_exact_solutions" (recurse variable) in
      Truth
        (match Ag_equation.solve ~variable equation with
        | Ag_equation.Finite (_ :: _) -> true
        | Ag_equation.No_solution | Ag_equation.All_values | Ag_equation.Finite []
        | Ag_equation.Unsupported ->
            false)
  | Call ("equation_solution_count", [ equation; variable ]) ->
      let equation = as_equation "equation_solution_count" (recurse equation)
      and variable = as_text "equation_solution_count" (recurse variable) in
      (match Ag_equation.exact_solutions ~variable equation with
      | Some roots -> Num (Ag_number.of_int (List.length roots))
      | None -> error "equation_solution_count requires a finite exact solution set")
  | Call ("equation_solution_set", [ equation; variable ]) ->
      let equation = as_equation "equation_solution_set" (recurse equation)
      and variable = as_text "equation_solution_set" (recurse variable) in
      (match Ag_equation.exact_solutions ~variable equation with
      | Some roots -> Set (List.fold_left Ag_set.insert Ag_set.empty roots)
      | None -> error "equation_solution_set requires a finite exact solution set")
  | Call ("equation_unique_solution", [ equation; variable ]) ->
      let equation = as_equation "equation_unique_solution" (recurse equation)
      and variable = as_text "equation_unique_solution" (recurse variable) in
      (match Ag_equation.exact_solutions ~variable equation with
      | Some [ root ] -> Num root
      | Some _ -> error "equation_unique_solution requires exactly one solution"
      | None -> error "equation_unique_solution requires an exact supported equation")
  | Call ("bool_var", [ name ]) ->
      let name = as_text "bool_var" (recurse name) in
      (try Boolean (Ag_boolean.variable name) with Invalid_argument message -> error message)
  | Call ("bool_true", []) -> Boolean (Ag_boolean.constant true)
  | Call ("bool_false", []) -> Boolean (Ag_boolean.constant false)
  | Call ("bool_not", [ body ]) -> Boolean (Ag_boolean.negate (as_boolean "bool_not" (recurse body)))
  | Call ("bool_and", [ left; right ]) ->
      Boolean
        (Ag_boolean.conjunction (as_boolean "bool_and" (recurse left))
           (as_boolean "bool_and" (recurse right)))
  | Call ("bool_or", [ left; right ]) ->
      Boolean
        (Ag_boolean.disjunction (as_boolean "bool_or" (recurse left))
           (as_boolean "bool_or" (recurse right)))
  | Call ("bool_xor", [ left; right ]) ->
      Boolean
        (Ag_boolean.exclusive (as_boolean "bool_xor" (recurse left))
           (as_boolean "bool_xor" (recurse right)))
  | Call ("bool_imp", [ left; right ]) ->
      Boolean
        (Ag_boolean.implication (as_boolean "bool_imp" (recurse left))
           (as_boolean "bool_imp" (recurse right)))
  | Call ("bool_iff", [ left; right ]) ->
      Boolean
        (Ag_boolean.biconditional (as_boolean "bool_iff" (recurse left))
           (as_boolean "bool_iff" (recurse right)))
  | Call ("bool_latex", [ body ]) -> Text (Ag_boolean.to_latex (as_boolean "bool_latex" (recurse body)))
  | Call ("bool_equivalent", [ left; right ]) ->
      Truth
        (Ag_boolean.equivalent
           (as_boolean "bool_equivalent" (recurse left))
           (as_boolean "bool_equivalent" (recurse right)))
  | Call ("bool_evaluate", [ body; names; mask ]) ->
      let body = as_boolean "bool_evaluate" (recurse body)
      and names = as_text "bool_evaluate" (recurse names)
      and mask =
        Ag_number.require_integer "bool_evaluate" (as_number "bool_evaluate" (recurse mask))
      in
      (try Truth (Ag_boolean.evaluate_mask body names mask)
       with Invalid_argument message -> error ("bool_evaluate: " ^ message))
  | Call ("bool_sensitivity", [ body; names; mask ]) ->
      let body = as_boolean "bool_sensitivity" (recurse body)
      and names = as_text "bool_sensitivity" (recurse names)
      and mask =
        Ag_number.require_integer "bool_sensitivity"
          (as_number "bool_sensitivity" (recurse mask))
      in
      (try Num (Ag_number.of_int (Ag_boolean.sensitivity body names mask))
       with Invalid_argument message -> error ("bool_sensitivity: " ^ message))
  | Call ("bool_is_tautology", [ body ]) ->
      Truth (Ag_boolean.is_tautology (as_boolean "bool_is_tautology" (recurse body)))
  | Call ("bool_is_contradiction", [ body ]) ->
      Truth (Ag_boolean.is_contradiction (as_boolean "bool_is_contradiction" (recurse body)))
  | Call ("bool_is_tidy", [ body ]) ->
      Truth (Ag_boolean.is_tidy (as_boolean "bool_is_tidy" (recurse body)))
  | Call ("bool_is_atom", [ body ]) ->
      Truth (Ag_boolean.is_atom (as_boolean "bool_is_atom" (recurse body)))
  | Call ("bool_top", [ body ]) -> Text (Ag_boolean.top (as_boolean "bool_top" (recurse body)))
  | Call ("bool_size", [ body ]) ->
      Num (Ag_number.of_int (Ag_boolean.size (as_boolean "bool_size" (recurse body))))
  | Call ("bool_negations", [ body ]) ->
      Num (Ag_number.of_int (Ag_boolean.negations (as_boolean "bool_negations" (recurse body))))
  | Call ("bool_depth", [ body ]) ->
      Num (Ag_number.of_int (Ag_boolean.depth (as_boolean "bool_depth" (recurse body))))
  | Call ("bool_count", [ body; name ]) ->
      Num
        (Ag_number.of_int
           (Ag_boolean.count_top (as_text "bool_count" (recurse name))
              (as_boolean "bool_count" (recurse body))))
  | Call ("bool_variable_count", [ body ]) ->
      Num
        (Ag_number.of_int
           (List.length (Ag_boolean.variable_set (as_boolean "bool_variable_count" (recurse body)))))
  | Call ("matrix2", [ a; b; c; d ]) ->
      let n label e = as_number label (recurse e) in
      Matrix (Ag_matrix.make [ [ n "matrix2" a; n "matrix2" b ]; [ n "matrix2" c; n "matrix2" d ] ])
  | Call ("matrix3", [ a; b; c; d; e; f; g; h; i ]) ->
      let n x = as_number "matrix3" (recurse x) in
      Matrix (Ag_matrix.make [ [ n a; n b; n c ]; [ n d; n e; n f ]; [ n g; n h; n i ] ])
  | Call ("matrix_identity", [ size ]) ->
      Matrix (Ag_matrix.identity (Ag_number.require_integer "matrix_identity" (as_number "matrix_identity" (recurse size))))
  | Call (("matrix_add" | "matrix_subtract" | "matrix_multiply") as name, [ left; right ]) -> (
      let operation =
        match name with
        | "matrix_add" -> Ag_matrix.add
        | "matrix_subtract" -> Ag_matrix.subtract
        | _ -> Ag_matrix.multiply
      in
      try Matrix (operation (as_matrix name (recurse left)) (as_matrix name (recurse right)))
      with Invalid_argument message -> error (name ^ ": " ^ message))
  | Call ("matrix_scale", [ scalar; matrix ]) ->
      Matrix (Ag_matrix.scale (as_number "matrix_scale" (recurse scalar)) (as_matrix "matrix_scale" (recurse matrix)))
  | Call ("matrix_transpose", [ matrix ]) ->
      Matrix (Ag_matrix.transpose (as_matrix "matrix_transpose" (recurse matrix)))
  | Call ("matrix_determinant", [ matrix ]) -> (
      try Num (Ag_matrix.determinant (as_matrix "matrix_determinant" (recurse matrix)))
      with Invalid_argument message -> error ("matrix_determinant: " ^ message))
  | Call ("matrix_inverse", [ matrix ]) -> (
      try Matrix (Ag_matrix.inverse (as_matrix "matrix_inverse" (recurse matrix)))
      with Invalid_argument message -> error ("matrix_inverse: " ^ message))
  | Call ("matrix_is_invertible", [ matrix ]) ->
      Truth (Ag_matrix.is_invertible (as_matrix "matrix_is_invertible" (recurse matrix)))
  | Call ("matrix_entry", [ matrix; row; column ]) -> (
      let index label e = Ag_number.require_integer label (as_number label (recurse e)) in
      try Num (Ag_matrix.entry (as_matrix "matrix_entry" (recurse matrix)) (index "matrix_entry" row) (index "matrix_entry" column))
      with Invalid_argument message -> error ("matrix_entry: " ^ message))
  | Call ("matrix_vector", [ matrix; vector ]) -> (
      try
        Vector
          (Ag_vector.make
             (Ag_matrix.apply (as_matrix "matrix_vector" (recurse matrix))
                (Ag_vector.components (as_vector "matrix_vector" (recurse vector)))))
      with Invalid_argument message -> error ("matrix_vector: " ^ message))
  | Call ("matrix_latex", [ matrix ]) -> Text (Ag_matrix.to_latex (as_matrix "matrix_latex" (recurse matrix)))
  | Call ("matrix_row_latex", [ matrix; row ]) -> (
      try
        Text
          (Ag_matrix.row_latex (as_matrix "matrix_row_latex" (recurse matrix))
             (Ag_number.require_integer "matrix_row_latex" (as_number "matrix_row_latex" (recurse row))))
      with Invalid_argument message -> error ("matrix_row_latex: " ^ message))
  | Call ("vector_entry", [ vector; index ]) ->
      let components = Ag_vector.components (as_vector "vector_entry" (recurse vector)) in
      let i = Ag_number.require_integer "vector_entry" (as_number "vector_entry" (recurse index)) in
      if i < 1 || i > List.length components then
        error (Printf.sprintf "vector_entry: there is no component %d" i);
      Num (List.nth components (i - 1))
  | Call ("bool_without_conditionals", [ body ]) ->
      Boolean (Ag_boolean.without_conditionals (as_boolean "bool_without_conditionals" (recurse body)))
  | Call ("bool_model_count", [ body ]) ->
      Num (Ag_number.of_int (Ag_boolean.model_count (as_boolean "bool_model_count" (recurse body))))
  | Call ("set_empty", []) -> Set Ag_set.empty
  | Call ("set_insert", [ set; element ]) ->
      let set = as_set "set_insert" (recurse set) in
      let element = as_number "set_insert" (recurse element) in
      (try Set (Ag_set.insert set element) with Invalid_argument message -> error message)
  | Call ("set_interval", [ lower; upper; left_closed; right_closed ]) ->
      let lower = as_number "set_interval" (recurse lower) in
      let upper = as_number "set_interval" (recurse upper) in
      let endpoint context value =
        if as_truth context (recurse value) then Ag_set.Closed else Ag_set.Open
      in
      (try
         Set
           (Ag_set.interval lower upper (endpoint "set_interval" left_closed)
              (endpoint "set_interval" right_closed))
       with Invalid_argument message -> error message)
  | Call ("set_union", [ left; right ]) ->
      Set
        (Ag_set.union (as_set "set_union" (recurse left))
           (as_set "set_union" (recurse right)))
  | Call ("set_intersection", [ left; right ]) ->
      Set
        (Ag_set.intersection (as_set "set_intersection" (recurse left))
           (as_set "set_intersection" (recurse right)))
  | Call ("set_difference", [ left; right ]) ->
      Set
        (Ag_set.difference (as_set "set_difference" (recurse left))
           (as_set "set_difference" (recurse right)))
  | Call ("set_latex", [ set ]) ->
      Text (Ag_set.to_latex (as_set "set_latex" (recurse set)))
  | Call ("vector2", [ first; second ]) ->
      Vector
        (Ag_vector.make
           [ as_number "vector2" (recurse first); as_number "vector2" (recurse second) ])
  | Call ("vector3", [ first; second; third ]) ->
      Vector
        (Ag_vector.make
           [ as_number "vector3" (recurse first);
             as_number "vector3" (recurse second);
             as_number "vector3" (recurse third) ])
  | Call ("vector4", [ first; second; third; fourth ]) ->
      Vector
        (Ag_vector.make
           [ as_number "vector4" (recurse first);
             as_number "vector4" (recurse second);
             as_number "vector4" (recurse third);
             as_number "vector4" (recurse fourth) ])
  | Call ("vector_add", [ left; right ]) ->
      (try
         Vector
           (Ag_vector.add (as_vector "vector_add" (recurse left))
              (as_vector "vector_add" (recurse right)))
       with Invalid_argument message -> error message)
  | Call ("vector_subtract", [ left; right ]) ->
      (try
         Vector
           (Ag_vector.subtract (as_vector "vector_subtract" (recurse left))
              (as_vector "vector_subtract" (recurse right)))
       with Invalid_argument message -> error message)
  | Call ("vector_scale", [ scalar; vector ]) ->
      Vector
        (Ag_vector.scale (as_number "vector_scale" (recurse scalar))
           (as_vector "vector_scale" (recurse vector)))
  | Call ("vector_dot", [ left; right ]) ->
      (try
         Num
           (Ag_vector.dot (as_vector "vector_dot" (recurse left))
              (as_vector "vector_dot" (recurse right)))
       with Invalid_argument message -> error message)
  | Call ("vector_cross", [ left; right ]) ->
      (try
         Vector
           (Ag_vector.cross (as_vector "vector_cross" (recurse left))
              (as_vector "vector_cross" (recurse right)))
       with Invalid_argument message -> error message)
  | Call ("vector_latex", [ vector ]) ->
      Text (Ag_vector.to_latex (as_vector "vector_latex" (recurse vector)))
  | Call ("vector_is_zero", [ vector ]) ->
      Truth (Ag_vector.is_zero (as_vector "vector_is_zero" (recurse vector)))
  | Call ("vector_norm_answer", [ vector ]) ->
      VectorNormAnswer (as_vector "vector_norm_answer" (recurse vector))
  | Call ("vector_unit_answer", [ vector ]) ->
      VectorUnitAnswer (as_vector "vector_unit_answer" (recurse vector))
  | Call ("vector_parallel_answer", [ vector ]) ->
      VectorDirectionAnswer (as_vector "vector_parallel_answer" (recurse vector), false)
  | Call ("vector_same_direction_answer", [ vector ]) ->
      VectorDirectionAnswer
        (as_vector "vector_same_direction_answer" (recurse vector), true)
  | Call (("bit_and" | "bit_or" | "bit_xor") as operation, [ left; right ]) ->
      let whole name value =
        Ag_number.require_integer name (as_number name value)
      in
      let left = whole operation (recurse left)
      and right = whole operation (recurse right) in
      Num
        (Ag_number.of_int
           (match operation with
           | "bit_and" -> left land right
           | "bit_or" -> left lor right
           | _ -> left lxor right))
  | Call ("abs", [ body ]) -> Num (Ag_number.absolute (as_number "abs" (recurse body)))
  | Call ("min", [ left; right ]) ->
      let left = as_number "min" (recurse left) and right = as_number "min" (recurse right) in
      Num (if Ag_number.compare left right <= 0 then left else right)
  | Call ("max", [ left; right ]) ->
      let left = as_number "max" (recurse left) and right = as_number "max" (recurse right) in
      Num (if Ag_number.compare left right >= 0 then left else right)
  | Call (name, arguments) ->
      error (Printf.sprintf "cannot apply '%s' to %d argument(s)" name (List.length arguments))

(* ------------------------------------------------------------------ *)
(* Generation                                                          *)
(* ------------------------------------------------------------------ *)

exception Requirement_failed of string

(* A generated prompt is text with answer blanks in it. *)
type piece = Piece_text of string | Piece_blank of value

type question = {
  prompt : string;  (* the text, with each blank shown as [___] *)
  answer : value;  (* the first blank's answer *)
  answer_text : string;  (* every blank's answer, for listings *)
  pieces : piece list;
  answers : value list;
  context : string;  (* the WeBWorK context this question needs *)
  width : int option;  (* its answer width, when the grammar sets one *)
  globals : (string * value) list;
  tree : node;
}

let retries_per_node = 40
let retries_per_question = 200

(* The values of every module's randoms and lets for the current question,
   by the module's file. A module imported twice is drawn once. *)
type module_globals = (string * (string * value) list) list

let rec tree_builder (spec : Ag_check.spec) ~globals ~(module_globals : module_globals) =
  let open Ag_check in
  let nonterminals =
    spec.rules |> List.map (fun rule -> rule.lhs) |> List.sort_uniq String.compare
  in
  let is_nonterminal name = List.mem name nonterminals in
  let inherited_names = List.map (fun a -> a.attribute_name) spec.inherited in
  let is_inherited name = List.mem name inherited_names in
  let rule_precedence rule =
    List.fold_left
      (fun found symbol ->
        match found with
        | Some _ -> found
        | None ->
            List.find_opt
              (fun (name, _, _) -> name = symbol_name symbol)
              spec.precedences)
      None rule.rhs
  in
  let evaluate_in ?(self = []) ~environment ~children ~rule ~target expression =
    evaluate ~self ~globals ~is_inherited ~rule_precedence ~environment ~children ~rule
      ~target expression
  in
  (* Budget updates are applied before any child exists, so they may only read
     inherited attributes. The checker has already guaranteed that. *)
  let apply_updates environment rule =
    List.fold_left
      (fun current equation ->
        match equation with
        | Assign (name, body, _) when is_inherited name ->
            let delta =
              match
                evaluate_in ~environment:current ~children:[] ~rule:None ~target:name body
              with
              | Num number when Ag_number.is_integer number ->
                  Ag_number.require_integer name number
              | other ->
                  error
                    (Printf.sprintf "budget '%s' must change by a whole number, not \"%s\""
                       name (describe_value other))
            in
            let next = lookup current name + delta in
            if next < 0 then
              error (Printf.sprintf "budget '%s' would go negative" name);
            bind current name next
        | _ -> current)
      environment rule.equations
  in
  let guard_holds environment rule =
    match rule.guard with
    | None -> true
    | Some condition -> (
        match
          evaluate_in ~environment ~children:[] ~rule:None ~target:"" condition
        with
        | Truth truth -> truth
        | other ->
            error
              (Printf.sprintf "a 'when' condition must be true or false, but gave \"%s\""
                 (describe_value other)))
  in
  let fuel = ref 200_000 in
  let spend () =
    decr fuel;
    if !fuel <= 0 then error "generation exceeded its safety limit"
  in

  let rec expand_symbol symbol environment =
    spend ();
    match symbol with
    | Generator (name, arguments) ->
        let argument index =
          match List.nth_opt arguments index with
          | Some expression -> (
              match
                evaluate_in ~environment ~children:[] ~rule:None ~target:"" expression
              with
              | Num number -> Ag_number.require_integer name number
              | other ->
                  error
                    (Printf.sprintf "%s expects a whole number, but received \"%s\"" name
                       (describe_value other)))
          | None -> error (Printf.sprintf "%s is missing an argument" name)
        in
        let drawn =
          arguments |> List.mapi (fun index _ -> argument index) |> draw_generator name
        in
        {
          symbol = name;
          applied_rule = None;
          children = [];
          inherited_attributes = [];
          attributes = [ ("value", Num (Ag_number.of_int drawn)) ];
          level = atom_level;
        }
    | Literal text ->
        {
          symbol = text;
          applied_rule = None;
          children = [];
          inherited_attributes = [];
          attributes = [ ("value", Text text) ];
          level = atom_level;
        }
    | Symbol name when not (is_nonterminal name) ->
        {
          symbol = name;
          applied_rule = None;
          children = [];
          inherited_attributes = [];
          attributes = [ ("value", Text name) ];
          level = atom_level;
        }
    | Symbol name -> expand_nonterminal name environment
    | Module_symbol (alias, nonterminal, arguments) ->
        (* The arguments are read in this node's scope -- the environment is
           already this child's share of any split budget -- and become the
           module's inherited attributes at the root of the subtree. The
           module then expands with its own rules, precedences and values. *)
        let module_spec =
          match List.assoc_opt alias spec.imports with
          | Some module_spec -> module_spec
          | None -> error (Printf.sprintf "'%s' is not an imported module" alias)
        in
        let qualified = alias ^ "." ^ nonterminal in
        let defaults =
          List.map
            (fun (declaration : Ag_check.inherited_attribute) ->
              (declaration.attribute_name, declaration.initial))
            module_spec.inherited
        in
        let initial =
          List.fold_left
            (fun current (name, body) ->
              let value =
                match
                  evaluate_in ~environment ~children:[] ~rule:None ~target:name body
                with
                | Num number when Ag_number.is_integer number ->
                    Ag_number.require_integer name number
                | other ->
                    error
                      (Printf.sprintf
                         "%s: '%s' must start at a whole number, not \"%s\"" qualified
                         name (describe_value other))
              in
              if value < 0 then
                error
                  (Printf.sprintf "%s: '%s' cannot start negative (%d was computed)"
                     qualified name value);
              bind current name value)
            defaults arguments
        in
        let module_values =
          match List.assoc_opt module_spec.source module_globals with
          | Some values -> values
          | None ->
              error (Printf.sprintf "the values of module %s were not drawn" alias)
        in
        let node =
          expand_module module_spec ~globals:module_values ~module_globals nonterminal
            initial
        in
        (* The importer's precedence table says nothing about the module's
           operators, so the subtree is an atom to the importer: infix() adds
           no brackets around it. A rule that needs them writes them. *)
        { node with level = atom_level }

  and expand_nonterminal name environment =
    let candidates =
      spec.rules
      |> List.filter (fun rule ->
             rule.lhs = name
             && guard_holds environment rule
             &&
             try
               ignore (apply_updates environment rule);
               true
             with Generation_error _ -> false)
    in
    if candidates = [] then
      error
        (Printf.sprintf "no rule for '%s' fits {%s}" name
           (environment
           |> List.map (fun (attribute, value) -> attribute ^ "=" ^ string_of_int value)
           |> String.concat ", "));
    let rec attempt remaining last_failure =
      if remaining <= 0 then
        raise
          (Requirement_failed
             (Printf.sprintf "'%s' still failed after %d attempts; last failure: %s"
                name retries_per_node
                (match last_failure with
                | Some message -> message
                | None -> "no requirement could be satisfied")))
      else
        let before = !choice_points in
        match build_once name environment candidates with
        | node -> node
        | exception Requirement_failed message ->
            if !choice_points = before then
              (* Nothing random happened on the way to this failure, so every
                 retry would fail identically. Stop now instead of burning the
                 remaining attempts on a foregone conclusion. *)
              raise (Requirement_failed (mark_deterministic message))
            else attempt (remaining - 1) (Some message)
    in
    attempt retries_per_node None

  and build_once name environment candidates =
    let rule = weighted_pick candidates in
    let updated = apply_updates environment rule in
    (* Only nonterminal positions receive a share of a split budget; a
       module's nonterminal counts as one, so `calc.F(cost = cost)` hands
       over exactly what a local F would have received. *)
    let expandable =
      rule.rhs
      |> List.mapi (fun index symbol -> (index, symbol))
      |> List.filter (fun (_, symbol) ->
             match symbol with
             | Symbol name -> is_nonterminal name
             | Module_symbol _ -> true
             | _ -> false)
    in
    let child_environments = Array.make (max 1 (List.length expandable)) updated in
    List.iteri (fun index _ -> child_environments.(index) <- updated) expandable;
    List.iter
      (fun (declaration : Ag_check.inherited_attribute) ->
        match declaration.distribution with
        | Copy -> ()
        | Split ->
            let total = lookup updated declaration.attribute_name in
            let shares = random_partition total (List.length expandable) in
            List.iteri
              (fun index share ->
                child_environments.(index) <-
                  bind child_environments.(index) declaration.attribute_name share)
              shares)
      spec.inherited;
    let environment_for position =
      let rec find slot = function
        | [] -> updated
        | (index, _) :: rest ->
            if index = position then child_environments.(slot) else find (slot + 1) rest
      in
      find 0 expandable
    in
    let children =
      List.mapi
        (fun position symbol -> expand_symbol symbol (environment_for position))
        rule.rhs
    in
    (* Synthesized equations and requirements, in the order they were written. *)
    let attributes =
      List.fold_left
        (fun collected equation ->
          match equation with
          | Assign (attribute_name, _, _) when is_inherited attribute_name -> collected
          | Assign (attribute_name, body, _) ->
              let value =
                evaluate_in ~self:collected ~environment:updated ~children
                  ~rule:(Some rule) ~target:attribute_name body
              in
              collected @ [ (attribute_name, value) ]
          | Require (condition, position) -> (
              match
                evaluate_in ~self:collected ~environment:updated ~children
                  ~rule:(Some rule) ~target:"" condition
              with
              | Truth true -> collected
              | Truth false ->
                  raise
                    (Requirement_failed
                       (Printf.sprintf "a 'require' on line %d was not satisfied"
                          position.line))
              | other ->
                  error
                    (Printf.sprintf
                       "a 'require' must be true or false, but gave \"%s\""
                       (describe_value other))))
        [] rule.equations
    in
    {
      symbol = name;
      applied_rule = Some rule;
      children;
      inherited_attributes = environment;
      attributes;
      level =
        (match rule_precedence rule with Some (_, level, _) -> level | None -> atom_level);
    }
  in
  (expand_nonterminal, is_inherited, rule_precedence)

(* A subtree of an imported module, from one of its nonterminals and the
   starting values an importer gave its inherited attributes. *)
and expand_module (module_spec : Ag_check.spec) ~globals ~module_globals nonterminal initial =
  let expand, _, _ = tree_builder module_spec ~globals ~module_globals in
  expand nonterminal initial

let generate_tree (spec : Ag_check.spec) ~globals ~module_globals =
  let expand, is_inherited, rule_precedence = tree_builder spec ~globals ~module_globals in
  let initial =
    List.map
      (fun (declaration : Ag_check.inherited_attribute) ->
        (declaration.attribute_name, declaration.initial))
      spec.Ag_check.inherited
  in
  (expand spec.Ag_check.start initial, is_inherited, rule_precedence)

(* Rewrite the start symbol's name away so the top-level answer expression can
   be evaluated with the root standing in as child $1. *)
let rec bind_root start expression =
  match expression with
  | Attr_child_named (owner, name) when owner = start -> Attr_child (1, name)
  | Unary (operator, body) -> Unary (operator, bind_root start body)
  | Binary (operator, left, right) ->
      Binary (operator, bind_root start left, bind_root start right)
  | Call (name, arguments) -> Call (name, List.map (bind_root start) arguments)
  | other -> other

(* Question-level values are fixed before any expression is generated: every
   occurrence of the same random has to agree across the whole question, which
   a value drawn at the leaves could not guarantee. *)
let draw_globals (spec : Ag_check.spec) ~(module_globals : module_globals) =
  let open Ag_check in
  let globals =
    List.map
      (fun (name, how) ->
        let value =
          match how with
          | Draw_boolean ->
              chose ();
              Truth (Random.bool ())
          | Draw_generator (generator, arguments) ->
              let constant_integer = function
                | Int value -> value
                | Unary ("-", Int value) -> -value
                | _ ->
                    error
                      (Printf.sprintf "%s needs constant integer arguments" generator)
              in
              let arguments = List.map constant_integer arguments in
              Num (Ag_number.of_int (draw_generator generator arguments))
        in
        (name, value))
      spec.randoms
  in
  (* The randoms and lets of each imported module, under their qualified
     names, so a let or a prompt here may read calc.given. *)
  let globals =
    List.fold_left
      (fun known (alias, (module_spec : Ag_check.spec)) ->
        match List.assoc_opt module_spec.source module_globals with
        | None -> known
        | Some values ->
            known
            @ List.filter_map
                (fun (name, value) ->
                  if String.contains name '.' then None
                  else Some (alias ^ "." ^ name, value))
                values)
      globals spec.imports
  in
  (* Lets are evaluated in order, so a later one may use an earlier one. *)
  List.fold_left
    (fun known (name, body) ->
      let value =
        evaluate ~globals:known
          ~is_inherited:(fun _ -> false)
          ~rule_precedence:(fun _ -> None)
          ~environment:[] ~children:[] ~rule:None ~target:"" body
      in
      known @ [ (name, value) ])
    globals spec.lets

(* Draw the values of every module a specification imports, directly or
   through other modules, each once, a module's own imports before it. *)
let rec draw_module_globals table (spec : Ag_check.spec) : module_globals =
  List.fold_left
    (fun table (_, (module_spec : Ag_check.spec)) ->
      if List.mem_assoc module_spec.Ag_check.source table then table
      else
        let table = draw_module_globals table module_spec in
        (module_spec.Ag_check.source, draw_globals module_spec ~module_globals:table) :: table)
    table spec.Ag_check.imports

let generate_once (spec : Ag_check.spec) =
  let open Ag_check in
  if spec.library then
    error "this file has no start symbol: it is a library, to be included by a grammar";
  let module_globals = draw_module_globals [] spec in
  let globals = draw_globals spec ~module_globals in
  let tree, is_inherited, rule_precedence = generate_tree spec ~globals ~module_globals in
  let global_value name =
    match List.assoc_opt name globals with
    | Some value -> value
    | None -> error (Printf.sprintf "'%s' has no value" name)
  in
  let pieces =
    spec.prompt
    |> List.map (function
         | Ag_check.Text text -> Piece_text text
         | Ag_check.Value_hole name -> Piece_text (as_text "prompt" (global_value name))
         | Ag_check.Hole (_, attribute_name) ->
             Piece_text (as_text "prompt" (attribute tree attribute_name))
         | Ag_check.Answer_hole (_, attribute_name) -> Piece_blank (attribute tree attribute_name)
         | Ag_check.Answer_value_hole name -> Piece_blank (global_value name))
  in
  (* A trailing `answer` is one more blank after the text. *)
  let pieces =
    match spec.answer with
    | Some expression ->
        let text =
          pieces
          |> List.map (function Piece_text text -> text | Piece_blank _ -> "")
          |> String.concat ""
        in
        [
          Piece_text text;
          Piece_blank
            (evaluate ~globals ~is_inherited ~rule_precedence ~environment:[]
               ~children:[ tree ] ~rule:None ~target:"value"
               (bind_root spec.start expression));
        ]
    | None -> pieces
  in
  let answers =
    List.filter_map (function Piece_blank value -> Some value | Piece_text _ -> None) pieces
  in
  let answer =
    match answers with
    | first :: _ -> first
    | [] -> error "the question has no answer blank"
  in
  (* The readable prompt shows an inline blank as [___]; a trailing blank is
     left unwritten, as it always was. *)
  let prompt =
    match spec.answer with
    | Some _ -> (
        match pieces with Piece_text text :: _ -> text | _ -> "")
    | None ->
        pieces
        |> List.map (function Piece_text text -> text | Piece_blank _ -> "[___]")
        |> String.concat ""
        |> String.trim
  in
  let context =
    if spec.per_question_context then
      let name = as_text "pg_context" (attribute tree "pg_context") in
      if not (Ag_check.valid_context_name name) then
        error (Printf.sprintf "'%s' is not a WeBWorK context name" name);
      name
    else spec.context
  in
  let width =
    if spec.per_question_width then
      Some
        (Ag_number.require_integer "pg_width" (as_number "pg_width" (attribute tree "pg_width")))
    else None
  in
  {
    prompt;
    answer;
    answer_text = String.concat "; " (List.map describe_value answers);
    pieces;
    answers;
    context;
    width;
    globals;
    tree;
  }

let generate spec =
  (* Which failure happened how often, so the final error tells the grammar
     author what to fix instead of just that generation gave up. *)
  let failure_counts : (string, int) Hashtbl.t = Hashtbl.create 8 in
  let record message =
    let seen = try Hashtbl.find failure_counts message with Not_found -> 0 in
    Hashtbl.replace failure_counts message (seen + 1)
  in
  let most_frequent_failure () =
    Hashtbl.fold
      (fun message count best ->
        match best with
        | Some (_, best_count) when best_count >= count -> best
        | _ -> Some (message, count))
      failure_counts None
  in
  let rec attempt remaining =
    if remaining <= 0 then
      error
        (match most_frequent_failure () with
        | Some (message, count) ->
            Printf.sprintf
              "could not generate a question after %d attempts; the most \
               frequent failure (%d of %d) was: %s"
              retries_per_question count retries_per_question message
        | None -> "could not generate a question")
    else
      let before = !choice_points in
      match generate_once spec with
      | question -> question
      | exception Requirement_failed message ->
          record message;
          if !choice_points = before then
            (* The whole question was built without a single random draw, so
               this grammar fails the same way every time. *)
            error ("this grammar can never satisfy its own constraints: " ^ message)
          else attempt (remaining - 1)
      | exception Ag_number.Arithmetic_error message ->
          record message;
          if !choice_points = before then
            error ("this grammar always fails the same way: " ^ message)
          else attempt (remaining - 1)
  in
  attempt retries_per_question
