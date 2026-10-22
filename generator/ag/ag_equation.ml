(* Symbolic equations whose sides are Formula values.  Exact equation solving
   deliberately accepts only univariate polynomials of degree at most two;
   callers can distinguish unsupported equations instead of receiving a
   plausible but unverified answer. *)

type t = { left : Ag_formula.t; right : Ag_formula.t }

type solution =
  | No_solution
  | All_values
  | Finite of Ag_number.t list
  | Unsupported

let make left right = { left; right }
let left equation = equation.left
let right equation = equation.right
let equal = ( = )

let of_polynomials left right =
  if Ag_polynomial.variable_name left <> Ag_polynomial.variable_name right then
    invalid_arg "polynomial equation requires matching variables";
  make (Ag_polynomial.to_formula left) (Ag_polynomial.to_formula right)

let normal_form equation = Ag_formula.subtract equation.left equation.right

let polynomial ~variable equation =
  Ag_polynomial.of_formula ~variable (normal_form equation)

let solve ~variable equation =
  match polynomial ~variable equation with
  | None -> Unsupported
  | Some polynomial -> (
      match Ag_polynomial.degree polynomial with
      | None -> All_values
      | Some 0 -> No_solution
      | Some 1 -> (
          match Ag_polynomial.linear_root polynomial with
          | Some root -> Finite [ root ]
          | None -> Unsupported)
      | Some 2 -> (
          match Ag_polynomial.roots_exact polynomial with
          | Some roots -> Finite roots
          | None -> Unsupported)
      | Some _ -> Unsupported)

let exact_solutions ~variable equation =
  match solve ~variable equation with
  | Finite roots -> Some roots
  | No_solution -> Some []
  | All_values | Unsupported -> None

let satisfies ~variable ~value equation =
  match polynomial ~variable equation with
  | Some polynomial -> Ag_number.is_zero (Ag_polynomial.evaluate polynomial value)
  | None ->
      let lookup name = if name = variable then Some (Ag_number.to_float value) else None in
      let left = Ag_formula.evaluate_with lookup equation.left
      and right = Ag_formula.evaluate_with lookup equation.right in
      Float.abs (left -. right) <= 1e-9 *. max 1.0 (max (Float.abs left) (Float.abs right))

let to_pg equation = Ag_formula.to_pg equation.left ^ "=" ^ Ag_formula.to_pg equation.right

let to_latex equation =
  Ag_formula.to_latex equation.left ^ " = " ^ Ag_formula.to_latex equation.right
