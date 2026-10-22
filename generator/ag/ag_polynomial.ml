(* Exact univariate polynomials for reusable algebra specifications.

   Coefficients are stored in ascending degree order: [c0; c1; c2] means
   c0 + c1*x + c2*x^2.  Every constructor normalizes trailing zeroes, so
   equality and degree checks do not depend on how a polynomial was built. *)

type t = { variable : string; coefficients : Ag_number.t list }

let validate_variable name = ignore (Ag_formula.variable name)

let rec drop_trailing_zeroes = function
  | [] -> []
  | coefficients -> (
      match List.rev coefficients with
      | coefficient :: rest when Ag_number.is_zero coefficient ->
          drop_trailing_zeroes (List.rev rest)
      | _ -> coefficients)

let normalize coefficients =
  match drop_trailing_zeroes coefficients with
  | [] -> [ Ag_number.zero ]
  | coefficients -> coefficients

let make ~variable coefficients =
  validate_variable variable;
  { variable; coefficients = normalize coefficients }

let variable_name polynomial = polynomial.variable
let coefficients polynomial = polynomial.coefficients

let zero ~variable = make ~variable []
let constant ~variable value = make ~variable [ value ]
let variable name = make ~variable:name [ Ag_number.zero; Ag_number.of_int 1 ]

let monomial ~variable coefficient degree =
  if degree < 0 then invalid_arg "polynomial degree must be non-negative";
  make ~variable
    (List.init degree (fun _ -> Ag_number.zero) @ [ coefficient ])

let linear ~variable coefficient constant_term =
  make ~variable [ constant_term; coefficient ]

let quadratic ~variable quadratic_coefficient linear_coefficient constant_term =
  make ~variable [ constant_term; linear_coefficient; quadratic_coefficient ]

let is_zero polynomial =
  match polynomial.coefficients with
  | [ coefficient ] -> Ag_number.is_zero coefficient
  | _ -> false

let degree polynomial =
  if is_zero polynomial then None else Some (List.length polynomial.coefficients - 1)

let coefficient polynomial degree =
  if degree < 0 then invalid_arg "polynomial degree must be non-negative";
  match List.nth_opt polynomial.coefficients degree with
  | Some coefficient -> coefficient
  | None -> Ag_number.zero

let ensure_same_variable operation left right =
  if left.variable <> right.variable then
    invalid_arg
      (Printf.sprintf "%s requires matching variables, received %s and %s" operation
         left.variable right.variable)

let equal left right =
  left.variable = right.variable
  && List.length left.coefficients = List.length right.coefficients
  && List.for_all2 Ag_number.equal left.coefficients right.coefficients

let map_coefficients operation left right =
  let size = max (List.length left.coefficients) (List.length right.coefficients) in
  List.init size (fun degree ->
      operation (coefficient left degree) (coefficient right degree))

let add left right =
  ensure_same_variable "polynomial_add" left right;
  make ~variable:left.variable (map_coefficients Ag_number.add left right)

let subtract left right =
  ensure_same_variable "polynomial_subtract" left right;
  make ~variable:left.variable (map_coefficients Ag_number.subtract left right)

let scale scalar polynomial =
  make ~variable:polynomial.variable
    (List.map (Ag_number.multiply scalar) polynomial.coefficients)

let multiply left right =
  ensure_same_variable "polynomial_multiply" left right;
  let result_size = List.length left.coefficients + List.length right.coefficients - 1 in
  let result = Array.make result_size Ag_number.zero in
  List.iteri
    (fun left_degree left_coefficient ->
      List.iteri
        (fun right_degree right_coefficient ->
          let degree = left_degree + right_degree in
          result.(degree) <-
            Ag_number.add result.(degree)
              (Ag_number.multiply left_coefficient right_coefficient))
        right.coefficients)
    left.coefficients;
  make ~variable:left.variable (Array.to_list result)

let power polynomial exponent =
  if exponent < 0 then invalid_arg "polynomial exponent must be non-negative";
  let rec repeat accumulator base exponent =
    if exponent = 0 then accumulator
    else if exponent mod 2 = 1 then
      repeat (multiply accumulator base) (multiply base base) (exponent / 2)
    else repeat accumulator (multiply base base) (exponent / 2)
  in
  repeat (constant ~variable:polynomial.variable (Ag_number.of_int 1)) polynomial
    exponent

let derivative polynomial =
  let differentiated =
    polynomial.coefficients
    |> List.mapi (fun degree coefficient ->
           if degree = 0 then None
           else Some (Ag_number.multiply (Ag_number.of_int degree) coefficient))
    |> List.filter_map Fun.id
  in
  make ~variable:polynomial.variable differentiated

let evaluate polynomial value =
  List.fold_right
    (fun coefficient accumulator ->
      Ag_number.add coefficient (Ag_number.multiply value accumulator))
    polynomial.coefficients Ag_number.zero

let to_formula polynomial =
  let x = Ag_formula.variable polynomial.variable in
  polynomial.coefficients
  |> List.mapi (fun degree coefficient ->
         if Ag_number.is_zero coefficient then None
         else
           let variable_part =
             if degree = 0 then Ag_formula.one else Ag_formula.power x degree
           in
           Some
             (if degree > 0 && Ag_number.equal coefficient (Ag_number.of_int 1) then
                variable_part
              else if
                degree > 0 && Ag_number.equal coefficient (Ag_number.of_int (-1))
              then Ag_formula.negate variable_part
              else Ag_formula.multiply (Ag_formula.constant coefficient) variable_part))
  |> List.filter_map Fun.id |> List.rev
  |> List.fold_left Ag_formula.add Ag_formula.zero

let to_pg polynomial = Ag_formula.to_pg (to_formula polynomial)
let to_latex polynomial = Ag_formula.to_latex (to_formula polynomial)

let rec of_formula ~variable expression =
  let recurse = of_formula ~variable in
  match expression with
  | Ag_formula.Constant value -> Some (constant ~variable value)
  | Ag_formula.Variable name ->
      if name = variable then
        Some (make ~variable:name [ Ag_number.zero; Ag_number.of_int 1 ])
      else None
  | Ag_formula.Add (left, right) -> (
      match (recurse left, recurse right) with
      | Some left, Some right -> Some (add left right)
      | _ -> None)
  | Ag_formula.Subtract (left, right) -> (
      match (recurse left, recurse right) with
      | Some left, Some right -> Some (subtract left right)
      | _ -> None)
  | Ag_formula.Multiply (left, right) -> (
      match (recurse left, recurse right) with
      | Some left, Some right -> Some (multiply left right)
      | _ -> None)
  | Ag_formula.Divide (numerator, Ag_formula.Constant denominator)
    when not (Ag_number.is_zero denominator) -> (
      match recurse numerator with
      | Some numerator -> Some (scale (Ag_number.divide (Ag_number.of_int 1) denominator) numerator)
      | None -> None)
  | Ag_formula.Power (base, exponent) when exponent >= 0 -> (
      match recurse base with Some base -> Some (power base exponent) | None -> None)
  | Ag_formula.Negate body -> (
      match recurse body with
      | Some body -> Some (scale (Ag_number.of_int (-1)) body)
      | None -> None)
  | Ag_formula.Divide _ | Ag_formula.Power _ | Ag_formula.Sin _ | Ag_formula.Cos _
  | Ag_formula.Tan _ | Ag_formula.Exp _ | Ag_formula.Ln _ | Ag_formula.Sqrt _ ->
      None

let linear_root polynomial =
  match degree polynomial with
  | Some 1 ->
      Some
        (Ag_number.divide (Ag_number.negate (coefficient polynomial 0))
           (coefficient polynomial 1))
  | _ -> None

(* [Some roots] means the real roots are known exactly. [None] means the
   polynomial is unsupported or has irrational roots. *)
let roots_exact polynomial =
  match degree polynomial with
  | Some 1 -> Option.map (fun root -> [ root ]) (linear_root polynomial)
  | Some 2 ->
      let a = coefficient polynomial 2
      and b = coefficient polynomial 1
      and c = coefficient polynomial 0 in
      let discriminant =
        Ag_number.subtract (Ag_number.multiply b b)
          (Ag_number.multiply (Ag_number.of_int 4) (Ag_number.multiply a c))
      in
      if Ag_number.compare discriminant Ag_number.zero < 0 then Some []
      else (
        match Ag_number.square_root_exact discriminant with
        | None -> None
        | Some root ->
            let denominator = Ag_number.multiply (Ag_number.of_int 2) a in
            let first = Ag_number.divide (Ag_number.subtract (Ag_number.negate b) root) denominator
            and second = Ag_number.divide (Ag_number.add (Ag_number.negate b) root) denominator in
            Some (List.sort_uniq Ag_number.compare [ first; second ]))
  | _ -> None
