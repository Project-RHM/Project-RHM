(* rhema_latex.ml — the same questions as a paper: a LaTeX document.

   A question's text is PGML, of which a paper needs little: `[`...`]` is
   inline mathematics and `[``...``]` displayed mathematics, both already
   LaTeX; everything else is words, in which the characters LaTeX reads as
   commands are escaped. An answer blank becomes a rule to write on. With
   [answers] the document ends with a key on a page of its own, each answer
   in the LaTeX form its value already has.

   The preamble asks for amsmath, amssymb and graphicx and nothing else that
   a TeX installation may lack, and the questions are set through four
   commands defined there (\rhemaquestion, \rhemablank, \rhemaheading,
   \rhemamath), so that a teacher who wants another layout changes four
   lines.

   A formula in the text cannot be broken across lines where it is inside
   brackets, and the engine's formulas often are: a long derivative or a
   matrix of six columns would run off the page. \rhemamath sets a formula
   in a box, which goes to the next line when it does not fit the rest of
   this one and is scaled down to the width of the line when it is wider
   than that. The text is set ragged right, so that a line left short by
   such a box is not stretched. *)

(* ------------------------------------------------------------------ *)
(* Words                                                               *)
(* ------------------------------------------------------------------ *)

let escape text =
  let buffer = Buffer.create (String.length text + 16) in
  String.iter
    (function
      | '\\' -> Buffer.add_string buffer "\\textbackslash{}"
      | ('{' | '}' | '$' | '&' | '%' | '#' | '_') as character ->
          Buffer.add_char buffer '\\';
          Buffer.add_char buffer character
      | '~' -> Buffer.add_string buffer "\\textasciitilde{}"
      | '^' -> Buffer.add_string buffer "\\textasciicircum{}"
      | character -> Buffer.add_char buffer character)
    text;
  Buffer.contents buffer

(* The position of [fragment] in [text] at or after [start]. *)
let find_from text start fragment =
  let length = String.length text and size = String.length fragment in
  let rec search index =
    if index + size > length then None
    else if String.sub text index size = fragment then Some index
    else search (index + 1)
  in
  search start

(* Words outside mathematics: escaped, with PGML's line break (two spaces
   before the end of a line) kept as one. *)
let words text =
  let lines = String.split_on_char '\n' text in
  let count = List.length lines in
  lines
  |> List.mapi (fun index line ->
         let size = String.length line in
         let broken = index < count - 1 && size >= 2 && String.sub line (size - 2) 2 = "  " && String.trim line <> "" in
         if broken then escape (String.sub line 0 (size - 2)) ^ "\\\\" else escape line)
  |> String.concat "\n"

(* PGML text to LaTeX. A `[`` that is never closed is left as words. *)
let text_to_latex text =
  let buffer = Buffer.create (String.length text + 32) in
  let length = String.length text in
  let starts position fragment =
    position + String.length fragment <= length && String.sub text position (String.length fragment) = fragment
  in
  let rec go position =
    if position >= length then ()
    else
      match find_from text position "[`" with
      | None -> Buffer.add_string buffer (words (String.sub text position (length - position)))
      | Some opening -> (
          let display = starts opening "[``" in
          let inside = opening + if display then 3 else 2 in
          let closing = if display then "``]" else "`]" in
          match find_from text inside closing with
          | None -> Buffer.add_string buffer (words (String.sub text position (length - position)))
          | Some close ->
              Buffer.add_string buffer (words (String.sub text position (opening - position)));
              let mathematics = String.sub text inside (close - inside) in
              Buffer.add_string buffer
                (if display then "\\[ " ^ mathematics ^ " \\]" else "\\rhemamath{" ^ mathematics ^ "}");
              (* PGML's trailing star asks for display style; a paper has no use for it *)
              let after = close + String.length closing in
              go (if starts after "*" then after + 1 else after))
  in
  go 0;
  Buffer.contents buffer

(* ------------------------------------------------------------------ *)
(* Answers                                                             *)
(* ------------------------------------------------------------------ *)

(* The square root of a non-negative rational, written exactly. *)
let root_latex number =
  let exact n =
    let r = int_of_float (Float.round (sqrt (float_of_int n))) in
    if r * r = n then Some r else None
  in
  let numerator = number.Rhema_number.numerator and denominator = number.Rhema_number.denominator in
  match (exact numerator, exact denominator) with
  | Some top, Some bottom -> Rhema_engine.number_latex (Rhema_number.make top bottom)
  | _ -> "\\sqrt{" ^ Rhema_engine.number_latex number ^ "}"

let squared_norm vector =
  List.fold_left
    (fun total component -> Rhema_number.add total (Rhema_number.multiply component component))
    Rhema_number.zero (Rhema_vector.components vector)

(* An answer as it is printed in the key: mathematics in display style, so
   that a fraction is as large as it is in the question, and for an answer
   that is graded up to a multiple the words that say so. *)
let rec answer_latex value =
  let shown mathematics = "\\rhemamath{\\displaystyle " ^ mathematics ^ "}" in
  match value with
  | Rhema_engine.Num number | Rhema_engine.Exactly number -> shown (Rhema_engine.number_latex number)
  | Rhema_engine.Truth truth -> shown (if truth then "1" else "0")
  | Rhema_engine.Text text -> "\\texttt{" ^ escape text ^ "}"
  | Rhema_engine.Complex (real, imaginary) -> shown (Rhema_engine.format_complex_latex real imaginary)
  | Rhema_engine.Formula formula -> shown (Rhema_formula.to_latex formula)
  | Rhema_engine.Polynomial polynomial -> shown (Rhema_polynomial.to_latex polynomial)
  | Rhema_engine.Boolean formula -> shown (Rhema_boolean.to_latex formula)
  | Rhema_engine.Matrix matrix -> shown (Rhema_matrix.to_latex matrix)
  | Rhema_engine.Set set -> shown (Rhema_set.to_latex set)
  | Rhema_engine.Vector vector -> shown (Rhema_vector.to_latex vector)
  | Rhema_engine.Point coordinates ->
      shown ("\\left(" ^ String.concat ", " (List.map Rhema_engine.number_latex coordinates) ^ "\\right)")
  | Rhema_engine.VectorNormAnswer vector -> shown (root_latex (squared_norm vector))
  | Rhema_engine.VectorUnitAnswer vector ->
      let norm = root_latex (squared_norm vector) in
      if norm = "1" then shown (Rhema_vector.to_latex vector)
      else shown ("\\frac{1}{" ^ norm ^ "} " ^ Rhema_vector.to_latex vector)
  | Rhema_engine.VectorDirectionAnswer (vector, same_direction) ->
      shown (Rhema_vector.to_latex vector)
      ^ ", or any "
      ^ (if same_direction then "positive" else "non-zero")
      ^ " multiple of it"
  | Rhema_engine.Plain value -> answer_latex value
  | Rhema_engine.Equation _ -> invalid_arg "an Equation is not a direct answer"
  | Rhema_engine.Rich _ -> invalid_arg "text that holds an answer blank is not itself an answer"

(* ------------------------------------------------------------------ *)
(* The document                                                        *)
(* ------------------------------------------------------------------ *)

(* A blank's rule: as wide as its answer field in WeBWorK, where the grammar
   says how wide that is, within what a line of a page can take. *)
let blank_length = function
  | None -> "3cm"
  | Some columns -> Printf.sprintf "%.1fem" (Float.min 24. (Float.max 4. (0.6 *. float_of_int columns)))

let question_body ?width (question : Rhema_engine.question) =
  let width = match question.Rhema_engine.width with Some columns -> Some columns | None -> width in
  (* A rule cannot be broken across lines, so it is given a space before it
     where the text has none: the line can then end there, and a rule that
     does not fit goes to the next line instead of into the margin. *)
  let ends_in_space text =
    text = "" || match text.[String.length text - 1] with ' ' | '\n' | '\t' -> true | _ -> false
  in
  let buffer = Buffer.create 256 in
  let blank length =
    if not (ends_in_space (Buffer.contents buffer)) then Buffer.add_char buffer ' ';
    Buffer.add_string buffer ("\\rhemablank{" ^ length ^ "}")
  in
  (* Text joined with ++ arrives as several pieces, and a formula may begin
     in one and end in another: the text between two blanks is read whole. *)
  let pending = Buffer.create 256 in
  let flush () =
    Buffer.add_string buffer (text_to_latex (Buffer.contents pending));
    Buffer.clear pending
  in
  List.iter
    (function
      | Rhema_engine.Piece_text text -> Buffer.add_string pending text
      | Rhema_engine.Piece_blank _ ->
          flush ();
          blank (blank_length width)
      | Rhema_engine.Piece_wide_blank (_, columns) ->
          flush ();
          blank (blank_length (Some columns)))
    question.Rhema_engine.pieces;
  flush ();
  String.trim (Buffer.contents buffer)

let preamble =
  "\\documentclass[11pt]{article}\n\
   \\usepackage[T1]{fontenc}\n\
   \\usepackage[utf8]{inputenc}\n\
   \\usepackage[margin=2.5cm]{geometry}\n\
   \\usepackage{amsmath,amssymb}\n\
   \\usepackage{graphicx}\n\
   \\setlength{\\parindent}{0pt}\n\
   \\setlength{\\parskip}{0.6em}\n\
   % How a paper is set: change these four to change every question.\n\
   \\newcommand{\\rhemaquestion}[1]{\\par\\medskip\\noindent\\textbf{#1}\\quad}\n\
   \\newcommand{\\rhemablank}[1]{\\underline{\\hspace{#1}}}\n\
   \\newcommand{\\rhemaheading}[1]{\\par\\bigskip\\noindent{\\large\\bfseries #1}\\par}\n\
   % A formula: kept whole, and scaled down when it is wider than the line.\n\
   \\newsavebox{\\rhemabox}\n\
   \\newcommand{\\rhemamath}[1]{\\sbox{\\rhemabox}{\\(#1\\)}%\n\
   \\ifdim\\wd\\rhemabox>\\linewidth\\resizebox{\\linewidth}{!}{\\usebox{\\rhemabox}}\\else\\usebox{\\rhemabox}\\fi}\n"

(* [items] carry the labels a set gives its questions ("2(a)."); a question
   without one is numbered by its place. *)
let document_items ?width ?(answers = false) ?student ~title (items : Rhema_pgml.item list) =
  let buffer = Buffer.create 4096 in
  let labelled =
    List.mapi
      (fun index (item : Rhema_pgml.item) ->
        ((if item.Rhema_pgml.label = "" then string_of_int (index + 1) ^ "." else item.Rhema_pgml.label), item))
      items
  in
  Buffer.add_string buffer preamble;
  Buffer.add_string buffer "\\begin{document}\n\\raggedright\n\n";
  Printf.bprintf buffer "\\begin{center}\n{\\Large\\bfseries %s}\n\\end{center}\n" (escape title);
  Option.iter (fun student -> Printf.bprintf buffer "\\begin{center}\n%s\n\\end{center}\n" (escape student)) student;
  List.iter
    (fun (label, (item : Rhema_pgml.item)) ->
      Option.iter (fun heading -> Printf.bprintf buffer "\n\\rhemaheading{%s}\n" (escape heading)) item.Rhema_pgml.heading;
      Printf.bprintf buffer "\n\\rhemaquestion{%s}\n%s\n" (escape label) (question_body ?width item.Rhema_pgml.question))
    labelled;
  if answers then begin
    Buffer.add_string buffer "\n\\newpage\n\\begin{center}\n{\\Large\\bfseries Answers}\n\\end{center}\n";
    List.iter
      (fun (label, (item : Rhema_pgml.item)) ->
        Printf.bprintf buffer "\n\\rhemaquestion{%s}\n%s\n" (escape label)
          (String.concat ";\\quad " (List.map answer_latex item.Rhema_pgml.question.Rhema_engine.answers)))
      labelled
  end;
  Buffer.add_string buffer "\n\\end{document}\n";
  Buffer.contents buffer

let document ?width ?answers ?student ~title questions =
  document_items ?width ?answers ?student ~title
    (List.map (fun question -> { Rhema_pgml.label = ""; heading = None; question }) questions)
