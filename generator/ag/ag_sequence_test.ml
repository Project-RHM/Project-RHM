(* Independent checks for the sequence specification. The expected answer is
   recomputed here from the generated parameters rather than trusted from the
   equations in sequence.ag. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let contains haystack needle =
  let haystack_length = String.length haystack in
  let needle_length = String.length needle in
  let rec search index =
    if index + needle_length > haystack_length then false
    else if String.sub haystack index needle_length = needle then true
    else search (index + 1)
  in
  search 0

let load_file filename =
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
      exit 1

let number_of_value label = function
  | Ag_engine.Num number -> (
      try Ag_number.require_integer label number
      with Ag_number.Arithmetic_error message ->
        fail message;
        0)
  | value ->
      fail (Printf.sprintf "%s was not numeric: %s" label (Ag_engine.describe_value value));
      0

let number_attribute tree name =
  number_of_value name (Ag_engine.attribute tree name)

let text_attribute tree name =
  match Ag_engine.attribute tree name with
  | Ag_engine.Text text -> text
  | value ->
      fail (Printf.sprintf "%s was not text: %s" name (Ag_engine.describe_value value));
      ""

let rec integer_power base exponent =
  if exponent = 0 then 1 else base * integer_power base (exponent - 1)

let expected_answer kind first step index =
  match kind with
  | "arithmetic_nth" -> first + ((index - 1) * step)
  | "geometric_nth" -> first * integer_power step (index - 1)
  | "arithmetic_sum" -> index * ((2 * first) + ((index - 1) * step)) / 2
  | "geometric_sum" ->
      if step = 1 then first * index
      else first * (integer_power step index - 1) / (step - 1)
  | other ->
      fail ("unknown generated sequence kind: " ^ other);
      0

(* sequence.ag offers each fixed form at its price alone. *)
let price_of_kind = function
  | "arithmetic_nth" -> 1
  | "geometric_nth" | "arithmetic_sum" -> 2
  | "geometric_sum" -> 3
  | other -> invalid_arg ("unknown sequence kind " ^ other)

(* Every check on one generated question, at whatever budget it was built. *)
let check_question kinds saw_negative_first saw_positive_first seed question =
    let tree = question.Ag_engine.tree in
    let kind = text_attribute tree "kind" in
    let first = number_attribute tree "first_value" in
    let step = number_attribute tree "step_value" in
    let index = number_attribute tree "index_value" in
    let actual = number_of_value "answer" question.Ag_engine.answer in
    let expected = expected_answer kind first step index in
    Hashtbl.replace kinds kind true;
    if first < 0 then saw_negative_first := true;
    if first > 0 then saw_positive_first := true;
    if first < -10 || first > 10 then
      fail (Printf.sprintf "seed %d: first term %d is outside [-10,10]" seed first);
    if step = 0 then fail (Printf.sprintf "seed %d: step/ratio is zero" seed);
    if index < 2 || index > 8 then
      fail (Printf.sprintf "seed %d: index %d is outside [2,8]" seed index);
    if actual <> expected then
      fail
        (Printf.sprintf
           "seed %d: %s(first=%d, step=%d, index=%d) expected %d but got %d"
           seed kind first step index expected actual);
    List.iter
      (fun value ->
        if not (contains question.Ag_engine.prompt (string_of_int value)) then
          fail
            (Printf.sprintf "seed %d: prompt omitted generated value %d: %s" seed
               value question.Ag_engine.prompt))
      [ first; step; index ]

let () =
  let spec = load_file "sequence.ag" in
  let kinds = Hashtbl.create 4 in
  let saw_negative_first = ref false in
  let saw_positive_first = ref false in
  for seed = 0 to 499 do
    Random.init seed;
    match Ag_engine.generate spec with
    | exception Ag_engine.Generation_error message ->
        fail (Printf.sprintf "seed %d: generation failed: %s" seed message)
    | question ->
        check_question kinds saw_negative_first saw_positive_first seed question;
        if Ag_engine.consumption question.Ag_engine.tree "cost" <> 2 then
          fail (Printf.sprintf "seed %d: did not spend exactly the default cost of 2" seed)
  done;
  (* Every form is fixed and offered at its price alone, so the kinds are
     collected over the budgets 1 to 3. *)
  for cost = 1 to 3 do
    match Ag_check.with_initial spec "cost" cost with
    | Error message -> fail message
    | Ok spec ->
        for seed = 0 to 99 do
          Random.init (seed + (cost * 1000));
          match Ag_engine.generate spec with
          | exception Ag_engine.Generation_error message ->
              fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
          | question ->
              check_question kinds saw_negative_first saw_positive_first seed question;
              let kind = text_attribute question.Ag_engine.tree "kind" in
              if price_of_kind kind <> cost then
                fail (Printf.sprintf "cost %d produced a %s question" cost kind);
              if Ag_engine.consumption question.Ag_engine.tree "cost" <> cost then
                fail (Printf.sprintf "cost %d: the tree spent something else" cost)
        done
  done;
  List.iter
    (fun kind ->
      if not (Hashtbl.mem kinds kind) then fail ("no question generated for " ^ kind))
    [ "arithmetic_nth"; "geometric_nth"; "arithmetic_sum"; "geometric_sum" ];
  if not !saw_negative_first then fail "integer_between never generated a negative first term";
  if not !saw_positive_first then fail "integer_between never generated a positive first term"

let () =
  let spec = load_file "sequence.ag" in
  Random.init 20260831;
  let first = Ag_engine.generate spec in
  Random.init 20260831;
  let second = Ag_engine.generate spec in
  if first.Ag_engine.prompt <> second.Ag_engine.prompt
     || first.Ag_engine.answer_text <> second.Ag_engine.answer_text
  then fail "the same seed did not reproduce the same sequence question"

let invalid_range_source =
  "random x = integer_between(5, -5)\n\
   synth value on Q\n\
   start Q\n\
   Q -> \"range\" { value = x }\n\
   prompt \"{Q.value}\"\n\
   answer Q.value\n"

let invalid_nonzero_source =
  "random x = nonzero_integer_between(0, 0)\n\
   synth value on Q\n\
   start Q\n\
   Q -> \"range\" { value = x }\n\
   prompt \"{Q.value}\"\n\
   answer Q.value\n"

let range_leaf_source =
  "synth first on Q\n\
   synth second on Q\n\
   synth text on Q\n\
   synth value on Q\n\
   start Q\n\
   Q -> integer_between(-2, 2) nonzero_integer_between(-1, 1) {\n\
     first = $1.value\n\
     second = $2.value\n\
     text = str($1.value)\n\
     value = $1.value + $2.value\n\
   }\n\
   prompt \"{Q.text}\"\n\
   answer Q.value\n"

let () =
  match Ag_load.parse_string ~filename:"invalid_range.ag" invalid_range_source with
  | Ok _ -> fail "a reversed integer_between range passed static checking"
  | Error errors ->
      let reports = List.map Ag_load.string_of_failure errors |> String.concat " | " in
      if not (contains reports "lower bound 5 is greater than upper bound -5") then
        fail ("the reversed range error was unclear: " ^ reports)

let () =
  match Ag_load.parse_string ~filename:"invalid_nonzero.ag" invalid_nonzero_source with
  | Ok _ -> fail "nonzero_integer_between(0, 0) passed static checking"
  | Error errors ->
      let reports = List.map Ag_load.string_of_failure errors |> String.concat " | " in
      if not (contains reports "has no non-zero value") then
        fail ("the empty non-zero range error was unclear: " ^ reports)

let () =
  let spec =
    match Ag_load.parse_string ~filename:"range_leaf.ag" range_leaf_source with
    | Ok spec -> spec
    | Error errors ->
        List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
        exit 1
  in
  for seed = 0 to 99 do
    Random.init seed;
    let tree = (Ag_engine.generate spec).Ag_engine.tree in
    let first = number_attribute tree "first" in
    let second = number_attribute tree "second" in
    if first < -2 || first > 2 then
      fail (Printf.sprintf "RHS integer_between generated %d" first);
    if second <> -1 && second <> 1 then
      fail (Printf.sprintf "RHS nonzero_integer_between generated %d" second)
  done

let () =
  if !failures = 0 then print_endline "Ag sequence tests passed."
  else (
    prerr_endline (Printf.sprintf "%d check(s) failed." !failures);
    exit 1)
