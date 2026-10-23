(* ag_load.ml — read a .ag file into a validated specification.

   Every failure comes back as "file:line:column: message" so that a user who
   mistypes something is pointed at the character, not told "parse error".

   An `include "other.ag"` declaration is resolved here, before checking: the
   other file's declarations are read (relative to the including file, and
   recursively) and placed before the including file's own. Rules, attributes,
   randoms, lets and precedences add up; of the declarations a grammar makes
   once -- start, context, prompt, answer, width -- the including file's own
   wins over an included one, so a grammar can include another grammar and
   re-ask its question. A file that includes itself, directly or through
   others, is refused.

   An `import "other.ag" as name` declaration is resolved here too, but the
   other file is not merged: it is loaded and checked as a module of its own,
   once per run however many files import it, and handed to the checker so
   that `name.F`, `name.cost` and `name.given` can be resolved. A file that
   imports itself, directly or through others, is refused. *)

type failure = { where : string; what : string }

let string_of_failure failure = failure.where ^ ": " ^ failure.what

let describe_position filename (position : Lexing.position) =
  Printf.sprintf "%s:%d:%d" filename position.Lexing.pos_lnum
    (position.Lexing.pos_cnum - position.Lexing.pos_bol + 1)

let parse_declarations ~filename source : (Ag_ast.file, failure list) result =
  let lexbuf = Lexing.from_string source in
  lexbuf.Lexing.lex_curr_p <-
    { lexbuf.Lexing.lex_curr_p with Lexing.pos_fname = filename };
  match Ag_parser.file Ag_lexer.token lexbuf with
  | declarations -> Ok declarations
  | exception Ag_lexer.Lexing_error (message, position) ->
      Error [ { where = describe_position filename position; what = message } ]
  | exception Ag_parser.Error ->
      let position = Lexing.lexeme_start_p lexbuf in
      let token = Lexing.lexeme lexbuf in
      let what =
        if token = "" then "unexpected end of file"
        else Printf.sprintf "unexpected %s" (String.escaped token)
      in
      Error [ { where = describe_position filename position; what } ]

let read_file filename =
  let channel = open_in_bin filename in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))

(* The declarations a grammar makes once. An including file's own override
   those of the files it includes. *)
let singleton_kind = function
  | Ag_ast.Start_decl _ -> Some "start"
  | Ag_ast.Context_decl _ -> Some "context"
  | Ag_ast.Prompt_decl _ -> Some "prompt"
  | Ag_ast.Answer_decl _ -> Some "answer"
  | Ag_ast.Width_decl _ -> Some "width"
  | _ -> None

(* Two files may both declare the same attribute, random or let; one copy is
   kept when they agree (a random with the same draw, a let with the same
   body), and the checker reports the clash when they do not. For an
   inherited attribute the first declaration seen wins, so two included
   grammars with different default budgets do not clash, and the including
   file's own declaration, placed first below, wins over both. *)
let same_declaration left right =
  match (left, right) with
  | Ag_ast.Synthesized_decl (a, scope_a, _), Ag_ast.Synthesized_decl (b, scope_b, _) ->
      a = b && scope_a = scope_b
  | Ag_ast.Inherited_decl (a, _, _, _), Ag_ast.Inherited_decl (b, _, _, _) -> a = b
  | Ag_ast.Random_decl (a, draw_a, _), Ag_ast.Random_decl (b, draw_b, _) -> a = b && draw_a = draw_b
  | Ag_ast.Let_decl (a, body_a, _), Ag_ast.Let_decl (b, body_b, _) -> a = b && body_a = body_b
  | Ag_ast.Import_decl (a, alias_a, _), Ag_ast.Import_decl (b, alias_b, _) ->
      a = b && alias_a = alias_b
  | _ -> false

let is_inherited_decl = function Ag_ast.Inherited_decl _ -> true | _ -> false

let resolve ~directory name =
  if Filename.is_relative name then Filename.concat directory name else name

(* A module is identified by its file, so "lib/../boolean.ag" and
   "boolean.ag" must come out the same. Lexical only: no symlinks are followed. *)
let normalize_path path =
  let absolute = not (Filename.is_relative path) in
  let parts = String.split_on_char '/' path in
  let rec walk kept = function
    | [] -> List.rev kept
    | ("" | ".") :: rest -> walk kept rest
    | ".." :: rest -> (
        match kept with
        | parent :: before when parent <> ".." -> walk before rest
        | _ -> walk (".." :: kept) rest)
    | part :: rest -> walk (part :: kept) rest
  in
  let joined = String.concat "/" (walk [] parts) in
  if absolute then "/" ^ joined else if joined = "" then "." else joined

(* Every module loaded during one top-level load, by its file, so two imports
   of one file (from two different importers, or under two aliases) share a
   single checked specification. *)
type cache = (string, (Ag_check.spec, failure list) result) Hashtbl.t

let rec load_declarations ~stack filename : (Ag_ast.file, failure list) result =
  if List.mem filename stack then
    Error
      [
        {
          where = filename;
          what =
            "this file includes itself: "
            ^ String.concat " -> " (List.rev (filename :: stack));
        };
      ]
  else
    match read_file filename with
    | exception Sys_error message -> Error [ { where = filename; what = message } ]
    | source -> (
        match parse_declarations ~filename source with
        | Error failures -> Error failures
        | Ok declarations ->
            expand ~stack:(filename :: stack) ~directory:(Filename.dirname filename)
              declarations)

and expand ~stack ~directory declarations =
  let own_singletons = List.filter_map singleton_kind declarations in
  let keep declaration =
    match singleton_kind declaration with
    | Some kind -> not (List.mem kind own_singletons)
    | None -> true
  in
  let merge accumulated incoming =
    List.fold_left
      (fun accumulated declaration ->
        if List.exists (same_declaration declaration) accumulated then accumulated
        else accumulated @ [ declaration ])
      accumulated incoming
  in
  let rec go accumulated = function
    | [] -> Ok accumulated
    | Ag_ast.Include_decl (name, _) :: rest -> (
        let path = resolve ~directory name in
        match load_declarations ~stack path with
        | Error failures -> Error failures
        | Ok included -> go (merge accumulated (List.filter keep included)) rest)
    (* An import inside an included file is relative to that file, so its
       path is fixed here, while the directory is still known. *)
    | Ag_ast.Import_decl (name, alias, position) :: rest ->
        let path = normalize_path (resolve ~directory name) in
        go (merge accumulated [ Ag_ast.Import_decl (path, alias, position) ]) rest
    | declaration :: rest -> go (merge accumulated [ declaration ]) rest
  in
  (* The including file's own attributes go first, so that they win. *)
  let own_attributes = List.filter is_inherited_decl declarations in
  go own_attributes (List.filter (fun d -> not (is_inherited_decl d)) declarations)

let describe_errors ~filename errors =
  List.map
    (fun (error : Ag_check.error) ->
      let position = error.Ag_check.position in
      let file = if position.Ag_ast.file = "" then filename else position.Ag_ast.file in
      {
        where =
          (if position.Ag_ast.line = 0 then file
           else Printf.sprintf "%s:%d:%d" file position.Ag_ast.line position.Ag_ast.column);
        what = error.Ag_check.message;
      })
    errors

let describe_position_of (position : Ag_ast.position) filename =
  let file = if position.Ag_ast.file = "" then filename else position.Ag_ast.file in
  if position.Ag_ast.line = 0 then file
  else Printf.sprintf "%s:%d:%d" file position.Ag_ast.line position.Ag_ast.column

(* Load every module the (already include-expanded) declarations import, then
   check the declarations against them. [stack] holds the files being loaded,
   so a file that imports one of them has closed a cycle. *)
let rec check ~stack ~cache ~filename ~source declarations =
  let rec load_modules loaded = function
    | [] -> Ok (List.rev loaded)
    | Ag_ast.Import_decl (path, alias, position) :: rest -> (
        let where = describe_position_of position filename in
        if List.mem path stack then
          Error
            [
              {
                where;
                what =
                  Printf.sprintf "import \"%s\" as %s closes a cycle: %s" path alias
                    (String.concat " -> " (List.rev (path :: stack)));
              };
            ]
        else
          match load_module ~stack ~cache path with
          | Ok module_spec -> load_modules ((alias, module_spec) :: loaded) rest
          | Error failures ->
              Error
                ({
                   where;
                   what =
                     Printf.sprintf "import \"%s\" as %s: the module has problems of its own"
                       path alias;
                 }
                :: failures))
    | _ :: rest -> load_modules loaded rest
  in
  match load_modules [] declarations with
  | Error failures -> Error failures
  | Ok modules -> (
      match Ag_check.check ~source ~modules declarations with
      | Ok spec -> Ok spec
      | Error errors -> Error (describe_errors ~filename errors))

and load_module ~stack ~cache path =
  match Hashtbl.find_opt cache path with
  | Some result -> result
  | None ->
      let result =
        match load_declarations ~stack path with
        | Error failures -> Error failures
        | Ok declarations ->
            check ~stack:(path :: stack) ~cache ~filename:path ~source:path declarations
      in
      Hashtbl.replace cache path result;
      result

let parse_string ?(filename = "<input>") source :
    (Ag_check.spec, failure list) result =
  match parse_declarations ~filename source with
  | Error failures -> Error failures
  | Ok declarations -> (
      let directory =
        if filename = "<input>" then Filename.current_dir_name else Filename.dirname filename
      in
      match expand ~stack:[ filename ] ~directory declarations with
      | Error failures -> Error failures
      | Ok declarations ->
          check ~stack:[ filename ] ~cache:(Hashtbl.create 4) ~filename ~source:"" declarations)

let parse_file filename =
  let path = normalize_path filename in
  match load_declarations ~stack:[] path with
  | Error failures -> Error failures
  | Ok declarations ->
      check ~stack:[ path ] ~cache:(Hashtbl.create 4) ~filename ~source:path declarations
