(* Checks for the additions to the language after the module layer: the
   literals `true` and `false`, a `let` inside a rule, the point value,
   matrices of any shape (rows, columns, stacking, the reduced row echelon
   form and the rank), answer blanks in text, formula answers in any
   variables, pi, exact values of sine, cosine and tangent, and answers that
   must be worked out. Each is tried in a small grammar written here, and
   the functions behind them are also checked against what they are defined
   to be. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let check label condition = if not condition then fail label

let contains text fragment =
  let rec search index =
    index + String.length fragment <= String.length text
    && (String.sub text index (String.length fragment) = fragment || search (index + 1))
  in
  search 0

let load_source name content =
  let channel = open_out name in
  output_string channel content;
  close_out channel;
  let result = Rhema_load.parse_file name in
  Sys.remove name;
  result

let expect_ok name content =
  match load_source name content with
  | Ok spec -> Some spec
  | Error errors ->
      List.iter (fun error -> fail (name ^ ": " ^ Rhema_load.string_of_failure error)) errors;
      None

let expect_error name content ~mentions =
  match load_source name content with
  | Ok _ -> fail (Printf.sprintf "%s was accepted although %s" name mentions)
  | Error errors ->
      if not (List.exists (fun error -> contains (Rhema_load.string_of_failure error) mentions) errors)
      then
        fail
          (Printf.sprintf "%s: no error mentions %S; got: %s" name mentions
             (errors |> List.map Rhema_load.string_of_failure |> String.concat " | "))

let questions spec count =
  List.init count (fun seed ->
      Random.init seed;
      match Rhema_engine.generate spec with
      | question -> Some question
      | exception Rhema_engine.Generation_error message ->
          fail (Printf.sprintf "seed %d: %s" seed message);
          None)
  |> List.filter_map Fun.id

let header = "attribute cost = 1 split\nsynth text on Q\nsynth answer_value on Q\nstart Q\n"
let footer = "prompt \"{Q.text}\"\nanswer Q.answer_value\n"

(* ------------------------------------------------------------------ *)
(* 1. true and false                                                    *)
(* ------------------------------------------------------------------ *)

let () =
  let source =
    header
    ^ "Q -> integer_between(1, 9) when true and not false {\n\
      \  cost = -1\n\
      \  require true\n\
      \  text = cond(false, \"wrong\", cond(true, \"right\", \"wrong\"))\n\
      \  answer_value = set_interval($1.value, $1.value + 1, true, false)\n\
       }\n\
       Q -> integer_between(1, 9) when false {\n\
      \  cost = -1\n\
      \  text = \"never\"\n\
      \  answer_value = set_empty()\n\
       }\n"
    ^ footer
  in
  (match expect_ok "literals_test.rhm" source with
  | None -> ()
  | Some spec ->
      List.iter
        (fun (q : Rhema_engine.question) ->
          check "a literal chose the wrong branch" (q.Rhema_engine.prompt = "right");
          match q.Rhema_engine.answer with
          | Rhema_engine.Set (Rhema_set.Interval (_, _, Rhema_set.Closed, Rhema_set.Open)) -> ()
          | other -> fail ("true and false as arguments gave " ^ Rhema_engine.describe_value other))
        (questions spec 30));
  (* They are reserved: neither can be used as a name. *)
  expect_error "reserved_test.rhm" ("random true = boolean\n" ^ header ^ footer) ~mentions:"true";
  (* A literal is a truth value, not a number. *)
  match
    expect_ok "literal_type_test.rhm"
      (header ^ "Q -> integer_between(1, 9) {\n  cost = -1\n  text = \"x\"\n  answer_value = true + 1\n}\n" ^ footer)
  with
  | None -> ()
  | Some spec -> (
      Random.init 1;
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error _ -> ()
      | q -> fail ("true + 1 gave " ^ Rhema_engine.describe_value q.Rhema_engine.answer))

(* ------------------------------------------------------------------ *)
(* 2. let inside a rule                                                 *)
(* ------------------------------------------------------------------ *)

let rule body = header ^ "random given = integer_between(1, 3)\nQ -> integer_between(-3, 2) integer_between(1, 4) {\n  cost = -1\n" ^ body ^ "}\n" ^ footer

let () =
  let source =
    rule
      "  let upper = $1.value + $2.value\n\
      \  let span = upper - $1.value\n\
      \  require upper != 0\n\
      \  text = str($1.value) ++ \" \" ++ str(upper) ++ \" \" ++ str(span)\n\
      \  let shown = text ++ \"!\"\n\
      \  answer_value = upper * span + given - given\n"
  in
  (match expect_ok "local_test.rhm" source with
  | None -> ()
  | Some spec ->
      let seen = questions spec 60 in
      check "no question was generated with local names" (seen <> []);
      List.iter
        (fun (q : Rhema_engine.question) ->
          (match String.split_on_char ' ' q.Rhema_engine.prompt |> List.map int_of_string with
          | [ lower; upper; width ] ->
              check "a local name has the wrong value" (width = upper - lower && width >= 1);
              check "a require on a local name was not applied" (upper <> 0);
              (match q.Rhema_engine.answer with
              | Rhema_engine.Num n -> check "an answer built on local names is wrong" (Rhema_number.equal n (Rhema_number.of_int (upper * width)))
              | other -> fail ("not a number: " ^ Rhema_engine.describe_value other))
          | _ -> fail ("unexpected prompt " ^ q.Rhema_engine.prompt)
          | exception Failure _ -> fail ("unexpected prompt " ^ q.Rhema_engine.prompt));
          (* The node carries its attributes only. *)
          let node = q.Rhema_engine.tree in
          List.iter
            (fun name ->
              if List.mem_assoc name node.Rhema_engine.attributes then
                fail (Printf.sprintf "the local name '%s' was kept on the node" name))
            [ "upper"; "span"; "shown" ];
          check "the node lost an attribute" (List.mem_assoc "text" node.Rhema_engine.attributes))
        seen);
  (* A local name must be new, is seen only below its line, and never by
     what is evaluated before the children exist. *)
  expect_error "local_inherited_test.rhm" (rule "  let cost = 3\n  text = \"x\"\n  answer_value = 1\n")
    ~mentions:"hide the inherited attribute 'cost'";
  expect_error "local_synth_test.rhm" (rule "  let text = \"x\"\n  text = \"y\"\n  answer_value = 1\n")
    ~mentions:"'text' is a synthesized attribute";
  expect_error "local_global_test.rhm" (rule "  let given = 2\n  text = \"x\"\n  answer_value = 1\n")
    ~mentions:"hide the question-level 'given'";
  expect_error "local_twice_test.rhm" (rule "  let a = 1\n  let a = 2\n  text = \"x\"\n  answer_value = a\n")
    ~mentions:"'a' is assigned twice";
  expect_error "local_early_test.rhm" (rule "  text = str(later)\n  let later = 1\n  answer_value = 1\n")
    ~mentions:"unknown name 'later'";
  expect_error "local_budget_test.rhm" (rule "  let step = 1\n  text = \"x\"\n  answer_value = 1\n" |> fun s ->
    (* the budget update reads the local name *)
    Str.global_replace (Str.regexp_string "cost = -1") "cost = 0 - step" s)
    ~mentions:"unknown name 'step'";
  (* A refused name is reported once: the attribute of that name is still
     asked for, and its own assignment is not called a second one. *)
  match load_source "local_once_test.rhm" (rule "  let text = \"x\"\n  text = \"y\"\n  answer_value = 1\n") with
  | Ok _ -> fail "a local name hiding a synthesized attribute was accepted"
  | Error errors -> check "one mistake with a local name was reported more than once" (List.length errors = 1)

(* ------------------------------------------------------------------ *)
(* 3. Points                                                            *)
(* ------------------------------------------------------------------ *)

let () =
  let source =
    header
    ^ "Q -> integer_between(-9, 9) integer_between(-9, 9) integer_between(-9, 9) {\n\
      \  cost = -1\n\
      \  let middle = point2(($1.value + $2.value) / 2, $3.value)\n\
      \  require middle = point2(($2.value + $1.value) / 2, $3.value)\n\
      \  require middle != point2(($1.value + $2.value) / 2, $3.value + 1)\n\
      \  require point3(1, 2, 3) != point2(1, 2)\n\
      \  text = point_latex(middle) ++ \" \" ++ point_latex(point3(1, 0 - 1 / 3, 0))\n\
      \  answer_value = middle\n\
       }\n"
    ^ footer
  in
  match expect_ok "point_test.rhm" source with
  | None -> ()
  | Some spec ->
      let seen = questions spec 60 in
      let fractions = ref false in
      List.iter
        (fun (q : Rhema_engine.question) ->
          check "a question with a point is not in the default context" (q.Rhema_engine.context = "Numeric");
          check "point_latex of a point in space"
            (contains q.Rhema_engine.prompt "\\left(1, -\\frac{1}{3}, 0\\right)");
          match q.Rhema_engine.answer with
          | Rhema_engine.Point [ x; y ] ->
              if not (Rhema_number.is_integer x) then fractions := true;
              let expected =
                Printf.sprintf "Point(Parser::Context->getCopy(\"Point\"),%s,%s)" (Rhema_number.to_string x)
                  (Rhema_number.to_string y)
              in
              let pg = Rhema_pgml.document [ q ] in
              if not (contains pg ("[_____]{" ^ expected ^ "}")) then
                fail (Printf.sprintf "the PG document does not hold %s:\n%s" expected pg);
              check "a point's listing" (q.Rhema_engine.answer_text = Printf.sprintf "Point(%s, %s)" (Rhema_number.to_string x) (Rhema_number.to_string y))
          | other -> fail ("not a point of the plane: " ^ Rhema_engine.describe_value other))
        seen;
      check "no point with a fraction was tried" !fractions

(* ------------------------------------------------------------------ *)
(* 4. Matrices of any shape                                             *)
(* ------------------------------------------------------------------ *)

let number = Rhema_number.of_int
let matrix rows = Rhema_matrix.make (List.map (List.map number) rows)

(* The properties that define the reduced row echelon form. *)
let is_reduced (m : Rhema_matrix.t) =
  let rows = Rhema_matrix.entries m in
  let leading row =
    let rec find index = function
      | [] -> None
      | entry :: rest -> if Rhema_number.is_zero entry then find (index + 1) rest else Some (index, entry)
    in
    find 0 row
  in
  let leads = List.map leading rows in
  let rec ordered last = function
    | [] -> true
    | None :: rest -> List.for_all (fun lead -> lead = None) rest
    | Some (column, entry) :: rest ->
        column > last && Rhema_number.equal entry (number 1) && ordered column rest
  in
  ordered (-1) leads
  && List.for_all
       (function
         | None -> true
         | Some (column, _) ->
             (* a pivot is the only non-zero entry of its column *)
             List.length (List.filter (fun row -> not (Rhema_number.is_zero (List.nth row column))) rows) = 1)
       leads

let () =
  Random.init 11;
  for trial = 1 to 300 do
    let height = 1 + Random.int 4 and width = 1 + Random.int 5 in
    (* Small entries and sometimes a repeated row, so that every rank occurs. *)
    let base = List.init height (fun _ -> List.init width (fun _ -> Random.int 5 - 2)) in
    let rows =
      if height > 1 && Random.bool () then List.hd base :: List.hd base :: List.tl (List.tl base) else base
    in
    let m = matrix rows in
    let label text = Printf.sprintf "trial %d (%d by %d): %s" trial height width text in
    let reduced, pivots = Rhema_matrix.reduce m in
    check (label "the result is not in reduced row echelon form") (is_reduced reduced);
    check (label "the shape changed")
      (Rhema_matrix.rows reduced = height && Rhema_matrix.columns reduced = width);
    check (label "reducing twice changes the result") (Rhema_matrix.equal (Rhema_matrix.row_echelon reduced) reduced);
    check (label "the rank is not the number of pivots") (Rhema_matrix.rank m = List.length pivots);
    check (label "rank(A) = rank(A^T)") (Rhema_matrix.rank m = Rhema_matrix.rank (Rhema_matrix.transpose m));
    (* Row operations keep the solutions: x solves A x = 0 exactly when it
       solves R x = 0. A vector of the null space of R is built from each
       free column and tried on A. *)
    List.iter
      (fun free ->
        if not (List.mem free pivots) then begin
          let x = Array.make width Rhema_number.zero in
          x.(free) <- number 1;
          List.iteri
            (fun row pivot -> x.(pivot) <- Rhema_number.negate (Rhema_matrix.entry reduced (row + 1) (free + 1)))
            pivots;
          let image = Rhema_matrix.apply m (Array.to_list x) in
          check (label "a null vector of the reduced form is not one of the matrix") (List.for_all Rhema_number.is_zero image)
        end)
      (List.init width Fun.id);
    (* A square matrix has full rank exactly when its determinant is not zero. *)
    if height = width then
      check (label "full rank and a non-zero determinant disagree")
        ((Rhema_matrix.rank m = height) = not (Rhema_number.is_zero (Rhema_matrix.determinant m)));
    (* Stacking and augmenting, undone by the transpose. *)
    let other = matrix (List.init height (fun _ -> List.init width (fun _ -> Random.int 5 - 2))) in
    let stacked = Rhema_matrix.stack m other and beside = Rhema_matrix.augment m other in
    check (label "stack has the wrong shape") (Rhema_matrix.rows stacked = 2 * height && Rhema_matrix.columns stacked = width);
    check (label "augment has the wrong shape") (Rhema_matrix.rows beside = height && Rhema_matrix.columns beside = 2 * width);
    check (label "augment is not stack transposed")
      (Rhema_matrix.equal beside
         (Rhema_matrix.transpose (Rhema_matrix.stack (Rhema_matrix.transpose m) (Rhema_matrix.transpose other))));
    check (label "an entry of the lower block") (Rhema_number.equal (Rhema_matrix.entry stacked (height + 1) 1) (Rhema_matrix.entry other 1 1));
    check (label "rank([A | A]) = rank(A)") (Rhema_matrix.rank (Rhema_matrix.augment m m) = Rhema_matrix.rank m)
  done;
  (* A worked example, and the refusals. *)
  let m = matrix [ [ 1; 2; 1; 4 ]; [ 2; 4; 0; 6 ]; [ 3; 6; 1; 10 ] ] in
  check "a worked reduced row echelon form"
    (Rhema_matrix.equal (Rhema_matrix.row_echelon m) (matrix [ [ 1; 2; 0; 3 ]; [ 0; 0; 1; 1 ]; [ 0; 0; 0; 0 ] ]));
  check "a worked rank" (Rhema_matrix.rank m = 2);
  check "a row" (Rhema_matrix.equal (Rhema_matrix.of_row [ number 1; number 2 ]) (matrix [ [ 1; 2 ] ]));
  check "a column" (Rhema_matrix.equal (Rhema_matrix.of_column [ number 1; number 2 ]) (matrix [ [ 1 ]; [ 2 ] ]));
  (match Rhema_matrix.stack (matrix [ [ 1; 2 ] ]) (matrix [ [ 1 ] ]) with
  | exception Invalid_argument _ -> ()
  | _ -> fail "matrices of different widths were stacked");
  (match Rhema_matrix.augment (matrix [ [ 1; 2 ] ]) (matrix [ [ 1 ]; [ 2 ] ]) with
  | exception Invalid_argument _ -> ()
  | _ -> fail "matrices of different heights were put side by side");
  (* The same through the language: a 2 by 3 system [A | b] built from
     vectors, reduced, and read back. *)
  let source =
    "attribute cost = 1 split\nsynth text on Q\nsynth answer_value on Q\nsynth rank on Q\nsynth shape on Q\nstart Q\n\
     Q -> integer_between(-4, 4) integer_between(-4, 4) nonzero_integer_between(-3, 3) {\n\
    \  cost = -1\n\
    \  let a = matrix_stack(matrix_row(vector2(1, $3.value)), matrix_row(vector2(2, 2 * $3.value + 1)))\n\
    \  let system = matrix_augment(a, matrix_column(matrix_vector(a, vector2($1.value, $2.value))))\n\
    \  text = matrix_latex(system)\n\
    \  rank = matrix_rank(system)\n\
    \  shape = matrix_rows(system) * 10 + matrix_columns(system)\n\
    \  answer_value = matrix_rref(system)\n\
     }\n"
    ^ footer
  in
  match expect_ok "matrix_shape_test.rhm" source with
  | None -> ()
  | Some spec ->
      List.iter
        (fun (q : Rhema_engine.question) ->
          let whole name =
            match Rhema_engine.attribute q.Rhema_engine.tree name with
            | Rhema_engine.Num n -> Rhema_number.require_integer name n
            | other -> fail (name ^ " is " ^ Rhema_engine.describe_value other); 0
          in
          check "the rank of a system with one solution" (whole "rank" = 2);
          check "the shape of an augmented matrix" (whole "shape" = 23);
          match q.Rhema_engine.answer with
          | Rhema_engine.Matrix reduced ->
              (* [I | x]: the last column is the solution the system was built from *)
              check "the reduced system is not [I | x]"
                (Rhema_number.equal (Rhema_matrix.entry reduced 1 1) (number 1)
                && Rhema_number.is_zero (Rhema_matrix.entry reduced 1 2)
                && Rhema_number.is_zero (Rhema_matrix.entry reduced 2 1)
                && Rhema_number.equal (Rhema_matrix.entry reduced 2 2) (number 1));
              let x = Rhema_matrix.entry reduced 1 3 and y = Rhema_matrix.entry reduced 2 3 in
              let integers text =
                let found = ref [] and re = Str.regexp "-?[0-9]+" in
                let rec go start =
                  match Str.search_forward re text start with
                  | exception Not_found -> ()
                  | i ->
                      found := int_of_string (Str.matched_string text) :: !found;
                      go (i + String.length (Str.matched_string text))
                in
                go 0;
                List.rev !found
              in
              (match integers q.Rhema_engine.prompt with
              | [ a11; a12; b1; a21; a22; b2 ] ->
                  let at a b = Rhema_number.add (Rhema_number.multiply (number a) x) (Rhema_number.multiply (number b) y) in
                  check "the solution read from the reduced form does not solve the printed system"
                    (Rhema_number.equal (at a11 a12) (number b1) && Rhema_number.equal (at a21 a22) (number b2))
              | _ -> fail ("unexpected matrix in the prompt: " ^ q.Rhema_engine.prompt))
          | other -> fail ("not a matrix: " ^ Rhema_engine.describe_value other))
        (questions spec 40)

(* ------------------------------------------------------------------ *)
(* 5. Answer blanks in text                                             *)
(* ------------------------------------------------------------------ *)

let generation_error spec =
  Random.init 3;
  match Rhema_engine.generate spec with
  | exception Rhema_engine.Generation_error message -> Some message
  | _ -> None

let expect_generation_error name content ~mentions =
  match expect_ok name content with
  | None -> ()
  | Some spec -> (
      match generation_error spec with
      | Some message ->
          if not (contains message mentions) then
            fail (Printf.sprintf "%s: the error does not mention %S: %s" name mentions message)
      | None -> fail (Printf.sprintf "%s generated a question although %s" name mentions))

let blanks_header = "attribute cost = 2 split\nsynth kind on Q\nsynth text on Q\nstart Q\n"

let blanks_grammar =
  blanks_header
  ^ "Q -> \"circle\" nonzero_integer_between(-9, 9) nonzero_integer_between(-9, 9) integer_between(1, 9) when cost = 2 {\n\
    \  cost = -2\n\
    \  kind = \"circle\"\n\
    \  text = \"Centre \" ++ blank(point2($2.value, $3.value)) ++ \", radius \" ++ blank_wide($4.value, 4)\n\
    \         ++ \", area over [`\\pi`] \" ++ blank($4.value ^ 2) ++ \".\"\n\
     }\n\
     Q -> \"double\" integer_between(1, 9) when cost = 1 {\n\
    \  cost = -1\n\
    \  kind = \"double\"\n\
    \  text = \"Twice [`\" ++ str($2.value) ++ \"`] is \" ++ blank(2 * $2.value)\n\
     }\n\
     prompt \"Q: {Q.text}\"\n"

let () =
  (match expect_ok "blanks_test.rhm" blanks_grammar with
  | None -> ()
  | Some base ->
      List.iter
        (fun (cost, kind, blanks) ->
          let spec = match Rhema_check.with_initial base "cost" cost with Ok s -> s | Error m -> fail m; base in
          List.iter
            (fun (q : Rhema_engine.question) ->
              (match Rhema_engine.attribute q.Rhema_engine.tree "kind" with
              | Rhema_engine.Text k -> check "the wrong form for its price" (k = kind)
              | _ -> fail "no kind");
              check (kind ^ ": the number of blanks") (List.length q.Rhema_engine.answers = blanks);
              check (kind ^ ": the listing shows each blank")
                (List.length (Str.split_delim (Str.regexp_string "[___]") q.Rhema_engine.prompt) = blanks + 1);
              check (kind ^ ": the prompt's own text is kept") (contains q.Rhema_engine.prompt "Q: ");
              let pg = Rhema_pgml.document [ q ] in
              check (kind ^ ": one PG blank per answer")
                (List.length (Str.split_delim (Str.regexp_string "[_____]{") pg) = blanks + 1);
              if kind = "circle" then begin
                (match q.Rhema_engine.answers with
                | [ Rhema_engine.Point [ _; _ ]; Rhema_engine.Num radius; Rhema_engine.Num square ] ->
                    check "the blanks are not in the order written"
                      (Rhema_number.equal square (Rhema_number.multiply radius radius));
                    check "a blank's own width is not written"
                      (contains pg (Printf.sprintf "[_____]{answer=>%s,width=>4}" (Rhema_number.to_string radius)));
                    check "a plain blank was given a width"
                      (contains pg (Printf.sprintf "[_____]{%s}" (Rhema_number.to_string square)))
                | _ -> fail ("unexpected answers: " ^ q.Rhema_engine.answer_text));
                (* The question's width applies to the blanks without one of their own. *)
                let wide = Rhema_pgml.document ~width:12 [ q ] in
                check "the document's width did not reach a plain blank" (contains wide ",width=>12}");
                check "the document's width replaced a blank's own" (contains wide ",width=>4}")
              end)
            (questions spec 25))
        [ (2, "circle", 3); (1, "double", 1) ]);
  (* Where the blanks may come from, and where they may not be. *)
  expect_error "no_blank_test.rhm"
    (blanks_header ^ "Q -> integer_between(1, 9) {\n  cost = -1\n  kind = \"k\"\n  text = \"x\"\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"'answer ...' declaration is required";
  expect_generation_error "blank_unused_test.rhm"
    (blanks_header
   ^ "let spare = blank(1)\nQ -> integer_between(1, 9) {\n  cost = -2\n  kind = \"k\"\n  text = \"x\"\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"no answer blank";
  expect_generation_error "blank_and_answer_test.rhm"
    (blanks_header
   ^ "Q -> integer_between(1, 9) {\n  cost = -2\n  kind = \"k\"\n  text = \"x \" ++ blank(1)\n}\nprompt \"{Q.text}\"\nanswer 2\n")
    ~mentions:"'answer' line and answer blanks";
  expect_generation_error "blank_in_math_test.rhm"
    (blanks_header
   ^ "Q -> integer_between(1, 9) {\n  cost = -2\n  kind = \"k\"\n  text = \"[`x = \" ++ blank(1) ++ \"`]\"\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"inside mathematics";
  expect_generation_error "blank_as_text_test.rhm"
    (blanks_header
   ^ "Q -> integer_between(1, 9) {\n  cost = -2\n  kind = str(blank(1))\n  text = \"x\"\n}\nprompt \"{Q.text}\"\nanswer 1\n")
    ~mentions:"holds an answer blank";
  expect_generation_error "blank_of_blank_test.rhm"
    (blanks_header
   ^ "Q -> integer_between(1, 9) {\n  cost = -2\n  kind = \"k\"\n  text = blank(blank(1))\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"cannot be graded against text";
  expect_generation_error "blank_width_test.rhm"
    (blanks_header
   ^ "Q -> integer_between(1, 9) {\n  cost = -2\n  kind = \"k\"\n  text = blank_wide(1, 0)\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"not between 1 and 200";
  (* A let may hold the blank, and a module's text brings its blanks to the
     file that imports it, which then needs no answer line of its own. *)
  (match
     expect_ok "blank_let_test.rhm"
       ("attribute cost = 1 split\nsynth text on Q\nrandom n = integer_between(1, 9)\nlet ask = \"n + 1 = \" ++ blank(n + 1)\n\
         start Q\nQ -> integer_between(1, 9) {\n  cost = -1\n  text = \"given\"\n}\nprompt \"{Q.text}: {ask}\"\n")
   with
  | None -> ()
  | Some spec ->
      List.iter
        (fun (q : Rhema_engine.question) -> check "a let's blank did not reach the question" (List.length q.Rhema_engine.answers = 1))
        (questions spec 5));
  let channel = open_out "blank_module_test.rhm" in
  output_string channel blanks_grammar;
  close_out channel;
  (match
     expect_ok "blank_importer_test.rhm"
       ("import \"blank_module_test.rhm\" as m\nattribute cost = 2 split\nsynth text on T\nstart T\n\
         T -> m.Q(cost = cost) {\n  cost = 0\n  text = \"Imported. \" ++ $1.text\n}\nprompt \"{T.text}\"\n")
   with
  | None -> ()
  | Some spec ->
      List.iter
        (fun (q : Rhema_engine.question) ->
          check "a module's blanks did not reach the importing question" (List.length q.Rhema_engine.answers = 3);
          check "the importer's text is missing" (contains q.Rhema_engine.prompt "Imported. Centre [___]"))
        (questions spec 5));
  Sys.remove "blank_module_test.rhm"

(* ------------------------------------------------------------------ *)
(* 6. Formula answers in any variables                                  *)
(* ------------------------------------------------------------------ *)

let own_numeric = "do { my $c = Parser::Context->getCopy(\"Numeric\"); "

let () =
  let source =
    "attribute cost = 1 split\nsynth text on Q\nstart Q\n\
     let x = formula_variable(\"x\")\nlet y = formula_variable(\"y\")\nlet t = formula_variable(\"t\")\n\
     Q -> integer_between(2, 5) integer_between(1, 4) {\n\
    \  cost = -1\n\
    \  let f = formula_add(formula_multiply(formula_constant($1.value), formula_multiply(formula_power(x, 2), y)),\n\
    \                      formula_multiply(formula_constant($2.value), formula_power(y, 3)))\n\
    \  let at = formula_substitute(formula_substitute(differentiate(f, \"x\"), \"x\", formula_constant(1)), \"y\", formula_constant(2))\n\
    \  text = \"a \" ++ blank(differentiate(f, \"x\")) ++ \" b \" ++ blank(differentiate(differentiate(f, \"x\"), \"y\"))\n\
    \         ++ \" c \" ++ blank(formula_value(at)) ++ \" d \" ++ blank(formula_value(formula_power(formula_constant(2 / 3), 2)))\n\
     }\n\
     prompt \"{Q.text}\"\n\
     question one_variable {\n  start S\n  prompt \"{S.text}\"\n}\n\
     question in_t {\n  start U\n  prompt \"{U.text}\"\n}\n\
     synth text on S\nsynth text on U\n\
     S -> integer_between(2, 5) {\n  cost = -1\n  text = \"s \" ++ blank(formula_multiply(formula_constant($1.value), formula_sin(x)))\n}\n\
     U -> integer_between(2, 5) {\n  cost = -1\n  text = \"u \" ++ blank(formula_multiply(formula_constant($1.value), formula_exp(t)))\n}\n"
  in
  let named name spec = match Rhema_check.select_question spec name with Ok s -> Some s | Error m -> fail m; None in
  match expect_ok "variables_test.rhm" source with
  | None -> ()
  | Some spec ->
      List.iter
        (fun (q : Rhema_engine.question) ->
          let pg = Rhema_pgml.document [ q ] in
          (match q.Rhema_engine.answers with
          | [ Rhema_engine.Formula fx; Rhema_engine.Formula fxy; Rhema_engine.Num value; Rhema_engine.Num square ] ->
              check "a partial derivative lost a variable" (Rhema_formula.variables fx = [ "x"; "y" ]);
              (* f_xy = 2 a x holds x alone, but is written with the variables
                 of the whole question, so every blank accepts the same names. *)
              check "the mixed derivative should hold x alone" (Rhema_formula.variables fxy = [ "x" ]);
              let declared = own_numeric ^ "$c->variables->are(x=>\"Real\",y=>\"Real\"); Formula($c,\"" in
              check "a two-variable answer is not written with its variables"
                (contains pg (declared ^ Rhema_formula.to_pg fx ^ "\") }"));
              check "the blanks of one question do not share their variables"
                (contains pg (declared ^ Rhema_formula.to_pg fxy ^ "\") }"));
              (* f_x(1, 2) = 4a, computed exactly; (2/3)^2 = 4/9 *)
              check "formula_value at a point"
                (Float.abs
                   (Rhema_number.to_float value
                   -. Rhema_formula.evaluate_with (function "x" -> Some 1. | "y" -> Some 2. | _ -> None) fx)
                < 1e-9);
              check "formula_value of a power of a fraction" (Rhema_number.equal square (Rhema_number.make 4 9))
          | _ -> fail ("unexpected answers: " ^ q.Rhema_engine.answer_text));
          check "a number was given a context of its own" (not (contains pg "Formula($c,\"4/9\")")))
        (questions spec 20);
      (match named "one_variable" spec with
      | None -> ()
      | Some spec ->
          List.iter
            (fun (q : Rhema_engine.question) ->
              let pg = Rhema_pgml.document [ q ] in
              check "a formula in x alone is no longer written as before"
                (contains pg "[_____]{Formula('" && not (contains pg own_numeric)))
            (questions spec 5));
      (match named "in_t" spec with
      | None -> ()
      | Some spec ->
          List.iter
            (fun (q : Rhema_engine.question) ->
              check "a formula in t does not declare t alone"
                (contains (Rhema_pgml.document [ q ]) (own_numeric ^ "$c->variables->are(t=>\"Real\"); Formula($c,\"")))
            (questions spec 5));
      expect_generation_error "formula_value_test.rhm"
        ("attribute cost = 1 split\nsynth text on Q\nstart Q\nQ -> integer_between(2, 5) {\n  cost = -1\n\
         \  text = str(formula_value(formula_multiply(formula_constant($1.value), formula_pi())))\n}\nprompt \"{Q.text}\"\nanswer 1\n")
        ~mentions:"not a rational number"

(* The variables may be declared: for a whole file by a let, or for each
   question by the start symbol. An answer that holds y alone, or only a
   number of x, is then written with every declared name. *)
let () =
  let body declare_let declare_attribute =
    "attribute cost = 1 split\nsynth text on Q\n" ^ (if declare_attribute then "synth pg_variables on Q\n" else "")
    ^ "start Q\nlet y = formula_variable(\"y\")\n" ^ (if declare_let then "let pg_variables = \"x, y\"\n" else "")
    ^ "Q -> integer_between(2, 5) {\n  cost = -1\n"
    ^ (if declare_attribute then "  pg_variables = \"t y\"\n" else "")
    ^ "  text = \"a \" ++ blank(formula_multiply(formula_constant($1.value), y)) ++ \" b \" ++ blank(formula_constant($1.value))\n}\n\
       prompt \"{Q.text}\"\n"
  in
  List.iter
    (fun (name, declare_let, declare_attribute, expected) ->
      match expect_ok name (body declare_let declare_attribute) with
      | None -> ()
      | Some spec ->
          List.iter
            (fun (q : Rhema_engine.question) ->
              let pg = Rhema_pgml.document [ q ] in
              let wanted = own_numeric ^ "$c->variables->are(" ^ expected ^ "); Formula($c,\"" in
              if not (contains pg wanted) then fail (Printf.sprintf "%s: the answer is not written with %s:\n%s" name expected pg);
              (* the constant formula is a formula answer too, and gets the same names *)
              check (name ^ ": both formula answers share the declared variables")
                (List.length (Str.split_delim (Str.regexp_string wanted) pg) = 3))
            (questions spec 5))
    [ ("variables_none_test.rhm", false, false, "y=>\"Real\"");
      ("variables_let_test.rhm", true, false, "x=>\"Real\",y=>\"Real\"");
      ("variables_attribute_test.rhm", false, true, "t=>\"Real\",y=>\"Real\"");
      (* the start symbol's own declaration wins over the file's *)
      ("variables_both_test.rhm", true, true, "t=>\"Real\",y=>\"Real\"") ];
  expect_generation_error "variables_name_test.rhm"
    ("attribute cost = 1 split\nsynth text on Q\nstart Q\nlet pg_variables = \"x 2y\"\nQ -> integer_between(2, 5) {\n  cost = -1\n  text = \"a \" ++ blank($1.value)\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"pg_variables"

(* ------------------------------------------------------------------ *)
(* 7. Pi, exact values and answers that must be worked out              *)
(* ------------------------------------------------------------------ *)

let () =
  let open Rhema_formula in
  let value formula = evaluate_with (fun _ -> None) formula in
  let close a b = Float.abs (a -. b) < 1e-12 in
  (* Every angle with a known value, over three turns in both directions. *)
  List.iter
    (fun q ->
      for p = -3 * q to 3 * q do
        let angle = float p *. Float.pi /. float q in
        let label name = Printf.sprintf "%s(%d pi / %d)" name p q in
        check (label "sin") (close (value (exact_value Sine ~numerator:p ~denominator:q)) (Stdlib.sin angle));
        check (label "cos") (close (value (exact_value Cosine ~numerator:p ~denominator:q)) (Stdlib.cos angle));
        if Float.abs (Stdlib.cos angle) > 1e-9 then
          check (label "tan") (close (value (exact_value Tangent ~numerator:p ~denominator:q)) (Stdlib.tan angle))
        else
          match exact_value Tangent ~numerator:p ~denominator:q with
          | exception Invalid_argument _ -> ()
          | _ -> fail (label "tan" ^ " was given a value")
      done)
    [ 1; 2; 3; 4; 6 ];
  (* An angle is reduced first; others have no closed form here. *)
  check "an angle that reduces" (exact_value Sine ~numerator:2 ~denominator:12 = exact_value Sine ~numerator:1 ~denominator:6);
  check "a negative denominator" (exact_value Sine ~numerator:1 ~denominator:(-6) = exact_value Sine ~numerator:(-1) ~denominator:6);
  List.iter
    (fun (p, q) ->
      match exact_value Sine ~numerator:p ~denominator:q with
      | exception Invalid_argument _ -> ()
      | _ -> fail (Printf.sprintf "sin(%d pi / %d) was given an exact value" p q))
    [ (1, 5); (1, 12); (1, 8); (1, 0) ];
  (* The values are written as a first course writes them. *)
  check "sin(pi/3) for WeBWorK" (to_pg (exact_value Sine ~numerator:1 ~denominator:3) = "sqrt(3)/2");
  check "cos(3pi/4) for WeBWorK" (to_pg (exact_value Cosine ~numerator:3 ~denominator:4) = "-(sqrt(2)/2)");
  check "tan(pi/6) in LaTeX" (to_latex (exact_value Tangent ~numerator:1 ~denominator:6) = "\\frac{\\sqrt{3}}{3}");
  check "sin(pi/6) is a number" (rational_value (exact_value Sine ~numerator:1 ~denominator:6) = Some (Rhema_number.make 1 2));
  check "sin(pi/3) is not rational" (rational_value (exact_value Sine ~numerator:1 ~denominator:3) = None);
  (* Pi and its multiples. *)
  let times n d = multiply (constant (Rhema_number.make n d)) Pi in
  List.iter
    (fun (n, d, latex, pg) ->
      check (Printf.sprintf "%d pi / %d in LaTeX: %s" n d (to_latex (times n d))) (to_latex (times n d) = latex);
      check (Printf.sprintf "%d pi / %d for WeBWorK: %s" n d (to_pg (times n d))) (to_pg (times n d) = pg);
      check (Printf.sprintf "%d pi / %d as a number" n d) (close (value (times n d)) (float n *. Float.pi /. float d)))
    [ (1, 1, "\\pi", "pi"); (2, 1, "2\\pi", "2*pi"); (5, 6, "\\frac{5\\pi}{6}", "5/6*pi");
      (1, 4, "\\frac{\\pi}{4}", "1/4*pi"); (-1, 4, "-\\frac{\\pi}{4}", "-(1/4*pi)"); (-3, 1, "-3\\pi", "-(3*pi)") ];
  check "pi does not depend on x" (differentiate ~variable:"x" (multiply Pi (variable "x")) = Pi);
  check "pi holds no variable" (variables (add Pi (variable "x")) = [ "x" ]);
  check "pi is not rational" (rational_value Pi = None);
  (* A fraction is a quotient: as a divisor or under a power it is bracketed. *)
  let two_thirds = constant (Rhema_number.make 2 3) in
  check "x divided by a fraction" (to_pg (divide (variable "x") two_thirds) = "x/(2/3)");
  check "a power of a fraction" (to_pg (power two_thirds 2) = "(2/3)^2");
  check "a fraction times x is written as before" (to_pg (multiply two_thirds (variable "x")) = "2/3*x");
  check "x plus a fraction is written as before" (to_pg (add (variable "x") two_thirds) = "x+2/3");
  check "the value of a power of a fraction" (rational_value (power two_thirds 2) = Some (Rhema_number.make 4 9));
  check "a root that comes out" (rational_value (Sqrt (constant (Rhema_number.make 9 4))) = Some (Rhema_number.make 3 2));
  check "a division by zero has no value" (rational_value (Divide (one, zero)) = None)

let () =
  let disabled = "$c->functions->disable(\"Trig\",\"Hyperbolic\",\"Numeric\"); $c->functions->enable(\"sqrt\",\"abs\"); " in
  let source =
    "attribute cost = 1 split\nsynth text on Q\nstart Q\n\
     Q -> integer_between(0, 11) integer_between(2, 5) {\n\
    \  cost = -1\n\
    \  let angle = formula_multiply(formula_constant($1.value / 6), formula_pi())\n\
    \  text = \"[`\\sin\\left(\" ++ formula_latex(angle) ++ \"\\right) = `] \" ++ blank(plain(exact_sin($1.value, 6)))\n\
    \         ++ \" log \" ++ blank(plain($2.value)) ++ \" angle \" ++ blank(angle)\n\
     }\n\
     prompt \"{Q.text}\"\n"
  in
  (match expect_ok "plain_test.rhm" source with
  | None -> ()
  | Some spec ->
      List.iter
        (fun (q : Rhema_engine.question) ->
          let pg = Rhema_pgml.document [ q ] in
          match q.Rhema_engine.answers with
          | [ Rhema_engine.Plain (Rhema_engine.Formula sine); Rhema_engine.Plain (Rhema_engine.Num whole); Rhema_engine.Formula angle ] ->
              check "an exact value is not written with the functions off"
                (contains pg (own_numeric ^ disabled ^ "Formula($c,\"" ^ Rhema_formula.to_pg sine ^ "\") }"));
              check "a whole number under plain is not written with the functions off"
                (contains pg (own_numeric ^ disabled ^ "Formula($c,\"" ^ Rhema_number.to_string whole ^ "\") }"));
              check "an angle is written with a context of its own"
                (contains pg ("[_____]{Formula('" ^ Rhema_formula.to_pg angle ^ "')}")
                || contains pg ("[_____]{" ^ Rhema_formula.to_pg angle ^ "}"));
              check "the listing shows the value, not the wrapper"
                (not (contains q.Rhema_engine.answer_text "Plain"))
          | _ -> fail ("unexpected answers: " ^ q.Rhema_engine.answer_text))
        (questions spec 30));
  (* A whole number graded exactly: half a unit of absolute tolerance, so
     that no other whole number passes. Below 1000 only exactly() asks for
     it; from 1000 up every whole number is written that way, because
     WeBWorK's usual tolerance would accept its neighbours. *)
  List.iter
    (fun (name, low, high, ordinary_is_exact) ->
      match
        expect_ok name
          (Printf.sprintf
             "attribute cost = 1 split\nsynth text on Q\nstart Q\nQ -> integer_between(%d, %d) {\n  cost = -1\n  text = \"a \" ++ blank(exactly($1.value)) ++ \" b \" ++ blank($1.value)\n}\nprompt \"{Q.text}\"\n"
             low high)
      with
      | None -> ()
      | Some spec ->
          List.iter
            (fun (q : Rhema_engine.question) ->
              match q.Rhema_engine.answers with
              | [ Rhema_engine.Exactly n; Rhema_engine.Num same ] ->
                  let pg = Rhema_pgml.document [ q ] and digits = Rhema_number.to_string n in
                  let exact = "[_____]{Real(" ^ digits ^ ")->cmp(tolType=>\"absolute\",tolerance=>0.5)}" in
                  check "exactly changed the number" (Rhema_number.equal n same);
                  check "an exact answer is not written with an absolute tolerance" (contains pg ("a " ^ exact));
                  check
                    (if ordinary_is_exact then "a whole number of four digits is not graded exactly"
                     else "a small whole number is no longer written bare")
                    (contains pg (" b " ^ if ordinary_is_exact then exact else "[_____]{" ^ digits ^ "}"));
                  check "the listing shows the number" (q.Rhema_engine.answer_text = digits ^ "; " ^ digits)
              | _ -> fail ("unexpected answers: " ^ q.Rhema_engine.answer_text))
            (questions spec 10))
    [ ("exactly_small_test.rhm", 2, 999, false); ("exactly_large_test.rhm", 1000, 99999, true) ];
  expect_generation_error "exactly_fraction_test.rhm"
    ("attribute cost = 1 split\nsynth text on Q\nstart Q\nQ -> integer_between(2, 5) {\n  cost = -1\n  text = \"x \" ++ blank(exactly(1 / $1.value))\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"exactly expected a whole number";
  expect_generation_error "plain_text_test.rhm"
    ("attribute cost = 1 split\nsynth text on Q\nstart Q\nQ -> integer_between(2, 5) {\n  cost = -1\n  text = \"x \" ++ blank(plain(\"text\"))\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"plain expected a number or a formula";
  expect_generation_error "exact_angle_test.rhm"
    ("attribute cost = 1 split\nsynth text on Q\nstart Q\nQ -> integer_between(2, 5) {\n  cost = -1\n  text = \"x \" ++ blank(exact_sin(1, 5))\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"exact_sin: no exact value";
  expect_generation_error "exact_tangent_test.rhm"
    ("attribute cost = 1 split\nsynth text on Q\nstart Q\nQ -> integer_between(2, 5) {\n  cost = -1\n  text = \"x \" ++ blank(exact_tan(1, 2))\n}\nprompt \"{Q.text}\"\n")
    ~mentions:"exact_tan: the tangent of 1 pi / 2 is not defined"

(* ------------------------------------------------------------------ *)
(* 9. Proposition answers carry a Boolean context of their own          *)
(* ------------------------------------------------------------------ *)

(* contextBoolean.pl knows p and q alone: an answer in r written in the
   plain Boolean context cannot be read by WeBWorK. Each proposition answer
   declares its variables in a copy of that context instead, and the
   document loads the macro file for it whatever context it is in. *)
let () =
  let own names text =
    Printf.sprintf "do { my $c = Parser::Context->getCopy(\"Boolean\"); $c->variables->are(%s); Formula($c,\"%s\") }"
      (String.concat "," (List.map (fun name -> name ^ "=>\"Boolean\"") names))
      text
  in
  let macro = "\"contextBoolean.pl\"" in
  let body ?(declared = "") text =
    "attribute cost = 1 split\nsynth text on Q\nstart Q\n" ^ declared
    ^ "Q -> integer_between(2, 5) {\n  cost = -1\n  text = " ^ text ^ "\n}\nprompt \"{Q.text}\"\n"
  in
  let implication = "bool_or(bool_not(bool_var(\"p\")), bool_var(\"r\"))" in
  List.iter
    (fun (name, source, expected) ->
      match expect_ok name source with
      | None -> ()
      | Some spec ->
          List.iter
            (fun (q : Rhema_engine.question) ->
              let pg = Rhema_pgml.document [ q ] in
              List.iter
                (fun wanted ->
                  if not (contains pg ("[_____]{" ^ wanted ^ "}")) then
                    fail (Printf.sprintf "%s: no answer written as %s:\n%s" name wanted pg))
                expected;
              check (name ^ ": the document does not load contextBoolean.pl") (contains pg macro);
              check (name ^ ": the question's own context was changed") (contains pg "Context(\"Numeric\");");
              check (name ^ ": a proposition is still written in the context in force") (not (contains pg "Compute(")))
            (questions spec 5))
    [ (* a variable beyond p and q, in a question that sets no context *)
      ("proposition_r_test.rhm", body ("\"a \" ++ blank(" ^ implication ^ ")"), [ own [ "p"; "r" ] "(not (p)) or (r)" ]);
      (* the names a grammar declares are propositional variables too *)
      ( "proposition_declared_test.rhm",
        body ~declared:"let pg_variables = \"p q r s\"\n" ("\"a \" ++ blank(" ^ implication ^ ")"),
        [ own [ "p"; "q"; "r"; "s" ] "(not (p)) or (r)" ] );
      (* two blanks accept the same names *)
      ( "proposition_shared_test.rhm",
        body ("\"a \" ++ blank(bool_var(\"q\")) ++ \" b \" ++ blank(" ^ implication ^ ")"),
        [ own [ "p"; "q"; "r" ] "q"; own [ "p"; "q"; "r" ] "(not (p)) or (r)" ] );
      (* beside a formula answer, each kind keeps its own variables *)
      ( "proposition_mixed_test.rhm",
        body ("\"a \" ++ blank(bool_var(\"q\")) ++ \" b \" ++ blank(formula_variable(\"t\"))"),
        [ own [ "q" ] "q"; own_numeric ^ "$c->variables->are(t=>\"Real\"); Formula($c,\"t\") }" ] ) ];
  (* a document without a proposition answer loads nothing more *)
  match expect_ok "proposition_none_test.rhm" (body "\"a \" ++ blank($1.value)") with
  | None -> ()
  | Some spec ->
      List.iter
        (fun q -> check "contextBoolean.pl is loaded without a proposition" (not (contains (Rhema_pgml.document [ q ]) macro)))
        (questions spec 3)

let () =
  if !failures = 0 then print_endline "Rhema language additions tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d language additions test(s) failed." !failures);
    exit 1
  end
