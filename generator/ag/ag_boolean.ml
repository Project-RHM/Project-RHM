(* Propositional formulas: the value behind the Boolean questions.

   A formula is kept exactly as written -- nothing is simplified -- because
   the student sees it. Meaning comes from enumeration: two formulas are
   equivalent when they agree on every assignment of their variables, which
   for the three or four variables of a course question is a handful of
   evaluations. Rendering follows the bracketing a course uses, and
   [tidy_problems] names the shapes a person would have simplified away, so
   a grammar can refuse them with a single `require`. *)

type t =
  | Var of string
  | Const of bool
  | Not of t
  | And of t * t
  | Or of t * t
  | Xor of t * t
  | Imp of t * t
  | Iff of t * t

(* ------------------------------------------------------------------ *)
(* Construction                                                        *)
(* ------------------------------------------------------------------ *)

let variable name =
  let valid_start = function 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false in
  let valid_character = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
    | _ -> false
  in
  if name = "" || not (valid_start name.[0]) || not (String.for_all valid_character name)
  then invalid_arg (Printf.sprintf "%S is not a valid propositional variable" name);
  Var name

let constant truth = Const truth
let negate body = Not body

(* The negation a person writes: \neg of \neg p is p. Used where a law
   negates a part that may already be negated, such as the contrapositive of
   p \to \neg q, which a course writes q \to \neg p. *)
let negate_simply = function Not body -> body | body -> Not body
let conjunction left right = And (left, right)
let disjunction left right = Or (left, right)
let exclusive left right = Xor (left, right)
let implication left right = Imp (left, right)
let biconditional left right = Iff (left, right)

(* ------------------------------------------------------------------ *)
(* Meaning                                                             *)
(* ------------------------------------------------------------------ *)

let rec variables = function
  | Var name -> [ name ]
  | Const _ -> []
  | Not body -> variables body
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) -> variables l @ variables r

let variable_set formula = List.sort_uniq compare (variables formula)

let rec evaluate assignment = function
  | Var name -> (
      match List.assoc_opt name assignment with
      | Some truth -> truth
      | None -> invalid_arg (Printf.sprintf "no value given for variable %s" name))
  | Const truth -> truth
  | Not body -> not (evaluate assignment body)
  | And (l, r) ->
      let a = evaluate assignment l in
      let b = evaluate assignment r in
      a && b
  | Or (l, r) ->
      let a = evaluate assignment l in
      let b = evaluate assignment r in
      a || b
  | Xor (l, r) -> evaluate assignment l <> evaluate assignment r
  | Imp (l, r) ->
      let a = evaluate assignment l in
      let b = evaluate assignment r in
      (not a) || b
  | Iff (l, r) -> evaluate assignment l = evaluate assignment r

(* Every assignment over the given names, 2^n of them. *)
let assignments names =
  let count = 1 lsl List.length names in
  List.init count (fun row ->
      List.mapi (fun index name -> (name, row land (1 lsl index) <> 0)) names)

let for_all_assignments names predicate = List.for_all predicate (assignments names)

let equivalent left right =
  let names = List.sort_uniq compare (variables left @ variables right) in
  for_all_assignments names (fun assignment ->
      evaluate assignment left = evaluate assignment right)

let is_tautology formula =
  for_all_assignments (variable_set formula) (fun assignment -> evaluate assignment formula)

let is_contradiction formula =
  for_all_assignments (variable_set formula) (fun assignment ->
      not (evaluate assignment formula))

let model_count formula =
  assignments (variable_set formula)
  |> List.filter (fun assignment -> evaluate assignment formula)
  |> List.length

(* A grammar names its variables once, "p,q,r", and passes an assignment as
   a bitmask over that list: bit 0 is the first name. *)
let names_of_text text =
  String.split_on_char ',' text |> List.map String.trim |> List.filter (( <> ) "")

let assignment_of_mask names_text mask =
  List.mapi (fun index name -> (name, mask land (1 lsl index) <> 0)) (names_of_text names_text)

let evaluate_mask formula names_text mask =
  evaluate (assignment_of_mask names_text mask) formula

(* How many of the formula's variables would change the value if flipped
   under this assignment. A question whose answer survives every single flip
   can be answered without reading the whole expression. *)
let sensitivity formula names_text mask =
  let assignment = assignment_of_mask names_text mask in
  let here = evaluate assignment formula in
  variable_set formula
  |> List.filter (fun name ->
         let flipped =
           List.map (fun (other, truth) -> if other = name then (other, not truth) else (other, truth))
             assignment
         in
         evaluate flipped formula <> here)
  |> List.length

(* ------------------------------------------------------------------ *)
(* Shape                                                               *)
(* ------------------------------------------------------------------ *)

let is_atom = function Var _ | Not (Var _) -> true | _ -> false

let top = function
  | Var _ -> "var"
  | Const _ -> "const"
  | Not _ -> "not"
  | And _ -> "and"
  | Or _ -> "or"
  | Xor _ -> "xor"
  | Imp _ -> "imp"
  | Iff _ -> "iff"

(* Connectives as a course counts them: every binary connective plus a
   negation applied to a compound. A negated variable is free. *)
let rec size = function
  | Var _ | Const _ -> 0
  | Not (Var _) -> 0
  | Not body -> 1 + size body
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) -> 1 + size l + size r

let rec negations = function
  | Var _ | Const _ -> 0
  | Not body -> 1 + negations body
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) -> negations l + negations r

let rec depth = function
  | Var _ | Const _ -> 0
  | Not body -> 1 + depth body
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) -> 1 + max (depth l) (depth r)

let rec count_top name formula =
  (if top formula = name then 1 else 0)
  +
  match formula with
  | Var _ | Const _ -> 0
  | Not body -> count_top name body
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) ->
      count_top name l + count_top name r

(* ------------------------------------------------------------------ *)
(* Rendering                                                           *)
(* ------------------------------------------------------------------ *)

let latex_operator = function
  | And _ -> "\\land"
  | Or _ -> "\\lor"
  | Xor _ -> "\\oplus"
  | Imp _ -> "\\to"
  | Iff _ -> "\\leftrightarrow"
  | Var _ | Const _ | Not _ -> ""

let same_chain parent child =
  match (parent, child) with And _, And _ | Or _, Or _ -> true | _ -> false

(* The bracketing a course writes: a chain of one \land or \lor stays flat,
   every other compound operand is bracketed, and a negation needs no
   brackets around it, only around a compound it applies to. A bracket that
   already contains round brackets is written square, [p \land (p \to q)] \to q,
   which is how the course's own assignments write nested groups. *)
let wrap inner =
  if String.contains inner '(' && not (String.contains inner '[') then "[" ^ inner ^ "]"
  else "(" ^ inner ^ ")"

let rec to_latex formula =
  match formula with
  | Var name -> name
  | Const true -> "\\mathsf{T}"
  | Const false -> "\\mathsf{F}"
  | Not ((Var _ | Const _ | Not _) as body) -> "\\neg " ^ to_latex body
  | Not body -> "\\neg " ^ wrap (to_latex body)
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) ->
      let operand child =
        match child with
        | Var _ | Const _ | Not _ -> to_latex child
        | _ when same_chain formula child -> to_latex child
        | _ -> wrap (to_latex child)
      in
      operand l ^ " " ^ latex_operator formula ^ " " ^ operand r

(* For WeBWorK's contextBoolean.pl, which knows and/or/not/xor and grades by
   truth table, so the two connectives it lacks are spelled out. *)
let rec to_pg = function
  | Var name -> name
  | Const true -> "T"
  | Const false -> "F"
  | Not body -> "not (" ^ to_pg body ^ ")"
  | And (l, r) -> "(" ^ to_pg l ^ ") and (" ^ to_pg r ^ ")"
  | Or (l, r) -> "(" ^ to_pg l ^ ") or (" ^ to_pg r ^ ")"
  | Xor (l, r) -> "(" ^ to_pg l ^ ") xor (" ^ to_pg r ^ ")"
  | Imp (l, r) -> "(not (" ^ to_pg l ^ ")) or (" ^ to_pg r ^ ")"
  | Iff (l, r) -> "not ((" ^ to_pg l ^ ") xor (" ^ to_pg r ^ "))"

(* ------------------------------------------------------------------ *)
(* What a person would not have written                                *)
(* ------------------------------------------------------------------ *)

(* The operands of one flat chain: p \land (q \land r) and (p \land q) \land r
   are both the chain p, q, r. For any other connective, just the two sides. *)
let rec members parent formula =
  match formula with
  | (And (l, r) | Or (l, r)) when same_chain parent formula -> members parent l @ members parent r
  | _ -> [ formula ]

let intersects a b = List.exists (fun x -> List.mem x b) a
let subset a b = List.for_all (fun x -> List.mem x b) a

(* Every departure from the shapes a course writes, as readable complaints.
   Empty means tidy. The rules:
     - no constant, and no negation of a negation;
     - the two sides of \oplus, \to, \leftrightarrow are not over the same
       variables (p \to \neg p, (p \land q) \leftrightarrow (q \land p));
     - in a chain of \land or \lor, a variable standing alone never occurs
       inside another operand of the chain (p \land (p \lor q), p \lor q \lor p);
     - two compound operands of a chain that share a connective are not over
       nested variable sets ((p \land q \land r) \lor (r \land p)). *)
let rec tidy_problems formula =
  match formula with
  | Var _ -> []
  | Const _ -> [ "a constant in the expression: " ^ to_latex formula ]
  | Not (Not _) -> ("a negation of a negation: " ^ to_latex formula) :: tidy_problems_below formula
  | Not body -> tidy_problems body
  | And _ | Or _ ->
      let chain = members formula formula in
      let indexed = List.mapi (fun index member -> (index, member)) chain in
      let others index = List.filter_map (fun (i, m) -> if i = index then None else Some m) indexed in
      let standing_alone =
        List.concat_map
          (fun (index, member) ->
            if not (is_atom member) then []
            else
              let name = List.hd (variables member) in
              if List.exists (fun other -> List.mem name (variables other)) (others index) then
                [
                  Printf.sprintf "%s stands alone beside an operand that contains it: %s"
                    (to_latex member) (to_latex formula);
                ]
              else [])
          indexed
      in
      (* Only chains nest into chains: two implications over the same
         variables, (p \to \neg q) \lor (q \to \neg p), are a question a course
         does set. *)
      let nested =
        List.concat_map
          (fun (index, a) ->
            if is_atom a || not (top a = "and" || top a = "or") then []
            else
              List.concat_map
                (fun b ->
                  if (not (is_atom b)) && top a = top b && subset (variable_set a) (variable_set b)
                  then
                    [
                      Printf.sprintf "%s and %s are over nested sets of variables: %s"
                        (to_latex a) (to_latex b) (to_latex formula);
                    ]
                  else [])
                (others index))
          indexed
      in
      standing_alone @ nested @ List.concat_map tidy_problems chain
  | Xor (l, r) | Imp (l, r) | Iff (l, r) ->
      let same =
        if variable_set l = variable_set r then
          [ "both sides over the same variables: " ^ to_latex formula ]
        else []
      in
      let alone =
        List.concat_map
          (fun (atom, other) ->
            if is_atom atom && intersects (variables atom) (variables other) then
              [
                Printf.sprintf "%s stands alone beside an operand that contains it: %s"
                  (to_latex atom) (to_latex formula);
              ]
            else [])
          [ (l, r); (r, l) ]
      in
      same @ alone @ tidy_problems l @ tidy_problems r

and tidy_problems_below = function
  | Not body -> tidy_problems body
  | other -> tidy_problems other

let is_tidy formula = tidy_problems formula = []

(* ------------------------------------------------------------------ *)
(* Rewriting                                                           *)
(* ------------------------------------------------------------------ *)

(* The conditional-disjunction equivalence applied everywhere: p \to q
   becomes \neg p \lor q, and p \leftrightarrow q becomes
   (\neg p \lor q) \land (\neg q \lor p). A negation that meets a negation
   cancels, so the result reads as a person would write it. *)
let rec without_conditionals formula =
  match formula with
  | Var _ | Const _ -> formula
  | Not body -> negate_simply (without_conditionals body)
  | And (l, r) -> And (without_conditionals l, without_conditionals r)
  | Or (l, r) -> Or (without_conditionals l, without_conditionals r)
  | Xor (l, r) -> Xor (without_conditionals l, without_conditionals r)
  | Imp (l, r) ->
      Or (negate_simply (without_conditionals l), without_conditionals r)
  | Iff (l, r) ->
      let l = without_conditionals l and r = without_conditionals r in
      And (Or (negate_simply l, r), Or (negate_simply r, l))

(* ------------------------------------------------------------------ *)
(* Truth tables                                                        *)
(* ------------------------------------------------------------------ *)

(* The columns a course draws: the variables, then every compound
   subformula in the order it is built, each once. A negated variable gets a
   column too, as \neg q does in a table for p \oplus \neg q. *)
let table_columns formulas =
  let seen = ref [] in
  let add formula = if not (List.mem formula !seen) then seen := formula :: !seen in
  let rec walk formula =
    match formula with
    | Var _ | Const _ -> ()
    | Not body ->
        walk body;
        add formula
    | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) ->
        walk l;
        walk r;
        add formula
  in
  List.iter walk formulas;
  List.rev !seen

let table_variables formulas =
  List.sort_uniq compare (List.concat_map variables formulas)

(* Rows in the course's order: all true first, then counting down, so with
   p, q, r the first row is T T T and the last F F F. *)
let table_rows formulas =
  let names = table_variables formulas in
  let count = List.length names in
  List.init (1 lsl count) (fun row ->
      List.mapi (fun index name -> (name, row land (1 lsl (count - 1 - index)) = 0)) names)

(* ------------------------------------------------------------------ *)
(* A looser tidiness                                                   *)
(* ------------------------------------------------------------------ *)

(* Some questions repeat a variable on purpose: (p \lor q) \to \neg p is a
   course exercise. In the course's assignments the repetition is always
   across a conditional, biconditional or exclusive or, never inside one
   chain of \land or \lor. So inside a chain a variable standing alone may
   not occur in another member (r \land (q \lor r \lor p) is absorption,
   (p \to q) \land p a redundancy), and across the other connectives only a
   literal against itself or its negation is refused (p \to \neg p). A
   double negation or a constant is never plain. *)
let rec plain_problems formula =
  let literal_name = function Var n -> Some n | Not (Var n) -> Some n | _ -> None in
  match formula with
  | Var _ -> []
  | Const _ -> [ "a constant in the expression: " ^ to_latex formula ]
  | Not (Not _) -> [ "a negation of a negation: " ^ to_latex formula ]
  | Not body -> plain_problems body
  | And _ | Or _ ->
      let chain = members formula formula in
      let indexed = List.mapi (fun index member -> (index, member)) chain in
      let standing_alone =
        List.concat_map
          (fun (index, member) ->
            match literal_name member with
            | None -> []
            | Some name ->
                if
                  List.exists
                    (fun (i, other) -> i <> index && List.mem name (variables other))
                    indexed
                then
                  [
                    Printf.sprintf "%s appears again in the same chain: %s" (to_latex member)
                      (to_latex formula);
                  ]
                else [])
          indexed
      in
      standing_alone @ List.concat_map plain_problems chain
  | Xor (l, r) | Iff (l, r) ->
      (* Symmetric connectives read like chains: nothing standing alone on one
         side occurs on the other, as in \neg q \oplus (r \oplus \neg q). *)
      let alone side other =
        match literal_name side with
        | Some name when List.mem name (variables other) ->
            [ Printf.sprintf "%s appears on both sides: %s" (to_latex side) (to_latex formula) ]
        | _ -> []
      in
      alone l r @ alone r l @ plain_problems l @ plain_problems r
  | Imp (l, r) ->
      (* Across a conditional a variable may recur, but with the other sign,
         as in (p \lor q) \to \neg p and (p \to \neg q) \to (\neg p \to q). The
         same literal on both sides, (p \to q) \to q, is refused. *)
      let rec literals positive = function
        | Var n -> [ (n, positive) ]
        | Const _ -> []
        | Not body -> literals (not positive) body
        | And (a, b) | Or (a, b) | Xor (a, b) | Imp (a, b) | Iff (a, b) ->
            literals positive a @ literals positive b
      in
      let alone side other =
        match side with
        | Var _ | Not (Var _) -> (
            match literals true side with
            | [ literal ] when List.mem literal (literals true other) ->
                [ Printf.sprintf "%s appears with the same sign on both sides: %s" (to_latex side) (to_latex formula) ]
            | [ (name, _) ] when (match (l, r) with (Var _ | Not (Var _)), (Var _ | Not (Var _)) -> true | _ -> false)
                                 && List.mem_assoc name (literals true other) ->
                [ "a literal against itself or its negation: " ^ to_latex formula ]
            | _ -> [])
        | _ -> []
      in
      alone l r @ alone r l @ plain_problems l @ plain_problems r

let is_plain formula = plain_problems formula = []

(* A proper part that is always true or always false, as in
   q \to (\neg q \to \neg p), whose inner conditional holds whatever q is.
   A person setting the question would have simplified it away. *)
let has_trivial_part formula =
  let rec parts = function
    | Var _ | Const _ -> []
    | Not body -> body :: parts body
    | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) -> (l :: parts l) @ (r :: parts r)
  in
  List.exists
    (fun part ->
      match part with
      | Var _ | Const _ -> false
      | _ -> is_tautology part || is_contradiction part)
    (parts formula)

(* The variables in the order they are first read, left to right. A person
   writes (p \to q) \to r, not r \leftrightarrow (q \to p): the first time
   each variable appears, it appears in alphabetical order. *)
let first_occurrences formula =
  let seen = ref [] in
  let rec walk = function
    | Var name -> if not (List.mem name !seen) then seen := name :: !seen
    | Const _ -> ()
    | Not body -> walk body
    | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) ->
        walk l;
        walk r
  in
  walk formula;
  List.rev !seen

let in_reading_order formula =
  let names = first_occurrences formula in
  names = List.sort compare names
