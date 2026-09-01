(* Exact vectors for Attribute Grammar questions. Components remain rational
   Ag_number values so dot and cross products have deterministic exact answers. *)

type t = Ag_number.t list

let make components =
  if components = [] then invalid_arg "a vector must have at least one component";
  components

let equal left right =
  List.length left = List.length right && List.for_all2 Ag_number.equal left right

let dimension vector = List.length vector
let is_zero vector = List.for_all Ag_number.is_zero vector

let map2 operation left right =
  if List.length left <> List.length right then
    invalid_arg "vector operands must have the same dimension";
  List.map2 operation left right

let add = map2 Ag_number.add
let subtract = map2 Ag_number.subtract
let scale scalar vector = List.map (Ag_number.multiply scalar) vector

let dot left right =
  map2 Ag_number.multiply left right |> List.fold_left Ag_number.add Ag_number.zero

let cross left right =
  match (left, right) with
  | [ a1; a2; a3 ], [ b1; b2; b3 ] ->
      [ Ag_number.subtract (Ag_number.multiply a2 b3) (Ag_number.multiply a3 b2);
        Ag_number.subtract (Ag_number.multiply a3 b1) (Ag_number.multiply a1 b3);
        Ag_number.subtract (Ag_number.multiply a1 b2) (Ag_number.multiply a2 b1) ]
  | _ -> invalid_arg "vector_cross requires two three-dimensional vectors"

let components vector = vector

let component_text vector =
  vector |> List.map Ag_number.to_string |> String.concat ", "

let to_latex vector = "\\langle " ^ component_text vector ^ " \\rangle"
let to_compute vector = "Compute(\"<" ^ component_text vector ^ ">\")"
