(* Independent checks for partial_fractions.rhm. The rational function and
   the shape of its decomposition are read back from the printed question;
   the constants answered are put into the decomposition, and the two sides
   are compared as numbers at several points away from the poles. A
   decomposition into partial fractions is unique, so constants that pass
   are the constants. The factors must be different, or it would not be. *)

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
  let terms = !out in
  fun x -> List.fold_left (fun total (d, c) -> total +. (c *. (x ** float d))) 0. terms

(* Every match of a regular expression, as the list of its first [groups]
   groups (an absent group is ""). *)
let matches re groups text =
  let re = Str.regexp re in
  let rec go start found =
    match Str.search_forward re text start with
    | exception Not_found -> List.rev found
    | _ ->
        let next = Str.match_end () in
        let got = List.init groups (fun n -> try Str.matched_group (n + 1) text with Not_found -> "") in
        go next (got :: found)
  in
  go 0 []

let split_once separator text =
  let index = Str.search_forward (Str.regexp_string separator) text 0 in
  (String.sub text 0 index, String.sub text (index + String.length separator) (String.length text - index - String.length separator))

(* The first formula of the prompt: \dfrac{N}{D} = right side. *)
let parts prompt =
  let formula = List.hd (List.hd (matches "\\[`\\(\\\\dfrac[^`]*\\)`\\]" 1 prompt)) in
  let left, right = split_once " = " formula in
  ignore (Str.string_match (Str.regexp "\\\\dfrac{\\(.*\\)}{\\(\\\\left(.*\\)}$") left 0);
  (Str.matched_group 1 left, Str.matched_group 2 left, right)

(* The factors of a denominator, \left(x - 3\right) or \left(x - 3\right)^{2},
   as (function, power, text). *)
let factors text =
  matches "\\\\left(\\([^()]*\\)\\\\right)\\(\\^{\\([0-9]+\\)}\\)?" 3 text
  |> List.map (function
       | [ body; _; power ] -> (polynomial body, (if power = "" then 1 else int_of_string power), body)
       | _ -> assert false)

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answers %s, for %S" k what q.Rhema_engine.answer_text p) in
  let numerator, denominator, right = parts p in
  let top = polynomial numerator and bottom = factors denominator in
  (* different factors: no two with a common root *)
  let roots =
    List.map (fun (f, _, _) -> let slope = f 1. -. f 0. in -.f 0. /. slope) bottom
  in
  if List.length (List.sort_uniq compare roots) <> List.length roots then wrong "two factors with one root";
  let constants =
    List.map
      (function Rhema_engine.Num n -> Rhema_number.to_float n | other -> fail ("not a number: " ^ Rhema_engine.describe_value other); nan)
      q.Rhema_engine.answers
  in
  (* the right side: an optional whole quotient, then \dfrac{LETTER}{denominator} terms *)
  let quotient =
    if Str.string_match (Str.regexp "\\([0-9]+\\) \\+ ") right 0 then float_of_string (Str.matched_group 1 right) else 0.
  in
  let terms =
    matches "\\\\dfrac{\\([A-C]\\)}{\\(\\\\left(\\([^()]*\\)\\\\right)\\^{\\([0-9]+\\)}\\|\\([^{}]*\\)\\)}" 5 right
    |> List.map (function
         | [ letter; _; bracketed; power; bare ] ->
             let body = if bare <> "" then bare else bracketed in
             (letter, polynomial body, if power = "" then 1 else int_of_string power)
         | _ -> assert false)
  in
  if List.map (fun (letter, _, _) -> letter) terms <> List.filteri (fun i _ -> i < List.length terms) [ "A"; "B"; "C" ] then
    wrong "the constants are not named A, B, C in order";
  if List.length terms <> List.length constants then
    wrong (Printf.sprintf "%d constants asked, %d answered" (List.length terms) (List.length constants));
  (* each term's denominator is a factor of the whole one, to no higher power *)
  List.iter
    (fun (_, f, power) ->
      if not (List.exists (fun (g, highest, _) -> Float.abs (f 0.37 -. g 0.37) < 1e-9 && Float.abs (f 2.11 -. g 2.11) < 1e-9 && power <= highest) bottom) then
        wrong "a term whose denominator is not a factor")
    terms;
  if List.length terms = List.length constants then
    List.iter
      (fun x ->
        let left = top x /. List.fold_left (fun product (f, power, _) -> product *. (f x ** float power)) 1. bottom in
        let right =
          List.fold_left2 (fun total (_, f, power) constant -> total +. (constant /. (f x ** float power))) quotient terms constants
        in
        if Float.abs (left -. right) > 1e-9 *. Float.max 1. (Float.abs left) then
          wrong (Printf.sprintf "the two sides differ at x = %g: %g and %g" x left right))
      [ 0.37; 1.91; -2.63; 5.21; -7.45 ]

let () =
  let base = load_file "partial_fractions.rhm" in
  let prices = [ ("two_factors", 1, 2); ("scaled", 2, 2); ("improper", 2, 2); ("three_factors", 3, 3); ("repeated", 3, 3) ] in
  let seen = Hashtbl.create 8 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q in
          Hashtbl.replace seen k ();
          match List.find_opt (fun (name, _, _) -> name = k) prices with
          | None -> fail ("unknown kind " ^ k)
          | Some (_, price, blanks) ->
              if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost);
              if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
              if List.length q.Rhema_engine.answers <> blanks then
                fail (Printf.sprintf "%s has %d blanks" k (List.length q.Rhema_engine.answers));
              (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) q.Rhema_engine.prompt)))
    done
  done;
  List.iter (fun (k, _, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema partial fractions tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d partial fractions test(s) failed." !failures);
    exit 1
  end
