(* agrun.ml — generate questions from a .ag file.

   Usage:
     agrun [options] FILE.ag

   Options:
     --pg              emit a complete WeBWorK .pg document
     --count N         how many questions (default 5)
     --seed N          random seed (default 0)
     --seed-from ID    derive the seed from a string, so the same student id
                       always produces the same paper (same rule as
                       Generator.seed_of_id, which the existing generator uses)
     --set NAME=VALUE  override an inherited attribute's starting value
     --question NAME   generate one of the file's named questions (default: main)
     --run NAME        generate the set NAME declared in the file (its own budgets
                       and count; --set, --count and --question do not apply)
     --pg-dir DIR      with --run: one .pg file per question, written to DIR
     --out FILE        write to FILE instead of standard output
     --ast-out FILE    write the attributed derivations as readable text
     --visualization-out FILE
                       write an interactive production/attribute tree

   --set is how difficulty arrives from outside: the .ag file decides what a
   question looks like, the caller decides how hard it starts. Without it, the
   values written in the file are used. *)

type options = {
  filename : string;
  question : string option;
  run : string option;  (* a set of the file to generate *)
  pg_dir : string option;  (* one .pg file per question of the set, here *)
  count : int;
  seed : int;
  overrides : (string * int) list;
  as_pg : bool;
  output : string option;
  ast_output : string option;
  visualization_output : string option;
}

let usage () =
  prerr_endline
    "usage: agrun [--pg] [--count N] [--seed N] [--question NAME | --run SET [--pg-dir DIR]] [--set NAME=VALUE]... \
     [--out FILE] [--ast-out FILE] [--visualization-out FILE] FILE.ag";
  exit 2

(* The same derivation the existing generator uses, so a student id maps to the
   same paper whichever path produced it. *)
let seed_of_id id =
  let hex = Digest.to_hex (Digest.string id) in
  int_of_string ("0x" ^ String.sub hex 0 8)

let parse_override text =
  match String.index_opt text '=' with
  | None ->
      prerr_endline ("--set expects NAME=VALUE, but received: " ^ text);
      exit 2
  | Some index -> (
      let name = String.sub text 0 index |> String.trim in
      let value = String.sub text (index + 1) (String.length text - index - 1) in
      match int_of_string_opt (String.trim value) with
      | Some value -> (name, value)
      | None ->
          prerr_endline ("--set expects a whole number, but received: " ^ text);
          exit 2)

let parse_arguments () =
  let rec walk arguments accumulated =
    match arguments with
    | [] -> accumulated
    | "--pg" :: rest -> walk rest { accumulated with as_pg = true }
    | "--count" :: value :: rest ->
        walk rest { accumulated with count = int_of_string value }
    | "--seed" :: value :: rest -> walk rest { accumulated with seed = int_of_string value }
    | "--seed-from" :: value :: rest -> walk rest { accumulated with seed = seed_of_id value }
    | "--set" :: value :: rest ->
        walk rest
          { accumulated with overrides = accumulated.overrides @ [ parse_override value ] }
    | "--question" :: value :: rest -> walk rest { accumulated with question = Some value }
    | "--run" :: value :: rest -> walk rest { accumulated with run = Some value }
    | "--pg-dir" :: value :: rest -> walk rest { accumulated with pg_dir = Some value }
    | "--out" :: value :: rest -> walk rest { accumulated with output = Some value }
    | "--ast-out" :: value :: rest ->
        walk rest { accumulated with ast_output = Some value }
    | "--visualization-out" :: value :: rest ->
        walk rest { accumulated with visualization_output = Some value }
    | option :: _ when String.length option > 1 && option.[0] = '-' ->
        prerr_endline ("unknown option: " ^ option);
        usage ()
    | filename :: rest ->
        if accumulated.filename <> "" then usage ()
        else walk rest { accumulated with filename }
  in
  let options =
    walk
      (Array.to_list Sys.argv |> List.tl)
      {
        filename = "";
        question = None;
        run = None;
        pg_dir = None;
        count = 5;
        seed = 0;
        overrides = [];
        as_pg = false;
        output = None;
        ast_output = None;
        visualization_output = None;
      }
  in
  if options.filename = "" then usage ();
  options

let write_file path text =
  let channel = open_out path in
  Fun.protect ~finally:(fun () -> close_out channel) (fun () -> output_string channel text)

(* --run NAME: the set's own entries say what to generate and how hard. *)
let run_set options (spec : Ag_check.spec) =
  let name = Option.get options.run in
  if options.question <> None then begin
    prerr_endline "--question and --run cannot be combined: a set names its own questions";
    exit 2
  end;
  if options.overrides <> [] then
    prerr_endline "note: --set is ignored with --run; a set draws its own budgets";
  let set =
    match List.find_opt (fun (set : Ag_ast.set_decl) -> set.Ag_ast.set_name = name) spec.Ag_check.sets with
    | Some set -> set
    | None ->
        prerr_endline
          (Printf.sprintf "%s: '%s' is not a set of this file; it has %s" options.filename name
             (match spec.Ag_check.sets with
             | [] -> "none"
             | sets -> sets |> List.map (fun (set : Ag_ast.set_decl) -> set.Ag_ast.set_name) |> String.concat ", "));
        exit 1
  in
  let result =
    try Ag_sets.run spec set ~seed:options.seed
    with Ag_engine.Generation_error message ->
      prerr_endline ("generation failed: " ^ message);
      exit 1
  in
  (match options.pg_dir with
  | None -> ()
  | Some directory ->
      if not (Sys.file_exists directory) then Sys.mkdir directory 0o755;
      List.iter
        (fun (file, text) -> write_file (Filename.concat directory file) text)
        (Ag_sets.documents result);
      prerr_endline
        (Printf.sprintf "%d PG files written to %s" (List.length (Ag_sets.documents result)) directory));
  let text = if options.as_pg then Ag_sets.document result else Ag_sets.listing result in
  (match options.output with
  | None -> print_string text
  | Some path ->
      write_file path text;
      prerr_endline ("written to " ^ path));
  let questions = Ag_sets.questions result in
  (match options.ast_output with
  | None -> ()
  | Some path ->
      Ag_visualization.write_ast path questions;
      prerr_endline ("AST saved to: " ^ path));
  match options.visualization_output with
  | None -> ()
  | Some path ->
      Ag_visualization.write_html path ~grammar:options.filename questions;
      prerr_endline ("Tree visualization saved to: " ^ path)

let () =
  let options = parse_arguments () in
  match Ag_load.parse_file options.filename with
  | Error errors ->
      List.iter (fun error -> prerr_endline (Ag_load.string_of_failure error)) errors;
      exit 1
  | Ok spec when options.run <> None -> run_set options spec
  | Ok spec -> (
      if spec.Ag_check.library then begin
        prerr_endline
          (if spec.Ag_check.sets <> [] then
             Printf.sprintf "%s: this file has no question of its own; it holds the set%s %s, run one with --run NAME"
               options.filename
               (if List.length spec.Ag_check.sets = 1 then "" else "s")
               (spec.Ag_check.sets |> List.map (fun (set : Ag_ast.set_decl) -> set.Ag_ast.set_name) |> String.concat ", ")
           else
             options.filename
             ^ ": this file has no start symbol; it is a library, to be included by a grammar");
        exit 1
      end;
      (* The question comes first, then --set overrides its starting budgets. *)
      let spec =
        match options.question with
        | None -> spec
        | Some name -> (
            match Ag_check.select_question spec name with
            | Ok spec -> spec
            | Error message ->
                prerr_endline (options.filename ^ ": " ^ message);
                exit 1)
      in
      let spec =
        List.fold_left
          (fun spec (name, value) ->
            match Ag_check.with_initial spec name value with
            | Ok spec -> spec
            | Error message ->
                prerr_endline (options.filename ^ ": " ^ message);
                exit 1)
          spec options.overrides
      in
      Random.init options.seed;
      let questions =
        try
          List.init options.count (fun _ -> Ag_engine.generate spec)
        with Ag_engine.Generation_error message ->
          prerr_endline ("generation failed: " ^ message);
          exit 1
      in
      let text =
        if options.as_pg then
          Ag_pgml.document ?width:spec.Ag_check.width ~context:spec.Ag_check.context
            questions
        else
          questions
          |> List.mapi (fun index question ->
                 Printf.sprintf "%2d. %s\n    %s: %s\n" (index + 1)
                   question.Ag_engine.prompt
                   (if List.length question.Ag_engine.answers > 1 then "answers" else "answer")
                   question.Ag_engine.answer_text)
          |> String.concat ""
      in
      (match options.output with
      | None -> print_string text
      | Some path ->
          let channel = open_out path in
          Fun.protect
            ~finally:(fun () -> close_out channel)
            (fun () -> output_string channel text);
          prerr_endline ("written to " ^ path));
      (match options.ast_output with
      | None -> ()
      | Some path ->
          Ag_visualization.write_ast path questions;
          prerr_endline ("AST saved to: " ^ path));
      (match options.visualization_output with
      | None -> ()
      | Some path ->
          Ag_visualization.write_html path ~grammar:options.filename questions;
          prerr_endline ("Tree visualization saved to: " ^ path)))
