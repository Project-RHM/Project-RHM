(* Independent checks for integral_applications.rhm. Nothing here uses the
   grammar's closed formulas. Every question is matched against the whole
   sentence of its form; each number in the sentence is read from a group,
   the curves are read back from their LaTeX (a sum of terms c x^m written the
   one way the grammar writes one, or the fractions and roots of the special
   curves, with every number in them read too), and the answer is found again
   from what was read, in floating point, by numerical integration of the
   quantity's definition: a composite four-point Gauss-Legendre rule, which
   never evaluates a curve at the ends of its interval. Form by form:

   - disc: the cross-section of the solid at x is a disc whose radius is the
     height of the curve there; pi y^2 is integrated from the lower to the
     upper limit read. The mistake radius_not_squared integrates pi y.
   - washer_line, washer_level (one sentence, two curves): the points where
     the two curves meet are found by a scan of their difference over
     [-20, 20] in steps of 1/100 and bisection; there must be exactly two,
     and the region is what lies between the curves there. Both curves must
     be on or above the axis in it. At each x the washer has the higher curve
     for its outer radius and the lower for its inner one, and
     pi (R^2 - r^2) is integrated between the two meeting points. The mistake
     radii_subtracted_first integrates pi (R - r)^2. The promise of
     washer_level, that the level is c s^2 for the c in front of x^2, is
     checked.
   - shell: the curve c(kx - x^2) is read (kx - x^2 when c is 1); the points
     where it meets the x-axis are found in the same way (exactly two, both
     on or right of the y-axis, the curve above the axis between them); a
     shell at x has radius x and the height of the curve, and 2 pi x y is
     integrated. The mistake shell_radius_forgotten
     integrates 2 pi y.
   - arc_length_cubic, arc_length_power: y' is found by the power rule from
     the numbers read (x^P / Q + 1 / (R x), and (A / B) x^(C/D)) and
     sqrt(1 + y'^2) is integrated; as a second opinion, the length of a
     polyline of 20000 chords on the curve. The promises are checked: 1 + y'^2
     is the square of a sum of the two parts of y' at several points for the
     first curve, y'^2 = x for the second, each of whose limits is one less
     than a square.
   - surface_parabola, surface_cone: 2 pi y sqrt(1 + y'^2) is integrated with
     y' found by the power rule (1 / (2 sqrt x) for sqrt(x), p / q for the
     cone); as a second opinion, the sum of the lateral areas of 20000 thin
     frustums on the polyline. The promises: 4 x + 1 at both ends of the
     parabola is a square, and p and q are two sides of a right triangle with
     whole sides.
   - centroid: the area, the moment about the y-axis (the integral of x y)
     and the moment about the x-axis (of y^2 / 2) are integrated and the
     moments divided by the area.
   - spring: Hooke's law from the printed force and stretch, the centimetres
     turned into metres: the constant is the force over the stretch in metres,
     and the force k x is integrated from the start to the end of the stretch.
     The mistake constant_force is the printed force times the distance, in
     metres; the spring's promise, that this mistake does not come to the
     right answer, is checked with every mistake.
   - pumping: the water is cut into layers; the layer at height y has the
     printed weight per cubic metre times pi r^2 dy and rises h - y to the
     top, which is integrated from 0 to h, in joules, and turned into the
     kilojoules asked for. The mistake lift_full_height lifts every layer
     through h.

   An answer with pi must be a `plain` formula written as one fraction times
   pi (or pi alone), which is compared as a number with the integral, and
   which is worth less than 1000: WeBWorK grades a formula to one part in a
   thousand, which would let a larger answer be off by one. The spring and
   the lengths are numbers, the centroid a point. The working of this file
   is itself tried first on integrals and curves with known answers and on
   sums that are not written as they should be.

   Besides the answers: the mistakes a form declares are listed on each of
   its questions, in the order of their declarations, each with the value
   found here and each different from the right answer, and described in
   the words of the header's list, and a form without mistakes lists none;
   each kind appears at its price alone and spends its budget; a budget
   outside 1..3 gives no question; the budget the grammar sets itself is the
   middle price; each printed number of each form takes exactly the values
   the grammar offers, none missing and none more; the pairs of limits of
   the lengths and of the parabola are exactly the ordered pairs offered;
   and the discs, washers and shells asked for are exactly those of the
   numbers offered whose volume, worked out here, is at most 300 pi. Those
   ranges, the cap and the descriptions are the only things taken from the
   grammar. The weights are not looked at. *)

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
let close ?(within = 1e-9) a b = Float.abs (a -. b) <= within *. Float.max 1.0 (Float.abs b)

(* A whole number that is a perfect square has a whole square root. *)
let square_root n =
  let rec up r = if r * r >= n then r else up (r + 1) in
  let r = up 0 in
  if n >= 0 && r * r = n then Some r else None

(* ---- Numerical working ---------------------------------------------------- *)

(* The integral of g from a to b by the four-point Gauss-Legendre rule on
   `panels` equal pieces. The ends of the interval are never evaluated. *)
let integral ?(panels = 400) g a b =
  let nodes = [ (-0.8611363115940526, 0.3478548451374538); (-0.3399810435848563, 0.6521451548625461);
                (0.3399810435848563, 0.6521451548625461); (0.8611363115940526, 0.3478548451374538) ] in
  let width = (b -. a) /. float_of_int panels in
  let sum = ref 0.0 in
  for i = 0 to panels - 1 do
    let middle = a +. (width *. (float_of_int i +. 0.5)) in
    List.iter (fun (t, w) -> sum := !sum +. (w *. g (middle +. (width *. t /. 2.0)))) nodes
  done;
  !sum *. width /. 2.0

(* The places in [-20, 20] where g vanishes: points of the grid of steps of
   1/100 where it is 0, and a bisection of each step over which it changes
   sign. *)
let zeros g =
  let at i = float_of_int i /. 100.0 in
  let found = ref [] in
  for i = -2000 to 2000 do
    if g (at i) = 0.0 then found := at i :: !found
    else if i < 2000 && g (at (i + 1)) <> 0.0 && (g (at i) < 0.0) <> (g (at (i + 1)) < 0.0) then begin
      let a = ref (at i) and b = ref (at (i + 1)) in
      for _ = 1 to 60 do
        let m = (!a +. !b) /. 2.0 in
        if (g m < 0.0) = (g !a < 0.0) then a := m else b := m
      done;
      found := ((!a +. !b) /. 2.0) :: !found
    end
  done;
  List.rev !found

(* The two places where g vanishes, with g of one sign between them. *)
let two_zeros what g =
  match zeros g with
  | [ a; b ] ->
      let samples = List.init 99 (fun n -> a +. ((b -. a) *. float_of_int (n + 1) /. 100.0)) in
      if not (List.for_all (fun x -> g x > 0.0) samples || List.for_all (fun x -> g x < 0.0) samples) then
        failwith (what ^ " change sign between the two places where they meet");
      (a, b)
  | found -> failwith (Printf.sprintf "%s meet at %d places, not two" what (List.length found))

(* The length of the polyline of `chords` chords on y between a and b, and
   the lateral area of the frustums its chords sweep out about the x-axis. *)
let polyline ?(chords = 20000) y a b =
  let at i = a +. ((b -. a) *. float_of_int i /. float_of_int chords) in
  let length = ref 0.0 and area = ref 0.0 in
  for i = 0 to chords - 1 do
    let x0 = at i and x1 = at (i + 1) in
    let y0 = y x0 and y1 = y x1 in
    let chord = sqrt (((x1 -. x0) ** 2.0) +. ((y1 -. y0) ** 2.0)) in
    length := !length +. chord;
    area := !area +. (pi *. (y0 +. y1) *. chord)
  done;
  (!length, !area)

(* ---- Reading a curve c x^m and sums of such terms --------------------------- *)

(* A whole number, written the one way it is written. *)
let integer text =
  match int_of_string_opt text with
  | Some n when string_of_int n = text -> n
  | _ -> failwith ("not a whole number: " ^ text)

(* A sum as the grammar prints one: the first term with a bare minus sign if
   it is negative, the others joined with " + " and " - "; a 1 is not written
   in front of x, a power 1 is not written. A term is (coefficient, power). *)
let written terms =
  String.concat ""
    (List.mapi
       (fun n (c, m) ->
         let letters = if m = 0 then "" else if m = 1 then "x" else Printf.sprintf "x^{%d}" m in
         (if n = 0 then if c < 0 then "-" else "" else if c < 0 then " - " else " + ")
         ^ (if abs c = 1 && letters <> "" then "" else string_of_int (abs c))
         ^ letters)
       terms)

let terms_of text =
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
  let term sign =
    let before = digits () in
    let power =
      if next () <> Some 'x' then 0
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
    if before = "" && power = 0 then failwith ("a term is missing in: " ^ text);
    ((if before = "" then sign else sign * integer before), power)
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

let height terms x = List.fold_left (fun sum (c, m) -> sum +. (float_of_int c *. (x ** float_of_int m))) 0.0 terms

(* A curve y = c x^m with c and m at least 1: (c, m). *)
let monomial text =
  match terms_of text with
  | [ (c, m) ] when c >= 1 && m >= 1 -> (c, m)
  | _ -> failwith ("not a curve c x^m: " ^ text)

(* ---- Reading a question ---------------------------------------------------- *)

let words = Str.quote

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

let a_curve = "\\([^`=]*\\)"
let a_number = "\\([0-9]+\\)"
let exact = words " Give the exact value, with [`\\pi`] written as pi where it is needed."

(* What was generated besides the kinds: each choice the grammar offers. *)
let noted : (string, string list) Hashtbl.t = Hashtbl.create 64

let note topic choice =
  let so_far = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
  if not (List.mem choice so_far) then Hashtbl.replace noted topic (choice :: so_far)

let note_number topic n = note topic (string_of_int n)

(* What a question's answer is found to be. *)
type found = Number of float | Pi_times of float | Pair of float * float

let show = function
  | Number v -> Printf.sprintf "%.12g" v
  | Pi_times v -> Printf.sprintf "%.12g pi" v
  | Pair (x, y) -> Printf.sprintf "(%.12g, %.12g)" x y

let same a b =
  match (a, b) with
  | Number u, Number v | Pi_times u, Pi_times v -> close u v
  | Pair (x, y), Pair (u, v) -> close x u && close y v
  | _ -> false

(* ---- Price 1 ---------------------------------------------------------------- *)

let disc_sentence =
  words "The region under [`y = " ^ a_curve ^ words "`] from [`x = " ^ a_number ^ words "`] to [`x = " ^ a_number
  ^ words "`] is turned about the [`x`]-axis. Find the volume of the solid it sweeps out." ^ exact

let examine_disc prompt =
  match fields 3 disc_sentence prompt with
  | [ curve; low; high ] ->
      let c, m = monomial curve in
      let a = float_of_int (integer low) and b = float_of_int (integer high) in
      if not (a < b) then failwith "the limits are not in order";
      let y = height [ (c, m) ] in
      let volume = integral (fun x -> pi *. (y x ** 2.0)) a b in
      let slip = integral (fun x -> pi *. y x) a b in
      note_number "disc: coefficient" c;
      note_number "disc: power" m;
      note "disc: lower limit" low;
      note "disc: upper limit" high;
      note "disc: coefficient, power and upper limit" (Printf.sprintf "%d, %d, %s" c m high);
      (Pi_times (volume /. pi), [ ("radius_not_squared", Pi_times (slip /. pi)) ])
  | _ -> failwith "three fields were expected"

let spring_sentence =
  words "A force of [`" ^ a_number ^ words "`] newtons holds a spring stretched [`" ^ a_number
  ^ words "`] centimetres beyond its natural length. Find the work, in joules, done in stretching it from [`" ^ a_number
  ^ words "`] to [`" ^ a_number ^ words "`] centimetres beyond its natural length."

let examine_spring prompt =
  match List.map integer (fields 4 spring_sentence prompt) with
  | [ force; held; start; finish ] ->
      if held <= 0 then failwith "the spring is held at no stretch";
      if not (start < finish) then failwith "the stretch does not grow";
      let metres n = float_of_int n /. 100.0 in
      (* Hooke's law: the force is k times the stretch *)
      let k = float_of_int force /. metres held in
      let work = integral (fun x -> k *. x) (metres start) (metres finish) in
      let slip = float_of_int force *. (metres finish -. metres start) in
      note_number "spring: force" force;
      note_number "spring: held stretch" held;
      note_number "spring: start" start;
      note_number "spring: length of the stretch" (finish - start);
      (Number work, [ ("constant_force", Number slip) ])
  | _ -> failwith "four fields were expected"

(* ---- Price 2 ---------------------------------------------------------------- *)

let washer_sentence =
  words "The region between [`y = " ^ a_curve ^ words "`] and [`y = " ^ a_curve
  ^ words "`] is turned about the [`x`]-axis. Find the volume of the solid it sweeps out." ^ exact

(* The volume swept out by the region between two curves f and g, by
   washers between the two places where they meet, and the volume a student
   finds who squares the difference of the radii. *)
let washer_volumes f g =
  let a, b = two_zeros "the curves" (fun x -> height f x -. height g x) in
  let outer x = Float.max (height f x) (height g x) and inner x = Float.min (height f x) (height g x) in
  if List.exists (fun n -> inner (a +. ((b -. a) *. float_of_int n /. 50.0)) < 0.0) (List.init 51 Fun.id) then
    failwith "the region goes below the axis";
  ( integral (fun x -> pi *. ((outer x ** 2.0) -. (inner x ** 2.0))) a b,
    integral (fun x -> pi *. ((outer x -. inner x) ** 2.0)) a b )

let examine_washer k prompt =
  match fields 2 washer_sentence prompt with
  | [ first; second ] ->
      let f = terms_of first and g = terms_of second in
      (match (k, f, g) with
       | "washer_line", [ (slope, 1) ], [ (c, 2) ] when slope >= 1 && c >= 1 ->
           note_number "washer_line: slope" slope;
           note_number "washer_line: in front of x^2" c;
           note "washer_line: slope and c" (Printf.sprintf "%d, %d" slope c)
       | "washer_level", [ (c, 2) ], [ (level, 0) ] when c >= 1 && level >= 1 -> (
           (* the promise: the level is c s^2, so the curves meet at -s and s *)
           match if level mod c = 0 then square_root (level / c) else None with
           | Some s ->
               note_number "washer_level: in front of x^2" c;
               note_number "washer_level: s" s;
               note "washer_level: c and s" (Printf.sprintf "%d, %d" c s)
           | None -> failwith "the level is not c times a square")
       | _ -> failwith "the curves are not those of this kind");
      let volume, slip = washer_volumes f g in
      (Pi_times (volume /. pi), [ ("radii_subtracted_first", Pi_times (slip /. pi)) ])
  | _ -> failwith "two fields were expected"

let shell_sentence =
  words "The region between [`y = " ^ a_curve
  ^ words "`] and the [`x`]-axis is turned about the [`y`]-axis. Find the volume of the solid it sweeps out." ^ exact

(* The volume swept out about the y-axis by the region between a curve and
   the x-axis, by shells, and the volume a student finds who leaves out the
   radius of a shell. *)
let shell_volumes height =
  let a, b = two_zeros "the curve and the axis" height in
  if a < 0.0 then failwith "the region is not on one side of the y-axis";
  if height ((a +. b) /. 2.0) < 0.0 then failwith "the region is below the axis";
  (integral (fun x -> 2.0 *. pi *. x *. height x) a b, integral (fun x -> 2.0 *. pi *. height x) a b)

(* y = c(kx - x^2), or kx - x^2 when c is 1: (c, k). *)
let shell_curve text =
  let c, inside =
    if Str.string_match (Str.regexp "\\([0-9]+\\)(\\(.*\\))$") text 0 then
      (integer (Str.matched_group 1 text), Str.matched_group 2 text)
    else (1, text)
  in
  if c < 1 || (c = 1 && inside <> text) then failwith ("a factor that is not written as one is: " ^ text);
  match terms_of inside with
  | [ (k, 1); (-1, 2) ] when k >= 1 -> (c, k)
  | _ -> failwith "the curve is not c (k x - x^2)"

let examine_shell prompt =
  match fields 1 shell_sentence prompt with
  | [ curve ] ->
      let c, k = shell_curve curve in
      note_number "shell: k" k;
      note_number "shell: c" c;
      note "shell: c and k" (Printf.sprintf "%d, %d" c k);
      let volume, slip = shell_volumes (fun x -> float_of_int c *. height [ (k, 1); (-1, 2) ] x) in
      (Pi_times (volume /. pi), [ ("shell_radius_forgotten", Pi_times (slip /. pi)) ])
  | _ -> failwith "one field was expected"

let length_sentence curve =
  words "Find the length of the curve [`y = " ^ curve ^ words "`] from [`x = " ^ a_number ^ words "`] to [`x = "
  ^ a_number ^ words "`]."

(* The length by the integral of sqrt(1 + y'^2), and by a polyline, which
   must agree. *)
let length_of y slope a b =
  let length = integral (fun x -> sqrt (1.0 +. (slope x ** 2.0))) a b in
  let chords, _ = polyline y a b in
  if not (close ~within:1e-6 length chords) then
    failwith (Printf.sprintf "the integral gives %.12g and the polyline %.12g" length chords);
  length

let cubic_curve = words "\\frac{x^{" ^ a_number ^ words "}}{" ^ a_number ^ words "} + \\frac{1}{" ^ a_number ^ words "x}"

let examine_arc_cubic prompt =
  match List.map integer (fields 5 (length_sentence cubic_curve) prompt) with
  | [ p; q; r; low; high ] ->
      let a = float_of_int low and b = float_of_int high in
      if not (0.0 < a && a < b) then failwith "the limits are not in order on the positive side";
      let fp = float_of_int p and fq = float_of_int q and fr = float_of_int r in
      let y x = ((x ** fp) /. fq) +. (1.0 /. (fr *. x)) in
      let rising x = fp *. (x ** (fp -. 1.0)) /. fq and falling x = 1.0 /. (fr *. x *. x) in
      let slope x = rising x -. falling x in
      (* the promise: 1 + y'^2 is the square of the sum of the two parts *)
      List.iter
        (fun x ->
          if not (close (1.0 +. (slope x ** 2.0)) ((rising x +. falling x) ** 2.0)) then
            failwith "1 + y'^2 is not a square")
        [ 0.5; 1.0; 1.7; 2.3; 3.9 ];
      note_number "arc_length_cubic: power" p;
      note_number "arc_length_cubic: under the power" q;
      note_number "arc_length_cubic: in front of 1/x" r;
      note_number "arc_length_cubic: lower limit" low;
      note_number "arc_length_cubic: upper limit" high;
      note "arc_length_cubic: limits" (Printf.sprintf "%d, %d" low high);
      (Number (length_of y slope a b), [])
  | _ -> failwith "five fields were expected"

let power_curve = words "\\frac{" ^ a_number ^ words "}{" ^ a_number ^ words "} x^{" ^ a_number ^ "/" ^ a_number ^ "}"

let examine_arc_power prompt =
  match List.map integer (fields 6 (length_sentence power_curve) prompt) with
  | [ top; bottom; up; down; low; high ] ->
      let a = float_of_int low and b = float_of_int high in
      if not (0.0 <= a && a < b) then failwith "the limits are not in order on the positive side";
      let scale = float_of_int top /. float_of_int bottom and exponent = float_of_int up /. float_of_int down in
      let y x = scale *. (x ** exponent) in
      let slope x = scale *. exponent *. (x ** (exponent -. 1.0)) in
      (* the promise: y'^2 = x, and each limit is one less than a square *)
      List.iter (fun x -> if not (close (slope x ** 2.0) x) then failwith "y'^2 is not x") [ 0.5; 1.0; 2.3; 7.9 ];
      if square_root (low + 1) = None || square_root (high + 1) = None then
        failwith "a limit is not one less than a square";
      note (Printf.sprintf "arc_length_power: curve") (Printf.sprintf "%d/%d x^%d/%d" top bottom up down);
      note_number "arc_length_power: lower limit" low;
      note_number "arc_length_power: upper limit" high;
      note "arc_length_power: limits" (Printf.sprintf "%d, %d" low high);
      (Number (length_of y slope a b), [])
  | _ -> failwith "six fields were expected"

(* ---- Price 3 ---------------------------------------------------------------- *)

let surface_sentence curve =
  words "The curve [`y = " ^ curve ^ words "`] from [`x = " ^ a_number ^ words "`] to [`x = " ^ a_number
  ^ words "`] is turned about the [`x`]-axis. Find the area of the surface it sweeps out." ^ exact

(* The area by the integral of 2 pi y sqrt(1 + y'^2), and by frustums, which
   must agree. *)
let surface_of y slope a b =
  let area = integral (fun x -> 2.0 *. pi *. y x *. sqrt (1.0 +. (slope x ** 2.0))) a b in
  let _, frustums = polyline y a b in
  if not (close ~within:1e-6 area frustums) then
    failwith (Printf.sprintf "the integral gives %.12g and the frustums %.12g" area frustums);
  area

let examine_surface_parabola prompt =
  match List.map integer (fields 2 (surface_sentence (words "\\sqrt{x}")) prompt) with
  | [ low; high ] ->
      let a = float_of_int low and b = float_of_int high in
      if not (0.0 <= a && a < b) then failwith "the limits are not in order on the positive side";
      let area = surface_of sqrt (fun x -> 1.0 /. (2.0 *. sqrt x)) a b in
      List.iter
        (fun x ->
          match square_root ((4 * x) + 1) with
          | Some _ -> ()
          | None -> failwith "4 x + 1 at an end of the parabola is not a square")
        [ low; high ];
      note_number "surface_parabola: lower limit" low;
      note_number "surface_parabola: upper limit" high;
      note "surface_parabola: limits" (Printf.sprintf "%d, %d" low high);
      (Pi_times (area /. pi), [])
  | _ -> failwith "two fields were expected"

let examine_surface_cone prompt =
  match
    List.map integer (fields 4 (surface_sentence (words "\\frac{" ^ a_number ^ words "}{" ^ a_number ^ words "} x")) prompt)
  with
  | [ p; q; low; high ] ->
      let a = float_of_int low and b = float_of_int high in
      if not (0.0 <= a && a < b) then failwith "the limits are not in order on the positive side";
      let slope = float_of_int p /. float_of_int q in
      let area = surface_of (fun x -> slope *. x) (fun _ -> slope) a b in
      if square_root ((p * p) + (q * q)) = None then
        failwith "the slope is not the ratio of two sides of a right triangle with whole sides";
      note "surface_cone: slope" (Printf.sprintf "%d/%d" p q);
      note_number "surface_cone: lower limit" low;
      note_number "surface_cone: upper limit" high;
      (Pi_times (area /. pi), [])
  | _ -> failwith "four fields were expected"

let centroid_sentence =
  words "Find the centroid of the region between [`y = " ^ a_curve ^ words "`] and the [`x`]-axis from [`x = " ^ a_number
  ^ words "`] to [`x = " ^ a_number ^ words "`]. Enter it as a point, such as [`(3/4, 5/2)`]."

let examine_centroid prompt =
  match fields 3 centroid_sentence prompt with
  | [ curve; low; high ] ->
      let c, m = monomial curve in
      let a = float_of_int (integer low) and b = float_of_int (integer high) in
      if not (a < b) then failwith "the limits are not in order";
      let y = height [ (c, m) ] in
      let area = integral y a b in
      let about_y = integral (fun x -> x *. y x) a b and about_x = integral (fun x -> (y x ** 2.0) /. 2.0) a b in
      note_number "centroid: coefficient" c;
      note_number "centroid: power" m;
      note "centroid: lower limit" low;
      note "centroid: upper limit" high;
      (Pair (about_y /. area, about_x /. area), [])
  | _ -> failwith "three fields were expected"

let pumping_sentence =
  words "A tank in the shape of an upright cylinder of radius [`" ^ a_number ^ words "`] metres and height [`" ^ a_number
  ^ words "`] metres is full of water, which weighs [`" ^ a_number
  ^ words "`] newtons per cubic metre. Find the work, in kilojoules, done in pumping all the water out over the top of the tank."
  ^ exact

let examine_pumping prompt =
  match List.map integer (fields 3 pumping_sentence prompt) with
  | [ radius; tall; weight ] ->
      let r = float_of_int radius and h = float_of_int tall and w = float_of_int weight in
      (* the layer at height y weighs w pi r^2 dy and rises h - y *)
      let layer y = w *. pi *. r *. r *. (h -. y) in
      let work = integral layer 0.0 h /. 1000.0 in
      let slip = integral (fun _ -> w *. pi *. r *. r *. h) 0.0 h /. 1000.0 in
      note_number "pumping: radius" radius;
      note_number "pumping: height" tall;
      note_number "pumping: weight of water" weight;
      (Pi_times (work /. pi), [ ("lift_full_height", Pi_times (slip /. pi)) ])
  | _ -> failwith "three fields were expected"

(* The right answer of a question and the answer of each mistake its form
   declares, found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let prompt = q.Rhema_engine.prompt in
  match kind q with
  | "disc" -> examine_disc prompt
  | "spring" -> examine_spring prompt
  | ("washer_line" | "washer_level") as k -> examine_washer k prompt
  | "shell" -> examine_shell prompt
  | "arc_length_cubic" -> examine_arc_cubic prompt
  | "arc_length_power" -> examine_arc_power prompt
  | "surface_parabola" -> examine_surface_parabola prompt
  | "surface_cone" -> examine_surface_cone prompt
  | "centroid" -> examine_centroid prompt
  | "pumping" -> examine_pumping prompt
  | k -> failwith ("unknown kind " ^ k)

(* ---- The engine's answer ------------------------------------------------------ *)

module F = Rhema_formula

(* A multiple of pi is written as one positive fraction in front of pi, as
   3/5*pi, or as pi alone. *)
let pi_multiple f =
  let q =
    match f with
    | F.Pi -> 1.0
    | F.Multiply (F.Constant c, F.Pi)
      when Rhema_number.compare c Rhema_number.zero > 0 && not (Rhema_number.equal c (Rhema_number.of_int 1)) ->
        Rhema_number.to_float c
    | _ -> failwith "a formula that is not one fraction times pi"
  in
  if not (close (F.evaluate_with (fun _ -> None) f) (q *. pi)) then
    failwith "the formula does not come to the multiple of pi read from it";
  q

(* What a value is, and whether it is a plain answer. *)
let reading = function
  | Rhema_engine.Plain (Rhema_engine.Formula f) -> (Pi_times (pi_multiple f), true)
  | Rhema_engine.Num n -> (Number (Rhema_number.to_float n), false)
  | Rhema_engine.Point [ x; y ] -> (Pair (Rhema_number.to_float x, Rhema_number.to_float y), false)
  | other -> failwith ("an answer of an unexpected type: " ^ Rhema_engine.describe_value other)

(* ---- The working of this file, tried on examples --------------------------- *)

let trials () =
  let expect name condition = if not condition then fail ("trial: " ^ name) in
  let refused work = match work () with _ -> false | exception Failure _ -> true in
  List.iter
    (fun text -> expect ("this sum should be refused: " ^ text) (refused (fun () -> terms_of text)))
    [ "1x"; "x^{1}"; "0x + 1"; "x +2"; "x + - 2"; "+ x"; "02x"; ""; "x - "; "x^{2"; "x^{}"; "x - -x"; "2 x" ];
  expect "a sum is read" (terms_of "-x^{2} + 4x - 7" = [ (-1, 2); (4, 1); (-7, 0) ]);
  expect "a curve is read" (monomial "3x^{2}" = (3, 2) && monomial "x" = (1, 1));
  expect "a constant is not a curve c x^m" (refused (fun () -> monomial "4"));
  expect "the integral of x^2 from 0 to 3" (close (integral (fun x -> x *. x) 0.0 3.0) 9.0);
  expect "the integral of sqrt x from 0 to 4" (close ~within:1e-5 (integral sqrt 0.0 4.0) (16.0 /. 3.0));
  expect "the integral of 1 / x from 1 to e" (close (integral (fun x -> 1.0 /. x) 1.0 (exp 1.0)) 1.0);
  expect "x^2 - 4 vanishes at -2 and 2" (zeros (fun x -> (x *. x) -. 4.0) = [ -2.0; 2.0 ]);
  (match zeros (fun x -> (x *. x) -. 2.0) with
   | [ a; b ] -> expect "x^2 - 2 vanishes at the roots of 2" (close a (-.sqrt 2.0) && close b (sqrt 2.0))
   | _ -> expect "x^2 - 2 vanishes twice" false);
  expect "x^3 - x does not vanish twice" (refused (fun () -> two_zeros "x^3 - x" (fun x -> (x *. x *. x) -. x)));
  (* the unit circle's upper half: half the circumference, the sphere *)
  let length, area = polyline (fun x -> sqrt (Float.max 0.0 (1.0 -. (x *. x)))) (-1.0) 1.0 in
  expect "half the unit circle" (close ~within:1e-6 length pi);
  expect "the unit sphere" (close ~within:1e-6 area (4.0 *. pi));
  (* a cone of slope 3/4 from 0 to 4: slant 5, radius 3 *)
  expect "a cone" (close (surface_of (fun x -> 0.75 *. x) (fun _ -> 0.75) 0.0 4.0) (15.0 *. pi));
  expect "the length of a straight line" (close (length_of (fun x -> 0.75 *. x) (fun _ -> 0.75) 0.0 4.0) 5.0);
  expect "a length whose slope is wrong is refused"
    (refused (fun () -> length_of (fun x -> x *. x) (fun x -> x) 0.0 2.0));
  (* one fraction times pi *)
  let fraction n d = F.Constant (Rhema_number.make n d) in
  expect "3/5 pi is read" (close (pi_multiple (F.Multiply (fraction 3 5, F.Pi))) 0.6);
  expect "pi is read" (pi_multiple F.Pi = 1.0);
  expect "3 pi / 5 is refused" (refused (fun () -> pi_multiple (F.Divide (F.Multiply (fraction 3 1, F.Pi), fraction 5 1))));
  expect "1 pi is refused" (refused (fun () -> pi_multiple (F.Multiply (fraction 1 1, F.Pi))));
  expect "a fraction alone is refused" (refused (fun () -> pi_multiple (fraction 3 5)))

(* ---- The questions ----------------------------------------------------------- *)

let questions_at_each_budget = 3000

(* What each mistake's description says, word for word. *)
let said =
  [ ("radius_not_squared", "takes the area of a disc to be pi times its radius, where the radius is squared");
    ( "radii_subtracted_first",
      "squares the difference of the outer and inner radius, where the difference of their squares belongs" );
    ("shell_radius_forgotten", "leaves out the radius x of a shell: 2 pi times the integral of the height alone");
    ( "constant_force",
      "takes the force given for one stretch to act all the way, where the force grows with the stretch" );
    ( "lift_full_height",
      "lifts all the water through the whole height of the tank, where a layer only rises from where it is" ) ]

(* The kinds, their prices, their mistakes in order, and the type of their
   answers: a plain multiple of pi, a number, or a point. *)
type shape = Pi_plain | Plain_number | Plain_point

let kinds =
  [ ("disc", 1, [ "radius_not_squared" ], Pi_plain); ("spring", 1, [ "constant_force" ], Plain_number);
    ("washer_line", 2, [ "radii_subtracted_first" ], Pi_plain);
    ("washer_level", 2, [ "radii_subtracted_first" ], Pi_plain);
    ("shell", 2, [ "shell_radius_forgotten" ], Pi_plain); ("arc_length_cubic", 2, [], Plain_number);
    ("arc_length_power", 2, [], Plain_number); ("surface_parabola", 3, [], Pi_plain);
    ("surface_cone", 3, [], Pi_plain); ("centroid", 3, [], Plain_point);
    ("pumping", 3, [ "lift_full_height" ], Pi_plain) ]

let of_shape shape (found, plain) =
  match (shape, found) with
  | Pi_plain, Pi_times _ -> plain
  | Plain_number, Number _ | Plain_point, Pair _ -> not plain
  | _ -> false

let examine k p (q : Rhema_engine.question) =
  let _, _, declared, shape = List.find (fun (name, _, _, _) -> name = k) kinds in
  match q.Rhema_engine.answers with
  | [] | _ :: _ :: _ -> fail (Printf.sprintf "%s: one answer was expected for %S" k p)
  | [ answer ] -> (
      match reading answer with
      | exception Failure m -> fail (Printf.sprintf "%s: %s, for %S" k m p)
      | (got, _) as read -> (
          if not (of_shape shape read) then fail (Printf.sprintf "%s: the answer is not of the type expected, for %S" k p);
          (match got with
           | Pi_times v when v *. pi >= 1000.0 ->
               fail (Printf.sprintf "%s: the answer %s is worth 1000 or more, for %S" k (show got) p)
           | _ -> ());
          match expected q with
          | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
          | want, slips ->
              if not (same got want) then
                fail (Printf.sprintf "%s: answer %s, worked out %s, for %S" k (show got) (show want) p);
              if List.map fst slips <> declared then fail (Printf.sprintf "%s: the mistakes worked out are not those declared" k);
              List.iter
                (fun (name, slip) ->
                  if same slip want then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k name p))
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
                      | (given, _) as read -> (
                          if not (of_shape shape read) then
                            fail (Printf.sprintf "%s: %s is not of the answer's type, for %S" k m.mistake p);
                          if same given got then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p);
                          match List.assoc_opt m.mistake slips with
                          | Some slip when not (same slip given) ->
                              fail
                                (Printf.sprintf "%s: %s gives %s, worked out %s, for %S" k m.mistake (show given) (show slip) p)
                          | _ -> ()))
                  | _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                made))

let () =
  trials ();
  let base = load_file "integral_applications.rhm" in
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
  let range first last = List.init (last - first + 1) (fun n -> string_of_int (first + n)) in
  (* The discs asked for are those whose volume, worked out here, is at
     most 300 pi, so that one part in a thousand of it is less than 1. *)
  let small_discs =
    List.concat_map
      (fun c ->
        List.concat_map
          (fun m ->
            List.filter_map
              (fun b ->
                let y x = float_of_int c *. (x ** float_of_int m) in
                if integral (fun x -> y x *. y x) 0.0 (float_of_int b) <= 300.0 +. 1e-6 then
                  Some (Printf.sprintf "%d, %d, %d" c m b)
                else None)
              [ 1; 2; 3 ])
          [ 1; 2; 3 ])
      [ 1; 2; 3 ]
  in
  (* Likewise for washers and shells: the pairs whose volume, worked out
     here, is at most 300 pi. *)
  let capped name pairs volume =
    List.filter_map
      (fun (u, v) -> if volume u v <= (300.0 *. pi) +. 1e-6 then Some (Printf.sprintf "%d, %d" u v) else None)
      pairs
    |> fun offered -> (name, offered)
  in
  let pairs us vs = List.concat_map (fun u -> List.map (fun v -> (u, v)) vs) us in
  let ints first last = List.init (last - first + 1) (fun n -> first + n) in
  let ordered values f =
    List.concat_map (fun u -> List.filter_map (fun v -> if u < v then Some (Printf.sprintf "%d, %d" (f u) (f v)) else None) values) values
  in
  let capped_pairs =
    [ capped "washer_line: slope and c" (pairs (ints 1 4) (ints 1 3)) (fun k c -> fst (washer_volumes [ (k, 1) ] [ (c, 2) ]));
      capped "washer_level: c and s" (pairs (ints 1 3) (ints 1 3)) (fun c s -> fst (washer_volumes [ (c, 2) ] [ (c * s * s, 0) ]));
      capped "shell: c and k" (pairs (ints 1 3) (ints 3 6)) (fun c k ->
          fst (shell_volumes (fun x -> float_of_int c *. height [ (k, 1); (-1, 2) ] x))) ]
  in
  let choices =
    capped_pairs
    @ [ ("arc_length_cubic: limits", ordered (ints 1 4) Fun.id);
        ("arc_length_power: limits", ordered (ints 1 5) (fun j -> (j * j) - 1));
        ("surface_parabola: limits", ordered [ 1; 3; 5; 7; 9 ] (fun j -> ((j * j) - 1) / 4)) ]
    @ [ ("disc: coefficient, power and upper limit", small_discs); ("disc: coefficient", range 1 3); ("disc: power", range 1 3); ("disc: lower limit", [ "0" ]);
      ("disc: upper limit", range 1 3);
      ("spring: force", List.init 11 (fun n -> string_of_int (5 * (n + 2)))); ("spring: held stretch", range 2 10);
      ("spring: start", range 0 10); ("spring: length of the stretch", range 1 10);
      ("washer_line: slope", range 1 4); ("washer_line: in front of x^2", range 1 3);
      ("washer_level: in front of x^2", range 1 3); ("washer_level: s", range 1 2); ("shell: k", range 3 6);
      ("shell: c", range 1 3); ("arc_length_cubic: power", [ "3" ]); ("arc_length_cubic: under the power", [ "6" ]);
      ("arc_length_cubic: in front of 1/x", [ "2" ]); ("arc_length_cubic: lower limit", range 1 3);
      ("arc_length_cubic: upper limit", range 2 4); ("arc_length_power: curve", [ "2/3 x^3/2" ]);
      ("arc_length_power: lower limit", [ "0"; "3"; "8"; "15" ]);
      ("arc_length_power: upper limit", [ "3"; "8"; "15"; "24" ]);
      ("surface_parabola: lower limit", [ "0"; "2"; "6"; "12" ]);
      ("surface_parabola: upper limit", [ "2"; "6"; "12"; "20" ]);
      ("surface_cone: slope", [ "3/4"; "4/3"; "5/12"; "12/5" ]); ("surface_cone: lower limit", [ "0" ]);
      ("surface_cone: upper limit", range 1 3); ("centroid: coefficient", range 1 3); ("centroid: power", range 1 3);
      ("centroid: lower limit", [ "0" ]); ("centroid: upper limit", range 1 3); ("pumping: radius", range 1 2);
      ("pumping: height", range 1 4); ("pumping: weight of water", [ "9800" ]) ]
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
  if !failures = 0 then print_endline "Rhema integral_applications tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d integral_applications test(s) failed." !failures);
    exit 1
  end
