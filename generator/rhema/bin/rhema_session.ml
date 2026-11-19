(* rhema_session.ml -- `rhema try FILE`: a grammar tried out, one question
   at a time.

   A session reads one command a line and answers it. It is the same from a
   keyboard and from a file of commands, so what it does can be tested, and
   a transcript of it can be kept.

   The session is exact about what it shows. The questions of a session are
   a sequence: the Nth question since the last change of setting is the Nth
   question of

     rhema run FILE [--question NAME] [--set BUDGET=VALUE ...] --seed S --count N

   and `how` prints that command. To keep this true, changing the question
   type, a budget or the seed starts the sequence again at its first
   question, and a command that is refused changes nothing.

   Questions, answers and what was asked for go to standard output. The
   prompt, the hints and the errors go to standard error. *)

module Ui = Rhema_terminal

type state = {
  ui : Ui.t;
  file : string;
  base : Rhema_check.spec;  (* the file as loaded *)
  student : string option;
  assignment : string option;
  mutable question : string option;  (* None: the file's main question *)
  mutable overrides : (string * int) list;  (* the budgets changed, in the order given *)
  mutable seed : int option;  (* None: the seed `rhema run` derives *)
  mutable spec : Rhema_check.spec;  (* [base] with the question and the budgets applied *)
  mutable shown : int;  (* questions generated since the sequence started *)
  mutable random : Random.State.t;  (* where the sequence continues *)
  mutable current : Rhema_engine.question option;
}

let configured base ~question ~overrides =
  let ( let* ) = Result.bind in
  let* spec =
    match question with None -> Ok base | Some name -> Rhema_check.select_question base name
  in
  List.fold_left
    (fun spec (name, value) ->
      let* spec = spec in
      Rhema_check.with_initial spec name value)
    (Ok spec) overrides

(* The seed of the sequence: the one given, else the one `rhema run` would
   derive for the same file, question, assignment and student. *)
let seed_of state =
  let assignment =
    match state.assignment with
    | Some name -> name
    | None -> Rhema_cli.default_assignment ~filename:state.file ~question:state.question
  in
  Rhema_cli.variant ~assignment ~student:state.student ~seed:state.seed

let question_name state = Option.value ~default:"main" state.question

let budgets state =
  state.spec.Rhema_check.inherited
  |> List.map (fun (a : Rhema_check.inherited_attribute) ->
         Printf.sprintf "%s = %d" a.Rhema_check.attribute_name a.Rhema_check.initial)

(* The command that prints the questions of this sequence up to [count]. *)
let command state ~count =
  let plain = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '.' | '/' | '_' | '-' | ':' | '=' -> true
    | _ -> false
  in
  (* quoted for a shell only where it has to be *)
  let word text = if text <> "" && String.for_all plain text then text else Filename.quote text in
  String.concat " "
    ([ "rhema"; "run"; word state.file ]
    @ (match state.question with None -> [] | Some name -> [ "--question"; word name ])
    @ List.concat_map (fun (name, value) -> [ "--set"; word (Printf.sprintf "%s=%d" name value) ]) state.overrides
    @ [ "--seed"; string_of_int (seed_of state); "--count"; string_of_int count ])

let say fmt = Printf.printf (fmt ^^ "\n%!")

(* An error of the session: said, and the session goes on. *)
let refuse state message = prerr_endline (state.file ^ ": error: " ^ message)

let status state =
  say "-- %s%s, seed %d" (question_name state)
    (match budgets state with [] -> "" | budgets -> ", " ^ String.concat ", " budgets)
    (seed_of state)

let restart state =
  Random.init (seed_of state);
  state.random <- Random.get_state ();
  state.shown <- 0;
  state.current <- None

let next state =
  Random.set_state state.random;
  match Rhema_engine.generate state.spec with
  | question ->
      state.random <- Random.get_state ();
      state.shown <- state.shown + 1;
      state.current <- Some question;
      (* the line `rhema run` prints for it, without its answer *)
      say "%2d. %s" state.shown question.Rhema_engine.prompt
  | exception Rhema_engine.Generation_error message ->
      state.current <- None;
      refuse state message

(* The lines `rhema run` prints under a question: its answer, and what each
   mistake that can be made in it leads to. *)
let answer_lines (question : Rhema_engine.question) =
  Printf.sprintf "    %s: %s"
    (if List.length question.Rhema_engine.answers > 1 then "answers" else "answer")
    question.Rhema_engine.answer_text
  :: List.map (fun line -> "    " ^ line) (Rhema_engine.describe_mistakes question)

let with_current state use =
  match state.current with
  | Some question -> use question
  | None -> refuse state "there is no question to look at; press Enter for the next one"

(* A number that is an answer, however it is to be graded. *)
let rec exact_number = function
  | Rhema_engine.Num number | Rhema_engine.Exactly number -> Some number
  | Rhema_engine.Plain value -> exact_number value
  | _ -> None

let all_some values = if List.for_all Option.is_some values then Some (List.map Option.get values) else None

(* Compare what was typed with the answer, exactly. Only numbers are
   compared: every other kind of answer is graded by WeBWorK, which knows
   when two formulas or two sets are the same, and is not second-guessed. *)
let check state typed (question : Rhema_engine.question) =
  let parts = String.split_on_char ';' typed |> List.map String.trim in
  let wanted = question.Rhema_engine.answers in
  match all_some (List.map exact_number wanted) with
  | None ->
      refuse state
        "this question's answer is not a number, and only numbers are compared here; WeBWorK \
         grades the rest ('a' shows the answer)"
  | Some right -> (
      if List.length parts <> List.length right then
        refuse state
          (Printf.sprintf "this question has %d answers; type them in order, with ';' between them"
             (List.length right))
      else
        match all_some (List.map Rhema_cli.number_of_text parts) with
        | None ->
            refuse state
              "type a whole number, a fraction such as 3/4 or a decimal such as 0.75 (numbers \
               are compared exactly)"
        | Some given ->
            let same = List.for_all2 Rhema_number.equal in
            if same given right then say "    right"
            else
              let made =
                List.find_opt
                  (fun (made : Rhema_engine.mistaken) ->
                    match made.Rhema_engine.mistaken_answers with
                    | Some values -> (
                        match all_some (List.map exact_number values) with
                        | Some mistaken -> List.length mistaken = List.length given && same given mistaken
                        | None -> false)
                    | None -> false)
                  question.Rhema_engine.mistakes
              in
              (match made with
              | Some made ->
                  say "    not right: this is the answer of the mistake %s (%s)" made.Rhema_engine.mistake
                    made.Rhema_engine.description
              | None -> say "    not right"))

let help =
  [
    "(Enter), n          the next question";
    "a                   the answer, and what each mistake that can be made here gives";
    "= NUMBER            compare a number with the answer, exactly (several: 3; 1/2)";
    "t                   the derivation: the rules accepted and the attribute values";
    "pg                  this question as WeBWorK PG";
    "how                 the command that prints the questions shown so far";
    "question NAME       another question type of the file";
    "BUDGET = N          start a budget at N, such as cost = 8";
    "reset               the budgets as the file sets them";
    "seed N              start the sequence from seed N; seed alone: the derived one";
    "list                the question types and budgets of the file";
    "quit                end the session (so does the end of the input)";
    "";
    "Changing the question type, a budget or the seed starts again at question 1,";
    "so that every question shown is one a command can print again: see how.";
  ]

let commands = [ "n"; "next"; "a"; "answer"; "t"; "tree"; "pg"; "how"; "question"; "reset"; "seed"; "list"; "quit"; "exit"; "help" ]

(* Apply a change of setting, or refuse it and keep everything as it was. *)
let change state ~question ~overrides ~seed =
  match configured state.base ~question ~overrides with
  | Error message -> refuse state message
  | Ok spec ->
      state.question <- question;
      state.overrides <- overrides;
      state.seed <- seed;
      state.spec <- spec;
      restart state;
      status state;
      next state

let listing state =
  say "questions: %s"
    (String.concat ", "
       (List.map (fun (q : Rhema_check.question) -> q.Rhema_check.q_name) state.base.Rhema_check.questions));
  say "budgets: %s" (match budgets state with [] -> "none" | budgets -> String.concat ", " budgets);
  status state

(* One line of input. False when the session is to end. *)
let obey state line =
  let line = String.trim line in
  let words = String.split_on_char ' ' line |> List.filter (( <> ) "") in
  let budget_change () =
    (* BUDGET = N, with or without the spaces *)
    match String.index_opt line '=' with
    | Some at when at > 0 -> (
        let name = String.trim (String.sub line 0 at) in
        let value = String.trim (String.sub line (at + 1) (String.length line - at - 1)) in
        match int_of_string_opt value with
        | Some value when not (String.contains name ' ') ->
            change state ~question:state.question
              ~overrides:(List.remove_assoc name state.overrides @ [ (name, value) ])
              ~seed:state.seed;
            true
        | _ -> false)
    | _ -> false
  in
  if line <> "" && line.[0] = '=' then begin
    with_current state (check state (String.sub line 1 (String.length line - 1)));
    true
  end
  else
    match words with
    | [] | [ "n" ] | [ "next" ] ->
        next state;
        true
    | [ "a" ] | [ "answer" ] ->
        with_current state (fun question -> List.iter print_endline (answer_lines question); flush stdout);
        true
    | [ "t" ] | [ "tree" ] ->
        with_current state (fun question -> Ui.derivation stdout question; flush stdout);
        true
    | [ "pg" ] ->
        with_current state (fun question ->
            print_string (Rhema_cli.questions_document state.spec [ question ]);
            flush stdout);
        true
    | [ "how" ] ->
        if state.shown = 0 then refuse state "no question has been shown yet"
        else say "%s" (command state ~count:state.shown);
        true
    | [ "question"; name ] ->
        (* a budget set by hand stays set, if the new question type has it *)
        change state ~question:(Some name) ~overrides:state.overrides ~seed:state.seed;
        true
    | [ "reset" ] ->
        change state ~question:state.question ~overrides:[] ~seed:state.seed;
        true
    | [ "seed" ] ->
        change state ~question:state.question ~overrides:state.overrides ~seed:None;
        true
    | [ "seed"; value ] ->
        (match int_of_string_opt value with
        | Some seed -> change state ~question:state.question ~overrides:state.overrides ~seed:(Some seed)
        | None -> refuse state ("seed takes a whole number, not " ^ value));
        true
    | [ "list" ] | [ "questions" ] ->
        listing state;
        true
    | [ "?" ] | [ "help" ] ->
        List.iter print_endline help;
        flush stdout;
        true
    | [ "quit" ] | [ "exit" ] -> false
    | word :: _ ->
        if not (budget_change ()) then
          refuse state
            (Printf.sprintf "'%s' is not a command of the session%s; ? lists them" line
               (Rhema_cli.did_you_mean word commands));
        true

(* Run a session on [base], which is already checked. The question type,
   budgets, seed, assignment and student are those of the command line. *)
let run ui ~file ~base ~question ~overrides ~seed ~student ~assignment =
  match configured base ~question ~overrides with
  | Error message ->
      prerr_endline (file ^ ": error: " ^ message);
      exit 1
  | Ok spec ->
      let state =
        { ui; file; base; student; assignment; question; overrides; seed; spec; shown = 0;
          random = Random.get_state (); current = None }
      in
      let asking = Unix.isatty Unix.stdin in
      Ui.note ui "Enter: the next question.  a: its answer.  ?: every command.  quit: end.";
      restart state;
      status state;
      next state;
      let rec loop () =
        if asking then Printf.eprintf "try> %!";
        match In_channel.input_line stdin with
        | None -> if asking then prerr_newline ()
        | Some line -> if obey state line then loop ()
      in
      loop ()
