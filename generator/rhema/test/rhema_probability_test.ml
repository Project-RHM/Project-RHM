(* Independent checks for probability.rhm. Every question is matched against
   the whole sentence of its form, the numbers are read back from it, and the
   answer is found again by counting outcomes, in exact fractions:

   - union: the two events are laid out on a row of equally likely outcomes
     (as many as the common denominator of the three probabilities), so that
     they share what the question says they share, and the outcomes in A or
     in B are counted. The layout exists only if the three probabilities are
     consistent.
   - conditional_formula: the same row, with the overlap searched for until
     the outcomes in A or in B are as many as the question says; exactly one
     overlap must do. The answer is the share of B that lies in A.
   - independent, at_least_one: a grid with one row for each outcome of the
     first experiment and one column for each outcome of the second; the
     cells where both events happen, or at least one, are counted.
   - conditional_table: the class is written out student by student, the
     students the question describes are kept, and the girls among them are
     counted. Knowing whether the student plays chess must change the
     probability.
   - total_probability, bayes: every face of the die is followed by every
     ball of the bag it chooses, each ball weighted so that the six faces
     are equally likely, and the weights are added up. The two bags must
     hold red in different shares, and the die must be able to choose both.

   Each answer must be a probability strictly between 0 and 1. The mistakes
   are found again in the same way: overlap_counted_twice counts the outcomes
   of A and those of B and adds them; wrong_way_round takes the same outcomes
   as the answer out of the other group (the girls, the event A, bag 1). Each
   question must list exactly the mistake of its form, with that value,
   unless the value happens to be the right answer: the mistake is then not
   listed at all. A form with no mistake lists none. *)

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

(* A fraction in lowest terms, with a positive denominator. *)
type fraction = { top : int; bottom : int }

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let ratio top bottom =
  if bottom <= 0 then failwith "a share of nothing";
  let divisor = gcd top bottom in
  { top = top / divisor; bottom = bottom / divisor }

let is_probability x = 0 < x.top && x.top < x.bottom
let print x = Printf.sprintf "%d/%d" x.top x.bottom

let number = function
  | Rhema_engine.Num n -> Some { top = n.Rhema_number.numerator; bottom = n.Rhema_number.denominator }
  | _ -> None

(* The numbers of a prompt: the pattern is the whole sentence, with a group
   wherever a number stands. *)
let words = Str.quote
let a_number = "\\([^`]*\\)"
let a_count = "\\([0-9]+\\)"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* A probability as number_latex writes it, \frac{a}{b}: in lowest terms and
   strictly between 0 and 1. *)
let probability text =
  if not (Str.string_match (Str.regexp "^\\\\frac{\\([0-9]+\\)}{\\([0-9]+\\)}$") text 0) then
    failwith ("not a fraction: " ^ text);
  let top = int_of_string (Str.matched_group 1 text) and bottom = int_of_string (Str.matched_group 2 text) in
  if gcd top bottom <> 1 then failwith ("not in lowest terms: " ^ text);
  let value = ratio top bottom in
  if not (is_probability value) then failwith ("not strictly between 0 and 1: " ^ text);
  value

(* How many of the outcomes 0 .. size - 1 pass the test. *)
let count size test =
  let found = ref 0 in
  for outcome = 0 to size - 1 do
    if test outcome then incr found
  done;
  !found

(* Two events on a row of `size` equally likely outcomes: A is the first
   `in_a` of them, and B is `in_b` outcomes in a row, of which the first
   `shared` are the last of A. None if they do not fit. *)
let layout ~size ~in_a ~in_b ~shared =
  let start = in_a - shared in
  if shared < 0 || start < 0 || shared > in_b || start + in_b > size then None
  else Some ((fun outcome -> outcome < in_a), fun outcome -> outcome >= start && outcome < start + in_b)

(* As many outcomes as make every probability a whole number of them. *)
let common_size probabilities =
  List.fold_left (fun size x -> size * x.bottom / gcd size x.bottom) 1 probabilities

let outcomes size x = x.top * (size / x.bottom)

(* Every way the experiment of the two bags can go: a face of the die, then a
   ball of the bag that face chooses, as (bag, red, weight). A ball of bag 1
   weighs as many as bag 2 holds, and the other way round, so that the weights
   are whole and every face weighs the same. *)
let draws ~faces (red1, blue1) (red2, blue2) =
  let bag name (red, blue) weight =
    List.init red (fun _ -> (name, true, weight)) @ List.init blue (fun _ -> (name, false, weight))
  in
  List.concat
    (List.init 6 (fun face ->
         if face + 1 <= faces then bag 1 (red1, blue1) (red2 + blue2) else bag 2 (red2, blue2) (red1 + blue1)))

let weight test all = List.fold_left (fun total ((_, _, w) as draw) -> if test draw then total + w else total) 0 all

(* The chance of `event` among the draws that pass `given`. *)
let chance event given all = ratio (weight (fun draw -> event draw && given draw) all) (weight given all)

let is_red (_, red, _) = red
let from_bag name (bag, _, _) = bag = name
let any _ = true

let two_events_start = words "Two events [`A`] and [`B`] have [`P(A) = " ^ a_number ^ words "`], [`P(B) = " ^ a_number
let independent_start =
  words "The events [`A`] and [`B`] are independent, with [`P(A) = " ^ a_number ^ words "`] and [`P(B) = " ^ a_number
  ^ words "`]. "

let bags_start =
  words "Bag 1 holds [`" ^ a_count ^ words "`] red and [`" ^ a_count ^ words "`] blue balls, and bag 2 holds [`" ^ a_count
  ^ words "`] red and [`" ^ a_count ^ words "`] blue balls. A fair die is rolled: if it shows [`" ^ a_count ^ words "`]"
  ^ "\\(\\| or less\\)" ^ words ", a ball is drawn at random from bag 1, and otherwise from bag 2. "

(* The draws of a bag question, from the six groups of `bags_start`. *)
let bags = function
  | [ red1; blue1; red2; blue2; faces; or_less ] ->
      let faces = int_of_string faces in
      if faces < 1 || faces > 5 then failwith "the die cannot choose both bags";
      if (faces = 1) <> (or_less = "") then failwith "the die is not read as it is written";
      let all =
        draws ~faces (int_of_string red1, int_of_string blue1) (int_of_string red2, int_of_string blue2)
      in
      if chance is_red (from_bag 1) all = chance is_red (from_bag 2) all then
        failwith "the two bags hold red in the same share";
      all
  | _ -> failwith "six numbers were expected"

(* The right answer of a question, and the answer of each mistake that its
   form is open to, all found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "union" -> (
      match
        List.map probability
          (fields 3 (two_events_start ^ words "`] and [`P(A \\cap B) = " ^ a_number ^ words "`]. Find [`P(A \\cup B)`].") p)
      with
      | [ a; b; both ] as shown -> (
          let size = common_size shown in
          match layout ~size ~in_a:(outcomes size a) ~in_b:(outcomes size b) ~shared:(outcomes size both) with
          | None -> failwith "the three probabilities are not consistent"
          | Some (in_a, in_b) ->
              ( ratio (count size (fun o -> in_a o || in_b o)) size,
                [ ("overlap_counted_twice", ratio (count size in_a + count size in_b) size) ] ))
      | _ -> failwith "three probabilities were expected")
  | "conditional_formula" -> (
      match
        List.map probability
          (fields 3 (two_events_start ^ words "`] and [`P(A \\cup B) = " ^ a_number ^ words "`]. Find [`P(A \\mid B)`].") p)
      with
      | [ a; b; either ] as shown -> (
          let size = common_size shown in
          let in_a = outcomes size a and in_b = outcomes size b in
          let fits shared =
            match layout ~size ~in_a ~in_b ~shared with
            | Some (in_a, in_b) when count size (fun o -> in_a o || in_b o) = outcomes size either -> Some (in_a, in_b)
            | _ -> None
          in
          match List.filter_map fits (List.init (min in_a in_b + 1) Fun.id) with
          | [ (in_a, in_b) ] ->
              let both = count size (fun o -> in_a o && in_b o) in
              (ratio both (count size in_b), [ ("wrong_way_round", ratio both (count size in_a)) ])
          | _ -> failwith "the three probabilities are not consistent")
      | _ -> failwith "three probabilities were expected")
  | ("independent" | "at_least_one") as k -> (
      let both = k = "independent" in
      let asked =
        if both then "Find the probability that both happen."
        else "Find the probability that at least one of them happens."
      in
      match List.map probability (fields 2 (independent_start ^ words asked) p) with
      | [ a; b ] ->
          (* the cell (row, column) is in A when its row is one of the first
             a.top, and in B when its column is one of the first b.top *)
          let cells test =
            List.fold_left ( + ) 0
              (List.init a.bottom (fun row -> count b.bottom (fun column -> test (row < a.top) (column < b.top))))
          in
          let all = a.bottom * b.bottom in
          if both then (ratio (cells ( && )) all, [])
          else
            ( ratio (cells ( || )) all,
              [ ("overlap_counted_twice", ratio (cells (fun in_a _ -> in_a) + cells (fun _ in_b -> in_b)) all) ] )
      | _ -> failwith "two probabilities were expected")
  | "conditional_table" -> (
      match
        fields 5
          (words "In a class, [`" ^ a_count ^ words "`] boys play chess and [`" ^ a_count ^ words "`] boys do not; [`"
         ^ a_count ^ words "`] girls play chess and [`" ^ a_count
         ^ words "`] girls do not. A student chosen at random "
         ^ "\\(plays chess\\|does not play chess\\)"
         ^ words ". Find the probability that the student is a girl.")
          p
      with
      | [ boys_play; boys_do_not; girls_play; girls_do_not; known ] ->
          (* a student is (girl, plays chess) *)
          let some text student = List.init (int_of_string text) (fun _ -> student) in
          let students =
            some boys_play (false, true) @ some boys_do_not (false, false) @ some girls_play (true, true)
            @ some girls_do_not (true, false)
          in
          let share test among = ratio (List.length (List.filter test among)) (List.length among) in
          let is_girl (girl, _) = girl and as_known (_, plays) = plays = (known = "plays chess") in
          let right = share is_girl (List.filter as_known students) in
          if right = share is_girl students then failwith "knowing about chess changes nothing";
          (right, [ ("wrong_way_round", share as_known (List.filter is_girl students)) ])
      | _ -> failwith "five fields were expected")
  | "total_probability" ->
      let all = bags (fields 6 (bags_start ^ words "Find the probability that the ball is red.") p) in
      (chance is_red any all, [])
  | "bayes" ->
      let all =
        bags (fields 6 (bags_start ^ words "The ball is red. Find the probability that it came from bag 1.") p)
      in
      (chance (from_bag 1) is_red all, [ ("wrong_way_round", chance is_red (from_bag 1) all) ])
  | k -> failwith ("unknown kind " ^ k)

let () =
  let base = load_file "probability.rhm" in
  let prices =
    [ ("union", 1); ("independent", 1); ("conditional_table", 2); ("conditional_formula", 2); ("at_least_one", 2);
      ("total_probability", 3); ("bayes", 3) ]
  in
  let seen = Hashtbl.create 8 and made = Hashtbl.create 2 and wordings = Hashtbl.create 4 in
  let contains text part =
    match Str.search_forward (Str.regexp_string part) text 0 with _ -> true | exception Not_found -> false
  in
  let asked_both_ways = [ "random plays chess"; "random does not play chess"; "shows [`1`],"; "or less" ] in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          (* the table is asked both ways, and the die is read both ways *)
          List.iter
            (fun part -> if contains p part then Hashtbl.replace wordings part ())
            asked_both_ways;
          match (number q.Rhema_engine.answer, q.Rhema_engine.answers) with
          | None, _ | _, ([] | _ :: _ :: _) -> fail (Printf.sprintf "%s: one number was expected as the answer of %S" k p)
          | Some got, [ _ ] -> (
              if not (is_probability got) then
                fail (Printf.sprintf "%s: the answer %s is not strictly between 0 and 1, for %S" k (print got) p);
              match expected q with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | want, slips ->
                  (* the grammar does not ask a question in which the wrong way
                     round comes to the right number: wrong working would be
                     marked right *)
                  List.iter
                    (fun (name, slip) ->
                      if name = "wrong_way_round" && slip = want then
                        fail (Printf.sprintf "%s: the wrong way round gives the right answer %s, for %S" k (print want) p))
                    slips;
                  let slips = List.filter (fun (_, slip) -> slip <> want) slips in
                  if got <> want then
                    fail (Printf.sprintf "%s: answer %s, recomputed %s, for %S" k (print got) (print want) p);
                  let listed = q.Rhema_engine.mistakes in
                  if List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed <> List.map fst slips then
                    fail
                      (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k
                         (String.concat ", " (List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed))
                         (String.concat ", " (List.map fst slips))
                         p);
                  List.iter
                    (fun (m : Rhema_engine.mistaken) ->
                      Hashtbl.replace made m.mistake ();
                      if m.description = "" then fail (m.mistake ^ " has no description");
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match number value with
                          | Some wrong ->
                              if wrong <> slip then
                                fail
                                  (Printf.sprintf "%s: %s gives %s, recomputed %s, for %S" k m.mistake (print wrong)
                                     (print slip) p);
                              if wrong = got then
                                fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p)
                          | None -> fail (Printf.sprintf "%s: %s does not give a number, for %S" k m.mistake p))
                      | _, None -> ()
                      | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                    listed))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  List.iter
    (fun mistake -> if not (Hashtbl.mem made mistake) then fail ("never listed: " ^ mistake))
    [ "overlap_counted_twice"; "wrong_way_round" ];
  List.iter
    (fun part -> if not (Hashtbl.mem wordings part) then fail ("never worded: " ^ part))
    asked_both_ways;
  if !failures = 0 then print_endline "Rhema probability tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d probability test(s) failed." !failures);
    exit 1
  end
