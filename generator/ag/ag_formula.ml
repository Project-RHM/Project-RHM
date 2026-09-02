(* Typed symbolic expressions shared by derivative and integral questions. *)

type t =
  | Constant of Ag_number.t
  | Variable of string
  | Add of t * t
  | Subtract of t * t
  | Multiply of t * t
  | Power of t * int
  | Negate of t
  | Sin of t
  | Cos of t
  | Exp of t

let zero = Constant Ag_number.zero
let one = Constant (Ag_number.of_int 1)
let minus_one = Constant (Ag_number.of_int (-1))

let equal = ( = )

let is_constant expected = function
  | Constant value -> Ag_number.equal value expected
  | _ -> false

let is_zero = is_constant Ag_number.zero
let is_one = is_constant (Ag_number.of_int 1)
let is_minus_one = is_constant (Ag_number.of_int (-1))

let constant value = Constant value

let variable name =
  let valid_start = function
    | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
    | _ -> false
  in
  let valid_character = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
    | _ -> false
  in
  if name = "" || not (valid_start name.[0]) || not (String.for_all valid_character name)
  then invalid_arg (Printf.sprintf "%S is not a valid formula variable" name);
  Variable name

let negate = function
  | Constant value -> Constant (Ag_number.negate value)
  | Negate body -> body
  | body -> Negate body

let rec add left right =
  match (left, right) with
  | Constant left, Constant right -> Constant (Ag_number.add left right)
  | left, right when is_zero left -> right
  | left, right when is_zero right -> left
  | left, Negate right -> subtract left right
  | Negate left, right -> subtract right left
  | left, Constant right when Ag_number.compare right Ag_number.zero < 0 ->
      subtract left (Constant (Ag_number.absolute right))
  | Constant left, right when Ag_number.compare left Ag_number.zero < 0 ->
      subtract right (Constant (Ag_number.absolute left))
  | left, right -> Add (left, right)

and subtract left right =
  match (left, right) with
  | Constant left, Constant right -> Constant (Ag_number.subtract left right)
  | left, right when is_zero right -> left
  | left, right when is_zero left -> negate right
  | left, right when equal left right -> zero
  | left, Negate right -> add left right
  | Negate left, right -> negate (add left right)
  | left, Constant right when Ag_number.compare right Ag_number.zero < 0 ->
      add left (Constant (Ag_number.absolute right))
  | Constant left, right when Ag_number.compare left Ag_number.zero < 0 ->
      negate (add (Constant (Ag_number.absolute left)) right)
  | left, right -> Subtract (left, right)

let rec multiply left right =
  match (left, right) with
  | Constant left, Constant right -> Constant (Ag_number.multiply left right)
  | left, right when is_zero left || is_zero right -> zero
  | left, right when is_one left -> right
  | left, right when is_one right -> left
  | left, right when is_minus_one left -> negate right
  | left, right when is_minus_one right -> negate left
  | Constant left, right when Ag_number.compare left Ag_number.zero < 0 ->
      negate (multiply (Constant (Ag_number.absolute left)) right)
  | left, Constant right when Ag_number.compare right Ag_number.zero < 0 ->
      negate (multiply left (Constant (Ag_number.absolute right)))
  | Negate left, Negate right -> multiply left right
  | Negate left, right | left, Negate right -> negate (multiply left right)
  | left, right -> Multiply (left, right)

let power base exponent =
  if exponent = 0 then one
  else if exponent = 1 then base
  else Power (base, exponent)

let sin body = Sin body
let cos body = Cos body
let exp body = Exp body

let rec differentiate ~variable:name = function
  | Constant _ -> zero
  | Variable variable_name -> if variable_name = name then one else zero
  | Add (left, right) ->
      add (differentiate ~variable:name left) (differentiate ~variable:name right)
  | Subtract (left, right) ->
      subtract (differentiate ~variable:name left) (differentiate ~variable:name right)
  | Multiply (left, right) ->
      add
        (multiply (differentiate ~variable:name left) right)
        (multiply left (differentiate ~variable:name right))
  | Power (base, exponent) ->
      multiply
        (multiply
           (constant (Ag_number.of_int exponent))
           (power base (exponent - 1)))
        (differentiate ~variable:name base)
  | Negate body -> negate (differentiate ~variable:name body)
  | Sin body ->
      multiply (cos body) (differentiate ~variable:name body)
  | Cos body ->
      negate (multiply (sin body) (differentiate ~variable:name body))
  | Exp body ->
      multiply (exp body) (differentiate ~variable:name body)

let rec evaluate ~variable:name ~at = function
  | Constant value -> Ag_number.to_float value
  | Variable variable_name ->
      if variable_name = name then at
      else invalid_arg (Printf.sprintf "no value was provided for variable %s" variable_name)
  | Add (left, right) ->
      evaluate ~variable:name ~at left +. evaluate ~variable:name ~at right
  | Subtract (left, right) ->
      evaluate ~variable:name ~at left -. evaluate ~variable:name ~at right
  | Multiply (left, right) ->
      evaluate ~variable:name ~at left *. evaluate ~variable:name ~at right
  | Power (base, exponent) ->
      evaluate ~variable:name ~at base ** float_of_int exponent
  | Negate body -> -.evaluate ~variable:name ~at body
  | Sin body -> Stdlib.sin (evaluate ~variable:name ~at body)
  | Cos body -> Stdlib.cos (evaluate ~variable:name ~at body)
  | Exp body -> Stdlib.exp (evaluate ~variable:name ~at body)

let precedence = function
  | Add _ | Subtract _ -> 10
  | Multiply _ -> 20
  | Negate _ -> 30
  | Constant value when Ag_number.compare value Ag_number.zero < 0 -> 30
  | Power _ -> 40
  | Constant _ | Variable _ | Sin _ | Cos _ | Exp _ -> 50

let parenthesize needed text = if needed then "(" ^ text ^ ")" else text

let rec to_pg_with_context context expression =
  let level = precedence expression in
  let text =
    match expression with
    | Constant value -> Ag_number.to_string value
    | Variable name -> name
    | Add (left, right) ->
        to_pg_with_context level left ^ "+" ^ to_pg_with_context level right
    | Subtract (left, right) ->
        to_pg_with_context level left ^ "-" ^ to_pg_with_context (level + 1) right
    | Multiply (left, right) ->
        to_pg_with_context level left ^ "*" ^ to_pg_with_context level right
    | Power (base, exponent) ->
        to_pg_with_context (level + 1) base ^ "^" ^ string_of_int exponent
    | Negate body -> "-" ^ to_pg_with_context level body
    | Sin body -> "sin(" ^ to_pg_with_context 0 body ^ ")"
    | Cos body -> "cos(" ^ to_pg_with_context 0 body ^ ")"
    | Exp body -> "exp(" ^ to_pg_with_context 0 body ^ ")"
  in
  parenthesize (level < context) text

let to_pg expression = to_pg_with_context 0 expression

let rec to_latex_with_context context expression =
  let level = precedence expression in
  let text =
    match expression with
    | Constant value -> Ag_number.to_string value
    | Variable name -> name
    | Add (left, right) ->
        to_latex_with_context level left ^ " + " ^ to_latex_with_context level right
    | Subtract (left, right) ->
        to_latex_with_context level left ^ " - "
        ^ to_latex_with_context (level + 1) right
    | Multiply (left, right) ->
        to_latex_with_context level left ^ " \\cdot "
        ^ to_latex_with_context level right
    | Power (base, exponent) ->
        to_latex_with_context (level + 1) base ^ "^{" ^ string_of_int exponent ^ "}"
    | Negate body -> "-" ^ to_latex_with_context level body
    | Sin body -> "\\sin\\left(" ^ to_latex_with_context 0 body ^ "\\right)"
    | Cos body -> "\\cos\\left(" ^ to_latex_with_context 0 body ^ "\\right)"
    | Exp body -> "e^{" ^ to_latex_with_context 0 body ^ "}"
  in
  parenthesize (level < context) text

let to_latex expression = to_latex_with_context 0 expression
