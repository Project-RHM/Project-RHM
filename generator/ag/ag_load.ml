(* ag_load.ml — read a .ag file into a validated specification.

   Every failure comes back as "file:line:column: message" so that a user who
   mistypes something is pointed at the character, not told "parse error". *)

type failure = { where : string; what : string }

let string_of_failure failure = failure.where ^ ": " ^ failure.what

let describe_position filename (position : Lexing.position) =
  Printf.sprintf "%s:%d:%d" filename position.Lexing.pos_lnum
    (position.Lexing.pos_cnum - position.Lexing.pos_bol + 1)

let parse_string ?(filename = "<input>") source :
    (Ag_check.spec, failure list) result =
  let lexbuf = Lexing.from_string source in
  lexbuf.Lexing.lex_curr_p <-
    { lexbuf.Lexing.lex_curr_p with Lexing.pos_fname = filename };
  match Ag_parser.file Ag_lexer.token lexbuf with
  | declarations -> (
      match Ag_check.check declarations with
      | Ok spec -> Ok spec
      | Error errors ->
          Error
            (List.map
               (fun (error : Ag_check.error) ->
                 {
                   where =
                     (if error.Ag_check.position.Ag_ast.line = 0 then filename
                      else
                        Printf.sprintf "%s:%d:%d" filename
                          error.Ag_check.position.Ag_ast.line
                          error.Ag_check.position.Ag_ast.column);
                   what = error.Ag_check.message;
                 })
               errors))
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

let parse_file filename =
  match read_file filename with
  | source -> parse_string ~filename source
  | exception Sys_error message ->
      Error [ { where = filename; what = message } ]
