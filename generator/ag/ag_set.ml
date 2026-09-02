(* Symbolic sets used by set question specifications. Finite sets are
   canonicalized; interval and operation nodes are kept symbolic so the same
   value can be rendered both as student-facing LaTeX and as WeBWorK Compute
   syntax. *)

type endpoint = Open | Closed

type t =
  | Finite of Ag_number.t list
  | Interval of Ag_number.t * Ag_number.t * endpoint * endpoint
  | Union of t * t
  | Intersection of t * t
  | Difference of t * t

let compare_number = Ag_number.compare

let normalize elements = List.sort_uniq compare_number elements

let empty = Finite []

let insert set element =
  match set with
  | Finite elements -> Finite (normalize (element :: elements))
  | _ -> invalid_arg "set_insert expects a finite set"

let interval lower upper left_endpoint right_endpoint =
  if Ag_number.compare lower upper >= 0 then
    invalid_arg "set_interval requires its lower endpoint to be less than its upper endpoint";
  Interval (lower, upper, left_endpoint, right_endpoint)

let union left right = Union (left, right)
let intersection left right = Intersection (left, right)
let difference left right = Difference (left, right)
let equal = ( = )

let precedence = function
  | Union _ -> 10
  | Intersection _ | Difference _ -> 20
  | Finite _ | Interval _ -> 50

let parenthesize needed text = if needed then "(" ^ text ^ ")" else text

let finite_text ~left ~right elements =
  left ^ String.concat ", " (List.map Ag_number.to_string elements) ^ right

let rec to_latex_with_context context set =
  let level = precedence set in
  let text =
    match set with
    | Finite elements -> finite_text ~left:"\\{" ~right:"\\}" elements
    | Interval (lower, upper, left_endpoint, right_endpoint) ->
        let left = match left_endpoint with Open -> "(" | Closed -> "[" in
        let right = match right_endpoint with Open -> ")" | Closed -> "]" in
        Printf.sprintf "%s%s, %s%s" left (Ag_number.to_string lower)
          (Ag_number.to_string upper) right
    | Union (left, right) ->
        to_latex_with_context level left ^ " \\cup " ^ to_latex_with_context level right
    | Intersection (left, right) ->
        to_latex_with_context level left ^ " \\cap "
        ^ to_latex_with_context (level + 1) right
    | Difference (left, right) ->
        to_latex_with_context level left ^ " \\setminus "
        ^ to_latex_with_context (level + 1) right
  in
  parenthesize (level < context) text

let to_latex set = to_latex_with_context 0 set

(* WeBWorK's Interval context uses U for union and has no direct intersection
   token in Compute strings. A cap B is therefore encoded as
   A - (universe - B), matching the Stage 1 generator. *)
let rec to_pg = function
  | Finite elements -> finite_text ~left:"{" ~right:"}" elements
  | Interval (lower, upper, left_endpoint, right_endpoint) ->
      let left = match left_endpoint with Open -> "(" | Closed -> "[" in
      let right = match right_endpoint with Open -> ")" | Closed -> "]" in
      Printf.sprintf "%s%s, %s%s" left (Ag_number.to_string lower)
        (Ag_number.to_string upper) right
  | Union (left, right) -> Printf.sprintf "(%s) U (%s)" (to_pg left) (to_pg right)
  | Intersection (left, right) ->
      Printf.sprintf "(%s) - ((-infinity, infinity) - (%s))" (to_pg left) (to_pg right)
  | Difference (left, right) -> Printf.sprintf "(%s) - (%s)" (to_pg left) (to_pg right)

let rec contains value = function
  | Finite elements -> List.exists (Ag_number.equal value) elements
  | Interval (lower, upper, left_endpoint, right_endpoint) ->
      let lower_comparison = Ag_number.compare value lower in
      let upper_comparison = Ag_number.compare value upper in
      let above_lower =
        match left_endpoint with Open -> lower_comparison > 0 | Closed -> lower_comparison >= 0
      in
      let below_upper =
        match right_endpoint with Open -> upper_comparison < 0 | Closed -> upper_comparison <= 0
      in
      above_lower && below_upper
  | Union (left, right) -> contains value left || contains value right
  | Intersection (left, right) -> contains value left && contains value right
  | Difference (left, right) -> contains value left && not (contains value right)
