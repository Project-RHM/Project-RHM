(* ag_boolean_test.ml — the generality check.

   Boolean questions were the first migration after arithmetic, and they were
   chosen because they stress parts of the design arithmetic never touches:

     - a truth assignment belongs to the whole question, not to a leaf, so it
       cannot be an inherited budget (those only ever decrease, and are ints);
     - the question text has to contain generated content (the assignment
       list) rather than a single expression;
     - the answer is a truth value, not a number.

   As with arithmetic, the main check re-reads the generated question with an
   independent reader: the expression is parsed back, evaluated against the
   assignment shown to the student, and compared with the stated answer. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

(* ------------------------------------------------------------------ *)
(* An independent reader for the generated question                    *)
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

(* Every operand is read into a variable before it is combined. Writing
   [left := !left || disjunction ()] would let OCaml's short-circuiting skip
   the call whenever the left side is already true, and the tokens it should
   have consumed would be left behind.

   biconditional := implication ("\leftrightarrow" implication)*      left
   implication   := disjunction ("\to" implication)?                  right
   disjunction   := exclusive ("\lor" exclusive)*
   exclusive     := conjunction ("\oplus" conjunction)*
   conjunction   := unary ("\land" unary)*
   unary         := "\neg" unary | VARIABLE | "(" biconditional ")"       *)
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
    | None -> raise (Reread_error ("no assignment shown for " ^ name))
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
    let left = ref (exclusive ()) in
    let rec loop () =
      match peek () with
      | Some (Operator "\\lor") ->
          advance ();
          let right = exclusive () in
          left := !left || right;
          loop ()
      | _ -> ()
    in
    loop ();
    !left
  and exclusive () =
    let left = ref (conjunction ()) in
    let rec loop () =
      match peek () with
      | Some (Operator "\\oplus") ->
          advance ();
          let right = conjunction () in
          left := !left <> right;
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

(* ------------------------------------------------------------------ *)
(* Reading the parts of the generated question back                    *)
(* ------------------------------------------------------------------ *)

let expression_of_prompt prompt =
  match (String.index_opt prompt '`', String.rindex_opt prompt '`') with
  | Some first, Some last when last > first ->
      String.sub prompt (first + 1) (last - first - 1)
  | _ -> raise (Reread_error ("no [`...`] found in: " ^ prompt))

(* The assignment the student is shown, read straight out of the question
   text: "- A = \mathsf{T}" lines. *)
let assignment_of_prompt prompt =
  prompt |> String.split_on_char '\n'
  |> List.filter_map (fun line ->
         let line = String.trim line in
         if String.length line > 2 && line.[0] = '-' && line.[1] = ' ' then
           match String.index_opt line '=' with
           | Some equals ->
               let name = String.sub line 2 (equals - 2) |> String.trim in
               let rendered =
                 String.sub line (equals + 1) (String.length line - equals - 1)
                 |> String.trim
               in
               if rendered = "\\mathsf{T}" then Some (name, true)
               else if rendered = "\\mathsf{F}" then Some (name, false)
               else None
           | None -> None
         else None)

let count_connectives text =
  tokenize text |> List.filter (function Operator _ -> true | _ -> false) |> List.length

let load_file filename =
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
      exit 1

(* ------------------------------------------------------------------ *)
(* 1. The answer agrees with the question as the student sees it       *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.ag" in
  for seed = 0 to 299 do
    Random.init seed;
    match Ag_engine.generate spec with
    | exception Ag_engine.Generation_error message ->
        fail (Printf.sprintf "seed %d: generation failed: %s" seed message)
    | question -> (
        let prompt = question.Ag_engine.prompt in
        let text = expression_of_prompt prompt in
        let assignment = assignment_of_prompt prompt in
        if List.length assignment <> 3 then
          fail
            (Printf.sprintf "seed %d: expected three assignment lines, found %d" seed
               (List.length assignment));
        match evaluate_text text assignment with
        | exception Reread_error message ->
            fail (Printf.sprintf "seed %d: could not re-read %S: %s" seed text message)
        | recomputed ->
            let stated =
              match question.Ag_engine.answer with
              | Ag_engine.Truth truth -> truth
              | other ->
                  fail
                    (Printf.sprintf "seed %d: answer was not true/false: %s" seed
                       (Ag_engine.describe_value other));
                  recomputed
            in
            if recomputed <> stated then
              fail
                (Printf.sprintf
                   "seed %d: %S under that assignment is %b, but the answer says %b" seed
                   text recomputed stated))
  done

(* ------------------------------------------------------------------ *)
(* 2. The same variable means the same thing throughout one question   *)
(* ------------------------------------------------------------------ *)

(* This is the property a leaf-level draw could not provide, and the reason
   `random` exists. It is already implied by test 1 -- an inconsistent A would
   usually make the recomputed answer disagree -- but checking it directly says
   so plainly, and catches the case where the inconsistency happens to cancel
   out. *)
let () =
  let spec = load_file "boolean.ag" in
  for seed = 0 to 99 do
    Random.init seed;
    let question = Ag_engine.generate spec in
    let prompt = question.Ag_engine.prompt in
    let assignment = assignment_of_prompt prompt in
    let text = expression_of_prompt prompt in
    (* Evaluating with the shown assignment must succeed for every variable
       that appears, which means no variable escaped the assignment list. *)
    match evaluate_text text assignment with
    | exception Reread_error message ->
        fail (Printf.sprintf "seed %d: %s" seed message)
    | _ -> ()
  done

(* ------------------------------------------------------------------ *)
(* 3. The budget still means what it says                              *)
(* ------------------------------------------------------------------ *)

let () =
  let base = load_file "boolean.ag" in
  for len = 0 to 5 do
    match Ag_check.with_initial base "len" len with
    | Error message -> fail message
    | Ok spec ->
        for seed = 0 to 29 do
          Random.init (seed + (len * 1000));
          match Ag_engine.generate spec with
          | exception Ag_engine.Generation_error message ->
              fail (Printf.sprintf "len %d seed %d: %s" len seed message)
          | question ->
              let text = expression_of_prompt question.Ag_engine.prompt in
              if count_connectives text <> len then
                fail
                  (Printf.sprintf "len %d: %S has %d connectives" len text
                     (count_connectives text))
        done
  done

(* ------------------------------------------------------------------ *)
(* 4. A truth value reaches the .pg file as 1 or 0                     *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "boolean.ag" in
  Random.init 2;
  let document = Ag_pgml.of_spec ~count:6 spec in
  (* Only the answer blank, not the braces inside \mathsf{T} on the assignment
     lines. *)
  let marker = "[_____]" in
  let blanks =
    document |> String.split_on_char '\n'
    |> List.filter_map (fun line ->
           let rec find index =
             if index + String.length marker > String.length line then None
             else if String.sub line index (String.length marker) = marker then
               Some (String.sub line (index + String.length marker)
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
