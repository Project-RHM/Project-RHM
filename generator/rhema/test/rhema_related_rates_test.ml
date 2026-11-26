(* Independent checks for related_rates.rhm. Nothing here uses the grammar's
   differentiated formulas. Every question is matched against the whole
   sentence of its form, each number in the sentence is read from a group,
   and the answer is found again from what was read by acting the story out:
   the quantity asked about is written as a function of time from the
   geometry alone, and its rate at the moment of the question is taken by
   differencing, in floating point: symmetric difference quotients at four
   steps, each half the one before, carried through three rounds of
   Richardson's extrapolation; the last two rounds must agree, so a function
   with a corner is turned away. Form by form:

   - circle_area, square_area, cube_volume, sphere_volume, sphere_surface:
     the radius or the side at time t is the printed one plus the printed
     rate times t; the area or the volume of the figure of that size (pi r^2,
     s^2, s^3, 4 pi r^3 / 3, 4 pi r^2) is differenced. The mistake
     chain_rule_forgotten differences the same quantity with respect to the
     radius or the side alone: it is the rate when the size grows by one
     centimetre a second.
   - square_root_estimate, cube_root_estimate: the slope of the root at the
     printed point is taken by differencing the root itself, the tangent line
     is the root of the point plus that slope times the step, and it is read
     at the printed number. The promises: the point is a square (a cube), so
     its root is whole; the number is not, and is not the point; the estimate
     is not a whole number; it lies above the true root, as a tangent to a
     curve that bends down must, by less than a tenth of the root. The
     mistake derivative_factor_lost takes 1 / sqrt(x), or x^(-2/3), for the
     slope; that this is twice, or three times, the slope found by
     differencing is checked.
   - ladder: the top of a ladder of the printed length whose foot is x from
     the wall is sqrt(L^2 - x^2) up, by Pythagoras; the foot at time t is the
     printed distance plus the printed speed times t, and the height is
     differenced; the answer is how fast the height falls, a positive speed.
     The promises: the ladder is at most 20 metres long, the foot is nearer
     the wall than the ladder is long, and the height of the top is a whole
     number of metres. The mistake sides_swapped exchanges the two sides of
     the triangle, which is the same ladder standing the other way: its foot
     where the top was high and its top where the foot was far, acted out in
     the same way.
   - balloon: the volume of the balloon at time t is that of a sphere of the
     printed radius plus the printed rate (with its pi) times t; the radius
     at time t is the one whose sphere has that volume, found by halving an
     interval, and it is differenced.
   - apart: the first cyclist at time t is at the printed distance plus the
     printed speed times t east of the crossing, the second likewise north of
     it; the distance between the two points is differenced. The promise:
     the two distances are sides of a right triangle with whole sides.
   - cone: at height y above its point the tank is a disc of radius R y / H,
     by similar triangles; the water up to a depth has the volume of those
     discs, integrated numerically (a four-point Gauss-Legendre rule); the
     volume at time t is that of the printed depth plus the printed rate
     times t, the depth at time t is the one with that volume, found by
     halving an interval, and it is differenced. The promise: the water is
     not as deep as the tank is high. The mistake full_radius_used fills a
     cylinder instead: every disc has the radius of the top.
   - shadow_length, shadow_tip: the walker at time t is a starting distance
     plus the printed speed times t from the lamp post, the heights turned
     from decimetres into kilometres; the ray from the lamp past the walker's
     head comes down where similar triangles put it, which is the tip of the
     shadow, and the shadow is as long as from the walker to the tip. Both
     are differenced, from two different starting distances, which must give
     the same rates. The mistake tip_for_length gives the other of the two.

   An answer with pi must be a `plain` formula written as one fraction times
   pi (the areas and volumes, at most 300 pi) or one fraction over pi (the
   cone), worth less than 1000; the areas and volumes without pi are whole
   numbers, the estimates are fractions, the other answers are numbers. Every
   answer is a positive number. Every number printed with a unit is at least
   2, so that no unit is in the plural after a 1.

   Besides the answers: the mistakes a form declares are listed on each of
   its questions, in the order of their declarations, each with the value
   found here, described in the words of the header's list, and far enough
   from the right answer for WeBWorK's grading (one part in a thousand) not
   to take it for right: more than 1% away, or, where the right answer is a
   whole number, which the engine has graded more tightly, a different number
   more than 0.2% away below 1000; a form without mistakes lists none. Each
   kind appears at its price alone and spends its budget; a budget outside
   1..3 gives no question; the budget the grammar sets itself is the middle
   price; and the numbers each form is asked with are exactly those the
   grammar offers, none missing and none more: the sizes and rates of the
   areas and volumes are those of the ranges whose rate, worked out here, is
   at most 300 (times pi where there is one); the estimates are those of the
   ranges whose root is not whole and whose mistake, worked out here, is more
   than 1% away; the depths of the cone are those below its height, and the
   rate at which it is filled is drawn apart from the depth: below it, equal
   to it and above it. The ranges, the cap and the descriptions are the only
   things taken from the grammar. The weights are not looked at.

   The working of this file is itself tried first: the differencing and the
   halving on functions with known answers, the areas and volumes of the
   round figures against a polygon of many sides, discs and thin bands, and
   each story against a textbook exercise whose answer is known. *)

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

(* Two numbers that agree to one part in a thousand million. *)
let near ?(within = 1e-9) a b = Float.abs (a -. b) <= within *. Float.abs b

(* The whole number whose given power is n, if there is one. *)
let whole_root power n =
  let rec raised r k = if k = 0 then 1 else r * raised r (k - 1) in
  let rec up r = if raised r power >= n then r else up (r + 1) in
  let r = up 0 in
  if n >= 0 && raised r power = n then Some r else None

(* ---- Numerical working ---------------------------------------------------- *)

(* The integral of g from a to b by the four-point Gauss-Legendre rule on
   `panels` equal pieces. *)
let integral ?(panels = 2) g a b =
  let nodes = [ (-0.8611363115940526, 0.3478548451374538); (-0.3399810435848563, 0.6521451548625461);
                (0.3399810435848563, 0.6521451548625461); (0.8611363115940526, 0.3478548451374538) ] in
  let width = (b -. a) /. float_of_int panels in
  let sum = ref 0.0 in
  for i = 0 to panels - 1 do
    let middle = a +. (width *. (float_of_int i +. 0.5)) in
    List.iter (fun (t, w) -> sum := !sum +. (w *. g (middle +. (width *. t /. 2.0)))) nodes
  done;
  !sum *. width /. 2.0

(* The rate of change of f at 0: symmetric difference quotients at the step
   and at its half, quarter and eighth, and three rounds of Richardson's
   extrapolation, each of which removes the leading term of the error. The
   last two rounds must agree. *)
let rate ~step f =
  let quotient h = (f h -. f (-.h)) /. (2.0 *. h) in
  let better factor coarse fine = ((factor *. fine) -. coarse) /. (factor -. 1.0) in
  let q0 = quotient step and q1 = quotient (step /. 2.0) and q2 = quotient (step /. 4.0) and q3 = quotient (step /. 8.0) in
  let r0 = better 4.0 q0 q1 and r1 = better 4.0 q1 q2 and r2 = better 4.0 q2 q3 in
  let s0 = better 16.0 r0 r1 and s1 = better 16.0 r1 r2 in
  let best = better 64.0 s0 s1 in
  if not (Float.abs (best -. s1) <= 1e-9 *. Float.max 1e-3 (Float.abs best)) then
    failwith (Printf.sprintf "the difference quotients do not settle: %.15g, then %.15g" s1 best);
  best

(* Where the increasing g takes the value `target` between low and high, by
   halving the interval until it cannot be halved. *)
let inverse g target low high =
  if not (g low <= target && target <= g high) then failwith "the value is not taken in the interval";
  let a = ref low and b = ref high and halving = ref true in
  while !halving do
    let m = (!a +. !b) /. 2.0 in
    if m <= !a || m >= !b then halving := false else if g m <= target then a := m else b := m
  done;
  !a

(* ---- The geometry ----------------------------------------------------------- *)

let disc r = pi *. r *. r
let ball r = 4.0 *. pi *. r *. r *. r /. 3.0
let sphere r = 4.0 *. pi *. r *. r

(* The volume of what fills a vessel up to a depth, when its cross-section
   at height y is a disc of radius `radius_at y`: the discs, added up. *)
let filled radius_at depth = integral (fun y -> disc (radius_at y)) 0.0 depth

(* ---- The stories, acted out -------------------------------------------------- *)

(* How fast a quantity grows that depends on a size, when the size is `size`
   and grows at `speed`. *)
let growth quantity ~size ~speed = rate ~step:(0.01 *. size /. speed) (fun t -> quantity (size +. (speed *. t)))

(* The slope of a root at a point. *)
let slope_of root point = rate ~step:(point /. 50.0) (fun h -> root (point +. h))

(* The tangent line to a root at a point, read at a number. *)
let tangent_estimate root ~point ~number = root point +. (slope_of root point *. (number -. point))

(* How fast the top of a ladder comes down when its foot is `foot` from the
   wall and is pulled away at `pull`: the height of the top is the third
   side of the right triangle. *)
let ladder_speed ~length ~foot ~pull =
  let height x = sqrt ((length *. length) -. (x *. x)) in
  -.rate ~step:(0.02 /. pull) (fun t -> height (foot +. (pull *. t)))

(* How fast the radius of a balloon grows when its radius is `radius` and
   `inflow` of volume goes in per unit of time. *)
let balloon_growth ~inflow ~radius =
  let start = ball radius in
  rate ~step:(0.02 *. start /. inflow) (fun t -> inverse ball (start +. (inflow *. t)) 0.0 (2.0 *. radius))

(* How fast the distance grows between a point `east` of a crossing going
   east and a point `north` of it going north. *)
let parting_speed ~east ~north ~east_speed ~north_speed =
  let distance t =
    let x = east +. (east_speed *. t) and y = north +. (north_speed *. t) in
    sqrt ((x *. x) +. (y *. y))
  in
  rate ~step:(0.02 *. Float.min east north /. Float.max east_speed north_speed) distance

(* How fast the water rises in a vessel when it is `depth` deep and `inflow`
   of volume goes in per unit of time. *)
let rising_speed radius_at ~inflow ~depth =
  let start = filled radius_at depth in
  rate ~step:(0.02 *. start /. inflow) (fun t -> inverse (filled radius_at) (start +. (inflow *. t)) 0.0 (2.0 *. depth))

(* A cone with its point down: the radius of the water's surface is to its
   depth as the radius of the top is to the height. *)
let cone ~top ~height y = top *. y /. height

(* A cylinder of the radius of the top. *)
let cylinder ~top _ = top

(* Where the tip of the shadow is when the walker is `position` from the
   post: the ray from the lamp past the walker's head has come down by
   lamp - walker over that distance, and has the whole height of the lamp to
   come down. *)
let tip_of_shadow ~lamp ~walker position = position *. lamp /. (lamp -. walker)

(* How fast the shadow lengthens, and how fast its tip moves, for a walker
   who starts `start` from the post. *)
let shadow_speeds ~lamp ~walker ~speed ~start =
  let place t = start +. (speed *. t) in
  let step = 0.01 *. start /. speed in
  ( rate ~step (fun t -> tip_of_shadow ~lamp ~walker (place t) -. place t),
    rate ~step (fun t -> tip_of_shadow ~lamp ~walker (place t)) )

(* ---- Reading a question ---------------------------------------------------- *)

(* A whole number, written the one way it is written. *)
let integer text =
  match int_of_string_opt text with
  | Some n when string_of_int n = text -> n
  | _ -> failwith ("not a whole number: " ^ text)

let words = Str.quote

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* The numbers of a sentence, each of which stands before a unit in the
   plural: none is 1. *)
let quantities count pattern prompt =
  let numbers = List.map integer (fields count pattern prompt) in
  if List.exists (fun n -> n < 2) numbers then failwith "a quantity below 2 before a unit in the plural";
  numbers

let a_number = "\\([0-9]+\\)"
let exact = words " Give the exact value, with [`\\pi`] written as pi."

(* What was generated besides the kinds: each choice the grammar offers. *)
let noted : (string, string list) Hashtbl.t = Hashtbl.create 64

let note topic choice =
  let so_far = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
  if not (List.mem choice so_far) then Hashtbl.replace noted topic (choice :: so_far)

let note_number topic n = note topic (string_of_int n)

(* What a question's answer is found to be: a number, so many times pi, or
   so much over pi. *)
type found = Number of float | Pi_times of float | Over_pi of float

let show = function
  | Number v -> Printf.sprintf "%.12g" v
  | Pi_times v -> Printf.sprintf "%.12g pi" v
  | Over_pi v -> Printf.sprintf "%.12g / pi" v

let worth = function Number v -> v | Pi_times v -> v *. pi | Over_pi v -> v /. pi

let same a b =
  match (a, b) with
  | Number u, Number v | Pi_times u, Pi_times v | Over_pi u, Over_pi v -> near u v
  | _ -> false

(* Whether WeBWorK, which grades to one part in a thousand, tells a mistaken
   answer from the right one: it is more than 1% away. A right answer that
   is a whole number is graded more tightly by the engine (no other whole
   number passes), so there a different number is enough, more than 0.2%
   away below 1000. *)
let told_apart ~whole right slip =
  let r = worth right and s = worth slip in
  if whole then s <> r && (Float.abs r >= 1000.0 || Float.abs (s -. r) > 0.002 *. Float.abs r)
  else Float.abs (s -. r) > 0.01 *. Float.abs r

(* ---- Price 1 ---------------------------------------------------------------- *)

(* The figures: the kind, the figure, the part that grows, the unit of the
   rate, what is asked about, its size as a function of the part, and whether
   it has a pi. *)
let figures =
  [ ("circle_area", ("circle", "radius", "square", "area", disc, true));
    ("square_area", ("square", "side", "square", "area", (fun s -> s *. s), false));
    ("cube_volume", ("cube", "side", "cubic", "volume", (fun s -> s *. s *. s), false));
    ("sphere_volume", ("sphere", "radius", "cubic", "volume", ball, true));
    ("sphere_surface", ("sphere", "radius", "square", "surface area", sphere, true)) ]

let growth_sentence (figure, part, unit, asked, _, round) =
  words ("The " ^ part ^ " of a " ^ figure ^ " grows at [`")
  ^ a_number
  ^ words ("`] centimetres per second. How fast, in " ^ unit ^ " centimetres per second, is its " ^ asked ^ " growing when the " ^ part ^ " is [`")
  ^ a_number ^ words "`] centimetres?"
  ^ if round then exact else ""

(* The rate of a figure's quantity and what the mistake makes of it, with
   the pi taken out where there is one. *)
let growth_values (_, _, _, _, quantity, round) ~size ~speed =
  let found v = if round then Pi_times (v /. pi) else Number v in
  let right = growth quantity ~size ~speed in
  (* with respect to the size alone: the size grows by one a second *)
  let slip = growth quantity ~size ~speed:1.0 in
  (found right, found slip)

let examine_growth k prompt =
  let figure = List.assoc k figures in
  match quantities 2 (growth_sentence figure) prompt with
  | [ speed; size ] ->
      note (k ^ ": size and its rate") (Printf.sprintf "%d, %d" size speed);
      let right, slip = growth_values figure ~size:(float_of_int size) ~speed:(float_of_int speed) in
      (right, [ ("chain_rule_forgotten", slip) ])
  | _ -> failwith "two fields were expected"

(* The roots: the kind, how the root is written up to what is under it, the
   root, its power, and the slope of a student who loses the factor. *)
let roots =
  [ ("square_root_estimate", ("\\sqrt{", sqrt, 2, fun x -> x ** -0.5));
    ("cube_root_estimate", ("\\sqrt[3]{", Float.cbrt, 3, fun x -> x ** (-2.0 /. 3.0))) ]

(* The estimate of the root of a number by the tangent at a point, what the
   mistake makes of it, and the true root. *)
let estimate_values (_, root, power, bare_slope) ~point ~number =
  let a = float_of_int point and b = float_of_int number in
  let right = tangent_estimate root ~point:a ~number:b in
  (* the factor lost is 1/2 for a square root and 1/3 for a cube root *)
  if not (near (float_of_int power *. slope_of root a) (bare_slope a)) then
    failwith "the slope without its factor is not what it should be";
  let slip = root a +. (bare_slope a *. (b -. a)) in
  (right, slip, root b)

(* Whether an estimate is one to ask for: the root is not known beforehand,
   and the mistake can be told from the estimate. *)
let estimate_offered ((_, _, power, _) as the_root) ~point ~number =
  let right, slip, _ = estimate_values the_root ~point ~number in
  whole_root power number = None && told_apart ~whole:false (Number right) (Number slip)

let examine_estimate k prompt =
  let ((written, _, power, _) as the_root) = List.assoc k roots in
  let sentence =
    words ("Use the tangent line to [`y = " ^ written ^ "x}`] at [`x = ")
    ^ a_number
    ^ words ("`] to estimate [`" ^ written)
    ^ a_number
    ^ words "}`]. Give the estimate as a fraction."
  in
  match List.map integer (fields 2 sentence prompt) with
  | [ point; number ] ->
      if whole_root power point = None then failwith "the root of the point of the tangent is not whole";
      if number = point then failwith "the number is the point of the tangent";
      if whole_root power number <> None then failwith "the root to estimate is a whole number";
      let right, slip, true_root = estimate_values the_root ~point ~number in
      if not (right > true_root *. (1.0 +. 1e-7)) then failwith "the estimate is not above the root";
      if not (right < true_root *. 1.1) then failwith "the estimate is not close to the root";
      note (k ^ ": point and number") (Printf.sprintf "%d, %d" point number);
      (Number right, [ ("derivative_factor_lost", Number slip) ])
  | _ -> failwith "two fields were expected"

(* ---- Price 2 ---------------------------------------------------------------- *)

let ladder_sentence =
  words "A ladder [`" ^ a_number ^ words "`] metres long leans against a wall. Its foot is pulled away from the wall at [`"
  ^ a_number
  ^ words "`] metres per second. How fast, in metres per second, is the top of the ladder sliding down the wall when the foot is [`"
  ^ a_number ^ words "`] metres from the wall?"

let examine_ladder prompt =
  match quantities 3 ladder_sentence prompt with
  | [ length; pull; foot ] -> (
      if length > 20 then failwith "the ladder is more than 20 metres long";
      if foot >= length then failwith "the foot is further from the wall than the ladder is long";
      match whole_root 2 ((length * length) - (foot * foot)) with
      | None -> failwith "the top of the ladder is not a whole number of metres up"
      | Some top ->
          note "ladder: length, distance and speed" (Printf.sprintf "%d, %d, %d" length foot pull);
          let down foot = ladder_speed ~length:(float_of_int length) ~foot:(float_of_int foot) ~pull:(float_of_int pull) in
          (* the two sides exchanged: the same ladder, standing the other way *)
          (Number (down foot), [ ("sides_swapped", Number (down top)) ]))
  | _ -> failwith "three fields were expected"

let balloon_sentence =
  words "Air is pumped into a spherical balloon at [`" ^ a_number
  ^ words "\\pi`] cubic centimetres per second. How fast, in centimetres per second, is its radius growing when the radius is [`"
  ^ a_number ^ words "`] centimetres?"

let examine_balloon prompt =
  match quantities 2 balloon_sentence prompt with
  | [ inflow; radius ] ->
      note "balloon: rate and radius" (Printf.sprintf "%d, %d" inflow radius);
      (Number (balloon_growth ~inflow:(float_of_int inflow *. pi) ~radius:(float_of_int radius)), [])
  | _ -> failwith "two fields were expected"

let apart_sentence =
  words "A cyclist is [`" ^ a_number ^ words "`] kilometres east of a crossing and rides east at [`" ^ a_number
  ^ words "`] kilometres per hour. A second cyclist is [`" ^ a_number
  ^ words "`] kilometres north of the crossing and rides north at [`" ^ a_number
  ^ words "`] kilometres per hour. How fast, in kilometres per hour, is the distance between them growing?"

let examine_apart prompt =
  match quantities 4 apart_sentence prompt with
  | [ east; east_speed; north; north_speed ] ->
      if whole_root 2 ((east * east) + (north * north)) = None then
        failwith "the cyclists are not a whole number of kilometres apart";
      note "apart: east and north" (Printf.sprintf "%d, %d" east north);
      note_number "apart: speed east" east_speed;
      note_number "apart: speed north" north_speed;
      ( Number
          (parting_speed ~east:(float_of_int east) ~north:(float_of_int north) ~east_speed:(float_of_int east_speed)
             ~north_speed:(float_of_int north_speed)),
        [] )
  | _ -> failwith "four fields were expected"

(* ---- Price 3 ---------------------------------------------------------------- *)

let cone_sentence =
  words "A tank has the shape of a cone with its point down. It is [`" ^ a_number
  ^ words "`] metres high, and its radius at the top is [`" ^ a_number ^ words "`] metres. Water is poured in at [`"
  ^ a_number ^ words "`] cubic metres per minute. How fast, in metres per minute, is the water rising when it is [`"
  ^ a_number ^ words "`] metres deep?" ^ exact

let examine_cone prompt =
  match quantities 4 cone_sentence prompt with
  | [ height; top; inflow; depth ] ->
      if depth >= height then failwith "the water is as deep as the tank is high";
      note "cone: height, radius and depth" (Printf.sprintf "%d, %d, %d" height top depth);
      note_number "cone: rate" inflow;
      (* the rate and the depth are drawn apart from one another *)
      note "cone: rate against depth" (if inflow < depth then "below" else if inflow = depth then "equal" else "above");
      let rising vessel = rising_speed vessel ~inflow:(float_of_int inflow) ~depth:(float_of_int depth) in
      let top = float_of_int top and height = float_of_int height in
      (Over_pi (rising (cone ~top ~height) *. pi), [ ("full_radius_used", Over_pi (rising (cylinder ~top) *. pi)) ])
  | _ -> failwith "four fields were expected"

let shadow_sentence asked =
  words "A lamp hangs [`" ^ a_number ^ words "`] decimetres above the ground. A walker [`" ^ a_number
  ^ words "`] decimetres tall walks away from the lamp post at [`" ^ a_number
  ^ words ("`] kilometres per hour. How fast, in kilometres per hour, is " ^ asked)

let examine_shadow k prompt =
  let asked =
    if k = "shadow_length" then "the shadow of the walker lengthening?" else "the tip of the walker's shadow moving along the ground?"
  in
  match quantities 3 (shadow_sentence asked) prompt with
  | [ lamp; walker; speed ] ->
      if walker >= lamp then failwith "the walker is as tall as the lamp is high";
      note_number (k ^ ": lamp") lamp;
      note_number (k ^ ": walker") walker;
      note_number (k ^ ": speed") speed;
      (* decimetres into kilometres *)
      let kilometres n = float_of_int n /. 10000.0 in
      let from start = shadow_speeds ~lamp:(kilometres lamp) ~walker:(kilometres walker) ~speed:(float_of_int speed) ~start in
      let lengthening, tip = from 0.004 in
      let lengthening_later, tip_later = from 0.05 in
      if not (near lengthening lengthening_later && near tip tip_later) then
        failwith "the rates depend on where the walker is, which the question does not say";
      if k = "shadow_length" then (Number lengthening, [ ("tip_for_length", Number tip) ])
      else (Number tip, [ ("tip_for_length", Number lengthening) ])
  | _ -> failwith "three fields were expected"

(* The right answer of a question and the answer of each mistake its form
   declares, found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let prompt = q.Rhema_engine.prompt in
  match kind q with
  | ("circle_area" | "square_area" | "cube_volume" | "sphere_volume" | "sphere_surface") as k -> examine_growth k prompt
  | ("square_root_estimate" | "cube_root_estimate") as k -> examine_estimate k prompt
  | "ladder" -> examine_ladder prompt
  | "balloon" -> examine_balloon prompt
  | "apart" -> examine_apart prompt
  | "cone" -> examine_cone prompt
  | ("shadow_length" | "shadow_tip") as k -> examine_shadow k prompt
  | k -> failwith ("unknown kind " ^ k)

(* ---- The engine's answer ------------------------------------------------------ *)

module F = Rhema_formula

(* How an answer is written: a whole number, a fraction that is not one, one
   fraction times pi, or one fraction over pi. *)
type written = Whole_number | Broken_number | Times_pi | Divided_by_pi

(* What a value is and how it is written. A multiple of pi is one positive
   fraction in front of pi, as 3/5*pi; a fraction over pi is one positive
   fraction over pi, as 3/5/pi. *)
let reading value =
  let positive c = Rhema_number.compare c Rhema_number.zero > 0 in
  let agreeing f v = if near (F.evaluate_with (fun _ -> None) f) v then () else failwith "the formula does not come to what is read from it" in
  match value with
  | Rhema_engine.Plain (Rhema_engine.Num n) ->
      (Number (Rhema_number.to_float n), if Rhema_number.is_integer n then Whole_number else Broken_number)
  | Rhema_engine.Plain (Rhema_engine.Formula (F.Multiply (F.Constant c, F.Pi) as f))
    when positive c && not (Rhema_number.equal c (Rhema_number.of_int 1)) ->
      let c = Rhema_number.to_float c in
      agreeing f (c *. pi);
      (Pi_times c, Times_pi)
  | Rhema_engine.Plain (Rhema_engine.Formula (F.Divide (F.Constant c, F.Pi) as f)) when positive c ->
      let c = Rhema_number.to_float c in
      agreeing f (c /. pi);
      (Over_pi c, Divided_by_pi)
  | other -> failwith ("an answer of an unexpected type: " ^ Rhema_engine.describe_value other)

(* ---- The working of this file, tried on examples --------------------------- *)

let trials () =
  let expect name condition = if not condition then fail ("trial: " ^ name) in
  let refused work = match work () with _ -> false | exception Failure _ -> true in
  List.iter
    (fun text -> expect ("this number should be refused: " ^ text) (refused (fun () -> integer text)))
    [ "01"; ""; "+3"; "3 "; "3.0"; "x" ];
  expect "a number is read" (integer "36" = 36);
  expect "whole roots"
    (whole_root 2 36 = Some 6 && whole_root 2 35 = None && whole_root 3 125 = Some 5 && whole_root 3 124 = None
    && whole_root 2 1 = Some 1 && whole_root 2 2 = None);
  (* the differencing *)
  expect "the rate of t^3 at 2" (near (rate ~step:0.01 (fun t -> (2.0 +. t) ** 3.0)) 12.0);
  expect "the rate of the square root at 4" (near (rate ~step:0.05 (fun t -> sqrt (4.0 +. t))) 0.25);
  expect "the rate of exp at 0" (near (rate ~step:0.02 exp) 1.0);
  expect "the rate of sin at 1" (near (rate ~step:0.02 (fun t -> sin (1.0 +. t))) (cos 1.0));
  expect "a corner is refused" (refused (fun () -> rate ~step:0.01 (fun t -> Float.abs (t -. 0.003))));
  (* the halving *)
  expect "the cube root of 27" (near (inverse (fun x -> x *. x *. x) 27.0 0.0 10.0) 3.0);
  expect "a value outside the interval is refused" (refused (fun () -> inverse (fun x -> x *. x) 200.0 0.0 10.0));
  expect "the integral of x^6 from 0 to 2" (near (integral (fun x -> x ** 6.0) 0.0 2.0) (128.0 /. 7.0));
  (* the round figures: a circle against a polygon of many sides, a ball
     against its discs, a sphere against thin bands between parallels *)
  let sides = 200000 in
  let corner i = let angle = 2.0 *. pi *. float_of_int i /. float_of_int sides in (3.0 *. cos angle, 3.0 *. sin angle) in
  let polygon = ref 0.0 in
  for i = 0 to sides - 1 do
    let x0, y0 = corner i and x1, y1 = corner (i + 1) in
    polygon := !polygon +. (((x0 *. y1) -. (x1 *. y0)) /. 2.0)
  done;
  expect "the area of a circle" (near ~within:1e-8 !polygon (disc 3.0));
  expect "the volume of a ball"
    (near (integral (fun y -> disc (sqrt (Float.max 0.0 (9.0 -. (y *. y))))) (-3.0) 3.0) (ball 3.0));
  let bands = ref 0.0 in
  for i = 0 to (sides / 2) - 1 do
    let x0, y0 = corner i and x1, y1 = corner (i + 1) in
    (* the band a chord sweeps out about the x-axis: a frustum's side *)
    bands := !bands +. (pi *. (y0 +. y1) *. sqrt (((x1 -. x0) ** 2.0) +. ((y1 -. y0) ** 2.0)))
  done;
  expect "the surface of a sphere" (near ~within:1e-8 !bands (sphere 3.0));
  (* a cone holds a third of the cylinder around it *)
  expect "a cone and its cylinder"
    (near (3.0 *. filled (cone ~top:2.0 ~height:5.0) 5.0) (filled (cylinder ~top:2.0) 5.0)
    && near (filled (cylinder ~top:2.0) 5.0) (20.0 *. pi));
  (* textbook exercises with known answers *)
  expect "a circle of radius 3 whose radius grows at 5" (near (growth disc ~size:3.0 ~speed:5.0) (30.0 *. pi));
  expect "a ball of radius 25 that takes in 100 a second" (near (balloon_growth ~inflow:100.0 ~radius:25.0) (1.0 /. (25.0 *. pi)));
  expect "a ladder of 10 whose foot is 6 away and goes at 1" (near (ladder_speed ~length:10.0 ~foot:6.0 ~pull:1.0) 0.75);
  expect "two cars, 0.3 and 0.4 from a crossing, at 50 and 60, coming in"
    (near (parting_speed ~east:0.3 ~north:0.4 ~east_speed:(-50.0) ~north_speed:(-60.0)) (-78.0));
  expect "a cone of radius 2 and height 4, filled at 2, when 3 deep"
    (near (rising_speed (cone ~top:2.0 ~height:4.0) ~inflow:2.0 ~depth:3.0) (8.0 /. (9.0 *. pi)));
  (let lengthening, tip = shadow_speeds ~lamp:15.0 ~walker:6.0 ~speed:5.0 ~start:40.0 in
   expect "a lamp at 15, a walker of 6 going at 5" (near lengthening (10.0 /. 3.0) && near tip (25.0 /. 3.0)));
  expect "the square root of 4.05 by the tangent at 4" (near (tangent_estimate sqrt ~point:4.0 ~number:4.05) 2.0125);
  expect "the cube root of 1001 by the tangent at 1000"
    (near (tangent_estimate Float.cbrt ~point:1000.0 ~number:1001.0) (10.0 +. (1.0 /. 300.0)));
  (* what WeBWorK tells apart *)
  expect "1% away is not enough" (not (told_apart ~whole:false (Number 100.0) (Number 101.0)));
  expect "more than 1% away is" (told_apart ~whole:false (Over_pi 100.0) (Over_pi 101.1));
  expect "a whole answer and another number" (told_apart ~whole:true (Number 100.0) (Number 100.5));
  expect "a whole answer and a number too near" (not (told_apart ~whole:true (Number 100.0) (Number 100.1)));
  expect "a whole answer and itself" (not (told_apart ~whole:true (Number 2000.0) (Number 2000.0)));
  (* answers as they are written *)
  let fraction n d = F.Constant (Rhema_number.make n d) in
  let formula f = Rhema_engine.Plain (Rhema_engine.Formula f) in
  expect "3/5 pi is read" (reading (formula (F.Multiply (fraction 3 5, F.Pi))) = (Pi_times 0.6, Times_pi));
  expect "3/4 over pi is read" (reading (formula (F.Divide (fraction 3 4, F.Pi))) = (Over_pi 0.75, Divided_by_pi));
  expect "numbers are read"
    (reading (Rhema_engine.Plain (Rhema_engine.Num (Rhema_number.make 6 2))) = (Number 3.0, Whole_number)
    && reading (Rhema_engine.Plain (Rhema_engine.Num (Rhema_number.make 7 2))) = (Number 3.5, Broken_number));
  List.iter
    (fun (name, value) -> expect (name ^ " is refused") (refused (fun () -> reading value)))
    [ ("3 pi / 5", formula (F.Divide (F.Multiply (fraction 3 1, F.Pi), fraction 5 1))); ("1 pi", formula (F.Multiply (fraction 1 1, F.Pi)));
      ("-2 pi", formula (F.Multiply (fraction (-2) 1, F.Pi))); ("pi over 3", formula (F.Divide (F.Pi, fraction 3 1)));
      ("a number that is not plain", Rhema_engine.Num (Rhema_number.of_int 3));
      ("a formula that is not plain", Rhema_engine.Formula (F.Multiply (fraction 3 1, F.Pi))) ]

(* ---- The questions ----------------------------------------------------------- *)

let questions_at_each_budget = 6000
let seed_offset = 0

(* What each mistake's description says, word for word. *)
let said =
  [ ("chain_rule_forgotten", "differentiates with respect to the radius or the side and does not multiply by its rate of change");
    ("derivative_factor_lost", "loses the 1/2 in the derivative of a square root, or the 1/3 in that of a cube root");
    ( "sides_swapped",
      "exchanges the two sides of the right triangle: the height over the distance from the wall where the distance over the height belongs" );
    ("full_radius_used", "treats the water in the cone as a cylinder of the cone's full radius");
    ("tip_for_length", "gives the speed of the tip of the shadow for the rate at which the shadow lengthens, or the other way round") ]

(* The kinds, their prices, their mistakes in order, and the type of their
   answers: a whole number, a fraction that is not one, either, a multiple of
   pi, or a fraction over pi. *)
type shape = Whole | Fraction | Any_number | Pi_multiple | Fraction_over_pi

let kinds =
  [ ("circle_area", 1, [ "chain_rule_forgotten" ], Pi_multiple); ("square_area", 1, [ "chain_rule_forgotten" ], Whole);
    ("cube_volume", 1, [ "chain_rule_forgotten" ], Whole); ("sphere_volume", 1, [ "chain_rule_forgotten" ], Pi_multiple);
    ("sphere_surface", 1, [ "chain_rule_forgotten" ], Pi_multiple);
    ("square_root_estimate", 1, [ "derivative_factor_lost" ], Fraction);
    ("cube_root_estimate", 1, [ "derivative_factor_lost" ], Fraction); ("ladder", 2, [ "sides_swapped" ], Any_number);
    ("balloon", 2, [], Any_number); ("apart", 2, [], Any_number); ("cone", 3, [ "full_radius_used" ], Fraction_over_pi);
    ("shadow_length", 3, [ "tip_for_length" ], Any_number); ("shadow_tip", 3, [ "tip_for_length" ], Any_number) ]

let of_shape shape written =
  match (shape, written) with
  | Whole, Whole_number | Fraction, Broken_number | Any_number, (Whole_number | Broken_number) | Pi_multiple, Times_pi
  | Fraction_over_pi, Divided_by_pi ->
      true
  | _ -> false

(* A mistaken answer is of the family of the right one: a number of any
   kind for a number, and the same writing with pi for an answer with pi. *)
let of_family shape written =
  match shape with Whole | Fraction | Any_number -> of_shape Any_number written | _ -> of_shape shape written

let examine k p (q : Rhema_engine.question) =
  let _, _, declared, shape = List.find (fun (name, _, _, _) -> name = k) kinds in
  match q.Rhema_engine.answers with
  | [] | _ :: _ :: _ -> fail (Printf.sprintf "%s: one answer was expected for %S" k p)
  | [ answer ] -> (
      match reading answer with
      | exception Failure m -> fail (Printf.sprintf "%s: %s, for %S" k m p)
      | got, written -> (
          if not (of_shape shape written) then fail (Printf.sprintf "%s: the answer %s is not of the type expected, for %S" k (show got) p);
          let whole = written = Whole_number in
          (match got with
           | Pi_times v when v > 300.0 -> fail (Printf.sprintf "%s: the answer %s is more than 300 pi, for %S" k (show got) p)
           | (Pi_times _ | Over_pi _) when worth got >= 1000.0 ->
               fail (Printf.sprintf "%s: the answer %s is worth 1000 or more, for %S" k (show got) p)
           | _ -> ());
          if not (worth got > 0.0) then fail (Printf.sprintf "%s: the answer %s is not a positive number, for %S" k (show got) p);
          match expected q with
          | exception Failure m -> fail (Printf.sprintf "%s: %s, for %S" k m p)
          | want, slips ->
              if not (same got want) then
                fail (Printf.sprintf "%s: answer %s, worked out %s, for %S" k (show got) (show want) p);
              if List.map fst slips <> declared then fail (Printf.sprintf "%s: the mistakes worked out are not those declared" k);
              List.iter
                (fun (name, slip) ->
                  if not (told_apart ~whole want slip) then
                    fail (Printf.sprintf "%s: %s, worked out %s, is too near the answer %s, for %S" k name (show slip) (show want) p))
                slips;
              let made = q.Rhema_engine.mistakes in
              let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) made in
              if names <> declared then
                fail
                  (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k (String.concat ", " names)
                     (String.concat ", " declared) p);
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
                      | given, given_written -> (
                          if not (of_family shape given_written) then
                            fail (Printf.sprintf "%s: %s gives %s, which is not of the answer's type, for %S" k m.mistake (show given) p);
                          if not (told_apart ~whole got given) then
                            fail (Printf.sprintf "%s: %s gives %s, too near the answer %s, for %S" k m.mistake (show given) (show got) p);
                          match List.assoc_opt m.mistake slips with
                          | Some slip when not (same given slip) ->
                              fail
                                (Printf.sprintf "%s: %s gives %s, worked out %s, for %S" k m.mistake (show given) (show slip) p)
                          | _ -> ()))
                  | _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                made))

let () =
  trials ();
  let base = load_file "related_rates.rhm" in
  let seen = Hashtbl.create 16 and generated = Hashtbl.create 4 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at_each_budget - 1 do
      Random.init (seed + seed_offset + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          Hashtbl.replace generated cost (1 + Option.value ~default:0 (Hashtbl.find_opt generated cost));
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          (match Rhema_engine.attribute q.Rhema_engine.tree "text" with
           | Rhema_engine.Text t when t = p -> ()
           | _ -> fail (Printf.sprintf "%s: the prompt is not the text of the question, for %S" k p));
          match List.find_opt (fun (name, _, _, _) -> name = k) kinds with
          | None -> fail ("a kind the header does not list: " ^ k)
          | Some (_, price, _, _) ->
              if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost) else examine k p q)
    done
  done;
  for cost = 1 to 3 do
    let count = Option.value ~default:0 (Hashtbl.find_opt generated cost) in
    if count < questions_at_each_budget / 2 then fail (Printf.sprintf "only %d questions at cost %d" count cost)
  done;
  List.iter (fun (k, _, _, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) kinds;
  (* Every choice the grammar offers is taken at least once, and no other. *)
  let ints first last = List.init (last - first + 1) (fun n -> first + n) in
  let range first last = List.map string_of_int (ints first last) in
  let pairs us vs = List.concat_map (fun u -> List.map (fun v -> (u, v)) vs) us in
  (* The areas and volumes asked for are those of the sizes 2 to 6 and the
     rates 2 to 5 whose rate of growth, worked out here, is at most 300, or
     300 pi. *)
  let growths =
    List.map
      (fun (k, figure) ->
        ( k ^ ": size and its rate",
          List.filter_map
            (fun (size, speed) ->
              match growth_values figure ~size:(float_of_int size) ~speed:(float_of_int speed) with
              | (Number v | Pi_times v), _ when v <= 300.0 +. 1e-6 -> Some (Printf.sprintf "%d, %d" size speed)
              | _ -> None)
            (pairs (ints 2 6) (ints 2 5)) ))
      figures
  in
  (* The estimates asked for are those at the squares of 2 to 9 and the
     cubes of 2 to 5, up to 3 away on either side, whose root is not known
     beforehand and whose mistake can be told from the estimate. *)
  let estimates =
    List.map
      (fun (k, ((_, _, power, _) as the_root)) ->
        ( k ^ ": point and number",
          List.filter_map
            (fun (n, d) ->
              let point = if power = 2 then n * n else n * n * n in
              if estimate_offered the_root ~point ~number:(point + d) then Some (Printf.sprintf "%d, %d" point (point + d)) else None)
            (pairs (ints 2 (if power = 2 then 9 else 5)) [ -3; -2; -1; 1; 2; 3 ]) ))
      roots
  in
  (* The ladders: the triangles 3-4-5, 6-8-10, 5-12-13 and 8-15-17, once or
     twice over, with either side on the ground, when no longer than 20. *)
  let triangles = [ (3, 4, 5); (6, 8, 10); (5, 12, 13); (8, 15, 17) ] in
  let ladders =
    List.sort_uniq compare
      (List.concat_map
         (fun ((a, b, c), times) ->
           if c * times > 20 then []
           else
             List.concat_map
               (fun speed ->
                 [ Printf.sprintf "%d, %d, %d" (c * times) (a * times) speed; Printf.sprintf "%d, %d, %d" (c * times) (b * times) speed ])
               (ints 2 4))
         (pairs triangles [ 1; 2 ]))
  in
  (* The cones: a top of radius 2 to 4, a height of 1 to 3 times as much,
     and a depth of 2 to 9 below the height. *)
  let cones =
    List.concat_map
      (fun (top, times) ->
        List.filter_map
          (fun depth -> if depth < top * times then Some (Printf.sprintf "%d, %d, %d" (top * times) top depth) else None)
          (ints 2 9))
      (pairs (ints 2 4) (ints 1 3))
  in
  let shadows k = [ (k ^ ": lamp", range 40 60); (k ^ ": walker", range 15 19); (k ^ ": speed", range 3 6) ] in
  let choices =
    growths @ estimates
    @ [ ("ladder: length, distance and speed", ladders);
        ("balloon: rate and radius", List.map (fun (c, r) -> Printf.sprintf "%d, %d" (4 * c) r) (pairs (ints 1 24) (ints 2 5)));
        ( "apart: east and north",
          List.concat_map (fun (a, b, _) -> [ Printf.sprintf "%d, %d" a b; Printf.sprintf "%d, %d" b a ]) triangles );
        ("apart: speed east", List.map (fun n -> string_of_int (10 * n)) (ints 2 9));
        ("apart: speed north", List.map (fun n -> string_of_int (10 * n)) (ints 2 9));
        ("cone: height, radius and depth", cones); ("cone: rate", range 2 9);
        ("cone: rate against depth", [ "below"; "equal"; "above" ]) ]
    @ shadows "shadow_length" @ shadows "shadow_tip"
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
  if !failures = 0 then print_endline "Rhema related_rates tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d related_rates test(s) failed." !failures);
    exit 1
  end
