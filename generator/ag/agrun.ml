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
     --out FILE        write to FILE instead of standard output
     --ast-out FILE    write the attributed derivations as readable text
     --visualization-out FILE
                       write an interactive production/attribute tree

   --set is how difficulty arrives from outside: the .ag file decides what a
   question looks like, the caller decides how hard it starts. Without it, the
   values written in the file are used. *)

type options = {
  filename : string;
  count : int;
  seed : int;
  overrides : (string * int) list;
  as_pg : bool;
  output : string option;
  ast_output : string option;
  visualization_output : string option;
  pick : int list;
}

let usage () =
  prerr_endline
    "usage: agrun [--pg] [--count N] [--seed N] [--set NAME=VALUE]... \
     [--out FILE] [--ast-out FILE] [--visualization-out FILE] [--pick I,J,...] FILE.ag";
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
    | "--out" :: value :: rest -> walk rest { accumulated with output = Some value }
    | "--ast-out" :: value :: rest ->
        walk rest { accumulated with ast_output = Some value }
    | "--visualization-out" :: value :: rest ->
        walk rest { accumulated with visualization_output = Some value }
    (* Keep only these questions (1-based) of the --count generated, so a
       caller that chose them from a pool can ask for exactly those again. *)
    | "--pick" :: value :: rest ->
        let picks =
          String.split_on_char ',' value |> List.filter (( <> ) "")
          |> List.map (fun text ->
                 match int_of_string_opt (String.trim text) with
                 | Some index when index >= 1 -> index
                 | _ ->
                     prerr_endline ("--pick expects 1-based indices, but received: " ^ value);
                     exit 2)
        in
        walk rest { accumulated with pick = picks }
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
        count = 5;
        seed = 0;
        overrides = [];
        as_pg = false;
        output = None;
        ast_output = None;
        visualization_output = None;
        pick = [];
      }
  in
  if options.filename = "" then usage ();
  options

let () =
  let options = parse_arguments () in
  match Ag_load.parse_file options.filename with
  | Error errors ->
      List.iter (fun error -> prerr_endline (Ag_load.string_of_failure error)) errors;
      exit 1
  | Ok spec -> (
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
      let questions =
        match options.pick with
        | [] -> questions
        | picks ->
            List.map
              (fun index ->
                match List.nth_opt questions (index - 1) with
                | Some question -> question
                | None ->
                    prerr_endline
                      (Printf.sprintf "--pick %d is beyond the %d questions generated" index
                         options.count);
                    exit 2)
              picks
      in
      let text =
        if options.as_pg then
          Ag_pgml.document ?width:spec.Ag_check.width ~context:spec.Ag_check.context
            ?stem:spec.Ag_check.stem questions
        else
          (match spec.Ag_check.stem with Some stem -> "Stem: " ^ stem ^ "\n\n" | None -> "")
          ^ (questions
            |> List.mapi (fun index question ->
                   Printf.sprintf "%2d. %s\n    answer: %s\n" (index + 1)
                     question.Ag_engine.prompt question.Ag_engine.answer_text)
            |> String.concat "")
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
