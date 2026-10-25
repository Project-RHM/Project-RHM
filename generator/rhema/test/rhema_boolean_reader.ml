(* rhema_boolean_reader.ml — an independent reader for the Boolean questions.

   Neither Boolean test suite trusts the grammar's own attributes. Each reads
   the question exactly as the student sees it: the expression is parsed back
   into a tree, evaluated on its own, and rendered again with the bracketing
   the grammars promise. This module holds that reader; the suites hold the
   checks. *)

exception Reread_error of string

type expr =
  | Var of string
  | Not of expr
  | Bin of string * expr * expr  (* the operator as its LaTeX command *)

(* ------------------------------------------------------------------ *)
(* Parsing                                                             *)
(* ------------------------------------------------------------------ *)

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
    | 'A' .. 'Z' | 'a' .. 'z' ->
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

(* The expression as a course reads it, loosest connective first:

     biconditional := implication ("\leftrightarrow" implication)*      left
     implication   := disjunction ("\to" implication)?                  right
     disjunction   := exclusive ("\lor" exclusive)*
     exclusive     := conjunction ("\oplus" conjunction)*
     conjunction   := unary ("\land" unary)*
     unary         := "\neg" unary | VARIABLE | "(" biconditional ")"

   The grammars bracket more than this requires, so the precedence here is
   only ever exercised by flat chains such as A \land B \land C. *)
let parse text =
  let remaining = ref (tokenize text) in
  let peek () = match !remaining with [] -> None | token :: _ -> Some token in
  let advance () =
    match !remaining with
    | [] -> raise (Reread_error "unexpected end of expression")
    | _ :: rest -> remaining := rest
  in
  let chain next operator =
    let left = ref (next ()) in
    let rec loop () =
      match peek () with
      | Some (Operator found) when found = operator ->
          advance ();
          let right = next () in
          left := Bin (operator, !left, right);
          loop ()
      | _ -> ()
    in
    loop ();
    !left
  in
  let rec biconditional () = chain implication "\\leftrightarrow"
  and implication () =
    let left = disjunction () in
    match peek () with
    | Some (Operator "\\to") ->
        advance ();
        Bin ("\\to", left, implication ())
    | _ -> left
  and disjunction () = chain exclusive "\\lor"
  and exclusive () = chain conjunction "\\oplus"
  and conjunction () = chain unary "\\land"
  and unary () =
    match peek () with
    | Some (Operator "\\neg") ->
        advance ();
        Not (unary ())
    | Some (Variable name) ->
        advance ();
        Var name
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
(* Meaning                                                             *)
(* ------------------------------------------------------------------ *)

let rec evaluate assignment = function
  | Var name -> (
      match List.assoc_opt name assignment with
      | Some value -> value
      | None -> raise (Reread_error ("no assignment shown for " ^ name)))
  | Not body -> not (evaluate assignment body)
  | Bin (operator, left, right) -> (
      (* Both sides are read before they are combined, so no evaluation is
         skipped by short-circuiting. *)
      let a = evaluate assignment left in
      let b = evaluate assignment right in
      match operator with
      | "\\land" -> a && b
      | "\\lor" -> a || b
      | "\\oplus" -> a <> b
      | "\\to" -> (not a) || b
      | "\\leftrightarrow" -> a = b
      | other -> raise (Reread_error ("unknown connective " ^ other)))

(* Every assignment over the variables of both sides, evaluated one at a
   time. This is the independent answer to "are these equivalent": no
   engine, just 2^n evaluations of each side. *)
let equivalent left right =
  let rec variables = function
    | Var name -> [ name ]
    | Not body -> variables body
    | Bin (_, l, r) -> variables l @ variables r
  in
  let names = List.sort_uniq compare (variables left @ variables right) in
  let count = 1 lsl List.length names in
  List.for_all
    (fun row ->
      let assignment = List.mapi (fun index name -> (name, row land (1 lsl index) <> 0)) names in
      evaluate assignment left = evaluate assignment right)
    (List.init count Fun.id)

(* ------------------------------------------------------------------ *)
(* Shape                                                               *)
(* ------------------------------------------------------------------ *)

let rec variables = function
  | Var name -> [ name ]
  | Not body -> variables body
  | Bin (_, left, right) -> variables left @ variables right

let variable_set expression = List.sort_uniq compare (variables expression)

(* A variable or a negated variable: what the grammars call an atom. *)
let is_atom = function Var _ | Not (Var _) -> true | _ -> false

(* Connectives as a course counts them: every binary connective, plus a
   negation applied to a compound. A negated variable is free. *)
let rec size = function
  | Var _ -> 0
  | Not (Var _) -> 0
  | Not body -> 1 + size body
  | Bin (_, left, right) -> 1 + size left + size right

let is_extra operator =
  operator = "\\to" || operator = "\\leftrightarrow" || operator = "\\oplus"

let rec extras = function
  | Var _ -> 0
  | Not body -> extras body
  | Bin (operator, left, right) ->
      (if is_extra operator then 1 else 0) + extras left + extras right

let rec stacked_negations = function
  | Var _ -> 0
  | Not (Not body) -> 1 + stacked_negations body
  | Not body -> stacked_negations body
  | Bin (_, left, right) -> stacked_negations left + stacked_negations right

(* How many variables would change the value if flipped under this
   assignment. *)
let sensitivity assignment expression =
  let here = evaluate assignment expression in
  List.length
    (List.filter
       (fun (name, _) ->
         let flipped =
           List.map (fun (n, v) -> if n = name then (n, not v) else (n, v)) assignment
         in
         List.mem name (variables expression) && evaluate flipped expression <> here)
       assignment)

(* ------------------------------------------------------------------ *)
(* Rendering                                                           *)
(* ------------------------------------------------------------------ *)

let is_chain_operator operator = operator = "\\land" || operator = "\\lor"

(* The bracketing the grammars promise: an operand is bracketed unless it is
   a variable, a negation, or the same \land / \lor as its parent, which is
   written as one flat chain. A negation brackets a compound operand only. *)
let rec render = function
  | Var name -> name
  | Not (Bin _ as body) -> "\\neg (" ^ render body ^ ")"
  | Not body -> "\\neg " ^ render body
  | Bin (operator, left, right) ->
      let operand = function
        | (Var _ | Not _) as e -> render e
        | Bin (child, _, _) as e when child = operator && is_chain_operator operator ->
            render e
        | e -> "(" ^ render e ^ ")"
      in
      operand left ^ " " ^ operator ^ " " ^ operand right

(* ------------------------------------------------------------------ *)
(* What a person would not have written                                *)
(* ------------------------------------------------------------------ *)

(* The operands of one flat chain: A \land (B \land C) and (A \land B) \land C
   are both the chain A, B, C. For any other connective, just the two sides. *)
let rec members operator = function
  | Bin (child, left, right) when child = operator && is_chain_operator operator ->
      members operator left @ members operator right
  | e -> [ e ]

(* Every departure from the two rules the grammars enforce on operands:
   no two operands over the same variables, and no variable standing alone
   in a chain that also occurs inside another operand of that chain. *)
let rec smells expression =
  match expression with
  | Var _ -> []
  | Not body -> smells body
  | Bin (operator, left, right) ->
      let chain =
        if is_chain_operator operator then members operator expression else [ left; right ]
      in
      let same_variables =
        if (not (is_chain_operator operator)) && variable_set left = variable_set right
        then [ "operands over the same variables: " ^ render expression ]
        else []
      in
      let indexed = List.mapi (fun index member -> (index, member)) chain in
      let standing_alone =
        List.concat_map
          (fun (index, member) ->
            if not (is_atom member) then []
            else
              let name = List.hd (variables member) in
              if
                List.exists
                  (fun (i, other) -> i <> index && List.mem name (variables other))
                  indexed
              then
                [
                  Printf.sprintf "%s stands alone beside an operand that contains it: %s"
                    (render member) (render expression);
                ]
              else [])
          indexed
      in
      let nested =
        if not (is_chain_operator operator) then []
        else
          List.concat_map
            (fun (index, a) ->
              match a with
              | Bin (inner, _, _) when is_chain_operator inner ->
                  List.concat_map
                    (fun (i, b) ->
                      match b with
                      | Bin (other, _, _)
                        when i <> index && other = inner
                             && List.for_all (fun v -> List.mem v (variable_set b)) (variable_set a) ->
                          [
                            Printf.sprintf "%s and %s are over nested sets of variables: %s"
                              (render a) (render b) (render expression);
                          ]
                      | _ -> [])
                    indexed
              | _ -> [])
            indexed
      in
      same_variables @ standing_alone @ nested @ List.concat_map smells chain

(* X \land (X \lor Y) or X \lor (X \land Y): the one shape that repeats an
   operand on purpose, because absorption is a law about that repetition. *)
let absorption_shaped = function
  | Bin (outer, x, (Bin (inner, _, _) as body))
    when is_chain_operator outer && is_chain_operator inner && outer <> inner -> (
      (* The inner side is read as a flat chain, so X \lor Y \lor Z has X as
         its first member whatever way the parser grouped it. *)
      match members inner body with
      | first :: _ -> render first = render x
      | [] -> false)
  | _ -> false

(* ------------------------------------------------------------------ *)
(* Reading the prompt                                                  *)
(* ------------------------------------------------------------------ *)

(* The contents of every [`...`] in the prompt, in order. *)
let math_blocks prompt =
  let length = String.length prompt in
  let rec find_from index found =
    if index + 1 >= length then List.rev found
    else if prompt.[index] = '[' && prompt.[index + 1] = '`' then
      let start = index + 2 in
      let rec close at =
        if at + 1 >= length then raise (Reread_error "unclosed [` in the prompt")
        else if prompt.[at] = '`' && prompt.[at + 1] = ']' then at
        else close (at + 1)
      in
      let stop = close start in
      find_from (stop + 2) (String.sub prompt start (stop - start) :: found)
    else find_from (index + 1) found
  in
  find_from 0 []

(* "p = \mathsf{T}" read as ("p", true); anything else as None. *)
let assignment_entry text =
  let text = String.trim text in
  if String.length text = 14 && String.sub text 1 13 = " = \\mathsf{T}" then
    Some (String.make 1 text.[0], true)
  else if String.length text = 14 && String.sub text 1 13 = " = \\mathsf{F}" then
    Some (String.make 1 text.[0], false)
  else None

(* Split a string on a separator, keeping it simple. *)
let split_on separator text =
  let separator_length = String.length separator in
  let rec go start index found =
    if index + separator_length > String.length text then
      List.rev (String.sub text start (String.length text - start) :: found)
    else if String.sub text index separator_length = separator then
      go (index + separator_length) (index + separator_length)
        (String.sub text start (index - start) :: found)
    else go start (index + 1) found
  in
  go 0 0 []

(* A block is an assignment when every comma-separated entry is one: both
   "A = \mathsf{T}" on its own and "A = \mathsf{T},\; B = \mathsf{F},\; ...". *)
let assignment_of_block block =
  let entries = List.map assignment_entry (split_on ",\\;" block) in
  if List.for_all Option.is_some entries then Some (List.filter_map Fun.id entries)
  else None

let assignment_of_blocks blocks = List.concat_map (fun block ->
    match assignment_of_block block with Some entries -> entries | None -> []) blocks

let expression_blocks blocks =
  List.filter (fun block -> assignment_of_block block = None) blocks
