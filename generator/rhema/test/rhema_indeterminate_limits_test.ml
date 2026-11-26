(* Independent checks for indeterminate_limits.rhm. Nothing here uses the
   grammar's closed formulas. Every question is matched against the whole
   sentence of its form; the point the limit is taken at and every number of
   the expression are read from the sentence alone, the expression is built
   again from them as it is printed, and its limit is found in two ways that
   must agree:

   - by expansions. The expression is expanded about the point in powers of
     a small t (x = t at 0, x = 1 + t at 1, x = 1 / t at infinity) with
     fractions as coefficients, kept exactly, by a series arithmetic written
     here: sums, products, quotients, and e^w, ln(1 + w), sin w, cos w,
     tan w = sin w / cos w and the square root of a series. Negative powers
     of t are allowed, so that x f(a / x) and a difference of square roots
     at infinity are expanded as they stand. The limit is the term without
     t; an expansion that begins with a negative power has no limit and one
     that vanishes as far as it is known is refused. For a power the
     logarithm, exponent times ln(base), is expanded, and the limit is e to
     its limit;
   - by numbers. The printed expression is evaluated as it stands, in
     floating point, at x = 1/32, 1/64, ... from the point (on both sides at
     0 and at 1; at x = 32, 64, ... for infinity), and the seven values are
     extrapolated to the point by Richardson's scheme. The points are far
     enough from the limit point for plain double arithmetic to keep eight
     figures of x - sin x or e^x - 1 - x, and the extrapolation makes up
     for the distance: the two ways must agree to seven places (they agree
     to better than eight on every question the grammar can ask).

   Form by form:

   - power_ratio, log_linear: both ways, and l'Hopital's rule itself, done
     on the expansions (above and below the line are differentiated while
     both vanish at the point); the rule must be used once and give the
     same limit. The powers of power_ratio differ.
   - exponential_bases: a^x has no expansion with fractions. The limit is
     found by numbers, and as an integral: (a^x - b^x) / x is the integral
     of t^(x - 1) from b to a (tried at two values of x on each question),
     which at x = 0 is the integral of 1 / t, taken by a Gauss-Legendre
     rule. The answer must be the logarithm of one positive fraction.
   - second_order_exponential, second_order_cosine, second_order_logarithm:
     both ways and the rule, which must be used twice.
   - product_exponential, product_logarithm, product_sine, product_cosine:
     both ways; the first factor must tend to infinity and the second to 0.
   - power_at_infinity, power_at_zero: both ways; the base must tend to 1
     and the exponent to infinity. The answer must be e to a whole number,
     which is the limit of the logarithm found here, within 6 either way.
   - root_and_line, two_roots: both ways; both terms must tend to plus
     infinity. The number in front of x^2 under the root must be a square
     (the root of an expansion is taken of nothing else).
   - third_order_sine, third_order_tangent, third_order_mixed: both ways
     and the rule, which must be used three times.

   The mistakes, each redone from its description:

   - power_not_brought_down, wherever a single power of x stands below the
     line: l'Hopital's rule is done again on the expansions, with c x^n
     below the line turned into c x^(n - 1) each time. Over x^2 that must
     give twice the right answer and over x^3 six times, as the grammar's
     comments say; over x itself it changes nothing, so the mistake comes
     to the right answer and must not be listed (log_linear,
     exponential_bases). power_ratio has x^n - 1 below the line, which is
     not a single power, and lists nothing.
   - zero_times_infinity: 0, for a product whose factors were found to tend
     to infinity and to 0.
   - one_to_infinity: 1, for a power whose base was found to tend to 1 and
     whose exponent to infinity.
   - infinities_cancelled: 0, for a difference whose terms were both found
     to tend to infinity.

   Besides the answers: no limit is 0; a mistake that comes to the right
   answer must not be listed and every other one must be, in the order of
   the declarations, with the value found here, more than 1% away from the
   right answer, and described in the words of the header's list. An answer
   is a number (a fraction, compared exactly with the one found here) or a
   formula that is the logarithm of a fraction or e to a whole number, worth
   less than 1000: WeBWorK grades to one part in a thousand. The sentence
   asks for the exact value exactly when the answer is a formula. Each kind
   appears at its price alone and spends its budget; a budget outside 1..3
   gives no question; the budget the grammar sets itself is the middle
   price; the numbers of each form take exactly the values the grammar
   offers, none missing and none more. Those ranges and the descriptions
   are the only things taken from the grammar. The weights are not looked
   at. The working of this file is itself tried first on expansions and
   limits with known answers, on limits that do not exist and on sentences
   that are not written as they should be. *)

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

(* Two numbers that are the same to nine places, or to `within`. *)
let close ?(within = 1e-9) a b = Float.abs (a -. b) <= within *. Float.max 1.0 (Float.abs b)

(* ---- Fractions --------------------------------------------------------------- *)

(* A fraction in lowest terms over a positive number, so that two fractions
   are equal when they are the same record. *)
type fraction = { n : int; d : int }

let rec common a b = if b = 0 then abs a else common b (a mod b)

let frac n d =
  if d = 0 then failwith "a fraction over 0";
  let g = common n d in
  let g = if d < 0 then -g else g in
  { n = n / g; d = d / g }

(* Whole numbers are added and multiplied with a look at the result: one
   that does not fit is refused, not wrapped round. *)
let too_large () = failwith "a number too large for the working of this file"

let product a b =
  if a = 0 || b = 0 then 0
  else
    let p = a * b in
    if p / b <> a || p = min_int then too_large () else p

let sum a b =
  let s = a + b in
  if (a >= 0) = (b >= 0) && (s >= 0) <> (a >= 0) then too_large () else s

let whole n = frac n 1
let zero = whole 0
let one = whole 1

let ( +: ) a b =
  let g = common a.d b.d in
  frac (sum (product a.n (b.d / g)) (product b.n (a.d / g))) (product a.d (b.d / g))

let ( *: ) a b =
  let g = common a.n b.d and h = common b.n a.d in
  frac (product (a.n / g) (b.n / h)) (product (a.d / h) (b.d / g))

let ( /: ) a b = if b.n = 0 then failwith "a division by 0" else a *: frac b.d b.n
let is_zero a = a.n = 0
let to_float a = float_of_int a.n /. float_of_int a.d
let fraction_text a = if a.d = 1 then string_of_int a.n else Printf.sprintf "%d/%d" a.n a.d

(* ---- Expansions --------------------------------------------------------------- *)

(* terms.(i) is the coefficient of t^(low + i), and nothing is known from
   t^(low + length) on. `low` may be negative. *)
type series = { low : int; terms : fraction array }

(* How many terms are kept of what is known exactly. *)
let kept = 8

let known_to s = s.low + Array.length s.terms

(* c t^n, exactly. *)
let monomial c n = { low = n; terms = Array.init kept (fun i -> if i = 0 then c else zero) }

let constant c = monomial c 0

(* The coefficient of t^n. *)
let coefficient s n =
  if n < s.low then zero
  else if n >= known_to s then failwith "a term of an expansion that is not known"
  else s.terms.(n - s.low)

(* The same series without the zeros it begins with. *)
let trim s =
  let length = Array.length s.terms in
  let rec first i = if i < length && is_zero s.terms.(i) then first (i + 1) else i in
  let i = first 0 in
  { low = s.low + i; terms = Array.sub s.terms i (length - i) }

(* The power of t a series begins with. *)
let order s =
  let s = trim s in
  if Array.length s.terms = 0 then failwith "an expansion that vanishes as far as it is known";
  s.low

(* The coefficient it begins with. *)
let leading s =
  let s = trim s in
  if Array.length s.terms = 0 then failwith "an expansion that vanishes as far as it is known";
  s.terms.(0)

let add a b =
  let low = min a.low b.low and high = min (known_to a) (known_to b) in
  { low; terms = Array.init (max 0 (high - low)) (fun i -> coefficient a (low + i) +: coefficient b (low + i)) }

let scale c s = { s with terms = Array.map (fun x -> c *: x) s.terms }
let subtract a b = add a (scale (whole (-1)) b)

let multiply a b =
  let a = trim a and b = trim b in
  let length = min (Array.length a.terms) (Array.length b.terms) in
  let term k =
    let sum = ref zero in
    for i = 0 to k do
      sum := !sum +: (a.terms.(i) *: b.terms.(k - i))
    done;
    !sum
  in
  { low = a.low + b.low; terms = Array.init length term }

let inverse a =
  let a = trim a in
  let length = Array.length a.terms in
  if length = 0 then failwith "a division by an expansion that vanishes as far as it is known";
  let result = Array.make length zero in
  result.(0) <- one /: a.terms.(0);
  for k = 1 to length - 1 do
    let sum = ref zero in
    for i = 1 to k do
      sum := !sum +: (a.terms.(i) *: result.(k - i))
    done;
    result.(k) <- whole (-1) *: !sum /: a.terms.(0)
  done;
  { low = -a.low; terms = result }

let divide a b = multiply a (inverse b)
let rec raise_to s n = if n <= 0 then constant one else multiply s (raise_to s (n - 1))

(* g(w), for a function g whose Taylor coefficients at 0 are `taylor n`, and
   a series w that vanishes at the point. The sum is begun from one
   coefficient known up to a multiple of t, and each step of Horner's scheme
   makes one more term known. *)
let compose taylor w =
  let w = trim w in
  if w.low < 1 then failwith "a function of something that does not vanish at the point";
  let count = kept + 2 in
  let result = ref { low = 0; terms = [| taylor (count - 1) |] } in
  for n = count - 2 downto 0 do
    result := add (constant (taylor n)) (multiply w !result)
  done;
  !result

let rec factorial n = if n <= 1 then 1 else n * factorial (n - 1)

(* e^w: 1 / n!. *)
let exponential = compose (fun n -> frac 1 (factorial n))

(* sin w and cos w: the odd and the even terms of e^w, with changing signs. *)
let sine = compose (fun n -> if n mod 2 = 0 then zero else frac (if n mod 4 = 1 then 1 else -1) (factorial n))
let cosine = compose (fun n -> if n mod 2 = 1 then zero else frac (if n mod 4 = 0 then 1 else -1) (factorial n))
let tangent w = divide (sine w) (cosine w)

(* ln of a series that begins with 1: w - w^2 / 2 + w^3 / 3 - ... *)
let logarithm s =
  let s = trim s in
  if not (Array.length s.terms > 0 && s.low = 0 && s.terms.(0) = one) then
    failwith "the logarithm of something that does not tend to 1";
  let w = { s with terms = Array.mapi (fun i x -> if i = 0 then zero else x) s.terms } in
  compose (fun n -> if n = 0 then zero else frac (if n mod 2 = 1 then 1 else -1) n) w

(* The binomial coefficients of the power 1/2. *)
let rec half_power n = if n = 0 then one else half_power (n - 1) *: frac (3 - (2 * n)) (2 * n)

let whole_root n =
  let rec up r = if r * r >= n then r else up (r + 1) in
  let r = up 0 in
  if n >= 0 && r * r = n then Some r else None

(* The positive square root of a series that begins with a square times an
   even power of t (t is positive: the roots are asked for at infinity). *)
let root s =
  let s = trim s in
  if Array.length s.terms = 0 then failwith "the root of an expansion that vanishes as far as it is known";
  let c = s.terms.(0) in
  let r =
    match (whole_root c.n, whole_root c.d) with
    | Some above, Some below -> frac above below
    | _ -> failwith "the root of something that does not begin with a square"
  in
  if s.low mod 2 <> 0 then failwith "the root of an odd power";
  let w = { low = 0; terms = Array.mapi (fun i x -> if i = 0 then zero else x /: c) s.terms } in
  { (scale r (compose half_power w)) with low = s.low / 2 }

(* The slope of a series, and the slope as the mistake takes it of a single
   power c t^n: c t^(n - 1). *)
let slope s = { low = s.low - 1; terms = Array.mapi (fun i c -> whole (s.low + i) *: c) s.terms }

let single_power s =
  let s = trim s in
  let length = Array.length s.terms in
  length >= 1 && s.low >= 1 && Array.for_all is_zero (Array.sub s.terms 1 (length - 1))

let slope_without_the_power s =
  if not (single_power s) then failwith "not a single power of x";
  let s = trim s in
  { s with low = s.low - 1 }

(* The limit of a series at the point: its term without t. *)
let constant_term s =
  let s = trim s in
  if Array.length s.terms = 0 then failwith "an expansion that vanishes as far as it is known"
  else if s.low < 0 then failwith "no finite limit"
  else if s.low > 0 then zero
  else s.terms.(0)

(* L'Hopital's rule on the expansions of what stands above and below the
   line: while both vanish at the point, both are differentiated. The limit
   and how many times the rule was used. *)
let rule ~below_slope above below =
  let rec go above below used =
    if used > 4 then failwith "the rule does not come to an end";
    let top = constant_term above and bottom = constant_term below in
    if is_zero bottom then
      if is_zero top then go (slope above) (below_slope below) (used + 1) else failwith "the quotient has no finite limit"
    else (top /: bottom, used)
  in
  go above below 0

(* ---- Expressions --------------------------------------------------------------- *)

type expression =
  | X
  | Whole of int
  | Plus of expression * expression
  | Minus of expression * expression
  | Times of expression * expression
  | Over of expression * expression
  | Raised of expression * int
  | E_to of expression
  | Ln of expression
  | Sin of expression
  | Cos of expression
  | Tan of expression
  | Root of expression
  | Number_to of int * expression  (* a^x, a whole number to a power *)
  | Lifted of expression * expression  (* a base that holds x to a power that holds x *)

(* Where the limit is taken. *)
type point = At of int | Infinity

(* The value at x, in floating point, as the expression stands. *)
let rec value x = function
  | X -> x
  | Whole n -> float_of_int n
  | Plus (a, b) -> value x a +. value x b
  | Minus (a, b) -> value x a -. value x b
  | Times (a, b) -> value x a *. value x b
  | Over (a, b) -> value x a /. value x b
  | Raised (a, n) ->
      let v = value x a in
      let rec times n = if n <= 0 then 1.0 else v *. times (n - 1) in
      times n
  | E_to a -> exp (value x a)
  | Ln a -> log (value x a)
  | Sin a -> sin (value x a)
  | Cos a -> cos (value x a)
  | Tan a -> tan (value x a)
  | Root a -> sqrt (value x a)
  | Number_to (a, b) -> Float.pow (float_of_int a) (value x b)
  | Lifted (a, b) -> Float.pow (value x a) (value x b)

(* Whether an expression has an expansion with fractions. *)
let rec with_fractions = function
  | X | Whole _ -> true
  | Plus (a, b) | Minus (a, b) | Times (a, b) | Over (a, b) -> with_fractions a && with_fractions b
  | Raised (a, _) | E_to a | Ln a | Sin a | Cos a | Tan a | Root a -> with_fractions a
  | Number_to _ | Lifted _ -> false

(* The expansion about a point, in t. *)
let rec expansion point = function
  | X -> (
      match point with
      | At 0 -> monomial one 1
      | At a -> add (constant (whole a)) (monomial one 1)
      | Infinity -> monomial one (-1))
  | Whole n -> constant (whole n)
  | Plus (a, b) -> add (expansion point a) (expansion point b)
  | Minus (a, b) -> subtract (expansion point a) (expansion point b)
  | Times (a, b) -> multiply (expansion point a) (expansion point b)
  | Over (a, b) -> divide (expansion point a) (expansion point b)
  | Raised (a, n) -> raise_to (expansion point a) n
  | E_to a -> exponential (expansion point a)
  | Ln a -> logarithm (expansion point a)
  | Sin a -> sine (expansion point a)
  | Cos a -> cosine (expansion point a)
  | Tan a -> tangent (expansion point a)
  | Root a -> root (expansion point a)
  | Number_to _ -> failwith "a number to a power has no expansion with fractions"
  | Lifted _ -> failwith "a power is expanded through its logarithm"

(* What a limit is found to be. *)
type found =
  | Fraction of fraction
  | E_to_the of fraction  (* e to this power *)
  | Number_near of float  (* found by numbers alone *)

let worth = function Fraction q -> to_float q | E_to_the q -> exp (to_float q) | Number_near v -> v

let found_text = function
  | Fraction q -> fraction_text q
  | E_to_the q -> "e^(" ^ fraction_text q ^ ")"
  | Number_near v -> Printf.sprintf "%.12g" v

(* The limit by expansions. *)
let limit_by_expansion point = function
  | Lifted (base, exponent) -> E_to_the (constant_term (multiply (expansion point exponent) (logarithm (expansion point base))))
  | whole_expression -> Fraction (constant_term (expansion point whole_expression))

(* ---- Numbers -------------------------------------------------------------------- *)

let first_step = 1.0 /. 32.0
let levels = 7

(* The limit of f(h) as h tends to 0 on one side, from its values at
   first_step, half of it, a quarter of it and so on, by Richardson's
   scheme. *)
let extrapolated f side =
  let row = Array.init levels (fun k -> f (side *. first_step /. float_of_int (1 lsl k))) in
  for j = 1 to levels - 1 do
    for k = levels - 1 downto j do
      row.(k) <- row.(k) +. ((row.(k) -. row.(k - 1)) /. float_of_int ((1 lsl j) - 1))
    done
  done;
  row.(levels - 1)

(* The limit by numbers: from each side of a finite point, and from below
   at infinity. *)
let limits_by_numbers point whole_expression =
  match point with
  | At a -> List.map (extrapolated (fun h -> value (float_of_int a +. h) whole_expression)) [ 1.0; -1.0 ]
  | Infinity -> [ extrapolated (fun h -> value (1.0 /. h) whole_expression) 1.0 ]

(* How near the two ways must come. *)
let numbers_within = 1e-7

(* The integral of g from a to b by the four-point Gauss-Legendre rule on
   200 equal pieces. *)
let integral g a b =
  let nodes = [ (-0.8611363115940526, 0.3478548451374538); (-0.3399810435848563, 0.6521451548625461);
                (0.3399810435848563, 0.6521451548625461); (0.8611363115940526, 0.3478548451374538) ] in
  let panels = 200 in
  let width = (b -. a) /. float_of_int panels in
  let sum = ref 0.0 in
  for i = 0 to panels - 1 do
    let middle = a +. (width *. (float_of_int i +. 0.5)) in
    List.iter (fun (t, w) -> sum := !sum +. (w *. g (middle +. (width *. t /. 2.0)))) nodes
  done;
  !sum *. width /. 2.0

(* ---- A question, worked out ------------------------------------------------------ *)

(* The four indeterminate forms, with their two parts. *)
type shape =
  | Quotient of expression * expression  (* above and below the line *)
  | Product of expression * expression  (* the factor that grows and the one that vanishes *)
  | Power of expression * expression  (* the base and the exponent *)
  | Difference of expression * expression

let whole_of = function
  | Quotient (above, below) -> Over (above, below)
  | Product (grows, vanishes) -> Times (grows, vanishes)
  | Power (base, exponent) -> Lifted (base, exponent)
  | Difference (first, second) -> Minus (first, second)

(* What a mistake makes of a question. *)
type slip = Gives of fraction | Changes_nothing

type worked = {
  right : found;  (* the limit *)
  times : int option;  (* how often l'Hopital's rule is used, for a quotient with an expansion *)
  slips : (string * slip) list;  (* each mistake the form can make *)
}

(* The form is the indeterminate one it is said to be. *)
let check_form point shape =
  match shape with
  | Quotient (above, below) ->
      (match point with
       | At a ->
           if value (float_of_int a) above <> 0.0 || value (float_of_int a) below <> 0.0 then
             failwith "not 0 over 0 at the point"
       | Infinity -> failwith "a quotient at infinity");
      if with_fractions above && with_fractions below && not (order (expansion point above) >= 1 && order (expansion point below) >= 1)
      then failwith "the expansions do not both vanish at the point"
  | Product (grows, vanishes) ->
      if not (order (expansion point grows) < 0 && order (expansion point vanishes) > 0) then
        failwith "not a factor that tends to infinity times one that tends to 0"
  | Power (base, exponent) ->
      if not (constant_term (expansion point base) = one && order (expansion point exponent) < 0) then
        failwith "not a base that tends to 1 to a power that tends to infinity"
  | Difference (first, second) ->
      let grows term =
        let s = expansion point term in
        order s < 0 && (leading s).n > 0
      in
      if not (point = Infinity && grows first && grows second) then failwith "not a difference of two terms that tend to infinity"

(* (a^x - b^x) / x as the integral of t^(x - 1) from b to a, which is tried
   at two values of x; at x = 0 it is the integral of 1 / t. *)
let limit_of_bases a b whole_expression =
  let fa = float_of_int a and fb = float_of_int b in
  List.iter
    (fun x ->
      if not (close ~within:1e-10 (value x whole_expression) (integral (fun t -> Float.pow t (x -. 1.0)) fb fa)) then
        failwith "the quotient is not the integral of t^(x - 1) between the bases")
    [ 0.5; 0.125 ];
  integral (fun t -> 1.0 /. t) fb fa

let work_out point shape =
  let whole_expression = whole_of shape in
  check_form point shape;
  let right, times =
    match shape with
    | Quotient (Minus (Number_to (a, X), Number_to (b, X)), X) when point = At 0 ->
        (Number_near (limit_of_bases a b whole_expression), None)
    | Quotient (above, below) ->
        let limit = limit_by_expansion point whole_expression in
        let by_rule, times = rule ~below_slope:slope (expansion point above) (expansion point below) in
        if Fraction by_rule <> limit then
          failwith (Printf.sprintf "the rule gives %s and the expansions %s" (fraction_text by_rule) (found_text limit));
        (limit, Some times)
    | Product _ | Power _ | Difference _ -> (limit_by_expansion point whole_expression, None)
  in
  List.iter
    (fun estimate ->
      if not (close ~within:numbers_within estimate (worth right)) then
        failwith (Printf.sprintf "by numbers the limit is %.12g, and otherwise %s" estimate (found_text right)))
    (limits_by_numbers point whole_expression);
  if Float.abs (worth right) < 1e-9 then failwith "the limit is 0";
  let slips =
    match shape with
    | Quotient (above, below) ->
        (* the mistake is one of a single power of x below the line *)
        if point = At 0 && single_power (expansion point below) then
          let below = expansion point below in
          if with_fractions above then
            [ ("power_not_brought_down", Gives (fst (rule ~below_slope:slope_without_the_power (expansion point above) below))) ]
          else if trim (slope_without_the_power below) = trim (slope below) then [ ("power_not_brought_down", Changes_nothing) ]
          else failwith "the mistake cannot be redone without an expansion"
        else []
    | Product _ -> [ ("zero_times_infinity", Gives zero) ]
    | Power _ -> [ ("one_to_infinity", Gives one) ]
    | Difference _ -> [ ("infinities_cancelled", Gives zero) ]
  in
  { right; times; slips }

(* ---- Reading a question ---------------------------------------------------------- *)

(* A whole number, written the one way it is written. *)
let integer text =
  match int_of_string_opt text with
  | Some n when string_of_int n = text && n >= 0 -> n
  | _ -> failwith ("not a whole number: " ^ text)

(* A positive whole number in front of something, which is not written when
   it is 1. *)
let factor text =
  if text = "" then 1
  else
    let n = integer text in
    if n < 2 then failwith ("a factor that is not written as one is: " ^ text);
    n

(* The same, when it may be negative: a bare minus sign for -1, never 0. *)
let rate text =
  let length = String.length text in
  if length > 0 && text.[0] = '-' then -factor (String.sub text 1 (length - 1)) else factor text

(* A power as it is written after x: nothing for 1, or ^{n}. *)
let power_of text =
  let length = String.length text in
  if text = "" then 1
  else if length >= 4 && String.sub text 0 2 = "^{" && text.[length - 1] = '}' then begin
    let n = integer (String.sub text 2 (length - 3)) in
    if n < 2 then failwith ("a power that is not written as one is: " ^ text);
    n
  end
  else failwith ("not a power: " ^ text)

(* A number with the sign that stands in front of it. *)
let signed sign n =
  if n < 1 then failwith "a number after a sign that is not positive";
  match sign with "+" -> n | "-" -> -n | _ -> failwith ("not a sign: " ^ sign)

let words = Str.quote

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    Some (List.init count (fun n -> Str.matched_group (n + 1) prompt))
  else None

let a_number = "\\([0-9]+\\)"
let a_factor = "\\([0-9]*\\)"
let a_rate = "\\(-?[0-9]*\\)"
let a_sign = "\\([+-]\\)"
let a_power = "\\([0-9^{}]*\\)"

(* The fields of the sentence that asks for the limit of `body` at a point;
   `exact` says whether it goes on to ask for the exact value. *)
let read ~at ~exact count body prompt =
  let pattern =
    words ("Find [`\\displaystyle\\lim_{x \\to " ^ at ^ "} ") ^ body ^ words "`]."
    ^ if exact then words " Give the exact value." else ""
  in
  match fields count pattern prompt with Some found -> found | None -> failwith "the wording is not the expected one"

(* What was generated besides the kinds: each choice the grammar offers. *)
let noted : (string, string list) Hashtbl.t = Hashtbl.create 64

let note topic choice =
  let so_far = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
  if not (List.mem choice so_far) then Hashtbl.replace noted topic (choice :: so_far)

let note_pair topic a b = note topic (Printf.sprintf "%d, %d" a b)

(* k x, and a x with the same number in two or three places. *)
let times k e = Times (Whole k, e)

let same numbers =
  match numbers with
  | first :: rest when List.for_all (( = ) first) rest -> first
  | _ -> failwith "the number in front of x is not the same throughout"

(* The point and the shape of a question of a kind, from its sentence. *)
let read_question k prompt =
  let unexpected () = failwith "another number of fields was expected" in
  match k with
  (* ---- price 1 ---- *)
  | "power_ratio" -> (
      match read ~at:"1" ~exact:false 2 (words "\\frac{x" ^ a_power ^ words " - 1}{x" ^ a_power ^ words " - 1}") prompt with
      | [ above; below ] ->
          let m = power_of above and n = power_of below in
          (* the promise: the powers differ *)
          if m = n then failwith "the two powers are the same";
          note_pair "power_ratio: m, n" m n;
          (At 1, Quotient (Minus (Raised (X, m), Whole 1), Minus (Raised (X, n), Whole 1)))
      | _ -> unexpected ())
  | "log_linear" -> (
      match
        read ~at:"0" ~exact:false 3 (words "\\frac{\\ln(1 " ^ a_sign ^ " " ^ a_factor ^ words "x)}{" ^ a_rate ^ words "x}") prompt
      with
      | [ sign; inside; below ] ->
          let a = signed sign (factor inside) and b = rate below in
          note_pair "log_linear: a, b" a b;
          let within = if a > 0 then Plus (Whole 1, times a X) else Minus (Whole 1, times (-a) X) in
          (At 0, Quotient (Ln within, times b X))
      | _ -> unexpected ())
  (* ---- price 2 ---- *)
  | "exponential_bases" -> (
      match read ~at:"0" ~exact:true 2 (words "\\frac{" ^ a_number ^ words "^{x} - " ^ a_number ^ words "^{x}}{x}") prompt with
      | [ first; second ] ->
          let a = integer first and b = integer second in
          if a < 2 || b < 2 then failwith "a base under 2";
          note_pair "exponential_bases: a, b" a b;
          (At 0, Quotient (Minus (Number_to (a, X), Number_to (b, X)), X))
      | _ -> unexpected ())
  | "second_order_exponential" -> (
      match
        read ~at:"0" ~exact:false 3 (words "\\frac{e^{" ^ a_factor ^ words "x} - 1 - " ^ a_factor ^ words "x}{" ^ a_factor ^ words "x^{2}}") prompt
      with
      | [ raised; taken; below ] ->
          let a = same [ factor raised; factor taken ] and b = factor below in
          note_pair "second_order_exponential: a, b" a b;
          (At 0, Quotient (Minus (Minus (E_to (times a X), Whole 1), times a X), times b (Raised (X, 2))))
      | _ -> unexpected ())
  | "second_order_cosine" -> (
      match
        read ~at:"0" ~exact:false 3
          (words "\\frac{\\cos(" ^ a_factor ^ words "x) - \\cos(" ^ a_factor ^ words "x)}{" ^ a_factor ^ words "x^{2}}")
          prompt
      with
      | [ first; second; below ] ->
          let a = factor first and c = factor second and b = factor below in
          note "second_order_cosine: a, c, b" (Printf.sprintf "%d, %d, %d" a c b);
          (At 0, Quotient (Minus (Cos (times a X), Cos (times c X)), times b (Raised (X, 2))))
      | _ -> unexpected ())
  | "second_order_logarithm" -> (
      match
        read ~at:"0" ~exact:false 3
          (words "\\frac{\\ln(1 + " ^ a_factor ^ words "x) - " ^ a_factor ^ words "x}{" ^ a_factor ^ words "x^{2}}")
          prompt
      with
      | [ inside; taken; below ] ->
          let a = same [ factor inside; factor taken ] and b = factor below in
          note_pair "second_order_logarithm: a, b" a b;
          (At 0, Quotient (Minus (Ln (Plus (Whole 1, times a X)), times a X), times b (Raised (X, 2))))
      | _ -> unexpected ())
  | "product_exponential" -> (
      match read ~at:"\\infty" ~exact:false 2 (a_factor ^ words "x\\left(e^{" ^ a_number ^ words "/x} - 1\\right)") prompt with
      | [ front; inside ] ->
          let k = factor front and a = integer inside in
          note_pair "product_exponential: k, a" k a;
          (Infinity, Product (times k X, Minus (E_to (Over (Whole a, X)), Whole 1)))
      | _ -> unexpected ())
  | "product_logarithm" -> (
      match
        read ~at:"\\infty" ~exact:false 2 (a_factor ^ words "x \\ln\\left(1 + \\frac{" ^ a_number ^ words "}{x}\\right)") prompt
      with
      | [ front; inside ] ->
          let k = factor front and a = integer inside in
          note_pair "product_logarithm: k, a" k a;
          (Infinity, Product (times k X, Ln (Plus (Whole 1, Over (Whole a, X)))))
      | _ -> unexpected ())
  | "product_sine" -> (
      match read ~at:"\\infty" ~exact:false 2 (a_factor ^ words "x \\sin\\left(\\frac{" ^ a_number ^ words "}{x}\\right)") prompt with
      | [ front; inside ] ->
          let k = factor front and a = integer inside in
          note_pair "product_sine: k, a" k a;
          (Infinity, Product (times k X, Sin (Over (Whole a, X))))
      | _ -> unexpected ())
  | "product_cosine" -> (
      match
        read ~at:"\\infty" ~exact:false 2
          (a_factor ^ words "x^{2}\\left(1 - \\cos\\left(\\frac{" ^ a_number ^ words "}{x}\\right)\\right)")
          prompt
      with
      | [ front; inside ] ->
          let k = factor front and a = integer inside in
          note_pair "product_cosine: k, a" k a;
          (Infinity, Product (times k (Raised (X, 2)), Minus (Whole 1, Cos (Over (Whole a, X)))))
      | _ -> unexpected ())
  (* ---- price 3 ---- *)
  | "power_at_infinity" -> (
      match
        read ~at:"\\infty" ~exact:true 3
          (words "\\left(1 " ^ a_sign ^ words " \\frac{" ^ a_number ^ words "}{x}\\right)^{" ^ a_factor ^ words "x}")
          prompt
      with
      | [ sign; inside; raised ] ->
          let a = signed sign (integer inside) and b = factor raised in
          note_pair "power_at_infinity: a, b" a b;
          let part = Over (Whole (abs a), X) in
          (Infinity, Power ((if a > 0 then Plus (Whole 1, part) else Minus (Whole 1, part)), times b X))
      | _ -> unexpected ())
  | "power_at_zero" -> (
      match
        read ~at:"0" ~exact:true 3 (words "\\left(1 " ^ a_sign ^ " " ^ a_factor ^ words "x\\right)^{" ^ a_number ^ words "/x}") prompt
      with
      | [ sign; inside; raised ] ->
          let a = signed sign (factor inside) and b = integer raised in
          note_pair "power_at_zero: a, b" a b;
          let part = times (abs a) X in
          (At 0, Power ((if a > 0 then Plus (Whole 1, part) else Minus (Whole 1, part)), Over (Whole b, X)))
      | _ -> unexpected ())
  | "root_and_line" -> (
      match
        read ~at:"\\infty" ~exact:false 4
          (words "\\left(\\sqrt{" ^ a_factor ^ words "x^{2} " ^ a_sign ^ " " ^ a_factor ^ words "x} - " ^ a_factor ^ words "x\\right)")
          prompt
      with
      | [ square; sign; inside; line ] ->
          let squared = factor square and b = signed sign (factor inside) and a = factor line in
          note_pair "root_and_line: a, b" a b;
          let under = if b > 0 then Plus (times squared (Raised (X, 2)), times b X) else Minus (times squared (Raised (X, 2)), times (-b) X) in
          (Infinity, Difference (Root under, times a X))
      | _ -> unexpected ())
  | "two_roots" -> (
      match
        read ~at:"\\infty" ~exact:false 4
          (words "\\left(\\sqrt{x^{2} " ^ a_sign ^ " " ^ a_factor ^ words "x} - \\sqrt{x^{2} " ^ a_sign ^ " " ^ a_factor
         ^ words "x}\\right)")
          prompt
      with
      | [ first_sign; first; second_sign; second ] ->
          let b = signed first_sign (factor first) and c = signed second_sign (factor second) in
          (* the promise: two different roots *)
          if b = c then failwith "the same root twice";
          note "two_roots: b" (string_of_int b);
          note "two_roots: c" (string_of_int c);
          let under n = if n > 0 then Plus (Raised (X, 2), times n X) else Minus (Raised (X, 2), times (-n) X) in
          (Infinity, Difference (Root (under b), Root (under c)))
      | _ -> unexpected ())
  | "third_order_sine" -> (
      match
        read ~at:"0" ~exact:false 3 (words "\\frac{" ^ a_factor ^ words "x - \\sin(" ^ a_factor ^ words "x)}{" ^ a_factor ^ words "x^{3}}") prompt
      with
      | [ line; inside; below ] ->
          let a = same [ factor line; factor inside ] and b = factor below in
          note_pair "third_order_sine: a, b" a b;
          (At 0, Quotient (Minus (times a X, Sin (times a X)), times b (Raised (X, 3))))
      | _ -> unexpected ())
  | "third_order_tangent" -> (
      match
        read ~at:"0" ~exact:false 3 (words "\\frac{\\tan(" ^ a_factor ^ words "x) - " ^ a_factor ^ words "x}{" ^ a_factor ^ words "x^{3}}") prompt
      with
      | [ inside; line; below ] ->
          let a = same [ factor inside; factor line ] and b = factor below in
          note_pair "third_order_tangent: a, b" a b;
          (At 0, Quotient (Minus (Tan (times a X), times a X), times b (Raised (X, 3))))
      | _ -> unexpected ())
  | "third_order_mixed" -> (
      match
        read ~at:"0" ~exact:false 4
          (words "\\frac{\\sin(" ^ a_factor ^ words "x) - " ^ a_factor ^ words "x \\cos(" ^ a_factor ^ words "x)}{" ^ a_factor
         ^ words "x^{3}}")
          prompt
      with
      | [ first; line; second; below ] ->
          let a = same [ factor first; factor line; factor second ] and b = factor below in
          note_pair "third_order_mixed: a, b" a b;
          (At 0, Quotient (Minus (Sin (times a X), Times (times a X, Cos (times a X))), times b (Raised (X, 3))))
      | _ -> unexpected ())
  | _ -> failwith ("unknown kind " ^ k)

(* A question worked out from its kind and its sentence. *)
let work k prompt =
  let point, shape = read_question k prompt in
  work_out point shape

(* ---- The engine's answer ---------------------------------------------------------- *)

module F = Rhema_formula

(* How a value is written: a number, the logarithm of a positive fraction,
   or e to a fraction. *)
type written = A_number of fraction | A_logarithm of fraction | An_exponential of fraction

let name_of = function A_number _ -> "a number" | A_logarithm _ -> "the logarithm of a fraction" | An_exponential _ -> "e to a number"

let fraction_of (c : Rhema_number.t) = frac c.Rhema_number.numerator c.Rhema_number.denominator

(* The value as it is written, and what it is worth. A formula is worth
   what the engine's own evaluation says, which must be what its parts say
   here. *)
let reading = function
  | Rhema_engine.Num n -> (A_number (fraction_of n), Rhema_number.to_float n)
  | Rhema_engine.Formula (F.Ln (F.Constant c) as f) when Rhema_number.compare c Rhema_number.zero > 0 ->
      let v = F.evaluate_with (fun _ -> None) f in
      if not (close v (log (Rhema_number.to_float c))) then failwith "the formula is not worth the logarithm read from it";
      (A_logarithm (fraction_of c), v)
  | Rhema_engine.Formula (F.Exp (F.Constant c) as f) ->
      let v = F.evaluate_with (fun _ -> None) f in
      if not (close v (exp (Rhema_number.to_float c))) then failwith "the formula is not worth the power of e read from it";
      (An_exponential (fraction_of c), v)
  | other -> failwith ("a value of an unexpected type: " ^ Rhema_engine.describe_value other)

(* ---- The kinds ---------------------------------------------------------------------- *)

(* Each kind with its price and, for a quotient with an expansion, how many
   times l'Hopital's rule is used. *)
let kinds =
  [ ("power_ratio", 1, Some 1); ("log_linear", 1, Some 1); ("exponential_bases", 2, None);
    ("second_order_exponential", 2, Some 2); ("second_order_cosine", 2, Some 2); ("second_order_logarithm", 2, Some 2);
    ("product_exponential", 2, None); ("product_logarithm", 2, None); ("product_sine", 2, None); ("product_cosine", 2, None);
    ("power_at_infinity", 3, None); ("power_at_zero", 3, None); ("root_and_line", 3, None); ("two_roots", 3, None);
    ("third_order_sine", 3, Some 3); ("third_order_tangent", 3, Some 3); ("third_order_mixed", 3, Some 3) ]

(* What each mistake's description says, word for word, in the order of the
   declarations. *)
let said =
  [ ("power_not_brought_down", "differentiates x^n below the line as x^(n-1), without the factor n, each time the rule is used");
    ("zero_times_infinity", "takes a factor that tends to 0 times one that tends to infinity to be 0");
    ("one_to_infinity", "takes a base that tends to 1 raised to a power that tends to infinity to be 1");
    ("infinities_cancelled", "takes the difference of two terms that both tend to infinity to be 0") ]

(* One question: Failure says what is wrong with it. *)
let examine k expected_times (q : Rhema_engine.question) =
  let only =
    match q.Rhema_engine.answers with
    | [ only ] -> only
    | answers -> failwith (Printf.sprintf "%d answers and not one" (List.length answers))
  in
  if only <> q.Rhema_engine.answer then failwith "the answer is not the one of the only blank";
  let written, got = reading only in
  let { right; times; slips } = work k q.Rhema_engine.prompt in
  let differs () =
    failwith (Printf.sprintf "the answer is %s (%.12g), and worked out here %s" (name_of written) got (found_text right))
  in
  (match (right, written) with
   | Fraction found, A_number given -> if found <> given then differs ()
   | E_to_the found, An_exponential given ->
       if found <> given then differs ();
       (* the promises: a whole power of e, within 6 either way *)
       if found.d <> 1 then failwith "e to a power that is not whole";
       if abs found.n > 6 then failwith "e to a power beyond 6"
   | Number_near found, A_logarithm given ->
       if not (close found got) then differs ();
       if given = one then failwith "the logarithm of 1"
   | _ -> differs ());
  if not (close got (worth right)) then differs ();
  (match written with
   | A_number _ -> ()
   | A_logarithm _ | An_exponential _ -> if Float.abs got >= 1000.0 then failwith "a formula answer worth 1000 or more");
  note (k ^ ": answer") (name_of written);
  if times <> expected_times then
    failwith
      (Printf.sprintf "l'Hopital's rule is used %s"
         (match times with Some n -> Printf.sprintf "%d time(s)" n | None -> "on no expansion"));
  (* the promises: without the power brought down, twice the answer over
     x^2 and six times over x^3 *)
  (match (List.assoc_opt "power_not_brought_down" slips, times, right) with
   | Some (Gives slip), Some used, Fraction found ->
       if slip <> whole (factorial used) *: found then
         failwith (Printf.sprintf "without the power brought down the answer is not %d times as large" (factorial used))
   | Some (Gives _), _, _ -> failwith "the power is not brought down in a quotient without an expansion"
   | _ -> ());
  (* the mistakes: one that comes to the right answer is not a mistake of
     this question; any other is more than 1% away *)
  let expected =
    List.filter_map
      (fun (mistake, _) ->
        match List.assoc_opt mistake slips with
        | None -> None
        | Some Changes_nothing ->
            note (Printf.sprintf "%s: %s" k mistake) "not listed";
            None
        | Some (Gives slip) ->
            if Fraction slip = right then begin
              note (Printf.sprintf "%s: %s" k mistake) "not listed";
              None
            end
            else if Float.abs (to_float slip -. got) <= 0.01 *. Float.abs got then
              failwith (Printf.sprintf "%s gives %s, within 1%% of the right answer" mistake (fraction_text slip))
            else Some (mistake, slip))
      said
  in
  List.iter (fun (mistake, _) -> if not (List.mem_assoc mistake said) then failwith ("a mistake with no description: " ^ mistake)) slips;
  let listed = q.Rhema_engine.mistakes in
  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
  if names <> List.map fst expected then
    failwith
      (Printf.sprintf "the mistakes listed are [%s], not [%s]" (String.concat ", " names) (String.concat ", " (List.map fst expected)));
  List.iter
    (fun (m : Rhema_engine.mistaken) ->
      if List.assoc_opt m.mistake said <> Some m.description then failwith (Printf.sprintf "%s is described as %S" m.mistake m.description);
      match m.mistaken_answers with
      | Some [ value ] ->
          let shape, given = reading value in
          let slip = List.assoc m.mistake expected in
          if shape <> A_number slip then
            failwith (Printf.sprintf "%s gives %.12g, and redone here %s" m.mistake given (fraction_text slip));
          if Float.abs (given -. got) <= 0.01 *. Float.abs got then
            failwith (Printf.sprintf "%s gives %.12g, within 1%% of the right answer" m.mistake given);
          note (Printf.sprintf "%s: %s" k m.mistake) ("listed as " ^ name_of shape)
      | _ -> failwith (m.mistake ^ " does not give one answer"))
    listed

(* ---- The working of this file, tried on examples --------------------------------- *)

let trials () =
  let expect name condition = if not condition then fail ("trial: " ^ name) in
  let refused work = match work () with _ -> false | exception Failure _ -> true in
  (* fractions *)
  expect "6 / -4 is -3/2" (frac 6 (-4) = { n = -3; d = 2 });
  expect "0 / -7 is 0" (frac 0 (-7) = zero);
  expect "1/2 + 1/3" (frac 1 2 +: frac 1 3 = frac 5 6);
  expect "2/3 times 9/4" (frac 2 3 *: frac 9 4 = frac 3 2);
  expect "2/3 over 4/9" (frac 2 3 /: frac 4 9 = frac 3 2);
  expect "a fraction over 0 is refused" (refused (fun () -> frac 1 0));
  expect "a division by 0 is refused" (refused (fun () -> one /: zero));
  expect "a fraction that is too large is refused" (refused (fun () -> whole (1 lsl 40) *: whole (1 lsl 40)) && refused (fun () -> whole max_int +: one));
  (* numbers as they are written *)
  expect "a whole number is read" (integer "0" = 0 && integer "12" = 12);
  List.iter (fun text -> expect ("this whole number should be refused: " ^ text) (refused (fun () -> integer text))) [ ""; "-2"; "02"; "+2"; "2 " ];
  expect "a factor is read" (factor "" = 1 && factor "6" = 6);
  List.iter (fun text -> expect ("this factor should be refused: " ^ text) (refused (fun () -> factor text))) [ "1"; "0"; "02"; "-2"; "+2" ];
  expect "a rate is read" (rate "" = 1 && rate "-" = -1 && rate "-3" = -3 && rate "2" = 2);
  List.iter (fun text -> expect ("this rate should be refused: " ^ text) (refused (fun () -> rate text))) [ "1"; "-1"; "0"; "-0"; "+2"; "--2" ];
  expect "a power is read" (power_of "" = 1 && power_of "^{3}" = 3 && power_of "^{12}" = 12);
  List.iter
    (fun text -> expect ("this power should be refused: " ^ text) (refused (fun () -> power_of text)))
    [ "^{1}"; "^{}"; "^3"; "{3}"; "^{3"; "^{03}"; "3" ];
  expect "a sign is read" (signed "+" 3 = 3 && signed "-" 3 = -3);
  expect "a sign in front of 0 is refused" (refused (fun () -> signed "+" 0));
  (* expansions: known coefficients *)
  let t = monomial one 1 in
  let term s n = coefficient s n in
  expect "e^t" (term (exponential t) 0 = one && term (exponential t) 5 = frac 1 120);
  expect "sin t" (term (sine t) 1 = one && term (sine t) 2 = zero && term (sine t) 3 = frac (-1) 6 && term (sine t) 5 = frac 1 120);
  expect "cos t" (term (cosine t) 0 = one && term (cosine t) 2 = frac (-1) 2 && term (cosine t) 4 = frac 1 24);
  expect "tan t" (term (tangent t) 1 = one && term (tangent t) 3 = frac 1 3 && term (tangent t) 5 = frac 2 15 && term (tangent t) 7 = frac 17 315);
  let one_and_t = add (constant one) t in
  expect "ln(1 + t)" (term (logarithm one_and_t) 0 = zero && term (logarithm one_and_t) 1 = one && term (logarithm one_and_t) 4 = frac (-1) 4);
  expect "sqrt(1 + t)" (term (root one_and_t) 1 = frac 1 2 && term (root one_and_t) 2 = frac (-1) 8 && term (root one_and_t) 3 = frac 1 16);
  expect "1 / (1 - t)" (List.for_all (fun n -> term (inverse (subtract (constant one) t)) n = one) [ 0; 1; 2; 5; 7 ]);
  expect "sqrt(9 / t^2 + 6 / t + 1) is 3 / t + 1"
    (let s = root (add (add (monomial (whole 9) (-2)) (monomial (whole 6) (-1))) (constant one)) in
     order s = -1 && term s (-1) = whole 3 && term s 0 = one && term s 1 = zero && term s 3 = zero);
  expect "the slope of 2 t^3" (trim (slope (monomial (whole 2) 3)) = trim (monomial (whole 6) 2));
  expect "the slope of 2 t^3 without the power" (trim (slope_without_the_power (monomial (whole 2) 3)) = trim (monomial (whole 2) 2));
  expect "the slope of t^2 - t without the power is refused"
    (refused (fun () -> slope_without_the_power (subtract (monomial one 2) t)));
  expect "the slope of a constant without the power is refused" (refused (fun () -> slope_without_the_power (constant one)));
  expect "an unknown term is refused" (refused (fun () -> term (exponential t) kept));
  expect "e^(1 + t) is refused" (refused (fun () -> exponential one_and_t));
  expect "ln(2 + t) is refused" (refused (fun () -> logarithm (add one_and_t (constant one))));
  expect "sqrt(2 + t) is refused" (refused (fun () -> root (add one_and_t (constant one))));
  expect "sqrt(t + t^2) is refused" (refused (fun () -> root (add t (monomial one 2))));
  (* expansions against the functions themselves, a little way from 0 *)
  let at_small s =
    let h = 0.02 in
    let sum = ref 0.0 in
    Array.iteri (fun i c -> sum := !sum +. (to_float c *. Float.pow h (float_of_int (s.low + i)))) s.terms;
    !sum
  in
  let two_t = scale (whole 2) t in
  expect "e^(2t) at 0.02" (close (at_small (exponential two_t)) (exp 0.04));
  expect "sin(2t) at 0.02" (close (at_small (sine two_t)) (sin 0.04));
  expect "cos(2t) at 0.02" (close (at_small (cosine two_t)) (cos 0.04));
  expect "tan(2t) at 0.02" (close (at_small (tangent two_t)) (tan 0.04));
  expect "ln(1 + 2t) at 0.02" (close (at_small (logarithm (add (constant one) two_t))) (log 1.04));
  expect "sqrt(4 + 2t) at 0.02" (close (at_small (root (add (constant (whole 4)) two_t))) (sqrt 4.04));
  expect "1 / (3 + 2t) at 0.02" (close (at_small (inverse (add (constant (whole 3)) two_t))) (1.0 /. 3.04));
  (* limits with known answers, by expansions and by numbers *)
  let comes name point e expected =
    expect (name ^ ", by expansions") (match limit_by_expansion point e with found -> found = expected | exception Failure _ -> false);
    expect (name ^ ", by numbers")
      (List.for_all (fun estimate -> close ~within:numbers_within estimate (worth expected)) (limits_by_numbers point e))
  in
  let none name point e = expect (name ^ " has no limit to be found") (refused (fun () -> limit_by_expansion point e)) in
  comes "sin x / x" (At 0) (Over (Sin X, X)) (Fraction one);
  comes "(1 - cos x) / x^2" (At 0) (Over (Minus (Whole 1, Cos X), Raised (X, 2))) (Fraction (frac 1 2));
  comes "(tan x - sin x) / x^3" (At 0) (Over (Minus (Tan X, Sin X), Raised (X, 3))) (Fraction (frac 1 2));
  comes "(x - sin x) / x^3" (At 0) (Over (Minus (X, Sin X), Raised (X, 3))) (Fraction (frac 1 6));
  expect "(e^x - 1 - x - x^2 / 2) / x^3, by expansions"
    (limit_by_expansion (At 0) (Over (Minus (Minus (Minus (E_to X, Whole 1), X), Over (Raised (X, 2), Whole 2)), Raised (X, 3)))
     = Fraction (frac 1 6));
  comes "x^2 / sin x" (At 0) (Over (Raised (X, 2), Sin X)) (Fraction zero);
  comes "(x^3 - 1) / (x^2 - 1)" (At 1) (Over (Minus (Raised (X, 3), Whole 1), Minus (Raised (X, 2), Whole 1))) (Fraction (frac 3 2));
  comes "ln x / (x - 1)" (At 1) (Over (Ln X, Minus (X, Whole 1))) (Fraction one);
  comes "x sin(1 / x)" Infinity (Times (X, Sin (Over (Whole 1, X)))) (Fraction one);
  comes "(2x + 1) / (3x - 5)" Infinity (Over (Plus (times 2 X, Whole 1), Minus (times 3 X, Whole 5))) (Fraction (frac 2 3));
  comes "sqrt(x^2 + x) - x" Infinity (Minus (Root (Plus (Raised (X, 2), X)), X)) (Fraction (frac 1 2));
  comes "sqrt(4x^2 + 3x) - 2x" Infinity (Minus (Root (Plus (times 4 (Raised (X, 2)), times 3 X)), times 2 X)) (Fraction (frac 3 4));
  comes "(1 + 1 / x)^x" Infinity (Lifted (Plus (Whole 1, Over (Whole 1, X)), X)) (E_to_the one);
  comes "(1 + 2x)^(3 / x)" (At 0) (Lifted (Plus (Whole 1, times 2 X), Over (Whole 3, X))) (E_to_the (whole 6));
  comes "(1 - x)^(1 / (2x))" (At 0) (Lifted (Minus (Whole 1, X), Over (Whole 1, times 2 X))) (E_to_the (frac (-1) 2));
  none "1 / x at 0" (At 0) (Over (Whole 1, X));
  none "sin x / x^2 at 0" (At 0) (Over (Sin X, Raised (X, 2)));
  none "(x - x) / x at 0" (At 0) (Over (Minus (X, X), X));
  none "e^(1 / x) at 0" (At 0) (E_to (Over (Whole 1, X)));
  none "sqrt(2x^2 + x) - x at infinity" Infinity (Minus (Root (Plus (times 2 (Raised (X, 2)), X)), X));
  none "sqrt(4x^2 + 3x) - x at infinity" Infinity (Minus (Root (Plus (times 4 (Raised (X, 2)), times 3 X)), X));
  none "(2 + x)^(1 / x) at 0" (At 0) (Lifted (Plus (Whole 2, X), Over (Whole 1, X)));
  none "(2^x - 1) / x at 0" (At 0) (Over (Minus (Number_to (2, X), Whole 1), X));
  expect "the numbers tell 1/6 from 1/6 + 1/100000"
    (List.for_all
       (fun estimate -> not (close ~within:numbers_within estimate ((1.0 /. 6.0) +. 1e-5)))
       (limits_by_numbers (At 0) (Over (Minus (X, Sin X), Raised (X, 3)))));
  (* the rule *)
  let about_zero = expansion (At 0) in
  let above = about_zero (Minus (Whole 1, Cos X)) and below = about_zero (Raised (X, 2)) in
  expect "the rule on (1 - cos x) / x^2" (rule ~below_slope:slope above below = (frac 1 2, 2));
  expect "the rule on it without the power" (rule ~below_slope:slope_without_the_power above below = (one, 2));
  let above = about_zero (Minus (X, Sin X)) and below = about_zero (times 2 (Raised (X, 3))) in
  expect "the rule on (x - sin x) / (2x^3)" (rule ~below_slope:slope above below = (frac 1 12, 3));
  expect "the rule on it without the power" (rule ~below_slope:slope_without_the_power above below = (frac 1 2, 3));
  expect "the rule on (2 + x) / (3 + x) is not used" (rule ~below_slope:slope (about_zero (Plus (Whole 2, X))) (about_zero (Plus (Whole 3, X))) = (frac 2 3, 0));
  expect "the rule on sin x / x^2 is refused" (refused (fun () -> rule ~below_slope:slope (about_zero (Sin X)) (about_zero (Raised (X, 2)))));
  (* the integral *)
  expect "the integral of 1 / t from 1 to e" (close (integral (fun t -> 1.0 /. t) 1.0 (exp 1.0)) 1.0);
  expect "the integral of t^2 from 3 to 0" (close (integral (fun t -> t *. t) 3.0 0.0) (-9.0));
  (* the forms *)
  let form_refused name point shape = expect (name ^ " should be refused") (refused (fun () -> work_out point shape)) in
  form_refused "a quotient that is not 0 / 0" (At 0) (Quotient (Sin X, Plus (Whole 1, X)));
  form_refused "a quotient at infinity" Infinity (Quotient (X, times 2 X));
  form_refused "a product of two factors that grow" Infinity (Product (X, Plus (Whole 1, Over (Whole 1, X))));
  form_refused "a product in the other order" Infinity (Product (Sin (Over (Whole 1, X)), X));
  form_refused "a power of a base that tends to 2" Infinity (Power (Plus (Whole 2, Over (Whole 1, X)), X));
  form_refused "a power that stays bounded" (At 0) (Power (Plus (Whole 1, X), Whole 2));
  form_refused "a difference of a term that grows and one that does not" Infinity (Difference (X, Over (Whole 1, X)));
  form_refused "a difference of terms that tend to minus infinity" Infinity (Difference (times (-2) X, times (-2) X));
  form_refused "a limit that is 0" (At 0) (Quotient (Minus (Whole 1, Cos X), X));
  (* sentences: the limits, and what is not written as it should be *)
  let ask ?(exact = false) at body =
    Printf.sprintf "Find [`\\displaystyle\\lim_{x \\to %s} %s`].%s" at body (if exact then " Give the exact value." else "")
  in
  let reads k prompt right slips =
    expect ("this sentence should be read: " ^ prompt)
      (match work k prompt with
       | worked -> (
           worked.slips = slips
           && match (right, worked.right) with Number_near v, Number_near w -> close v w | expected, found -> expected = found)
       | exception Failure _ -> false)
  in
  let not_read k prompt = expect ("this sentence should be refused: " ^ prompt) (refused (fun () -> work k prompt)) in
  let gives name n d = [ (name, Gives (frac n d)) ] in
  reads "power_ratio" (ask "1" "\\frac{x^{8} - 1}{x^{4} - 1}") (Fraction (whole 2)) [];
  reads "power_ratio" (ask "1" "\\frac{x - 1}{x^{2} - 1}") (Fraction (frac 1 2)) [];
  not_read "power_ratio" (ask "1" "\\frac{x^{1} - 1}{x^{2} - 1}");
  not_read "power_ratio" (ask "1" "\\frac{x^{3} - 1}{x^{3} - 1}");
  not_read "power_ratio" (ask "0" "\\frac{x^{8} - 1}{x^{4} - 1}");
  not_read "power_ratio" (ask "1" "\\frac{x^{8} - 1}{x^{4} + 1}");
  reads "log_linear" (ask "0" "\\frac{\\ln(1 - 2x)}{5x}") (Fraction (frac (-2) 5)) (gives "power_not_brought_down" (-2) 5);
  reads "log_linear" (ask "0" "\\frac{\\ln(1 + x)}{-x}") (Fraction (whole (-1))) (gives "power_not_brought_down" (-1) 1);
  not_read "log_linear" (ask "0" "\\frac{\\ln(1 + 1x)}{5x}");
  not_read "log_linear" (ask "0" "\\frac{\\ln(1 + 2x)}{-1x}");
  not_read "log_linear" (ask "0" "\\frac{\\ln(1 + -2x)}{5x}");
  not_read "log_linear" (ask "1" "\\frac{\\ln(1 + 2x)}{5x}");
  not_read "log_linear" (ask ~exact:true "0" "\\frac{\\ln(1 + 2x)}{5x}");
  reads "exponential_bases" (ask ~exact:true "0" "\\frac{6^{x} - 3^{x}}{x}") (Number_near (log 2.0)) [ ("power_not_brought_down", Changes_nothing) ];
  reads "exponential_bases" (ask ~exact:true "0" "\\frac{2^{x} - 9^{x}}{x}") (Number_near (log (2.0 /. 9.0))) [ ("power_not_brought_down", Changes_nothing) ];
  not_read "exponential_bases" (ask ~exact:true "0" "\\frac{6^{x} - 6^{x}}{x}");
  not_read "exponential_bases" (ask ~exact:true "0" "\\frac{6^{x} - 1^{x}}{x}");
  not_read "exponential_bases" (ask "0" "\\frac{6^{x} - 3^{x}}{x}");
  reads "second_order_exponential" (ask "0" "\\frac{e^{4x} - 1 - 4x}{6x^{2}}") (Fraction (frac 4 3)) (gives "power_not_brought_down" 8 3);
  not_read "second_order_exponential" (ask "0" "\\frac{e^{4x} - 1 - 3x}{6x^{2}}");
  not_read "second_order_exponential" (ask "0" "\\frac{e^{4x} - 1 - 4x}{6x^{3}}");
  reads "second_order_cosine" (ask "0" "\\frac{\\cos(x) - \\cos(5x)}{5x^{2}}") (Fraction (frac 12 5)) (gives "power_not_brought_down" 24 5);
  reads "second_order_cosine" (ask "0" "\\frac{\\cos(3x) - \\cos(2x)}{x^{2}}") (Fraction (frac (-5) 2)) (gives "power_not_brought_down" (-5) 1);
  not_read "second_order_cosine" (ask "0" "\\frac{\\cos(3x) - \\cos(3x)}{5x^{2}}");
  not_read "second_order_cosine" (ask "0" "\\frac{\\cos(3x) + \\cos(2x)}{5x^{2}}");
  reads "second_order_logarithm" (ask "0" "\\frac{\\ln(1 + 5x) - 5x}{x^{2}}") (Fraction (frac (-25) 2)) (gives "power_not_brought_down" (-25) 1);
  not_read "second_order_logarithm" (ask "0" "\\frac{\\ln(1 + 5x) - 4x}{x^{2}}");
  not_read "second_order_logarithm" (ask "0" "\\frac{\\ln(1 + 5x) - 5x}{1x^{2}}");
  reads "product_exponential" (ask "\\infty" "5x\\left(e^{2/x} - 1\\right)") (Fraction (whole 10)) (gives "zero_times_infinity" 0 1);
  reads "product_exponential" (ask "\\infty" "x\\left(e^{1/x} - 1\\right)") (Fraction one) (gives "zero_times_infinity" 0 1);
  not_read "product_exponential" (ask "\\infty" "1x\\left(e^{2/x} - 1\\right)");
  not_read "product_exponential" (ask "0" "5x\\left(e^{2/x} - 1\\right)");
  not_read "product_exponential" (ask "\\infty" "5x\\left(e^{0/x} - 1\\right)");
  reads "product_logarithm" (ask "\\infty" "2x \\ln\\left(1 + \\frac{3}{x}\\right)") (Fraction (whole 6)) (gives "zero_times_infinity" 0 1);
  not_read "product_logarithm" (ask "\\infty" "2x \\ln\\left(2 + \\frac{3}{x}\\right)");
  reads "product_sine" (ask "\\infty" "4x \\sin\\left(\\frac{6}{x}\\right)") (Fraction (whole 24)) (gives "zero_times_infinity" 0 1);
  not_read "product_sine" (ask "\\infty" "4x \\cos\\left(\\frac{6}{x}\\right)");
  reads "product_cosine" (ask "\\infty" "4x^{2}\\left(1 - \\cos\\left(\\frac{4}{x}\\right)\\right)") (Fraction (whole 32)) (gives "zero_times_infinity" 0 1);
  reads "product_cosine" (ask "\\infty" "x^{2}\\left(1 - \\cos\\left(\\frac{1}{x}\\right)\\right)") (Fraction (frac 1 2)) (gives "zero_times_infinity" 0 1);
  not_read "product_cosine" (ask "\\infty" "4x\\left(1 - \\cos\\left(\\frac{4}{x}\\right)\\right)");
  reads "power_at_zero" (ask ~exact:true "0" "\\left(1 - 2x\\right)^{2/x}") (E_to_the (whole (-4))) (gives "one_to_infinity" 1 1);
  reads "power_at_zero" (ask ~exact:true "0" "\\left(1 + x\\right)^{1/x}") (E_to_the one) (gives "one_to_infinity" 1 1);
  not_read "power_at_zero" (ask ~exact:true "0" "\\left(1 + 1x\\right)^{1/x}");
  not_read "power_at_zero" (ask ~exact:true "0" "\\left(1 + x\\right)^{0/x}");
  not_read "power_at_zero" (ask ~exact:true "\\infty" "\\left(1 + x\\right)^{1/x}");
  not_read "power_at_zero" (ask "0" "\\left(1 + x\\right)^{1/x}");
  reads "power_at_infinity" (ask ~exact:true "\\infty" "\\left(1 - \\frac{3}{x}\\right)^{2x}") (E_to_the (whole (-6))) (gives "one_to_infinity" 1 1);
  reads "power_at_infinity" (ask ~exact:true "\\infty" "\\left(1 + \\frac{1}{x}\\right)^{x}") (E_to_the one) (gives "one_to_infinity" 1 1);
  not_read "power_at_infinity" (ask ~exact:true "\\infty" "\\left(1 + \\frac{0}{x}\\right)^{x}");
  not_read "power_at_infinity" (ask ~exact:true "\\infty" "\\left(1 + \\frac{1}{x}\\right)^{1x}");
  not_read "power_at_infinity" (ask ~exact:true "0" "\\left(1 + \\frac{1}{x}\\right)^{x}");
  reads "root_and_line" (ask "\\infty" "\\left(\\sqrt{9x^{2} - 4x} - 3x\\right)") (Fraction (frac (-2) 3)) (gives "infinities_cancelled" 0 1);
  reads "root_and_line" (ask "\\infty" "\\left(\\sqrt{x^{2} + x} - x\\right)") (Fraction (frac 1 2)) (gives "infinities_cancelled" 0 1);
  not_read "root_and_line" (ask "\\infty" "\\left(\\sqrt{8x^{2} - 4x} - 3x\\right)");
  not_read "root_and_line" (ask "\\infty" "\\left(\\sqrt{9x^{2} - 4x} - 2x\\right)");
  not_read "root_and_line" (ask "\\infty" "\\left(\\sqrt{9x^{2} - 4x} + 3x\\right)");
  not_read "root_and_line" (ask "0" "\\left(\\sqrt{9x^{2} - 4x} - 3x\\right)");
  reads "two_roots" (ask "\\infty" "\\left(\\sqrt{x^{2} - 3x} - \\sqrt{x^{2} - 6x}\\right)") (Fraction (frac 3 2)) (gives "infinities_cancelled" 0 1);
  reads "two_roots" (ask "\\infty" "\\left(\\sqrt{x^{2} - 9x} - \\sqrt{x^{2} + 9x}\\right)") (Fraction (whole (-9))) (gives "infinities_cancelled" 0 1);
  not_read "two_roots" (ask "\\infty" "\\left(\\sqrt{x^{2} - 3x} - \\sqrt{x^{2} - 3x}\\right)");
  not_read "two_roots" (ask "\\infty" "\\left(\\sqrt{x^{2} - 3x} - \\sqrt{x^{2} + 0x}\\right)");
  reads "third_order_sine" (ask "0" "\\frac{4x - \\sin(4x)}{4x^{3}}") (Fraction (frac 8 3)) (gives "power_not_brought_down" 16 1);
  reads "third_order_sine" (ask "0" "\\frac{x - \\sin(x)}{4x^{3}}") (Fraction (frac 1 24)) (gives "power_not_brought_down" 1 4);
  not_read "third_order_sine" (ask "0" "\\frac{4x - \\sin(3x)}{4x^{3}}");
  not_read "third_order_sine" (ask "0" "\\frac{4x - \\sin(4x)}{4x^{2}}");
  reads "third_order_tangent" (ask "0" "\\frac{\\tan(2x) - 2x}{4x^{3}}") (Fraction (frac 2 3)) (gives "power_not_brought_down" 4 1);
  not_read "third_order_tangent" (ask "0" "\\frac{\\tan(2x) - 3x}{4x^{3}}");
  reads "third_order_mixed" (ask "0" "\\frac{\\sin(3x) - 3x \\cos(3x)}{2x^{3}}") (Fraction (frac 9 2)) (gives "power_not_brought_down" 27 1);
  not_read "third_order_mixed" (ask "0" "\\frac{\\sin(3x) - 3x \\cos(2x)}{2x^{3}}");
  not_read "third_order_mixed" (ask "0" "\\frac{\\sin(3x) - 3x \\cos(3x)}{2x^{3}}" ^ " ");
  not_read "third_order_sine" (ask "0" "\\frac{\\tan(2x) - 2x}{4x^{3}}");
  not_read "no_such_kind" (ask "0" "\\frac{4x - \\sin(4x)}{4x^{3}}");
  (* nothing of the trials is counted among what the grammar offers *)
  Hashtbl.reset noted

(* ---- The questions ---------------------------------------------------------------- *)

let questions_at_each_budget = 30000

(* Added to every seed: another number gives other draws, and the suite
   passes with them too. *)
let seed_offset = 0

(* A question that was looked at already, with the same answer and the same
   mistakes, is not worked out again. *)
let examined : (string, unit) Hashtbl.t = Hashtbl.create 4096

let () =
  trials ();
  let base = load_file "indeterminate_limits.rhm" in
  let seen = Hashtbl.create 32 and generated = Hashtbl.create 4 in
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
          match List.find_opt (fun (name, _, _) -> name = k) kinds with
          | None -> fail ("a kind the header does not list: " ^ k)
          | Some (_, price, times) ->
              if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost)
              else
                let whole_question = String.concat "\n" (k :: p :: q.Rhema_engine.answer_text :: Rhema_engine.describe_mistakes q) in
                if not (Hashtbl.mem examined whole_question) then begin
                  Hashtbl.replace examined whole_question ();
                  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
                  try examine k times q with Failure m -> wrong m | e -> wrong (Printexc.to_string e)
                end)
    done
  done;
  for cost = 1 to 3 do
    let count = Option.value ~default:0 (Hashtbl.find_opt generated cost) in
    if count < questions_at_each_budget then fail (Printf.sprintf "only %d questions at cost %d" count cost)
  done;
  List.iter (fun (k, _, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) kinds;
  (* Every choice the grammar offers is taken at least once, and no other. *)
  let ints first last = List.init (last - first + 1) (fun n -> first + n) in
  let either_sign last = List.map (fun n -> -n) (List.rev (ints 1 last)) @ ints 1 last in
  let pairs ?(keep = fun _ _ -> true) firsts seconds =
    List.concat_map (fun a -> List.filter_map (fun b -> if keep a b then Some (Printf.sprintf "%d, %d" a b) else None) seconds) firsts
  in
  let different a b = a <> b in
  let number = "a number" in
  let answers how names = List.map (fun k -> (k ^ ": answer", [ how ])) names in
  let slip mistake how names = List.map (fun k -> (Printf.sprintf "%s: %s" k mistake, [ how ])) names in
  let second_order = [ "second_order_exponential"; "second_order_cosine"; "second_order_logarithm" ] in
  let products = [ "product_exponential"; "product_logarithm"; "product_sine"; "product_cosine" ] in
  let powers = [ "power_at_infinity"; "power_at_zero" ] and roots = [ "root_and_line"; "two_roots" ] in
  let third_order = [ "third_order_sine"; "third_order_tangent"; "third_order_mixed" ] in
  let choices =
    [ ("power_ratio: m, n", pairs ~keep:different (ints 1 9) (ints 1 9));
      ("log_linear: a, b", pairs ~keep:different (either_sign 5) (either_sign 6));
      ("exponential_bases: a, b", pairs ~keep:different (ints 2 9) (ints 2 9));
      ("second_order_exponential: a, b", pairs (ints 1 5) (ints 1 6));
      ( "second_order_cosine: a, c, b",
        List.concat_map (fun b -> List.map (fun a_c -> Printf.sprintf "%s, %d" a_c b) (pairs ~keep:different (ints 1 5) (ints 1 5))) (ints 1 6) );
      ("second_order_logarithm: a, b", pairs (ints 1 5) (ints 1 6));
      ("two_roots: b", List.map string_of_int (either_sign 9)); ("two_roots: c", List.map string_of_int (either_sign 9));
      ("root_and_line: a, b", pairs (ints 1 5) (either_sign 9)) ]
    @ List.map (fun k -> (k ^ ": k, a", pairs (ints 1 5) (ints 1 6))) products
    @ List.map (fun k -> (k ^ ": a, b", pairs ~keep:(fun a b -> abs (a * b) <= 6) (either_sign 4) (ints 1 4))) powers
    @ List.map (fun k -> (k ^ ": a, b", pairs (ints 1 4) (ints 1 6))) third_order
    @ answers number ([ "power_ratio"; "log_linear" ] @ second_order @ products @ roots @ third_order)
    @ answers "the logarithm of a fraction" [ "exponential_bases" ]
    @ answers "e to a number" powers
    @ slip "power_not_brought_down" "not listed" [ "log_linear"; "exponential_bases" ]
    @ slip "power_not_brought_down" ("listed as " ^ number) (second_order @ third_order)
    @ slip "zero_times_infinity" ("listed as " ^ number) products
    @ slip "one_to_infinity" ("listed as " ^ number) powers
    @ slip "infinities_cancelled" ("listed as " ^ number) roots
  in
  List.iter
    (fun (topic, offered) ->
      let met = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
      List.iter (fun choice -> if not (List.mem choice met) then fail (Printf.sprintf "never generated: %s %s" topic choice)) offered;
      List.iter (fun choice -> if not (List.mem choice offered) then fail (Printf.sprintf "not offered: %s %s" topic choice)) met)
    choices;
  Hashtbl.iter (fun topic _ -> if not (List.mem_assoc topic choices) then fail ("nothing is said of: " ^ topic)) noted;
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
  if !failures = 0 then print_endline "Rhema indeterminate_limits tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d indeterminate_limits test(s) failed." !failures);
    exit 1
  end
