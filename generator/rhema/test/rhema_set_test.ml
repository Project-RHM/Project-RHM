(* Independent semantic and generation checks for set.rhm. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let contains text fragment =
  let text_length = String.length text and fragment_length = String.length fragment in
  let rec search index =
    index + fragment_length <= text_length
    && (String.sub text index fragment_length = fragment || search (index + 1))
  in
  fragment_length = 0 || search 0

let load_file filename =
  match Rhema_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Rhema_load.string_of_failure error)) errors;
      exit 1

let with_initial spec name value =
  match Rhema_check.with_initial spec name value with
  | Ok changed -> changed
  | Error message ->
      fail message;
      spec

let set_value context = function
  | Rhema_engine.Set set -> set
  | other ->
      fail (context ^ " expected Set, got " ^ Rhema_engine.describe_value other);
      Rhema_set.empty

let global_set question name =
  match List.assoc_opt name question.Rhema_engine.globals with
  | Some value -> set_value name value
  | None ->
      fail ("missing question-level set " ^ name);
      Rhema_set.empty

let expression_child root =
  match List.find_opt (fun (node : Rhema_engine.node) -> node.symbol = "E") root.Rhema_engine.children with
  | Some expression -> expression
  | None ->
      fail "set question has no E child";
      root

let operator_of node =
  match node.Rhema_engine.applied_rule with
  | Some rule -> (
      match rule.Rhema_ast.rhs with
      | [ Rhema_ast.Symbol "E"; Rhema_ast.Literal operator; Rhema_ast.Symbol "E" ] -> operator
      | _ -> "")
  | None -> ""

let rec reconstruct globals operators (node : Rhema_engine.node) =
  match (node.symbol, node.children) with
  | "E", [ left; _operator; right ] ->
      let operator = operator_of node in
      Hashtbl.replace operators operator
        (1 + Option.value ~default:0 (Hashtbl.find_opt operators operator));
      let left = reconstruct globals operators left in
      let right = reconstruct globals operators right in
      (match operator with
      | "\\cup" -> Rhema_set.union left right
      | "\\cap" -> Rhema_set.intersection left right
      | "\\setminus" -> Rhema_set.difference left right
      | other ->
          fail ("unknown set operator " ^ other);
          Rhema_set.empty)
  | "E", [ child ] -> reconstruct globals operators child
  | "S", [ literal ] -> (
      match List.assoc_opt ("set_" ^ String.lowercase_ascii literal.symbol) globals with
      | Some value -> set_value literal.symbol value
      | None ->
          fail ("unknown set leaf " ^ literal.symbol);
          Rhema_set.empty)
  | _ ->
      fail ("unexpected set expression node " ^ node.symbol);
      Rhema_set.empty

let rec independent_contains value = function
  | Rhema_set.Finite elements -> List.exists (Rhema_number.equal value) elements
  | Rhema_set.Interval (lower, upper, left_endpoint, right_endpoint) ->
      let lower_comparison = Rhema_number.compare value lower in
      let upper_comparison = Rhema_number.compare value upper in
      let lower_ok =
        match left_endpoint with
        | Rhema_set.Open -> lower_comparison > 0
        | Rhema_set.Closed -> lower_comparison >= 0
      in
      let upper_ok =
        match right_endpoint with
        | Rhema_set.Open -> upper_comparison < 0
        | Rhema_set.Closed -> upper_comparison <= 0
      in
      lower_ok && upper_ok
  | Rhema_set.Union (left, right) ->
      independent_contains value left || independent_contains value right
  | Rhema_set.Intersection (left, right) ->
      independent_contains value left && independent_contains value right
  | Rhema_set.Difference (left, right) ->
      independent_contains value left && not (independent_contains value right)

let check_semantics seed expected actual =
  for numerator = -24 to 30 do
    let point = Rhema_number.make numerator 2 in
    if independent_contains point expected <> independent_contains point actual then
      fail
        (Printf.sprintf "seed %d: set answer differs at %s" seed
           (Rhema_number.to_string point))
  done

let check_global_definition seed name set =
  match set with
  | Rhema_set.Finite elements ->
      let canonical = List.sort_uniq Rhema_number.compare elements in
      if canonical <> elements then
        fail (Printf.sprintf "seed %d: %s is not canonical" seed name)
  | Rhema_set.Interval (lower, upper, _, _) ->
      if Rhema_number.compare lower upper >= 0 then
        fail (Printf.sprintf "seed %d: %s has an invalid interval" seed name)
  | _ -> fail (Printf.sprintf "seed %d: %s definition is not atomic" seed name)

let generated_operators root =
  let found = Hashtbl.create 3 in
  let rec visit (node : Rhema_engine.node) =
    let operator = operator_of node in
    if operator <> "" then Hashtbl.replace found operator true;
    List.iter visit node.children
  in
  visit root;
  found

let check_mode base mode expected =
  let spec = with_initial base "set_mode" mode in
  for seed = 0 to 79 do
    Random.init (10_000 + (mode * 100) + seed);
    let question = Rhema_engine.generate spec in
    let operators = generated_operators question.tree in
    Hashtbl.iter
      (fun operator _ ->
        if operator <> expected then
          fail
            (Printf.sprintf "set_mode=%d generated %s instead of %s" mode operator
               expected))
      operators
  done

(* ------------------------------------------------------------------ *)
(* The cost budget, in every mode                                      *)
(* ------------------------------------------------------------------ *)

(* set.rhm prices a union at 1, an intersection or difference at 2, and a
   leaf at 1 when its set is an interval, 0 when it is finite. The printed
   expression is re-priced here: operators by their symbol, leaves by the
   kind of the set the question defines under that letter. Every budget must
   be spendable in every set_mode, because a node holding a budget no rule
   fits is an error, not a retry. *)
let count_occurrences text fragment =
  let text_length = String.length text and fragment_length = String.length fragment in
  let rec count index found =
    if index + fragment_length > text_length then found
    else if String.sub text index fragment_length = fragment then
      count (index + fragment_length) (found + 1)
    else count (index + 1) found
  in
  count 0 0

let price_of_question question =
  let prompt = question.Rhema_engine.prompt in
  let expression =
    (* the last [`...`] of the prompt is the expression; the definitions
       come first *)
    match String.rindex_opt prompt '`' with
    | Some last -> (
        match String.rindex_from_opt prompt (last - 1) '`' with
        | Some first -> String.sub prompt (first + 1) (last - first - 1)
        | None -> "")
    | None -> ""
  in
  let leaf_price name letter =
    let kind =
      match global_set question name with Rhema_set.Interval _ -> 1 | _ -> 0
    in
    kind * count_occurrences expression letter
  in
  count_occurrences expression "\\cup"
  + (2 * count_occurrences expression "\\cap")
  + (2 * count_occurrences expression "\\setminus")
  + leaf_price "set_a" "A" + leaf_price "set_b" "B" + leaf_price "set_c" "C"

let check_cost_budget base =
  for mode = 0 to 3 do
    let spec = with_initial base "set_mode" mode in
    for cost = 0 to 12 do
      let spec = with_initial spec "cost" cost in
      for seed = 0 to 19 do
        Random.init (seed + (cost * 100) + (mode * 10_000));
        match Rhema_engine.generate spec with
        | exception Rhema_engine.Generation_error message ->
            fail (Printf.sprintf "set_mode %d cost %d seed %d: %s" mode cost seed message)
        | question ->
            let spent = Rhema_engine.consumption question.Rhema_engine.tree "cost" in
            if spent <> cost then
              fail (Printf.sprintf "set_mode %d cost %d: the tree spent %d" mode cost spent);
            let priced = price_of_question question in
            if priced <> cost then
              fail
                (Printf.sprintf "set_mode %d cost %d: %S re-prices as %d" mode cost
                   question.Rhema_engine.prompt priced)
      done
    done
  done

let () =
  let spec = load_file "set.rhm" in
  if spec.Rhema_check.context <> "Interval" then
    fail ("set.rhm selected context " ^ spec.context);
  let all_operators = Hashtbl.create 3 in
  let saw_finite = ref false and saw_interval = ref false in
  for seed = 0 to 499 do
    Random.init seed;
    let question = Rhema_engine.generate spec in
    let root = question.Rhema_engine.tree in
    let sets =
      List.map
        (fun name ->
          let set = global_set question name in
          check_global_definition seed name set;
          (match set with
          | Rhema_set.Finite _ -> saw_finite := true
          | Rhema_set.Interval _ -> saw_interval := true
          | _ -> ());
          if not (contains question.prompt (Rhema_set.to_latex set)) then
            fail (Printf.sprintf "seed %d: prompt omits %s" seed name);
          set)
        [ "set_a"; "set_b"; "set_c" ]
    in
    (match sets with
    | [ first; second; third ] ->
        if Rhema_set.equal first second || Rhema_set.equal first third || Rhema_set.equal second third
        then fail (Printf.sprintf "seed %d: set definitions are duplicated" seed)
    | _ -> ());
    let operators = Hashtbl.create 3 in
    let expected = reconstruct question.globals operators (expression_child root) in
    Hashtbl.iter (fun operator _ -> Hashtbl.replace all_operators operator true) operators;
    let actual = set_value "answer" question.answer in
    check_semantics seed expected actual;
    if Rhema_engine.consumption root "cost" <> 7 then
      fail (Printf.sprintf "seed %d: did not spend exactly the default cost of 7" seed)
  done;
  if not !saw_finite then fail "set.rhm never generated a finite definition";
  if not !saw_interval then fail "set.rhm never generated an interval definition";
  List.iter
    (fun operator ->
      if not (Hashtbl.mem all_operators operator) then
        fail ("mixed set generation never used " ^ operator))
    [ "\\cup"; "\\cap"; "\\setminus" ];

  check_mode spec 1 "\\cup";
  check_mode spec 2 "\\cap";
  check_mode spec 3 "\\setminus";
  check_cost_budget spec;

  Random.init 8104;
  let first = Rhema_engine.generate spec in
  Random.init 8104;
  let second = Rhema_engine.generate spec in
  if first.prompt <> second.prompt || first.answer_text <> second.answer_text then
    fail "the same seed did not reproduce the same set question";

  Random.init 31;
  let document = Rhema_pgml.of_spec ~count:40 spec in
  if not (contains document "Context(\"Interval\");") then
    fail "set PGML did not select Context(\"Interval\")";
  if not (contains document "Compute(\"") then
    fail "set PGML did not contain a Compute answer";
  if not (contains document "(-infinity, infinity)") then
    fail "set PGML did not encode intersection against the universe";

  if !failures = 0 then print_endline "Ag set tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG set test(s) failed." !failures);
    exit 1
  end
