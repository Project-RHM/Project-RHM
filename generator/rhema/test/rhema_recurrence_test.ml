(* Independent checks for recurrence.rhm. The recurrence and its first terms
   are read back from the printed question and the sequence is computed
   term by term. A term asked for must be that term; a closed form with the
   answered constants must give every computed term from the first to the
   twelfth; roots must satisfy the characteristic equation. *)

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
  Array.init 8 (fun n -> try Some (Str.matched_group n text) with Not_found | Invalid_argument _ -> None)

let present g n = match g.(n) with Some s -> s | None -> ""

(* A number written in front of a symbol: "" is 1, "-" is -1. *)
let coefficient = function "" -> 1 | "-" -> -1 | s -> int_of_string s

(* A term added with its sign: absent is 0, absent digits are 1. *)
let signed g sign digits =
  match g.(sign) with
  | None -> 0
  | Some s -> (if s = "-" then -1 else 1) * (match present g digits with "" -> 1 | d -> int_of_string d)

(* The recurrence a_n = s a_(n-1) + t a_(n-2) + d, as (s, t, d). *)
let recurrence p =
  let g = groups "\\[`a_n = \\(-?[0-9]*\\)a_{n-1}\\( \\([+-]\\) \\([0-9]*\\)a_{n-2}\\)?\\( \\([+-]\\) \\([0-9]+\\)\\)?`\\]" p in
  (coefficient (present g 1), signed g 3 4, signed g 6 7)

(* The first terms given, by index. *)
let given p =
  let re = Str.regexp "\\[`a_\\([0-9]\\) = \\(-?[0-9]+\\)`\\]" in
  let rec go start found =
    match Str.search_forward re p start with
    | exception Not_found -> List.rev found
    | _ ->
        let index = int_of_string (Str.matched_group 1 p) and value = int_of_string (Str.matched_group 2 p) in
        go (Str.match_end ()) ((index, value) :: found)
  in
  go 0 []

(* Terms from the first index given up to index 12. *)
let terms p =
  let s, t, d = recurrence p and start = given p in
  let table = Hashtbl.create 16 in
  List.iter (fun (index, value) -> Hashtbl.replace table index value) start;
  let order = if t = 0 then 1 else 2 in
  if List.length start <> order then failwith (Printf.sprintf "an order %d recurrence with %d terms given" order (List.length start));
  let first = List.fold_left (fun low (index, _) -> min low index) 99 start in
  for n = first + order to 12 do
    Hashtbl.replace table n ((s * Hashtbl.find table (n - 1)) + (if t = 0 then 0 else t * Hashtbl.find table (n - 2)) + d)
  done;
  (first, fun n -> Hashtbl.find table n)

let rec power base exponent = if exponent = 0 then 1 else base * power base (exponent - 1)

let whole = function
  | Rhema_engine.Num n when Rhema_number.is_integer n -> Rhema_number.require_integer "answer" n
  | other -> failwith ("not a whole number: " ^ Rhema_engine.describe_value other)

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answers %s, for %S" k what q.Rhema_engine.answer_text p) in
  let every first term formula =
    for n = first to 12 do
      if formula n <> term n then wrong (Printf.sprintf "the closed form gives %d for a_%d, the recurrence %d" (formula n) n (term n))
    done
  in
  match (k, q.Rhema_engine.answers) with
  | ("iterate_first" | "iterate_second"), [ value ] ->
      let _, term = terms p in
      let index = int_of_string (present (groups "Find \\[`a_{\\([0-9]+\\)}`\\]" p) 1) in
      if whole value <> term index then wrong (Printf.sprintf "a_%d is %d" index (term index))
  | "closed_first", [ a; b ] ->
      let s, t, _ = recurrence p and first, term = terms p in
      if t <> 0 then wrong "not a first-order recurrence";
      (* the base written in the solution is the recurrence's ratio *)
      let base = present (groups "A \\\\cdot \\(\\\\left(\\)?\\(-?[0-9]+\\)\\(\\\\right)\\)?\\^{n} \\+ B" p) 2 in
      if int_of_string base <> s then wrong "the solution is written with another base";
      every first term (fun n -> (whole a * power s n) + whole b)
  | "characteristic", [ Rhema_engine.Set (Rhema_set.Finite [ r1; r2 ]) ] ->
      let s, t, d = recurrence p in
      if d <> 0 then wrong "not a homogeneous recurrence";
      List.iter
        (fun root ->
          let r = Rhema_number.require_integer "root" root in
          if r * r <> (s * r) + t then wrong (Printf.sprintf "%d is not a root" r))
        [ r1; r2 ];
      if Rhema_number.equal r1 r2 then wrong "one root given twice"
  | "closed_second", [ r; s; a; b ] ->
      let c1, c2, d = recurrence p and first, term = terms p in
      let r = whole r and s = whole s in
      if d <> 0 then wrong "not a homogeneous recurrence";
      if not (r < s) then wrong "the roots are not in order";
      if r * r <> (c1 * r) + c2 || s * s <> (c1 * s) + c2 then wrong "not the roots of the characteristic equation";
      every first term (fun n -> (whole a * power r n) + (whole b * power s n))
  | "repeated", [ r; a; b ] ->
      let c1, c2, _ = recurrence p and first, term = terms p in
      let r = whole r in
      (* a repeated root: t^2 - c1 t - c2 = (t - r)^2 *)
      if c1 <> 2 * r || c2 <> -(r * r) then wrong "not a repeated root of the characteristic equation";
      every first term (fun n -> (whole a + (whole b * n)) * power r n)
  | _ -> wrong "unexpected answers"

let () =
  let base = load_file "recurrence.rhm" in
  let prices =
    [ ("iterate_first", 1, 1); ("iterate_second", 1, 1); ("closed_first", 2, 2); ("characteristic", 2, 1);
      ("closed_second", 3, 4); ("repeated", 3, 3) ]
  in
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
              let context = if k = "characteristic" then "Interval" else "Numeric" in
              if q.Rhema_engine.context <> context then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
              (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) q.Rhema_engine.prompt)))
    done
  done;
  List.iter (fun (k, _, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema recurrence tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d recurrence test(s) failed." !failures);
    exit 1
  end
