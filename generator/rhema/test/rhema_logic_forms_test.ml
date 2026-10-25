(* Independent checks for logic_forms.rhm: the displayed proposition is read
   back with the Boolean reader and evaluated over all eight assignments, so
   each classification, each count and each rewriting is checked against
   the truth table rather than against the engine. *)

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

let text_attribute node name =
  match Rhema_engine.attribute node name with
  | Rhema_engine.Text text -> text
  | other -> fail (name ^ " expected text, got " ^ Rhema_engine.describe_value other); ""

let all_assignments =
  List.concat_map
    (fun p -> List.concat_map (fun q -> List.map (fun r -> [ ("p", p); ("q", q); ("r", r) ]) [ false; true ]) [ false; true ])
    [ false; true ]

let truth_table expression = List.map (fun assignment -> evaluate assignment expression) all_assignments

let rec has_conditional = function
  | Var _ -> false
  | Not body -> has_conditional body
  | Bin (operator, l, r) ->
      List.mem operator [ "\\to"; "\\leftrightarrow"; "\\oplus" ] || has_conditional l || has_conditional r

(* The proposition is the longest math block; the others name variables or
   connectives. *)
let displayed prompt =
  match List.sort (fun a b -> compare (String.length b) (String.length a)) (math_blocks prompt) with
  | longest :: _ -> longest
  | [] -> fail "no math block in the prompt"; ""

let contains text fragment =
  let rec search index =
    index + String.length fragment <= String.length text
    && (String.sub text index (String.length fragment) = fragment || search (index + 1))
  in
  search 0

let () =
  let base = load_file "logic_forms.rhm" in
  let kinds = Hashtbl.create 5 in
  for cost = 1 to 10 do
    match Rhema_check.with_initial base "cost" cost with
    | Error message -> fail message
    | Ok spec ->
        for seed = 0 to 29 do
          Random.init (seed + (cost * 1000));
          match Rhema_engine.generate spec with
          | exception Rhema_engine.Generation_error message -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
          | question -> (
              let root = question.Rhema_engine.tree in
              let kind = text_attribute root "kind" in
              Hashtbl.replace kinds kind true;
              if Rhema_engine.consumption root "cost" <> cost then
                fail (Printf.sprintf "cost %d seed %d: the budget was not spent exactly" cost seed);
              let shown = parse (displayed question.Rhema_engine.prompt) in
              let table = truth_table shown in
              let bad message = fail (Printf.sprintf "cost %d seed %d (%s): %s" cost seed kind message) in
              match (kind, question.Rhema_engine.answer) with
              | "tautology", Rhema_engine.Num n ->
                  if not (List.for_all Fun.id table) then bad "not a tautology";
                  if Rhema_number.to_float n <> 1. then bad "answer is not 1";
                  if question.Rhema_engine.context <> "Numeric" then bad "wrong context"
              | "contradiction", Rhema_engine.Num n ->
                  if List.exists Fun.id table then bad "not a contradiction";
                  if Rhema_number.to_float n <> 2. then bad "answer is not 2"
              | "neither", Rhema_engine.Num n ->
                  if List.for_all Fun.id table || not (List.exists Fun.id table) then bad "not contingent";
                  if Rhema_number.to_float n <> 0. then bad "answer is not 0"
              | "count", Rhema_engine.Num n ->
                  let models = List.length (List.filter Fun.id table) in
                  if Rhema_number.to_float n <> float_of_int models then
                    bad (Printf.sprintf "answer %s but %d models" (Rhema_number.to_string n) models);
                  if List.length (variable_set shown) <> 3 then bad "not every variable takes part"
              | "rewrite", Rhema_engine.Boolean answer ->
                  if question.Rhema_engine.context <> "Boolean" then bad "wrong context";
                  if not (has_conditional shown) then bad "nothing to rewrite";
                  let rewritten = parse (Rhema_boolean.to_latex answer) in
                  if has_conditional rewritten then bad "the answer still has a conditional";
                  if truth_table rewritten <> table then bad "the answer is not equivalent"
              | _, other -> bad ("unexpected answer " ^ Rhema_engine.describe_value other))
        done
  done;
  List.iter (fun kind -> if not (Hashtbl.mem kinds kind) then fail ("never asked a " ^ kind ^ " question"))
    [ "tautology"; "contradiction"; "neither"; "count"; "rewrite" ];
  Random.init 4;
  let document = Rhema_pgml.of_spec ~count:12 base in
  if not (contains document "contextBoolean.pl") then fail "the document does not load contextBoolean.pl";
  if not (contains document "Context(\"Boolean\");") then fail "the document never switches to the Boolean context";
  if !failures = 0 then print_endline "Ag logic forms tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG logic forms test(s) failed." !failures);
    exit 1
  end
