(* Independent checks for regression.rhm. Every question is matched against
   the whole sentence of its form, the numbers are read back from it, and the
   answer is found again from the definition of the least-squares line, in
   exact fractions. Nothing is taken from the way the grammar builds its data:
   the x-values are whatever the question prints.

   - slope: S_xx, S_yy and S_xy are read. Such data can exist only if S_xx
     and S_yy are positive and S_xy^2 is at most S_xx S_yy (Cauchy-Schwarz).
     The slope is S_xy divided by S_xx.
   - intercept: the slope and the two means are read. The line with that
     slope through the point of the means is written down and its value at
     x = 0 is taken.
   - residual: the printed line and the printed point are read; the residual
     is the y of the point minus the value of the line at its x, and it must
     not be 0.
   - slope_from_data, predict, determination: the five points are read. The
     line a + b x is found by solving the two normal equations
     (n a + b sum x = sum y; a sum x + b sum x^2 = sum x y) as a 2 by 2
     system, by elimination, and it is then checked to be the least-squares
     line directly: its residuals add up to 0 and are orthogonal to x. The
     slope is b and must not be 0; a prediction is the value of the line at
     the printed x, which must lie beyond the data; r^2 is 1 - SSE / SST,
     with SSE the sum of the squared residuals of that line and SST the sum
     of the squared distances of y from its mean, and it must be strictly
     between 0 and 1. That fraction, brought to lowest terms here, must have
     a denominator of at most two digits, as the header says.
   - slope_from_sums: the number of pairs and the four sums are read. They
     are the sums of some data with different x-values only if
     n sum x^2 > (sum x)^2. The same two normal equations are solved from the
     printed sums, the solution is put back into both, and the slope, which
     must not be 0, is the answer.

   The header also says that the data are five points at x-values one apart,
   whose y-values are a trend with a small whole disturbance on each: this is
   checked on every listing (some line with a whole slope must pass within 2
   of every point, at a whole distance), but never used to find an answer.

   Some of what is checked is rare (points that lie on one line, data with a
   slope of 0), so several thousand questions are made at each budget, and
   many more at budget 2: the data on which the two mistakes give the same
   wrong number are about one listing in four thousand.

   The mistakes are found again from what they say. x_on_y divides the sum of
   the products of the deviations by the spread of y: from the data, with the
   deviations taken from the two means, or S_xy / S_yy from the printed
   values. through_origin is the sum of x y over the sum of x^2, from the
   data or from the printed sums. Each question must list exactly the
   mistakes its form is open to (slope: x_on_y; slope_from_data: both;
   slope_from_sums: through_origin; the others: none), each with the value
   found here, and that value must not be the right answer. Where a question
   lists two mistakes they must give different numbers, both as found here
   and as the engine reports them, so that a wrong answer says which mistake
   was made. *)

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

(* A fraction in lowest terms, with a positive denominator, so that two equal
   fractions are the same record. *)
type fraction = { top : int; bottom : int }

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let ratio top bottom =
  if bottom = 0 then failwith "a division by zero";
  let divisor = if bottom < 0 then -gcd top bottom else gcd top bottom in
  { top = top / divisor; bottom = bottom / divisor }

let whole n = { top = n; bottom = 1 }
let zero = whole 0
let one = whole 1
let ( +/ ) a b = ratio ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( -/ ) a b = ratio ((a.top * b.bottom) - (b.top * a.bottom)) (a.bottom * b.bottom)
let ( */ ) a b = ratio (a.top * b.top) (a.bottom * b.bottom)
let ( // ) a b = ratio (a.top * b.bottom) (a.bottom * b.top)
let is_zero x = x.top = 0
let less a b = a.top * b.bottom < b.top * a.bottom
let print x = if x.bottom = 1 then string_of_int x.top else Printf.sprintf "%d/%d" x.top x.bottom
let sum f items = List.fold_left (fun total item -> total +/ f item) zero items
let mean values = sum Fun.id values // whole (List.length values)

let number = function
  | Rhema_engine.Num n -> Some { top = n.Rhema_number.numerator; bottom = n.Rhema_number.denominator }
  | _ -> None

(* The numbers of a prompt: the pattern is the whole sentence, with a group
   wherever a number stands. A group that the sentence leaves out is "". *)
let words = Str.quote
let a_number = "\\([^`]*\\)"
let an_integer = "\\(-?[0-9]+\\)"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> match Str.matched_group (n + 1) prompt with text -> text | exception Not_found -> "")
  else failwith "the wording is not the expected one"

(* A whole number, written the one way it is written. *)
let integer text =
  match int_of_string_opt text with
  | Some n when string_of_int n = text -> n
  | _ -> failwith ("not a whole number: " ^ text)

(* A number as number_latex writes it: a whole number, or \frac{a}{b} in
   lowest terms with the sign in front. *)
let latex_number text =
  if Str.string_match (Str.regexp "^\\(-?\\)\\\\frac{\\([0-9]+\\)}{\\([0-9]+\\)}$") text 0 then begin
    let sign = Str.matched_group 1 text and top = Str.matched_group 2 text and bottom = Str.matched_group 3 text in
    let top = integer top and bottom = integer bottom in
    if top < 1 || bottom < 2 || gcd top bottom <> 1 then failwith ("not a fraction in lowest terms: " ^ text);
    ratio (if sign = "-" then -top else top) bottom
  end
  else whole (integer text)

(* The data points of a listing "(0, 3), (1, 5), ...", all of it. *)
let points text =
  let one_point = Str.regexp "(\\(-?[0-9]+\\), \\(-?[0-9]+\\))" in
  let rec read start found =
    if not (Str.string_match one_point text start) then failwith ("not a list of points: " ^ text);
    let x = Str.matched_group 1 text and y = Str.matched_group 2 text and next = Str.match_end () in
    let found = (whole (integer x), whole (integer y)) :: found in
    if next = String.length text then List.rev found
    else if next + 2 <= String.length text && String.sub text next 2 = ", " then read (next + 2) found
    else failwith ("not a list of points: " ^ text)
  in
  read 0 []

(* What the header says of the data: five points, at x-values one apart, on
   a trend with a small whole disturbance on each. How far a small disturbance
   may go is the one number taken from the grammar. *)
let small = 2

let as_described data =
  if List.length data <> 5 then failwith "the data are not five points";
  let rec one_apart = function
    | (x, _) :: ((next, _) :: _ as rest) -> next -/ x = one && one_apart rest
    | _ -> true
  in
  if not (one_apart data) then failwith "the x-values are not one apart";
  (* a trend with a small whole disturbance: for some whole slope b, the
     numbers y - b x lie within 2 of one whole number, that is, they are whole
     and the largest is at most 4 more than the smallest *)
  if List.exists (fun (x, y) -> x.bottom <> 1 || y.bottom <> 1) data then failwith "the data are not whole numbers";
  let heights = List.map (fun (_, y) -> y.top) data in
  let lowest = List.fold_left min max_int heights and highest = List.fold_left max min_int heights in
  let reach = highest - lowest + (2 * small) in
  let fits b =
    let left = List.map (fun (x, y) -> y.top - (b * x.top)) data in
    List.fold_left max min_int left - List.fold_left min max_int left <= 2 * small
  in
  if not (List.exists fits (List.init ((2 * reach) + 1) (fun n -> n - reach))) then
    failwith "the y-values are not a trend with a small disturbance on each"

(* The line y = at_zero + slope x. *)
type line = { at_zero : fraction; slope : fraction }

let value line x = line.at_zero +/ (line.slope */ x)

(* The line with this slope through this point. *)
let through (x, y) slope = { at_zero = y -/ (slope */ x); slope }

(* The two unknowns u, v of  a1 u + b1 v = c1,  a2 u + b2 v = c2,  by
   elimination: the first equation, which must hold u, is taken out of the
   second, which then gives v. *)
let solve (a1, b1, c1) (a2, b2, c2) =
  if is_zero a1 then failwith "the first equation does not hold the first unknown";
  let times = a2 // a1 in
  let b = b2 -/ (times */ b1) and c = c2 -/ (times */ c1) in
  if is_zero b then failwith "the two equations do not have one solution";
  let v = c // b in
  let u = (c1 -/ (b1 */ v)) // a1 in
  (u, v)

(* The line of the normal equations for n pairs with these sums. *)
let normal_line ~n ~sum_x ~sum_y ~sum_xx ~sum_xy =
  let at_zero, slope = solve (n, sum_x, sum_y) (sum_x, sum_xx, sum_xy) in
  { at_zero; slope }

let residuals line data = List.map (fun (x, y) -> (x, y -/ value line x)) data

(* The least-squares line of the data: the line of the normal equations,
   then checked to be the best one, with residuals that add up to nothing and
   are orthogonal to x. *)
let least_squares data =
  let line =
    normal_line
      ~n:(whole (List.length data))
      ~sum_x:(sum fst data) ~sum_y:(sum snd data)
      ~sum_xx:(sum (fun (x, _) -> x */ x) data)
      ~sum_xy:(sum (fun (x, y) -> x */ y) data)
  in
  let left = residuals line data in
  if not (is_zero (sum snd left)) then failwith "the residuals of the fitted line do not add up to 0";
  if not (is_zero (sum (fun (x, e) -> x */ e) left)) then failwith "the residuals of the fitted line are not orthogonal to x";
  line

(* The sum of the squared distances of the values from their mean. *)
let spread values =
  let centre = mean values in
  sum (fun v -> (v -/ centre) */ (v -/ centre)) values

(* The two mistakes, on data. *)
let x_on_y_of data =
  let centre_x = mean (List.map fst data) and centre_y = mean (List.map snd data) in
  let products = sum (fun (x, y) -> (x -/ centre_x) */ (y -/ centre_y)) data in
  let spread_y = spread (List.map snd data) in
  if is_zero spread_y then failwith "the y-values are all the same: x_on_y divides by 0";
  products // spread_y

let through_origin_of data =
  let squares = sum (fun (x, _) -> x */ x) data in
  if is_zero squares then failwith "the x-values are all 0: through_origin divides by 0";
  sum (fun (x, y) -> x */ y) data // squares

(* The wordings that were met, to see that each one is. *)
let wordings = Hashtbl.create 8
let note wording = Hashtbl.replace wordings wording ()

let all_wordings =
  [ "a whole slope"; "a slope that is a fraction"; "a line written x"; "a line written -x";
    "a line with a number before x"; "a line with no constant"; "a line with a constant added";
    "a line with a constant taken away"; "a negative y-value" ]

let slope_asked = words "Find the slope of the least-squares regression line of [`y`] on [`x`]"

(* A listing, read and held against the header. *)
let data_of listing =
  let data = points listing in
  as_described data;
  if List.exists (fun (_, y) -> less y zero) data then note "a negative y-value";
  data

(* The right answer of a question, and the answer of each mistake that its
   form is open to, all found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "slope" -> (
      match
        List.map integer
          (fields 3
             (words "For a set of data pairs [`(x, y)`], [`S_{xx} = \\sum (x - \\bar{x})^{2} = " ^ an_integer
            ^ words "`], [`S_{yy} = \\sum (y - \\bar{y})^{2} = " ^ an_integer
            ^ words "`] and [`S_{xy} = \\sum (x - \\bar{x})(y - \\bar{y}) = " ^ an_integer ^ words "`]. " ^ slope_asked
            ^ words ".")
             p)
      with
      | [ s_xx; s_yy; s_xy ] ->
          if s_xx <= 0 then failwith "S_xx is not positive";
          if s_yy <= 0 then failwith "S_yy is not positive";
          if s_xy * s_xy > s_xx * s_yy then failwith "no data have these values: S_xy^2 is more than S_xx S_yy";
          (ratio s_xy s_xx, [ ("x_on_y", ratio s_xy s_yy) ])
      | _ -> failwith "three numbers were expected")
  | "intercept" -> (
      match
        fields 3
          (words "The least-squares regression line of [`y`] on [`x`] for a set of data has the slope [`" ^ a_number
         ^ words "`]. The mean of the [`x`]-values is [`" ^ an_integer ^ words "`] and the mean of the [`y`]-values is [`"
         ^ an_integer ^ words "`]. Find the intercept of the line, its value at [`x = 0`].")
          p
      with
      | [ slope; mean_x; mean_y ] ->
          let slope = latex_number slope in
          note (if slope.bottom = 1 then "a whole slope" else "a slope that is a fraction");
          (value (through (whole (integer mean_x), whole (integer mean_y)) slope) zero, [])
      | _ -> failwith "three numbers were expected")
  | "residual" -> (
      match
        fields 6
          (words "The least-squares regression line for a set of data is [`\\hat{y} = " ^ "\\(-?[0-9]*\\)x"
         ^ "\\( \\([-+]\\) \\([0-9]+\\)\\|\\)" ^ words "`]. One of the data points is [`(" ^ an_integer ^ words ", "
         ^ an_integer
         ^ words ")`]. Find the residual of this point: the observed value of [`y`] minus the predicted one.")
          p
      with
      | [ before_x; _; sign; constant; x; y ] ->
          (* 1 and -1 are not written before x, and a constant of 0 is left out *)
          let slope =
            match before_x with
            | "" -> note "a line written x"; 1
            | "-" -> note "a line written -x"; -1
            | text ->
                let n = integer text in
                if abs n < 2 then failwith ("the line is not written as a line is: " ^ text ^ "x");
                note "a line with a number before x";
                n
          in
          let at_zero =
            match sign with
            | "" -> note "a line with no constant"; 0
            | _ ->
                let n = integer constant in
                if n < 1 then failwith "the line is not written as a line is: a constant of 0";
                if sign = "+" then (note "a line with a constant added"; n)
                else (note "a line with a constant taken away"; -n)
          in
          let line = { at_zero = whole at_zero; slope = whole slope } in
          let left = whole (integer y) -/ value line (whole (integer x)) in
          if is_zero left then failwith "the point is on the line: its residual is 0";
          (left, [])
      | _ -> failwith "six fields were expected")
  | "slope_from_data" -> (
      match fields 1 (slope_asked ^ words " for the data [`" ^ a_number ^ words "`].") p with
      | [ listing ] ->
          let data = data_of listing in
          let line = least_squares data in
          if is_zero line.slope then failwith "the data show no trend: the slope is 0";
          (line.slope, [ ("x_on_y", x_on_y_of data); ("through_origin", through_origin_of data) ])
      | _ -> failwith "one listing was expected")
  | "slope_from_sums" -> (
      match
        fields 5
          ("\\([A-Z][a-z]+\\)" ^ words " data pairs [`(x, y)`] have [`\\sum x = " ^ an_integer ^ words "`], [`\\sum y = "
         ^ an_integer ^ words "`], [`\\sum x^{2} = " ^ an_integer ^ words "`] and [`\\sum xy = " ^ an_integer
         ^ words "`]. " ^ slope_asked ^ words ".")
          p
      with
      | [ how_many; sum_x; sum_y; sum_xx; sum_xy ] ->
          let n = match how_many with "Five" -> 5 | other -> failwith ("how many pairs is " ^ other) in
          let sum_x = integer sum_x and sum_y = integer sum_y and sum_xx = integer sum_xx and sum_xy = integer sum_xy in
          if n * sum_xx <= sum_x * sum_x then failwith "no data with different x-values have these sums";
          let line =
            normal_line ~n:(whole n) ~sum_x:(whole sum_x) ~sum_y:(whole sum_y) ~sum_xx:(whole sum_xx)
              ~sum_xy:(whole sum_xy)
          in
          (* the line found does satisfy both normal equations *)
          if (whole n */ line.at_zero) +/ (line.slope */ whole sum_x) <> whole sum_y then
            failwith "the first normal equation is not satisfied";
          if (line.at_zero */ whole sum_x) +/ (line.slope */ whole sum_xx) <> whole sum_xy then
            failwith "the second normal equation is not satisfied";
          if is_zero line.slope then failwith "the data show no trend: the slope is 0";
          (line.slope, [ ("through_origin", ratio sum_xy sum_xx) ])
      | _ -> failwith "five fields were expected")
  | "predict" -> (
      match
        fields 2
          (words "The least-squares regression line of [`y`] on [`x`] is fitted to the data [`" ^ a_number
         ^ words "`]. Find the value of [`y`] it predicts at [`x = " ^ an_integer ^ words "`].")
          p
      with
      | [ listing; at ] ->
          let data = data_of listing and at = whole (integer at) in
          let line = least_squares data in
          if is_zero line.slope then failwith "the data show no trend: the slope is 0";
          if not (List.for_all (fun (x, _) -> less x at) data || List.for_all (fun (x, _) -> less at x) data) then
            failwith "the prediction is not asked beyond the data";
          (value line at, [])
      | _ -> failwith "two fields were expected")
  | "determination" -> (
      match
        fields 1
          (words
             "Find the coefficient of determination [`r^{2}`], the square of the correlation coefficient, for the data [`"
          ^ a_number ^ words "`]. Give it as a fraction.")
          p
      with
      | [ listing ] ->
          let data = data_of listing in
          let line = least_squares data in
          let unexplained = sum (fun (_, e) -> e */ e) (residuals line data) in
          let all = spread (List.map snd data) in
          if is_zero all then failwith "the y-values are all the same: r^2 is 0 / 0";
          let r2 = one -/ (unexplained // all) in
          if not (less zero r2 && less r2 one) then failwith ("r^2 = " ^ print r2 ^ " is not strictly between 0 and 1");
          (* in lowest terms, the denominator has at most two digits *)
          let shared = gcd r2.top r2.bottom in
          if r2.bottom / shared >= 100 then
            failwith (Printf.sprintf "r^2 = %d/%d has a denominator of more than two digits" (r2.top / shared) (r2.bottom / shared));
          (r2, [])
      | _ -> failwith "one listing was expected")
  | k -> failwith ("unknown kind " ^ k)

(* How many questions are made at a budget. Budget 2 has the rarest thing to
   look for: two mistakes that give the same wrong number, on about one
   listing in four thousand. *)
let questions_at cost = if cost = 2 then 80000 else 6000

(* The first two of the values that are the same number, if any are. *)
let rec same_pair = function
  | [] -> None
  | (name, value) :: rest -> (
      match List.find_opt (fun (_, other) -> other = value) rest with
      | Some (other, _) -> Some (name, other, value)
      | None -> same_pair rest)

let () =
  let base = load_file "regression.rhm" in
  let prices =
    [ ("slope", 1); ("intercept", 1); ("residual", 1); ("slope_from_data", 2); ("slope_from_sums", 2); ("predict", 3);
      ("determination", 3) ]
  in
  let seen = Hashtbl.create 8 and made = Hashtbl.create 2 in
  (* no question outside the three prices *)
  List.iter
    (fun cost ->
      let spec = with_initial base "cost" cost in
      for seed = 0 to 4 do
        Random.init seed;
        match Rhema_engine.generate spec with
        | exception Rhema_engine.Generation_error _ -> ()
        | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
      done)
    [ 0; 4; 5; 6 ];
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at cost - 1 do
      Random.init (seed + (1000000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          match (number q.Rhema_engine.answer, q.Rhema_engine.answers) with
          | None, _ | _, ([] | _ :: _ :: _) -> fail (Printf.sprintf "%s: one number was expected as the answer of %S" k p)
          | Some got, [ _ ] -> (
              match expected q with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | want, slips ->
                  if got <> want then
                    fail (Printf.sprintf "%s: answer %s, recomputed %s, for %S" k (print got) (print want) p);
                  (* a question is asked only where each mistake gives another number *)
                  List.iter
                    (fun (name, slip) ->
                      if slip = want then
                        fail (Printf.sprintf "%s: %s gives the right answer %s, for %S" k name (print want) p))
                    slips;
                  (* and two mistakes never give the same wrong number *)
                  (match same_pair slips with
                   | Some (first, second, value) ->
                       fail
                         (Printf.sprintf "%s: %s and %s give the same wrong answer %s, for %S" k first second
                            (print value) p)
                   | None -> ());
                  let listed = q.Rhema_engine.mistakes in
                  (match
                     same_pair
                       (List.filter_map
                          (fun (m : Rhema_engine.mistaken) ->
                            match m.mistaken_answers with
                            | Some [ value ] -> Option.map (fun wrong -> (m.mistake, wrong)) (number value)
                            | _ -> None)
                          listed)
                   with
                   | Some (first, second, value) ->
                       fail
                         (Printf.sprintf "%s: %s and %s are reported with the same wrong answer %s, for %S" k first
                            second (print value) p)
                   | None -> ());
                  if List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed <> List.map fst slips then
                    fail
                      (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k
                         (String.concat ", " (List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed))
                         (String.concat ", " (List.map fst slips))
                         p);
                  List.iter
                    (fun (m : Rhema_engine.mistaken) ->
                      Hashtbl.replace made m.mistake ();
                      if m.description = "" then fail (m.mistake ^ " has no description");
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match number value with
                          | Some wrong ->
                              if wrong <> slip then
                                fail
                                  (Printf.sprintf "%s: %s gives %s, recomputed %s, for %S" k m.mistake (print wrong)
                                     (print slip) p);
                              if wrong = got then
                                fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p)
                          | None -> fail (Printf.sprintf "%s: %s does not give a number, for %S" k m.mistake p))
                      | _, None -> ()
                      | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                    listed))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  List.iter
    (fun mistake -> if not (Hashtbl.mem made mistake) then fail ("never listed: " ^ mistake))
    [ "x_on_y"; "through_origin" ];
  List.iter (fun wording -> if not (Hashtbl.mem wordings wording) then fail ("never worded: " ^ wording)) all_wordings;
  if !failures = 0 then print_endline "Rhema regression tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d regression test(s) failed." !failures);
    exit 1
  end
