(* Exact vectors for Attribute Grammar questions. Components remain rational
   Rhema_number values so dot and cross products have deterministic exact answers. *)

type t = Rhema_number.t list

let make components =
  if components = [] then invalid_arg "a vector must have at least one component";
  components

let equal left right =
  List.length left = List.length right && List.for_all2 Rhema_number.equal left right

let dimension vector = List.length vector
let is_zero vector = List.for_all Rhema_number.is_zero vector

let map2 operation left right =
  if List.length left <> List.length right then
    invalid_arg "vector operands must have the same dimension";
  List.map2 operation left right

let add = map2 Rhema_number.add
let subtract = map2 Rhema_number.subtract
let scale scalar vector = List.map (Rhema_number.multiply scalar) vector

let dot left right =
  map2 Rhema_number.multiply left right |> List.fold_left Rhema_number.add Rhema_number.zero

let cross left right =
  match (left, right) with
  | [ a1; a2; a3 ], [ b1; b2; b3 ] ->
      [ Rhema_number.subtract (Rhema_number.multiply a2 b3) (Rhema_number.multiply a3 b2);
        Rhema_number.subtract (Rhema_number.multiply a3 b1) (Rhema_number.multiply a1 b3);
        Rhema_number.subtract (Rhema_number.multiply a1 b2) (Rhema_number.multiply a2 b1) ]
  | _ -> invalid_arg "vector_cross requires two three-dimensional vectors"

let components vector = vector

let component_text vector =
  vector |> List.map Rhema_number.to_string |> String.concat ", "

let to_latex vector = "\\langle " ^ component_text vector ^ " \\rangle"
let to_compute vector = "Compute(\"<" ^ component_text vector ^ ">\")"
