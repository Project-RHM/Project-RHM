(* ag_boolean_core_test.ml — the propositional formula value on its own.

   The grammars lean on this module for three things: that equivalence is
   decided by enumeration, that the rendering is the one a course writes,
   and that [tidy_problems] names exactly the shapes a person would not set.
   Each is pinned here with small hand-checked cases. *)

open Ag_boolean

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let check name condition = if not condition then fail name

let p = variable "p" and q = variable "q" and r = variable "r"

(* ---- meaning ---- *)
let () =
  check "De Morgan holds" (equivalent (negate (conjunction p q)) (disjunction (negate p) (negate q)));
  check "converse fails" (not (equivalent (implication p q) (implication q p)));
  check "contrapositive holds" (equivalent (implication p q) (implication (negate q) (negate p)));
  check "\\to is not associative"
    (not (equivalent (implication p (implication q r)) (implication (implication p q) r)));
  check "\\leftrightarrow is associative"
    (equivalent (biconditional p (biconditional q r)) (biconditional (biconditional p q) r));
  check "\\oplus is associative"
    (equivalent (exclusive p (exclusive q r)) (exclusive (exclusive p q) r));
  check "different variables are compared over their union"
    (not (equivalent p q));
  check "tautology" (is_tautology (disjunction p (negate p)));
  check "contradiction" (is_contradiction (conjunction p (negate p)));
  check "model count" (model_count (disjunction p q) = 3)

(* ---- assignments as masks ---- *)
let () =
  (* names "p,q,r": bit 0 = p, bit 1 = q, bit 2 = r *)
  check "evaluate mask 1 (p only)" (evaluate_mask (conjunction p q) "p,q,r" 1 = false);
  check "evaluate mask 3 (p and q)" (evaluate_mask (conjunction p q) "p,q,r" 3 = true);
  check "evaluate mask 4 (r only) on p -> q" (evaluate_mask (implication p q) "p,q,r" 4 = true);
  (* p \land q at p=T,q=T: flipping either changes it *)
  check "sensitivity 2" (sensitivity (conjunction p q) "p,q,r" 3 = 2);
  (* p \land q at p=F,q=F: nothing changes it *)
  check "sensitivity 0" (sensitivity (conjunction p q) "p,q,r" 0 = 0);
  (* p \lor q at p=T,q=F: only p matters *)
  check "sensitivity 1" (sensitivity (disjunction p q) "p,q,r" 1 = 1);
  (match evaluate_mask (conjunction p r) "p,q" 1 with
  | exception Invalid_argument _ -> ()
  | _ -> fail "a variable outside the names should be an error")

(* ---- rendering ---- *)
let () =
  let expect formula text =
    let got = to_latex formula in
    if got <> text then fail (Printf.sprintf "rendered %S, expected %S" got text)
  in
  expect (conjunction p (conjunction q r)) "p \\land q \\land r";
  expect (conjunction (conjunction p q) r) "p \\land q \\land r";
  expect (disjunction p (conjunction q r)) "p \\lor (q \\land r)";
  expect (implication (implication p q) r) "(p \\to q) \\to r";
  expect (implication p (implication q r)) "p \\to (q \\to r)";
  expect (negate (conjunction p q)) "\\neg (p \\land q)";
  expect (negate p) "\\neg p";
  expect (negate (negate (conjunction p q))) "\\neg \\neg (p \\land q)";
  expect (conjunction (negate (disjunction p q)) r) "\\neg (p \\lor q) \\land r";
  expect (biconditional (negate p) (disjunction q r)) "\\neg p \\leftrightarrow (q \\lor r)";
  expect (exclusive p r) "p \\oplus r";
  check "pg spelling uses words"
    (to_pg (implication p (negate q)) = "(not (p)) or (not (q))")

(* ---- tidiness ---- *)
let () =
  let tidy formula = check ("tidy: " ^ to_latex formula) (is_tidy formula) in
  let untidy formula = check ("untidy: " ^ to_latex formula) (not (is_tidy formula)) in
  tidy (conjunction (disjunction p q) (disjunction (negate p) r));
  tidy (implication (conjunction p q) (disjunction (negate r) (negate p)));
  tidy (negate (conjunction p (disjunction q r)));
  tidy (disjunction (implication p (negate q)) (implication q (negate p)));
  tidy (conjunction p (conjunction q r));
  untidy (conjunction p p);
  untidy (disjunction p (negate p));
  untidy (conjunction p (conjunction p q));
  untidy (disjunction (disjunction p q) (disjunction q r));
  untidy (conjunction p (disjunction p q));
  untidy (implication p (conjunction p q));
  untidy (biconditional (conjunction p q) (conjunction q p));
  untidy (negate (negate p));
  untidy (disjunction (conjunction p (conjunction q r)) (conjunction r p));
  untidy (conjunction p (constant true));
  check "size counts binary connectives and compound negations"
    (size (negate (conjunction (negate p) q)) = 2);
  check "negations counts every \\neg" (negations (negate (conjunction (negate p) q)) = 2);
  check "top" (top (implication p q) = "imp")

(* ---- the course's conventions, added for the MATH2003 question types ---- *)
let () =
  let expect formula text =
    let got = to_latex formula in
    if got <> text then fail (Printf.sprintf "rendered %S, expected %S" got text)
  in
  (* a bracket around round brackets is square, as the assignments write it *)
  expect (implication (conjunction p (implication p q)) q) "[p \\land (p \\to q)] \\to q";
  expect (implication (conjunction (conjunction (disjunction p q) (implication p r)) (implication q r)) r)
    "[(p \\lor q) \\land (p \\to r) \\land (q \\to r)] \\to r";
  expect (negate (disjunction p (conjunction q r))) "\\neg [p \\lor (q \\land r)]";
  (* removing conditionals *)
  let no_arrows f = not (List.mem (top f) [ "imp"; "iff" ]) && count_top "imp" f = 0 && count_top "iff" f = 0 in
  List.iter
    (fun f ->
      let g = without_conditionals f in
      check ("equivalent without conditionals: " ^ to_latex f) (equivalent f g);
      check ("no conditional left: " ^ to_latex g) (no_arrows g))
    [ implication (disjunction p q) (negate p);
      implication (implication p (negate q)) (implication (negate p) q);
      biconditional p (conjunction q r) ];
  check "a negation meeting a negation cancels"
    (without_conditionals (implication (negate p) q) = disjunction p q);
  (* truth tables: columns in build order, rows T..T first *)
  check "columns"
    (List.map to_latex (table_columns [ exclusive p (negate q) ]) = [ "\\neg q"; "p \\oplus \\neg q" ]);
  check "columns of two sides: p \\to q, \\neg p, \\neg p \\lor q"
    (List.length (table_columns [ implication p q; disjunction (negate p) q ]) = 3);
  (match table_rows [ conjunction p q ] with
  | [ first; second; third; last ] ->
      check "row 1 is T T" (first = [ ("p", true); ("q", true) ]);
      check "row 2 is T F" (second = [ ("p", true); ("q", false) ]);
      check "row 3 is F T" (third = [ ("p", false); ("q", true) ]);
      check "row 4 is F F" (last = [ ("p", false); ("q", false) ])
  | _ -> fail "a two-variable table has four rows");
  (* the looser tidiness of the course's exercises *)
  let plain f = check ("plain: " ^ to_latex f) (is_plain f) in
  let not_plain f = check ("not plain: " ^ to_latex f) (not (is_plain f)) in
  plain (implication (disjunction p q) (negate p));
  plain (implication (implication p (negate q)) (implication (negate p) q));
  plain (implication (conjunction p q) r);
  not_plain (implication p (negate p));
  not_plain (conjunction r (disjunction (disjunction q r) p));
  not_plain (conjunction (implication p q) p);
  not_plain (exclusive (negate q) (exclusive r (negate q)));
  not_plain (implication (implication p q) q);
  not_plain (negate (negate p));
  (* reading order and trivial parts *)
  check "in order" (in_reading_order (implication (implication p q) r));
  check "out of order" (not (in_reading_order (biconditional r (implication q p))));
  check "trivial part"
    (has_trivial_part (implication (implication q (implication (negate q) (negate p))) p));
  check "no trivial part" (not (has_trivial_part (implication (disjunction p q) (negate p))))

(* ---- laws as rewrites, and derivations ---- *)
let () =
  (* Every law, in both directions, preserves meaning wherever it applies. *)
  let samples =
    [ implication p (disjunction q r); negate (conjunction p q); conjunction p (disjunction q r);
      implication (conjunction p q) r; biconditional p q; disjunction p (conjunction (negate p) q);
      negate (implication p q); implication (disjunction p q) r; exclusive p q;
      disjunction (negate p) (disjunction q r); conjunction (implication p q) (implication q p) ]
  in
  List.iter
    (fun rule ->
      List.iter
        (fun formula ->
          List.iter
            (fun result ->
              if not (equivalent formula result) then
                fail (Printf.sprintf "%s turns %s into %s" rule.law (to_latex formula) (to_latex result)))
            (apply_anywhere rule formula))
        samples)
    correct_rules;
  (* Every mistake changes the meaning of some sample it applies to. *)
  List.iter
    (fun rule ->
      let changes =
        List.exists
          (fun formula -> List.exists (fun result -> not (equivalent formula result)) (apply_anywhere rule formula))
          (samples @ [ implication p (implication q r); negate (disjunction p q) ])
      in
      if not changes then fail ("the mistake never changes a meaning: " ^ rule.law))
    mistake_rules;
  (* Derivations: each correct step keeps the meaning; a wrong one loses it
     somewhere; no chain revisits a formula. *)
  let lost = ref 0 in
  for seed = 0 to 199 do
    let start = List.nth samples (seed mod List.length samples) in
    let chain = derivation start 3 seed in
    let formulas = start :: List.map snd chain in
    List.iter (fun f -> if not (equivalent start f) then fail ("a correct derivation changed the meaning: " ^ to_latex f)) formulas;
    if List.length (List.sort_uniq compare formulas) <> List.length formulas then fail "a derivation revisited a formula";
    List.iter (fun f -> if not (is_fair f) then fail ("a derivation step is not fair: " ^ to_latex f)) (List.tl formulas);
    let wrong = derive ~mistake_at:(seed mod 3) start 3 seed in
    if not (equivalent start wrong) then incr lost
  done;
  if !lost < 100 then fail (Printf.sprintf "only %d of 200 wrong derivations changed the meaning" !lost);
  (* the course's examples *)
  check "definition of conditional read backwards"
    (List.mem (implication (negate p) q) (apply_anywhere (reversed (List.hd equivalence_laws)) (disjunction p q)));
  check "one law apart" (one_step_apart (implication p q) (disjunction (negate p) q));
  check "one mistake apart" (one_step_apart (implication p q) (implication q p));
  check "two laws apart" (not (one_step_apart (implication p q) (negate (conjunction p (negate q)))));
  check "same up to order" (same_shape (conjunction p (disjunction q r)) (conjunction (disjunction r q) p));
  check "fair" (is_fair (disjunction p (conjunction (negate p) q)));
  check "not fair: negation over two negated literals" (not (is_fair (negate (implication (negate r) (negate q)))));
  check "not fair: a literal against itself" (not (is_fair (implication q (negate q))));
  check "table width" (table_width [ implication p q; disjunction (negate p) q ] = 3)

let () =
  if !failures = 0 then print_endline "Ag boolean core tests passed."
  else (
    prerr_endline (Printf.sprintf "%d check(s) failed." !failures);
    exit 1)
