(* Independent checks for double_integral.rhm. Nothing here uses the
   grammar's closed formulas. The integrand, the limits and the region are
   read back from the printed question; the integrand is held as a polynomial
   in x and y with exact fractions as coefficients and is integrated as an
   iterated integral, symbolically: the inner integral between two polynomials
   in the outer variable, then the outer integral between two numbers. The
   result must be the engine's answer, exactly.

   Rectangle (rectangle_monomial, rectangle_sum): the four limits are numbers.
   The order of dy and dx in the text says which pair of limits belongs to
   which variable. The integral is worked out in the order printed and in the
   other order as well; the two must agree.

   Inner limit on a line (inner_variable, inner_line): the upper inner limit
   is read as a polynomial in the outer variable (x, 2x, 3x), put into the
   antiderivative of the inner integral, and the result is integrated again.
   The region must not be turned over: the inner lower limit stays below the
   upper one over the whole outer interval.

   Average value (average): f is integrated over the rectangle printed in
   words, in both orders, and divided by the rectangle's area.

   Triangle (triangle_region): only the three corners are read. They are
   sorted by x, the three sides are found as lines through pairs of corners,
   and the triangle is cut at the middle corner into pieces that each have
   one side below and one above; which is which is decided by their heights
   in the middle of the piece. The integral of p x + q y is also found a
   second way, as the area times the integrand at the centroid.

   Parabola and line (parabola_region): both curves are read as polynomials
   in x. The points where they meet are the two roots of their difference,
   found with the quadratic formula on fractions; the curve that is higher
   half way between them is the upper limit.

   Besides the answer: every question's whole text must be worded as its kind
   is (a text that cannot be read is a failure), an integrand is p x + q y or
   one term c x^m y^n with a variable in it, in brackets exactly when it needs
   them, no answer is 0, every kind appears at its price and only there, each
   question spends its budget, a budget outside 1 to 3 gives no question, the
   numbers of each form cover exactly the values its rule allows, and each
   form comes about as often as its weight says. *)

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
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

(* ---- Polynomials in x and y ------------------------------------------- *)

(* A list of ((power of x, power of y), coefficient), sorted by the powers,
   each pair of powers once and no coefficient 0, so that two equal
   polynomials are equal as lists. *)
let normal terms =
  let rec merge = function
    | (e, a) :: (e', b) :: rest when e = e' -> merge ((e, a +: b) :: rest)
    | (e, a) :: rest -> if a = zero then merge rest else (e, a) :: merge rest
    | [] -> []
  in
  merge (List.sort (fun (e, _) (e', _) -> compare e e') terms)

let constant c = normal [ ((0, 0), c) ]
let add p q = normal (p @ q)
let subtract p q = normal (p @ List.map (fun (e, a) -> (e, zero -: a)) q)

let multiply p q =
  normal (List.concat_map (fun ((i, j), a) -> List.map (fun ((k, l), b) -> ((i + k, j + l), a *: b)) q) p)

let rec raised p n = if n = 0 then constant (whole 1) else multiply p (raised p (n - 1))

(* The same polynomial with the two variables exchanged. *)
let exchanged p = normal (List.map (fun ((i, j), a) -> ((j, i), a)) p)
let has_y p = List.exists (fun ((_, j), _) -> j > 0) p
let value p x y = List.fold_left (fun total ((i, j), a) -> total +: (a *: power x i *: power y j)) zero p

(* Term by term: the antiderivative of a x^i y^j in y is a x^i y^(j+1) / (j+1). *)
let antiderivative_in_y p = normal (List.map (fun ((i, j), a) -> ((i, j + 1), a /: whole (j + 1))) p)
let antiderivative_in_x p = normal (List.map (fun ((i, j), a) -> ((i + 1, j), a /: whole (i + 1))) p)

(* y replaced by a polynomial in x. *)
let with_y p limit =
  List.fold_left (fun total ((i, j), a) -> add total (multiply [ ((i, 0), a) ] (raised limit j))) [] p

(* The integral of f, first in y from the curve `lower` to the curve `upper`
   (polynomials in x), then in x from `from` to `until`. *)
let iterated f ~lower ~upper ~from ~until =
  if has_y lower || has_y upper then failwith "an inner limit holds the variable of the inner integral";
  let inner = antiderivative_in_y f in
  let in_x = subtract (with_y inner upper) (with_y inner lower) in
  if has_y in_x then failwith "the inner integral still holds its own variable";
  let outer = antiderivative_in_x in_x in
  value outer until zero -: value outer from zero

(* ---- Reading the text -------------------------------------------------- *)

let matched n text = match Str.matched_group n text with s -> Some s | exception Not_found -> None

(* One term as the grammar writes it: 3, x, -x, 2x, -4x^{2}y, y^{2}. A
   coefficient of 1 is not written, nor is a power of 1. *)
let term_re = Str.regexp "^\\(-?\\)\\([0-9]*\\)\\(x\\(\\^{\\([0-9]+\\)}\\)?\\)?\\(y\\(\\^{\\([0-9]+\\)}\\)?\\)?$"

let term text =
  if not (Str.string_match term_re text 0) then failwith ("cannot read the term \"" ^ text ^ "\"");
  let minus = Str.matched_group 1 text = "-" and digits = Str.matched_group 2 text in
  let exponent variable written =
    match (matched variable text, matched written text) with
    | None, _ -> 0
    | Some _, None -> 1
    | Some _, Some n -> if int_of_string n < 2 then failwith ("a power of 0 or 1 is written out in \"" ^ text ^ "\"") else int_of_string n
  in
  let i = exponent 3 5 in
  let j = exponent 6 8 in
  if digits = "" && i + j = 0 then failwith ("a term with nothing in it: \"" ^ text ^ "\"");
  if String.length digits > 1 && digits.[0] = '0' then failwith ("a number that starts with 0 in \"" ^ text ^ "\"");
  let size = if digits = "" then 1 else int_of_string digits in
  if i + j > 0 && digits <> "" && size < 2 then failwith ("a coefficient of 0 or 1 is written out in \"" ^ text ^ "\"");
  if minus && size = 0 then failwith "minus 0";
  ((i, j), whole (if minus then -size else size))

(* A sum of such terms, "3x - 4y", in the order printed. Only the first term
   may carry its own minus sign, and no pair of powers comes twice. *)
let polynomial text =
  let rec read first = function
    | Str.Delim d :: Str.Text t :: rest ->
        if (not first) && t <> "" && t.[0] = '-' then failwith ("two signs in a row in \"" ^ text ^ "\"");
        let e, c = term t in
        (e, if d = " - " then zero -: c else c) :: read false rest
    | [] -> []
    | _ -> failwith ("cannot read the sum \"" ^ text ^ "\"")
  in
  let terms = read true (Str.full_split (Str.regexp " [+-] ") (" + " ^ text)) in
  if terms = [] then failwith "an empty sum";
  let powers = List.map fst terms in
  if List.length (List.sort_uniq compare powers) <> List.length powers then
    failwith ("terms that could be collected in \"" ^ text ^ "\"");
  terms

(* An integrand stands in \left( \right) exactly when it is a sum or starts
   with a minus sign. *)
let integrand text =
  let bracketed = Str.string_match (Str.regexp "^\\\\left(\\(.*\\)\\\\right)$") text 0 in
  let inside = if bracketed then Str.matched_group 1 text else text in
  let terms = polynomial inside in
  let needs_brackets = match terms with [ (_, c) ] -> sign c < 0 | _ -> true in
  if bracketed && not needs_brackets then failwith "brackets round a single term without a minus sign";
  if needs_brackets && not bracketed then failwith "no brackets round a sum or a term with a minus sign";
  terms

let whole_number text =
  if Str.string_match (Str.regexp "^\\(0\\|-?[1-9][0-9]*\\)$") text 0 then int_of_string text
  else failwith ("cannot read the number \"" ^ text ^ "\"")

(* The whole text must be the pattern, from its first character to its last;
   the groups are given back in order. *)
let fields re count text =
  if not (Str.string_match (Str.regexp re) text 0 && Str.match_end () = String.length text) then
    failwith "the text is not worded as its kind is";
  List.init count (fun i -> Str.matched_group (i + 1) text)

let limit_re = "\\([^{}`]*\\)"

let iterated_re =
  "^Evaluate \\[`\\\\int_{" ^ limit_re ^ "}\\^{" ^ limit_re ^ "} \\\\int_{" ^ limit_re ^ "}\\^{" ^ limit_re
  ^ "} \\([^`]*\\) \\\\, d\\([xy]\\) \\\\, d\\([xy]\\)`\\]\\.$"

let integer_re = "\\(-?[0-9]+\\)"

let average_re =
  "^Find the average value of \\[`f(x, y) = \\([^`]*\\)`\\] over the rectangle \\[`" ^ integer_re ^ " \\\\le x \\\\le "
  ^ integer_re ^ "`\\], \\[`" ^ integer_re ^ " \\\\le y \\\\le " ^ integer_re ^ "`\\]\\.$"

let corner_re = "\\[`(" ^ integer_re ^ ", " ^ integer_re ^ ")`\\]"

let triangle_re =
  "^Let \\[`T`\\] be the triangle with the corners " ^ corner_re ^ ", " ^ corner_re ^ " and " ^ corner_re
  ^ "\\. Evaluate \\[`\\\\iint_{T} \\([^`]*\\) \\\\, dA`\\]\\.$"

let parabola_re =
  "^Let \\[`R`\\] be the region enclosed by the parabola \\[`y = \\([^`]*\\)`\\] and the line \\[`y = \\([^`]*\\)`\\]\\. \
   Evaluate \\[`\\\\iint_{R} \\([^`]*\\) \\\\, dA`\\]\\.$"

(* ---- What was generated ------------------------------------------------ *)

(* The numbers of each form, to compare at the end with the values its rule
   allows: none outside them, and none of them missing. *)
let noted : (string * string, int list) Hashtbl.t = Hashtbl.create 64

let note k name n =
  let before = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
  if not (List.mem n before) then Hashtbl.replace noted (k, name) (n :: before)

(* p x + q y, in this order. *)
let note_sum k = function
  | [ ((1, 0), p); ((0, 1), q) ] ->
      note k "coefficient of x" p.top;
      note k "coefficient of y" q.top
  | _ -> failwith "the integrand is not p x + q y"

(* c x^m y^n with at least one of the variables in it. The two powers are
   noted together, as 10 m + n. *)
let note_monomial k = function
  | [ ((m, n), c) ] when m + n >= 1 ->
      note k "coefficient" c.top;
      note k "powers" ((10 * m) + n)
  | _ -> failwith "the integrand is not one term c x^m y^n with a variable in it"

(* ---- Regions given in words -------------------------------------------- *)

(* The line through two corners that are not one above the other, as y in
   terms of x. *)
let line (x1, y1) (x2, y2) =
  let slope = fraction (y2 - y1) (x2 - x1) in
  normal [ ((1, 0), slope); ((0, 0), whole y1 -: (slope *: whole x1)) ]

let over_triangle f corners =
  match List.sort compare corners with
  | [ ((x1, _) as p1); ((x2, _) as p2); ((x3, _) as p3) ] ->
      if x1 = x3 then failwith "the corners lie on one line";
      let long = line p1 p3 in
      let piece from until short =
        let middle = fraction (from + until) 2 in
        let a = value long middle zero and b = value short middle zero in
        if a = b then failwith "the corners lie on one line";
        let lower, upper = if less a b then (long, short) else (short, long) in
        iterated f ~lower ~upper ~from:(whole from) ~until:(whole until)
      in
      (if x1 < x2 then piece x1 x2 (line p1 p2) else zero) +: if x2 < x3 then piece x2 x3 (line p2 p3) else zero
  | _ -> failwith "a triangle has three corners"

(* Area times the integrand at the centroid: right for a polynomial of
   degree 1. *)
let by_centroid f corners =
  match corners with
  | [ (x1, y1); (x2, y2); (x3, y3) ] ->
      let twice_area = abs (((x2 - x1) * (y3 - y1)) - ((x3 - x1) * (y2 - y1))) in
      fraction twice_area 2 *: value f (fraction (x1 + x2 + x3) 3) (fraction (y1 + y2 + y3) 3)
  | _ -> failwith "a triangle has three corners"

let square_root n =
  let rec up r = if r * r >= n then r else up (r + 1) in
  let r = up 0 in
  if r * r <> n then failwith "the curves do not meet at fractions";
  r

(* Where two curves y = polynomial in x meet, when their difference is a
   quadratic with two roots: the smaller root, then the larger. *)
let meeting_points first second =
  let difference = subtract first second in
  if List.exists (fun ((i, j), _) -> i > 2 || j > 0) difference then failwith "the curves are not a parabola and a line";
  let coefficient i = Option.value (List.assoc_opt (i, 0) difference) ~default:zero in
  let a = coefficient 2 and b = coefficient 1 and c = coefficient 0 in
  if a = zero then failwith "the curves do not enclose a region";
  let under_root = (b *: b) -: (whole 4 *: a *: c) in
  if sign under_root <= 0 then failwith "the curves do not meet twice";
  let root = fraction (square_root under_root.top) (square_root under_root.bottom) in
  let one = (root -: b) /: (whole 2 *: a) and other = (zero -: root -: b) /: (whole 2 *: a) in
  if less one other then (one, other) else (other, one)

(* ---- The answer, found again ------------------------------------------- *)

let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | ("rectangle_monomial" | "rectangle_sum" | "inner_variable" | "inner_line") as k -> (
      match fields iterated_re 7 p with
      | [ from; until; lower; upper; f; inner; outer ] ->
          let from = whole_number from and until = whole_number until in
          if from >= until then failwith "the outer limits are not in order";
          let f = integrand f in
          let lower = normal (polynomial lower) and upper = normal (polynomial upper) in
          (* the limits written first belong to the differential written last;
             the working is done with the inner variable called y *)
          let turn =
            match inner ^ outer with
            | "yx" -> fun g -> g
            | "xy" -> exchanged
            | _ -> failwith "the two differentials are the same"
          in
          let g = turn (normal f) and lower = turn lower and upper = turn upper in
          let result = iterated g ~lower ~upper ~from:(whole from) ~until:(whole until) in
          (* the inner limits are in order over the whole outer interval; they
             are lines, so the two ends and the middle settle it *)
          let gap x = value upper x zero -: value lower x zero in
          if sign (gap (whole from)) < 0 || sign (gap (whole until)) < 0 || sign (gap (fraction (from + until) 2)) <= 0
          then failwith "the inner limits are not in order";
          let fixed g = match g with [] -> Some 0 | [ ((0, 0), c) ] when c.bottom = 1 -> Some c.top | _ -> None in
          let multiple_of_x g = match g with [ ((1, 0), c) ] when c.bottom = 1 -> Some c.top | _ -> None in
          if fixed lower <> Some 0 then failwith "the inner integral does not start at 0";
          let rectangle top =
            (* the other order of integration *)
            let again =
              iterated (exchanged g) ~lower:(constant (whole from)) ~upper:(constant (whole until)) ~from:zero
                ~until:(whole top)
            in
            if again <> result then failwith "the two orders of integration disagree"
          in
          let starts_at_0 () = if from <> 0 then failwith "the outer integral does not start at 0" in
          (match (k, fixed upper, multiple_of_x upper) with
          | "rectangle_monomial", Some top, _ ->
              rectangle top;
              note_monomial k f;
              note k "outer lower limit" from;
              note k "outer width" (until - from);
              note k "inner upper limit" top
          | "rectangle_sum", Some top, _ ->
              rectangle top;
              starts_at_0 ();
              note_sum k f;
              note k "outer upper limit" until;
              note k "inner upper limit" top
          | "inner_variable", _, Some 1 ->
              starts_at_0 ();
              note_sum k f;
              note k "outer upper limit" until
          | "inner_line", _, Some slope when slope >= 2 ->
              starts_at_0 ();
              note_monomial k f;
              note k "outer upper limit" until;
              note k "slope of the inner limit" slope
          | _ -> failwith "the inner upper limit is not that of its kind");
          result
      | _ -> failwith "the text is not worded as its kind is")
  | "average" as k -> (
      match fields average_re 5 p with
      | [ f; x0; x1; y0; y1 ] ->
          let x0 = int_of_string x0 and x1 = int_of_string x1 and y0 = int_of_string y0 and y1 = int_of_string y1 in
          if x0 >= x1 || y0 >= y1 then failwith "the rectangle has no area";
          if x0 <> 0 || y0 <> 0 then failwith "the rectangle does not start at the origin";
          let f = polynomial f in
          (match f with
          | [ ((2, 0), a); ((0, 1), b) ] ->
              note k "coefficient of x^2" a.top;
              note k "coefficient of y" b.top
          | _ -> failwith "the function is not p x^2 + q y");
          note k "width" x1;
          note k "height" y1;
          let g = normal f in
          let total =
            iterated g ~lower:(constant (whole y0)) ~upper:(constant (whole y1)) ~from:(whole x0) ~until:(whole x1)
          in
          let again =
            iterated (exchanged g) ~lower:(constant (whole x0)) ~upper:(constant (whole x1)) ~from:(whole y0)
              ~until:(whole y1)
          in
          if again <> total then failwith "the two orders of integration disagree";
          total /: whole ((x1 - x0) * (y1 - y0))
      | _ -> failwith "the text is not worded as its kind is")
  | "triangle_region" as k -> (
      match fields triangle_re 7 p with
      | [ x1; y1; x2; y2; x3; y3; f ] ->
          let corner x y = (int_of_string x, int_of_string y) in
          let corners = [ corner x1 y1; corner x2 y2; corner x3 y3 ] in
          let f = integrand f in
          note_sum k f;
          (* cut off by the axes: the origin and a point on each positive axis *)
          (match corners with
          | [ (0, 0); (a, 0); (0, b) ] when a > 0 && b > 0 ->
              note k "corner on the x axis" a;
              note k "corner on the y axis" b
          | _ -> failwith "the corners are not the origin, a point on the positive x axis and one on the positive y axis");
          let result = over_triangle (normal f) corners in
          if by_centroid (normal f) corners <> result then failwith "the limits and the centroid disagree";
          result
      | _ -> failwith "the text is not worded as its kind is")
  | "parabola_region" as k -> (
      match fields parabola_re 3 p with
      | [ parabola; straight; f ] ->
          let parabola = polynomial parabola and straight = polynomial straight in
          let f = integrand f in
          note_sum k f;
          (match parabola with [ ((2, 0), c) ] when c = whole 1 -> () | _ -> failwith "the parabola is not y = x^2");
          (match straight with
          | [ ((1, 0), slope) ] when sign slope > 0 -> note k "slope of the line" slope.top
          | _ -> failwith "the line is not y = k x with k positive");
          let parabola = normal parabola and straight = normal straight in
          let left, right = meeting_points parabola straight in
          let middle = (left +: right) /: whole 2 in
          let a = value parabola middle zero and b = value straight middle zero in
          if a = b then failwith "the curves do not enclose a region";
          let lower, upper = if less a b then (parabola, straight) else (straight, parabola) in
          iterated (normal f) ~lower ~upper ~from:left ~until:right
      | _ -> failwith "the text is not worded as its kind is")
  | k -> failwith ("unknown kind " ^ k)

let rec range a b = if a > b then [] else a :: range (a + 1) b
let nonzero a b = List.filter (fun n -> n <> 0) (range a b)

(* The values each form's numbers take, all of which must appear. *)
let allowed =
  let sum = [ ("coefficient of x", nonzero (-4) 6); ("coefficient of y", nonzero (-4) 6) ] in
  let monomial = [ ("coefficient", nonzero (-4) 6); ("powers", [ 1; 2; 10; 11; 12; 20; 21; 22 ]) ] in
  [ ( "rectangle_monomial",
      monomial @ [ ("outer lower limit", range 0 1); ("outer width", range 1 2); ("inner upper limit", range 1 3) ] );
    ("rectangle_sum", sum @ [ ("outer upper limit", range 1 3); ("inner upper limit", range 1 3) ]);
    ("inner_variable", sum @ [ ("outer upper limit", range 1 3) ]);
    ("inner_line", monomial @ [ ("outer upper limit", range 1 2); ("slope of the inner limit", range 2 3) ]);
    ( "average",
      [ ("coefficient of x^2", nonzero (-3) 4); ("coefficient of y", nonzero (-4) 5); ("width", range 1 3);
        ("height", range 1 4) ] );
    ("triangle_region", sum @ [ ("corner on the x axis", range 1 4); ("corner on the y axis", range 1 4) ]);
    ("parabola_region", sum @ [ ("slope of the line", range 1 3) ]) ]

let prices =
  [ ("rectangle_monomial", 1); ("rectangle_sum", 1); ("inner_variable", 2); ("inner_line", 2); ("average", 2);
    ("triangle_region", 3); ("parabola_region", 3) ]

(* How often a form is chosen among those of its price: the forms set up
   from a line or from two curves are given twice the weight of the others. *)
let weights =
  [ ("rectangle_monomial", 1); ("rectangle_sum", 1); ("inner_variable", 2); ("inner_line", 2); ("average", 1);
    ("triangle_region", 1); ("parabola_region", 2) ]

let seen : (string, int) Hashtbl.t = Hashtbl.create 8
let times k = Option.value (Hashtbl.find_opt seen k) ~default:0

let check cost seed (q : Rhema_engine.question) =
  let k = kind q and p = q.Rhema_engine.prompt in
  Hashtbl.replace seen k (times k + 1);
  if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d (seed %d)" k cost seed);
  if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
  if q.Rhema_engine.mistakes <> [] then fail (Printf.sprintf "%s: a mistake is listed, and the grammar has none, for %S" k p);
  match (q.Rhema_engine.answer, q.Rhema_engine.answers) with
  | Rhema_engine.Num n, [ _ ] -> (
      let got = fraction n.Rhema_number.numerator n.Rhema_number.denominator in
      (* two parts that cancel are not asked, and one term over a region of
         the first quadrant cannot come to 0 *)
      if got = zero then fail (Printf.sprintf "%s: the answer is 0, for %S" k p);
      match expected q with
      | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
      | want -> if got <> want then fail (Printf.sprintf "%s: answer %s, worked out %s, for %S" k (show got) (show want) p))
  | Rhema_engine.Num _, _ -> fail (Printf.sprintf "%s: not one answer, for %S" k p)
  | other, _ -> fail (Printf.sprintf "%s: not a number: %s" k (Rhema_engine.describe_value other))

let () =
  let base = load_file "double_integral.rhm" in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 2999 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> check cost seed q
    done
  done;
  (* left alone, the budget is 2 *)
  for seed = 0 to 99 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "default budget, seed %d: %s" seed m)
    | q -> check 2 seed q
  done;
  (* no form is offered at any other price *)
  List.iter
    (fun cost ->
      let spec = with_initial base "cost" cost in
      for seed = 0 to 19 do
        Random.init seed;
        match Rhema_engine.generate spec with
        | exception Rhema_engine.Generation_error _ -> ()
        | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
      done)
    [ 0; 4; 5 ];
  List.iter (fun (k, _) -> if times k = 0 then fail ("never generated: " ^ k)) prices;
  (* a form's share of the questions of its price is its share of their
     weights, give or take 7 in a hundred: a question thrown away by a
     `require` moves it a little, and so does chance *)
  List.iter
    (fun (k, price) ->
      let same_price = List.filter (fun (_, other) -> other = price) prices in
      let total over = List.fold_left (fun sum (other, _) -> sum + over other) 0 same_price in
      let share = float (times k) /. float (total times) in
      let due = float (List.assoc k weights) /. float (total (fun other -> List.assoc other weights)) in
      if Float.abs (share -. due) > 0.07 then
        fail (Printf.sprintf "%s is %.0f in a hundred of the questions of price %d, not about %.0f" k (100. *. share) price (100. *. due)))
    prices;
  let list values = String.concat ", " (List.map string_of_int values) in
  List.iter
    (fun (k, names) ->
      List.iter
        (fun (name, values) ->
          let found = List.sort compare (Option.value (Hashtbl.find_opt noted (k, name)) ~default:[]) in
          if found <> values then
            fail (Printf.sprintf "%s: the %s takes the values [%s], not [%s]" k name (list found) (list values)))
        names)
    allowed;
  Hashtbl.iter
    (fun (k, name) _ ->
      match List.assoc_opt k allowed with
      | Some names when List.mem_assoc name names -> ()
      | _ -> fail (Printf.sprintf "%s: the %s was noted and is not looked at" k name))
    noted;
  if !failures = 0 then print_endline "Rhema double integral tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d double integral test(s) failed." !failures);
    exit 1
  end
