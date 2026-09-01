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

let load filename =
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter
        (fun error -> fail (Ag_load.string_of_failure error))
        errors;
      exit 1

let check_file filename seed =
  let spec = load filename in
  Random.init seed;
  let questions = List.init 3 (fun _ -> Ag_engine.generate spec) in
  let text = Ag_visualization.ast_text questions in
  List.iter
    (fun expected ->
      if not (contains text expected) then
        fail (Printf.sprintf "%s AST text is missing %S" filename expected))
    [ "Attribute Grammar Generated Derivations";
      "Question 1";
      "Expected answer:";
      "production:";
      "inherited:";
      "synthesized:" ];
  let html =
    Ag_visualization.html_document ~d3_source:"/* test d3 */" ~grammar:filename
      questions
  in
  List.iter
    (fun expected ->
      if not (contains html expected) then
        fail (Printf.sprintf "%s HTML is missing %S" filename expected))
    [ "Attribute Grammar Explorer";
      "Applied Production Tree";
      "Attributed Derivation Tree";
      "Question values";
      "/* test d3 */" ]

let () =
  check_file "arithmetic.ag" 10;
  check_file "boolean.ag" 20;
  check_file "boolean_equiv.ag" 30;
  check_file "sequence.ag" 40;
  check_file "complex.ag" 50;
  check_file "calculus.ag" 60;
  check_file "set.ag" 60;
  check_file "vector.ag" 60;
  let escaped = Ag_visualization.json_escape "</script>" in
  if contains escaped "<" || contains escaped ">" then
    fail "JSON embedded in HTML did not escape a script-closing tag";
  if !failures = 0 then print_endline "Ag visualization tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG visualization test(s) failed." !failures);
    exit 1
  end
