(* Typed symbolic expressions shared by derivative and integral questions. *)

type t =
  | Constant of Rhema_number.t
  | Pi
      (* the constant pi: kept as a symbol, so that 5 pi / 6 is an exact answer *)
  | Variable of string
  | Add of t * t
  | Subtract of t * t
  | Multiply of t * t
  | Divide of t * t
  | Power of t * int
  | Negate of t
  | Sin of t
  | Cos of t
  | Tan of t
  | Exp of t
  | Ln of t
  | Sqrt of t

let zero = Constant Rhema_number.zero
let one = Constant (Rhema_number.of_int 1)
let minus_one = Constant (Rhema_number.of_int (-1))

let equal = ( = )

let is_constant expected = function
  | Constant value -> Rhema_number.equal value expected
  | _ -> false

let is_zero = is_constant Rhema_number.zero
let is_one = is_constant (Rhema_number.of_int 1)
let is_minus_one = is_constant (Rhema_number.of_int (-1))

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
  | Constant value -> Constant (Rhema_number.negate value)
  | Negate body -> body
  | body -> Negate body

let rec add left right =
  match (left, right) with
  | Constant left, Constant right -> Constant (Rhema_number.add left right)
  | left, right when is_zero left -> right
  | left, right when is_zero right -> left
  | left, Negate right -> subtract left right
  | Negate left, right -> subtract right left
  | left, Constant right when Rhema_number.compare right Rhema_number.zero < 0 ->
      subtract left (Constant (Rhema_number.absolute right))
  | Constant left, right when Rhema_number.compare left Rhema_number.zero < 0 ->
      subtract right (Constant (Rhema_number.absolute left))
  | left, right -> Add (left, right)

and subtract left right =
  match (left, right) with
  | Constant left, Constant right -> Constant (Rhema_number.subtract left right)
  | left, right when is_zero right -> left
  | left, right when is_zero left -> negate right
  | left, right when equal left right -> zero
  | left, Negate right -> add left right
  | Negate left, right -> negate (add left right)
  | left, Constant right when Rhema_number.compare right Rhema_number.zero < 0 ->
      add left (Constant (Rhema_number.absolute right))
  | Constant left, right when Rhema_number.compare left Rhema_number.zero < 0 ->
      negate (add (Constant (Rhema_number.absolute left)) right)
  | left, right -> Subtract (left, right)

let rec multiply left right =
  match (left, right) with
  | Constant left, Constant right -> Constant (Rhema_number.multiply left right)
  | left, right when is_zero left || is_zero right -> zero
  | left, right when is_one left -> right
  | left, right when is_one right -> left
  | left, right when is_minus_one left -> negate right
  | left, right when is_minus_one right -> negate left
  | Constant left, right when Rhema_number.compare left Rhema_number.zero < 0 ->
      negate (multiply (Constant (Rhema_number.absolute left)) right)
  | left, Constant right when Rhema_number.compare right Rhema_number.zero < 0 ->
      negate (multiply left (Constant (Rhema_number.absolute right)))
  | Negate left, Negate right -> multiply left right
  | Negate left, right | left, Negate right -> negate (multiply left right)
  | left, right -> Multiply (left, right)

let rec divide numerator denominator =
  match (numerator, denominator) with
  | _, denominator when is_zero denominator -> invalid_arg "formula division by zero"
  | Constant numerator, Constant denominator ->
      Constant (Rhema_number.divide numerator denominator)
  | numerator, denominator when is_one denominator -> numerator
  | numerator, denominator when is_minus_one denominator -> negate numerator
  | Negate numerator, Negate denominator -> divide numerator denominator
  | Negate numerator, denominator | numerator, Negate denominator ->
      negate (divide numerator denominator)
  | numerator, denominator -> Divide (numerator, denominator)

let power base exponent =
  if exponent = 0 then one
  else if exponent = 1 then base
  else Power (base, exponent)

let sin body = Sin body
let cos body = Cos body
let tan body = Tan body
let exp body = Exp body
let ln = function body when is_one body -> zero | body -> Ln body

let sqrt = function
  | Constant value -> (
      match Rhema_number.square_root_exact value with
      | Some root -> Constant root
      | None -> Sqrt (Constant value))
  | body -> Sqrt body

let rec differentiate ~variable:name = function
  | Constant _ | Pi -> zero
  | Variable variable_name -> if variable_name = name then one else zero
  | Add (left, right) ->
      add (differentiate ~variable:name left) (differentiate ~variable:name right)
  | Subtract (left, right) ->
      subtract (differentiate ~variable:name left) (differentiate ~variable:name right)
  | Multiply (left, right) ->
      add
        (multiply (differentiate ~variable:name left) right)
        (multiply left (differentiate ~variable:name right))
  | Divide (numerator, denominator) ->
      divide
        (subtract
           (multiply (differentiate ~variable:name numerator) denominator)
           (multiply numerator (differentiate ~variable:name denominator)))
        (power denominator 2)
  | Power (base, exponent) ->
      multiply
        (multiply
           (constant (Rhema_number.of_int exponent))
           (power base (exponent - 1)))
        (differentiate ~variable:name base)
  | Negate body -> negate (differentiate ~variable:name body)
  | Sin body ->
      multiply (cos body) (differentiate ~variable:name body)
  | Cos body ->
      negate (multiply (sin body) (differentiate ~variable:name body))
  | Tan body ->
      divide (differentiate ~variable:name body) (power (cos body) 2)
  | Exp body ->
      multiply (exp body) (differentiate ~variable:name body)
  | Ln body -> divide (differentiate ~variable:name body) body
  | Sqrt body ->
      divide (differentiate ~variable:name body)
        (multiply (constant (Rhema_number.of_int 2)) (sqrt body))

let rec variables = function
  | Constant _ | Pi -> []
  | Variable name -> [ name ]
  | Add (left, right) | Subtract (left, right) | Multiply (left, right)
  | Divide (left, right) ->
      List.sort_uniq String.compare (variables left @ variables right)
  | Power (body, _) | Negate body | Sin body | Cos body | Tan body | Exp body
  | Ln body | Sqrt body ->
      variables body

let rec substitute ~variable:name ~replacement = function
  | (Constant _ | Pi) as expression -> expression
  | Variable variable_name as expression ->
      if variable_name = name then replacement else expression
  | Add (left, right) ->
      add (substitute ~variable:name ~replacement left)
        (substitute ~variable:name ~replacement right)
  | Subtract (left, right) ->
      subtract (substitute ~variable:name ~replacement left)
        (substitute ~variable:name ~replacement right)
  | Multiply (left, right) ->
      multiply (substitute ~variable:name ~replacement left)
        (substitute ~variable:name ~replacement right)
  | Divide (left, right) ->
      divide (substitute ~variable:name ~replacement left)
        (substitute ~variable:name ~replacement right)
  | Power (body, exponent) -> power (substitute ~variable:name ~replacement body) exponent
  | Negate body -> negate (substitute ~variable:name ~replacement body)
  | Sin body -> sin (substitute ~variable:name ~replacement body)
  | Cos body -> cos (substitute ~variable:name ~replacement body)
  | Tan body -> tan (substitute ~variable:name ~replacement body)
  | Exp body -> exp (substitute ~variable:name ~replacement body)
  | Ln body -> ln (substitute ~variable:name ~replacement body)
  | Sqrt body -> sqrt (substitute ~variable:name ~replacement body)

let rec evaluate_with lookup = function
  | Constant value -> Rhema_number.to_float value
  | Pi -> Float.pi
  | Variable name -> (
      match lookup name with
      | Some value -> value
      | None -> invalid_arg (Printf.sprintf "no value was provided for variable %s" name))
  | Add (left, right) -> evaluate_with lookup left +. evaluate_with lookup right
  | Subtract (left, right) -> evaluate_with lookup left -. evaluate_with lookup right
  | Multiply (left, right) -> evaluate_with lookup left *. evaluate_with lookup right
  | Divide (left, right) -> evaluate_with lookup left /. evaluate_with lookup right
  | Power (base, exponent) -> evaluate_with lookup base ** float_of_int exponent
  | Negate body -> -.evaluate_with lookup body
  | Sin body -> Stdlib.sin (evaluate_with lookup body)
  | Cos body -> Stdlib.cos (evaluate_with lookup body)
  | Tan body -> Stdlib.tan (evaluate_with lookup body)
  | Exp body -> Stdlib.exp (evaluate_with lookup body)
  | Ln body -> Stdlib.log (evaluate_with lookup body)
  | Sqrt body -> Stdlib.sqrt (evaluate_with lookup body)

let evaluate ~variable:name ~at expression =
  evaluate_with (fun variable_name -> if variable_name = name then Some at else None) expression

let precedence = function
  | Add _ | Subtract _ -> 10
  | Multiply _ | Divide _ -> 20
  (* A fraction is written 5/6, a quotient: as a divisor or under a power it
     needs brackets, x/(5/6) and (2/3)^2, like any other quotient. *)
  | Constant value when not (Rhema_number.is_integer value) -> 20
  | Negate _ -> 30
  | Constant value when Rhema_number.compare value Rhema_number.zero < 0 -> 30
  | Power _ -> 40
  | Constant _ | Pi | Variable _ | Sin _ | Cos _ | Tan _ | Exp _ | Ln _ | Sqrt _ -> 50

let parenthesize needed text = if needed then "(" ^ text ^ ")" else text

let rec to_pg_with_context context expression =
  let level = precedence expression in
  let text =
    match expression with
    | Constant value -> Rhema_number.to_string value
    | Pi -> "pi"
    | Variable name -> name
    | Add (left, right) ->
        to_pg_with_context level left ^ "+" ^ to_pg_with_context level right
    | Subtract (left, right) ->
        to_pg_with_context level left ^ "-" ^ to_pg_with_context (level + 1) right
    | Multiply (left, right) ->
        to_pg_with_context level left ^ "*" ^ to_pg_with_context level right
    | Divide (left, right) ->
        to_pg_with_context level left ^ "/" ^ to_pg_with_context (level + 1) right
    | Power (base, exponent) ->
        to_pg_with_context (level + 1) base ^ "^" ^ string_of_int exponent
    | Negate body -> "-" ^ to_pg_with_context level body
    | Sin body -> "sin(" ^ to_pg_with_context 0 body ^ ")"
    | Cos body -> "cos(" ^ to_pg_with_context 0 body ^ ")"
    | Tan body -> "tan(" ^ to_pg_with_context 0 body ^ ")"
    | Exp body -> "exp(" ^ to_pg_with_context 0 body ^ ")"
    | Ln body -> "ln(" ^ to_pg_with_context 0 body ^ ")"
    | Sqrt body -> "sqrt(" ^ to_pg_with_context 0 body ^ ")"
  in
  parenthesize (level < context) text

let to_pg expression = to_pg_with_context 0 expression

let rec to_latex_with_context context expression =
  let level = precedence expression in
  let text =
    match expression with
    | Constant value -> Rhema_number.to_string value
    | Pi -> "\\pi"
    (* A rational multiple of pi is written as it is read: 2\pi, \frac{\pi}{4},
       \frac{5\pi}{6}. A negative multiple is a Negate around one of these. *)
    | Multiply (Constant value, Pi) | Multiply (Pi, Constant value) ->
        let numerator = value.Rhema_number.numerator
        and denominator = value.Rhema_number.denominator in
        let top = (if numerator = 1 then "" else string_of_int numerator) ^ "\\pi" in
        if denominator = 1 then top else "\\frac{" ^ top ^ "}{" ^ string_of_int denominator ^ "}"
    | Variable name -> name
    | Add (left, right) ->
        to_latex_with_context level left ^ " + " ^ to_latex_with_context level right
    | Subtract (left, right) ->
        to_latex_with_context level left ^ " - "
        ^ to_latex_with_context (level + 1) right
    | Multiply (left, right) ->
        to_latex_with_context level left ^ " \\cdot "
        ^ to_latex_with_context level right
    | Divide (left, right) ->
        "\\frac{" ^ to_latex_with_context 0 left ^ "}{"
        ^ to_latex_with_context 0 right ^ "}"
    | Power ((Exp _ as base), exponent) ->
        (* e^{x}^{3} is a double superscript in LaTeX; bracket the base *)
        "\\left(" ^ to_latex_with_context 0 base ^ "\\right)^{" ^ string_of_int exponent ^ "}"
    | Power (base, exponent) ->
        to_latex_with_context (level + 1) base ^ "^{" ^ string_of_int exponent ^ "}"
    | Negate ((Multiply _ | Divide _) as body) ->
        (* -(5 \cdot x) reads as a bracketed product; -5 \cdot x is the same
           value and is how it is written. Sums still need their brackets. *)
        "-" ^ to_latex_with_context (precedence body) body
    | Negate body -> "-" ^ to_latex_with_context level body
    | Sin body -> "\\sin\\left(" ^ to_latex_with_context 0 body ^ "\\right)"
    | Cos body -> "\\cos\\left(" ^ to_latex_with_context 0 body ^ "\\right)"
    | Tan body -> "\\tan\\left(" ^ to_latex_with_context 0 body ^ "\\right)"
    | Exp body -> "e^{" ^ to_latex_with_context 0 body ^ "}"
    | Ln body -> "\\ln\\left(" ^ to_latex_with_context 0 body ^ "\\right)"
    | Sqrt body -> "\\sqrt{" ^ to_latex_with_context 0 body ^ "}"
  in
  parenthesize (level < context) text

let to_latex expression = to_latex_with_context 0 expression

(* The number a formula without variables comes to, when it is rational:
   arithmetic on constants, whole powers, and roots that come out exactly.
   None for anything else (a variable, pi, a function value). *)
let rec rational_value = function
  | Constant value -> Some value
  | Pi | Variable _ | Sin _ | Cos _ | Tan _ | Exp _ | Ln _ -> None
  | Add (left, right) -> both Rhema_number.add left right
  | Subtract (left, right) -> both Rhema_number.subtract left right
  | Multiply (left, right) -> both Rhema_number.multiply left right
  | Divide (left, right) -> (
      match (rational_value left, rational_value right) with
      | Some left, Some right when not (Rhema_number.is_zero right) ->
          Some (Rhema_number.divide left right)
      | _ -> None)
  | Power (base, exponent) -> (
      match rational_value base with
      | Some base when exponent >= 0 || not (Rhema_number.is_zero base) ->
          Some (Rhema_number.power base (Rhema_number.of_int exponent))
      | _ -> None)
  | Negate body -> Option.map Rhema_number.negate (rational_value body)
  | Sqrt body -> Option.bind (rational_value body) Rhema_number.square_root_exact

and both operation left right =
  match (rational_value left, rational_value right) with
  | Some left, Some right -> Some (operation left right)
  | _ -> None

(* ------------------------------------------------------------------ *)
(* Exact values of sine, cosine and tangent                             *)
(* ------------------------------------------------------------------ *)

type trigonometric = Sine | Cosine | Tangent

(* The value at p pi / q, for the angles whose values are known in closed
   form in a first course: the multiples of pi/6 and of pi/4. The angle is
   counted in twelfths of pi, so those are the even numbers and the
   multiples of 3. Invalid_argument for any other angle, and for a tangent
   that is not defined. *)
let exact_value which ~numerator:p ~denominator:q =
  if q = 0 then invalid_arg "the angle p pi / q needs q different from 0";
  let p, q = if q < 0 then (-p, -q) else (p, q) in
  let rec gcd a b = if b = 0 then abs a else gcd b (a mod b) in
  let common = max 1 (gcd p q) in
  let p = p / common and q = q / common in
  if not (List.mem q [ 1; 2; 3; 4; 6 ]) then
    invalid_arg
      (Printf.sprintf
         "no exact value is known for the angle %d pi / %d; use multiples of pi/6 and pi/4" p q);
  let whole value = Constant (Rhema_number.of_int value) in
  let root value = Sqrt (whole value) in
  (* written as a quotient, so that it reads \\frac{1}{2} beside \\frac{\\sqrt{3}}{2} *)
  let half = Divide (one, whole 2) in
  (* sine of k twelfths of pi, for k from 0 to 6 *)
  let first_quadrant = function
    | 0 -> zero
    | 2 -> half
    | 3 -> Divide (root 2, whole 2)
    | 4 -> Divide (root 3, whole 2)
    | 6 -> one
    | k -> invalid_arg (Printf.sprintf "no exact sine for %d twelfths of pi" k)
  in
  let rec sine k =
    let k = ((k mod 24) + 24) mod 24 in
    if k > 12 then negate (sine (k - 12)) else if k > 6 then first_quadrant (12 - k) else first_quadrant k
  in
  let twelfths = p * (12 / q) in
  match which with
  | Sine -> sine twelfths
  | Cosine -> sine (twelfths + 6)
  | Tangent -> (
      match ((twelfths mod 12) + 12) mod 12 with
      | 0 -> zero
      | 2 -> Divide (root 3, whole 3)
      | 3 -> one
      | 4 -> root 3
      | 6 -> invalid_arg (Printf.sprintf "the tangent of %d pi / %d is not defined" p q)
      | 8 -> negate (root 3)
      | 9 -> minus_one
      | 10 -> negate (Divide (root 3, whole 3))
      | k -> invalid_arg (Printf.sprintf "no exact tangent for %d twelfths of pi" k))
