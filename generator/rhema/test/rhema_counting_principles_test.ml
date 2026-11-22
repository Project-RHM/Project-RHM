(* Independent checks for counting_principles.rhm. Every question is matched
   against the whole sentence of its form, the numbers are read back from it,
   and the answer is found again by brute force from the definitions, never
   by the formula the grammar uses:

   union_two         the three printed sizes are those of the footballers,
                     the chess players and those who play both. The class is
                     written out student by student: those who play both
                     first, then the rest of each game. The sets built must
                     have the printed sizes, and the students in either set
                     are counted. At least two play both (so that "play both"
                     reads well), and each game has somebody who plays it
                     alone.
   pigeonhole        "to be sure" is taken at its word. Every way of sharing
                     m socks among the k colours is written out (the counts
                     in non-increasing order, since the names of the colours
                     do not matter), and m is enough when every one of them
                     has a colour with at least r socks. The answer is the
                     least m that is enough, searched for from 0 upwards.
   divisible_either  every whole number from 1 to N is tried, and those that
                     a or b divides are counted. Neither of a and b divides
                     the other, and some number up to N is divisible by both.
   union_three       the seven printed numbers are turned into the seven
                     regions of the Venn diagram by subtraction: all three,
                     each two without the third, each language alone. No
                     region may be negative. The group is written out
                     student by student, region by region; the sets built
                     must have the seven printed sizes, and the students in
                     any of them are counted.
   stars_bars        the number of variables is read from the left side of
                     the printed equation; every tuple of that many whole
                     numbers from 0 to n is written out and those that add
                     up to n are counted.
   divisible_none    every whole number from 1 to N is tried, and those that
                     none of the three printed numbers divides are counted.
                     The three are different primes (by trial division), and
                     some number up to N is divisible by all three.
   bounded           every triple of whole numbers from 0 to m is written
                     out and those that add up to n are counted. There are
                     at least two, so that the answer is not the one solution
                     (m, m, m): 3m is above n. The limit matters as well:
                     without it there are more solutions.
   derangements      every permutation of the n letters is written out, and
                     the letters it leaves in their own envelopes are
                     counted. The sentence asks for one of three things, and
                     the permutations with no such letter, with exactly one,
                     or with at least one are counted. The two printed
                     numbers must be the same. Each of the three is asked
                     with every n from 4 to 7.

   The mistakes are found again by counting as well. overlap_counted_twice
   is the number of elements of each set, added up (union_two, union_three),
   or the multiples of a counted in one loop and those of b in another
   (divisible_either). triple_left_out is, for union_three, the sizes of the
   three sets less the students counted in each two of them, and for
   divisible_none N less the multiples of each prime plus the numbers that
   each two of the primes divide, all by loops. A question must list exactly
   the mistakes of its form, in the order they are declared, with these
   values, each of them another number than the right answer; a form with no
   mistake lists none. Each mistake is described as itself.

   Every kind must come up at its price and at no other, the budget must be
   spent, a budget outside 1 to 3 must give no question, and every answer
   must be one whole number. The numbers each form is asked with are pinned
   as well: every choice the grammar offers must come up, and nothing else.
   The weights of the forms are not pinned. *)

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

(* The numbers of a prompt: the pattern is the whole sentence, with a group
   wherever a number stands. A number is written without a sign and without
   a leading zero; no form prints a zero. *)
let words = Str.quote
let a_count = "\\([1-9][0-9]*\\)"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

let counts count pattern prompt = List.map int_of_string (fields count pattern prompt)

(* How many variables the left side of an equation has: x_1 + x_2 + ... + x_k,
   numbered in order from 1. *)
let variables left =
  let names = Str.split_delim (Str.regexp_string " + ") left in
  List.iteri
    (fun place name ->
      if name <> Printf.sprintf "x_%d" (place + 1) then failwith ("not a sum of x_1, x_2, ...: " ^ left))
    names;
  List.length names

(* ---- Counting by brute force ---- *)

let range first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)
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

(* Sets of labelled elements. The regions of a diagram are dealt out one
   after the other, so that no two of them share an element. *)
let regions sizes =
  if List.exists (fun size -> size < 0) sizes then failwith "a region with fewer than no elements";
  if sum sizes > 1000 then failwith "sets too large to write out";
  let _, dealt =
    List.fold_left
      (fun (next, dealt) size -> (next + size, List.init size (fun i -> next + i) :: dealt))
      (0, []) sizes
  in
  List.rev dealt

let size = List.length
let common xs ys = List.filter (fun x -> List.mem x ys) xs
let together sets = List.sort_uniq compare (List.concat sets)

(* How many of the whole numbers from 1 to `limit` pass a test. *)
let numbers_that =
  fun limit test ->
    if limit > 100000 then failwith "too many numbers to try each";
    let found = ref 0 in
    for n = 1 to limit do
      if test n then incr found
    done;
    !found

let divides d n = n mod d = 0
let is_prime p = p >= 2 && List.for_all (fun d -> not (divides d p)) (range 2 (p - 1))

(* Every way of sharing m socks among k colours, as the numbers of socks of
   each colour from the most to the least; `most` is the largest number a
   colour may still have. *)
let rec shares m k most =
  if k = 0 then if m = 0 then [ [] ] else []
  else if m > k * most then []
  else
    List.concat_map
      (fun first -> List.map (fun rest -> first :: rest) (shares (m - first) (k - 1) first))
      (range 0 (min m most))

(* m socks are enough when, however they fall among the k colours, some
   colour has at least r of them. *)
let enough ~colours ~wanted m = List.for_all (List.exists (fun socks -> socks >= wanted)) (shares m colours m)

(* The fewest socks that are enough. *)
let fewest_socks =
  memo (fun (colours, wanted) ->
      if colours < 1 || colours > 8 || wanted < 1 || wanted > 7 then failwith "too many socks to share out every way";
      let rec search m =
        if m > (colours * wanted) + 1 then failwith "no number of socks is enough"
        else if enough ~colours ~wanted m then m
        else search (m + 1)
      in
      search 0)

(* Every tuple of k whole numbers from 0 to `largest`. *)
let rec tuples k largest =
  if k = 0 then [ [] ]
  else List.concat_map (fun rest -> List.map (fun x -> x :: rest) (range 0 largest)) (tuples (k - 1) largest)

(* The tuples of k whole numbers from 0 to `largest` that add up to `total`. *)
let solutions =
  memo (fun (k, largest, total) ->
      if k < 1 || k > 5 || largest < 0 || largest > 12 then failwith "too many tuples to write out";
      size (List.filter (fun tuple -> sum tuple = total) (tuples k largest)))

let rec permutations = function
  | [] -> [ [] ]
  | items ->
      List.concat_map
        (fun first -> List.map (fun rest -> first :: rest) (permutations (List.filter (fun x -> x <> first) items)))
        items

(* What a question about letters and envelopes asks for: how many letters
   are in their own envelope. *)
type in_place = Nobody | Exactly_one | At_least_one

(* The ways of putting n letters into n envelopes, the letter at place i into
   the envelope the permutation names there, in which as many letters as
   asked are in their own envelope. *)
let ways_with =
  memo (fun (n, asked) ->
      if n < 1 || n > 8 then failwith "too many letters to write out every way";
      let own = range 1 n in
      let in_place envelopes =
        size (List.filter Fun.id (List.map2 (fun letter envelope -> letter = envelope) own envelopes))
      in
      let wanted envelopes =
        match asked with
        | Nobody -> in_place envelopes = 0
        | Exactly_one -> in_place envelopes = 1
        | At_least_one -> in_place envelopes >= 1
      in
      size (List.filter wanted (permutations own)))

(* ---- What each form was asked with ---- *)

let asked : (string * int list, unit) Hashtbl.t = Hashtbl.create 1024
let note label numbers = Hashtbl.replace asked (label, numbers) ()

(* Every choice the grammar offers, form by form. *)
let offered =
  let one values = List.map (fun value -> [ value ]) values in
  let tens = List.map (fun n -> 10 * n) (range 5 30) in
  [ ("union_two, football alone", one (range 3 15));
    ("union_two, chess alone", one (range 3 15));
    ("union_two, both", one (range 2 9));
    ("pigeonhole", List.concat_map (fun k -> List.map (fun r -> [ k; r ]) (range 2 6)) (range 3 7));
    (* N is a number of tens from 50 to 300; a is below b, both at most 9,
       neither divides the other and some number up to N is divisible by both *)
    ( "divisible_either",
      List.concat_map
        (fun limit ->
          List.concat_map
            (fun a ->
              List.filter_map
                (fun b ->
                  if (not (divides a b)) && numbers_that limit (fun n -> divides a n && divides b n) >= 1 then
                    Some [ limit; a; b ]
                  else None)
                (range (a + 1) 9))
            (range 2 9))
        tens );
    ("union_three, French alone", one (range 1 9));
    ("union_three, German alone", one (range 1 9));
    ("union_three, Spanish alone", one (range 1 9));
    ("union_three, French and German alone", one (range 0 4));
    ("union_three, French and Spanish alone", one (range 0 4));
    ("union_three, German and Spanish alone", one (range 0 4));
    ("union_three, all three", one (range 2 4));
    ("stars_bars", List.concat_map (fun k -> List.map (fun n -> [ k; n ]) (range 4 10)) [ 3; 4 ]);
    (* three of 2, 3, 5 and 7 in order, and N a number of tens that some
       number divisible by all three is not above *)
    ( "divisible_none",
      List.concat_map
        (fun limit ->
          List.filter_map
            (fun primes ->
              if numbers_that limit (fun n -> List.for_all (fun p -> divides p n) primes) >= 1 then Some (limit :: primes)
              else None)
            [ [ 2; 3; 5 ]; [ 2; 3; 7 ]; [ 2; 5; 7 ]; [ 3; 5; 7 ] ])
        tens );
    (* n from 6 to 12 and a limit from 3 to 7 that leaves more than one
       solution and rules one out *)
    ( "bounded",
      List.concat_map
        (fun n ->
          List.filter_map
            (fun m ->
              let within = solutions (3, m, n) in
              if within >= 2 && within < solutions (3, n, n) then Some [ n; m ] else None)
            (range 3 7))
        (range 6 12) );
    (* each of the three things asked (0 none, 1 exactly one, 2 at least
       one letter in its own envelope) with every n from 4 to 7 *)
    ("derangements", List.concat_map (fun n -> List.map (fun asked -> [ n; asked ]) [ 0; 1; 2 ]) (range 4 7)) ]

(* ---- The answer of each form, found again ---- *)

let up_to_n = words "How many of the whole numbers from [`1`] to [`" ^ a_count ^ words "`] are divisible by "

(* The right answer of a question, and the answer of each mistake that its
   form is open to, all found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "union_two" -> (
      match
        counts 3
          (words "In a class, [`" ^ a_count ^ words "`] students play football, [`" ^ a_count
          ^ words "`] play chess and [`" ^ a_count
          ^ words "`] play both. How many play at least one of the two?")
          p
      with
      | [ football; chess; both ] -> (
          if both < 2 then failwith "fewer than two play both";
          if both > football || both > chess then failwith "more play both than play one of the games";
          if both = football || both = chess then failwith "nobody plays one of the games alone";
          match regions [ both; football - both; chess - both ] with
          | [ shared; football_alone; chess_alone ] ->
              let footballers = shared @ football_alone and chess_players = shared @ chess_alone in
              if
                size footballers <> football || size chess_players <> chess
                || size (common footballers chess_players) <> both
              then failwith "the class built does not have the printed sizes";
              note "union_two, football alone" [ size football_alone ];
              note "union_two, chess alone" [ size chess_alone ];
              note "union_two, both" [ both ];
              ( size (together [ footballers; chess_players ]),
                [ ("overlap_counted_twice", size footballers + size chess_players) ] )
          | _ -> failwith "three regions were expected")
      | _ -> failwith "three numbers were expected")
  | "pigeonhole" -> (
      match
        counts 2
          (words "A drawer holds many socks of each of [`" ^ a_count
          ^ words "`] colours. How many socks must be taken out, without looking, to be sure of having at least [`"
          ^ a_count ^ words "`] of the same colour?")
          p
      with
      | [ colours; wanted ] ->
          note "pigeonhole" [ colours; wanted ];
          let fewest = fewest_socks (colours, wanted) in
          (* said the other way round: one sock fewer may still fall short,
             and no sock more is ever needed *)
          if fewest < 1 || enough ~colours ~wanted (fewest - 1) || not (enough ~colours ~wanted (fewest + 1)) then
            failwith "the search for the fewest socks went wrong";
          (fewest, [])
      | _ -> failwith "two numbers were expected")
  | "divisible_either" -> (
      match counts 3 (up_to_n ^ words "[`" ^ a_count ^ words "`] or by [`" ^ a_count ^ words "`]?") p with
      | [ limit; a; b ] ->
          note "divisible_either" [ limit; a; b ];
          if divides a b || divides b a then failwith "one of the two numbers divides the other";
          if numbers_that limit (fun n -> divides a n && divides b n) < 1 then
            failwith "no number in the range is divisible by both";
          ( numbers_that limit (fun n -> divides a n || divides b n),
            [ ("overlap_counted_twice", numbers_that limit (divides a) + numbers_that limit (divides b)) ] )
      | _ -> failwith "three numbers were expected")
  | "union_three" -> (
      match
        counts 7
          (words "In a group of students, [`" ^ a_count ^ words "`] study French, [`" ^ a_count
          ^ words "`] study German and [`" ^ a_count ^ words "`] study Spanish; [`" ^ a_count
          ^ words "`] study both French and German, [`" ^ a_count ^ words "`] both French and Spanish, [`" ^ a_count
          ^ words "`] both German and Spanish, and [`" ^ a_count
          ^ words "`] study all three. How many study at least one of the three languages?")
          p
      with
      | [ french; german; spanish; french_german; french_spanish; german_spanish; all_three ] -> (
          if all_three < 2 then failwith "fewer than two study all three";
          (* the regions, from the middle of the diagram outwards *)
          let fg = french_german - all_three and fs = french_spanish - all_three and gs = german_spanish - all_three in
          let f = french - fg - fs - all_three and g = german - fg - gs - all_three and s = spanish - fs - gs - all_three in
          match regions [ all_three; fg; fs; gs; f; g; s ] with
          | [ in_all; in_fg; in_fs; in_gs; in_f; in_g; in_s ] ->
              let studies_french = together [ in_all; in_fg; in_fs; in_f ]
              and studies_german = together [ in_all; in_fg; in_gs; in_g ]
              and studies_spanish = together [ in_all; in_fs; in_gs; in_s ] in
              let fg_both = common studies_french studies_german
              and fs_both = common studies_french studies_spanish
              and gs_both = common studies_german studies_spanish in
              if
                [ size studies_french; size studies_german; size studies_spanish; size fg_both; size fs_both;
                  size gs_both; size (common fg_both studies_spanish) ]
                <> [ french; german; spanish; french_german; french_spanish; german_spanish; all_three ]
              then failwith "the group built does not have the printed sizes";
              note "union_three, French alone" [ size in_f ];
              note "union_three, German alone" [ size in_g ];
              note "union_three, Spanish alone" [ size in_s ];
              note "union_three, French and German alone" [ size in_fg ];
              note "union_three, French and Spanish alone" [ size in_fs ];
              note "union_three, German and Spanish alone" [ size in_gs ];
              note "union_three, all three" [ size in_all ];
              let sizes_added = size studies_french + size studies_german + size studies_spanish in
              ( size (together [ studies_french; studies_german; studies_spanish ]),
                [ ("overlap_counted_twice", sizes_added);
                  ("triple_left_out", sizes_added - size fg_both - size fs_both - size gs_both) ] )
          | _ -> failwith "seven regions were expected")
      | _ -> failwith "seven numbers were expected")
  | "stars_bars" -> (
      match
        fields 2
          (words "How many solutions in non-negative whole numbers does [`" ^ "\\([^`=]*\\) = " ^ a_count
         ^ words "`] have?")
          p
      with
      | [ left; total ] ->
          let k = variables left and n = int_of_string total in
          note "stars_bars" [ k; n ];
          (* no variable of a solution is above the total *)
          (solutions (k, n, n), [])
      | _ -> failwith "a left side and a total were expected")
  | "divisible_none" -> (
      match
        counts 4
          (up_to_n ^ words "none of [`" ^ a_count ^ words "`], [`" ^ a_count ^ words "`] and [`" ^ a_count ^ words "`]?")
          p
      with
      | [ limit; a; b; c ] ->
          note "divisible_none" [ limit; a; b; c ];
          if not (is_prime a && is_prime b && is_prime c) then failwith "one of the three numbers is not a prime";
          if a = b || a = c || b = c then failwith "two of the three primes are the same";
          if numbers_that limit (fun n -> divides a n && divides b n && divides c n) < 1 then
            failwith "no number in the range is divisible by all three";
          let by d = numbers_that limit (divides d) in
          let by_both d e = numbers_that limit (fun n -> divides d n && divides e n) in
          ( numbers_that limit (fun n -> not (divides a n || divides b n || divides c n)),
            [ ("triple_left_out", limit - by a - by b - by c + by_both a b + by_both a c + by_both b c) ] )
      | _ -> failwith "four numbers were expected")
  | "bounded" -> (
      match
        counts 2
          (words "How many solutions in whole numbers does [`x_1 + x_2 + x_3 = " ^ a_count
          ^ words "`] have with [`0 \\le x_i \\le " ^ a_count ^ words "`] for each [`i`]?")
          p
      with
      | [ n; m ] ->
          note "bounded" [ n; m ];
          let within = solutions (3, m, n) in
          if within < 1 then failwith "there is no solution";
          (* with 3m = n the one solution is (m, m, m), and nothing is counted *)
          if 3 * m <= n || within < 2 then failwith "there is one solution only";
          if within >= solutions (3, n, n) then failwith "the limit rules no solution out";
          (within, [])
      | _ -> failwith "two numbers were expected")
  | "derangements" -> (
      match
        fields 3
          (words "[`" ^ a_count ^ words "`] letters are put into [`" ^ a_count
          ^ words "`] addressed envelopes, one in each, at random. In how many ways can it happen that "
          ^ "\\(no letter is\\|exactly one letter is\\|at least one letter is\\)"
          ^ words " in its own envelope?")
          p
      with
      | [ letters; envelopes; asked ] ->
          let letters = int_of_string letters in
          if letters <> int_of_string envelopes then failwith "not as many envelopes as letters";
          let asked, name =
            match asked with
            | "no letter is" -> (Nobody, 0)
            | "exactly one letter is" -> (Exactly_one, 1)
            | "at least one letter is" -> (At_least_one, 2)
            | other -> failwith ("nothing is known of the question: " ^ other)
          in
          note "derangements" [ letters; name ];
          (ways_with (letters, asked), [])
      | _ -> failwith "two numbers and what is asked were expected")
  | k -> failwith ("unknown kind " ^ k)

(* How many questions are made at each budget. Budget 2 has the form with
   the most choices to come up one by one (divisible_either, more than 500
   of them), and is given three times as many. *)
let questions_at cost = if cost = 2 then 60000 else 20000

let () =
  let base = load_file "counting_principles.rhm" in
  let prices =
    [ ("union_two", 1); ("pigeonhole", 1); ("divisible_either", 2); ("union_three", 2); ("stars_bars", 2);
      ("divisible_none", 3); ("bounded", 3); ("derangements", 3) ]
  in
  (* what the description of each mistake must speak of *)
  let spoken = [ ("overlap_counted_twice", "adds the sizes"); ("triple_left_out", "leaves out what all three share") ] in
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
    [ -1; 0; 4; 5; 6; 9 ];
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at cost - 1 do
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
              if whole (Rhema_engine.attribute q.Rhema_engine.tree "answer_value") <> Some got then
                fail (Printf.sprintf "%s: the answer is not the answer_value of the question, for %S" k p);
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
                      Hashtbl.replace made (m.mistake, k) ();
                      (* each mistake is described as itself, not as the other *)
                      let speaks_of part =
                        match Str.search_forward (Str.regexp_string part) m.description 0 with
                        | _ -> true
                        | exception Not_found -> false
                      in
                      (match List.assoc_opt m.mistake spoken with
                      | Some part ->
                          if not (speaks_of part) then fail (Printf.sprintf "%s is described as %S" m.mistake m.description)
                      | None -> fail ("an unknown mistake is listed: " ^ m.mistake));
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
  Hashtbl.iter (fun k _ -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  List.iter
    (fun (mistake, k) ->
      if not (Hashtbl.mem made (mistake, k)) then fail (Printf.sprintf "%s never listed on %s" mistake k))
    [ ("overlap_counted_twice", "union_two"); ("overlap_counted_twice", "divisible_either");
      ("overlap_counted_twice", "union_three"); ("triple_left_out", "union_three"); ("triple_left_out", "divisible_none") ];
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
  if !failures = 0 then print_endline "Rhema counting_principles tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d counting_principles test(s) failed." !failures);
    exit 1
  end
