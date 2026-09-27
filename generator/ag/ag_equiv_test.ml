(* ag_equiv_test.ml — equivalence claims justified by a truth table.

   Each question shows a claim "X \equiv Y", a truth table to complete and a
   choice of "logically equivalent" or "not logically equivalent". Nothing
   here trusts the grammar: the two sides are read back out of the text the
   student sees, evaluated under every assignment independently, and the
   stated conclusion is compared with that. The table must be the table of
   exactly those two sides. Then the properties that make the claim read as
   a lecturer's are checked: two or three laws apart rather than one, sides
   a person would write, a table of a sensible size, and an even split of
   the two conclusions. *)

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

let contains haystack needle =
  let h = String.length haystack and n = String.length needle in
  let rec search i = i + n <= h && (String.sub haystack i n = needle || search (i + 1)) in
  n = 0 || search 0

let count_occurrences haystack needle =
  let h = String.length haystack and n = String.length needle in
  let rec go i found =
    if i + n > h then found else if String.sub haystack i n = needle then go (i + n) (found + 1) else go (i + 1) found
  in
  go 0 0

let options = [ "logically equivalent"; "not logically equivalent" ]

(* The claim is one math block, "X \equiv Y". *)
let sides_of_prompt prompt =
  match expression_blocks (math_blocks prompt) with
  | [ claim ] -> (
      match split_on " \\equiv " claim with
      | [ left; right ] -> (String.trim left, String.trim right)
      | _ -> raise (Reread_error ("no single \\equiv in: " ^ claim)))
  | blocks -> raise (Reread_error (Printf.sprintf "%d math blocks in the prompt" (List.length blocks)))

(* The answer: the table of both sides, then the labelled conclusion. *)
let answer_parts seed question =
  match question.Ag_engine.answer with
  | Ag_engine.Parts [ Ag_engine.TruthTable formulas; Ag_engine.Labelled (_, Ag_engine.Choice (offered, chosen)) ] ->
      if offered <> options then fail (Printf.sprintf "seed %d: the conclusion offers other options" seed);
      Some (formulas, chosen)
  | other ->
      fail (Printf.sprintf "seed %d: unexpected answer %s" seed (Ag_engine.describe_value other));
      None

let rec negation_count = function
  | Var _ -> 0
  | Not body -> 1 + negation_count body
  | Bin (_, l, r) -> negation_count l + negation_count r

let truth_values e =
  let names = variable_set e in
  let n = List.length names in
  List.init (1 lsl n) (fun row -> evaluate (List.mapi (fun i name -> (name, row land (1 lsl i) <> 0)) names) e)

(* ------------------------------------------------------------------ *)
(* 1. The stated conclusion and the table match the claim shown         *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  let equivalent_count = ref 0 and total = 600 in
  for_seeds spec total (fun seed question ->
      match (answer_parts seed question, sides_of_prompt question.Ag_engine.prompt) with
      | exception Reread_error message -> fail (Printf.sprintf "seed %d: %s" seed message)
      | None, _ -> ()
      | Some (formulas, chosen), (left, right) -> (
          let l = parse left and r = parse right in
          let truly = equivalent l r in
          if truly then incr equivalent_count;
          let expected = if truly then "logically equivalent" else "not logically equivalent" in
          if chosen <> expected then
            fail (Printf.sprintf "seed %d: %S vs %S is %s, but the answer says %s" seed left right expected chosen);
          match formulas with
          | [ fl; fr ] ->
              if Ag_boolean.to_latex fl <> left || Ag_boolean.to_latex fr <> right then
                fail (Printf.sprintf "seed %d: the table is not of the claim shown" seed);
              List.iter
                (fun row ->
                  if evaluate row l <> Ag_boolean.evaluate row fl || evaluate row r <> Ag_boolean.evaluate row fr then
                    fail (Printf.sprintf "seed %d: a cell of the table is wrong" seed))
                (Ag_boolean.table_rows formulas)
          | _ -> fail (Printf.sprintf "seed %d: the table is not of two sides" seed)));
  (* A student who always picks the same conclusion should score about half. *)
  let share = float_of_int !equivalent_count /. float_of_int total in
  if share < 0.4 || share > 0.6 then
    fail (Printf.sprintf "%.0f%% of the claims hold; the two conclusions should be close to even" (share *. 100.))

(* ------------------------------------------------------------------ *)
(* 2. Set as a lecturer sets it                                        *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  let widths = Hashtbl.create 8 in
  for_seeds spec 500 (fun seed question ->
      match (answer_parts seed question, sides_of_prompt question.Ag_engine.prompt) with
      | exception Reread_error _ -> ()
      | None, _ -> ()
      | Some (formulas, _), (left, right) -> (
          let l = parse left and r = parse right in
          List.iter
            (fun (text, e) ->
              if render e <> text then fail (Printf.sprintf "seed %d: %S re-renders as %S" seed text (render e));
              if stacked_negations e > 0 then fail (Printf.sprintf "seed %d: stacked negation in %S" seed text);
              if negation_count e > 2 then fail (Printf.sprintf "seed %d: %d negations in %S" seed (negation_count e) text);
              (* No part written twice in one chain or on both sides of one
                 connective, as in (p \to q) \land (p \to q). *)
              let rec repeated = function
                | Var _ -> false
                | Not body -> repeated body
                | Bin (op, l, r) as node ->
                    let parts =
                      if op = "\\land" || op = "\\lor" then List.map render (members op node) else [ render l; render r ]
                    in
                    List.length parts <> List.length (List.sort_uniq compare parts)
                    || (if op = "\\land" || op = "\\lor" then List.exists repeated (members op node)
                        else repeated l || repeated r)
              in
              if repeated e then fail (Printf.sprintf "seed %d: a part is written twice in %S" seed text);
              let values = truth_values e in
              if List.for_all Fun.id values || not (List.exists Fun.id values) then
                fail (Printf.sprintf "seed %d: %S is always true or always false" seed text))
            [ (left, l); (right, r) ];
          if size l < 2 && size r < 2 then fail (Printf.sprintf "seed %d: both sides are too slight" seed);
          (* The table: two or three variables, three to seven columns to fill. *)
          let variables = List.length (Ag_boolean.table_variables formulas) in
          if variables < 2 || variables > 3 then fail (Printf.sprintf "seed %d: %d variables" seed variables);
          let width = Ag_boolean.table_width formulas in
          Hashtbl.replace widths width ();
          if width < 3 || width > 7 then fail (Printf.sprintf "seed %d: %d columns to fill" seed width);
          (* Two or three laws apart: not the same up to the order of
             operands, and not one law or one classic mistake apart. These use
             the engine's own law table, which ag_boolean_core_test checks
             law by law. *)
          match formulas with
          | [ fl; fr ] ->
              if Ag_boolean.same_shape fl fr then fail (Printf.sprintf "seed %d: the sides differ only in order" seed);
              if Ag_boolean.one_step_apart fl fr then
                fail (Printf.sprintf "seed %d: %S and %S are one step apart" seed left right)
          | _ -> ()));
  if Hashtbl.length widths < 3 then fail "the tables are all of one or two sizes"

(* ------------------------------------------------------------------ *)
(* 3. The .pg document                                                 *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  Random.init 4;
  let questions = List.init 3 (fun _ -> Ag_engine.generate spec) in
  let document = Ag_pgml.document ?stem:spec.Ag_check.stem questions in
  List.iter
    (fun marker -> if not (contains document marker) then fail (Printf.sprintf "the document lacks %S" marker))
    [ "\"contextBoolean.pl\""; "\"parserPopUp.pl\""; "[#"; "#]{align";
      "Therefore the two sides are [_]{$ans"; "\"logically equivalent\", \"not logically equivalent\"";
      "Determine whether each of the following logical equivalences holds"; "a) "; "c) " ];
  if count_occurrences document "[#" <> 3 then fail "expected one table per question";
  if count_occurrences document "= PopUp([\"?\"" <> 3 then fail "expected one conclusion per question"

let () =
  if !failures = 0 then print_endline "Ag equivalence tests passed."
  else (
    prerr_endline (Printf.sprintf "%d check(s) failed." !failures);
    exit 1)
