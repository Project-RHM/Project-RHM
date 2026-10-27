(* Independent checks for counting.rhm. The numbers are read back from the
   printed question, and each answer is recomputed from them by brute force
   where that is feasible (listing selections, rolling dice, tossing coins)
   or by the textbook formula otherwise. *)

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

(* The whole numbers shown in [`...`] blocks, in order. *)
let numbers prompt =
  let found = ref [] in
  let re = Str.regexp "\\[`\\([0-9]+\\)`\\]" in
  let rec go start =
    match Str.search_forward re prompt start with
    | exception Not_found -> ()
    | index ->
        found := int_of_string (Str.matched_group 1 prompt) :: !found;
        go (index + 1)
  in
  go 0;
  List.rev !found

let answer_fraction (question : Rhema_engine.question) =
  match question.Rhema_engine.answer with
  | Rhema_engine.Num n -> Rhema_number.to_string n
  | other -> fail ("answer is not a number: " ^ Rhema_engine.describe_value other); ""

let kind (question : Rhema_engine.question) =
  match Rhema_engine.attribute question.Rhema_engine.tree "kind" with
  | Rhema_engine.Text t -> t
  | _ -> "?"

(* Brute force: subsets of {0..n-1} of size k. *)
let rec subsets n k =
  if k = 0 then [ [] ]
  else if n < k then []
  else List.map (fun s -> (n - 1) :: s) (subsets (n - 1) (k - 1)) @ subsets (n - 1) k

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let fraction p q =
  let g = gcd p q in
  let p = p / g and q = q / g in
  if q = 1 then string_of_int p else Printf.sprintf "%d/%d" p q

let rec factorial n = if n <= 1 then 1 else n * factorial (n - 1)

let word_count = function
  | "BANANA" | "PEPPER" -> 60
  | "LETTER" -> 180
  | "COMMITTEE" -> 45360
  | "STATISTICS" -> 50400
  | "MISSISSIPPI" -> 34650
  | w -> fail ("unknown word " ^ w); -1

let check (question : Rhema_engine.question) =
  let prompt = question.Rhema_engine.prompt in
  let got = answer_fraction question in
  let ns = numbers prompt in
  let expected =
    match (kind question, ns) with
    | "row", [ n ] -> string_of_int (factorial n)
    | "ranked", [ n; k ] -> string_of_int (factorial n / factorial (n - k))
    | "committee", [ k; n ] -> string_of_int (List.length (subsets n k))
    | "word", [] ->
        let re = Str.regexp "\\\\text{\\([A-Z]+\\)}" in
        ignore (Str.search_forward re prompt 0);
        string_of_int (word_count (Str.matched_group 1 prompt))
    | "at_least_one", [ k; men; women ] ->
        (* people 0..men-1 are men *)
        string_of_int
          (List.length (List.filter (List.exists (fun p -> p >= men)) (subsets (men + women) k)))
    | "not_together", [ k; n ] ->
        (* people 0 and 1 refuse to serve together *)
        string_of_int
          (List.length (List.filter (fun s -> not (List.mem 0 s && List.mem 1 s)) (subsets n k)))
    | "dice_sum", [ s ] ->
        let ways = ref 0 in
        for a = 1 to 6 do for b = 1 to 6 do if a + b = s then incr ways done done;
        fraction !ways 36
    | "draw_all", [ red; blue; k ] ->
        let all = subsets (red + blue) k in
        fraction (List.length (List.filter (List.for_all (fun b -> b < red)) all)) (List.length all)
    | "at_least_one_six", [ n ] ->
        let total = int_of_float (6. ** float n) and none = int_of_float (5. ** float n) in
        fraction (total - none) total
    | "heads", [ n; j ] ->
        let count = ref 0 in
        for mask = 0 to (1 lsl n) - 1 do
          let ones = ref 0 in
          for bit = 0 to n - 1 do if mask land (1 lsl bit) <> 0 then incr ones done;
          if !ones = j then incr count
        done;
        fraction !count (1 lsl n)
    | k, ns ->
        fail (Printf.sprintf "%s: unexpected numbers %s in %S" k (String.concat "," (List.map string_of_int ns)) prompt);
        got
  in
  if got <> expected then
    fail (Printf.sprintf "%s: answer %s, recomputed %s, for %S" (kind question) got expected prompt)

let () =
  let base = load_file "counting.rhm" in
  let kinds = Hashtbl.create 16 in
  let prices =
    [ ("row", 1); ("ranked", 1); ("committee", 1); ("word", 2); ("at_least_one", 2); ("not_together", 2);
      ("dice_sum", 2); ("draw_all", 3); ("at_least_one_six", 3); ("heads", 3) ]
  in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | question ->
          let k = kind question in
          Hashtbl.replace kinds k ();
          (match List.assoc_opt k prices with
          | Some price when price <> cost -> fail (Printf.sprintf "%s appeared at cost %d, its price is %d" k cost price)
          | None -> fail ("unknown kind " ^ k)
          | _ -> ());
          if Rhema_engine.consumption question.Rhema_engine.tree "cost" <> cost then
            fail (Printf.sprintf "cost %d: %s did not spend its budget" cost k);
          check question
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem kinds k) then fail ("never generated: " ^ k)) prices;
  (* The named questions keep to their family. *)
  List.iter
    (fun (name, family) ->
      match Rhema_check.select_question base name with
      | Error m -> fail m
      | Ok spec ->
          List.iter
            (fun cost ->
              let spec = with_initial spec "cost" cost in
              for seed = 0 to 29 do
                Random.init seed;
                match Rhema_engine.generate spec with
                | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "%s cost %d: %s" name cost m)
                | question ->
                    if not (List.mem (kind question) family) then
                      fail (Printf.sprintf "%s asked a %s question" name (kind question))
              done)
            (if name = "counting" then [ 1; 2 ] else [ 2; 3 ]))
    [ ("counting", [ "row"; "ranked"; "committee"; "word"; "at_least_one"; "not_together" ]);
      ("probability", [ "dice_sum"; "draw_all"; "at_least_one_six"; "heads" ]) ];
  if !failures = 0 then print_endline "Rhema counting tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d counting test(s) failed." !failures);
    exit 1
  end
