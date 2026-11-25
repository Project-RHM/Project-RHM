(* Independent checks for integral_coordinates.rhm. Nothing here uses the
   grammar's closed formulas, and nothing here changes coordinates to find
   an answer: every integral is worked out in x, y and z, so that no factor
   r and no sin(phi) can be forgotten or put in twice. Every question is
   matched against the whole sentence of its form; the integrand is read
   back from its LaTeX by a small reader of expressions in x, y and z
   (numbers, powers, square roots, brackets, sums and products written side
   by side), which gives the function that is integrated; the region is read
   from its inequalities. The answer is then found twice:

   - by an iterated integral in Cartesian coordinates. The limits of each
     variable are solved here from the inequalities for the values of the
     variables outside it (square roots, and where a ring or a shell has a
     hole, the two pieces on either side of it); each piece is integrated by
     a 16-point Gauss-Legendre rule, whose nodes are found here by Newton's
     method, after the substitution t = m + h sin(u), which takes away the
     square-root behaviour of the limits at both ends of a piece. A piece
     ends wherever the limits or the integrand have a kink: at the edge of
     the hole, at 0, where sqrt(x^2 + y^2) has its point, and once more a
     sixteenth of the way out from 0, which keeps the piece that touches
     the point small. The box, whose limits are numbers, is integrated by
     the 4-point rule as it is, exact for its monomials;
   - as a second opinion, by a sum over the midpoints of a grid of small
     squares or cubes laid over the region, keeping the midpoints that pass
     a membership test written straight from the inequalities, with the
     integrand built from the numbers read in the sentence and not from the
     reader of expressions. The two must agree to one part in a thousand in
     the plane and four in space (the grid is coarse), and the two readings
     of the integrand must agree at three points.

   The first is compared with the engine's answer to one part in 10^9. Form
   by form:

   - box: the limits 0..A, 0..B, 0..C are read from the three integral signs,
     the outermost belonging to the last differential, dx; the monomial is
     integrated over the box. Promises: some variable is in the integrand,
     and the answer is at most 500.
   - disc, ring: lo <= x^2 + y^2 <= hi with lo = 0 for a disc; x runs over
     [-sqrt(hi), sqrt(hi)], y between the two circles at that x.
   - quarter_product, quarter_coordinate, quarter_square: the same disc cut
     down to x >= 0 and y >= 0. The kind must be the one of the integrand
     (x y; x or y; x^2).
   - paraboloid, cone: the surface z = ... is read as a function; where it is
     above z = 0 is found here by bisection (along the x-axis for the reach
     of the region, then along y for each x), and the height is integrated
     over that region. The grid keeps the midpoints where the height is not
     negative. Promise: no cone of radius 3 is asked (the radius is the
     reach found by bisection).
   - ball, shell, half_ball: lo <= x^2 + y^2 + z^2 <= hi, with z >= 0 for the
     half; x, then y, then z, each between the two spheres.
   - cylinder_distance, cylinder_height, cylinder_both: the disc in x and y,
     and z from 0 to the height read. Promise: z alone is never asked over a
     cylinder of radius 2.

   The mistakes are worked out from what their descriptions say the student
   does. jacobian_forgotten: the student sets up the integral in polar (or
   cylindrical) coordinates with the right limits, the radii being the roots
   of the bounds read (for a solid, the place on each ray where the surface
   meets the plane, by bisection), writes the integrand at
   (r cos(theta), r sin(theta)), and integrates dr d(theta) (dz) with no
   factor r. sine_forgotten: the integrand at the point with spherical
   coordinates rho, phi, theta, times rho^2 and no sin(phi), integrated over
   the box of rho, phi (0 to pi, or to pi/2 for the half ball) and theta.
   Both by the same rule, from the function read.

   An answer with pi must be a `plain` formula written as one fraction times
   pi (or pi alone); it is compared as a number with the integral, is at
   most 300 pi as the grammar promises, and so is worth less than 1000:
   WeBWorK grades to one part in a thousand, which would let a larger answer
   be off by one. The box and the quarter-disc integrals of x y, x and y are
   plain numbers. The sine_forgotten value of a ball or a shell is one
   fraction times pi^2. The working of this file is itself tried first on
   integrals with known values and on expressions that are not written as
   they should be.

   Besides the answers: the mistakes a form declares are listed on each of
   its questions, in the order of their declarations, each with the value
   found here, of the expected type, described in the words of the header's
   list, and more than 1% away from the right answer; the box lists none;
   each kind appears at its price alone and spends its budget; a budget
   outside 1..3 gives no question; the budget the grammar sets itself is the
   middle price; each printed number of each form takes exactly the values
   the grammar offers, none missing and none more; and where a form is kept
   under 300 pi, the questions asked are exactly those of the numbers
   offered whose integral, worked out here, is at most 300 pi (for the box,
   the largest answer asked is the largest at most 500 that the numbers
   offered give). Those ranges, the caps and the descriptions are the only
   things taken from the grammar. The weights are not looked at. *)

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

let pi = Float.pi

(* Two numbers that are the same to a part in 10^9, or to `within`. *)
let close ?(within = 1e-9) a b = Float.abs (a -. b) <= within *. Float.max (Float.abs a) (Float.abs b)

(* ---- Numerical working ---------------------------------------------------- *)

(* The nodes and weights of the Gauss-Legendre rule with n points on
   [-1, 1]: the zeros of the Legendre polynomial P_n, by Newton's method
   from the usual first guess, P_n and P_(n-1) by the three-term
   recurrence. *)
let gauss_legendre n =
  Array.init n (fun i ->
      let x = ref (cos (pi *. (float_of_int i +. 0.75) /. (float_of_int n +. 0.5))) in
      let slope = ref 1.0 in
      for _ = 1 to 50 do
        let before = ref 1.0 and this = ref !x in
        for k = 2 to n do
          let next = ((float_of_int ((2 * k) - 1) *. !x *. !this) -. (float_of_int (k - 1) *. !before)) /. float_of_int k in
          before := !this;
          this := next
        done;
        slope := float_of_int n *. ((!x *. !this) -. !before) /. ((!x *. !x) -. 1.0);
        x := !x -. (!this /. !slope)
      done;
      (!x, 2.0 /. ((1.0 -. (!x *. !x)) *. !slope *. !slope)))

(* The same rule after the substitution t = sin(pi u / 2), which is still a
   rule on [-1, 1]: the nodes move towards the ends and the weights carry
   the cosine. An integrand that behaves like a square root at an end of
   its interval becomes smooth. *)
let softened n =
  Array.map (fun (u, w) -> (sin (pi *. u /. 2.0), w *. pi /. 2.0 *. cos (pi *. u /. 2.0))) (gauss_legendre n)

let fine = softened 16

(* The rule as it is, with 4 points: exact for a polynomial of degree 7, and
   enough for a monomial over a box, whose limits are numbers. *)
let light = gauss_legendre 4

(* The integral of g from a to b. The ends are never evaluated. *)
let integral ?(rule = fine) g a b =
  if not (a < b) then 0.0
  else begin
    let middle = (a +. b) /. 2.0 and half = (b -. a) /. 2.0 in
    let sum = ref 0.0 in
    Array.iter (fun (s, w) -> sum := !sum +. (w *. g (middle +. (half *. s)))) rule;
    !sum *. half
  end

(* The integral of g over several pieces of a line. *)
let over ?rule pieces g = List.fold_left (fun sum (a, b) -> sum +. integral ?rule g a b) 0.0 pieces

(* The place t > 0 where g, positive at 0, comes down to 0: the upper end is
   doubled until g is negative there, then the interval is halved. *)
let crossing g =
  if not (g 0.0 > 0.0) then failwith "nothing to cross: the start is not above 0";
  let high = ref 1.0 in
  while g !high > 0.0 do
    if !high > 1e6 then failwith "no crossing was found";
    high := !high *. 2.0
  done;
  let low = ref 0.0 in
  for _ = 1 to 100 do
    let middle = (!low +. !high) /. 2.0 in
    if g middle > 0.0 then low := middle else high := middle
  done;
  (!low +. !high) /. 2.0

(* A region of the plane or of space: the pieces x runs over, the pieces y
   runs over for an x, the pieces z runs over for an x and a y (none in the
   plane), and, for the second opinion, a test of whether a point is in the
   region and an interval for each coordinate that holds the region. *)
type region = {
  xs : (float * float) list;
  ys : float -> (float * float) list;
  zs : float -> float -> (float * float) list;
  holds : float -> float -> float -> bool;
  frame : (float * float) list;
}

let root v = sqrt (Float.max 0.0 v)

(* The pieces of [-top, top] when nothing is cut out of it: they end at 0,
   where the distance from the origin has its point, and once more close to
   0 on either side, so that the piece that touches the point is a small
   one. *)
let about_zero top =
  let near = top /. 16.0 in
  [ (-.top, -.near); (-.near, 0.0); (0.0, near); (near, top) ]

(* Where lo <= t^2 + s <= hi for the last coordinate t, s being the sum of
   the squares of the others: two pieces, on either side of the hole if
   there is one at this s, and of 0 if not. *)
let cut ~lo ~hi s =
  let top = root (hi -. s) in
  if lo -. s > 0.0 then begin
    let hole = sqrt (lo -. s) in
    [ (-.top, -.hole); (hole, top) ]
  end
  else about_zero top

(* The same for a coordinate that is not the last: some point of the region
   lies over every t up to the outer edge, and the limits of the
   coordinates inside change their form at the edge of the hole. *)
let span ~lo ~hi s =
  let top = root (hi -. s) in
  if lo -. s > 0.0 then begin
    let hole = sqrt (lo -. s) in
    [ (-.top, -.hole); (-.hole, hole); (hole, top) ]
  end
  else about_zero top

(* What is left of some pieces where the coordinate is not negative. *)
let positive pieces = List.filter_map (fun (a, b) -> if b <= 0.0 then None else Some (Float.max a 0.0, b)) pieces

(* lo <= x^2 + y^2 <= hi, the whole of it or what lies in the first quadrant. *)
let between_circles ?(quadrant = false) lo hi =
  let keep = if quadrant then positive else Fun.id in
  let far = sqrt hi in
  { xs = keep (span ~lo ~hi 0.0);
    ys = (fun x -> keep (cut ~lo ~hi (x *. x)));
    zs = (fun _ _ -> []);
    holds =
      (fun x y _ ->
        let s = (x *. x) +. (y *. y) in
        lo <= s && s <= hi && ((not quadrant) || (x >= 0.0 && y >= 0.0)));
    frame = [ (-.far, far); (-.far, far) ] }

(* lo <= x^2 + y^2 + z^2 <= hi, the whole of it or what lies above z = 0. *)
let between_spheres ?(upper = false) lo hi =
  let keep = if upper then positive else Fun.id in
  let far = sqrt hi in
  { xs = span ~lo ~hi 0.0;
    ys = (fun x -> span ~lo ~hi (x *. x));
    zs = (fun x y -> keep (cut ~lo ~hi ((x *. x) +. (y *. y))));
    holds =
      (fun x y z ->
        let s = (x *. x) +. (y *. y) +. (z *. z) in
        lo <= s && s <= hi && ((not upper) || z >= 0.0));
    frame = [ (-.far, far); (-.far, far); (-.far, far) ] }

(* x^2 + y^2 <= hi and 0 <= z <= height. *)
let upright_cylinder hi height =
  let far = sqrt hi in
  { xs = span ~lo:0.0 ~hi 0.0;
    ys = (fun x -> cut ~lo:0.0 ~hi (x *. x));
    zs = (fun _ _ -> [ (0.0, height) ]);
    holds = (fun x y z -> (x *. x) +. (y *. y) <= hi && 0.0 <= z && z <= height);
    frame = [ (-.far, far); (-.far, far); (0.0, height) ] }

(* 0 <= x <= a, 0 <= y <= b, 0 <= z <= c. *)
let cuboid a b c =
  { xs = [ (0.0, a) ];
    ys = (fun _ -> [ (0.0, b) ]);
    zs = (fun _ _ -> [ (0.0, c) ]);
    holds = (fun x y z -> 0.0 <= x && x <= a && 0.0 <= y && y <= b && 0.0 <= z && z <= c);
    frame = [ (0.0, a); (0.0, b); (0.0, c) ] }

(* The part of the plane over which a surface z = height(x, y), highest
   over the origin and falling away from it, is above z = 0: its reach
   along the x-axis, and for each x its reach along y, by bisection. That
   the region reaches no further in another direction is left to the
   second opinion, whose frame is wider. *)
let above_the_plane height =
  if not (height 0.0 0.0 0.0 > 0.0) then failwith "the surface is not above the plane over the origin";
  let reach = crossing (fun t -> height t 0.0 0.0) in
  if not (close reach (crossing (fun t -> height (-.t) 0.0 0.0))) then failwith "the solid is not the same on both sides";
  let far = 1.25 *. reach in
  ( reach,
    { xs = about_zero reach;
      ys = (fun x -> about_zero (crossing (fun t -> height x t 0.0)));
      zs = (fun _ _ -> []);
      holds = (fun x y _ -> height x y 0.0 >= 0.0);
      frame = [ (-.far, far); (-.far, far) ] } )

(* The integral of f over a region of the plane and over a region of space,
   one variable inside another. *)
let double ?rule f region = over ?rule region.xs (fun x -> over ?rule (region.ys x) (fun y -> f x y 0.0))

let triple ?rule f region =
  over ?rule region.xs (fun x -> over ?rule (region.ys x) (fun y -> over ?rule (region.zs x y) (fun z -> f x y z)))

(* The second opinion: the frame is cut into `cells` equal parts each way,
   and f at the midpoint of each small square or cube whose midpoint is in
   the region is added up. *)
let grid ~cells f region =
  let midpoint (a, b) i = a +. ((b -. a) *. (float_of_int i +. 0.5) /. float_of_int cells) in
  let side (a, b) = (b -. a) /. float_of_int cells in
  let sum = ref 0.0 in
  match region.frame with
  | [ fx; fy ] ->
      for i = 0 to cells - 1 do
        let x = midpoint fx i in
        for j = 0 to cells - 1 do
          let y = midpoint fy j in
          if region.holds x y 0.0 then sum := !sum +. f x y 0.0
        done
      done;
      !sum *. side fx *. side fy
  | [ fx; fy; fz ] ->
      for i = 0 to cells - 1 do
        let x = midpoint fx i in
        for j = 0 to cells - 1 do
          let y = midpoint fy j in
          for l = 0 to cells - 1 do
            let z = midpoint fz l in
            if region.holds x y z then sum := !sum +. f x y z
          done
        done
      done;
      !sum *. side fx *. side fy *. side fz
  | _ -> failwith "a frame of two or three intervals was expected"

(* The integral over a region by the rule, with the grid's agreement. The
   grid's integrand is the one built from the numbers of the sentence. *)
let both ?rule ~cells ~within what f plain region =
  let by_rule = match region.frame with [ _; _ ] -> double ?rule f region | _ -> triple ?rule f region in
  let by_grid = grid ~cells plain region in
  if not (close ~within by_rule by_grid) then
    failwith (Printf.sprintf "%s: the rule gives %.12g and the grid %.12g" what by_rule by_grid);
  by_rule

(* What the student who forgets a factor works out. The angle theta is cut
   into quarter turns. *)
let quarter_turn = [ (0.0, pi /. 2.0) ]
let full_turn = List.init 4 (fun n -> (float_of_int n *. pi /. 2.0, float_of_int (n + 1) *. pi /. 2.0))

(* dr d(theta) with no factor r, the radius running from `inner` to what
   `outer` gives for the angle. *)
let polar_without_r f angles inner outer =
  over angles (fun theta ->
      let c = cos theta and s = sin theta in
      integral (fun r -> f (r *. c) (r *. s) 0.0) inner (outer c s))

(* dz dr d(theta) with no factor r. *)
let cylindrical_without_r f radius height =
  over full_turn (fun theta ->
      let c = cos theta and s = sin theta in
      integral (fun r -> integral (fun z -> f (r *. c) (r *. s) z) 0.0 height) 0.0 radius)

(* rho^2 d(rho) d(phi) d(theta) with no sin(phi), phi measured from the
   z-axis down to `lowest`. *)
let spherical_without_sine f inner outer lowest =
  let down = if lowest > pi /. 2.0 then [ (0.0, pi /. 2.0); (pi /. 2.0, lowest) ] else [ (0.0, lowest) ] in
  over full_turn (fun theta ->
      over down (fun phi ->
          integral
            (fun rho ->
              rho *. rho *. f (rho *. sin phi *. cos theta) (rho *. sin phi *. sin theta) (rho *. cos phi))
            inner outer))

(* ---- Reading an expression in x, y and z ------------------------------------ *)

(* A whole number, written the one way it is written. *)
let integer text =
  match int_of_string_opt text with
  | Some n when string_of_int n = text -> n
  | _ -> failwith ("not a whole number: " ^ text)

let rec power v n = if n <= 0 then 1.0 else v *. power v (n - 1)

(* The function an expression stands for, as LaTeX prints it: a sum of
   products joined by " + " and " - "; a product is its factors written
   side by side; a factor is a whole number, a letter x, y or z, a square
   root \sqrt{...} or a sum in brackets, with a whole power ^{n} after it
   or none. *)
let expression text =
  let length = String.length text in
  let position = ref 0 in
  let ahead word =
    let n = String.length word in
    !position + n <= length && String.sub text !position n = word
  in
  let take word =
    ahead word
    && begin
         position := !position + String.length word;
         true
       end
  in
  let need word = if not (take word) then failwith (Printf.sprintf "%S was expected at %d in: %s" word !position text) in
  let digits () =
    let start = !position in
    while !position < length && match text.[!position] with '0' .. '9' -> true | _ -> false do
      incr position
    done;
    String.sub text start (!position - start)
  in
  let rec sum () =
    let rec more left =
      if take " + " then begin
        let right = product () in
        more (fun x y z -> left x y z +. right x y z)
      end
      else if take " - " then begin
        let right = product () in
        more (fun x y z -> left x y z -. right x y z)
      end
      else left
    in
    more (product ())
  and product () =
    let rec more left =
      if !position < length && match text.[!position] with 'x' | 'y' | 'z' | '(' | '\\' | '0' .. '9' -> true | _ -> false
      then begin
        let right = factor () in
        more (fun x y z -> left x y z *. right x y z)
      end
      else left
    in
    more (factor ())
  and factor () =
    let base = atom () in
    if take "^{" then begin
      let n = integer (digits ()) in
      need "}";
      fun x y z -> power (base x y z) n
    end
    else base
  and atom () =
    if take "x" then fun x _ _ -> x
    else if take "y" then fun _ y _ -> y
    else if take "z" then fun _ _ z -> z
    else if take "\\sqrt{" then begin
      let inside = sum () in
      need "}";
      fun x y z -> sqrt (inside x y z)
    end
    else if take "(" then begin
      let inside = sum () in
      need ")";
      inside
    end
    else begin
      match digits () with
      | "" -> failwith (Printf.sprintf "a factor was expected at %d in: %s" !position text)
      | written ->
          let v = float_of_int (integer written) in
          fun _ _ _ -> v
    end
  in
  let f = sum () in
  if !position <> length then failwith (Printf.sprintf "nothing was expected at %d in: %s" !position text);
  f

(* The two readings of an integrand are one function. *)
let same_function f plain =
  List.iter
    (fun (x, y, z) -> if not (close ~within:1e-12 (f x y z) (plain x y z)) then failwith "the two readings of the integrand differ")
    [ (0.3, 0.7, 1.1); (1.3, 0.4, 0.9); (2.1, 1.7, 0.2) ]

(* ---- Reading a question ---------------------------------------------------- *)

let words = Str.quote

(* The groups of a pattern that takes in the whole of a text; a group that
   took no part is empty. *)
let fields count pattern text =
  if Str.string_match (Str.regexp (pattern ^ "$")) text 0 && Str.match_end () = String.length text then
    List.init count (fun n -> try Str.matched_group (n + 1) text with Not_found -> "")
  else failwith ("not written as expected: " ^ text)

let a_number = "\\([0-9]+\\)"
let an_integrand = "\\([^`]*\\)"
let exact = words " Give the exact value, with [`\\pi`] written as pi."

(* The number in front of an integrand: 1 is not written. *)
let coefficient text =
  if text = "" then 1
  else
    match integer text with
    | n when n >= 2 -> n
    | _ -> failwith ("a factor that is not written as one is: " ^ text)

(* k times a power of the distance sqrt(sum): k, and the power 1, 2 or 4.
   The square of the distance is in brackets when a number stands in front
   of it, and only then. *)
let distance_power sum text =
  let rooted = "\\sqrt{" ^ sum ^ "}" and squared = "(" ^ sum ^ ")^{2}" and held = "(" ^ sum ^ ")" in
  match
    fields 2 ("\\([0-9]*\\)\\(" ^ String.concat "\\|" (List.map words [ rooted; squared; held; sum ]) ^ "\\)") text
  with
  | [ front; body ] ->
      let k = coefficient front in
      if body = rooted then (k, 1)
      else if body = squared then (k, 4)
      else if (body = held) = (k > 1) then (k, 2)
      else failwith ("brackets that are not written as they are: " ^ text)
  | _ -> failwith "two fields were expected"

let planar_sum = "x^{2} + y^{2}"
let spatial_sum = "x^{2} + y^{2} + z^{2}"

(* k times the power p of the distance from the origin in space, and from
   the z-axis, as functions. *)
let spatial_distance k p x y z = float_of_int k *. (sqrt ((x *. x) +. (y *. y) +. (z *. z)) ** float_of_int p)
let planar_distance k p x y _ = spatial_distance k p x y 0.0

(* What was generated besides the kinds: each choice the grammar offers. *)
let noted : (string, string list) Hashtbl.t = Hashtbl.create 64

let note topic choice =
  let so_far = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
  if not (List.mem choice so_far) then Hashtbl.replace noted topic (choice :: so_far)

let note_number topic n = note topic (string_of_int n)

(* How fine the grid is, and how far it may be from the rule. *)
let plane_cells = 240
let plane_within = 1e-3
let space_cells = 80
let box_cells = 20
let space_within = 4e-3

(* ---- Price 1 ---------------------------------------------------------------- *)

let box_sentence =
  words "Evaluate [`\\int_{0}^{" ^ a_number ^ words "} \\int_{0}^{" ^ a_number ^ words "} \\int_{0}^{" ^ a_number
  ^ words "} " ^ "\\([^` ]*\\)" ^ words " \\, dz \\, dy \\, dx`]."

(* k x^i y^j z^l, each power 0, 1 or 2: (k, i, j, l). *)
let monomial text =
  let letter name = "\\(" ^ words (name ^ "^{2}") ^ "\\|" ^ name ^ "\\)?" in
  match fields 4 ("\\([0-9]*\\)" ^ letter "x" ^ letter "y" ^ letter "z") text with
  | [ front; x; y; z ] ->
      let exponent written = match String.length written with 0 -> 0 | 1 -> 1 | _ -> 2 in
      (coefficient front, exponent x, exponent y, exponent z)
  | _ -> failwith "four fields were expected"

let largest_box = ref 0.0
let box_cap = 500.0

let examine_box prompt =
  match fields 4 box_sentence prompt with
  | [ first; second; third; integrand ] ->
      (* the outermost integral sign goes with the last differential, dx *)
      let a = integer first and b = integer second and c = integer third in
      let k, i, j, l = monomial integrand in
      if i + j + l = 0 then failwith "the integrand holds no variable";
      let f = expression integrand in
      let plain x y z = float_of_int k *. power x i *. power y j *. power z l in
      same_function f plain;
      let value =
        both ~rule:light ~cells:box_cells ~within:space_within "box" f plain (cuboid (float_of_int a) (float_of_int b) (float_of_int c))
      in
      if value > box_cap +. 1e-6 then failwith "the answer is above 500";
      if value > !largest_box then largest_box := value;
      note_number "box: coefficient" k;
      note "box: powers of x, y and z" (Printf.sprintf "%d, %d, %d" i j l);
      note_number "box: limit of x" a;
      note_number "box: limit of y" b;
      note_number "box: limit of z" c;
      (value, [])
  | _ -> failwith "four fields were expected"

let disc_sentence =
  words "Evaluate the double integral of [`" ^ an_integrand ^ words "`] over the disc [`x^{2} + y^{2} \\le " ^ a_number
  ^ words "`]." ^ exact

(* The integral of an integrand read over lo <= x^2 + y^2 <= hi, and what
   the student finds who leaves out the factor r. *)
let between_circles_worked what integrand plain ?(quadrant = false) lo hi =
  let f = expression integrand in
  same_function f plain;
  if not (0.0 <= lo && lo < hi) then failwith "the circles are not in order";
  let value = both ~cells:plane_cells ~within:plane_within what f plain (between_circles ~quadrant lo hi) in
  let slip = polar_without_r f (if quadrant then quarter_turn else full_turn) (sqrt lo) (fun _ _ -> sqrt hi) in
  (value, [ ("jacobian_forgotten", slip) ])

let examine_disc prompt =
  match fields 2 disc_sentence prompt with
  | [ integrand; bound ] ->
      let k, p = distance_power planar_sum integrand in
      let hi = integer bound in
      note "disc: k, power and radius squared" (Printf.sprintf "%d, %d, %d" k p hi);
      between_circles_worked "disc" integrand (planar_distance k p) 0.0 (float_of_int hi)
  | _ -> failwith "two fields were expected"

(* ---- Price 2 ---------------------------------------------------------------- *)

let ring_sentence =
  words "Evaluate the double integral of [`" ^ an_integrand ^ words "`] over the ring [`" ^ a_number
  ^ words " \\le x^{2} + y^{2} \\le " ^ a_number ^ words "`]." ^ exact

let examine_ring prompt =
  match fields 3 ring_sentence prompt with
  | [ integrand; lower; upper ] ->
      let k, p = distance_power planar_sum integrand in
      let lo = integer lower and hi = integer upper in
      if lo < 1 then failwith "a ring without a hole";
      note "ring: k, power and radii squared" (Printf.sprintf "%d, %d, %d, %d" k p lo hi);
      between_circles_worked "ring" integrand (planar_distance k p) (float_of_int lo) (float_of_int hi)
  | _ -> failwith "three fields were expected"

let quarter_sentence =
  words "Evaluate the double integral of [`" ^ an_integrand ^ words "`] over the quarter of the disc [`x^{2} + y^{2} \\le "
  ^ a_number ^ words "`] that lies in the first quadrant, [`x \\ge 0`], [`y \\ge 0`]." ^ exact

let examine_quarter k prompt =
  match fields 2 quarter_sentence prompt with
  | [ integrand; bound ] -> (
      match fields 2 ("\\([0-9]*\\)\\(xy\\|" ^ words "x^{2}" ^ "\\|x\\|y\\)") integrand with
      | [ front; what ] ->
          let c = float_of_int (coefficient front) and hi = integer bound in
          let of_kind, plain =
            match what with
            | "xy" -> ("quarter_product", fun x y _ -> c *. x *. y)
            | "x" -> ("quarter_coordinate", fun x _ _ -> c *. x)
            | "y" -> ("quarter_coordinate", fun _ y _ -> c *. y)
            | _ -> ("quarter_square", fun x _ _ -> c *. x *. x)
          in
          if k <> of_kind then failwith ("the integrand is that of " ^ of_kind);
          note "quarter: coefficient" (if front = "" then "1" else front);
          note "quarter: integrand and radius squared" (Printf.sprintf "%s, %d" what hi);
          between_circles_worked "quarter" integrand plain ~quadrant:true 0.0 (float_of_int hi)
      | _ -> failwith "two fields were expected")
  | _ -> failwith "two fields were expected"

let solid_sentence =
  words "Find the volume of the solid that lies above the plane [`z = 0`] and below the surface [`z = " ^ an_integrand
  ^ words "`]." ^ exact

(* The surface c(N - x^2 - y^2), without the brackets when c is 1, or
   H - c sqrt(x^2 + y^2): which it is, the two numbers, and its height from
   the numbers. *)
let surface text =
  let attempt count pattern = match fields count pattern text with found -> Some found | exception Failure _ -> None in
  let paraboloid c level =
    let c = float_of_int c and level = float_of_int level in
    fun x y _ -> c *. (level -. (x *. x) -. (y *. y))
  in
  match attempt 2 (a_number ^ "(" ^ a_number ^ words " - x^{2} - y^{2})") with
  | Some [ front; level ] ->
      let c = coefficient front and level = integer level in
      ("paraboloid", c, level, paraboloid c level)
  | _ -> (
      match attempt 1 (a_number ^ words " - x^{2} - y^{2}") with
      | Some [ level ] -> ("paraboloid", 1, integer level, paraboloid 1 (integer level))
      | _ -> (
          match attempt 2 (a_number ^ " - \\([0-9]*\\)" ^ words "\\sqrt{x^{2} + y^{2}}") with
          | Some [ top; front ] ->
              let c = coefficient front and top = integer top in
              ("cone", c, top, fun x y _ -> float_of_int top -. (float_of_int c *. sqrt ((x *. x) +. (y *. y))))
          | _ -> failwith ("not a surface of this grammar: " ^ text)))

let examine_solid k prompt =
  match fields 1 solid_sentence prompt with
  | [ written ] ->
      let of_kind, c, level, plain = surface written in
      if k <> of_kind then failwith ("the surface is that of " ^ of_kind);
      let height = expression written in
      same_function height plain;
      let reach, region = above_the_plane height in
      (* the promise: for a cone of radius 3 the integral without the factor
         r is the same, and none is asked *)
      if k = "cone" && close ~within:1e-6 reach 3.0 then failwith "a cone of radius 3";
      let volume = both ~cells:plane_cells ~within:plane_within k height plain region in
      let slip =
        polar_without_r height full_turn 0.0 (fun c s -> crossing (fun r -> height (r *. c) (r *. s) 0.0))
      in
      note (k ^ ": factor and level") (Printf.sprintf "%d, %d" c level);
      (volume, [ ("jacobian_forgotten", slip) ])
  | _ -> failwith "one field was expected"

(* ---- Price 3 ---------------------------------------------------------------- *)

let ball_sentence =
  words "Evaluate the triple integral of [`" ^ an_integrand ^ words "`] over the ball [`x^{2} + y^{2} + z^{2} \\le "
  ^ a_number ^ words "`]." ^ exact

let shell_sentence =
  words "Evaluate the triple integral of [`" ^ an_integrand ^ words "`] over the region [`" ^ a_number
  ^ words " \\le x^{2} + y^{2} + z^{2} \\le " ^ a_number ^ words "`] between two spheres." ^ exact

(* The integral of an integrand read over lo <= x^2 + y^2 + z^2 <= hi, the
   whole of it or its upper half, and what the student finds who leaves out
   sin(phi). *)
let between_spheres_worked what integrand plain ?(upper = false) lo hi =
  let f = expression integrand in
  same_function f plain;
  if not (0.0 <= lo && lo < hi) then failwith "the spheres are not in order";
  let value = both ~cells:space_cells ~within:space_within what f plain (between_spheres ~upper lo hi) in
  let slip = spherical_without_sine f (sqrt lo) (sqrt hi) (if upper then pi /. 2.0 else pi) in
  (value, [ ("sine_forgotten", slip) ])

let examine_ball prompt =
  match fields 2 ball_sentence prompt with
  | [ integrand; bound ] ->
      let k, p = distance_power spatial_sum integrand in
      let hi = integer bound in
      note "ball: k, power and radius squared" (Printf.sprintf "%d, %d, %d" k p hi);
      between_spheres_worked "ball" integrand (spatial_distance k p) 0.0 (float_of_int hi)
  | _ -> failwith "two fields were expected"

let examine_shell prompt =
  match fields 3 shell_sentence prompt with
  | [ integrand; lower; upper ] ->
      let k, p = distance_power spatial_sum integrand in
      let lo = integer lower and hi = integer upper in
      if lo < 1 then failwith "a shell without a hole";
      note "shell: k, power and radii squared" (Printf.sprintf "%d, %d, %d, %d" k p lo hi);
      between_spheres_worked "shell" integrand (spatial_distance k p) (float_of_int lo) (float_of_int hi)
  | _ -> failwith "three fields were expected"

let half_ball_sentence =
  words "Evaluate the triple integral of [`" ^ an_integrand
  ^ words "`] over the half of the ball [`x^{2} + y^{2} + z^{2} \\le " ^ a_number
  ^ words "`] that lies above the plane [`z = 0`]." ^ exact

let examine_half_ball prompt =
  match fields 2 half_ball_sentence prompt with
  | [ integrand; bound ] -> (
      match fields 1 "\\([0-9]*\\)z" integrand with
      | [ front ] ->
          let k = coefficient front and hi = integer bound in
          note "half_ball: coefficient and radius squared" (Printf.sprintf "%d, %d" k hi);
          between_spheres_worked "half_ball" integrand (fun _ _ z -> float_of_int k *. z) ~upper:true 0.0 (float_of_int hi)
      | _ -> failwith "one field was expected")
  | _ -> failwith "two fields were expected"

let cylinder_sentence =
  words "Evaluate the triple integral of [`" ^ an_integrand ^ words "`] over the cylinder [`x^{2} + y^{2} \\le " ^ a_number
  ^ words "`], [`0 \\le z \\le " ^ a_number ^ words "`]." ^ exact

(* What is integrated over a cylinder, by the name of its kind. *)
let cylinder_function k what x y z =
  float_of_int k
  *.
  match what with
  | "cylinder_distance" -> (x *. x) +. (y *. y)
  | "cylinder_height" -> z
  | _ -> z *. ((x *. x) +. (y *. y))

let examine_cylinder kind_name prompt =
  match fields 3 cylinder_sentence prompt with
  | [ integrand; bound; top ] -> (
      let both_written = "z(" ^ planar_sum ^ ")" and held = "(" ^ planar_sum ^ ")" in
      match
        fields 2
          ("\\([0-9]*\\)\\(" ^ String.concat "\\|" (List.map words [ both_written; held; planar_sum ]) ^ "\\|z\\)")
          integrand
      with
      | [ front; body ] ->
          let k = coefficient front and hi = integer bound and h = integer top in
          let of_kind =
            if body = both_written then "cylinder_both"
            else if body = "z" then "cylinder_height"
            else if (body = held) = (k > 1) then "cylinder_distance"
            else failwith ("brackets that are not written as they are: " ^ integrand)
          in
          if kind_name <> of_kind then failwith ("the integrand is that of " ^ of_kind);
          (* the promise: the integral of z over a cylinder of radius 2 is
             the same without the factor r, and is not asked *)
          if of_kind = "cylinder_height" && hi = 4 then failwith "z over a cylinder of radius 2";
          if h < 1 then failwith "a cylinder of no height";
          let f = expression integrand and plain = cylinder_function k of_kind in
          same_function f plain;
          let value =
            both ~cells:space_cells ~within:space_within of_kind f plain (upright_cylinder (float_of_int hi) (float_of_int h))
          in
          let slip = cylindrical_without_r f (sqrt (float_of_int hi)) (float_of_int h) in
          note "cylinder: coefficient, kind, radius squared and height" (Printf.sprintf "%d, %s, %d, %d" k of_kind hi h);
          (value, [ ("jacobian_forgotten", slip) ])
      | _ -> failwith "two fields were expected")
  | _ -> failwith "three fields were expected"

(* The right answer of a question and the answer of each mistake its form
   declares, found again from the prompt. A question that comes up again is
   not worked out again. *)
let worked : (string, (float * (string * float) list, string) result) Hashtbl.t = Hashtbl.create 4096

let expected k prompt =
  let key = k ^ "|" ^ prompt in
  match Hashtbl.find_opt worked key with
  | Some found -> found
  | None ->
      let found =
        match
          match k with
          | "box" -> examine_box prompt
          | "disc" -> examine_disc prompt
          | "ring" -> examine_ring prompt
          | "quarter_product" | "quarter_coordinate" | "quarter_square" -> examine_quarter k prompt
          | "paraboloid" | "cone" -> examine_solid k prompt
          | "ball" -> examine_ball prompt
          | "shell" -> examine_shell prompt
          | "half_ball" -> examine_half_ball prompt
          | "cylinder_distance" | "cylinder_height" | "cylinder_both" -> examine_cylinder k prompt
          | _ -> failwith ("unknown kind " ^ k)
        with
        | answer -> Ok answer
        | exception Failure m -> Error m
      in
      Hashtbl.replace worked key found;
      found

(* ---- The engine's answer ------------------------------------------------------ *)

module F = Rhema_formula

(* An answer is a plain number, one fraction times pi, or one fraction times
   pi^2. *)
type shape = Plain_number | Pi_multiple | Pi_squared_multiple

let shape_name = function
  | Plain_number -> "a plain number"
  | Pi_multiple -> "a plain multiple of pi"
  | Pi_squared_multiple -> "a plain multiple of pi^2"

(* A multiple of pi is written as one positive fraction in front of pi, as
   3/5*pi, or as pi alone; and of pi^2 likewise. *)
let in_front c =
  if Rhema_number.compare c Rhema_number.zero > 0 && not (Rhema_number.equal c (Rhema_number.of_int 1)) then
    Rhema_number.to_float c
  else failwith "a multiple that is not written as one fraction in front"

(* The shape of a value, the number in front of its pi, and what it is
   worth. *)
let reading value =
  let formula f =
    let shape, front =
      match f with
      | F.Pi -> (Pi_multiple, 1.0)
      | F.Multiply (F.Constant c, F.Pi) -> (Pi_multiple, in_front c)
      | F.Power (F.Pi, 2) -> (Pi_squared_multiple, 1.0)
      | F.Multiply (F.Constant c, F.Power (F.Pi, 2)) -> (Pi_squared_multiple, in_front c)
      | _ -> failwith "a formula that is not one fraction times pi or pi^2"
    in
    let worth = if shape = Pi_multiple then front *. pi else front *. pi *. pi in
    if not (close ~within:1e-12 (F.evaluate_with (fun _ -> None) f) worth) then
      failwith "the formula does not come to the multiple read from it";
    (shape, front, worth)
  in
  match value with
  | Rhema_engine.Plain (Rhema_engine.Formula f) -> formula f
  | Rhema_engine.Plain (Rhema_engine.Num n) -> (Plain_number, 0.0, Rhema_number.to_float n)
  | other -> failwith ("an answer of an unexpected type: " ^ Rhema_engine.describe_value other)

(* ---- The working of this file, tried on examples --------------------------- *)

let trials () =
  let expect name condition = if not condition then fail ("trial: " ^ name) in
  let refused work = match work () with _ -> false | exception Failure _ -> true in
  (* the rule *)
  expect "the weights of the rule add up to 2" (close ~within:1e-13 (Array.fold_left (fun sum (_, w) -> sum +. w) 0.0 fine) 2.0);
  expect "the integral of x^2 from 0 to 3" (close ~within:1e-12 (integral (fun x -> x *. x) 0.0 3.0) 9.0);
  expect "the same by the light rule" (close ~within:1e-12 (integral ~rule:light (fun x -> x *. x) 0.0 3.0) 9.0);
  expect "the integral of 1 / x from 1 to e" (close ~within:1e-12 (integral (fun x -> 1.0 /. x) 1.0 (exp 1.0)) 1.0);
  expect "half the unit disc, a square root at both ends"
    (close ~within:1e-12 (integral (fun x -> sqrt (1.0 -. (x *. x))) (-1.0) 1.0) (pi /. 2.0));
  expect "an empty interval" (integral (fun x -> x) 2.0 2.0 = 0.0);
  expect "x^2 - 2 comes down to 0 at the root of 2" (close ~within:1e-14 (crossing (fun t -> 2.0 -. (t *. t))) (sqrt 2.0));
  expect "nothing to cross is refused" (refused (fun () -> crossing (fun t -> -1.0 -. t)));
  (* regions whose sizes are known *)
  let one _ _ _ = 1.0 in
  let size region = match region.frame with [ _; _ ] -> double one region | _ -> triple one region in
  expect "the area of a disc" (close ~within:1e-12 (size (between_circles 0.0 4.0)) (4.0 *. pi));
  expect "the area of a ring" (close ~within:1e-12 (size (between_circles 1.0 9.0)) (8.0 *. pi));
  expect "the area of a quarter disc" (close ~within:1e-12 (size (between_circles ~quadrant:true 0.0 4.0)) pi);
  expect "the volume of a ball" (close ~within:1e-12 (size (between_spheres 0.0 9.0)) (36.0 *. pi));
  expect "the volume of a shell" (close ~within:1e-12 (size (between_spheres 1.0 4.0)) (28.0 *. pi /. 3.0));
  expect "the volume of half a ball" (close ~within:1e-12 (size (between_spheres ~upper:true 0.0 1.0)) (2.0 *. pi /. 3.0));
  expect "the volume of a cylinder" (close ~within:1e-12 (size (upright_cylinder 4.0 3.0)) (12.0 *. pi));
  expect "the volume of a box" (close ~within:1e-12 (triple ~rule:light one (cuboid 1.0 2.0 3.0)) 6.0);
  (* a pyramid of height 1 on the square |x| + |y| <= 1 has volume 2/3: the
     point at the origin and the corners are where the pieces end *)
  let pyramid = { (between_circles 0.0 1.0) with ys = (fun x -> [ (Float.abs x -. 1.0, 0.0); (0.0, 1.0 -. Float.abs x) ]) } in
  expect "a pyramid" (close ~within:1e-12 (double (fun x y _ -> 1.0 -. Float.abs x -. Float.abs y) pyramid) (2.0 /. 3.0));
  (* the mean distance from the centre of the unit disc is 2/3, and the
     mean distance from the centre of the unit ball is 3/4 *)
  let distance = spatial_distance 1 1 in
  expect "the distance over a disc" (close (double distance (between_circles 0.0 1.0)) (2.0 *. pi /. 3.0));
  expect "the distance over a ball" (close (triple distance (between_spheres 0.0 1.0)) pi);
  (* a hemisphere of radius 2 as a solid under a surface *)
  let reach, dome = above_the_plane (fun x y _ -> sqrt (Float.max 0.0 (4.0 -. (x *. x) -. (y *. y))) -. 1e-300) in
  expect "the reach of a dome" (close reach 2.0);
  expect "the volume of a dome"
    (close (double (fun x y _ -> sqrt (Float.max 0.0 (4.0 -. (x *. x) -. (y *. y)))) dome) (16.0 *. pi /. 3.0));
  expect "a surface below the plane is refused" (refused (fun () -> above_the_plane (fun _ _ _ -> -1.0)));
  (* the grid *)
  expect "the grid on a disc" (close ~within:plane_within (grid ~cells:plane_cells one (between_circles 0.0 4.0)) (4.0 *. pi));
  expect "the grid on a shell"
    (close ~within:space_within (grid ~cells:space_cells one (between_spheres 1.0 4.0)) (28.0 *. pi /. 3.0));
  expect "the grid tells half a region from the whole"
    (refused (fun () -> both ~cells:plane_cells ~within:plane_within "half" one one { (between_circles 0.0 4.0) with xs = [ (0.0, 2.0) ] }));
  (* forgetting a factor: the area of a disc of radius 3 becomes 2 pi times 3,
     the volume of a cylinder 2 pi times radius times height, and the volume
     of the unit ball 2 pi times pi times 1/3 *)
  expect "a disc without r" (close (polar_without_r one full_turn 0.0 (fun _ _ -> 3.0)) (6.0 *. pi));
  expect "a quarter ring without r" (close (polar_without_r one quarter_turn 1.0 (fun _ _ -> 3.0)) pi);
  expect "a cylinder without r" (close (cylindrical_without_r one 3.0 5.0) (30.0 *. pi));
  expect "a ball without the sine" (close (spherical_without_sine one 0.0 1.0 pi) (2.0 *. pi *. pi /. 3.0));
  expect "half a shell without the sine" (close (spherical_without_sine one 1.0 2.0 (pi /. 2.0)) (7.0 *. pi *. pi /. 3.0));
  (* expressions *)
  let value text = (expression text) 2.0 3.0 5.0 in
  expect "a monomial is read" (value "5x^{2}yz^{2}" = 1500.0);
  expect "a sum is read" (value "16 - x^{2} - y^{2}" = 3.0);
  expect "brackets are read" (value "2(x^{2} + y^{2} + z^{2})^{2}" = 2888.0);
  expect "a root is read" (close ~within:1e-14 (value "12 - 3\\sqrt{x^{2} + y^{2}}") (12.0 -. (3.0 *. sqrt 13.0)));
  expect "a product with brackets is read" (value "4z(x^{2} + y^{2})" = 260.0);
  List.iter
    (fun text -> expect ("this expression should be refused: " ^ text) (refused (fun () -> expression text)))
    [ ""; "x +y"; "x + "; "(x"; "x^{2"; "x^2"; "\\sqrt{x"; "\\frac{1}{2}"; "x - - y"; "-x"; "02x"; "x)"; "w" ];
  (* the writing of an integrand *)
  expect "a monomial's numbers" (monomial "5x^{2}yz^{2}" = (5, 2, 1, 2) && monomial "y" = (1, 0, 1, 0) && monomial "6z^{2}" = (6, 0, 0, 2));
  List.iter
    (fun text -> expect ("this monomial should be refused: " ^ text) (refused (fun () -> monomial text)))
    [ "1x"; "0x"; "yx"; "x^{3}"; "x^{1}"; "2 x"; "xx"; "05x" ];
  expect "the powers of a distance"
    (distance_power planar_sum "\\sqrt{x^{2} + y^{2}}" = (1, 1)
    && distance_power planar_sum "x^{2} + y^{2}" = (1, 2)
    && distance_power planar_sum "3(x^{2} + y^{2})" = (3, 2)
    && distance_power planar_sum "(x^{2} + y^{2})^{2}" = (1, 4)
    && distance_power spatial_sum "5\\sqrt{x^{2} + y^{2} + z^{2}}" = (5, 1)
    && distance_power spatial_sum "2(x^{2} + y^{2} + z^{2})^{2}" = (2, 4));
  List.iter
    (fun text -> expect ("this distance should be refused: " ^ text) (refused (fun () -> distance_power planar_sum text)))
    [ "(x^{2} + y^{2})"; "3x^{2} + y^{2}"; "1\\sqrt{x^{2} + y^{2}}"; "x^{2} + y^{2} + z^{2}"; "(x^{2} + y^{2})^{3}"; "" ];
  (match surface "3(16 - x^{2} - y^{2})" with
   | "paraboloid", 3, 16, f -> expect "a paraboloid's height" (f 1.0 2.0 0.0 = 33.0)
   | _ -> expect "a paraboloid is read" false);
  (match surface "8 - 2\\sqrt{x^{2} + y^{2}}" with
   | "cone", 2, 8, f -> expect "a cone's height" (f 3.0 4.0 0.0 = -2.0)
   | _ -> expect "a cone is read" false);
  List.iter
    (fun text -> expect ("this surface should be refused: " ^ text) (refused (fun () -> surface text)))
    [ "1(4 - x^{2} - y^{2})"; "(4 - x^{2} - y^{2})"; "4 - 1\\sqrt{x^{2} + y^{2}}"; "4 + x^{2} + y^{2}"; "2(4 - x^{2} - y^{2}" ];
  (* one fraction times pi or pi^2 *)
  let fraction n d = F.Constant (Rhema_number.make n d) in
  let plain f = Rhema_engine.Plain (Rhema_engine.Formula f) in
  expect "3/5 pi is read"
    (match reading (plain (F.Multiply (fraction 3 5, F.Pi))) with Pi_multiple, front, _ -> close front 0.6 | _ -> false);
  expect "pi is read" (match reading (plain F.Pi) with Pi_multiple, 1.0, _ -> true | _ -> false);
  expect "7/2 pi^2 is read"
    (match reading (plain (F.Multiply (fraction 7 2, F.Power (F.Pi, 2)))) with
     | Pi_squared_multiple, front, worth -> close front 3.5 && close worth (3.5 *. pi *. pi)
     | _ -> false);
  expect "a plain number is read"
    (match reading (Rhema_engine.Plain (Rhema_engine.Num (Rhema_number.make 320 27))) with
     | Plain_number, _, worth -> close worth (320.0 /. 27.0)
     | _ -> false);
  expect "3 pi / 5 is refused"
    (refused (fun () -> reading (plain (F.Divide (F.Multiply (fraction 3 1, F.Pi), fraction 5 1)))));
  expect "1 pi is refused" (refused (fun () -> reading (plain (F.Multiply (fraction 1 1, F.Pi)))));
  expect "pi^3 is refused" (refused (fun () -> reading (plain (F.Power (F.Pi, 3)))));
  expect "a fraction as a formula is refused" (refused (fun () -> reading (plain (fraction 3 5))));
  expect "a number that is not plain is refused" (refused (fun () -> reading (Rhema_engine.Num (Rhema_number.of_int 3))))

(* ---- The questions ----------------------------------------------------------- *)

let questions_at_each_budget = 8000

(* What each mistake's description says, word for word. *)
let said =
  [ ("jacobian_forgotten", "leaves out the factor r of the area element r dr d(theta)");
    ("sine_forgotten", "leaves out the sin(phi) of the volume element rho^2 sin(phi) d(rho) d(phi) d(theta)") ]

(* The kinds, their prices, their mistakes in order with the shape of the
   mistaken value, and the shape of their answers. *)
let kinds =
  let jacobian shape = [ ("jacobian_forgotten", shape) ] in
  [ ("box", 1, [], Plain_number); ("disc", 1, jacobian Pi_multiple, Pi_multiple);
    ("ring", 2, jacobian Pi_multiple, Pi_multiple); ("quarter_product", 2, jacobian Plain_number, Plain_number);
    ("quarter_coordinate", 2, jacobian Plain_number, Plain_number);
    ("quarter_square", 2, jacobian Pi_multiple, Pi_multiple); ("paraboloid", 2, jacobian Pi_multiple, Pi_multiple);
    ("cone", 2, jacobian Pi_multiple, Pi_multiple); ("ball", 3, [ ("sine_forgotten", Pi_squared_multiple) ], Pi_multiple);
    ("shell", 3, [ ("sine_forgotten", Pi_squared_multiple) ], Pi_multiple);
    ("half_ball", 3, [ ("sine_forgotten", Pi_multiple) ], Pi_multiple);
    ("cylinder_distance", 3, jacobian Pi_multiple, Pi_multiple); ("cylinder_height", 3, jacobian Pi_multiple, Pi_multiple);
    ("cylinder_both", 3, jacobian Pi_multiple, Pi_multiple) ]

(* An answer with pi is at most this many pi. *)
let pi_cap = 300.0

(* Two values that WeBWorK, which compares to one part in a thousand, could
   take for one another: they are within 1% of each other. *)
let confusable wrong right = Float.abs (wrong -. right) <= 0.01 *. Float.abs right

let examine k p (q : Rhema_engine.question) =
  let _, _, declared, shape = List.find (fun (name, _, _, _) -> name = k) kinds in
  match q.Rhema_engine.answers with
  | [] | _ :: _ :: _ -> fail (Printf.sprintf "%s: one answer was expected for %S" k p)
  | [ answer ] -> (
      match reading answer with
      | exception Failure m -> fail (Printf.sprintf "%s: %s, for %S" k m p)
      | answer_shape, front, got -> (
          if answer_shape <> shape then fail (Printf.sprintf "%s: the answer is not %s, for %S" k (shape_name shape) p);
          if answer_shape <> Plain_number && front > pi_cap then
            fail (Printf.sprintf "%s: the answer %.12g is more than 300 pi, for %S" k got p);
          if answer_shape <> Plain_number && got >= 1000.0 then
            fail (Printf.sprintf "%s: the answer %.12g is worth 1000 or more, for %S" k got p);
          match expected k p with
          | Error m -> fail (Printf.sprintf "%s: %s, for %S" k m p)
          | Ok (want, slips) ->
              if not (close got want) then fail (Printf.sprintf "%s: answer %.12g, worked out %.12g, for %S" k got want p);
              if List.map fst slips <> List.map fst declared then
                fail (Printf.sprintf "%s: the mistakes worked out are not those declared" k);
              List.iter
                (fun (name, slip) ->
                  if confusable slip want then
                    fail (Printf.sprintf "%s: %s gives %.12g, within 1%% of the answer %.12g, for %S" k name slip want p))
                slips;
              let made = q.Rhema_engine.mistakes in
              let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) made in
              if names <> List.map fst declared then
                fail
                  (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k (String.concat ", " names)
                     (String.concat ", " (List.map fst declared))
                     p);
              List.iter
                (fun (m : Rhema_engine.mistaken) ->
                  (match List.assoc_opt m.mistake said with
                   | Some words ->
                       if m.description <> words then
                         fail (Printf.sprintf "%s is described as %S, not %S" m.mistake m.description words)
                   | None -> fail ("a mistake the header does not name: " ^ m.mistake));
                  match m.mistaken_answers with
                  | Some [ value ] -> (
                      match reading value with
                      | exception Failure message -> fail (Printf.sprintf "%s: %s: %s, for %S" k m.mistake message p)
                      | given_shape, _, given -> (
                          (match List.assoc_opt m.mistake declared with
                           | Some expected_shape when given_shape <> expected_shape ->
                               fail (Printf.sprintf "%s: %s is not %s, for %S" k m.mistake (shape_name expected_shape) p)
                           | _ -> ());
                          if confusable given got then
                            fail
                              (Printf.sprintf "%s: %s gives %.12g, within 1%% of the answer %.12g, for %S" k m.mistake given
                                 got p);
                          match List.assoc_opt m.mistake slips with
                          | Some slip when not (close slip given) ->
                              fail (Printf.sprintf "%s: %s gives %.12g, worked out %.12g, for %S" k m.mistake given slip p)
                          | _ -> ()))
                  | _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                made))

let () =
  trials ();
  let base = load_file "integral_coordinates.rhm" in
  let seen = Hashtbl.create 16 and generated = Hashtbl.create 4 in
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
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          match List.find_opt (fun (name, _, _, _) -> name = k) kinds with
          | None -> fail ("a kind the header does not list: " ^ k)
          | Some (_, price, _, _) -> if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost) else examine k p q)
    done
  done;
  for cost = 1 to 3 do
    let count = Option.value ~default:0 (Hashtbl.find_opt generated cost) in
    if count < questions_at_each_budget / 2 then fail (Printf.sprintf "only %d questions at cost %d" count cost)
  done;
  List.iter (fun (k, _, _, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) kinds;
  (* Every choice the grammar offers is taken at least once, and no other.
     A choice comes with the number its answer has in front of pi, worked
     out here if the choice never came up: the grammar turns away those
     above 300, and those alone. *)
  let range first last = List.init (last - first + 1) (fun n -> first + n) in
  let free choices = List.map (fun choice -> (choice, lazy 0.0)) choices in
  let numbers first last = free (List.map string_of_int (range first last)) in
  let product us vs = List.concat_map (fun u -> List.map (fun v -> (u, v)) vs) us in
  let distances = product (range 1 5) [ 1; 2; 4 ] in
  let over_pi value = lazy (Lazy.force value /. pi) in
  let rings name make pairs =
    List.concat_map
      (fun (k, p) ->
        List.map
          (fun (lo, hi) ->
            ( (if lo = 0 then Printf.sprintf "%d, %d, %d" k p hi else Printf.sprintf "%d, %d, %d, %d" k p lo hi),
              over_pi
                (lazy
                  (let region = make (float_of_int lo) (float_of_int hi) in
                   match region.frame with
                   | [ _; _ ] -> double (planar_distance k p) region
                   | _ -> triple (spatial_distance k p) region)) ))
          pairs)
      distances
    |> fun offered -> (name, offered)
  in
  let squares pairs = List.map (fun (a, b) -> (a * a, b * b)) pairs in
  let choices =
    [ ("box: coefficient", numbers 1 6);
      (* every monomial but the one without a variable *)
      ( "box: powers of x, y and z",
        free
          (List.filter_map
             (fun ((i, j), l) -> if i + j + l > 0 then Some (Printf.sprintf "%d, %d, %d" i j l) else None)
             (product (product (range 0 2) (range 0 2)) (range 0 2))) );
      ("box: limit of x", numbers 1 3); ("box: limit of y", numbers 1 3); ("box: limit of z", numbers 1 3);
      rings "disc: k, power and radius squared" (fun lo hi -> between_circles lo hi) (squares [ (0, 1); (0, 2); (0, 3) ]);
      rings "ring: k, power and radii squared"
        (fun lo hi -> between_circles lo hi)
        (squares [ (1, 2); (1, 3); (1, 4); (2, 3); (2, 4); (3, 4) ]);
      ("quarter: coefficient", numbers 1 6);
      ( "quarter: integrand and radius squared",
        free (List.map (fun (what, a) -> Printf.sprintf "%s, %d" what (a * a)) (product [ "xy"; "x"; "y"; "x^{2}" ] (range 1 4))) );
      ( "paraboloid: factor and level",
        List.map
          (fun (c, a) ->
            ( Printf.sprintf "%d, %d" c (a * a),
              over_pi
                (lazy
                  (let height x y _ = float_of_int c *. (float_of_int (a * a) -. (x *. x) -. (y *. y)) in
                   double height (snd (above_the_plane height)))) ))
          (product (range 1 3) (range 1 4)) );
      ("cone: factor and level", free (List.map (fun (c, a) -> Printf.sprintf "%d, %d" c (c * a)) (product (range 1 3) [ 1; 2; 4 ])));
      rings "ball: k, power and radius squared" (fun lo hi -> between_spheres lo hi) (squares [ (0, 1); (0, 2); (0, 3) ]);
      rings "shell: k, power and radii squared" (fun lo hi -> between_spheres lo hi) (squares [ (1, 2); (1, 3); (2, 3) ]);
      ( "half_ball: coefficient and radius squared",
        List.map
          (fun (k, a) ->
            ( Printf.sprintf "%d, %d" k (a * a),
              over_pi
                (lazy (triple (fun _ _ z -> float_of_int k *. z) (between_spheres ~upper:true 0.0 (float_of_int (a * a))))) ))
          (product (range 1 6) (range 1 4)) );
      ( "cylinder: coefficient, kind, radius squared and height",
        List.filter_map
          (fun ((k, what), (a, h)) ->
            (* z over a cylinder of radius 2 is not offered *)
            if what = "cylinder_height" && a = 2 then None
            else
              Some
                ( Printf.sprintf "%d, %s, %d, %d" k what (a * a) h,
                  over_pi
                    (lazy (triple (cylinder_function k what) (upright_cylinder (float_of_int (a * a)) (float_of_int h)))) ))
          (product
             (product (range 1 4) [ "cylinder_distance"; "cylinder_height"; "cylinder_both" ])
             (product (range 1 3) (range 1 4))) ) ]
  in
  List.iter
    (fun (topic, offered) ->
      let met = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
      List.iter
        (fun (choice, front) ->
          if (not (List.mem choice met)) && Lazy.force front <= pi_cap +. 1e-6 then
            fail (Printf.sprintf "never generated: %s %s" topic choice))
        offered;
      List.iter
        (fun choice -> if not (List.mem_assoc choice offered) then fail (Printf.sprintf "not offered: %s %s" topic choice))
        met)
    choices;
  Hashtbl.iter (fun topic _ -> if not (List.mem_assoc topic choices) then fail ("nothing is said of: " ^ topic)) noted;
  (* The largest box answer that came up is the largest, at most 500, that
     the numbers offered give. *)
  let largest_offered =
    List.fold_left
      (fun best (((k, i), (j, l)), ((a, b), c)) ->
        let value =
          triple ~rule:light
            (fun x y z -> float_of_int k *. power x i *. power y j *. power z l)
            (cuboid (float_of_int a) (float_of_int b) (float_of_int c))
        in
        if i + j + l > 0 && value <= box_cap +. 1e-6 && value > best then value else best)
      0.0
      (product
         (product (product (range 1 6) (range 0 2)) (product (range 0 2) (range 0 2)))
         (product (product (range 1 3) (range 1 3)) (range 1 3)))
  in
  if not (close !largest_box largest_offered) then
    fail (Printf.sprintf "the largest box answer is %.12g, not %.12g" !largest_box largest_offered);
  (* The grammar as it is written sets itself the budget 2 and gives a
     question of that price. *)
  for seed = 0 to 19 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q -> (
        match List.find_opt (fun (name, _, _, _) -> name = kind q) kinds with
        | Some (_, 2, _, _) when Rhema_engine.consumption q.Rhema_engine.tree "cost" = 2 -> ()
        | _ -> fail (Printf.sprintf "the grammar's own budget gave %s, not a question of price 2" (kind q)))
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
  if !failures = 0 then print_endline "Rhema integral_coordinates tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d integral_coordinates test(s) failed." !failures);
    exit 1
  end
