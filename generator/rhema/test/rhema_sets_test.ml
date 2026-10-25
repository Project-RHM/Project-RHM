(* Checks for `set NAME { ... }`: the entries are generated with the budgets
   they ask for, drawn the three ways, the constraints hold, the result is
   numbered and reproducible, and the mistakes a set can contain are each
   reported. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let contains text fragment =
  let rec search index =
    index + String.length fragment <= String.length text
    && (String.sub text index (String.length fragment) = fragment || search (index + 1))
  in
  search 0

let load_file name =
  match Rhema_load.parse_file name with
  | Ok spec -> Some spec
  | Error errors ->
      List.iter (fun error -> fail (name ^ ": " ^ Rhema_load.string_of_failure error)) errors;
      None

let expect_error name source ~mentions =
  match Rhema_load.parse_string ~filename:name source with
  | Ok _ -> fail (Printf.sprintf "%s was accepted although %s" name mentions)
  | Error errors ->
      if not (List.exists (fun error -> contains (Rhema_load.string_of_failure error) mentions) errors)
      then
        fail
          (Printf.sprintf "%s: no error mentions %S; got: %s" name mentions
             (errors |> List.map Rhema_load.string_of_failure |> String.concat " | "))

let set_named (spec : Rhema_check.spec) name =
  List.find (fun (set : Rhema_ast.set_decl) -> set.Rhema_ast.set_name = name) spec.Rhema_check.sets

let run spec name seed =
  match Rhema_sets.run spec (set_named spec name) ~variant:seed with
  | result -> Some result
  | exception Rhema_engine.Generation_error message ->
      fail (Printf.sprintf "set %s seed %d: %s" name seed message);
      None

let budget (drawn : Rhema_sets.drawn) attribute =
  match List.assoc_opt attribute drawn.Rhema_sets.budgets with
  | Some value -> value
  | None -> fail ("no budget " ^ attribute); -1

let answers (result : Rhema_sets.result) =
  Rhema_sets.questions result |> List.map (fun (q : Rhema_engine.question) -> q.Rhema_engine.answer_text)

(* ------------------------------------------------------------------ *)
(* 1. The shipped set file                                              *)
(* ------------------------------------------------------------------ *)

let () =
  match load_file "homework_set.rhm" with
  | None -> ()
  | Some spec ->
      if not spec.Rhema_check.library then fail "a file of sets alone should count as having no question";
      if List.map (fun (set : Rhema_ast.set_decl) -> set.Rhema_ast.set_name) spec.Rhema_check.sets <> [ "homework"; "quick" ]
      then fail "homework_set.rhm should declare homework and quick";
      for seed = 1 to 6 do
        match run spec "homework" seed with
        | None -> ()
        | Some result -> (
            let parts = result.Rhema_sets.parts in
            if List.length parts <> 3 then fail (Printf.sprintf "seed %d: %d parts" seed (List.length parts));
            (match parts with
            | [ (Some "Differentiation", first); (Some "Propositional logic", second); (Some "Mixed", third) ] ->
                if List.length first <> 4 || List.length second <> 5 || List.length third <> 2 then
                  fail (Printf.sprintf "seed %d: part sizes %d %d %d" seed (List.length first)
                          (List.length second) (List.length third));
                (* cost ~ 6 spread 2 low 2 over three derivatives: sum exactly 18, none below 2 *)
                let derivatives = List.filter (fun d -> d.Rhema_sets.kind = "calc.derivative") first in
                let costs = List.map (fun d -> budget d "cost") derivatives in
                if List.length costs <> 3 then fail (Printf.sprintf "seed %d: %d derivatives" seed (List.length costs));
                if List.fold_left ( + ) 0 costs <> 18 then
                  fail (Printf.sprintf "seed %d: derivative budgets %s do not average 6" seed
                          (String.concat "," (List.map string_of_int costs)));
                if List.exists (fun c -> c < 2) costs then fail (Printf.sprintf "seed %d: a budget below low" seed);
                (* cost in {5, 7} *)
                List.iter
                  (fun d -> if not (List.mem (budget d "cost") [ 5; 7 ]) then fail (Printf.sprintf "seed %d: integral budget %d" seed (budget d "cost")))
                  (List.filter (fun d -> d.Rhema_sets.kind = "calc.integral") first);
                (* cost in {8, 10, 12} over three questions: each once *)
                let bools = List.filter (fun d -> d.Rhema_sets.kind = "bool.main") second in
                let drawn = List.sort compare (List.map (fun d -> budget d "cost") bools) in
                if drawn <> [ 8; 10; 12 ] then
                  fail (Printf.sprintf "seed %d: bool budgets %s" seed (String.concat "," (List.map string_of_int drawn)));
                List.iter
                  (fun d -> if budget d "cost" <> 6 then fail (Printf.sprintf "seed %d: a law at %d" seed (budget d "cost")))
                  (List.filter (fun d -> d.Rhema_sets.kind = "laws.main") second);
                (* any(...) over two slots: one of each *)
                let kinds = List.sort compare (List.map (fun d -> d.Rhema_sets.kind) third) in
                if kinds <> [ "calc.derivative"; "forms.main" ] then
                  fail (Printf.sprintf "seed %d: mixed kinds %s" seed (String.concat "," kinds));
                (* labels *)
                if List.map (fun d -> d.Rhema_sets.label) first <> [ "1(a)"; "1(b)"; "1(c)"; "1(d)" ] then
                  fail (Printf.sprintf "seed %d: labels %s" seed (String.concat " " (List.map (fun d -> d.Rhema_sets.label) first)));
                (* ordered: within a part, budgets do not decrease *)
                List.iter
                  (fun members ->
                    let totals = List.map (fun d -> List.fold_left (fun s (_, v) -> s + v) 0 d.Rhema_sets.budgets) members in
                    if List.sort compare totals <> totals then
                      fail (Printf.sprintf "seed %d: a part is not ordered: %s" seed (String.concat "," (List.map string_of_int totals))))
                  [ first; second; third ]
            | _ -> fail (Printf.sprintf "seed %d: unexpected parts" seed));
            (* distinct: no two shapes alike *)
            let shapes = Rhema_sets.questions result |> List.map (fun (q : Rhema_engine.question) -> Rhema_sets.skeleton q.Rhema_engine.tree) in
            if List.length (List.sort_uniq compare shapes) <> List.length shapes then
              fail (Printf.sprintf "seed %d: two questions share a shape" seed);
            (* balanced: no three equal coded answers in a row *)
            let coded = Rhema_sets.questions result |> List.filter_map Rhema_sets.coded_answer in
            let rec triple = function
              | a :: (b :: c :: _ as rest) -> (a = b && b = c) || triple rest
              | _ -> false
            in
            if triple coded then fail (Printf.sprintf "seed %d: three equal answers in a row: %s" seed (String.concat "" coded));
            (* reproducible *)
            match run spec "homework" seed with
            | Some again -> if answers again <> answers result then fail (Printf.sprintf "seed %d: not reproducible" seed)
            | None -> ())
      done;
      (* different seeds, different sets *)
      (match (run spec "homework" 1, run spec "homework" 2) with
      | Some a, Some b -> if answers a = answers b then fail "seeds 1 and 2 gave the same set"
      | _ -> ());
      (* the flat set: four numbers, no letters *)
      (match run spec "quick" 3 with
      | Some result ->
          let labels = result.Rhema_sets.parts |> List.concat_map snd |> List.map (fun d -> d.Rhema_sets.label) in
          if labels <> [ "1"; "2"; "3"; "4" ] then fail ("quick labels: " ^ String.concat " " labels);
          let kinds = result.Rhema_sets.parts |> List.concat_map snd |> List.map (fun d -> d.Rhema_sets.kind) in
          if List.length (List.filter (( = ) "bool.main") kinds) <> 2 then fail "quick should draw two of each kind"
      | None -> ());
      (* the documents *)
      match run spec "homework" 5 with
      | None -> ()
      | Some result ->
          let document = Rhema_sets.document result in
          List.iter
            (fun fragment -> if not (contains document fragment) then fail ("the PG document lacks " ^ fragment))
            [ "Differentiation"; "1(a). "; "2(e). "; "Propositional logic"; "BEGIN_PGML"; "ENDDOCUMENT();" ];
          let listing = Rhema_sets.listing result in
          List.iter
            (fun fragment -> if not (contains listing fragment) then fail ("the listing lacks " ^ fragment))
            [ "homework: 11 questions in 3 parts"; "1. Differentiation"; "budget means:"; "part 1 Differentiation: cost"; "over 4" ];
          let files = Rhema_sets.documents result in
          if List.length files <> 11 then fail (Printf.sprintf "%d per-question documents" (List.length files));
          if fst (List.hd files) <> "question01.pg" then fail ("first file " ^ fst (List.hd files))

(* ------------------------------------------------------------------ *)
(* 2. A set over the file's own questions                               *)
(* ------------------------------------------------------------------ *)

let () =
  let source =
    {|attribute len = 3 split
synth value
synth latex
start E
E -> E "+" E when len >= 1 { len = -1  value = $1.value + $3.value  latex = $1.latex ++ " + " ++ $3.latex }
E -> N when len = 0 { value = $1.value  latex = $1.latex }
N -> integer(1) { value = $1.value  latex = str($1.value) }
prompt "Compute [`{E.latex}`]."
answer E.value
question single { start N  prompt "Copy [`{N.latex}`]."  answer N.value }
set drill {
  part "Sums"
    3 of main(len in {1, 2, 3})
  part "Copies"
    2 of single
}
|}
  in
  match Rhema_load.parse_string ~filename:"own_set.rhm" source with
  | Error errors -> List.iter (fun error -> fail ("own set: " ^ Rhema_load.string_of_failure error)) errors
  | Ok spec -> (
      if spec.Rhema_check.library then fail "a file with questions and a set is not a library";
      match run spec "drill" 11 with
      | None -> ()
      | Some result -> (
          match result.Rhema_sets.parts with
          | [ (Some "Sums", sums); (Some "Copies", copies) ] ->
              let lens = List.sort compare (List.map (fun d -> budget d "len") sums) in
              if lens <> [ 1; 2; 3 ] then fail "len in {1, 2, 3} should give each once";
              List.iter
                (fun d ->
                  let spent = Rhema_engine.consumption d.Rhema_sets.question.Rhema_engine.tree "len" in
                  if spent <> budget d "len" then fail (Printf.sprintf "a sum spent %d of %d" spent (budget d "len")))
                sums;
              if List.length copies <> 2 then fail "two copies expected";
              List.iter
                (fun d -> if not (contains d.Rhema_sets.question.Rhema_engine.prompt "Copy") then fail "single's prompt expected")
                copies
          | _ -> fail "own set: unexpected parts"))

(* `distinct` over two copies of a one-rule question cannot be satisfied,
   and the set says so instead of looping. *)
let () =
  let source =
    {|synth value
N -> integer(1) { value = $1.value }
question single { start N  prompt "[`{N.value}`]"  answer N.value }
set twins { 2 of single  distinct }
|}
  in
  match Rhema_load.parse_string ~filename:"twins.rhm" source with
  | Error errors -> List.iter (fun error -> fail ("twins: " ^ Rhema_load.string_of_failure error)) errors
  | Ok spec -> (
      match Rhema_sets.run spec (set_named spec "twins") ~variant:1 with
      | _ -> fail "two identical shapes were accepted as distinct"
      | exception Rhema_engine.Generation_error message ->
          if not (contains message "question 2 (single) could not satisfy the set's constraints") then
            fail ("unexpected message: " ^ message))

(* ------------------------------------------------------------------ *)
(* 3. Mistakes in a set                                                 *)
(* ------------------------------------------------------------------ *)

let () =
  let with_set body =
    {|import "boolean.rhm" as bool
attribute len = 1 copy
synth value
start N
N -> integer(1) { value = $1.value }
prompt "[`{N.value}`]"
answer N.value
|}
    ^ body ^ "\n"
  in
  expect_error "unknown_question.rhm" (with_set "set s { 2 of nothing }")
    ~mentions:"'nothing', which is not a question of this file";
  expect_error "unknown_alias.rhm" (with_set "set s { 2 of calc.main }")
    ~mentions:"'calc' is not an imported module";
  expect_error "unknown_module_question.rhm" (with_set "set s { 2 of bool.integral }")
    ~mentions:"module bool has no such question; it has main";
  expect_error "unknown_attribute.rhm" (with_set "set s { 2 of bool.main(depth = 3) }")
    ~mentions:"no such inherited attribute; it has cost";
  expect_error "twice_attribute.rhm" (with_set "set s { 2 of bool.main(cost = 3, cost = 4) }")
    ~mentions:"draws 'cost' twice";
  expect_error "zero_count.rhm" (with_set "set s { 0 of bool.main }")
    ~mentions:"the count must be positive";
  expect_error "negative_budget.rhm" (with_set "set s { 2 of bool.main(cost = -1) }")
    ~mentions:"cannot be negative";
  expect_error "empty_set.rhm" (with_set "set s { part \"A\" }")
    ~mentions:"asks for no questions";
  expect_error "duplicate_set.rhm" (with_set "set s { 1 of main }\nset s { 1 of main }")
    ~mentions:"set 's' is declared more than once";
  expect_error "twice_distinct.rhm" (with_set "set s { 1 of main distinct distinct }")
    ~mentions:"says 'distinct' more than once";
  expect_error "bad_word.rhm" (with_set "set s { parts \"A\" 1 of main }")
    ~mentions:"expected 'part' here, not 'parts'";
  expect_error "bad_of.rhm" (with_set "set s { 1 off main }")
    ~mentions:"expected 'of' here, not 'off'";
  expect_error "bad_in.rhm" (with_set "set s { 1 of bool.main(cost within {1, 2}) }")
    ~mentions:"expected 'in' here, not 'within'";
  expect_error "bad_option.rhm" (with_set "set s { 1 of bool.main(cost ~ 6 sprd 2) }")
    ~mentions:"expected one of 'spread', 'low', 'allowed' here, not 'sprd'"

(* A grammar may still name an attribute by one of the set words. *)
let () =
  match
    Rhema_load.parse_string ~filename:"low_attribute.rhm"
      "attribute low = 2 copy\nsynth value\nstart N\nN -> integer(low) { value = $1.value }\nprompt \"[`{N.value}`]\"\nanswer N.value\nset part { 1 of main(low = 1) }\n"
  with
  | Ok spec -> if List.length spec.Rhema_check.sets <> 1 then fail "the set named part was lost"
  | Error errors -> List.iter (fun error -> fail ("low attribute: " ^ Rhema_load.string_of_failure error)) errors

let () =
  if !failures = 0 then print_endline "Ag set tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG set test(s) failed." !failures);
    exit 1
  end
