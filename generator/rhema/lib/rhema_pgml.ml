(* rhema_pgml.ml — turn generated questions into a WeBWorK .pg document.

   The document is written in the subset of PG that this project's own parser
   accepts, so the output can be checked by reading it straight back through
   Lexer/Parser/Semantic. That rules out a whole class of mistakes locally.
   Answers that carry more than a value are outside that subset: a point, a
   proposition or a formula with a context of its own, and a whole number
   with its own tolerance (exact_whole below). The read-back test puts the last of these
   back to the bare number before it reads the document.

   Three habits of the existing printer are deliberately not copied, because
   the project's parser rejects all three (its own generated files do not read
   back either):

     - loadMacros spread over several lines
     - a "# Questions:" preamble inside BEGIN_PGML
     - "---" rules between questions

   Questions are separated by a blank line instead, which the grammar does
   accept. *)

let perl_string text =
  let buffer = Buffer.create (String.length text) in
  String.iter
    (function
      | ('\\' | '"' | '$' | '@') as character ->
          Buffer.add_char buffer '\\';
          Buffer.add_char buffer character
      | character -> Buffer.add_char buffer character)
    text;
  Buffer.contents buffer

(* A context that lives in its own macro file needs that file loaded before
   Context() can select it. *)
let extra_macros = function
  | "PolynomialFactors" | "PolynomialFactors-Strict" -> [ "contextPolynomialFactors.pl" ]
  | "Boolean" -> [ "contextBoolean.pl" ]
  | _ -> []

let header ?(propositions = false) contexts =
  let contexts_loaded = if propositions then "Boolean" :: contexts else contexts in
  let extra = List.concat_map extra_macros contexts_loaded |> List.sort_uniq compare in
  let macros =
    [ "PGstandard.pl"; "MathObjects.pl"; "PGML.pl" ] @ extra
    |> List.map (Printf.sprintf "\"%s\"")
    |> String.concat ", "
  in
  Printf.sprintf "DOCUMENT();\nloadMacros(%s);\nContext(\"%s\");\n\n" macros
    (perl_string (List.hd contexts))

let footer = "END_PGML\nENDDOCUMENT();\n"

(* A fraction is emitted as Formula('46/53') rather than a decimal. The exact
   value is what the question actually asks for, and it avoids the existing
   generator's habit of printing Formula('4.87708333333') under a rubric that
   asks for three significant digits. *)
(* The variables of a formula answer; x alone is what the Numeric context
   already knows. *)
let rec variables_of_value = function
  | Rhema_engine.Formula expression -> Rhema_formula.variables expression
  | Rhema_engine.Polynomial polynomial ->
      Rhema_formula.variables (Rhema_polynomial.to_formula polynomial)
  | Rhema_engine.Plain value -> variables_of_value value
  | _ -> []

let beyond_x variables = List.exists (fun name -> name <> "x") variables

(* A formula written with a context of its own: a copy of Numeric that
   declares the formula's variables, and for an answer that must be worked
   out has the functions switched off (sqrt and abs stay). The answer
   carries this context, so the question may be in any context. *)
let own_context ?(plain = false) variables text =
  Printf.sprintf "do { my $c = Parser::Context->getCopy(\"Numeric\"); %s%sFormula($c,\"%s\") }"
    (if variables = [] then ""
     else
       Printf.sprintf "$c->variables->are(%s); "
         (String.concat "," (List.map (fun name -> name ^ "=>\"Real\"") variables)))
    (if plain then
       "$c->functions->disable(\"Trig\",\"Hyperbolic\",\"Numeric\"); \
        $c->functions->enable(\"sqrt\",\"abs\"); "
     else "")
    (perl_string text)

let is_proposition = function Rhema_engine.Boolean _ -> true | _ -> false

(* The variables of a proposition answer. *)
let proposition_variables = function
  | Rhema_engine.Boolean formula -> Rhema_boolean.variable_set formula
  | _ -> []

(* A proposition written with a context of its own: a copy of Boolean that
   declares its variables. The Boolean context of contextBoolean.pl knows p
   and q alone, so an answer in r could not be read in it; and an answer
   that carries its context is read as a proposition whatever context the
   question is in. The document loads contextBoolean.pl for it (header). *)
let own_boolean_context variables text =
  Printf.sprintf "do { my $c = Parser::Context->getCopy(\"Boolean\"); $c->variables->are(%s); Formula($c,\"%s\") }"
    (String.concat "," (List.map (fun name -> name ^ "=>\"Boolean\"") variables))
    (perl_string text)

(* A whole number graded with half a unit of absolute tolerance, so that no
   other whole number is accepted. *)
let exact_whole number =
  Printf.sprintf "Real(%s)->cmp(tolType=>\"absolute\",tolerance=>0.5)" (Rhema_number.to_string number)

(* WeBWorK compares numbers with a relative tolerance of one part in a
   thousand. Up to 1000 that still tells a whole number from its neighbours;
   from 1001 on it does not: 5041 is accepted for 5040. Measured on the
   renderer: n + 1 and n - 1 pass for every |n| > 1000 and for none below. *)
let tolerance_reaches_neighbours number = abs number.Rhema_number.numerator >= 1000

(* [variables] are those of every formula answer of the question, so that
   its blanks all accept the same names; [propositional] are those of its
   proposition answers, for the same reason. *)
let answer_of_value ?(variables = []) ?(propositional = []) = function
  | Rhema_engine.Num number when Rhema_number.is_integer number ->
      if tolerance_reaches_neighbours number then exact_whole number else Rhema_number.to_string number
  | Rhema_engine.Num number -> Printf.sprintf "Formula('%s')" (Rhema_number.to_string number)
  | Rhema_engine.Text text -> Printf.sprintf "Formula('%s')" text
  | Rhema_engine.Truth truth -> if truth then "1" else "0"
  | Rhema_engine.Complex (real, imaginary) ->
      Printf.sprintf "Complex(%s,%s)" (Rhema_number.to_string real)
        (Rhema_number.to_string imaginary)
  | (Rhema_engine.Formula _ | Rhema_engine.Polynomial _) as value ->
      let text =
        match value with
        | Rhema_engine.Formula expression -> Rhema_formula.to_pg expression
        | Rhema_engine.Polynomial polynomial -> Rhema_polynomial.to_pg polynomial
        | _ -> assert false
      in
      let variables = List.sort_uniq String.compare (variables @ variables_of_value value) in
      if beyond_x variables then own_context variables text else Printf.sprintf "Formula('%s')" text
  | Rhema_engine.Exactly number -> exact_whole number
  | Rhema_engine.Plain value ->
      let text =
        match value with
        | Rhema_engine.Num number -> Rhema_number.to_string number
        | Rhema_engine.Formula expression -> Rhema_formula.to_pg expression
        | Rhema_engine.Polynomial polynomial -> Rhema_polynomial.to_pg polynomial
        | _ -> invalid_arg "plain() holds a number or a formula"
      in
      let variables = List.sort_uniq String.compare (variables @ variables_of_value value) in
      own_context ~plain:true (if beyond_x variables then variables else []) text
  | Rhema_engine.Equation _ ->
      invalid_arg
        "an Equation is not a direct answer; use equation_solution_set or equation_unique_solution"
  | Rhema_engine.Rich _ ->
      invalid_arg "text that holds an answer blank is not itself an answer"
  | Rhema_engine.Matrix matrix -> Rhema_matrix.to_pg matrix
  | Rhema_engine.Boolean formula as value ->
      (* contextBoolean.pl grades it: any equivalent proposition is right. A
         proposition without variables still needs one to make a context. *)
      let names = List.sort_uniq String.compare (propositional @ proposition_variables value) in
      own_boolean_context (if names = [] then [ "p" ] else names) (Rhema_boolean.to_pg formula)
  | Rhema_engine.Set set -> Printf.sprintf "Compute(\"%s\")" (perl_string (Rhema_set.to_pg set))
  | Rhema_engine.Vector vector -> Rhema_vector.to_compute vector
  | Rhema_engine.Point coordinates ->
      (* A Point object made in a copy of the Point context carries that
         context with it, so the answer is read as a point whatever context
         the question is in; the grammar does not have to set one. *)
      Printf.sprintf "Point(Parser::Context->getCopy(\"Point\"),%s)"
        (String.concat "," (List.map Rhema_number.to_string coordinates))
  | Rhema_engine.VectorNormAnswer vector ->
      Printf.sprintf "norm(%s)" (Rhema_vector.to_compute vector)
  | Rhema_engine.VectorUnitAnswer vector ->
      Printf.sprintf "unit(%s)" (Rhema_vector.to_compute vector)
  | Rhema_engine.VectorDirectionAnswer (vector, same_direction) ->
      Printf.sprintf "%s->cmp(parallel=>1%s)" (Rhema_vector.to_compute vector)
        (if same_direction then ",sameDirection=>1" else "")

let blank ?width answer =
  match width with
  | None -> Printf.sprintf "[_____]{%s}" answer
  | Some columns -> Printf.sprintf "[_____]{answer=>%s,width=>%d}" answer columns

(* The grammar's own width, when it computes one, wins over the document's. *)
let question_block ?width (question : Rhema_engine.question) =
  let width = match question.Rhema_engine.width with Some columns -> Some columns | None -> width in
  let named of_value =
    question.Rhema_engine.variables @ List.concat_map of_value question.Rhema_engine.answers
    |> List.sort_uniq String.compare
  in
  let variables = named variables_of_value in
  (* the names a grammar declares with pg_variables are propositional
     variables to a proposition answer *)
  let propositional = named proposition_variables in
  question.Rhema_engine.pieces
  |> List.map (function
       | Rhema_engine.Piece_text text -> text
       | Rhema_engine.Piece_blank value -> blank ?width (answer_of_value ~variables ~propositional value)
       | Rhema_engine.Piece_wide_blank (value, columns) ->
           blank ~width:columns (answer_of_value ~variables ~propositional value))
  |> String.concat ""
  |> String.trim

(* A question in a document, with the label a set gives it ("2(a).", or ""
   for none) and the heading of the part it opens, if any. *)
type item = { label : string; heading : string option; question : Rhema_engine.question }

let item_block ?width item =
  let body = question_block ?width item.question in
  let labelled = if item.label = "" then body else item.label ^ " " ^ body in
  match item.heading with
  | Some heading -> heading ^ "\n\n" ^ labelled
  | None -> labelled

(* Questions that need different WeBWorK contexts are written in separate
   PGML blocks, with Context() switched between them. Questions in the same
   context stay in one block, so a document in a single context reads as it
   always did. *)
let document_items ?width ?(context = "Numeric") items =
  let runs =
    List.fold_left
      (fun runs item ->
        match runs with
        | (run_context, members) :: rest when run_context = item.question.Rhema_engine.context ->
            (run_context, item :: members) :: rest
        | _ -> (item.question.Rhema_engine.context, [ item ]) :: runs)
      [] items
    |> List.rev_map (fun (run_context, members) -> (run_context, List.rev members))
  in
  let contexts = match runs with [] -> [ context ] | _ -> List.map fst runs in
  let propositions =
    List.exists (fun item -> List.exists is_proposition item.question.Rhema_engine.answers) items
  in
  let block members =
    "BEGIN_PGML\n"
    ^ (members |> List.map (item_block ?width) |> String.concat "\n\n")
    ^ "\nEND_PGML\n"
  in
  header ~propositions contexts
  ^ (match runs with
    | [] -> "BEGIN_PGML\n\nEND_PGML\n"
    | (_, first) :: rest ->
        block first
        ^ String.concat ""
            (List.map
               (fun (run_context, members) ->
                 Printf.sprintf "Context(\"%s\");\n" (perl_string run_context) ^ block members)
               rest))
  ^ "ENDDOCUMENT();\n"

let document ?width ?context questions =
  document_items ?width ?context
    (List.map (fun question -> { label = ""; heading = None; question }) questions)

let of_spec ?count (spec : Rhema_check.spec) =
  let count = match count with Some count -> count | None -> 6 in
  let questions = List.init count (fun _ -> Rhema_engine.generate spec) in
  document ?width:spec.Rhema_check.width ~context:spec.Rhema_check.context questions
