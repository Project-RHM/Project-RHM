(* Independent checks for conic_sections.rhm. Every question is matched
   against the whole sentence of its form, the printed equation is read back
   into a general equation of the second degree, a x^2 + c y^2 + d x + e y +
   f = 0, and the answer is found again from what defines it, on the curve
   itself, never by the formula the grammar calls for:

   The tools. The points of a curve are found by cutting it with many
   vertical and horizontal lines and solving each quadratic. The centre of an
   ellipse or a hyperbola is where both partial derivatives of the equation
   vanish; its axes are the lines through the centre parallel to x and y,
   and the semi-axes are half the chords the curve cuts on them (a hyperbola
   meets only one of them, the axis of its foci). A pair of foci is the pair
   of points on that axis, symmetric about the centre, for which the sum (an
   ellipse) or the difference (a hyperbola) of the distances to a point of
   the curve is the same at a vertex and at a second point of the curve: it
   is found by bisection and then checked at every point of the curve
   found, where the sum or the difference must be twice the semi-axis.

   ellipse_eccentricity,   the foci found as above, c their distance from
   hyperbola_eccentricity  the centre, and the vertex found on the curve at
                           distance a: c / a in floating point, matched to
                           the exact answer, and the exact fraction of the
                           two whole numbers as well.
   parabola_focus          through the answer, the line that meets the curve
                           once is the axis and that point is the vertex; the
                           directrix is the line across the axis through the
                           reflection of the answer in the vertex. Every point
                           of the curve found must be as far from the answer
                           as from that line.
   ellipse_focus           the answer and its reflection in the centre must
                           have the same sum of distances to every point of
                           the curve found; the answer is the focus found by
                           bisection on the side where the coordinates add up
                           to more.
   asymptote               y / x at a point of the curve with x = 10^6 and y
                           > 0: the limit of the slope along the curve.
   ellipse_expanded        (two blanks) the centre, exactly, as the point
                           where both partial derivatives of the expanded
                           equation vanish; the major axis as the longest of
                           720 chords through the centre (and no two of 120
                           points of the curve are further apart).
   parabola_equation       every point (x, f(x)) of the answer, at many x, is
                           as far from the printed focus as from the printed
                           directrix.
   latus_rectum_ellipse,   the line through a focus found as above, at right
   latus_rectum_hyperbola  angles to the axis of the foci, cuts the curve in
                           two points, and the chord between them is measured.

   The mistakes are worked out from their descriptions: minor_axis_used is
   the semi-minor axis found on the curve over the semi-major one;
   four_p_confused on parabola_focus is the point four times as far from the
   vertex as the focus, and on parabola_equation the parabola with the same
   vertex whose focus and directrix are a quarter as far from it (checked by
   the same equidistance); axes_swapped is the point at the focal distance
   from the centre along the minor axis, on the side where the coordinates
   add up to more; ratio_inverted is 1 over the slope found; ellipse_rule is
   sqrt(a^2 - b^2) / a with a and b the semi-axes under the positive and the
   negative term, only where a > b (otherwise the student finds no real
   number and the mistake is not listed); semi_axis_given leaves the centre
   and gives half the major axis found; not_doubled is half the chord found.
   The engine must list exactly these mistakes, in declaration order, with
   these values and descriptions, each different from the right answer.

   For every question: the prompt is the whole sentence of its form; there
   is one blank, or two for ellipse_expanded; the answer has the type of its
   form (a point of the plane, a number, a number graded as plain for the
   eccentricity of a hyperbola, a polynomial of degree 2 in x); the context
   is "Numeric"; each kind appears at its price and at no other, the budget
   is spent, the grammar's own budget gives a question of price 2, and a
   budget outside 1..3 gives no question.

   The promises of the grammar's comments: every focus asked for (and every
   focus behind an eccentricity) has whole coordinates; a conic opens along
   x or along y and both come up in every form that lets it; no answer is
   the example point (7, -9). The numbers stay in the grammar's ranges and
   every choice is seen: the four right triangles 3 4 5, 6 8 10, 5 12 13 and
   8 15 17 with either short side in either place, the number 4p from -16 to
   16 in steps of 4 without 0, a centre with coordinates from -4 to 4 but not
   the origin, the semi-axes of an asymptote from 1 to 6 and different, the
   semi-axes of the expanded ellipse from 2 to 5 and different, p from -3 to
   3 without 0 and a vertex from -5 to 5 for the parabola from its focus,
   and for a latus rectum the semi-major axis from 2 to 6 over a smaller
   semi-minor one (an ellipse along x or y) or a from 2 to 6 and b from 1 to
   6, different (a hyperbola along x). The two coordinates of a centre, and
   any two of p, h and k of the parabola from its focus, are seen both equal
   and different, so none is tied to another. The weights of the forms are
   not tested. *)

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

module F = Rhema_formula

(* ---- Exact fractions -------------------------------------------------- *)

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
let ( *: ) a b = fraction (a.top * b.top) (a.bottom * b.bottom)
let ( /: ) a b = fraction (a.top * b.bottom) (a.bottom * b.top)
let to_float a = float a.top /. float a.bottom
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom
let of_number (n : Rhema_number.t) = fraction n.Rhema_number.numerator n.Rhema_number.denominator

let close a b = Float.abs (a -. b) <= 1e-9 *. Float.max 1. (Float.abs b)

(* A float that is a whole number, as that number. *)
let whole_of what x =
  let n = Float.round x in
  if Float.abs (x -. n) > 1e-7 then failwith (Printf.sprintf "%s is %.12g, not a whole number" what x);
  int_of_float n

(* ---- Reading an equation ------------------------------------------------ *)

(* A term of a sum of squares: sign (x - shift)^2 / under. *)
type term = { sign : int; var : char; shift : int; under : int }

let shifted = "\\(([xy] [+-] [1-9][0-9]*)\\|[xy]\\)\\^{2}"
let frac_re = Str.regexp ("\\\\frac{" ^ shifted ^ "}{\\([1-9][0-9]*\\)}")
let bare_re = Str.regexp shifted
let base_re = Str.regexp "^(\\([xy]\\) \\([+-]\\) \\([1-9][0-9]*\\))$"
let join_re = Str.regexp " \\([+=-]\\) "

let base_of text =
  if String.length text = 1 then (text.[0], 0)
  else if Str.string_match base_re text 0 then
    let v = (Str.matched_group 1 text).[0] and sign = Str.matched_group 2 text and n = int_of_string (Str.matched_group 3 text) in
    (v, if sign = "-" then n else -n)
  else failwith ("not a square: " ^ text)

let render_base v shift =
  if shift = 0 then String.make 1 v else Printf.sprintf "(%c %s %d)" v (if shift > 0 then "-" else "+") (abs shift)

let render_term t =
  let square = render_base t.var t.shift ^ "^{2}" in
  if t.under = 1 then square else "\\frac{" ^ square ^ "}{" ^ string_of_int t.under ^ "}"

let render terms rhs =
  String.concat ""
    (List.mapi
       (fun place t ->
         (if place = 0 then (if t.sign < 0 then "-" else "") else if t.sign < 0 then " - " else " + ") ^ render_term t)
       terms)
  ^ " = " ^ string_of_int rhs

(* "\frac{(x + 3)^{2}}{100} + \frac{y^{2}}{36} = 1", or with a bare square,
   as its terms and the number on the right. It must be written the one way
   the test writes it. *)
let standard text =
  let rec go pos sign found =
    let term, next =
      if Str.string_match frac_re text pos then
        let b = Str.matched_group 1 text and u = Str.matched_group 2 text and next = Str.match_end () in
        let var, shift = base_of b in
        ({ sign; var; shift; under = int_of_string u }, next)
      else if Str.string_match bare_re text pos then
        let b = Str.matched_group 1 text and next = Str.match_end () in
        let var, shift = base_of b in
        ({ sign; var; shift; under = 1 }, next)
      else failwith ("not a term at " ^ String.sub text pos (String.length text - pos))
    in
    if not (Str.string_match join_re text next) then failwith ("no sign after a term in " ^ text);
    let op = Str.matched_group 1 text and after = Str.match_end () in
    match op with
    | "+" -> go after 1 (term :: found)
    | "-" -> go after (-1) (term :: found)
    | _ -> (List.rev (term :: found), int_of_string (String.sub text after (String.length text - after)))
  in
  let terms, rhs = go 0 1 [] in
  if render terms rhs <> text then failwith ("an equation written in an unusual way: " ^ text);
  (terms, rhs)

(* a x^2 + c y^2 + d x + e y + f = 0, exactly. *)
type exact_conic = { xx : fraction; yy : fraction; x1 : fraction; y1 : fraction; c0 : fraction }

let empty = { xx = zero; yy = zero; x1 = zero; y1 = zero; c0 = zero }

let conic_of terms rhs =
  List.fold_left
    (fun k t ->
      let w = fraction t.sign t.under in
      let h = whole t.shift in
      let k = { k with c0 = k.c0 +: (w *: h *: h) } in
      if t.var = 'x' then { k with xx = k.xx +: w; x1 = k.x1 +: (whole (-2) *: w *: h) }
      else { k with yy = k.yy +: w; y1 = k.y1 +: (whole (-2) *: w *: h) })
    { empty with c0 = whole (-rhs) } terms

(* "y^{2} = -12x": the square of one variable is a number times the other. *)
let parabola_re = Str.regexp "^\\([xy]\\)\\^{2} = \\(-?[1-9][0-9]*\\)\\([xy]\\)$"

let parabola text =
  if not (Str.string_match parabola_re text 0) then failwith ("not a parabola: " ^ text);
  let squared = (Str.matched_group 1 text).[0] and n = int_of_string (Str.matched_group 2 text) in
  let other = (Str.matched_group 3 text).[0] in
  if squared = other then failwith ("one variable on both sides: " ^ text);
  ( squared,
    n,
    if squared = 'y' then { empty with yy = whole 1; x1 = whole (-n) } else { empty with xx = whole 1; y1 = whole (-n) } )

(* "16x^{2} + 25y^{2} - 128x - 50y - 119 = 0": every coefficient written,
   the terms in this order, those that are 0 left out. *)
let names = [ "x^{2}"; "y^{2}"; "x"; "y"; "" ]
let expanded_term = Str.regexp "^\\([0-9]+\\)\\(x\\^{2}\\|y\\^{2}\\|x\\|y\\)?$"

let expanded text =
  let suffix = " = 0" in
  let n = String.length text and s = String.length suffix in
  if n <= s || String.sub text (n - s) s <> suffix then failwith ("not = 0: " ^ text);
  let left = String.sub text 0 (n - s) in
  let sign = ref 1 and found = ref [] in
  List.iter
    (function
      | Str.Delim d -> sign := if String.trim d = "-" then -1 else 1
      | Str.Text t ->
          if not (Str.string_match expanded_term t 0) then failwith ("not a term: " ^ t);
          let coefficient = int_of_string (Str.matched_group 1 t) in
          let name = try Str.matched_group 2 t with Not_found -> "" in
          if List.mem_assoc name !found then failwith ("a term twice: " ^ text);
          found := (name, !sign * coefficient) :: !found)
    (Str.full_split (Str.regexp " [+-] ") (" + " ^ left));
  let coefficient name = Option.value ~default:0 (List.assoc_opt name !found) in
  let shown = List.filter (fun name -> coefficient name <> 0) names in
  let again =
    String.concat ""
      (List.mapi
         (fun place name ->
           let c = coefficient name in
           (if place = 0 then (if c < 0 then "-" else "") else if c < 0 then " - " else " + ")
           ^ string_of_int (abs c) ^ name)
         shown)
  in
  if again <> left || List.exists (fun (_, c) -> c = 0) !found then failwith ("an equation written in an unusual way: " ^ text);
  let w name = whole (coefficient name) in
  { xx = w "x^{2}"; yy = w "y^{2}"; x1 = w "x"; y1 = w "y"; c0 = w "" }

(* ---- The curve ----------------------------------------------------------- *)

type conic = { a : float; c : float; d : float; e : float; f : float }

let floats k = { a = to_float k.xx; c = to_float k.yy; d = to_float k.x1; e = to_float k.y1; f = to_float k.c0 }
let value_at k (x, y) = (k.a *. x *. x) +. (k.c *. y *. y) +. (k.d *. x) +. (k.e *. y) +. k.f
let distance (x1, y1) (x2, y2) = Float.hypot (x2 -. x1) (y2 -. y1)

(* The real roots of alpha t^2 + beta t + gamma, which may be linear. *)
let roots alpha beta gamma =
  if alpha = 0. then if beta = 0. then [] else [ -.gamma /. beta ]
  else
    let disc = (beta *. beta) -. (4. *. alpha *. gamma) in
    if disc < 0. then []
    else if disc = 0. then [ -.beta /. (2. *. alpha) ]
    else
      let s = sqrt disc in
      [ (-.beta -. s) /. (2. *. alpha); (-.beta +. s) /. (2. *. alpha) ]

(* Where the curve meets the line x = x0, and the line y = y0. *)
let on_vertical k x0 = List.map (fun y -> (x0, y)) (roots k.c k.e ((k.a *. x0 *. x0) +. (k.d *. x0) +. k.f))
let on_horizontal k y0 = List.map (fun x -> (x, y0)) (roots k.a k.d ((k.c *. y0 *. y0) +. (k.e *. y0) +. k.f))

(* Points of the curve on many lines around (cx, cy), `step` apart, none of
   them a tangent. Each is checked to lie on the curve. *)
let samples k step (cx, cy) =
  let found =
    List.concat_map
      (fun i ->
        let t = step *. (0.41 +. float i) in
        on_vertical k (cx +. t) @ on_horizontal k (cy +. t))
      (List.init 81 (fun i -> i - 40))
  in
  List.iter
    (fun ((x, y) as p) ->
      let scale = Float.max 1. ((x *. x) +. (y *. y)) in
      if Float.abs (value_at k p) > 1e-9 *. scale *. Float.max 1. (Float.abs k.a +. Float.abs k.c) then
        failwith "the test's own point is not on the curve")
    found;
  if List.length found < 40 then failwith "the test finds too few points of the curve";
  found

(* An ellipse or a hyperbola, as the test finds it: its centre, the unit
   vector along the axis of the foci (u) and across it (w), both pointing to
   larger coordinates, the semi-axis along u, and for an ellipse the one
   along w. *)
type central = {
  centre : float * float;
  u : float * float;
  w : float * float;
  semi : float;
  minor : float;
  ellipse : bool;
}

let along (cx, cy) (ux, uy) t = (cx +. (t *. ux), cy +. (t *. uy))

let central k =
  if k.a = 0. || k.c = 0. then failwith "not an ellipse nor a hyperbola";
  (* where both partial derivatives, 2 a x + d and 2 c y + e, vanish *)
  let centre = (-.k.d /. (2. *. k.a), -.k.e /. (2. *. k.c)) in
  let cx, cy = centre in
  let half = function
    | [ p; q ] ->
        let (px, py), (qx, qy) = (p, q) in
        if not (close ((px +. qx) /. 2.) cx && close ((py +. qy) /. 2.) cy) then
          failwith "a chord through the centre is not halved by it";
        Some (distance p q /. 2.)
    | [] -> None
    | _ -> failwith "a line through the centre touches the curve"
  in
  let ex = (1., 0.) and ey = (0., 1.) in
  match (half (on_horizontal k cy), half (on_vertical k cx)) with
  | Some rx, Some ry ->
      if close rx ry then failwith "a circle";
      if rx > ry then { centre; u = ex; w = ey; semi = rx; minor = ry; ellipse = true }
      else { centre; u = ey; w = ex; semi = ry; minor = rx; ellipse = true }
  | Some rx, None -> { centre; u = ex; w = ey; semi = rx; minor = Float.nan; ellipse = false }
  | None, Some ry -> { centre; u = ey; w = ex; semi = ry; minor = Float.nan; ellipse = false }
  | None, None -> failwith "the curve meets neither axis through its centre"

(* The sum (ellipse) or the difference (hyperbola) of the distances of p to
   two points. *)
let spread cn p f1 f2 =
  let d1 = distance p f1 and d2 = distance p f2 in
  if cn.ellipse then d1 +. d2 else Float.abs (d1 -. d2)

(* Two points are the foci when the sum or difference is twice the semi-axis
   at every point of the curve found. *)
let are_foci cn points f1 f2 =
  List.for_all (fun p -> Float.abs (spread cn p f1 f2 -. (2. *. cn.semi)) <= 1e-8 *. Float.max 1. cn.semi) points

(* The distance of the foci from the centre, by bisection: the points at
   distance t on either side along the axis give the same sum or difference
   at a vertex and at a second point of the curve, which is the end of the
   other axis for an ellipse and the point at twice the semi-axis along the
   axis for a hyperbola. The foci are then checked at every point found. *)
let focal k cn points =
  let vertex = along cn.centre cn.u cn.semi in
  let second =
    if cn.ellipse then along cn.centre cn.w cn.minor
    else
      let x, y = along cn.centre cn.u (2. *. cn.semi) in
      match if cn.u = (1., 0.) then on_vertical k x else on_horizontal k y with
      | p :: _ -> p
      | [] -> failwith "no point of the hyperbola at twice its semi-axis"
  in
  let phi t =
    let f1 = along cn.centre cn.u t and f2 = along cn.centre cn.u (-.t) in
    spread cn second f1 f2 -. spread cn vertex f1 f2
  in
  let low, high = if cn.ellipse then (0., cn.semi) else (cn.semi, cn.semi +. 1000.) in
  if not (phi low < 0. && phi high > 0.) then failwith "the bisection for the foci has no change of sign";
  let rec bisect low high n = if n = 0 then (low +. high) /. 2. else
      let middle = (low +. high) /. 2. in
      if phi middle < 0. then bisect middle high (n - 1) else bisect low middle (n - 1)
  in
  let t = bisect low high 200 in
  if not (are_foci cn points (along cn.centre cn.u t) (along cn.centre cn.u (-.t))) then
    failwith "the points found by bisection are not foci";
  t

(* A parabola: through a point that is meant to be its focus, the line that
   meets the curve once is the axis, and that point is the vertex. Every
   point of the curve must be as far from the focus as from the line across
   the axis through the reflection of the focus in the vertex. The result is
   the vertex. *)
let parabola_focus_holds k ((fx, fy) as focus) =
  let vertex, axis_along_x =
    match (on_horizontal k fy, on_vertical k fx) with
    | [ v ], [ _; _ ] -> (v, true)
    | [ _; _ ], [ v ] -> (v, false)
    | _ -> failwith "no line through the focus meets the parabola once"
  in
  let vx, vy = vertex in
  let mx, my = ((2. *. vx) -. fx, (2. *. vy) -. fy) in
  let points = samples k 0.3 focus in
  List.iter
    (fun ((x, y) as p) ->
      let to_line = if axis_along_x then Float.abs (x -. mx) else Float.abs (y -. my) in
      if Float.abs (distance p focus -. to_line) > 1e-8 *. Float.max 1. to_line then
        failwith "a point of the parabola is not as far from the focus as from the directrix")
    points;
  vertex

(* ---- The engine's answers ----------------------------------------------- *)

let describe = Rhema_engine.describe_value

let point_of = function
  | Rhema_engine.Point [ x; y ] -> (of_number x, of_number y)
  | other -> failwith ("not a point of the plane: " ^ describe other)

let number_of = function Rhema_engine.Num n -> of_number n | other -> failwith ("not a number: " ^ describe other)

let plain_number_of = function
  | Rhema_engine.Plain (Rhema_engine.Num n) -> of_number n
  | other -> failwith ("not a number graded as plain: " ^ describe other)

(* A constant formula graded as plain, as a float. *)
let plain_formula_of = function
  | Rhema_engine.Plain (Rhema_engine.Formula f) ->
      if F.variables f <> [] then failwith ("a formula with variables: " ^ describe (Rhema_engine.Formula f));
      F.evaluate ~variable:"x" ~at:0. f
  | other -> failwith ("not a formula graded as plain: " ^ describe other)

(* A polynomial of degree 2 in x, as a function on floats. *)
let quadratic_of = function
  | Rhema_engine.Polynomial p when Rhema_polynomial.variable_name p = "x" && Rhema_polynomial.degree p = Some 2 ->
      let coefficients = List.map of_number (Rhema_polynomial.coefficients p) in
      fun x -> List.fold_right (fun c total -> to_float c +. (x *. total)) coefficients 0.
  | other -> failwith ("not a polynomial of degree 2 in x: " ^ describe other)

let point_text (x, y) = Printf.sprintf "(%s, %s)" (show x) (show y)
let fpoint (x, y) = Printf.sprintf "(%.10g, %.10g)" x y
let same_point (x, y) (px, py) = close (to_float x) px && close (to_float y) py

(* ---- Reading the question ----------------------------------------------- *)

let words = Str.quote
let equation = "\\([^`]*\\)"
let a_whole = "\\(0\\|-?[1-9][0-9]*\\)"
let example = words "[`(7, -9)`]"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

let sentence k =
  match k with
  | "ellipse_eccentricity" -> words "Find the eccentricity of the ellipse [`" ^ equation ^ words "`]. [___]"
  | "hyperbola_eccentricity" -> words "Find the eccentricity of the hyperbola [`" ^ equation ^ words "`]. [___]"
  | "parabola_focus" ->
      words "Find the focus of the parabola [`" ^ equation ^ words "`]. Enter it as a point, such as " ^ example
      ^ words ". [___]"
  | "ellipse_focus" ->
      words "The ellipse [`" ^ equation
      ^ words "`] has two foci. Find the one whose two coordinates add up to more, as a point such as " ^ example
      ^ words ". [___]"
  | "asymptote" ->
      words "Find the slope of the asymptote with positive slope of the hyperbola [`" ^ equation ^ words "`]. [___]"
  | "ellipse_expanded" ->
      words "The equation [`" ^ equation ^ words "`] is an ellipse. Its centre, as a point such as " ^ example
      ^ words ": [___] The length of its major axis: [___]"
  | "parabola_equation" ->
      words "Find the parabola whose focus is [`(" ^ a_whole ^ words ", " ^ a_whole
      ^ words ")`] and whose directrix is the line [`y = " ^ a_whole
      ^ words "`], as [`y = f(x)`]. Enter [`f(x)`]. [___]"
  | "latus_rectum_ellipse" | "latus_rectum_hyperbola" ->
      words "Find the length of a latus rectum of the "
      ^ words (if k = "latus_rectum_ellipse" then "ellipse" else "hyperbola")
      ^ words " [`" ^ equation
      ^ words "`], the chord through a focus at right angles to the axis on which the foci lie. [___]"
  | k -> failwith ("unknown kind " ^ k)

(* ---- What was generated besides the kinds ------------------------------- *)

let noted = Hashtbl.create 1024
let note what = Hashtbl.replace noted what ()
let between first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)

(* Two numbers of a form are not tied to each other: they are seen both
   equal and different. *)
let tie k first x second y = Printf.sprintf "%s: %s and %s %s" k first second (if x = y then "are equal" else "differ")
let ties k pairs = List.concat_map (fun (a, b) -> [ tie k a 0 b 0; tie k a 0 b 1 ]) pairs

let triangles = [ (3, 4, 5); (6, 8, 10); (5, 12, 13); (8, 15, 17) ]

(* ---- One question ------------------------------------------------------- *)

(* A slip the form must list: its name and a check of its answers, which
   fails with a message when they are not what the description gives. *)
type slip = string * (Rhema_engine.value list -> unit)

let expect_number what want values =
  match values with
  | [ v ] ->
      let got = number_of v in
      if got <> want then failwith (Printf.sprintf "%s: %s, worked out %s" what (show got) (show want))
  | _ -> failwith (what ^ ": not one answer")

let expect_close what want values =
  match values with
  | [ v ] ->
      let got = to_float (number_of v) in
      if not (close got want) then failwith (Printf.sprintf "%s: %.12g, worked out %.12g" what got want)
  | _ -> failwith (what ^ ": not one answer")

let expect_point what want values =
  match values with
  | [ v ] ->
      let got = point_of v in
      if got <> want then failwith (Printf.sprintf "%s: %s, worked out %s" what (point_text got) (point_text want))
  | _ -> failwith (what ^ ": not one answer")

(* The square root of a whole number that is a square. *)
let root n =
  let r = int_of_float (Float.round (sqrt (float n))) in
  if r * r <> n then failwith (Printf.sprintf "%d is not a square" n);
  r

(* The right answer is tested here by what defines it; the result is the
   slips the form must list. *)
let check (q : Rhema_engine.question) : slip list =
  let p = q.Rhema_engine.prompt and k = kind q in
  let only () = match q.Rhema_engine.answers with [ v ] -> v | _ -> failwith "not one blank" in
  let terms_of text rhs_wanted =
    let terms, rhs = standard text in
    if rhs <> rhs_wanted then failwith ("an equation that is not = " ^ string_of_int rhs_wanted);
    terms
  in
  match k with
  | "ellipse_eccentricity" -> (
      match fields 1 (sentence k) p with
      | [ eq ] ->
          let terms = terms_of eq 1 in
          (match terms with
          | [ { sign = 1; var = 'x'; shift = 0; under = ux }; { sign = 1; var = 'y'; shift = 0; under = uy } ] ->
              note (Printf.sprintf "%s: x^2 over %d, y^2 over %d" k ux uy)
          | _ -> failwith "not x^2 / A + y^2 / B = 1");
          let kc = floats (conic_of terms 1) in
          let cn = central kc in
          if not cn.ellipse then failwith "not an ellipse";
          note (Printf.sprintf "%s: foci along %s" k (if cn.u = (1., 0.) then "x" else "y"));
          let c = focal kc cn (samples kc (cn.semi /. 15.) cn.centre) in
          let ci = whole_of "the focal distance" c and ai = whole_of "the semi-major axis" cn.semi in
          let bi = whole_of "the semi-minor axis" cn.minor in
          let got = number_of (only ()) in
          if not (close (to_float got) (c /. cn.semi)) then
            failwith (Printf.sprintf "c / a is %.12g, not %s" (c /. cn.semi) (show got));
          if got <> fraction ci ai then failwith "not the exact fraction c / a";
          [ ("minor_axis_used", expect_number "minor_axis_used" (fraction bi ai)) ]
      | _ -> failwith "one field was expected")
  | "hyperbola_eccentricity" -> (
      match fields 1 (sentence k) p with
      | [ eq ] ->
          let terms = terms_of eq 1 in
          let a2, b2 =
            match terms with
            | [ { sign = 1; var = v1; shift = 0; under = a2 }; { sign = -1; var = v2; shift = 0; under = b2 } ] when v1 <> v2
              ->
                note (Printf.sprintf "%s: %c^2 first, over %d, then over %d" k v1 a2 b2);
                (a2, b2)
            | _ -> failwith "not x^2 / A - y^2 / B = 1 or the other way round"
          in
          let kc = floats (conic_of terms 1) in
          let cn = central kc in
          if cn.ellipse then failwith "not a hyperbola";
          note (Printf.sprintf "%s: foci along %s" k (if cn.u = (1., 0.) then "x" else "y"));
          let c = focal kc cn (samples kc (cn.semi /. 15.) cn.centre) in
          let ci = whole_of "the focal distance" c and ai = whole_of "the semi-axis" cn.semi in
          let a = root a2 and b = root b2 in
          if a <> ai then failwith "the vertex is not at the root of the first number";
          let got = plain_number_of (only ()) in
          if not (close (to_float got) (c /. cn.semi)) then
            failwith (Printf.sprintf "c / a is %.12g, not %s" (c /. cn.semi) (show got));
          if got <> fraction ci ai then failwith "not the exact fraction c / a";
          if a > b then
            let slip = sqrt (float ((a * a) - (b * b))) /. float a in
            [
              ( "ellipse_rule",
                function
                | [ v ] ->
                    let x = plain_formula_of v in
                    if not (close x slip) then failwith (Printf.sprintf "ellipse_rule: %.12g, worked out %.12g" x slip)
                | _ -> failwith "ellipse_rule: not one answer" );
            ]
          else []
      | _ -> failwith "one field was expected")
  | "parabola_focus" -> (
      match fields 1 (sentence k) p with
      | [ eq ] ->
          let squared, n, exact = parabola eq in
          note (Printf.sprintf "%s: %c^2 = %d %c" k squared n (if squared = 'y' then 'x' else 'y'));
          let fx, fy = point_of (only ()) in
          if fx.bottom <> 1 || fy.bottom <> 1 then failwith "a focus without whole coordinates";
          let kc = floats exact in
          let vx, vy = parabola_focus_holds kc (to_float fx, to_float fy) in
          let vertex = (fraction (whole_of "the vertex" vx) 1, fraction (whole_of "the vertex" vy) 1) in
          (* four times as far from the vertex *)
          let four a v = v +: (whole 4 *: (a +: (whole (-1) *: v))) in
          [ ("four_p_confused", expect_point "four_p_confused" (four fx (fst vertex), four fy (snd vertex))) ]
      | _ -> failwith "one field was expected")
  | "ellipse_focus" -> (
      match fields 1 (sentence k) p with
      | [ eq ] ->
          let terms = terms_of eq 1 in
          (match terms with
          | [ { sign = 1; var = 'x'; shift = h; under = ux }; { sign = 1; var = 'y'; shift = kk; under = uy } ] ->
              note (Printf.sprintf "%s: x^2 over %d, y^2 over %d" k ux uy);
              note (Printf.sprintf "%s: h is %d" k h);
              note (Printf.sprintf "%s: k is %d" k kk);
              note (tie k "h" h "k" kk);
              if h = 0 && kk = 0 then failwith "the centre is the origin"
          | _ -> failwith "not (x - h)^2 / A + (y - k)^2 / B = 1");
          let kc = floats (conic_of terms 1) in
          let cn = central kc in
          if not cn.ellipse then failwith "not an ellipse";
          note (Printf.sprintf "%s: foci along %s" k (if cn.u = (1., 0.) then "x" else "y"));
          let points = samples kc (cn.semi /. 15.) cn.centre in
          let c = focal kc cn points in
          let ((ax, ay) as answer) = point_of (only ()) in
          if ax.bottom <> 1 || ay.bottom <> 1 then failwith "a focus without whole coordinates";
          let cx, cy = cn.centre in
          let fa = (to_float ax, to_float ay) in
          let mirror = ((2. *. cx) -. fst fa, (2. *. cy) -. snd fa) in
          if not (are_foci cn points fa mirror) then failwith "the answer and its reflection in the centre are not foci";
          if not (fst fa +. snd fa > fst mirror +. snd mirror) then failwith "the other focus has the larger sum";
          let found = along cn.centre cn.u c in
          if not (same_point answer found) then failwith ("the test finds the focus " ^ fpoint found);
          let to_whole what (x, y) = (whole (whole_of what x), whole (whole_of what y)) in
          [ ("axes_swapped", expect_point "axes_swapped" (to_whole "the swapped focus" (along cn.centre cn.w c))) ]
      | _ -> failwith "one field was expected")
  | "asymptote" -> (
      match fields 1 (sentence k) p with
      | [ eq ] ->
          let terms = terms_of eq 1 in
          (match terms with
          | [ { sign = 1; var = v1; shift = 0; under = a2 }; { sign = -1; var = v2; shift = 0; under = b2 } ] when v1 <> v2 ->
              note (Printf.sprintf "%s: %c^2 first, a = %d, b = %d" k v1 (root a2) (root b2))
          | _ -> failwith "not x^2 / A - y^2 / B = 1 or the other way round");
          let kc = floats (conic_of terms 1) in
          if (central kc).ellipse then failwith "not a hyperbola";
          let far = 1e6 in
          let slope =
            match on_vertical kc far with
            | [ (_, y1); (_, y2) ] -> Float.max y1 y2 /. far
            | _ -> failwith "the hyperbola does not reach x = 10^6 twice"
          in
          if not (slope > 0.) then failwith "no positive slope";
          let got = to_float (number_of (only ())) in
          if Float.abs (got -. slope) > 1e-6 then failwith (Printf.sprintf "the slope far out is %.12g" slope);
          (* the slope found far out is good to about 10^-12 *)
          [
            ( "ratio_inverted",
              function
              | [ v ] ->
                  let x = to_float (number_of v) in
                  if Float.abs (x -. (1. /. slope)) > 1e-6 then
                    failwith (Printf.sprintf "ratio_inverted: %.12g, worked out %.12g" x (1. /. slope))
              | _ -> failwith "ratio_inverted: not one answer" );
          ]
      | _ -> failwith "one field was expected")
  | "ellipse_expanded" -> (
      match fields 1 (sentence k) p with
      | [ eq ] -> (
          let exact = expanded eq in
          let kc = floats exact in
          (* where both partial derivatives vanish, exactly *)
          let hx = whole (-1) *: exact.x1 /: (whole 2 *: exact.xx) and hy = whole (-1) *: exact.y1 /: (whole 2 *: exact.yy) in
          if not (kc.a > 0. && kc.c > 0.) then failwith "not an ellipse: the squares have different signs";
          let cx, cy = (to_float hx, to_float hy) in
          if not (value_at kc (cx, cy) < 0.) then failwith "not an ellipse: no point inside";
          if hx.bottom <> 1 || hy.bottom <> 1 then failwith "a centre without whole coordinates";
          note (Printf.sprintf "%s: h is %d" k hx.top);
          note (Printf.sprintf "%s: k is %d" k hy.top);
          note (tie k "h" hx.top "k" hy.top);
          if hx = zero && hy = zero then failwith "the centre is the origin";
          note (Printf.sprintf "%s: %s constant term" k (if exact.c0 = zero then "no" else "a"));
          (* the chord through the centre at angle theta *)
          let chord theta =
            let ux = cos theta and uy = sin theta in
            match
              roots ((kc.a *. ux *. ux) +. (kc.c *. uy *. uy))
                ((((2. *. kc.a *. cx) +. kc.d) *. ux) +. (((2. *. kc.c *. cy) +. kc.e) *. uy))
                (value_at kc (cx, cy))
            with
            | [ r1; r2 ] -> (along (cx, cy) (ux, uy) r1, along (cx, cy) (ux, uy) r2)
            | _ -> failwith "a line through the centre does not cut the ellipse twice"
          in
          let longest = ref 0. in
          for j = 0 to 719 do
            let p1, p2 = chord (float j *. Float.pi /. 720.) in
            longest := Float.max !longest (distance p1 p2)
          done;
          let ring = List.concat_map (fun j -> let p1, p2 = chord (float j *. Float.pi /. 60.) in [ p1; p2 ]) (between 0 59) in
          List.iter
            (fun p1 ->
              List.iter (fun p2 -> if distance p1 p2 > !longest +. 1e-9 then failwith "two points further apart than the longest chord") ring)
            ring;
          let across = let p1, p2 = chord 0. in distance p1 p2 /. 2. and up = let p1, p2 = chord (Float.pi /. 2.) in distance p1 p2 /. 2. in
          note
            (Printf.sprintf "%s: semi-axes %d along x and %d along y" k (whole_of "a semi-axis" across) (whole_of "a semi-axis" up));
          match q.Rhema_engine.answers with
          | [ centre; axis ] ->
              let centre = point_of centre and axis = number_of axis in
              if centre <> (hx, hy) then failwith ("the centre is " ^ point_text (hx, hy));
              if not (close (to_float axis) !longest) then failwith (Printf.sprintf "the longest chord is %.12g" !longest);
              let half = whole_of "half the longest chord" (!longest /. 2.) in
              [
                ( "semi_axis_given",
                  function
                  | [ c; a ] ->
                      if point_of c <> (hx, hy) then failwith "semi_axis_given: the centre is changed";
                      expect_number "semi_axis_given" (whole half) [ a ]
                  | _ -> failwith "semi_axis_given: not two answers" );
              ]
          | _ -> failwith "not two blanks")
      | _ -> failwith "one field was expected")
  | "parabola_equation" -> (
      match fields 3 (sentence k) p with
      | [ fx; fy; line ] ->
          let fx = float_of_string fx and fy = float_of_string fy and line = float_of_string line in
          if fy = line then failwith "the focus is on the directrix";
          let vy = (fy +. line) /. 2. and pp = (fy -. line) /. 2. in
          let pi = whole_of "p" pp and hi = whole_of "h" fx and ki = whole_of "k" vy in
          note (Printf.sprintf "%s: p is %d" k pi);
          note (Printf.sprintf "%s: h is %d" k hi);
          note (Printf.sprintf "%s: k is %d" k ki);
          note (tie k "p" pi "h" hi);
          note (tie k "p" pi "k" ki);
          note (tie k "h" hi "k" ki);
          let xs = [ -9.3; -6.; -3.7; -1.; 0.; 0.45; 2.; 3.3; 5.; 8.6; 12. ] in
          (* every point (x, f(x)) as far from the focus as from the line *)
          let equidistant what f (fx, fy) line =
            List.iter
              (fun x ->
                let y = f x in
                if not (close (distance (x, y) (fx, fy)) (Float.abs (y -. line))) then
                  failwith (Printf.sprintf "%s: (%g, %g) is not as far from the focus as from the directrix" what x y))
              xs
          in
          equidistant "the answer" (quadratic_of (only ())) (fx, fy) line;
          [
            ( "four_p_confused",
              function
              | [ v ] -> equidistant "four_p_confused" (quadratic_of v) (fx, vy +. (pp /. 4.)) (vy -. (pp /. 4.))
              | _ -> failwith "four_p_confused: not one answer" );
          ]
      | _ -> failwith "three fields were expected")
  | "latus_rectum_ellipse" | "latus_rectum_hyperbola" -> (
      match fields 1 (sentence k) p with
      | [ eq ] ->
          let terms = terms_of eq 1 in
          if List.exists (fun t -> t.shift <> 0) terms || List.length terms <> 2 then failwith "not a conic about the origin";
          let kc = floats (conic_of terms 1) in
          let cn = central kc in
          if cn.ellipse <> (k = "latus_rectum_ellipse") then failwith "the curve is not the one the question names";
          let along_x = cn.u = (1., 0.) in
          if cn.ellipse then
            note
              (Printf.sprintf "%s: major %d along %s, minor %d" k (whole_of "a semi-axis" cn.semi)
                 (if along_x then "x" else "y")
                 (whole_of "a semi-axis" cn.minor))
          else (
            match terms with
            | [ { sign = 1; under = a2; _ }; { sign = -1; under = b2; _ } ] ->
                note (Printf.sprintf "%s: a %d, b %d, along %s" k (root a2) (root b2) (if along_x then "x" else "y"))
            | _ -> failwith "not a hyperbola written x^2 / A - y^2 / B = 1");
          let c = focal kc cn (samples kc (cn.semi /. 15.) cn.centre) in
          let fx, fy = along cn.centre cn.u c in
          let length =
            match if along_x then on_vertical kc fx else on_horizontal kc fy with
            | [ p1; p2 ] -> distance p1 p2
            | _ -> failwith "the line through the focus does not cut the curve twice"
          in
          let got = to_float (number_of (only ())) in
          if not (close got length) then failwith (Printf.sprintf "the chord is %.12g long" length);
          [ ("not_doubled", expect_close "not_doubled" (length /. 2.)) ]
      | _ -> failwith "one field was expected")
  | k -> failwith ("unknown kind " ^ k)

(* The mistakes as the grammar's header describes them, in its order. *)
let described =
  [ ("minor_axis_used", "divides the semi-minor axis by the semi-major one, where the focal distance c belongs above the line");
    ("four_p_confused", "confuses p, the distance from the vertex to the focus, with 4p, the number in the equation");
    ("axes_swapped", "puts the foci on the minor axis of the ellipse, where they lie on its major axis");
    ("ratio_inverted", "turns the slope of the asymptote over: a / b where b / a belongs, or the other way round");
    ("ellipse_rule", "takes c^2 = a^2 - b^2 for a hyperbola, the rule of an ellipse, where c^2 = a^2 + b^2");
    ("semi_axis_given", "gives the semi-major axis, where the whole major axis is asked for");
    ("not_doubled", "gives half the latus rectum, b^2 / a, where its whole length 2 b^2 / a belongs") ]

let prices =
  [ ("ellipse_eccentricity", 1); ("parabola_focus", 1); ("ellipse_focus", 2); ("asymptote", 2);
    ("hyperbola_eccentricity", 2); ("ellipse_expanded", 3); ("parabola_equation", 3); ("latus_rectum_ellipse", 3);
    ("latus_rectum_hyperbola", 3) ]

(* The forms whose answer is a point. *)
let pointed = [ "parabola_focus"; "ellipse_focus" ]

let () =
  let base = load_file "conic_sections.rhm" in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 16 and generated = Hashtbl.create 4 in
  let one spec cost seed =
    Random.init (seed + (100000 * cost));
    match Rhema_engine.generate spec with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
    | q -> (
        let k = kind q and p = q.Rhema_engine.prompt in
        Hashtbl.replace seen k ();
        Hashtbl.replace generated cost (1 + Option.value ~default:0 (Hashtbl.find_opt generated cost));
        if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
        if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
        if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
        let blanks = if k = "ellipse_expanded" then 2 else 1 in
        if List.length q.Rhema_engine.answers <> blanks then
          fail (Printf.sprintf "%s: %d blanks, for %S" k (List.length q.Rhema_engine.answers) p);
        (match q.Rhema_engine.answers with
        | first :: _ when first = q.Rhema_engine.answer -> ()
        | _ -> fail (Printf.sprintf "%s: the answer is not the first blank's, for %S" k p));
        (* the example point is never an answer *)
        List.iter
          (function
            | Rhema_engine.Point [ x; y ] when of_number x = whole 7 && of_number y = whole (-9) ->
                fail (Printf.sprintf "%s: the example point is the answer, for %S" k p)
            | _ -> ())
          q.Rhema_engine.answers;
        if List.mem k pointed || k = "ellipse_expanded" then
          (match q.Rhema_engine.answer with
          | Rhema_engine.Point [ _; _ ] -> ()
          | other -> fail (Printf.sprintf "%s: the answer %s is not a point" k (describe other)));
        match check q with
        | exception e -> fail (Printf.sprintf "%s: %s, answer %s, for %S" k (Printexc.to_string e) q.Rhema_engine.answer_text p)
        | slips ->
            let listed = q.Rhema_engine.mistakes in
            let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
            if names <> List.map fst slips then
              fail
                (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k (String.concat ", " names)
                   (String.concat ", " (List.map fst slips))
                   p);
            List.iter
              (fun (m : Rhema_engine.mistaken) ->
                Hashtbl.replace made (m.mistake ^ " on " ^ k) ();
                (match List.assoc_opt m.mistake described with
                | None -> fail ("a mistake the grammar does not declare in its header: " ^ m.mistake)
                | Some description ->
                    if m.description <> description then
                      fail (Printf.sprintf "%s is described as %S, not as %S" m.mistake m.description description));
                match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                | Some values, Some verify -> (
                    if values = q.Rhema_engine.answers then
                      fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p);
                    if List.length values <> blanks then
                      fail (Printf.sprintf "%s: %s gives %d answers, for %S" k m.mistake (List.length values) p);
                    match verify values with
                    | () -> ()
                    | exception e ->
                        fail
                          (Printf.sprintf "%s: %s [%s], for %S" k (Printexc.to_string e)
                             (String.concat "; " (List.map describe values))
                             p))
                | None, _ -> fail (Printf.sprintf "%s: %s gives no answer, for %S" k m.mistake p)
                | _, None -> ())
              listed)
  in
  let per_budget = 2500 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to per_budget - 1 do
      one spec cost seed
    done
  done;
  for cost = 1 to 3 do
    let count = Option.value ~default:0 (Hashtbl.find_opt generated cost) in
    if count < per_budget then fail (Printf.sprintf "only %d questions at cost %d" count cost)
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k () -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  List.iter
    (fun what -> if not (Hashtbl.mem made what) then fail ("never listed: " ^ what))
    [ "minor_axis_used on ellipse_eccentricity"; "four_p_confused on parabola_focus"; "axes_swapped on ellipse_focus";
      "ratio_inverted on asymptote"; "ellipse_rule on hyperbola_eccentricity"; "semi_axis_given on ellipse_expanded";
      "four_p_confused on parabola_equation"; "not_doubled on latus_rectum_ellipse"; "not_doubled on latus_rectum_hyperbola" ];
  (* Every choice the grammar offers is taken, and nothing else. *)
  let legs = List.concat_map (fun (s, l, h) -> [ (h, s, l); (h, l, s) ]) triangles in
  let unders k =
    List.concat_map
      (fun (h, leg, _) ->
        [ Printf.sprintf "%s: x^2 over %d, y^2 over %d" k (h * h) (leg * leg);
          Printf.sprintf "%s: x^2 over %d, y^2 over %d" k (leg * leg) (h * h) ])
      legs
  in
  let both k = [ k ^ ": foci along x"; k ^ ": foci along y" ] in
  let centre k =
    List.concat_map (fun n -> [ Printf.sprintf "%s: h is %d" k n; Printf.sprintf "%s: k is %d" k n ]) (between (-4) 4)
    @ ties k [ ("h", "k") ]
  in
  let xy = [ 'x'; 'y' ] in
  let choices =
    unders "ellipse_eccentricity" @ both "ellipse_eccentricity"
    @ List.concat_map
        (fun v ->
          List.filter_map
            (fun n -> if n = 0 then None else Some (Printf.sprintf "parabola_focus: %c^2 = %d %c" v (4 * n) (if v = 'y' then 'x' else 'y')))
            (between (-4) 4))
        xy
    @ unders "ellipse_focus" @ both "ellipse_focus" @ centre "ellipse_focus"
    @ List.concat_map
        (fun v ->
          List.concat_map
            (fun a ->
              List.filter_map
                (fun b -> if a = b then None else Some (Printf.sprintf "asymptote: %c^2 first, a = %d, b = %d" v a b))
                (between 1 6))
            (between 1 6))
        xy
    @ List.concat_map
        (fun v ->
          List.map
            (fun (_, a, b) -> Printf.sprintf "hyperbola_eccentricity: %c^2 first, over %d, then over %d" v (a * a) (b * b))
            legs)
        xy
    @ both "hyperbola_eccentricity"
    @ List.concat_map
        (fun a ->
          List.filter_map
            (fun b -> if a = b then None else Some (Printf.sprintf "ellipse_expanded: semi-axes %d along x and %d along y" a b))
            (between 2 5))
        (between 2 5)
    @ centre "ellipse_expanded"
    @ [ "ellipse_expanded: no constant term"; "ellipse_expanded: a constant term" ]
    @ List.filter_map (fun n -> if n = 0 then None else Some (Printf.sprintf "parabola_equation: p is %d" n)) (between (-3) 3)
    @ ties "parabola_equation" [ ("p", "h"); ("p", "k"); ("h", "k") ]
    @ List.concat_map
        (fun n -> [ Printf.sprintf "parabola_equation: h is %d" n; Printf.sprintf "parabola_equation: k is %d" n ])
        (between (-5) 5)
    @ List.concat_map
        (fun major ->
          List.concat_map
            (fun minor ->
              List.map
                (fun axis -> Printf.sprintf "latus_rectum_ellipse: major %d along %s, minor %d" major axis minor)
                [ "x"; "y" ])
            (between 1 (major - 1)))
        (between 2 6)
    @ List.concat_map
        (fun a ->
          List.filter_map
            (fun b -> if a = b then None else Some (Printf.sprintf "latus_rectum_hyperbola: a %d, b %d, along x" a b))
            (between 1 6))
        (between 2 6)
  in
  List.iter (fun what -> if not (Hashtbl.mem noted what) then fail ("never generated: " ^ what)) choices;
  Hashtbl.iter (fun what () -> if not (List.mem what choices) then fail ("not a choice of the grammar: " ^ what)) noted;
  (* The grammar as it is written, with the budget it sets itself, gives a
     question of price 2. *)
  for seed = 0 to 19 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 || Rhema_engine.consumption q.Rhema_engine.tree "cost" <> 2 then
          fail (Printf.sprintf "the grammar's own budget gave a question that is not of price 2: %s" (kind q))
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
    [ 0; 4; 5 ];
  if !failures = 0 then print_endline "Rhema conic_sections tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d conic_sections test(s) failed." !failures);
    exit 1
  end
