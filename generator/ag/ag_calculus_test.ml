(* Independent semantic and generation checks for calculus.ag. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let contains text fragment =
  let text_length = String.length text and fragment_length = String.length fragment in
  let rec search index =
    index + fragment_length <= text_length
    &&
    (String.sub text index fragment_length = fragment || search (index + 1))
  in
  fragment_length = 0 || search 0

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

let text_attribute node name =
  match Ag_engine.attribute node name with
  | Ag_engine.Text text -> text
  | other ->
      fail (name ^ " expected text, got " ^ Ag_engine.describe_value other);
      ""

let formula_attribute node name =
  match Ag_engine.attribute node name with
  | Ag_engine.Formula formula -> formula
  | other ->
      fail (name ^ " expected Formula, got " ^ Ag_engine.describe_value other);
      Ag_formula.zero

let formula_answer question =
  match question.Ag_engine.answer with
  | Ag_engine.Formula formula -> formula
  | other ->
      fail ("answer expected Formula, got " ^ Ag_engine.describe_value other);
      Ag_formula.zero

let expression_child root =
  match List.find_opt (fun (node : Ag_engine.node) -> node.symbol = "F") root.Ag_engine.children with
  | Some expression -> expression
  | None ->
      fail "calculus question has no F child";
      root

let rec has_standalone_constant_leaf (node : Ag_engine.node) =
  let is_constant_leaf =
    node.symbol = "T"
    &&
    match node.applied_rule with
    | Some rule -> (
        match rule.Ag_ast.rhs with
        | [ Ag_ast.Generator ("nonzero_integer_between", _) ] -> true
        | _ -> false)
    | None -> false
  in
  is_constant_leaf || List.exists has_standalone_constant_leaf node.children

let finite value =
  match classify_float value with
  | FP_nan | FP_infinite -> false
  | FP_normal | FP_subnormal | FP_zero -> true

let check_numeric_derivative seed original derivative =
  let step = 0.000001 in
  List.iter
    (fun point ->
      let upper = Ag_formula.evaluate ~variable:"x" ~at:(point +. step) original in
      let lower = Ag_formula.evaluate ~variable:"x" ~at:(point -. step) original in
      let numerical = (upper -. lower) /. (2. *. step) in
      let symbolic = Ag_formula.evaluate ~variable:"x" ~at:point derivative in
      if finite numerical && finite symbolic then
        let tolerance = 0.002 *. max 1.0 (abs_float symbolic) in
        if abs_float (numerical -. symbolic) > tolerance then
          fail
            (Printf.sprintf
               "seed %d at x=%g: finite difference %g disagrees with symbolic derivative %g (%s -> %s)"
               seed point numerical symbolic (Ag_formula.to_pg original)
               (Ag_formula.to_pg derivative)))
    [ -0.05; 0.0; 0.05 ]

let rec record_constructors seen = function
  | Ag_formula.Constant _ -> Hashtbl.replace seen "constant" true
  | Ag_formula.Variable _ -> Hashtbl.replace seen "variable" true
  | Ag_formula.Add (left, right) ->
      Hashtbl.replace seen "add" true;
      record_constructors seen left;
      record_constructors seen right
  | Ag_formula.Subtract (left, right) ->
      Hashtbl.replace seen "subtract" true;
      record_constructors seen left;
      record_constructors seen right
  | Ag_formula.Multiply (left, right) ->
      Hashtbl.replace seen "multiply" true;
      record_constructors seen left;
      record_constructors seen right
  | Ag_formula.Divide (left, right) ->
      Hashtbl.replace seen "divide" true;
      record_constructors seen left;
      record_constructors seen right
  | Ag_formula.Power (base, _) ->
      Hashtbl.replace seen "power" true;
      record_constructors seen base
  | Ag_formula.Negate body ->
      Hashtbl.replace seen "negate" true;
      record_constructors seen body
  | Ag_formula.Sin body ->
      Hashtbl.replace seen "sin" true;
      record_constructors seen body
  | Ag_formula.Cos body ->
      Hashtbl.replace seen "cos" true;
      record_constructors seen body
  | Ag_formula.Tan body ->
      Hashtbl.replace seen "tan" true;
      record_constructors seen body
  | Ag_formula.Exp body ->
      Hashtbl.replace seen "exp" true;
      record_constructors seen body
  | Ag_formula.Ln body ->
      Hashtbl.replace seen "ln" true;
      record_constructors seen body
  | Ag_formula.Sqrt body ->
      Hashtbl.replace seen "sqrt" true;
      record_constructors seen body

let check_formula_core () =
  let x = Ag_formula.variable "x" in
  let derivative expression = Ag_formula.differentiate ~variable:"x" expression in
  let check label expected actual =
    if expected <> Ag_formula.to_pg actual then
      fail
        (Printf.sprintf "%s rendered as %S, expected %S" label
           (Ag_formula.to_pg actual) expected)
  in
  check "d(x^3)" "3*x^2" (derivative (Ag_formula.power x 3));
  check "d(sin(x))" "cos(x)" (derivative (Ag_formula.sin x));
  check "d(cos(x))" "-sin(x)" (derivative (Ag_formula.cos x));
  check "d(exp(x))" "exp(x)" (derivative (Ag_formula.exp x));
  check "product rule" "cos(x)*exp(x)+sin(x)*exp(x)"
    (derivative (Ag_formula.multiply (Ag_formula.sin x) (Ag_formula.exp x)));
  let negative_three = Ag_formula.constant (Ag_number.of_int (-3)) in
  let normalized = Ag_formula.add x (Ag_formula.multiply negative_three x) in
  check "negative-term normalization" "x-3*x" normalized;
  let constant_power =
    Ag_formula.power (Ag_formula.constant (Ag_number.of_int (-8))) 5
  in
  check "negative constant power remains symbolic" "(-8)^5" constant_power;
  if not (Ag_formula.is_zero (derivative constant_power)) then
    fail "the derivative of a symbolic constant power was not zero";
  if contains (Ag_formula.to_latex normalized) "+ -" then
    fail "formula LaTeX retained an ambiguous '+ -' sequence"

let check_mode spec mode expected_kind =
  let spec = with_initial spec "calculus_mode" mode in
  for seed = 0 to 79 do
    Random.init (10_000 + (mode * 1_000) + seed);
    let question = Ag_engine.generate spec in
    let actual = text_attribute question.Ag_engine.tree "kind" in
    if actual <> expected_kind then
      fail
        (Printf.sprintf "calculus_mode=%d generated %s instead of %s" mode actual
           expected_kind)
  done

(* ------------------------------------------------------------------ *)
(* The cost budget is spent exactly and prices what the student sees    *)
(* ------------------------------------------------------------------ *)

(* calculus.ag prices F by the differentiation rule each construct asks for:
   sum or difference 1, product 3, a power or sin/cos/exp of a leaf 1, of a
   compound 3 plus the compound; a leaf c*x costs 1 and x or a constant 0.
   An integral question pays 2 before F is built. The formula is re-priced
   here from the finished Ag_formula tree, independently of the derivation:
   the only way the two can agree at every budget is if each printed
   expression has exactly one price. Negate is a rendering of a negative
   coefficient and costs nothing. *)
let rec is_leaf = function
  | Ag_formula.Variable _ | Ag_formula.Constant _ -> true
  | Ag_formula.Negate body -> is_leaf body
  | Ag_formula.Multiply (Ag_formula.Constant _, Ag_formula.Variable _) -> true
  | _ -> false

let rec price = function
  | Ag_formula.Variable _ | Ag_formula.Constant _ -> 0
  | Ag_formula.Negate body -> price body
  | Ag_formula.Multiply (Ag_formula.Constant _, Ag_formula.Variable _) -> 1
  | Ag_formula.Add (left, right) | Ag_formula.Subtract (left, right) ->
      1 + price left + price right
  | Ag_formula.Multiply (left, right) -> 3 + price left + price right
  | Ag_formula.Divide (left, right) -> 4 + price left + price right
  | Ag_formula.Power (body, _) | Ag_formula.Sin body | Ag_formula.Cos body
  | Ag_formula.Exp body | Ag_formula.Ln body | Ag_formula.Sqrt body | Ag_formula.Tan body ->
      (if is_leaf body then 1 else 3) + price body

(* ln, sqrt, tan and quotients belong to derivative questions only. *)
let rec uses_advanced = function
  | Ag_formula.Divide _ | Ag_formula.Ln _ | Ag_formula.Sqrt _ | Ag_formula.Tan _ -> true
  | Ag_formula.Constant _ | Ag_formula.Variable _ -> false
  | Ag_formula.Add (l, r) | Ag_formula.Subtract (l, r) | Ag_formula.Multiply (l, r) ->
      uses_advanced l || uses_advanced r
  | Ag_formula.Power (b, _) | Ag_formula.Negate b | Ag_formula.Sin b | Ag_formula.Cos b
  | Ag_formula.Exp b ->
      uses_advanced b

let check_cost_budget base =
  let kinds_seen = Hashtbl.create 2 in
  for cost = 0 to 14 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 29 do
      Random.init (seed + (cost * 1000));
      match Ag_engine.generate spec with
      | exception Ag_engine.Generation_error message ->
          fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
      | question ->
          let root = question.Ag_engine.tree in
          let spent = Ag_engine.consumption root "cost" in
          if spent <> cost then
            fail (Printf.sprintf "cost %d: the tree spent %d" cost spent);
          let kind = text_attribute root "kind" in
          Hashtbl.replace kinds_seen kind true;
          let premium = if kind = "integral" then 2 else 0 in
          let original = formula_attribute (expression_child root) "formula" in
          let priced = premium + price original in
          if priced <> cost then
            fail
              (Printf.sprintf "cost %d: %s %s re-prices as %d" cost kind
                 (Ag_formula.to_pg original) priced);
          if kind = "integral" && cost < 3 then
            fail (Printf.sprintf "cost %d produced an integral question" cost);
          if kind = "integral" && uses_advanced original then
            fail (Printf.sprintf "cost %d: integral built from %s" cost (Ag_formula.to_pg original))
    done
  done;
  List.iter
    (fun kind ->
      if not (Hashtbl.mem kinds_seen kind) then
        fail ("the cost sweep never generated a " ^ kind ^ " question"))
    [ "derivative"; "integral" ]

let () =
  check_formula_core ();
  let spec = load_file "calculus.ag" in
  check_cost_budget spec;
  if spec.Ag_check.context <> "Numeric" then
    fail ("calculus.ag selected context " ^ spec.Ag_check.context);
  check_mode spec 1 "derivative";
  check_mode spec 2 "integral";

  let kinds = Hashtbl.create 2 in
  let constructors = Hashtbl.create 10 in
  for seed = 0 to 499 do
    Random.init seed;
    let question = Ag_engine.generate spec in
    let root = question.Ag_engine.tree in
    let expression_node = expression_child root in
    let original = formula_attribute expression_node "formula" in
    let derivative = formula_attribute root "derivative" in
    let answer = formula_answer question in
    let kind = text_attribute root "kind" in
    Hashtbl.replace kinds kind true;
    record_constructors constructors original;
    if Ag_formula.is_zero derivative then
      fail (Printf.sprintf "seed %d generated a constant calculus question" seed);
    if Ag_engine.consumption root "cost" <> 7 then
      fail (Printf.sprintf "seed %d did not spend exactly the default cost of 7" seed);
    if contains question.prompt "+ -" || contains question.prompt "- -" then
      fail (Printf.sprintf "seed %d has ambiguous signs in %S" seed question.prompt);
    check_numeric_derivative seed original derivative;
    (match kind with
    | "derivative" ->
        if not (Ag_formula.equal answer derivative) then
          fail (Printf.sprintf "seed %d derivative answer differs from Q.derivative" seed)
    | "integral" ->
        if not (Ag_formula.equal answer original) then
          fail (Printf.sprintf "seed %d integral answer differs from generated F" seed);
        if has_standalone_constant_leaf expression_node then
          fail (Printf.sprintf "seed %d integral retained an unrelated constant leaf" seed);
        let recomputed = Ag_formula.differentiate ~variable:"x" answer in
        if not (Ag_formula.equal recomputed derivative) then
          fail (Printf.sprintf "seed %d integral integrand is not dF/dx" seed)
    | other -> fail ("unknown calculus question kind " ^ other))
  done;
  List.iter
    (fun kind ->
      if not (Hashtbl.mem kinds kind) then fail ("mixed mode never generated " ^ kind))
    [ "derivative"; "integral" ];
  List.iter
    (fun constructor ->
      if not (Hashtbl.mem constructors constructor) then
        fail ("generated formulas never used " ^ constructor))
    [ "add"; "subtract"; "multiply"; "power"; "sin"; "cos"; "exp"; "ln"; "sqrt"; "tan"; "divide" ];

  Random.init 9103;
  let first = Ag_engine.generate spec in
  Random.init 9103;
  let second = Ag_engine.generate spec in
  if first.prompt <> second.prompt || first.answer_text <> second.answer_text then
    fail "the same seed did not reproduce the same calculus question";

  Random.init 72;
  let document = Ag_pgml.of_spec ~count:40 spec in
  List.iter
    (fun expected ->
      if not (contains document expected) then
        fail (Printf.sprintf "calculus PGML is missing %S" expected))
    [ "Context(\"Numeric\");";
      "Formula('";
      "Differentiate the function";
      "Find an antiderivative";
      "\\int" ];

  if !failures = 0 then print_endline "Ag calculus tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG calculus test(s) failed." !failures);
    exit 1
  end
