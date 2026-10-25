(* Checks for `question NAME { ... }` blocks: a file holds several named
   question types over one set of rules, the file-level declarations are the
   question `main`, a block may start its budgets elsewhere, and the mistakes
   a block can contain are each reported. *)

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

let load name source =
  match Rhema_load.parse_string ~filename:name source with
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

let names (spec : Rhema_check.spec) =
  List.map (fun (question : Rhema_check.question) -> question.Rhema_check.q_name) spec.Rhema_check.questions

let initial (spec : Rhema_check.spec) name =
  match List.find_opt (fun (a : Rhema_check.inherited_attribute) -> a.Rhema_check.attribute_name = name) spec.Rhema_check.inherited with
  | Some attribute -> attribute.Rhema_check.initial
  | None -> fail ("no attribute " ^ name); -1

let generate spec seed =
  Random.init seed;
  match Rhema_engine.generate spec with
  | question -> Some question
  | exception Rhema_engine.Generation_error message ->
      fail (Printf.sprintf "seed %d: %s" seed message);
      None

(* A small arithmetic grammar with three questions over one rule set. *)
let source =
  {|attribute len = 3 split
synth value
synth latex
start E
context "Numeric"
width 12

E -> E "+" E when len >= 1 { len = -1  value = $1.value + $3.value  latex = $1.latex ++ " + " ++ $3.latex }
E -> N when len = 0 { value = $1.value  latex = $1.latex }
N -> integer(1) { value = $1.value  latex = str($1.value) }

prompt "Compute [`{E.latex}`]."
answer E.value

question terms {
  start E
  prompt "How many terms does [`{E.latex}`] have?"
  answer E.value
  len = 1
}

question single {
  start N
  context "Complex"
  width 4
  prompt "Write [`{N.latex}`] again."
  answer N.value
}
|}

(* ------------------------------------------------------------------ *)
(* 1. The questions of a file, and which one the engine reads             *)
(* ------------------------------------------------------------------ *)

let () =
  match load "three_questions.rhm" source with
  | None -> ()
  | Some spec ->
      if names spec <> [ "main"; "terms"; "single" ] then
        fail ("questions: " ^ String.concat ", " (names spec));
      if spec.Rhema_check.library then fail "a file with questions was taken for a library";
      (* main is selected: file-level start, prompt, width, declared budget *)
      if spec.Rhema_check.start <> "E" then fail "main should start at E";
      if spec.Rhema_check.width <> Some 12 then fail "main should have the file-level width";
      if initial spec "len" <> 3 then fail "main should start len at its declared 3";
      (match generate spec 1 with
      | Some question ->
          if not (contains question.Rhema_engine.prompt "Compute") then
            fail ("main's prompt was not used: " ^ question.Rhema_engine.prompt)
      | None -> ());
      (* a block may start a budget elsewhere; what it leaves alone it inherits *)
      (match Rhema_check.select_question spec "terms" with
      | Error message -> fail message
      | Ok terms ->
          if initial terms "len" <> 1 then fail "terms should start len at 1";
          if terms.Rhema_check.context <> "Numeric" then fail "terms should take the file-level context";
          if terms.Rhema_check.width <> Some 12 then fail "terms should take the file-level width";
          for seed = 0 to 9 do
            match generate terms seed with
            | Some question ->
                if Rhema_engine.consumption question.Rhema_engine.tree "len" <> 1 then
                  fail (Printf.sprintf "terms seed %d: len 1 was not spent" seed);
                if not (contains question.Rhema_engine.prompt "How many terms") then
                  fail ("terms' prompt was not used: " ^ question.Rhema_engine.prompt)
            | None -> ()
          done);
      (* a block may start at another nonterminal and set its own context *)
      (match Rhema_check.select_question spec "single" with
      | Error message -> fail message
      | Ok single ->
          if single.Rhema_check.start <> "N" then fail "single should start at N";
          if single.Rhema_check.context <> "Complex" then fail "single should have its own context";
          if single.Rhema_check.width <> Some 4 then fail "single should have its own width";
          if initial single "len" <> 3 then fail "single should keep the declared len";
          (match generate single 2 with
          | Some question ->
              if question.Rhema_engine.context <> "Complex" then fail "the generated question lost its context";
              if not (contains question.Rhema_engine.prompt "again") then fail "single's prompt was not used"
          | None -> ());
          (* --set applies after the selection *)
          match Rhema_check.with_initial single "len" 2 with
          | Ok overridden -> if initial overridden "len" <> 2 then fail "--set after selection did not apply"
          | Error message -> fail message);
      (* and back again *)
      (match Rhema_check.select_question spec "main" with
      | Ok main -> if initial main "len" <> 3 || main.Rhema_check.start <> "E" then fail "main could not be reselected"
      | Error message -> fail message);
      match Rhema_check.select_question spec "nothing" with
      | Ok _ -> fail "an unknown question was selected"
      | Error message ->
          if not (contains message "it has main, terms, single") then fail ("unexpected message: " ^ message)

(* ------------------------------------------------------------------ *)
(* 2. A file of blocks only: the first is selected; none is a library     *)
(* ------------------------------------------------------------------ *)

let () =
  let blocks_only =
    {|synth value
N -> integer(1) { value = $1.value }
question one { start N  prompt "[`{N.value}`]"  answer N.value }
question two { start N  prompt "Again: [`{N.value}`]"  answer N.value }
|}
  in
  (match load "blocks_only.rhm" blocks_only with
  | None -> ()
  | Some spec ->
      if names spec <> [ "one"; "two" ] then fail ("blocks only: " ^ String.concat ", " (names spec));
      if spec.Rhema_check.library then fail "a file of question blocks was taken for a library";
      if spec.Rhema_check.start <> "N" || spec.Rhema_check.prompt = [] then
        fail "the first block should be selected when there is no main";
      match generate spec 0 with
      | Some question -> if contains question.Rhema_engine.prompt "Again" then fail "the second block was selected"
      | None -> ());
  match load "still_library.rhm" "synth value\nN -> integer(1) { value = $1.value }\n" with
  | Some spec -> if not spec.Rhema_check.library then fail "a file without questions should be a library"
  | None -> ()

(* ------------------------------------------------------------------ *)
(* 3. Mistakes inside a block                                           *)
(* ------------------------------------------------------------------ *)

let () =
  let with_block block =
    {|attribute len = 2 split
synth value
synth latex
start E
E -> N { value = $1.value  latex = $1.latex }
N -> integer(1) { value = $1.value  latex = str($1.value) }
prompt "[`{E.latex}`]"
answer E.value
|}
    ^ block ^ "\n"
  in
  expect_error "no_start.rhm" (with_block {|question q { prompt "x" answer E.value }|})
    ~mentions:"question 'q' needs a 'start SYMBOL' line";
  expect_error "no_prompt.rhm" (with_block {|question q { start E answer E.value }|})
    ~mentions:"question 'q' needs a 'prompt";
  expect_error "no_answer.rhm" (with_block {|question q { start E prompt "x" }|})
    ~mentions:"question 'q' needs an 'answer";
  expect_error "bad_start.rhm" (with_block {|question q { start Z prompt "x" answer Z.value }|})
    ~mentions:"start symbol 'Z' has no rules";
  expect_error "wrong_owner.rhm" (with_block {|question q { start N prompt "[`{E.latex}`]" answer N.value }|})
    ~mentions:"a prompt can only use the start symbol 'N'";
  expect_error "twice_prompt.rhm" (with_block {|question q { start E prompt "x" prompt "y" answer E.value }|})
    ~mentions:"question 'q' declares 'prompt' more than once";
  expect_error "bad_default.rhm" (with_block {|question q { start E prompt "x" answer E.value depth = 2 }|})
    ~mentions:"question 'q' sets 'depth', which is not an inherited attribute";
  expect_error "negative_default.rhm" (with_block {|question q { start E prompt "x" answer E.value len = -1 }|})
    ~mentions:"question 'q' starts 'len' at -1";
  expect_error "twice_default.rhm" (with_block {|question q { start E prompt "x" answer E.value len = 1 len = 2 }|})
    ~mentions:"question 'q' sets 'len' more than once";
  expect_error "bad_context.rhm" (with_block {|question q { start E context "No/Such" prompt "x" answer E.value }|})
    ~mentions:"context must be a non-empty WeBWorK context name";
  expect_error "bad_width.rhm" (with_block {|question q { start E width 0 prompt "x" answer E.value }|})
    ~mentions:"width must be positive";
  expect_error "named_main.rhm" (with_block {|question main { start E prompt "x" answer E.value }|})
    ~mentions:"'main' is the file-level question";
  expect_error "duplicate.rhm"
    (with_block {|question q { start E prompt "x" answer E.value }
question q { start E prompt "y" answer E.value }|})
    ~mentions:"question 'q' is declared more than once"

(* ------------------------------------------------------------------ *)
(* 4. The shipped example: calculus.rhm                                   *)
(* ------------------------------------------------------------------ *)

let () =
  match Rhema_load.parse_file "calculus.rhm" with
  | Error errors -> List.iter (fun error -> fail ("calculus.rhm: " ^ Rhema_load.string_of_failure error)) errors
  | Ok spec ->
      if names spec <> [ "main"; "derivative"; "integral" ] then
        fail ("calculus.rhm questions: " ^ String.concat ", " (names spec));
      let kind_of (question : Rhema_engine.question) =
        match Rhema_engine.attribute question.Rhema_engine.tree "kind" with
        | Rhema_engine.Text kind -> kind
        | _ -> "?"
      in
      List.iter
        (fun (name, budget) ->
          match Rhema_check.select_question spec name with
          | Error message -> fail message
          | Ok selected ->
              if initial selected "cost" <> budget then
                fail (Printf.sprintf "%s should start cost at %d" name budget);
              for seed = 0 to 19 do
                match generate selected seed with
                | Some question ->
                    if kind_of question <> name then
                      fail (Printf.sprintf "%s seed %d asked a %s question" name seed (kind_of question));
                    if Rhema_engine.consumption question.Rhema_engine.tree "cost" <> budget then
                      fail (Printf.sprintf "%s seed %d did not spend %d" name seed budget)
                | None -> ()
              done)
        [ ("derivative", 7); ("integral", 7) ];
      (* an integral below 3 is refused as such, not silently another form *)
      match Rhema_check.select_question spec "integral" with
      | Error message -> fail message
      | Ok integral -> (
          match Rhema_check.with_initial integral "cost" 2 with
          | Error message -> fail message
          | Ok cheap -> (
              Random.init 0;
              match Rhema_engine.generate cheap with
              | _ -> fail "an integral of budget 2 was generated"
              | exception Rhema_engine.Generation_error message ->
                  if not (contains message "no rule for 'I' fits") then fail ("unexpected: " ^ message)))

let () =
  if !failures = 0 then print_endline "Ag question tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG question test(s) failed." !failures);
    exit 1
  end
