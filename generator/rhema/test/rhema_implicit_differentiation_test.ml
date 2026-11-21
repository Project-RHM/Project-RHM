(* Independent checks for implicit_differentiation.rhm. Every question is
   matched against the whole sentence of its form. The equation of the curve
   is read back from it, term by term, as a polynomial F(x, y) = left - right
   with whole coefficients, and the point is read back too. Nothing of the
   grammar's working is used: the point must lie on the curve (F = 0 there),
   the partial derivatives of F are taken here, term by term, and the answer
   is found again from them, in exact fractions. It must be the engine's
   answer, exactly.

   - circle, conic, product, cubic: the slope is -F_x / F_y at the point.
   - related_rate: along the curve F_x dx/dt + F_y dy/dt = 0, so dy/dt is
     -F_x / F_y times the rate printed.
   - tangent_intercept: the tangent is the line through the point at right
     angles to the gradient, F_x (x - a) + F_y (y - b) = 0; x = 0 is put in
     and y is solved for.
   - second_derivative: the formula for any implicit curve,
     y'' = -(F_xx F_y^2 - 2 F_xy F_x F_y + F_yy F_x^2) / F_y^3, from the
     second partial derivatives of the polynomial read.

   Every answer is found a second way, in floats, with no derivative of F in
   x at all: for an x a little to each side of the point, F(x, y) = 0 is
   solved for y by Newton's method starting from the point, and the two
   points of the curve so found give a difference quotient (the slope, the
   rate), the line through them (the intercept), or with the point itself a
   second difference (the second derivative). It must agree with the exact
   answer to a loose tolerance.

   The mistakes are found again from their descriptions. sign_dropped takes
   the slope to be g = +F_x / F_y: that is the wrong slope, the wrong rate,
   and the intercept of the line through the point with that slope. For the
   second derivative the student differentiates that wrong slope once more
   along the curve and uses it again for dy/dx, which gives g_x + g_y g; the
   two parts are found by the quotient rule from the partial derivatives of
   F, and the value is found a second time in floats, as the change of
   F_x / F_y between two points a little to each side of the point on the
   line of slope g. product_rule_missed differentiates x y as if x were a
   constant factor, so in F_y the terms that hold both x and y are left out.
   Each question must list exactly the mistakes its form has a line for
   (sign_dropped everywhere, product_rule_missed where the curve has a
   product term), with those values, and none of them may be the right
   answer.

   What the header promises is checked as well: the form of each equation
   and the ranges of its numbers, a point with neither coordinate zero, no
   tangent that is level or upright, a constant other than 0 for
   p x^2 + q y^2 = c, with p and q different (no circle offered as a conic)
   and with no common factor, every kind at its price and no other, and no
   question at a budget outside 1 to 3. An equation that looks like a curve
   and is not one is refused whatever its form: the tangent at the point,
   as a whole straight line, must not lie in the curve (F is put on that
   line and must not vanish all along it), and x^2 + k x y + y^2 must not be
   a perfect square. Every value of every number, and every way an equation
   is printed, must turn up; the forms must turn up in the shares their
   weights give. *)

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
let ( +: ) a b = fraction ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( *: ) a b = fraction (a.top * b.top) (a.bottom * b.bottom)
let to_float a = float a.top /. float a.bottom
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

let number = function
  | Rhema_engine.Num n -> Some (fraction n.Rhema_number.numerator n.Rhema_number.denominator)
  | _ -> None

(* The fields of a prompt: the pattern is the whole sentence, with a group
   wherever something is read. *)
let words = Str.quote

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

let an_equation = "\\([^`]*\\)"
let an_integer = "\\(-?[0-9]+\\)"
let a_point = words "\\left(" ^ an_integer ^ ", " ^ an_integer ^ words "\\right)"

let slope_sentence =
  words "Find the slope [`\\dfrac{dy}{dx}`] of the " ^ "\\(circle\\|curve\\)" ^ words " [`" ^ an_equation
  ^ words "`] at the point [`" ^ a_point ^ words "`]."

let rate_sentence =
  words "A point moves along the circle [`" ^ an_equation ^ words "`]. At the moment it passes through [`" ^ a_point
  ^ words "`], its [`x`]-coordinate is changing at the rate [`\\dfrac{dx}{dt} = " ^ an_integer
  ^ words "`]. Find [`\\dfrac{dy}{dt}`] at that moment."

let intercept_sentence =
  words "The tangent to the curve [`" ^ an_equation ^ words "`] at the point [`" ^ a_point
  ^ words "`] meets the [`y`]-axis at the point [`(0, h)`]. Find [`h`]."

let second_sentence =
  words "Find [`\\dfrac{d^{2}y}{dx^{2}}`] at the point [`" ^ a_point ^ words "`] of the curve [`" ^ an_equation
  ^ words "`]."

(* One term of a polynomial in x and y: coefficient x^x_power y^y_power. *)
type term = { coefficient : int; x_power : int; y_power : int }

let term_pattern = Str.regexp "\\([0-9]*\\)\\(x\\(\\^{\\([0-9]+\\)}\\)?\\)?\\(y\\(\\^{\\([0-9]+\\)}\\)?\\)?"

(* A term as the grammar writes it: "3x^{2}", "y^{3}", "2xy", "xy", "25".
   A coefficient of 1 is not written, nor is a power of 1. *)
let term sign text =
  if not (Str.string_match term_pattern text 0 && Str.match_end () = String.length text) then
    failwith ("cannot read the term " ^ text);
  let group n = match Str.matched_group n text with s -> Some s | exception Not_found -> None in
  let power letter exponent =
    match (group letter, group exponent) with
    | None, _ -> 0
    | Some _, None -> 1
    | Some _, Some e -> if int_of_string e < 2 then failwith ("a power written that need not be: " ^ text) else int_of_string e
  in
  let x_power = power 2 4 and y_power = power 5 7 in
  let digits = match group 1 with Some d -> d | None -> "" in
  if String.length digits > 1 && digits.[0] = '0' then failwith ("a number that begins with 0: " ^ text);
  let coefficient =
    if x_power = 0 && y_power = 0 then
      if digits = "" then failwith "an empty term" else int_of_string digits
    else if digits = "" then 1
    else if digits = "1" || digits = "0" then failwith ("a coefficient written that need not be: " ^ text)
    else int_of_string digits
  in
  { coefficient = sign * coefficient; x_power; y_power }

(* One side of an equation: terms joined by " + " and " - ". Only the first
   term may carry its own minus sign. *)
let side text =
  match Str.full_split (Str.regexp " [+-] ") text with
  | Str.Text first :: rest ->
      let first =
        if first <> "" && first.[0] = '-' then term (-1) (String.sub first 1 (String.length first - 1))
        else term 1 first
      in
      let rec others = function
        | [] -> []
        | Str.Delim sign :: Str.Text t :: rest -> term (if sign = " - " then -1 else 1) t :: others rest
        | _ -> failwith ("cannot read the side " ^ text)
      in
      first :: others rest
  | _ -> failwith ("cannot read the side " ^ text)

type curve = { left : term list; right : term list }

let curve text =
  match Str.split_delim (Str.regexp_string " = ") text with
  | [ left; right ] -> { left = side left; right = side right }
  | _ -> failwith ("not an equation: " ^ text)

(* F = left - right, and its derivatives, term by term. *)
let difference c = c.left @ List.map (fun t -> { t with coefficient = -t.coefficient }) c.right

let d_x terms =
  List.filter_map
    (fun t -> if t.x_power = 0 then None else Some { t with coefficient = t.coefficient * t.x_power; x_power = t.x_power - 1 })
    terms

let d_y terms =
  List.filter_map
    (fun t -> if t.y_power = 0 then None else Some { t with coefficient = t.coefficient * t.y_power; y_power = t.y_power - 1 })
    terms

let rec power base n = if n = 0 then 1 else base * power base (n - 1)
let at terms x y = List.fold_left (fun total t -> total + (t.coefficient * power x t.x_power * power y t.y_power)) 0 terms

let at_float terms x y =
  List.fold_left
    (fun total t -> total +. (float t.coefficient *. (x ** float t.x_power) *. (y ** float t.y_power)))
    0. terms

(* What was generated besides the kinds: every value of every number, and
   every way an equation is printed. *)
let noted = Hashtbl.create 64
let note what = Hashtbl.replace noted what ()
let between low high n = low <= n && n <= high

(* The forms of the equations. Each one checks that the curve read is of its
   form, with numbers in the ranges of the grammar, and notes them. *)
let circle k c =
  match (c.left, c.right) with
  | ( [ { coefficient = 1; x_power = 2; y_power = 0 }; { coefficient = 1; x_power = 0; y_power = 2 } ],
      [ { coefficient = constant; x_power = 0; y_power = 0 } ] )
    when constant > 0 ->
      ()
  | _ -> failwith (k ^ ": not a circle x^2 + y^2 = c")

(* p x^2 + q y^2 = c with p from 1 to 4 and q from -3 to 4, not 0. p and q
   are different, or it would be a circle, and have no common factor, or the
   equation would not be in lowest terms. The constant is not 0: that would
   be a point, or a pair of lines. *)
let conic k c =
  match (c.left, c.right) with
  | ( [ { coefficient = p; x_power = 2; y_power = 0 }; { coefficient = q; x_power = 0; y_power = 2 } ],
      [ { coefficient = constant; x_power = 0; y_power = 0 } ] ) ->
      if not (between 1 4 p) then failwith (Printf.sprintf "%s: p = %d" k p);
      if q = 0 || not (between (-3) 4 q) then failwith (Printf.sprintf "%s: q = %d" k q);
      if p = q then failwith (k ^ ": a circle is offered as a conic");
      if gcd p q <> 1 then failwith (Printf.sprintf "%s: p = %d and q = %d have a common factor" k p q);
      if constant = 0 then failwith (k ^ ": the constant is 0");
      note (Printf.sprintf "%s: p = %d" k p);
      note (Printf.sprintf "%s: q = %d" k q);
      note (Printf.sprintf "%s: %s" k (if q > 0 then "an ellipse" else "a hyperbola"));
      if constant < 0 then note (k ^ ": a negative constant")
  | _ -> failwith (k ^ ": not a curve p x^2 + q y^2 = c")

let product_factor k factor =
  if factor = 0 || not (between (-3) 3 factor) then failwith (Printf.sprintf "%s: k = %d" k factor);
  note (Printf.sprintf "%s: k = %d" k factor)

(* x^2 + k x y + y^2 = c. The left side A x^2 + B x y + C y^2 is not a
   perfect square, which it is when B^2 = 4 A C: the equation would be that
   of two parallel lines. *)
let product k c =
  match (c.left, c.right) with
  | ( [ { coefficient = 1; x_power = 2; y_power = 0 }; { coefficient = factor; x_power = 1; y_power = 1 };
        { coefficient = 1; x_power = 0; y_power = 2 } ],
      [ { coefficient = constant; x_power = 0; y_power = 0 } ] ) ->
      if factor * factor = 4 * 1 * 1 then failwith (k ^ ": the left side is a perfect square, a pair of lines");
      product_factor k factor;
      if constant < 0 then note (k ^ ": a negative constant")
  | _ -> failwith (k ^ ": not a curve x^2 + k x y + y^2 = c")

(* x^3 + y^3 = k x y + c, where a constant of 0 is not written. *)
let cubic k c =
  let cubes = function
    | [ { coefficient = 1; x_power = 3; y_power = 0 }; { coefficient = 1; x_power = 0; y_power = 3 } ] -> true
    | _ -> false
  in
  match (cubes c.left, c.right) with
  | true, [ { coefficient = factor; x_power = 1; y_power = 1 } ] ->
      product_factor k factor;
      note (k ^ ": no constant")
  | true, [ { coefficient = factor; x_power = 1; y_power = 1 }; { coefficient = constant; x_power = 0; y_power = 0 } ] ->
      product_factor k factor;
      if constant = 0 then failwith (k ^ ": a constant of 0 is written");
      note (k ^ if constant > 0 then ": a constant added" else ": a constant taken away")
  | _ -> failwith (k ^ ": not a curve x^3 + y^3 = k x y + c")

(* The point, with neither coordinate zero and both from -4 to 4. *)
let point k across up =
  let a = int_of_string across and b = int_of_string up in
  if a = 0 || b = 0 then failwith (k ^ ": a coordinate of the point is 0");
  if not (between (-4) 4 a && between (-4) 4 b) then failwith (k ^ ": a coordinate of the point is beyond 4");
  note (Printf.sprintf "%s: x = %d" k a);
  note (Printf.sprintf "%s: y = %d" k b);
  (a, b)

(* What the curve does at the point: the partial derivatives there, F_y with
   the terms in both x and y left out, F_x / F_y at any point in floats, and
   the curve itself near the point, as the y that Newton's method finds for
   the x that is `aside` away.

   The curve must not hold a straight line through the point. Such a line
   would be the tangent, which runs along (F_y, -F_x). On it F is a
   polynomial in the distance gone, of the degree of F at most, and it is 0
   at the point: if it is 0 at as many more places as its degree, it is 0
   all along the line. *)
let flaw f (a, b) =
  let f_x = at (d_x f) a b and f_y = at (d_y f) a b in
  if f_y = 0 then Some "the tangent is upright"
  else if f_x = 0 then Some "the tangent is level"
  else
    let degree = List.fold_left (fun highest t -> max highest (t.x_power + t.y_power)) 0 f in
    let common = gcd f_x f_y in
    let along = f_y / common and rise = -f_x / common in
    if List.for_all (fun step -> at f (a + (step * along)) (b + (step * rise)) = 0) (List.init degree (fun i -> i + 1))
    then Some "the curve holds the whole straight line through the point, it is not a curve there"
    else None

type study = {
  a : int;
  b : int;
  f_x : int;
  f_y : int;
  f_xx : int;
  f_xy : int;
  f_yy : int;
  f_y_alone : int;
  ratio : float -> float -> float;
  near : float -> float;
}

let study k c (a, b) =
  let f = difference c in
  if at f a b <> 0 then failwith (k ^ ": the point is not on the curve");
  let f_x = at (d_x f) a b and f_y = at (d_y f) a b in
  (match flaw f (a, b) with Some what -> failwith (k ^ ": " ^ what) | None -> ());
  let near aside =
    let x = float a +. aside in
    let rec solve y steps =
      if steps > 60 then failwith (k ^ ": Newton's method does not settle on the curve near the point");
      let step = at_float f x y /. at_float (d_y f) x y in
      if Float.abs step < 1e-14 then y -. step else solve (y -. step) (steps + 1)
    in
    solve (float b) 0
  in
  {
    a;
    b;
    f_x;
    f_y;
    f_xx = at (d_x (d_x f)) a b;
    f_xy = at (d_y (d_x f)) a b;
    f_yy = at (d_y (d_y f)) a b;
    f_y_alone = at (d_y (List.filter (fun t -> t.x_power = 0) f)) a b;
    ratio = (fun x y -> at_float (d_x f) x y /. at_float (d_y f) x y);
    near;
  }

(* The right answer of a question, the answer of each mistake its form has a
   line for, and the answer found again in floats with the tolerance it is
   held to, all from the prompt. *)
type working = { right : fraction; slips : (string * fraction) list; estimate : float; tolerance : float }

let aside = 1e-6

let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | ("circle" | "conic" | "product" | "cubic") as k -> (
      match fields 4 slope_sentence p with
      | [ noun; equation; across; up ] ->
          if (noun = "circle") <> (k = "circle") then failwith (k ^ ": called a " ^ noun);
          let c = curve equation in
          (match k with "circle" -> circle k c | "conic" -> conic k c | "product" -> product k c | _ -> cubic k c);
          let s = study k c (point k across up) in
          let missed =
            if k = "product" || k = "cubic" then [ ("product_rule_missed", fraction (-s.f_x) s.f_y_alone) ] else []
          in
          {
            right = fraction (-s.f_x) s.f_y;
            slips = ("sign_dropped", fraction s.f_x s.f_y) :: missed;
            estimate = (s.near aside -. s.near (-.aside)) /. (2. *. aside);
            tolerance = 1e-5;
          }
      | _ -> failwith "four fields were expected")
  | "related_rate" as k -> (
      match fields 4 rate_sentence p with
      | [ equation; across; up; rate ] ->
          let c = curve equation in
          circle k c;
          let s = study k c (point k across up) in
          let rate = int_of_string rate in
          if rate = 0 || not (between (-5) 5 rate) then failwith (Printf.sprintf "%s: dx/dt = %d" k rate);
          note (Printf.sprintf "%s: dx/dt = %d" k rate);
          (* the point a moment before and a moment after *)
          let moved = float rate *. aside in
          {
            right = fraction (-s.f_x) s.f_y *: whole rate;
            slips = [ ("sign_dropped", fraction s.f_x s.f_y *: whole rate) ];
            estimate = (s.near moved -. s.near (-.moved)) /. (2. *. aside);
            tolerance = 1e-5;
          }
      | _ -> failwith "four fields were expected")
  | "tangent_intercept" as k -> (
      match fields 3 intercept_sentence p with
      | [ equation; across; up ] ->
          let c = curve equation in
          conic k c;
          let s = study k c (point k across up) in
          (* F_x (0 - a) + F_y (h - b) = 0 *)
          let right = whole s.b +: fraction (s.f_x * s.a) s.f_y in
          (* the line through the point with the slope +F_x / F_y, at x = 0 *)
          let slipped = whole s.b +: (fraction s.f_x s.f_y *: whole (-s.a)) in
          (* the line through the two points of the curve beside the point *)
          let before = s.near (-.aside) and after = s.near aside in
          let estimate = before +. ((after -. before) /. (2. *. aside) *. (0. -. (float s.a -. aside))) in
          { right; slips = [ ("sign_dropped", slipped) ]; estimate; tolerance = 1e-5 }
      | _ -> failwith "three fields were expected")
  | "second_derivative" as k -> (
      match fields 3 second_sentence p with
      | [ across; up; equation ] ->
          let c = curve equation in
          conic k c;
          let s = study k c (point k across up) in
          let above = (s.f_xx * s.f_y * s.f_y) - (2 * s.f_xy * s.f_x * s.f_y) + (s.f_yy * s.f_x * s.f_x) in
          (* The student's slope is g = F_x / F_y at every point. One more
             derivative along the curve, with g again for dy/dx: g_x + g_y g,
             each part by the quotient rule. *)
          let square = s.f_y * s.f_y in
          let g = fraction s.f_x s.f_y in
          let g_x = fraction ((s.f_xx * s.f_y) - (s.f_x * s.f_xy)) square
          and g_y = fraction ((s.f_xy * s.f_y) - (s.f_x * s.f_yy)) square in
          let slipped = g_x +: (g_y *: g) in
          (* the same in floats: how g changes along the line of slope g *)
          let gone = aside *. to_float g in
          let changed =
            (s.ratio (float s.a +. aside) (float s.b +. gone) -. s.ratio (float s.a -. aside) (float s.b -. gone))
            /. (2. *. aside)
          in
          if Float.abs (changed -. to_float slipped) > 1e-5 *. (1. +. Float.abs (to_float slipped)) then
            failwith
              (Printf.sprintf "%s: the wrong slope changes at the rate %.9g along itself, not %s" k changed (show slipped));
          let wide = 1e-4 in
          {
            right = fraction (-above) (s.f_y * s.f_y * s.f_y);
            slips = [ ("sign_dropped", slipped) ];
            estimate = (s.near wide -. (2. *. float s.b) +. s.near (-.wide)) /. (wide *. wide);
            tolerance = 1e-4;
          }
      | _ -> failwith "three fields were expected")
  | k -> failwith ("unknown kind " ^ k)

(* How much of what a form can draw makes a question, by the checks above
   alone: the equation is built from each choice of its numbers and of its
   point, with the constant that puts the point on it, and must have no flaw
   there. The engine draws a form again when it refuses a question, so a
   form turns up in proportion to its weight times this share. (p and q are
   drawn again on their own until they suit, so only pairs that suit are
   counted; k is drawn from -3 to 3 with the form.) *)
let nonzero low high = List.filter (fun n -> n <> 0) (List.init (high - low + 1) (fun i -> low + i))
let monomial coefficient x_power y_power = { coefficient; x_power; y_power }

let asked k =
  let points = List.concat_map (fun a -> List.map (fun b -> (a, b)) (nonzero (-4) 4)) (nonzero (-4) 4) in
  let share sides =
    let good =
      List.concat_map
        (fun terms -> List.map (fun (a, b) -> flaw (terms @ [ monomial (-at terms a b) 0 0 ]) (a, b) = None) points)
        sides
    in
    float (List.length (List.filter Fun.id good)) /. float (List.length good)
  in
  match k with
  | "product" ->
      share (List.map (fun factor -> [ monomial 1 2 0; monomial factor 1 1; monomial 1 0 2 ]) (nonzero (-3) 3))
  | "cubic" ->
      share (List.map (fun factor -> [ monomial 1 3 0; monomial 1 0 3; monomial (-factor) 1 1 ]) (nonzero (-3) 3))
  | "conic" | "tangent_intercept" | "second_derivative" ->
      share
        (List.concat_map
           (fun p ->
             List.filter_map
               (fun q -> if p <> q && gcd p q = 1 then Some [ monomial p 2 0; monomial q 0 2 ] else None)
               (nonzero (-3) 4))
           (nonzero 1 4))
  | _ -> 1.

let () =
  let base = load_file "implicit_differentiation.rhm" in
  (* each kind with its price and its weight among the kinds of that price *)
  let prices =
    [ ("circle", 1, 1); ("conic", 1, 2); ("product", 2, 2); ("cubic", 2, 2); ("related_rate", 2, 1);
      ("tangent_intercept", 3, 2); ("second_derivative", 3, 2) ]
  in
  let per_budget = 1500 in
  let seen = Hashtbl.create 8 and made = Hashtbl.create 2 in
  let times k = match Hashtbl.find_opt seen k with Some n -> n | None -> 0 in
  (* No form is offered at any other budget. *)
  List.iter
    (fun cost ->
      let spec = with_initial base "cost" cost in
      for seed = 0 to 4 do
        Random.init seed;
        match Rhema_engine.generate spec with
        | exception Rhema_engine.Generation_error _ -> ()
        | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
      done)
    [ 0; 4; 5 ];
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to per_budget - 1 do
      Random.init (seed + (10000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k (times k + 1);
          if not (List.exists (fun (name, price, _) -> name = k && price = cost) prices) then
            fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          match (number q.Rhema_engine.answer, q.Rhema_engine.answers) with
          | None, _ | _, ([] | _ :: _ :: _) -> fail (Printf.sprintf "%s: one number was expected as the answer of %S" k p)
          | Some got, [ _ ] -> (
              match expected q with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | { right; slips; estimate; tolerance } ->
                  if got <> right then
                    fail (Printf.sprintf "%s: answer %s, recomputed %s, for %S" k (show got) (show right) p);
                  if Float.abs (estimate -. to_float right) > tolerance *. (1. +. Float.abs (to_float right)) then
                    fail
                      (Printf.sprintf "%s: the curve itself gives %.9g near the point, not %s, for %S" k estimate
                         (show right) p);
                  (* a question is asked only where each mistake gives another number *)
                  List.iter
                    (fun (name, slip) ->
                      if slip = right then
                        fail (Printf.sprintf "%s: %s gives the right answer %s, for %S" k name (show right) p))
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
                      Hashtbl.replace made m.mistake ();
                      if m.description = "" then fail (m.mistake ^ " has no description");
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
  List.iter (fun (k, _, _) -> if times k = 0 then fail ("never generated: " ^ k)) prices;
  (* The kinds of one price turn up in the shares that their weights give,
     each weight counted for the questions the form is not refused, to
     within a sixth of the share either way. *)
  List.iter
    (fun (k, price, weight) ->
      let pull name w = float w *. asked name in
      let all = List.fold_left (fun sum (name, other, w) -> if other = price then sum +. pull name w else sum) 0. prices in
      let share = float per_budget *. pull k weight /. all in
      if Float.abs (float (times k) -. share) > share /. 6. then
        fail (Printf.sprintf "%s: %d of the %d questions of its price, where about %.0f were expected" k (times k) per_budget share))
    prices;
  List.iter
    (fun mistake -> if not (Hashtbl.mem made mistake) then fail ("never listed: " ^ mistake))
    [ "sign_dropped"; "product_rule_missed" ];
  let each k what values = List.map (fun n -> Printf.sprintf "%s: %s = %d" k what n) values in
  let wanted =
    List.concat_map (fun (k, _, _) -> each k "x" (nonzero (-4) 4) @ each k "y" (nonzero (-4) 4)) prices
    @ List.concat_map
        (fun k ->
          each k "p" (nonzero 1 4)
          @ each k "q" (nonzero (-3) 4)
          @ [ k ^ ": an ellipse"; k ^ ": a hyperbola"; k ^ ": a negative constant" ])
        [ "conic"; "tangent_intercept"; "second_derivative" ]
    @ each "product" "k" [ -3; -1; 1; 3 ]
    @ each "cubic" "k" (nonzero (-3) 3)
    @ [ "product: a negative constant"; "cubic: no constant"; "cubic: a constant added"; "cubic: a constant taken away" ]
    @ each "related_rate" "dx/dt" (nonzero (-5) 5)
  in
  List.iter (fun what -> if not (Hashtbl.mem noted what) then fail ("never generated: " ^ what)) wanted;
  if !failures = 0 then print_endline "Rhema implicit differentiation tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d implicit differentiation test(s) failed." !failures);
    exit 1
  end
