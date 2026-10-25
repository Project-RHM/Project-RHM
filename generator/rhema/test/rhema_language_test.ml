(* Checks for the three language features: `include`, a context and width
   per question, and several answer blanks in one question. *)

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

let count text fragment =
  let rec go index found =
    if index + String.length fragment > String.length text then found
    else if String.sub text index (String.length fragment) = fragment then
      go (index + String.length fragment) (found + 1)
    else go (index + 1) found
  in
  go 0 0

let load filename =
  match Rhema_load.parse_file filename with
  | Ok spec -> Some spec
  | Error errors ->
      List.iter (fun error -> fail (filename ^ ": " ^ Rhema_load.string_of_failure error)) errors;
      None

let text_attribute node name =
  match Rhema_engine.attribute node name with
  | Rhema_engine.Text text -> text
  | other -> fail (name ^ " expected text, got " ^ Rhema_engine.describe_value other); ""

let number_global question name =
  match List.assoc_opt name question.Rhema_engine.globals with
  | Some (Rhema_engine.Num number) -> Rhema_number.to_float number
  | _ -> fail ("missing number " ^ name); 0.

let write filename content =
  let channel = open_out filename in
  output_string channel content;
  close_out channel

(* ------------------------------------------------------------------ *)
(* 1. A grammar built on a library, with a context per question         *)
(* ------------------------------------------------------------------ *)

let () =
  match load "polynomial_forms.rhm" with
  | None -> ()
  | Some spec ->
      if spec.Rhema_check.library then fail "polynomial_forms.rhm was taken for a library";
      if not spec.Rhema_check.per_question_context then
        fail "polynomial_forms.rhm should compute its context per question";
      let contexts = Hashtbl.create 2 in
      for seed = 0 to 59 do
        Random.init seed;
        match Rhema_engine.generate spec with
        | exception Rhema_engine.Generation_error message -> fail (Printf.sprintf "seed %d: %s" seed message)
        | question -> (
            Hashtbl.replace contexts question.Rhema_engine.context true;
            let kind = text_attribute question.Rhema_engine.tree "kind" in
            match (kind, question.Rhema_engine.context, question.Rhema_engine.answer) with
            | "expand", "Numeric", Rhema_engine.Polynomial _ -> ()
            | "factor", "PolynomialFactors", Rhema_engine.Formula _ -> ()
            | _ ->
                fail
                  (Printf.sprintf "seed %d: a %s question in context %s with answer %s" seed kind
                     question.Rhema_engine.context (Rhema_engine.describe_value question.Rhema_engine.answer)))
      done;
      List.iter
        (fun context -> if not (Hashtbl.mem contexts context) then fail ("no question used context " ^ context))
        [ "Numeric"; "PolynomialFactors" ];
      Random.init 3;
      let document = Rhema_pgml.of_spec ~count:12 spec in
      if not (contains document "contextPolynomialFactors.pl") then
        fail "the document does not load contextPolynomialFactors.pl";
      if not (contains document "Context(\"PolynomialFactors\");") then
        fail "the document never switches to PolynomialFactors";
      if not (contains document "Context(\"Numeric\");") then fail "the document never uses Numeric";
      if count document "BEGIN_PGML" <> count document "END_PGML" then fail "unbalanced PGML blocks";
      if count document "BEGIN_PGML" < 2 then fail "questions in two contexts share one PGML block";
      if count document "[_____]{" <> 12 then
        fail (Printf.sprintf "the document has %d blanks for 12 questions" (count document "[_____]{"))

(* ------------------------------------------------------------------ *)
(* 2. A library on its own, an including file that re-asks, a cycle     *)
(* ------------------------------------------------------------------ *)

let () =
  (match Rhema_load.parse_file "polynomial_core.rhm" with
  | Error errors ->
      List.iter (fun error -> fail ("library: " ^ Rhema_load.string_of_failure error)) errors
  | Ok spec ->
      if not spec.Rhema_check.library then fail "polynomial_core.rhm should be a library";
      (match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error message ->
          if not (contains message "library") then fail ("library generation failed oddly: " ^ message)
      | _ -> fail "a library generated a question"));
  let here = Sys.getcwd () in
  let override = Filename.concat here "override_test.rhm" in
  write override "include \"factoring.rhm\"\nprompt \"Try this one: [`{Q.text}`]\"\n";
  (match load override with
  | None -> ()
  | Some spec ->
      Random.init 1;
      let question = Rhema_engine.generate spec in
      if not (contains question.Rhema_engine.prompt "Try this one:") then
        fail "the including file's prompt did not win over the included one";
      (match question.Rhema_engine.answer with
      | Rhema_engine.Formula _ -> ()
      | other -> fail ("the included answer was lost: " ^ Rhema_engine.describe_value other)));
  Sys.remove override;
  let loop_a = Filename.concat here "loop_a_test.rhm" and loop_b = Filename.concat here "loop_b_test.rhm" in
  write loop_a "include \"loop_b_test.rhm\"\n";
  write loop_b "include \"loop_a_test.rhm\"\n";
  (match Rhema_load.parse_file loop_a with
  | Ok _ -> fail "a cycle of includes was accepted"
  | Error errors ->
      if not (List.exists (fun error -> contains (Rhema_load.string_of_failure error) "includes itself") errors)
      then fail "the include cycle was not named as such");
  Sys.remove loop_a;
  Sys.remove loop_b;
  let broken = Filename.concat here "broken_core_test.rhm" and user = Filename.concat here "uses_broken_test.rhm" in
  write broken "synth value\nE -> E \"+\" E { value = $1.value + $3.value }\n";
  write user "include \"broken_core_test.rhm\"\nstart E\nprompt \"[`{E.value}`]\"\nanswer E.value\n";
  (match Rhema_load.parse_file user with
  | Ok _ -> fail "a grammar on a broken library was accepted"
  | Error errors ->
      if not (List.exists (fun error -> contains error.Rhema_load.where "broken_core_test.rhm") errors) then
        fail "an error inside an included file was not reported with that file's name");
  Sys.remove broken;
  Sys.remove user

(* ------------------------------------------------------------------ *)
(* 3. Two answer blanks in one question                                 *)
(* ------------------------------------------------------------------ *)

let () =
  match load "sequence_parts.rhm" with
  | None -> ()
  | Some spec ->
      for seed = 0 to 99 do
        Random.init seed;
        match Rhema_engine.generate spec with
        | exception Rhema_engine.Generation_error message -> fail (Printf.sprintf "seed %d: %s" seed message)
        | question ->
            if List.length question.Rhema_engine.answers <> 2 then
              fail (Printf.sprintf "seed %d: %d answers" seed (List.length question.Rhema_engine.answers));
            if count question.Rhema_engine.prompt "[___]" <> 2 then
              fail (Printf.sprintf "seed %d: the prompt shows %d blanks" seed (count question.Rhema_engine.prompt "[___]"));
            let first = number_global question "first" and n = number_global question "index" in
            let expected_nth, expected_sum =
              match text_attribute question.Rhema_engine.tree "kind" with
              | "arithmetic" ->
                  let d = number_global question "difference" in
                  (first +. ((n -. 1.) *. d), n *. ((2. *. first) +. ((n -. 1.) *. d)) /. 2.)
              | "geometric" ->
                  let r = number_global question "ratio" in
                  ( first *. (r ** (n -. 1.)),
                    if r = 1. then first *. n else first *. ((r ** n) -. 1.) /. (r -. 1.) )
              | other -> fail ("unknown kind " ^ other); (0., 0.)
            in
            (match question.Rhema_engine.answers with
            | [ Rhema_engine.Num nth; Rhema_engine.Num sum ] ->
                if Float.abs (Rhema_number.to_float nth -. expected_nth) > 1e-9 then
                  fail (Printf.sprintf "seed %d: nth term %s, expected %g" seed (Rhema_number.to_string nth) expected_nth);
                if Float.abs (Rhema_number.to_float sum -. expected_sum) > 1e-9 then
                  fail (Printf.sprintf "seed %d: sum %s, expected %g" seed (Rhema_number.to_string sum) expected_sum)
            | _ -> fail (Printf.sprintf "seed %d: answers are not two numbers" seed))
      done;
      Random.init 7;
      let document = Rhema_pgml.of_spec ~count:5 spec in
      if count document "[_____]{" <> 10 then
        fail (Printf.sprintf "the document has %d blanks for 5 two-part questions" (count document "[_____]{"));
      if contains document "[___]" then fail "a blank placeholder leaked into the .pg file";
      (* a prompt that places its blanks may not also declare a trailing answer *)
      (match
         Rhema_load.parse_string
           "synth value\nstart E\nE -> integer_between(1, 3) { value = $1.value }\nprompt \"{answer E.value}\"\nanswer E.value\n"
       with
      | Ok _ -> fail "a prompt with {answer} and an answer declaration was accepted"
      | Error errors ->
          if not (List.exists (fun error -> contains error.Rhema_load.what "drop the 'answer'") errors) then
            fail "the conflicting answer declaration was not explained")

(* ------------------------------------------------------------------ *)
(* 4. Two whole grammars imported into one file                          *)
(* ------------------------------------------------------------------ *)

(* derivative_or_boolean.rhm hands its budget of 8 to calc.F as it is and to
   bool.E with two more, so the module's subtree spends 8 or 10. *)
let () =
  match load "derivative_or_boolean.rhm" with
  | None -> ()
  | Some spec ->
      if List.map fst spec.Rhema_check.imports <> [ "calc"; "bool" ] then
        fail "derivative_or_boolean.rhm should import calc and bool";
      let kinds = Hashtbl.create 2 in
      for seed = 0 to 79 do
        Random.init seed;
        match Rhema_engine.generate spec with
        | exception Rhema_engine.Generation_error message -> fail (Printf.sprintf "mixed seed %d: %s" seed message)
        | question -> (
            let kind = text_attribute question.Rhema_engine.tree "kind" in
            Hashtbl.replace kinds kind true;
            let expected = if kind = "boolean" then 10 else 8 in
            let spent = Rhema_engine.consumption question.Rhema_engine.tree "cost" in
            if spent <> expected then
              fail (Printf.sprintf "mixed seed %d: the %s module spent %d, not the %d it was handed" seed kind spent expected);
            if kind = "boolean" && not (List.mem_assoc "bool.given" question.Rhema_engine.globals) then
              fail (Printf.sprintf "mixed seed %d: the module's values are not kept under their qualified names" seed);
            match (kind, question.Rhema_engine.answer) with
            | "derivative", Rhema_engine.Formula _ -> ()
            | "boolean", Rhema_engine.Truth _ -> ()
            | _ ->
                fail (Printf.sprintf "mixed seed %d: %s question with answer %s" seed kind
                        (Rhema_engine.describe_value question.Rhema_engine.answer)))
      done;
      List.iter (fun kind -> if not (Hashtbl.mem kinds kind) then fail ("the mixed file never asked a " ^ kind ^ " question"))
        [ "derivative"; "boolean" ]

let () =
  if !failures = 0 then print_endline "Ag language tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG language test(s) failed." !failures);
    exit 1
  end
