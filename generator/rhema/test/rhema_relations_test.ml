(* Independent checks for relations.rhm. Every question is matched against
   the whole sentence of its form, the numbers and the pairs are read back
   from it, and the answer is found again by brute force from the
   definitions, never by the formula the grammar uses:

   count_relations     the pairs of A x B are written out and every subset
                       of them is built, by bit masks; the different subsets
                       are counted.
   count_functions     every way of giving each element of A one element of
                       B is written out, and counted.
   injections          the same assignments, keeping those in which no
                       element of B is used twice. A must be smaller than B.
   surjections         the same assignments, keeping those in which every
                       element of B is used. B has two or three elements and
                       A has more.
   reflexive_count,    every relation on {1, ..., n} is built as a subset of
   symmetric_count     the n * n pairs (65536 of them for n = 4), and those
                       that hold every (a, a), or the mirror image of each
                       of their pairs, are counted.
   symmetric_closure   the pairs of R are read from the listing, which must
                       be well formed: pairs of {1, 2, 3}, none twice, in
                       order, three to six of them. Every one of the 512
                       relations on {1, 2, 3} that contains R and is
                       symmetric is looked at, and the fewest pairs any of
                       them adds is the answer. It must be at least 1, and
                       it must be the number of pairs of R whose mirror
                       image is missing. Every relation of three to six
                       pairs that is not symmetric must be asked.
   equivalence_pairs   a set is cut into classes of the printed sizes, the
                       pairs of two elements of one class are marked, and
                       the marks are counted. The relation built must be
                       reflexive, symmetric and transitive, the printed
                       total must be the sum of the sizes, and no class may
                       be empty.
   composition         R and S are read from their listings; each pair
                       (a, c) is tried with every b, as the question itself
                       defines the composite (R first, then S), and the
                       pairs found are counted. R and S must differ, every
                       relation of three to six pairs must come up as R and
                       as S, and so must every pair of sizes.
   transitive_closure  R is read from its listing and closed by adding
                       (a, c) whenever (a, b) and (b, c) are there, until
                       nothing changes. The result must be the one smallest
                       transitive relation among the 512 that contain R, and
                       it must be larger than R. Every relation of three to
                       six pairs that is not transitive must be asked.
   two_classes         every way of putting the elements in class 0 or 1,
                       the first element in class 0 and class 1 not empty,
                       is written out and counted.

   The mistakes are found again in the same way. sets_swapped is listed on
   count_functions alone, with the number of assignments from B to A;
   diagonal_forgotten is listed on symmetric_count alone, with the number of
   subsets of the unordered pairs of two different elements. Each must give
   another number than the right answer, and no other form lists a mistake.
   The description of the first must speak of the two sets, and that of the
   second of the pairs (a, a).

   Every kind must come up at its price and at no other, a budget outside 1
   to 3 must give no question, and every answer must be one whole number.
   The numbers each form is asked with are pinned as well: every choice the
   grammar offers must come up, and nothing else. At each price the forms
   the grammar gives double weight must come up more often than the others. *)

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

let whole = function
  | Rhema_engine.Num n when Rhema_number.is_integer n -> Some n.Rhema_number.numerator
  | _ -> None

(* ---- Reading a question ---- *)

(* The fields of a prompt: the pattern is the whole sentence, with a group
   wherever a number or a list of pairs stands. *)
let words = Str.quote
let a_count = "\\([0-9]+\\)"
let a_listing = "\\([^`{}]*\\)"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

let counts count pattern prompt = List.map int_of_string (fields count pattern prompt)

(* A relation on {1, 2, 3} as its listing writes it, "(1, 2), (2, 1), (3, 3)":
   pairs of 1, 2 and 3 separated by a comma and a space, in order (by first
   element, then by second), none twice, three to six of them. *)
let a_pair = Str.regexp "(\\([0-9]+\\), \\([0-9]+\\))"

let listing text =
  let length = String.length text in
  let rec read from found =
    if not (Str.string_match a_pair text from) then failwith ("not a list of pairs: " ^ text);
    let pair = (int_of_string (Str.matched_group 1 text), int_of_string (Str.matched_group 2 text)) in
    let next = Str.match_end () in
    if next = length then List.rev (pair :: found)
    else if next + 2 <= length && String.sub text next 2 = ", " then read (next + 2) (pair :: found)
    else failwith ("pairs not separated by a comma and a space: " ^ text)
  in
  let pairs = read 0 [] in
  let rec in_order = function a :: (b :: _ as rest) -> compare a b < 0 && in_order rest | _ -> true in
  if List.exists (fun (a, b) -> a < 1 || a > 3 || b < 1 || b > 3) pairs then
    failwith ("a pair that is not of {1, 2, 3}: " ^ text);
  if not (in_order pairs) then failwith ("pairs out of order, or one twice: " ^ text);
  if List.length pairs < 3 || List.length pairs > 6 then failwith ("not three to six pairs: " ^ text);
  pairs

(* ---- Counting by brute force ---- *)

let upto n = List.init n (fun i -> i + 1)
let product xs ys = List.concat_map (fun x -> List.map (fun y -> (x, y)) ys) xs
let sum = List.fold_left ( + ) 0

let memo f =
  let known = Hashtbl.create 16 in
  fun key ->
    match Hashtbl.find_opt known key with
    | Some value -> value
    | None ->
        let value = f key in
        Hashtbl.add known key value;
        value

(* Every subset of a list: the item at place i is taken when bit i of the
   mask is set. *)
let subsets items =
  if List.length items > 16 then failwith "too many pairs to go through every subset";
  List.init (1 lsl List.length items) (fun mask -> List.filteri (fun i _ -> mask land (1 lsl i) <> 0) items)

(* Every way of giving each of `sources` elements one of the targets, as the
   list of the images. *)
let rec assignments sources targets =
  if sources = 0 then [ [] ]
  else List.concat_map (fun rest -> List.map (fun image -> image :: rest) targets) (assignments (sources - 1) targets)

(* The functions from a set of m elements to a set of n that pass a test. *)
let functions_that test =
  memo (fun (m, n) ->
      if m < 0 || n < 1 || m > 6 || n > 7 then failwith "sets too large to go through every function";
      List.length (List.filter (test n) (assignments m (upto n))))

let functions = functions_that (fun _ _ -> true)
let one_to_one = functions_that (fun _ images -> List.length (List.sort_uniq compare images) = List.length images)
let onto = functions_that (fun n images -> List.for_all (fun b -> List.mem b images) (upto n))

(* The relations from a set of m elements to a set of n: the different
   subsets of the m * n pairs. *)
let relations_between =
  memo (fun (m, n) -> List.length (List.sort_uniq compare (subsets (product (upto m) (upto n)))))

let reflexive n r = List.for_all (fun a -> List.mem (a, a) r) (upto n)
let symmetric r = List.for_all (fun (a, b) -> List.mem (b, a) r) r
let transitive r = List.for_all (fun (a, b) -> List.for_all (fun (b', c) -> b <> b' || List.mem (a, c) r) r) r
let contains large small = List.for_all (fun pair -> List.mem pair large) small

(* The relations on {1, ..., n} that pass a test, out of all of them. *)
let relations_that test =
  memo (fun n ->
      if n < 1 || n > 4 then failwith "a set too large to go through every relation on it";
      List.length (List.filter (test n) (subsets (product (upto n) (upto n)))))

let reflexive_relations = relations_that reflexive
let symmetric_relations = relations_that (fun _ r -> symmetric r)

(* What diagonal_forgotten counts: the subsets of the pairs a < b. *)
let subsets_off_the_diagonal =
  memo (fun n -> List.length (subsets (List.filter (fun (a, b) -> a < b) (product (upto n) (upto n)))))

(* All 512 relations on {1, 2, 3}. *)
let on_three = subsets (product (upto 3) (upto 3))

(* The fewest pairs that a symmetric relation containing r has more than r. *)
let fewest_added r =
  List.filter (fun s -> contains s r && symmetric s) on_three
  |> List.map (fun s -> List.length s - List.length r)
  |> List.fold_left min max_int

(* (a, c) for which some b has (a, b) in r and (b, c) in s. *)
let composite r s =
  List.filter
    (fun (a, c) -> List.exists (fun b -> List.mem (a, b) r && List.mem (b, c) s) (upto 3))
    (product (upto 3) (upto 3))

(* Add (a, c) wherever (a, b) and (b, c) are there, until nothing is added. *)
let rec closure r =
  let wanted =
    List.concat_map (fun (a, b) -> List.filter_map (fun (b', c) -> if b = b' then Some (a, c) else None) r) r
  in
  match List.sort_uniq compare (List.filter (fun pair -> not (List.mem pair r)) wanted) with
  | [] -> List.sort compare r
  | more -> closure (r @ more)

(* The pairs of the equivalence relation whose classes have these sizes. The
   elements 0 .. total - 1 are dealt out class by class, and a pair is marked
   when its two elements are in one class. *)
let pairs_in_classes =
  memo (fun sizes ->
      if List.exists (fun size -> size < 1) sizes then failwith "an empty class";
      if sum sizes > 40 then failwith "a set too large to mark every pair";
      let class_of = Array.of_list (List.concat (List.mapi (fun name size -> List.init size (fun _ -> name)) sizes)) in
      let total = Array.length class_of in
      let related = Array.init total (fun x -> Array.init total (fun y -> class_of.(x) = class_of.(y))) in
      let every test = List.for_all test (List.init total Fun.id) in
      if
        not
          (every (fun x -> related.(x).(x))
          && every (fun x -> every (fun y -> related.(x).(y) = related.(y).(x)))
          && every (fun x -> every (fun y -> every (fun z -> (not (related.(x).(y) && related.(y).(z))) || related.(x).(z))))
          )
      then failwith "the test's relation is not an equivalence relation";
      sum (Array.to_list (Array.map (fun row -> List.length (List.filter Fun.id (Array.to_list row))) related)))

(* The ways of cutting a set of n elements into exactly two classes: every
   element is put in class 0 or 1, the first one in class 0, and class 1 is
   not left empty. *)
let cuts_in_two =
  memo (fun n ->
      if n < 1 || n > 16 then failwith "a set too large to go through every cut";
      List.length (List.filter (List.mem 1) (assignments (n - 1) [ 0; 1 ])))

(* ---- What each form was asked with ---- *)

let asked : (string * int list, unit) Hashtbl.t = Hashtbl.create 64
let note label numbers = Hashtbl.replace asked (label, numbers) ()

(* A relation read from a question, as the numbers of its pairs in a row. *)
let in_a_row r = List.concat_map (fun (a, b) -> [ a; b ]) r
let note_relation label r = note label (in_a_row r)

(* Every choice the grammar offers, form by form. *)
let offered =
  (* the relations on {1, 2, 3} that are drawn: those of three to six pairs *)
  let drawn = List.filter (fun r -> List.length r >= 3 && List.length r <= 6) on_three in
  let drawn_unless test = List.map in_a_row (List.filter (fun r -> not (test r)) drawn) in
  let range first last = List.init (last - first + 1) (fun i -> first + i) in
  let both xs ys = List.map (fun (x, y) -> [ x; y ]) (product xs ys) in
  [ ("count_relations", both [ 2; 3 ] [ 2; 3 ]);
    (* a pair of sizes is left out when the swapped sets give as many functions *)
    ( "count_functions",
      List.filter
        (function [ m; n ] -> functions (m, n) <> functions (n, m) | _ -> false)
        (both (range 2 5) (range 2 5)) );
    ("injections", List.filter (function [ m; n ] -> m < n | _ -> false) (both (range 2 4) (range 3 7)));
    ("surjections", List.filter (function [ m; n ] -> m > n && m <= n + 3 | _ -> false) (both (range 3 6) [ 2; 3 ]));
    ("reflexive_count", [ [ 2 ]; [ 3 ]; [ 4 ] ]);
    ("symmetric_count", [ [ 2 ]; [ 3 ]; [ 4 ] ]);
    (* three classes of one to four elements, on a set of at least five *)
    ( "equivalence_pairs",
      List.filter
        (fun sizes -> sum sizes >= 5)
        (List.concat_map (fun (a, b) -> List.map (fun c -> [ a; b; c ]) (range 1 4)) (product (range 1 4) (range 1 4))) );
    ("two_classes", List.map (fun n -> [ n ]) (range 3 8));
    (* every relation drawn is asked, unless it is symmetric already *)
    ("symmetric_closure", drawn_unless symmetric);
    ("composition R", drawn_unless (fun _ -> false));
    ("composition S", drawn_unless (fun _ -> false));
    ("composition, sizes of R and S", both (range 3 6) (range 3 6));
    (* every relation drawn is asked, unless it is transitive already *)
    ("transitive_closure", drawn_unless transitive) ]

(* ---- The answer of each form, found again ---- *)

let two_sets =
  words "The set [`A`] has [`" ^ a_count ^ words "`] elements and the set [`B`] has [`" ^ a_count ^ words "`]. "

let on_the_set = words "\\}`] is on the set [`\\{1, 2, 3\\}`]. "

(* The right answer of a question, and the answer of each mistake that its
   form is open to, all found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let sets asked_for =
    match counts 2 (two_sets ^ words asked_for) p with [ m; n ] -> (m, n) | _ -> failwith "two numbers were expected"
  in
  let one before after =
    match counts 1 (words before ^ a_count ^ words after) p with [ n ] -> n | _ -> failwith "one number was expected"
  in
  match kind q with
  | "count_relations" ->
      let m, n = sets "How many relations are there from [`A`] to [`B`]?" in
      note "count_relations" [ m; n ];
      (relations_between (m, n), [])
  | "count_functions" ->
      let m, n = sets "How many functions are there from [`A`] to [`B`]?" in
      note "count_functions" [ m; n ];
      (functions (m, n), [ ("sets_swapped", functions (n, m)) ])
  | "injections" ->
      let m, n = sets "How many one-to-one functions are there from [`A`] to [`B`]?" in
      note "injections" [ m; n ];
      if m >= n then failwith "A is not smaller than B";
      (one_to_one (m, n), [])
  | "surjections" ->
      let m, n =
        sets
          "How many functions from [`A`] to [`B`] are onto, so that every element of [`B`] is the image of some element of [`A`]?"
      in
      note "surjections" [ m; n ];
      if n <> 2 && n <> 3 then failwith "B does not have two or three elements";
      if m <= n then failwith "A is not larger than B";
      (onto (m, n), [])
  | "reflexive_count" ->
      let n = one "How many reflexive relations are there on a set with [`" "`] elements?" in
      note "reflexive_count" [ n ];
      (reflexive_relations n, [])
  | "symmetric_count" ->
      let n = one "How many symmetric relations are there on a set with [`" "`] elements?" in
      note "symmetric_count" [ n ];
      (symmetric_relations n, [ ("diagonal_forgotten", subsets_off_the_diagonal n) ])
  | "symmetric_closure" -> (
      match
        fields 1
          (words "The relation [`R = \\{" ^ a_listing ^ on_the_set
          ^ words "What is the smallest number of pairs that must be added to [`R`] to make it symmetric?")
          p
      with
      | [ shown ] ->
          let r = listing shown in
          note_relation "symmetric_closure" r;
          let added = fewest_added r in
          if added < 1 then failwith "the relation is symmetric already";
          (* the other way: each pair whose mirror image is missing wants it,
             and with them all the relation is symmetric *)
          let mirrors = List.filter_map (fun (a, b) -> if List.mem (b, a) r then None else Some (b, a)) r in
          if List.length mirrors <> added || not (symmetric (r @ mirrors)) then
            failwith "the search and the missing mirror images disagree";
          (added, [])
      | _ -> failwith "one listing was expected")
  | "equivalence_pairs" -> (
      match
        counts 4
          (words "An equivalence relation on a set of [`" ^ a_count
          ^ words "`] elements has three equivalence classes, of sizes [`"
          ^ a_count ^ words "`], [`" ^ a_count ^ words "`] and [`" ^ a_count
          ^ words "`]. How many ordered pairs does the relation contain?")
          p
      with
      | [ total; first; second; third ] ->
          note "equivalence_pairs" [ first; second; third ];
          if total <> first + second + third then failwith "the sizes of the classes do not add up to the set";
          (pairs_in_classes [ first; second; third ], [])
      | _ -> failwith "four numbers were expected")
  | "composition" -> (
      match
        fields 2
          (words "On the set [`\\{1, 2, 3\\}`], let [`R = \\{" ^ a_listing ^ words "\\}`] and [`S = \\{" ^ a_listing
          ^ words
              "\\}`]. The composite of [`R`] followed by [`S`] holds the pairs [`(a, c)`] for which there is a [`b`] with [`(a, b)`] in [`R`] and [`(b, c)`] in [`S`]. How many pairs does it hold?"
          )
          p
      with
      | [ first; second ] ->
          let r = listing first and s = listing second in
          note_relation "composition R" r;
          note_relation "composition S" s;
          note "composition, sizes of R and S" [ List.length r; List.length s ];
          if r = s then failwith "R and S are the same relation";
          (List.length (composite r s), [])
      | _ -> failwith "two listings were expected")
  | "transitive_closure" -> (
      match
        fields 1
          (words "The relation [`R = \\{" ^ a_listing ^ on_the_set
          ^ words
              "How many pairs does its transitive closure, the smallest transitive relation that contains [`R`], hold?")
          p
      with
      | [ shown ] ->
          let r = listing shown in
          note_relation "transitive_closure" r;
          let closed = closure r in
          (* as the question defines it: of the transitive relations that
             contain R, the smallest, which every other one contains *)
          let candidates = List.filter (fun s -> contains s r && transitive s) on_three in
          let smallest = List.fold_left (fun best s -> min best (List.length s)) max_int candidates in
          (match List.filter (fun s -> List.length s = smallest) candidates with
          | [ only ] ->
              if only <> closed then failwith "the closure built is not the smallest transitive relation";
              if not (List.for_all (fun s -> contains s only) candidates) then
                failwith "a transitive relation that contains R does not contain its closure"
          | _ -> failwith "no one smallest transitive relation");
          if List.length closed <= List.length r then failwith "the relation is transitive already";
          (List.length closed, [])
      | _ -> failwith "one listing was expected")
  | "two_classes" ->
      let n =
        one "How many equivalence relations on a set of [`" "`] elements have exactly two equivalence classes?"
      in
      note "two_classes" [ n ];
      (cuts_in_two n, [])
  | k -> failwith ("unknown kind " ^ k)

let per_budget = 20000

let () =
  let base = load_file "relations.rhm" in
  let prices =
    [ ("count_relations", 1); ("count_functions", 1); ("injections", 1); ("reflexive_count", 2);
      ("symmetric_count", 2); ("surjections", 2); ("symmetric_closure", 2); ("equivalence_pairs", 2);
      ("composition", 3); ("transitive_closure", 3); ("two_classes", 3) ]
  in
  (* the forms that work on a listed relation, the functions and the onto
     functions are given double weight *)
  let favoured = [ "count_functions"; "surjections"; "symmetric_closure"; "composition"; "transitive_closure" ] in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 2 in
  let times k = Option.value (Hashtbl.find_opt seen k) ~default:0 in
  (* a budget below the lowest or above the highest is refused *)
  List.iter
    (fun cost ->
      match Rhema_check.with_initial base "cost" cost with
      | Error _ -> ()
      | Ok spec -> (
          Random.init 1;
          match Rhema_engine.generate spec with
          | exception Rhema_engine.Generation_error _ -> ()
          | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)))
    [ 0; 4; 9 ];
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to per_budget - 1 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k (times k + 1);
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          match (whole q.Rhema_engine.answer, q.Rhema_engine.answers) with
          | None, _ | _, ([] | _ :: _ :: _) ->
              fail (Printf.sprintf "%s: one whole number was expected as the answer of %S" k p)
          | Some got, [ _ ] -> (
              match expected q with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | want, slips ->
                  if got <> want then fail (Printf.sprintf "%s: answer %d, recomputed %d, for %S" k got want p);
                  (* a question in which the mistake comes to the right number
                     is not to be asked: wrong working would be marked right *)
                  List.iter
                    (fun (name, slip) ->
                      if slip = want then
                        fail (Printf.sprintf "%s: %s gives the right answer %d, for %S" k name want p))
                    slips;
                  let listed = q.Rhema_engine.mistakes in
                  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
                  if names <> List.map fst slips then
                    fail
                      (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k (String.concat ", " names)
                         (String.concat ", " (List.map fst slips))
                         p);
                  List.iter
                    (fun (m : Rhema_engine.mistaken) ->
                      Hashtbl.replace made m.mistake ();
                      (* each mistake is described as itself, not as the other *)
                      let speaks_of part =
                        match Str.search_forward (Str.regexp_string part) m.description 0 with
                        | _ -> true
                        | exception Not_found -> false
                      in
                      if not (speaks_of (if m.mistake = "sets_swapped" then "the two sets" else "(a, a)")) then
                        fail (Printf.sprintf "%s is described as %S" m.mistake m.description);
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match whole value with
                          | Some wrong ->
                              if wrong <> slip then
                                fail (Printf.sprintf "%s: %s gives %d, recomputed %d, for %S" k m.mistake wrong slip p);
                              if wrong = got then
                                fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p)
                          | None -> fail (Printf.sprintf "%s: %s does not give a whole number, for %S" k m.mistake p))
                      | _, None -> ()
                      | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                    listed))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  (* at each price, a favoured form comes up more often than one that is not *)
  List.iter
    (fun (often, price) ->
      List.iter
        (fun (seldom, at) ->
          if at = price && List.mem often favoured && (not (List.mem seldom favoured)) && times often <= times seldom then
            fail (Printf.sprintf "%s came up %d times and %s %d times" often (times often) seldom (times seldom)))
        prices)
    prices;
  List.iter
    (fun mistake -> if not (Hashtbl.mem made mistake) then fail ("never listed: " ^ mistake))
    [ "sets_swapped"; "diagonal_forgotten" ];
  (* every choice the grammar offers came up, and nothing else *)
  let print numbers = "(" ^ String.concat ", " (List.map string_of_int numbers) ^ ")" in
  List.iter
    (fun (label, choices) ->
      List.iter
        (fun numbers -> if not (Hashtbl.mem asked (label, numbers)) then fail (label ^ ": never asked with " ^ print numbers))
        choices)
    offered;
  Hashtbl.iter
    (fun (label, numbers) () ->
      match List.assoc_opt label offered with
      | Some choices -> if not (List.mem numbers choices) then fail (label ^ ": asked with " ^ print numbers)
      | None -> fail ("nothing is known of what is offered for " ^ label))
    asked;
  if !failures = 0 then print_endline "Rhema relations tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d relations test(s) failed." !failures);
    exit 1
  end
