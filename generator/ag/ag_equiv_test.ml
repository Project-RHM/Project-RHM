(* ag_equiv_test.ml — checks for boolean equivalence questions.

   These questions state a claim about *every* assignment, so the grammar
   carries a truth table rather than a truth value, and `holds` is a hand
   written comparison of two tables. A hand written formula can be wrong: an
   early draft compared the two sides with a bitwise AND against 255 instead of
   comparing them for equality, and every De Morgan question came out labelled
   "not equivalent".

   Nothing here trusts that formula. Both sides are parsed back out of the
   question text the student sees, each is evaluated under all eight
   assignments independently, and the two tables are compared. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

(* ------------------------------------------------------------------ *)
(* Reading an expression back                                          *)
(* ------------------------------------------------------------------ *)

exception Reread_error of string

type token = Variable of string | Operator of string | Open | Close

let tokenize text =
  let length = String.length text in
  let tokens = ref [] in
  let index = ref 0 in
  while !index < length do
    match text.[!index] with
    | ' ' | '\t' -> incr index
    | '(' ->
        tokens := Open :: !tokens;
        incr index
    | ')' ->
        tokens := Close :: !tokens;
        incr index
    | 'A' .. 'Z' ->
        tokens := Variable (String.make 1 text.[!index]) :: !tokens;
        incr index
    | '\\' ->
        let start = !index in
        incr index;
        while
          !index < length
          && match text.[!index] with 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false
        do
          incr index
        done;
        tokens := Operator (String.sub text start (!index - start)) :: !tokens
    | character -> raise (Reread_error (Printf.sprintf "unexpected %C" character))
  done;
  List.rev !tokens

(* Operands are read into variables before being combined: OCaml's && and ||
   short-circuit, and a parser that consumes tokens as a side effect must not
   be skipped. *)
let evaluate_text text assignment =
  let remaining = ref (tokenize text) in
  let peek () = match !remaining with [] -> None | token :: _ -> Some token in
  let advance () =
    match !remaining with
    | [] -> raise (Reread_error "unexpected end of expression")
    | _ :: rest -> remaining := rest
  in
  let value_of name =
    match List.assoc_opt name assignment with
    | Some value -> value
    | None -> raise (Reread_error ("unknown variable " ^ name))
  in
  let rec biconditional () =
    let left = ref (implication ()) in
    let rec loop () =
      match peek () with
      | Some (Operator "\\leftrightarrow") ->
          advance ();
          let right = implication () in
          left := !left = right;
          loop ()
      | _ -> ()
    in
    loop ();
    !left
  and implication () =
    let left = disjunction () in
    match peek () with
    | Some (Operator "\\to") ->
        advance ();
        let right = implication () in
        (not left) || right
    | _ -> left
  and disjunction () =
    let left = ref (conjunction ()) in
    let rec loop () =
      match peek () with
      | Some (Operator "\\lor") ->
          advance ();
          let right = conjunction () in
          left := !left || right;
          loop ()
      | _ -> ()
    in
    loop ();
    !left
  and conjunction () =
    let left = ref (unary ()) in
    let rec loop () =
      match peek () with
      | Some (Operator "\\land") ->
          advance ();
          let right = unary () in
          left := !left && right;
          loop ()
      | _ -> ()
    in
    loop ();
    !left
  and unary () =
    match peek () with
    | Some (Operator "\\neg") ->
        advance ();
        not (unary ())
    | Some (Variable name) ->
        advance ();
        value_of name
    | Some Open ->
        advance ();
        let inner = biconditional () in
        (match peek () with
        | Some Close -> advance ()
        | _ -> raise (Reread_error "missing ')'"));
        inner
    | Some (Operator other) -> raise (Reread_error ("unexpected " ^ other))
    | Some Close -> raise (Reread_error "unexpected ')'")
    | None -> raise (Reread_error "unexpected end of expression")
  in
  let result = biconditional () in
  if !remaining <> [] then raise (Reread_error "trailing tokens");
  result

(* All eight assignments over A, B, C, evaluated one at a time. This is the
   independent answer to "are these equivalent": no bit tricks, just eight
   evaluations of each side. *)
let all_assignments =
  List.init 8 (fun row ->
      [
        ("A", row land 4 <> 0); ("B", row land 2 <> 0); ("C", row land 1 <> 0);
      ])

let equivalent left right =
  List.for_all
    (fun assignment -> evaluate_text left assignment = evaluate_text right assignment)
    all_assignments

(* ------------------------------------------------------------------ *)
(* Pulling the two sides out of the question                           *)
(* ------------------------------------------------------------------ *)

(* The question reads "...[`LEFT, RIGHT`]...". The comma that separates them is
   the only one at bracket depth zero. *)
let sides_of_prompt prompt =
  let inner =
    match (String.index_opt prompt '`', String.rindex_opt prompt '`') with
    | Some first, Some last when last > first ->
        String.sub prompt (first + 1) (last - first - 1)
    | _ -> raise (Reread_error ("no [`...`] found in: " ^ prompt))
  in
  let depth = ref 0 in
  let split = ref None in
  String.iteri
    (fun index character ->
      match character with
      | '(' -> incr depth
      | ')' -> decr depth
      | ',' when !depth = 0 && !split = None -> split := Some index
      | _ -> ())
    inner;
  match !split with
  | None -> raise (Reread_error ("no separating comma in: " ^ inner))
  | Some index ->
      ( String.sub inner 0 index |> String.trim,
        String.sub inner (index + 1) (String.length inner - index - 1) |> String.trim )

let load_file filename =
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
      exit 1

(* ------------------------------------------------------------------ *)
(* 1. The stated answer matches what the two displayed sides do        *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  let saw_equivalent = ref false in
  let saw_different = ref false in
  for seed = 0 to 299 do
    Random.init seed;
    match Ag_engine.generate spec with
    | exception Ag_engine.Generation_error message ->
        fail (Printf.sprintf "seed %d: generation failed: %s" seed message)
    | question -> (
        let prompt = question.Ag_engine.prompt in
        match sides_of_prompt prompt with
        | exception Reread_error message ->
            fail (Printf.sprintf "seed %d: %s" seed message)
        | left, right -> (
            match equivalent left right with
            | exception Reread_error message ->
                fail
                  (Printf.sprintf "seed %d: could not re-read %S / %S: %s" seed left
                     right message)
            | truly ->
                if truly then saw_equivalent := true else saw_different := true;
                let stated =
                  match question.Ag_engine.answer with
                  | Ag_engine.Truth truth -> truth
                  | other ->
                      fail
                        (Printf.sprintf "seed %d: answer was not true/false: %s" seed
                           (Ag_engine.describe_value other));
                      truly
                in
                if truly <> stated then
                  fail
                    (Printf.sprintf
                       "seed %d: %S vs %S is actually %s, but the answer says %s" seed
                       left right
                       (if truly then "equivalent" else "not equivalent")
                       (if stated then "equivalent" else "not equivalent"))))
  done;
  (* A question set that is all one answer would be useless, and would also
     hide a formula that always returns the same thing. *)
  if not !saw_equivalent then fail "no equivalent pair was ever produced";
  if not !saw_different then fail "no inequivalent pair was ever produced"

(* ------------------------------------------------------------------ *)
(* 2. Both answers appear often enough to be worth asking              *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  let equivalent_count = ref 0 in
  let total = 400 in
  for seed = 0 to total - 1 do
    Random.init seed;
    match Ag_engine.generate spec with
    | exception Ag_engine.Generation_error _ -> ()
    | question -> (
        match question.Ag_engine.answer with
        | Ag_engine.Truth true -> incr equivalent_count
        | _ -> ())
  done;
  let share = float_of_int !equivalent_count /. float_of_int total in
  if share < 0.2 || share > 0.8 then
    fail
      (Printf.sprintf
         "%.0f%% of questions answer 'equivalent'; a student could pass by always \
          guessing the same way"
         (share *. 100.))

(* ------------------------------------------------------------------ *)
(* 3. The two sides of a claim are never the same text                 *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean_equiv.ag" in
  for seed = 0 to 199 do
    Random.init seed;
    match Ag_engine.generate spec with
    | exception Ag_engine.Generation_error _ -> ()
    | question -> (
        match sides_of_prompt question.Ag_engine.prompt with
        | exception Reread_error _ -> ()
        | left, right ->
            if left = right then
              fail (Printf.sprintf "seed %d: both sides read %S" seed left))
  done

(* ------------------------------------------------------------------ *)
(* 4. Answers reach the .pg file as 1 or 0                             *)
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
