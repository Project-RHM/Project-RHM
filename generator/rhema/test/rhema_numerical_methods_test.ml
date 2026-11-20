(* Independent checks for numerical_methods.rhm. The function, the starting
   values, the limits and the step are read back from the printed question
   and the method is run here as an algorithm, on exact fractions; the result
   must be the engine's answer, exactly.

   Newton's method: x <- x - f(x) / f'(x) with f = x^2 - a, as many times as
   the question asks. The number a must not be a square, must lie within 3 of
   the square of the start, the start must be next to the root, and the
   iterate asked for must be closer to the root than the start is.

   Bisection: the sign of f must change between the two ends. The interval is
   halved three times, each time keeping the half where the sign changes; the
   first midpoint must be the one the question prints, the third is the
   answer, and no midpoint may be a root.

   Trapezoidal rule: the strips are equal and as many as the question says;
   their areas are added one by one. The polynomial is also integrated term
   by term, and the estimate must not be that integral.

   Simpson's rule: c / (x + d) must be positive over the whole interval; the
   five values are added with the weights 1 4 2 4 1. The estimate must not be
   the integral c ln(...).

   Euler's method: y <- y + h f(x, y), x <- x + h, from x = 0 until x is the
   point asked for, which must take two steps. *)

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

(* Fractions on OCaml integers, in lowest terms with a positive denominator,
   so that two equal fractions are equal as records. The numbers of these
   questions are small. *)
type fraction = { top : int; bottom : int }

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let fraction top bottom =
  if bottom = 0 then failwith "division by zero";
  let top, bottom = if bottom < 0 then (-top, -bottom) else (top, bottom) in
  let divisor = gcd top bottom in
  { top = top / divisor; bottom = bottom / divisor }

let whole n = { top = n; bottom = 1 }
let zero = whole 0
let ( +: ) a b = fraction ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( -: ) a b = fraction ((a.top * b.bottom) - (b.top * a.bottom)) (a.bottom * b.bottom)
let ( *: ) a b = fraction (a.top * b.top) (a.bottom * b.bottom)
let ( /: ) a b = fraction (a.top * b.bottom) (a.bottom * b.top)
let sign a = compare a.top 0
let less a b = sign (a -: b) < 0
let rec power a n = if n = 0 then whole 1 else a *: power a (n - 1)
let to_float a = float a.top /. float a.bottom
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

let group re text n =
  ignore (Str.search_forward (Str.regexp re) text 0);
  Str.matched_group n text

(* A number as number_latex writes it: 3, -2, \frac{11}{2}, -\frac{1}{2}. *)
let number_re = "-?[0-9]+\\|-?\\\\frac{[0-9]+}{[0-9]+}"

let number text =
  if Str.string_match (Str.regexp "^\\(-?\\)\\\\frac{\\([0-9]+\\)}{\\([0-9]+\\)}$") text 0 then begin
    let minus = Str.matched_group 1 text and top = Str.matched_group 2 text and bottom = Str.matched_group 3 text in
    fraction ((if minus = "-" then -1 else 1) * int_of_string top) (int_of_string bottom)
  end
  else if Str.string_match (Str.regexp "^-?[0-9]+$") text 0 then whole (int_of_string text)
  else failwith ("cannot read the number " ^ text)

(* A sum of terms as polynomial_latex writes it, in x and in y:
   "-3 \cdot x^{2} + 2 \cdot x + 1", "-x - y^{2}". A constant is a term in x
   to the power 0. *)
type term = { coefficient : int; variable : char; exponent : int }

let terms text =
  let parts = Str.full_split (Str.regexp " [+-] ") (" + " ^ String.trim text) in
  let sign = ref 1 and found = ref [] in
  List.iter
    (function
      | Str.Delim d -> sign := if String.trim d = "-" then -1 else 1
      | Str.Text t ->
          (* a leading minus belongs to the first term *)
          let t, sign = if t <> "" && t.[0] = '-' then (String.sub t 1 (String.length t - 1), - !sign) else (t, !sign) in
          if Str.string_match (Str.regexp "^\\(\\([0-9]+\\) \\\\cdot \\)?\\([xy]\\)\\(\\^{\\([0-9]+\\)}\\)?$") t 0 then begin
            let optional n = match Str.matched_group n t with s -> int_of_string s | exception Not_found -> 1 in
            let coefficient = optional 2 and exponent = optional 5 and variable = (Str.matched_group 3 t).[0] in
            found := { coefficient = sign * coefficient; variable; exponent } :: !found
          end
          else if Str.string_match (Str.regexp "^[0-9]+$") t 0 then
            found := { coefficient = sign * int_of_string t; variable = 'x'; exponent = 0 } :: !found
          else failwith ("cannot read the term " ^ t))
    parts;
  List.rev !found

let value terms x y =
  List.fold_left
    (fun total t -> total +: (whole t.coefficient *: power (if t.variable = 'y' then y else x) t.exponent))
    zero terms

(* The integral of a polynomial in x between two limits, term by term. *)
let integral terms lower upper =
  List.fold_left
    (fun total t ->
      let n = t.exponent + 1 in
      total +: (fraction t.coefficient n *: (power upper n -: power lower n)))
    zero terms

let limits p =
  let re = "\\\\int_{\\(" ^ number_re ^ "\\)}\\^{\\(" ^ number_re ^ "\\)}" in
  let lower = number (group re p 1) and upper = number (group re p 2) in
  if not (less lower upper) then failwith "the limits are not in order";
  (lower, upper)

let strips p = int_of_string (group "with \\[`\\([0-9]+\\)`\\] strips of equal width" p 1)

(* Is x closer to the square root of a than y is? Both are positive.
   (x - r)^2 < (y - r)^2 is x^2 - y^2 < 2 (x - y) r, so for x > y it is
   x + y < 2 r, and for x < y it is x + y > 2 r. *)
let closer x y a =
  let sum = x +: y in
  let side = sign ((sum *: sum) -: whole (4 * a)) in
  if less y x then side < 0 else if less x y then side > 0 else false

(* What was generated besides the kinds: both strip widths, both halves of a
   bisection, both forms of the integrand of Simpson's rule. *)
let noted = Hashtbl.create 8
let note what = Hashtbl.replace noted what ()

(* The points of a rule are whole numbers or halves. *)
let note_width p h =
  if h = whole 1 then note "strips of width 1"
  else if h = fraction 1 2 then note "strips of width 1/2"
  else fail ("strips of width " ^ show h ^ ": " ^ p)

let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | ("newton_one" | "newton_two") as k ->
      let a = int_of_string (group "solve \\[`x\\^{2} - \\([0-9]+\\) = 0`\\]" p 1) in
      let x0 = int_of_string (group "starting from \\[`x_0 = \\([0-9]+\\)`\\]" p 1) in
      let steps = int_of_string (group "Find \\[`x_\\([0-9]+\\)`\\]" p 1) in
      if steps <> (if k = "newton_one" then 1 else 2) then fail (Printf.sprintf "%s asks for x_%d: %s" k steps p);
      let rec is_square r = r * r <= a && (r * r = a || is_square (r + 1)) in
      if is_square 0 then fail ("the root is a whole number: " ^ p);
      if abs (a - (x0 * x0)) > 3 then fail ("a is not within 3 of the square of the start: " ^ p);
      if not ((x0 - 1) * (x0 - 1) < a && a < (x0 + 1) * (x0 + 1)) then fail ("the start is not next to the root: " ^ p);
      let f x = (x *: x) -: whole a and slope x = whole 2 *: x in
      let x = ref (whole x0) in
      for _ = 1 to steps do
        x := !x -: (f !x /: slope !x)
      done;
      if not (closer !x (whole x0) a) then fail ("the iterate is no closer to the root than the start: " ^ p);
      !x
  | "bisection" ->
      let a = int_of_string (group "root of \\[`f(x) = x\\^{2} - \\([0-9]+\\)`\\]" p 1) in
      let ends = "between \\[`\\(" ^ number_re ^ "\\)`\\] and \\[`\\(" ^ number_re ^ "\\)`\\]" in
      let lower = number (group ends p 1) and upper = number (group ends p 2) in
      let printed = number (group ("first midpoint it tries is \\[`\\(" ^ number_re ^ "\\)`\\]") p 1) in
      let f x = (x *: x) -: whole a in
      if not (less lower upper && sign (f lower) < 0 && sign (f upper) > 0) then
        fail ("f does not go from negative to positive over the interval: " ^ p);
      let low = ref lower and high = ref upper and tried = ref [] in
      for _ = 1 to 3 do
        let middle = (!low +: !high) /: whole 2 in
        tried := middle :: !tried;
        if sign (f middle) = 0 then fail ("a midpoint is the root: " ^ p)
        else if sign (f !low) * sign (f middle) < 0 then begin
          high := middle;
          note "bisection keeps the lower half"
        end
        else begin
          low := middle;
          note "bisection keeps the upper half"
        end
      done;
      let third = List.hd !tried and first = List.hd (List.rev !tried) in
      if first <> printed then fail (Printf.sprintf "the first midpoint is %s, not the one printed: %s" (show first) p);
      third
  | ("trapezoid_two" | "trapezoid_four") as k ->
      let lower, upper = limits p and n = strips p in
      if n <> (if k = "trapezoid_two" then 2 else 4) then fail (Printf.sprintf "%s with %d strips: %s" k n p);
      let f = terms (group "\\\\left(\\(.*\\)\\\\right) \\\\, dx`" p 1) in
      if List.exists (fun t -> t.variable <> 'x') f then failwith "an integrand in y";
      let degree = List.fold_left (fun highest t -> max highest t.exponent) 0 f in
      if degree < 2 || degree > 3 then fail (Printf.sprintf "a polynomial of degree %d: %s" degree p);
      let h = (upper -: lower) /: whole n in
      note_width p h;
      let total = ref zero in
      for strip = 0 to n - 1 do
        let left = lower +: (whole strip *: h) in
        let right = left +: h in
        total := !total +: (h *: (value f left zero +: value f right zero) /: whole 2)
      done;
      if !total = integral f lower upper then fail (k ^ ": the estimate is the integral itself: " ^ p);
      !total
  | "simpson" ->
      let lower, upper = limits p and n = strips p in
      if n <> 4 then fail (Printf.sprintf "simpson with %d strips: %s" n p);
      let re = Str.regexp "\\\\frac{\\([0-9]+\\)}{x\\( [+] \\([0-9]+\\)\\)?} \\\\, dx`" in
      ignore (Str.search_forward re p 0);
      let c = int_of_string (Str.matched_group 1 p) in
      let d = match Str.matched_group 3 p with s -> int_of_string s | exception Not_found -> 0 in
      note (if d = 0 then "simpson of c / x" else "simpson of c / (x + d)");
      let f x =
        let below = x +: whole d in
        if sign below <= 0 then failwith "x + d is not positive over the interval";
        whole c /: below
      in
      let h = (upper -: lower) /: whole n in
      note_width p h;
      let weights = [| 1; 4; 2; 4; 1 |] in
      let total = ref zero in
      Array.iteri (fun i weight -> total := !total +: (whole weight *: f (lower +: (whole i *: h)))) weights;
      let estimate = h /: whole 3 *: !total in
      let exact = float c *. log (to_float (upper +: whole d) /. to_float (lower +: whole d)) in
      if Float.abs (to_float estimate -. exact) <= 1e-9 then fail ("simpson: the estimate is the integral itself: " ^ p);
      estimate
  | ("euler_linear" | "euler_quadratic") as k ->
      let re = "applied to \\[`y' = \\([^`]*\\)`\\] with \\[`y(0) = \\(-?[0-9]+\\)`\\]" in
      let f = terms (group re p 1) and start = whole (int_of_string (group re p 2)) in
      let h = number (group ("the step \\[`h = \\(" ^ number_re ^ "\\)`\\]") p 1) in
      let target = number (group ("for \\[`y(\\(" ^ number_re ^ "\\))`\\]") p 1) in
      (* a x + b y, and a x + y^2 or a x - y^2 *)
      (match (k, f) with
      | "euler_linear", [ { variable = 'x'; exponent = 1; _ }; { variable = 'y'; exponent = 1; _ } ] -> ()
      | "euler_quadratic", [ { variable = 'x'; exponent = 1; _ }; { variable = 'y'; exponent = 2; coefficient = 1 | -1 } ] -> ()
      | _ -> fail (k ^ ": not the equation of its kind: " ^ p));
      if sign h <= 0 then failwith "a step that is not positive";
      let x = ref zero and y = ref start and steps = ref 0 in
      while less !x target && !steps < 100 do
        y := !y +: (h *: value f !x !y);
        x := !x +: h;
        incr steps;
        (* from 0 the next step would not use y at all *)
        if !steps = 1 && !y = zero then fail (k ^ ": the first step lands on 0: " ^ p)
      done;
      if !x <> target then fail ("the steps do not land on the point asked for: " ^ p);
      if !steps <> 2 then fail (Printf.sprintf "%s takes %d steps: %s" k !steps p);
      !y
  | k -> failwith ("unknown kind " ^ k)

let () =
  let base = load_file "numerical_methods.rhm" in
  let prices =
    [ ("newton_one", 1); ("trapezoid_two", 1); ("newton_two", 2); ("bisection", 2); ("trapezoid_four", 2);
      ("euler_linear", 2); ("simpson", 3); ("euler_quadratic", 3) ]
  in
  let seen = Hashtbl.create 8 in
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
          match q.Rhema_engine.answer with
          | Rhema_engine.Num n -> (
              let got = fraction n.Rhema_number.numerator n.Rhema_number.denominator in
              match expected q with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | want -> if got <> want then fail (Printf.sprintf "%s: answer %s, worked out %s, for %S" k (show got) (show want) p))
          | other -> fail (Printf.sprintf "%s: not a number: %s" k (Rhema_engine.describe_value other)))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  List.iter
    (fun what -> if not (Hashtbl.mem noted what) then fail ("never generated: " ^ what))
    [ "strips of width 1"; "strips of width 1/2"; "bisection keeps the lower half"; "bisection keeps the upper half";
      "simpson of c / x"; "simpson of c / (x + d)" ];
  if !failures = 0 then print_endline "Rhema numerical methods tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d numerical methods test(s) failed." !failures);
    exit 1
  end
