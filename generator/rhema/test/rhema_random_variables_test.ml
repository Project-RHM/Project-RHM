(* Independent checks for random_variables.rhm. Every question is matched
   against the whole sentence of its form, the numbers are read back from it,
   and the answer is found again from the definitions, with exact fractions,
   never by the rule or the closed formula the grammar uses:

   linear_mean       random variables with the printed mean are written out
                     as tables of values and probabilities: two families (a
                     skewed one with two values, a balanced one with three),
                     each with two spreads. The mean of each table is checked
                     by the definition; every value x is replaced by a x + b,
                     and the mean of the new table is the sum of value times
                     probability. The four tables must agree, since what is
                     given is to settle the answer.
   linear_variance   tables with the printed variance (the same two families,
                     about two different means), the variance of each checked
                     by the definition as the mean of (x - E X)^2. Every
                     value is replaced by a x + b and the variance of the new
                     table is found by the definition. The tables must agree.
   variance_from_moments
                     in each family the table with the printed mean whose
                     E(X^2), summed by the definition, is the printed one is
                     searched for, from the least spread upwards. Its
                     variance is the mean of (x - E X)^2. The two families
                     must agree. The mean is neither 0 nor 1.
   binomial_mean, binomial_variance
                     the number of successes is followed trial by trial: the
                     table of the number of successes after t + 1 trials is
                     made from the table after t trials by the two outcomes
                     of one more trial. No binomial coefficient is used. The
                     mean and the variance of the last table are sums over
                     it, by the definition. The probability printed is in
                     lowest terms and strictly between 0 and 1.
   uniform_probability
                     all four ends are whole numbers, so the interval is cut
                     into pieces of length 1, and the pieces inside the part
                     asked for are counted against all of them. The part
                     asked for lies in the interval, has a length, and is not
                     the whole interval.
   geometric_mean    the expected number E of attempts satisfies the equation
                     of the first step: E = p * 1 + (1 - p) * (1 + E), which
                     is solved as a linear equation. The sum of k times the
                     probability of a first success at attempt k is added up
                     in floating point as well, until what is left has no
                     weight, and must come to the same number.
   independent_combination
                     a table for X and one for Y with the printed variances
                     (checked by the definition), of different families and
                     about different means. Every pair of outcomes is written
                     out with the product of the two probabilities, which is
                     what independence says; a x + b y or a x - b y is worked
                     out for each pair, and the variance of the result is
                     found by the definition. Two such pairs of tables must
                     agree. One of the two factors is not 1.
   geometric_first   a trial is the drawing of one of b tickets, a of them
                     winning, for the printed probability a / b. Every
                     sequence of k tickets is written out, and those whose
                     first winning ticket is the last one are counted against
                     all of them.
   density_constant  x^n is integrated over the printed interval by this
                     file's own polynomials (and by Simpson's rule in
                     floating point, which must agree); c is 1 over the
                     integral, and c x^n is then integrated to 1.
   density_probability, density_mean, density_variance
                     the printed density is first integrated over the printed
                     interval, and must come to 1. The probability is its
                     integral over the part asked for (from 0 up to m, or
                     from m to the upper end, with m strictly inside); the
                     mean is the integral of x f(x); the variance is the
                     integral of (x - E X)^2 f(x). Every integral is exact,
                     by the antiderivative of a polynomial, and is checked by
                     Simpson's rule.
   covariance        the four printed probabilities are above 0 and add up to
                     1. E(X) and E(Y) are sums over the four outcomes, and
                     the covariance is the sum of (x - E X)(y - E Y) p over
                     them: the definition, not the shorter form the question
                     prints.

   The mistakes are found again from what each says the student does.
   not_squared multiplies a variance (found from a table by the definition)
   by the factor printed in front of its variable: a Var(X), with the sign
   of a, for aX + b, and a Var(X) + b Var(Y) for aX + bY and aX - bY, where
   the variances are still added. variances_subtracted is the variance of aX
   less the variance of bY, each from its own table by the definition; it
   is a mistake of a difference only. mean_not_squared is E(X^2) less E(X),
   both summed over the table or integrated. A question must list exactly
   the mistakes of its form, in the order they are declared, with these
   values, each of them another number than the right answer; a form with no
   mistake lists none, and a sum of two variables is not open to
   variances_subtracted. Each mistake is described in the words it was
   declared with.

   Every kind must come up at its price and at no other, the budget must be
   spent, a budget outside 1 to 3 must give no question, a budget left alone
   is 2, and every answer must be one number, whole or a fraction. The
   numbers each form is asked with are pinned as well: every choice the
   grammar offers must come up, and nothing else. The weights of the forms
   are not pinned. *)

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

let memo f =
  let known = Hashtbl.create 16 in
  fun key ->
    match Hashtbl.find_opt known key with
    | Some value -> value
    | None ->
        let value = f key in
        Hashtbl.add known key value;
        value

let range first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)

(* ---- Fractions ---- *)

(* Fractions on OCaml integers, in lowest terms with a positive denominator,
   so that two equal fractions are equal as records. The table of a binomial
   variable has denominators up to 6^20, so every sum and every product of
   integers is checked: a number that does not fit is an error, never a
   wrong number. *)
type fraction = { top : int; bottom : int }

let too_large () = failwith "a number grew too large to be kept exact"

let times a b =
  if a = 0 || b = 0 then 0
  else if a = min_int || b = min_int then too_large ()
  else
    let product = a * b in
    if product / b <> a then too_large () else product

let plus a b =
  let sum = a + b in
  if a >= 0 = (b >= 0) && sum >= 0 <> (a >= 0) then too_large () else sum

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let fraction top bottom =
  if bottom = 0 then failwith "division by zero";
  let top, bottom = if bottom < 0 then (-top, -bottom) else (top, bottom) in
  let divisor = gcd top bottom in
  { top = top / divisor; bottom = bottom / divisor }

let whole n = { top = n; bottom = 1 }
let zero = whole 0
let one = whole 1

let ( +: ) a b =
  let shared = gcd a.bottom b.bottom in
  fraction
    (plus (times a.top (b.bottom / shared)) (times b.top (a.bottom / shared)))
    (times a.bottom (b.bottom / shared))

let ( *: ) a b =
  let left = gcd a.top b.bottom and right = gcd b.top a.bottom in
  fraction (times (a.top / left) (b.top / right)) (times (a.bottom / right) (b.bottom / left))

let ( -: ) a b = a +: { b with top = -b.top }
let ( /: ) a b = if b.top = 0 then failwith "division by zero" else a *: fraction b.bottom b.top
let square a = a *: a
let sign a = compare a.top 0
let less a b = sign (a -: b) < 0
let to_float a = float a.top /. float a.bottom
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

let number = function
  | Rhema_engine.Num n -> Some (fraction n.Rhema_number.numerator n.Rhema_number.denominator)
  | _ -> None

(* The same number found in several ways: it is given once. *)
let agreed = function
  | [] -> failwith "nothing was worked out"
  | first :: others ->
      if List.exists (fun other -> other <> first) others then
        failwith "the answer is not settled by what is given: two random variables that fit give two answers";
      first

(* ---- Random variables as tables ---- *)

(* A random variable with finitely many outcomes: each outcome with its
   probability. The probabilities are above 0 and add up to 1. *)
let table outcomes =
  if List.exists (fun (_, p) -> sign p <= 0) outcomes then failwith "an outcome without a probability above 0";
  if List.fold_left (fun total (_, p) -> total +: p) zero outcomes <> one then
    failwith "the probabilities do not add up to 1";
  outcomes

(* The mean of f over a table: the sum of f(outcome) times probability. *)
let expectation f outcomes = List.fold_left (fun total (x, p) -> total +: (f x *: p)) zero outcomes

let mean outcomes = expectation Fun.id outcomes
let second_moment outcomes = expectation square outcomes

(* The variance by its definition: the mean of the squared distance from the mean. *)
let variance outcomes =
  let centre = mean outcomes in
  expectation (fun x -> square (x -: centre)) outcomes

(* The variable f(X): every outcome is replaced. *)
let image f outcomes = List.map (fun (x, p) -> (f x, p)) outcomes

(* Two independent variables together: every pair of outcomes, with the
   product of the two probabilities. *)
let independent xs ys = table (List.concat_map (fun (x, p) -> List.map (fun (y, q) -> ((x, y), p *: q)) ys) xs)

(* Two families of tables about a mean m, with a spread v that is a whole
   number above 0. The skewed one takes m - 1 with probability v / (v + 1)
   and m + v with probability 1 / (v + 1). The balanced one takes m - c and
   m + c with the same probability and m with the rest, for the least whole
   c whose square reaches v. Both are made to have the mean m and the
   variance v, but nothing below takes that on trust: the mean and the
   variance are worked out from the table wherever they are needed. *)
let skewed m v =
  if v < 1 then failwith "a table needs a spread above 0";
  table [ (whole (m - 1), fraction v (v + 1)); (whole (m + v), fraction 1 (v + 1)) ]

let balanced m v =
  if v < 1 then failwith "a table needs a spread above 0";
  let rec reach c = if c * c >= v then c else reach (c + 1) in
  let c = reach 1 in
  let side = fraction v (2 * c * c) in
  table
    (List.filter
       (fun (_, p) -> sign p > 0)
       [ (whole (m - c), side); (whole m, one -: side -: side); (whole (m + c), side) ])

let having name wanted found outcomes =
  if found outcomes <> wanted then failwith ("the table written out does not have the printed " ^ name);
  outcomes

(* The table of a family with the mean m whose E(X^2) is the printed one,
   searched for from the least spread upwards: E(X^2) grows with the spread. *)
let with_moments family m second =
  let rec search v =
    if v > 1000 then failwith "no table was found with the two printed moments"
    else
      let outcomes = family m v in
      let found = second_moment outcomes in
      if found = second then outcomes
      else if less second found then failwith "no random variable has the two printed moments"
      else search (v + 1)
  in
  having "mean" (whole m) mean (search 1)

(* The number of successes in n independent trials that each succeed with
   probability a / b, followed trial by trial. The weights are numbers of
   b^t-ths after t trials: one more trial leaves the number of successes as
   it is with weight b - a, or adds one to it with weight a. *)
let successes =
  memo (fun (n, a, b) ->
      if n < 0 || n > 60 || a < 1 || a >= b then failwith "not a number of trials and a probability to follow";
      let rec after trials weights all =
        if trials = n then (weights, all)
        else
          let stay = List.map (fun w -> times w (b - a)) weights @ [ 0 ]
          and gain = 0 :: List.map (fun w -> times w a) weights in
          after (trials + 1) (List.map2 plus stay gain) (times all b)
      in
      let weights, all = after 0 [ 1 ] 1 in
      table (List.mapi (fun k w -> (whole k, fraction w all)) weights))

(* The expected number E of attempts up to the first success. After one
   attempt the experiment has succeeded, with probability p, or it stands
   where it began, with one attempt spent: E = p * 1 + (1 - p) * (1 + E).
   The equation E = c + d E is solved for E. The sum of the definition, of
   k times the probability that the first success comes at attempt k, is
   added up as well, and must come to the same. *)
let attempts_expected =
  memo (fun p ->
      if sign p <= 0 || less one p then failwith "not a probability of success";
      let again = one -: p in
      let c = (p *: one) +: (again *: one) and d = again in
      let solved = c /: (one -: d) in
      let chance = to_float p in
      let total = ref 0.0 and unsuccessful = ref 1.0 in
      for attempt = 1 to 20000 do
        total := !total +. (float attempt *. !unsuccessful *. chance);
        unsuccessful := !unsuccessful *. (1.0 -. chance)
      done;
      if !unsuccessful > 1e-30 then failwith "the sum for the expected number of attempts was not carried far enough";
      if Float.abs (!total -. to_float solved) > 1e-9 then
        failwith "the first-step equation and the sum of the definition give two expected numbers of attempts";
      solved)

(* Every sequence of k tickets out of b. *)
let rec sequences k b =
  if k = 0 then [ [] ]
  else List.concat_map (fun rest -> List.map (fun ticket -> ticket :: rest) (range 1 b)) (sequences (k - 1) b)

(* The probability that the first success comes at attempt k, when a trial
   succeeds with probability a / b: a trial draws one of b tickets, of which
   those numbered 1 to a win. The sequences of k tickets whose first winning
   ticket is the last are counted against all of them. *)
let first_success_at =
  memo (fun (a, b, k) ->
      if b < 2 || b > 8 || k < 1 || k > 6 || a < 1 || a >= b then failwith "too many sequences of tickets to write out";
      let wins ticket = ticket <= a in
      let rec first_win place = function
        | [] -> None
        | ticket :: rest -> if wins ticket then Some place else first_win (place + 1) rest
      in
      let all = sequences k b in
      fraction (List.length (List.filter (fun drawn -> first_win 1 drawn = Some k) all)) (List.length all))

(* The share of an interval with whole ends that a part of it with whole
   ends takes: the pieces of length 1 inside the part, against all of them. *)
let share_of_interval ~lower ~upper ~from ~upto =
  if upper <= lower then failwith "the interval has no length";
  if upper - lower > 1000 then failwith "too long an interval to cut into pieces";
  if from < lower || upto > upper then failwith "the part asked for is not inside the interval";
  if upto <= from then failwith "the part asked for has no length";
  let pieces = range lower (upper - 1) in
  let inside = List.filter (fun piece -> from <= piece && piece + 1 <= upto) pieces in
  fraction (List.length inside) (List.length pieces)

(* ---- Densities ---- *)

(* A polynomial, as its coefficients from the constant term upwards. *)
let monomial c n = List.init (n + 1) (fun i -> if i = n then c else zero)

let rec add p q =
  match (p, q) with
  | [], rest | rest, [] -> rest
  | a :: p, b :: q -> (a +: b) :: add p q

let rec multiply p q =
  match p with [] -> [] | a :: rest -> add (List.map (fun b -> a *: b) q) (zero :: multiply rest q)

let value p x = List.fold_right (fun c higher -> c +: (x *: higher)) p zero
let value_float p x = List.fold_right (fun c higher -> to_float c +. (x *. higher)) p 0.0

(* The integral of a polynomial between two whole numbers: exactly, term by
   term, and by Simpson's rule on 2000 strips in floating point, which must
   come to the same number. *)
let integral p lower upper =
  let antiderivative = zero :: List.mapi (fun i c -> c /: whole (i + 1)) p in
  let exact = value antiderivative (whole upper) -: value antiderivative (whole lower) in
  let strips = 2000 in
  let width = float (upper - lower) /. float strips in
  let total = ref (value_float p (float lower) +. value_float p (float upper)) in
  for i = 1 to strips - 1 do
    total := !total +. ((if i mod 2 = 1 then 4.0 else 2.0) *. value_float p (float lower +. (float i *. width)))
  done;
  if Float.abs ((!total *. width /. 3.0) -. to_float exact) > 1e-9 then
    failwith "the exact integral and Simpson's rule give two numbers";
  exact

let x_alone = monomial one 1

(* The density c x^n on the interval from 0 to b, and nothing elsewhere: it
   is not negative, and its integral is 1. *)
let density =
  memo (fun (c, n, b) ->
      if n < 0 || n > 8 || b < 1 || b > 20 then failwith "not a density this file integrates";
      if sign c <= 0 then failwith "the density is not above 0 inside its interval";
      let f = monomial c n in
      if integral f 0 b <> one then failwith "the printed density does not integrate to 1";
      f)

(* The mean, E(X^2) and the variance of a density on the interval from 0 to
   b, each by its integral. *)
let density_moments =
  memo (fun (c, n, b) ->
      let f = density (c, n, b) in
      let centre = integral (multiply x_alone f) 0 b in
      let off_centre = [ zero -: centre; one ] in
      let spread = integral (multiply (multiply off_centre off_centre) f) 0 b in
      let second = integral (multiply (multiply x_alone x_alone) f) 0 b in
      (centre, second, spread))

(* ---- Reading a question ---- *)

(* The numbers of a prompt: the pattern is the whole sentence, with a group
   wherever a number stands. *)
let words = Str.quote
let a_count = "\\([1-9][0-9]*\\)"
let an_integer = "\\(0\\|-?[1-9][0-9]*\\)"

(* a fraction: two groups *)
let a_fraction = words "\\frac{" ^ a_count ^ words "}{" ^ a_count ^ words "}"

(* the factor in front of a variable: nothing, a sign, or a number *)
let a_factor = "\\(-?[0-9]*\\)"

(* x or x^{n} *)
let a_power = "\\(x\\|x\\^{[1-9][0-9]*}\\)"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* A factor as it is written in front of a variable: 1 is not written, -1
   is a minus sign, and no factor is 0. *)
let factor written =
  match written with
  | "" -> 1
  | "-" -> -1
  | _ -> (
      match int_of_string_opt written with
      | Some n when n <> 0 && n <> 1 && n <> -1 && string_of_int n = written -> n
      | _ -> failwith ("not the way a factor is written: " ^ written))

(* The factor and the constant of a X + b or a X - b. The factor is neither
   0 nor 1 and the constant is not 0. *)
let linear a operation b =
  let a = factor a and b = int_of_string b in
  if a = 1 then failwith "the factor in front of X is 1";
  (a, if operation = "-" then -b else b)

(* A probability printed as a fraction: in lowest terms, strictly between 0
   and 1. *)
let probability top bottom =
  let top = int_of_string top and bottom = int_of_string bottom in
  if gcd top bottom <> 1 then failwith "a probability that is not in lowest terms";
  if top < 1 || top >= bottom then failwith "a probability that is not strictly between 0 and 1";
  fraction top bottom

(* The degree of x or x^{n}; x^{1} is written x. *)
let degree written =
  if written = "x" then 1
  else
    match int_of_string_opt (String.sub written 3 (String.length written - 4)) with
    | Some n when n >= 2 -> n
    | _ -> failwith ("not the way a power is written: " ^ written)

(* ---- What each form was asked with ---- *)

let asked : (string * int list, unit) Hashtbl.t = Hashtbl.create 1024
let note label numbers = Hashtbl.replace asked (label, numbers) ()

(* Every choice the grammar offers, form by form. A form with many numbers
   is pinned by its numbers two or three at a time. *)
let offered =
  let pairs firsts seconds = List.concat_map (fun first -> List.map (fun second -> [ first; second ]) seconds) firsts in
  let one values = List.map (fun value -> [ value ]) values in
  let not_zero values = List.filter (fun value -> value <> 0) values in
  (* the probabilities of success: the fractions in lowest terms with a
     denominator up to 6, strictly between 0 and 1 *)
  let chances =
    List.concat_map
      (fun bottom ->
        List.filter_map (fun top -> if gcd top bottom = 1 then Some [ top; bottom ] else None) (range 1 (bottom - 1)))
      (range 2 6)
  in
  (* the factors of a X + b and its constants *)
  let factors = List.filter (fun a -> a <> 0 && a <> 1) (range (-5) 5) and constants = not_zero (range (-9) 9) in
  (* the densities: the degree and the upper end *)
  let densities = pairs (range 1 3) (range 2 4) in
  [ ("linear_mean, mean and factor", pairs (not_zero (range (-9) 9)) factors);
    ("linear_mean, factor and constant", pairs factors constants);
    ("binomial_mean", List.concat_map (fun n -> List.map (fun chance -> n :: chance) chances) (range 4 20));
    ("uniform_probability, lower end", one (range (-5) 5));
    (* the lengths before, inside and after the part asked for: the part has
       a length and is not the whole interval *)
    ( "uniform_probability, lengths",
      List.concat_map
        (fun before ->
          List.concat_map
            (fun inside ->
              List.filter_map (fun after -> if before + after > 0 then Some [ before; inside; after ] else None) (range 0 4))
            (range 1 5))
        (range 0 4) );
    ("geometric_mean", chances);
    ("linear_variance, variance and factor", pairs (range 1 9) factors);
    ("linear_variance, factor and constant", pairs factors constants);
    (* the mean and the variance; the mean is neither 0 nor 1 *)
    ("variance_from_moments", pairs (List.filter (fun m -> m <> 0 && m <> 1) (range (-6) 6)) (range 1 9));
    ("binomial_variance", List.concat_map (fun n -> List.map (fun chance -> n :: chance) chances) (range 4 20));
    ("independent_combination, variances", pairs (range 1 9) (range 1 9));
    (* the two factors, not both 1, and 1 for a difference or 0 for a sum *)
    ( "independent_combination, factors",
      List.concat_map
        (fun a ->
          List.concat_map (fun b -> if a + b > 2 then [ [ a; b; 0 ]; [ a; b; 1 ] ] else []) (range 1 4))
        (range 1 4) );
    ("geometric_first", List.concat_map (fun chance -> List.map (fun k -> chance @ [ k ]) (range 2 4)) chances);
    ("density_constant", densities);
    (* the degree, the upper end, a whole number strictly inside the
       interval, and 0 for "at most" or 1 for "above" *)
    ( "density_probability",
      List.concat_map
        (fun d ->
          match d with
          | [ _; b ] -> List.concat_map (fun m -> [ d @ [ m; 0 ]; d @ [ m; 1 ] ]) (range 1 (b - 1))
          | _ -> [])
        densities );
    ("density_mean", densities);
    ("density_variance", densities);
    (* the four probabilities as whole numbers in lowest terms: four weights
       from 1 to 4, divided by what they share *)
    ( "covariance",
      List.sort_uniq compare
        (List.concat_map
           (fun w1 ->
             List.concat_map
               (fun w2 ->
                 List.concat_map
                   (fun w3 ->
                     List.map
                       (fun w4 ->
                         let shared = gcd (gcd w1 w2) (gcd w3 w4) in
                         List.map (fun w -> w / shared) [ w1; w2; w3; w4 ])
                       (range 1 4))
                   (range 1 4))
               (range 1 4))
           (range 1 4)) ) ]

(* ---- The answer of each form, found again ---- *)

let experiment =
  words "An experiment succeeds with probability [`" ^ a_fraction
  ^ words "`] each time it is tried, independently of the other times. "

let trials = experiment ^ words "It is tried [`" ^ a_count ^ words "`] times, and [`X`] is the number of successes. Find [`"

let density_given =
  words "A random variable [`X`] has the probability density [`f(x) = " ^ a_fraction ^ " " ^ a_power
  ^ words "`] for [`0 \\le x \\le " ^ a_count ^ words "`], and [`f(x) = 0`] elsewhere. Find [`"

(* The density a question prints: its constant, its degree and its upper end. *)
let printed_density top bottom power upper =
  (fraction (int_of_string top) (int_of_string bottom), degree power, int_of_string upper)

(* The right answer of a question, and the answer of each mistake that its
   form is open to, all found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "linear_mean" -> (
      match
        fields 4
          (words "A random variable [`X`] has [`E(X) = " ^ an_integer ^ words "`]. Find [`E(" ^ a_factor ^ "X \\([+-]\\) "
         ^ a_count ^ words ")`].")
          p
      with
      | [ m; a; operation; b ] ->
          let m = int_of_string m and a, b = linear a operation b in
          note "linear_mean, mean and factor" [ m; a ];
          note "linear_mean, factor and constant" [ a; b ];
          let found =
            List.map
              (fun outcomes ->
                let outcomes = having "mean" (whole m) mean outcomes in
                mean (image (fun x -> (whole a *: x) +: whole b) outcomes))
              [ skewed m 2; balanced m 2; skewed m 7; balanced m 7 ]
          in
          (agreed found, [])
      | _ -> failwith "four fields were expected")
  | "linear_variance" -> (
      match
        fields 4
          (words "A random variable [`X`] has [`\\mathrm{Var}(X) = " ^ a_count ^ words "`]. Find [`\\mathrm{Var}("
         ^ a_factor ^ "X \\([+-]\\) " ^ a_count ^ words ")`].")
          p
      with
      | [ v; a; operation; b ] ->
          let v = int_of_string v and a, b = linear a operation b in
          note "linear_variance, variance and factor" [ v; a ];
          note "linear_variance, factor and constant" [ a; b ];
          let found =
            List.map
              (fun outcomes ->
                let outcomes = having "variance" (whole v) variance outcomes in
                ( variance (image (fun x -> (whole a *: x) +: whole b) outcomes),
                  (* the variance, times the factor as it stands *)
                  whole a *: variance outcomes ))
              [ skewed (-3) v; balanced (-3) v; skewed 2 v; balanced 2 v ]
          in
          (agreed (List.map fst found), [ ("not_squared", agreed (List.map snd found)) ])
      | _ -> failwith "four fields were expected")
  | "variance_from_moments" -> (
      match
        fields 2
          (words "A random variable [`X`] has [`E(X) = " ^ an_integer ^ words "`] and [`E(X^{2}) = " ^ a_count
          ^ words "`]. Find [`\\mathrm{Var}(X)`].")
          p
      with
      | [ m; second ] ->
          let m = int_of_string m and second = int_of_string second in
          if m = 0 || m = 1 then failwith "the mean is its own square";
          let found =
            List.map
              (fun family ->
                let outcomes = with_moments family m (whole second) in
                (variance outcomes, second_moment outcomes -: mean outcomes))
              [ skewed; balanced ]
          in
          let spread = agreed (List.map fst found) in
          if spread.bottom <> 1 then failwith "the variance is not a whole number";
          note "variance_from_moments" [ m; spread.top ];
          (spread, [ ("mean_not_squared", agreed (List.map snd found)) ])
      | _ -> failwith "two numbers were expected")
  | ("binomial_mean" | "binomial_variance") as k -> (
      match fields 4 (trials ^ "\\(E(X)\\|" ^ words "\\mathrm{Var}(X)" ^ "\\)" ^ words "`].") p with
      | [ top; bottom; n; wanted ] ->
          let chance = probability top bottom and n = int_of_string n in
          note k [ n; chance.top; chance.bottom ];
          let outcomes = successes (n, chance.top, chance.bottom) in
          (* the table is that of n trials: from no success to n of them *)
          if List.map fst outcomes <> List.map whole (range 0 n) then
            failwith "the table of the successes is not from 0 to n";
          let found =
            match (k, wanted) with
            | "binomial_mean", "E(X)" -> mean outcomes
            | "binomial_variance", "\\mathrm{Var}(X)" ->
                let spread = variance outcomes in
                if sign spread <= 0 then failwith "a variance that is not above 0";
                spread
            | _ -> failwith "the question does not ask for what its kind says"
          in
          (found, [])
      | _ -> failwith "four fields were expected")
  | "uniform_probability" -> (
      match
        fields 4
          (words "A random variable [`X`] is uniformly distributed on the interval from [`" ^ an_integer
         ^ words "`] to [`" ^ an_integer ^ words "`]. Find [`P(" ^ an_integer ^ words " \\le X \\le " ^ an_integer
         ^ words ")`].")
          p
      with
      | [ lower; upper; from; upto ] ->
          let lower = int_of_string lower and upper = int_of_string upper in
          let from = int_of_string from and upto = int_of_string upto in
          let share = share_of_interval ~lower ~upper ~from ~upto in
          if share = one then failwith "the part asked for is the whole interval";
          if sign share <= 0 then failwith "the part asked for has no probability";
          note "uniform_probability, lower end" [ lower ];
          note "uniform_probability, lengths" [ from - lower; upto - from; upper - upto ];
          (share, [])
      | _ -> failwith "four numbers were expected")
  | "geometric_mean" -> (
      match
        fields 2
          (experiment
          ^ words "It is tried until it succeeds for the first time. "
          ^ words "Find the expected number of attempts, the successful one included.")
          p
      with
      | [ top; bottom ] ->
          let chance = probability top bottom in
          note "geometric_mean" [ chance.top; chance.bottom ];
          (attempts_expected chance, [])
      | _ -> failwith "a probability was expected")
  | "independent_combination" -> (
      match
        fields 5
          (words "The random variables [`X`] and [`Y`] are independent, with [`\\mathrm{Var}(X) = " ^ a_count
         ^ words "`] and [`\\mathrm{Var}(Y) = " ^ a_count ^ words "`]. Find [`\\mathrm{Var}(" ^ a_factor
         ^ "X \\([+-]\\) " ^ a_factor ^ words "Y)`].")
          p
      with
      | [ vx; vy; a; operation; b ] ->
          let vx = int_of_string vx and vy = int_of_string vy in
          let a = factor a and b = factor b and difference = operation = "-" in
          if a < 1 || b < 1 then failwith "a factor that is not above 0";
          if a = 1 && b = 1 then failwith "both factors are 1, and no square matters";
          note "independent_combination, variances" [ vx; vy ];
          note "independent_combination, factors" [ a; b; (if difference then 1 else 0) ];
          let found =
            List.map
              (fun (xs, ys) ->
                let xs = having "variance of X" (whole vx) variance xs
                and ys = having "variance of Y" (whole vy) variance ys in
                let combined (x, y) =
                  let ax = whole a *: x and by = whole b *: y in
                  if difference then ax -: by else ax +: by
                in
                ( variance (image combined (independent xs ys)),
                  (* each variance times its factor as it stands, and added *)
                  (whole a *: variance xs) +: (whole b *: variance ys),
                  (* the variance of aX less that of bY *)
                  variance (image (fun x -> whole a *: x) xs) -: variance (image (fun y -> whole b *: y) ys) ))
              [ (skewed 1 vx, balanced (-2) vy); (balanced 3 vx, skewed 0 vy) ]
          in
          ( agreed (List.map (fun (right, _, _) -> right) found),
            ("not_squared", agreed (List.map (fun (_, flat, _) -> flat) found))
            ::
            (if difference then [ ("variances_subtracted", agreed (List.map (fun (_, _, less) -> less) found)) ] else []) )
      | _ -> failwith "five fields were expected")
  | "geometric_first" -> (
      match
        fields 3
          (experiment ^ words "Find the probability that it succeeds for the first time at attempt [`" ^ a_count
         ^ words "`].")
          p
      with
      | [ top; bottom; attempt ] ->
          let chance = probability top bottom and attempt = int_of_string attempt in
          note "geometric_first" [ chance.top; chance.bottom; attempt ];
          let found = first_success_at (chance.top, chance.bottom, attempt) in
          if sign found <= 0 || not (less found one) then failwith "a probability that is not strictly between 0 and 1";
          (found, [])
      | _ -> failwith "a probability and an attempt were expected")
  | "density_constant" -> (
      match
        fields 2
          (words "The function [`f(x) = c \\, " ^ a_power ^ words "`] for [`0 \\le x \\le " ^ a_count
          ^ words "`], and [`f(x) = 0`] elsewhere, is the probability density of a random variable. Find the constant [`c`]."
          )
          p
      with
      | [ power; upper ] ->
          let n = degree power and b = int_of_string upper in
          note "density_constant" [ n; b ];
          let c = one /: integral (monomial one n) 0 b in
          (* with this constant it is a density *)
          ignore (density (c, n, b));
          (c, [])
      | _ -> failwith "a power and an upper end were expected")
  | "density_probability" -> (
      match fields 6 (density_given ^ "P(X \\(" ^ words "\\le" ^ "\\|>\\) " ^ a_count ^ words ")`].") p with
      | [ top; bottom; power; upper; side; m ] ->
          let c, n, b = printed_density top bottom power upper and m = int_of_string m in
          if m >= b then failwith "the number asked about is not strictly inside the interval";
          let above = side = ">" in
          note "density_probability" [ n; b; m; (if above then 1 else 0) ];
          let f = density (c, n, b) in
          let found = if above then integral f m b else integral f 0 m in
          if sign found <= 0 || not (less found one) then failwith "a probability that is not strictly between 0 and 1";
          (found, [])
      | _ -> failwith "six fields were expected")
  | ("density_mean" | "density_variance") as k -> (
      match fields 5 (density_given ^ "\\(E(X)\\|" ^ words "\\mathrm{Var}(X)" ^ "\\)" ^ words "`].") p with
      | [ top; bottom; power; upper; wanted ] -> (
          let c, n, b = printed_density top bottom power upper in
          note k [ n; b ];
          let centre, second, spread = density_moments (c, n, b) in
          match (k, wanted) with
          | "density_mean", "E(X)" ->
              if sign centre <= 0 || not (less centre (whole b)) then failwith "a mean outside the interval";
              (centre, [])
          | "density_variance", "\\mathrm{Var}(X)" ->
              if sign spread <= 0 then failwith "a variance that is not above 0";
              (spread, [ ("mean_not_squared", second -: centre) ])
          | _ -> failwith "the question does not ask for what its kind says")
      | _ -> failwith "five fields were expected")
  | "covariance" -> (
      match
        fields 8
          (words "The random variables [`X`] and [`Y`] each take the values [`0`] and [`1`], with [`P(X = 0, Y = 0) = "
         ^ a_fraction ^ words "`], [`P(X = 0, Y = 1) = " ^ a_fraction ^ words "`], [`P(X = 1, Y = 0) = " ^ a_fraction
         ^ words "`] and [`P(X = 1, Y = 1) = " ^ a_fraction
         ^ words "`]. Find the covariance [`\\mathrm{Cov}(X, Y) = E(XY) - E(X) E(Y)`].")
          p
      with
      | [ t1; b1; t2; b2; t3; b3; t4; b4 ] ->
          let p00 = probability t1 b1 and p01 = probability t2 b2 in
          let p10 = probability t3 b3 and p11 = probability t4 b4 in
          let outcomes = table [ ((0, 0), p00); ((0, 1), p01); ((1, 0), p10); ((1, 1), p11) ] in
          (* the four probabilities as whole numbers in lowest terms *)
          let shared = List.fold_left (fun l chance -> l / gcd l chance.bottom * chance.bottom) 1 [ p00; p01; p10; p11 ] in
          note "covariance" (List.map (fun chance -> chance.top * (shared / chance.bottom)) [ p00; p01; p10; p11 ]);
          let x_mean = expectation (fun (x, _) -> whole x) outcomes
          and y_mean = expectation (fun (_, y) -> whole y) outcomes in
          (expectation (fun (x, y) -> (whole x -: x_mean) *: (whole y -: y_mean)) outcomes, [])
      | _ -> failwith "four probabilities were expected")
  | k -> failwith ("unknown kind " ^ k)

(* How many questions are made at each budget. *)
let questions_at _cost = 30000

let () =
  let base = load_file "random_variables.rhm" in
  let prices =
    [ ("linear_mean", 1); ("binomial_mean", 1); ("uniform_probability", 1); ("geometric_mean", 1);
      ("linear_variance", 2); ("variance_from_moments", 2); ("binomial_variance", 2); ("independent_combination", 2);
      ("geometric_first", 2); ("density_constant", 3); ("density_probability", 3); ("density_mean", 3);
      ("density_variance", 3); ("covariance", 3) ]
  in
  (* how each mistake is described *)
  let described =
    [ ("not_squared", "multiplies a variance by the factor in front of the variable where the square of the factor belongs");
      ("variances_subtracted", "subtracts the variances of a difference of independent variables where they are added");
      ("mean_not_squared", "takes the mean off E(X^2) where the square of the mean belongs") ]
  in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 8 in
  let times_seen k = Option.value (Hashtbl.find_opt seen k) ~default:0 in
  (* a budget below the lowest or above the highest is refused *)
  List.iter
    (fun cost ->
      match Rhema_check.with_initial base "cost" cost with
      | Error _ -> ()
      | Ok spec -> (
          Random.init 1;
          match Rhema_engine.generate spec with
          | exception Rhema_engine.Generation_error _ -> ()
          | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)))
    [ -1; 0; 4; 5; 6; 9 ];
  (* left alone, the budget is 2 *)
  for seed = 0 to 199 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "no budget set, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 then
          fail ("with no budget set, a question that does not cost 2: " ^ kind q)
  done;
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at cost - 1 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k (times_seen k + 1);
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          match (number q.Rhema_engine.answer, q.Rhema_engine.answers) with
          | None, _ | _, ([] | _ :: _ :: _) -> fail (Printf.sprintf "%s: one number was expected as the answer of %S" k p)
          | Some got, [ _ ] -> (
              if number (Rhema_engine.attribute q.Rhema_engine.tree "answer_value") <> Some got then
                fail (Printf.sprintf "%s: the answer is not the answer_value of the question, for %S" k p);
              match expected q with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | want, slips ->
                  if got <> want then
                    fail (Printf.sprintf "%s: answer %s, recomputed %s, for %S" k (show got) (show want) p);
                  (* a question in which the mistake comes to the right number
                     is not to be asked: wrong working would be marked right *)
                  List.iter
                    (fun (name, slip) ->
                      if slip = want then
                        fail (Printf.sprintf "%s: %s gives the right answer %s, for %S" k name (show want) p))
                    slips;
                  let listed = q.Rhema_engine.mistakes in
                  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
                  if names <> List.map fst slips then
                    fail
                      (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k (String.concat ", " names)
                         (String.concat ", " (List.map fst slips))
                         p);
                  List.iter
                    (fun (m : Rhema_engine.mistaken) ->
                      Hashtbl.replace made (m.mistake, k) ();
                      (* each mistake is described in its own words *)
                      (match List.assoc_opt m.mistake described with
                      | Some text ->
                          if m.description <> text then fail (Printf.sprintf "%s is described as %S" m.mistake m.description)
                      | None -> fail ("an unknown mistake is listed: " ^ m.mistake));
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match number value with
                          | Some wrong ->
                              if wrong <> slip then
                                fail
                                  (Printf.sprintf "%s: %s gives %s, recomputed %s, for %S" k m.mistake (show wrong)
                                     (show slip) p);
                              if wrong = got then
                                fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p)
                          | None -> fail (Printf.sprintf "%s: %s does not give a number, for %S" k m.mistake p))
                      | _, None -> ()
                      | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                    listed))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k _ -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  List.iter
    (fun (mistake, k) ->
      if not (Hashtbl.mem made (mistake, k)) then fail (Printf.sprintf "%s never listed on %s" mistake k))
    [ ("not_squared", "linear_variance"); ("not_squared", "independent_combination");
      ("variances_subtracted", "independent_combination"); ("mean_not_squared", "variance_from_moments");
      ("mean_not_squared", "density_variance") ];
  (* every choice the grammar offers came up, and nothing else *)
  let print numbers = "(" ^ String.concat ", " (List.map string_of_int numbers) ^ ")" in
  List.iter
    (fun (label, choices) ->
      List.iter
        (fun numbers -> if not (Hashtbl.mem asked (label, numbers)) then fail (label ^ ": never asked with " ^ print numbers))
        choices)
    offered;
  Hashtbl.iter
    (fun (label, numbers) () ->
      match List.assoc_opt label offered with
      | Some choices -> if not (List.mem numbers choices) then fail (label ^ ": asked with " ^ print numbers)
      | None -> fail ("nothing is known of what is offered for " ^ label))
    asked;
  if !failures = 0 then print_endline "Rhema random_variables tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d random_variables test(s) failed." !failures);
    exit 1
  end
