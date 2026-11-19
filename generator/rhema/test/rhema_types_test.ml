(* Checks for static types.

   `rhema check` infers the types every expression can have and reports a
   use that no such type allows. Three things are held here:

     1. The table of builtin types (Rhema_types) against the engine. Every
        function that takes values is called with every type in each of its
        arguments, the others being right: the checker refuses the call
        exactly when the table does, the engine never accepts what the table
        refuses, never refuses for its type what the table allows, and a
        call that succeeds gives a type the table lists. infix and prefix,
        which take children, and the functions without arguments are tried
        separately. Every operator is tried with every type, and every pair
        of types, where the checker's verdict must be the engine's.
     2. What the checker infers against what generation produces: over the
        whole library, every synthesized attribute of every node built by a
        rule, and every random and let of the file, has in every generated
        question one of the types inferred for it.
     3. The checker itself, on small grammars written here: what it reports,
        where, in which words, and what it leaves alone. *)

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

(* ------------------------------------------------------------------ *)
(* 1. The table against the engine                                      *)
(* ------------------------------------------------------------------ *)

open Rhema_ast

let call name arguments = Call (name, arguments)

(* An expression of each type, built from literals. *)
let sample (ty : Rhema_types.ty) =
  let x = call "formula_variable" [ Str "x" ] and v = call "vector3" [ Int 1; Int 2; Int 3 ] in
  match ty with
  | Number -> Int 2
  | Text -> Str "x"
  | Truth -> Bool true
  | Complex -> call "complex" [ Int 1; Int 2 ]
  | Formula -> x
  | Polynomial -> call "polynomial_variable" [ Str "x" ]
  | Equation -> call "equation" [ x; call "formula_constant" [ Int 2 ] ]
  | Proposition -> call "bool_var" [ Str "p" ]
  | Matrix -> call "matrix_identity" [ Int 2 ]
  | Set -> call "set_empty" []
  | Vector -> v
  | Point -> call "point2" [ Int 1; Int 2 ]
  | Norm_answer -> call "vector_norm_answer" [ v ]
  | Unit_answer -> call "vector_unit_answer" [ v ]
  | Direction_answer -> call "vector_parallel_answer" [ v ]
  | Blanked -> call "blank" [ Int 2 ]
  | Exactly -> call "exactly" [ Int 2 ]
  | Plain -> call "plain" [ Int 2 ]

type outcome = Value of Rhema_types.ty | Refused of string

let run expression =
  match
    Rhema_engine.evaluate ~globals:[]
      ~is_inherited:(fun _ -> false)
      ~rule_precedence:(fun _ -> None)
      ~environment:[] ~children:[] ~rule:None ~target:"" expression
  with
  | value -> Value (Rhema_engine.value_type value)
  | exception Rhema_engine.Generation_error message -> Refused message
  | exception Rhema_number.Arithmetic_error message -> Refused message
  (* A few builtins let a library's complaint about a value through as it
     is, such as a variable named "2". *)
  | exception Invalid_argument message -> Refused message

(* A refusal because of a type, as the engine words it; any other refusal
   is about the value (a matrix of the wrong shape, a base out of range). *)
let about_type message = contains message "expected" || contains message "cannot"

(* What the checker says of an expression that sees nothing around it. *)
let nothing : Rhema_check.type_scope =
  { here = (fun _ -> None); child = (fun _ _ -> None); named = (fun _ _ -> None); target = "" }

let statically expression =
  let reports = ref [] in
  let inferred =
    Rhema_check.infer_type
      ~report:(fun _ message -> reports := message :: !reports)
      ~position:dummy_position nothing expression
  in
  (inferred, List.rev !reports)

let () =
  List.iter
    (fun ty ->
      (match run (sample ty) with
      | Value actual -> check ("the sample of " ^ Rhema_types.name ty ^ " has another type") (actual = ty)
      | Refused message -> fail ("the sample of " ^ Rhema_types.name ty ^ " failed: " ^ message));
      let inferred, reports = statically (sample ty) in
      check
        ("the sample of " ^ Rhema_types.name ty ^ " is inferred as " ^ Rhema_types.describe inferred)
        (inferred = [ ty ] && reports = []))
    Rhema_types.all

(* Every builtin, every argument, every type. *)
let () =
  let calls = ref 0 in
  List.iter
    (fun (entry : Rhema_types.signature) ->
      let has_node = List.mem Rhema_types.Node entry.parameters in
      if not has_node then begin
        let good =
          List.map
            (function
              | Rhema_types.Takes (first :: _) -> sample first
              | Rhema_types.Takes [] | Rhema_types.Node -> Int 2)
            entry.parameters
        in
        let with_argument position argument =
          call entry.builtin (List.mapi (fun index other -> if index = position then argument else other) good)
        in
        List.iteri
          (fun position parameter ->
            match parameter with
            | Rhema_types.Node -> ()
            | Rhema_types.Takes accepted ->
                List.iter
                  (fun ty ->
                    incr calls;
                    let label =
                      Printf.sprintf "%s, argument %d, given %s" entry.builtin (position + 1)
                        (Rhema_types.name ty)
                    in
                    let expression = with_argument position (sample ty) in
                    let _, reports = statically expression in
                    let allowed = List.mem ty accepted in
                    check (label ^ ": the checker and the table disagree")
                      ((reports = []) = allowed);
                    match run expression with
                    | Refused message ->
                        if allowed then
                          check
                            (label ^ ": the table allows it, the engine refuses the type: " ^ message)
                            (not (about_type message))
                    | Value result ->
                        check (label ^ ": the table refuses it, the engine accepts it") allowed;
                        check
                          (Printf.sprintf "%s: gave %s, which the table does not list" label
                             (Rhema_types.name result))
                          (match entry.result with
                          | Rhema_types.Gives results -> List.mem result results
                          | Rhema_types.Either -> true))
                  Rhema_types.all)
          entry.parameters
      end)
    Rhema_types.builtins;
  check "the functions were called with every type in every argument" (!calls > 4000)

(* The functions without arguments give what the table says. *)
let () =
  let tried = ref 0 in
  List.iter
    (fun (entry : Rhema_types.signature) ->
      if entry.parameters = [] then begin
        incr tried;
        let expression = call entry.builtin [] in
        let inferred, reports = statically expression in
        match run expression with
        | Value result ->
            check (entry.builtin ^ "() has another type than the table gives")
              (inferred = [ result ] && reports = [])
        | Refused message -> fail (entry.builtin ^ "() failed: " ^ message)
      end)
    Rhema_types.builtins;
  check "the functions without arguments were tried" (!tried >= 4)

(* infix and prefix take children. A child here is a leaf carrying one
   attribute, `latex`, of each type in turn; the operator text is of each
   type in turn. The engine writes both as text, and so must the table. *)
let () =
  let value_of ty =
    Rhema_engine.evaluate ~globals:[]
      ~is_inherited:(fun _ -> false)
      ~rule_precedence:(fun _ -> None)
      ~environment:[] ~children:[] ~rule:None ~target:"" (sample ty)
  in
  let leaf ty : Rhema_engine.node =
    {
      symbol = "leaf";
      applied_rule = None;
      children = [];
      inherited_attributes = [];
      attributes = [ ("latex", value_of ty) ];
      level = Rhema_engine.atom_level;
    }
  in
  let engine children expression =
    match
      Rhema_engine.evaluate ~globals:[]
        ~is_inherited:(fun _ -> false)
        ~rule_precedence:(fun _ -> None)
        ~environment:[] ~children ~rule:None ~target:"latex" expression
    with
    | value -> Value (Rhema_engine.value_type value)
    | exception Rhema_engine.Generation_error message -> Refused message
  in
  let checker child_types expression =
    let reports = ref [] in
    let scope : Rhema_check.type_scope =
      {
        here = (fun _ -> None);
        child = (fun index name -> if name = "latex" then List.nth_opt child_types (index - 1) else None);
        named = (fun _ _ -> None);
        target = "latex";
      }
    in
    let inferred =
      Rhema_check.infer_type
        ~report:(fun _ message -> reports := message :: !reports)
        ~position:dummy_position scope expression
    in
    (inferred, !reports)
  in
  let agree label children child_types expression =
    let inferred, reports = checker child_types expression in
    match engine children expression with
    | Refused message ->
        check (label ^ ": the engine refuses, the checker does not: " ^ message) (reports <> [])
    | Value result ->
        check (label ^ ": the checker refuses, the engine does not") (reports = []);
        check (label ^ ": the result is not the one the table gives") (inferred = [ result ])
  in
  List.iter
    (fun ty ->
      let name = Rhema_types.name ty in
      let text = leaf Rhema_types.Text in
      (* the child's attribute, on either side *)
      agree ("infix, left child " ^ name) [ leaf ty; text; text ] [ [ ty ]; [ Text ]; [ Text ] ]
        (call "infix" [ Child 1; Str "+"; Child 3 ]);
      agree ("infix, right child " ^ name) [ text; text; leaf ty ] [ [ Text ]; [ Text ]; [ ty ] ]
        (call "infix" [ Child 1; Str "+"; Child 3 ]);
      agree ("prefix, child " ^ name) [ text; leaf ty ] [ [ Text ]; [ ty ] ]
        (call "prefix" [ Str "-"; Child 2 ]);
      (* the operator text *)
      agree ("infix, operator " ^ name) [ text; text; text ] [ [ Text ]; [ Text ]; [ Text ] ]
        (call "infix" [ Child 1; sample ty; Child 3 ]);
      agree ("prefix, operator " ^ name) [ text; text ] [ [ Text ]; [ Text ] ]
        (call "prefix" [ sample ty; Child 2 ]))
    Rhema_types.all;
  (* a value where a child is wanted *)
  agree "infix of a value" [ leaf Text; leaf Text; leaf Text ] [ [ Text ]; [ Text ]; [ Text ] ]
    (call "infix" [ Str "a"; Str "+"; Child 3 ]);
  agree "prefix of a value" [ leaf Text; leaf Text ] [ [ Text ]; [ Text ] ]
    (call "prefix" [ Str "-"; Str "a" ])

(* Every operator, every type or pair of types. With one type on each side
   the checker's verdict is exact, so it must be the engine's. *)
let () =
  List.iter
    (fun operator ->
      List.iter
        (fun ty ->
          let expression = Unary (operator, sample ty) in
          let _, reports = statically expression in
          match run expression with
          | Refused _ ->
              check
                (Printf.sprintf "'%s' of %s: the engine refuses, the checker does not" operator
                   (Rhema_types.name ty))
                (reports <> [])
          | Value result ->
              check
                (Printf.sprintf "'%s' of %s: the checker refuses, the engine does not" operator
                   (Rhema_types.name ty))
                (reports = []);
              check "a unary result has the type the table gives"
                (match Rhema_types.unary operator with
                | Some (_, results) -> List.mem result results
                | None -> false))
        Rhema_types.all)
    [ "-"; "not" ];
  List.iter
    (fun operator ->
      List.iter
        (fun left ->
          List.iter
            (fun right ->
              (* `or` stops at a true left side; a false one makes it read
                 the right. *)
              let left_sample =
                if operator = "or" && left = Rhema_types.Truth then Bool false else sample left
              in
              let expression = Binary (operator, left_sample, sample right) in
              let inferred, reports = statically expression in
              let label =
                Printf.sprintf "%s %s %s" (Rhema_types.name left) operator (Rhema_types.name right)
              in
              match run expression with
              | Refused message ->
                  check (label ^ ": the engine refuses, the checker does not: " ^ message)
                    (reports <> [])
              | Value result ->
                  check (label ^ ": the checker refuses, the engine does not") (reports = []);
                  check
                    (Printf.sprintf "%s: gave %s, inferred %s" label (Rhema_types.name result)
                       (Rhema_types.describe inferred))
                    (List.mem result inferred))
            Rhema_types.all)
        Rhema_types.all)
    [ "+"; "-"; "*"; "/"; "%"; "^"; "++"; "="; "!="; "<"; "<="; ">"; ">="; "and"; "or" ]

(* ------------------------------------------------------------------ *)
(* 2. What is inferred against what is generated                        *)
(* ------------------------------------------------------------------ *)

(* The specification a node's rule belongs to: the file's own, or one of
   the modules it imports, directly or through others. *)
let rec owner (spec : Rhema_check.spec) rule =
  if List.memq rule spec.rules then Some spec
  else List.find_map (fun (_, imported) -> owner imported rule) spec.imports

(* The files of the library, given by name on the command line (see the
   dune file). The suites run side by side in this directory and write
   temporary grammars into it, so listing the directory would pick up a file
   of another suite that is malformed on purpose, or gone a moment later. *)
let library_files =
  Array.to_list Sys.argv |> List.tl |> List.map Filename.basename
  |> List.filter (fun name -> Filename.check_suffix name ".rhm")
  |> List.sort_uniq String.compare

let () =
  let files = library_files in
  let attributes = ref 0 and values = ref 0 and files_run = ref 0 in
  List.iter
    (fun filename ->
      match Rhema_load.parse_file filename with
      | Error errors ->
          List.iter (fun error -> fail (filename ^ ": " ^ Rhema_load.string_of_failure error)) errors
      | Ok file ->
          if file.questions <> [] then incr files_run;
          List.iter
            (fun (question : Rhema_check.question) ->
              match Rhema_check.select_question file question.q_name with
              | Error message -> fail message
              | Ok spec ->
                  Random.init 11;
                  for _ = 1 to 25 do
                    let generated = Rhema_engine.generate spec in
                    let rec visit (node : Rhema_engine.node) =
                      (match node.applied_rule with
                      | None -> ()
                      | Some rule -> (
                          match owner spec rule with
                          | None -> fail (filename ^ ": a node's rule belongs to no specification")
                          | Some home ->
                              List.iter
                                (fun (name, value) ->
                                  incr attributes;
                                  let actual = Rhema_engine.value_type value in
                                  match List.assoc_opt (node.symbol, name) home.attribute_types with
                                  | None ->
                                      fail
                                        (Printf.sprintf "%s: no type was inferred for %s.%s" filename
                                           node.symbol name)
                                  | Some inferred ->
                                      check
                                        (Printf.sprintf "%s: %s.%s is %s, inferred as %s" filename
                                           node.symbol name (Rhema_types.name actual)
                                           (Rhema_types.describe inferred))
                                        (List.mem actual inferred))
                                node.attributes));
                      List.iter visit node.children
                    in
                    visit generated.tree;
                    List.iter
                      (fun (name, value) ->
                        (* alias.NAME is a module's value, typed there. *)
                        if not (String.contains name '.') then begin
                          incr values;
                          let actual = Rhema_engine.value_type value in
                          match List.assoc_opt name spec.value_types with
                          | None -> fail (Printf.sprintf "%s: no type was inferred for %s" filename name)
                          | Some inferred ->
                              check
                                (Printf.sprintf "%s: %s is %s, inferred as %s" filename name
                                   (Rhema_types.name actual) (Rhema_types.describe inferred))
                                (List.mem actual inferred)
                        end)
                      generated.globals
                  done)
            file.questions)
    files;
  check "the library was generated from" (!files_run > 40);
  (* About 20000 here; the count moves with the random generator, which
     is another one in OCaml 4.14, so the floor is well below. *)
  check "attributes were compared" (!attributes > 8000);
  check "randoms and lets were compared" (!values > 1000)

(* ------------------------------------------------------------------ *)
(* 3. The checker on small grammars                                     *)
(* ------------------------------------------------------------------ *)

let errors_of name source =
  match Rhema_load.parse_string ~filename:name source with
  | Ok _ -> []
  | Error errors -> List.map Rhema_load.string_of_failure errors

let accepted name source =
  match errors_of name source with
  | [] -> ()
  | errors -> fail (Printf.sprintf "%s was refused: %s" name (String.concat " | " errors))

(* Exactly one error, holding every fragment. *)
let refused name source ~mentions =
  match errors_of name source with
  | [ error ] ->
      List.iter
        (fun fragment ->
          if not (contains error fragment) then
            fail (Printf.sprintf "%s: the error does not mention %S: %s" name fragment error))
        mentions
  | [] -> fail (Printf.sprintf "%s was accepted; an error mentioning %S was expected" name (List.hd mentions))
  | errors ->
      fail
        (Printf.sprintf "%s: one error was expected, not %d: %s" name (List.length errors)
           (String.concat " | " errors))

let types_of name source =
  match Rhema_load.parse_string ~filename:name source with
  | Ok spec -> Some spec
  | Error errors ->
      fail (Printf.sprintf "%s was refused: %s" name (String.concat " | " (List.map Rhema_load.string_of_failure errors)));
      None

(* A grammar of sums of numbers, with room for one more declaration, one
   more line in the sum, and one more in the leaf. *)
let sums ?(declarations = "") ?(in_sum = "") ?(in_leaf = "") ?(guard = "cost >= 1")
    ?(update = "cost = -1") ?(leaf = "integer_between(1, 9)") ?(prompt = "What is [`{E.latex}`]?")
    ?(answer = "E.value") () =
  Printf.sprintf
    {|attribute cost = 3 split
random n = integer_between(2, 9)
random flag = boolean
let label = "n = " ++ n
%s
synth value on E
synth latex on E
precedence 1 left +
start E

E -> E + E when %s {
  %s
  value = $1.value + $3.value
  latex = infix($1, "+", $3)
  %s
}

E -> %s when cost = 0 {
  value = $1.value
  latex = str($1.value)
  %s
}

prompt "%s"
answer %s
|}
    declarations guard update in_sum leaf in_leaf prompt answer

(* ---- numbers, text and truth values ---- *)
let () =
  accepted "plain.rhm" (sums ());
  (* A number is written out wherever text is wanted. *)
  accepted "number_as_text.rhm" (sums ~in_leaf:{|let shown = "value " ++ $1.value ++ str(n)|} ());
  accepted "truth_equality.rhm" (sums ~in_leaf:"require (flag = true) != false" ());
  accepted "text_equality.rhm" (sums ~in_leaf:{|require label != "n = 1"|} ());
  refused "text_in_sum.rhm"
    (sums ~in_leaf:"let more = label + 1" ())
    ~mentions:[ "text_in_sum.rhm:21:14"; "'+' takes a number on its left"; "'label' is text" ];
  refused "text_times.rhm"
    (sums ~in_leaf:{|let more = $1.value * "two"|} ())
    ~mentions:[ "'*' takes a number on its right"; {|"two" is text|} ];
  refused "minus_text.rhm" (sums ~in_leaf:"let more = -label" ()) ~mentions:[ "'-' takes a number"; "'label' is text" ];
  refused "not_number.rhm"
    (sums ~in_leaf:"require not n" ())
    ~mentions:[ "'not' takes a truth value"; "'n' is a number" ];
  refused "and_number.rhm"
    (sums ~in_leaf:"require flag and n" ())
    ~mentions:[ "'and' takes a truth value on its right"; "'n' is a number" ];
  refused "order_text.rhm"
    (sums ~in_leaf:"require label < 3" ())
    ~mentions:[ "'<' takes a number on its left"; "'label' is text" ];
  refused "compare_across.rhm"
    (sums ~in_leaf:"require flag = n" ())
    ~mentions:[ "'=' compares two values of one type"; "'flag' is a truth value"; "'n' is a number" ];
  refused "join_formula.rhm"
    (sums ~in_leaf:{|let shown = "f = " ++ formula_constant(n)|} ())
    ~mentions:[ "'++' takes"; "formula_constant(...) is a formula" ]

(* ---- builtins and their arguments ---- *)
let () =
  accepted "formula_arguments.rhm"
    (sums ~in_leaf:{|let f = formula_add(formula_constant($1.value), formula_variable("x"))|} ());
  (* plain() takes a number, a formula or a polynomial. *)
  accepted "plain_overloads.rhm"
    (sums
       ~in_leaf:
         {|let a = plain(n)
  let b = plain(formula_constant(n))
  let c = plain(polynomial_variable("x"))|}
       ());
  refused "number_for_formula.rhm"
    (sums ~in_leaf:"let f = formula_add(formula_constant(n), $1.value)" ())
    ~mentions:
      [ "number_for_formula.rhm:21:44"; "formula_add takes a formula as its second argument";
        "$1.value is a number" ];
  refused "text_for_number.rhm"
    (sums ~in_leaf:{|let big = abs("x")|} ())
    ~mentions:[ "abs takes a number as its first argument"; {|"x" is text|} ];
  refused "plain_matrix.rhm"
    (sums ~in_leaf:"let a = plain(matrix_identity(2))" ())
    ~mentions:[ "plain takes a number, a formula or a polynomial"; "matrix_identity(...) is a matrix" ];
  refused "exactly_text.rhm"
    (sums ~in_leaf:"let a = exactly(label)" ())
    ~mentions:[ "exactly takes a number"; "'label' is text" ];
  refused "truth_for_endpoint.rhm"
    (sums ~in_leaf:"let s = set_interval(1, 2, 1, true)" ())
    ~mentions:[ "set_interval takes a truth value as its third argument"; "1 is a number" ];
  (* One wrong argument is one error: the call still has its own type, so
     what is built on it is not reported again. *)
  refused "no_cascade.rhm"
    (sums
       ~in_leaf:
         {|let f = formula_add(formula_constant(n), label)
  let g = formula_multiply(f, f)
  let shown = formula_latex(g) ++ "."|}
       ())
    ~mentions:[ "formula_add takes a formula as its second argument" ]

(* ---- guards, requirements, budgets ---- *)
let () =
  refused "guard_budget.rhm" (sums ~guard:"cost" ())
    ~mentions:[ "a 'when' condition must be true or false, but this one is a number" ];
  refused "require_label.rhm" (sums ~in_leaf:"require label" ())
    ~mentions:[ "a 'require' must be true or false, but this one is text" ];
  refused "update_word.rhm" (sums ~update:{|cost = "one"|} ())
    ~mentions:[ "the budget 'cost' changes by a whole number, but this update is text" ];
  refused "update_formula.rhm" (sums ~update:"cost = formula_constant(1)" ())
    ~mentions:[ "the budget 'cost' changes by a whole number, but this update is a formula" ];
  refused "generator_text.rhm" (sums ~leaf:"integer_between(1, label)" ())
    ~mentions:[ "integer_between takes a number as its second argument"; "'label' is text" ];
  (* A guard reads the budgets, which are numbers, and the randoms. *)
  accepted "guard_values.rhm" (sums ~guard:"cost >= 1 and (flag or n > 3)" ())

(* ---- local names and children ---- *)
let () =
  refused "local_flows.rhm"
    (sums ~in_leaf:{|let unit = "cm"
  let area = unit * 2|} ())
    ~mentions:[ "'*' takes a number on its left"; "'unit' is text" ];
  refused "child_text.rhm"
    (sums ~in_sum:"let total = $1.latex + 1" ())
    ~mentions:[ "'+' takes a number on its left"; "$1.latex is text" ];
  (* A terminal of the production, here the `+` of E -> E + E, is text. *)
  refused "terminal_value.rhm"
    (sums ~in_sum:"let sign = $2.value + 1" ())
    ~mentions:[ "$2.value is text" ];
  accepted "child_number.rhm" (sums ~in_sum:"let total = $1.value * 2 + $3.value" ());
  (* A child is a node: only infix and prefix take it whole. *)
  refused "node_as_value.rhm"
    (sums ~in_sum:"let wrapped = paren($1)" ())
    ~mentions:[ "$1 is a node, not a value"; "$1.value" ];
  refused "value_as_node.rhm"
    (sums ~in_sum:{|let joined = infix($1.latex, "+", $3)|} ())
    ~mentions:[ "infix takes a child written $n as its first argument"; "$1.latex is a value" ];
  (* prefix and infix write the child's copy of the attribute being
     computed, which must be text. In the sum above `latex` is; here `f` is
     a formula on F. *)
  refused "prefix_of_formula.rhm"
    {|synth f on F
synth f on Q
start Q

Q -> F {
  f = prefix("-", $1)
}

F -> integer_between(1, 9) {
  f = formula_constant($1.value)
}

prompt "Go."
answer Q.f
|}
    ~mentions:[ "prefix writes the 'f' of $1 as text"; "$1.f is a formula" ]

(* ---- recursion and the order of declarations ---- *)

(* The question comes first and the leaf last; the type of F.d is found
   through the recursive rules whatever the order. *)
let derivative uses =
  Printf.sprintf
    {|attribute cost = 4 split
synth text on Q
synth shown on Q
synth d on F
synth f on F
start Q

Q -> F {
  shown = %s
  text = "Differentiate."
}

F -> F "+" F when cost >= 1 {
  cost = -1
  f = formula_add($1.f, $3.f)
  d = formula_add($1.d, $3.d)
}

F -> "sin" F when cost >= 2 {
  cost = -2
  f = formula_sin($2.f)
  d = formula_multiply(formula_cos($2.f), $2.d)
}

F -> "x" when cost <= 1 {
  f = formula_variable("x")
  d = formula_constant(1)
}

prompt "{Q.text}"
answer Q.shown
|}
    uses

let () =
  accepted "recursive.rhm" (derivative "formula_latex($1.d)");
  refused "recursive_wrong.rhm" (derivative "$1.d + 1")
    ~mentions:[ "'+' takes a number on its left"; "$1.d is a formula" ];
  match types_of "recursive_types.rhm" (derivative "formula_latex($1.d)") with
  | None -> ()
  | Some spec ->
      check "F.d is a formula" (List.assoc_opt ("F", "d") spec.attribute_types = Some [ Rhema_types.Formula ]);
      check "Q.shown is text" (List.assoc_opt ("Q", "shown") spec.attribute_types = Some [ Rhema_types.Text ])

(* A wrong leaf under a recursive rule. The rule's own `+` gives a number
   only when its operands can be numbers, so it does not vouch for the leaf:
   E.value is text and both sides of the sum are refused. An earlier version
   took the result of `+` for granted, made E.value "a number or text", and
   let this file through to fail on its first question. *)
let () =
  let source =
    {|attribute cost = 3 split
synth value on E
precedence 1 left +
start E

E -> E + E when cost >= 1 {
  cost = -1
  value = $1.value + $3.value
}

E -> integer_between(1, 9) when cost = 0 {
  value = str($1.value)
}

prompt "Add."
answer E.value
|}
  in
  (match errors_of "wrong_leaf.rhm" source with
  | [ left; right ] ->
      check "the left side of the sum is refused" (contains left "'+' takes a number on its left, but $1.value is text");
      check "and the right" (contains right "'+' takes a number on its right, but $3.value is text")
  | errors ->
      fail
        (Printf.sprintf "wrong_leaf.rhm: two errors were expected, not %d: %s" (List.length errors)
           (String.concat " | " errors)))

(* The order of the rules does not change the verdict. The three files hold
   the same rules; `a` is a matrix or text with blanks, and `++` takes only
   the second. An earlier version counted the refused matrix as text while
   the sets were still growing, and accepted one order and refused two. *)
let () =
  let matrix = {|E -> "m" { a = matrix_identity(2) }|}
  and blanked = {|E -> "b" { a = blank(1) }|}
  and joined = {|Q -> E { t = $1.a ++ "x" }|} in
  let file rules =
    "synth a on E
synth t on Q
start Q
" ^ String.concat "
" rules ^ "
prompt \"Go.\"
answer Q.t
"
  in
  let verdict name rules =
    errors_of name (file rules)
    |> List.map (fun error ->
           (* drop file:line:column, which do differ *)
           match String.index_opt error ' ' with
           | Some space -> String.sub error space (String.length error - space)
           | None -> error)
    |> List.sort compare
  in
  let first = verdict "order.rhm" [ matrix; blanked; joined ] in
  List.iter
    (fun rules -> check "the order of the rules changes the verdict" (verdict "order.rhm" rules = first))
    [ [ matrix; joined; blanked ]; [ joined; matrix; blanked ]; [ blanked; joined; matrix ];
      [ joined; blanked; matrix ]; [ blanked; matrix; joined ] ];
  (* and the verdict is that the answer always holds a blank or fails *)
  check "the joined text is refused as an answer in every order"
    (List.exists (fun error -> contains error "cannot be graded") first)

(* ---- one name, several types ---- *)

(* `value` is a number on N and a formula on G: two attributes. On A it is
   either, by production; on C it is either, by `cond`. *)
let several uses =
  Printf.sprintf
    {|random flag = boolean
synth value on N
synth value on G
synth value on A
synth value on C
synth out on Q
start Q

Q -> N G A C {
  out = %s
}

N -> integer_between(1, 9) { value = $1.value }
G -> integer_between(1, 9) { value = formula_constant($1.value) }
A -> N { value = $1.value }
A -> G { value = $1.value }
C -> N G { value = cond(flag, $1.value, $2.value) }

prompt "Go."
answer Q.out
|}
    uses

let () =
  (* N.value and G.value do not share a type because they share a name. *)
  accepted "by_nonterminal.rhm" (several "formula_add(formula_constant($1.value), $2.value)");
  refused "by_nonterminal_wrong.rhm" (several "formula_add($1.value, $2.value)")
    ~mentions:[ "formula_add takes a formula as its first argument"; "$1.value is a number" ];
  (* What may be a formula is allowed where a formula is wanted, and where
     a number is: the engine decides, question by question. *)
  accepted "either_as_formula.rhm" (several "formula_negate($3.value)");
  accepted "either_as_number.rhm" (several "$3.value + 1");
  accepted "cond_as_formula.rhm" (several "formula_negate($4.value)");
  (* What can be neither is refused, and the message names both. *)
  refused "either_as_matrix.rhm" (several "matrix_transpose($3.value)")
    ~mentions:[ "matrix_transpose takes a matrix"; "$3.value is a number or a formula" ];
  refused "cond_as_matrix.rhm" (several "matrix_transpose($4.value)")
    ~mentions:[ "$4.value is a number or a formula" ];
  (* Only the chosen branch of cond is evaluated, so the branches need not
     agree; the test must still be a truth value. *)
  accepted "cond_branches.rhm" (several {|cond(flag, 1, "one")|});
  refused "cond_test.rhm" (several {|cond($1.value, 1, 2)|})
    ~mentions:[ "cond takes a truth value as its first argument"; "$1.value is a number" ];
  match types_of "several_types.rhm" (several "1") with
  | None -> ()
  | Some spec ->
      let either = Some [ Rhema_types.Number; Rhema_types.Formula ] in
      check "N.value is a number" (List.assoc_opt ("N", "value") spec.attribute_types = Some [ Rhema_types.Number ]);
      check "G.value is a formula" (List.assoc_opt ("G", "value") spec.attribute_types = Some [ Rhema_types.Formula ]);
      check "A.value is either, by production" (List.assoc_opt ("A", "value") spec.attribute_types = either);
      check "C.value is either, by cond" (List.assoc_opt ("C", "value") spec.attribute_types = either);
      check "flag is a truth value" (List.assoc_opt "flag" spec.value_types = Some [ Rhema_types.Truth ])

(* ---- modules ---- *)

let write name content =
  let channel = open_out name in
  output_string channel content;
  close_out channel

let () =
  write "types_core.rhm" (derivative "formula_latex($1.d)" ^ {|let given = "about x"
let size = 3
|});
  let importer ?(argument = "cost") uses =
    Printf.sprintf
      {|import "types_core.rhm" as core

attribute cost = 4 copy
synth out on Q
start Q

Q -> core.F(cost = %s) {
  out = %s
}

prompt "Go."
answer Q.out
|}
      argument uses
  in
  let from_file name source =
    write name source;
    let result =
      match Rhema_load.parse_file name with
      | Ok _ -> []
      | Error errors -> List.map Rhema_load.string_of_failure errors
    in
    Sys.remove name;
    result
  in
  let expect name source mentions =
    match (from_file name source, mentions) with
    | [], [] -> ()
    | [ error ], _ :: _ ->
        List.iter
          (fun fragment ->
            if not (contains error fragment) then
              fail (Printf.sprintf "%s: the error does not mention %S: %s" name fragment error))
          mentions
    | errors, _ ->
        fail
          (Printf.sprintf "%s: %d error(s) where %d were expected: %s" name (List.length errors)
             (if mentions = [] then 0 else 1)
             (String.concat " | " errors))
  in
  (* The types of a module's attributes and values cross the import. *)
  expect "import_right.rhm" (importer {|formula_latex($1.d) ++ core.given ++ str(core.size + 1)|}) [];
  expect "import_attribute.rhm" (importer "$1.d + 1") [ "'+' takes a number on its left"; "$1.d is a formula" ];
  expect "import_value.rhm" (importer "core.given + 1") [ "core.given is text" ];
  expect "import_budget.rhm"
    (importer ~argument:"core.given" "formula_latex($1.d)")
    [ "core.F starts 'cost' at a whole number"; "core.given is text" ];
  Sys.remove "types_core.rhm"

(* ---- prompts, answers, blanks ---- *)
let () =
  accepted "blank_in_text.rhm"
    (sums ~declarations:"synth text on E"
       ~in_sum:{|text = "Sum: " ++ blank(value)|}
       ~in_leaf:{|text = "Value: " ++ blank_wide(exactly(value), 6) ++ " and " ++ blank(plain(value))|}
       ~prompt:"{E.text}" ~answer:"E.value" ()
    |> fun source ->
    (* this question's blanks are in its text, so it has no answer line *)
    String.concat "" (List.filter (fun line -> not (contains line "answer E.value")) (String.split_on_char '\n' source |> List.map (fun line -> line ^ "\n"))));
  refused "blank_of_blank.rhm"
    (sums ~in_leaf:"let twice = blank(blank(value))" ())
    ~mentions:[ "blank takes"; "blank(...) is text with answer blanks" ];
  refused "str_of_blank.rhm"
    (sums ~in_leaf:"let flat = str(blank(value))" ())
    ~mentions:[ "str takes a number or text"; "blank(...) is text with answer blanks" ];
  refused "blank_of_equation.rhm"
    (sums ~in_leaf:{|let ask = blank(equation(formula_variable("x"), formula_constant(n)))|} ())
    ~mentions:[ "blank takes"; "equation(...) is an equation" ];
  refused "answer_equation.rhm"
    (sums ~declarations:{|let eq = equation(formula_variable("x"), formula_constant(n))|}
       ~prompt:"Solve. {answer eq}" ~answer:"E.value" ()
    |> fun source ->
    String.concat "" (List.filter (fun line -> not (contains line "answer E.value")) (String.split_on_char '\n' source |> List.map (fun line -> line ^ "\n"))))
    ~mentions:[ "{answer eq} is an equation, which cannot be graded"; "equation_solution_set" ];
  refused "answer_line_equation.rhm"
    (sums ~answer:"equation(formula_constant(E.value), formula_constant(1))" ())
    ~mentions:[ "the answer is an equation, which cannot be graded" ];
  refused "prompt_formula.rhm"
    (sums ~declarations:{|let f = formula_constant(n)|} ~prompt:"Here is {f}." ())
    ~mentions:[ "{f} is a formula, which a prompt cannot show"; "_latex" ];
  accepted "prompt_number.rhm" (sums ~prompt:"With {n} and {label}: [`{E.latex}`]" ());
  (* An attribute of the start symbol in a hole; a truth value has no
     function ending in _latex, so none is suggested. *)
  refused "prompt_attribute.rhm"
    (sums ~declarations:"synth even on E" ~in_sum:"even = value % 2 = 0" ~in_leaf:"even = value % 2 = 0"
       ~prompt:"Is it even? {E.even}" ())
    ~mentions:[ "{E.even} is a truth value, which a prompt cannot show; a prompt shows text and numbers" ];
  (match errors_of "prompt_attribute.rhm"
           (sums ~declarations:"synth even on E" ~in_sum:"even = value % 2 = 0" ~in_leaf:"even = value % 2 = 0"
              ~prompt:"Is it even? {E.even}" ())
   with
  | [ error ] -> check "no _latex function is suggested for a truth value" (not (contains error "_latex"))
  | _ -> ());
  (* The same hole twice is one mistake. *)
  refused "prompt_twice.rhm"
    (sums ~declarations:{|let f = formula_constant(n)|} ~prompt:"Here is {f}, and again {f}." ())
    ~mentions:[ "{f} is a formula" ];
  (* Text that holds a blank is not itself an answer. *)
  refused "answer_blanked.rhm"
    (sums ~answer:"blank(E.value)" ())
    ~mentions:[ "the answer is text with answer blanks, which cannot be graded; it already holds its own blanks" ];
  (* `=` on values that have no equality. *)
  refused "compare_blanks.rhm"
    (sums ~in_leaf:"require blank(1) = blank(1)" ())
    ~mentions:[ "'=' cannot compare text with answer blanks" ];
  refused "width_text.rhm"
    (sums ~declarations:"synth pg_width on E" ~in_sum:{|pg_width = "wide"|} ~in_leaf:{|pg_width = "wide"|} ())
    ~mentions:[ "'pg_width' must be a number, but 'E' computes it as text" ];
  refused "variables_truth.rhm"
    (sums ~declarations:"let pg_variables = flag" ())
    ~mentions:[ "'pg_variables' must be a number or text, but the file computes it as a truth value" ];
  refused "context_number.rhm"
    (sums ~declarations:"synth pg_context on E" ~in_sum:"pg_context = 1 = 1" ~in_leaf:"pg_context = true" ())
    ~mentions:[ "context_number.rhm:24:1"; "'pg_context' must be a number or text"; "a truth value" ]

(* ---- mistakes ---- *)

(* A mistake line may give a value of any kind. What is refused is a use
   that, as the mistake works the grammar out, can never be evaluated:
   generation stops there every time the mistake is tried. *)
let () =
  let slip line =
    sums ~declarations:{|mistake slip "adds one too many"|} ~in_sum:line ()
  in
  accepted "mistake_same_type.rhm" (slip "mistake slip value = value + 1");
  accepted "mistake_wrapped.rhm" (slip "mistake slip value = exactly(value + 1)");
  (* Another kind of value, read by nothing that cannot take it: the sum
     above may still meet a right number from another node. *)
  accepted "mistake_other_kind.rhm" (slip {|mistake slip value = "many"|});
  (* The expression of a mistake line is checked, as the mistake reads it. *)
  refused "mistake_expression.rhm" (slip {|mistake slip value = value + "one"|})
    ~mentions:[ "under the mistake 'slip', '+' takes a number on its right"; {|"one" is text|} ];
  (* A mistake line teaches the checker nothing about the right value: the
     attribute keeps its type, and the right working is read with it. *)
  (match
     types_of "mistake_apart.rhm"
       (slip {|let after = value * 2
  mistake slip value = "many"|})
   with
  | None -> ()
  | Some spec ->
      check "a mistake line does not change the attribute's type"
        (List.assoc_opt ("E", "value") spec.attribute_types = Some [ Rhema_types.Number ]));
  (* One root where the set of roots is asked: a real mistake, of another
     kind than the answer, and nothing reads it but the answer. *)
  accepted "mistake_one_root.rhm"
    {|mistake one_root "gives one root where both are asked"
synth roots on Q
start Q

Q -> integer_between(1, 4) integer_between(5, 9) {
  roots = set_insert(set_insert(set_empty(), $1.value), $2.value)
  mistake one_root roots = $1.value
}

prompt "Find every root."
answer Q.roots
|};
  (* The line below reads the mistaken value and cannot take it. Before
     types were checked, generation stopped here with "under the mistake
     'as_text': * expected a number". *)
  refused "mistake_then_used.rhm"
    {|mistake as_text "writes the number as a word"
synth value on Q
synth twice on Q
start Q

Q -> integer_between(1, 4) {
  value = $1.value
  mistake as_text value = "two"
  twice = value * 2
}

prompt "Double it."
answer Q.twice
|}
    ~mentions:
      [ "mistake_then_used.rhm:9:11"; "under the mistake 'as_text', '*' takes a number on its left";
        "'value' is text" ];
  (* The same across two rules. N has one rule, so under the mistake its
     value is always text and the rule above can never add it. *)
  let across second_rule =
    Printf.sprintf
      {|mistake as_text "writes the number as a word"
synth value on N
synth total on Q
start Q

Q -> N N {
  total = $1.value + $2.value
}

N -> integer_between(1, 4) {
  value = $1.value
  mistake as_text value = "two"
}
%s
prompt "Add them."
answer Q.total
|}
      second_rule
  in
  (match errors_of "mistake_across.rhm" (across "") with
  | [ left; right ] ->
      check "the left side is refused under the mistake"
        (contains left "under the mistake 'as_text', '+' takes a number on its left, but $1.value is text");
      check "and the right" (contains right "on its right, but $2.value is text")
  | errors ->
      fail
        (Printf.sprintf "mistake_across.rhm: two errors were expected, not %d: %s" (List.length errors)
           (String.concat " | " errors)));
  (* With a second rule for N that has no line, a value under the mistake
     may be a number: the engine decides, question by question. *)
  accepted "mistake_across_some.rhm" (across {|
N -> "seven" {
  value = 7
}
|});
  (* A mistake line reads the children as the mistake leaves them. G.f is a
     formula; under the mistake it may be a number, and so can be added to.
     (With the first rule of G alone it would always be a number under the
     mistake, and `formula_latex($1.f)`, which is evaluated before the line
     replaces `v`, could never work: that file is refused, rightly.) *)
  accepted "mistake_reads_mistaken.rhm"
    {|mistake as_number "treats the formula as its constant"
synth f on G
synth v on Q
start Q

Q -> G {
  v = formula_latex($1.f)
  mistake as_number v = str($1.f + 1)
}

G -> integer_between(1, 4) {
  f = formula_constant($1.value)
  mistake as_number f = $1.value
}

G -> "x" {
  f = formula_variable("x")
}

prompt "Write it."
answer Q.v
|};
  (* A requirement is not read under a mistake, as the engine does not
     check it again. *)
  accepted "mistake_skips_require.rhm"
    {|mistake as_text "writes the number as a word"
synth value on Q
start Q

Q -> integer_between(1, 4) {
  value = $1.value
  mistake as_text value = "two"
  require value > 0
}

prompt "Copy it."
answer Q.value
|}

(* ---- when types are checked ---- *)
let () =
  (* A file with an undeclared name is not typed: that name has no type,
     and one mistake is reported once. *)
  refused "untyped_when_broken.rhm"
    (sums ~in_leaf:{|let more = label + missing|} ())
    ~mentions:[ "missing" ];
  (* A wrong type in a branch that is never taken is still reported: the
     checker reads every expression, the engine only the ones it reaches. *)
  refused "dead_branch.rhm"
    (sums ~in_leaf:{|let safe = cond(true, 1, label + 1)|} ())
    ~mentions:[ "'+' takes a number on its left" ];
  (* What depends on the value is not the checker's: this takes the
     factorial of a fraction and divides by zero, and is accepted. *)
  accepted "value_errors.rhm" (sums ~in_leaf:"let later = factorial(1 / 2) + 1 / (n - n)" ())

let () =
  if !failures = 0 then print_endline "Rhema static type tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d static type test(s) failed." !failures);
    exit 1
  end
