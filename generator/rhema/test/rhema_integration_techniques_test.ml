(* Independent checks for integration_techniques.rhm. Nothing here uses the
   grammar's closed formulas. Every question is matched against the whole
   sentence of its form; the limits, the integrand and every number in it
   are read from the sentence alone, and the answer is found again from what
   was read, in floating point, by numerical integration of the printed
   integrand between the printed limits: a composite four-point
   Gauss-Legendre rule, which never evaluates an integrand at the ends of
   its interval. Form by form:

   - half_angle: k sin^2(mx) or k cos^2(mx) is integrated from 0 to the
     printed pi or pi / 2. The mistake half_forgotten is k times the length
     of the interval. The promises: the interval is a whole number of
     quarter periods of sin(mx), and the integral is half of what the
     mistake gives.
   - inverse_tangent: k / (x^2 + c) is integrated from 0 to the printed
     limit; c must be a square a^2 and the limit a. The mistake
     scale_forgotten is k times the inverse tangent of x / a between the
     limits, with no 1 / a in front; for a = 1 that is the right answer, and
     the mistake must then not be listed.
   - inverse_sine: k / sqrt(c - x^2) is integrated from 0 to the printed
     limit; c must be a square a^2 with a even and the limit a / 2, where
     the integrand is still smooth. No mistake.
   - parts_exponential, parts_logarithm, parts_sine, parts_cosine: the
     printed integrand is integrated as it stands (k x e^(ax) from 0 to 1,
     k x^n ln x from 1 to e, k x sin(mx) and k x cos(mx) from 0 to pi). For
     the mistake plus_for_minus the integration by parts is redone with a
     split u, dv chosen here (u = kx with the exponential and the
     trigonometric functions, u = ln x with the logarithm): u dv must be the
     printed integrand, du and dv the slopes of u and v by a central
     difference, the boundary term [u v] less the integral of v du must be
     the integral found directly, and the mistake is the boundary term PLUS
     that second integral, found numerically. With sin(mx) the second
     integral must be 0, so that the mistake gives the right answer and is
     not listed; with cos(mx) the boundary term must be 0 and m odd. The
     promise that m is as likely to be each of 1 to 4 with the sine and each
     of 1, 3 and 5 with the cosine is checked on 40000 more questions of
     price 2: each count is within five standard deviations of its share.
   - trig_powers: k sin^a x cos^b x, or the same with the letters exchanged,
     is integrated from 0 to pi / 2; the second power must be odd and the
     two functions different. No mistake. The promise that exchanging sine
     and cosine changes nothing but the letters is checked on the engine's
     answers to the two letterings of the same numbers.
   - reduction: k sin^n x or k cos^n x is integrated from 0 to pi / 2; n is
     at least 3, the power 2 being the half-angle integral of price 1. No
     mistake. The reduction formula itself is checked on the engine's
     answers: n I(n) = (n - 1) I(n - 2), and the same for sine and cosine.
   - substitution_root, substitution_square: k sqrt(c - x^2) and
     k x^2 sqrt(c - x^2) are integrated from 0 to the printed limit; c must
     be a square a^2 and the limit a. The slope of the integrand is not
     bounded at a, so the integral is taken in t with x = a - t^2, which
     makes the integrand smooth (this is not the trigonometric
     substitution). No mistake.
   - parts_twice: k x^2 e^(ax) is integrated from 0 to 1. For
     plus_for_minus the two steps by parts are redone as above (u = k x^2,
     then u = 2kx / a); the first step is right and the second adds its
     second integral.
   - log_fractions: k / ((x + a)(x + b)) is integrated from 0 to 1, with
     a < b. The mistake logs_added integrates
     (k / (b - a)) (1 / (x + a) + 1 / (x + b)); the partial fractions with
     the right sign must be the printed integrand at several points.

   How an answer is written follows from the value found here, by the
   promise of the header: a fraction (with a denominator up to 256) is a
   `plain` number; a fraction times pi is a `plain` formula written as one
   fraction in front of pi (or pi alone, or the negative of either); any
   other value is an ordinary formula without variables that holds e alone
   (the forms by parts) or a logarithm alone (the partial fractions). The
   sentence says to write pi exactly when the answer is a multiple of pi. A
   formula answer is worth less than 1000: WeBWorK grades to one part in a
   thousand. The working of this file is itself tried first on integrals
   with known answers, on splits that are wrong and on sentences that are
   not written as they should be.

   Besides the answers: the mistakes a form can make are worked out here on
   each question; one that comes to the right answer must not be listed and
   every other one must be, in the order of the declarations, with the value
   found here, more than 1% away from the right answer, and described in the
   words of the header's list; a form without mistakes lists none. How each
   answer and each mistaken answer is written is pinned form by form. Each
   kind appears at its price alone and spends its budget; a budget outside
   1..3 gives no question; the budget the grammar sets itself is the middle
   price; each printed number of each form takes exactly the values the
   grammar offers, none missing and none more. Those ranges and the
   descriptions are the only things taken from the grammar. The weights are
   not looked at. *)

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

let pi = Float.pi

(* Two numbers that are the same to nine places of the larger. *)
let near a b = Float.abs (a -. b) <= 1e-9 *. Float.max (Float.abs a) (Float.abs b)

(* The same, for numbers that may be 0. *)
let close ?(within = 1e-9) a b = Float.abs (a -. b) <= within *. Float.max 1.0 (Float.abs b)

(* A whole number that is a perfect square has a whole square root. *)
let square_root n =
  let rec up r = if r * r >= n then r else up (r + 1) in
  let r = up 0 in
  if n >= 0 && r * r = n then Some r else None

let rec power x n = if n <= 0 then 1.0 else x *. power x (n - 1)

(* ---- Numerical working ---------------------------------------------------- *)

(* The integral of g from a to b by the four-point Gauss-Legendre rule on
   `panels` equal pieces. The ends of the interval are never evaluated. *)
let integral ?(panels = 200) g a b =
  let nodes = [ (-0.8611363115940526, 0.3478548451374538); (-0.3399810435848563, 0.6521451548625461);
                (0.3399810435848563, 0.6521451548625461); (0.8611363115940526, 0.3478548451374538) ] in
  let width = (b -. a) /. float_of_int panels in
  let sum = ref 0.0 in
  for i = 0 to panels - 1 do
    let middle = a +. (width *. (float_of_int i +. 0.5)) in
    List.iter (fun (t, w) -> sum := !sum +. (w *. g (middle +. (width *. t /. 2.0)))) nodes
  done;
  !sum *. width /. 2.0

(* The integral from a to b of a function that behaves like sqrt(b - x) at
   b: with x = b - t^2 the integrand in t is smooth. *)
let integral_to_a_root g a b = integral (fun t -> 2.0 *. t *. g (b -. (t *. t))) 0.0 (sqrt (b -. a))

(* The slope of g at x, by a central difference. *)
let slope g x =
  let h = 1e-5 in
  (g (x +. h) -. g (x -. h)) /. (2.0 *. h)

(* A split of an integrand into u and dv, with du and v. *)
type split = { u : float -> float; du : float -> float; v : float -> float; dv : float -> float }

(* Integration by parts of `integrand` from a to b with a split: the
   boundary term [u v] and the second integral, of v du, which is taken off
   it. The split must be one of the integrand. *)
let by_parts integrand { u; du; v; dv } a b =
  List.iter
    (fun n ->
      let x = a +. ((b -. a) *. (float_of_int n +. 0.5) /. 7.0) in
      if not (close (u x *. dv x) (integrand x)) then failwith "by parts: u dv is not the integrand";
      if not (close ~within:1e-6 (slope u x) (du x)) then failwith "by parts: du is not the slope of u";
      if not (close ~within:1e-6 (slope v x) (dv x)) then failwith "by parts: dv is not the slope of v")
    (List.init 7 Fun.id);
  let boundary = (u b *. v b) -. (u a *. v a) and second = integral (fun x -> du x *. v x) a b in
  (boundary, second)

(* The fraction p / q with q up to 256 that a number is, if it is one: to
   eleven places, which the integrals found here have. *)
let small_fraction v =
  let rec search q =
    if q > 256 then None
    else
      let p = Float.round (v *. float_of_int q) in
      if Float.abs (v -. (p /. float_of_int q)) <= 1e-11 *. Float.max 1.0 (Float.abs v) then Some (int_of_float p, q)
      else search (q + 1)
  in
  search 1

(* ---- Reading a question ---------------------------------------------------- *)

(* A whole number, written the one way it is written. *)
let integer text =
  match int_of_string_opt text with
  | Some n when string_of_int n = text -> n
  | _ -> failwith ("not a whole number: " ^ text)

(* A positive whole number in front of something, which is not written when
   it is 1. *)
let coefficient text =
  if text = "" then 1
  else
    let n = integer text in
    if n < 2 then failwith ("a coefficient that is not written as one is: " ^ text);
    n

(* The a of e^(ax): nothing for 1, a bare minus sign for -1, never 0. *)
let rate text =
  match text with
  | "" -> 1
  | "-" -> -1
  | _ ->
      let n = integer text in
      if abs n < 2 then failwith ("a rate that is not written as one is: " ^ text);
      n

(* A power as it is written after a letter: nothing for 1, or ^{n}. *)
let power_of text =
  let length = String.length text in
  if text = "" then 1
  else if length >= 4 && String.sub text 0 2 = "^{" && text.[length - 1] = '}' then begin
    let n = integer (String.sub text 2 (length - 3)) in
    if n < 2 then failwith ("a power that is not written as one is: " ^ text);
    n
  end
  else failwith ("not a power: " ^ text)

(* \sin or \cos: the function and its letters. *)
let trigonometric name =
  match name with
  | "\\sin" -> (sin, "sin")
  | "\\cos" -> (cos, "cos")
  | _ -> failwith ("neither a sine nor a cosine: " ^ name)

let words = Str.quote

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    Some (List.init count (fun n -> Str.matched_group (n + 1) prompt))
  else None

let a_number = "\\([0-9]+\\)"
let a_factor = "\\([0-9]*\\)"
let a_rate = "\\(-?[0-9]*\\)"
let a_function = "\\(\\\\sin\\|\\\\cos\\)"
let a_power = "\\([0-9^{}]*\\)"

(* The fields of the sentence that asks for the integral of `integrand` from
   `low` to `high` (three regular expressions with `count` groups in all),
   and whether the sentence goes on to say how pi is written. *)
let read ~low ~high integrand count prompt =
  let sentence hint =
    words "Evaluate [`\\int_{" ^ low ^ words "}^{" ^ high ^ words "} " ^ integrand
    ^ words " \\, dx`]. Give the exact value."
    ^ if hint then words " Write [`\\pi`] as pi." else ""
  in
  match fields count (sentence false) prompt with
  | Some found -> (found, false)
  | None -> (
      match fields count (sentence true) prompt with
      | Some found -> (found, true)
      | None -> failwith "the wording is not the expected one")

(* What was generated besides the kinds: each choice the grammar offers. *)
let noted : (string, string list) Hashtbl.t = Hashtbl.create 64

let note topic choice =
  let so_far = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
  if not (List.mem choice so_far) then Hashtbl.replace noted topic (choice :: so_far)

let note_number topic n = note topic (string_of_int n)

(* What a question comes to, worked out here. *)
type worked = {
  right : float;  (* the integral *)
  slips : (string * float) list;  (* each mistake its form can make, with what it gives *)
  hinted : bool;  (* whether the sentence says how pi is written *)
  case : string;  (* which case of its form it is, where what is pinned depends on it *)
  name : string;  (* a name for the question, where answers are compared with each other *)
}

(* ---- Price 1 ---------------------------------------------------------------- *)

let examine_half_angle prompt =
  let found, hinted =
    read ~low:"0" ~high:"\\(\\\\pi/2\\|\\\\pi\\)" (a_factor ^ a_function ^ words "^{2}(" ^ a_factor ^ words "x)") 4 prompt
  in
  match found with
  | [ high; front; letters; inside ] ->
      let k = coefficient front and m = coefficient inside in
      let f, letters = trigonometric letters in
      let top, top_name = if high = "\\pi" then (pi, "pi") else (pi /. 2.0, "pi/2") in
      let fk = float_of_int k and fm = float_of_int m in
      let right = integral (fun x -> fk *. power (f (fm *. x)) 2) 0.0 top in
      (* the length of the interval, where the integral is half of it *)
      let slip = fk *. (top -. 0.0) in
      (* the promises: a whole number of quarter periods of sin(mx), over
         which the square averages a half *)
      let quarters = top /. (2.0 *. pi /. fm /. 4.0) in
      if not (close quarters (Float.round quarters)) then failwith "the interval is not a whole number of quarter periods";
      if not (near right (slip /. 2.0)) then failwith "the integral is not half the length of the interval times k";
      note_number "half_angle: coefficient" k;
      note_number "half_angle: m" m;
      note "half_angle: function, m and upper limit" (Printf.sprintf "%s, %d, %s" letters m top_name);
      { right; slips = [ ("half_forgotten", slip) ]; hinted; case = "any"; name = "" }
  | _ -> failwith "four fields were expected"

let examine_inverse_tangent prompt =
  let found, hinted =
    read ~low:"0" ~high:a_number (words "\\frac{" ^ a_number ^ words "}{x^{2} + " ^ a_number ^ words "}") 3 prompt
  in
  match List.map integer found with
  | [ top; k; c ] ->
      let a = match square_root c with Some a when a >= 1 -> a | _ -> failwith "x^2 is not added to a square" in
      if top <> a then failwith "the upper limit is not a";
      let fk = float_of_int k and fa = float_of_int a and ftop = float_of_int top in
      let right = integral (fun x -> fk /. ((x *. x) +. float_of_int c)) 0.0 ftop in
      (* k arctan(x / a) between the limits, with no 1 / a in front *)
      let slip = fk *. (atan (ftop /. fa) -. atan (0.0 /. fa)) in
      note_number "inverse_tangent: coefficient" k;
      note_number "inverse_tangent: a" a;
      { right; slips = [ ("scale_forgotten", slip) ]; hinted; case = (if a = 1 then "a = 1" else "a over 1"); name = "" }
  | _ -> failwith "three fields were expected"

let examine_inverse_sine prompt =
  let found, hinted =
    read ~low:"0" ~high:a_number (words "\\frac{" ^ a_number ^ words "}{\\sqrt{" ^ a_number ^ words " - x^{2}}}") 3 prompt
  in
  match List.map integer found with
  | [ top; k; c ] ->
      let a = match square_root c with Some a when a >= 1 -> a | _ -> failwith "x^2 is not taken from a square" in
      (* the promise: a is even and the upper limit is a / 2 *)
      if 2 * top <> a then failwith "the upper limit is not a / 2";
      let right = integral (fun x -> float_of_int k /. sqrt (float_of_int c -. (x *. x))) 0.0 (float_of_int top) in
      note_number "inverse_sine: coefficient" k;
      note_number "inverse_sine: upper limit" top;
      { right; slips = []; hinted; case = "any"; name = "" }
  | _ -> failwith "three fields were expected"

(* ---- Price 2 ---------------------------------------------------------------- *)

(* The integral of an integrand between a and b, and what plus_for_minus
   makes of it with a split: the split must give the integral. *)
let parts_and_slip integrand split a b =
  let right = integral integrand a b in
  let boundary, second = by_parts integrand split a b in
  if not (near (boundary -. second) right) then failwith "by parts: the split does not give the integral";
  (right, boundary, second)

let examine_parts_exponential prompt =
  let found, hinted = read ~low:"0" ~high:"1" (a_factor ^ words "x e^{" ^ a_rate ^ words "x}") 2 prompt in
  match found with
  | [ front; inside ] ->
      let k = coefficient front and a = rate inside in
      let fk = float_of_int k and fa = float_of_int a in
      let integrand x = fk *. x *. exp (fa *. x) in
      let split = { u = (fun x -> fk *. x); du = (fun _ -> fk); v = (fun x -> exp (fa *. x) /. fa); dv = (fun x -> exp (fa *. x)) } in
      let right, boundary, second = parts_and_slip integrand split 0.0 1.0 in
      note_number "parts_exponential: coefficient" k;
      note_number "parts_exponential: rate" a;
      let case = if a = 1 then "rate 1" else if a = -1 then "rate -1" else "another rate" in
      { right; slips = [ ("plus_for_minus", boundary +. second) ]; hinted; case; name = "" }
  | _ -> failwith "two fields were expected"

let examine_parts_logarithm prompt =
  let found, hinted = read ~low:"1" ~high:"e" (a_factor ^ "x" ^ a_power ^ words " \\ln x") 2 prompt in
  match found with
  | [ front; raised ] ->
      let k = coefficient front and n = power_of raised in
      let fk = float_of_int k in
      let integrand x = fk *. power x n *. log x in
      let split =
        { u = log; du = (fun x -> 1.0 /. x); v = (fun x -> fk *. power x (n + 1) /. float_of_int (n + 1));
          dv = (fun x -> fk *. power x n) }
      in
      let right, boundary, second = parts_and_slip integrand split 1.0 (exp 1.0) in
      note_number "parts_logarithm: coefficient" k;
      note_number "parts_logarithm: power" n;
      { right; slips = [ ("plus_for_minus", boundary +. second) ]; hinted; case = "any"; name = "" }
  | _ -> failwith "two fields were expected"

let examine_parts_trigonometric k prompt =
  let letters = if k = "parts_sine" then "\\sin" else "\\cos" in
  let found, hinted = read ~low:"0" ~high:(words "\\pi") (a_factor ^ words ("x " ^ letters ^ "(") ^ a_factor ^ words "x)") 2 prompt in
  match found with
  | [ front; inside ] ->
      let c = coefficient front and m = coefficient inside in
      let fc = float_of_int c and fm = float_of_int m in
      let sine = k = "parts_sine" in
      let integrand x = fc *. x *. if sine then sin (fm *. x) else cos (fm *. x) in
      let split =
        if sine then { u = (fun x -> fc *. x); du = (fun _ -> fc); v = (fun x -> -.cos (fm *. x) /. fm); dv = (fun x -> sin (fm *. x)) }
        else { u = (fun x -> fc *. x); du = (fun _ -> fc); v = (fun x -> sin (fm *. x) /. fm); dv = (fun x -> cos (fm *. x)) }
      in
      let right, boundary, second = parts_and_slip integrand split 0.0 pi in
      (* the promises: with the sine the second integral is 0; with the
         cosine m is odd and the boundary term is 0 *)
      if sine then begin
        if Float.abs second > 1e-12 then failwith "the second integral is not 0"
      end
      else begin
        if m mod 2 = 0 then failwith "m is even";
        if Float.abs boundary > 1e-12 then failwith "the boundary term is not 0"
      end;
      note_number (k ^ ": coefficient") c;
      note_number (k ^ ": m") m;
      { right; slips = [ ("plus_for_minus", boundary +. second) ]; hinted; case = "any"; name = "" }
  | _ -> failwith "two fields were expected"

let examine_trig_powers prompt =
  let found, hinted =
    read ~low:"0" ~high:(words "\\pi/2")
      (a_factor ^ a_function ^ a_power ^ words " x \\, " ^ a_function ^ a_power ^ words " x")
      5 prompt
  in
  match found with
  | [ front; first; first_power; second; second_power ] ->
      let k = coefficient front and a = power_of first_power and b = power_of second_power in
      let f, f_letters = trigonometric first and g, g_letters = trigonometric second in
      if f_letters = g_letters then failwith "the same function twice";
      (* the promise: the second power is odd *)
      if b mod 2 = 0 then failwith "the second power is even";
      let right = integral (fun x -> float_of_int k *. power (f x) a *. power (g x) b) 0.0 (pi /. 2.0) in
      note_number "trig_powers: coefficient" k;
      note "trig_powers: first function, its power and the second power" (Printf.sprintf "%s, %d, %d" f_letters a b);
      { right; slips = []; hinted; case = "any"; name = Printf.sprintf "trig_powers %d %s %d %d" k f_letters a b }
  | _ -> failwith "five fields were expected"

(* ---- Price 3 ---------------------------------------------------------------- *)

let examine_reduction prompt =
  let found, hinted =
    read ~low:"0" ~high:(words "\\pi/2") (a_factor ^ a_function ^ words "^{" ^ a_number ^ words "} x") 3 prompt
  in
  match found with
  | [ front; letters; raised ] ->
      let k = coefficient front and n = integer raised in
      let f, letters = trigonometric letters in
      (* the promise: the power 2 is left to the half-angle formula *)
      if n < 3 then failwith "a power under 3";
      let right = integral (fun x -> float_of_int k *. power (f x) n) 0.0 (pi /. 2.0) in
      note_number "reduction: coefficient" k;
      note "reduction: function and power" (Printf.sprintf "%s, %d" letters n);
      { right; slips = []; hinted; case = (if n mod 2 = 0 then "even power" else "odd power");
        name = Printf.sprintf "reduction %d %s %d" k letters n }
  | _ -> failwith "three fields were expected"

let examine_substitution k prompt =
  let square = k = "substitution_square" in
  let found, hinted =
    read ~low:"0" ~high:a_number
      (a_factor ^ words ((if square then "x^{2}" else "") ^ "\\sqrt{") ^ a_number ^ words " - x^{2}}")
      3 prompt
  in
  match found with
  | [ high; front; under ] ->
      let top = integer high and c = coefficient front and under = integer under in
      let a = match square_root under with Some a when a >= 1 -> a | _ -> failwith "x^2 is not taken from a square" in
      (* the promise: from 0 to a, where the root ends *)
      if top <> a then failwith "the upper limit is not a";
      let integrand x =
        float_of_int c *. (if square then x *. x else 1.0) *. sqrt (Float.max 0.0 (float_of_int under -. (x *. x)))
      in
      let right = integral_to_a_root integrand 0.0 (float_of_int top) in
      note_number (k ^ ": coefficient") c;
      note_number (k ^ ": a") a;
      { right; slips = []; hinted; case = "any"; name = "" }
  | _ -> failwith "three fields were expected"

let examine_parts_twice prompt =
  let found, hinted = read ~low:"0" ~high:"1" (a_factor ^ words "x^{2} e^{" ^ a_rate ^ words "x}") 2 prompt in
  match found with
  | [ front; inside ] ->
      let k = coefficient front and a = rate inside in
      let fk = float_of_int k and fa = float_of_int a in
      let integrand x = fk *. x *. x *. exp (fa *. x) in
      let v x = exp (fa *. x) /. fa and dv x = exp (fa *. x) in
      (* the first step: u = k x^2 *)
      let first = { u = (fun x -> fk *. x *. x); du = (fun x -> 2.0 *. fk *. x); v; dv } in
      let right, boundary, second = parts_and_slip integrand first 0.0 1.0 in
      (* the second step, on the second integral: u = 2kx / a *)
      let left x = first.du x *. v x in
      let again = { u = (fun x -> 2.0 *. fk *. x /. fa); du = (fun _ -> 2.0 *. fk /. fa); v; dv } in
      let second_right, second_boundary, second_second = parts_and_slip left again 0.0 1.0 in
      if not (near second_right second) then failwith "by parts: the second step is not on the second integral";
      (* the sign is wrong in the second step only *)
      let slip = boundary -. (second_boundary +. second_second) in
      note_number "parts_twice: coefficient" k;
      note_number "parts_twice: rate" a;
      { right; slips = [ ("plus_for_minus", slip) ]; hinted; case = "any"; name = "" }
  | _ -> failwith "two fields were expected"

let examine_log_fractions prompt =
  let found, hinted =
    read ~low:"0" ~high:"1" (words "\\frac{" ^ a_number ^ words "}{(x + " ^ a_number ^ words ")(x + " ^ a_number ^ words ")}") 3 prompt
  in
  match List.map integer found with
  | [ k; a; b ] ->
      if not (1 <= a && a < b) then failwith "the two numbers added to x are not in order";
      let fk = float_of_int k and fa = float_of_int a and fb = float_of_int b in
      let integrand x = fk /. ((x +. fa) *. (x +. fb)) in
      let fractions sign x = fk /. (fb -. fa) *. ((1.0 /. (x +. fa)) +. (sign /. (x +. fb))) in
      (* the promise: the partial fractions, one taken from the other *)
      List.iter
        (fun x -> if not (near (fractions (-1.0) x) (integrand x)) then failwith "the partial fractions are not the integrand")
        [ 0.0; 0.3; 0.5; 0.8; 1.0 ];
      let right = integral integrand 0.0 1.0 in
      let slip = integral (fractions 1.0) 0.0 1.0 in
      note_number "log_fractions: coefficient" k;
      note "log_fractions: a and b" (Printf.sprintf "%d, %d" a b);
      { right; slips = [ ("logs_added", slip) ]; hinted; case = "any"; name = "" }
  | _ -> failwith "three fields were expected"

(* A question worked out from its kind and its prompt. *)
let work k prompt =
  match k with
  | "half_angle" -> examine_half_angle prompt
  | "inverse_tangent" -> examine_inverse_tangent prompt
  | "inverse_sine" -> examine_inverse_sine prompt
  | "parts_exponential" -> examine_parts_exponential prompt
  | "parts_logarithm" -> examine_parts_logarithm prompt
  | "parts_sine" | "parts_cosine" -> examine_parts_trigonometric k prompt
  | "trig_powers" -> examine_trig_powers prompt
  | "reduction" -> examine_reduction prompt
  | "substitution_root" | "substitution_square" -> examine_substitution k prompt
  | "parts_twice" -> examine_parts_twice prompt
  | "log_fractions" -> examine_log_fractions prompt
  | _ -> failwith ("unknown kind " ^ k)

(* ---- The engine's answer ------------------------------------------------------ *)

module F = Rhema_formula

(* How a value is written: a number, one fraction times pi, a formula that
   holds e alone or a logarithm alone, or a formula that is a bare number. *)
type written = Fraction | Pi_multiple | Exponential | Logarithm | Constant_formula

let name_of = function
  | Fraction, true -> "a plain number"
  | Fraction, false -> "a number"
  | Pi_multiple, true -> "a plain multiple of pi"
  | Pi_multiple, false -> "a multiple of pi"
  | Exponential, plain -> if plain then "a plain formula with e" else "a formula with e"
  | Logarithm, plain -> if plain then "a plain formula with a logarithm" else "a formula with a logarithm"
  | Constant_formula, plain -> if plain then "a plain formula that is a number" else "a formula that is a number"

(* What a formula holds besides numbers and arithmetic. The power of e is a
   whole number and a logarithm is that of a positive number. *)
let rec held = function
  | F.Constant _ -> []
  | F.Pi -> [ "pi" ]
  | F.Variable name -> [ "the variable " ^ name ]
  | F.Add (a, b) | F.Subtract (a, b) | F.Multiply (a, b) | F.Divide (a, b) -> held a @ held b
  | F.Power (a, _) | F.Negate a -> held a
  | F.Exp (F.Constant c) when c.Rhema_number.denominator = 1 -> [ "e" ]
  | F.Ln (F.Constant c) when Rhema_number.compare c Rhema_number.zero > 0 -> [ "ln" ]
  | F.Sin a | F.Cos a | F.Tan a | F.Sqrt a | F.Exp a | F.Ln a -> "a function that does not belong" :: held a

(* A multiple of pi is written as one positive fraction in front of pi, as
   3/5*pi, or as pi alone, or as the negative of either. *)
let pi_multiple f =
  let positive = function
    | F.Pi -> Some 1.0
    | F.Multiply (F.Constant c, F.Pi)
      when Rhema_number.compare c Rhema_number.zero > 0 && not (Rhema_number.equal c (Rhema_number.of_int 1)) ->
        Some (Rhema_number.to_float c)
    | _ -> None
  in
  match f with F.Negate g -> Option.map (fun q -> -.q) (positive g) | g -> positive g

let formula_reading f =
  match pi_multiple f with
  | Some q ->
      if not (near (F.evaluate_with (fun _ -> None) f) (q *. pi)) then
        failwith "the formula does not come to the multiple of pi read from it";
      (q *. pi, Pi_multiple)
  | None -> (
      match (f, List.sort_uniq compare (held f)) with
      | F.Constant c, [] -> (Rhema_number.to_float c, Constant_formula)
      | _, [ "e" ] -> (F.evaluate_with (fun _ -> None) f, Exponential)
      | _, [ "ln" ] -> (F.evaluate_with (fun _ -> None) f, Logarithm)
      | _, [] -> failwith "a formula of numbers that is not worked out"
      | _, [ "pi" ] -> failwith "a formula with pi that is not one fraction times pi"
      | _, things -> failwith ("a formula that holds " ^ String.concat " and " things))

(* The number a value is, how it is written, and whether it is `plain`. *)
let reading = function
  | Rhema_engine.Plain (Rhema_engine.Num n) -> (Rhema_number.to_float n, Fraction, true)
  | Rhema_engine.Num n -> (Rhema_number.to_float n, Fraction, false)
  | Rhema_engine.Plain (Rhema_engine.Formula f) ->
      let value, written = formula_reading f in
      (value, written, true)
  | Rhema_engine.Formula f ->
      let value, written = formula_reading f in
      (value, written, false)
  | other -> failwith ("a value of an unexpected type: " ^ Rhema_engine.describe_value other)

(* ---- The kinds ---------------------------------------------------------------- *)

(* Each kind with its price and with how its answer is written when it is
   neither a fraction nor a fraction times pi. *)
let kinds =
  [ ("half_angle", 1, None); ("inverse_tangent", 1, None); ("inverse_sine", 1, None);
    ("parts_exponential", 2, Some Exponential); ("parts_logarithm", 2, Some Exponential); ("parts_sine", 2, None);
    ("parts_cosine", 2, None); ("trig_powers", 2, None); ("reduction", 3, None); ("substitution_root", 3, None);
    ("substitution_square", 3, None); ("parts_twice", 3, Some Exponential); ("log_fractions", 3, Some Logarithm) ]

(* How the answer of a question of a kind is written, from its value: the
   promise of the grammar's header. *)
let written_for k value =
  match small_fraction value with
  | Some _ -> (Fraction, true)
  | None -> (
      match small_fraction (value /. pi) with
      | Some _ -> (Pi_multiple, true)
      | None -> (
          match List.find_opt (fun (name, _, _) -> name = k) kinds with
          | Some (_, _, Some formula) -> (formula, false)
          | _ -> failwith (Printf.sprintf "the value %.12g found here is neither a fraction nor a fraction times pi" value)))

(* What each mistake's description says, word for word, in the order of the
   declarations. *)
let said =
  [ ("half_forgotten", "takes the integral of sin^2 or cos^2 to be the length of the interval, where it is half of it");
    ("scale_forgotten", "leaves out the 1 / a in front of the inverse tangent of x / a");
    ("plus_for_minus", "adds the second integral of an integration by parts, where it is subtracted");
    ("logs_added", "adds the logarithms of the two partial fractions, where one is subtracted from the other") ]

(* The engine's answers by the names of their questions, where answers are
   compared with each other. *)
let answers_by_name : (string, float) Hashtbl.t = Hashtbl.create 256

(* One question: Failure says what is wrong with it. *)
let examine k (q : Rhema_engine.question) =
  let only =
    match q.Rhema_engine.answers with
    | [ only ] -> only
    | answers -> failwith (Printf.sprintf "%d answers and not one" (List.length answers))
  in
  if only <> q.Rhema_engine.answer then failwith "the answer is not the one of the only blank";
  let got, written, plain = reading only in
  let { right; slips; hinted; case; name } = work k q.Rhema_engine.prompt in
  if not (near got right) then failwith (Printf.sprintf "the answer is %.12g, and worked out here %.12g" got right);
  let expected = written_for k right in
  if (written, plain) <> expected then
    failwith (Printf.sprintf "the answer is %s, where %s is expected" (name_of (written, plain)) (name_of expected));
  note (Printf.sprintf "%s: answer, %s" k case) (name_of (written, plain));
  if hinted <> (written = Pi_multiple) then
    failwith (if hinted then "the sentence says how pi is written, and the answer has none" else "the sentence does not say how pi is written");
  if written <> Fraction && Float.abs got >= 1000.0 then failwith "a formula answer worth 1000 or more";
  if name <> "" then Hashtbl.replace answers_by_name name got;
  (* the mistakes: one that comes to the right answer is not a mistake of
     this question; any other is more than 1% away *)
  let expected_names =
    List.filter_map
      (fun (mistake, _) ->
        match List.assoc_opt mistake slips with
        | None -> None
        | Some slip ->
            if near slip right then begin
              note (Printf.sprintf "%s: %s, %s" k mistake case) "not listed";
              None
            end
            else if Float.abs (slip -. right) <= 0.01 *. Float.abs right then
              failwith (Printf.sprintf "%s gives %.12g, within 1%% of the right answer" mistake slip)
            else Some mistake)
      said
  in
  List.iter (fun (mistake, _) -> if not (List.mem_assoc mistake said) then failwith ("a mistake with no description: " ^ mistake)) slips;
  let listed = q.Rhema_engine.mistakes in
  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
  if names <> expected_names then
    failwith
      (Printf.sprintf "the mistakes listed are [%s], not [%s]" (String.concat ", " names) (String.concat ", " expected_names));
  List.iter
    (fun (m : Rhema_engine.mistaken) ->
      if List.assoc_opt m.mistake said <> Some m.description then
        failwith (Printf.sprintf "%s is described as %S" m.mistake m.description);
      match m.mistaken_answers with
      | Some [ value ] ->
          let given, shape, flat = reading value in
          let slip = List.assoc m.mistake slips in
          if not (near given slip) then failwith (Printf.sprintf "%s gives %.12g, and redone here %.12g" m.mistake given slip);
          if Float.abs (given -. got) <= 0.01 *. Float.abs got then
            failwith (Printf.sprintf "%s gives %.12g, within 1%% of the right answer" m.mistake given);
          note (Printf.sprintf "%s: %s, %s" k m.mistake case) ("listed as " ^ name_of (shape, flat))
      | _ -> failwith (m.mistake ^ " does not give one answer"))
    listed

(* ---- The working of this file, tried on examples --------------------------- *)

let trials () =
  let expect name condition = if not condition then fail ("trial: " ^ name) in
  let refused work = match work () with _ -> false | exception Failure _ -> true in
  (* numbers as they are written *)
  expect "a coefficient is read" (coefficient "" = 1 && coefficient "6" = 6);
  List.iter
    (fun text -> expect ("this coefficient should be refused: " ^ text) (refused (fun () -> coefficient text)))
    [ "1"; "0"; "02"; "-2"; "+2" ];
  expect "a rate is read" (rate "" = 1 && rate "-" = -1 && rate "-3" = -3 && rate "2" = 2);
  List.iter (fun text -> expect ("this rate should be refused: " ^ text) (refused (fun () -> rate text))) [ "1"; "-1"; "0"; "-0"; "+2"; "--2" ];
  expect "a power is read" (power_of "" = 1 && power_of "^{3}" = 3 && power_of "^{12}" = 12);
  List.iter
    (fun text -> expect ("this power should be refused: " ^ text) (refused (fun () -> power_of text)))
    [ "^{1}"; "^{}"; "^3"; "{3}"; "^{3"; "^{03}"; "3" ];
  (* integrals with known answers *)
  expect "the integral of x^2 from 0 to 3" (near (integral (fun x -> x *. x) 0.0 3.0) 9.0);
  expect "the integral of 1 / x from 1 to e" (near (integral (fun x -> 1.0 /. x) 1.0 (exp 1.0)) 1.0);
  expect "the integral of sin from 0 to pi" (near (integral sin 0.0 pi) 2.0);
  expect "the integral of e^(2x) from 0 to 1" (near (integral (fun x -> exp (2.0 *. x)) 0.0 1.0) ((exp 2.0 -. 1.0) /. 2.0));
  expect "the integral of sqrt(4 - x) from 0 to 4" (near (integral_to_a_root (fun x -> sqrt (4.0 -. x)) 0.0 4.0) (16.0 /. 3.0));
  expect "the integral of x sqrt(1 - x) from 0 to 1" (near (integral_to_a_root (fun x -> x *. sqrt (1.0 -. x)) 0.0 1.0) (4.0 /. 15.0));
  expect "the plain rule is not good enough at a root" (not (near (integral (fun x -> sqrt (4.0 -. x)) 0.0 4.0) (16.0 /. 3.0)));
  expect "the slope of x^3 at 2" (close ~within:1e-6 (slope (fun x -> x *. x *. x) 2.0) 12.0);
  (* by parts: x cos x from 0 to 1 with u = x *)
  let integrand x = x *. cos x in
  let split = { u = Fun.id; du = (fun _ -> 1.0); v = sin; dv = cos } in
  let boundary, second = by_parts integrand split 0.0 1.0 in
  expect "by parts: the boundary term" (near boundary (sin 1.0));
  expect "by parts: the second integral" (near second (1.0 -. cos 1.0));
  expect "by parts: the integral" (near (boundary -. second) (integral integrand 0.0 1.0));
  expect "a split of another integrand is refused" (refused (fun () -> by_parts integrand { split with dv = sin } 0.0 1.0));
  expect "a split with a wrong du is refused" (refused (fun () -> by_parts integrand { split with du = Fun.id } 0.0 1.0));
  expect "a split with a wrong v is refused"
    (refused (fun () -> by_parts integrand { split with v = (fun x -> -.sin x) } 0.0 1.0));
  (* fractions *)
  expect "3/8 is a fraction" (small_fraction 0.375 = Some (3, 8));
  expect "-16/35 is a fraction" (small_fraction (-16.0 /. 35.0) = Some (-16, 35));
  expect "12 is a fraction" (small_fraction 12.0 = Some (12, 1));
  expect "105/256 is a fraction" (small_fraction (105.0 /. 256.0) = Some (105, 256));
  expect "1/257 is not a fraction" (small_fraction (1.0 /. 257.0) = None);
  expect "pi is not a fraction" (small_fraction pi = None);
  expect "e^2 / 4 + 1 / 4 is not a fraction" (small_fraction ((exp 2.0 +. 1.0) /. 4.0) = None);
  expect "ln(4/3) is not a fraction" (small_fraction (log (4.0 /. 3.0)) = None && small_fraction (log (4.0 /. 3.0) /. pi) = None);
  (* how values are written *)
  let number top bottom = F.Constant (Rhema_number.make top bottom) in
  let reads name formula expected =
    expect ("the formula " ^ name)
      (match formula_reading formula with
       | value, written -> ( match expected with Some (v, w) -> near value v && written = w | None -> false)
       | exception Failure _ -> expected = None)
  in
  reads "pi" F.Pi (Some (pi, Pi_multiple));
  reads "3/5 pi" (F.Multiply (number 3 5, F.Pi)) (Some (0.6 *. pi, Pi_multiple));
  reads "-(3/2 pi)" (F.Negate (F.Multiply (number 3 2, F.Pi))) (Some (-1.5 *. pi, Pi_multiple));
  reads "-pi" (F.Negate F.Pi) (Some (-.pi, Pi_multiple));
  reads "1 pi" (F.Multiply (number 1 1, F.Pi)) None;
  reads "pi 3/5" (F.Multiply (F.Pi, number 3 5)) None;
  reads "-3/5 pi" (F.Multiply (number (-3) 5, F.Pi)) None;
  reads "3 pi / 5" (F.Divide (F.Multiply (number 3 1, F.Pi), number 5 1)) None;
  reads "3/5 pi + 1" (F.Add (F.Multiply (number 3 5, F.Pi), number 1 1)) None;
  reads "2/3 e^3 + 1/3"
    (F.Add (F.Multiply (number 2 3, F.Exp (number 3 1)), number 1 3))
    (Some ((2.0 *. exp 3.0 /. 3.0) +. (1.0 /. 3.0), Exponential));
  reads "5/4 ln(5/3)" (F.Multiply (number 5 4, F.Ln (number 5 3))) (Some (1.25 *. log (5.0 /. 3.0), Logarithm));
  reads "5" (number 5 1) (Some (5.0, Constant_formula));
  reads "2 + 3" (F.Add (number 2 1, number 3 1)) None;
  reads "e^3 + ln 2" (F.Add (F.Exp (number 3 1), F.Ln (number 2 1))) None;
  reads "e^(1/2)" (F.Exp (number 1 2)) None;
  reads "e^pi" (F.Exp F.Pi) None;
  reads "ln(-2)" (F.Ln (number (-2) 1)) None;
  reads "sin(1)" (F.Sin (number 1 1)) None;
  reads "sqrt(2)" (F.Sqrt (number 2 1)) None;
  reads "x e^2" (F.Multiply (F.Variable "x", F.Exp (number 2 1))) None;
  expect "a fraction is a plain number" (written_for "trig_powers" (5.0 /. 12.0) = (Fraction, true));
  expect "a fraction times pi is a plain multiple of pi" (written_for "reduction" (3.0 *. pi /. 16.0) = (Pi_multiple, true));
  expect "a value with e is a formula" (written_for "parts_twice" (exp 1.0 -. 2.0) = (Exponential, false));
  expect "a value with a logarithm is a formula" (written_for "log_fractions" (log 1.5) = (Logarithm, false));
  expect "a value with e is refused where a fraction belongs" (refused (fun () -> written_for "reduction" (exp 1.0 -. 2.0)));
  (* sentences: the integrals, and what is not written as it should be *)
  let ask integrand ~low ~high ~hint =
    Printf.sprintf "Evaluate [`\\int_{%s}^{%s} %s \\, dx`]. Give the exact value.%s" low high integrand
      (if hint then " Write [`\\pi`] as pi." else "")
  in
  let comes k prompt value slips =
    expect ("this sentence should be read: " ^ prompt)
      (match work k prompt with
       | worked ->
           near worked.right value
           && List.length worked.slips = List.length slips
           && List.for_all2 (fun (name, found) (expected_name, expected) -> name = expected_name && close found expected) worked.slips slips
       | exception Failure _ -> false)
  in
  let not_read k prompt = expect ("this sentence should be refused: " ^ prompt) (refused (fun () -> work k prompt)) in
  comes "half_angle" (ask "3\\sin^{2}(2x)" ~low:"0" ~high:"\\pi" ~hint:true) (1.5 *. pi) [ ("half_forgotten", 3.0 *. pi) ];
  comes "half_angle" (ask "\\cos^{2}(x)" ~low:"0" ~high:"\\pi/2" ~hint:true) (pi /. 4.0) [ ("half_forgotten", pi /. 2.0) ];
  not_read "half_angle" (ask "\\cos^{2}(1x)" ~low:"0" ~high:"\\pi/2" ~hint:true);
  not_read "half_angle" (ask "1\\cos^{2}(x)" ~low:"0" ~high:"\\pi/2" ~hint:true);
  not_read "half_angle" (ask "\\cos^{3}(x)" ~low:"0" ~high:"\\pi/2" ~hint:true);
  not_read "half_angle" (ask "\\cos^{2}(x)" ~low:"0" ~high:"\\pi/4" ~hint:true);
  not_read "half_angle" (ask "\\cos^{2}(x)" ~low:"1" ~high:"\\pi" ~hint:true);
  not_read "half_angle" (ask "\\tan^{2}(x)" ~low:"0" ~high:"\\pi" ~hint:true);
  comes "inverse_tangent" (ask "\\frac{3}{x^{2} + 4}" ~low:"0" ~high:"2" ~hint:true) (3.0 *. pi /. 8.0) [ ("scale_forgotten", 3.0 *. pi /. 4.0) ];
  comes "inverse_tangent" (ask "\\frac{1}{x^{2} + 1}" ~low:"0" ~high:"1" ~hint:true) (pi /. 4.0) [ ("scale_forgotten", pi /. 4.0) ];
  not_read "inverse_tangent" (ask "\\frac{3}{x^{2} + 5}" ~low:"0" ~high:"2" ~hint:true);
  not_read "inverse_tangent" (ask "\\frac{3}{x^{2} + 4}" ~low:"0" ~high:"1" ~hint:true);
  not_read "inverse_tangent" (ask "\\frac{3}{x^{2} - 4}" ~low:"0" ~high:"2" ~hint:true);
  comes "inverse_sine" (ask "\\frac{5}{\\sqrt{100 - x^{2}}}" ~low:"0" ~high:"5" ~hint:true) (5.0 *. pi /. 6.0) [];
  not_read "inverse_sine" (ask "\\frac{5}{\\sqrt{100 - x^{2}}}" ~low:"0" ~high:"10" ~hint:true);
  not_read "inverse_sine" (ask "\\frac{5}{\\sqrt{99 - x^{2}}}" ~low:"0" ~high:"5" ~hint:true);
  not_read "inverse_sine" (ask "\\frac{5}{\\sqrt{9 - x^{2}}}" ~low:"0" ~high:"1" ~hint:true);
  comes "parts_exponential" (ask "x e^{x}" ~low:"0" ~high:"1" ~hint:false) 1.0 [ ("plus_for_minus", (2.0 *. exp 1.0) -. 1.0) ];
  comes "parts_exponential" (ask "2x e^{-x}" ~low:"0" ~high:"1" ~hint:false) (2.0 -. (4.0 /. exp 1.0)) [ ("plus_for_minus", -2.0) ];
  not_read "parts_exponential" (ask "1x e^{x}" ~low:"0" ~high:"1" ~hint:false);
  not_read "parts_exponential" (ask "x e^{1x}" ~low:"0" ~high:"1" ~hint:false);
  not_read "parts_exponential" (ask "x e^{0x}" ~low:"0" ~high:"1" ~hint:false);
  not_read "parts_exponential" (ask "x e^{x}" ~low:"0" ~high:"2" ~hint:false);
  not_read "parts_exponential" (ask "x^{2} e^{x}" ~low:"0" ~high:"1" ~hint:false);
  comes "parts_logarithm" (ask "x \\ln x" ~low:"1" ~high:"e" ~hint:false) ((exp 2.0 +. 1.0) /. 4.0)
    [ ("plus_for_minus", ((3.0 *. exp 2.0) -. 1.0) /. 4.0) ];
  not_read "parts_logarithm" (ask "x^{1} \\ln x" ~low:"1" ~high:"e" ~hint:false);
  not_read "parts_logarithm" (ask "x \\ln x" ~low:"0" ~high:"e" ~hint:false);
  not_read "parts_logarithm" (ask "x \\ln x" ~low:"1" ~high:"1" ~hint:false);
  comes "parts_sine" (ask "3x \\sin(2x)" ~low:"0" ~high:"\\pi" ~hint:true) (-1.5 *. pi) [ ("plus_for_minus", -1.5 *. pi) ];
  comes "parts_cosine" (ask "x \\cos(3x)" ~low:"0" ~high:"\\pi" ~hint:false) (-2.0 /. 9.0) [ ("plus_for_minus", 2.0 /. 9.0) ];
  comes "parts_cosine" (ask "4x \\cos(5x)" ~low:"0" ~high:"\\pi" ~hint:false) (-8.0 /. 25.0) [ ("plus_for_minus", 8.0 /. 25.0) ];
  not_read "parts_cosine" (ask "x \\cos(2x)" ~low:"0" ~high:"\\pi" ~hint:false);
  not_read "parts_cosine" (ask "x \\sin(3x)" ~low:"0" ~high:"\\pi" ~hint:false);
  not_read "parts_sine" (ask "x \\cos(3x)" ~low:"0" ~high:"\\pi" ~hint:true);
  not_read "parts_sine" (ask "x \\sin(3x)" ~low:"0" ~high:"\\pi/2" ~hint:true);
  comes "trig_powers" (ask "5\\sin^{3} x \\, \\cos^{3} x" ~low:"0" ~high:"\\pi/2" ~hint:false) (5.0 /. 12.0) [];
  comes "trig_powers" (ask "\\cos x \\, \\sin x" ~low:"0" ~high:"\\pi/2" ~hint:false) 0.5 [];
  not_read "trig_powers" (ask "\\cos x \\, \\cos x" ~low:"0" ~high:"\\pi/2" ~hint:false);
  not_read "trig_powers" (ask "\\cos x \\, \\sin^{2} x" ~low:"0" ~high:"\\pi/2" ~hint:false);
  not_read "trig_powers" (ask "\\cos^{1} x \\, \\sin x" ~low:"0" ~high:"\\pi/2" ~hint:false);
  not_read "trig_powers" (ask "\\cos x \\sin x" ~low:"0" ~high:"\\pi/2" ~hint:false);
  not_read "trig_powers" (ask "\\cos x \\, \\sin x" ~low:"0" ~high:"\\pi" ~hint:false);
  comes "reduction" (ask "3\\sin^{7} x" ~low:"0" ~high:"\\pi/2" ~hint:false) (48.0 /. 35.0) [];
  comes "reduction" (ask "\\cos^{4} x" ~low:"0" ~high:"\\pi/2" ~hint:true) (3.0 *. pi /. 16.0) [];
  not_read "reduction" (ask "\\cos^{1} x" ~low:"0" ~high:"\\pi/2" ~hint:false);
  not_read "reduction" (ask "\\cos x" ~low:"0" ~high:"\\pi/2" ~hint:false);
  not_read "reduction" (ask "\\cos^{2} x" ~low:"0" ~high:"\\pi/2" ~hint:true);
  comes "reduction" (ask "2\\sin^{8} x" ~low:"0" ~high:"\\pi/2" ~hint:true) (35.0 *. pi /. 128.0) [];
  comes "substitution_root" (ask "2\\sqrt{9 - x^{2}}" ~low:"0" ~high:"3" ~hint:true) (4.5 *. pi) [];
  comes "substitution_square" (ask "x^{2}\\sqrt{16 - x^{2}}" ~low:"0" ~high:"4" ~hint:true) (16.0 *. pi) [];
  not_read "substitution_root" (ask "x^{2}\\sqrt{16 - x^{2}}" ~low:"0" ~high:"4" ~hint:true);
  not_read "substitution_square" (ask "2\\sqrt{9 - x^{2}}" ~low:"0" ~high:"3" ~hint:true);
  not_read "substitution_root" (ask "2\\sqrt{9 - x^{2}}" ~low:"0" ~high:"2" ~hint:true);
  not_read "substitution_root" (ask "2\\sqrt{8 - x^{2}}" ~low:"0" ~high:"3" ~hint:true);
  comes "parts_twice" (ask "3x^{2} e^{x}" ~low:"0" ~high:"1" ~hint:false) ((3.0 *. exp 1.0) -. 6.0) [ ("plus_for_minus", 6.0 -. (9.0 *. exp 1.0)) ];
  not_read "parts_twice" (ask "3x e^{x}" ~low:"0" ~high:"1" ~hint:false);
  comes "log_fractions" (ask "\\frac{3}{(x + 1)(x + 5)}" ~low:"0" ~high:"1" ~hint:false) (0.75 *. log (5.0 /. 3.0))
    [ ("logs_added", 0.75 *. log 2.4) ];
  not_read "log_fractions" (ask "\\frac{3}{(x + 5)(x + 1)}" ~low:"0" ~high:"1" ~hint:false);
  not_read "log_fractions" (ask "\\frac{3}{(x + 2)(x + 2)}" ~low:"0" ~high:"1" ~hint:false);
  not_read "log_fractions" (ask "\\frac{3}{(x - 1)(x + 5)}" ~low:"0" ~high:"1" ~hint:false);
  not_read "log_fractions" (ask "\\frac{3}{(x + 1)(x + 5)}" ~low:"0" ~high:"1" ~hint:false ^ " ");
  not_read "no_such_kind" (ask "x" ~low:"0" ~high:"1" ~hint:false);
  (* nothing of the trials is counted among what the grammar offers *)
  Hashtbl.reset noted

(* ---- The questions ----------------------------------------------------------- *)

let questions_at_each_budget = 3000
let questions_for_the_shares = 40000

(* Added to every seed: another number gives other draws, and the suite
   passes with them too. *)
let seed_offset = 0

(* A question that was looked at already, with the same answer and the same
   mistakes, is not worked out again. *)
let examined : (string, unit) Hashtbl.t = Hashtbl.create 4096

let () =
  trials ();
  let base = load_file "integration_techniques.rhm" in
  let seen = Hashtbl.create 16 and generated = Hashtbl.create 4 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at_each_budget - 1 do
      Random.init (seed_offset + seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          Hashtbl.replace generated cost (1 + Option.value ~default:0 (Hashtbl.find_opt generated cost));
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s, not Numeric" k q.Rhema_engine.context);
          (match Rhema_engine.attribute q.Rhema_engine.tree "text" with
           | Rhema_engine.Text t when t = p -> ()
           | _ -> fail (Printf.sprintf "%s: the prompt is not the text of the question, for %S" k p));
          match List.find_opt (fun (name, _, _) -> name = k) kinds with
          | None -> fail ("a kind the header does not list: " ^ k)
          | Some (_, price, _) ->
              if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost)
              else
                let whole_question = String.concat "\n" (k :: p :: q.Rhema_engine.answer_text :: Rhema_engine.describe_mistakes q) in
                if not (Hashtbl.mem examined whole_question) then begin
                  Hashtbl.replace examined whole_question ();
                  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
                  try examine k q with Failure m -> wrong m | e -> wrong (Printexc.to_string e)
                end)
    done
  done;
  for cost = 1 to 3 do
    let count = Option.value ~default:0 (Hashtbl.find_opt generated cost) in
    if count < questions_at_each_budget then fail (Printf.sprintf "only %d questions at cost %d" count cost)
  done;
  List.iter (fun (k, _, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) kinds;
  (* Every choice the grammar offers is taken at least once, and no other. *)
  let range first last = List.init (last - first + 1) (fun n -> string_of_int (first + n)) in
  let ints first last = List.init (last - first + 1) (fun n -> first + n) in
  let each things f = List.concat_map f things in
  let plain_pi = "a plain multiple of pi" and plain_number = "a plain number" in
  let with_e = "a formula with e" and with_ln = "a formula with a logarithm" in
  let choices =
    [ ("half_angle: coefficient", range 1 6); ("half_angle: m", range 1 4);
      ( "half_angle: function, m and upper limit",
        each [ "sin"; "cos" ] (fun f -> each (ints 1 4) (fun m -> List.map (Printf.sprintf "%s, %d, %s" f m) [ "pi"; "pi/2" ])) );
      ("half_angle: answer, any", [ plain_pi ]); ("half_angle: half_forgotten, any", [ "listed as " ^ plain_pi ]);
      ("inverse_tangent: coefficient", range 1 6); ("inverse_tangent: a", range 1 5);
      ("inverse_tangent: answer, a = 1", [ plain_pi ]); ("inverse_tangent: answer, a over 1", [ plain_pi ]);
      ("inverse_tangent: scale_forgotten, a = 1", [ "not listed" ]);
      ("inverse_tangent: scale_forgotten, a over 1", [ "listed as " ^ plain_pi ]);
      ("inverse_sine: coefficient", range 1 6); ("inverse_sine: upper limit", range 1 5);
      ("inverse_sine: answer, any", [ plain_pi ]);
      ("parts_exponential: coefficient", range 1 6); ("parts_exponential: rate", [ "-3"; "-2"; "-1"; "1"; "2"; "3" ]);
      ("parts_exponential: answer, rate 1", [ plain_number ]); ("parts_exponential: answer, rate -1", [ with_e ]);
      ("parts_exponential: answer, another rate", [ with_e ]);
      ("parts_exponential: plus_for_minus, rate 1", [ "listed as " ^ with_e ]);
      ("parts_exponential: plus_for_minus, rate -1", [ "listed as a formula that is a number" ]);
      ("parts_exponential: plus_for_minus, another rate", [ "listed as " ^ with_e ]);
      ("parts_logarithm: coefficient", range 1 6); ("parts_logarithm: power", range 1 4);
      ("parts_logarithm: answer, any", [ with_e ]); ("parts_logarithm: plus_for_minus, any", [ "listed as " ^ with_e ]);
      ("parts_sine: coefficient", range 1 6); ("parts_sine: m", range 1 4); ("parts_sine: answer, any", [ plain_pi ]);
      ("parts_sine: plus_for_minus, any", [ "not listed" ]);
      ("parts_cosine: coefficient", range 1 6); ("parts_cosine: m", [ "1"; "3"; "5" ]);
      ("parts_cosine: answer, any", [ plain_number ]); ("parts_cosine: plus_for_minus, any", [ "listed as " ^ plain_number ]);
      ("trig_powers: coefficient", range 1 6);
      ( "trig_powers: first function, its power and the second power",
        each [ "sin"; "cos" ] (fun f -> each (ints 1 5) (fun a -> List.map (Printf.sprintf "%s, %d, %d" f a) [ 1; 3 ])) );
      ("trig_powers: answer, any", [ plain_number ]);
      ("reduction: coefficient", range 1 4);
      ("reduction: function and power", each [ "sin"; "cos" ] (fun f -> List.map (Printf.sprintf "%s, %d" f) (ints 3 8)));
      ("reduction: answer, even power", [ plain_pi ]); ("reduction: answer, odd power", [ plain_number ]);
      ("substitution_root: coefficient", range 1 5); ("substitution_root: a", range 1 4);
      ("substitution_root: answer, any", [ plain_pi ]);
      ("substitution_square: coefficient", range 1 5); ("substitution_square: a", range 1 4);
      ("substitution_square: answer, any", [ plain_pi ]);
      ("parts_twice: coefficient", range 1 6); ("parts_twice: rate", [ "-2"; "-1"; "1"; "2" ]);
      ("parts_twice: answer, any", [ with_e ]); ("parts_twice: plus_for_minus, any", [ "listed as " ^ with_e ]);
      ("log_fractions: coefficient", range 1 6);
      ( "log_fractions: a and b",
        each (ints 1 4) (fun a -> List.filter_map (fun b -> if a < b then Some (Printf.sprintf "%d, %d" a b) else None) (ints 2 5)) );
      ("log_fractions: answer, any", [ with_ln ]); ("log_fractions: logs_added, any", [ "listed as " ^ with_ln ]) ]
  in
  List.iter
    (fun (topic, offered) ->
      let met = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
      List.iter (fun choice -> if not (List.mem choice met) then fail (Printf.sprintf "never generated: %s %s" topic choice)) offered;
      List.iter (fun choice -> if not (List.mem choice offered) then fail (Printf.sprintf "not offered: %s %s" topic choice)) met)
    choices;
  Hashtbl.iter (fun topic _ -> if not (List.mem_assoc topic choices) then fail ("nothing is said of: " ^ topic)) noted;
  (* Exchanging sine and cosine changes nothing but the letters: the two
     letterings of the same numbers have the same answer. *)
  let answer name = Hashtbl.find_opt answers_by_name name in
  let compared = ref 0 in
  List.iter
    (fun k ->
      List.iter
        (fun a ->
          List.iter
            (fun b ->
              match
                (answer (Printf.sprintf "trig_powers %d sin %d %d" k a b), answer (Printf.sprintf "trig_powers %d cos %d %d" k a b))
              with
              | Some one, Some other ->
                  incr compared;
                  if not (near one other) then fail (Printf.sprintf "trig_powers: the letters change the answer for %d, %d, %d" k a b)
              | _ -> ())
            [ 1; 3 ])
        (ints 1 5))
    (ints 1 6);
  if !compared < 40 then fail (Printf.sprintf "trig_powers: only %d pairs of letterings were compared" !compared);
  (* The reduction formula: n I(n) = (n - 1) I(n - 2), and the same for
     sine and cosine. *)
  let reduced = ref 0 and exchanged = ref 0 in
  List.iter
    (fun k ->
      List.iter
        (fun n ->
          let of_letters letters power = answer (Printf.sprintf "reduction %d %s %d" k letters power) in
          (match (of_letters "sin" n, of_letters "cos" n) with
           | Some one, Some other ->
               incr exchanged;
               if not (near one other) then fail (Printf.sprintf "reduction: the letters change the answer for %d, %d" k n)
           | _ -> ());
          List.iter
            (fun letters ->
              match (of_letters letters n, of_letters letters (n - 2)) with
              | Some this, Some before ->
                  incr reduced;
                  if not (near (float_of_int n *. this) (float_of_int (n - 1) *. before)) then
                    fail (Printf.sprintf "reduction: the formula does not lead from %d to %d for %d %s" (n - 2) n k letters)
              | _ -> ())
            [ "sin"; "cos" ])
        (ints 3 8))
    (ints 1 4);
  if !reduced < 20 || !exchanged < 15 then
    fail (Printf.sprintf "reduction: only %d steps of the formula and %d pairs of letterings were compared" !reduced !exchanged);
  (* By parts with a sine or a cosine: m is as likely to be each of the
     numbers offered. Over many more questions, the count of each is within
     five standard deviations of its share. *)
  let counts : (string * string, int) Hashtbl.t = Hashtbl.create 16 in
  let inside = Str.regexp "\\\\\\(sin\\|cos\\)(\\([0-9]*\\)x)" in
  let at_two = with_initial base "cost" 2 in
  for seed = 0 to questions_for_the_shares - 1 do
    Random.init (seed_offset + seed + 500000);
    match Rhema_engine.generate at_two with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost 2 seed %d: %s" seed m)
    | q -> (
        let k = kind q and p = q.Rhema_engine.prompt in
        if k = "parts_sine" || k = "parts_cosine" then
          match Str.search_forward inside p 0 with
          | _ ->
              let key = (k, Str.matched_group 2 p) in
              Hashtbl.replace counts key (1 + Option.value ~default:0 (Hashtbl.find_opt counts key))
          | exception Not_found -> fail (Printf.sprintf "%s: no m is read in %S" k p))
  done;
  List.iter
    (fun (k, offered) ->
      let count m = Option.value ~default:0 (Hashtbl.find_opt counts (k, m)) in
      let total = float_of_int (List.fold_left (fun sum m -> sum + count m) 0 offered) in
      let share = 1.0 /. float_of_int (List.length offered) in
      let allowed = 5.0 *. sqrt (total *. share *. (1.0 -. share)) in
      if total < float_of_int (questions_for_the_shares / 16) then fail (Printf.sprintf "%s: only %.0f questions for the shares of m" k total);
      List.iter
        (fun m ->
          if Float.abs (float_of_int (count m) -. (total *. share)) > allowed then
            fail
              (Printf.sprintf "%s: m = %s in %d questions of %.0f, where %.0f give or take %.0f are expected" k
                 (if m = "" then "1" else m)
                 (count m) total (total *. share) allowed))
        offered)
    [ ("parts_sine", [ ""; "2"; "3"; "4" ]); ("parts_cosine", [ ""; "3"; "5" ]) ];
  (* The grammar as it is written sets itself the budget 2 and gives a
     question of that price. *)
  for seed = 0 to 19 do
    Random.init (seed_offset + seed);
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q -> (
        match List.find_opt (fun (name, _, _) -> name = kind q) kinds with
        | Some (_, 2, _) when Rhema_engine.consumption q.Rhema_engine.tree "cost" = 2 -> ()
        | _ -> fail (Printf.sprintf "the grammar's own budget gave %s, not a question of price 2" (kind q)))
  done;
  (* A budget that no form is priced at gives no question. *)
  List.iter
    (fun cost ->
      for seed = 0 to 19 do
        Random.init (seed_offset + seed);
        match Rhema_engine.generate (with_initial base "cost" cost) with
        | exception Rhema_engine.Generation_error _ -> ()
        | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
      done)
    [ 0; 4; 5; 6 ];
  if !failures = 0 then print_endline "Rhema integration_techniques tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d integration_techniques test(s) failed." !failures);
    exit 1
  end
