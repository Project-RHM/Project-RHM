(* Independent checks for triangles.rhm. Every question is matched against
   the whole sentence of its form, the numbers are read back from it, and the
   answer is found again here by drawing the triangle in coordinates and
   measuring it, never by the trigonometric formula the grammar works with.
   The measured number is a float; it must agree with the engine's exact
   answer to nine places.

   The measuring, form by form:

     area_two_sides  one side is laid along the x-axis from the origin and
                     the other from the origin at the printed angle (the
                     cosine and sine of the angle in floats): three corners,
                     whose area is taken by the shoelace formula
     cosine          the side c is laid along the x-axis and the third
                     corner C is where the circle of radius b about one end
                     meets the circle of radius a about the other; the answer
                     is the dot product of the two sides that leave C, over
                     their measured lengths. The three sides must make a
                     triangle and a^2 + b^2 must not be c^2, so that the
                     angle is not a right angle
     third_side      the corners as for the area; the answer is the measured
                     distance between the two free corners, and must be a
                     whole number
     sine_rule       the side opposite A is laid from B to C along the
                     x-axis; the third angle is what the two printed ones
                     leave of 180 degrees, which must be something; the ray
                     from B at the angle B and the ray from C at the third
                     angle are intersected, and they must meet in front of
                     both; the angle measured at that corner must be the
                     printed A, and the answer is the measured distance from
                     it to C. The two printed angles must have different
                     sines
     heron           the triangle is placed by intersecting two circles and
                     its area taken by the shoelace formula; it must be whole
     circumradius    the centre is where the perpendicular bisectors of two
                     sides meet; its distances to the three corners must be
                     one number, the answer
     inradius        the centre is where the bisectors of two angles meet
                     (each along the sum of the two unit vectors that leave
                     the corner); its distances to the lines of the three
                     sides must be one number, the answer
     altitude        the distance from the opposite corner to the line of
                     the side named, which must be the last of the three and
                     no shorter than the others
     ambiguous       the angle of 30 degrees is put at the origin, the side
                     b along the x-axis to its end E, and the triangles are
                     counted: the points of the other arm, the ray at 30
                     degrees, in front of the origin, whose distance to E is
                     a. They lie on either side of the foot of the
                     perpendicular from E, half a chord away, or at the foot
                     itself when the arm only touches the circle, or nowhere
                     when the arm passes outside it. Each point counted is
                     built and its distance to E measured. b must be even

   How an answer is written follows from the number measured, by the promise
   of the header: every answer is a `plain` answer; a fraction is a number;
   anything else is a positive fraction times sqrt(2), sqrt(3) or sqrt(6),
   written as that fraction in front of the root, and which of the three is
   found here by trying each. A third side, the area of a triangle with
   three whole sides and a count of triangles are whole numbers; a cosine and
   the three measures of the price 3 are fractions. An answer with a root is
   worth less than 1000, since WeBWorK grades to one part in a thousand.

   The mistakes are worked out from what their descriptions say the student
   does: the product of the two sides and the sine, without the 1/2; the law
   of cosines with the sign of its cosine term turned (for the cosine itself
   that is the negative of the right value, for a third side the root of
   p^2 + q^2 + 2 p q cos C); the root of p^2 + q^2; the side times sin A
   over sin B; Heron's formula with the whole perimeter for s; the area over
   the whole perimeter for the radius of the inscribed circle. Each form
   must list exactly its mistakes, in the order of the declarations, with
   these values, each more than 1% away from the right answer, each a plain
   answer made of numbers and square roots alone, and each described word
   for word as the grammar declares it. Leaving out the 1/2 and turning a
   ratio over do not change the root, so those two are written as the right
   answer is: a number, or a fraction in front of the same root. The
   circumradius, the altitude and the count of triangles list none.

   Besides the answers: every kind comes up at its price and at no other and
   spends its budget; the grammar's own budget gives a question of price 2;
   a budget outside 1 to 3 gives no question; every question has one blank.
   What each form is asked with is pinned: every choice the grammar offers
   must come up, and nothing else. For the cosine that is each side on its
   own, and that the third side comes as close as a whole number can to the
   difference and to the sum of the other two. Those choices and the
   descriptions are the only things taken from the grammar. The working of
   this file is itself tried first on triangles with known measures. The
   weights are not looked at. *)

module F = Rhema_formula

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

(* Two numbers that are the same to nine places of the larger. *)
let near a b = Float.abs (a -. b) <= 1e-9 *. Float.max (Float.abs a) (Float.abs b)

let range first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)

(* ---- Points, lines and triangles ------------------------------------------ *)

type point = { x : float; y : float }

let origin = { x = 0.0; y = 0.0 }
let on_axis length = { x = float_of_int length; y = 0.0 }
let ( -- ) p q = { x = p.x -. q.x; y = p.y -. q.y }
let ( ++ ) p q = { x = p.x +. q.x; y = p.y +. q.y }
let scaled s u = { x = s *. u.x; y = s *. u.y }
let dot u v = (u.x *. v.x) +. (u.y *. v.y)
let cross u v = (u.x *. v.y) -. (u.y *. v.x)
let length u = sqrt (dot u u)
let distance p q = length (p -- q)
let unit u = scaled (1.0 /. length u) u
let quarter_turn u = { x = -.u.y; y = u.x }
let middle p q = scaled 0.5 (p ++ q)
let radians degrees = float_of_int degrees *. Float.pi /. 180.0

(* The unit vector at an angle to the x-axis. *)
let direction degrees = { x = cos (radians degrees); y = sin (radians degrees) }

(* The shoelace formula for the area of a triangle. *)
let area (p, q, r) =
  Float.abs (cross p q +. cross q r +. cross r p) /. 2.0

(* The distance from a point to the line through two others. *)
let from_line p a b = Float.abs (cross (b -- a) (p -- a)) /. distance a b

(* The cosine of the angle at p between the sides to q and to r. *)
let cosine_at p q r = dot (q -- p) (r -- p) /. (distance p q *. distance p r)

(* Where the line from p along u meets the line from q along v: the point,
   and how far along each line it is, in lengths of u and of v. *)
let meet p u q v =
  let determinant = cross v u and d = q -- p in
  if Float.abs determinant <= 1e-12 *. length u *. length v then failwith "two lines that should meet are parallel";
  let s = cross v d /. determinant and t = cross u d /. determinant in
  (p ++ scaled s u, s, t)

(* Two sides from the origin with an angle between them: the first along the
   x-axis, the second at the angle. The corner of the angle comes first. *)
let hinged p q degrees =
  if p <= 0 || q <= 0 || degrees <= 0 || degrees >= 180 then failwith "two sides and an angle that make no triangle";
  (origin, on_axis p, scaled (float_of_int q) (direction degrees))

(* A triangle with three given sides: the first from P to Q along the
   x-axis, the second from Q to R, the third from R to P. R is where the
   circle of the third side about P meets the circle of the second about Q,
   above the axis. The sides it is built with are measured again. *)
let with_sides first second third =
  if first <= 0 || second <= 0 || third <= 0 then failwith "a side that is not positive";
  if first >= second + third || second >= first + third || third >= first + second then
    failwith "the three sides do not make a triangle";
  let a = float_of_int first and b = float_of_int second and c = float_of_int third in
  (* on both circles: x^2 + y^2 = c^2 and (x - a)^2 + y^2 = b^2 *)
  let x = ((a *. a) +. (c *. c) -. (b *. b)) /. (2.0 *. a) in
  let y = sqrt ((c *. c) -. (x *. x)) in
  let p = origin and q = on_axis first and r = { x; y } in
  if not (y > 0.0 && near (distance p q) a && near (distance q r) b && near (distance r p) c) then
    failwith "the triangle built does not have the three sides";
  (p, q, r)

(* A triangle from the side opposite A and the angles A and B: the side
   from B to C along the x-axis, a ray from B at the angle B, a ray from C
   at the angle that is left for C. The corners come as A, B, C. *)
let with_side_and_angles side at_a at_b =
  let at_c = 180 - at_a - at_b in
  if side <= 0 || at_a <= 0 || at_b <= 0 then failwith "a side or an angle that is not positive";
  if at_c <= 0 then failwith "the two angles leave no room for a third";
  let b = origin and c = on_axis side in
  let a, from_b, from_c = meet b (direction at_b) c (direction (180 - at_c)) in
  if not (from_b > 0.0 && from_c > 0.0) then failwith "the two rays do not meet";
  if Float.abs (acos (cosine_at a b c) -. radians at_a) > 1e-9 then failwith "the angle at A is not the printed one";
  (a, b, c)

(* The centre of the circle through the three corners is on the
   perpendicular bisector of each side; two of them are intersected. Its
   distances to the three corners must be one number. *)
let circumradius (p, q, r) =
  let bisector a b = (middle a b, quarter_turn (b -- a)) in
  let from_pq, along_pq = bisector p q and from_qr, along_qr = bisector q r in
  let centre, _, _ = meet from_pq along_pq from_qr along_qr in
  let radius = distance centre p in
  if not (near radius (distance centre q) && near radius (distance centre r)) then
    failwith "the centre found is not as far from each corner";
  radius

(* The centre of the circle inside is on the bisector of each angle, which
   leaves the corner along the sum of the unit vectors of its two sides; two
   of them are intersected. Its distances to the three sides must be one
   number. *)
let inradius (p, q, r) =
  let bisector a b c = unit (b -- a) ++ unit (c -- a) in
  let centre, _, _ = meet p (bisector p q r) q (bisector q r p) in
  let radius = from_line centre p q in
  if not (near radius (from_line centre q r) && near radius (from_line centre r p)) then
    failwith "the centre found is not as far from each side";
  radius

(* The triangles with an angle of `degrees` at the origin, the side b along
   the x-axis to its end E, and the side a opposite the angle: the third
   corner is a point of the other arm, in front of the origin, at the
   distance a from E. Such points are on either side of the foot of the
   perpendicular from E to the arm, half a chord away. The sides are whole,
   so a point is in front of the origin, or the arm touches the circle, by a
   wide margin or not at all. Each point counted is measured again. *)
let triangles_with ~degrees ~opposite ~adjacent =
  if opposite <= 0 || adjacent <= 0 then failwith "a side that is not positive";
  let a = float_of_int opposite and b = float_of_int adjacent in
  let arm = direction degrees and e = on_axis adjacent in
  let foot = dot e arm and away = from_line e origin arm in
  let margin = 1e-9 *. b in
  let places =
    if a < away -. margin then []
    else if a <= away +. margin then [ foot ]
    else
      let half_chord = sqrt ((a *. a) -. (away *. away)) in
      [ foot -. half_chord; foot +. half_chord ]
  in
  let corners = List.filter_map (fun t -> if t > margin then Some (scaled t arm) else None) places in
  List.iter
    (fun corner ->
      if not (near (distance corner e) a) then failwith "a triangle counted does not have the side opposite the angle";
      if Float.abs (acos (cosine_at origin e corner) -. radians degrees) > 1e-9 then
        failwith "a triangle counted does not have the angle")
    corners;
  List.length corners

(* ---- How a number is written ---------------------------------------------- *)

(* A number that is a fraction with a small denominator, to nine places. *)
let is_fraction v =
  List.exists
    (fun q ->
      let multiple = v *. float_of_int q in
      Float.abs (multiple -. Float.round multiple) <= 1e-9 *. Float.max 1.0 (Float.abs multiple))
    (range 1 24)

(* What stands under the root of an exact value: 1 for a fraction, or the 2,
   3 or 6 that a fraction is multiplied by the root of. *)
let radicand v = List.find_opt (fun n -> is_fraction (v /. sqrt (float_of_int n))) [ 1; 2; 3; 6 ]

(* An answer of the engine: what it comes to, whether it is graded with the
   functions switched off, and how it is written. *)
type written =
  | Fraction  (* a number *)
  | Root of int  (* a formula: a positive number, or nothing, in front of the root of this whole number above 1 *)
  | Bare  (* a formula that is a number and nothing more *)
  | Other

type given = { number : float; plain : bool; written : written; whole : bool }

let given value =
  let positive c = Rhema_number.compare c Rhema_number.zero > 0 in
  let under n = if Rhema_number.is_integer n && n.Rhema_number.numerator > 1 then Root n.Rhema_number.numerator else Other in
  let inner plain = function
    | Rhema_engine.Num n -> { number = Rhema_number.to_float n; plain; written = Fraction; whole = Rhema_number.is_integer n }
    | Rhema_engine.Formula f ->
        let written =
          match f with
          | F.Sqrt (F.Constant n) -> under n
          | F.Multiply (F.Constant c, F.Sqrt (F.Constant n)) when positive c -> under n
          | F.Constant _ -> Bare
          | _ -> Other
        in
        { number = F.evaluate_with (fun _ -> None) f; plain; written; whole = false }
    | other -> failwith ("not a number: " ^ Rhema_engine.describe_value other)
  in
  match value with Rhema_engine.Plain value -> inner true value | value -> inner false value

(* ---- Reading a question ---------------------------------------------------- *)

(* The pattern of a prompt is the whole sentence, with a group wherever a
   number stands. A number is written without a sign and without a leading
   zero; no form prints a zero. *)
let words = Str.quote
let a_number = "\\([1-9][0-9]*\\)"

let numbers_of count pattern text =
  if Str.string_match (Str.regexp (pattern ^ "$")) text 0 && Str.match_end () = String.length text then
    Some (List.init count (fun n -> int_of_string (Str.matched_group (n + 1) text)))
  else None

let sentence parts = String.concat a_number (List.map words parts)
let hint = " Give the exact value, with a square root written as sqrt."

let two_sides_and_angle asked =
  sentence
    [ "Two sides of a triangle are [`"; "`] and [`"; "`] long, and the angle between them is [`";
      {|^{\circ}`]. |} ^ asked ^ hint ]

let three_sides asked = sentence [ "A triangle has sides [`"; "`], [`"; "`] and [`"; "`]. Find " ^ asked ]

(* ---- What was generated ---------------------------------------------------- *)

(* What each form was asked with, to compare at the end with the choices the
   grammar offers: none may be missing and none may be new. *)
let noted : (string * string, unit) Hashtbl.t = Hashtbl.create 512

let note label what = Hashtbl.replace noted (label, what) ()
let note_int label value = note label (string_of_int value)
let numbers values = String.concat " " (List.map string_of_int values)

(* ---- The answers, form by form --------------------------------------------- *)

(* How the right answer must be written. *)
type shape =
  | Whole  (* a whole number *)
  | Rational  (* a fraction *)
  | Exact  (* a fraction, or a fraction times sqrt(2), sqrt(3) or sqrt(6) *)

(* The right answer measured here, how it must be written, and the answer of
   each mistake of the form, in the order of the declarations. *)
type expected = { want : float; shape : shape; slips : (string * float) list }

let square n = float_of_int (n * n)

let expected (q : Rhema_engine.question) =
  let k = kind q and p = q.Rhema_engine.prompt in
  let read count pattern =
    match numbers_of count pattern p with Some values -> values | None -> failwith "the wording is not the expected one"
  in
  match k with
  | "area_two_sides" -> (
      match read 3 (two_sides_and_angle "Find the area of the triangle.") with
      | [ first; second; degrees ] ->
          note_int (k ^ ": first side") first;
          note_int (k ^ ": second side") second;
          note_int (k ^ ": angle") degrees;
          let want = area (hinged first second degrees) in
          { want; shape = Exact; slips = [ ("half_forgotten", float_of_int (first * second) *. sin (radians degrees)) ] }
      | _ -> assert false)
  | "cosine" -> (
      match
        read 3
          (sentence
             [ "A triangle has the sides [`a = "; "`], [`b = "; "`] and [`c = ";
               "`]. Find the cosine of the angle opposite the side [`c`], the angle between the sides [`a`] and [`b`]." ])
      with
      | [ a; b; c ] ->
          note_int (k ^ ": a") a;
          note_int (k ^ ": b") b;
          note_int (k ^ ": c") c;
          note (k ^ ": c above the difference of a and b by") (if c - abs (a - b) = 1 then "1" else "more");
          note (k ^ ": c below the sum of a and b by") (if a + b - c = 1 then "1" else "more");
          if (a * a) + (b * b) = c * c then failwith "the angle asked for is a right angle";
          (* the side c from P to Q, the side a from Q to C, the side b from C to P *)
          let from_c, to_c, corner = with_sides c a b in
          let want = cosine_at corner from_c to_c in
          { want; shape = Rational; slips = [ ("cosine_term_sign", -.want) ] }
      | _ -> assert false)
  | "third_side" -> (
      match read 3 (two_sides_and_angle "Find the length of the third side.") with
      | [ first; second; degrees ] ->
          note (k ^ ": sides and angle") (numbers [ first; second; degrees ]);
          let _, end_of_first, end_of_second = hinged first second degrees in
          let squares = square first +. square second in
          { want = distance end_of_first end_of_second;
            shape = Whole;
            slips =
              [ ("cosine_term_sign", sqrt (squares +. (2.0 *. float_of_int (first * second) *. cos (radians degrees))));
                ("pythagoras_used", sqrt squares) ] }
      | _ -> assert false)
  | "sine_rule" -> (
      match
        read 3
          (sentence
             [ "In a triangle, the angle [`A`] is [`"; {|^{\circ}`] and the angle [`B`] is [`|};
               {|^{\circ}`]. The side opposite [`A`] is [`|};
               "`] long. Find the length of the side opposite [`B`]." ^ hint ])
      with
      | [ at_a; at_b; side ] ->
          note_int (k ^ ": side") side;
          note (k ^ ": angles") (numbers [ at_a; at_b ]);
          let sine_a = sin (radians at_a) and sine_b = sin (radians at_b) in
          if at_a = at_b || near sine_a sine_b then failwith "the two angles have the same sine";
          let a, _, c = with_side_and_angles side at_a at_b in
          { want = distance a c; shape = Exact; slips = [ ("sines_inverted", float_of_int side *. sine_a /. sine_b) ] }
      | _ -> assert false)
  | "heron" -> (
      match read 3 (three_sides "its area.") with
      | [ a; b; c ] ->
          note (k ^ ": sides") (numbers [ a; b; c ]);
          let around = float_of_int (a + b + c) in
          let slip = sqrt (around *. (around -. float_of_int a) *. (around -. float_of_int b) *. (around -. float_of_int c)) in
          { want = area (with_sides a b c); shape = Whole; slips = [ ("perimeter_for_semiperimeter", slip) ] }
      | _ -> assert false)
  | "circumradius" -> (
      match read 3 (three_sides "the radius of the circle through its three corners.") with
      | [ a; b; c ] ->
          note (k ^ ": sides") (numbers [ a; b; c ]);
          { want = circumradius (with_sides a b c); shape = Rational; slips = [] }
      | _ -> assert false)
  | "inradius" -> (
      match read 3 (three_sides "the radius of the circle inside it that touches its three sides.") with
      | [ a; b; c ] ->
          note (k ^ ": sides") (numbers [ a; b; c ]);
          let triangle = with_sides a b c in
          { want = inradius triangle;
            shape = Rational;
            slips = [ ("perimeter_for_semiperimeter", area triangle /. float_of_int (a + b + c)) ] }
      | _ -> assert false)
  | "altitude" -> (
      match
        read 4 (sentence [ "A triangle has sides [`"; "`], [`"; "`] and [`"; "`]. Find its altitude to the side [`"; "`]." ])
      with
      | [ a; b; c; base ] ->
          note (k ^ ": sides") (numbers [ a; b; c ]);
          if base <> c then failwith "the altitude is not to the last of the three sides";
          if c < a || c < b then failwith "the last of the three sides is not the longest";
          (* the last side runs from R back to P, opposite Q *)
          let from_base, opposite, to_base = with_sides a b c in
          { want = from_line opposite to_base from_base; shape = Rational; slips = [] }
      | _ -> assert false)
  | "ambiguous" -> (
      match
        read 3
          (sentence
             [ "How many triangles, different in shape, have an angle [`A`] of [`"; {|^{\circ}`], the side opposite [`A`] [`|};
               "`] long and another side [`"; "`] long?" ])
      with
      | [ degrees; opposite; adjacent ] ->
          note_int (k ^ ": angle") degrees;
          note (k ^ ": sides") (numbers [ adjacent; opposite ]);
          if adjacent mod 2 <> 0 then failwith "the side along the arm is not even";
          let count = triangles_with ~degrees ~opposite ~adjacent in
          note (k ^ ": case")
            (match count with
            | 0 -> "none"
            | 2 -> "two"
            | _ -> if opposite >= adjacent then "one, the side opposite no shorter" else "one, touching");
          { want = float_of_int count; shape = Whole; slips = [] }
      | _ -> assert false)
  | _ -> failwith "an unknown kind"

(* ---- The working of this file, tried on triangles with known measures ------ *)

let check_working () =
  let try_number what found wanted =
    if not (near found wanted) then fail (Printf.sprintf "the working: %s is %.12g, found %.12g" what wanted found)
  in
  let try_count what found wanted =
    if found <> wanted then fail (Printf.sprintf "the working: %s is %d, found %d" what wanted found)
  in
  let refused what work =
    match work () with exception Failure _ -> () | _ -> fail ("the working: " ^ what ^ " is not refused")
  in
  let right = with_sides 3 4 5 in
  try_number "the area of 3, 4, 5" (area right) 6.0;
  try_number "the circumradius of 3, 4, 5" (circumradius right) 2.5;
  try_number "the inradius of 3, 4, 5" (inradius right) 1.0;
  (let p, q, r = right in
   try_number "the altitude of 3, 4, 5 to 5" (from_line q r p) 2.4;
   try_number "the altitude of 3, 4, 5 to 3" (from_line r p q) 4.0;
   if Float.abs (cosine_at q p r) > 1e-12 then fail "the working: the angle between 3 and 4 is a right angle");
  try_number "the circumradius of 13, 14, 15" (circumradius (with_sides 13 14 15)) 8.125;
  try_number "the inradius of 13, 14, 15" (inradius (with_sides 13 14 15)) 4.0;
  try_number "the area of 2, 3 at a right angle" (area (hinged 2 3 90)) 3.0;
  (let _, e, f = hinged 3 8 60 in
   try_number "the third side of 3, 8 at 60 degrees" (distance e f) 7.0);
  (let _, e, f = hinged 3 5 120 in
   try_number "the third side of 3, 5 at 120 degrees" (distance e f) 7.0);
  (let a, b, c = with_side_and_angles 1 30 90 in
   try_number "the hypotenuse opposite 90 degrees" (distance a c) 2.0;
   try_number "the side opposite 60 degrees" (distance a b) (sqrt 3.0));
  try_count "the triangles with 30 degrees, 4 opposite, 10 along" (triangles_with ~degrees:30 ~opposite:4 ~adjacent:10) 0;
  try_count "the triangles with 30 degrees, 5 opposite, 10 along" (triangles_with ~degrees:30 ~opposite:5 ~adjacent:10) 1;
  try_count "the triangles with 30 degrees, 7 opposite, 10 along" (triangles_with ~degrees:30 ~opposite:7 ~adjacent:10) 2;
  try_count "the triangles with 30 degrees, 9 opposite, 10 along" (triangles_with ~degrees:30 ~opposite:9 ~adjacent:10) 2;
  try_count "the triangles with 30 degrees, 10 opposite, 10 along" (triangles_with ~degrees:30 ~opposite:10 ~adjacent:10) 1;
  try_count "the triangles with 30 degrees, 12 opposite, 10 along" (triangles_with ~degrees:30 ~opposite:12 ~adjacent:10) 1;
  try_count "the triangles with 150 degrees, 9 opposite, 10 along" (triangles_with ~degrees:150 ~opposite:9 ~adjacent:10) 0;
  refused "a triangle with sides 2, 3, 5" (fun () -> with_sides 2 3 5);
  refused "a triangle with sides 9, 3, 5" (fun () -> with_sides 9 3 5);
  refused "a triangle with angles of 120 and 60 degrees" (fun () -> with_side_and_angles 4 120 60);
  refused "a triangle with angles of 150 and 45 degrees" (fun () -> with_side_and_angles 4 150 45);
  List.iter
    (fun (what, value, wanted) ->
      if radicand value <> wanted then fail ("the working: what stands under the root of " ^ what))
    [ ("7/2", 3.5, Some 1); ("7/2 sqrt(3)", 3.5 *. sqrt 3.0, Some 3); ("5/3 sqrt(2)", 5.0 /. 3.0 *. sqrt 2.0, Some 2);
      ("11/4 sqrt(6)", 2.75 *. sqrt 6.0, Some 6); ("sqrt(5)", sqrt 5.0, None); ("sqrt(97)", sqrt 97.0, None) ]

(* ---- The choices the grammar offers ---------------------------------------- *)

let angles = [ 30; 45; 60; 90; 120; 135; 150 ]

(* Two sides and the angle of 60 or 120 degrees between them, with a whole
   third side: the list of the grammar, either side first, up to three times
   as large. *)
let with_whole_third =
  List.concat_map
    (fun (short, long, degrees) ->
      List.concat_map
        (fun times -> [ numbers [ times * short; times * long; degrees ]; numbers [ times * long; times * short; degrees ] ])
        (range 1 3))
    [ (3, 8, 60); (5, 8, 60); (7, 15, 60); (8, 15, 60); (5, 21, 60); (16, 21, 60); (3, 5, 120); (7, 8, 120); (5, 16, 120) ]

(* The triangles with whole sides and a whole area, up to `largest` times as
   large. *)
let with_whole_area largest =
  List.concat_map
    (fun (a, b, c) -> List.map (fun times -> numbers [ times * a; times * b; times * c ]) (range 1 largest))
    [ (5, 5, 6); (5, 5, 8); (13, 14, 15); (9, 10, 17); (7, 15, 20); (10, 13, 13); (11, 13, 20); (4, 13, 15); (12, 17, 25);
      (13, 20, 21); (17, 25, 28); (13, 13, 24) ]

(* The side b along the arm is twice 3 to 10; the side a opposite the angle
   is up to 4 below half of b, half of b, up to 4 above it and still below
   b, or b and up to 3 more. *)
let two_sides_and_thirty =
  List.concat_map
    (fun half ->
      List.filter_map
        (fun a -> if (abs (a - half) <= 4 && a < 2 * half) || a >= 2 * half then Some (numbers [ 2 * half; a ]) else None)
        (range 1 ((2 * half) + 3)))
    (range 3 10)

let ints = List.map string_of_int

let offered =
  [ ("area_two_sides: first side", ints (range 2 12));
    ("area_two_sides: second side", ints (range 2 12));
    ("area_two_sides: angle", ints angles);
    ("cosine: a", ints (range 2 9));
    ("cosine: b", ints (range 2 9));
    ("cosine: c", ints (range 2 15));
    ("cosine: c above the difference of a and b by", [ "1"; "more" ]);
    ("cosine: c below the sum of a and b by", [ "1"; "more" ]);
    ("third_side: sides and angle", with_whole_third);
    ("sine_rule: side", ints (range 2 12));
    ( "sine_rule: angles",
      List.concat_map
        (fun at_a ->
          List.filter_map (fun at_b -> if at_a + at_b < 180 && at_a <> at_b then Some (numbers [ at_a; at_b ]) else None) angles)
        angles );
    ("heron: sides", with_whole_area 3);
    ("circumradius: sides", with_whole_area 2);
    ("inradius: sides", with_whole_area 2);
    ("altitude: sides", with_whole_area 2);
    ("ambiguous: angle", [ "30" ]);
    ("ambiguous: sides", two_sides_and_thirty);
    ("ambiguous: case", [ "none"; "one, touching"; "two"; "one, the side opposite no shorter" ]) ]

let questions_at cost = if cost = 1 then 3000 else 6000

let () =
  check_working ();
  let base = load_file "triangles.rhm" in
  let prices =
    [ ("area_two_sides", 1); ("cosine", 1); ("third_side", 2); ("sine_rule", 2); ("heron", 2); ("circumradius", 3);
      ("inradius", 3); ("altitude", 3); ("ambiguous", 3) ]
  in
  (* the description of each mistake, word for word, in the order of the
     declarations *)
  let described =
    [ ("half_forgotten", "gives the product of the two sides and the sine, without the 1/2 of the area of a triangle");
      ("cosine_term_sign", "gives the cosine term of the law of cosines the wrong sign");
      ("pythagoras_used", "uses Pythagoras' theorem, as if the angle between the two sides were a right angle");
      ("sines_inverted", "turns the ratio of the two sines over");
      ("perimeter_for_semiperimeter", "uses the whole perimeter where half the perimeter belongs") ]
  in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 16 in
  (* a budget below the lowest or above the highest is refused *)
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
  (* the grammar as it is written, with the budget it sets itself, gives a
     question of price 2 *)
  for seed = 0 to 19 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 || Rhema_engine.consumption q.Rhema_engine.tree "cost" <> 2 then
          fail (Printf.sprintf "the grammar's own budget gave %s, not a question of price 2" (kind q))
  done;
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at cost - 1 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          let wrong what = fail (Printf.sprintf "%s: %s, for %S with the answer %s" k what p q.Rhema_engine.answer_text) in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          match q.Rhema_engine.answers with
          | [ answer ] -> (
              match (given answer, expected q) with
              | exception Failure message -> wrong message
              | got, { want; shape; slips } ->
                  if not (near got.number want) then wrong (Printf.sprintf "the answer measured is %.12g" want);
                  if not got.plain then wrong "the answer is not a plain answer";
                  (* how the answer is written *)
                  (match shape with
                  | Whole -> if not (got.written = Fraction && got.whole) then wrong "the answer is not a whole number"
                  | Rational -> if got.written <> Fraction then wrong "the answer is not a fraction"
                  | Exact -> (
                      match radicand want with
                      | Some 1 -> if got.written <> Fraction then wrong "the answer is a fraction and is not written as one"
                      | Some n ->
                          if got.written <> Root n then
                            wrong (Printf.sprintf "the answer is not a fraction in front of sqrt(%d)" n);
                          if not (got.number < 1000.0) then wrong "an answer with a root is worth 1000 or more"
                      | None -> wrong "the answer measured is not a fraction times 1, sqrt(2), sqrt(3) or sqrt(6)"));
                  (* exactly the mistakes of the form, in order *)
                  let listed = q.Rhema_engine.mistakes in
                  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
                  if names <> List.map fst slips then
                    wrong
                      (Printf.sprintf "the mistakes listed are [%s], not [%s]" (String.concat ", " names)
                         (String.concat ", " (List.map fst slips)));
                  List.iter
                    (fun (m : Rhema_engine.mistaken) ->
                      Hashtbl.replace made (m.mistake, k) ();
                      (* each mistake is described as itself, not as another *)
                      (match List.assoc_opt m.mistake described with
                      | Some said ->
                          if m.description <> said then fail (Printf.sprintf "%s is described as %S" m.mistake m.description)
                      | None -> fail ("an unknown mistake is listed: " ^ m.mistake));
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match given value with
                          | exception Failure message -> wrong (m.mistake ^ ": " ^ message)
                          | mistaken ->
                              if not (near mistaken.number slip) then
                                wrong (Printf.sprintf "%s gives %.12g, worked out %.12g" m.mistake mistaken.number slip);
                              if not (mistaken.plain && mistaken.written <> Other) then
                                wrong (m.mistake ^ " is not a plain answer of numbers and square roots");
                              (* a factor of 2 or a ratio turned over leaves
                                 the root what it was *)
                              if shape = Exact && mistaken.written <> got.written then
                                wrong (m.mistake ^ " is not written with the root of the answer, or without one");
                              (* nor may a marker with a tolerance of one part
                                 in a thousand take it for the right answer *)
                              if not (Float.abs (slip -. want) > 0.01 *. Float.abs want) then
                                wrong (Printf.sprintf "%s gives %.12g, within 1%% of the answer %.12g" m.mistake slip want))
                      | _, None -> ()
                      | _, Some _ -> wrong (m.mistake ^ " does not give one answer"))
                    listed)
          | _ -> wrong "the question does not have one blank")
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k () -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  List.iter
    (fun (mistake, k) -> if not (Hashtbl.mem made (mistake, k)) then fail (Printf.sprintf "%s never listed on %s" mistake k))
    [ ("half_forgotten", "area_two_sides"); ("cosine_term_sign", "cosine"); ("cosine_term_sign", "third_side");
      ("pythagoras_used", "third_side"); ("sines_inverted", "sine_rule"); ("perimeter_for_semiperimeter", "heron");
      ("perimeter_for_semiperimeter", "inradius") ];
  (* every choice the grammar offers came up, and nothing else *)
  List.iter
    (fun (label, choices) ->
      List.iter (fun what -> if not (Hashtbl.mem noted (label, what)) then fail (label ^ ": never asked with " ^ what)) choices)
    offered;
  Hashtbl.iter
    (fun (label, what) () ->
      match List.assoc_opt label offered with
      | None -> fail (Printf.sprintf "%s, which is not expected of any question: asked with %s" label what)
      | Some choices -> if not (List.mem what choices) then fail (label ^ ": asked with " ^ what))
    noted;
  if !failures = 0 then print_endline "Rhema triangles tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d triangles test(s) failed." !failures);
    exit 1
  end
