(* ag_equiv_test.ml — Boolean equivalence questions.

   These questions state a claim about *every* assignment, so the grammar
   carries a truth table rather than a truth value, and `holds` is a hand
   written comparison of two tables. A hand written formula can be wrong: an
   early draft compared the two sides with a bitwise AND against 255 instead of
   comparing them for equality, and every De Morgan question came out labelled
   "not equivalent".

   Nothing here trusts that formula. Both sides are read back out of the
   question text the student sees, each is evaluated under all eight
   assignments independently, and the two tables are compared. The later
   checks hold the questions to the same hand-written standard as the
   evaluation questions: no redundant shapes, the promised brackets, both
   wordings, and an even split of answers. *)

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

(* The two sides: either two math blocks, or one block joined by \equiv. *)
let sides_of_prompt prompt =
  match expression_blocks (math_blocks prompt) with
  | [ left; right ] -> (String.trim left, String.trim right)
  | [ single ] -> (
      match split_on " \\equiv " single with
      | [ left; right ] -> (String.trim left, String.trim right)
      | _ -> raise (Reread_error ("no \\equiv between the sides of: " ^ single)))
  | blocks ->
      raise (Reread_error (Printf.sprintf "%d math blocks in the prompt" (List.length blocks)))

let stated_truth seed question =
  match question.Ag_engine.answer with
  | Ag_engine.Truth truth -> truth
  | other ->
      fail
        (Printf.sprintf "seed %d: answer was not true/false: %s" seed
           (Ag_engine.describe_value other));
      false

(* ------------------------------------------------------------------ *)
(* 1. The stated answer matches what the two displayed sides do        *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  let saw_equivalent = ref false in
  let saw_different = ref false in
  for_seeds spec 300 (fun seed question ->
      match sides_of_prompt question.Ag_engine.prompt with
      | exception Reread_error message -> fail (Printf.sprintf "seed %d: %s" seed message)
      | left, right -> (
          match equivalent (parse left) (parse right) with
          | exception Reread_error message ->
              fail
                (Printf.sprintf "seed %d: could not re-read %S / %S: %s" seed left right
                   message)
          | truly ->
              if truly then saw_equivalent := true else saw_different := true;
              let stated = stated_truth seed question in
              if truly <> stated then
                fail
                  (Printf.sprintf "seed %d: %S vs %S is actually %s, but the answer says %s"
                     seed left right
                     (if truly then "equivalent" else "not equivalent")
                     (if stated then "equivalent" else "not equivalent"))));
  (* A question set that is all one answer would be useless, and would also
     hide a formula that always returns the same thing. *)
  if not !saw_equivalent then fail "no equivalent pair was ever produced";
  if not !saw_different then fail "no inequivalent pair was ever produced"

(* ------------------------------------------------------------------ *)
(* 2. Neither answer dominates                                         *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  let total = 1000 and equivalent_count = ref 0 in
  for_seeds spec total (fun seed question ->
      if stated_truth seed question then incr equivalent_count);
  let share = float_of_int !equivalent_count /. float_of_int total in
  if share < 0.4 || share > 0.6 then
    fail
      (Printf.sprintf
         "%.0f%% of questions answer 'equivalent'; a student could do well by always \
          guessing the same way"
         (share *. 100.))

(* ------------------------------------------------------------------ *)
(* 3. The two sides of a claim are never the same text                 *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  for_seeds spec 300 (fun seed question ->
      match sides_of_prompt question.Ag_engine.prompt with
      | exception Reread_error _ -> ()
      | left, right ->
          if left = right then fail (Printf.sprintf "seed %d: both sides read %S" seed left))

(* ------------------------------------------------------------------ *)
(* 4. Each side looks set by hand                                      *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  for_seeds spec 500 (fun seed question ->
      match sides_of_prompt question.Ag_engine.prompt with
      | exception Reread_error _ -> ()
      | left, right ->
          List.iter
            (fun text ->
              let expression = parse text in
              (* Absorption repeats an operand on purpose; every other law
                 follows the same rules as the evaluation questions. *)
              if not (absorption_shaped expression) then
                List.iter
                  (fun smell -> fail (Printf.sprintf "seed %d: %s" seed smell))
                  (smells expression);
              (* \neg \neg appears only as the whole of one side, in the
                 double negation law, and never deeper. *)
              let allowed =
                match expression with
                | Not (Not (Not _)) -> -1
                | Not (Not _) -> 1
                | _ -> 0
              in
              if stacked_negations expression <> allowed then
                fail (Printf.sprintf "seed %d: stacked negation in %S" seed text);
              let again = render expression in
              if again <> text then
                fail (Printf.sprintf "seed %d: %S re-renders as %S" seed text again);
              (* The course rarely writes more than two negations on a side. *)
              let rec count = function
                | Var _ -> 0
                | Not body -> 1 + count body
                | Bin (_, l, r) -> count l + count r
              in
              if count expression > 2 then
                fail (Printf.sprintf "seed %d: %d negations in %S" seed (count expression) text))
            [ left; right ])

(* ------------------------------------------------------------------ *)
(* 5. Both wordings appear                                             *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  let two_blocks = ref false and one_block = ref false in
  for_seeds spec 100 (fun _ question ->
      match expression_blocks (math_blocks question.Ag_engine.prompt) with
      | [ _; _ ] -> two_blocks := true
      | [ _ ] -> one_block := true
      | _ -> ());
  if not !two_blocks then fail "the two-line wording never appeared in 100 seeds";
  if not !one_block then fail "the \\equiv wording never appeared in 100 seeds"

(* ------------------------------------------------------------------ *)
(* 6. Answers reach the .pg file as 1 or 0                             *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  Random.init 4;
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
        fail (Printf.sprintf "an equivalence answer was written as %s" blank))
    blanks;
  if blanks = [] then fail "no answer blanks were produced"

let () =
  if !failures = 0 then print_endline "Ag equivalence tests passed."
  else (
    prerr_endline (Printf.sprintf "%d check(s) failed." !failures);
    exit 1)
