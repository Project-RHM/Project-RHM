(* Independent checks for linear_programming.rhm. Every question is matched
   against the whole sentence of its form, the objective and every constraint
   are read back from it, and the programme is solved again here, on exact
   fractions, by a method that knows nothing of how the grammar builds a
   region or of which points are its corners:

     every constraint is a half-plane a x + b y <= c; every two boundary
     lines that are not parallel are intersected; the intersections that
     satisfy all the constraints are the corners of the region; the
     objective is tried at each of them.

   The directions in which the region goes on for ever are found too (a
   direction along a boundary line that no constraint ever stops). A greatest
   value is asked for only over a region that is cut off on every side; a
   least value may be asked for over a region that goes on for ever, and then
   the objective must not decrease along any of those directions, and its
   coefficients must be positive with x >= 0 and y >= 0 among the
   constraints, so that the least corner value is the least value.

   As a second opinion, every point with coordinates in quarters in the box
   around the corners (a little beyond it where the region goes on) is tried:
   none that lies in the region may beat the corner value, and where the best
   corner is such a point the grid must reach that value too. Every printed
   constraint must carry an edge of the region (two corners on its line, or
   one corner and a direction along it in which the region goes on): a
   constraint that never matters is a failure.

   - corners: the four printed points are read in their order. They start at
     the origin and go round counter-clockwise through a point of the x-axis,
     a point with positive coordinates and a point of the y-axis, and the
     cross products of consecutive edges all have one sign, so they are the
     corners of a convex quadrilateral. Its four edges are then turned into
     half-planes and the method above must give back exactly the four printed
     points as corners; the answer is the greatest value it finds, which must
     also be the greatest of the objective at the four printed points.
   - box_and_sum: x + y <= s, x <= a, y <= b, x >= 0, y >= 0 are read and
     solved as above. The answer is the greatest corner value. The two
     coefficients of the objective differ: with equal ones the answer would
     be the coefficient times s whatever a and b are.
   - two_lines, general_lines: two slanted constraints and the two axes are
     read and solved as above; the answer is the greatest corner value.
     two_lines has the lines x + 2y and 2x + y, general_lines any other pair.
   - optimal_point: the same reading; the question must ask for a point; the
     answer must be a point, a corner of the region found here, the one that
     gives the greatest value, and no other corner may give that value. The
     point to enter has whole coordinates. Two corners that are not the best
     may give the same value, and such questions are seen.
   - minimise: two slanted constraints with >= and the two axes; the region
     goes on for ever, the checks of the second paragraph are made, and the
     answer is the least corner value.

   In the forms with two slanted lines the header says more, and it is
   checked on the printed lines: they cross at a point with whole positive
   coordinates, which is a corner of the region, and besides it (and the
   origin, when the region is below the lines) the region has one corner on
   each axis, each on a different one of the two lines.

   The mistake intercepts_outside is found again from what it says: for
   every constraint line other than the axes, the points where it meets the
   x-axis and the y-axis are taken, whether they lie in the region or not;
   the corners of the region are added; the greatest value of the objective
   over all of them (the least, where the least value is asked for) is the
   mistaken answer. Where a point is asked for, the mistaken answer is the
   point outside the region, among those met on the axes, that gives the
   greatest value, if that value is more than the right one; of two such
   points with the same value the one on the x-axis is taken. On the forms
   that have a line for the mistake (all but corners) it must be listed with
   exactly that answer whenever it is not the right answer, and not listed
   when it is; a listed mistake never gives the right answer; corners lists
   nothing.

   Each kind appears at its price and at no other, no other kind appears, the
   budget is spent, a budget outside 1..3 gives no question, and every choice
   the grammar offers (each coefficient of the objective, each pair of lines,
   each crossing point, each bound) is seen at least once and nothing beyond
   them: those ranges, the budget 2 that the grammar sets itself and the
   order in which a form prints its constraints are the only things taken
   from the grammar. The weights of the forms are not looked at. *)

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
let ( +/ ) a b = ratio ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( */ ) a b = ratio (a.top * b.top) (a.bottom * b.bottom)
let less a b = a.top * b.bottom < b.top * a.bottom
let print x = if x.bottom = 1 then string_of_int x.top else Printf.sprintf "%d/%d" x.top x.bottom

(* The whole numbers just below and just above a fraction. *)
let floor_of x = if x.top >= 0 then x.top / x.bottom else -((x.bottom - 1 - x.top) / x.bottom)
let ceiling_of x = -floor_of (ratio (-x.top) x.bottom)

let of_number (n : Rhema_number.t) = ratio n.Rhema_number.numerator n.Rhema_number.denominator

(* An answer: a number, or a point of the plane. *)
type answer = Number of fraction | Place of (fraction * fraction)

let show_point (x, y) = Printf.sprintf "(%s, %s)" (print x) (print y)
let show = function Number x -> print x | Place point -> show_point point

let read = function
  | Rhema_engine.Num n -> Some (Number (of_number n))
  | Rhema_engine.Point [ x; y ] -> Some (Place (of_number x, of_number y))
  | _ -> None

(* ---- Linear programmes in the plane ------------------------------------ *)

(* The half-plane a x + b y <= c. *)
type half_plane = { a : int; b : int; c : int }

let show_half_plane h = Printf.sprintf "%dx + %dy <= %d" h.a h.b h.c
let left_side h (x, y) = (whole h.a */ x) +/ (whole h.b */ y)
let holds h point = not (less (whole h.c) (left_side h point))
let on_line h point = left_side h point = whole h.c

(* The point where two boundary lines meet, by Cramer's rule; none when they
   are parallel. *)
let crossing h k =
  let det = (h.a * k.b) - (k.a * h.b) in
  if det = 0 then None else Some (ratio ((h.c * k.b) - (k.c * h.b)) det, ratio ((h.a * k.c) - (k.a * h.c)) det)

let rec pairs = function [] -> [] | first :: rest -> List.map (fun other -> (first, other)) rest @ pairs rest

(* The corners of a region: the meeting points of two boundary lines that
   satisfy every constraint. *)
let corners_of region =
  List.sort_uniq compare
    (List.filter_map
       (fun (h, k) ->
         match crossing h k with
         | Some point when List.for_all (fun each -> holds each point) region -> Some point
         | _ -> None)
       (pairs region))

(* The directions in which a region goes on for ever: a direction along a
   boundary line, one way or the other, that moves into no constraint. Every
   other such direction lies between two of these. *)
let ways_out region =
  List.sort_uniq compare
    (List.filter
       (fun (dx, dy) -> List.for_all (fun h -> (h.a * dx) + (h.b * dy) <= 0) region)
       (List.concat_map (fun h -> [ (-h.b, h.a); (h.b, -h.a) ]) region))

(* The same half-plane written twice, perhaps with all its numbers scaled. *)
let same_half_plane h k =
  h.a * k.b = k.a * h.b && h.a * k.c = k.a * h.c && h.b * k.c = k.b * h.c && (h.a * k.a) + (h.b * k.b) > 0

let value (p, q) (x, y) = (whole p */ x) +/ (whole q */ y)

let best_of ~greatest values =
  match values with
  | [] -> failwith "no value to choose from"
  | first :: rest ->
      List.fold_left (fun best v -> if (if greatest then less best v else less v best) then v else best) first rest

(* Every point of the region with coordinates in quarters, in the box around
   the corners (and a little beyond, where the region goes on): none beats
   `best`, and if the best corner is such a point the grid reaches `best`. *)
let quarters = 4

let grid_agrees ~greatest (p, q) region corners out best at =
  let margin = if out = [] then 0 else 3 in
  let lowest part = List.fold_left (fun least point -> min least (floor_of (part point))) max_int corners - margin
  and highest part = List.fold_left (fun most point -> max most (ceiling_of (part point))) min_int corners + margin in
  let inside = ref 0 and reached = ref false in
  for i = quarters * lowest fst to quarters * highest fst do
    for j = quarters * lowest snd to quarters * highest snd do
      if List.for_all (fun h -> (h.a * i) + (h.b * j) <= quarters * h.c) region then begin
        incr inside;
        (* the value here is ((p i) + (q j)) / 4, held against best *)
        let here = ((p * i) + (q * j)) * best.bottom and there = quarters * best.top in
        if here = there then reached := true;
        if if greatest then here > there else here < there then
          failwith
            (Printf.sprintf "the point (%d/4, %d/4) of the region gives %s, which beats %s" i j
               (print (ratio ((p * i) + (q * j)) quarters))
               (print best))
      end
    done
  done;
  if !inside < 2 then failwith "the region holds no points of the grid";
  let on_grid (x, y) = quarters mod x.bottom = 0 && quarters mod y.bottom = 0 in
  if List.exists on_grid at && not !reached then failwith "no point of the grid reaches the best corner value"

type solved = {
  best : fraction;  (* the greatest or the least value *)
  corners : (fraction * fraction) list;
  at : (fraction * fraction) list;  (* the corners that give it *)
  out : (int * int) list;  (* the directions in which the region goes on *)
}

(* The greatest or least value of p x + q y over a region, with everything
   that makes it one: the region has corners, the objective does not improve
   for ever, the grid agrees, and every constraint carries an edge. *)
let solve ~greatest ((p, q) as objective) region =
  List.iter
    (fun (h, k) -> if same_half_plane h k then failwith ("a constraint is given twice: " ^ show_half_plane h))
    (pairs region);
  let corners = corners_of region in
  if corners = [] then failwith "the region has no corner";
  let out = ways_out region in
  List.iter
    (fun (dx, dy) ->
      let gain = (p * dx) + (q * dy) in
      if if greatest then gain > 0 else gain < 0 then
        failwith (Printf.sprintf "the objective improves for ever in the direction (%d, %d)" dx dy))
    out;
  let best = best_of ~greatest (List.map (value objective) corners) in
  let at = List.filter (fun corner -> value objective corner = best) corners in
  grid_agrees ~greatest objective region corners out best at;
  List.iter
    (fun h ->
      let carries_an_edge =
        match List.filter (on_line h) corners with
        | _ :: _ :: _ -> true
        | [ _ ] -> List.exists (fun (dx, dy) -> (h.a * dx) + (h.b * dy) = 0) out
        | [] -> false
      in
      if not carries_an_edge then failwith ("a constraint never matters: " ^ show_half_plane h))
    region;
  { best; corners; at; out }

(* What the mistake intercepts_outside says: every point where a constraint
   line other than an axis meets an axis is tried, in the region or not,
   besides the corners. *)
let is_axis h = h.c = 0 && (h.a = 0 || h.b = 0)

let meets_axes h =
  (if h.a <> 0 then [ (ratio h.c h.a, zero) ] else []) @ if h.b <> 0 then [ (zero, ratio h.c h.b) ] else []

let intercepts_outside ~greatest objective region corners =
  let tried = corners @ List.concat_map meets_axes (List.filter (fun h -> not (is_axis h)) region) in
  best_of ~greatest (List.map (value objective) tried)

(* The same mistake where a point is asked for: of the points met on the axes
   that lie outside the region, the one with the best value, if that value
   beats the right one; of several with that value, the one on the x-axis.
   None when no point outside the region beats the right value. With the
   point comes whether another point outside had the same value. *)
let point_outside ~greatest objective region best =
  let beats a b = if greatest then less b a else less a b in
  let met = List.concat_map meets_axes (List.filter (fun h -> not (is_axis h)) region) in
  let outside = List.sort_uniq compare (List.filter (fun point -> not (List.for_all (fun h -> holds h point) region)) met) in
  if outside = [] then None
  else
    let top = best_of ~greatest (List.map (value objective) outside) in
    if not (beats top best) then None
    else
      match List.filter (fun point -> value objective point = top) outside with
      | [ only ] -> Some (only, false)
      | several -> (
          match List.filter (fun (_, y) -> y = zero) several with
          | [ only ] -> Some (only, true)
          | _ -> failwith "the points outside the region with the best value are not one on the x-axis and others")

(* ---- Reading a question -------------------------------------------------- *)

let words = Str.quote

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* A whole number, written the one way it is written. *)
let integer text =
  match int_of_string_opt text with
  | Some n when string_of_int n = text -> n
  | _ -> failwith ("not a whole number: " ^ text)

(* The number before a letter: a 1 is not written, and nothing less is. *)
let before_letter text =
  if text = "" then 1
  else
    let n = integer text in
    if n < 2 then failwith ("a coefficient is not written as one is: " ^ text);
    n

(* "px + qy", as two groups. *)
let an_objective = "\\([0-9]*\\)x \\+ \\([0-9]*\\)y"

(* The items of "[`A`], [`B`] and [`C`]", written the one way a list is. *)
let listed text =
  let length = String.length text in
  if length < 4 || String.sub text 0 2 <> "[`" || String.sub text (length - 2) 2 <> "`]" then
    failwith ("not a list: " ^ text);
  let body = String.sub text 2 (length - 4) in
  let items = Str.split_delim (Str.regexp "`\\], \\[`\\|`\\] and \\[`") body in
  let rec joined = function
    | [] -> ""
    | [ only ] -> only
    | [ first; last ] -> first ^ "`] and [`" ^ last
    | first :: rest -> first ^ "`], [`" ^ joined rest
  in
  if List.length items < 2 || joined items <> body then failwith ("not a list with commas and one \"and\": " ^ text);
  List.iter (fun item -> if String.contains item '`' then failwith ("not a list: " ^ text)) items;
  items

(* A printed constraint: on_x x + on_y y, then <= or >=, then the bound. *)
type inequality = { on_x : int; on_y : int; at_most : bool; bound : int }

let inequality text =
  let pattern = Str.regexp "\\(\\([0-9]*\\)x\\)?\\( \\+ \\)?\\(\\([0-9]*\\)y\\)? \\\\\\(le\\|ge\\) \\(-?[0-9]+\\)$" in
  if not (Str.string_match pattern text 0) then failwith ("not an inequality: " ^ text);
  let group n = match Str.matched_group n text with found -> Some found | exception Not_found -> None in
  let x_term = group 1 and before_x = group 2 and plus = group 3 and y_term = group 4 and before_y = group 5 in
  let relation = group 6 and bound = group 7 in
  if x_term = None && y_term = None then failwith ("an inequality with nothing on its left: " ^ text);
  if (plus <> None) <> (x_term <> None && y_term <> None) then failwith ("not an inequality: " ^ text);
  let coefficient term before =
    match (term, before) with None, _ -> 0 | Some _, None -> 1 | Some _, Some digits -> before_letter digits
  in
  match (relation, bound) with
  | Some relation, Some bound ->
      { on_x = coefficient x_term before_x; on_y = coefficient y_term before_y; at_most = relation = "le";
        bound = integer bound }
  | _ -> failwith ("not an inequality: " ^ text)

let half_plane i =
  if i.at_most then { a = i.on_x; b = i.on_y; c = i.bound } else { a = -i.on_x; b = -i.on_y; c = -i.bound }

(* The left side of a constraint, as it is printed. *)
let left_text i =
  let term n letter = if n = 1 then letter else string_of_int n ^ letter in
  if i.on_y = 0 then term i.on_x "x" else if i.on_x = 0 then term i.on_y "y" else term i.on_x "x" ^ " + " ^ term i.on_y "y"

(* A point with whole coordinates, "(3, 2)". *)
let whole_point text =
  match fields 2 "(\\(-?[0-9]+\\), \\(-?[0-9]+\\))" text with
  | [ x; y ] -> (integer x, integer y)
  | _ -> failwith ("not a point: " ^ text)

(* What was generated besides the kinds: each choice the grammar offers. *)
let noted : (string, string list) Hashtbl.t = Hashtbl.create 32

let note topic choice =
  let so_far = Option.value ~default:[] (Hashtbl.find_opt noted topic) in
  if not (List.mem choice so_far) then Hashtbl.replace noted topic (choice :: so_far)

let note_number topic n = note topic (string_of_int n)

let objective_of before_x before_y =
  let p = before_letter before_x and q = before_letter before_y in
  if p < 1 || q < 1 then failwith "the objective does not have positive coefficients";
  note_number "objective: before x" p;
  note_number "objective: before y" q;
  (p, q)

(* ---- The form given by its corners ------------------------------------ *)

let corners_sentence =
  words "The feasible region of a linear programming problem is the quadrilateral with the corners " ^ "\\([^.]*\\)"
  ^ words ". Find the greatest value of [`P = " ^ an_objective ^ words "`] over the region."

(* The cross products of consecutive edges, all round the polygon. *)
let turns points =
  let count = List.length points in
  let at n = List.nth points (n mod count) in
  List.init count (fun n ->
      let ax, ay = at n and bx, by = at (n + 1) and cx, cy = at (n + 2) in
      ((bx - ax) * (cy - by)) - ((by - ay) * (cx - bx)))

(* The half-plane to the left of the edge from one point to the next. *)
let left_of (ax, ay) (bx, by) =
  let a = by - ay and b = ax - bx in
  { a; b; c = (a * ax) + (b * ay) }

let examine_corners prompt =
  match fields 3 corners_sentence prompt with
  | [ listing; before_x; before_y ] -> (
      let objective = objective_of before_x before_y in
      match List.map whole_point (listed listing) with
      | [ (0, 0); (across, 0); (x, y); (0, up) ] as points ->
          if across < 1 || up < 1 || x < 1 || y < 1 then failwith "the corners do not go round a region of the first quadrant";
          (* all the turns are to the left: a convex quadrilateral, with no
             three corners on one line *)
          if not (List.for_all (fun turn -> turn > 0) (turns points)) then
            failwith "the four points are not the corners of a convex quadrilateral in this order";
          let edges =
            List.mapi (fun n point -> left_of point (List.nth points ((n + 1) mod List.length points))) points
          in
          let found = solve ~greatest:true objective edges in
          let printed = List.sort_uniq compare (List.map (fun (px, py) -> (whole px, whole py)) points) in
          if found.corners <> printed then failwith "the region inside the four edges does not have the four points as its corners";
          if found.out <> [] then failwith "the region is not cut off on every side";
          if found.best <> best_of ~greatest:true (List.map (value objective) printed) then
            failwith "the greatest value over the region is not the greatest at the four printed corners";
          note_number "corners: middle x" x;
          note_number "corners: middle y" y;
          note "corners: on the axes, beyond the middle by" (Printf.sprintf "%d, %d" (across - x) (up - y));
          Number found.best
      | _ -> failwith "the corners are not the origin, a point of the x-axis, a point and a point of the y-axis")
  | _ -> failwith "three fields were expected"

(* ---- The forms given by their constraints ------------------------------ *)

let programme_sentence =
  "\\(Maximise\\|Minimise\\) " ^ words "[`" ^ "\\([A-Z]\\)" ^ words " = " ^ an_objective ^ words "`] subject to "
  ^ "\\([^.]*\\)" ^ words ". " ^ "\\(.*\\)"

type asked = A_value | A_point

(* What a kind is said to be: whether the greatest value is wanted, whether a
   value or a point is asked for, and how its constraints other than the axes
   look (x coefficient, y coefficient), all with <= for a greatest value and
   >= for a least one. *)
let is_slanted (on_x, on_y) = on_x > 0 && on_y > 0
let two_slanted = function [ first; second ] -> is_slanted first && is_slanted second | _ -> false
let plain_pair = [ (1, 2); (2, 1) ]

let forms =
  [ ("box_and_sum", (true, A_value, fun sides -> sides = [ (1, 1); (1, 0); (0, 1) ]));
    ("two_lines", (true, A_value, fun sides -> sides = plain_pair));
    ("general_lines", (true, A_value, fun sides -> two_slanted sides && sides <> plain_pair));
    ("optimal_point", (true, A_point, two_slanted));
    ("minimise", (false, A_value, two_slanted)) ]

(* The forms that have a line for the mistake. *)
let open_to_the_mistake = [ "box_and_sum"; "two_lines"; "general_lines"; "optimal_point"; "minimise" ]

let examine_programme k prompt =
  match fields 6 programme_sentence prompt with
  | [ verb; name; before_x; before_y; listing; question ] ->
      let greatest = verb = "Maximise" in
      if name <> if greatest then "P" else "C" then failwith ("the objective is called " ^ name);
      let extreme = if greatest then "greatest" else "least" in
      let asked =
        if question = Printf.sprintf "Find the %s value of [`%s`]." extreme name then A_value
        else if
          question
          = Printf.sprintf "At which point of the region is [`%s`] %s? Enter the point as [`(x, y)`]." name extreme
        then A_point
        else failwith "the question asked is not worded as expected"
      in
      let objective = objective_of before_x before_y in
      let printed = List.map inequality (listed listing) in
      (* the two axes come last, and before them the constraints of the form *)
      let rec split = function
        | [ x_axis; y_axis ] ->
            if x_axis <> { on_x = 1; on_y = 0; at_most = false; bound = 0 } then failwith "x >= 0 is not where it is expected";
            if y_axis <> { on_x = 0; on_y = 1; at_most = false; bound = 0 } then failwith "y >= 0 is not where it is expected";
            []
        | first :: rest -> first :: split rest
        | [] -> failwith "the two axes are not among the constraints"
      in
      let own = split printed in
      let wants_greatest, wants, looks =
        match List.assoc_opt k forms with Some form -> form | None -> failwith ("unknown kind " ^ k)
      in
      if greatest <> wants_greatest then failwith ("this kind does not ask for the " ^ extreme ^ " value");
      if asked <> wants then failwith "this kind does not ask for that";
      if List.exists (fun i -> i.at_most <> greatest) own then failwith "a constraint looks the wrong way";
      if not (looks (List.map (fun i -> (i.on_x, i.on_y)) own)) then failwith "the constraints are not those of this kind";
      let region = List.map half_plane printed in
      let found = solve ~greatest objective region in
      if greatest && found.out <> [] then failwith "the region is not cut off on every side";
      if (not greatest) && found.out = [] then failwith "the region is cut off on every side";
      (* a least value over a region that goes on for ever: positive
         coefficients in the first quadrant, so no value is below 0 and the
         least corner value is the least *)
      if (not greatest) && not (fst objective > 0 && snd objective > 0) then failwith "the least value may not exist";
      (match own with
       | [ first; second ] when is_slanted (first.on_x, first.on_y) && is_slanted (second.on_x, second.on_y) -> (
           (* the two printed lines cross at a point with whole positive
              coordinates, a corner of the region, and meet the axes on
              either side of it *)
           match crossing (half_plane first) (half_plane second) with
           | None -> failwith "the two lines are parallel"
           | Some ((x, y) as meeting) ->
               if x.bottom <> 1 || y.bottom <> 1 || x.top < 1 || y.top < 1 then
                 failwith ("the two lines cross at " ^ show_point meeting ^ ", not at whole positive coordinates");
               if not (List.mem meeting found.corners) then
                 failwith ("the two lines cross at " ^ show_point meeting ^ ", which is not a corner of the region");
               let origin = (zero, zero) in
               if List.mem origin found.corners <> greatest then failwith "the origin is a corner of the wrong kind of region";
               let others = List.filter (fun corner -> corner <> origin && corner <> meeting) found.corners in
               let on_axis part = List.filter (fun corner -> part corner = zero) others in
               (match (on_axis snd, on_axis fst) with
                | [ on_x_axis ], [ on_y_axis ] when List.length others = 2 ->
                    let line_of corner =
                      List.filter (fun i -> on_line (half_plane i) corner) [ first; second ]
                    in
                    (match (line_of on_x_axis, line_of on_y_axis) with
                     | [ one ], [ other ] when one <> other -> ()
                     | _ -> failwith "the corners on the axes are not one on each of the two lines");
                    (* a point may be asked for where the two corners on the
                       axes give the same value: the crossing then gives more *)
                    if asked = A_point then
                      note (k ^ ": the corners on the axes")
                        (if value objective on_x_axis = value objective on_y_axis then "give the same value"
                         else "give different values")
                | _ -> failwith "the region does not have one corner on each axis besides the crossing");
               note (k ^ ": lines") (left_text first ^ ", " ^ left_text second);
               note (k ^ ": crossing") (Printf.sprintf "%d, %d" x.top y.top))
       | [ sum; across; up ] ->
           (* with equal coefficients the greatest value is the coefficient
              times the sum, whatever the box is *)
           if fst objective = snd objective then
             failwith "the objective has equal coefficients: the answer does not depend on the bounds of x and y";
           note_number (k ^ ": x + y at most") sum.bound;
           note_number (k ^ ": x at most") across.bound;
           note_number (k ^ ": y at most") up.bound
       | _ -> failwith "neither two slanted lines nor a box and a sum");
      let want =
        match asked with
        | A_value -> Number found.best
        | A_point -> (
            match found.at with
            | [ ((x, y) as only) ] ->
                if x.bottom <> 1 || y.bottom <> 1 then
                  failwith ("the point to enter, " ^ show_point only ^ ", does not have whole coordinates");
                Place only
            | several ->
                failwith
                  (Printf.sprintf "%d corners give the %s value %s: %s" (List.length several) extreme (print found.best)
                     (String.concat ", " (List.map show_point several))))
      in
      let slips =
        if not (List.mem k open_to_the_mistake) then []
        else
          match asked with
          | A_value -> [ ("intercepts_outside", Number (intercepts_outside ~greatest objective region found.corners)) ]
          | A_point -> (
              (* no point outside the region is better: the right point is given *)
              match point_outside ~greatest objective region found.best with
              | Some (((_, y) as point), shared) ->
                  note (k ^ ": the mistaken point")
                    (if shared then "on the x-axis, a point on the y-axis having the same value"
                     else if y = zero then "on the x-axis"
                     else "on the y-axis");
                  [ ("intercepts_outside", Place point) ]
              | None -> [ ("intercepts_outside", want) ])
      in
      (want, slips)
  | _ -> failwith "six fields were expected"

(* The right answer of a question and the answer of each mistake its form is
   open to, found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  match kind q with
  | "corners" -> (examine_corners q.Rhema_engine.prompt, [])
  | k -> examine_programme k q.Rhema_engine.prompt

let questions_at_each_budget = 2000

let () =
  let base = load_file "linear_programming.rhm" in
  let prices =
    [ ("corners", 1); ("box_and_sum", 2); ("two_lines", 2); ("general_lines", 3); ("optimal_point", 3); ("minimise", 3) ]
  in
  let seen = Hashtbl.create 8 and listed_on = Hashtbl.create 2 and generated = Hashtbl.create 4 in
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
              | None -> fail (Printf.sprintf "%s: the answer is neither a number nor a point of the plane, for %S" k p)
              | Some got -> (
                  match expected q with
                  | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
                  | want, slips ->
                      if got <> want then
                        fail (Printf.sprintf "%s: answer %s, worked out %s, for %S" k (show got) (show want) p);
                      (* a mistake is listed where it gives another answer, and
                         only there *)
                      let wrong = List.filter (fun (_, slip) -> slip <> want) slips in
                      let made = q.Rhema_engine.mistakes in
                      let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) made in
                      if names <> List.map fst wrong then
                        fail
                          (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k (String.concat ", " names)
                             (String.concat ", " (List.map fst wrong))
                             p);
                      List.iter
                        (fun (m : Rhema_engine.mistaken) ->
                          Hashtbl.replace listed_on (m.mistake, k) ();
                          (match Str.search_forward (Str.regexp_string "outside the region") m.description 0 with
                           | _ -> ()
                           | exception Not_found ->
                               fail
                                 (Printf.sprintf "%s is not described as trying points outside the region: %S" m.mistake
                                    m.description));
                          match m.mistaken_answers with
                          | Some [ value ] -> (
                              match read value with
                              | Some given ->
                                  if given = got then
                                    fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p);
                                  (match List.assoc_opt m.mistake slips with
                                   | Some slip when slip <> given ->
                                       fail
                                         (Printf.sprintf "%s: %s gives %s, worked out %s, for %S" k m.mistake (show given)
                                            (show slip) p)
                                   | _ -> ())
                              | None ->
                                  fail (Printf.sprintf "%s: %s gives neither a number nor a point, for %S" k m.mistake p))
                          | _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                        made)))
    done
  done;
  for cost = 1 to 3 do
    let count = Option.value ~default:0 (Hashtbl.find_opt generated cost) in
    if count < 500 then fail (Printf.sprintf "only %d questions at cost %d" count cost)
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k () -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  List.iter
    (fun k -> if not (Hashtbl.mem listed_on ("intercepts_outside", k)) then fail ("intercepts_outside is never listed on " ^ k))
    open_to_the_mistake;
  (* Every choice the grammar offers is taken at least once, and no other. *)
  let range first last = List.init (last - first + 1) (fun n -> string_of_int (first + n)) in
  let both firsts seconds = List.concat_map (fun first -> List.map (fun second -> first ^ ", " ^ second) seconds) firsts in
  let flat = [ "x + 2y"; "x + 3y"; "2x + 3y" ] and steep = [ "2x + y"; "3x + y"; "3x + 2y" ] in
  let every_pair = both flat steep in
  let plain = "x + 2y, 2x + y" in
  let choices =
    [ ("objective: before x", range 1 6); ("objective: before y", range 1 6); ("corners: middle x", range 1 6);
      ("corners: middle y", range 1 6); ("corners: on the axes, beyond the middle by", both (range 1 4) (range 1 4));
      ("box_and_sum: x + y at most", range 3 12);
      ("box_and_sum: x at most", range 2 7); ("box_and_sum: y at most", range 2 7); ("two_lines: lines", [ plain ]);
      ("general_lines: lines", List.filter (fun pair -> pair <> plain) every_pair);
      ("optimal_point: lines", every_pair); ("minimise: lines", [ plain ]);
      ("optimal_point: the corners on the axes", [ "give the same value"; "give different values" ]);
      ( "optimal_point: the mistaken point",
        [ "on the x-axis"; "on the y-axis"; "on the x-axis, a point on the y-axis having the same value" ] ) ]
    @ List.map
        (fun k -> (k ^ ": crossing", both (range 1 6) (range 1 6)))
        [ "two_lines"; "general_lines"; "optimal_point"; "minimise" ]
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
  if !failures = 0 then print_endline "Rhema linear programming tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d linear programming test(s) failed." !failures);
    exit 1
  end
