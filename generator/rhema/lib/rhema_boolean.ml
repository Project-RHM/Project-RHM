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

(* The same proposition written with not, and, or alone: a conditional
   becomes a disjunction, a biconditional a disjunction of two conjunctions,
   an exclusive or likewise. No simplification is attempted. *)
let rec without_conditionals = function
  | (Var _ | Const _) as leaf -> leaf
  | Not body -> Not (without_conditionals body)
  | And (l, r) -> And (without_conditionals l, without_conditionals r)
  | Or (l, r) -> Or (without_conditionals l, without_conditionals r)
  | Imp (l, r) -> Or (negated (without_conditionals l), without_conditionals r)
  | Iff (l, r) ->
      let l = without_conditionals l and r = without_conditionals r in
      Or (And (l, r), And (negated l, negated r))
  | Xor (l, r) ->
      let l = without_conditionals l and r = without_conditionals r in
      Or (And (l, negated r), And (negated l, r))

(* Negate without stacking: the negation of a negation is its body. *)
and negated = function Not body -> body | formula -> Not formula

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
   brackets around it, only around a compound it applies to. *)
let rec to_latex formula =
  match formula with
  | Var name -> name
  | Const true -> "\\mathsf{T}"
  | Const false -> "\\mathsf{F}"
  | Not ((Var _ | Const _ | Not _) as body) -> "\\neg " ^ to_latex body
  | Not body -> "\\neg (" ^ to_latex body ^ ")"
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) ->
      let operand child =
        match child with
        | Var _ | Const _ | Not _ -> to_latex child
        | _ when same_chain formula child -> to_latex child
        | _ -> "(" ^ to_latex child ^ ")"
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
