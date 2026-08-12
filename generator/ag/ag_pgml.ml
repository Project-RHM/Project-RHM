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

let header =
  "DOCUMENT();\n\
   loadMacros(\"PGstandard.pl\", \"MathObjects.pl\", \"PGML.pl\");\n\
   Context(\"Numeric\");\n\
   \n"

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

let blank ?width answer =
  match width with
  | None -> Printf.sprintf "[_____]{%s}" answer
  | Some columns -> Printf.sprintf "[_____]{answer=>%s,width=>%d}" answer columns

let question_block ?width (question : Ag_engine.question) =
  Printf.sprintf "%s %s" question.Ag_engine.prompt
    (blank ?width (answer_of_value question.Ag_engine.answer))

let document ?width questions =
  header ^ "BEGIN_PGML\n"
  ^ (questions |> List.map (question_block ?width) |> String.concat "\n\n")
  ^ "\n" ^ footer

let of_spec ?count (spec : Ag_check.spec) =
  let count = match count with Some count -> count | None -> 6 in
  let questions = List.init count (fun _ -> Ag_engine.generate spec) in
  document ?width:spec.Ag_check.width questions
