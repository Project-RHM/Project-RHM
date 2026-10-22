(* ag_test.ml — front-end tests for the .ag question-grammar language.

   Two things are checked:
     1. the shipped arithmetic.ag parses into the specification we expect;
     2. a broken grammar produces a message that names the actual mistake and
        points at a line. "syntax error" with no position is a test failure. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let check_int label expected actual =
  if expected <> actual then
    fail (Printf.sprintf "%s: expected %d, received %d" label expected actual)

let check_string label expected actual =
  if expected <> actual then
    fail (Printf.sprintf "%s: expected %S, received %S" label expected actual)

let contains haystack needle =
  let haystack_length = String.length haystack in
  let needle_length = String.length needle in
  let rec search index =
    if index + needle_length > haystack_length then false
    else if String.sub haystack index needle_length = needle then true
    else search (index + 1)
  in
  search 0

(* ------------------------------------------------------------------ *)
(* 1. The shipped grammar                                              *)
(* ------------------------------------------------------------------ *)

let () =
  match Ag_load.parse_file "arithmetic.ag" with
  | Error errors ->
      List.iter
        (fun error -> fail ("arithmetic.ag: " ^ Ag_load.string_of_failure error))
        errors
  | Ok spec ->
      check_string "start symbol" "E" spec.Ag_check.start;
      check_int "rule count" 9 (List.length spec.Ag_check.rules);
      check_int "inherited attributes" 2
        (List.length spec.Ag_check.inherited);
      check_int "synthesized attributes" 4
        (List.length spec.Ag_check.synthesized);
      check_string "default context" "Numeric" spec.Ag_check.context;
      check_int "precedence entries" 4 (List.length spec.Ag_check.precedences);
      (match spec.Ag_check.inherited with
      | [ cost; digit ] ->
          check_string "first attribute" "cost" cost.Ag_check.attribute_name;
          check_int "cost initial" 12 cost.Ag_check.initial;
          if cost.Ag_check.distribution <> Ag_ast.Split then
            fail "cost should be a split attribute";
          check_string "second attribute" "digit"
            digit.Ag_check.attribute_name;
          if digit.Ag_check.distribution <> Ag_ast.Copy then
            fail "digit should be a copy attribute"
      | _ -> fail "expected exactly the attributes cost and digit");
      (* the prompt must survive as text plus one {E.latex} hole *)
      let holes =
        List.filter
          (function Ag_check.Hole _ -> true | _ -> false)
          spec.Ag_check.prompt
      in
      check_int "prompt holes" 1 (List.length holes);
      (match holes with
      | [ Ag_check.Hole (owner, attribute) ] ->
          check_string "prompt hole symbol" "E" owner;
          check_string "prompt hole attribute" "latex" attribute
      | _ -> fail "expected a single {E.latex} placeholder");
      (* "\cdot" in the file must arrive as exactly one backslash, not two *)
      let literals = ref [] in
      let rec collect = function
        | Ag_ast.Str text -> literals := text :: !literals
        | Ag_ast.Binary (_, left, right) ->
            collect left;
            collect right
        | Ag_ast.Unary (_, body) -> collect body
        | Ag_ast.Call (_, arguments) -> List.iter collect arguments
        | _ -> ()
      in
      List.iter
        (fun (rule : Ag_ast.rule) ->
          List.iter
            (function Ag_ast.Assign (_, body, _) -> collect body | Ag_ast.Require (body, _) -> collect body)
            rule.Ag_ast.equations)
        spec.Ag_check.rules;
      if not (List.mem "\\cdot" !literals) then
        fail
          (Printf.sprintf "expected the literal \\cdot exactly, found: %s"
             (String.concat " " (List.map (Printf.sprintf "%S") !literals)))

(* ------------------------------------------------------------------ *)
(* 2. Broken grammars                                                  *)
(* ------------------------------------------------------------------ *)

let preamble =
  "attribute len = 3 split\n\
   attribute digit = 2 copy\n\
   synth value\n\
   synth latex\n\
   start E\n"

(* The rules that let a derivation stop, without the prompt/answer pair. *)
let terminating_rules =
  "E -> num when len = 0 { value = $1.value latex = $1.latex }\n\
   num -> integer(digit) { value = $1.value latex = str($1.value) }\n"

let question = "prompt \"Value of [`{E.latex}`]?\"\nanswer E.value\n"

let terminator = terminating_rules ^ question

(* Each case: a label, the source, the text the message must mention, and
   whether the report has to carry a line number. *)
let broken_cases =
  [
    ( "missing closing brace",
      preamble
      ^ "E -> E + E when len > 0 { len = -1 value = $1.value + $3.value latex \
         = infix($1, \"+\", $3)\n"
      ^ terminator,
      "unexpected",
      true );
    ( "attribute typo in a guard",
      preamble
      ^ "E -> E + E when lenn > 0 { len = -1 value = $1.value + $3.value latex \
         = infix($1, \"+\", $3) }\n"
      ^ terminator,
      "unknown name 'lenn'",
      true );
    ( "synthesized attribute used in a guard",
      preamble
      ^ "E -> E + E when value > 0 { len = -1 value = $1.value + $3.value \
         latex = infix($1, \"+\", $3) }\n"
      ^ terminator,
      "synthesized attribute",
      true );
    ( "budget equation reads a child",
      preamble
      ^ "E -> E + E when len > 0 { len = $1.value value = $1.value + $3.value \
         latex = infix($1, \"+\", $3) }\n"
      ^ terminator,
      "does not exist yet",
      true );
    ( "budget equation grows the budget",
      preamble
      ^ "E -> E + E when len > 0 { len = 1 value = $1.value + $3.value latex = \
         infix($1, \"+\", $3) }\n"
      ^ terminator,
      "would grow the budget",
      true );
    ( "a rule forgets a synthesized attribute",
      preamble
      ^ "E -> E + E when len > 0 { len = -1 value = $1.value + $3.value }\n"
      ^ terminator,
      "does not say how to compute 'latex'",
      true );
    ( "child index out of range",
      preamble
      ^ "E -> E + E when len > 0 { len = -1 value = $1.value + $5.value latex \
         = infix($1, \"+\", $3) }\n"
      ^ terminator,
      "$5 is out of range",
      true );
    ( "misspelled builtin",
      preamble
      ^ "E -> E + E when len > 0 { len = -1 value = $1.value + $3.value latex \
         = strr($1.value) }\n"
      ^ terminator,
      "unknown function 'strr'",
      true );
    ( "wrong builtin arity",
      preamble
      ^ "E -> E + E when len > 0 { len = -1 value = $1.value + $3.value latex \
         = infix($1, \"+\") }\n"
      ^ terminator,
      "takes 3 argument(s)",
      true );
    ( "weight is not positive",
      preamble
      ^ "E -> E + E when len > 0 weight 0 { len = -1 value = $1.value + \
         $3.value latex = infix($1, \"+\", $3) }\n"
      ^ terminator,
      "weight must be positive",
      true );
    ( "invalid PGML context name",
      "context \"../Complex\"\n" ^ preamble ^ terminator,
      "context must be a non-empty WeBWorK context name",
      true );
    ( "duplicate PGML context",
      "context \"Complex\"\ncontext \"Numeric\"\n" ^ preamble ^ terminator,
      "duplicate 'context' declaration",
      true );
    ( "prompt uses a symbol other than the start symbol",
      preamble ^ terminating_rules
      ^ "prompt \"Value of [`{num.latex}`]?\"\nanswer E.value\n",
      "only use the start symbol",
      false );
    ( "prompt placeholder is malformed",
      preamble ^ terminating_rules
      ^ "prompt \"Value of [`{latex}`]?\"\nanswer E.value\n",
      "is not a random or a let",
      false );
    ( "missing start declaration",
      "attribute len = 3 split\n\
       synth value\n\
       synth latex\n"
      ^ terminator,
      "'start SYMBOL' declaration is required",
      false );
    ( "undeclared attribute assigned in a rule",
      preamble
      ^ "E -> E + E when len > 0 { len = -1 depth = -1 value = $1.value + \
         $3.value latex = infix($1, \"+\", $3) }\n"
      ^ terminator,
      "is not declared",
      true );
    ( "string literal runs to end of file",
      preamble ^ terminator ^ "prompt \"oops",
      "unterminated string literal",
      true );
    ( "no rule lets the derivation finish",
      preamble
      ^ "E -> E + E when len > 0 { len = -1 value = $1.value + $3.value latex \
         = infix($1, \"+\", $3) }\n"
      ^ "num -> integer(digit) { value = $1.value latex = str($1.value) }\n"
      ^ question,
      "keeps the derivation going",
      true );
    ( "recursion never spends a budget",
      preamble
      ^ "E -> E + E when len > 0 { len = 0 value = $1.value + $3.value latex \
         = infix($1, \"+\", $3) }\n"
      ^ terminator,
      "without spending any inherited attribute",
      true );
  ]

let () =
  List.iter
    (fun (label, source, expected, needs_position) ->
      match Ag_load.parse_string ~filename:"case.ag" source with
      | Ok _ -> fail (label ^ ": expected an error, but the grammar was accepted")
      | Error errors ->
          let reports = List.map Ag_load.string_of_failure errors in
          let joined = String.concat " | " reports in
          if not (List.exists (fun report -> contains report expected) reports)
          then
            fail
              (Printf.sprintf "%s: no message mentioned %S. Got: %s" label
                 expected joined);
          if needs_position then
            let has_line =
              List.exists
                (fun (error : Ag_load.failure) ->
                  contains error.Ag_load.where "case.ag:"
                  && String.length error.Ag_load.where > String.length "case.ag:")
                errors
            in
            if not has_line then
              fail
                (Printf.sprintf "%s: no message carried a line number. Got: %s"
                   label joined))
    broken_cases

let () =
  if !failures = 0 then print_endline "Ag front-end tests passed."
  else (
    prerr_endline (Printf.sprintf "%d check(s) failed." !failures);
    exit 1)
