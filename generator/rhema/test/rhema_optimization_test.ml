(* Independent checks for optimization.rhm. Nothing here uses the grammar's
   closed formulas. Every question is matched against the whole sentence of
   its form, and the function (and the constraint, where there is one) is
   read back from the printed LaTeX by a small reader of sums of terms in x,
   y and z, which holds a polynomial as a list of terms with exact fractions
   in front. A sum must be written the one way the grammar writes one: a 1 in
   front of a letter, a term with 0 in front, a power 1 or a term out of its
   place is a failure. The answer is then found again from that polynomial
   alone, form by form:

   - discriminant: the polynomial is differentiated term by term, twice, and
     D = f_xx f_yy - (f_xy)^2 is multiplied out as a polynomial, which must
     come to a number (the same at every point). As a second opinion the
     three second derivatives are taken as second differences of the values
     of f round a point that is not the origin. The mistake
     coefficients_for_derivatives is what it says: the numbers in front of
     x^2 and y^2 are put where f_xx and f_yy belong, f_xy as it is.
   - square_completed, quadratic_extreme: both first derivatives are of the
     first degree, and the one point where both vanish is found by Cramer's
     rule and put back into them. The second derivatives there must say
     "minimum" where the least value is asked for and "maximum" where the
     greatest is; the function being of the second degree, that value is
     then the least (greatest) of all. The answer is the value of f at the
     point. Every point of a grid of half steps round it must do strictly
     worse. The header's promises are checked: the point is not the origin,
     it has whole coordinates, and the constant printed is not the answer.
   - cubic_extreme: f_x = 0 is solved for y (f_x must be a polynomial in x
     plus a multiple of y), y is put into f_y, and the whole roots of the
     polynomial in x that comes out are taken out of it one by one; what is
     left must have no real root (a number, or a second-degree polynomial
     with a negative discriminant), so the critical points are all found.
     Each is put back into f_x and f_y and judged by its second derivatives.
     There must be exactly two: one extreme of the kind the text names and
     one saddle. The answer is the value at the extreme; the mistake
     saddle_taken is the value at the saddle. Near the extreme every point
     of a small grid does strictly worse, and near the saddle some do better
     and some worse.
   - product_on_line, squares_on_line, linear_on_circle, product_on_plane:
     the constraint is parametrised (a line by x, over the part where x and
     y are positive when the text says "positive", or else as far out as the
     least value can lie; a circle by its angle; a plane by x and y over the
     triangle where all three are positive) and the extreme value is searched
     for in floating point: a scan, then golden-section refinement (one
     inside the other for the plane). The place found is brought to the
     nearest fractions with small denominators, and there, exactly: the
     constraint holds, the numbers are positive where they must be, and the
     gradients of the function and of the constraint are parallel (the
     Lagrange condition), both gradients taken from the polynomials read.
     The exact value there, which must agree with the value the search
     reached to nine places, is the answer. Then points of the constraint
     with fractions for coordinates are tried, exactly: none beats it.

   The working of this file is itself tried first on a few examples with
   known answers and on sums that are not written as they should be.

   Besides the answers: the mistakes a form declares are listed on each of
   its questions, in the order of their declarations, each with the answer
   found here and each different from the right answer, and a form without
   mistakes lists none; a square on the right of the circle and coefficients
   that are the legs of a right triangle with whole sides are checked as
   properties, not used; the line of squares_on_line does not pass through
   the origin; each kind appears at its price alone and spends its budget; a
   budget outside 1..3 gives no question; the budget the grammar sets itself
   is the middle price; and each printed number of each form takes exactly
   the values the grammar offers, none missing and none more (the answer of
   square_completed and the constant of quadratic_extreme are held to their
   range once for "least" and once for "greatest"). Those ranges are the
   only things taken from the grammar. The weights are not looked at. *)

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
   fractions are the same record. The numbers of these questions are small. *)
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
let less a b = a.top * b.bottom < b.top * a.bottom
let sign a = compare a.top 0
let to_float a = float_of_int a.top /. float_of_int a.bottom
let print a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom
let of_number (n : Rhema_number.t) = ratio n.Rhema_number.numerator n.Rhema_number.denominator
let read = function Rhema_engine.Num n -> Some (of_number n) | _ -> None

(* A whole number that is a perfect square has a whole square root. *)
let square_root n =
  let rec up r = if r * r >= n then r else up (r + 1) in
  let r = up 0 in
  if n >= 0 && r * r = n then Some r else None

(* ---- Polynomials in x, y and z ------------------------------------------- *)

(* A term is a fraction in front of x^i y^j z^k, held with (i, j, k). A
   polynomial is its terms in one fixed order, none with 0 in front and no
   two with the same powers, so that equal polynomials are equal lists. *)
type powers = int * int * int
type polynomial = (powers * fraction) list

let unit : powers = (0, 0, 0)
let x1 : powers = (1, 0, 0)
let y1 : powers = (0, 1, 0)
let z1 : powers = (0, 0, 1)
let xy : powers = (1, 1, 0)
let x2 : powers = (2, 0, 0)
let y2 : powers = (0, 2, 0)
let x3 : powers = (3, 0, 0)
let y3 : powers = (0, 3, 0)
let xyz : powers = (1, 1, 1)

let normal (terms : polynomial) : polynomial =
  let rec merged = function
    | (m, a) :: (n, b) :: rest when m = n -> merged ((m, a +/ b) :: rest)
    | (m, a) :: rest -> if a = zero then merged rest else (m, a) :: merged rest
    | [] -> []
  in
  merged (List.sort (fun (m, _) (n, _) -> compare n m) terms)

let plus (p : polynomial) (q : polynomial) = normal (p @ q)
let scaled c (p : polynomial) = normal (List.map (fun (m, a) -> (m, c */ a)) p)

let times (p : polynomial) (q : polynomial) =
  normal (List.concat_map (fun ((i, j, k), a) -> List.map (fun ((l, m, n), b) -> ((i + l, j + m, k + n), a */ b)) q) p)

let minus p q = plus p (scaled (whole (-1)) q)

(* The derivative in one of the letters, term by term. *)
let derivative letter (p : polynomial) =
  normal
    (List.filter_map
       (fun ((i, j, k), a) ->
         match letter with
         | 'x' -> if i = 0 then None else Some ((i - 1, j, k), whole i */ a)
         | 'y' -> if j = 0 then None else Some ((i, j - 1, k), whole j */ a)
         | 'z' -> if k = 0 then None else Some ((i, j, k - 1), whole k */ a)
         | _ -> failwith "a letter that is not x, y or z")
       p)

let rec power a n = if n = 0 then one else a */ power a (n - 1)

let value_at (p : polynomial) (x, y, z) =
  List.fold_left (fun sum ((i, j, k), a) -> sum +/ (a */ power x i */ power y j */ power z k)) zero p

let rec float_power a n = if n = 0 then 1.0 else a *. float_power a (n - 1)

let float_at (p : polynomial) (x, y, z) =
  List.fold_left
    (fun sum ((i, j, k), a) -> sum +. (to_float a *. float_power x i *. float_power y j *. float_power z k))
    0.0 p

let coefficient (p : polynomial) (m : powers) = Option.value ~default:zero (List.assoc_opt m p)

(* The number a polynomial comes to, when it has no letter left. *)
let number (p : polynomial) =
  match p with
  | [] -> zero
  | [ (m, a) ] when m = unit -> a
  | _ -> failwith "a polynomial that should be a number still has a letter in it"

(* ---- Reading a printed sum of terms --------------------------------------- *)

(* A whole number, written the one way it is written. *)
let integer text =
  match int_of_string_opt text with
  | Some n when string_of_int n = text -> n
  | _ -> failwith ("not a whole number: " ^ text)

(* A sum as the grammar prints one: the first term with a bare minus sign if
   it is negative, the others joined with " + " and " - "; a 1 is not written
   in front of a letter, a power 1 is not written, the letters come in the
   order x, y, z. *)
let written terms =
  String.concat ""
    (List.mapi
       (fun n (c, (i, j, k)) ->
         let letter name power =
           if power = 0 then "" else if power = 1 then name else Printf.sprintf "%s^{%d}" name power
         in
         let letters = letter "x" i ^ letter "y" j ^ letter "z" k in
         (if n = 0 then if c < 0 then "-" else "" else if c < 0 then " - " else " + ")
         ^ (if abs c = 1 && letters <> "" then "" else string_of_int (abs c))
         ^ letters)
       terms)

(* The terms of a printed sum, in the order printed: the whole number in
   front and the powers. Whatever is read must print back as the same text. *)
let terms_of text : (int * powers) list =
  let length = String.length text in
  let position = ref 0 in
  let next () = if !position < length then Some text.[!position] else None in
  let digits () =
    let start = !position in
    while match next () with Some '0' .. '9' -> true | _ -> false do
      incr position
    done;
    String.sub text start (!position - start)
  in
  let letter name =
    if next () <> Some name then 0
    else begin
      incr position;
      if !position + 1 < length && text.[!position] = '^' && text.[!position + 1] = '{' then begin
        position := !position + 2;
        let n = integer (digits ()) in
        if next () <> Some '}' then failwith ("a power is not closed in: " ^ text);
        incr position;
        n
      end
      else 1
    end
  in
  let term sign =
    let before = digits () in
    let i = letter 'x' in
    let j = letter 'y' in
    let k = letter 'z' in
    if before = "" && (i, j, k) = unit then failwith ("a term is missing in: " ^ text);
    ((if before = "" then sign else sign * integer before), (i, j, k))
  in
  let first_sign =
    if next () = Some '-' then begin
      incr position;
      -1
    end
    else 1
  in
  let first = term first_sign in
  let rec others () =
    if !position = length then []
    else if !position + 3 <= length && List.mem (String.sub text !position 3) [ " + "; " - " ] then begin
      let sign = if text.[!position + 1] = '+' then 1 else -1 in
      position := !position + 3;
      let this = term sign in
      this :: others ()
    end
    else failwith ("not a sum of terms: " ^ text)
  in
  let terms = first :: others () in
  if List.exists (fun (c, _) -> c = 0) terms then failwith ("a term with 0 in front in: " ^ text);
  if written terms <> text then failwith ("a sum that is not written as one is: " ^ text);
  terms

(* The powers found follow the order expected, each at most once, and none
   that must be there is left out. *)
let rec follows expected found =
  match (expected, found) with
  | _, [] -> List.for_all (fun (_, needed) -> not needed) expected
  | [], _ :: _ -> false
  | (m, needed) :: rest, f :: others -> if m = f then follows rest others else (not needed) && follows rest found

(* A printed sum as a polynomial; `expected` says which terms it may have, in
   their order, and which of them it must have. *)
let polynomial_of expected text : polynomial =
  let terms = terms_of text in
  if not (follows expected (List.map snd terms)) then
    failwith ("the terms are not those of this form, in their order: " ^ text);
  normal (List.map (fun (c, m) -> (m, whole c)) terms)

(* The whole number a coefficient is. *)
let whole_of a = if a.bottom = 1 then a.top else failwith ("not a whole number: " ^ print a)

(* ---- Critical points ------------------------------------------------------ *)

type nature = Lowest | Highest | Saddle

(* What the second derivatives say of a critical point of f(x, y). *)
let nature f point =
  let fx = derivative 'x' f and fy = derivative 'y' f in
  let fxx = value_at (derivative 'x' fx) point and fyy = value_at (derivative 'y' fy) point in
  let fxy = value_at (derivative 'y' fx) point in
  let d = (fxx */ fyy) -/ (fxy */ fxy) in
  if sign d < 0 then Saddle
  else if sign d = 0 then failwith "the second-derivative test says nothing at a critical point"
  else if sign fxx > 0 then Lowest
  else Highest

let both_vanish f (x, y) =
  value_at (derivative 'x' f) (x, y, zero) = zero && value_at (derivative 'y' f) (x, y, zero) = zero

(* a x + b y + c, for a polynomial of the first degree in x and y. *)
let first_degree p =
  if List.exists (fun (m, _) -> not (List.mem m [ x1; y1; unit ])) p then
    failwith "a first derivative is not of the first degree";
  (coefficient p x1, coefficient p y1, coefficient p unit)

(* The one point where both first derivatives of a polynomial of the second
   degree vanish, by Cramer's rule. *)
let only_critical_point f =
  let a, b, c = first_degree (derivative 'x' f) and d, e, g = first_degree (derivative 'y' f) in
  let det = (a */ e) -/ (b */ d) in
  if det = zero then failwith "the first derivatives do not vanish at one point alone";
  let point = (((b */ g) -/ (c */ e)) // det, ((c */ d) -/ (a */ g)) // det) in
  if not (both_vanish f point) then failwith "the derivatives do not vanish at the point found";
  point

(* A polynomial in one letter, as its coefficients from the highest power
   down: its value, and its quotient by x - r when r is a root. *)
let evaluate coefficients x = List.fold_left (fun sum c -> (sum */ x) +/ c) zero coefficients

let divided coefficients r =
  let rec go carried = function
    | [] | [ _ ] -> []
    | c :: rest ->
        let carried = (carried */ r) +/ c in
        carried :: go carried rest
  in
  go zero coefficients

(* Every critical point of an f(x, y) whose derivative in x is a polynomial
   in x plus a multiple of y. On f_x = 0, y is that polynomial over minus the
   multiple; put into f_y it leaves a polynomial in x alone, whose whole
   roots are taken out one by one. What is left must have no real root. *)
let critical_points f =
  let fx = derivative 'x' f and fy = derivative 'y' f in
  let m = coefficient fx y1 in
  let u = List.filter (fun (powers, _) -> powers <> y1) fx in
  if m = zero || List.exists (fun ((_, j, k), _) -> j <> 0 || k <> 0) u then
    failwith "f_x = 0 does not give y in terms of x";
  let y_of_x = scaled (whole (-1) // m) u in
  let rec raised p n = if n = 0 then [ (unit, one) ] else times p (raised p (n - 1)) in
  let in_x_alone =
    List.fold_left (fun sum ((i, j, _), a) -> plus sum (scaled a (times [ ((i, 0, 0), one) ] (raised y_of_x j)))) [] fy
  in
  if in_x_alone = [] then failwith "f_y vanishes wherever f_x does";
  let degree = List.fold_left (fun most ((i, _, _), _) -> max most i) 0 in_x_alone in
  let coefficients = List.init (degree + 1) (fun n -> coefficient in_x_alone (degree - n, 0, 0)) in
  let rec taken_out left roots = function
    | [] -> (left, roots)
    | r :: rest as candidates ->
        if List.length left > 1 && evaluate left r = zero then
          taken_out (divided left r) (if List.mem r roots then roots else r :: roots) candidates
        else taken_out left roots rest
  in
  let left, roots = taken_out coefficients [] (List.init 81 (fun n -> whole (n - 40))) in
  (match left with
   | [ _ ] -> ()
   | [ a; b; c ] when sign ((b */ b) -/ (whole 4 */ a */ c)) < 0 -> ()
   | _ -> failwith "the critical points cannot all be found: what is left of f_y may have a real root");
  List.map
    (fun x ->
      let y = value_at y_of_x (x, zero, zero) in
      if not (both_vanish f (x, y)) then failwith "the derivatives do not vanish at a point found";
      (x, y))
    (List.sort compare roots)

(* The values of f at the points of a grid round a point, the point itself
   left out: steps of 1/parts, `reach` of them each way. *)
let values_round f (x, y) ~parts ~reach =
  let offsets = List.init ((2 * reach) + 1) (fun n -> n - reach) in
  List.concat_map
    (fun i ->
      List.filter_map
        (fun j -> if i = 0 && j = 0 then None else Some (value_at f (x +/ ratio i parts, y +/ ratio j parts, zero)))
        offsets)
    offsets

(* ---- Extreme values under a constraint ------------------------------------ *)

let golden = (sqrt 5.0 -. 1.0) /. 2.0

(* Where g is greatest on [low, high], in floating point: the best of a scan
   in equal steps, then golden-section refinement between its neighbours. *)
let place_of_greatest ?(steps = 360) g low high =
  let at i = low +. ((high -. low) *. float_of_int i /. float_of_int steps) in
  let best = ref 0 and best_value = ref (g low) in
  for i = 1 to steps do
    let v = g (at i) in
    if v > !best_value then begin
      best := i;
      best_value := v
    end
  done;
  let a = ref (at (max 0 (!best - 1))) and b = ref (at (min steps (!best + 1))) in
  for _ = 1 to 60 do
    let c = !b -. (golden *. (!b -. !a)) and d = !a +. (golden *. (!b -. !a)) in
    if g c > g d then b := d else a := c
  done;
  (!a +. !b) /. 2.0

(* The fraction with a denominator up to 100 that a place found by the search
   stands for. Two such fractions are at least 1/10000 apart, so there is at
   most one within 1/100000. *)
let nearest_fraction v =
  let rec from q =
    if q > 100 then failwith (Printf.sprintf "the place found, %.9f, is not at a fraction with a small denominator" v)
    else
      let p = Float.round (v *. float_of_int q) in
      if Float.abs (v -. (p /. float_of_int q)) < 1e-5 then ratio (int_of_float p) q else from (q + 1)
  in
  from 1

(* The Lagrange condition at a point: the gradients of f and of g, in the
   letters given, are parallel there. *)
let gradients_parallel f g point letters =
  let gradient p = List.map (fun letter -> value_at (derivative letter p) point) letters in
  let of_f = gradient f and of_g = gradient g in
  if List.for_all (fun part -> part = zero) of_g then failwith "the gradient of the constraint vanishes at the place found";
  let rec pairs = function [] -> [] | first :: rest -> List.map (fun other -> (first, other)) rest @ pairs rest in
  List.for_all (fun ((a, b), (c, d)) -> (a */ d) -/ (b */ c) = zero) (pairs (List.combine of_f of_g))

let must_be_parallel f g point letters =
  if not (gradients_parallel f g point letters) then failwith "the Lagrange condition does not hold at the place found"

(* The exact value at the place found is the value the search reached. *)
let agree exact reached =
  if Float.abs (to_float exact -. reached) > 1e-9 *. Float.max 1.0 (Float.abs reached) then
    failwith (Printf.sprintf "the search reached %.12g, but the value at the place found is %s" reached (print exact))

let show_point (x, y, z) = Printf.sprintf "(%s, %s, %s)" (print x) (print y) (print z)

(* None of the points beats the value `best`, taken at `at`, and no other of
   them reaches it. *)
let none_beats ~greatest f best at points =
  List.iter
    (fun point ->
      let v = value_at f point in
      if if greatest then less best v else less v best then
        failwith (Printf.sprintf "the point %s gives %s, which beats %s" (show_point point) (print v) (print best));
      if v = best && point <> at then
        failwith (Printf.sprintf "the point %s gives %s too" (show_point point) (print best)))
    points

(* The greatest (or least) value of f(x, y) on the line g = c, for x between
   low and high. *)
let extreme_on_line ~greatest ~positive f g c (low, high) =
  let p = coefficient g x1 and q = coefficient g y1 in
  let y_of x = (c -/ (p */ x)) // q in
  let turn = if greatest then 1.0 else -1.0 in
  let along x = turn *. float_at f (x, (to_float c -. (to_float p *. x)) /. to_float q, 0.0) in
  let found = place_of_greatest along low high in
  let x = nearest_fraction found in
  let point = (x, y_of x, zero) in
  if positive && not (sign x > 0 && sign (y_of x) > 0) then failwith "the extreme value is not taken at positive numbers";
  must_be_parallel f g point [ 'x'; 'y' ];
  let best = value_at f point in
  agree best (turn *. along found);
  (best, point)

(* The greatest (or least) value of f(x, y) on the circle g = level, where g
   is x^2 + y^2, by the angle. The scan goes a little more than once round. *)
let extreme_on_circle ~greatest f g level =
  let radius = sqrt (float_of_int level) in
  let turn = if greatest then 1.0 else -1.0 in
  let round t = turn *. float_at f (radius *. cos t, radius *. sin t, 0.0) in
  let found = place_of_greatest round 0.0 7.0 in
  let point = (nearest_fraction (radius *. cos found), nearest_fraction (radius *. sin found), zero) in
  if value_at g point <> whole level then failwith "the place found is not on the circle";
  must_be_parallel f g point [ 'x'; 'y' ];
  let best = value_at f point in
  agree best (turn *. round found);
  (best, point)

(* The greatest value of f(x, y, z) on the part of the plane g = c where the
   three numbers are positive, g having positive coefficients: x and y run
   over a triangle, one golden-section search inside the other. *)
let greatest_on_plane f g c =
  let p = coefficient g x1 and q = coefficient g y1 and r = coefficient g z1 in
  let pf = to_float p and qf = to_float q and rf = to_float r and level = to_float c in
  let product x y = float_at f (x, y, (level -. (pf *. x) -. (qf *. y)) /. rf) in
  let best_y x = place_of_greatest ~steps:24 (product x) 0.0 ((level -. (pf *. x)) /. qf) in
  let found_x = place_of_greatest ~steps:24 (fun x -> product x (best_y x)) 0.0 (level /. pf) in
  let found_y = best_y found_x in
  let x = nearest_fraction found_x and y = nearest_fraction found_y in
  let z = (c -/ (p */ x) -/ (q */ y)) // r in
  let point = (x, y, z) in
  if not (sign x > 0 && sign y > 0 && sign z > 0) then failwith "the greatest value is not taken at positive numbers";
  must_be_parallel f g point [ 'x'; 'y'; 'z' ];
  let best = value_at f point in
  agree best (product found_x found_y);
  (best, point)

(* ---- Reading a question ---------------------------------------------------- *)

let words = Str.quote

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* A sum of terms, as a group, and a whole number, as a group. *)
let a_sum = "\\([^`=]*\\)"
let a_number = "\\(-?[0-9]+\\)"

(* What was generated besides the kinds: each choice the grammar offers. *)
let noted : (string, string list) Hashtbl.t = Hashtbl.create 64

let note topic choice =
  let so_far = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
  if not (List.mem choice so_far) then Hashtbl.replace noted topic (choice :: so_far)

let note_number topic n = note topic (string_of_int n)
let note_coefficient topic f m = note_number topic (whole_of (coefficient f m))

(* ---- Price 1 ---------------------------------------------------------------- *)

let discriminant_sentence =
  words "For [`f(x, y) = " ^ a_sum
  ^ words "`], find [`D = f_{xx} f_{yy} - (f_{xy})^{2}`], the number that the second-derivative test looks at."

let examine_discriminant prompt =
  match fields 1 discriminant_sentence prompt with
  | [ body ] ->
      let f = polynomial_of [ (x2, true); (xy, true); (y2, true); (x1, false); (y1, false) ] body in
      let fx = derivative 'x' f and fy = derivative 'y' f in
      let fxx = derivative 'x' fx and fyy = derivative 'y' fy and fxy = derivative 'y' fx in
      if derivative 'x' fy <> fxy then failwith "the two mixed derivatives differ";
      (* multiplied out, D has no letter left: it is the same at every point *)
      let d = number (minus (times fxx fyy) (times fxy fxy)) in
      (* the same from second differences of the values of f round (2, -3) *)
      let at i j = value_at f (whole (2 + i), whole (j - 3), zero) in
      let by_x = at 1 0 -/ (whole 2 */ at 0 0) +/ at (-1) 0 and by_y = at 0 1 -/ (whole 2 */ at 0 0) +/ at 0 (-1) in
      let mixed = (at 1 1 -/ at 1 (-1) -/ at (-1) 1 +/ at (-1) (-1)) // whole 4 in
      if (by_x */ by_y) -/ (mixed */ mixed) <> d then failwith "the second differences of f give another number";
      (* the mistake: the numbers in front of x^2 and y^2 where f_xx and f_yy belong *)
      let slip = (coefficient f x2 */ coefficient f y2) -/ (number fxy */ number fxy) in
      note_coefficient "discriminant: before x^2" f x2;
      note_coefficient "discriminant: before xy" f xy;
      note_coefficient "discriminant: before y^2" f y2;
      note_coefficient "discriminant: before x" f x1;
      note_coefficient "discriminant: before y" f y1;
      (d, [ ("coefficients_for_derivatives", slip) ])
  | _ -> failwith "one field was expected"

let value_sentence = words "Find the " ^ "\\(least\\|greatest\\)" ^ words " value of [`f(x, y) = " ^ a_sum ^ words "`]."

(* The two forms that ask for the least or greatest value of a quadratic. *)
let examine_quadratic k prompt =
  match fields 2 value_sentence prompt with
  | [ word; body ] ->
      let greatest = word = "greatest" in
      let with_xy = k = "quadratic_extreme" in
      let f =
        polynomial_of
          ([ (x2, true) ] @ (if with_xy then [ (xy, true) ] else [])
          @ [ (y2, true); (x1, false); (y1, false); (unit, false) ])
          body
      in
      let ((h, v) as point) = only_critical_point f in
      (match (nature f (h, v, zero), greatest) with
       | Lowest, false | Highest, true -> ()
       | Saddle, _ -> failwith "the critical point is a saddle: there is no least or greatest value"
       | _ -> failwith ("the function has no " ^ word ^ " value"));
      let best = value_at f (h, v, zero) in
      List.iter
        (fun other ->
          if not (if greatest then less other best else less best other) then
            failwith (Printf.sprintf "a point near the critical point gives %s, no worse than %s" (print other) (print best)))
        (values_round f point ~parts:2 ~reach:6);
      (* the header's promises *)
      if point = (zero, zero) then failwith "the critical point is the origin";
      if best = coefficient f unit then failwith "the constant printed is the answer";
      let turn = if greatest then -1 else 1 in
      note (k ^ ": asks for the") word;
      note_number (k ^ ": critical x") (whole_of h);
      note_number (k ^ ": critical y") (whole_of v);
      if with_xy then begin
        (* the second-degree part, with every sign turned over where the
           greatest value is asked for *)
        let a = turn * whole_of (coefficient f x2) and b = turn * whole_of (coefficient f xy) in
        let c = turn * whole_of (coefficient f y2) in
        note (k ^ ": second-degree part") (Printf.sprintf "%d, %d, %d" a (abs b) c);
        note_number (k ^ ": before xy") b;
        note_coefficient (k ^ ": constant, with the " ^ word ^ " value asked for") f unit
      end
      else begin
        note_number (k ^ ": before x^2") (turn * whole_of (coefficient f x2));
        note_number (k ^ ": before y^2") (turn * whole_of (coefficient f y2));
        note_number (k ^ ": the " ^ word ^ " value") (whole_of best)
      end;
      (best, [])
  | _ -> failwith "two fields were expected"

(* ---- Price 2 ---------------------------------------------------------------- *)

let product_on_line_sentence =
  words "Find the greatest value of [`" ^ a_sum ^ words "`] for positive numbers [`x`] and [`y`] with [`" ^ a_sum
  ^ " = " ^ a_number ^ words "`]."

let examine_product_on_line prompt =
  match fields 3 product_on_line_sentence prompt with
  | [ objective; left; right ] ->
      let f = polynomial_of [ (xy, true) ] objective in
      if f <> [ (xy, one) ] then failwith "the product is not x y";
      let g = polynomial_of [ (x1, true); (y1, true) ] left and c = whole (integer right) in
      let p = coefficient g x1 and q = coefficient g y1 in
      (* positive coefficients and a positive right side: the positive
         points of the line are a segment, with x between 0 and c / p *)
      if not (sign p > 0 && sign q > 0 && sign c > 0) then failwith "the positive points of the line are not a segment";
      let best, at = extreme_on_line ~greatest:true ~positive:true f g c (0.0, to_float (c // p)) in
      none_beats ~greatest:true f best at
        (List.init 59 (fun n ->
             let x = (c // p) */ ratio (n + 1) 60 in
             (x, (c -/ (p */ x)) // q, zero)));
      note_coefficient "product_on_line: before x" g x1;
      note_coefficient "product_on_line: before y" g y1;
      note_number "product_on_line: equals" (whole_of c);
      (best, [])
  | _ -> failwith "three fields were expected"

let squares_on_line_sentence =
  words "Find the least value of [`" ^ a_sum ^ words "`] for numbers [`x`] and [`y`] with [`" ^ a_sum ^ " = " ^ a_number
  ^ words "`]."

let squares = normal [ (x2, one); (y2, one) ]

let examine_squares_on_line prompt =
  match fields 3 squares_on_line_sentence prompt with
  | [ objective; left; right ] ->
      let f = polynomial_of [ (x2, true); (y2, true) ] objective in
      if f <> squares then failwith "the sum of squares is not x^2 + y^2";
      let g = polynomial_of [ (x1, true); (y1, true) ] left and c = whole (integer right) in
      let p = coefficient g x1 and q = coefficient g y1 in
      if c = zero then failwith "the line passes through the origin";
      (* the line meets the y-axis at (0, c / q); a point with x further out
         than |c / q| has x^2 alone above the value there *)
      let reach = Float.abs (to_float (c // q)) in
      let best, ((x, _, _) as at) = extreme_on_line ~greatest:false ~positive:false f g c (-.reach, reach) in
      none_beats ~greatest:false f best at
        (List.init 81 (fun n ->
             let x = x +/ ratio (n - 40) 4 in
             (x, (c -/ (p */ x)) // q, zero)));
      note_coefficient "squares_on_line: before x" g x1;
      note_coefficient "squares_on_line: before y" g y1;
      note_number "squares_on_line: equals" (whole_of c);
      (best, [])
  | _ -> failwith "three fields were expected"

(* ---- Price 3 ---------------------------------------------------------------- *)

let linear_on_circle_sentence =
  words "Find the " ^ "\\(greatest\\|least\\)" ^ words " value of [`" ^ a_sum ^ words "`] on the circle [`" ^ a_sum ^ " = "
  ^ a_number ^ words "`]."

let examine_linear_on_circle prompt =
  match fields 4 linear_on_circle_sentence prompt with
  | [ word; objective; left; right ] ->
      let greatest = word = "greatest" in
      let f = polynomial_of [ (x1, true); (y1, true) ] objective in
      let g = polynomial_of [ (x2, true); (y2, true) ] left and level = integer right in
      if g <> squares then failwith "the circle is not x^2 + y^2 = a number";
      if level <= 0 then failwith "the circle has no points";
      let best, at = extreme_on_circle ~greatest f g level in
      (* properties the header gives, not used for the answer: the right
         side is the square of a whole radius, and the coefficients are the
         legs of a right triangle with whole sides *)
      let a = whole_of (coefficient f x1) and b = whole_of (coefficient f y1) in
      if square_root ((a * a) + (b * b)) = None then failwith "the coefficients are not the legs of a right triangle with whole sides";
      (match square_root level with
       | None -> failwith "the right side of the circle is not a square"
       | Some radius ->
           (* points of the circle with fractions for coordinates *)
           let r = whole radius in
           none_beats ~greatest f best at
             ((zero -/ r, zero, zero)
             :: List.init 61 (fun n ->
                    let t = ratio (n - 30) 6 in
                    let bottom = one +/ (t */ t) in
                    ((r */ (one -/ (t */ t))) // bottom, (whole 2 */ r */ t) // bottom, zero)));
           note_number "linear_on_circle: radius" radius);
      note "linear_on_circle: asks for the" word;
      note "linear_on_circle: legs" (Printf.sprintf "%d, %d" (abs a) (abs b));
      note "linear_on_circle: signs" (Printf.sprintf "%d, %d" (compare a 0) (compare b 0));
      (best, [])
  | _ -> failwith "four fields were expected"

let cubic_sentence =
  words "The function [`f(x, y) = " ^ a_sum ^ words "`] has one local " ^ "\\(minimum\\|maximum\\)"
  ^ words ". Find the value of [`f`] there."

let examine_cubic prompt =
  match fields 2 cubic_sentence prompt with
  | [ body; word ] ->
      let f = polynomial_of [ (x3, true); (y3, true); (xy, true); (unit, false) ] body in
      let wanted = if word = "minimum" then Lowest else Highest in
      let judged = List.map (fun (x, y) -> ((x, y), nature f (x, y, zero))) (critical_points f) in
      let of_nature which = List.filter_map (fun (point, found) -> if found = which then Some point else None) judged in
      let extreme =
        match (of_nature Lowest, of_nature Highest) with
        | [ point ], [] when wanted = Lowest -> point
        | [], [ point ] when wanted = Highest -> point
        | _ -> failwith ("the function does not have one local extreme, a " ^ word)
      in
      let saddle =
        match of_nature Saddle with
        | [ point ] -> point
        | _ -> failwith "the function does not have one saddle point"
      in
      if List.length judged <> 2 then failwith "the function does not have two critical points";
      let value (x, y) = value_at f (x, y, zero) in
      let best = value extreme in
      (* near the extreme every point does worse; near the saddle some do
         better and some worse *)
      let better other than = if wanted = Lowest then less other than else less than other in
      if not (List.for_all (fun other -> better best other) (values_round f extreme ~parts:8 ~reach:2)) then
        failwith "a point near the extreme does no worse";
      let near_saddle = values_round f saddle ~parts:8 ~reach:2 in
      if not (List.exists (fun other -> less other (value saddle)) near_saddle
              && List.exists (fun other -> less (value saddle) other) near_saddle) then
        failwith "the saddle is not one";
      note_coefficient "cubic_extreme: before xy" f xy;
      note_coefficient "cubic_extreme: constant" f unit;
      note "cubic_extreme: has one local" word;
      (best, [ ("saddle_taken", value saddle) ])
  | _ -> failwith "two fields were expected"

let product_on_plane_sentence =
  words "Find the greatest value of [`" ^ a_sum ^ words "`] for positive numbers [`x`], [`y`] and [`z`] with [`" ^ a_sum
  ^ " = " ^ a_number ^ words "`]."

let examine_product_on_plane prompt =
  match fields 3 product_on_plane_sentence prompt with
  | [ objective; left; right ] ->
      let f = polynomial_of [ (xyz, true) ] objective in
      if f <> [ (xyz, one) ] then failwith "the product is not x y z";
      let g = polynomial_of [ (x1, true); (y1, true); (z1, true) ] left and c = whole (integer right) in
      let p = coefficient g x1 and q = coefficient g y1 and r = coefficient g z1 in
      if not (sign p > 0 && sign q > 0 && sign r > 0 && sign c > 0) then
        failwith "the positive points of the plane are not a triangle";
      let best, at = greatest_on_plane f g c in
      let parts = 18 in
      none_beats ~greatest:true f best at
        (List.concat
           (List.init (parts - 1) (fun i ->
                List.init (parts - 2 - i) (fun j ->
                    let x = (c // p) */ ratio (i + 1) parts and y = (c // q) */ ratio (j + 1) parts in
                    (x, y, (c -/ (p */ x) -/ (q */ y)) // r)))));
      note_coefficient "product_on_plane: before x" g x1;
      note_coefficient "product_on_plane: before y" g y1;
      note_coefficient "product_on_plane: before z" g z1;
      note_number "product_on_plane: equals" (whole_of c);
      (best, [])
  | _ -> failwith "three fields were expected"

(* The right answer of a question and the answer of each mistake its form
   declares, found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let prompt = q.Rhema_engine.prompt in
  match kind q with
  | "discriminant" -> examine_discriminant prompt
  | ("square_completed" | "quadratic_extreme") as k -> examine_quadratic k prompt
  | "product_on_line" -> examine_product_on_line prompt
  | "squares_on_line" -> examine_squares_on_line prompt
  | "linear_on_circle" -> examine_linear_on_circle prompt
  | "cubic_extreme" -> examine_cubic prompt
  | "product_on_plane" -> examine_product_on_plane prompt
  | k -> failwith ("unknown kind " ^ k)

(* ---- The working of this file, tried on examples --------------------------- *)

let trials () =
  let expect name condition = if not condition then fail ("trial: " ^ name) in
  let refused work = match work () with _ -> false | exception Failure _ -> true in
  List.iter
    (fun text -> expect ("this sum should be refused: " ^ text) (refused (fun () -> terms_of text)))
    [ "1x + y"; "x + 0y"; "x^{1} + y"; "x +2y"; "x + - 2y"; "+ x"; "yx"; "02x"; ""; "x + "; "x^{2"; "x^{}"; "x - -y" ];
  expect "a sum is read"
    (terms_of "-x^{2} + 2xy - 3y^{2} - 8x + 12y + 7" = [ (-1, x2); (2, xy); (-3, y2); (-8, x1); (12, y1); (7, unit) ]);
  let quadratic = [ (x2, true); (xy, false); (y2, true); (x1, false); (y1, false); (unit, false) ] in
  expect "a term out of its place is refused" (refused (fun () -> polynomial_of quadratic "x^{2} + y^{2} + 3y - 2x"));
  expect "a term left out is refused" (refused (fun () -> polynomial_of quadratic "x^{2} - 2x"));
  expect "a term given twice is refused" (refused (fun () -> polynomial_of quadratic "x^{2} + y^{2} + x + x"));
  (* (x - 1)^2 + (y - 2)^2 + 2 *)
  let bowl = polynomial_of quadratic "x^{2} + y^{2} - 2x - 4y + 7" in
  expect "the lowest point of a bowl" (only_critical_point bowl = (whole 1, whole 2));
  expect "a bowl has a lowest point" (nature bowl (whole 1, whole 2, zero) = Lowest);
  expect "the least value of a bowl" (value_at bowl (whole 1, whole 2, zero) = whole 2);
  expect "x^2 - y^2 has a saddle" (nature (polynomial_of quadratic "x^{2} - y^{2}") (zero, zero, zero) = Saddle);
  expect "x^2 + 2xy + y^2 has no one critical point"
    (refused (fun () -> only_critical_point (polynomial_of quadratic "x^{2} + 2xy + y^{2}")));
  (* x^3 + y^3 - 3xy: a saddle at the origin, and the least value -1 nearby at (1, 1) *)
  let folium = polynomial_of [ (x3, true); (y3, true); (xy, true); (unit, false) ] "x^{3} + y^{3} - 3xy" in
  expect "the critical points of x^3 + y^3 - 3xy" (critical_points folium = [ (zero, zero); (one, one) ]);
  expect "its saddle" (nature folium (zero, zero, zero) = Saddle);
  expect "its minimum" (nature folium (one, one, zero) = Lowest && value_at folium (one, one, zero) = whole (-1));
  (* x^3 + y^3 - 2xy has a critical point at (2/3, 2/3), which the whole roots miss *)
  expect "critical points that are not all found are refused"
    (refused (fun () -> critical_points (polynomial_of [ (x3, true); (y3, true); (xy, true) ] "x^{3} + y^{3} - 2xy")));
  expect "x^3 + y^2 - 3x cannot be solved for y"
    (refused (fun () -> critical_points (normal [ (x3, one); (y2, one); (x1, whole (-3)) ])));
  (* constraints *)
  let line = normal [ (x1, one); (y1, one) ] in
  expect "x y on x + y = 2"
    (extreme_on_line ~greatest:true ~positive:true [ (xy, one) ] line (whole 2) (0.0, 2.0) = (one, (one, one, zero)));
  expect "x^2 + y^2 on x + y = 2"
    (extreme_on_line ~greatest:false ~positive:false squares line (whole 2) (-2.0, 2.0) = (whole 2, (one, one, zero)));
  expect "x y has no least value on x + y = 2 at positive numbers"
    (refused (fun () -> extreme_on_line ~greatest:false ~positive:true [ (xy, one) ] line (whole 2) (0.0, 2.0)));
  let slope = normal [ (x1, whole 3); (y1, whole 4) ] in
  expect "3x + 4y on the unit circle, greatest"
    (extreme_on_circle ~greatest:true slope squares 1 = (whole 5, (ratio 3 5, ratio 4 5, zero)));
  expect "3x + 4y on the unit circle, least"
    (extreme_on_circle ~greatest:false slope squares 1 = (whole (-5), (ratio (-3) 5, ratio (-4) 5, zero)));
  expect "x + y on the circle of radius 2 is not extreme at fractions"
    (refused (fun () -> extreme_on_circle ~greatest:true line squares 4));
  expect "x y z on x + y + z = 3"
    (greatest_on_plane [ (xyz, one) ] (normal [ (x1, one); (y1, one); (z1, one) ]) (whole 3) = (one, (one, one, one)));
  expect "x y z on x + 2y + 3z = 6"
    (greatest_on_plane [ (xyz, one) ] (normal [ (x1, one); (y1, whole 2); (z1, whole 3) ]) (whole 6)
     = (ratio 4 3, (whole 2, one, ratio 2 3)));
  expect "the Lagrange condition fails away from the extreme"
    (not (gradients_parallel [ (xy, one) ] line (ratio 1 2, ratio 3 2, zero) [ 'x'; 'y' ]));
  expect "a point that beats the value is noticed"
    (refused (fun () -> none_beats ~greatest:true [ (xy, one) ] (ratio 3 4) (ratio 1 2, ratio 3 2, zero) [ (one, one, zero) ]))

(* ---- The questions ----------------------------------------------------------- *)

let questions_at_each_budget = 3000

(* What a mistake's description must say. *)
let said =
  [ ("coefficients_for_derivatives", [ "coefficients of x^2 and y^2"; "second derivatives"; "twice as large" ]);
    ("saddle_taken", [ "saddle point"; "local extreme value" ]) ]

let () =
  trials ();
  let base = load_file "optimization.rhm" in
  let prices =
    [ ("discriminant", 1); ("square_completed", 1); ("quadratic_extreme", 2); ("product_on_line", 2);
      ("squares_on_line", 2); ("linear_on_circle", 3); ("cubic_extreme", 3); ("product_on_plane", 3) ]
  in
  let seen = Hashtbl.create 8 and generated = Hashtbl.create 4 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at_each_budget - 1 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          Hashtbl.replace generated cost (1 + Option.value ~default:0 (Hashtbl.find_opt generated cost));
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          (match Rhema_engine.attribute q.Rhema_engine.tree "text" with
           | Rhema_engine.Text t when t = p -> ()
           | _ -> fail (Printf.sprintf "%s: the prompt is not the text of the question, for %S" k p));
          match q.Rhema_engine.answers with
          | [] | _ :: _ :: _ -> fail (Printf.sprintf "%s: one answer was expected for %S" k p)
          | [ answer ] -> (
              match read answer with
              | None -> fail (Printf.sprintf "%s: the answer is not a number, for %S" k p)
              | Some got -> (
                  match expected q with
                  | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
                  | want, slips ->
                      if got <> want then
                        fail (Printf.sprintf "%s: answer %s, worked out %s, for %S" k (print got) (print want) p);
                      (* a question is asked only where each mistake of its
                         form gives another number, so all of them are listed *)
                      List.iter
                        (fun (name, slip) ->
                          if slip = want then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k name p))
                        slips;
                      let made = q.Rhema_engine.mistakes in
                      let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) made in
                      if names <> List.map fst slips then
                        fail
                          (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k (String.concat ", " names)
                             (String.concat ", " (List.map fst slips))
                             p);
                      List.iter
                        (fun (m : Rhema_engine.mistaken) ->
                          (match List.assoc_opt m.mistake said with
                           | Some phrases ->
                               List.iter
                                 (fun phrase ->
                                   match Str.search_forward (Str.regexp_string phrase) m.description 0 with
                                   | _ -> ()
                                   | exception Not_found ->
                                       fail
                                         (Printf.sprintf "%s is not described with %S: %S" m.mistake phrase m.description))
                                 phrases
                           | None -> fail ("a mistake the header does not name: " ^ m.mistake));
                          match m.mistaken_answers with
                          | Some [ value ] -> (
                              match read value with
                              | Some given ->
                                  if given = got then
                                    fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p);
                                  (match List.assoc_opt m.mistake slips with
                                   | Some slip when slip <> given ->
                                       fail
                                         (Printf.sprintf "%s: %s gives %s, worked out %s, for %S" k m.mistake (print given)
                                            (print slip) p)
                                   | _ -> ())
                              | None -> fail (Printf.sprintf "%s: %s does not give a number, for %S" k m.mistake p))
                          | _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                        made)))
    done
  done;
  for cost = 1 to 3 do
    let count = Option.value ~default:0 (Hashtbl.find_opt generated cost) in
    if count < questions_at_each_budget / 2 then fail (Printf.sprintf "only %d questions at cost %d" count cost)
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k () -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  (* Every choice the grammar offers is taken at least once, and no other. *)
  let range first last = List.init (last - first + 1) (fun n -> string_of_int (first + n)) in
  let but_zero choices = List.filter (fun choice -> choice <> "0") choices in
  let definite =
    List.concat_map
      (fun a ->
        List.concat_map
          (fun b ->
            List.filter_map
              (fun c -> if 4 * a * c > b * b then Some (Printf.sprintf "%d, %d, %d" a b c) else None)
              [ 1; 2; 3; 4 ])
          [ 1; 2; 3 ])
      [ 1; 2; 3; 4 ]
  in
  let choices =
    [ ("discriminant: before x^2", range 1 5); ("discriminant: before xy", but_zero (range (-9) 9));
      ("discriminant: before y^2", but_zero (range (-5) 5)); ("discriminant: before x", range (-9) 9);
      ("discriminant: before y", range (-9) 9); ("square_completed: asks for the", [ "least"; "greatest" ]);
      ("square_completed: before x^2", range 1 4); ("square_completed: before y^2", range 1 4);
      ("square_completed: critical x", range (-4) 4); ("square_completed: critical y", range (-4) 4);
      ("square_completed: the least value", range (-9) 9); ("square_completed: the greatest value", range (-9) 9);
      ("quadratic_extreme: asks for the", [ "least"; "greatest" ]);
      ("quadratic_extreme: second-degree part", definite); ("quadratic_extreme: before xy", but_zero (range (-3) 3));
      ("quadratic_extreme: critical x", range (-3) 3); ("quadratic_extreme: critical y", range (-3) 3);
      ("quadratic_extreme: constant, with the least value asked for", range (-9) 9);
      ("quadratic_extreme: constant, with the greatest value asked for", range (-9) 9);
      ("product_on_line: before x", range 1 5);
      ("product_on_line: before y", range 1 5); ("product_on_line: equals", range 2 20);
      ("squares_on_line: before x", range 1 5); ("squares_on_line: before y", but_zero (range (-5) 5));
      ("squares_on_line: equals", but_zero (range (-12) 12)); ("linear_on_circle: asks for the", [ "greatest"; "least" ]);
      ( "linear_on_circle: legs",
        [ "3, 4"; "4, 3"; "6, 8"; "8, 6"; "5, 12"; "12, 5"; "8, 15"; "15, 8" ] );
      ("linear_on_circle: signs", [ "1, 1"; "1, -1"; "-1, 1"; "-1, -1" ]); ("linear_on_circle: radius", range 1 5);
      ("cubic_extreme: before xy", [ "-12"; "-9"; "-6"; "-3"; "3"; "6"; "9"; "12" ]);
      ("cubic_extreme: constant", range (-9) 9); ("cubic_extreme: has one local", [ "minimum"; "maximum" ]);
      ("product_on_plane: before x", range 1 3); ("product_on_plane: before y", range 1 3);
      ("product_on_plane: before z", range 1 3); ("product_on_plane: equals", range 3 12) ]
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
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 || Rhema_engine.consumption q.Rhema_engine.tree "cost" <> 2 then
          fail (Printf.sprintf "the grammar's own budget gave %s, not a question of price 2" (kind q))
  done;
  (* A budget that no form is priced at gives no question. *)
  List.iter
    (fun cost ->
      for seed = 0 to 19 do
        Random.init seed;
        match Rhema_engine.generate (with_initial base "cost" cost) with
        | exception Rhema_engine.Generation_error _ -> ()
        | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
      done)
    [ 0; 4; 5; 6 ];
  if !failures = 0 then print_endline "Rhema optimization tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d optimization test(s) failed." !failures);
    exit 1
  end
