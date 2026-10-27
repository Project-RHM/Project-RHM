(* Independent checks for number_theory.rhm: the numbers are read back from
   the printed question and each answer is found by search. *)

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

let all_numbers text =
  let found = ref [] and re = Str.regexp "[0-9]+" in
  let rec go start =
    match Str.search_forward re text start with
    | exception Not_found -> ()
    | index ->
        found := int_of_string (Str.matched_string text) :: !found;
        go (index + String.length (Str.matched_string text))
  in
  go 0;
  List.rev !found

let kind (q : Rhema_engine.question) =
  match Rhema_engine.attribute q.Rhema_engine.tree "kind" with Rhema_engine.Text t -> t | _ -> "?"

let answer (q : Rhema_engine.question) =
  match q.Rhema_engine.answer with
  | Rhema_engine.Num n when Rhema_number.is_integer n -> int_of_string (Rhema_number.to_string n)
  | other -> fail ("not a whole number: " ^ Rhema_engine.describe_value other); -1

let first_from n p = let rec go i = if p i then i else go (i + 1) in go n

let check (q : Rhema_engine.question) =
  let prompt = q.Rhema_engine.prompt and got = answer q in
  let expected =
    match (kind q, all_numbers prompt) with
    | "gcd", [ a; b ] -> List.fold_left (fun best d -> if a mod d = 0 && b mod d = 0 then d else best) 1 (List.init (min a b) succ)
    | "lcm", [ a; b ] -> first_from 1 (fun m -> m mod a = 0 && m mod b = 0)
    | "power", [ a; k; n ] ->
        let r = ref 1 in
        for _ = 1 to k do r := !r * a mod n done;
        !r
    | "inverse", [ a; n; _; _; a'; _; n' ] when a = a' && n = n' ->
        first_from 0 (fun x -> x * a mod n = 1)
    | "congruence", [ a; b; n; _; _ ] ->
        let solutions = List.filter (fun x -> a * x mod n = b) (List.init n Fun.id) in
        if List.length solutions <> 1 then fail (Printf.sprintf "%S has %d solutions" prompt (List.length solutions));
        (match solutions with x :: _ -> x | [] -> -1)
    | k, ns ->
        fail (Printf.sprintf "%s: unexpected numbers %s in %S" k (String.concat "," (List.map string_of_int ns)) prompt);
        got
  in
  if got <> expected then fail (Printf.sprintf "%s: answer %d, found %d, for %S" (kind q) got expected prompt);
  (match kind q with
  | "gcd" -> if got = 1 then fail ("trivial gcd in " ^ prompt)
  | "congruence" -> if got < 2 then fail ("trivial congruence " ^ prompt)
  | _ -> ())

let () =
  let base = load_file "number_theory.rhm" in
  let prices = [ ("gcd", 1); ("lcm", 1); ("power", 2); ("inverse", 2); ("congruence", 3) ] in
  let seen = Hashtbl.create 8 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 199 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          Hashtbl.replace seen (kind q) ();
          if List.assoc_opt (kind q) prices <> Some cost then fail (Printf.sprintf "%s at cost %d" (kind q) cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (kind q ^ " did not spend its budget");
          check q
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema number theory tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d number theory test(s) failed." !failures);
    exit 1
  end
