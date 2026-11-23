(* Independent checks for automata.rhm. Every question is matched against the
   whole sentence of its form, the table, the words and the numbers are read
   back from it, and the answer is found again by running automata letter by
   letter and by writing words out, never by the matrices or the formulas the
   grammar uses:

   final_state          the transition table is read from the printed array:
                        its header must name the letters a and b in that
                        order, its rows the states 1, 2 and 3 in that order,
                        and every entry must be one of the three states. The
                        automaton is run from state 1 on the printed word,
                        one letter after the other. The table must keep what
                        the grammar promises of it: the two letters do
                        different things, neither sends every state to the
                        same one, and a search from state 1 finds the states
                        2 and 3. The word has four letters.
   word_count           an alphabet of as many letters as printed is taken,
                        every word of the printed length over it is written
                        out, and the words are counted.
   words_up_to          the same, for every length from 0 to the printed one,
                        the counts added up; the empty word is one of the
                        words written out.
   accepted_count,      the table is read and checked as for final_state, the
   accepted_count_long  accepting states are read from "in state 1 or in
                        state 3" (one or two states, in order). Every word of
                        the printed length over a and b is written out, the
                        automaton is run on each, and the words that end in
                        an accepting state are counted. The number of words
                        the sentence gives must be the number written out;
                        some word is accepted and some is not.
   no_two_together,     every word of the printed length over the printed
   two_together         letters (a and b, or a, b and c) is written out, and
                        each is searched for two a's side by side; the words
                        without (with) such a pair are counted. The answer of
                        no_two_together stays below 1000.
   remainders,          the least number of states is found by building a
   contains_word,       deterministic automaton for the language and then
   from_the_end         minimising it. The automaton built is wasteful on
                        purpose, so that the minimising has work to do:
                        - remainders: it counts the a's modulo 2m and the b's
                          modulo 2n, and accepts when m divides the one count
                          and n the other (four states for each pair of
                          remainders);
                        - contains_word: it remembers the last letters read,
                          as many as the word has, and whether the word has
                          been seen; it accepts when it has;
                        - from_the_end: it remembers the last k letters read
                          (fewer at the start) and accepts when it has k of
                          them and the first of them is the letter wanted.
                        Only the states reached from the start are built (a
                        breadth-first search). The automaton is first tried
                        against the sentence itself: on every word of up to
                        12 letters it must accept exactly when the word is in
                        the language, as decided by counting letters, by
                        looking for the word at every place, or by looking at
                        the letter in place k from the end. It is then
                        minimised by Moore's algorithm: the states are split
                        into accepting and not, and the classes are split
                        again by the classes the two letters lead to until
                        nothing more splits. The number of classes is the
                        answer. It is counted a second time without any
                        automaton, as the number of Myhill-Nerode classes:
                        the words up to the length that reaches every class,
                        told apart by the continuations up to the length that
                        the splitting took; both lengths are read off the
                        minimising, the classes are counted from the sentence
                        alone, and the two counts must be the same.

   The mistakes are found again from what the student does. read_backwards
   runs the automaton on the word with its letters in the opposite order.
   one_state_per_letter is the number of states of the chain a student draws
   for "the letter in place k from the end": a start state, and one state
   for each of the k letters to remember. The chain is built; it does accept
   the right words when it may guess (as a nondeterministic automaton, tried
   on every word of up to 12 letters), which is why it tempts, and its states
   are counted. A question must list exactly the mistakes of its form, in the
   order they are declared, with these values, each of them another number
   than the right answer; a form with no mistake lists none. Each mistake is
   described as itself.

   Every kind must come up at its price and at no other, the budget must be
   spent, the grammar's own budget must give a question of price 2, a budget
   outside 1 to 3 must give no question, and every answer must be one whole
   number. What each form is asked with is pinned as well: every choice the
   grammar offers must come up, and nothing else. For the forms with a table
   the questions are too many to wait for each of them (2452 tables with a
   word, 1968 and 4048 tables with accepting states and a length), so every
   question such a form can ask is written out here, from all 729 tables,
   and what must come up is each part of those questions:
   - final_state: every table that has a question at all (336 of the 356
     that keep the promises have a word that reading backwards takes to
     another state), and every word with every pair of states it can lead to
     forwards and backwards;
   - accepted_count: every table that has a question (352), and every choice
     of accepting states with every number of words it can accept;
   - accepted_count_long: every table (356), every choice of accepting
     states with each length, and each length with every number of words
     that can be accepted.
   That a question is itself one of those written out is checked on the
   question. The weights of the forms are not pinned. *)

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

(* The parts of a prompt: the pattern is the whole sentence, with a group
   wherever a number, a word or a table stands. A number is written without
   a sign and without a leading zero; no form prints a zero of its own. *)
let words = Str.quote
let a_count = "\\([1-9][0-9]*\\)"
let a_state = "\\([1-3]\\)"
let a_word = "\\([ab]+\\)"

let fields count pattern text =
  if Str.string_match (Str.regexp pattern) text 0 && Str.match_end () = String.length text then
    List.init count (fun n -> Str.matched_group (n + 1) text)
  else failwith "the wording is not the expected one"

let range first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)
let sum = List.fold_left ( + ) 0
let size = List.length
let letters_of word = List.init (String.length word) (String.get word)

let memo f =
  let known = Hashtbl.create 16 in
  fun key ->
    match Hashtbl.find_opt known key with
    | Some value -> value
    | None ->
        let value = f key in
        Hashtbl.add known key value;
        value

(* ---- Words ---- *)

(* Every word of a length over the letters of an alphabet, written out. *)
let words_of =
  let rec write alphabet length =
    if length = 0 then [ "" ]
    else
      List.concat_map
        (fun word -> List.map (fun letter -> word ^ String.make 1 letter) (letters_of alphabet))
        (write alphabet (length - 1))
  in
  memo (fun (alphabet, length) ->
      if length < 0 || float_of_int (String.length alphabet) ** float_of_int length > 100000. then
        failwith "too many words to write out";
      write alphabet length)

(* Every word over a and b of at most a length, the empty word first. *)
let words_up_to = memo (fun length -> List.concat_map (fun l -> words_of ("ab", l)) (range 0 length))

let backwards word =
  let n = String.length word in
  String.init n (fun i -> word.[n - 1 - i])

(* Whether one word stands in another, as letters next to each other: every
   place it could start at is tried. *)
let contains ~part word =
  let n = String.length part in
  List.exists (fun at -> String.sub word at n = part) (range 0 (String.length word - n))

let count_letter letter word = size (List.filter (fun l -> l = letter) (letters_of word))

(* ---- The automaton with three states ---- *)

(* A transition table: the row of a state (1, 2, 3) gives the state reached
   on a and the state reached on b. *)
type table = int array array

let column = function 'a' -> 0 | 'b' -> 1 | _ -> failwith "a letter other than a and b"
let move (table : table) state letter = table.(state - 1).(column letter)

(* The state after a word, from state 1, one letter after the other. *)
let after table word = List.fold_left (move table) 1 (letters_of word)

(* The table as the array prints it: a header row with the letters, then one
   row for each state, the first under a rule. *)
let read_table body : table =
  match Str.split_delim (Str.regexp_string " \\\\ ") body with
  | [ "& a & b"; first; second; third ] ->
      let row state line =
        let name = (if state = 1 then "\\hline " else "") ^ string_of_int state ^ " & " in
        Array.of_list (List.map int_of_string (fields 2 (words name ^ a_state ^ words " & " ^ a_state) line))
      in
      [| row 1 first; row 2 second; row 3 third |]
  | _ -> failwith "the table does not have a header and three rows"

let table_name (table : table) =
  String.concat "" (List.map string_of_int (List.concat_map Array.to_list (Array.to_list table)))

(* The states that can be reached from state 1: a search that stops when a
   round finds nothing new. *)
let reachable table =
  let rec grow known =
    let further =
      List.sort_uniq compare (known @ List.concat_map (fun state -> [ move table state 'a'; move table state 'b' ]) known)
    in
    if further = known then known else grow further
  in
  grow [ 1 ]

(* What is wrong with a table, if it does not keep what the grammar promises. *)
let flaw table =
  let states = [ 1; 2; 3 ] in
  let all_to_one letter = size (List.sort_uniq compare (List.map (fun state -> move table state letter) states)) = 1 in
  if List.for_all (fun state -> move table state 'a' = move table state 'b') states then
    Some "the two letters do the same thing"
  else if all_to_one 'a' || all_to_one 'b' then Some "a letter sends every state to the same one"
  else if reachable table <> states then Some "a state cannot be reached from state 1"
  else None

let promised table = match flaw table with Some what -> failwith what | None -> ()

(* The accepting states, from "in state [`1`] or in state [`3`]". *)
let read_states phrase =
  let states =
    List.map
      (fun part ->
        match fields 1 (words "in state [`" ^ a_state ^ words "`]") part with
        | [ state ] -> int_of_string state
        | _ -> failwith "a state was expected")
      (Str.split_delim (Str.regexp_string " or ") phrase)
  in
  if not (List.mem (size states) [ 1; 2 ]) then failwith "one or two accepting states were expected";
  if List.sort_uniq compare states <> states then failwith "the accepting states are not in order";
  states

let states_name states = "{" ^ String.concat "," (List.map string_of_int states) ^ "}"

(* The words of a length that end in one of the accepting states. *)
let accepted_words table accepting length =
  size (List.filter (fun word -> List.mem (after table word) accepting) (words_of ("ab", length)))

(* ---- The least number of states ---- *)

(* A deterministic automaton over a and b. The states are numbered from 0,
   the start state; `depth` is the length of a shortest word that reaches
   each. *)
type automaton = { next : int array array; final : bool array; depth : int array }

(* The automaton of the states reached from `start`, found breadth first. A
   state is any value; it is given a number when it is first met. *)
let build ~start ~step ~accepts =
  let number = Hashtbl.create 64 and waiting = Queue.create () and found = ref [] in
  let name state depth =
    match Hashtbl.find_opt number state with
    | Some n -> n
    | None ->
        let n = Hashtbl.length number in
        if n >= 5000 then failwith "too many states to build";
        Hashtbl.add number state n;
        Queue.add (state, depth) waiting;
        n
  in
  ignore (name start 0);
  while not (Queue.is_empty waiting) do
    let state, depth = Queue.pop waiting in
    (* the states leave the queue in the order of their numbers *)
    let on_a = name (step state 'a') (depth + 1) in
    let on_b = name (step state 'b') (depth + 1) in
    found := ([| on_a; on_b |], accepts state, depth) :: !found
  done;
  let rows = Array.of_list (List.rev !found) in
  { next = Array.map (fun (moves, _, _) -> moves) rows;
    final = Array.map (fun (_, final, _) -> final) rows;
    depth = Array.map (fun (_, _, depth) -> depth) rows }

let accepts_word automaton word =
  automaton.final.(List.fold_left (fun state letter -> automaton.next.(state).(column letter)) 0 (letters_of word))

(* Moore's algorithm. The states are first split by whether they accept;
   then, round after round, two states stay together only when they are
   together and each letter leads them to states that are together. It stops
   when a round splits nothing. Returned: the class of each state, the
   number of classes, and the number of rounds that split something, which
   is the length of the longest word needed to tell two states apart. *)
let minimise automaton =
  let states = Array.length automaton.next in
  let classes_of signature =
    let names = Hashtbl.create 64 in
    let classes =
      Array.init states (fun state ->
          let s = signature state in
          match Hashtbl.find_opt names s with
          | Some c -> c
          | None ->
              let c = Hashtbl.length names in
              Hashtbl.add names s c;
              c)
    in
    (classes, Hashtbl.length names)
  in
  let rec refine classes count rounds =
    let finer, more =
      classes_of (fun state ->
          (classes.(state), classes.(automaton.next.(state).(0)), classes.(automaton.next.(state).(1))))
    in
    if more = count then (classes, count, rounds) else refine finer more (rounds + 1)
  in
  let classes, count = classes_of (fun state -> ((if automaton.final.(state) then 1 else 0), 0, 0)) in
  refine classes count 0

(* The number of Myhill-Nerode classes that words of up to `reach` letters
   fall into when they are told apart by continuations of up to `apart`
   letters: two words are in one class when no continuation is in the
   language after the one and not after the other. No automaton is used,
   only the test of whether a word is in the language. *)
let told_apart ~member ~reach ~apart =
  if reach + apart > 18 then failwith "too many words to tell apart";
  let continuations = words_up_to apart in
  let seen = Hashtbl.create 64 in
  List.iter
    (fun word ->
      let behaviour =
        String.concat "" (List.map (fun more -> if member (word ^ more) then "1" else "0") continuations)
      in
      Hashtbl.replace seen behaviour ())
    (words_up_to reach);
  Hashtbl.length seen

(* The least number of states of a deterministic automaton for a language:
   `member` says whether a word is in it, and `start`, `step` and `accepts`
   are some automaton for it, with states of any kind. *)
let fewest_states ~member ~start ~step ~accepts =
  let automaton = build ~start ~step ~accepts in
  List.iter
    (fun word ->
      if accepts_word automaton word <> member word then failwith ("the automaton built is wrong on the word " ^ word))
    (words_up_to 12);
  let classes, count, rounds = minimise automaton in
  (* the shortest word that reaches each class, and the longest of those *)
  let reach =
    List.fold_left max 0
      (List.map
         (fun c ->
           List.fold_left min max_int
             (List.filter_map
                (fun state -> if classes.(state) = c then Some automaton.depth.(state) else None)
                (range 0 (Array.length classes - 1))))
         (range 0 (count - 1)))
  in
  if told_apart ~member ~reach ~apart:rounds <> count then
    failwith "the classes of words counted from the sentence are not as many as the states left by the minimising";
  count

(* The languages the grammar asks about. *)
type language =
  | Remainders of int * int  (* the a's divisible by the one number, the b's by the other *)
  | Contains of string  (* the words with this word in them *)
  | From_the_end of int * char  (* this letter in place k from the end *)

(* Whether a word is in a language, by what the sentence says. *)
let member language word =
  match language with
  | Remainders (m, n) -> count_letter 'a' word mod m = 0 && count_letter 'b' word mod n = 0
  | Contains part -> contains ~part word
  | From_the_end (k, wanted) -> String.length word >= k && word.[String.length word - k] = wanted

(* The last letters of a word, at most so many. *)
let last_letters most word =
  let n = String.length word in
  if n <= most then word else String.sub word (n - most) most

let least_states =
  memo (fun language ->
      let member = member language in
      match language with
      | Remainders (m, n) ->
          if m < 1 || n < 1 || m > 8 || n > 8 then failwith "remainders too large to count";
          (* the counts go round twice before they start again *)
          fewest_states ~member ~start:(0, 0)
            ~step:(fun (i, j) letter -> if letter = 'a' then ((i + 1) mod (2 * m), j) else (i, (j + 1) mod (2 * n)))
            ~accepts:(fun (i, j) -> i mod m = 0 && j mod n = 0)
      | Contains part ->
          let length = String.length part in
          if length < 1 || length > 7 then failwith "a word too long to remember";
          fewest_states ~member ~start:("", false)
            ~step:(fun (last, seen) letter ->
              let last = last_letters length (last ^ String.make 1 letter) in
              (last, seen || last = part))
            ~accepts:snd
      | From_the_end (k, wanted) ->
          if k < 1 || k > 8 then failwith "too many letters to remember";
          fewest_states ~member ~start:""
            ~step:(fun last letter -> last_letters k (last ^ String.make 1 letter))
            ~accepts:(fun last -> String.length last = k && last.[0] = wanted))

(* The chain of the student who counts one state for each letter to
   remember: the start state 0, which waits, and the states 1 to k, one for
   the letter wanted and one for each letter read after it. Its moves are
   those the student draws: from the start on any letter to the start, from
   the start on the letter wanted to state 1, from each state to the next on
   any letter; state k accepts. It is no deterministic automaton (the start
   has two moves on the letter wanted), and run as a nondeterministic one,
   on every word of up to 12 letters, it accepts the right words. Returned:
   how many states it has. *)
let chain_states =
  memo (fun (k, wanted) ->
      let states = 0 :: range 1 k in
      let moves state letter =
        (if state = 0 then [ 0 ] else [])
        @ (if state = 0 && letter = wanted then [ 1 ] else [])
        @ if state >= 1 && state < k then [ state + 1 ] else []
      in
      let accepts word =
        List.mem k
          (List.fold_left
             (fun reached letter -> List.sort_uniq compare (List.concat_map (fun state -> moves state letter) reached))
             [ 0 ] (letters_of word))
      in
      List.iter
        (fun word ->
          if accepts word <> member (From_the_end (k, wanted)) word then
            failwith ("the chain of the student does not accept the right words: " ^ word))
        (words_up_to 12);
      size states)

(* ---- What each form was asked with ---- *)

let asked : (string * string, unit) Hashtbl.t = Hashtbl.create 4096
let note label what = Hashtbl.replace asked (label, what) ()
let numbers values = String.concat " " (List.map string_of_int values)

let accepting_choices = [ [ 1 ]; [ 2 ]; [ 3 ]; [ 1; 2 ]; [ 1; 3 ]; [ 2; 3 ] ]

(* Every choice the grammar offers, form by form. For the forms with a table,
   every question that can be asked is written out and its parts are kept. *)
let offered =
  let pairs firsts seconds = List.concat_map (fun x -> List.map (fun y -> numbers [ x; y ]) seconds) firsts in
  let each part questions = List.sort_uniq compare (List.map part questions) in
  (* each of the 729 tables that keeps the promises *)
  let tables =
    let states = [ 1; 2; 3 ] in
    let rows = List.concat_map (fun on_a -> List.map (fun on_b -> [| on_a; on_b |]) states) states in
    List.concat_map
      (fun first -> List.concat_map (fun second -> List.map (fun third -> [| first; second; third |]) rows) rows)
      rows
    |> List.filter (fun table -> flaw table = None)
  in
  (* a table and a word of four letters that leads to another state when it
     is read backwards *)
  let final_state =
    List.concat_map
      (fun table ->
        List.filter_map
          (fun word ->
            let reached = after table word and reversed = after table (backwards word) in
            if reached <> reversed then Some (table, word, reached, reversed) else None)
          (words_of ("ab", 4)))
      tables
  in
  (* a table, the accepting states and a length that accept some word and
     not every word *)
  let accepting lengths =
    List.concat_map
      (fun table ->
        List.concat_map
          (fun accepting ->
            List.filter_map
              (fun length ->
                let accepted = accepted_words table accepting length in
                if accepted > 0 && accepted < size (words_of ("ab", length)) then
                  Some (table, accepting, length, accepted)
                else None)
              lengths)
          accepting_choices)
      tables
  in
  let short = accepting [ 3 ] and long = accepting [ 4; 5 ] in
  (* two letters with a length from 4 to 8, three with one from 4 to 6 *)
  let together = pairs [ 2 ] (range 4 8) @ pairs [ 3 ] (range 4 6) in
  [ ("final_state, table", each (fun (table, _, _, _) -> table_name table) final_state);
    ( "final_state, word and states",
      each (fun (_, word, reached, reversed) -> Printf.sprintf "%s %d %d" word reached reversed) final_state );
    ("word_count", pairs (range 2 5) (range 2 5));
    ("words_up_to", pairs (range 2 5) (range 2 5));
    ("accepted_count, table", each (fun (table, _, _, _) -> table_name table) short);
    ( "accepted_count, states and words accepted",
      each (fun (_, accepting, _, accepted) -> Printf.sprintf "%s %d" (states_name accepting) accepted) short );
    ("no_two_together", together);
    ("remainders", pairs (range 2 5) (range 2 5));
    ("contains_word", words_of ("ab", 3) @ words_of ("ab", 4));
    ("accepted_count_long, table", each (fun (table, _, _, _) -> table_name table) long);
    ( "accepted_count_long, states and length",
      each (fun (_, accepting, length, _) -> Printf.sprintf "%s %d" (states_name accepting) length) long );
    ( "accepted_count_long, length and words accepted",
      each (fun (_, _, length, accepted) -> numbers [ length; accepted ]) long );
    ("two_together", together);
    ("from_the_end", List.concat_map (fun k -> [ Printf.sprintf "%d a" k; Printf.sprintf "%d b" k ]) (range 2 6)) ]

(* ---- The answer of each form, found again ---- *)

let machine =
  words
    "A finite automaton has the states [`1`], [`2`] and [`3`] and reads words over the letters [`a`] and [`b`]. It \
     starts in state [`1`]. Its transition table is [`\\begin{array}{c|cc} "
  ^ "\\([^`]*\\)"
  ^ words " \\end{array}`], in which the row of a state gives the state that each letter leads to."

let least = words "A deterministic finite automaton over the letters [`a`] and [`b`] is to accept exactly the words "
let how_few = words " What is the least number of states it can have?"

let one_of choices = "\\(" ^ String.concat "\\|" (List.map words choices) ^ "\\)"

(* The right answer of a question, and the answer of each mistake that its
   form is open to, all found again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "final_state" -> (
      match fields 2 (machine ^ words " In which state is it after reading the word [`" ^ a_word ^ words "`]?") p with
      | [ body; word ] ->
          let table = read_table body in
          promised table;
          let reached = after table word and reversed = after table (backwards word) in
          note "final_state, table" (table_name table);
          note "final_state, word and states" (Printf.sprintf "%s %d %d" word reached reversed);
          (reached, [ ("read_backwards", reversed) ])
      | _ -> failwith "a table and a word were expected")
  | ("word_count" | "words_up_to") as form -> (
      let which, more =
        if form = "word_count" then ("exactly", "") else ("at most", " The empty word, of length [`0`], is one of them.")
      in
      match
        fields 2
          (words ("How many words of length " ^ which ^ " [`")
          ^ a_count ^ words "`] are there over an alphabet of [`" ^ a_count
          ^ words ("`] letters?" ^ more))
          p
      with
      | [ length; letters ] ->
          let length = int_of_string length and letters = int_of_string letters in
          note form (numbers [ letters; length ]);
          if letters > 8 then failwith "too many letters for the alphabet";
          let alphabet = String.sub "abcdefgh" 0 letters in
          let of_length l = size (words_of (alphabet, l)) in
          ((if form = "word_count" then of_length length else sum (List.map of_length (range 0 length))), [])
      | _ -> failwith "a length and a number of letters were expected")
  | ("accepted_count" | "accepted_count_long") as form -> (
      match
        fields 4
          (machine ^ words " It accepts a word when it ends " ^ "\\(in state [^.]*\\)" ^ words ". How many of the [`"
         ^ a_count ^ words "`] words of length [`" ^ a_count ^ words "`] does it accept?")
          p
      with
      | [ body; accepting; total; length ] ->
          let table = read_table body and accepting = read_states accepting in
          let total = int_of_string total and length = int_of_string length in
          promised table;
          if length > 8 then failwith "too long a word";
          if size (words_of ("ab", length)) <> total then
            failwith "the words of that length are not as many as the sentence says";
          let accepted = accepted_words table accepting length in
          if accepted = 0 then failwith "no word is accepted";
          if accepted = total then failwith "every word is accepted";
          note (form ^ ", table") (table_name table);
          if form = "accepted_count" then begin
            if length <> 3 then failwith "not words of length 3";
            note "accepted_count, states and words accepted" (Printf.sprintf "%s %d" (states_name accepting) accepted)
          end
          else begin
            note "accepted_count_long, states and length" (Printf.sprintf "%s %d" (states_name accepting) length);
            note "accepted_count_long, length and words accepted" (numbers [ length; accepted ])
          end;
          (accepted, [])
      | _ -> failwith "a table, the accepting states and two numbers were expected")
  | ("no_two_together" | "two_together") as form -> (
      let two_letters = "[`a`] and [`b`]" and three_letters = "[`a`], [`b`] and [`c`]" in
      match
        fields 2
          (words "How many words of length [`" ^ a_count ^ words "`] over the letters "
          ^ one_of [ two_letters; three_letters ]
          ^ words
              (if form = "no_two_together" then " have no two [`a`]s next to each other?"
               else " have two [`a`]s next to each other somewhere?"))
          p
      with
      | [ length; letters ] ->
          let length = int_of_string length and alphabet = if letters = two_letters then "ab" else "abc" in
          note form (numbers [ String.length alphabet; length ]);
          if length > 10 then failwith "too long a word";
          let with_pair, without = List.partition (contains ~part:"aa") (words_of (alphabet, length)) in
          if form = "no_two_together" then begin
            if size without >= 1000 then failwith "the answer is not below 1000";
            (size without, [])
          end
          else (size with_pair, [])
      | _ -> failwith "a length and the letters were expected")
  | "remainders" -> (
      match
        fields 2
          (least ^ words "in which the number of [`a`]s is divisible by [`" ^ a_count
          ^ words "`] and the number of [`b`]s is divisible by [`" ^ a_count ^ words "`]." ^ how_few)
          p
      with
      | [ m; n ] ->
          let m = int_of_string m and n = int_of_string n in
          note "remainders" (numbers [ m; n ]);
          (least_states (Remainders (m, n)), [])
      | _ -> failwith "two numbers were expected")
  | "contains_word" -> (
      match
        fields 1
          (least ^ words "that contain [`" ^ a_word ^ words "`] somewhere, as letters next to each other." ^ how_few)
          p
      with
      | [ word ] ->
          note "contains_word" word;
          (least_states (Contains word), [])
      | _ -> failwith "a word was expected")
  | "from_the_end" -> (
      match
        fields 3
          (least ^ words "of at least [`" ^ a_count ^ words "`] letters whose letter in place [`" ^ a_count
         ^ words "`] counted from the end is [`" ^ "\\([ab]\\)"
          ^ words "`]. (In place [`1`] from the end is the last letter.)"
          ^ how_few)
          p
      with
      | [ at_least; place; wanted ] ->
          let k = int_of_string place and wanted = wanted.[0] in
          if int_of_string at_least <> k then failwith "the least length is not the place counted from the end";
          note "from_the_end" (Printf.sprintf "%d %c" k wanted);
          (least_states (From_the_end (k, wanted)), [ ("one_state_per_letter", chain_states (k, wanted)) ])
      | _ -> failwith "two numbers and a letter were expected")
  | k -> failwith ("unknown kind " ^ k)

(* How many questions are made at each budget. The forms with a table have
   the most to come up one by one, and at the budgets 2 and 3 they are asked
   less often than the form of budget 1. *)
let questions_at cost = if cost = 1 then 20000 else 40000

let () =
  let base = load_file "automata.rhm" in
  let prices =
    [ ("final_state", 1); ("word_count", 1); ("words_up_to", 1); ("accepted_count", 2); ("no_two_together", 2);
      ("remainders", 2); ("contains_word", 2); ("accepted_count_long", 3); ("two_together", 3); ("from_the_end", 3) ]
  in
  (* what the description of each mistake must speak of *)
  let spoken =
    [ ("read_backwards", "from its last letter to its first"); ("one_state_per_letter", "one state for each letter") ]
  in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 2 in
  let times k = Option.value (Hashtbl.find_opt seen k) ~default:0 in
  (* a budget below the lowest or above the highest is refused *)
  List.iter
    (fun cost ->
      match Rhema_check.with_initial base "cost" cost with
      | Error _ -> ()
      | Ok spec ->
          for seed = 0 to 19 do
            Random.init seed;
            match Rhema_engine.generate spec with
            | exception Rhema_engine.Generation_error _ -> ()
            | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
          done)
    [ -1; 0; 4; 5; 6; 9 ];
  (* the grammar as it is written, with the budget it sets itself, gives a
     question of price 2 *)
  for seed = 0 to 19 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 || Rhema_engine.consumption q.Rhema_engine.tree "cost" <> 2 then
          fail (Printf.sprintf "the grammar's own budget gave %s, not a question of price 2" (kind q))
  done;
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
    [ ("read_backwards", "final_state"); ("one_state_per_letter", "from_the_end") ];
  (* every choice the grammar offers came up, and nothing else *)
  List.iter
    (fun (label, choices) ->
      List.iter
        (fun what -> if not (Hashtbl.mem asked (label, what)) then fail (label ^ ": never asked with " ^ what))
        choices)
    offered;
  let offered_set = Hashtbl.create 4096 in
  List.iter (fun (label, choices) -> List.iter (fun what -> Hashtbl.replace offered_set (label, what) ()) choices) offered;
  Hashtbl.iter
    (fun (label, what) () ->
      if not (List.mem_assoc label offered) then fail ("nothing is known of what is offered for " ^ label)
      else if not (Hashtbl.mem offered_set (label, what)) then fail (label ^ ": asked with " ^ what))
    asked;
  if !failures = 0 then print_endline "Rhema automata tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d automata test(s) failed." !failures);
    exit 1
  end
