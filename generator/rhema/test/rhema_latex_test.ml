(* Checks of the LaTeX output (rhema_latex.ml, rhema_pdf.ml). Nothing here
   runs TeX: these are checks of what is written, which hold on any
   machine. tools/check_latex_output.sh compiles a paper of every library
   grammar where a TeX engine is installed.

   1. Words: the characters LaTeX reads as commands are escaped.
   2. PGML text: inline and displayed mathematics, line breaks.
   3. Answers: each kind of value in the form the key prints.
   4. A paper of every library grammar: one question command for each
      question and one rule for each blank; mathematics and braces closed;
      no character left that LaTeX would read as a command; with the key,
      one entry for each question and one answer for each blank; the same
      questions as the PG document of the same seeds.
   5. Sets: labels and headings; the student line; the title.
   6. The PDF step without a TeX engine: a message, no file. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let check label condition = if not condition then fail label

let expect label got wanted =
  if got <> wanted then fail (Printf.sprintf "%s: got %S, wanted %S" label got wanted)

let contains text fragment =
  let rec search index =
    index + String.length fragment <= String.length text
    && (String.sub text index (String.length fragment) = fragment || search (index + 1))
  in
  search 0

let count text fragment =
  let size = String.length fragment in
  let rec go index found =
    if index + size > String.length text then found
    else if String.sub text index size = fragment then go (index + size) (found + 1)
    else go (index + 1) found
  in
  go 0 0

let load_file filename =
  match Rhema_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Rhema_load.string_of_failure error)) errors;
      exit 1

(* ------------------------------------------------------------------ *)
(* 1. Words                                                             *)
(* ------------------------------------------------------------------ *)

let () =
  expect "plain words" (Rhema_latex.escape "Find the rank.") "Find the rank.";
  expect "specials" (Rhema_latex.escape "50% of A&B #1 costs $3_x") "50\\% of A\\&B \\#1 costs \\$3\\_x";
  expect "braces" (Rhema_latex.escape "{a}") "\\{a\\}";
  expect "backslash" (Rhema_latex.escape "a\\b") "a\\textbackslash{}b";
  expect "tilde and caret" (Rhema_latex.escape "~x^2") "\\textasciitilde{}x\\textasciicircum{}2"

(* ------------------------------------------------------------------ *)
(* 2. PGML text                                                         *)
(* ------------------------------------------------------------------ *)

let () =
  let t = Rhema_latex.text_to_latex in
  expect "inline mathematics" (t "Find [`x^{2}`] now.") "Find \\rhemamath{x^{2}} now.";
  expect "displayed mathematics" (t "Then [``\\frac{1}{2}``] holds.") "Then \\[ \\frac{1}{2} \\] holds.";
  expect "a trailing star" (t "Sum [`\\sum_k k`]* here") "Sum \\rhemamath{\\sum_k k} here";
  expect "mathematics is not escaped, words are" (t "100% of [`a_1 & b`] #2") "100\\% of \\rhemamath{a_1 & b} \\#2";
  expect "two formulas" (t "[`p`], [`q`] and [`r`]") "\\rhemamath{p}, \\rhemamath{q} and \\rhemamath{r}";
  expect "never closed" (t "a [`b") "a [`b";
  expect "a line break" (t "first  \nsecond") "first\\\\\nsecond";
  expect "a plain new line" (t "first\nsecond") "first\nsecond"

(* ------------------------------------------------------------------ *)
(* 3. Answers                                                           *)
(* ------------------------------------------------------------------ *)

let () =
  let whole = Rhema_number.of_int in
  let vector components = Rhema_vector.make (List.map whole components) in
  let shown mathematics = "\\rhemamath{\\displaystyle " ^ mathematics ^ "}" in
  List.iter
    (fun (label, value, wanted) -> expect label (Rhema_latex.answer_latex value) wanted)
    [ ("a whole number", Rhema_engine.Num (whole 42), shown "42");
      ("a fraction", Rhema_engine.Num (Rhema_number.make (-7) 3), shown "-\\frac{7}{3}");
      ("an exact number", Rhema_engine.Exactly (whole 1011), shown "1011");
      ("true", Rhema_engine.Truth true, shown "1");
      ("a complex number", Rhema_engine.Complex (whole 3, whole (-2)), shown "3 - 2i");
      ("a vector", Rhema_engine.Vector (vector [ 1; -2; 3 ]), shown "\\langle 1, -2, 3 \\rangle");
      ("a point", Rhema_engine.Point [ whole 3; Rhema_number.make 1 2 ], shown "\\left(3, \\frac{1}{2}\\right)");
      ("a norm that is whole", Rhema_engine.VectorNormAnswer (vector [ 3; 4 ]), shown "5");
      ("a norm that is a root", Rhema_engine.VectorNormAnswer (vector [ 1; 2; 3 ]), shown "\\sqrt{14}");
      ( "a unit vector",
        Rhema_engine.VectorUnitAnswer (vector [ 1; 2; 3 ]),
        shown "\\frac{1}{\\sqrt{14}} \\langle 1, 2, 3 \\rangle" );
      ("a unit vector already", Rhema_engine.VectorUnitAnswer (vector [ 0; 1 ]), shown "\\langle 0, 1 \\rangle");
      ( "any multiple",
        Rhema_engine.VectorDirectionAnswer (vector [ 1; 2; 1 ], false),
        shown "\\langle 1, 2, 1 \\rangle" ^ ", or any non-zero multiple of it" );
      ( "any positive multiple",
        Rhema_engine.VectorDirectionAnswer (vector [ 1; 2; 1 ], true),
        shown "\\langle 1, 2, 1 \\rangle" ^ ", or any positive multiple of it" );
      ("worked out", Rhema_engine.Plain (Rhema_engine.Num (whole 4)), shown "4");
      ("text", Rhema_engine.Text "x^2", "\\texttt{x\\textasciicircum{}2}") ]

(* ------------------------------------------------------------------ *)
(* 4. A paper of every library grammar                                  *)
(* ------------------------------------------------------------------ *)

(* The text between \begin{document} and \end{document}. *)
let body document =
  let opening = "\\begin{document}" and closing = "\\end{document}" in
  let start = Str.search_forward (Str.regexp_string opening) document 0 + String.length opening in
  let stop = Str.search_forward (Str.regexp_string closing) document start in
  String.sub document start (stop - start)

(* The same with every formula taken out: each \rhemamath{...}, its braces
   matched, and displayed mathematics. *)
let words_of text =
  let opening = "\\rhemamath{" in
  let buffer = Buffer.create (String.length text) in
  let length = String.length text in
  let rec go position =
    if position >= length then ()
    else if position + String.length opening <= length && String.sub text position (String.length opening) = opening
    then begin
      let depth = ref 1 and index = ref (position + String.length opening) in
      while !depth > 0 && !index < length do
        (match text.[!index] with
        | '\\' -> incr index (* an escaped character is not a brace *)
        | '{' -> incr depth
        | '}' -> decr depth
        | _ -> ());
        incr index
      done;
      Buffer.add_char buffer ' ';
      go !index
    end
    else begin
      Buffer.add_char buffer text.[position];
      go (position + 1)
    end
  in
  go 0;
  Str.global_replace (Str.regexp "\\\\\\[.*\\\\\\]") " " (Buffer.contents buffer)

(* A character LaTeX reads as a command, with no backslash before it. *)
let stray_special text =
  let found = ref None in
  String.iteri
    (fun index character ->
      if !found = None && String.contains "%&#$_^~" character && (index = 0 || text.[index - 1] <> '\\') then
        found := Some (String.sub text (max 0 (index - 20)) (min 40 (String.length text - max 0 (index - 20)))))
    text;
  !found

let check_paper name (questions : Rhema_engine.question list) =
  let blanks = List.fold_left (fun total (q : Rhema_engine.question) -> total + List.length q.Rhema_engine.answers) 0 questions in
  let asked = List.length questions in
  List.iter
    (fun answers ->
      let document = Rhema_latex.document ~answers ~title:name questions in
      let which = name ^ if answers then " with the key" else "" in
      check (which ^ ": not one document") (count document "\\begin{document}" = 1 && count document "\\end{document}" = 1);
      let text = body document in
      check
        (Printf.sprintf "%s: %d question commands for %d questions" which (count text "\\rhemaquestion{") asked)
        (count text "\\rhemaquestion{" = if answers then 2 * asked else asked);
      check
        (Printf.sprintf "%s: %d rules for %d blanks" which (count text "\\rhemablank{") blanks)
        (count text "\\rhemablank{" = blanks);
      check (which ^ ": mathematics left open") (count text "\\[" = count text "\\]");
      check (which ^ ": mathematics outside \\rhemamath") (count text "\\(" = 0 && count text "\\)" = 0);
      check (which ^ ": PGML left in the paper") (not (contains text "[`") && not (contains text "`]"));
      check (which ^ ": braces not balanced") (count document "{" - count document "\\{" = count document "}" - count document "\\}");
      (match stray_special (words_of text) with
      | None -> ()
      | Some near -> fail (Printf.sprintf "%s: a character LaTeX reads as a command, near %S" which near));
      if answers then begin
        let key = List.nth (Str.split (Str.regexp_string "\\newpage") text) 1 in
        let entries = List.tl (Str.split (Str.regexp_string "\\rhemaquestion{") key) in
        check (which ^ ": the key does not have an entry for each question") (List.length entries = asked);
        List.iteri
          (fun index (entry, (q : Rhema_engine.question)) ->
            let given = List.length (Str.split (Str.regexp_string ";\\quad ") entry) in
            if given <> List.length q.Rhema_engine.answers then
              fail
                (Printf.sprintf "%s: question %d has %d blanks and %d answers in the key" which (index + 1)
                   (List.length q.Rhema_engine.answers) given))
          (List.combine entries questions)
      end)
    [ false; true ]

let grammars =
  Sys.readdir "." |> Array.to_list
  |> List.filter (fun name -> Filename.check_suffix name ".rhm")
  |> List.sort compare

let () =
  let papers = ref 0 in
  List.iter
    (fun name ->
      match Rhema_load.parse_file name with
      | Error _ -> ()
      | Ok spec when spec.Rhema_check.library -> ()
      | Ok spec -> (
          Random.init 2026;
          match List.init 25 (fun _ -> Rhema_engine.generate spec) with
          | exception Rhema_engine.Generation_error message -> fail (name ^ ": " ^ message)
          | questions ->
              incr papers;
              check_paper name questions;
              (* the paper asks what the PG document asks: the same number of blanks *)
              let pg = Rhema_pgml.document questions in
              let tex = Rhema_latex.document ~title:name questions in
              if count pg "[_____]{" <> count tex "\\rhemablank{" then
                fail (name ^ ": the paper and the PG document do not have the same blanks")))
    grammars;
  check (Printf.sprintf "only %d grammars gave a paper" !papers) (!papers >= 40);
  (* the grammars that scale, at a high budget: longer text, more blanks *)
  List.iter
    (fun (name, cost) ->
      let spec = load_file name in
      match Rhema_check.with_initial spec "cost" cost with
      | Error message -> fail message
      | Ok spec ->
          Random.init 7;
          check_paper (Printf.sprintf "%s at budget %d" name cost) (List.init 25 (fun _ -> Rhema_engine.generate spec)))
    [ ("partial_fractions.rhm", 8); ("taylor.rhm", 8); ("inequality.rhm", 8); ("partial_derivatives.rhm", 8);
      ("row_reduction.rhm", 8); ("base_conversion.rhm", 8); ("definite_integral.rhm", 8); ("recurrence.rhm", 3);
      ("analytic_geometry.rhm", 3); ("boolean.rhm", 14); ("calculus.rhm", 12) ]

(* ------------------------------------------------------------------ *)
(* 5. Sets, the student line and the title                              *)
(* ------------------------------------------------------------------ *)

let () =
  let spec = load_file "homework_set.rhm" in
  match List.find_opt (fun (set : Rhema_ast.set_decl) -> set.Rhema_ast.set_name = "homework") spec.Rhema_check.sets with
  | None -> fail "homework_set.rhm has no set called homework"
  | Some set ->
      let result = Rhema_sets.run spec set ~variant:11 ~paper:"homework" in
      let questions = Rhema_sets.questions result in
      let tex = Rhema_sets.latex ~answers:true ~student:"Student: 2330026211" ~title:"Week 3 & 4" result in
      check "the title is not escaped" (contains tex "{\\Large\\bfseries Week 3 \\& 4}");
      check "the student line is missing" (contains tex "Student: 2330026211");
      check "a set's labels are missing" (contains tex "\\rhemaquestion{1(a).}" && contains tex "\\rhemaquestion{2(b).}");
      check "a part's heading is missing" (count tex "\\rhemaheading{" >= 2);
      check "the key does not repeat the labels" (count tex "\\rhemaquestion{1(a).}" = 2);
      check "the set's paper does not hold every question" (count tex "\\rhemaquestion{" = 2 * List.length questions);
      (* without a key there is no second page *)
      let plain = Rhema_sets.latex ~title:"homework" result in
      check "a paper without a key has an Answers page" (not (contains plain "Answers") && not (contains plain "\\newpage"));
      (* questions that are not a set are numbered by their place *)
      let numbered = Rhema_latex.document ~title:"t" (List.filteri (fun index _ -> index < 3) questions) in
      check "plain questions are not numbered 1. 2. 3."
        (contains numbered "\\rhemaquestion{1.}" && contains numbered "\\rhemaquestion{3.}"
        && not (contains numbered "\\rhemaquestion{4.}"))

(* ------------------------------------------------------------------ *)
(* 6. The PDF step                                                      *)
(* ------------------------------------------------------------------ *)

let () =
  expect "the errors of a log"
    (Rhema_pdf.errors_of_log "This is pdfTeX\n! Undefined control sequence.\nl.12 \\foo\n           bar\nmore\n")
    "! Undefined control sequence.\nl.12 \\foo\n           bar";
  check "a log without an error line" (contains (Rhema_pdf.errors_of_log "all fine\n") "no line starting with !");
  (* a blank's rule follows the width a grammar gives its answer fields *)
  expect "no width" (Rhema_latex.blank_length None) "3cm";
  expect "a narrow field" (Rhema_latex.blank_length (Some 2)) "4.0em";
  expect "a field of 20" (Rhema_latex.blank_length (Some 20)) "12.0em";
  expect "a very wide field" (Rhema_latex.blank_length (Some 200)) "24.0em"

(* A blank with a width of its own, which no library grammar has, and text
   that needs escaping beside a formula. *)
let () =
  let name = "latex_wide_test.rhm" in
  let channel = open_out name in
  output_string channel
    "attribute cost = 1 split\nsynth text on Q\nstart Q\nQ -> integer_between(2, 9) {\n  cost = -1\n\
    \  text = \"Is 50% of [`x_1`] & more? Centre \" ++ blank(point2($1.value, 3)) ++ \", radius\" ++ blank_wide($1.value, 30)\n\
     }\nprompt \"{Q.text}\"\n";
  close_out channel;
  let spec = load_file name in
  Sys.remove name;
  Random.init 3;
  let question = Rhema_engine.generate spec in
  let tex = Rhema_latex.document ~answers:true ~title:"wide" [ question ] in
  check "the plain blank has no rule of the usual length" (contains tex "Centre \\rhemablank{3cm}");
  check "the wide blank has no rule of its own length, after a space" (contains tex ", radius \\rhemablank{18.0em}");
  check "words beside a formula are not escaped" (contains tex "Is 50\\% of \\rhemamath{x_1} \\& more?");
  check_paper "a question with a wide blank" [ question ]

let () =
  if !failures = 0 then print_endline "Rhema LaTeX output tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d LaTeX output test(s) failed." !failures);
    exit 1
  end
