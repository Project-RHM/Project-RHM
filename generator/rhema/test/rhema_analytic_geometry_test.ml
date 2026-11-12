(* Independent checks for analytic_geometry.rhm. The points, lines and the
   circle are read back from the printed question and the answer is tested
   against what it should be by its definition: a midpoint doubled is the
   sum of the ends, a line through two points passes through both, a
   perpendicular passes through its point and its slope times the other
   slope is -1, a centre and radius put every point of the circle on the
   printed equation, and an intersection satisfies both lines, which are not
   parallel. *)

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

(* Every match of a regular expression with two groups, as pairs. *)
let pairs re text =
  let re = Str.regexp re in
  let rec go start found =
    match Str.search_forward re text start with
    | exception Not_found -> List.rev found
    | _ ->
        let pair = (Str.matched_group 1 text, Str.matched_group 2 text) and next = Str.match_end () in
        go next (pair :: found)
  in
  go 0 []

(* The points written \left(a, b\right), in order. *)
let points p =
  pairs "\\\\left(\\(-?[0-9]+\\), \\(-?[0-9]+\\)\\\\right)" p
  |> List.map (fun (x, y) -> (float_of_string x, float_of_string y))

(* A sum of terms in x, y, x^2, y^2 and constants, as coefficients by name:
   "x^{2} + y^{2} - 16 \cdot x - 4 \cdot y - 13", "-5 \cdot x + y". *)
let terms text =
  let out = Hashtbl.create 5 in
  let sign = ref 1. in
  List.iter
    (function
      | Str.Delim d -> sign := if String.trim d = "-" then -1. else 1.
      | Str.Text t ->
          let t = String.trim t in
          let t =
            if String.length t > 0 && t.[0] = '-' then (
              sign := -. !sign;
              String.sub t 1 (String.length t - 1))
            else t
          in
          if t <> "" then begin
            if not (Str.string_match (Str.regexp "^\\([0-9]*\\)\\( \\\\cdot \\)?\\([xy]\\(\\^{2}\\)?\\)?$") t 0) then
              failwith ("not a term: " ^ t);
            let coefficient = match Str.matched_group 1 t with "" -> 1. | s -> float_of_string s in
            let name = try Str.matched_group 3 t with Not_found -> "" in
            Hashtbl.replace out name ((try Hashtbl.find out name with Not_found -> 0.) +. (!sign *. coefficient))
          end)
    (Str.full_split (Str.regexp " [+-] ") (" + " ^ String.trim text));
  fun name -> try Hashtbl.find out name with Not_found -> 0.

(* The lines written a x + b y = c, in order, as (a, b, c). *)
let lines p =
  pairs "\\[`\\([^`=]*[xy]\\) = \\(-?[0-9]+\\)`\\]" p
  |> List.map (fun (left, right) ->
         let t = terms left in
         (t "x", t "y", float_of_string right))

let number_of_text text =
  match String.split_on_char '/' text with
  | [ n ] -> float_of_string n
  | [ n; d ] -> float_of_string n /. float_of_string d
  | _ -> failwith ("not a number: " ^ text)

(* A point answer, "(3,-2)" or "(7/2,-1)". *)
let point_answer (q : Rhema_engine.question) =
  match q.Rhema_engine.answer with
  | Rhema_engine.Text t when Str.string_match (Str.regexp "^(\\([^,()]+\\),\\([^,()]+\\))$") t 0 ->
      let x = Str.matched_group 1 t and y = Str.matched_group 2 t in
      (number_of_text x, number_of_text y)
  | other -> failwith ("not a point: " ^ Rhema_engine.describe_value other)

let number_answer (q : Rhema_engine.question) =
  match q.Rhema_engine.answer with
  | Rhema_engine.Num n -> Rhema_number.to_float n
  | other -> failwith ("not a number: " ^ Rhema_engine.describe_value other)

(* A line answer m x + b, as (m, b). *)
let line_answer (q : Rhema_engine.question) =
  match q.Rhema_engine.answer with
  | Rhema_engine.Polynomial line when Rhema_polynomial.degree line = Some 1 ->
      let at x = Rhema_number.to_float (Rhema_polynomial.evaluate line (Rhema_number.of_int x)) in
      (at 1 -. at 0, at 0)
  | other -> failwith ("not a line with a slope: " ^ Rhema_engine.describe_value other)

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" (kind q) what q.Rhema_engine.answer_text p) in
  let two () = match points p with [ a; b ] -> (a, b) | _ -> failwith "expected two points" in
  match kind q with
  | "distance" ->
      let (x1, y1), (x2, y2) = two () in
      if not (close (number_answer q) (Float.hypot (x2 -. x1) (y2 -. y1))) then wrong "not the distance"
  | "midpoint" ->
      let (x1, y1), (x2, y2) = two () and mx, my = point_answer q in
      if not (close (2. *. mx) (x1 +. x2) && close (2. *. my) (y1 +. y2)) then wrong "not the midpoint"
  | "slope" ->
      let (x1, y1), (x2, y2) = two () in
      if x1 = x2 then wrong "a vertical line";
      if not (close (number_answer q *. (x2 -. x1)) (y2 -. y1)) then wrong "not the slope"
  | "line_two_points" ->
      let (x1, y1), (x2, y2) = two () and m, b = line_answer q in
      if (x1, y1) = (x2, y2) then wrong "one point given twice";
      if not (close ((m *. x1) +. b) y1 && close ((m *. x2) +. b) y2) then wrong "the line misses a point"
  | "perpendicular" -> (
      let m, b = line_answer q in
      match (points p, lines p) with
      | [ (x0, y0) ], [ (a, bb, _) ] ->
          if not (close ((m *. x0) +. b) y0) then wrong "the line misses the point";
          (* the given line has slope -a/b *)
          if not (close (m *. (-.a /. bb)) (-1.)) then wrong "not perpendicular"
      | _ -> failwith "expected one point and one line")
  | "circle_centre" | "circle_radius" ->
      ignore (Str.search_forward (Str.regexp "\\[`\\(x\\^{2}[^`]*\\) = 0`\\]") p 0);
      let t = terms (Str.matched_group 1 p) in
      if t "x^{2}" <> 1. || t "y^{2}" <> 1. then wrong "not a circle in standard form";
      let on_circle x y = (x *. x) +. (y *. y) +. (t "x" *. x) +. (t "y" *. y) +. t "" in
      (* the other of centre and radius, from the printed coefficients *)
      let h, k, r =
        if kind q = "circle_centre" then
          let h, k = point_answer q in
          (h, k, sqrt ((h *. h) +. (k *. k) -. t ""))
        else (-.t "x" /. 2., -.t "y" /. 2., number_answer q)
      in
      if not (r > 0.) then wrong "no radius";
      List.iter
        (fun angle ->
          let v = on_circle (h +. (r *. cos angle)) (k +. (r *. sin angle)) in
          if Float.abs v > 1e-7 then wrong (Printf.sprintf "a point of the circle is off the equation by %g" v))
        [ 0.; 1.; 2.5; 4.; 5.5 ];
      (* and the centre is where the equation is smallest, -r^2 *)
      if not (close (on_circle h k) (-.r *. r)) then wrong "not the centre"
  | "intersection" -> (
      let x, y = point_answer q in
      match lines p with
      | [ (a1, b1, c1); (a2, b2, c2) ] ->
          if (a1 *. b2) -. (a2 *. b1) = 0. then wrong "the lines are parallel";
          if not (close ((a1 *. x) +. (b1 *. y)) c1 && close ((a2 *. x) +. (b2 *. y)) c2) then wrong "not on both lines"
      | _ -> failwith "expected two lines")
  | k -> fail ("unknown kind " ^ k)

let () =
  let base = load_file "analytic_geometry.rhm" in
  let prices =
    [ ("distance", 1); ("midpoint", 1); ("slope", 1); ("line_two_points", 2); ("perpendicular", 2);
      ("circle_centre", 3); ("circle_radius", 3); ("intersection", 3) ]
  in
  let contexts = [ ("midpoint", "Point"); ("circle_centre", "Point"); ("intersection", "Point") ] in
  let seen = Hashtbl.create 8 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          let k = kind q in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          let context = Option.value (List.assoc_opt k contexts) ~default:"Numeric" in
          if q.Rhema_engine.context <> context then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
          (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) q.Rhema_engine.prompt))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema analytic geometry tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d analytic geometry test(s) failed." !failures);
    exit 1
  end
