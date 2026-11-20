(* Independent checks for lines_planes.rhm. The points, the vectors, the
   lines and the planes are read back from the printed question, and the
   answer is tested against what is asked by its definition, with exact
   fractions, not by repeating how the grammar built the question:

   - plane_constant: the printed left side has the components of the printed
     normal as its coefficients, and with d the answer the given point
     satisfies the equation.
   - point_on_line: the answer minus the base point is t times the
     direction, for the t printed.
   - distance: the test finds the foot itself (the point of the plane on the
     line through the given point along the normal) and measures; the answer
     is positive and its square is the squared length of that segment. No
     other point of the plane tried is nearer. The normal has whole length,
     which is why the answer is a fraction.
   - line_meets_plane: the answer is on the plane and on the line (the answer
     minus the base point is parallel to the direction), and the line is not
     parallel to the plane, so there is one such point only.
   - plane_angle: the angle is computed from the two normals with floats and
     its cosine compared with the answer; the answer is strictly between 0
     and 1, so the planes are neither parallel nor perpendicular; both
     normals have whole length; the two equations are not the same plane.
   - foot: the answer is on the plane, the given point minus the answer is
     parallel to the normal, the given point is not on the plane, and no
     other point of the plane tried is nearer.
   - reflection: the midpoint of the given point and the answer is on the
     plane, the answer minus the given point is parallel to the normal, and
     the answer is not the given point.

   For every kind: no normal and no direction has a zero component, a general
   normal (one that need not have whole length) is primitive, and every plane
   is written the one way, with no digit for a coefficient 1 or -1. *)

module N = Rhema_number

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

let close a b = Float.abs (a -. b) <= 1e-9 *. Float.max 1. (Float.abs b)

(* ---- Reading the question ------------------------------------------- *)

(* Every match of a regular expression, each as the list of its groups. *)
let matches re groups text =
  let re = Str.regexp re in
  let rec go start found =
    match Str.search_forward re text start with
    | exception Not_found -> List.rev found
    | _ ->
        let row = List.init groups (fun i -> Str.matched_group (i + 1) text) and next = Str.match_end () in
        go next (row :: found)
  in
  go 0 []

let whole = "\\(-?[0-9]+\\)"
let three = whole ^ ", " ^ whole ^ ", " ^ whole
let point_re = "\\\\left(" ^ three ^ "\\\\right)"
let vector_re = "\\\\langle " ^ three ^ " \\\\rangle"

let triple = function
  | [ x; y; z ] -> (int_of_string x, int_of_string y, int_of_string z)
  | _ -> failwith "not three numbers"

(* The points written \left(1, -2, 3\right), in order. The example of how to
   enter a point, (3, -2, 1), has no \left and is not one of them. *)
let points p = List.map triple (matches point_re 3 p)

(* The vectors written \langle 1, -1, -3 \rangle, in order. *)
let vectors p = List.map triple (matches vector_re 3 p)

(* The lines written \mathbf{r} = \left(..\right) + t\langle ..\rangle, in
   order, each as its base point and its direction. *)
let lines p =
  matches ("\\\\mathbf{r} = " ^ point_re ^ " \\+ t" ^ vector_re) 6 p
  |> List.map (function
       | [ x; y; z; a; b; c ] -> (triple [ x; y; z ], triple [ a; b; c ])
       | _ -> failwith "not a line")

(* A left side a x + b y + c z as it should be written: no digit for 1 or
   -1, and the sign of the second and the third term as the operation. *)
let plane_text (a, b, c) =
  let first = match a with 1 -> "" | -1 -> "-" | a -> string_of_int a in
  let next k name = (if k < 0 then " - " else " + ") ^ (if abs k = 1 then "" else string_of_int (abs k)) ^ name in
  first ^ "x" ^ next b "y" ^ next c "z"

(* The planes written -2x + y - 3z = 12, in order, each as its coefficients
   and its right side, which is the letter d in one kind of question. *)
let planes p =
  matches "\\[`\\([^`=]*z\\) = \\(-?[0-9]+\\|d\\)`\\]" 2 p
  |> List.map (function
       | [ left; right ] ->
           if not (Str.string_match (Str.regexp "^\\(-?[0-9]*\\)x \\([+-]\\) \\([0-9]*\\)y \\([+-]\\) \\([0-9]*\\)z$") left 0)
           then failwith ("not the left side of a plane: " ^ left);
           let group i = Str.matched_group i left in
           let size = function "" -> 1 | digits -> int_of_string digits in
           let signed sign digits = if sign = "-" then -size digits else size digits in
           let a = match group 1 with "" -> 1 | "-" -> -1 | digits -> int_of_string digits in
           let normal = (a, signed (group 2) (group 3), signed (group 4) (group 5)) in
           if plane_text normal <> left then failwith ("a plane written in an unusual way: " ^ left);
           (normal, right)
       | _ -> failwith "not a plane")

(* The answer of the one blank. *)
let point_answer (q : Rhema_engine.question) =
  match q.Rhema_engine.answers with
  | [ Rhema_engine.Point [ x; y; z ] ] -> (x, y, z)
  | _ -> failwith ("not one point of space: " ^ q.Rhema_engine.answer_text)

let number_answer (q : Rhema_engine.question) =
  match q.Rhema_engine.answers with
  | [ Rhema_engine.Num n ] -> n
  | _ -> failwith ("not one number: " ^ q.Rhema_engine.answer_text)

(* ---- Exact arithmetic on points and vectors -------------------------- *)

let exact (a, b, c) = (N.of_int a, N.of_int b, N.of_int c)
let plus (a, b, c) (x, y, z) = (N.add a x, N.add b y, N.add c z)
let minus (a, b, c) (x, y, z) = (N.subtract a x, N.subtract b y, N.subtract c z)
let scale k (a, b, c) = (N.multiply k a, N.multiply k b, N.multiply k c)
let dot (a, b, c) (x, y, z) = N.add (N.multiply a x) (N.add (N.multiply b y) (N.multiply c z))

let cross (a, b, c) (x, y, z) =
  ( N.subtract (N.multiply b z) (N.multiply c y),
    N.subtract (N.multiply c x) (N.multiply a z),
    N.subtract (N.multiply a y) (N.multiply b x) )

let null (a, b, c) = N.is_zero a && N.is_zero b && N.is_zero c
let parallel u v = null (cross u v)
let square v = dot v v
let positive n = N.compare n N.zero > 0

(* ---- What the header says of normals and directions ------------------ *)

let no_zero (a, b, c) = a <> 0 && b <> 0 && c <> 0

let primitive (a, b, c) =
  let rec gcd a b = if b = 0 then abs a else gcd b (a mod b) in
  gcd (gcd a b) c = 1

let whole_length (a, b, c) =
  let squared = (a * a) + (b * b) + (c * c) in
  let rec root r = if r * r >= squared then r else root (r + 1) in
  let r = root 0 in
  r * r = squared

(* Some points of the plane n . X = d, away from one another: x and y are
   chosen and z solved for, which the nonzero third coefficient allows. *)
let plane_points (a, b, c) d =
  List.concat_map
    (fun x -> List.map (fun y -> (N.of_int x, N.of_int y, N.make (d - (a * x) - (b * y)) c)) [ -4; 1; 5 ])
    [ -6; 0; 7 ]

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" (kind q) what q.Rhema_engine.answer_text p) in
  let direction v = if not (no_zero v) then wrong "a direction with a zero component" in
  let general_normal n =
    if not (no_zero n) then wrong "a normal with a zero component";
    if not (primitive n) then wrong "a normal that is not primitive"
  in
  let whole_normal n =
    if not (no_zero n) then wrong "a normal with a zero component";
    if not (whole_length n) then wrong "a normal whose length is not whole"
  in
  (* No point of the plane tried is nearer to [from] than [squared] says. *)
  let nearest from n d squared =
    List.iter
      (fun other -> if N.compare (square (minus from other)) squared < 0 then wrong "a point of the plane is nearer")
      (plane_points n d)
  in
  (* Everything the question prints; each kind says what it expects. *)
  match (kind q, points p, vectors p, lines p, planes p) with
  | "plane_constant", [ a ], [ n ], [], [ (coefficients, "d") ] ->
      general_normal n;
      if coefficients <> n then wrong "the equation does not have the normal's components";
      if not (N.equal (dot (exact coefficients) (exact a)) (number_answer q)) then wrong "the point is not on the plane"
  | "point_on_line", [ _ ], [ _ ], [ (base, v) ], [] -> (
      direction v;
      match matches "\\[`t = \\(-?[0-9]+\\)`\\]" 1 p with
      | [ [ t ] ] ->
          let t = N.of_int (int_of_string t) in
          if not (null (minus (minus (point_answer q) (exact base)) (scale t (exact v)))) then
            wrong "not the point at this value of the parameter"
      | _ -> failwith "expected one value of the parameter")
  | "distance", [ a ], [], [], [ (n, d) ] ->
      let d = int_of_string d and answer = number_answer q in
      whole_normal n;
      let a = exact a and normal = exact n in
      (* The foot is a + t n with n . (a + t n) = d. *)
      let t = N.divide (N.subtract (N.of_int d) (dot normal a)) (square normal) in
      let foot = plus a (scale t normal) in
      if not (N.equal (dot normal foot) (N.of_int d)) then failwith "the test's own foot is off the plane";
      if not (positive answer) then wrong "a distance that is not positive";
      if not (N.equal (N.multiply answer answer) (square (minus a foot))) then wrong "not the distance";
      nearest a n d (N.multiply answer answer)
  | "line_meets_plane", [ _ ], [ _ ], [ (base, v) ], [ (n, d) ] ->
      let d = int_of_string d and m = point_answer q in
      direction v;
      general_normal n;
      if N.is_zero (dot (exact v) (exact n)) then wrong "the line is parallel to the plane";
      if not (N.equal (dot (exact n) m) (N.of_int d)) then wrong "the answer is not on the plane";
      if not (parallel (minus m (exact base)) (exact v)) then wrong "the answer is not on the line"
  | "plane_angle", [], [], [], [ (n1, d1); (n2, d2) ] ->
      let answer = number_answer q in
      whole_normal n1;
      whole_normal n2;
      let same_plane =
        parallel (exact n1) (exact n2)
        && (let a1, _, _ = n1 and a2, _, _ = n2 in
            a1 * int_of_string d2 = a2 * int_of_string d1)
      in
      if same_plane then wrong "one plane given twice";
      if not (positive answer && N.compare answer (N.of_int 1) < 0) then wrong "a cosine that is not between 0 and 1";
      let length n = sqrt (N.to_float (square (exact n))) in
      let angle = acos (Float.abs (N.to_float (dot (exact n1) (exact n2))) /. (length n1 *. length n2)) in
      if not (close (cos angle) (N.to_float answer)) then wrong "not the cosine of the angle"
  | "foot", [ a ], [], [], [ (n, d) ] ->
      let d = int_of_string d and f = point_answer q in
      general_normal n;
      let a = exact a and normal = exact n in
      if N.equal (dot normal a) (N.of_int d) then wrong "the point is on the plane";
      if not (N.equal (dot normal f) (N.of_int d)) then wrong "the foot is not on the plane";
      if not (parallel (minus a f) normal) then wrong "the segment to the foot is not along the normal";
      nearest a n d (square (minus a f))
  | "reflection", [ a ], [], [], [ (n, d) ] ->
      let d = int_of_string d and r = point_answer q in
      general_normal n;
      let a = exact a and normal = exact n in
      if null (minus r a) then wrong "the point is its own reflection";
      (* twice the midpoint is the sum, so the sum satisfies n . X = 2 d *)
      if not (N.equal (dot normal (plus a r)) (N.of_int (2 * d))) then wrong "the midpoint is not on the plane";
      if not (parallel (minus r a) normal) then wrong "the segment to the reflection is not along the normal"
  | ( ("plane_constant" | "point_on_line" | "distance" | "line_meets_plane" | "plane_angle" | "foot" | "reflection"),
      _, _, _, _ ) ->
      failwith "the question does not print what its kind should"
  | k, _, _, _, _ -> fail ("unknown kind " ^ k)

let () =
  let base = load_file "lines_planes.rhm" in
  let prices =
    [ ("plane_constant", 1); ("point_on_line", 1); ("distance", 2); ("line_meets_plane", 2); ("plane_angle", 2);
      ("foot", 3); ("reflection", 3) ]
  in
  let seen = Hashtbl.create 8 in
  let one spec cost seed =
    Random.init (seed + (1000 * cost));
    match Rhema_engine.generate spec with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
    | q ->
        let k = kind q in
        Hashtbl.replace seen k ();
        if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
        if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
        (* Every form places its own blank, one. *)
        if List.length q.Rhema_engine.answers <> 1 then
          fail (Printf.sprintf "%s has %d blanks" k (List.length q.Rhema_engine.answers));
        (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) q.Rhema_engine.prompt))
  in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      one spec cost seed
    done
  done;
  (* Two planes that are perpendicular, or parallel, are drawn rarely, about
     one pair in forty each, and the 150 questions above happen to draw
     neither, so they do not show that the grammar turns such pairs away. A
     longer run at price 2 does: it meets each case several times. *)
  let spec = with_initial base "cost" 2 in
  for seed = 150 to 1999 do
    one spec 2 seed
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema lines and planes tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d lines and planes test(s) failed." !failures);
    exit 1
  end
