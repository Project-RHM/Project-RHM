(* Exact univariate polynomials for reusable algebra specifications.

   Coefficients are stored in ascending degree order: [c0; c1; c2] means
   c0 + c1*x + c2*x^2.  Every constructor normalizes trailing zeroes, so
   equality and degree checks do not depend on how a polynomial was built. *)

type t = { variable : string; coefficients : Rhema_number.t list }

let validate_variable name = ignore (Rhema_formula.variable name)

let rec drop_trailing_zeroes = function
  | [] -> []
  | coefficients -> (
      match List.rev coefficients with
      | coefficient :: rest when Rhema_number.is_zero coefficient ->
          drop_trailing_zeroes (List.rev rest)
      | _ -> coefficients)

let normalize coefficients =
  match drop_trailing_zeroes coefficients with
  | [] -> [ Rhema_number.zero ]
  | coefficients -> coefficients

let make ~variable coefficients =
  validate_variable variable;
  { variable; coefficients = normalize coefficients }

let variable_name polynomial = polynomial.variable
let coefficients polynomial = polynomial.coefficients

let zero ~variable = make ~variable []
let constant ~variable value = make ~variable [ value ]
let variable name = make ~variable:name [ Rhema_number.zero; Rhema_number.of_int 1 ]

let monomial ~variable coefficient degree =
  if degree < 0 then invalid_arg "polynomial degree must be non-negative";
  make ~variable
    (List.init degree (fun _ -> Rhema_number.zero) @ [ coefficient ])

let linear ~variable coefficient constant_term =
  make ~variable [ constant_term; coefficient ]

let quadratic ~variable quadratic_coefficient linear_coefficient constant_term =
  make ~variable [ constant_term; linear_coefficient; quadratic_coefficient ]

let is_zero polynomial =
  match polynomial.coefficients with
  | [ coefficient ] -> Rhema_number.is_zero coefficient
  | _ -> false

let degree polynomial =
  if is_zero polynomial then None else Some (List.length polynomial.coefficients - 1)

let coefficient polynomial degree =
  if degree < 0 then invalid_arg "polynomial degree must be non-negative";
  match List.nth_opt polynomial.coefficients degree with
  | Some coefficient -> coefficient
  | None -> Rhema_number.zero

let ensure_same_variable operation left right =
  if left.variable <> right.variable then
    invalid_arg
      (Printf.sprintf "%s requires matching variables, received %s and %s" operation
         left.variable right.variable)

let equal left right =
  left.variable = right.variable
  && List.length left.coefficients = List.length right.coefficients
  && List.for_all2 Rhema_number.equal left.coefficients right.coefficients

let map_coefficients operation left right =
  let size = max (List.length left.coefficients) (List.length right.coefficients) in
  List.init size (fun degree ->
      operation (coefficient left degree) (coefficient right degree))

let add left right =
  ensure_same_variable "polynomial_add" left right;
  make ~variable:left.variable (map_coefficients Rhema_number.add left right)

let subtract left right =
  ensure_same_variable "polynomial_subtract" left right;
  make ~variable:left.variable (map_coefficients Rhema_number.subtract left right)

let scale scalar polynomial =
  make ~variable:polynomial.variable
    (List.map (Rhema_number.multiply scalar) polynomial.coefficients)

let multiply left right =
  ensure_same_variable "polynomial_multiply" left right;
  let result_size = List.length left.coefficients + List.length right.coefficients - 1 in
  let result = Array.make result_size Rhema_number.zero in
  List.iteri
    (fun left_degree left_coefficient ->
      List.iteri
        (fun right_degree right_coefficient ->
          let degree = left_degree + right_degree in
          result.(degree) <-
            Rhema_number.add result.(degree)
              (Rhema_number.multiply left_coefficient right_coefficient))
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
  repeat (constant ~variable:polynomial.variable (Rhema_number.of_int 1)) polynomial
    exponent

let derivative polynomial =
  let differentiated =
    polynomial.coefficients
    |> List.mapi (fun degree coefficient ->
           if degree = 0 then None
           else Some (Rhema_number.multiply (Rhema_number.of_int degree) coefficient))
    |> List.filter_map Fun.id
  in
  make ~variable:polynomial.variable differentiated

let evaluate polynomial value =
  List.fold_right
    (fun coefficient accumulator ->
      Rhema_number.add coefficient (Rhema_number.multiply value accumulator))
    polynomial.coefficients Rhema_number.zero

let to_formula polynomial =
  let x = Rhema_formula.variable polynomial.variable in
  polynomial.coefficients
  |> List.mapi (fun degree coefficient ->
         if Rhema_number.is_zero coefficient then None
         else
           let variable_part =
             if degree = 0 then Rhema_formula.one else Rhema_formula.power x degree
           in
           Some
             (if degree > 0 && Rhema_number.equal coefficient (Rhema_number.of_int 1) then
                variable_part
              else if
                degree > 0 && Rhema_number.equal coefficient (Rhema_number.of_int (-1))
              then Rhema_formula.negate variable_part
              else Rhema_formula.multiply (Rhema_formula.constant coefficient) variable_part))
  |> List.filter_map Fun.id |> List.rev
  |> List.fold_left Rhema_formula.add Rhema_formula.zero

let to_pg polynomial = Rhema_formula.to_pg (to_formula polynomial)
let to_latex polynomial = Rhema_formula.to_latex (to_formula polynomial)

let rec of_formula ~variable expression =
  let recurse = of_formula ~variable in
  match expression with
  | Rhema_formula.Constant value -> Some (constant ~variable value)
  | Rhema_formula.Variable name ->
      if name = variable then
        Some (make ~variable:name [ Rhema_number.zero; Rhema_number.of_int 1 ])
      else None
  | Rhema_formula.Add (left, right) -> (
      match (recurse left, recurse right) with
      | Some left, Some right -> Some (add left right)
      | _ -> None)
  | Rhema_formula.Subtract (left, right) -> (
      match (recurse left, recurse right) with
      | Some left, Some right -> Some (subtract left right)
      | _ -> None)
  | Rhema_formula.Multiply (left, right) -> (
      match (recurse left, recurse right) with
      | Some left, Some right -> Some (multiply left right)
      | _ -> None)
  | Rhema_formula.Divide (numerator, Rhema_formula.Constant denominator)
    when not (Rhema_number.is_zero denominator) -> (
      match recurse numerator with
      | Some numerator -> Some (scale (Rhema_number.divide (Rhema_number.of_int 1) denominator) numerator)
      | None -> None)
  | Rhema_formula.Power (base, exponent) when exponent >= 0 -> (
      match recurse base with Some base -> Some (power base exponent) | None -> None)
  | Rhema_formula.Negate body -> (
      match recurse body with
      | Some body -> Some (scale (Rhema_number.of_int (-1)) body)
      | None -> None)
  | Rhema_formula.Divide _ | Rhema_formula.Power _ | Rhema_formula.Sin _ | Rhema_formula.Cos _
  | Rhema_formula.Tan _ | Rhema_formula.Exp _ | Rhema_formula.Ln _ | Rhema_formula.Sqrt _ ->
      None

let linear_root polynomial =
  match degree polynomial with
  | Some 1 ->
      Some
        (Rhema_number.divide (Rhema_number.negate (coefficient polynomial 0))
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
        Rhema_number.subtract (Rhema_number.multiply b b)
          (Rhema_number.multiply (Rhema_number.of_int 4) (Rhema_number.multiply a c))
      in
      if Rhema_number.compare discriminant Rhema_number.zero < 0 then Some []
      else (
        match Rhema_number.square_root_exact discriminant with
        | None -> None
        | Some root ->
            let denominator = Rhema_number.multiply (Rhema_number.of_int 2) a in
            let first = Rhema_number.divide (Rhema_number.subtract (Rhema_number.negate b) root) denominator
            and second = Rhema_number.divide (Rhema_number.add (Rhema_number.negate b) root) denominator in
            Some (List.sort_uniq Rhema_number.compare [ first; second ]))
  | _ -> None
