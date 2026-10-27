(* Independent checks for inequality.rhm. The inequality is read back from
   the printed question and evaluated, with exact rationals, at every point
   of a grid, at each end of the answer and just either side of it; the
   point must satisfy the inequality exactly when it is in the answer, read
   back from the WeBWorK form of the answer ((-infinity, 2] U (5, infinity)). *)

module N = Rhema_number

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

let number text =
  match String.split_on_char '/' (String.trim text) with
  | [ a ] -> N.of_int (int_of_string a)
  | [ a; b ] -> N.divide (N.of_int (int_of_string a)) (N.of_int (int_of_string b))
  | _ -> failwith ("number " ^ text)

(* The answer as pieces (lower, upper, lower closed, upper closed), None for infinite. *)
let pieces answer =
  let body = String.sub answer 4 (String.length answer - 5) in
  Str.split (Str.regexp " U ") body
  |> List.map (fun piece ->
         let piece = String.trim piece in
         let lc = piece.[0] = '[' and uc = piece.[String.length piece - 1] = ']' in
         match String.split_on_char ',' (String.sub piece 1 (String.length piece - 2)) with
         | [ lo; hi ] ->
             let bound s = if String.trim s = "-infinity" || String.trim s = "infinity" then None else Some (number s) in
             (bound lo, bound hi, lc, uc)
         | _ -> failwith ("piece " ^ piece))

let member x pieces =
  List.exists
    (fun (lo, hi, lc, uc) ->
      (match lo with None -> true | Some lo -> let c = N.compare x lo in c > 0 || (lc && c = 0))
      && match hi with None -> true | Some hi -> let c = N.compare x hi in c < 0 || (uc && c = 0))
    pieces

let integers text =
  let found = ref [] and re = Str.regexp "-?[0-9]+" in
  let rec go start =
    match Str.search_forward re text start with
    | exception Not_found -> ()
    | i ->
        found := int_of_string (Str.matched_string text) :: !found;
        go (i + String.length (Str.matched_string text))
  in
  go 0;
  List.rev !found

let comparison prompt =
  if Str.string_match (Str.regexp ".*\\\\le ") prompt 0 then `Le
  else if Str.string_match (Str.regexp ".*\\\\ge ") prompt 0 then `Ge
  else if Str.string_match (Str.regexp ".* < ") prompt 0 then `Lt
  else `Gt

let holds op left right =
  let c = N.compare left right in
  match op with `Lt -> c < 0 | `Le -> c <= 0 | `Gt -> c > 0 | `Ge -> c >= 0

(* A linear expression a x + b as polynomial_latex writes it. *)
let linear text =
  let t = String.trim text in
  let sign, t = if t.[0] = '-' then (-1, String.sub t 1 (String.length t - 1)) else (1, t) in
  let a, rest =
    if Str.string_match (Str.regexp "\\([0-9]+\\) \\\\cdot x\\(.*\\)") t 0 then
      (int_of_string (Str.matched_group 1 t), Str.matched_group 2 t)
    else if Str.string_match (Str.regexp "x\\(.*\\)") t 0 then (1, Str.matched_group 1 t)
    else failwith ("linear " ^ text)
  in
  let rest = String.trim rest in
  let b =
    if rest = "" then 0
    else if Str.string_match (Str.regexp "\\([+-]\\) \\([0-9]+\\)") rest 0 then
      (if Str.matched_group 1 rest = "-" then -1 else 1) * int_of_string (Str.matched_group 2 rest)
    else failwith ("constant " ^ rest)
  in
  (sign * a, b)

let ( +: ) = N.add and ( *: ) = N.multiply and ( -: ) = N.subtract

let predicate (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let math = (ignore (Str.search_forward (Str.regexp "\\[`\\(.*\\)`\\]") p 0); Str.matched_group 1 p) in
  let op = comparison p in
  let i = N.of_int in
  match kind q with
  | "linear" ->
      let left, right = (ignore (Str.search_forward (Str.regexp "\\(.*\\) \\(<\\|>\\|\\\\le\\|\\\\ge\\) \\(-?[0-9]+\\)$") math 0);
                         (Str.matched_group 1 math, int_of_string (Str.matched_group 3 math))) in
      let a, b = linear left in
      fun x -> holds op ((i a *: x) +: i b) (i right)
  | "quadratic" ->
      (* k x^2 + b x + c as printed *)
      let left = Str.global_replace (Str.regexp " \\(<\\|>\\|\\\\le\\|\\\\ge\\) 0$") "" math in
      let terms = Str.full_split (Str.regexp " [+-] ") (if left.[0] = '-' then left else "+ " ^ left) in
      let coefficients = Array.make 3 0 and sign = ref 1 in
      List.iter
        (function
          | Str.Delim d -> sign := if String.trim d = "-" then -1 else 1
          | Str.Text t ->
              let t = String.trim t in
              let t = if t <> "" && t.[0] = '-' then (sign := - !sign; String.sub t 1 (String.length t - 1)) else if t <> "" && t.[0] = '+' then String.trim (String.sub t 1 (String.length t - 1)) else t in
              if t = "" then ()
              else
                let c, rest =
                  if Str.string_match (Str.regexp "\\([0-9]+\\) \\\\cdot \\(.*\\)") t 0 then (int_of_string (Str.matched_group 1 t), Str.matched_group 2 t)
                  else if t.[0] = 'x' then (1, t)
                  else (int_of_string t, "")
                in
                let degree = if rest = "x^{2}" then 2 else if rest = "x" then 1 else 0 in
                coefficients.(degree) <- !sign * c)
        terms;
      fun x -> holds op ((i coefficients.(2) *: x *: x) +: (i coefficients.(1) *: x) +: i coefficients.(0)) (i 0)
  | "absolute" | "absolute_linear" ->
      let inside = (ignore (Str.search_forward (Str.regexp "\\\\left|\\(.*\\)\\\\right|") math 0); Str.matched_group 1 math) in
      let a, b = linear inside in
      let bound = List.nth (List.rev (integers math)) 0 in
      fun x -> holds op (N.absolute ((i a *: x) +: i b)) (i bound)
  | "rational" ->
      let top = (ignore (Str.search_forward (Str.regexp "dfrac{\\([^}]*\\)}{\\([^}]*\\)}") math 0); Str.matched_group 1 math)
      and bottom = Str.matched_group 2 math in
      let a1, b1 = linear top and a2, b2 = linear bottom in
      fun x ->
        let d = (i a2 *: x) +: i b2 in
        N.compare d (i 0) <> 0 && holds op (N.divide ((i a1 *: x) +: i b1) d) (i 0)
  | k -> fail ("unknown kind " ^ k); fun _ -> false

let check (q : Rhema_engine.question) =
  let answer = Rhema_engine.describe_value q.Rhema_engine.answer in
  let set = pieces answer and satisfies = predicate q in
  let ends = List.concat_map (fun (lo, hi, _, _) -> List.filter_map Fun.id [ lo; hi ]) set in
  let tiny = N.divide (N.of_int 1) (N.of_int 1000) in
  let points =
    List.init 641 (fun k -> N.divide (N.of_int (k - 320)) (N.of_int 8))
    @ List.concat_map (fun e -> [ e; e +: tiny; e -: tiny ]) ends
  in
  List.iter
    (fun x ->
      if satisfies x <> member x set then
        fail (Printf.sprintf "%s: at x = %s the inequality says %b, the answer %s, for %S" (kind q) (N.to_string x)
                (satisfies x) answer q.Rhema_engine.prompt))
    points

let () =
  let base = load_file "inequality.rhm" in
  let prices = [ ("linear", 1); ("quadratic", 2); ("absolute", 2); ("absolute_linear", 3); ("rational", 3) ] in
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
  if !failures = 0 then print_endline "Rhema inequality tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d inequality test(s) failed." !failures);
    exit 1
  end
