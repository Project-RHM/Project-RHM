(* Independent checks for definite_integral.rhm. The integrand, the bounds
   and the curves are read back from the printed question and the integral
   is computed numerically (Simpson's rule); for an area the crossing points
   are found from the printed coefficients and the absolute difference is
   integrated between them. The result must agree with the exact answer. *)

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

let answer (q : Rhema_engine.question) =
  match q.Rhema_engine.answer with
  | Rhema_engine.Num n -> Rhema_number.to_float n
  | other -> fail ("not a number: " ^ Rhema_engine.describe_value other); nan

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

let simpson f a b =
  let n = 2000 in
  let h = (b -. a) /. float n in
  let total = ref (f a +. f b) in
  for i = 1 to n - 1 do
    total := !total +. ((if i mod 2 = 1 then 4. else 2.) *. f (a +. (float i *. h)))
  done;
  !total *. h /. 3.

let bounds p =
  let re = "\\\\int_{\\(-?[0-9]+\\)}\\^{\\(-?[0-9]+\\)}" in
  (float_of_string (group re p 1), float_of_string (group re p 2))

(* The two real roots of a quadratic given as a function, from three values. *)
let crossings d =
  let c = d 0. in
  let a = ((d 1. +. d (-1.)) /. 2.) -. c and b = (d 1. -. d (-1.)) /. 2. in
  let disc = (b *. b) -. (4. *. a *. c) in
  if a = 0. || disc <= 0. then failwith "the curves do not cross twice";
  let r1 = (-.b -. sqrt disc) /. (2. *. a) and r2 = (-.b +. sqrt disc) /. (2. *. a) in
  (Float.min r1 r2, Float.max r1 r2)

let whole x = Float.abs (x -. Float.round x) < 1e-9

let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "power" ->
      let a, b = bounds p in
      simpson (polynomial (group "} \\(.*\\) \\\\, dx`" p 1)) a b
  | "quadratic" ->
      let a, b = bounds p in
      if not (a < b) then fail ("the bounds are not in order: " ^ p);
      simpson (polynomial (group "\\\\left(\\(.*\\)\\\\right) dx`" p 1)) a b
  | "product" ->
      let a, b = bounds p in
      let re = "\\\\left(\\(.*\\)\\\\right)\\\\left(\\(.*\\)\\\\right) dx`" in
      let f = polynomial (group re p 1) and g = polynomial (group re p 2) in
      simpson (fun x -> f x *. g x) a b
  | "area_axis" ->
      let f = polynomial (group "y = \\(.*\\)`\\] and the \\[`x`\\]-axis" p 1) in
      let r1, r2 = crossings f in
      if not (whole r1 && whole r2) then fail ("the parabola does not cross the axis at whole numbers: " ^ p);
      simpson (fun x -> Float.abs (f x)) r1 r2
  | "between_curves" ->
      let re = "y = \\(.*\\)`\\] and the line \\[`y = \\(.*\\)`\\]" in
      let f = polynomial (group re p 1) and g = polynomial (group re p 2) in
      let d x = f x -. g x in
      let r1, r2 = crossings d in
      if not (whole r1 && whole r2) then fail ("the curves do not meet at whole numbers: " ^ p);
      simpson (fun x -> Float.abs (d x)) r1 r2
  | "substitution" ->
      let a, b = bounds p in
      let re = "} \\(.*\\) \\\\left(\\(.*\\)\\\\right)\\^{\\([0-9]+\\)} dx`" in
      let outer = polynomial (group re p 1) and inner = polynomial (group re p 2) in
      let n = float_of_string (group re p 3) in
      simpson (fun x -> outer x *. (inner x ** n)) a b
  | k -> fail ("unknown kind " ^ k); nan

let () =
  let base = load_file "definite_integral.rhm" in
  let prices =
    [ ("power", 1); ("quadratic", 1); ("product", 2); ("area_axis", 2); ("between_curves", 3); ("substitution", 3) ]
  in
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
          let got = answer q and want = (try expected q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) q.Rhema_engine.prompt); nan) in
          if (k = "area_axis" || k = "between_curves") && not (got > 0.) then
            fail (Printf.sprintf "%s: an area of %g for %S" k got q.Rhema_engine.prompt);
          if not (Float.abs (got -. want) <= 1e-6 *. Float.max 1. (Float.abs got)) then
            fail (Printf.sprintf "%s: answer %g, integrated %g, for %S" k got want q.Rhema_engine.prompt)
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema definite integral tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d definite integral test(s) failed." !failures);
    exit 1
  end
