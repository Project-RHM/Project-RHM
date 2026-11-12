(* Independent checks for exponential_log.rhm. Each equation is read back
   from the printed question as "left side minus right side", a function of
   x that is undefined where a logarithm has no value. The answer must be a
   zero of it, and scanning a wide range must find exactly one place where
   it changes sign, so the answer is the only solution and a rejected root
   is really outside the domain. A value of a logarithm is recomputed. *)

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

(* The groups of the first match, read at once: Str keeps one match only,
   and reading a linear expression below starts another. *)
let groups re text =
  ignore (Str.search_forward (Str.regexp re) text 0);
  let found = Array.init 7 (fun n -> try Some (Str.matched_group n text) with Not_found | Invalid_argument _ -> None) in
  fun n -> match found.(n) with Some s -> s | None -> raise Not_found

(* A linear expression in x as polynomial_latex writes it: "x", "x - 7",
   "4 \cdot x + 96", "-x + 2". *)
let linear text =
  let re = Str.regexp "^\\(-?[0-9]*\\)\\( \\\\cdot \\)?x\\( \\([+-]\\) \\([0-9]+\\)\\)?$" in
  if not (Str.string_match re text 0) then failwith ("not linear: " ^ text);
  let slope = match Str.matched_group 1 text with "" -> 1. | "-" -> -1. | s -> float_of_string s in
  let constant =
    match Str.matched_group 5 text with
    | exception Not_found -> 0.
    | digits -> (if Str.matched_group 4 text = "-" then -1. else 1.) *. float_of_string digits
  in
  fun x -> (slope *. x) +. constant

let log_base b v = if v > 0. then log v /. log b else nan

let num = "\\([0-9]+\\)"
let inside = "\\\\left(\\([^`]*\\)\\\\right)"

(* The equation as a function whose zeroes are its solutions. *)
let residual (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "same_base" ->
      let g = groups ("`" ^ num ^ "\\^{\\([^}]*\\)} = " ^ num ^ "`") p in
      let b = float_of_string (g 1) and e = linear (g 2) and n = float_of_string (g 3) in
      fun x -> (b ** e x) -. n
  | "two_bases" ->
      let g = groups ("`" ^ num ^ "\\^{\\([^}]*\\)} = " ^ num ^ "\\^{\\([^}]*\\)}`") p in
      let b1 = float_of_string (g 1) and e1 = linear (g 2) and b2 = float_of_string (g 3) and e2 = linear (g 4) in
      (* compared as exponents of a common scale, so that large powers stay finite *)
      fun x -> (e1 x *. log b1) -. (e2 x *. log b2)
  | "log_equation" ->
      let g = groups ("\\\\log_{" ^ num ^ "}" ^ inside ^ " = " ^ num ^ "`") p in
      let b = float_of_string (g 1) and e = linear (g 2) and k = float_of_string (g 3) in
      fun x -> log_base b (e x) -. k
  | "log_sum" ->
      let g =
        groups ("\\\\log_{" ^ num ^ "}\\\\left(x\\\\right) \\+ \\\\log_{" ^ num ^ "}\\\\left(\\([^`]*\\)\\\\right) = \\\\log_{" ^ num ^ "}\\\\left(" ^ num ^ "\\\\right)`") p
      in
      let b = float_of_string (g 1) and e = linear (g 3) and n = float_of_string (g 5) in
      if g 2 <> g 1 || g 4 <> g 1 then fail ("the logarithms have different bases: " ^ p);
      fun x -> log_base b x +. log_base b (e x) -. log_base b n
  | "quadratic_exp" ->
      let g = groups ("`" ^ num ^ "\\^{2x} \\([+-]\\) \\(\\([0-9]+\\) \\\\cdot \\)?" ^ num ^ "\\^{x} - " ^ num ^ " = 0`") p in
      let b = float_of_string (g 1) and n = float_of_string (g 6) in
      let m = (match g 4 with exception Not_found -> 1. | s -> float_of_string s) *. if g 2 = "-" then -1. else 1. in
      if g 5 <> g 1 then fail ("the exponentials have different bases: " ^ p);
      fun x -> (b ** (2. *. x)) +. (m *. (b ** x)) -. n
  | k -> failwith ("unknown kind " ^ k)

(* How many times a function changes sign between -60 and 60, looking only
   where it is defined. A grid point where it is exactly zero is skipped, so
   a root on the grid is counted once, by the signs on either side of it. *)
let sign_changes f =
  let changes = ref 0 and last = ref 0. in
  for i = -60_000 to 60_000 do
    let v = f (float i /. 1000. +. 0.0005) in
    if (not (Float.is_nan v)) && v <> 0. then begin
      if !last <> 0. && (v > 0.) <> (!last > 0.) then incr changes;
      last := v
    end
    else if Float.is_nan v then last := 0.
  done;
  !changes

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt and got = answer q in
  match kind q with
  | "log_value" ->
      let re = "\\\\log_{" ^ num ^ "}\\\\left(\\(\\\\frac{1}{\\)?" ^ num ^ "}?\\\\right)`" in
      let g = groups re p in
      let b = float_of_string (g 1) and n = float_of_string (g 3) in
      let reciprocal = (match g 2 with exception Not_found -> false | _ -> true) in
      let want = log_base b (if reciprocal then 1. /. n else n) in
      if Float.abs (got -. want) > 1e-9 then fail (Printf.sprintf "log_value: answer %g, computed %g, for %S" got want p)
  | k ->
      let f = residual q in
      let at = f got in
      if not (Float.abs at <= 1e-7) then fail (Printf.sprintf "%s: %g does not solve %S (off by %g)" k got p at);
      if Float.abs got >= 60. then fail (Printf.sprintf "%s: the answer %g is outside the scanned range, for %S" k got p);
      let n = sign_changes f in
      if n <> 1 then fail (Printf.sprintf "%s: %d solutions found by scanning, for %S" k n p)

let () =
  let base = load_file "exponential_log.rhm" in
  let prices =
    [ ("log_value", 1); ("same_base", 1); ("two_bases", 2); ("log_equation", 2); ("log_sum", 3); ("quadratic_exp", 3) ]
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
  if !failures = 0 then print_endline "Rhema exponential and logarithm tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d exponential and logarithm test(s) failed." !failures);
    exit 1
  end
