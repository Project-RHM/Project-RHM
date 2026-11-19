(* Independent checks for differential_equation.rhm. The equation and the
   initial values are read back from the printed question; the answer is
   evaluated as a function and differentiated numerically. It must satisfy
   the equation at several points and take the stated initial values. A
   linear equation of this kind with these initial values has one solution,
   so a function that passes is the solution. *)

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

(* The groups of the first match, read at once. *)
let groups re text =
  ignore (Str.search_forward (Str.regexp re) text 0);
  let found = Array.init 7 (fun n -> try Some (Str.matched_group n text) with Not_found | Invalid_argument _ -> None) in
  fun n -> found.(n)

let required g n = match g n with Some s -> s | None -> raise Not_found

(* A number written in front of a symbol: "" is 1, "-" is -1. *)
let coefficient = function "" -> 1. | "-" -> -1. | s -> float_of_string s

(* A signed term: the sign group and the digits group (absent digits are 1). *)
let signed g sign digits =
  match g sign with
  | None -> 0.
  | Some s -> (if s = "-" then -1. else 1.) *. (match g digits with None | Some "" -> 1. | Some d -> float_of_string d)

(* The answer as a function of x. *)
let solution (q : Rhema_engine.question) =
  let formula =
    match q.Rhema_engine.answer with
    | Rhema_engine.Formula f -> f
    | Rhema_engine.Polynomial p -> Rhema_polynomial.to_formula p
    | other -> failwith ("not a function: " ^ Rhema_engine.describe_value other)
  in
  fun at -> Rhema_formula.evaluate ~variable:"x" ~at formula

let first f x =
  let h = 1e-4 in
  (f (x +. h) -. f (x -. h)) /. (2. *. h)

let second f x =
  let h = 1e-3 in
  (f (x +. h) -. (2. *. f x) +. f (x -. h)) /. (h *. h)

(* The equation as (y, y', y'', x) -> left side minus right side. *)
let equation (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "direct" ->
      let g = groups "\\[`y' = \\(-?[0-9]*\\)\\( \\\\cdot \\)?x\\( \\([+-]\\) \\([0-9]+\\)\\)?`\\]" p in
      let a = coefficient (required g 1) and b = signed g 4 5 in
      fun (_, y1, _, x) -> y1 -. ((a *. x) +. b)
  | "growth" ->
      let k = coefficient (required (groups "\\[`y' = \\(-?[0-9]*\\)y`\\]" p) 1) in
      fun (y, y1, _, _) -> y1 -. (k *. y)
  | "linear" ->
      let g = groups "\\[`y' \\([+-]\\) \\([0-9]*\\)y = \\(-?[0-9]+\\)`\\]" p in
      let a = signed g 1 2 and b = float_of_string (required g 3) in
      fun (y, y1, _, _) -> y1 +. (a *. y) -. b
  | "separable" ->
      let k = coefficient (required (groups "\\[`y' = \\(-?[0-9]*\\)xy`\\]" p) 1) in
      fun (y, y1, _, x) -> y1 -. (k *. x *. y)
  | "two_roots" | "repeated_root" ->
      let g = groups "\\[`y''\\( \\([+-]\\) \\([0-9]*\\)y'\\)? \\([+-]\\) \\([0-9]*\\)y = 0`\\]" p in
      let b = signed g 2 3 and c = signed g 4 5 in
      (* the roots are real, and of the kind the form says *)
      let discriminant = (b *. b) -. (4. *. c) in
      if kind q = "two_roots" && not (discriminant > 0.) then fail ("not two real roots: " ^ p);
      if kind q = "repeated_root" && discriminant <> 0. then fail ("not a repeated root: " ^ p);
      fun (y, y1, y2, _) -> y2 +. (b *. y1) +. (c *. y)
  | k -> failwith ("unknown kind " ^ k)

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt and k = kind q in
  let f = solution q and residual = equation q in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
  List.iter
    (fun x ->
      let y = f x and y1 = first f x and y2 = second f x in
      let scale = 1. +. Float.abs y +. Float.abs y1 +. Float.abs y2 in
      let r = residual (y, y1, y2, x) in
      if not (Float.abs r <= 1e-3 *. scale) then wrong (Printf.sprintf "the equation is off by %g at x = %g" r x))
    [ -0.7; -0.2; 0.; 0.3; 0.9 ];
  let start = float_of_string (required (groups "\\[`y(0) = \\(-?[0-9]+\\)`\\]" p) 1) in
  if Float.abs (f 0. -. start) > 1e-9 then wrong (Printf.sprintf "y(0) is %g" (f 0.));
  let second_order = k = "two_roots" || k = "repeated_root" in
  match groups "\\[`y'(0) = \\(-?[0-9]+\\)`\\]" p with
  | exception Not_found -> if second_order then wrong "no initial slope is given"
  | g ->
      if not second_order then wrong "an initial slope is given for a first-order equation";
      let slope = float_of_string (required g 1) in
      if Float.abs (first f 0. -. slope) > 1e-5 *. Float.max 1. (Float.abs slope) then
        wrong (Printf.sprintf "y'(0) is %g" (first f 0.))

let () =
  let base = load_file "differential_equation.rhm" in
  let prices =
    [ ("direct", 1); ("growth", 1); ("linear", 2); ("separable", 2); ("two_roots", 3); ("repeated_root", 3) ]
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
          (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) q.Rhema_engine.prompt))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema differential equation tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d differential equation test(s) failed." !failures);
    exit 1
  end
