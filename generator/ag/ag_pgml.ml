(* ag_pgml.ml — turn generated questions into a WeBWorK .pg document.

   The document is written in the subset of PG that this project's own parser
   accepts, so the output can be checked by reading it straight back through
   Lexer/Parser/Semantic. That rules out a whole class of mistakes locally.

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

let header contexts =
  let extra = List.concat_map extra_macros contexts |> List.sort_uniq compare in
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
let answer_of_value = function
  | Ag_engine.Num number when Ag_number.is_integer number -> Ag_number.to_string number
  | Ag_engine.Num number -> Printf.sprintf "Formula('%s')" (Ag_number.to_string number)
  | Ag_engine.Text text -> Printf.sprintf "Formula('%s')" text
  | Ag_engine.Truth truth -> if truth then "1" else "0"
  | Ag_engine.Complex (real, imaginary) ->
      Printf.sprintf "Complex(%s,%s)" (Ag_number.to_string real)
        (Ag_number.to_string imaginary)
  | Ag_engine.Formula expression ->
      Printf.sprintf "Formula('%s')" (Ag_formula.to_pg expression)
  | Ag_engine.Polynomial polynomial ->
      Printf.sprintf "Formula('%s')" (Ag_polynomial.to_pg polynomial)
  | Ag_engine.Equation _ ->
      invalid_arg
        "an Equation is not a direct answer; use equation_solution_set or equation_unique_solution"
  | Ag_engine.Matrix matrix -> Ag_matrix.to_pg matrix
  | Ag_engine.Boolean formula ->
      (* Needs `context "Boolean"` in the grammar so contextBoolean.pl grades it. *)
      Printf.sprintf "Compute(\"%s\")" (perl_string (Ag_boolean.to_pg formula))
  | Ag_engine.Set set -> Printf.sprintf "Compute(\"%s\")" (perl_string (Ag_set.to_pg set))
  | Ag_engine.Vector vector -> Ag_vector.to_compute vector
  | Ag_engine.VectorNormAnswer vector ->
      Printf.sprintf "norm(%s)" (Ag_vector.to_compute vector)
  | Ag_engine.VectorUnitAnswer vector ->
      Printf.sprintf "unit(%s)" (Ag_vector.to_compute vector)
  | Ag_engine.VectorDirectionAnswer (vector, same_direction) ->
      Printf.sprintf "%s->cmp(parallel=>1%s)" (Ag_vector.to_compute vector)
        (if same_direction then ",sameDirection=>1" else "")

let blank ?width answer =
  match width with
  | None -> Printf.sprintf "[_____]{%s}" answer
  | Some columns -> Printf.sprintf "[_____]{answer=>%s,width=>%d}" answer columns

(* The grammar's own width, when it computes one, wins over the document's. *)
let question_block ?width (question : Ag_engine.question) =
  let width = match question.Ag_engine.width with Some columns -> Some columns | None -> width in
  question.Ag_engine.pieces
  |> List.map (function
       | Ag_engine.Piece_text text -> text
       | Ag_engine.Piece_blank value -> blank ?width (answer_of_value value))
  |> String.concat ""
  |> String.trim

(* A question in a document, with the label a set gives it ("2(a).", or ""
   for none) and the heading of the part it opens, if any. *)
type item = { label : string; heading : string option; question : Ag_engine.question }

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
        | (run_context, members) :: rest when run_context = item.question.Ag_engine.context ->
            (run_context, item :: members) :: rest
        | _ -> (item.question.Ag_engine.context, [ item ]) :: runs)
      [] items
    |> List.rev_map (fun (run_context, members) -> (run_context, List.rev members))
  in
  let contexts = match runs with [] -> [ context ] | _ -> List.map fst runs in
  let block members =
    "BEGIN_PGML\n"
    ^ (members |> List.map (item_block ?width) |> String.concat "\n\n")
    ^ "\nEND_PGML\n"
  in
  header contexts
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

let of_spec ?count (spec : Ag_check.spec) =
  let count = match count with Some count -> count | None -> 6 in
  let questions = List.init count (fun _ -> Ag_engine.generate spec) in
  document ?width:spec.Ag_check.width ~context:spec.Ag_check.context questions
