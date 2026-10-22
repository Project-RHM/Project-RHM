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

let () =
  if !failures = 0 then print_endline "Ag boolean core tests passed."
  else (
    prerr_endline (Printf.sprintf "%d check(s) failed." !failures);
    exit 1)
