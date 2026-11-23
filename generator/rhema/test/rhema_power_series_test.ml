(* Independent checks for power_series.rhm. Nothing here uses the grammar's
   closed formulas or its table of which end belongs to an interval. The
   series is read back from the printed question, whose whole text must be
   worded as these questions are (a text that cannot be read is a failure),
   and it is held as a product of factors above and below the line, each one
   of

     (-1)^n      n, n^2, sqrt(n)      k^n      (p x + q)^n, (p x + q)^(2n)
     (2n)!       (n!)^2

   From this product the logarithm of the size of the n-th term and its sign
   are computed at any x, for n in the thousands without overflow (the
   factorials come from a table of sums of logarithms). Every answer is then
   found again by the test that defines it, numerically, and the number found
   is recognised as the one fraction with a small denominator that lies
   within 1e-8 of it; that fraction must be the engine's answer exactly.

   The radius (geometric_radius, scaled_radius, even_powers,
   central_binomial, and the two ends of every interval). The centre is the
   x at which the bracket vanishes. The root test is carried out as it
   stands: the limit of log|term| / n is taken at a point x, with a second
   difference over n, 2n and 4n that removes a constant factor and any power
   of n from the term exactly, and the radius is the distance from the
   centre at which this limit is 0, found by bisection. It is then checked
   on both sides of the centre that the limit is negative a little inside
   that distance and positive a little outside it.

   An interval (geometric_interval, half_open_interval, interval_ends) is
   the centre minus and plus the radius, and each end is decided from the
   terms AT that end. Their sizes at n, 2n and 4n must be those of a power
   n^(-p), and p must be a whole number of halves. If p <= 0 the terms do
   not tend to 0 and the series diverges there. Otherwise, if the terms
   alternate in sign and decrease, it converges (Leibniz); if they keep one
   sign, it converges exactly when p > 1 (the p-series test). Any other
   behaviour is refused. An end belongs to the answer exactly when the
   series converges there.

   The sum (differentiated_sum) is added up term by term. The terms are a
   power of n times a geometric sequence, so the ratio of successive terms
   decreases with n: once that ratio is t < 1 at n, what is left of the sum
   is below term(n) t / (1 - t), and the adding stops when this bound is
   below 1e-14 of the sum.

   The mistakes are recomputed from what their descriptions say the student
   does, again numerically:

     reciprocal_taken      the limit of the ratio test itself: the limit of
                           |term(n+1) / term(n)| at distance 1 from the
                           centre, the ratio taken factor by factor (so
                           (2n+2)! / (2n)! is (2n+1)(2n+2)) and extrapolated
     inner_factor_ignored  the radius, found as above, of the series in which
                           (p x + q)^n is replaced by (x + q)^n
     root_not_taken        the radius, found as above, of the series in which
                           (x - c)^(2n) is replaced by (x - c)^n
     ends_not_tested       the open interval with the two ends of the answer

   Each question must list exactly the mistakes of its form, in the order
   they are declared, with these values, and each must differ from the right
   answer. One case is left out, as the engine leaves it out: in
   interval_ends the open interval is not listed as a mistake when it is the
   right answer (the series with n above the line).

   The working of this file is itself tried first, on series written by
   hand: with their radius, interval or sum, and ones that must be refused.

   Besides the answers: the whole text of each form is matched against the
   way that form is written, and a base 1 or a factor 1 is never written;
   each number of each form takes exactly the values the grammar offers,
   none missing and none more (the pairs that must share no factor are
   looked at as pairs); the number under an even power is a perfect square;
   all four ways for two ends to belong or not come up in interval_ends, and
   no question of it is the question of price 2; every kind appears at its
   price alone and spends its budget; a budget outside 1..3 gives no
   question; the budget the grammar sets itself is the middle price; the
   answer of a radius or a sum is a number in the context Numeric, that of
   an interval is an interval in the context Interval. *)

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
   so that two equal fractions are equal as records. *)
type fraction = { top : int; bottom : int }

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let fraction top bottom =
  if bottom = 0 then failwith "division by zero";
  let top, bottom = if bottom < 0 then (-top, -bottom) else (top, bottom) in
  let divisor = gcd top bottom in
  { top = top / divisor; bottom = bottom / divisor }

let whole n = { top = n; bottom = 1 }
let ( +: ) a b = fraction ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( -: ) a b = fraction ((a.top * b.bottom) - (b.top * a.bottom)) (a.bottom * b.bottom)
let to_float a = float a.top /. float a.bottom
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

(* The one fraction with a denominator up to 500 that lies within 1e-8
   (relative) of a number found numerically. Two such fractions are at least
   4e-6 apart, so there is never a choice. *)
let recognise x =
  if Float.is_nan x || Float.abs x > 1e6 then failwith "a number that is no small fraction was found";
  let within = 1e-8 *. Float.max 1. (Float.abs x) in
  let rec search bottom =
    if bottom > 500 then failwith (Printf.sprintf "%.12g is not recognised as a fraction" x)
    else
      let top = Float.round (x *. float bottom) in
      if Float.abs (x -. (top /. float bottom)) <= within then fraction (int_of_float top) bottom else search (bottom + 1)
  in
  search 1

(* An answer: a number, or an interval with its two ends and whether each
   belongs to it. *)
type result = Number of fraction | Range of fraction * fraction * bool * bool

let show_result = function
  | Number a -> show a
  | Range (a, b, lower, upper) ->
      Printf.sprintf "%s%s, %s%s" (if lower then "[" else "(") (show a) (show b) (if upper then "]" else ")")

(* ---- The series as it is printed ------------------------------------------ *)

type bracket = { slope : int; constant : int; times : int }  (* (slope x + constant)^(times n) *)

type factor =
  | Alternating  (* (-1)^n *)
  | Power_of_n of float  (* n, n^2, sqrt(n) *)
  | Geometric of int  (* k^n *)
  | Bracket of bracket
  | Factorial of { inner : int; power : int }  (* ((inner n)!)^power *)

(* The general term: its factors, each with 1 when it stands above the line
   and -1 when it stands below. *)
type term = (factor * int) list

type asked = Radius | Interval | Sum

(* ---- Reading the text ------------------------------------------------------ *)

(* The whole of `text` must be the pattern. Its groups are given back, all
   taken at once, before any other pattern is tried: a group that took no
   part in the match is None. *)
let fields re count text =
  if Str.string_match (Str.regexp re) text 0 && Str.match_end () = String.length text then
    Some (Array.init count (fun i -> match Str.matched_group (i + 1) text with s -> Some s | exception Not_found -> None))
  else None

let group groups n = groups.(n - 1)
let field groups n = match group groups n with Some s -> s | None -> failwith "a part of the text is missing"

(* A whole number written without a sign and without a 0 in front. *)
let number text =
  match fields "0\\|[1-9][0-9]*" 0 text with
  | Some _ -> int_of_string text
  | None -> failwith ("cannot read the number \"" ^ text ^ "\"")

(* A number that is written only when it is not 1: the base of k^n, the
   number in front of x. *)
let base text =
  let n = number text in
  if n < 2 then failwith ("a base or a factor " ^ text ^ " is written out");
  n

(* A number added to x or taken from it, which is never 0. *)
let signed sign text =
  let n = number text in
  if n = 0 then failwith "0 is added to x";
  if sign = "-" then -n else n

let lit = Str.quote
let digits = {|\([0-9]+\)|}

(* The three sentences. Each has the first value of n and the general term
   where the two groups stand. *)
let sentences =
  let around before after = lit before ^ {|\([01]\)|} ^ lit {|}^{\infty} |} ^ {|\([^`]*\)|} ^ lit after in
  [ (Radius, around {|Find the radius of convergence of the power series [`\sum_{n=|} "`].");
    ( Interval,
      around {|Find the interval of convergence of the power series [`\sum_{n=|}
        "`]. Enter it as an interval: a round bracket for an end that is left out, a square bracket for an end that belongs \
         to it." );
    (Sum, around {|Find the sum of the series [`\sum_{n=|} "`]. (Differentiate the geometric series.)") ]

(* What is asked, the first n, and the general term as it is written. *)
let read text =
  let rec first = function
    | (asked, re) :: rest -> (
        match fields re 2 text with Some g -> (asked, int_of_string (field g 1), field g 2) | None -> first rest)
    | [] -> failwith "the text is not worded as a question on a series is"
  in
  first sentences

(* The parts of a product: cut at each space that is not inside brackets. *)
let parts text =
  let found = ref [] and start = ref 0 and depth = ref 0 in
  String.iteri
    (fun i c ->
      match c with
      | '(' | '{' -> incr depth
      | ')' | '}' -> decr depth
      | ' ' when !depth = 0 ->
          found := String.sub text !start (i - !start) :: !found;
          start := i + 1
      | _ -> ())
    text;
  List.rev (String.sub text !start (String.length text - !start) :: !found)

let factor text =
  let shapes =
    [ ({|(-1)\^{n}|}, 0, fun _ -> Alternating);
      ("n", 0, fun _ -> Power_of_n 1.);
      ({|n\^{2}|}, 0, fun _ -> Power_of_n 2.);
      ({|\\sqrt{n}|}, 0, fun _ -> Power_of_n 0.5);
      (digits ^ {|\^{n}|}, 1, fun g -> Geometric (base (field g 1)));
      ({|x\^{\(2?\)n}|}, 1, fun g -> Bracket { slope = 1; constant = 0; times = (if field g 1 = "" then 1 else 2) });
      ( {|(\([0-9]*\)x \([-+]\) \([0-9]+\))\^{\(2?\)n}|},
        4,
        fun g ->
          Bracket
            { slope = (if field g 1 = "" then 1 else base (field g 1));
              constant = signed (field g 2) (field g 3);
              times = (if field g 4 = "" then 1 else 2) } );
      ({|(2n)!|}, 0, fun _ -> Factorial { inner = 2; power = 1 });
      ({|(n!)\^{2}|}, 0, fun _ -> Factorial { inner = 1; power = 2 }) ]
  in
  let rec first = function
    | (re, count, build) :: rest -> ( match fields re count text with Some g -> build g | None -> first rest)
    | [] -> failwith ("cannot read the factor \"" ^ text ^ "\"")
  in
  first shapes

(* A product of factors, with a thin space \, or a space between two. *)
let product side text =
  let rec go = function
    | [] -> failwith "an empty product"
    | [ last ] -> [ (factor last, side) ]
    | one :: {|\,|} :: rest | one :: rest -> (factor one, side) :: go rest
  in
  go (parts text)

(* What stands inside the braces that open at `start`, and where it ends. *)
let braced text start =
  if start >= String.length text || text.[start] <> '{' then failwith "a brace was expected";
  let rec close i depth =
    if i >= String.length text then failwith "a brace is not closed"
    else
      match text.[i] with
      | '{' -> close (i + 1) (depth + 1)
      | '}' -> if depth = 1 then i else close (i + 1) (depth - 1)
      | _ -> close (i + 1) depth
  in
  let stop = close start 0 in
  (String.sub text (start + 1) (stop - start - 1), stop + 1)

(* The general term: a product, or \frac{product}{product}, the fraction
   with or without a product after it. *)
let parse text : term =
  let starts prefix = String.length text >= String.length prefix && String.sub text 0 (String.length prefix) = prefix in
  if starts {|\frac{|} then begin
    let above, next = braced text 5 in
    let below, next = braced text next in
    let after = String.sub text next (String.length text - next) in
    let length = String.length after in
    product 1 above @ product (-1) below
    @
    if after = "" then []
    else if length > 4 && String.sub after 0 4 = {| \, |} then product 1 (String.sub after 4 (length - 4))
    else failwith ("cannot read what follows the fraction: \"" ^ after ^ "\"")
  end
  else product 1 text

(* ---- The terms in numbers --------------------------------------------------- *)

(* The root test looks at the terms at n, 2n and 4n for this n. *)
let far = 16384

(* log(n!) for n up to 8 * far, by adding logarithms (with Kahan's
   correction, so that the last entries are still good to 15 figures). *)
let log_factorial =
  let table = Array.make ((8 * far) + 1) 0. in
  let carry = ref 0. in
  for i = 1 to 8 * far do
    let step = log (float i) -. !carry in
    let next = table.(i - 1) +. step in
    carry := next -. table.(i - 1) -. step;
    table.(i) <- next
  done;
  fun n -> if n < 0 || n >= Array.length table then failwith "a factorial beyond the table" else table.(n)

let inside b x = (float b.slope *. x) +. float b.constant

(* log |term(n)| at x. What grows like a power k^n is added up apart from
   the rest, so that at an end of the interval, where these powers cancel,
   nothing of them is left by rounding. *)
let log_size (term : term) n x =
  let rate = ref 0. and rest = ref 0. in
  List.iter
    (fun (factor, side) ->
      let side = float side in
      match factor with
      | Alternating -> ()
      | Power_of_n a -> rest := !rest +. (side *. a *. log (float n))
      | Geometric k -> rate := !rate +. (side *. log (float k))
      | Bracket b -> rate := !rate +. (side *. float b.times *. log (Float.abs (inside b x)))
      | Factorial { inner; power } -> rest := !rest +. (side *. float power *. log_factorial (inner * n)))
    term;
  (float n *. !rate) +. !rest

(* The sign of term(n) at x: 1 or -1. *)
let sign_of (term : term) n x =
  List.fold_left
    (fun sign (factor, _) ->
      match factor with
      | Alternating -> if n mod 2 = 0 then sign else -sign
      | Bracket b ->
          let value = inside b x in
          if value = 0. then failwith "the term is 0 at the centre"
          else if value < 0. && b.times * n mod 2 <> 0 then -sign
          else sign
      | Power_of_n _ | Geometric _ | Factorial _ -> sign)
    1 term

(* log |term(n+1) / term(n)| at x, the ratio taken factor by factor as the
   ratio test takes it: (m n + m)! / (m n)! is (m n + 1) ... (m n + m). *)
let log_ratio (term : term) n x =
  List.fold_left
    (fun total (factor, side) ->
      let side = float side in
      match factor with
      | Alternating -> total
      | Power_of_n a -> total +. (side *. a *. log1p (1. /. float n))
      | Geometric k -> total +. (side *. log (float k))
      | Bracket b -> total +. (side *. float b.times *. log (Float.abs (inside b x)))
      | Factorial { inner; power } ->
          let run = ref 0. in
          for j = 1 to inner do
            run := !run +. log (float ((inner * n) + j))
          done;
          total +. (side *. float power *. !run))
    0. term

(* The power of x in a power series, which must stand above the line and be
   the only one. *)
let bracket_of (term : term) =
  match List.filter_map (function Bracket b, side -> Some (b, side) | _ -> None) term with
  | [ (b, 1) ] -> b
  | [] -> failwith "there is no power of x in the series"
  | _ -> failwith "the power of x stands below the line, or there are two of them"

(* The centre: where the bracket vanishes. *)
let centre term =
  let b = bracket_of term in
  fraction (-b.constant) b.slope

(* The limit of log |term(n)| / n at x, the logarithm of what the root test
   looks at. With g(n) = log |term(n)| = A n + a log n + B, the second
   difference g(4n) - 2 g(2n) + g(n) is A n exactly; what the factorials add
   to it is of the order of 1 / n. *)
let root_limit term x =
  let g n = log_size term n x in
  (g (4 * far) -. (2. *. g (2 * far)) +. g far) /. float far

(* The radius: the distance from the centre at which the root test gives 1.
   It is looked for between 1/1000 and 1000 by bisection, and the series
   must pass the test a little inside it and fail it a little outside it,
   on both sides of the centre. *)
let radius term =
  let c = to_float (centre term) in
  let at distance = root_limit term (c +. distance) in
  if not (at 1e-3 < 0. && at 1e3 > 0.) then failwith "no radius between 1/1000 and 1000";
  let lower = ref 1e-3 and upper = ref 1e3 in
  for _ = 1 to 100 do
    let middle = sqrt (!lower *. !upper) in
    if at middle < 0. then lower := middle else upper := middle
  done;
  let found = sqrt (!lower *. !upper) in
  List.iter
    (fun side ->
      if not (root_limit term (c +. (side *. found *. (1. -. 1e-6))) < 0.) then
        failwith "the root test is not passed just inside the radius";
      if not (root_limit term (c +. (side *. found *. (1. +. 1e-6))) > 0.) then
        failwith "the root test is not failed just outside the radius")
    [ 1.; -1. ];
  recognise found

(* The limit of the ratio test at distance 1 from the centre: the limit of
   |term(n+1) / term(n)| there. The ratio at n is off by something like
   1 / n, which the ratio at 2n halves; the two together leave 1 / n^2. *)
let ratio_limit term =
  let x = to_float (centre term) +. 1. in
  let n = 1 lsl 20 in
  recognise (exp ((2. *. log_ratio term (2 * n) x) -. log_ratio term n x))

(* Whether the series converges at x, an end of its interval of
   convergence, from the behaviour of its terms there. *)
let converges_at term start x =
  let g n = log_size term n x in
  let near = 4096 in
  (* |term| is like n^(-p): the same p from n to 2n and from 2n to 4n *)
  let p = (g near -. g (2 * near)) /. log 2. and again = (g (2 * near) -. g (4 * near)) /. log 2. in
  if not (Float.abs (p -. again) <= 1e-9) then
    failwith "the terms are not like a power of n there: it is not an end of the interval, or this file cannot decide";
  let halves = Float.round (2. *. p) in
  if not (Float.abs ((2. *. p) -. halves) <= 1e-9) then failwith "the terms are like a power of n that is not known";
  if halves <= 0. then (* the terms do not tend to 0 *) false
  else begin
    let first = max start 1 in
    let looked_at = List.init 60 (fun i -> first + i) @ [ near; 2 * near; 4 * near ] in
    let changes = List.map (fun n -> sign_of term n x * sign_of term (n + 1) x) looked_at in
    if List.for_all (fun change -> change = 1) changes then (* one sign: the p-series test *) halves > 2.
    else if List.for_all (fun change -> change = -1) changes then begin
      (* alternating: Leibniz, when the sizes decrease (to 0, since p > 0) *)
      if not (List.for_all (fun n -> g (n + 1) < g n) looked_at) then failwith "the alternating terms do not decrease";
      true
    end
    else failwith "the terms neither keep their sign nor alternate"
  end

(* The sum of a series of numbers whose terms are powers of n (above the
   line) times powers k^n: positive terms whose successive ratio decreases
   as n grows. Once the ratio is t < 1 at n, every later ratio is below t
   and the rest of the sum is below term(n) t / (1 - t). *)
let sum (term : term) start =
  List.iter
    (function
      | Geometric _, _ | Power_of_n _, 1 -> ()
      | _ -> failwith "no bound is known here for what is left of the sum of this series")
    term;
  let total = ref 0. and n = ref start and finished = ref false in
  while not !finished do
    if !n > 100000 then failwith "the series does not converge";
    let size = if !n = 0 && List.exists (function Power_of_n _, _ -> true | _ -> false) term then 0. else exp (log_size term !n 0.) in
    total := !total +. size;
    (if !n > 0 then
       let t = exp (log_ratio term !n 0.) in
       if t < 1. && size *. t /. (1. -. t) <= 1e-14 *. !total then finished := true);
    incr n
  done;
  recognise !total

(* The answer of a question, from what is asked, the first n and the term. *)
let solve asked start (term : term) =
  if start = 0 && List.exists (function Power_of_n _, -1 -> true | _ -> false) term then
    failwith "the first term is not defined: n is below the line and the sum starts at 0";
  match asked with
  | Radius -> Number (radius term)
  | Interval ->
      let c = centre term and r = radius term in
      let lower = c -: r and upper = c +: r in
      Range (lower, upper, converges_at term start (to_float lower), converges_at term start (to_float upper))
  | Sum ->
      if List.exists (function Bracket _, _ -> true | _ -> false) term then failwith "a power of x in a series of numbers";
      Number (sum term start)

(* What a mistake leads to, from its description. *)
let slip name (term : term) answer =
  let with_bracket change = List.map (function Bracket b, side -> (Bracket (change b), side) | other -> other) term in
  match name with
  | "reciprocal_taken" -> Number (ratio_limit term)
  | "inner_factor_ignored" ->
      if (bracket_of term).slope = 1 then failwith "there is no number in front of x to ignore";
      Number (radius (with_bracket (fun b -> { b with slope = 1 })))
  | "root_not_taken" ->
      if (bracket_of term).times <> 2 then failwith "the series does not have even powers alone";
      Number (radius (with_bracket (fun b -> { b with times = 1 })))
  | "ends_not_tested" -> (
      match answer with
      | Range (lower, upper, _, _) -> Range (lower, upper, false, false)
      | Number _ -> failwith "the ends of an answer that is not an interval")
  | other -> failwith ("nothing is known of the mistake " ^ other)

(* ---- The forms -------------------------------------------------------------- *)

(* Each form: its price, what it asks, its first n, and its mistakes in the
   order they are declared. *)
let forms =
  [ ("geometric_radius", (1, Radius, 0, [ "reciprocal_taken" ]));
    ("geometric_interval", (1, Interval, 0, []));
    ("scaled_radius", (2, Radius, 1, [ "reciprocal_taken"; "inner_factor_ignored" ]));
    ("even_powers", (2, Radius, 0, [ "root_not_taken" ]));
    ("half_open_interval", (2, Interval, 1, [ "ends_not_tested" ]));
    ("interval_ends", (3, Interval, 1, [ "ends_not_tested" ]));
    ("central_binomial", (3, Radius, 0, [ "reciprocal_taken" ]));
    ("differentiated_sum", (3, Sum, 1, [])) ]

(* What the description of each mistake must speak of. *)
let spoken =
  [ ("reciprocal_taken", [ "limit found by the ratio test"; "reciprocal of the radius" ]);
    ("inner_factor_ignored", [ "ignores the number in front of x"; "inside the bracket" ]);
    ("root_not_taken", [ "leaves the radius squared"; "only even powers" ]);
    ("ends_not_tested", [ "open interval"; "does not test its two ends" ]) ]

(* The numbers of each form, to compare at the end with what the grammar
   offers: none outside it, and nothing of it missing. *)
let noted : (string * string, int list list) Hashtbl.t = Hashtbl.create 64

let note k name numbers =
  let before = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
  if not (List.mem numbers before) then Hashtbl.replace noted (k, name) (numbers :: before)

(* x - c as it is written: x alone, (x - 3), (x + 3). *)
let shifted = {|\(x\|(x [-+] [0-9]+)\)|}

let centre_of text =
  if text = "x" then 0
  else
    match fields {|(x \([-+]\) \([0-9]+\))|} 2 text with
    | Some g -> -signed (field g 1) (field g 2)
    | None -> failwith ("cannot read the centre in \"" ^ text ^ "\"")

(* The square root of a whole number that is a perfect square. *)
let square_root n =
  let rec up r = if r * r >= n then r else up (r + 1) in
  let r = up 0 in
  if r * r = n then r else failwith (Printf.sprintf "%d is not a perfect square" n)

(* The general term of each form is written in the way of that form and in
   no other. Its numbers are noted. *)
let layout k body =
  let written alternatives =
    let rec first = function
      | (re, count, use) :: rest -> ( match fields re count body with Some g -> use g | None -> first rest)
      | [] -> failwith ("the series is not written as that of " ^ k ^ " is")
    in
    first alternatives
  in
  let fraction_of above below = lit {|\frac{|} ^ above ^ lit "}{" ^ below ^ lit "}" in
  let power = digits ^ lit "^{n}" in
  (* k^n after a thin space, left out when k is 1 *)
  let beside = {|\( \\, |} ^ power ^ {|\)?|} in
  let optional text = match text with Some text -> base text | None -> 1 in
  match k with
  | "geometric_radius" ->
      let above = {|\(|} ^ power ^ {| \)?|} ^ shifted ^ lit "^{n}" in
      let use below g =
        note k "pair of numbers" [ optional (group g 2); below g ];
        note k "centre" [ centre_of (field g 3) ]
      in
      written [ (above, 3, use (fun _ -> 1)); (fraction_of above power, 4, use (fun g -> base (field g 4))) ]
  | "geometric_interval" | "half_open_interval" ->
      let front = if k = "geometric_interval" then "" else lit {|n \, |} in
      written
        [ ( fraction_of (shifted ^ lit "^{n}") (front ^ power),
            2,
            fun g ->
              note k "centre" [ centre_of (field g 1) ];
              note k "base" [ base (field g 2) ] ) ]
  | "scaled_radius" ->
      let above = {|\(n \\, \|n\^{2} \\, \)?(\([0-9]+\)x \([-+]\) \([0-9]+\))\^{n}|} in
      let below = {|\(n\|\(n \\, \)?|} ^ power ^ {|\)|} in
      let use in_fraction g =
        let in_front = match group g 1 with None -> 0 | Some {|n \, |} -> 1 | Some _ -> 2 in
        let n_below, divisor =
          if not in_fraction then (false, 1)
          else if field g 5 = "n" then (true, 1)
          else (group g 6 <> None, base (field g 7))
        in
        let power_of_n =
          match (in_front, n_below) with
          | above, false -> above
          | 0, true -> 3
          | _ -> failwith "n stands both above and below the line"
        in
        note k "factor and base" [ base (field g 2); divisor ];
        note k "constant" [ signed (field g 3) (field g 4) ];
        note k "power of n" [ power_of_n ]
      in
      written [ (above, 4, use false); (fraction_of above below, 7, use true) ]
  | "even_powers" ->
      written
        [ ( fraction_of (shifted ^ lit "^{2n}") power,
            2,
            fun g ->
              note k "centre" [ centre_of (field g 1) ];
              note k "root of the base" [ square_root (base (field g 2)) ] ) ]
  | "interval_ends" ->
      written
        [ ( fraction_of ({|\((-1)\^{n} \\, \)?\(n \\, \)?|} ^ shifted ^ lit "^{n}") ({|\(n \\, \|n\^{2} \\, \|\\sqrt{n} \\, \)?|} ^ power),
            5,
            fun g ->
              let below = match group g 4 with None -> 0 | Some {|n \, |} -> 1 | Some {|n^{2} \, |} -> 2 | Some _ -> 3 in
              note k "centre" [ centre_of (field g 3) ];
              note k "base" [ base (field g 5) ];
              (* n above the line or not, what stands below, (-1)^n or not *)
              note k "factors beside the base" [ (if group g 2 = None then 0 else 1); below; (if group g 1 = None then 0 else 1) ] ) ]
  | "central_binomial" ->
      let use turned g = note k "number and side" [ optional (group g 2); turned ] in
      written
        [ (lit {|\frac{(2n)!}{(n!)^{2}|} ^ beside ^ lit {|} \, x^{n}|}, 2, use 0);
          (lit {|\frac{(n!)^{2}|} ^ beside ^ lit {|}{(2n)!} \, x^{n}|}, 2, use 1) ]
  | "differentiated_sum" ->
      written
        [ (fraction_of ("n" ^ beside) power, 3, fun g -> note k "pair of numbers" [ optional (group g 2); base (field g 3) ]) ]
  | k -> failwith ("unknown kind " ^ k)

let rec range a b = if a > b then [] else a :: range (a + 1) b
let singles values = List.map (fun n -> [ n ]) values
let pairs firsts seconds keep = List.concat_map (fun a -> List.filter_map (fun b -> if keep a b then Some [ a; b ] else None) seconds) firsts

(* What the grammar offers for each form, all of which must come up. *)
let offered =
  let centres = ("centre", singles (range (-5) 5)) in
  let apart a b = gcd a b = 1 in
  [ ("geometric_radius", [ ("pair of numbers", pairs (range 1 7) (range 1 7) (fun a b -> a <> b && apart a b)); centres ]);
    ("geometric_interval", [ centres; ("base", singles (range 2 6)); ("pair of ends that belong", [ [ 0; 0 ] ]) ]);
    ( "scaled_radius",
      [ ("factor and base", pairs (range 2 5) (range 1 7) apart);
        ("constant", singles (range (-9) (-1) @ range 1 9));
        ("power of n", singles (range 0 3)) ] );
    ("even_powers", [ centres; ("root of the base", singles (range 2 6)) ]);
    ("half_open_interval", [ centres; ("base", singles (range 2 5)); ("pair of ends that belong", [ [ 1; 0 ] ]) ]);
    ( "interval_ends",
      [ centres;
        ("base", singles (range 2 5));
        ("factors beside the base", [ [ 0; 1; 1 ]; [ 0; 2; 0 ]; [ 0; 2; 1 ]; [ 1; 0; 0 ]; [ 1; 0; 1 ]; [ 0; 3; 0 ]; [ 0; 3; 1 ] ]);
        ("pair of ends that belong", [ [ 0; 0 ]; [ 0; 1 ]; [ 1; 0 ]; [ 1; 1 ] ]) ] );
    ("central_binomial", [ ("number and side", pairs [ 1; 2; 3; 5; 6; 7 ] [ 0; 1 ] (fun _ _ -> true)) ]);
    ("differentiated_sum", [ ("pair of numbers", pairs (range 1 5) (range 2 6) (fun a b -> a < b && apart a b)) ]) ]

(* The answer of a question and what each mistake of its form leads to,
   from its kind and its text alone. *)
let work k text =
  let asked, start, body = read text in
  let _, wanted, first, slips =
    match List.assoc_opt k forms with Some form -> form | None -> failwith ("a kind the header does not list: " ^ k)
  in
  if asked <> wanted then failwith "the sentence is not the one of its kind";
  if start <> first then failwith (Printf.sprintf "the sum starts at n = %d" start);
  layout k body;
  let term = parse body in
  let answer = solve asked start term in
  (match answer with
  | Range (_, _, lower, upper) -> note k "pair of ends that belong" [ Bool.to_int lower; Bool.to_int upper ]
  | Number _ -> ());
  (answer, List.map (fun name -> (name, slip name term answer)) slips)

(* Each text is worked once: the questions of a form are few. With the
   outcome is kept the kind that asked it first. *)
let worked : (string, string * (result * (string * result) list, string) Stdlib.result) Hashtbl.t = Hashtbl.create 4096

let work_once k text =
  match Hashtbl.find_opt worked text with
  | Some (first, outcome) ->
      if first <> k then fail (Printf.sprintf "%s and %s ask the same question: %S" first k text);
      outcome
  | None ->
      let outcome =
        match work k text with
        | found -> Ok found
        | exception Failure m -> Error m
        | exception e -> Error (Printexc.to_string e)
      in
      Hashtbl.add worked text (k, outcome);
      outcome

(* ---- The engine's answer ---------------------------------------------------- *)

let of_number (n : Rhema_number.t) = fraction n.Rhema_number.numerator n.Rhema_number.denominator

(* A number, or one interval with two finite ends: nothing else, and no
   answer wrapped as plain or exact. *)
let read_value = function
  | Rhema_engine.Num n -> Number (of_number n)
  | Rhema_engine.Set (Rhema_set.Interval (lower, upper, left, right)) ->
      Range (of_number lower, of_number upper, left = Rhema_set.Closed, right = Rhema_set.Closed)
  | other -> failwith ("the answer is neither a number nor an interval: " ^ Rhema_engine.describe_value other)

let seen : (string, int) Hashtbl.t = Hashtbl.create 8
let times k = Option.value (Hashtbl.find_opt seen k) ~default:0
let made : (string * string, unit) Hashtbl.t = Hashtbl.create 8

let check cost seed (q : Rhema_engine.question) =
  let k = kind q and p = q.Rhema_engine.prompt in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
  Hashtbl.replace seen k (times k + 1);
  (match List.assoc_opt k forms with
  | Some (price, _, _, _) -> if price <> cost then fail (Printf.sprintf "%s at cost %d (seed %d)" k cost seed)
  | None -> fail (Printf.sprintf "a kind the header does not list: %s" k));
  if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
  match q.Rhema_engine.answers with
  | [ only ] -> (
      if only <> q.Rhema_engine.answer then wrong "the answer is not the one of the only blank";
      if Rhema_engine.attribute q.Rhema_engine.tree "answer_value" <> only then wrong "the blank does not hold answer_value";
      match (read_value only, work_once k p) with
      | exception Failure m -> wrong m
      | _, Error m -> wrong m
      | got, Ok (want, slips) ->
          if got <> want then wrong ("found again: " ^ show_result want);
          (* an interval is entered in the context Interval *)
          let context = match want with Range _ -> "Interval" | Number _ -> "Numeric" in
          (match Rhema_engine.attribute q.Rhema_engine.tree "pg_context" with
          | Rhema_engine.Text c when c = context -> ()
          | Rhema_engine.Text c -> wrong (Printf.sprintf "pg_context is %s, not %s" c context)
          | _ -> wrong "pg_context is not a text");
          if q.Rhema_engine.context <> context then
            wrong (Printf.sprintf "the question is in context %s, not %s" q.Rhema_engine.context context);
          (* a mistake that comes to the right answer is not listed. Only the
             open interval of interval_ends may do so; anywhere else such a
             question is not to be asked, wrong working would be marked right *)
          let due = List.filter (fun (_, value) -> value <> want) slips in
          if k <> "interval_ends" then
            List.iter
              (fun (name, value) -> if value = want then wrong (Printf.sprintf "%s gives the right answer %s" name (show_result want)))
              slips;
          let listed = q.Rhema_engine.mistakes in
          let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
          if names <> List.map fst due then
            wrong
              (Printf.sprintf "the mistakes listed are [%s], not [%s]" (String.concat ", " names)
                 (String.concat ", " (List.map fst due)));
          List.iter
            (fun (m : Rhema_engine.mistaken) ->
              Hashtbl.replace made (m.mistake, k) ();
              (* each mistake is described as itself *)
              let speaks_of part =
                match Str.search_forward (Str.regexp_string part) m.description 0 with
                | _ -> true
                | exception Not_found -> false
              in
              (match List.assoc_opt m.mistake spoken with
              | Some parts ->
                  if not (List.for_all speaks_of parts) then fail (Printf.sprintf "%s is described as %S" m.mistake m.description)
              | None -> fail ("an unknown mistake is listed: " ^ m.mistake));
              match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
              | Some [ value ], Some value_wanted -> (
                  match read_value value with
                  | exception Failure message -> wrong (m.mistake ^ ": " ^ message)
                  | value ->
                      if value <> value_wanted then
                        wrong (Printf.sprintf "%s gives %s, found again %s" m.mistake (show_result value) (show_result value_wanted));
                      if value = got then wrong (m.mistake ^ " gives the right answer"))
              | _, None -> ()
              | _, Some _ -> wrong (m.mistake ^ " does not give one answer"))
            listed)
  | answers -> wrong (Printf.sprintf "%d answers and not one" (List.length answers))

(* The working of this file, tried on series written by hand, most of which
   the grammar does not print. Each text is read as a question's is; it must
   come to the answer given, or be refused when none is given. *)
let check_own_working () =
  let sentence asked start body =
    match asked with
    | Radius -> Printf.sprintf {|Find the radius of convergence of the power series [`\sum_{n=%d}^{\infty} %s`].|} start body
    | Interval ->
        Printf.sprintf
          {|Find the interval of convergence of the power series [`\sum_{n=%d}^{\infty} %s`]. Enter it as an interval: a round bracket for an end that is left out, a square bracket for an end that belongs to it.|}
          start body
    | Sum -> Printf.sprintf {|Find the sum of the series [`\sum_{n=%d}^{\infty} %s`]. (Differentiate the geometric series.)|} start body
  in
  let attempt text =
    match
      let asked, start, body = read text in
      solve asked start (parse body)
    with
    | found -> Some found
    | exception Failure _ -> None
  in
  let number top bottom = Some (Number (fraction top bottom)) in
  let from a b lower upper = Some (Range (fraction a 1, fraction b 1, lower, upper)) in
  List.iter
    (fun (asked, start, body, wanted) ->
      let found = attempt (sentence asked start body) in
      if found <> wanted then
        let print = function Some value -> show_result value | None -> "refused" in
        fail (Printf.sprintf "own working: %s comes to %s, not %s" body (print found) (print wanted)))
    [ (Radius, 0, {|x^{n}|}, number 1 1);
      (Radius, 0, {|\frac{(2x - 3)^{n}}{5^{n}}|}, number 5 2);
      (Radius, 0, {|7^{n} (x + 2)^{n}|}, number 1 7);
      (Radius, 1, {|\frac{n^{2} \, (x + 1)^{2n}}{9^{n}}|}, number 3 1);
      (Radius, 1, {|\frac{(3x + 1)^{2n}}{\sqrt{n} \, 4^{n}}|}, number 2 3);
      (Radius, 0, {|\frac{(2n)!}{(n!)^{2}} \, x^{n}|}, number 1 4);
      (Radius, 0, {|\frac{(n!)^{2} \, 9^{n}}{(2n)!} \, (x - 1)^{2n}|}, number 2 3);
      (Interval, 0, {|x^{n}|}, from (-1) 1 false false);
      (Interval, 1, {|\frac{x^{n}}{n}|}, from (-1) 1 true false);
      (Interval, 1, {|\frac{(-1)^{n} \, x^{n}}{n}|}, from (-1) 1 false true);
      (Interval, 1, {|\frac{x^{n}}{n^{2}}|}, from (-1) 1 true true);
      (Interval, 1, {|n \, x^{n}|}, from (-1) 1 false false);
      (Interval, 1, {|\frac{(-1)^{n} \, \sqrt{n} \, x^{n}}{n}|}, from (-1) 1 false true);
      (Interval, 1, {|\frac{(x - 2)^{n}}{\sqrt{n} \, 3^{n}}|}, from (-1) 5 true false);
      (Interval, 1, {|\frac{(2x - 1)^{n}}{n \, 3^{n}}|}, from (-1) 2 true false);
      (Interval, 1, {|\frac{(x - 1)^{2n}}{n \, 4^{n}}|}, from (-1) 3 false false);
      (Interval, 1, {|\frac{(-1)^{n} \, (x - 1)^{2n}}{n \, 4^{n}}|}, from (-1) 3 true true);
      (Interval, 1, {|\frac{n^{2} \, (x + 4)^{n}}{n \, 2^{n}}|}, from (-6) (-2) false false);
      (Sum, 1, {|\frac{n}{2^{n}}|}, number 2 1);
      (Sum, 1, {|\frac{n \, 2^{n}}{3^{n}}|}, number 6 1);
      (Sum, 1, {|\frac{n^{2}}{2^{n}}|}, number 6 1);
      (Sum, 0, {|\frac{3^{n}}{4^{n}}|}, number 4 1);
      (* a sum that diverges; one whose rest is not bounded here *)
      (Sum, 1, {|\frac{n \, 3^{n}}{2^{n}}|}, None);
      (Sum, 1, {|\frac{2^{n}}{n \, 3^{n}}|}, None);
      (Sum, 1, {|\frac{n \, x^{n}}{3^{n}}|}, None);
      (* a first term that is not defined; no power of x; two of them *)
      (Interval, 0, {|\frac{x^{n}}{n}|}, None);
      (Radius, 0, {|\frac{3^{n}}{4^{n}}|}, None);
      (Radius, 0, {|x^{n} \, (x - 1)^{n}|}, None);
      (Radius, 0, {|\frac{2^{n}}{x^{n}}|}, None);
      (* a series that converges everywhere; ends this file cannot decide *)
      (Radius, 0, {|\frac{x^{n}}{(n!)^{2}}|}, None);
      (Interval, 0, {|\frac{(2n)!}{(n!)^{2} \, 4^{n}} \, x^{n}|}, None);
      (* what is never written *)
      (Radius, 0, {|\frac{x^{n}}{1^{n}}|}, None);
      (Radius, 0, {|(1x + 2)^{n}|}, None);
      (Radius, 0, {|(x + 0)^{n}|}, None);
      (Radius, 0, {|(x - 02)^{n}|}, None);
      (Radius, 0, {|(y - 2)^{n}|}, None);
      (Radius, 0, {|2^{n}  x^{n}|}, None);
      (Radius, 0, {|\frac{x^{n}}{2^{n}} x^{n}|}, None);
      (Radius, 2, {|x^{n}|}, None) ];
  (* the mistakes *)
  List.iter
    (fun (name, body, wanted) ->
      let found =
        match slip name (parse body) (Range (whole 0, whole 1, true, false)) with
        | found -> Some found
        | exception Failure _ -> None
      in
      if found <> wanted then fail (Printf.sprintf "own working: %s on %s is not what was expected" name body))
    [ ("reciprocal_taken", {|\frac{(3x + 1)^{n}}{4^{n}}|}, number 3 4);
      ("reciprocal_taken", {|\frac{n^{2} \, (x - 5)^{n}}{2^{n}}|}, number 1 2);
      ("reciprocal_taken", {|\frac{(2n)!}{(n!)^{2}} \, x^{n}|}, number 4 1);
      ("inner_factor_ignored", {|\frac{(3x + 1)^{n}}{4^{n}}|}, number 4 1);
      ("inner_factor_ignored", {|\frac{(x + 1)^{n}}{4^{n}}|}, None);
      ("root_not_taken", {|\frac{(x - 1)^{2n}}{9^{n}}|}, number 9 1);
      ("root_not_taken", {|\frac{(x - 1)^{n}}{9^{n}}|}, None);
      ("ends_not_tested", {|x^{n}|}, from 0 1 false false);
      ("ends_forgotten", {|x^{n}|}, None) ]

(* How many questions are made at each budget. Budget 2 has the form with
   the most different questions (scaled_radius, more than a thousand), and
   is given twice as many, so that nearly all of them are worked. *)
let questions_at cost = if cost = 2 then 40000 else 20000

let () =
  check_own_working ();
  let base = load_file "power_series.rhm" in
  (* a budget below the lowest price or above the highest is refused *)
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
    [ -1; 0; 4; 5; 6; 9 ];
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at cost - 1 do
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
  List.iter (fun (k, _) -> if times k = 0 then fail ("never generated: " ^ k)) forms;
  (* every mistake came up on each form that has it *)
  List.iter
    (fun (k, (_, _, _, slips)) ->
      List.iter (fun name -> if not (Hashtbl.mem made (name, k)) then fail (Printf.sprintf "%s never listed on %s" name k)) slips)
    forms;
  (* the numbers of each form: all that the grammar offers and no others *)
  let print numbers = "(" ^ String.concat ", " (List.map string_of_int numbers) ^ ")" in
  List.iter
    (fun (k, names) ->
      List.iter
        (fun (name, choices) ->
          let found = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
          List.iter
            (fun numbers -> if not (List.mem numbers found) then fail (Printf.sprintf "%s: the %s is never %s" k name (print numbers)))
            choices;
          List.iter
            (fun numbers -> if not (List.mem numbers choices) then fail (Printf.sprintf "%s: the %s is %s" k name (print numbers)))
            found)
        names)
    offered;
  Hashtbl.iter
    (fun (k, name) _ ->
      match List.assoc_opt k offered with
      | Some names when List.mem_assoc name names -> ()
      | _ -> fail (Printf.sprintf "%s: the %s was noted and is not looked at" k name))
    noted;
  if !failures = 0 then print_endline "Rhema power_series tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d power_series test(s) failed." !failures);
    exit 1
  end
