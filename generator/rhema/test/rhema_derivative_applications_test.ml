(* Independent checks for derivative_applications.rhm. The polynomial is
   read back from the printed question and differentiated numerically. A
   slope must be that derivative; a tangent line must touch the curve with
   the curve's slope; claimed critical points must be two different zeroes
   of the derivative (a cubic has no more); an extreme value must be the
   largest or smallest value found by scanning the interval; and on the
   claimed interval the derivative must have the stated sign and the
   opposite sign just outside both ends. *)

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

let group re text n =
  ignore (Str.search_forward (Str.regexp re) text 0);
  Str.matched_group n text

(* A polynomial in x as polynomial_latex writes it, as a function. *)
let polynomial text =
  let terms = Str.full_split (Str.regexp " [+-] ") (" + " ^ String.trim text) in
  let sign = ref 1. and out = ref [] in
  List.iter
    (function
      | Str.Delim d -> sign := if String.trim d = "-" then -1. else 1.
      | Str.Text t ->
          let t = String.trim t in
          (* a leading minus belongs to the first term *)
          let t =
            if String.length t > 0 && t.[0] = '-' then (
              sign := -. !sign;
              String.sub t 1 (String.length t - 1))
            else t
          in
          let coefficient part = if part = "" then 1. else float_of_string part in
          if Str.string_match (Str.regexp "\\([0-9]*\\)\\( \\\\cdot \\)?x\\^{\\([0-9]+\\)}$") t 0 then
            out := (int_of_string (Str.matched_group 3 t), !sign *. coefficient (Str.matched_group 1 t)) :: !out
          else if Str.string_match (Str.regexp "\\([0-9]*\\)\\( \\\\cdot \\)?x$") t 0 then
            out := (1, !sign *. coefficient (Str.matched_group 1 t)) :: !out
          else if t <> "" then out := (0, !sign *. float_of_string t) :: !out)
    terms;
  fun x -> List.fold_left (fun total (d, c) -> total +. (c *. (x ** float d))) 0. !out

(* Central difference; its error for a cubic is the third derivative times
   h^2 / 6, far below the tolerance used here. *)
let slope f x =
  let h = 1e-4 in
  (f (x +. h) -. f (x -. h)) /. (2. *. h)

let close a b = Float.abs (a -. b) <= 1e-5 *. Float.max 1. (Float.abs b)

let number (q : Rhema_engine.question) =
  match q.Rhema_engine.answer with
  | Rhema_engine.Num n -> Rhema_number.to_float n
  | other -> fail ("not a number: " ^ Rhema_engine.describe_value other); nan

(* The curve is the first formula of every prompt, after "y = " or "f(x) = ". *)
let curve p = polynomial (group "\\(y\\|f(x)\\) = \\([^`]*\\)`\\]" p 2)

let point p = float_of_string (group "at \\[`x = \\(-?[0-9]+\\)`\\]" p 1)

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let f = curve p in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" (kind q) what q.Rhema_engine.answer_text p) in
  match kind q with
  | "slope" -> if not (close (number q) (slope f (point p))) then wrong "not the slope"
  | "horizontal" ->
      if Float.abs (slope f (number q)) > 1e-6 then wrong "the tangent is not horizontal there";
      if Float.abs (slope f (number q +. 1.)) < 1e-6 then wrong "the curve is flat everywhere"
  | "tangent_line" -> (
      match q.Rhema_engine.answer with
      | Rhema_engine.Polynomial line ->
          let at x = Rhema_number.to_float (Rhema_polynomial.evaluate line (Rhema_number.of_int x)) in
          let x0 = int_of_float (point p) in
          if Rhema_polynomial.degree line <> Some 1 then wrong "not a line with a slope";
          if not (close (at x0) (f (float x0))) then wrong "the line misses the curve";
          if not (close (at (x0 + 1) -. at x0) (slope f (float x0))) then wrong "the line has the wrong slope"
      | _ -> wrong "not a polynomial")
  | "critical_points" -> (
      match q.Rhema_engine.answer with
      | Rhema_engine.Set (Rhema_set.Finite [ a; b ]) ->
          let a = Rhema_number.to_float a and b = Rhema_number.to_float b in
          if a = b then wrong "one point given twice";
          if Float.abs (slope f a) > 1e-6 || Float.abs (slope f b) > 1e-6 then wrong "not critical points";
          (* really a cubic, so there are no more than two *)
          if Float.abs (f 2. -. (3. *. f 1.) +. (3. *. f 0.) -. f (-1.)) < 1e-9 then wrong "not a cubic"
      | _ -> wrong "not a set of two points")
  | "extreme" ->
      let re = "\\[`\\(-?[0-9]+\\) \\\\le x \\\\le \\(-?[0-9]+\\)`\\]" in
      let lo = int_of_string (group re p 1) and hi = int_of_string (group re p 2) in
      if not (lo < hi) then wrong "an empty interval";
      let maximum = Str.string_match (Str.regexp ".*absolute maximum") p 0 in
      let best = ref (f (float lo)) in
      for i = 0 to (hi - lo) * 1000 do
        let v = f (float lo +. (float i /. 1000.)) in
        if (maximum && v > !best) || ((not maximum) && v < !best) then best := v
      done;
      if not (close (number q) !best) then wrong (Printf.sprintf "scanning gives %g" !best)
  | "monotonic" -> (
      match q.Rhema_engine.answer with
      | Rhema_engine.Set (Rhema_set.Interval (a, b, Rhema_set.Open, Rhema_set.Open)) ->
          let a = Rhema_number.to_float a and b = Rhema_number.to_float b in
          let sign = if Str.string_match (Str.regexp ".*is decreasing") p 0 then -1. else 1. in
          if not (a < b) then wrong "an empty interval";
          List.iter
            (fun t -> if sign *. slope f (a +. (t *. (b -. a))) <= 0. then wrong "the wrong direction inside")
            [ 0.01; 0.25; 0.5; 0.75; 0.99 ];
          if sign *. slope f (a -. 0.01) >= 0. || sign *. slope f (b +. 0.01) >= 0. then
            wrong "the interval could be longer"
      | _ -> wrong "not an open interval")
  | k -> fail ("unknown kind " ^ k)

let () =
  let base = load_file "derivative_applications.rhm" in
  let prices =
    [ ("slope", 1); ("horizontal", 1); ("tangent_line", 2); ("critical_points", 2); ("extreme", 3); ("monotonic", 3) ]
  in
  let contexts = [ ("critical_points", "Interval"); ("monotonic", "Interval") ] in
  let seen = Hashtbl.create 8 and winners = Hashtbl.create 8 in
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
          (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) q.Rhema_engine.prompt));
          (* an extreme value is sometimes at an end and sometimes inside *)
          if k = "extreme" then begin
            let p = q.Rhema_engine.prompt in
            let f = curve p in
            let re = "\\[`\\(-?[0-9]+\\) \\\\le x \\\\le \\(-?[0-9]+\\)`\\]" in
            let lo = float_of_string (group re p 1) and hi = float_of_string (group re p 2) in
            let v = number q in
            Hashtbl.replace winners (if close v (f lo) || close v (f hi) then "end" else "inside") ()
          end
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  List.iter
    (fun w -> if not (Hashtbl.mem winners w) then fail ("an extreme value was never at: " ^ w))
    [ "end"; "inside" ];
  if !failures = 0 then print_endline "Rhema derivative applications tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d derivative applications test(s) failed." !failures);
    exit 1
  end
