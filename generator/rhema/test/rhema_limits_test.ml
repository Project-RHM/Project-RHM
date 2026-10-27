(* Independent checks for limits.rhm. The function is read back from the
   printed question and evaluated numerically next to the point (on both
   sides) or far out (for x -> infinity); the values must approach the exact
   answer. A removable discontinuity is also checked to be one: the printed
   denominator must vanish at the point. *)

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

(* A polynomial in x as polynomial_latex writes it, as (degree, coefficient). *)
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

let fraction_parts p = (group "\\\\frac{\\(.*\\)}{\\(.*\\)}`" p 1, group "\\\\frac{\\(.*\\)}{\\(.*\\)}`" p 2)

let coefficient_before_x re p =
  let s = group re p 1 in
  if s = "" then 1. else float_of_string s

let near f a = (f (a -. 1e-6) +. f (a +. 1e-6)) /. 2.

let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "removable" | "removable_both" ->
      let a = float_of_string (group "x \\\\to \\(-?[0-9]+\\)}" p 1) in
      let top, bottom = fraction_parts p in
      let n = polynomial top and d = polynomial bottom in
      if Float.abs (d a) > 1e-9 then fail ("the denominator does not vanish at the point: " ^ p);
      if Float.abs (n a) > 1e-9 then fail ("the numerator does not vanish at the point: " ^ p);
      near (fun x -> n x /. d x) a
  | "at_infinity" ->
      let top, bottom = fraction_parts p in
      let n = polynomial top and d = polynomial bottom in
      n 1e7 /. d 1e7
  | "sin_linear" ->
      let k = coefficient_before_x "\\\\sin(\\([0-9]*\\)x)" p and m = coefficient_before_x "}{\\([0-9]*\\)x}" p in
      near (fun x -> sin (k *. x) /. (m *. x)) 0.
  | "exp_linear" ->
      let k = coefficient_before_x "e\\^{\\([0-9]*\\)x}" p and m = coefficient_before_x "}{\\([0-9]*\\)x}" p in
      near (fun x -> (exp (k *. x) -. 1.) /. (m *. x)) 0.
  | "sin_ratio" ->
      let k = coefficient_before_x "frac{\\\\sin(\\([0-9]*\\)x)" p and m = coefficient_before_x "}{\\\\sin(\\([0-9]*\\)x)" p in
      near (fun x -> sin (k *. x) /. sin (m *. x)) 0.
  | "cos_quadratic" ->
      let k = coefficient_before_x "\\\\cos(\\([0-9]*\\)x)" p and m = coefficient_before_x "}{\\([0-9]*\\)x\\^{2}}" p in
      (* farther from 0: 1 - cos loses precision when x is tiny *)
      let x = 1e-4 in
      (1. -. cos (k *. x)) /. (m *. x *. x)
  | k -> fail ("unknown kind " ^ k); nan

let () =
  let base = load_file "limits.rhm" in
  let prices =
    [ ("removable", 1); ("at_infinity", 1); ("removable_both", 2); ("sin_linear", 2); ("exp_linear", 2);
      ("sin_ratio", 3); ("cos_quadratic", 3) ]
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
          if Float.abs (got -. want) > 1e-4 *. Float.max 1. (Float.abs got) then
            fail (Printf.sprintf "%s: answer %g, evaluated %g, for %S" k got want q.Rhema_engine.prompt)
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema limits tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d limits test(s) failed." !failures);
    exit 1
  end
