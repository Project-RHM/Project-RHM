(* Independent checks for linear_equation.ag.

   Both sides of the printed equation are formulas the engine built; they
   are evaluated here as functions. The stated root must satisfy the
   equation, a neighbouring point must not (so the root is unique), and the
   left side re-prices to the budget from its shape. *)

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

let formula_attribute node name =
  match Ag_engine.attribute node name with
  | Ag_engine.Formula formula -> formula
  | other ->
      fail (name ^ " expected a formula, got " ^ Ag_engine.describe_value other);
      Ag_formula.zero

let expression_child (root : Ag_engine.node) =
  match List.find_opt (fun (node : Ag_engine.node) -> node.symbol = "E") root.children with
  | Some node -> node
  | None -> fail "equation has no E child"; root

(* The price of the left side from its shape: a sum or difference 1, a
   number times a compound 1, a fraction with a number below 2, a term 0.
   Negate only renders a negative coefficient. *)
let rec price = function
  | Ag_formula.Variable _ | Ag_formula.Constant _ -> 0
  | Ag_formula.Negate body -> price body
  | Ag_formula.Multiply (Ag_formula.Constant _, Ag_formula.Variable _) -> 0
  | Ag_formula.Multiply (Ag_formula.Constant _, body) -> 1 + price body
  | Ag_formula.Add (left, right) | Ag_formula.Subtract (left, right) -> 1 + price left + price right
  | Ag_formula.Divide (body, Ag_formula.Constant _) -> 2 + price body
  | other -> fail ("unexpected construct in " ^ Ag_formula.to_pg other); 0

let () =
  let base = load_file "linear_equation.ag" in
  let saw_fraction = ref false and saw_multiple = ref false in
  for cost = 1 to 10 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 29 do
      Random.init (seed + (cost * 1000));
      match Ag_engine.generate spec with
      | exception Ag_engine.Generation_error message ->
          fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
      | question ->
          let root = question.Ag_engine.tree in
          let spent = Ag_engine.consumption root "cost" in
          if spent <> cost then fail (Printf.sprintf "cost %d: the tree spent %d" cost spent);
          let left = formula_attribute (expression_child root) "formula" in
          let right = formula_attribute root "rhs" in
          let answer =
            match question.Ag_engine.answer with
            | Ag_engine.Num number -> Ag_number.to_float number
            | other -> fail ("answer expected a number, got " ^ Ag_engine.describe_value other); 0.
          in
          let at x formula = Ag_formula.evaluate ~variable:"x" ~at:x formula in
          let gap x = Float.abs (at x left -. at x right) in
          if gap answer > 1e-9 then
            fail (Printf.sprintf "cost %d seed %d: %s does not solve %s" cost seed
                    (string_of_float answer) (Ag_formula.to_pg left ^ " = " ^ Ag_formula.to_pg right));
          if gap (answer +. 1.) < 1e-9 then
            fail (Printf.sprintf "cost %d seed %d: the root of %s is not unique" cost seed (Ag_formula.to_pg left));
          let priced = price left in
          if priced <> cost then
            fail (Printf.sprintf "cost %d seed %d: %s re-prices as %d" cost seed (Ag_formula.to_pg left) priced);
          let rec walk = function
            | Ag_formula.Divide _ -> saw_fraction := true
            | Ag_formula.Multiply (Ag_formula.Constant _, (Ag_formula.Add _ | Ag_formula.Subtract _)) -> saw_multiple := true
            | Ag_formula.Add (l, r) | Ag_formula.Subtract (l, r) | Ag_formula.Multiply (l, r) -> walk l; walk r
            | Ag_formula.Negate b -> walk b
            | _ -> ()
          in
          walk left
    done
  done;
  if not !saw_fraction then fail "no fraction was generated";
  if not !saw_multiple then fail "no multiple of a bracket was generated";
  if !failures = 0 then print_endline "Ag linear equation tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG linear equation test(s) failed." !failures);
    exit 1
  end
