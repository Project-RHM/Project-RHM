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

(* ------------------------------------------------------------------ *)
(* Laws as rewrites, and derivations                                    *)
(* ------------------------------------------------------------------ *)

(* A law is a pair of patterns over the metavariables ?A, ?B, ?C. A course
   variable is lower case, so a metavariable can never be confused with one.
   Applying a law at a subformula matches one pattern there and replaces it
   with the other, instantiated; a negation that meets a negation cancels,
   as a person would write the result.

   A derivation applies a few laws in turn, so two propositions a few steps
   apart are exactly what a lecturer writes when setting "show that these
   are equivalent". A wrong derivation has one step replaced by a classic
   mistake -- the converse, De Morgan without switching the connective --
   which is how a lecturer sets a pair that looks equivalent but is not. *)

type rule = {
  law : string;  (* the name a course gives the law *)
  weight : int;
  from_ : t;
  into : t;
  (* A pattern \neg ?A normally matches only a negation. A loose rule lets it
     match anything, binding ?A to the negation of what it found, so that
     the definition of the conditional read backwards turns p \lor q into
     \neg p \to q, and De Morgan read backwards turns p \lor \neg q into
     \neg (\neg p \land q). *)
  loose : bool;
}

let meta name = Var ("?" ^ name)
let is_meta name = String.length name > 0 && name.[0] = '?'
let ma = meta "A" and mb = meta "B" and mc = meta "C"

let rec pattern_match ~loose bindings pattern term =
  match (pattern, term) with
  | Var name, _ when is_meta name -> (
      match List.assoc_opt name bindings with
      | Some bound -> if bound = term then Some bindings else None
      | None -> Some ((name, term) :: bindings))
  | Not (Var name), _ when loose && is_meta name -> (
      match term with
      | Not inner -> pattern_match ~loose bindings (Var name) inner
      | _ -> pattern_match ~loose bindings (Var name) (Not term))
  | Not p, Not t -> pattern_match ~loose bindings p t
  | And (p1, p2), And (t1, t2)
  | Or (p1, p2), Or (t1, t2)
  | Xor (p1, p2), Xor (t1, t2)
  | Imp (p1, p2), Imp (t1, t2)
  | Iff (p1, p2), Iff (t1, t2) -> (
      match pattern_match ~loose bindings p1 t1 with
      | Some bindings -> pattern_match ~loose bindings p2 t2
      | None -> None)
  | Var a, Var b -> if a = b then Some bindings else None
  | Const a, Const b -> if a = b then Some bindings else None
  | _ -> None

let rec instantiate bindings = function
  | Var name when is_meta name -> List.assoc name bindings
  | (Var _ | Const _) as leaf -> leaf
  | Not body -> negate_simply (instantiate bindings body)
  | And (l, r) -> And (instantiate bindings l, instantiate bindings r)
  | Or (l, r) -> Or (instantiate bindings l, instantiate bindings r)
  | Xor (l, r) -> Xor (instantiate bindings l, instantiate bindings r)
  | Imp (l, r) -> Imp (instantiate bindings l, instantiate bindings r)
  | Iff (l, r) -> Iff (instantiate bindings l, instantiate bindings r)

(* The same pattern with the operands of a top \land or \lor swapped, so
   A \land (B \lor C) also matches (B \lor C) \land A. *)
let commuted = function
  | And (l, r) -> [ And (l, r); And (r, l) ]
  | Or (l, r) -> [ Or (l, r); Or (r, l) ]
  | other -> [ other ]

let apply_here rule term =
  List.filter_map
    (fun pattern ->
      match pattern_match ~loose:rule.loose [] pattern term with
      | Some bindings -> Some (instantiate bindings rule.into)
      | None -> None)
    (commuted rule.from_)

(* Every result of applying [rule] once, anywhere in [formula]. A result
   that puts a negation directly on a negation is cancelled, as a person
   writes it -- unless [collapse] is false, when the double negation is kept
   so that cancelling it counts as a step of its own. *)
let rec apply_anywhere ?(collapse = true) rule formula =
  let apply_anywhere = apply_anywhere ~collapse in
  let here = apply_here rule formula in
  let below =
    match formula with
    | Var _ | Const _ -> []
    | Not body ->
        List.map (fun inner -> if collapse then negate_simply inner else Not inner) (apply_anywhere rule body)
    | And (l, r) ->
        List.map (fun l -> And (l, r)) (apply_anywhere rule l)
        @ List.map (fun r -> And (l, r)) (apply_anywhere rule r)
    | Or (l, r) ->
        List.map (fun l -> Or (l, r)) (apply_anywhere rule l)
        @ List.map (fun r -> Or (l, r)) (apply_anywhere rule r)
    | Xor (l, r) ->
        List.map (fun l -> Xor (l, r)) (apply_anywhere rule l)
        @ List.map (fun r -> Xor (l, r)) (apply_anywhere rule r)
    | Imp (l, r) ->
        List.map (fun l -> Imp (l, r)) (apply_anywhere rule l)
        @ List.map (fun r -> Imp (l, r)) (apply_anywhere rule r)
    | Iff (l, r) ->
        List.map (fun l -> Iff (l, r)) (apply_anywhere rule l)
        @ List.map (fun r -> Iff (l, r)) (apply_anywhere rule r)
  in
  List.sort_uniq compare (here @ below)

let law ?(loose = false) name weight from_ into = { law = name; weight; from_; into; loose }

(* The laws, each usable in both directions. Weights are set from measured
   use, not intent: the definition of the conditional applies to almost any
   disjunction when read backwards, so a small weight still makes it the
   most common step, while De Morgan and distribution need a shape that is
   rarer and so carry more weight. *)
let equivalence_laws =
  [
    law ~loose:true "Definition of Conditional" 2 (Imp (ma, mb)) (Or (Not ma, mb));
    law "Contrapositive" 2 (Imp (ma, mb)) (Imp (Not mb, Not ma));
    law ~loose:true "De Morgan's laws" 5 (Not (And (ma, mb))) (Or (Not ma, Not mb));
    law ~loose:true "De Morgan's laws" 5 (Not (Or (ma, mb))) (And (Not ma, Not mb));
    law "Negation of a conditional" 2 (Not (Imp (ma, mb))) (And (ma, Not mb));
    law "Distributive laws" 3 (And (ma, Or (mb, mc))) (Or (And (ma, mb), And (ma, mc)));
    law "Distributive laws" 3 (Or (ma, And (mb, mc))) (And (Or (ma, mb), Or (ma, mc)));
    law "Exportation" 3 (Imp (And (ma, mb), mc)) (Imp (ma, Imp (mb, mc)));
    law "Conditional with a conjunction" 3 (Imp (ma, And (mb, mc))) (And (Imp (ma, mb), Imp (ma, mc)));
    law "Conditional with a disjunction" 1 (Imp (ma, Or (mb, mc))) (Or (Imp (ma, mb), Imp (ma, mc)));
    law "Conditional with a disjunction" 3 (Imp (Or (ma, mb), mc)) (And (Imp (ma, mc), Imp (mb, mc)));
    law "Conditional with a conjunction" 1 (Imp (And (ma, mb), mc)) (Or (Imp (ma, mc), Imp (mb, mc)));
    law "Definition of Biconditional" 1 (Iff (ma, mb)) (And (Imp (ma, mb), Imp (mb, ma)));
    law "Negation of a biconditional" 1 (Not (Iff (ma, mb))) (Iff (ma, Not mb));
    law "Definition of Exclusive or" 1 (Xor (ma, mb)) (Not (Iff (ma, mb)));
    law "Distributive and Negation laws" 1 (Or (ma, And (Not ma, mb))) (Or (ma, mb));
    law "Distributive and Negation laws" 1 (And (ma, Or (Not ma, mb))) (And (ma, mb));
  ]

let reversed rule = { rule with from_ = rule.into; into = rule.from_ }

(* Most laws are used both ways. The two that remove a redundancy,
   p \lor (\neg p \land q) \equiv p \lor q, only simplify: read backwards
   they plant a redundancy in any disjunction, and the result reads as
   contrived as r \to [(r \to p) \to q]. *)
let simplify_only = [ "Distributive and Negation laws" ]

let correct_rules =
  List.concat_map
    (fun rule -> if List.mem rule.law simplify_only then [ rule ] else [ rule; reversed rule ])
    equivalence_laws

(* The mistakes a student makes, one way only. *)
let mistake_rules =
  [
    law "Converse (mistake)" 3 (Imp (ma, mb)) (Imp (mb, ma));
    law "Inverse (mistake)" 2 (Imp (ma, mb)) (Imp (Not ma, Not mb));
    law "De Morgan without switching (mistake)" 2 (Not (And (ma, mb))) (And (Not ma, Not mb));
    law "De Morgan without switching (mistake)" 2 (Not (Or (ma, mb))) (Or (Not ma, Not mb));
    law "De Morgan with a negation dropped (mistake)" 2 (Not (And (ma, mb))) (Or (Not ma, mb));
    law "Negated conditional as conditional (mistake)" 1 (Not (Imp (ma, mb))) (Imp (Not ma, Not mb));
    law "Conditional as the wrong disjunction (mistake)" 2 (Imp (ma, mb)) (Or (ma, Not mb));
    law "Distribution over one operand only (mistake)" 1 (And (ma, Or (mb, mc))) (Or (And (ma, mb), mc));
    law "Conditional with the wrong connective (mistake)" 1 (Imp (ma, Or (mb, mc))) (And (Imp (ma, mb), Imp (ma, mc)));
    law "Exportation with the wrong brackets (mistake)" 1 (Imp (And (ma, mb), mc)) (Imp (Imp (ma, mb), mc));
    law "Regrouping a conditional (mistake)" 1 (Imp (ma, Imp (mb, mc))) (Imp (Imp (ma, mb), mc));
    law "Conditional with a disjunction, wrong connective (mistake)" 1 (Imp (Or (ma, mb), mc)) (Or (Imp (ma, mc), Imp (mb, mc)));
  ]

(* ---- what a side of a question may look like ---- *)

(* ---- how far apart two sides are ---- *)

(* A form that ignores the order of operands of \land, \lor, \oplus and
   \leftrightarrow, so p \land q and q \land p count as the same. *)
let rec canonical formula =
  let by_text a b = compare (to_latex a) (to_latex b) in
  let rebuild make = function
    | [] -> invalid_arg "canonical: empty chain"
    | first :: rest -> List.fold_left make first rest
  in
  match formula with
  | Var _ | Const _ -> formula
  | Not body -> Not (canonical body)
  | And _ -> members formula formula |> List.map canonical |> List.sort by_text |> rebuild (fun l r -> And (l, r))
  | Or _ -> members formula formula |> List.map canonical |> List.sort by_text |> rebuild (fun l r -> Or (l, r))
  | Xor (l, r) -> ( match List.sort by_text [ canonical l; canonical r ] with [ a; b ] -> Xor (a, b) | _ -> formula)
  | Iff (l, r) -> ( match List.sort by_text [ canonical l; canonical r ] with [ a; b ] -> Iff (a, b) | _ -> formula)
  | Imp (l, r) -> Imp (canonical l, canonical r)

let same_shape a b = canonical a = canonical b

(* ---- what a side of a question may look like ---- *)

(* The operands of every \land / \lor chain as literals: a literal twice, or
   beside its own negation, in one chain (p \lor q \lor p, p \land \neg p) is
   something a person would never leave in a question. *)
let rec chain_literal_clash formula =
  match formula with
  | Var _ | Const _ -> false
  | Not body -> chain_literal_clash body
  | And _ | Or _ ->
      let chain = members formula formula in
      let names =
        List.filter_map (function Var n -> Some n | Not (Var n) -> Some n | _ -> None) chain
      in
      List.length names <> List.length (List.sort_uniq compare names)
      || List.exists chain_literal_clash chain
  | Xor (l, r) | Imp (l, r) | Iff (l, r) -> chain_literal_clash l || chain_literal_clash r

(* Fair for a side of an equivalence question: no constant, no double
   negation, no literal clashing in a chain, no part that is always true or
   always false. Unlike [is_tidy] it allows the shapes a derivation creates
   on purpose, such as p \lor (\neg p \land q). *)
let rec has_constant = function
  | Const _ -> true
  | Var _ -> false
  | Not body -> has_constant body
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) -> has_constant l || has_constant r

let rec has_double_negation = function
  | Not (Not _) -> true
  | Var _ | Const _ -> false
  | Not body -> has_double_negation body
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) ->
      has_double_negation l || has_double_negation r

(* \neg (\neg r \to \neg q), \neg (\neg p \land \neg q): a negation over a
   connective between two negated literals, which a person would have
   rewritten before setting the question. *)
let rec negated_negatives = function
  | Not (And (Not (Var _), Not (Var _)) | Or (Not (Var _), Not (Var _)) | Imp (Not (Var _), Not (Var _))
        | Iff (Not (Var _), Not (Var _)) | Xor (Not (Var _), Not (Var _))) -> true
  | Var _ | Const _ -> false
  | Not body -> negated_negatives body
  | And (l, r) | Or (l, r) | Xor (l, r) | Imp (l, r) | Iff (l, r) -> negated_negatives l || negated_negatives r

(* p \to \neg p, q \leftrightarrow q: a connective between a literal and
   itself or its negation. *)
let rec literal_against_itself = function
  | Imp (l, r) | Iff (l, r) | Xor (l, r) | And (l, r) | Or (l, r) as node -> (
      let name = function Var n | Not (Var n) -> Some n | _ -> None in
      (match (name l, name r) with Some a, Some b when a = b -> true | _ -> false)
      || (ignore node; literal_against_itself l || literal_against_itself r))
  | Not body -> literal_against_itself body
  | Var _ | Const _ -> false

(* (p \to q) \land (p \to q): the same part twice in one chain, or on both
   sides of one connective, up to the order of operands. *)
let rec repeated_part formula =
  match formula with
  | Var _ | Const _ -> false
  | Not body -> repeated_part body
  | And _ | Or _ ->
      let chain = List.map canonical (members formula formula) in
      List.length chain <> List.length (List.sort_uniq compare chain)
      || List.exists repeated_part (members formula formula)
  | Xor (l, r) | Imp (l, r) | Iff (l, r) -> canonical l = canonical r || repeated_part l || repeated_part r

let is_fair formula =
  (not (repeated_part formula))
  && (not (literal_against_itself formula))
  && (not (negated_negatives formula))
  && (not (has_constant formula))
  && (not (has_double_negation formula))
  && (not (chain_literal_clash formula))
  && not (has_trivial_part formula)


(* ---- derivations ---- *)

let pick_weighted state rules_with_results =
  let total = List.fold_left (fun sum (rule, _) -> sum + rule.weight) 0 rules_with_results in
  if total <= 0 then None else
  let target = Random.State.int state total in
  let rec walk acc = function
    | [] -> None
    | (rule, results) :: rest ->
        if target < acc + rule.weight then
          Some (rule, List.nth results (Random.State.int state (List.length results)))
        else walk (acc + rule.weight) rest
  in
  walk 0 rules_with_results

(* [steps] laws applied in turn from [formula], chosen with [seed]; with
   [mistake_at = k], the k-th step (0-based) is a mistake instead. A step is
   only taken if its result is fair, has at most two negations and five
   connectives, and has not been seen before in the chain, so a derivation
   never walks back on itself. The chain may be shorter than asked if no
   step fits; callers check the result. *)
let derivation ?(mistake_at = -1) formula steps seed =
  let state = Random.State.make [| seed |] in
  let rec go current taken visited chain =
    if taken = steps then List.rev chain
    else
      let rules = if taken = mistake_at then mistake_rules else correct_rules in
      let options =
        List.filter_map
          (fun rule ->
            let results =
              apply_anywhere rule current
              |> List.filter (fun result ->
                     is_fair result && negations result <= 2 && size result <= 5
                     && not (List.mem result visited))
            in
            if results = [] then None else Some (rule, results))
          rules
      in
      match pick_weighted state options with
      | None -> List.rev chain
      | Some (rule, result) -> go result (taken + 1) (result :: visited) ((rule.law, result) :: chain)
  in
  go formula 0 [ formula ] []

let derive ?mistake_at formula steps seed =
  match List.rev (derivation ?mistake_at formula steps seed) with
  | (_, last) :: _ -> last
  | [] -> formula

(* One law or one classic mistake, applied once anywhere, turns one side
   into the other. Such a pair is a recognition exercise -- spot the
   converse -- not a derivation. *)
let one_step_apart a b =
  let target_b = canonical b and target_a = canonical a in
  List.exists
    (fun rule ->
      List.exists (fun result -> canonical result = target_b) (apply_anywhere ~collapse:false rule a)
      || List.exists (fun result -> canonical result = target_a) (apply_anywhere ~collapse:false rule b))
    (correct_rules @ mistake_rules)

let table_width formulas =
  List.length (List.filter (function Var _ -> false | _ -> true) (table_columns formulas))
