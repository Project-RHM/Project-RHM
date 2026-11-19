(* rhema_cli.ml -- what the command shares with the tests: how a paper is
   named, how a grammar is generated into text or PG, how failures are
   printed, and where the library is. `rhema` is thin over this. *)

(* The same derivation the existing generator uses, so a student id maps to the
   same paper whichever path produced it. *)
let seed_of_id id =
  let hex = Digest.to_hex (Digest.string id) in
  int_of_string ("0x" ^ String.sub hex 0 8)

(* An assignment is one paper: the variant the engine starts from is derived
   from the assignment's name, so generating it again gives the same paper and
   nobody chooses a number. With a student the paper is that student's own,
   derived from both names. An explicit variant (the tools and tests) wins. *)
let variant ~assignment ~student ~seed =
  match (seed, student) with
  | Some seed, _ -> seed
  | None, Some student -> seed_of_id (assignment ^ "/" ^ student)
  | None, None -> seed_of_id assignment

let paper ~assignment ~student =
  match student with
  | Some student -> Printf.sprintf "%s for %s" assignment student
  | None -> assignment

(* FILE:QUESTION, the default assignment name of a run that is not a set. *)
let default_assignment ~filename ~question =
  Filename.remove_extension (Filename.basename filename)
  ^ ":" ^ Option.value ~default:"main" question

(* GNU style: file:line:col: error: message. *)
let describe_failure (failure : Rhema_load.failure) =
  failure.Rhema_load.where ^ ": error: " ^ failure.Rhema_load.what

let write_file path text =
  let channel = open_out path in
  Fun.protect ~finally:(fun () -> close_out channel) (fun () -> output_string channel text)

(* Generate [count] questions of the selected question of [spec]. *)
let questions ?(on_question = fun _ _ -> ()) spec ~variant ~count =
  Random.init variant;
  List.init count (fun index ->
      let question = Rhema_engine.generate spec in
      on_question (index + 1) count;
      question)

let questions_listing questions =
  questions
  |> List.mapi (fun index (question : Rhema_engine.question) ->
         Printf.sprintf "%2d. %s\n    %s: %s\n%s" (index + 1) question.Rhema_engine.prompt
           (if List.length question.Rhema_engine.answers > 1 then "answers" else "answer")
           question.Rhema_engine.answer_text
           (* what each mistake that can be made here leads to *)
           (Rhema_engine.describe_mistakes question
           |> List.map (fun line -> "    " ^ line ^ "\n")
           |> String.concat ""))
  |> String.concat ""

let questions_document (spec : Rhema_check.spec) questions =
  Rhema_pgml.document ?width:spec.Rhema_check.width ~context:spec.Rhema_check.context questions

(* Where the library grammars are, for a command living at [executable]:
   the source tree when run from the build directory, share/rhema when
   installed. Only directories that exist are kept. *)
let default_search_path executable =
  let exe_dir = Filename.dirname executable in
  let candidates =
    [
      Filename.concat exe_dir "../share/rhema";
      (* the source tree: _build/default/rhema/bin -> generator/stdlib *)
      Filename.concat exe_dir "../../../../stdlib";
      exe_dir;
    ]
  in
  List.filter (fun dir -> Sys.file_exists dir && Sys.is_directory dir) candidates

let path_separator = if Sys.win32 then ';' else ':'

let search_path_from_env () =
  match Sys.getenv_opt "RHEMA_PATH" with
  | None | Some "" -> []
  | Some value -> String.split_on_char path_separator value |> List.filter (fun dir -> dir <> "")

let version = Rhema_version.version

(* ------------------------------------------------------------------ *)
(* What the command needs to talk with a person                        *)
(* ------------------------------------------------------------------ *)

(* How many single-character edits turn [left] into [right]. *)
let edit_distance left right =
  let m = String.length left and n = String.length right in
  let previous = Array.init (n + 1) Fun.id in
  for i = 1 to m do
    let diagonal = ref previous.(0) in
    previous.(0) <- i;
    for j = 1 to n do
      let above = previous.(j) in
      let cost = if left.[i - 1] = right.[j - 1] then 0 else 1 in
      previous.(j) <- min (min (above + 1) (previous.(j - 1) + 1)) (!diagonal + cost);
      diagonal := above
    done
  done;
  previous.(n)

(* The names of [names] that [word] was most likely meant to be: those
   nearest to it, within two edits and within a third of the word's length,
   so that a short word is not turned into another. Usually one name, none
   when nothing is near, several when they are equally near. *)
let near word names =
  let limit = min 2 (max 1 (String.length word / 3)) in
  let scored =
    names
    |> List.sort_uniq String.compare
    |> List.filter (fun name -> name <> word)
    |> List.map (fun name -> (edit_distance word name, name))
    |> List.filter (fun (distance, _) -> distance <= limit)
    |> List.sort compare
  in
  match scored with
  | [] -> []
  | (best, _) :: _ -> List.filter_map (fun (distance, name) -> if distance = best then Some name else None) scored

(* The one name that was meant, when there is exactly one. *)
let nearest word names = match near word names with [ name ] -> Some name | _ -> None

(* " (did you mean --count?)", or nothing: for the end of an error message. *)
let did_you_mean word names =
  match near word names with
  | [] -> ""
  | [ name ] -> Printf.sprintf " (did you mean %s?)" name
  | several -> Printf.sprintf " (did you mean %s?)" (String.concat " or " several)

(* A number as a person types it: 12, -7, 3/4, 0.25. None for anything
   else, and for a number too large to be kept exact. *)
let number_of_text text =
  let text = String.trim text in
  let digits text = text <> "" && String.for_all (fun c -> c >= '0' && c <= '9') text in
  let signed text =
    if text <> "" && (text.[0] = '-' || text.[0] = '+') then
      ((if text.[0] = '-' then -1 else 1), String.sub text 1 (String.length text - 1))
    else (1, text)
  in
  let whole text = if digits text then int_of_string_opt text else None in
  let sign, body = signed text in
  try
    match (String.index_opt body '/', String.index_opt body '.') with
    | Some at, None -> (
        let top = String.sub body 0 at in
        let bottom = String.sub body (at + 1) (String.length body - at - 1) in
        match (whole (String.trim top), whole (String.trim bottom)) with
        | Some top, Some bottom when bottom <> 0 -> Some (Rhema_number.make (sign * top) bottom)
        | _ -> None)
    | None, Some at -> (
        let before = String.sub body 0 at in
        let after = String.sub body (at + 1) (String.length body - at - 1) in
        if before = "" && after = "" then None
        else if not ((before = "" || digits before) && (after = "" || digits after)) then None
        else
          match (whole (before ^ after), whole ("1" ^ String.make (String.length after) '0')) with
          | Some top, Some bottom -> Some (Rhema_number.make (sign * top) bottom)
          | _ -> None)
    | None, None -> Option.map (fun n -> Rhema_number.of_int (sign * n)) (whole body)
    | Some _, Some _ -> None
  with Rhema_number.Arithmetic_error _ -> None
