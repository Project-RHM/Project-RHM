(* Independent checks for binomial_theorem.rhm. The bracket, the power and
   the term asked for are read back from the printed question, the power is
   expanded here by repeated multiplication, and the answer is read off the
   expansion. No binomial coefficient is computed anywhere in this file.

   An expression is a map from the powers of x and y to a whole coefficient;
   a power of x may be negative, for the brackets with a fraction.

   - plain_coefficient, shifted_coefficient, linear_coefficient: the
     coefficient of the power of x asked for, in the expanded power of the
     bracket.
   - two_variable: the same with the powers of x and y asked for.
   - coefficient_sum: all the coefficients of the expansion added up.
   - constant_term: the coefficient of x^0, which must be there.
   - product_coefficient: the expanded power is multiplied by the linear
     factor in front of it before the coefficient is read.

   Each bracket must also have the form the grammar's header gives its kind,
   each kind must come at its price alone, and no answer may be zero.

   The two mistakes are recomputed by expanding a changed bracket:
   bare_coefficient with both numbers of the bracket replaced by 1, and
   powers_swapped with the two numbers exchanged. A mistake must be listed
   with that answer exactly when it differs from the right one. *)

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

let with_initial spec name value =
  match Rhema_check.with_initial spec name value with Ok s -> s | Error m -> fail m; spec

let kind (q : Rhema_engine.question) =
  match Rhema_engine.attribute q.Rhema_engine.tree "kind" with Rhema_engine.Text t -> t | _ -> "?"

(* A value of the engine as a whole number. *)
let whole context = function
  | Rhema_engine.Num n when Rhema_number.is_integer n -> Some n.Rhema_number.numerator
  | other -> fail (context ^ ": not a whole number: " ^ Rhema_engine.describe_value other); None

(* ---- Expressions ---------------------------------------------------- *)

module Powers = Map.Make (struct
  type t = int * int  (* the power of x, the power of y *)

  let compare = compare
end)

(* A coefficient of zero is never kept. *)
let add_term powers coefficient expression =
  Powers.update powers
    (fun old ->
      let total = Option.value old ~default:0 + coefficient in
      if total = 0 then None else Some total)
    expression

let one = Powers.singleton (0, 0) 1

let of_terms terms = List.fold_left (fun expression (powers, c) -> add_term powers c expression) Powers.empty terms

let multiply left right =
  Powers.fold
    (fun (lx, ly) lc total -> Powers.fold (fun (rx, ry) rc total -> add_term (lx + rx, ly + ry) (lc * rc) total) right total)
    left Powers.empty

let rec power expression n = if n = 0 then one else multiply expression (power expression (n - 1))

let coefficient powers expression = Option.value (Powers.find_opt powers expression) ~default:0

let sum_of_coefficients expression = Powers.fold (fun _ c total -> total + c) expression 0

(* ---- Reading the question ------------------------------------------- *)

(* An optional group of the last match. *)
let optional_group n text = match Str.matched_group n text with s -> Some s | exception Not_found -> None

(* A power as it is written: none stands for 1, and a 1 is never written. *)
let written_power = function
  | None -> 1
  | Some "1" -> failwith "a power of 1 written out"
  | Some e -> int_of_string e

let fraction_re = Str.regexp "^\\\\frac{\\([0-9]+\\)}{x\\(\\^{\\([0-9]+\\)}\\)?}$"
let monomial_re = Str.regexp "^\\(-?[0-9]*\\)\\(\\([xy]\\)\\(\\^{\\([0-9]+\\)}\\)?\\)?$"

(* One term of a bracket, as its powers and its number: "3", "-2x",
   "x^{2}", "y", "\frac{2}{x^{2}}". *)
let term text =
  if Str.string_match fraction_re text 0 then begin
    let top = int_of_string (Str.matched_group 1 text) in
    ((-written_power (optional_group 3 text), 0), top)
  end
  else if Str.string_match monomial_re text 0 then begin
    let number = Str.matched_group 1 text and variable = optional_group 3 text in
    let exponent = optional_group 5 text in
    match variable with
    | None -> if number = "" || number = "-" then failwith ("not a term: " ^ text) else ((0, 0), int_of_string number)
    | Some v ->
        let c =
          match number with
          | "" -> 1
          | "-" -> -1
          | "1" | "-1" -> failwith ("a coefficient of 1 written out: " ^ text)
          | digits -> int_of_string digits
        in
        let e = written_power exponent in
        ((if v = "x" then (e, 0) else (0, e)), c)
  end
  else failwith ("not a term: " ^ text)

(* The two terms of a bracket, "-2x + 3" or "x - \frac{2}{x^{2}}". Only the
   first may carry a sign of its own. *)
let bracket inside =
  match Str.full_split (Str.regexp " [-+] ") inside with
  | [ Str.Text first; Str.Delim sign; Str.Text second ] ->
      let first = term first and powers, c = term second in
      if c < 0 then failwith ("two signs in a row: " ^ inside);
      if snd first = 0 || c = 0 then failwith ("a zero in the bracket: " ^ inside);
      [ first; (powers, if sign = " - " then -c else c) ]
  | _ -> failwith ("not a bracket of two terms: " ^ inside)

let factor_re = Str.regexp "\\\\left(\\([^()]*\\)\\\\right)\\(\\^{\\([0-9]+\\)}\\)?"

(* The brackets of an expression in order, each with its power when it has
   one: "\left(2 - x\right)\left(1 - 2x\right)^{6}". *)
let factors text =
  let rec go at found =
    if at = String.length text then List.rev found
    else if Str.string_match factor_re text at then begin
      let inside = Str.matched_group 1 text and n = Option.map int_of_string (optional_group 3 text) in
      let next = Str.match_end () in
      go next ((bracket inside, n) :: found)
    end
    else failwith ("not a product of brackets: " ^ text)
  in
  go 0 []

let asked_re = Str.regexp "^x\\(\\^{\\([0-9]+\\)}\\)?\\( y\\(\\^{\\([0-9]+\\)}\\)?\\)?$"

(* The term asked for, "x", "x^{5}", "x^{2} y^{5}" or "x y^{4}", as the
   power of x and the power of y. *)
let asked text =
  if not (Str.string_match asked_re text 0) then failwith ("not a term to ask for: " ^ text);
  let x = written_power (optional_group 2 text) in
  let y = match optional_group 3 text with None -> 0 | Some _ -> written_power (optional_group 5 text) in
  (x, y)

let expansion_of = " in the expansion of \\[`\\([^`]*\\)`\\]\\.$"
let coefficient_re = Str.regexp ("^Find the coefficient of \\[`\\([^`]*\\)`\\]" ^ expansion_of)
let sum_re = Str.regexp ("^Find the sum of all the coefficients" ^ expansion_of)
let constant_re = Str.regexp ("^Find the term independent of \\[`x`\\]" ^ expansion_of)

(* What a question asks of its expansion. *)
type request = Coefficient of (int * int) | Sum | Constant

(* The request and the brackets of a printed question. *)
let read p =
  if Str.string_match coefficient_re p 0 then begin
    let term = Str.matched_group 1 p and expression = Str.matched_group 2 p in
    (Coefficient (asked term), factors expression)
  end
  else if Str.string_match sum_re p 0 then (Sum, factors (Str.matched_group 1 p))
  else if Str.string_match constant_re p 0 then (Constant, factors (Str.matched_group 1 p))
  else failwith "the question is not worded as expected"

(* ---- Recomputing ---------------------------------------------------- *)

(* What the question asks, of `front` times the n-th power of the bracket. *)
let value request front terms n =
  let expansion = multiply front (power (of_terms terms) n) in
  match request with
  | Coefficient powers -> coefficient powers expansion
  | Sum -> sum_of_coefficients expansion
  | Constant -> coefficient (0, 0) expansion

let bare terms = List.map (fun (powers, _) -> (powers, 1)) terms

let swapped = function
  | [ (first, a); (second, b) ] -> [ (first, b); (second, a) ]
  | terms -> terms

(* The right answer and what each mistake gives. The form of the brackets is
   the one the grammar's header gives the kind. *)
let recompute k request brackets =
  let form_fits, front, terms, n =
    match (k, request, brackets) with
    | "plain_coefficient", Coefficient (_, 0), [ (([ ((0, 0), 1); ((1, 0), 1) ] as terms), Some n) ] -> (true, one, terms, n)
    | "shifted_coefficient", Coefficient (_, 0), [ (([ ((1, 0), 1); ((0, 0), b) ] as terms), Some n) ] ->
        (abs b <> 1, one, terms, n)
    | "linear_coefficient", Coefficient (_, 0), [ (([ ((1, 0), _); ((0, 0), _) ] as terms), Some n) ] -> (true, one, terms, n)
    | "two_variable", Coefficient (i, j), [ (([ ((1, 0), _); ((0, 1), _) ] as terms), Some n) ] ->
        (i >= 1 && j >= 1, one, terms, n)
    | "coefficient_sum", Sum, [ (([ ((1, 0), _); ((0, 0), _) ] as terms), Some n) ] -> (true, one, terms, n)
    | "constant_term", Constant, [ (([ ((p, 0), _); ((q, 0), _) ] as terms), Some n) ] -> (p >= 1 && q <= -1, one, terms, n)
    | ( "product_coefficient",
        Coefficient (_, 0),
        [ (([ ((0, 0), c); ((1, 0), d) ] as front), None); (([ ((0, 0), 1); ((1, 0), a) ] as terms), Some n) ] ) ->
        (* the first bracket is not a multiple of the second *)
        (d <> c * a, of_terms front, terms, n)
    | _ -> (false, one, [], 0)
  in
  if not form_fits then failwith "the brackets do not have the form of the kind";
  if n < 2 then failwith "a power below 2";
  (value request front terms n, value request front (bare terms) n, value request front (swapped terms) n)

(* The mistakes each kind declares. *)
let declared =
  [ ("plain_coefficient", []);
    ("shifted_coefficient", [ "bare_coefficient"; "powers_swapped" ]);
    ("linear_coefficient", [ "bare_coefficient"; "powers_swapped" ]);
    ("two_variable", [ "bare_coefficient"; "powers_swapped" ]);
    ("coefficient_sum", []);
    ("constant_term", [ "bare_coefficient"; "powers_swapped" ]);
    ("product_coefficient", []) ]

let () =
  let base = load_file "binomial_theorem.rhm" in
  let prices =
    [ ("plain_coefficient", 1); ("shifted_coefficient", 1); ("linear_coefficient", 2); ("two_variable", 2);
      ("coefficient_sum", 2); ("constant_term", 3); ("product_coefficient", 3) ]
  in
  let seen = Hashtbl.create 8 and mistakes_seen = Hashtbl.create 8 and minus_seen = Hashtbl.create 8 in
  let constant_forms = Hashtbl.create 4 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          if List.length q.Rhema_engine.answers <> 1 then fail (k ^ ": not one answer: " ^ p);
          match
            let request, brackets = read p in
            (brackets, recompute k request brackets)
          with
          | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
          | brackets, (right, bare_value, swapped_value) ->
              (match whole k q.Rhema_engine.answer with
              | Some got when got <> right -> fail (Printf.sprintf "%s: answer %d, recomputed %d, for %S" k got right p)
              | _ -> ());
              (* the term asked for is in the expansion, and the answer is not zero *)
              if right = 0 then fail (Printf.sprintf "%s: the expansion has a zero there: %S" k p);
              (* which forms came up *)
              List.iter
                (fun (terms, _) -> if List.exists (fun (_, c) -> c < 0) terms then Hashtbl.replace minus_seen k ())
                brackets;
              (match (k, brackets) with
              | "constant_term", [ ([ ((top, _), _); ((bottom, _), _) ], _) ] -> Hashtbl.replace constant_forms (top, -bottom) ()
              | _ -> ());
              (* the mistakes: each one listed with its answer exactly when it differs *)
              let listed = q.Rhema_engine.mistakes in
              let expected = List.assoc_opt k declared |> Option.value ~default:[] in
              List.iter
                (fun (made : Rhema_engine.mistaken) ->
                  if not (List.mem made.Rhema_engine.mistake expected) then
                    fail (Printf.sprintf "%s: a mistake %s is listed for %S" k made.Rhema_engine.mistake p))
                listed;
              List.iter
                (fun name ->
                  let want = if name = "bare_coefficient" then bare_value else swapped_value in
                  let found = List.filter (fun (made : Rhema_engine.mistaken) -> made.Rhema_engine.mistake = name) listed in
                  match found with
                  | [] -> if want <> right then fail (Printf.sprintf "%s: mistake %s (%d) is not listed for %S" k name want p)
                  | [ { Rhema_engine.mistaken_answers = Some [ value ]; _ } ] -> (
                      Hashtbl.replace mistakes_seen (k, name) ();
                      match whole (k ^ " " ^ name) value with
                      | None -> ()
                      | Some got ->
                          if got = right then fail (Printf.sprintf "%s: mistake %s gives the right answer for %S" k name p);
                          if got <> want then
                            fail (Printf.sprintf "%s: mistake %s gives %d, recomputed %d, for %S" k name got want p))
                  | _ -> fail (Printf.sprintf "%s: mistake %s is not listed once with one answer for %S" k name p))
                expected)
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  List.iter
    (fun (k, names) ->
      List.iter
        (fun name -> if not (Hashtbl.mem mistakes_seen (k, name)) then fail (Printf.sprintf "%s never listed the mistake %s" k name))
        names)
    declared;
  (* every kind but the first has brackets with a minus sign *)
  List.iter
    (fun (k, _) ->
      if k <> "plain_coefficient" && not (Hashtbl.mem minus_seen k) then fail ("no minus sign in any bracket of " ^ k))
    prices;
  (* the constant term is asked with every pair of powers of x *)
  List.iter
    (fun (top, bottom) ->
      if not (Hashtbl.mem constant_forms (top, bottom)) then
        fail (Printf.sprintf "no constant term with x^%d and 1/x^%d" top bottom))
    [ (1, 1); (1, 2); (2, 1) ];
  if !failures = 0 then print_endline "Rhema binomial theorem tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d binomial theorem test(s) failed." !failures);
    exit 1
  end
