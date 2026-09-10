(* ag_boolean_test.ml — Boolean evaluation questions.

   Boolean questions were the first migration after arithmetic, and they were
   chosen because they stress parts of the design arithmetic never touches:

     - a truth assignment belongs to the whole question, not to a leaf, so it
       cannot be an inherited budget (those only ever decrease, and are ints);
     - the question text has to contain generated content (the assignment)
       rather than a single expression;
     - the answer is a truth value, not a number.

   These questions go into homework, so besides being right they have to look
   set by hand. The second half of this file checks that: the shapes a person
   would have simplified away never appear, the brackets are the ones a course
   writes, the sizes and wordings vary, and neither answer dominates. Every
   check re-reads the question the way a student would, through
   Ag_boolean_reader, rather than trusting the grammar's attributes. *)

open Ag_boolean_reader

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
  | Ok spec -> spec
  | Error message ->
      fail message;
      spec

(* Generate with a fixed seed; a generation failure is a test failure. *)
let generate spec seed =
  Random.init seed;
  match Ag_engine.generate spec with
  | question -> Some question
  | exception Ag_engine.Generation_error message ->
      fail (Printf.sprintf "seed %d: generation failed: %s" seed message);
      None

let for_seeds spec seeds check =
  for seed = 0 to seeds - 1 do
    match generate spec seed with Some question -> check seed question | None -> ()
  done

(* The assignment and the one expression, straight out of the prompt. *)
let read_prompt prompt =
  let blocks = math_blocks prompt in
  let assignment = assignment_of_blocks blocks in
  match expression_blocks blocks with
  | [ text ] -> (assignment, text)
  | [] -> raise (Reread_error "no expression in the prompt")
  | many -> raise (Reread_error (Printf.sprintf "%d expressions in one prompt" (List.length many)))

let stated_truth seed question =
  match question.Ag_engine.answer with
  | Ag_engine.Truth truth -> truth
  | other ->
      fail
        (Printf.sprintf "seed %d: answer was not true/false: %s" seed
           (Ag_engine.describe_value other));
      false

let opening prompt =
  match String.index_opt prompt ' ' with
  | Some space -> String.sub prompt 0 space
  | None -> prompt

(* ------------------------------------------------------------------ *)
(* 1. The answer agrees with the question as the student sees it       *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.ag" in
  for_seeds spec 300 (fun seed question ->
      let prompt = question.Ag_engine.prompt in
      match read_prompt prompt with
      | exception Reread_error message ->
          fail (Printf.sprintf "seed %d: could not read the prompt: %s" seed message)
      | assignment, text -> (
          if List.length assignment <> 3 then
            fail
              (Printf.sprintf "seed %d: expected an assignment for three variables, found %d"
                 seed (List.length assignment));
          match evaluate assignment (parse text) with
          | exception Reread_error message ->
              fail (Printf.sprintf "seed %d: could not re-read %S: %s" seed text message)
          | recomputed ->
              let stated = stated_truth seed question in
              if recomputed <> stated then
                fail
                  (Printf.sprintf "seed %d: %S under that assignment is %b, but the answer says %b"
                     seed text recomputed stated)))

(* ------------------------------------------------------------------ *)
(* 2. The same variable means the same thing throughout one question   *)
(* ------------------------------------------------------------------ *)

(* This is the property a leaf-level draw could not provide, and the reason
   `random` exists. Evaluating with the shown assignment must succeed for
   every variable that appears, which means no variable escaped it. Test 1
   implies it, but checking it directly says so plainly. *)
let () =
  let spec = load_file "boolean.ag" in
  for_seeds spec 100 (fun seed question ->
      match read_prompt question.Ag_engine.prompt with
      | exception Reread_error message -> fail (Printf.sprintf "seed %d: %s" seed message)
      | assignment, text -> (
          match evaluate assignment (parse text) with
          | exception Reread_error message -> fail (Printf.sprintf "seed %d: %s" seed message)
          | _ -> ()))

(* ------------------------------------------------------------------ *)
(* 3. The budget still means what it says                              *)
(* ------------------------------------------------------------------ *)

(* `len` is the most connectives a question may have; the size chooser
   trims it by one or two, and never below one connective when there is a
   budget to spend. *)
let allowed_sizes len =
  if len >= 3 then [ len - 2; len - 1; len ]
  else if len = 2 then [ 1; 2 ]
  else [ len ]

let () =
  let base = load_file "boolean.ag" in
  for len = 0 to 6 do
    let spec = with_initial base "len" len in
    for_seeds spec 40 (fun seed question ->
        let _, text = read_prompt question.Ag_engine.prompt in
        let found = size (parse text) in
        if not (List.mem found (allowed_sizes len)) then
          fail (Printf.sprintf "len %d seed %d: %S has %d connectives" len seed text found))
  done;
  (* With the default budget every one of the three sizes has to show up. *)
  let seen = Hashtbl.create 4 in
  for_seeds base 300 (fun _ question ->
      let _, text = read_prompt question.Ag_engine.prompt in
      Hashtbl.replace seen (size (parse text)) ());
  List.iter
    (fun expected ->
      if not (Hashtbl.mem seen expected) then
        fail (Printf.sprintf "no question with %d connectives in 300 seeds" expected))
    [ 2; 3; 4 ]

(* ------------------------------------------------------------------ *)
(* 4. The rarer connectives are rationed                               *)
(* ------------------------------------------------------------------ *)

let () =
  let base = load_file "boolean.ag" in
  for_seeds base 300 (fun seed question ->
      let _, text = read_prompt question.Ag_engine.prompt in
      let found = extras (parse text) in
      if found > 1 then
        fail (Printf.sprintf "seed %d: %S has %d of \\to/\\leftrightarrow/\\oplus" seed text found));
  for_seeds (with_initial base "extras" 0) 100 (fun seed question ->
      let _, text = read_prompt question.Ag_engine.prompt in
      if extras (parse text) > 0 then
        fail (Printf.sprintf "extras 0 seed %d: %S still has one" seed text));
  let doubled = ref false in
  for_seeds (with_initial base "extras" 2) 200 (fun _ question ->
      let _, text = read_prompt question.Ag_engine.prompt in
      if extras (parse text) = 2 then doubled := true);
  if not !doubled then fail "extras 2 never produced a question with two of them"

(* ------------------------------------------------------------------ *)
(* 5. Nothing a person would have simplified away                      *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.ag" in
  for_seeds spec 500 (fun seed question ->
      let assignment, text = read_prompt question.Ag_engine.prompt in
      let expression = parse text in
      List.iter
        (fun smell -> fail (Printf.sprintf "seed %d: %s" seed smell))
        (smells expression);
      if stacked_negations expression > 0 then
        fail (Printf.sprintf "seed %d: stacked negation in %S" seed text);
      (* The brackets are exactly the ones the grammar promises: re-rendering
         the parsed expression gives the text back unchanged. *)
      let again = render expression in
      if again <> text then
        fail (Printf.sprintf "seed %d: %S re-renders as %S" seed text again);
      (* All-true or all-false assignments let a student skip the expression. *)
      match List.sort_uniq compare (List.map snd assignment) with
      | [ _ ] -> fail (Printf.sprintf "seed %d: every variable has the same value" seed)
      | _ -> ())

(* ------------------------------------------------------------------ *)
(* 6. Neither answer dominates                                         *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.ag" in
  let total = 1000 and trues = ref 0 in
  for_seeds spec total (fun seed question ->
      if stated_truth seed question then incr trues);
  let share = float_of_int !trues /. float_of_int total in
  if share < 0.4 || share > 0.6 then
    fail
      (Printf.sprintf "%.0f%% of questions answer true; the two answers should be close to even"
         (share *. 100.))

(* ------------------------------------------------------------------ *)
(* 7. The wording varies                                               *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.ag" in
  let seen = Hashtbl.create 4 in
  for_seeds spec 100 (fun _ question ->
      Hashtbl.replace seen (opening question.Ag_engine.prompt) ());
  List.iter
    (fun expected ->
      if not (Hashtbl.mem seen expected) then
        fail (Printf.sprintf "no question opening with %S in 100 seeds" expected))
    [ "Suppose"; "Let"; "Evaluate" ]

(* ------------------------------------------------------------------ *)
(* 8. A truth value reaches the .pg file as 1 or 0                     *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.ag" in
  Random.init 2;
  let document = Ag_pgml.of_spec ~count:6 spec in
  let marker = "[_____]" in
  let blanks =
    document |> String.split_on_char '\n'
    |> List.filter_map (fun line ->
           let rec find index =
             if index + String.length marker > String.length line then None
             else if String.sub line index (String.length marker) = marker then
               Some
                 (String.sub line
                    (index + String.length marker)
                    (String.length line - index - String.length marker))
             else find (index + 1)
           in
           find 0)
  in
  List.iter
    (fun blank ->
      if blank <> "{1}" && blank <> "{0}" then
        fail (Printf.sprintf "a boolean answer was written as %s, not {1} or {0}" blank))
    blanks;
  if blanks = [] then fail "no answer blanks were produced"

let () =
  if !failures = 0 then print_endline "Ag boolean tests passed."
  else (
    prerr_endline (Printf.sprintf "%d check(s) failed." !failures);
    exit 1)
