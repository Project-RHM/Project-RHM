(* Independent checks for improper_integral.rhm. Nothing here uses the
   grammar's closed formulas. The two limits and the integrand are read back
   from the printed question, whose whole text must be worded as these
   questions are (a text that cannot be read is a failure). The integrand is
   held in a form of its own, one of

     k (x + s)^e           a power of x or of x + s, e a negative fraction
     k x^n e^(r x^m)       a power of x times an exponential, r of either sign
     k / (x^2 + c)

   and the value of the integral is found again in two ways that share
   nothing. Both must agree with the engine's answer.

   (A) In floating point. A half line [a, infinity) is brought onto [0, 1)
   with x = a + t / (1 - t); a half line going to minus infinity is turned
   round first, and the whole line is cut at 0. An interval with a finite
   end where the integrand may be unbounded is brought onto a smooth
   integrand with x = a + u^2. The interval is then cut into 400 panels and
   each is integrated with the 8-point Gauss-Legendre rule, whose nodes are
   found here by Newton's method and never touch an end of the interval.
   The result is within about 1e-10 of the truth for a convergent integral;
   it must be within 1e-6 (relative) of the engine's answer, a fraction or
   a fraction times pi.

   (B) Exactly, on fractions, from the integrand that was read:

   Powers (power_tail, shifted_power, root_singularity): the antiderivative
   of k (x + s)^e is taken by the power rule, k / (e + 1) (x + s)^(e + 1).
   At infinity it must vanish, so e + 1 must be negative: a power 1 gives a
   logarithm and is refused, which is p >= 2 for the whole powers printed.
   At an end where x + s = 0 the new power must be positive, and it then
   gives 0. At any other end x + s must be positive, so the point where the
   integrand is unbounded is never inside the interval; a half power of it
   needs a perfect square there (the upper limit of root_singularity). The
   answer is the value at the upper limit minus the value at the lower.

   Exponentials with a first power in the exponent (exponential_tail,
   first_moment, second_moment): an integral from minus infinity to 0 is
   turned into one from 0 to infinity by x -> -x, which changes the sign of
   the rate. The rate must then be negative, the exponential decaying on
   the side integrated over. With a = -rate the value is k I_n, where
   I_0 = 1 / a and I_n = (n / a) I_(n-1), integration by parts done n times.

   Exponential of -a x^2 (square_exponent): the power in front must be odd,
   n = 2 j + 1, and u = x^2 turns the integral into half of that of
   k u^j e^(-a u), found as above.

   k / (x^2 + c) (arctangent): c must be a perfect square a^2, and the
   antiderivative is (k / a) arctan(x / a), which is pi / 2 at infinity,
   -pi / 2 at minus infinity and 0 at 0; any other limit is refused. The
   value is a fraction times pi. The engine's answer must be a formula made
   of numbers and pi alone, with pi to the first power, written as one
   positive fraction in front of pi (or pi alone); its tree is read into
   that fraction, which must be the one found here. The text must tell the
   student to write pi, and must not say so in any other question. The
   answer must be a plain answer, one graded with the functions switched
   off, so that atan is not accepted in it. Every other answer must be a
   number, not a formula, and must not be a plain answer.

   The working of this file is itself tried first, on integrals written by
   hand: convergent ones with their values, and divergent or unanswerable
   ones, which (B) must refuse.

   Besides the answers: every kind of the header has the integrand and the
   limits the header gives it; every integral is improper; each kind
   appears at its price alone and spends its budget; a budget outside 1..3
   gives no question; the budget the grammar sets itself is the middle
   price; there is one answer and no mistake is listed; a coefficient 1 and
   a power 1 are never written; and each printed number of each form takes
   exactly the values expected, none missing and none more. *)

module F = Rhema_formula

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
let to_float a = float a.top /. float a.bottom
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

(* A whole power, of either sign. *)
let rec power a n = if n = 0 then whole 1 else if n < 0 then whole 1 /: power a (-n) else a *: power a (n - 1)

(* The square root of a whole number that is a perfect square. *)
let square_root n =
  let rec up r = if r * r >= n then r else up (r + 1) in
  let r = up 0 in
  if n >= 0 && r * r = n then Some r else None

(* ---- The integral as it is printed --------------------------------------- *)

type bound = Minus_infinity | Finite of int | Plus_infinity

type integrand =
  | Power of { scale : int; shift : int; exponent : fraction }  (* scale (x + shift)^exponent *)
  | Exponential of { scale : int; degree : int; rate : int; inner : int }  (* scale x^degree e^(rate x^inner) *)
  | Quadratic of { scale : int; constant : int }  (* scale / (x^2 + constant) *)

(* A value: a fraction, or a fraction times pi. *)
type result = Rational of fraction | Pi_multiple of fraction

let show_result = function Rational a -> show a | Pi_multiple a -> show a ^ " pi"
let float_of_result = function Rational a -> to_float a | Pi_multiple a -> to_float a *. Float.pi

(* ---- Reading the text ----------------------------------------------------- *)

(* The whole of `text` must be the pattern. Its groups are given back, all
   taken at once, before any other pattern is tried: a group that took no
   part in the match is None. *)
let fields re count text =
  if Str.string_match (Str.regexp re) text 0 && Str.match_end () = String.length text then
    Some (Array.init count (fun i -> match Str.matched_group (i + 1) text with s -> Some s | exception Not_found -> None))
  else None

let field groups n = match groups.(n - 1) with Some s -> s | None -> failwith "a part of the text is missing"

(* A whole number written without a sign and without a 0 in front. *)
let number text =
  match fields "0\\|[1-9][0-9]*" 0 text with
  | Some _ -> int_of_string text
  | None -> failwith ("cannot read the number \"" ^ text ^ "\"")

(* A number written in front of something: nothing stands for 1, and 0 and
   1 are never written. *)
let coefficient text =
  if text = "" then 1
  else
    let n = number text in
    if n < 2 then failwith ("a coefficient " ^ text ^ " is written out");
    n

(* A power written with ^{ }: no ^{ } stands for 1, and 0 and 1 are never
   written. *)
let written_power = function
  | None -> 1
  | Some text ->
      let n = number text in
      if n < 2 then failwith ("a power " ^ text ^ " is written out");
      n

let question_re =
  "Evaluate the improper integral \\[`\\\\int_{\\([^{}`]*\\)}\\^{\\([^{}`]*\\)} \\([^`]*\\) \\\\, dx`\\]\\.\\( Give the exact \
   value, with \\[`\\\\pi`\\] written as pi\\.\\)?"

let bound text =
  if text = "\\infty" then Plus_infinity
  else if text = "-\\infty" then Minus_infinity
  else if text <> "" && text.[0] = '-' then
    let n = number (String.sub text 1 (String.length text - 1)) in
    if n = 0 then failwith "minus 0 as a limit" else Finite (-n)
  else Finite (number text)

(* The integrand, in one of the shapes these questions print:
   \frac{k}{x^{p}}, \frac{k}{(x + s)^{p}}, \frac{k}{\sqrt{x}},
   \frac{k}{x^{2} + c}, and k x^{n} e^{-a x^{m}} with k, the power of x in
   front, a and m all optional. *)
let shapes =
  let signed sign n = if sign = "-" then -n else n in
  [ ( "\\\\frac{\\([0-9]+\\)}{x\\(\\^{\\([0-9]+\\)}\\)?}",
      3,
      fun g -> Power { scale = number (field g 1); shift = 0; exponent = whole (-written_power g.(2)) } );
    ( "\\\\frac{\\([0-9]+\\)}{(x \\([-+]\\) \\([0-9]+\\))\\(\\^{\\([0-9]+\\)}\\)?}",
      5,
      fun g ->
        let shift = signed (field g 2) (number (field g 3)) in
        Power { scale = number (field g 1); shift; exponent = whole (-written_power g.(4)) } );
    ( "\\\\frac{\\([0-9]+\\)}{\\\\sqrt{x}}",
      1,
      fun g -> Power { scale = number (field g 1); shift = 0; exponent = fraction (-1) 2 } );
    ( "\\\\frac{\\([0-9]+\\)}{x\\^{2} \\([-+]\\) \\([0-9]+\\)}",
      3,
      fun g -> Quadratic { scale = number (field g 1); constant = signed (field g 2) (number (field g 3)) } );
    ( "\\([0-9]*\\)\\(x\\(\\^{\\([0-9]+\\)}\\)? \\)?e\\^{\\(-?\\)\\([0-9]*\\)x\\(\\^{\\([0-9]+\\)}\\)?}",
      8,
      fun g ->
        let degree = match g.(1) with None -> 0 | Some _ -> written_power g.(3) in
        let rate = signed (field g 5) (coefficient (field g 6)) in
        Exponential { scale = coefficient (field g 1); degree; rate; inner = written_power g.(7) } ) ]

let integrand text =
  let rec first = function
    | (re, count, build) :: rest -> ( match fields re count text with Some g -> build g | None -> first rest)
    | [] -> failwith ("cannot read the integrand \"" ^ text ^ "\"")
  in
  first shapes

(* The two limits, the integrand, and whether the text asks for pi. *)
let read text =
  match fields question_re 4 text with
  | None -> failwith "the text is not worded as an improper integral is"
  | Some g -> (bound (field g 1), bound (field g 2), integrand (field g 3), g.(3) <> None)

(* ---- (A) The value in floating point -------------------------------------- *)

let value_at integrand x =
  match integrand with
  | Power { scale; shift; exponent } -> float scale *. ((x +. float shift) ** to_float exponent)
  | Exponential { scale; degree; rate; inner } -> float scale *. (x ** float degree) *. exp (float rate *. (x ** float inner))
  | Quadratic { scale; constant } -> float scale /. ((x *. x) +. float constant)

(* The nodes and weights of the Gauss-Legendre rule with n points on
   [-1, 1]: the roots of the Legendre polynomial P_n, by Newton's method. *)
let gauss_legendre n =
  Array.init n (fun i ->
      let x = ref (cos (Float.pi *. (float i +. 0.75) /. (float n +. 0.5))) in
      let slope = ref 0. in
      for _ = 1 to 50 do
        (* P_n and P_(n-1) at x, by the three-term recurrence *)
        let before = ref 1. and current = ref !x in
        for j = 2 to n do
          let next = (((2. *. float j) -. 1.) *. !x *. !current -. ((float j -. 1.) *. !before)) /. float j in
          before := !current;
          current := next
        done;
        slope := float n *. ((!x *. !current) -. !before) /. ((!x *. !x) -. 1.);
        x := !x -. (!current /. !slope)
      done;
      (!x, 2. /. ((1. -. (!x *. !x)) *. !slope *. !slope)))

let nodes = gauss_legendre 8
let panels = 400

(* The integral of g over [a, b]; g is never asked for its value at a or b. *)
let over_interval g a b =
  let h = (b -. a) /. float panels in
  let total = ref 0. in
  for i = 0 to panels - 1 do
    let middle = a +. (h *. (float i +. 0.5)) in
    Array.iter (fun (x, w) -> total := !total +. (w *. g (middle +. (0.5 *. h *. x)))) nodes
  done;
  0.5 *. h *. !total

(* From a to infinity, with x = a + t / (1 - t). *)
let to_infinity f a = over_interval (fun t -> f (a +. (t /. (1. -. t))) /. ((1. -. t) *. (1. -. t))) 0. 1.

(* From a to b, with x = a + u^2, which takes away an unboundedness like
   1 / sqrt(x - a) at a. *)
let from_singular_end f a b = over_interval (fun u -> 2. *. u *. f (a +. (u *. u))) 0. (sqrt (b -. a))

let numeric integrand lower upper =
  let f = value_at integrand in
  match (lower, upper) with
  | Finite a, Plus_infinity -> to_infinity f (float a)
  | Minus_infinity, Finite b -> to_infinity (fun s -> f (float b -. s)) 0.
  | Minus_infinity, Plus_infinity -> to_infinity f 0. +. to_infinity (fun s -> f (-.s)) 0.
  | Finite a, Finite b when a < b -> from_singular_end f (float a) (float b)
  | _ -> failwith "the limits are not in order"

(* ---- (B) The value on fractions ------------------------------------------- *)

let exact integrand lower upper =
  match integrand with
  | Power { scale; shift; exponent } ->
      (* the power rule *)
      let raised = exponent +: whole 1 in
      if sign raised = 0 then failwith "the antiderivative is a logarithm: the integral diverges";
      let front = whole scale /: raised in
      let at = function
        | Plus_infinity ->
            if sign raised < 0 then zero else failwith "the antiderivative does not vanish at infinity: the integral diverges"
        | Minus_infinity -> failwith "a power of x + a is integrated from minus infinity"
        | Finite b -> (
            let base = b + shift in
            if base < 0 then failwith "the base of the power is negative at a limit"
            else if base = 0 then
              if sign raised > 0 then zero else failwith "the antiderivative is unbounded at a limit: the integral diverges"
            else
              match raised.bottom with
              | 1 -> front *: power (whole base) raised.top
              | 2 -> (
                  match square_root base with
                  | Some root -> front *: power (whole root) raised.top
                  | None -> failwith "a square root of a number that is not a perfect square")
              | _ -> failwith "a power that is neither whole nor a half")
      in
      (match (lower, upper) with
      | Finite a, Finite b when a >= b -> failwith "the limits are not in order"
      | Plus_infinity, _ | _, Minus_infinity -> failwith "the limits are not in order"
      | _ -> ());
      Rational (at upper -: at lower)
  | Exponential { scale; degree; rate; inner } -> (
      (* onto [0, infinity), turning the line round when it goes the other way *)
      let scale, rate =
        match (lower, upper) with
        | Finite 0, Plus_infinity -> (scale, rate)
        | Minus_infinity, Finite 0 -> ((if degree mod 2 = 0 then scale else -scale), if inner mod 2 = 0 then rate else -rate)
        | _ -> failwith "an exponential is integrated neither from 0 to infinity nor from minus infinity to 0"
      in
      if rate >= 0 then failwith "the exponential does not decay on the side integrated over: the integral diverges";
      let a = whole (-rate) in
      (* the integral of u^j e^(-a u) from 0 to infinity, by parts j times *)
      let rec moment j = if j = 0 then whole 1 /: a else whole j /: a *: moment (j - 1) in
      match inner with
      | 1 -> Rational (whole scale *: moment degree)
      | 2 ->
          if degree mod 2 = 0 then failwith "an even power of x times e^(-a x^2) does not come to a fraction";
          (* u = x^2, x dx = du / 2 *)
          Rational (whole scale /: whole 2 *: moment ((degree - 1) / 2))
      | _ -> failwith "the power of x in the exponent is neither 1 nor 2")
  | Quadratic { scale; constant } ->
      if constant <= 0 then failwith "x^2 + c is not positive on the whole line";
      let a =
        match square_root constant with Some a -> a | None -> failwith "the number added to x^2 is not a perfect square"
      in
      (* arctan(x / a) at a limit, in units of pi *)
      let arctangent = function
        | Plus_infinity -> fraction 1 2
        | Minus_infinity -> fraction (-1) 2
        | Finite 0 -> zero
        | Finite _ -> failwith "the arctangent at a limit that is neither 0 nor infinite"
      in
      let turned = arctangent upper -: arctangent lower in
      if sign turned <= 0 then failwith "the limits are not in order";
      Pi_multiple (fraction scale a *: turned)

(* An integral is improper when a limit is infinite or the integrand is
   unbounded at a limit. *)
let improper integrand lower upper =
  let unbounded_at = function
    | Finite b -> ( match integrand with Power { shift; _ } -> b + shift = 0 | _ -> false)
    | _ -> true
  in
  unbounded_at lower || unbounded_at upper

(* ---- The engine's answer -------------------------------------------------- *)

(* A formula made of numbers and pi with products, quotients and minus
   signs alone: the fraction in front and the power of pi. Anything else (a
   sum, a function, a root, a variable) is refused. *)
let rec pi_term = function
  | F.Constant c -> Some (fraction c.Rhema_number.numerator c.Rhema_number.denominator, 0)
  | F.Pi -> Some (whole 1, 1)
  | F.Negate a -> Option.map (fun (q, n) -> (zero -: q, n)) (pi_term a)
  | F.Multiply (a, b) -> (
      match (pi_term a, pi_term b) with Some (p, i), Some (q, j) -> Some (p *: q, i + j) | _ -> None)
  | F.Divide (a, b) -> (
      match (pi_term a, pi_term b) with Some (p, i), Some (q, 0) when sign q <> 0 -> Some (p /: q, i) | _ -> None)
  | _ -> None

(* A multiple of pi is written as one fraction in front of pi, as 3/5*pi,
   or as pi alone: not as 3*pi/5, and not as 3/10*pi*2. *)
let tidy = function
  | F.Pi -> true
  | F.Multiply (F.Constant c, F.Pi) ->
      Rhema_number.compare c Rhema_number.zero > 0 && not (Rhema_number.equal c (Rhema_number.of_int 1))
  | _ -> false

let pi_multiple f =
  match pi_term f with
  | Some (q, 1) ->
      (* the tree was read rightly: it comes to q pi as a number too *)
      let number = F.evaluate_with (fun _ -> None) f in
      if not (Float.abs (number -. (to_float q *. Float.pi)) <= 1e-9 *. Float.abs number) then
        failwith "the answer's formula does not come to the multiple of pi read from it";
      if not (tidy f) then failwith "the answer is a multiple of pi that is not written as one fraction times pi";
      q
  | Some (_, 0) -> failwith "the answer is a formula with no pi in it: a number is not given as a formula"
  | _ -> failwith "the answer is a formula that is not a fraction times pi, written with pi alone"

(* A fraction is a number; a multiple of pi is a formula. With the value
   comes whether the answer is a plain answer, one graded with the
   functions switched off, so that atan is not accepted in it. *)
let answer value =
  let inside = function
    | Rhema_engine.Num n -> Rational (fraction n.Rhema_number.numerator n.Rhema_number.denominator)
    | Rhema_engine.Formula f -> Pi_multiple (pi_multiple f)
    | other -> failwith ("the answer is not a number: " ^ Rhema_engine.describe_value other)
  in
  match value with Rhema_engine.Plain value -> (inside value, true) | value -> (inside value, false)

(* ---- What was generated --------------------------------------------------- *)

(* The numbers of each form, to compare at the end with the values expected:
   none outside them, and none of them missing. *)
let noted : (string * string, int list) Hashtbl.t = Hashtbl.create 64

let note k name n =
  let before = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
  if not (List.mem n before) then Hashtbl.replace noted (k, name) (n :: before)

(* Each kind has the integrand and the limits the header gives it. Its
   numbers are noted. *)
let of_its_kind k integrand lower upper =
  let not_so () = failwith "the integrand or the limits are not those of its kind" in
  match (k, integrand, lower, upper) with
  | "power_tail", Power { scale; shift = 0; exponent = { top; bottom = 1 } }, Finite a, Plus_infinity ->
      if -top < 2 then failwith "a power below 2 in a tail: the integral diverges";
      if a < 1 then failwith "the tail starts at or below the point where the integrand is unbounded";
      note k "coefficient" scale;
      note k "power" (-top);
      note k "lower limit" a
  | "shifted_power", Power { scale; shift; exponent = { top; bottom = 1 } }, Finite 0, Plus_infinity ->
      if -top < 2 then failwith "a power below 2 in a tail: the integral diverges";
      if shift < 1 then failwith "x + a is not positive from 0 on";
      note k "coefficient" scale;
      note k "shift" shift;
      note k "power" (-top)
  | "root_singularity", Power { scale; shift = 0; exponent = { top = -1; bottom = 2 } }, Finite 0, Finite b ->
      note k "coefficient" scale;
      note k "upper limit" b
  | "exponential_tail", Exponential { scale; degree = 0; rate; inner = 1 }, Finite 0, Plus_infinity ->
      if rate >= 0 then failwith "the exponential grows toward plus infinity";
      note k "coefficient" scale;
      note k "rate" (-rate);
      note k "side" 1
  | "exponential_tail", Exponential { scale; degree = 0; rate; inner = 1 }, Minus_infinity, Finite 0 ->
      if rate <= 0 then failwith "the exponential grows toward minus infinity";
      note k "coefficient" scale;
      note k "rate" rate;
      note k "side" (-1)
  | ("first_moment" | "second_moment" | "square_exponent"), Exponential { scale; degree; rate; inner }, Finite 0, Plus_infinity ->
      if rate >= 0 then failwith "the exponential grows toward plus infinity";
      let wanted = match k with "first_moment" -> (1, 1) | "second_moment" -> (2, 1) | _ -> (1, 2) in
      if (degree, inner) <> wanted then not_so ();
      note k "coefficient" scale;
      note k "rate" (-rate)
  | "arctangent", Quadratic { scale; constant }, (Finite 0 | Minus_infinity), Plus_infinity ->
      note k "coefficient" scale;
      note k "constant" constant;
      note k "lower limit is 0" (if lower = Finite 0 then 1 else 0)
  | _ -> not_so ()

let rec range a b = if a > b then [] else a :: range (a + 1) b

(* The values each form's numbers take, all of which must appear. *)
let allowed =
  let moment = [ ("coefficient", range 1 9); ("rate", range 1 5) ] in
  [ ("power_tail", [ ("coefficient", range 1 9); ("power", range 2 4); ("lower limit", range 1 3) ]);
    ("exponential_tail", moment @ [ ("side", [ -1; 1 ]) ]);
    ("shifted_power", [ ("coefficient", range 1 9); ("shift", range 1 4); ("power", range 2 3) ]);
    ("first_moment", moment);
    ("root_singularity", [ ("coefficient", range 1 9); ("upper limit", [ 1; 4; 9; 16 ]) ]);
    ("second_moment", moment);
    ("square_exponent", moment);
    ("arctangent", [ ("coefficient", range 1 9); ("constant", [ 1; 4; 9; 16; 25 ]); ("lower limit is 0", [ 0; 1 ]) ]) ]

let prices =
  [ ("power_tail", 1); ("exponential_tail", 1); ("shifted_power", 2); ("first_moment", 2); ("root_singularity", 2);
    ("second_moment", 3); ("square_exponent", 3); ("arctangent", 3) ]

let seen : (string, int) Hashtbl.t = Hashtbl.create 8
let times k = Option.value (Hashtbl.find_opt seen k) ~default:0

let close found wanted = Float.abs (found -. wanted) <= 1e-6 *. Float.abs wanted

let check cost seed (q : Rhema_engine.question) =
  let k = kind q and p = q.Rhema_engine.prompt in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
  Hashtbl.replace seen k (times k + 1);
  (match List.assoc_opt k prices with
  | Some price -> if price <> cost then fail (Printf.sprintf "%s at cost %d (seed %d)" k cost seed)
  | None -> fail (Printf.sprintf "a kind the header does not list: %s" k));
  if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
  if q.Rhema_engine.mistakes <> [] then wrong "a mistake is listed, and the grammar has none";
  match q.Rhema_engine.answers with
  | [ only ] -> (
      if only <> q.Rhema_engine.answer then wrong "the answer is not the one of the only blank";
      try
        let lower, upper, integrand, says_pi = read p in
        let got, plain = answer only in
        of_its_kind k integrand lower upper;
        if not (improper integrand lower upper) then wrong "the integral is not improper";
        (* (B) on fractions *)
        let worked = exact integrand lower upper in
        if got <> worked then wrong ("worked out exactly: " ^ show_result worked);
        (* (A) in floating point, against the engine's answer and against (B) *)
        let estimate = numeric integrand lower upper in
        if not (close estimate (float_of_result got)) then wrong (Printf.sprintf "integrated numerically: %.10g" estimate);
        if not (close estimate (float_of_result worked)) then
          wrong (Printf.sprintf "the two ways disagree: %.10g and %s" estimate (show_result worked));
        (* pi is asked for exactly when the answer is a multiple of pi *)
        (match (got, says_pi) with
        | Pi_multiple _, false -> wrong "the answer is a multiple of pi and the text does not say how to write pi"
        | Rational _, true -> wrong "the text says how to write pi and the answer has no pi in it"
        | _ -> ());
        (match (got, k) with
        | Pi_multiple _, "arctangent" -> ()
        | Rational _, "arctangent" -> wrong "the answer of an arctangent question is not a multiple of pi"
        | Pi_multiple _, _ -> wrong "a multiple of pi is the answer of a question that is not an arctangent"
        | Rational _, _ -> ());
        (* the arctangent answer alone is graded with the functions switched off *)
        match (plain, k) with
        | false, "arctangent" -> wrong "the answer of an arctangent question is not a plain answer: atan is accepted in it"
        | true, "arctangent" | false, _ -> ()
        | true, _ -> wrong "a plain answer in a question that is not an arctangent"
      with
      | Failure m -> wrong m
      | e -> wrong (Printexc.to_string e))
  | answers -> wrong (Printf.sprintf "%d answers and not one" (List.length answers))

(* The working of this file, tried on integrals written by hand, most of
   which no grammar that the engine accepts can be made to print: an answer
   that divides by zero, as the closed formula of a divergent integral does,
   makes the engine drop the question. Each text is read as a question's is;
   it must come to the value given by both ways, or be refused by the exact
   one when no value is given. *)
let check_own_working () =
  let third = fraction 1 3 in
  List.iter
    (fun (body, wanted) ->
      let text = "Evaluate the improper integral [`" ^ body ^ " \\, dx`]." in
      match read text with
      | exception Failure m -> fail (Printf.sprintf "own working: %s is not read: %s" body m)
      | lower, upper, integrand, _ -> (
          match (exact integrand lower upper, wanted) with
          | exception Failure _ -> if wanted <> None then fail (Printf.sprintf "own working: %s is refused" body)
          | found, None -> fail (Printf.sprintf "own working: %s is given the value %s" body (show_result found))
          | found, Some value ->
              if found <> value then
                fail (Printf.sprintf "own working: %s comes to %s, not %s" body (show_result found) (show_result value));
              let estimate = numeric integrand lower upper in
              if not (Float.abs (estimate -. float_of_result value) <= 1e-8 *. Float.abs (float_of_result value)) then
                fail (Printf.sprintf "own working: %s is %.12g numerically, not %s" body estimate (show_result value))))
    [ ({|\int_{1}^{\infty} \frac{1}{x^{2}}|}, Some (Rational (whole 1)));
      ({|\int_{2}^{\infty} \frac{3}{x^{4}}|}, Some (Rational (fraction 1 8)));
      ({|\int_{2}^{\infty} \frac{1}{(x - 1)^{2}}|}, Some (Rational (whole 1)));
      ({|\int_{0}^{\infty} \frac{4}{(x + 2)^{3}}|}, Some (Rational (fraction 1 2)));
      ({|\int_{0}^{4} \frac{3}{\sqrt{x}}|}, Some (Rational (whole 12)));
      ({|\int_{1}^{9} \frac{1}{\sqrt{x}}|}, Some (Rational (whole 4)));
      ({|\int_{0}^{\infty} e^{-x}|}, Some (Rational (whole 1)));
      ({|\int_{-\infty}^{0} 2e^{3x}|}, Some (Rational (fraction 2 3)));
      ({|\int_{-\infty}^{0} x e^{x}|}, Some (Rational (whole (-1))));
      ({|\int_{0}^{\infty} x^{3} e^{-2x}|}, Some (Rational (fraction 3 8)));
      ({|\int_{0}^{\infty} x^{3} e^{-x^{2}}|}, Some (Rational (fraction 1 2)));
      ({|\int_{-\infty}^{0} x e^{-x^{2}}|}, Some (Rational (fraction (-1) 2)));
      ({|\int_{-\infty}^{\infty} \frac{1}{x^{2} + 1}|}, Some (Pi_multiple (whole 1)));
      ({|\int_{0}^{\infty} \frac{2}{x^{2} + 9}|}, Some (Pi_multiple third));
      ({|\int_{-\infty}^{0} \frac{2}{x^{2} + 9}|}, Some (Pi_multiple third));
      (* a logarithm; a power that does not vanish at infinity *)
      ({|\int_{1}^{\infty} \frac{1}{x}|}, None);
      ({|\int_{0}^{\infty} \frac{1}{(x + 2)}|}, None);
      ({|\int_{1}^{\infty} \frac{1}{\sqrt{x}}|}, None);
      (* unbounded at a limit, or inside the interval *)
      ({|\int_{0}^{\infty} \frac{1}{x^{2}}|}, None);
      ({|\int_{0}^{1} \frac{1}{x^{2}}|}, None);
      ({|\int_{0}^{1} \frac{1}{x}|}, None);
      ({|\int_{0}^{\infty} \frac{1}{(x - 1)^{2}}|}, None);
      (* an exponential that grows on the side integrated over *)
      ({|\int_{0}^{\infty} e^{x}|}, None);
      ({|\int_{-\infty}^{0} e^{-x}|}, None);
      ({|\int_{0}^{\infty} x e^{2x}|}, None);
      ({|\int_{0}^{\infty} x e^{x^{2}}|}, None);
      ({|\int_{-\infty}^{0} x e^{x^{2}}|}, None);
      (* limits and integrands that give no fraction and no fraction of pi *)
      ({|\int_{-\infty}^{\infty} e^{-x}|}, None);
      ({|\int_{1}^{\infty} e^{-x}|}, None);
      ({|\int_{0}^{\infty} x^{2} e^{-x^{2}}|}, None);
      ({|\int_{0}^{2} \frac{1}{\sqrt{x}}|}, None);
      ({|\int_{0}^{\infty} \frac{1}{x^{2} + 2}|}, None);
      ({|\int_{0}^{\infty} \frac{1}{x^{2} - 4}|}, None);
      ({|\int_{1}^{\infty} \frac{1}{x^{2} + 1}|}, None);
      ({|\int_{3}^{1} \frac{1}{\sqrt{x}}|}, None) ];
  (* texts that are not read at all *)
  List.iter
    (fun body ->
      match read ("Evaluate the improper integral [`" ^ body ^ " \\, dx`].") with
      | exception Failure _ -> ()
      | _ -> fail (Printf.sprintf "own working: %s is read" body))
    [ {|\int_{0}^{\infty} 1e^{-x}|};
      {|\int_{0}^{\infty} e^{-1x}|};
      {|\int_{0}^{\infty} x^{1} e^{-x}|};
      {|\int_{1}^{\infty} \frac{1}{x^{1}}|};
      {|\int_{01}^{\infty} \frac{1}{x^{2}}|};
      {|\int_{1}^{\infty} \frac{1}{y^{2}}|};
      {|\int_{0}^{\infty} \frac{1}{x + 4}|};
      {|\int_{0}^{\infty} e^{-x} + 1|} ];
  (* the answer's formula, on trees built by hand *)
  let number top bottom = F.Constant (Rhema_number.divide (Rhema_number.of_int top) (Rhema_number.of_int bottom)) in
  List.iter
    (fun (name, tree, wanted) ->
      let found = match pi_multiple tree with q -> Some q | exception Failure _ -> None in
      if found <> wanted then
        fail (Printf.sprintf "own working: the formula %s is %s" name (if wanted = None then "accepted" else "refused or misread")))
    [ ("pi", F.Pi, Some (whole 1));
      ("3/5 pi", F.Multiply (number 3 5, F.Pi), Some (fraction 3 5));
      ("2 pi", F.Multiply (number 2 1, F.Pi), Some (whole 2));
      ("1 pi", F.Multiply (number 1 1, F.Pi), None);
      ("pi 3/5", F.Multiply (F.Pi, number 3 5), None);
      ("3 pi / 5", F.Divide (F.Multiply (number 3 1, F.Pi), number 5 1), None);
      ("3/10 pi 2", F.Multiply (F.Multiply (number 3 10, F.Pi), number 2 1), None);
      ("-(3/5 pi)", F.Negate (F.Multiply (number 3 5, F.Pi)), None);
      ("-3/5 pi", F.Multiply (number (-3) 5, F.Pi), None);
      ("3/5", number 3 5, None);
      ("3/5 pi pi", F.Multiply (F.Multiply (number 3 5, F.Pi), F.Pi), None);
      ("3/5 pi + sin(pi)", F.Add (F.Multiply (number 3 5, F.Pi), F.Sin F.Pi), None);
      ("3/5 sqrt(pi)", F.Multiply (number 3 5, F.Sqrt F.Pi), None);
      ("3/5 x", F.Multiply (number 3 5, F.Variable "x"), None) ]

let () =
  check_own_working ();
  let base = load_file "improper_integral.rhm" in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 1999 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> check cost seed q
    done
  done;
  (* left alone, the budget is the middle price *)
  for seed = 0 to 99 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q -> check 2 seed q
  done;
  (* no question outside the three prices *)
  List.iter
    (fun cost ->
      match Rhema_check.with_initial base "cost" cost with
      | Error _ -> ()
      | Ok spec ->
          for seed = 0 to 19 do
            Random.init seed;
            match Rhema_engine.generate spec with
            | exception Rhema_engine.Generation_error _ -> ()
            | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
          done)
    [ 0; 4; 5; 6 ];
  List.iter (fun (k, _) -> if times k = 0 then fail ("never generated: " ^ k)) prices;
  (* the numbers of each form: all of these and no others *)
  let list values = String.concat ", " (List.map string_of_int values) in
  List.iter
    (fun (k, names) ->
      List.iter
        (fun (name, values) ->
          let found = List.sort compare (Option.value (Hashtbl.find_opt noted (k, name)) ~default:[]) in
          if found <> List.sort compare values then
            fail (Printf.sprintf "%s: the %s takes the values [%s], not [%s]" k name (list found) (list values)))
        names)
    allowed;
  Hashtbl.iter
    (fun (k, name) _ ->
      match List.assoc_opt k allowed with
      | Some names when List.mem_assoc name names -> ()
      | _ -> fail (Printf.sprintf "%s: the %s was noted and is not looked at" k name))
    noted;
  if !failures = 0 then print_endline "Rhema improper integral tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d improper integral test(s) failed." !failures);
    exit 1
  end
