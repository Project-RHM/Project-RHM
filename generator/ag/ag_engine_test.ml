(* ag_engine_test.ml — generation tests.

   The main check reads the generated question text back with an independent
   parser and evaluates it. If the engine's answer and the re-read text agree,
   then both the arithmetic and the parenthesisation are right: a misplaced
   parenthesis changes what the text means and the two would disagree. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

(* ------------------------------------------------------------------ *)
(* An independent reader for the generated text                        *)
(* ------------------------------------------------------------------ *)

exception Reread_error of string

type token = Number of int | Operator of string | Open | Close

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
    | '0' .. '9' ->
        let start = !index in
        while !index < length && text.[!index] >= '0' && text.[!index] <= '9' do
          incr index
        done;
        tokens := Number (int_of_string (String.sub text start (!index - start))) :: !tokens
    | _ ->
        let start = !index in
        while
          !index < length
          &&
          match text.[!index] with
          | ' ' | '\t' | '(' | ')' | '0' .. '9' -> false
          | _ -> true
        do
          incr index
        done;
        tokens := Operator (String.sub text start (!index - start)) :: !tokens
  done;
  List.rev !tokens

(* The re-read shape, kept separate from its value: a redundant parenthesis is
   one whose removal leaves the *parse* unchanged. Comparing values instead
   would be wrong, because a + (b - c - d) and a + b - c - d are equal numbers
   built from different trees, and only the first faithfully renders a tree
   whose right child is a subtraction. *)
type parsed = Literal of int | Applied of string * parsed * parsed

let rec evaluate_parsed = function
  | Literal value -> Ag_number.of_int value
  | Applied (operator, left, right) -> (
      let left = evaluate_parsed left and right = evaluate_parsed right in
      match operator with
      | "+" -> Ag_number.add left right
      | "-" -> Ag_number.subtract left right
      | "\\cdot" -> Ag_number.multiply left right
      | "\\div" -> Ag_number.divide left right
      | "\\bmod" -> Ag_number.modulo left right
      | _ -> raise (Reread_error ("unknown operator " ^ operator)))

(* expression := term (("+" | "-") term)*
   term       := factor (("\cdot" | "\div" | "\bmod") factor)*
   factor     := NUMBER | "(" expression ")"                          *)
let reread text =
  let remaining = ref (tokenize text) in
  let peek () = match !remaining with [] -> None | token :: _ -> Some token in
  let advance () =
    match !remaining with
    | [] -> raise (Reread_error "unexpected end of text")
    | _ :: rest -> remaining := rest
  in
  let rec expression () =
    let left = ref (term ()) in
    let rec loop () =
      match peek () with
      | Some (Operator (("+" | "-") as operator)) ->
          advance ();
          left := Applied (operator, !left, term ());
          loop ()
      | _ -> ()
    in
    loop ();
    !left
  and term () =
    let left = ref (factor ()) in
    let rec loop () =
      match peek () with
      | Some (Operator (("\\cdot" | "\\div" | "\\bmod") as operator)) ->
          advance ();
          left := Applied (operator, !left, factor ());
          loop ()
      | _ -> ()
    in
    loop ();
    !left
  and factor () =
    match peek () with
    | Some (Number value) ->
        advance ();
        Literal value
    | Some Open ->
        advance ();
        let inner = expression () in
        (match peek () with
        | Some Close -> advance ()
        | _ -> raise (Reread_error "missing ')'"));
        inner
    | Some (Operator operator) -> raise (Reread_error ("unexpected " ^ operator))
    | Some Close -> raise (Reread_error "unexpected ')'")
    | None -> raise (Reread_error "unexpected end of text")
  in
  let result = expression () in
  if !remaining <> [] then raise (Reread_error "trailing tokens");
  result

(* The question text is "What is the value of [`EXPR`]?"; take what is between
   the backticks. *)
let expression_of_prompt prompt =
  match (String.index_opt prompt '`', String.rindex_opt prompt '`') with
  | Some first, Some last when last > first ->
      String.sub prompt (first + 1) (last - first - 1)
  | _ -> raise (Reread_error ("no [`...`] found in: " ^ prompt))

let count_operators text =
  tokenize text
  |> List.filter (function Operator _ -> true | _ -> false)
  |> List.length

let longest_number text =
  tokenize text
  |> List.fold_left
       (fun longest token ->
         match token with
         | Number value -> max longest (String.length (string_of_int value))
         | _ -> longest)
       0

(* ------------------------------------------------------------------ *)
(* Loading helpers                                                     *)
(* ------------------------------------------------------------------ *)

let load label source =
  match Ag_load.parse_string ~filename:label source with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (label ^ ": " ^ Ag_load.string_of_failure error)) errors;
      exit 1

let load_file filename =
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
      exit 1

(* Rebuild a grammar text with a different budget so the exact-operator-count
   property can be checked across several budgets. *)
let arithmetic_source ~len ~digit ~prompt =
  Printf.sprintf
    "attribute len = %d split\n\
     attribute digit = %d copy\n\
     synth value\n\
     synth latex\n\
     precedence 1 left + -\n\
     precedence 2 left * /\n\
     start E\n\
     E -> E + E when len > 0 weight 3 { len = -1 value = $1.value + $3.value latex = \
     infix($1, \"+\", $3) }\n\
     E -> E - E when len > 0 weight 3 { len = -1 value = $1.value - $3.value latex = \
     infix($1, \"-\", $3) }\n\
     E -> E * E when len > 0 weight 2 { len = -1 value = $1.value * $3.value latex = \
     infix($1, \"\\cdot\", $3) }\n\
     E -> E / E when len > 0 weight 1 { len = -1 require $3.value != 0 value = $1.value \
     / $3.value latex = infix($1, \"\\div\", $3) }\n\
     E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
     num -> integer(digit) { value = $1.value latex = str($1.value) }\n\
     prompt \"%s\"\n\
     answer E.value\n"
    len digit prompt

(* ------------------------------------------------------------------ *)
(* 1. The answer agrees with the question text                         *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "arithmetic.ag" in
  for seed = 0 to 299 do
    Random.init seed;
    match Ag_engine.generate spec with
    | exception Ag_engine.Generation_error message ->
        fail (Printf.sprintf "seed %d: generation failed: %s" seed message)
    | question -> (
        let text = expression_of_prompt question.Ag_engine.prompt in
        match evaluate_parsed (reread text) with
        | exception Reread_error message ->
            fail (Printf.sprintf "seed %d: could not re-read %S: %s" seed text message)
        | recomputed ->
            let engine_answer =
              match question.Ag_engine.answer with
              | Ag_engine.Num number -> number
              | other ->
                  fail
                    (Printf.sprintf "seed %d: answer was not a number: %s" seed
                       (Ag_engine.describe_value other));
                  Ag_number.zero
            in
            if not (Ag_number.equal recomputed engine_answer) then
              fail
                (Printf.sprintf "seed %d: %S reads as %s but the answer says %s" seed text
                   (Ag_number.to_string recomputed)
                   (Ag_number.to_string engine_answer)))
  done

(* ------------------------------------------------------------------ *)
(* 2. A budget of n produces exactly n operators, at every n           *)
(* ------------------------------------------------------------------ *)

let () =
  for len = 0 to 6 do
    let spec =
      load "budget.ag"
        (arithmetic_source ~len ~digit:3 ~prompt:"[`{E.latex}`]")
    in
    for seed = 0 to 39 do
      Random.init (seed + (len * 1000));
      match Ag_engine.generate spec with
      | exception Ag_engine.Generation_error message ->
          fail (Printf.sprintf "len %d seed %d: %s" len seed message)
      | question ->
          let text = expression_of_prompt question.Ag_engine.prompt in
          if count_operators text <> len then
            fail
              (Printf.sprintf "len %d: %S has %d operators" len text
                 (count_operators text));
          if Ag_engine.consumption question.Ag_engine.tree "len" <> len then
            fail
              (Printf.sprintf "len %d: the tree consumed %d" len
                 (Ag_engine.consumption question.Ag_engine.tree "len"));
          if longest_number text > 3 then
            fail (Printf.sprintf "digit budget exceeded in %S" text)
    done
  done

(* ------------------------------------------------------------------ *)
(* 3. Parentheses are added only where they change the meaning         *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "arithmetic.ag" in
  for seed = 0 to 199 do
    Random.init seed;
    match Ag_engine.generate spec with
    | exception Ag_engine.Generation_error _ -> ()
    | question ->
        let text = expression_of_prompt question.Ag_engine.prompt in
        (* Strip one pair of parentheses at a time. If the text still parses
           the same way without them, that pair was not doing any work. *)
        let length = String.length text in
        let rec probe index =
          if index >= length then ()
          else if text.[index] = '(' then begin
            (* find its partner *)
            let rec partner position depth =
              if position >= length then None
              else
                match text.[position] with
                | '(' -> partner (position + 1) (depth + 1)
                | ')' -> if depth = 1 then Some position else partner (position + 1) (depth - 1)
                | _ -> partner (position + 1) depth
            in
            (match partner (index + 1) 1 with
            | None -> fail (Printf.sprintf "unbalanced parentheses in %S" text)
            | Some close ->
                let without =
                  String.sub text 0 index
                  ^ String.sub text (index + 1) (close - index - 1)
                  ^ String.sub text (close + 1) (length - close - 1)
                in
                (match (reread text, reread without) with
                | original, stripped when original = stripped ->
                    fail
                      (Printf.sprintf
                         "%S has a parenthesis pair that does not change how it parses"
                         text)
                | _ -> ()
                | exception Reread_error _ -> ()));
            probe (index + 1)
          end
          else probe (index + 1)
        in
        probe 0
  done

(* ------------------------------------------------------------------ *)
(* 4. The same seed reproduces the same question                       *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "arithmetic.ag" in
  Random.init 20260811;
  let first = Ag_engine.generate spec in
  Random.init 20260811;
  let second = Ag_engine.generate spec in
  if first.Ag_engine.prompt <> second.Ag_engine.prompt then
    fail "the same seed produced a different question";
  if first.Ag_engine.answer_text <> second.Ag_engine.answer_text then
    fail "the same seed produced a different answer"

(* ------------------------------------------------------------------ *)
(* 5. The headline property: a new operator needs no OCaml change      *)
(* ------------------------------------------------------------------ *)

(* Nothing in this test binary knows that a modulo *rule* exists. The rule is
   introduced entirely by the grammar text below, exactly as a user would add
   it by editing arithmetic.ag. *)
let modulo_grammar =
  "attribute len = 2 split\n\
   attribute digit = 2 copy\n\
   synth value\n\
   synth latex\n\
   precedence 1 left + -\n\
   precedence 2 left * / %\n\
   start E\n\
   E -> E % E when len > 0 weight 5 { len = -1 require $3.value != 0 value = $1.value % \
   $3.value latex = infix($1, \"\\bmod\", $3) }\n\
   E -> E + E when len > 0 weight 1 { len = -1 value = $1.value + $3.value latex = \
   infix($1, \"+\", $3) }\n\
   E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
   num -> integer(digit) { value = $1.value latex = str($1.value) }\n\
   prompt \"Compute [`{E.latex}`].\"\n\
   answer E.value\n"

let () =
  let spec = load "modulo.ag" modulo_grammar in
  let saw_modulo = ref false in
  for seed = 0 to 99 do
    Random.init seed;
    match Ag_engine.generate spec with
    | exception Ag_engine.Generation_error message ->
        fail (Printf.sprintf "modulo seed %d: %s" seed message)
    | question -> (
        let text = expression_of_prompt question.Ag_engine.prompt in
        let contains_bmod =
          List.exists (function Operator "\\bmod" -> true | _ -> false) (tokenize text)
        in
        if contains_bmod then saw_modulo := true;
        match evaluate_parsed (reread text) with
        | exception Reread_error message ->
            fail (Printf.sprintf "modulo seed %d: %S: %s" seed text message)
        | recomputed ->
            let engine_answer =
              match question.Ag_engine.answer with
              | Ag_engine.Num number -> number
              | _ -> Ag_number.zero
            in
            if not (Ag_number.equal recomputed engine_answer) then
              fail
                (Printf.sprintf "modulo: %S reads as %s but the answer says %s" text
                   (Ag_number.to_string recomputed)
                   (Ag_number.to_string engine_answer)))
  done;
  if not !saw_modulo then fail "the modulo grammar never produced a modulo question"

(* ------------------------------------------------------------------ *)
(* 6. The question wording comes from the file                         *)
(* ------------------------------------------------------------------ *)

let () =
  let spec =
    load "chinese.ag"
      (arithmetic_source ~len:2 ~digit:2
         ~prompt:"\194\191Cual es el valor de [`{E.latex}`]?")
  in
  Random.init 7;
  let question = Ag_engine.generate spec in
  let starts_with text prefix =
    String.length text >= String.length prefix
    && String.sub text 0 (String.length prefix) = prefix
  in
  if not (starts_with question.Ag_engine.prompt "\194\191Cual es") then
    fail ("the prompt did not come from the file: " ^ question.Ag_engine.prompt)

(* ------------------------------------------------------------------ *)
(* 7. Division never produces a zero denominator                       *)
(* ------------------------------------------------------------------ *)

let () =
  let division_only =
    "attribute len = 3 split\n\
     attribute digit = 1 copy\n\
     synth value\n\
     synth latex\n\
     precedence 2 left /\n\
     start E\n\
     E -> E / E when len > 0 { len = -1 require $3.value != 0 value = $1.value / \
     $3.value latex = infix($1, \"\\div\", $3) }\n\
     E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
     num -> integer(digit) { value = $1.value latex = str($1.value) }\n\
     prompt \"[`{E.latex}`]\"\n\
     answer E.value\n"
  in
  (* digit = 1 draws from 0..9, so zero denominators are common and the
     require clause has to do real work. *)
  let spec = load "division.ag" division_only in
  for seed = 0 to 199 do
    Random.init seed;
    match Ag_engine.generate spec with
    | exception Ag_engine.Generation_error message ->
        fail (Printf.sprintf "division seed %d: %s" seed message)
    | question -> (
        let text = expression_of_prompt question.Ag_engine.prompt in
        match evaluate_parsed (reread text) with
        | exception Ag_number.Arithmetic_error message ->
            fail (Printf.sprintf "division seed %d: %S: %s" seed text message)
        | exception Reread_error message ->
            fail (Printf.sprintf "division seed %d: %S: %s" seed text message)
        | _ -> ())
  done

(* ------------------------------------------------------------------ *)
(* 8. A failure no retry can fix is reported immediately               *)
(* ------------------------------------------------------------------ *)

let message_contains haystack needle =
  let haystack_length = String.length haystack in
  let needle_length = String.length needle in
  let rec search index =
    if index + needle_length > haystack_length then false
    else if String.sub haystack index needle_length = needle then true
    else search (index + 1)
  in
  search 0

let () =
  (* integer_between(5, 5) has one possible value, so the require can never
     hold and no amount of retrying changes that. The engine must say so
     instead of burning its 200 question attempts. *)
  let impossible =
    "attribute len = 0 split\n\
     synth value\n\
     synth latex\n\
     start E\n\
     E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
     num -> integer_between(5, 5) { value = $1.value require value != 5 latex = \
     str($1.value) }\n\
     prompt \"[`{E.latex}`]\"\n\
     answer E.value\n"
  in
  let spec = load "impossible.ag" impossible in
  Random.init 1;
  match Ag_engine.generate spec with
  | _ -> fail "the impossible grammar generated a question"
  | exception Ag_engine.Generation_error message ->
      if not (message_contains message "can never satisfy") then
        fail ("expected a 'can never satisfy' diagnosis, got: " ^ message)

(* ------------------------------------------------------------------ *)
(* 9. Running out of retries names the failing constraint              *)
(* ------------------------------------------------------------------ *)

let () =
  (* This require is possible to state but impossible to draw: values are 1 or
     2 and it wants more than 5. The draws are random, so the engine will use
     its full retry budget — and the final error must say how often which
     require failed, so the author knows what to fix. *)
  let unlucky =
    "attribute len = 0 split\n\
     synth value\n\
     synth latex\n\
     start E\n\
     E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
     num -> integer_between(1, 2) { value = $1.value require value > 5 latex = \
     str($1.value) }\n\
     prompt \"[`{E.latex}`]\"\n\
     answer E.value\n"
  in
  let spec = load "unlucky.ag" unlucky in
  Random.init 1;
  match Ag_engine.generate spec with
  | _ -> fail "the unlucky grammar generated a question"
  | exception Ag_engine.Generation_error message ->
      if not (message_contains message "attempts") then
        fail ("expected the attempt count in the error, got: " ^ message);
      if not (message_contains message "most frequent failure") then
        fail ("expected a failure tally in the error, got: " ^ message);
      if not (message_contains message "line") then
        fail ("expected the failing line in the error, got: " ^ message)

let () =
  if !failures = 0 then print_endline "Ag engine tests passed."
  else (
    prerr_endline (Printf.sprintf "%d check(s) failed." !failures);
    exit 1)
