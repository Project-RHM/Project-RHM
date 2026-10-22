(* Independent semantic and generation checks for set.ag. *)

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

let set_value context = function
  | Ag_engine.Set set -> set
  | other ->
      fail (context ^ " expected Set, got " ^ Ag_engine.describe_value other);
      Ag_set.empty

let global_set question name =
  match List.assoc_opt name question.Ag_engine.globals with
  | Some value -> set_value name value
  | None ->
      fail ("missing question-level set " ^ name);
      Ag_set.empty

let expression_child root =
  match List.find_opt (fun (node : Ag_engine.node) -> node.symbol = "E") root.Ag_engine.children with
  | Some expression -> expression
  | None ->
      fail "set question has no E child";
      root

let operator_of node =
  match node.Ag_engine.applied_rule with
  | Some rule -> (
      match rule.Ag_ast.rhs with
      | [ Ag_ast.Symbol "E"; Ag_ast.Literal operator; Ag_ast.Symbol "E" ] -> operator
      | _ -> "")
  | None -> ""

let rec reconstruct globals operators (node : Ag_engine.node) =
  match (node.symbol, node.children) with
  | "E", [ left; _operator; right ] ->
      let operator = operator_of node in
      Hashtbl.replace operators operator
        (1 + Option.value ~default:0 (Hashtbl.find_opt operators operator));
      let left = reconstruct globals operators left in
      let right = reconstruct globals operators right in
      (match operator with
      | "\\cup" -> Ag_set.union left right
      | "\\cap" -> Ag_set.intersection left right
      | "\\setminus" -> Ag_set.difference left right
      | other ->
          fail ("unknown set operator " ^ other);
          Ag_set.empty)
  | "E", [ child ] -> reconstruct globals operators child
  | "S", [ literal ] -> (
      match List.assoc_opt ("set_" ^ String.lowercase_ascii literal.symbol) globals with
      | Some value -> set_value literal.symbol value
      | None ->
          fail ("unknown set leaf " ^ literal.symbol);
          Ag_set.empty)
  | _ ->
      fail ("unexpected set expression node " ^ node.symbol);
      Ag_set.empty

let rec independent_contains value = function
  | Ag_set.Finite elements -> List.exists (Ag_number.equal value) elements
  | Ag_set.Interval (lower, upper, left_endpoint, right_endpoint) ->
      let lower_comparison = Ag_number.compare value lower in
      let upper_comparison = Ag_number.compare value upper in
      let lower_ok =
        match left_endpoint with
        | Ag_set.Open -> lower_comparison > 0
        | Ag_set.Closed -> lower_comparison >= 0
      in
      let upper_ok =
        match right_endpoint with
        | Ag_set.Open -> upper_comparison < 0
        | Ag_set.Closed -> upper_comparison <= 0
      in
      lower_ok && upper_ok
  | Ag_set.Union (left, right) ->
      independent_contains value left || independent_contains value right
  | Ag_set.Intersection (left, right) ->
      independent_contains value left && independent_contains value right
  | Ag_set.Difference (left, right) ->
      independent_contains value left && not (independent_contains value right)

let check_semantics seed expected actual =
  for numerator = -24 to 30 do
    let point = Ag_number.make numerator 2 in
    if independent_contains point expected <> independent_contains point actual then
      fail
        (Printf.sprintf "seed %d: set answer differs at %s" seed
           (Ag_number.to_string point))
  done

let check_global_definition seed name set =
  match set with
  | Ag_set.Finite elements ->
      let canonical = List.sort_uniq Ag_number.compare elements in
      if canonical <> elements then
        fail (Printf.sprintf "seed %d: %s is not canonical" seed name)
  | Ag_set.Interval (lower, upper, _, _) ->
      if Ag_number.compare lower upper >= 0 then
        fail (Printf.sprintf "seed %d: %s has an invalid interval" seed name)
  | _ -> fail (Printf.sprintf "seed %d: %s definition is not atomic" seed name)

let generated_operators root =
  let found = Hashtbl.create 3 in
  let rec visit (node : Ag_engine.node) =
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
    let question = Ag_engine.generate spec in
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

(* set.ag prices a union at 1, an intersection or difference at 2, and a
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
  let prompt = question.Ag_engine.prompt in
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
      match global_set question name with Ag_set.Interval _ -> 1 | _ -> 0
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
        match Ag_engine.generate spec with
        | exception Ag_engine.Generation_error message ->
            fail (Printf.sprintf "set_mode %d cost %d seed %d: %s" mode cost seed message)
        | question ->
            let spent = Ag_engine.consumption question.Ag_engine.tree "cost" in
            if spent <> cost then
              fail (Printf.sprintf "set_mode %d cost %d: the tree spent %d" mode cost spent);
            let priced = price_of_question question in
            if priced <> cost then
              fail
                (Printf.sprintf "set_mode %d cost %d: %S re-prices as %d" mode cost
                   question.Ag_engine.prompt priced)
      done
    done
  done

let () =
  let spec = load_file "set.ag" in
  if spec.Ag_check.context <> "Interval" then
    fail ("set.ag selected context " ^ spec.context);
  let all_operators = Hashtbl.create 3 in
  let saw_finite = ref false and saw_interval = ref false in
  for seed = 0 to 499 do
    Random.init seed;
    let question = Ag_engine.generate spec in
    let root = question.Ag_engine.tree in
    let sets =
      List.map
        (fun name ->
          let set = global_set question name in
          check_global_definition seed name set;
          (match set with
          | Ag_set.Finite _ -> saw_finite := true
          | Ag_set.Interval _ -> saw_interval := true
          | _ -> ());
          if not (contains question.prompt (Ag_set.to_latex set)) then
            fail (Printf.sprintf "seed %d: prompt omits %s" seed name);
          set)
        [ "set_a"; "set_b"; "set_c" ]
    in
    (match sets with
    | [ first; second; third ] ->
        if Ag_set.equal first second || Ag_set.equal first third || Ag_set.equal second third
        then fail (Printf.sprintf "seed %d: set definitions are duplicated" seed)
    | _ -> ());
    let operators = Hashtbl.create 3 in
    let expected = reconstruct question.globals operators (expression_child root) in
    Hashtbl.iter (fun operator _ -> Hashtbl.replace all_operators operator true) operators;
    let actual = set_value "answer" question.answer in
    check_semantics seed expected actual;
    if Ag_engine.consumption root "cost" <> 7 then
      fail (Printf.sprintf "seed %d: did not spend exactly the default cost of 7" seed)
  done;
  if not !saw_finite then fail "set.ag never generated a finite definition";
  if not !saw_interval then fail "set.ag never generated an interval definition";
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
  let first = Ag_engine.generate spec in
  Random.init 8104;
  let second = Ag_engine.generate spec in
  if first.prompt <> second.prompt || first.answer_text <> second.answer_text then
    fail "the same seed did not reproduce the same set question";

  Random.init 31;
  let document = Ag_pgml.of_spec ~count:40 spec in
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
