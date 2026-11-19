(* Independent checks for statistics.rhm. The data, the probabilities and
   the parameters are read back from the printed question and every summary
   is recomputed from its definition: the data are sorted for a median, a
   variance is the mean of the squared distances from the mean, an
   expectation and a variance are sums over the printed probabilities (which
   must add up to one), and a binomial probability is the total over every
   sequence of outcomes. *)

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

(* A list of whole numbers written "13, 6, 1, 14, 10". *)
let numbers text = String.split_on_char ',' text |> List.map (fun s -> float_of_string (String.trim s))

let data p = numbers (group "\\(data\\|are\\) \\[`\\([-0-9, ]+\\)`\\]" p 2)

let mean values = List.fold_left ( +. ) 0. values /. float (List.length values)

let median values =
  let sorted = Array.of_list (List.sort compare values) in
  let n = Array.length sorted in
  if n mod 2 = 1 then sorted.(n / 2) else (sorted.((n / 2) - 1) +. sorted.(n / 2)) /. 2.

(* A probability as number_latex writes it: \frac{a}{b}, or a whole number. *)
let fraction text =
  if Str.string_match (Str.regexp "^\\\\frac{\\([0-9]+\\)}{\\([0-9]+\\)}$") text 0 then
    float_of_string (Str.matched_group 1 text) /. float_of_string (Str.matched_group 2 text)
  else float_of_string text

(* The distribution of X: every "P(X = v) = p" of the prompt. *)
let distribution p =
  let re = Str.regexp "P(X = \\(-?[0-9]+\\)) = \\([^`]*\\)`" in
  let rec go start found =
    match Str.search_forward re p start with
    | exception Not_found -> List.rev found
    | _ ->
        let value = Str.matched_group 1 p and probability = Str.matched_group 2 p and next = Str.match_end () in
        go next ((float_of_string value, fraction probability) :: found)
  in
  go 0 []

let expectation f law = List.fold_left (fun total (v, pr) -> total +. (f v *. pr)) 0. law

(* The probability of at least `least` successes in n trials, by going
   through all 2^n sequences. *)
let at_least least n chance =
  let total = ref 0. in
  for outcome = 0 to (1 lsl n) - 1 do
    let successes = ref 0 in
    for trial = 0 to n - 1 do
      if outcome land (1 lsl trial) <> 0 then incr successes
    done;
    if !successes >= least then
      total := !total +. ((chance ** float !successes) *. ((1. -. chance) ** float (n - !successes)))
  done;
  !total

let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let law () =
    let law = distribution p in
    if List.length law <> 3 then fail ("not three values: " ^ p);
    if List.exists (fun (_, pr) -> not (pr > 0.)) law then fail ("a probability that is not positive: " ^ p);
    if Float.abs (expectation (fun _ -> 1.) law -. 1.) > 1e-12 then fail ("the probabilities do not add up to one: " ^ p);
    if List.length (List.sort_uniq compare (List.map fst law)) <> 3 then fail ("a value given twice: " ^ p);
    law
  in
  match kind q with
  | "mean" -> mean (data p)
  | "median" -> median (data p)
  | "range" ->
      let values = data p in
      List.fold_left Float.max neg_infinity values -. List.fold_left Float.min infinity values
  | "variance" ->
      let values = data p in
      let m = mean values in
      mean (List.map (fun v -> (v -. m) ** 2.) values)
  | "missing_value" ->
      let known = data p and m = float_of_string (group "have mean \\[`\\(-?[0-9]+\\)`\\]" p 1) in
      if List.length known <> 4 then fail ("not four known numbers: " ^ p);
      (5. *. m) -. List.fold_left ( +. ) 0. known
  | "expectation" -> expectation Fun.id (law ())
  | "rv_variance" ->
      let law = law () in
      let m = expectation Fun.id law in
      expectation (fun v -> (v -. m) ** 2.) law
  | "binomial_tail" ->
      let chance = fraction (group "probability \\[`\\([^`]*\\)`\\]" p 1) in
      let n = int_of_string (group "Among \\[`\\([0-9]+\\)`\\] parts" p 1) in
      if not (chance > 0. && chance < 1.) then fail ("not a probability: " ^ p);
      at_least 2 n chance
  | k -> fail ("unknown kind " ^ k); nan

let () =
  let base = load_file "statistics.rhm" in
  let prices =
    [ ("mean", 1); ("median", 1); ("range", 1); ("variance", 2); ("missing_value", 2); ("expectation", 2);
      ("rv_variance", 3); ("binomial_tail", 3) ]
  in
  let seen = Hashtbl.create 8 and sizes = Hashtbl.create 2 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          let got = answer q and want = (try expected q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p); nan) in
          if not (Float.abs (got -. want) <= 1e-9 *. Float.max 1. (Float.abs got)) then
            fail (Printf.sprintf "%s: answer %g, recomputed %g, for %S" k got want p);
          (* a median is asked of five values and of six; the data are not listed in order *)
          if k = "median" then begin
            let values = data p in
            Hashtbl.replace sizes (List.length values) ();
            if values = List.sort compare values then fail ("the data are listed in order: " ^ p)
          end;
          if k = "variance" && not (got > 0.) then fail ("a variance of zero: " ^ p)
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  List.iter (fun n -> if not (Hashtbl.mem sizes n) then fail (Printf.sprintf "no median of %d values" n)) [ 5; 6 ];
  if !failures = 0 then print_endline "Rhema statistics tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d statistics test(s) failed." !failures);
    exit 1
  end
