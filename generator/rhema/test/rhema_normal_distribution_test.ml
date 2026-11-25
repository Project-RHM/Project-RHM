(* Independent checks for normal_distribution.rhm. Every question is matched
   against the whole sentence of its form, the numbers are read back from it,
   and every answer is found again in two ways of this file's own, never by
   the closed formula the grammar uses:

   - numerically: the density of the normal distribution the question states
     is integrated by Simpson's rule between the limits the question states
     (a tail is taken twelve standard deviations out), which gives the true
     probability;
   - exactly: the distribution function F of the stated distribution is
     built on the values of Phi that the question prints, read as the
     decimals they are: F(x) is Phi(z) for z = (x - mean) / deviation above
     0, 1 - Phi(-z) for z below 0 and 1/2 at the mean, and a probability is
     a difference of two values of F, or 1 less one. A value of Phi that is
     needed and is not printed is an error, and so is one that is printed
     and that nothing needs.

   The engine's answer must be the exact one, and the exact one must be
   within the rounding of the printed values (half a unit of the fourth
   place for each time a printed value is used) of the true one. Every
   printed Phi(z) must itself be the true value, integrated here, rounded to
   four places.

   z_score           by the definition, with exact fractions: the value less
                     the mean, over the standard deviation.
   above             1 - F(x); numerically the area above x.
   within, between, across
                     F(b) - F(a); numerically the area from a to b. The two
                     values are checked to lie as the form says: as far from
                     the mean on either side, both on one side, or one on
                     each side at different distances. Where two values of
                     Phi are printed, the first must be the one of the nearer
                     value (between) or of the value below the mean (across).
   percentile_above, percentile_below
                     by a search: F is increasing, so the whole values are
                     halved until the one is found whose true distribution
                     function, integrated here, rounds to the printed share;
                     its neighbours must not fit. As a second opinion F built
                     on the printed Phi must give exactly the share there.
   sample_mean       the sample size is checked to be a square; the variance
                     of the mean is the sum of the n variances of the values
                     over n, each (sigma / n)^2, and its exact square root is
                     the standard deviation of the mean; then 1 - F(x) for
                     the distribution of the mean, and numerically the area
                     above x under its density.
   difference        Y - X has the mean of Y less the mean of X and the
                     variance that is the sum of the two variances, whose
                     exact square root must be whole; the answer is 1 - F(0)
                     for that distribution. Numerically, without that rule:
                     the density of X times the area of Y above x, integrated
                     over x (worked out once for each difference of the means
                     and pair of deviations).

   The mistakes are found again from what each says the student does.
   complement_forgotten gives F at the value, the probability below it; it
   is a mistake of above and of difference. one_side_only gives the area
   between the mean and the upper of the two values, F(b) - 1/2; it is a
   mistake of within (where the lower side must come to the same) and of
   across. sign_lost gives the value mirrored in the mean; it shows only
   where the value lies below the mean, in percentile_below, and
   percentile_above lists none. not_scaled keeps the standard deviation of
   one value for the mean of the sample; the Phi it needs must be the other
   value printed in the question. z_score and between list none. A question
   must list exactly the mistakes of its form, in the order they are
   declared, with these values, each of them more than 1% away from the
   right answer, so that a marker with a tolerance of one part in a thousand
   cannot take it for the answer; each is described in the words it was
   declared with.

   Every kind must come up at its price and at no other, the budget must be
   spent, a budget outside 1 to 3 must give no question, a budget left alone
   is 2, and every answer is a number in one blank. The numbers each form is
   asked with are pinned: every choice the grammar offers must come up, and
   nothing else, by pairs and triples where a form has more numbers than its
   questions can cover together. What the header promises is checked as
   well: the values of z are 0.5, 1, 1.5, 2 and 2.5, written so; the
   standard deviation is even and every value of the variable is whole and
   above 0 (every mean, limit and value printed, and the answer of a
   percentile: the means start at 50); a
   probability is a decimal with four places, strictly between 0 and 1; a z
   score is not 0 and at most 4 either way; the pairs of a sample mean are
   (2, 1), (2, 2), (3, 1.5), (4, 2) and (5, 2.5); the deviations of a
   difference are 6 and 8 times a whole number, in either order, and X has
   the larger mean. The weights of the forms are not pinned. *)

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

let range first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)

(* ---- Fractions ---- *)

(* Fractions on OCaml integers, in lowest terms with a positive denominator,
   so that two equal fractions are equal as records. Every sum and product
   is checked: a number that does not fit is an error, never a wrong
   number. *)
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
  if divisor = 0 then { top = 0; bottom = 1 } else { top = top / divisor; bottom = bottom / divisor }

let whole n = { top = n; bottom = 1 }
let zero = whole 0
let one = whole 1
let half = fraction 1 2

let ( +: ) a b =
  let shared = gcd a.bottom b.bottom in
  fraction
    (plus (times a.top (b.bottom / shared)) (times b.top (a.bottom / shared)))
    (times a.bottom (b.bottom / shared))

let ( *: ) a b =
  let left = gcd a.top b.bottom and right = gcd b.top a.bottom in
  let left = max left 1 and right = max right 1 in
  fraction (times (a.top / left) (b.top / right)) (times (a.bottom / right) (b.bottom / left))

let ( -: ) a b = a +: { b with top = -b.top }
let ( /: ) a b = if b.top = 0 then failwith "division by zero" else a *: fraction b.bottom b.top
let square a = a *: a
let absolute a = { a with top = abs a.top }
let less a b = (a -: b).top < 0
let sum fractions = List.fold_left ( +: ) zero fractions
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom
let to_float a = float a.top /. float a.bottom

let number = function
  | Rhema_engine.Num n -> Some (fraction n.Rhema_number.numerator n.Rhema_number.denominator)
  | _ -> None

(* The whole number whose square is n, found by halving an interval: n must
   be a square. *)
let root_of_square n =
  if n < 0 then failwith "the square root of a negative number";
  let rec search low high =
    (* low^2 <= n < high^2 *)
    if high - low <= 1 then low
    else
      let middle = low + ((high - low) / 2) in
      if times middle middle <= n then search middle high else search low middle
  in
  let r = search 0 (min (n + 1) 3037000499) in
  if r * r <> n then failwith (Printf.sprintf "%d is not a square" n);
  r

(* The square root of a fraction that is the square of a fraction: in lowest
   terms its top and its bottom are both squares. *)
let exact_root a =
  if a.top < 0 then failwith "the square root of a negative number";
  fraction (root_of_square a.top) (root_of_square a.bottom)

(* A decimal such as 0.9332, or a whole number such as 2, as the fraction it
   is. *)
let decimal written =
  match String.split_on_char '.' written with
  | [ units ] -> whole (int_of_string units)
  | [ units; places ] ->
      let scale = int_of_string ("1" ^ String.make (String.length places) '0') in
      fraction ((int_of_string units * scale) + int_of_string places) scale
  | _ -> failwith ("not a decimal: " ^ written)

(* ---- The normal distribution, numerically ---- *)

let pi = 4. *. atan 1.

(* The density of the normal distribution with this mean and standard
   deviation. *)
let density mean deviation x =
  let z = (x -. mean) /. deviation in
  exp (-.(z *. z) /. 2.) /. (deviation *. sqrt (2. *. pi))

(* Simpson's rule, with an even number of steps. *)
let integral f a b steps =
  let h = (b -. a) /. float steps in
  let total = ref (f a +. f b) in
  for i = 1 to steps - 1 do
    total := !total +. ((if i mod 2 = 1 then 4. else 2.) *. f (a +. (float i *. h)))
  done;
  !total *. h /. 3.

(* A tail is cut off twelve standard deviations from the mean: less than
   1e-32 lies beyond. *)
let far = 12.

let area mean deviation a b = integral (density mean deviation) a b 400
let area_above mean deviation x = integral (density mean deviation) x (mean +. (far *. deviation)) 800
let area_below mean deviation x = integral (density mean deviation) (mean -. (far *. deviation)) x 800

(* The standard normal distribution function, each value worked out once.
   Phi(2) is 0.97724987, close to the middle of two decimals with four
   places, so the steps are fine. *)
let true_phi =
  let known = Hashtbl.create 8 in
  fun (z : fraction) ->
    match Hashtbl.find_opt known z with
    | Some value -> value
    | None ->
        let value = integral (density 0. 1.) (-.far) (to_float z) 8000 in
        Hashtbl.replace known z value;
        value

(* Half a unit of the fourth decimal place. *)
let rounding = 0.00005

(* P(Y > X) for independent normal X and Y, as the integral over x of the
   density of X times the area of Y above x. It hangs on the means only by
   their difference, so X is given mean 0, and each case is worked out
   once. *)
let chance_y_above_x =
  let known = Hashtbl.create 64 in
  fun mean_y_less_mean_x deviation_x deviation_y ->
    let key = (mean_y_less_mean_x, deviation_x, deviation_y) in
    match Hashtbl.find_opt known key with
    | Some value -> value
    | None ->
        let mean_y = float mean_y_less_mean_x and sx = float deviation_x and sy = float deviation_y in
        let top = mean_y +. (far *. sy) in
        let y_above x = if x >= top then 0. else integral (density mean_y sy) x top 800 in
        let value = integral (fun x -> density 0. sx x *. y_above x) (-.far *. sx) (far *. sx) 400 in
        Hashtbl.replace known key value;
        value

(* The whole value with this share of the distribution below it: the
   distribution function is increasing, so the whole values within four
   standard deviations of the mean are halved until the least one is found
   whose distribution function is not below the share by more than the
   rounding. It must then round to the share, and no neighbour may. *)
let value_with_share mean deviation share =
  let below x = area_below (float mean) (float deviation) (float x) in
  let fits x = Float.abs (below x -. share) < rounding in
  let rec search low high =
    (* below low is too small, below high is large enough *)
    if high - low <= 1 then high
    else
      let middle = low + ((high - low) / 2) in
      if below middle > share -. rounding then search low middle else search middle high
  in
  let x = search (mean - (4 * deviation) - 1) (mean + (4 * deviation) + 1) in
  if not (fits x) then failwith "no whole value has that share of the distribution below it";
  if fits (x - 1) || fits (x + 1) then failwith "more than one whole value has that share below it";
  x

(* ---- The values of Phi a question prints ---- *)

(* One printed value: Phi(at) = phi, and how often the working here has
   used it. *)
type given = { at : fraction; phi : fraction; mutable uses : int }

(* z as the grammar writes it: a whole number, or a whole number and a
   half. *)
let written z =
  if z.bottom = 1 then string_of_int z.top
  else if z.bottom = 2 && z.top > 0 then Printf.sprintf "%d.5" (z.top / 2)
  else failwith ("z is not a whole number of halves: " ^ show z)

(* A printed value is read, and must be the true Phi(z) to four places. *)
let read_given z_text phi_text =
  let z = decimal z_text and value = decimal phi_text in
  if less z zero || z = zero then failwith "Phi is given at a z that is not above 0";
  if written z <> z_text then failwith ("z is written as " ^ z_text);
  if not (Float.abs (to_float value -. true_phi z) < rounding) then
    failwith (Printf.sprintf "Phi(%s) is given as %s, and is %.6f" z_text phi_text (true_phi z));
  { at = z; phi = value; uses = 0 }

let looked_up table z =
  match List.find_opt (fun g -> g.at = z) table with
  | Some g ->
      g.uses <- g.uses + 1;
      g.phi
  | None -> failwith (Printf.sprintf "Phi(%s) is needed and is not given" (show z))

(* The distribution function of the normal distribution with this mean and
   standard deviation, at x, on the printed values: by the symmetry of the
   density, 1/2 at the mean and 1 - Phi(-z) below it. *)
let below table mean deviation x =
  if not (less zero deviation) then failwith "a standard deviation that is not above 0";
  let z = (x -: mean) /: deviation in
  if z = zero then half else if less zero z then looked_up table z else one -: looked_up table (zero -: z)

(* The right working has been done on the printed values: it must have used
   exactly these of them, and its result must be within the rounding of the
   true probability, half a unit of the fourth place for each use. *)
let settle table used exact truth =
  if List.map (fun g -> g.uses > 0) table <> used then
    failwith "the working does not use the values of Phi that the question gives for it";
  let uses = List.fold_left (fun total g -> total + g.uses) 0 table in
  if not (Float.abs (to_float exact -. truth) <= (rounding *. float uses) +. 1e-9) then
    failwith (Printf.sprintf "the printed values give %s, and the true probability is %.6f" (show exact) truth)

(* After the mistakes too: nothing is printed that nothing needs. *)
let all_used table =
  if List.exists (fun g -> g.uses = 0) table then failwith "a value of Phi is given that nothing needs"

(* Twice z, which must be whole. *)
let doubled z =
  let twice = z *: whole 2 in
  if twice.bottom <> 1 then failwith ("z is not a whole number of halves: " ^ show z);
  twice.top

(* ---- Reading a question ---- *)

(* The numbers of a prompt: the pattern is the whole sentence, with a group
   wherever a number stands. *)
let words = Str.quote
let a_count = "\\(0\\|[1-9][0-9]*\\)"
let an_integer = "\\(0\\|-?[1-9][0-9]*\\)"
let a_z = "\\([0-9]+\\.?[0-9]*\\)"
let four_places = "\\(0\\.[0-9][0-9][0-9][0-9]\\)"

let text_fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* The parts the sentences share. *)
let one_variable =
  words "A random variable [`X`] is normally distributed with mean [`" ^ an_integer
  ^ words "`] and standard deviation [`" ^ a_count ^ words "`]. "

let phi_given = words "[`\\Phi(" ^ a_z ^ words ") = " ^ four_places ^ words "`]"
let closing = words " for the standard normal distribution function."
let between_two = words "Find [`P(" ^ an_integer ^ words " < X < " ^ an_integer ^ words ")`], using "

(* ---- What each form was asked with ---- *)

let asked : (string, int list) Hashtbl.t = Hashtbl.create 1024
let note label numbers = Hashtbl.add asked label numbers

(* Every choice the grammar offers, form by form: every tuple of numbers it
   may ask a form with, handed to a function one by one, and the views of
   those tuples (lists of positions) that must come up in full. A form with
   more numbers than its questions can cover together is pinned by pairs
   and triples. *)
let offered =
  let rec product lists keep emit =
    match lists with
    | [] -> if keep [] then emit []
    | first :: rest -> List.iter (fun v -> product rest (fun tail -> keep (v :: tail)) (fun tail -> emit (v :: tail))) first
  in
  let any _ = true in
  let means = List.map (fun a -> 5 * a) (range 10 40) in
  let deviations = List.map (fun h -> 2 * h) (range 1 8) in
  let halves = range 1 5 and either = [ 0; 1 ] in
  [ (* the mean, the deviation and the value less the mean: not 0, and at
       most four deviations *)
    ( "z_score",
      product
        [ means; deviations; List.filter (fun d -> d <> 0) (range (-20) 20) ]
        (function [ _; s; d ] -> abs d <= 4 * s | _ -> false),
      [ [ 0; 1 ]; [ 1; 2 ] ] );
    (* the mean, the deviation and twice z *)
    ("above", product [ means; deviations; halves ] any, [ [ 0; 1 ]; [ 1; 2 ]; [ 0; 2 ] ]);
    ("within", product [ means; deviations; halves ] any, [ [ 0; 1 ]; [ 1; 2 ]; [ 0; 2 ] ]);
    (* twice z of the nearer value and of the farther one, and the side:
       0 above the mean, 1 below *)
    ( "between",
      product [ means; deviations; halves; halves; either ] (function [ _; _; near; far; _ ] -> near < far | _ -> false),
      [ [ 1; 2; 3; 4 ]; [ 0; 1 ]; [ 0; 2; 3 ]; [ 0; 4 ] ] );
    (* twice z, and whether the share above 1/2 (0) or below it (1) is given *)
    ("percentile", product [ means; deviations; halves; either ] any, [ [ 1; 2; 3 ]; [ 0; 1 ]; [ 0; 2; 3 ] ]);
    (* twice z of the value below the mean and of the one above *)
    ( "across",
      product [ means; deviations; halves; halves ] (function [ _; _; low; high ] -> low <> high | _ -> false),
      [ [ 1; 2; 3 ]; [ 0; 1 ]; [ 0; 2 ]; [ 0; 3 ] ] );
    (* the mean, the root k of the sample size with twice z, and the unit u:
       the deviation is 2 k u *)
    ( "sample_mean",
      (fun emit ->
        product [ means; range 1 6 ] any (function
          | [ m; u ] -> List.iter (fun (k, twice_z) -> emit [ m; k; twice_z; u ]) [ (2, 2); (2, 4); (3, 3); (4, 4); (5, 5) ]
          | _ -> ())),
      [ [ 1; 2; 3 ]; [ 0; 1; 2 ]; [ 0; 3 ] ] );
    (* the mean of Y, twice z, the unit u and the order: 0 for deviations
       6 u and 8 u, 1 for 8 u and 6 u *)
    ("difference", product [ means; halves; range 1 3; either ] any, [ [ 1; 2; 3 ]; [ 0; 1 ]; [ 0; 2; 3 ] ]) ]

(* ---- The answer of each form, found again ---- *)

let positive what n = if n <= 0 then failwith (what ^ " is not above 0")

(* Every value of the variable that a question prints, or asks for, is
   above 0. *)
let printed values = List.iter (positive "a value of the variable") values

(* The right answer of a question and the answers of each mistake its form
   is open to, all found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let int = int_of_string in
  match kind q with
  | "z_score" -> (
      match text_fields 3 (one_variable ^ words "Find the [`z`] score of the value [`" ^ an_integer ^ words "`].") p with
      | [ mean; deviation; value ] ->
          let mean = int mean and deviation = int deviation and value = int value in
          positive "the standard deviation" deviation;
          printed [ mean; value ];
          note "z_score" [ mean; deviation; value - mean ];
          let z = whole (value - mean) /: whole deviation in
          if z = zero then failwith "the value is the mean";
          if less (whole 4) (absolute z) then failwith "the value is more than four standard deviations from the mean";
          (* the definition, the other way round *)
          if whole mean +: (z *: whole deviation) <> whole value then failwith "z standard deviations from the mean is not the value";
          (z, [])
      | _ -> failwith "three numbers were expected")
  | "above" -> (
      match text_fields 5 (one_variable ^ words "Find [`P(X > " ^ an_integer ^ words ")`], using " ^ phi_given ^ closing) p with
      | [ mean; deviation; value; z; phi ] ->
          let mean = int mean and deviation = int deviation and value = int value in
          positive "the standard deviation" deviation;
          printed [ mean; value ];
          if value <= mean then failwith "the value is not above the mean";
          let table = [ read_given z phi ] in
          let f x = below table (whole mean) (whole deviation) (whole x) in
          let right = one -: f value in
          settle table [ true ] right (area_above (float mean) (float deviation) (float value));
          note "above" [ mean; deviation; doubled (List.hd table).at ];
          (right, [ ("complement_forgotten", f value) ])
      | _ -> failwith "five numbers were expected")
  | "within" -> (
      match text_fields 6 (one_variable ^ between_two ^ phi_given ^ closing) p with
      | [ mean; deviation; low; high; z; phi ] ->
          let mean = int mean and deviation = int deviation and low = int low and high = int high in
          positive "the standard deviation" deviation;
          printed [ mean; low; high ];
          if not (low < mean && mean - low = high - mean) then failwith "the two values are not as far from the mean on either side";
          let table = [ read_given z phi ] in
          let f x = below table (whole mean) (whole deviation) (whole x) in
          let right = f high -: f low in
          settle table [ true ] right (area (float mean) (float deviation) (float low) (float high));
          note "within" [ mean; deviation; doubled (List.hd table).at ];
          let upper_side = f high -: f mean and lower_side = f mean -: f low in
          if upper_side <> lower_side then failwith "the two sides of the mean do not hold the same";
          (right, [ ("one_side_only", upper_side) ])
      | _ -> failwith "six numbers were expected")
  | ("between" | "across") as k -> (
      match text_fields 8 (one_variable ^ between_two ^ phi_given ^ words " and " ^ phi_given ^ closing) p with
      | [ mean; deviation; low; high; z1; phi1; z2; phi2 ] ->
          let mean = int mean and deviation = int deviation and low = int low and high = int high in
          positive "the standard deviation" deviation;
          printed [ mean; low; high ];
          if low >= high then failwith "the two values are not in order";
          let table = [ read_given z1 phi1; read_given z2 phi2 ] in
          let first = (List.nth table 0).at and second = (List.nth table 1).at in
          if first = second then failwith "the same value of Phi is given twice";
          let f x = below table (whole mean) (whole deviation) (whole x) in
          let right = f high -: f low in
          settle table [ true; true ] right (area (float mean) (float deviation) (float low) (float high));
          let distance x = fraction (abs (x - mean)) deviation in
          if k = "between" then begin
            if not (low > mean || high < mean) then failwith "the two values are not on one side of the mean";
            let side = if low > mean then 0 else 1 in
            let near = if side = 0 then low else high and far = if side = 0 then high else low in
            if first <> distance near || second <> distance far then failwith "Phi is not given for the nearer value first";
            note "between" [ mean; deviation; doubled first; doubled second; side ];
            (right, [])
          end
          else begin
            if not (low < mean && mean < high) then failwith "the two values are not on opposite sides of the mean";
            if distance low = distance high then failwith "the two values are as far from the mean";
            if first <> distance low || second <> distance high then failwith "Phi is not given for the lower value first";
            note "across" [ mean; deviation; doubled first; doubled second ];
            (right, [ ("one_side_only", f high -: f mean) ])
          end
      | _ -> failwith "eight numbers were expected")
  | ("percentile_above" | "percentile_below") as k -> (
      match
        text_fields 5
          (one_variable ^ words "Find the value [`x`] with [`P(X < x) = " ^ four_places ^ words "`], using " ^ phi_given ^ closing)
          p
      with
      | [ mean; deviation; share; z; phi ] ->
          let mean = int mean and deviation = int deviation in
          positive "the standard deviation" deviation;
          let table = [ read_given z phi ] in
          let x = value_with_share mean deviation (to_float (decimal share)) in
          printed [ mean; x ];
          (* on the printed value, the share is exactly the one asked for *)
          if below table (whole mean) (whole deviation) (whole x) <> decimal share then
            failwith "the printed value of Phi does not give the share at that value";
          all_used table;
          if k = (if x < mean then "percentile_above" else "percentile_below") then failwith "the value is on the other side of the mean";
          note "percentile" [ mean; deviation; doubled (List.hd table).at; (if x < mean then 1 else 0) ];
          (* a value below the mean, placed as far above it *)
          (whole x, if x < mean then [ ("sign_lost", whole (mean + (mean - x))) ] else [])
      | _ -> failwith "five numbers were expected")
  | "sample_mean" -> (
      match
        text_fields 8
          (words "A population is normally distributed with mean [`" ^ an_integer ^ words "`] and standard deviation [`"
         ^ a_count ^ words "`]. A sample of [`" ^ a_count
         ^ words "`] values is taken. Find the probability that the mean of the sample is above [`" ^ an_integer
         ^ words "`], using what is needed of " ^ phi_given ^ words " and " ^ phi_given ^ closing)
          p
      with
      | [ mean; deviation; size; value; z1; phi1; z2; phi2 ] ->
          let mean = int mean and deviation = int deviation and size = int size and value = int value in
          positive "the standard deviation" deviation;
          positive "the sample size" size;
          printed [ mean; value ];
          let k = root_of_square size in
          let table = [ read_given z1 phi1; read_given z2 phi2 ] in
          if (List.nth table 0).at = (List.nth table 1).at then failwith "the same value of Phi is given twice";
          (* the mean is the sum of n values, each over n: its variance is
             the sum of theirs *)
          let of_mean = exact_root (sum (List.map (fun _ -> square (fraction deviation size)) (range 1 size))) in
          let right = one -: below table (whole mean) of_mean (whole value) in
          (* the right working needs the second value printed, not the first *)
          settle table [ false; true ] right (area_above (float mean) (to_float of_mean) (float value));
          let slip = one -: below table (whole mean) (whole deviation) (whole value) in
          all_used table;
          if deviation mod (2 * k) <> 0 then failwith "the standard deviation is not a whole number of times twice the root of the sample size";
          note "sample_mean" [ mean; k; doubled (List.nth table 1).at; deviation / (2 * k) ];
          (right, [ ("not_scaled", slip) ])
      | _ -> failwith "eight numbers were expected")
  | "difference" -> (
      match
        text_fields 6
          (words "The random variables [`X`] and [`Y`] are independent and normally distributed: [`X`] with mean [`"
         ^ an_integer ^ words "`] and standard deviation [`" ^ a_count ^ words "`], [`Y`] with mean [`" ^ an_integer
         ^ words "`] and standard deviation [`" ^ a_count ^ words "`]. Find [`P(Y > X)`], using " ^ phi_given ^ closing)
          p
      with
      | [ mean_x; deviation_x; mean_y; deviation_y; z; phi ] ->
          let mean_x = int mean_x and deviation_x = int deviation_x and mean_y = int mean_y and deviation_y = int deviation_y in
          positive "a standard deviation" deviation_x;
          positive "a standard deviation" deviation_y;
          printed [ mean_x; mean_y ];
          if mean_x <= mean_y then failwith "X has not the larger mean";
          let table = [ read_given z phi ] in
          (* Y - X, which is above 0 when Y is above X *)
          let centre = whole (mean_y - mean_x) in
          let spread = exact_root (square (whole deviation_x) +: square (whole deviation_y)) in
          if spread.bottom <> 1 then failwith "the standard deviation of the difference is not whole";
          let f = below table centre spread zero in
          let right = one -: f in
          settle table [ true ] right (chance_y_above_x (mean_y - mean_x) deviation_x deviation_y);
          let u = min deviation_x deviation_y / 6 in
          if (min deviation_x deviation_y, max deviation_x deviation_y) <> (6 * u, 8 * u) then
            failwith "the standard deviations are not 6 and 8 times a whole number";
          note "difference" [ mean_y; doubled (List.hd table).at; u; (if deviation_x < deviation_y then 0 else 1) ];
          (right, [ ("complement_forgotten", below table centre spread zero) ])
      | _ -> failwith "six numbers were expected")
  | k -> failwith ("unknown kind " ^ k)

(* How many questions are made at each budget. *)
let questions_at _cost = 30000

let () =
  let base = load_file "normal_distribution.rhm" in
  let prices =
    [ ("z_score", 1); ("above", 1); ("within", 2); ("between", 2); ("percentile_above", 2); ("percentile_below", 2);
      ("across", 3); ("sample_mean", 3); ("difference", 3) ]
  in
  (* the forms whose answer is not a probability *)
  let not_a_probability = [ "z_score"; "percentile_above"; "percentile_below" ] in
  (* how each mistake is described *)
  let described =
    [ ("complement_forgotten", "gives Phi(z), the probability below the value, where the probability above it is asked for");
      ("one_side_only", "gives the area between the mean and one of the two values, where the area between both is asked for");
      ("sign_lost", "places a value that lies below the mean as far above it");
      ("not_scaled", "uses the standard deviation of one value for the mean of a sample, where it is divided by sqrt(n)") ]
  in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 8 in
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
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
          match List.map number q.Rhema_engine.answers with
          | [ Some got ] when number q.Rhema_engine.answer = Some got -> (
              (* a probability is a decimal with four places, and neither 0
                 nor 1 *)
              if not (List.mem k not_a_probability) then begin
                if not (less zero got && less got one) then fail (Printf.sprintf "%s: the probability %s, for %S" k (show got) p);
                if 10000 mod got.bottom <> 0 then fail (Printf.sprintf "%s: %s is not a decimal with four places, for %S" k (show got) p)
              end;
              match expected q with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | want, slips ->
                  if got <> want then fail (Printf.sprintf "%s: answer %s, recomputed %s, for %S" k (show got) (show want) p);
                  List.iter
                    (fun (name, slip) ->
                      (* a question in which the mistake comes to the right
                         answer is not to be asked, nor one that a marker
                         with a tolerance of one part in a thousand could
                         take for it: the mistake is more than 1% away *)
                      if slip = want then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k name p)
                      else if not (less (absolute want) (whole 100 *: absolute (slip -: want))) then
                        fail
                          (Printf.sprintf "%s: %s gives %s, within 1%% of the answer %s, for %S" k name (show slip) (show want) p))
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
                                fail (Printf.sprintf "%s: %s gives %s, recomputed %s, for %S" k m.mistake (show wrong) (show slip) p);
                              if wrong = got then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p)
                          | None -> fail (Printf.sprintf "%s: %s does not give a number, for %S" k m.mistake p))
                      | Some _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p)
                      | None, Some _ -> fail (Printf.sprintf "%s: %s gives no answer, for %S" k m.mistake p)
                      | _, None -> ())
                    listed)
          | _ -> fail (Printf.sprintf "%s: one number was expected as the answer of %S" k p))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k _ -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  List.iter
    (fun (mistake, k) ->
      if not (Hashtbl.mem made (mistake, k)) then fail (Printf.sprintf "%s never listed on %s" mistake k))
    [ ("complement_forgotten", "above"); ("one_side_only", "within"); ("sign_lost", "percentile_below");
      ("one_side_only", "across"); ("not_scaled", "sample_mean"); ("complement_forgotten", "difference") ];
  (* every choice the grammar offers came up, and nothing else, in each view *)
  let print numbers = "(" ^ String.concat ", " (List.map string_of_int numbers) ^ ")" in
  let project view numbers = List.map (fun i -> List.nth numbers i) view in
  List.iter
    (fun (label, choices, views) ->
      let wanted = List.map (fun view -> (view, Hashtbl.create 64)) views in
      choices (fun numbers -> List.iter (fun (view, table) -> Hashtbl.replace table (project view numbers) ()) wanted);
      let found = Hashtbl.find_all asked label in
      List.iter
        (fun (view, table) ->
          let met = Hashtbl.create 64 in
          List.iter
            (fun numbers ->
              let part = project view numbers in
              if not (Hashtbl.mem met part) then begin
                Hashtbl.replace met part ();
                if not (Hashtbl.mem table part) then fail (Printf.sprintf "%s: asked with %s at %s" label (print part) (print view))
              end)
            found;
          Hashtbl.iter
            (fun part () ->
              if not (Hashtbl.mem met part) then fail (Printf.sprintf "%s: never asked with %s at %s" label (print part) (print view)))
            table)
        wanted)
    offered;
  Hashtbl.iter
    (fun label _ ->
      if not (List.exists (fun (l, _, _) -> l = label) offered) then fail ("nothing is known of what is offered for " ^ label))
    asked;
  if !failures = 0 then print_endline "Rhema normal_distribution tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d normal_distribution test(s) failed." !failures);
    exit 1
  end
