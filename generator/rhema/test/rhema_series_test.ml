(* Independent checks for series.rhm. The summand is read back from the
   printed question and the series is summed numerically, term by term:
   finite sums exactly as written, infinite ones far enough that the tail is
   below the tolerance. The result must agree with the exact answer. *)

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

(* A number as the grammar writes it: 7, -\frac{4}{5}, \frac{28}{5}. *)
let number text =
  let text = String.trim text in
  let negative = String.length text > 0 && text.[0] = '-' in
  let body = if negative then String.sub text 1 (String.length text - 1) else text in
  let value =
    if Str.string_match (Str.regexp "\\\\frac{\\([0-9]+\\)}{\\([0-9]+\\)}") body 0 then
      float_of_string (Str.matched_group 1 body) /. float_of_string (Str.matched_group 2 body)
    else float_of_string body
  in
  if negative then -.value else value

let group re text n =
  if Str.search_forward (Str.regexp re) text 0 >= 0 then Str.matched_group n text else ""

let int_group re text n = int_of_string (group re text n)

let sum_from first last term =
  let total = ref 0. in
  for k = first to last do total := !total +. term (float k) done;
  !total

(* A quadratic in k as polynomial_latex writes it: 5 \cdot k^{2} - 8 \cdot k + 4. *)
let quadratic text =
  let a = ref 0. and b = ref 0. and c = ref 0. in
  let terms = Str.full_split (Str.regexp " [+-] ") (" + " ^ String.trim text) in
  let sign = ref 1. in
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
          if Str.string_match (Str.regexp "\\([0-9]*\\)\\( \\\\cdot \\)?k\\^{2}") t 0 then
            a := !sign *. coefficient (Str.matched_group 1 t)
          else if Str.string_match (Str.regexp "\\([0-9]*\\)\\( \\\\cdot \\)?k$") t 0 then
            b := !sign *. coefficient (Str.matched_group 1 t)
          else c := !sign *. float_of_string t)
    terms;
  (!a, !b, !c)

let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "geometric_infinite" ->
      let inner = group "\\[`\\(.*\\) \\+ \\\\cdots`\\]" p 1 in
      let parts = Str.full_split (Str.regexp " [+-] ") inner in
      let terms =
        let sign = ref 1. in
        List.filter_map
          (function
            | Str.Delim d -> sign := (if String.trim d = "-" then -1. else 1.); None
            | Str.Text t -> Some (!sign *. number t))
          parts
      in
      (match terms with
      | [ t0; t1; t2 ] ->
          let r = t1 /. t0 in
          if Float.abs ((t1 *. r) -. t2) > 1e-9 then fail ("not geometric: " ^ p);
          sum_from 0 400 (fun k -> t0 *. (r ** k))
      | _ -> fail ("three terms expected: " ^ p); nan)
  | "squares" -> sum_from 1 (int_group "\\^{\\([0-9]+\\)} k\\^{2}" p 1) (fun k -> k *. k)
  | "geometric_sigma" ->
      let m = int_group "sum_{k=\\([0-9]+\\)}" p 1 in
      let a = group "\\^{\\\\infty} \\([0-9]*\\)\\\\left(" p 1 in
      let a = if a = "" then 1. else float_of_string a in
      let r = number (group "\\\\left(\\(.*\\)\\\\right)\\^{k}" p 1) in
      sum_from m 400 (fun k -> a *. (r ** k))
  | "polynomial_sum" ->
      let n = int_group "\\^{\\([0-9]+\\)} \\\\left(" p 1 in
      let a, b, c = quadratic (group "\\\\left(\\(.*\\)\\\\right)`" p 1) in
      sum_from 1 n (fun k -> (a *. k *. k) +. (b *. k) +. c)
  | "telescoping" ->
      let n = int_group "\\^{\\([0-9]+\\)} \\\\frac" p 1 in
      let c = if Str.string_match (Str.regexp ".*k(k\\+1)") p 0 then 0 else int_group "(k\\+\\([0-9]+\\))(" p 1 in
      sum_from 1 n (fun k -> 1. /. ((k +. float c) *. (k +. float c +. 1.)))
  | "telescoping_gap" ->
      let n = int_group "\\^{\\([0-9]+\\)} \\\\frac" p 1 and g = int_group "k(k\\+\\([0-9]+\\))" p 1 in
      sum_from 1 n (fun k -> 1. /. (k *. (k +. float g)))
  | "telescoping_infinite" ->
      let g = int_group "k(k\\+\\([0-9]+\\))" p 1 in
      (* the tail beyond N is below g/N *)
      sum_from 1 2_000_000 (fun k -> 1. /. (k *. (k +. float g)))
  | "geometric_combined" ->
      let re =
        "\\\\left(\\([0-9]*\\)\\\\left(\\(.*\\)\\\\right)\\^{k} \\+ \\([0-9]*\\)\\\\left(\\(.*\\)\\\\right)\\^{k}\\\\right)"
      in
      let coefficient s = if s = "" then 1. else float_of_string s in
      let a = coefficient (group re p 1) and r = number (group re p 2) in
      let b = coefficient (group re p 3) and s = number (group re p 4) in
      sum_from 0 400 (fun k -> (a *. (r ** k)) +. (b *. (s ** k)))
  | k -> fail ("unknown kind " ^ k); nan

let () =
  let base = load_file "series.rhm" in
  let prices =
    [ ("geometric_infinite", 1); ("squares", 1); ("geometric_sigma", 2); ("polynomial_sum", 2); ("telescoping", 2);
      ("telescoping_gap", 3); ("telescoping_infinite", 3); ("geometric_combined", 3) ]
  in
  let seen = Hashtbl.create 8 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 119 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          let k = kind q in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          let got = answer q and want = expected q in
          let tolerance = if k = "telescoping_infinite" then 1e-5 else 1e-7 *. Float.max 1. (Float.abs want) in
          if Float.abs (got -. want) > tolerance then
            fail (Printf.sprintf "%s: answer %g, summed %g, for %S" k got want q.Rhema_engine.prompt);
          if Str.string_match (Str.regexp ".*[^0-9]1\\\\left(") q.Rhema_engine.prompt 0 then
            fail ("a coefficient of 1 is printed: " ^ q.Rhema_engine.prompt)
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema series tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d series test(s) failed." !failures);
    exit 1
  end
