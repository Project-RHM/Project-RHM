(* rhema_number.ml — exact rational arithmetic for generated answers.

   Answers are kept as fractions rather than floats so that 7 / 2 stays 7/2
   instead of turning into 3.5 and then into 3.4999999999999996. A question
   whose answer is a fraction can then be printed exactly, and one whose answer
   happens to be whole prints as a plain integer. *)

exception Arithmetic_error of string

type t = { numerator : int; denominator : int }
(* Invariant: denominator > 0, and gcd(|numerator|, denominator) = 1. *)

(* The numerator and the denominator are OCaml integers, of 63 bits. A sum or
   a product that does not fit used to wrap round without a word: the answer
   was then a wrong number, or a pair of numbers on which the next step never
   ended. Every operation below is checked instead, and one whose result does
   not fit raises Arithmetic_error, which generation treats like a division
   by zero: the question is drawn again, and a grammar that always overflows
   is told so. *)
let too_large () =
  raise (Arithmetic_error "a number grew too large to be kept exact (it needs more than 63 bits)")

let checked_negate value = if value = min_int then too_large () else -value

let checked_add left right =
  let sum = left + right in
  if left >= 0 = (right >= 0) && sum >= 0 <> (left >= 0) then too_large () else sum

let checked_subtract left right =
  let difference = left - right in
  if left >= 0 <> (right >= 0) && difference >= 0 <> (left >= 0) then too_large () else difference

let checked_multiply left right =
  if left = 0 || right = 0 then 0
  else if (left = -1 && right = min_int) || (right = -1 && left = min_int) then too_large ()
  else
    let product = left * right in
    if product / right <> left then too_large () else product

let rec greatest_common_divisor a b = if b = 0 then abs a else greatest_common_divisor b (a mod b)

let make numerator denominator =
  if denominator = 0 then raise (Arithmetic_error "division by zero");
  (* The one integer that has no negative and no absolute value. *)
  if numerator = min_int || denominator = min_int then too_large ();
  let sign = if denominator < 0 then -1 else 1 in
  let numerator = sign * numerator and denominator = sign * denominator in
  let divisor = greatest_common_divisor numerator denominator in
  let divisor = if divisor = 0 then 1 else divisor in
  { numerator = numerator / divisor; denominator = denominator / divisor }

let of_int value = { numerator = value; denominator = 1 }
let zero = of_int 0
let is_zero value = value.numerator = 0
let is_integer value = value.denominator = 1

let add left right =
  make
    (checked_add
       (checked_multiply left.numerator right.denominator)
       (checked_multiply right.numerator left.denominator))
    (checked_multiply left.denominator right.denominator)

let subtract left right =
  make
    (checked_subtract
       (checked_multiply left.numerator right.denominator)
       (checked_multiply right.numerator left.denominator))
    (checked_multiply left.denominator right.denominator)

let multiply left right =
  make
    (checked_multiply left.numerator right.numerator)
    (checked_multiply left.denominator right.denominator)

let divide left right =
  if is_zero right then raise (Arithmetic_error "division by zero");
  make
    (checked_multiply left.numerator right.denominator)
    (checked_multiply left.denominator right.numerator)

let negate value = { value with numerator = checked_negate value.numerator }

let absolute value =
  if value.numerator < 0 then { value with numerator = checked_negate value.numerator } else value

let compare left right =
  Stdlib.compare
    (checked_multiply left.numerator right.denominator)
    (checked_multiply right.numerator left.denominator)

let equal left right = compare left right = 0

let require_integer context value =
  if not (is_integer value) then
    raise
      (Arithmetic_error
         (Printf.sprintf "%s needs a whole number, but received %d/%d" context
            value.numerator value.denominator));
  value.numerator

let modulo left right =
  let left = require_integer "%" left and right = require_integer "%" right in
  if right = 0 then raise (Arithmetic_error "division by zero");
  of_int (left mod right)

let power base exponent =
  let exponent = require_integer "^" exponent in
  let rec repeat accumulator count =
    if count = 0 then accumulator else repeat (multiply accumulator base) (count - 1)
  in
  if exponent >= 0 then repeat (of_int 1) exponent
  else
    let positive = repeat (of_int 1) (-exponent) in
    if is_zero positive then raise (Arithmetic_error "division by zero")
    else divide (of_int 1) positive

let to_string value =
  if is_integer value then string_of_int value.numerator
  else Printf.sprintf "%d/%d" value.numerator value.denominator

let to_float value = float_of_int value.numerator /. float_of_int value.denominator

(* Return an exact rational square root when both the numerator and denominator
   are perfect squares.  Equation solving uses this to distinguish answers that
   can stay exact from irrational roots that need a richer answer type. *)
let integer_square_root_exact value =
  if value < 0 then None
  else
    let root = int_of_float (Stdlib.sqrt (float_of_int value)) in
    let candidates = [ root - 1; root; root + 1 ] in
    List.find_opt (fun candidate -> candidate >= 0 && candidate * candidate = value) candidates

let square_root_exact value =
  if value.numerator < 0 then None
  else
    match
      ( integer_square_root_exact value.numerator,
        integer_square_root_exact value.denominator )
    with
    | Some numerator, Some denominator -> Some (make numerator denominator)
    | _ -> None
