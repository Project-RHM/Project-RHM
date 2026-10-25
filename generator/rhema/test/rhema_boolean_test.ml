(* rhema_boolean_test.ml — Boolean evaluation questions.

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
   Rhema_boolean_reader, rather than trusting the grammar's attributes. *)

open Rhema_boolean_reader

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let load_file filename =
  match Rhema_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Rhema_load.string_of_failure error)) errors;
      exit 1

let with_initial spec name value =
  match Rhema_check.with_initial spec name value with
  | Ok spec -> spec
  | Error message ->
      fail message;
      spec

(* Generate with a fixed seed; a generation failure is a test failure. *)
let generate spec seed =
  Random.init seed;
  match Rhema_engine.generate spec with
  | question -> Some question
  | exception Rhema_engine.Generation_error message ->
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
  match question.Rhema_engine.answer with
  | Rhema_engine.Truth truth -> truth
  | other ->
      fail
        (Printf.sprintf "seed %d: answer was not true/false: %s" seed
           (Rhema_engine.describe_value other));
      false

let opening prompt =
  match String.index_opt prompt ' ' with
  | Some space -> String.sub prompt 0 space
  | None -> prompt

(* ------------------------------------------------------------------ *)
(* 1. The answer agrees with the question as the student sees it       *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.rhm" in
  for_seeds spec 300 (fun seed question ->
      let prompt = question.Rhema_engine.prompt in
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
  let spec = load_file "boolean.rhm" in
  for_seeds spec 100 (fun seed question ->
      match read_prompt question.Rhema_engine.prompt with
      | exception Reread_error message -> fail (Printf.sprintf "seed %d: %s" seed message)
      | assignment, text -> (
          match evaluate assignment (parse text) with
          | exception Reread_error message -> fail (Printf.sprintf "seed %d: %s" seed message)
          | _ -> ()))

(* ------------------------------------------------------------------ *)
(* 3. The budget is operator cost, spent exactly                        *)
(* ------------------------------------------------------------------ *)

(* boolean.rhm prices and/or 2, the conditional 4, the biconditional and
   xor 6, a negated variable 1 and a negated compound 3 plus the compound.
   The expression as the student sees it is re-priced here from the
   independent reader's tree, so the brackets decide what each negation
   applies to. A budget of 1 buys only a negated variable, which the
   grammar refuses as a whole proposition, so it has no question. *)
let rec price = function
  | Var _ -> 0
  | Not (Var _) -> 1
  | Not body -> 3 + price body
  | Bin (operator, left, right) ->
      (match operator with
       | "\\land" | "\\lor" -> 2
       | "\\to" -> 4
       | "\\leftrightarrow" | "\\oplus" -> 6
       | other -> fail ("no price for " ^ other); 0)
      + price left + price right

let () =
  let base = load_file "boolean.rhm" in
  List.iter
    (fun cost ->
      let spec = with_initial base "cost" cost in
      for_seeds spec 30 (fun seed question ->
          let spent = Rhema_engine.consumption question.Rhema_engine.tree "cost" in
          if spent <> cost then fail (Printf.sprintf "cost %d seed %d: the tree spent %d" cost seed spent);
          let _, text = read_prompt question.Rhema_engine.prompt in
          let priced = price (parse text) in
          if priced <> cost then
            fail (Printf.sprintf "cost %d seed %d: %S re-prices as %d" cost seed text priced)))
    (0 :: List.init 19 (fun i -> i + 2));
  (match Rhema_engine.generate (with_initial base "cost" 1) with
  | exception Rhema_engine.Generation_error _ -> ()
  | _ -> fail "a budget of 1 produced a question, which can only be a negated variable");
  (* Cost is not length: the default budget buys several sizes. *)
  let seen = Hashtbl.create 4 in
  for_seeds base 300 (fun _ question ->
      let _, text = read_prompt question.Rhema_engine.prompt in
      Hashtbl.replace seen (size (parse text)) ());
  if Hashtbl.length seen < 3 then
    fail (Printf.sprintf "the default budget produced only %d sizes in 300 seeds" (Hashtbl.length seen))

(* ------------------------------------------------------------------ *)
(* 4. The conditional family appears, and is priced                    *)
(* ------------------------------------------------------------------ *)

let () =
  let base = load_file "boolean.rhm" in
  let seen = ref 0 in
  for_seeds base 300 (fun _ question ->
      let _, text = read_prompt question.Rhema_engine.prompt in
      if extras (parse text) > 0 then incr seen);
  if !seen = 0 then fail "the default budget never produced a conditional, biconditional or xor";
  (* A budget of 3 cannot afford one. *)
  for_seeds (with_initial base "cost" 3) 60 (fun seed question ->
      let _, text = read_prompt question.Rhema_engine.prompt in
      if extras (parse text) > 0 then
        fail (Printf.sprintf "cost 3 seed %d: %S has a connective it cannot afford" seed text))

(* ------------------------------------------------------------------ *)
(* 5. Set the way the course sets them                                *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.rhm" in
  for_seeds spec 500 (fun seed question ->
      let assignment, text = read_prompt question.Rhema_engine.prompt in
      let expression = parse text in
      (* Nothing a person would have simplified away. *)
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
      (* Never a negation around the whole proposition, and at most two
         negations in it. *)
      (match expression with
      | Not (Bin _) -> fail (Printf.sprintf "seed %d: the whole proposition is negated: %S" seed text)
      | _ -> ());
      let negation_count =
        let rec count = function
          | Var _ -> 0
          | Not body -> 1 + count body
          | Bin (_, l, r) -> count l + count r
        in
        count expression
      in
      if negation_count > 2 then
        fail (Printf.sprintf "seed %d: %d negations in %S" seed negation_count text);
      (* Three leaves or more use all three variables. *)
      if size expression >= 2 && List.length (variable_set expression) < 3 then
        fail (Printf.sprintf "seed %d: %S does not use every variable" seed text);
      (* The assignment is chosen with intent: no single variable settles the
         answer, so at least two of them change it when flipped. *)
      let sensitive = sensitivity assignment expression in
      if sensitive < 2 then
        fail (Printf.sprintf "seed %d: only %d variable(s) matter in %S" seed sensitive text);
      (* All-true or all-false assignments let a student skip the expression. *)
      match List.sort_uniq compare (List.map snd assignment) with
      | [ _ ] -> fail (Printf.sprintf "seed %d: every variable has the same value" seed)
      | _ -> ())

(* ------------------------------------------------------------------ *)
(* 6. Neither answer dominates                                         *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.rhm" in
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
  let spec = load_file "boolean.rhm" in
  let seen = Hashtbl.create 4 in
  for_seeds spec 100 (fun _ question ->
      Hashtbl.replace seen (opening question.Rhema_engine.prompt) ());
  List.iter
    (fun expected ->
      if not (Hashtbl.mem seen expected) then
        fail (Printf.sprintf "no question opening with %S in 100 seeds" expected))
    [ "Suppose"; "Let"; "Evaluate" ]

(* ------------------------------------------------------------------ *)
(* 8. A truth value reaches the .pg file as 1 or 0                     *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.rhm" in
  Random.init 2;
  let document = Rhema_pgml.of_spec ~count:6 spec in
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
