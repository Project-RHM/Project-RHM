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

let base_macros = [ "PGstandard.pl"; "MathObjects.pl"; "PGML.pl" ]

(* With no extra macros this is byte for byte the header the project's own
   PG front-end reads back. *)
let header ?(macros = []) context =
  Printf.sprintf
    "DOCUMENT();\n\
     loadMacros(%s);\n\
     Context(\"%s\");\n\
     \n"
    (base_macros @ macros |> List.map (fun name -> "\"" ^ name ^ "\"") |> String.concat ", ")
    (perl_string context)

let footer = "END_PGML\nENDDOCUMENT();\n"

(* A fraction is emitted as Formula('46/53') rather than a decimal. The exact
   value is what the question actually asks for, and it avoids the existing
   generator's habit of printing Formula('4.87708333333') under a rubric that
   asks for three significant digits. *)
(* The three kinds that cannot be written inline -- a propositional formula,
   a drop-down, a truth table -- are built before BEGIN_PGML as named objects;
   see [document]. Every other kind is written inline, as before. *)
let answer_of_value = function
  | Ag_engine.Boolean _ | Ag_engine.Choice _ | Ag_engine.TruthTable _ | Ag_engine.Parts _
  | Ag_engine.Labelled _ | Ag_engine.Weighted _ ->
      invalid_arg "answer_of_value: this answer is built as a named object"
  | Ag_engine.Num number when Ag_number.is_integer number -> Ag_number.to_string number
  | Ag_engine.Num number -> Printf.sprintf "Formula('%s')" (Ag_number.to_string number)
  | Ag_engine.Text text -> Printf.sprintf "Formula('%s')" text
  | Ag_engine.Truth truth -> if truth then "1" else "0"
  | Ag_engine.Complex (real, imaginary) ->
      Printf.sprintf "Complex(%s,%s)" (Ag_number.to_string real)
        (Ag_number.to_string imaginary)
  | Ag_engine.Formula expression ->
      Printf.sprintf "Formula('%s')" (Ag_formula.to_pg expression)
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

(* ------------------------------------------------------------------ *)
(* Answers built before BEGIN_PGML                                     *)
(* ------------------------------------------------------------------ *)

(* What the document needs besides its questions: extra macros, the
   variables of the Boolean context, and the lines that build the named
   answer objects. Boolean objects are built inside Context("Boolean") and
   keep that context when the document switches back, so one document can
   mix them with numeric answers. *)
(* An answer blank is written as a placeholder first and finished once its
   whole question is known, because its weight depends on the question's
   other blanks. *)
type pending = {
  underscores : string;
  answer : string;
  columns : int option;  (* the old width option of inline answers *)
  group : int option;  (* the weighted answer this blank belongs to *)
}

type setup = {
  mutable macros : string list;
  mutable boolean_variables : string list;
  mutable boolean_lines : string list;
  mutable other_lines : string list;
  mutable next : int;
  mutable blanks : (int * pending) list;
  mutable groups : (int * float) list;  (* group -> percentage of its question *)
  mutable current_group : int option;
}

let new_setup () =
  {
    macros = [];
    boolean_variables = [];
    boolean_lines = [];
    other_lines = [];
    next = 1;
    blanks = [];
    groups = [];
    current_group = None;
  }

let placeholder id = Printf.sprintf "\001%d\002" id

let place setup ?columns ~underscores answer =
  let id = List.length setup.blanks in
  setup.blanks <- setup.blanks @ [ (id, { underscores; answer; columns; group = setup.current_group }) ];
  placeholder id

let need setup macro = if not (List.mem macro setup.macros) then setup.macros <- setup.macros @ [ macro ]

let fresh setup =
  let name = Printf.sprintf "$ans%d" setup.next in
  setup.next <- setup.next + 1;
  name

let use_boolean setup formulas =
  need setup "contextBoolean.pl";
  setup.boolean_variables <-
    List.sort_uniq compare (setup.boolean_variables @ Ag_boolean.table_variables formulas)

(* One truth table: the variables' columns are given, every other cell is a
   blank that takes T or F. *)
let truth_table_block setup formulas =
  use_boolean setup formulas;
  let columns = Ag_boolean.table_columns formulas in
  let variables = Ag_boolean.table_variables formulas in
  let computed = List.filter (fun c -> match c with Ag_boolean.Var _ -> false | _ -> true) columns in
  let heading =
    List.map (fun name -> Printf.sprintf "[. [`%s`] .]" name) variables
    @ List.map (fun c -> Printf.sprintf "[. [`%s`] .]" (Ag_boolean.to_latex c)) computed
  in
  let letter truth = if truth then "T" else "F" in
  let row assignment =
    List.map (fun name -> Printf.sprintf "[. %s .]" (letter (List.assoc name assignment))) variables
    @ List.map
        (fun c ->
          Printf.sprintf "[. %s .]"
            (place setup ~underscores:"___" (if Ag_boolean.evaluate assignment c then "$T" else "$F")))
        computed
  in
  let line cells = "  " ^ String.concat " " cells ^ "*" in
  let align = "|" ^ String.concat "|" (List.init (List.length heading) (fun _ -> "c")) ^ "|" in
  String.concat "\n"
    ([ "[#"; line heading ]
    @ List.map (fun assignment -> line (row assignment)) (Ag_boolean.table_rows formulas)
    @ [ Printf.sprintf "#]{align => '%s', horizontalrules => 1}" align ])

let rec answer_block setup ?width value =
  match value with
  | Ag_engine.Boolean formula ->
      use_boolean setup [ formula ];
      let name = fresh setup in
      setup.boolean_lines <-
        setup.boolean_lines
        @ [ Printf.sprintf "%s = Compute(\"%s\");" name (perl_string (Ag_boolean.to_pg formula)) ];
      " " ^ place setup ~underscores:"______________________________" name
  | Ag_engine.Choice (options, correct) ->
      need setup "parserPopUp.pl";
      let name = fresh setup in
      let quoted text = "\"" ^ perl_string text ^ "\"" in
      setup.other_lines <-
        setup.other_lines
        @ [
            Printf.sprintf "%s = PopUp([%s], %s);" name
              (String.concat ", " (List.map quoted ("?" :: options)))
              (quoted correct);
          ];
      " " ^ place setup ~underscores:"_" name
  | Ag_engine.TruthTable formulas -> "\n\n" ^ truth_table_block setup formulas
  | Ag_engine.Parts values ->
      (* Each part on its own paragraph after the first. *)
      String.concat "" (List.map (answer_block setup ?width) values)
  | Ag_engine.Labelled (words, inner) ->
      (* The blank follows the words after one space, however they end. *)
      let words =
        let rec trim_right text =
          if text <> "" && text.[String.length text - 1] = ' ' then
            trim_right (String.sub text 0 (String.length text - 1))
          else text
        in
        trim_right words
      in
      "\n\n" ^ words ^ answer_block setup ?width inner
  | Ag_engine.Weighted (percent, inner) ->
      let group = List.length setup.groups in
      setup.groups <- setup.groups @ [ (group, percent) ];
      let outer = setup.current_group in
      setup.current_group <- Some group;
      let text = answer_block setup ?width inner in
      setup.current_group <- outer;
      text
  | other -> " " ^ place setup ?columns:width ~underscores:"_____" (answer_of_value other)

let setup_text context setup =
  let boolean =
    if setup.boolean_lines = [] && not (List.mem "contextBoolean.pl" setup.macros) then []
    else
      [
        "Context(\"Boolean\");";
        Printf.sprintf "Context()->variables->are(%s);"
          (setup.boolean_variables
          |> List.map (fun name -> Printf.sprintf "%s => 'Boolean'" name)
          |> String.concat ", ");
        "$T = Compute(\"T\");";
        "$F = Compute(\"F\");";
      ]
      @ setup.boolean_lines
      @ [ Printf.sprintf "Context(\"%s\");" (perl_string context) ]
  in
  match boolean @ setup.other_lines with
  | [] -> ""
  | lines -> String.concat "\n" lines ^ "\n\n"

(* ------------------------------------------------------------------ *)
(* Documents                                                           *)
(* ------------------------------------------------------------------ *)

let question_block ?width (question : Ag_engine.question) =
  Printf.sprintf "%s %s" question.Ag_engine.prompt
    (blank ?width (answer_of_value question.Ag_engine.answer))

let letters = "abcdefghijklmnopqrstuvwxyz"

let replace_all ~pattern ~by text =
  let plen = String.length pattern in
  let buffer = Buffer.create (String.length text) in
  let rec go i =
    if i > String.length text - plen then Buffer.add_string buffer (String.sub text i (String.length text - i))
    else if String.sub text i plen = pattern then (
      Buffer.add_string buffer by;
      go (i + plen))
    else (
      Buffer.add_char buffer text.[i];
      go (i + 1))
  in
  go 0;
  Buffer.contents buffer

(* A blank as PGML writes it. Without a weight it is exactly what this
   module has always written; with one, the width and the grader's weight
   follow the answer: [_]{$ans}{5}{ cmp_options => { weight => 30 } }. *)
let blank_markup pending weight =
  match weight with
  | None -> (
      match pending.columns with
      | None -> Printf.sprintf "[%s]{%s}" pending.underscores pending.answer
      | Some columns -> Printf.sprintf "[%s]{answer=>%s,width=>%d}" pending.underscores pending.answer columns)
  | Some weight ->
      let columns = match pending.columns with Some c -> c | None -> String.length pending.underscores in
      let text = Printf.sprintf "%.4f" weight in
      let rec trim text =
        let last = text.[String.length text - 1] in
        if last = '0' then trim (String.sub text 0 (String.length text - 1))
        else if last = '.' then String.sub text 0 (String.length text - 1)
        else text
      in
      Printf.sprintf "[%s]{%s}{%d}{ cmp_options => { weight => %s } }" pending.underscores pending.answer columns
        (trim text)

(* Weights, when any answer in the document asks for one: every question
   is worth the same, 100 / n; a weighted answer takes its percentage of
   its question, split over its blanks; the question's other blanks share
   what is left equally. WeBWorK's average grader reads the weights as
   relative, so they need not be whole numbers. *)
let finish setup ~weighted ~share ids text =
  let entries = List.filter (fun (id, _) -> List.mem id ids) setup.blanks in
  let in_group group = List.filter (fun (_, pending) -> pending.group = Some group) entries in
  let groups_here =
    List.sort_uniq compare (List.filter_map (fun (_, pending) -> pending.group) entries)
  in
  let taken =
    List.fold_left (fun sum group -> sum +. List.assoc group setup.groups) 0. groups_here
  in
  let ungrouped = List.filter (fun (_, pending) -> pending.group = None) entries in
  let weight_of pending =
    if not weighted then None
    else
      match pending.group with
      | Some group ->
          Some (share *. List.assoc group setup.groups /. 100. /. float_of_int (List.length (in_group group)))
      | None -> Some (share *. (1. -. (taken /. 100.)) /. float_of_int (max 1 (List.length ungrouped)))
  in
  List.fold_left
    (fun text (id, pending) -> replace_all ~pattern:(placeholder id) ~by:(blank_markup pending (weight_of pending)) text)
    text entries

(* A set with a stem reads like the course's assignments: the instruction
   once, then parts a), b), c). Without one, questions are separated by a
   blank line, which the project's own PG grammar accepts. *)
(* [weigh_all] writes weights even when no answer asks for one, so that a
   document merged with others counts each of its questions equally. *)
let document ?width ?(context = "Numeric") ?stem ?(weigh_all = false) questions =
  let setup = new_setup () in
  let drafts =
    List.mapi
      (fun index (question : Ag_engine.question) ->
        let label =
          match stem with
          | Some _ when List.length questions > 1 && index < String.length letters ->
              Printf.sprintf "%c) " letters.[index]
          | _ -> ""
        in
        let first = List.length setup.blanks in
        let text = label ^ question.Ag_engine.prompt ^ answer_block setup ?width question.Ag_engine.answer in
        (text, List.init (List.length setup.blanks - first) (fun i -> first + i)))
      questions
  in
  let weighted = weigh_all || setup.groups <> [] in
  let share = 100. /. float_of_int (max 1 (List.length questions)) in
  let parts = List.map (fun (text, ids) -> finish setup ~weighted ~share ids text) drafts in
  let body =
    (match stem with Some text -> [ text ] | None -> []) @ parts |> String.concat "\n\n"
  in
  let setup_lines = setup_text context setup in
  header ~macros:setup.macros context ^ setup_lines ^ "BEGIN_PGML\n" ^ body ^ "\n" ^ footer

let of_spec ?count (spec : Ag_check.spec) =
  let count = match count with Some count -> count | None -> 6 in
  let questions = List.init count (fun _ -> Ag_engine.generate spec) in
  document ?width:spec.Ag_check.width ~context:spec.Ag_check.context ?stem:spec.Ag_check.stem
    questions
