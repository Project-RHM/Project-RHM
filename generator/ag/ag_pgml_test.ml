(* ag_pgml_test.ml — check generated .pg output by reading it back.

   The strongest local check available: run the emitted document through the
   project's own PG lexer, parser and semantic validator. If the existing
   front-end accepts it, the document is valid PG as this project defines PG.

   What this cannot tell us is whether a student typing 46/53 gets marked
   correct — that is WeBWorK's answer checker at runtime, and it needs a real
   WeBWorK instance. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let load label source =
  match Ag_load.parse_string ~filename:label source with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (label ^ ": " ^ Ag_load.string_of_failure error)) errors;
      exit 1

(* The PG grammar ends the document at ENDDOCUMENT(); with no room for a
   trailing newline, so the project's own reader trims first (see
   visualization.ml). Do the same here rather than dropping the newline from
   the emitted file, which every text file should end with. *)
let trim_trailing_whitespace text =
  let rec find index =
    if index < 0 then 0
    else
      match text.[index] with
      | ' ' | '\t' | '\r' | '\n' -> find (index - 1)
      | _ -> index + 1
  in
  String.sub text 0 (find (String.length text - 1))

(* Syntax only: lexer + parser, no semantic validation. Used where the point is
   whether the PG grammar can express something at all. *)
let reparse_syntax_only source =
  let lexbuf = Lexing.from_string (trim_trailing_whitespace source) in
  match Parser.main Lexer.read lexbuf with
  | _ -> Ok ()
  | exception Parser.Error ->
      let position = Lexing.lexeme_start_p lexbuf in
      Error
        (Printf.sprintf "parse error at line %d, near %S" position.Lexing.pos_lnum
           (Lexing.lexeme lexbuf))
  | exception Lexer.LexingError message -> Error ("lexing: " ^ message)
  | exception Failure message -> Error ("failure: " ^ message)

(* Round-trip: PG text -> lexer -> parser -> AST -> semantic validation. *)
let reparse source =
  let lexbuf = Lexing.from_string (trim_trailing_whitespace source) in
  match Parser.main Lexer.read lexbuf with
  | document -> (
      match Semantic.validate document with
      | () -> Ok document
      | exception Semantic.Semantic_error message -> Error ("semantic: " ^ message))
  | exception Parser.Error ->
      let position = Lexing.lexeme_start_p lexbuf in
      Error
        (Printf.sprintf "parse error at line %d, near %S" position.Lexing.pos_lnum
           (Lexing.lexeme lexbuf))
  | exception Lexer.LexingError message -> Error ("lexing: " ^ message)
  | exception Failure message -> Error ("failure: " ^ message)

(* An ASCII-rendering grammar. Everything else is identical to arithmetic.ag;
   only the strings handed to infix() differ, which is a decision the grammar
   author makes, not the engine. *)
let ascii_grammar =
  "attribute len = 2 split\n\
   attribute digit = 2 copy\n\
   synth value\n\
   synth latex\n\
   precedence 1 left + -\n\
   precedence 2 left * /\n\
   start E\n\
   E -> E + E when len > 0 weight 3 { len = -1 value = $1.value + $3.value latex = \
   infix($1, \"+\", $3) }\n\
   E -> E - E when len > 0 weight 3 { len = -1 value = $1.value - $3.value latex = \
   infix($1, \"-\", $3) }\n\
   E -> E * E when len > 0 weight 2 { len = -1 value = $1.value * $3.value latex = \
   infix($1, \"*\", $3) }\n\
   E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
   num -> integer(digit) { value = $1.value latex = str($1.value) }\n\
   prompt \"What is the value of [`{E.latex}`]?\"\n\
   answer E.value\n"

(* ------------------------------------------------------------------ *)
(* 1. An ASCII-rendered document is accepted by the existing front-end *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load "ascii.ag" ascii_grammar in
  for seed = 0 to 29 do
    Random.init seed;
    let source = Ag_pgml.of_spec ~count:4 spec in
    match reparse source with
    | Ok _ -> ()
    | Error message ->
        fail (Printf.sprintf "seed %d: the generated .pg did not read back: %s\n%s" seed
                message source)
  done

(* ------------------------------------------------------------------ *)
(* 2. The document has the structure a .pg file needs                  *)
(* ------------------------------------------------------------------ *)

let contains haystack needle =
  let haystack_length = String.length haystack and needle_length = String.length needle in
  let rec search index =
    if index + needle_length > haystack_length then false
    else if String.sub haystack index needle_length = needle then true
    else search (index + 1)
  in
  search 0

let () =
  let spec = load "ascii.ag" ascii_grammar in
  Random.init 1;
  let source = Ag_pgml.of_spec ~count:3 spec in
  List.iter
    (fun marker ->
      if not (contains source marker) then
        fail (Printf.sprintf "the document is missing %S" marker))
    [ "DOCUMENT();"; "loadMacros("; "BEGIN_PGML"; "END_PGML"; "ENDDOCUMENT();"; "[_____]{" ]

(* ------------------------------------------------------------------ *)
(* 3. A fractional answer is wrapped so PGML does not mangle it        *)
(* ------------------------------------------------------------------ *)

let () =
  let division =
    "attribute len = 1 split\n\
     attribute digit = 2 copy\n\
     synth value\n\
     synth latex\n\
     precedence 2 left /\n\
     start E\n\
     E -> E / E when len > 0 { len = -1 require $3.value != 0 value = $1.value / \
     $3.value latex = infix($1, \"/\", $3) }\n\
     E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
     num -> integer(digit) { value = $1.value latex = str($1.value) }\n\
     prompt \"What is the value of [`{E.latex}`]?\"\n\
     answer E.value\n"
  in
  let spec = load "division.ag" division in
  Random.init 3;
  let mutable_saw_fraction = ref false in
  for _ = 1 to 40 do
    let question = Ag_engine.generate spec in
    match question.Ag_engine.answer with
    | Ag_engine.Num number when not (Ag_number.is_integer number) ->
        mutable_saw_fraction := true;
        let rendered = Ag_pgml.answer_of_value question.Ag_engine.answer in
        if not (contains rendered "Formula('") then
          fail (Printf.sprintf "a fractional answer was emitted bare: %s" rendered)
    | _ -> ()
  done;
  if not !mutable_saw_fraction then fail "no fractional answer was produced to check"

(* ------------------------------------------------------------------ *)
(* 4. What the round-trip cannot cover, recorded on purpose            *)
(* ------------------------------------------------------------------ *)

(* LaTeX operators now read back: "\\div" was added to lexer.mll and both
   \\cdot and \\div were added to `term` in parser.mly, so a question rendered
   for a human (3 \\cdot 4) parses as readily as one written 3 * 4.

   A prompt in another language still does not. The PG lexer recognises the two
   fixed English openings as single tokens and rejects any byte outside ASCII;
   reading arbitrary prompt text would need a free-text lexer mode, which in
   turn needs a delimiter in the .pg output. Those cases are covered by the
   engine tests instead, where the question text is re-read by an independent
   reader.

   Each limitation below is asserted rather than hidden: if the PG front-end is
   extended so that one of them reads back, this test fails and that case should
   become a positive check. *)
let () =
  let with_prompt ~operator ~prompt =
    Printf.sprintf
      "attribute len = 1 split\n\
       attribute digit = 2 copy\n\
       synth value\n\
       synth latex\n\
       precedence 2 left *\n\
       start E\n\
       E -> E * E when len > 0 { len = -1 value = $1.value * $3.value latex = infix($1, \
       \"%s\", $3) }\n\
       E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
       num -> integer(digit) { value = $1.value latex = str($1.value) }\n\
       prompt \"%s\"\n\
       answer E.value\n"
      operator prompt
  in
  let known_limitations =
    [
      ("a non-English prompt", with_prompt ~operator:"*" ~prompt:"\194\191Cual es el valor de [`{E.latex}`]?");
    ]
  in
  (* LaTeX rendering, now a positive check *)
  (let spec =
     load "latex.ag"
       (with_prompt ~operator:"\\cdot" ~prompt:"What is the value of [`{E.latex}`]?")
   in
   for seed = 0 to 19 do
     Random.init seed;
     let document = Ag_pgml.of_spec ~count:3 spec in
     if not (contains document "\\cdot") then
       fail "the LaTeX grammar did not render \\cdot";
     match reparse document with
     | Ok _ -> ()
     | Error message ->
         fail (Printf.sprintf "seed %d: a LaTeX-rendered document did not read back: %s"
                 seed message)
   done);
  List.iter
    (fun (label, source) ->
      let spec = load "limitation.ag" source in
      Random.init 11;
      let document = Ag_pgml.of_spec ~count:2 spec in
      match reparse document with
      | Error _ -> ()
      | Ok _ ->
          fail
            (Printf.sprintf
               "%s now reads back through the PG parser — turn this into a positive check"
               label))
    known_limitations

(* ------------------------------------------------------------------ *)
(* 5. Negative literals are now expressible in the PG grammar          *)
(* ------------------------------------------------------------------ *)

(* parser.mly's `factor` had no unary minus, so Formula('-5') could not be
   parsed at all — a gap the existing generator hits too, since its shipped .pg
   files contain Formula('-12') and Formula('-25.7638888889'), neither of which
   read back. Two productions were added to `factor`, mirroring how `value`
   already handled a negative literal.

   This is checked at the parser, because that is where the fix is. *)
let () =
  let with_answer answer =
    Printf.sprintf
      "DOCUMENT();\n\
       loadMacros(\"PGstandard.pl\", \"MathObjects.pl\", \"PGML.pl\");\n\
       Context(\"Numeric\");\n\
       \n\
       BEGIN_PGML\n\
       What is the value of [`1+2`]? [_____]{%s}\n\
       END_PGML\n\
       ENDDOCUMENT();"
      answer
  in
  List.iter
    (fun answer ->
      match reparse_syntax_only (with_answer answer) with
      | Ok () -> ()
      | Error message -> fail (Printf.sprintf "%s did not parse: %s" answer message))
    [ "Formula(\'-5\')"; "Formula(\'-246/55\')"; "Formula(\'-25.7638888889\')";
      (* regressions: these parsed before and must still parse *)
      "Formula(\'3/4\')"; "Formula(\'575\')"; "-25"; "Real(-1.5)" ]

(* ------------------------------------------------------------------ *)
(* 6. Exact fractions do not survive Semantic.validate                 *)
(* ------------------------------------------------------------------ *)

(* Semantic.validate compares the question text and the answer with float
   equality (`if f1 = f2` in semantic.ml). Recomputing 77/25/92 left to right
   and 77/2300 directly differ in the last bit, so an exact fractional answer
   is reported as a mismatch even though it is arithmetically correct.

   Exact fractions are kept: they are right, and WeBWorK accepts them. The
   fragility is in that float comparison. If it is ever changed to compare with
   a tolerance, this test fails and should become a positive check. *)
let fractional_grammar =
  "attribute len = 2 split\n\
   attribute digit = 2 copy\n\
   synth value\n\
   synth latex\n\
   precedence 2 left /\n\
   start E\n\
   E -> E / E when len > 0 { len = -1 require $3.value != 0 value = $1.value / \
   $3.value latex = infix($1, \"/\", $3) }\n\
   E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
   num -> integer(digit) { value = $1.value latex = str($1.value) }\n\
   prompt \"What is the value of [`{E.latex}`]?\"\n\
   answer E.value\n"

let () =
  let spec = load "fractional.ag" fractional_grammar in
  Random.init 0;
  let document = Ag_pgml.of_spec ~count:4 spec in
  (* the parser itself is fine with it *)
  (match reparse_syntax_only document with
  | Ok () -> ()
  | Error message -> fail ("a fractional document did not parse: " ^ message));
  (* only the float comparison in the validator objects *)
  match reparse document with
  | Error _ -> ()
  | Ok _ ->
      fail
        "Semantic.validate now accepts exact fractions — turn this into a positive check"

let () =
  if !failures = 0 then print_endline "Ag PGML tests passed."
  else (
    prerr_endline (Printf.sprintf "%d check(s) failed." !failures);
    exit 1)
