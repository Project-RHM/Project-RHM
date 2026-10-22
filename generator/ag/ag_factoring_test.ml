(* Independent checks for factoring.ag.

   The answer is a product of factors; the question is the same product
   multiplied out. Both come from the engine, by different routes (the
   Formula library for the answer, the Polynomial library for the question),
   so agreement between them at several points is a real check. The shape of
   the answer is inspected directly: every factor must be irreducible and
   primitive, no factor may repeat outside a power, and the factors must
   re-price to the budget. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let load_file filename =
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
      exit 1

let with_initial spec name value =
  match Ag_check.with_initial spec name value with
  | Ok changed -> changed
  | Error message ->
      fail message;
      spec

let expression_child (root : Ag_engine.node) =
  match List.find_opt (fun (node : Ag_engine.node) -> node.symbol = "E") root.children with
  | Some node -> node
  | None ->
      fail "factoring question has no E child";
      root

let polynomial_attribute node name =
  match Ag_engine.attribute node name with
  | Ag_engine.Polynomial polynomial -> polynomial
  | other ->
      fail (name ^ " expected a polynomial, got " ^ Ag_engine.describe_value other);
      Ag_polynomial.zero ~variable:"x"

let formula_answer question =
  match question.Ag_engine.answer with
  | Ag_engine.Formula formula -> formula
  | other ->
      fail ("answer expected a formula, got " ^ Ag_engine.describe_value other);
      Ag_formula.zero

(* ------------------------------------------------------------------ *)
(* The shape of a factored form                                        *)
(* ------------------------------------------------------------------ *)

let rec factors = function
  | Ag_formula.Multiply (left, right) -> factors left @ factors right
  | factor -> [ factor ]

let base_and_multiplicity = function
  | Ag_formula.Power (base, exponent) -> (base, exponent)
  | base -> (base, 1)

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let integer number = Ag_number.require_integer "coefficient" number

(* The price of a factor's base and what kind it is, or None when the base
   is not one of the grammar's irreducible, primitive factors. *)
let classify = function
  | Ag_formula.Add (Ag_formula.Variable "x", Ag_formula.Constant _)
  | Ag_formula.Subtract (Ag_formula.Variable "x", Ag_formula.Constant _) ->
      Some ("monic", 0)
  | Ag_formula.Add (Ag_formula.Multiply (Ag_formula.Constant a, Ag_formula.Variable "x"), Ag_formula.Constant b)
  | Ag_formula.Subtract (Ag_formula.Multiply (Ag_formula.Constant a, Ag_formula.Variable "x"), Ag_formula.Constant b) ->
      if gcd (integer a) (integer b) = 1 then Some ("linear", 1) else None
  | Ag_formula.Add (Ag_formula.Power (Ag_formula.Variable "x", 2), Ag_formula.Constant c)
    when Ag_number.compare c Ag_number.zero > 0 ->
      Some ("quadratic", 2)
  | _ -> None

let power_price = function 1 -> 0 | 2 -> 1 | 3 -> 2 | _ -> -1000

(* ------------------------------------------------------------------ *)
(* Generation across the budgets                                        *)
(* ------------------------------------------------------------------ *)

let () =
  let base = load_file "factoring.ag" in
  if base.Ag_check.context <> "PolynomialFactors" then
    fail ("factoring.ag selected context " ^ base.context);
  let kinds = Hashtbl.create 4 and powers = Hashtbl.create 3 in
  for cost = 1 to 10 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 29 do
      Random.init (seed + (cost * 1000));
      match Ag_engine.generate spec with
      | exception Ag_engine.Generation_error message ->
          fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
      | question -> (
          let root = question.Ag_engine.tree in
          let spent = Ag_engine.consumption root "cost" in
          if spent <> cost then fail (Printf.sprintf "cost %d: the tree spent %d" cost spent);
          let answer = formula_answer question in
          let expanded = polynomial_attribute (expression_child root) "poly" in
          (* the answer and the question agree as functions *)
          List.iter
            (fun x ->
              let from_answer = Ag_formula.evaluate ~variable:"x" ~at:x answer in
              let from_question =
                Ag_number.to_float
                  (Ag_polynomial.evaluate expanded (Ag_number.make (int_of_float (x *. 4.)) 4))
              in
              if Float.abs (from_answer -. from_question)
                 > 1e-6 *. Float.max 1. (Float.abs from_question)
              then
                fail
                  (Printf.sprintf "cost %d seed %d: answer %s and question differ at x = %g" cost
                     seed (Ag_formula.to_pg answer) x))
            [ -2.; -0.75; 0.; 0.5; 3. ];
          (* the factored form is complete, primitive and distinct *)
          let parts = List.map base_and_multiplicity (factors answer) in
          if List.length parts < 2 && List.for_all (fun (_, n) -> n = 1) parts then
            fail (Printf.sprintf "cost %d seed %d: %s is a single factor" cost seed (Ag_formula.to_pg answer));
          let degree = List.fold_left (fun total (base, n) ->
            total + n * (match classify base with Some ("quadratic", _) -> 2 | _ -> 1)) 0 parts in
          (match Ag_polynomial.degree expanded with
          | Some found when found = degree -> ()
          | _ -> fail (Printf.sprintf "cost %d seed %d: degree of %s is not %d" cost seed (Ag_formula.to_pg answer) degree));
          let bases = List.map fst parts in
          if List.length (List.sort_uniq compare bases) <> List.length bases then
            fail (Printf.sprintf "cost %d seed %d: %s repeats a factor" cost seed (Ag_formula.to_pg answer));
          match List.map (fun (base, n) -> (classify base, n)) parts with
          | classified when List.exists (fun (kind, _) -> kind = None) classified ->
              fail (Printf.sprintf "cost %d seed %d: %s has a factor that is not irreducible and primitive" cost seed (Ag_formula.to_pg answer))
          | classified ->
              List.iter (fun (kind, n) ->
                (match kind with Some (name, _) -> Hashtbl.replace kinds name true | None -> ());
                Hashtbl.replace powers n true) classified;
              let priced =
                (2 * (List.length classified - 1))
                + List.fold_left (fun total (kind, n) ->
                    total + power_price n + (match kind with Some (_, price) -> price | None -> 0)) 0 classified
              in
              if priced <> cost then
                fail (Printf.sprintf "cost %d seed %d: %s re-prices as %d" cost seed (Ag_formula.to_pg answer) priced))
    done
  done;
  List.iter (fun kind -> if not (Hashtbl.mem kinds kind) then fail ("no " ^ kind ^ " factor was generated"))
    [ "monic"; "linear"; "quadratic" ];
  List.iter (fun n -> if not (Hashtbl.mem powers n) then fail (Printf.sprintf "no factor of multiplicity %d was generated" n))
    [ 1; 2; 3 ];
  (* the .pg file selects the factoring context and loads its macro *)
  Random.init 5;
  let document = Ag_pgml.of_spec ~count:3 base in
  let contains fragment =
    let rec search index =
      index + String.length fragment <= String.length document
      && (String.sub document index (String.length fragment) = fragment || search (index + 1))
    in
    search 0
  in
  if not (contains "Context(\"PolynomialFactors\");") then fail "the .pg file does not select PolynomialFactors";
  if not (contains "contextPolynomialFactors.pl") then fail "the .pg file does not load contextPolynomialFactors.pl";
  if !failures = 0 then print_endline "Ag factoring tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG factoring test(s) failed." !failures);
    exit 1
  end
