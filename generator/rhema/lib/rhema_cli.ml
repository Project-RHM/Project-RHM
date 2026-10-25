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
let questions spec ~variant ~count =
  Random.init variant;
  List.init count (fun _ -> Rhema_engine.generate spec)

let questions_listing questions =
  questions
  |> List.mapi (fun index (question : Rhema_engine.question) ->
         Printf.sprintf "%2d. %s\n    %s: %s\n" (index + 1) question.Rhema_engine.prompt
           (if List.length question.Rhema_engine.answers > 1 then "answers" else "answer")
           question.Rhema_engine.answer_text)
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
