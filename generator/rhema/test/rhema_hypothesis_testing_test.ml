(* Independent checks for hypothesis_testing.rhm. Every question is matched
   against the whole sentence of its form, the numbers are read back from it,
   and every answer is found again from the definitions, with exact
   fractions, never by the closed formula the grammar uses:

   z_mean, t_mean    the sample size is checked to be a square and its root
                     is found by an integer square root of this file's own;
                     the standard error is the printed standard deviation
                     over that root, and the statistic is the sample mean less
                     the claimed mean, over the standard error.
   interval          the standard error as above; the 1.96 printed in the
                     question is read as the decimal it is, and the two ends
                     are the sample mean less and plus 1.96 standard errors.
                     As a second opinion, the z statistic of the sample mean
                     against each end, taken as a claimed mean, must be 1.96
                     and -1.96: the interval is the set of means not refused.
   proportion        the hypothesis p = p_0 is read from the question (the
                     printed fraction); the standard error is the exact
                     square root of p_0 (1 - p_0) / n, a fraction whose top
                     and bottom must both be squares; the statistic is the
                     proportion of heads less p_0, over it.
   die               the number of faces is read from the question ([`1`] to
                     [`6`]), the expected count of each is the number of
                     throws over the number of faces, and the statistic is
                     the sum of (observed - expected)^2 / expected over the
                     faces. The counts must add up to the throws.
   table             the expected count of each of the four cells is its row
                     total times its column total over the whole, and the
                     statistic is the sum over the cells; the shortcut
                     N (ad - bc)^2 / (the four totals multiplied) must agree,
                     as a second opinion.
   two_means         each standard error is a standard deviation over the
                     integer square root of its sample size; the standard
                     error of the difference is the exact square root of the
                     sum of their squares, and the statistic is the difference
                     of the sample means over it.
   degrees_t, degrees_fit, degrees_table
                     the values that are free to vary: the n deviations of a
                     sample from its mean, which add up to 0; the k counts of
                     the categories, which add up to the whole; the cells of
                     the table that are not fixed by the row and column
                     totals, found by going through the cells and leaving
                     out the last row and the last column.

   The mistakes are found again from what each says the student does.
   not_scaled divides the difference by the standard deviation itself, and
   in an interval puts 1.96 standard deviations either side; it is a mistake
   of z_mean, t_mean and interval. divided_by_observed divides every squared
   difference by its observed count; it is a mistake of die and table.
   standard_errors_added divides the difference of two means by the sum of
   the two standard errors. cells_minus_one counts the cells of the table
   less one; it is a mistake of degrees_table only, and a test with a t or
   a goodness of fit lists none, as the proportion does. A question must list
   exactly the mistakes of its form, in the order they are declared, with
   these values, each of them more than 1% away from the right answer in
   every blank, so that a marker with a tolerance of one part in a thousand
   cannot take it for the answer (and for the die and the table, whose
   mistakes are kept that far away, some come within 1.5%, on both sides of
   the answer); each is described in the words it was declared with.

   Every kind must come up at its price and at no other, the budget must be
   spent, a budget outside 1 to 3 must give no question, a budget left alone
   is 2, every answer is a number (whole or a fraction), the interval has
   two blanks and every other form one. The numbers each form is asked with
   are pinned: every choice the grammar offers must come up, and nothing
   else, by single numbers and pairs where a form has more numbers than its
   questions can cover together (the bound on a statistic is checked by the
   largest statistic seen, and the four cells of a table together by the
   half of the counts each lies in). What the header
   promises is checked as well: a sample size is a square, the two standard
   errors of a difference are whole and the standard error of the
   difference is whole, the two rows of a table are not in proportion, a
   count of heads is near half the tosses (steps of one, or of two from a
   sample of 100 or more), and the statistics reach but do not pass 4 (z for
   a mean, for two means) and 5 (t). The weights of the forms are not
   pinned. *)

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

(* A decimal such as 1.96, as the fraction it is. *)
let decimal written =
  match String.split_on_char '.' written with
  | [ units; places ] ->
      let scale = int_of_string ("1" ^ String.make (String.length places) '0') in
      fraction ((int_of_string units * scale) + int_of_string places) scale
  | _ -> failwith ("not a decimal: " ^ written)

(* ---- Reading a question ---- *)

(* The numbers of a prompt: the pattern is the whole sentence, with a group
   wherever a number stands. *)
let words = Str.quote
let a_count = "\\(0\\|[1-9][0-9]*\\)"
let an_integer = "\\(0\\|-?[1-9][0-9]*\\)"
let a_decimal = "\\([0-9]+\\.[0-9]+\\)"
let blank = words "[___]"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> int_of_string (Str.matched_group (n + 1) prompt))
  else failwith "the wording is not the expected one"

let text_fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* ---- What each form was asked with ---- *)

let asked : (string, int list) Hashtbl.t = Hashtbl.create 1024
let note label numbers = Hashtbl.add asked label numbers

(* The largest statistic seen for each form. *)
let largest : (string, fraction) Hashtbl.t = Hashtbl.create 8

let reach label statistic =
  let size = absolute statistic in
  match Hashtbl.find_opt largest label with
  | Some known when not (less known size) -> ()
  | _ -> Hashtbl.replace largest label size

(* The four counts of a table: from 5 to 40, the rows not in proportion,
   and the chi-square statistic with each squared difference divided by the
   observed count more than 1% away from the right one. The expected counts
   are row total times column total over the whole; this sorting is done in
   floating point, since the nearest table kept is 1.00003% away. *)
let tables emit =
  let values = range 5 40 in
  let far a b c d =
    let whole = float (a + b + c + d) in
    let cells = [ (a, a + b, a + c); (b, a + b, b + d); (c, c + d, a + c); (d, c + d, b + d) ] in
    let chi divide =
      List.fold_left
        (fun total (o, row, column) ->
          let e = float row *. float column /. whole in
          total +. ((float o -. e) ** 2. /. divide (float o) e))
        0. cells
    in
    let right = chi (fun _ e -> e) and slip = chi (fun o _ -> o) in
    Float.abs (slip -. right) > right /. 100.
  in
  List.iter
    (fun a ->
      List.iter
        (fun b ->
          List.iter
            (fun c -> List.iter (fun d -> if a * d <> b * c && far a b c d then emit [ a; b; c; d ]) values)
            values)
        values)
    values

(* 5 to 22 or 23 to 40 *)
let halves count = (count - 5) / 18

(* For each form, the smallest relative distance seen between a mistake and
   the right answer, and whether mistakes were seen below it and above it.
   The distances are kept in floating point: two of them, as fractions, can
   be too large to compare exactly. *)
let gaps : (string, float * bool * bool) Hashtbl.t = Hashtbl.create 8

let record_gap label wrong right =
  let relative = (float wrong.top /. float wrong.bottom -. (float right.top /. float right.bottom))
                 /. Float.abs (float right.top /. float right.bottom) in
  let size = Float.abs relative and below = less wrong right in
  match Hashtbl.find_opt gaps label with
  | None -> Hashtbl.replace gaps label (size, below, not below)
  | Some (least, seen_below, seen_above) ->
      Hashtbl.replace gaps label (Float.min size least, seen_below || below, seen_above || not below)

(* Every choice the grammar offers, form by form: every tuple of numbers it
   may ask a form with, handed to a function one by one, and the views of
   those tuples (lists of positions) that must come up in full. A form with
   more numbers than its questions can cover together is pinned by pairs or
   by single numbers. *)
let offered =
  let every values emit = List.iter (fun v -> emit [ v ]) values in
  let not_zero values = List.filter (fun value -> value <> 0) values in
  let fives = List.map (fun a -> 5 * a) (range 4 24) in
  (* a mean test: the deviation, the root of the sample size and the
     difference of the means, with the statistic kept within its bound *)
  let mean_test deviations roots bound emit =
    List.iter
      (fun s ->
        List.iter
          (fun k -> List.iter (fun d -> if abs (d * k) <= bound * s then emit [ s; k; d ]) (not_zero (range (-12) 12)))
          roots)
      deviations
  in
  (* each number of a mean test alone: the bound on the statistic is
     checked by the largest statistic seen *)
  let singles = [ [ 0 ]; [ 1 ]; [ 2 ] ] in
  [ ("z_mean, claimed mean", every fives, [ [ 0 ] ]);
    ("z_mean", mean_test (range 2 20) (range 3 10) 4, singles);
    ("t_mean, claimed mean", every fives, [ [ 0 ] ]);
    ("t_mean", mean_test (range 2 20) (range 2 8) 5, singles);
    ( "interval",
      (fun emit -> List.iter (fun s -> List.iter (fun k -> emit [ s; k ]) (range 3 10)) (range 2 20)),
      [ [ 0; 1 ] ] );
    ("interval, mean", every (range 11 129), [ [ 0 ] ]);
    (* the root of the number of tosses and the count of heads less half the
       tosses, rounded down: steps of one, or of two from 100 tosses *)
    ( "proportion",
      (fun emit ->
        List.iter
          (fun k -> List.iter (fun j -> emit [ k; j * if k * k >= 100 then 2 else 1 ]) (not_zero (range (-8) 8)))
          (range 4 20)),
      [ [ 0; 1 ] ] );
    ("die, expected count", every (range 10 30), [ [ 0 ] ]);
    (* the six counts less the expected count: five free, the sixth what
       makes them add up to 0, and not all of them 0. The rule that the
       mistake stays 1% away from the answer turns away some of them with
       some expected counts, but no count and no pair of these views: that
       was found once by going through every die. *)
    ( "die, deviations",
      (fun emit ->
        let values = range (-6) 6 in
        List.iter
          (fun d1 ->
            List.iter
              (fun d2 ->
                List.iter
                  (fun d3 ->
                    List.iter
                      (fun d4 ->
                        List.iter
                          (fun d5 ->
                            let d6 = -(d1 + d2 + d3 + d4 + d5) in
                            if abs d6 <= 8 && List.exists (fun d -> d <> 0) [ d1; d2; d3; d4; d5; d6 ] then
                              emit [ d1; d2; d3; d4; d5; d6 ])
                          values)
                      values)
                  values)
              values)
          values),
      [ [ 0 ]; [ 1 ]; [ 2 ]; [ 3 ]; [ 4 ]; [ 5 ]; [ 0; 1 ]; [ 1; 2 ]; [ 2; 3 ]; [ 3; 4 ] ] );
    ("table", tables, [ [ 0 ]; [ 1 ]; [ 2 ]; [ 3 ] ]);
    (* the four cells together, each by the half of the counts it lies in:
       no two cells are tied to each other *)
    ("table, cells by halves", (fun emit -> tables (fun cells -> emit (List.map halves cells))), [ [ 0; 1; 2; 3 ] ]);
    (* the two standard errors and the difference of the means, kept within
       4 standard errors of the difference *)
    ( "two_means",
      (fun emit ->
        List.iter
          (fun (u, v) ->
            let w = root_of_square ((u * u) + (v * v)) in
            List.iter (fun d -> if abs d <= 4 * w then emit [ u; v; d ]) (not_zero (range (-30) 30)))
          [ (3, 4); (4, 3); (6, 8); (8, 6); (5, 12); (12, 5) ]),
      [ [ 0; 1; 2 ] ] );
    ( "two_means, sample sizes",
      (fun emit -> List.iter (fun a -> List.iter (fun b -> emit [ a; b ]) (range 2 6)) (range 2 6)),
      [ [ 0; 1 ] ] );
    ("two_means, second mean", every fives, [ [ 0 ] ]);
    ("degrees_t", every (range 5 40), [ [ 0 ] ]);
    ("degrees_fit", every (range 4 10), [ [ 0 ] ]);
    ( "degrees_table",
      (fun emit -> List.iter (fun r -> List.iter (fun c -> emit [ r; c ]) (range 2 5)) (range 2 5)),
      [ [ 0; 1 ] ] ) ]

(* ---- The answer of each form, found again ---- *)

(* The standard error of a mean: the standard deviation over the square
   root of the sample size, which must be a square. *)
let standard_error deviation size = whole deviation /: whole (root_of_square size)

let positive what n = if n <= 0 then failwith (what ^ " is not above 0")

(* The right answers of a question (one per blank), and the answers of each
   mistake its form is open to, all found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "z_mean" -> (
      match
        fields 4
          (words "A population has standard deviation [`\\sigma = " ^ a_count ^ words "`]. To test [`H_0: \\mu = "
         ^ an_integer ^ words "`], a sample of [`" ^ a_count ^ words "`] values is taken, and its mean is [`"
         ^ an_integer ^ words "`]. Find the value of the [`z`] statistic. " ^ blank)
          p
      with
      | [ sigma; claimed; size; mean ] ->
          positive "the standard deviation" sigma;
          let se = standard_error sigma size in
          note "z_mean, claimed mean" [ claimed ];
          note "z_mean" [ sigma; root_of_square size; mean - claimed ];
          let difference = whole (mean - claimed) in
          let z = difference /: se in
          reach "z_mean" z;
          ([ z ], [ ("not_scaled", [ difference /: whole sigma ]) ])
      | _ -> failwith "four numbers were expected")
  | "t_mean" -> (
      match
        fields 4
          (words "To test [`H_0: \\mu = " ^ an_integer ^ words "`], a sample of [`" ^ a_count
         ^ words "`] values is taken. Its mean is [`" ^ an_integer ^ words "`] and its standard deviation is [`s = "
         ^ a_count ^ words "`]. Find the value of the [`t`] statistic. " ^ blank)
          p
      with
      | [ claimed; size; mean; s ] ->
          positive "the standard deviation" s;
          let se = standard_error s size in
          note "t_mean, claimed mean" [ claimed ];
          note "t_mean" [ s; root_of_square size; mean - claimed ];
          let difference = whole (mean - claimed) in
          let t = difference /: se in
          reach "t_mean" t;
          ([ t ], [ ("not_scaled", [ difference /: whole s ]) ])
      | _ -> failwith "four numbers were expected")
  | "interval" -> (
      match
        text_fields 4
          (words "A population has standard deviation [`\\sigma = " ^ a_count ^ words "`]. A sample of [`" ^ a_count
         ^ words "`] values has mean [`" ^ an_integer
         ^ words "`]. Find the 95% confidence interval for the mean of the population, using [`z = " ^ a_decimal
         ^ words "`]. From " ^ blank ^ words " to " ^ blank)
          p
      with
      | [ sigma; size; mean; z ] ->
          let sigma = int_of_string sigma and size = int_of_string size and mean = int_of_string mean in
          positive "the standard deviation" sigma;
          let z = decimal z in
          let se = standard_error sigma size in
          note "interval" [ sigma; root_of_square size ];
          note "interval, mean" [ mean ];
          let centre = whole mean in
          let low = centre -: (z *: se) and high = centre +: (z *: se) in
          (* the ends are the claimed means at which the sample mean is just
             refused *)
          if (centre -: low) /: se <> z || (centre -: high) /: se <> zero -: z then
            failwith "the ends are not where the z statistic is 1.96";
          ([ low; high ], [ ("not_scaled", [ centre -: (z *: whole sigma); centre +: (z *: whole sigma) ]) ])
      | _ -> failwith "four numbers were expected")
  | "proportion" -> (
      match
        fields 4
          (words "A coin is tossed [`" ^ a_count ^ words "`] times and comes up heads [`" ^ a_count
         ^ words "`] times. To test whether it is fair, [`H_0: p = \\frac{" ^ a_count ^ words "}{" ^ a_count
         ^ words "}`], find the value of the [`z`] statistic for the proportion of heads. " ^ blank)
          p
      with
      | [ tosses; heads; top; bottom ] ->
          positive "the number of tosses" tosses;
          if heads > tosses then failwith "more heads than tosses";
          let p0 = fraction top bottom in
          if p0 <> fraction 1 2 then failwith "a fair coin is not tested against 1/2";
          let se = exact_root (p0 *: (one -: p0) /: whole tosses) in
          let k = root_of_square tosses in
          (* the count less half the tosses, rounded down *)
          note "proportion" [ k; heads - ((tosses - (tosses mod 2)) / 2) ];
          let z = (fraction heads tosses -: p0) /: se in
          if z = zero then failwith "the proportion is exactly the one tested";
          ([ z ], [])
      | _ -> failwith "four numbers were expected")
  | "die" -> (
      match
        fields 9
          (words "A die is thrown [`" ^ a_count ^ words "`] times, and the faces [`" ^ a_count ^ words "`] to [`"
         ^ a_count ^ words "`] come up [`" ^ a_count ^ words "`], [`" ^ a_count ^ words "`], [`" ^ a_count
         ^ words "`], [`" ^ a_count ^ words "`], [`" ^ a_count ^ words "`] and [`" ^ a_count
         ^ words "`] times. To test whether the die is fair, find the value of the chi-square statistic. " ^ blank)
          p
      with
      | throws :: first :: last :: counts ->
          if first <> 1 then failwith "the faces do not start at 1";
          let faces = last - first + 1 in
          if List.length counts <> faces then failwith "not one count for every face";
          if List.fold_left ( + ) 0 counts <> throws then failwith "the counts do not add up to the throws";
          let expected_count = fraction throws faces in
          if expected_count.bottom <> 1 then failwith "the throws are not a whole number of times the faces";
          note "die, expected count" [ expected_count.top ];
          note "die, deviations" (List.map (fun c -> c - expected_count.top) counts);
          List.iter (positive "an observed count") counts;
          let statistic =
            sum (List.map (fun c -> square (whole c -: expected_count) /: expected_count) counts)
          and slip = sum (List.map (fun c -> square (whole c -: expected_count) /: whole c) counts) in
          if statistic = zero then failwith "every face came up as often as expected";
          ([ statistic ], [ ("divided_by_observed", [ slip ]) ])
      | _ -> failwith "nine numbers were expected")
  | "table" -> (
      match
        fields 4
          (words
             "A survey counts people by two characteristics: [`\\begin{array}{c|cc} & \\text{yes} & \\text{no} \\\\ \\hline \\text{group 1} & "
          ^ a_count ^ words " & " ^ a_count ^ words " \\\\ \\text{group 2} & " ^ a_count ^ words " & " ^ a_count
          ^ words
              " \\end{array}`]. To test whether the answer is independent of the group, find the value of the chi-square statistic. "
          ^ blank)
          p
      with
      | [ a; b; c; d ] as cells ->
          List.iter (positive "a count") cells;
          if a * d = b * c then failwith "the two rows are in proportion";
          note "table" cells;
          note "table, cells by halves" (List.map halves cells);
          let grid = [| [| a; b |]; [| c; d |] |] in
          let row i = grid.(i).(0) + grid.(i).(1) and column j = grid.(0).(j) + grid.(1).(j) in
          let all = row 0 + row 1 in
          let cells = List.concat_map (fun i -> List.map (fun j -> (i, j)) [ 0; 1 ]) [ 0; 1 ] in
          let expected_count (i, j) = fraction (row i * column j) all in
          let term divide (i, j) = square (whole grid.(i).(j) -: expected_count (i, j)) /: divide (i, j) in
          let statistic = sum (List.map (term expected_count) cells)
          and slip = sum (List.map (term (fun (i, j) -> whole grid.(i).(j))) cells) in
          let shortcut =
            fraction (times all (times ((a * d) - (b * c)) ((a * d) - (b * c)))) (row 0 * row 1 * column 0 * column 1)
          in
          if shortcut <> statistic then failwith "the sum over the cells and the shortcut disagree";
          ([ statistic ], [ ("divided_by_observed", [ slip ]) ])
      | _ -> failwith "four numbers were expected")
  | "two_means" -> (
      match
        fields 6
          (words "Two populations have standard deviations [`\\sigma_1 = " ^ a_count ^ words "`] and [`\\sigma_2 = "
         ^ a_count ^ words "`]. A sample of [`" ^ a_count ^ words "`] values from the first has mean [`" ^ an_integer
         ^ words "`], and a sample of [`" ^ a_count ^ words "`] values from the second has mean [`" ^ an_integer
         ^ words "`]. To test [`H_0: \\mu_1 = \\mu_2`], find the value of the [`z`] statistic. " ^ blank)
          p
      with
      | [ sigma1; sigma2; n1; mean1; n2; mean2 ] ->
          positive "a standard deviation" sigma1;
          positive "a standard deviation" sigma2;
          let se1 = standard_error sigma1 n1 and se2 = standard_error sigma2 n2 in
          if se1.bottom <> 1 || se2.bottom <> 1 then failwith "a standard error that is not whole";
          let se = exact_root (square se1 +: square se2) in
          if se.bottom <> 1 then failwith "the standard error of the difference is not whole";
          note "two_means" [ se1.top; se2.top; mean1 - mean2 ];
          note "two_means, sample sizes" [ root_of_square n1; root_of_square n2 ];
          note "two_means, second mean" [ mean2 ];
          let difference = whole (mean1 - mean2) in
          let z = difference /: se in
          reach "two_means" z;
          ([ z ], [ ("standard_errors_added", [ difference /: (se1 +: se2) ]) ])
      | _ -> failwith "six numbers were expected")
  | ("degrees_t" | "degrees_fit" | "degrees_table") as k -> (
      let question = words " How many degrees of freedom does the test have? " ^ blank in
      match k with
      | "degrees_t" -> (
          match fields 1 (words "A [`t`] test for a mean is made on a sample of [`" ^ a_count ^ words "`] values." ^ question) p with
          | [ n ] ->
              positive "the sample size" n;
              note "degrees_t" [ n ];
              (* n deviations from the mean, which add up to 0: all but one are free *)
              let deviations = range 1 n in
              ([ whole (List.length (List.filter (fun i -> i <> n) deviations)) ], [])
          | _ -> failwith "one number was expected")
      | "degrees_fit" -> (
          match
            fields 1
              (words "A chi-square goodness-of-fit test is made with [`" ^ a_count
             ^ words "`] categories, and no parameter is estimated from the data." ^ question)
              p
          with
          | [ categories ] ->
              positive "the number of categories" categories;
              note "degrees_fit" [ categories ];
              (* k counts that add up to the whole: all but the last are free *)
              ([ whole (List.length (List.filter (fun i -> i <> categories) (range 1 categories))) ], [])
          | _ -> failwith "one number was expected")
      | _ -> (
          match
            fields 2
              (words "A chi-square test of independence is made on a table of counts with [`" ^ a_count
             ^ words "`] rows and [`" ^ a_count ^ words "`] columns." ^ question)
              p
          with
          | [ rows; columns ] ->
              positive "the number of rows" rows;
              positive "the number of columns" columns;
              note "degrees_table" [ rows; columns ];
              let cells = List.concat_map (fun i -> List.map (fun j -> (i, j)) (range 1 columns)) (range 1 rows) in
              (* the last row and the last column follow from the totals *)
              let free = List.filter (fun (i, j) -> i <> rows && j <> columns) cells in
              ([ whole (List.length free) ], [ ("cells_minus_one", [ whole (List.length cells - 1) ]) ])
          | _ -> failwith "two numbers were expected"))
  | k -> failwith ("unknown kind " ^ k)

(* How many questions are made at each budget. *)
let questions_at _cost = 30000

let () =
  let base = load_file "hypothesis_testing.rhm" in
  let prices =
    [ ("z_mean", 1); ("degrees_t", 1); ("degrees_fit", 1); ("degrees_table", 1); ("t_mean", 2); ("interval", 2);
      ("proportion", 2); ("die", 3); ("table", 3); ("two_means", 3) ]
  in
  (* how each mistake is described *)
  let described =
    [ ( "not_scaled",
        "divides by the standard deviation itself, where the standard error, the standard deviation over sqrt(n), belongs"
      );
      ("divided_by_observed", "divides each squared difference by the observed count, where the expected count belongs");
      ("standard_errors_added", "adds the two standard errors, where their squares are added and the square root taken");
      ("cells_minus_one", "takes one less than the number of cells of the table, where (rows - 1)(columns - 1) belongs") ]
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
          let got = List.map number q.Rhema_engine.answers in
          let blanks = if k = "interval" then 2 else 1 in
          if List.length got <> blanks || List.mem None got then
            fail (Printf.sprintf "%s: %d numbers were expected as the answers of %S" k blanks p)
          else if number q.Rhema_engine.answer <> List.hd got then
            fail (Printf.sprintf "%s: the answer is not the first blank's, for %S" k p)
          else
            let got = List.map Option.get got in
            let shown values = String.concat "; " (List.map show values) in
            match expected q with
            | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
            | want, slips ->
                if got <> want then fail (Printf.sprintf "%s: answers %s, recomputed %s, for %S" k (shown got) (shown want) p);
                (* a question in which the mistake comes to the right answer
                   is not to be asked: wrong working would be marked right *)
                List.iter
                  (fun (name, slip) ->
                    if slip = want then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k name p);
                    (* nor one that a marker with a tolerance of one part in a
                       thousand could take for it: every blank of the mistake
                       is more than 1% away from the right one *)
                    List.iter2
                      (fun wrong right ->
                        if right <> zero then record_gap k wrong right;
                        if not (less (absolute right) (whole 100 *: absolute (wrong -: right))) then
                          fail
                            (Printf.sprintf "%s: %s gives %s, within 1%% of the answer %s, for %S" k name (show wrong)
                               (show right) p))
                      slip want)
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
                    | Some values, Some slip ->
                        let wrong = List.map number values in
                        if List.mem None wrong then fail (Printf.sprintf "%s: %s does not give numbers, for %S" k m.mistake p)
                        else
                          let wrong = List.map Option.get wrong in
                          if wrong <> slip then
                            fail (Printf.sprintf "%s: %s gives %s, recomputed %s, for %S" k m.mistake (shown wrong) (shown slip) p);
                          if wrong = got then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p)
                    | None, Some _ -> fail (Printf.sprintf "%s: %s gives no answer, for %S" k m.mistake p)
                    | _, None -> ())
                  listed)
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k _ -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  List.iter
    (fun (mistake, k) ->
      if not (Hashtbl.mem made (mistake, k)) then fail (Printf.sprintf "%s never listed on %s" mistake k))
    [ ("not_scaled", "z_mean"); ("not_scaled", "t_mean"); ("not_scaled", "interval"); ("divided_by_observed", "die");
      ("divided_by_observed", "table"); ("standard_errors_added", "two_means"); ("cells_minus_one", "degrees_table") ];
  (* the statistics reach their bounds and do not pass them *)
  List.iter
    (fun (label, bound) ->
      match Hashtbl.find_opt largest label with
      | Some size when size = whole bound -> ()
      | Some size -> fail (Printf.sprintf "%s: the largest statistic is %s, not %d" label (show size) bound)
      | None -> fail ("no statistic was seen for " ^ label))
    [ ("z_mean", 4); ("t_mean", 5); ("two_means", 4) ];
  (* A chi-square mistake is kept away from the answer by 1% and no more:
     mistakes between 1% and 1.5% away come up, on both sides of the
     answer. *)
  List.iter
    (fun label ->
      match Hashtbl.find_opt gaps label with
      | Some (least, below, above) ->
          if not (least < 0.015) then
            fail (Printf.sprintf "%s: no mistake comes within 1.5%% of its answer; the nearest is %g away" label least);
          if not (below && above) then fail (label ^ ": the mistakes all fall on one side of the answer")
      | None -> fail ("no mistake was seen for " ^ label))
    [ "die"; "table" ];
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
              Hashtbl.replace met part ();
              if not (Hashtbl.mem table part) then fail (Printf.sprintf "%s: asked with %s at %s" label (print part) (print view)))
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
  if !failures = 0 then print_endline "Rhema hypothesis_testing tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d hypothesis_testing test(s) failed." !failures);
    exit 1
  end
