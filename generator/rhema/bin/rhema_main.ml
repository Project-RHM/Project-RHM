(* rhema.ml -- the Rhema command.

     rhema FILE.rhm [-o OUT.pg] [options]   compile: check the file, generate,
                                            write WeBWorK PG (default OUT:
                                            FILE.pg, or SET.pg with --run)
     rhema check FILE...                    check only, report problems
     rhema run FILE [options]               generate and show the questions
     rhema list FILE                        the questions and sets of a file
     rhema doc                              the builtin functions
     rhema --version | --help

   Problems are reported as file:line:col: error: message, and the exit code
   is 0 when all went well, 1 when the input or the generation failed, 2 when
   the command line was wrong. *)

let program = "rhema"

module Ui = Rhema_terminal

let usage =
  String.concat "\n"
    [
      "usage: rhema FILE.rhm [-o OUT.pg] [options]     compile FILE to WeBWorK PG";
      "       rhema check FILE...                      check only";
      "       rhema run FILE [options]                 show the questions and answers";
      "       rhema list FILE                          the questions and sets FILE declares";
      "       rhema doc [NAME]                         the builtin functions (or one of them)";
      "       rhema --version | --help";
      "";
      "options (compile and run):";
      "  --question NAME     one of the file's named questions (default: main)";
      "  --run SET           the set SET declared in the file";
      "  --count N           how many questions, when not a set (default 5)";
      "  --assignment NAME   the assignment this paper is; one assignment is one";
      "                      paper, the same every time (default: the set's name,";
      "                      or FILE:QUESTION)";
      "  --student ID        a paper of this student's own for the assignment";
      "  --set NAME=VALUE    start an inherited attribute of the question there";
      "  -I DIR              also look for imported and included files in DIR";
      "                      (after the file's own directory; RHEMA_PATH too)";
      "  --pg-dir DIR        with --run: one .pg file per question, in DIR";
      "  --ast-out FILE, --visualization-out FILE   save the derivation trees too";
      "";
      "terminal output:";
      "  --plain             omit the banner, progress and styled diagnostics";
      "  --no-color          disable colors (also respects NO_COLOR)";
      "  --no-emoji          use ASCII status markers and progress bar";
      "  -v, --verbose       show accepted rules and attribute values on stderr";
      "";
      "Every imported or included file is looked for beside the importing one,";
      "then in the -I directories, RHEMA_PATH, and the installed library.";
    ]

let fail_usage message =
  prerr_endline (program ^ ": " ^ message);
  prerr_endline usage;
  exit 2

type options = {
  mutable files : string list;
  mutable output : string option;
  mutable question : string option;
  mutable run : string option;
  mutable count : int;
  mutable assignment : string option;
  mutable student : string option;
  mutable seed : int option;
  mutable overrides : (string * int) list;
  mutable includes : string list;
  mutable pg_dir : string option;
  mutable ast_output : string option;
  mutable visualization_output : string option;
  mutable terminal : Ui.options;
}

let parse_override text =
  match String.index_opt text '=' with
  | None -> fail_usage ("--set expects NAME=VALUE, not " ^ text)
  | Some index -> (
      let name = String.trim (String.sub text 0 index) in
      let value = String.trim (String.sub text (index + 1) (String.length text - index - 1)) in
      match int_of_string_opt value with
      | Some value -> (name, value)
      | None -> fail_usage ("--set expects a whole number, not " ^ text))

let known_options =
  [ "-o"; "--out"; "--question"; "--run"; "--count"; "--assignment"; "--student"; "--seed";
    "--set"; "-I"; "--pg-dir"; "--ast-out"; "--visualization-out" ]

let parse_options terminal arguments =
  let options =
    {
      files = [];
      output = None;
      question = None;
      run = None;
      count = 5;
      assignment = None;
      student = None;
      seed = None;
      overrides = [];
      includes = [];
      pg_dir = None;
      ast_output = None;
      visualization_output = None;
      terminal;
    }
  in
  let number flag value =
    match int_of_string_opt value with
    | Some n -> n
    | None -> fail_usage (flag ^ " expects a whole number, not " ^ value)
  in
  let rec walk = function
    | [] -> ()
    | "-o" :: value :: rest | "--out" :: value :: rest ->
        options.output <- Some value;
        walk rest
    | "--question" :: value :: rest ->
        options.question <- Some value;
        walk rest
    | "--run" :: value :: rest ->
        options.run <- Some value;
        walk rest
    | "--count" :: value :: rest ->
        options.count <- number "--count" value;
        walk rest
    | "--assignment" :: value :: rest ->
        options.assignment <- Some value;
        walk rest
    | "--student" :: value :: rest ->
        options.student <- Some value;
        walk rest
    | "--seed" :: value :: rest ->
        (* not in the usage text: a variant as a number, for tools and tests *)
        options.seed <- Some (number "--seed" value);
        walk rest
    | "--set" :: value :: rest ->
        options.overrides <- options.overrides @ [ parse_override value ];
        walk rest
    | "-I" :: value :: rest ->
        options.includes <- options.includes @ [ value ];
        walk rest
    | "--pg-dir" :: value :: rest ->
        options.pg_dir <- Some value;
        walk rest
    | "--ast-out" :: value :: rest ->
        options.ast_output <- Some value;
        walk rest
    | "--visualization-out" :: value :: rest ->
        options.visualization_output <- Some value;
        walk rest
    | [ flag ] when List.mem flag known_options -> fail_usage (flag ^ " needs a value")
    | flag :: rest when String.length flag > 1 && flag.[0] = '-' -> (
        match Ui.option options.terminal flag with
        | Some terminal ->
            options.terminal <- terminal;
            walk rest
        | None -> fail_usage ("unknown option " ^ flag))
    | file :: rest ->
        options.files <- options.files @ [ file ];
        walk rest
  in
  walk arguments;
  options

(* ------------------------------------------------------------------ *)
(* Loading                                                             *)
(* ------------------------------------------------------------------ *)

let set_search_path options =
  Rhema_load.search_path :=
    options.includes @ Rhema_cli.search_path_from_env ()
    @ Rhema_cli.default_search_path Sys.executable_name

(* The one file a compile, run or list works on. *)
let the_file options =
  match options.files with
  | [ file ] -> file
  | [] -> fail_usage "no input file"
  | _ -> fail_usage "one input file at a time (check takes several)"

let load ui ?note file =
  match Rhema_load.parse_file file with
  | Ok spec -> spec
  | Error failures ->
      Ui.specification_errors ui ?note failures;
      exit 1

let abort ui ?note ~heading file message =
  Ui.errors ui ?note ~heading [ { Rhema_load.where = file; what = message; kind = Other } ];
  exit 1

let set_names (spec : Rhema_check.spec) =
  spec.Rhema_check.sets |> List.map (fun (set : Rhema_ast.set_decl) -> set.Rhema_ast.set_name)

let question_names (spec : Rhema_check.spec) =
  spec.Rhema_check.questions |> List.map (fun (q : Rhema_check.question) -> q.Rhema_check.q_name)

let list_or_none = function [] -> "none" | names -> String.concat ", " names

(* ------------------------------------------------------------------ *)
(* What a run produces                                                 *)
(* ------------------------------------------------------------------ *)

type product =
  | Questions of Rhema_check.spec * Rhema_engine.question list
  | Set of Rhema_sets.result

let assignment_of options file =
  match options.assignment with
  | Some name -> name
  | None -> (
      match options.run with
      | Some set -> set
      | None -> Rhema_cli.default_assignment ~filename:file ~question:options.question)

let produce ui ~compiling options file =
  if options.run <> None && options.question <> None then
    fail_usage "--question and --run cannot be combined: a set names its own questions";
  if options.run = None && options.count < 0 then fail_usage "--count must be non-negative";
  let assignment = assignment_of options file in
  let variant = Rhema_cli.variant ~assignment ~student:options.student ~seed:options.seed in
  let paper = Rhema_cli.paper ~assignment ~student:options.student in
  let note = if compiling then Some "This run did not write a PG file." else None in
  let generation_error message = abort ui ?note ~heading:"Question generation failed" file message in
  let generate count work =
    Ui.generating ui;
    if count >= 100 then
      Ui.quip ui (Printf.sprintf "Are you sure? That's %d questions. Continuing." count);
    Ui.progress ui 0 count;
    match work () with
    | product ->
        Ui.finish_progress ui;
        product
    | exception Rhema_engine.Generation_error message -> generation_error message
  in
  Ui.banner ui;
  Ui.field ui "Specification" file;
  Ui.field ui "Assignment" assignment;
  Option.iter (Ui.field ui "Student ID") options.student;
  Ui.field ui "Seed" (string_of_int variant);
  Ui.stage ui 1 "Load specification";
  set_search_path options;
  let spec = load ui ?note file in
  Ui.loaded ui;
  let product =
    match options.run with
    | Some name -> (
        match
          List.find_opt (fun (set : Rhema_ast.set_decl) -> set.Rhema_ast.set_name = name) spec.Rhema_check.sets
        with
        | None ->
            generation_error
              (Printf.sprintf "'%s' is not a set of this file; it has %s" name (list_or_none (set_names spec)))
        | Some set ->
            let count =
              List.fold_left
                (fun total -> function Rhema_ast.Set_entry e -> total + e.se_count | _ -> total)
                0 set.Rhema_ast.set_items
            in
            generate count (fun () -> Set (Rhema_sets.run spec set ~variant ~paper ~on_question:(Ui.progress ui))))
    | None ->
        if spec.Rhema_check.library then
          generation_error
            (if spec.Rhema_check.sets <> [] then
               Printf.sprintf "this file has no question of its own; it holds the set%s %s, run one with --run NAME"
                 (if List.length spec.Rhema_check.sets = 1 then "" else "s")
                 (String.concat ", " (set_names spec))
             else
               "this file has no start symbol; it is a library, to be included or imported by a grammar");
        let selected = function Ok spec -> spec | Error message -> generation_error message in
        let spec =
          match options.question with
          | None -> spec
          | Some name -> (
              match Rhema_check.select_question spec name with
              | Ok spec -> spec
              | Error message ->
                  Ui.quip ui "404: question not found.";
                  generation_error message)
        in
        let spec =
          List.fold_left
            (fun spec (name, value) -> selected (Rhema_check.with_initial spec name value))
            spec options.overrides
        in
        generate options.count (fun () ->
            Questions (spec, Rhema_cli.questions spec ~variant ~count:options.count
              ~on_question:(Ui.progress ui)))
  in
  (product, variant)

let questions_of = function Questions (_, questions) -> questions | Set result -> Rhema_sets.questions result

(* ------------------------------------------------------------------ *)
(* Commands                                                            *)
(* ------------------------------------------------------------------ *)

let export ui file write =
  try write (); flush stdout with
  | Sys_error message | Failure message -> abort ui ~heading:"Output failed" file message
  | Unix.Unix_error (code, action, path) ->
      let message = Printf.sprintf "%s: %s (%s)" action (Unix.error_message code) path in
      abort ui ~heading:"Output failed" file message

let write_trees options ~file questions =
  Option.iter (fun path -> Rhema_visualization.write_ast path questions) options.ast_output;
  Option.iter
    (fun path -> Rhema_visualization.write_html path ~grammar:file questions)
    options.visualization_output

let tree_paths options =
  List.filter_map (fun (label, path) -> Option.map (fun path -> (label, path)) path)
    [ ("AST", options.ast_output); ("Tree", options.visualization_output) ]

let compile options =
  let file = the_file options in
  let output =
    match options.output with
    | Some path -> path
    | None -> (
        match options.run with
        | Some set -> set ^ ".pg"
        | None -> Filename.remove_extension file ^ ".pg")
  in
  if options.pg_dir <> None && options.run = None then fail_usage "--pg-dir goes with --run";
  let pg_stdout = output = "-" in
  let ui = Ui.create { options.terminal with plain = options.terminal.plain || pg_stdout } in
  let product, variant = produce ui ~compiling:true options file in
  let questions = questions_of product in
  Ui.trace ui questions;
  Ui.stage ui 4 "Export WeBWorK PG";
  if options.pg_dir <> None then
    Ui.quip ui "Rush B! One PG file per question, coming up.";
  export ui file (fun () ->
      let document =
        match product with
        | Questions (spec, questions) -> Rhema_cli.questions_document spec questions
        | Set result -> Rhema_sets.document result
      in
      (match (product, options.pg_dir) with
      | Set result, Some directory ->
          if not (Sys.file_exists directory) then Sys.mkdir directory 0o755;
          List.iter
            (fun (name, text) -> Rhema_cli.write_file (Filename.concat directory name) text)
            (Rhema_sets.documents result)
      | _ -> ());
      if pg_stdout then print_string document else Rhema_cli.write_file output document;
      write_trees options ~file questions);
  let paths =
    (if pg_stdout then [] else [ ("PG", output) ])
    @ (match options.pg_dir with None -> [] | Some path -> [ ("Individual PG", path) ])
    @ tree_paths options
  in
  Ui.summary ui ~count:(List.length questions) ~variant ~explicit_seed:options.seed ~paths

let run options =
  let file = the_file options in
  let ui = Ui.create options.terminal in
  let product, variant = produce ui ~compiling:false options file in
  let questions = questions_of product in
  Ui.trace ui questions;
  Ui.stage ui 4 "Show questions and answers";
  export ui file (fun () ->
      (match product with
      | Questions (_, questions) -> print_string (Rhema_cli.questions_listing questions)
      | Set result -> print_string (Rhema_sets.listing result));
      write_trees options ~file questions);
  Ui.summary ui ~count:(List.length questions) ~variant ~explicit_seed:options.seed
    ~paths:(tree_paths options)

let check options =
  if options.files = [] then fail_usage "check needs at least one file";
  set_search_path options;
  let ui = Ui.create options.terminal in
  let failed = ref false in
  List.iter
    (fun file ->
      match Rhema_load.parse_file file with
      | Error failures ->
          failed := true;
          Ui.specification_errors ui failures
      | Ok spec ->
          Printf.printf "%s: OK (%d rules; questions: %s; sets: %s%s)\n" file
            (List.length spec.Rhema_check.rules)
            (list_or_none (question_names spec))
            (list_or_none (set_names spec))
            (if spec.Rhema_check.library && spec.Rhema_check.sets = [] then "; a library" else ""))
    options.files;
  if !failed then exit 1;
  if List.length options.files > 1 then begin
    flush stdout;
    Ui.quip ui "Oh, that will be great! All specifications checked out."
  end

let list options =
  let file = the_file options in
  set_search_path options;
  let spec = load (Ui.create options.terminal) file in
  if spec.Rhema_check.imports <> [] then
    Printf.printf "imports:\n%s"
      (spec.Rhema_check.imports
      |> List.map (fun (alias, (m : Rhema_check.spec)) -> Printf.sprintf "  %s = %s\n" alias m.Rhema_check.source)
      |> String.concat "");
  if spec.Rhema_check.questions = [] then print_endline "questions: none (a library)"
  else begin
    print_endline "questions:";
    List.iter
      (fun (q : Rhema_check.question) ->
        Printf.printf "  %-14s start %s, context %s%s\n" q.Rhema_check.q_name q.Rhema_check.q_start
          q.Rhema_check.q_context
          (match
             List.filter
               (fun (name, value) ->
                 List.exists
                   (fun (a : Rhema_check.inherited_attribute) ->
                     a.Rhema_check.attribute_name = name && a.Rhema_check.initial <> value)
                   spec.Rhema_check.inherited)
               q.Rhema_check.q_initials
           with
          | [] -> ""
          | own ->
              ", "
              ^ String.concat ", " (List.map (fun (n, v) -> Printf.sprintf "%s = %d" n v) own)))
      spec.Rhema_check.questions
  end;
  if spec.Rhema_check.inherited <> [] then
    Printf.printf "budgets: %s\n"
      (spec.Rhema_check.inherited
      |> List.map (fun (a : Rhema_check.inherited_attribute) ->
             Printf.sprintf "%s = %d" a.Rhema_check.attribute_name a.Rhema_check.initial)
      |> String.concat ", ");
  if spec.Rhema_check.sets <> [] then begin
    print_endline "sets:";
    List.iter
      (fun (set : Rhema_ast.set_decl) ->
        let count =
          List.fold_left
            (fun total item ->
              match item with Rhema_ast.Set_entry e -> total + e.Rhema_ast.se_count | _ -> total)
            0 set.Rhema_ast.set_items
        in
        Printf.printf "  %-14s %d questions\n" set.Rhema_ast.set_name count)
      spec.Rhema_check.sets
  end

(* The builtin functions, grouped by the value type their name starts with. *)
let doc options =
  let wanted = match options.files with [] -> None | name :: _ -> Some name in
  (* The value type a function works on, from its name: matrix2 and
     matrix_add are matrix functions, differentiate a formula function. *)
  let group name =
    let starts prefix =
      String.length name >= String.length prefix
      && String.sub name 0 (String.length prefix) = prefix
    in
    match
      List.find_opt starts
        [ "formula"; "polynomial"; "equation"; "bool"; "matrix"; "set_"; "vector"; "complex" ]
    with
    | Some "set_" -> "set"
    | Some prefix -> prefix
    | None ->
        if name = "differentiate" then "formula"
        else if List.mem name [ "factorial"; "choose"; "permutations"; "gcd"; "lcm"; "pow_mod"; "mod_inverse" ]
        then "integers"
        else "general"
  in
  let entries =
    List.map (fun (name, arity) -> (group name, name, arity, "expression")) Rhema_check.expression_builtins
    @ List.map (fun (name, arity) -> ("generators", name, arity, "generator")) Rhema_check.generator_builtins
  in
  match wanted with
  | Some name -> (
      match List.find_opt (fun (_, n, _, _) -> n = name) entries with
      | Some (group, name, arity, kind) ->
          Printf.printf "%s: %s builtin of the %s group, %d argument%s\n" name kind group arity
            (if arity = 1 then "" else "s")
      | None ->
          prerr_endline (Printf.sprintf "%s: error: no builtin named '%s'" program name);
          exit 1)
  | None ->
      let groups =
        entries |> List.map (fun (g, _, _, _) -> g) |> List.sort_uniq compare
      in
      List.iter
        (fun group ->
          Printf.printf "%s\n" group;
          List.iter
            (fun (g, name, arity, kind) ->
              if g = group then
                Printf.printf "  %-28s %d arg%s%s\n" name arity (if arity = 1 then "" else "s")
                  (if kind = "generator" then "   (a leaf that draws a value)" else ""))
            entries)
        groups;
      print_endline "\nWhat each one does: https://project-rhm.github.io/reference/builtins/"

let nailong_harness terminal =
  let ui = Ui.create terminal in
  let file = "<nailong>" in
  let smoke =
    {|synth value
start Q
Q -> "multiply" { value = 6 * 7 }
prompt "What is six times seven?"
answer Q.value
|}
  in
  let fail = abort ui ~heading:"Nailong Harness failed" file in
  let spec =
    match Rhema_load.parse_string ~filename:file smoke with
    | Ok spec -> spec
    | Error failures ->
        Ui.errors ui ~heading:"Nailong Harness failed" failures;
        exit 1
  in
  match Rhema_cli.questions spec ~variant:42 ~count:1 with
  | [ { Rhema_engine.answer_text = "42"; _ } ] ->
      print_endline "Nailong Harness: PASS (parse, check, generate; answer = 42)";
      Ui.quip ui "Works on my machine."
  | _ -> fail "the sample's answer should be 42"
  | exception Rhema_engine.Generation_error message -> fail message

let rec leading_terminal_options options = function
  | flag :: rest as arguments -> (
      match Ui.option options flag with
      | Some options -> leading_terminal_options options rest
      | None -> (options, arguments))
  | [] -> (options, [])

let () =
  let terminal, arguments = leading_terminal_options Ui.defaults (List.tl (Array.to_list Sys.argv)) in
  let parse_options = parse_options terminal in
  match arguments with
  | [] | [ "--help" ] | [ "-h" ] | [ "help" ] ->
      Ui.banner (Ui.create terminal);
      print_endline usage;
      exit (if arguments = [] then 2 else 0)
  | [ "--version" ] | [ "-V" ] | [ "version" ] ->
      Printf.printf "%s %s (the Rhema language, RHM project)\n" program Rhema_cli.version
  | [ "--hello" ] -> Ui.hello (Ui.create terminal)
  | [ "--nailong" ] -> nailong_harness terminal
  | [ "--coffee" ] -> print_endline "418: I'm a teapot. I compile questions, not coffee."
  | "check" :: rest -> check (parse_options rest)
  | "run" :: rest -> run (parse_options rest)
  | "list" :: rest -> list (parse_options rest)
  | "doc" :: rest -> doc (parse_options rest)
  | arguments -> compile (parse_options arguments)
