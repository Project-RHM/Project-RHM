(* Independent checks for markov_chain.rhm. Every question is matched against
   the whole sentence of its form, the probabilities, the states and the
   matrix are read back from it, and the answer is found again here, on exact
   fractions, without the formulas of the grammar:

   - path, two_days, three_days: the two printed probabilities make a chain
     with two states. Every sequence of days of the right length is written
     out, each weighted by the product of its steps from today's weather, and
     the weights of the sequences that end as the question asks (for path:
     the one sequence asked for) are added up.
   - forecast: the same, over the sequences of two days that start today,
     with today's weather weighted by the printed forecast.
   - long_run: the balance equations (the share of sunny days is left as it
     is by one more day, and the two shares add up to one) are solved as a
     linear system by Gaussian elimination. The engine's share must also
     satisfy s = s * stay + (1 - s) * turn, and the chain followed for 200
     days in floats, from a sunny day and from a rainy one, must come within
     1e-9 of it.
   - run_length: the series n * P(the run has n days) is added up in floats
     until it has converged and must come within 1e-9 of the answer, which
     must also satisfy E = 1 + p E exactly, p being the probability that the
     weather stays as it is; that equation is solved for the expected value.
   - matrix_two_steps: the matrix is read from its pmatrix. Every row must
     hold three whole numbers of quarters between 0 and 1 that add up to 1.
     Every path of two steps from the state now to the state asked for is
     written out and the products are added up. The mistake `transposed` is
     the same sum on the matrix with rows and columns exchanged; it must be
     listed with that value, which must not be the right answer. The two
     states differ, and the answer is not the entry of the printed matrix in
     the row of the state now and the column of the state asked for (one
     step read off the matrix).
   - ruin: the chances h_1 .. h_(n-1) of stopping at the top are the solution
     of h_i = p h_(i+1) + (1 - p) h_(i-1) with h_0 = 0 and h_n = 1, solved by
     Gaussian elimination. The walk is also followed step by step in floats
     and the weight stopped at the top must come within 1e-9 of the answer.

   Every probability answer lies strictly between 0 and 1, and a run is
   longer than one day on average. The two probabilities of the story are
   different fractions in lowest terms strictly between 0 and 1. Each kind
   appears at its price and at no other, no other kind appears, a budget
   outside 1..3 gives no question, and every choice the grammar offers (each
   weather in each place, each fraction, each row of quarters, each pair of
   states, each line and start) is seen at least once. Only matrix_two_steps
   lists a mistake, described as reading the matrix the wrong way round. *)

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

(* Fractions on OCaml integers, in lowest terms with a positive denominator,
   so that two equal fractions are equal as records. The numbers of these
   questions are small. *)
type fraction = { top : int; bottom : int }

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let fraction top bottom =
  if bottom = 0 then failwith "division by zero";
  let top, bottom = if bottom < 0 then (-top, -bottom) else (top, bottom) in
  let divisor = gcd top bottom in
  { top = top / divisor; bottom = bottom / divisor }

let whole n = { top = n; bottom = 1 }
let zero = whole 0
let one = whole 1
let ( +: ) a b = fraction ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( -: ) a b = fraction ((a.top * b.bottom) - (b.top * a.bottom)) (a.bottom * b.bottom)
let ( *: ) a b = fraction (a.top * b.top) (a.bottom * b.bottom)
let ( /: ) a b = fraction (a.top * b.bottom) (a.bottom * b.top)
let sign a = compare a.top 0
let less a b = sign (a -: b) < 0
let is_probability x = less zero x && less x one
let to_float a = float a.top /. float a.bottom
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom
let close x y = Float.abs (x -. y) <= 1e-9

let number = function
  | Rhema_engine.Num n -> Some (fraction n.Rhema_number.numerator n.Rhema_number.denominator)
  | _ -> None

(* The fields of a prompt: the pattern is the whole sentence, with a group
   wherever a number or a word of the question stands. *)
let words = Str.quote
let a_number = "\\([^`]*\\)"
let a_count = "\\([0-9]+\\)"
let a_weather = "\\(sunny\\|rainy\\)"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* A number as number_latex writes it: a whole number bare, a fraction as
   \frac{a}{b} in lowest terms. None of these questions prints a negative
   number. *)
let printed_number text =
  if Str.string_match (Str.regexp "^\\\\frac{\\([0-9]+\\)}{\\([0-9]+\\)}$") text 0 then begin
    let top = int_of_string (Str.matched_group 1 text) and bottom = int_of_string (Str.matched_group 2 text) in
    if bottom < 2 || gcd top bottom <> 1 then failwith ("not in lowest terms: " ^ text);
    fraction top bottom
  end
  else if Str.string_match (Str.regexp "^[0-9]+$") text 0 then whole (int_of_string text)
  else failwith ("cannot read the number " ^ text)

(* A probability of the stories: strictly between 0 and 1. *)
let probability text =
  let value = printed_number text in
  if not (is_probability value) then failwith ("not strictly between 0 and 1: " ^ text);
  value

(* The solution of a square system of linear equations, by Gaussian
   elimination on fractions: `rows` times the unknowns is `right`. The system
   must have exactly one solution. *)
let solve rows right =
  let n = Array.length rows in
  let table = Array.init n (fun i -> Array.append rows.(i) [| right.(i) |]) in
  for column = 0 to n - 1 do
    let pivot = ref column in
    while !pivot < n && sign table.(!pivot).(column) = 0 do
      incr pivot
    done;
    if !pivot = n then failwith "the equations do not have exactly one solution";
    let row = table.(!pivot) in
    table.(!pivot) <- table.(column);
    table.(column) <- row;
    let lead = row.(column) in
    Array.iteri (fun j x -> row.(j) <- x /: lead) row;
    for other = 0 to n - 1 do
      let factor = table.(other).(column) in
      if other <> column && sign factor <> 0 then
        Array.iteri (fun j x -> table.(other).(j) <- x -: (factor *: row.(j))) table.(other)
    done
  done;
  Array.init n (fun i -> table.(i).(n))

(* ---- The weather: a chain with two states -------------------------------- *)

(* `after_sunny` and `after_rainy` are the probabilities of a sunny day after
   a sunny day and after a rainy one, as the story prints them. A day is true
   when it is sunny. *)
type weather = { after_sunny : fraction; after_rainy : fraction }

let is_sunny word = word = "sunny"

(* The probability that the day after `today` is `next`. *)
let step chain today next =
  let sunny = if today then chain.after_sunny else chain.after_rainy in
  if next then sunny else one -: sunny

(* Every sequence of `days` days. *)
let rec sequences days =
  if days = 0 then [ [] ] else List.concat_map (fun rest -> [ true :: rest; false :: rest ]) (sequences (days - 1))

(* The probability that the days after `today` are exactly `following`. *)
let weight chain today following =
  fst (List.fold_left (fun (product, from) day -> (product *: step chain from day, day)) (one, today) following)

(* The probability, from today's weather, that the next `days` days pass the
   test: the weights of all the sequences that pass it. *)
let chance chain today days test =
  let all = sequences days in
  if List.fold_left (fun total s -> total +: weight chain today s) zero all <> one then
    failwith "the sequences of days do not add up to 1";
  List.fold_left (fun total s -> if test s then total +: weight chain today s else total) zero all

let last days = List.nth days (List.length days - 1)

(* What was generated besides the kinds: every word, fraction, state and
   line that the grammar can choose. *)
let noted = Hashtbl.create 64
let note what = Hashtbl.replace noted what ()

let story =
  words "Each day in a town is sunny or rainy. After a sunny day the next day is sunny with probability [`" ^ a_number
  ^ words "`], and after a rainy day the next day is sunny with probability [`" ^ a_number ^ words "`]."

(* The chain of a story, from its two printed probabilities. *)
let weather after_sunny after_rainy =
  let chain = { after_sunny = probability after_sunny; after_rainy = probability after_rainy } in
  if chain.after_sunny = chain.after_rainy then failwith "today's weather says nothing about tomorrow's";
  note ("after a sunny day " ^ show chain.after_sunny);
  note ("after a rainy day " ^ show chain.after_rainy);
  chain

(* ---- The chain with three states ------------------------------------------ *)

(* The matrix of a pmatrix, as rows of numbers. *)
let matrix text =
  let opening = "\\begin{pmatrix} " and closing = " \\end{pmatrix}" in
  let length = String.length text and outside = String.length opening + String.length closing in
  if
    length < outside
    || String.sub text 0 (String.length opening) <> opening
    || String.sub text (length - String.length closing) (String.length closing) <> closing
  then failwith "not a pmatrix";
  let body = String.sub text (String.length opening) (length - outside) in
  let rows = Str.split_delim (Str.regexp_string " \\\\ ") body in
  let entries = List.map (fun row -> List.map printed_number (Str.split_delim (Str.regexp_string " & ") row)) rows in
  if List.length entries <> 3 || List.exists (fun row -> List.length row <> 3) entries then
    failwith "not a matrix of 3 rows and 3 columns";
  Array.of_list (List.map Array.of_list entries)

let states = [ 0; 1; 2 ]

(* Every path of two steps from one state to another: its two steps are
   multiplied, and the paths are added up. *)
let two_steps chain start target =
  List.fold_left (fun total middle -> total +: (chain.(start).(middle) *: chain.(middle).(target))) zero states

let exchanged chain = Array.init 3 (fun i -> Array.init 3 (fun j -> chain.(j).(i)))

(* ---- The walk on a line ---------------------------------------------------- *)

(* The chances of stopping at the top from the positions 1 .. length - 1:
   h_i - up h_(i+1) - down h_(i-1) = 0, where h_0 = 0 adds nothing and
   h_length = 1 goes to the right-hand side. *)
let reach_top ~length ~up =
  let down = one -: up and unknowns = length - 1 in
  let rows = Array.make_matrix unknowns unknowns zero and right = Array.make unknowns zero in
  for position = 1 to length - 1 do
    let row = position - 1 in
    rows.(row).(row) <- one;
    if position + 1 = length then right.(row) <- up else rows.(row).(row + 1) <- zero -: up;
    if position - 1 > 0 then rows.(row).(row - 1) <- zero -: down
  done;
  solve rows right

(* The walk followed step by step in floats: the weight that has stopped at
   the top once almost none is still moving. *)
let followed_to_top ~length ~up ~start =
  let weights = ref (Array.init (length + 1) (fun position -> if position = start then 1.0 else 0.0)) in
  for _ = 1 to 2000 do
    let next = Array.make (length + 1) 0.0 in
    next.(0) <- !weights.(0);
    next.(length) <- !weights.(length);
    for position = 1 to length - 1 do
      next.(position + 1) <- next.(position + 1) +. (!weights.(position) *. up);
      next.(position - 1) <- next.(position - 1) +. (!weights.(position) *. (1.0 -. up))
    done;
    weights := next
  done;
  !weights.(length)

(* The right answer of a question, and the answer of each mistake its form is
   open to, found again from the prompt. `got` is the engine's answer, for the
   checks that are equations the answer must satisfy. *)
let expected (q : Rhema_engine.question) got =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "path" -> (
      match
        fields 5
          (story ^ words " Today is " ^ a_weather ^ words ". Find the probability that tomorrow is " ^ a_weather
         ^ words " and the day after tomorrow is " ^ a_weather ^ words ".")
          p
      with
      | [ after_sunny; after_rainy; today; tomorrow; after ] ->
          let chain = weather after_sunny after_rainy in
          note (Printf.sprintf "path: %s, %s, %s" today tomorrow after);
          let asked = [ is_sunny tomorrow; is_sunny after ] in
          (chance chain (is_sunny today) 2 (fun days -> days = asked), [])
      | _ -> failwith "five fields were expected")
  | "forecast" -> (
      match
        fields 3
          (story ^ words " The forecast says that today is sunny with probability [`" ^ a_number
         ^ words "`]. Find the probability that tomorrow is sunny.")
          p
      with
      | [ after_sunny; after_rainy; forecast ] ->
          let chain = weather after_sunny after_rainy and sunny_today = probability forecast in
          note ("forecast " ^ show sunny_today);
          let tomorrow_sunny today = chance chain today 1 (fun days -> last days) in
          ((sunny_today *: tomorrow_sunny true) +: ((one -: sunny_today) *: tomorrow_sunny false), [])
      | _ -> failwith "three fields were expected")
  | ("two_days" | "three_days") as k -> (
      let days = if k = "two_days" then 2 else 3 in
      let asks =
        if days = 2 then words ". Find the probability that the day after tomorrow is " ^ a_weather ^ words "."
        else words ". Find the probability that it is " ^ a_weather ^ words " three days from today."
      in
      match fields 4 (story ^ words " Today is " ^ a_weather ^ asks) p with
      | [ after_sunny; after_rainy; today; asked ] ->
          let chain = weather after_sunny after_rainy in
          note (Printf.sprintf "%s: %s, %s" k today asked);
          (chance chain (is_sunny today) days (fun sequence -> last sequence = is_sunny asked), [])
      | _ -> failwith "four fields were expected")
  | "long_run" -> (
      match fields 3 (story ^ words " In the long run, what fraction of the days is " ^ a_weather ^ words "?") p with
      | [ after_sunny; after_rainy; asked ] ->
          let chain = weather after_sunny after_rainy in
          note ("long_run: " ^ asked);
          (* sunny = sunny * after_sunny + rainy * after_rainy, and
             sunny + rainy = 1 *)
          let shares =
            solve [| [| chain.after_sunny -: one; chain.after_rainy |]; [| one; one |] |] [| zero; one |]
          in
          let sunny = if is_sunny asked then got else one -: got in
          if sunny <> (sunny *: chain.after_sunny) +: ((one -: sunny) *: chain.after_rainy) then
            fail (Printf.sprintf "long_run: one more day changes the share %s, for %S" (show sunny) p);
          List.iter
            (fun today ->
              let share = ref (if today then 1.0 else 0.0) in
              for _ = 1 to 200 do
                share := (!share *. to_float chain.after_sunny) +. ((1.0 -. !share) *. to_float chain.after_rainy)
              done;
              if not (close !share (to_float sunny)) then
                fail (Printf.sprintf "long_run: after 200 days the share is %.12f, not %s, for %S" !share (show sunny) p))
            [ true; false ];
          ((if is_sunny asked then shares.(0) else shares.(1)), [])
      | _ -> failwith "three fields were expected")
  | "run_length" -> (
      match
        fields 5
          (story ^ words " Today is the first " ^ a_weather ^ words " day after a " ^ a_weather
         ^ words " one. Find the expected number of " ^ a_weather
         ^ words " days in a row, today included, before the weather changes.")
          p
      with
      | [ after_sunny; after_rainy; today; before; counted ] ->
          let chain = weather after_sunny after_rainy in
          if today = before then failwith "the run does not start today";
          if counted <> today then failwith "the days counted are not the days of the run";
          note ("run_length: " ^ today);
          let same = is_sunny today in
          let stays = step chain same same in
          (* the run has n days when the weather stays n - 1 times and then
             changes *)
          let total = ref 0.0 and reached = ref 1.0 and n = ref 1 in
          while !n <= 100000 && float !n *. !reached > 1e-18 do
            total := !total +. (float !n *. !reached *. to_float (step chain same (not same)));
            reached := !reached *. to_float stays;
            incr n
          done;
          if not (close !total (to_float got)) then
            fail (Printf.sprintf "run_length: the series comes to %.12f, not %s, for %S" !total (show got) p);
          if got <> one +: (stays *: got) then
            fail (Printf.sprintf "run_length: %s is not 1 + %s times itself, for %S" (show got) (show stays) p);
          ((solve [| [| one -: stays |] |] [| one |]).(0), [])
      | _ -> failwith "five fields were expected")
  | "matrix_two_steps" -> (
      match
        fields 3
          (words "A Markov chain on the states [`1`], [`2`] and [`3`] has the transition matrix [`P = " ^ a_number
         ^ words "`], in which the entry in row [`i`] and column [`j`] is the probability of going from state [`i`]"
         ^ words " to state [`j`] in one step. The chain is in state [`" ^ a_count
         ^ words "`] now. Find the probability that it is in state [`" ^ a_count ^ words "`] after two steps.")
          p
      with
      | [ printed; start; target ] ->
          let chain = matrix printed and start = int_of_string start and target = int_of_string target in
          Array.iter
            (fun row ->
              Array.iter
                (fun entry ->
                  if less entry zero || less one entry then failwith ("an entry is not a probability: " ^ show entry);
                  if (entry *: whole 4).bottom <> 1 then failwith ("an entry is not a number of quarters: " ^ show entry);
                  note ("matrix entry " ^ show entry))
                row;
              if Array.fold_left ( +: ) zero row <> one then failwith "a row does not add up to 1";
              note ("matrix row " ^ String.concat " " (Array.to_list (Array.map show row))))
            chain;
          if start < 1 || start > 3 || target < 1 || target > 3 then failwith "not a state of the chain";
          if start = target then failwith "the state asked for is the state now";
          note (Printf.sprintf "matrix from %d to %d" start target);
          (* reading one step off the printed matrix must not be marked right *)
          let one_step = chain.(start - 1).(target - 1) in
          if got = one_step then
            fail
              (Printf.sprintf "matrix_two_steps: the answer %s is the entry of the matrix itself, for %S" (show got) p);
          ( two_steps chain (start - 1) (target - 1),
            [ ("transposed", two_steps (exchanged chain) (start - 1) (target - 1)) ] )
      | _ -> failwith "three fields were expected")
  | "ruin" -> (
      match
        fields 5
          (words "A counter moves on the positions [`0, 1, \\ldots, " ^ a_count
         ^ words "`]. At each step it moves up by one with probability [`" ^ a_number
         ^ words "`] and down by one otherwise, and it stops when it reaches [`0`] or [`" ^ a_count
         ^ words "`]. It starts at [`" ^ a_count ^ words "`]. Find the probability that it stops at [`" ^ a_count
         ^ words "`].")
          p
      with
      | [ length; up; stop; start; asked ] ->
          let length = int_of_string length and start = int_of_string start and up = probability up in
          if int_of_string stop <> length || int_of_string asked <> length then
            failwith "the top of the line is not the same throughout";
          if start < 1 || start >= length then failwith "the counter starts where it stops";
          note (Printf.sprintf "ruin on %d from %d" length start);
          note ("ruin up " ^ show up);
          let chances = reach_top ~length ~up in
          let followed = followed_to_top ~length ~up:(to_float up) ~start in
          if not (close followed (to_float got)) then
            fail
              (Printf.sprintf "ruin: the walk stops at the top with weight %.12f, not %s, for %S" followed (show got) p);
          (chances.(start - 1), [])
      | _ -> failwith "five fields were expected")
  | k -> failwith ("unknown kind " ^ k)

let () =
  let base = load_file "markov_chain.rhm" in
  let prices =
    [ ("path", 1); ("forecast", 1); ("two_days", 2); ("long_run", 2); ("run_length", 2); ("three_days", 3);
      ("matrix_two_steps", 3); ("ruin", 3) ]
  in
  let seen = Hashtbl.create 8 and made = Hashtbl.create 2 and generated = Hashtbl.create 4 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 399 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          Hashtbl.replace generated cost (1 + Option.value ~default:0 (Hashtbl.find_opt generated cost));
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          (match Rhema_engine.attribute q.Rhema_engine.tree "text" with
          | Rhema_engine.Text t when t = p -> ()
          | _ -> fail (Printf.sprintf "%s: the prompt is not the text of the question, for %S" k p));
          match (number q.Rhema_engine.answer, q.Rhema_engine.answers) with
          | None, _ | _, ([] | _ :: _ :: _) -> fail (Printf.sprintf "%s: one number was expected as the answer of %S" k p)
          | Some got, [ _ ] -> (
              if k = "run_length" then begin
                if not (less one got) then
                  fail (Printf.sprintf "%s: a run of %s days is not longer than one day, for %S" k (show got) p)
              end
              else if not (is_probability got) then
                fail (Printf.sprintf "%s: the answer %s is not strictly between 0 and 1, for %S" k (show got) p);
              match expected q got with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | want, slips ->
                  if got <> want then
                    fail (Printf.sprintf "%s: answer %s, worked out %s, for %S" k (show got) (show want) p);
                  (* the grammar asks a question only where reading the matrix
                     the wrong way round gives another number *)
                  List.iter
                    (fun (name, slip) ->
                      if slip = want then
                        fail (Printf.sprintf "%s: %s gives the right answer %s, for %S" k name (show want) p))
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
                      (match Str.search_forward (Str.regexp_string "wrong way round") m.description 0 with
                      | _ -> ()
                      | exception Not_found ->
                          fail
                            (Printf.sprintf "%s is not described as reading the matrix the wrong way round: %S" m.mistake
                               m.description));
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match number value with
                          | Some wrong ->
                              if wrong <> slip then
                                fail
                                  (Printf.sprintf "%s: %s gives %s, worked out %s, for %S" k m.mistake (show wrong)
                                     (show slip) p);
                              if wrong = got then
                                fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p)
                          | None -> fail (Printf.sprintf "%s: %s does not give a number, for %S" k m.mistake p))
                      | _, None -> ()
                      | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                    listed))
    done
  done;
  for cost = 1 to 3 do
    let count = Option.value ~default:0 (Hashtbl.find_opt generated cost) in
    if count < 300 then fail (Printf.sprintf "only %d questions at cost %d" count cost)
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k () -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  if not (Hashtbl.mem made "transposed") then fail "never listed: transposed";
  (* Every choice the grammar offers is taken at least once. *)
  let both = [ "sunny"; "rainy" ] and three = [ 1; 2; 3 ] in
  let fractions =
    List.map show
      [ fraction 1 2; fraction 1 3; fraction 2 3; fraction 1 4; fraction 3 4; fraction 1 5; fraction 2 5; fraction 3 5;
        fraction 4 5 ]
  in
  (* every list of `length` words *)
  let rec weathers length =
    if length = 0 then [ [] ]
    else List.concat_map (fun rest -> List.map (fun word -> word :: rest) both) (weathers (length - 1))
  in
  let days k length = List.map (fun chosen -> k ^ ": " ^ String.concat ", " chosen) (weathers length) in
  let quarters n = show (fraction n 4) in
  let choices =
    days "path" 3 @ days "two_days" 2 @ days "three_days" 2 @ days "long_run" 1 @ days "run_length" 1
    @ List.concat_map
        (fun f -> [ "after a sunny day " ^ f; "after a rainy day " ^ f; "forecast " ^ f; "ruin up " ^ f ])
        fractions
    @ List.init 5 (fun n -> "matrix entry " ^ quarters n)
    @ List.concat
        (List.init 5 (fun first ->
             List.init (5 - first) (fun second ->
                 Printf.sprintf "matrix row %s %s %s" (quarters first) (quarters second) (quarters (4 - first - second)))))
    @ List.concat_map
        (fun start ->
          List.filter_map
            (fun target -> if start = target then None else Some (Printf.sprintf "matrix from %d to %d" start target))
            three)
        three
    @ List.map
        (fun (length, start) -> Printf.sprintf "ruin on %d from %d" length start)
        [ (3, 1); (3, 2); (4, 1); (4, 2); (4, 3) ]
  in
  List.iter (fun what -> if not (Hashtbl.mem noted what) then fail ("never generated: " ^ what)) choices;
  (* The grammar as it is written, with the budget it sets itself, gives a
     question of one of the three prices. *)
  for seed = 0 to 19 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some (Rhema_engine.consumption q.Rhema_engine.tree "cost") then
          fail (Printf.sprintf "the grammar's own budget gave %s, which did not spend its price" (kind q))
  done;
  (* A budget that no form is priced at gives no question. *)
  List.iter
    (fun cost ->
      for seed = 0 to 19 do
        Random.init seed;
        match Rhema_engine.generate (with_initial base "cost" cost) with
        | exception Rhema_engine.Generation_error _ -> ()
        | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
      done)
    [ 0; 4; 5; 6 ];
  if !failures = 0 then print_endline "Rhema markov chain tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d markov chain test(s) failed." !failures);
    exit 1
  end
