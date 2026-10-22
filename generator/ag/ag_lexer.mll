(* ag_lexer.mll — tokens of the .ag question-grammar language. *)

{
open Ag_parser

exception Lexing_error of string * Lexing.position

let error lexbuf message =
  raise (Lexing_error (message, Lexing.lexeme_start_p lexbuf))

let keywords = [
  "attribute",  ATTRIBUTE;
  "random",     RANDOM;
  "let",        LET;
  "boolean",    BOOLEAN;
  "synth",      SYNTH;
  "on",         ON;
  "start",      START;
  "context",    CONTEXT;
  "precedence", PRECEDENCE;
  "left",       LEFT;
  "right",      RIGHT;
  "nonassoc",   NONASSOC;
  "copy",       COPY;
  "split",      SPLIT;
  "when",       WHEN;
  "weight",     WEIGHT;
  "require",    REQUIRE;
  "prompt",     PROMPT;
  "answer",     ANSWER;
  "width",      WIDTH;
  "include",    INCLUDE;
  "and",        AND;
  "or",         OR;
  "not",        NOT;
]

let identifier_or_keyword text =
  match List.assoc_opt text keywords with
  | Some token -> token
  | None -> IDENT text

(* A .ag file is full of LaTeX, so a backslash that starts no known escape is
   kept as a plain backslash. That way both "\cdot" and "\\cdot" produce the
   same \cdot, and an author does not have to think about which one this
   language wants. *)
let string_buffer = Buffer.create 64
}

let newline    = '\r'? '\n'
let blank      = [' ' '\t']
let digit      = ['0'-'9']
let letter     = ['a'-'z' 'A'-'Z']
let identifier = (letter | '_') (letter | digit | '_')*

rule token = parse
  | newline           { Lexing.new_line lexbuf; token lexbuf }
  | blank+            { token lexbuf }
  | '#' [^ '\r' '\n']* { token lexbuf }

  | "->"              { ARROW }
  | "++"              { CONCAT }
  | "!="              { NEQ }
  | "<="              { LE }
  | ">="              { GE }
  | '='               { EQ }
  | '<'               { LT }
  | '>'               { GT }
  | '+'               { PLUS }
  | '-'               { MINUS }
  | '*'               { STAR }
  | '/'               { SLASH }
  | '%'               { PERCENT }
  | '^'               { CARET }
  | '.'               { DOT }
  | ','               { COMMA }
  | '('               { LPAREN }
  | ')'               { RPAREN }
  | '{'               { LBRACE }
  | '}'               { RBRACE }

  | '$' (digit+ as index)
      { match int_of_string_opt index with
        | Some value when value > 0 -> DOLLAR value
        | _ -> error lexbuf ("child reference out of range: $" ^ index) }

  | digit+ as number
      { match int_of_string_opt number with
        | Some value -> INT value
        | None -> error lexbuf ("integer literal is too large: " ^ number) }

  | identifier as text { identifier_or_keyword text }

  | '"'
      { Buffer.clear string_buffer;
        string_literal lexbuf;
        STRING (Buffer.contents string_buffer) }

  | eof               { EOF }
  | _ as character
      { error lexbuf (Printf.sprintf "unexpected character %C" character) }

and string_literal = parse
  | '"'               { () }
  (* Only two escapes exist, and on purpose. A .ag file is mostly LaTeX, where
     \t and \n begin ordinary commands -- \to, \times, \neg, \nabla -- so
     treating them as tab and newline would silently corrupt them. A newline is
     written by pressing return, since a string may span lines. *)
  | "\\\""            { Buffer.add_char string_buffer '"'; string_literal lexbuf }
  | "\\\\"            { Buffer.add_char string_buffer '\\'; string_literal lexbuf }
  (* A prompt is naturally several lines long, so a string may span them. The
     newline is kept, and the lexer's line count is advanced so later errors
     still report the right line. *)
  | newline           { Lexing.new_line lexbuf;
                        Buffer.add_char string_buffer '\n';
                        string_literal lexbuf }
  | eof               { error lexbuf "unterminated string literal" }
  | _ as character    { Buffer.add_char string_buffer character; string_literal lexbuf }
