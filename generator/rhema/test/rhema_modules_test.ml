(* Checks for `import "file.rhm" as name`: a module's names are reached
   through its alias and never clash, an imported nonterminal is expanded
   with the module's own rules from the budget the importer hands it, a
   module is drawn once per question however often it is imported, and the
   mistakes an importer can make are each reported at the importer. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let contains text fragment =
  let rec search index =
    index + String.length fragment <= String.length text
    && (String.sub text index (String.length fragment) = fragment || search (index + 1))
  in
  search 0

let here = Sys.getcwd ()

let write name content =
  let path = Filename.concat here name in
  let channel = open_out path in
  output_string channel content;
  close_out channel;
  path

(* Load an importer written to a file beside the library grammars. *)
let load_source name content =
  let path = write name content in
  let result = Rhema_load.parse_file path in
  Sys.remove path;
  result

let expect_ok name content =
  match load_source name content with
  | Ok spec -> Some spec
  | Error errors ->
      List.iter (fun error -> fail (name ^ ": " ^ Rhema_load.string_of_failure error)) errors;
      None

(* The importer is wrong in one way; the loader must say which. *)
let expect_error name content ~mentions =
  match load_source name content with
  | Ok _ -> fail (Printf.sprintf "%s was accepted although %s" name mentions)
  | Error errors ->
      if not (List.exists (fun error -> contains (Rhema_load.string_of_failure error) mentions) errors)
      then
        fail
          (Printf.sprintf "%s: no error mentions %S; got: %s" name mentions
             (errors |> List.map Rhema_load.string_of_failure |> String.concat " | "))

let generate spec seed =
  Random.init seed;
  match Rhema_engine.generate spec with
  | question -> Some question
  | exception Rhema_engine.Generation_error message ->
      fail (Printf.sprintf "seed %d: %s" seed message);
      None

let module_child (question : Rhema_engine.question) index =
  List.nth question.Rhema_engine.tree.Rhema_engine.children index

let truth_global (question : Rhema_engine.question) name =
  match List.assoc_opt name question.Rhema_engine.globals with
  | Some (Rhema_engine.Truth truth) -> truth
  | _ -> fail ("missing truth value " ^ name); false

(* ------------------------------------------------------------------ *)
(* 1. Two modules with the same names sit side by side                  *)
(* ------------------------------------------------------------------ *)

(* boolean.rhm and boolean_equiv.rhm both have Q, E, V, cost and phrasing.
   Imported, each keeps its own, and the importer may use the names too. *)
let () =
  match
    expect_ok "side_by_side_test.rhm"
      {|import "boolean.rhm" as bool
import "boolean_equiv.rhm" as laws
attribute cost = 6 split
random phrasing = integer_between(1, 2)
synth text on Q
synth value on Q
start Q
Q -> bool.E(cost = cost) "then" laws.L(cost = cost + 1) {
  text = bool_latex($1.f) ++ " / " ++ bool_latex($3.fa) ++ cond(phrasing = 1, "", ".")
  value = bool_evaluate($1.f, bool.names, bool.mask)
}
prompt "{Q.text} given {bool.given}"
answer Q.value
|}
  with
  | None -> ()
  | Some spec ->
      for seed = 0 to 29 do
        match generate spec seed with
        | None -> ()
        | Some question ->
            let left = Rhema_engine.consumption (module_child question 0) "cost"
            and right = Rhema_engine.consumption (module_child question 2) "cost" in
            (* `cost = cost` under split: each module gets its share, and the
               two shares are the whole budget (plus the 1 the law is given on
               top, since a law needs a budget of at least 1). *)
            if left + right <> 7 then
              fail (Printf.sprintf "seed %d: the shares %d and %d do not add up to 6 + 1" seed left right);
            if not (contains question.Rhema_engine.prompt "given [`p = ") then
              fail (Printf.sprintf "seed %d: {bool.given} was not filled in: %s" seed question.Rhema_engine.prompt);
            (match question.Rhema_engine.answer with
            | Rhema_engine.Truth _ -> ()
            | other -> fail (Printf.sprintf "seed %d: answer %s" seed (Rhema_engine.describe_value other)))
      done

(* ------------------------------------------------------------------ *)
(* 2. Arguments, defaults and exact spending                            *)
(* ------------------------------------------------------------------ *)

let () =
  (* A constant budget, a budget computed from the importer's, and none. *)
  let cases =
    [
      ("bool.E(cost = 5)", fun _ -> 5);
      ("bool.E(cost = cost - 1)", fun budget -> budget - 1);
      ("bool.E(cost = 2 * cost)", fun budget -> 2 * budget);
      ("bool.E", fun _ -> 10);
    ]
  in
  List.iter
    (fun (symbol, expected) ->
      match
        expect_ok "arguments_test.rhm"
          (Printf.sprintf
             {|import "boolean.rhm" as bool
attribute cost = 4 copy
synth text on M
start M
M -> %s { text = bool_latex($1.f) }
prompt "[`{M.text}`]"
answer M.text
|}
             symbol)
      with
      | None -> ()
      | Some base ->
          List.iter
            (fun budget ->
              match Rhema_check.with_initial base "cost" budget with
              | Error message -> fail message
              | Ok spec ->
                  for seed = 0 to 9 do
                    match generate spec seed with
                    | None -> ()
                    | Some question ->
                        let spent = Rhema_engine.consumption question.Rhema_engine.tree "cost" in
                        if spent <> expected budget then
                          fail
                            (Printf.sprintf "%s with cost %d, seed %d: the module spent %d, expected %d"
                               symbol budget seed spent (expected budget))
                  done)
            [ 2; 4; 7 ])
    cases

(* A budget the importer computes must be a whole non-negative number. *)
let () =
  match
    expect_ok "negative_test.rhm"
      {|import "boolean.rhm" as bool
attribute cost = 1 copy
synth text on M
start M
M -> bool.E(cost = cost - 3) { text = bool_latex($1.f) }
prompt "[`{M.text}`]"
answer M.text
|}
  with
  | None -> ()
  | Some spec -> (
      Random.init 0;
      match Rhema_engine.generate spec with
      | _ -> fail "a module started on a negative budget"
      | exception Rhema_engine.Generation_error message ->
          if not (contains message "cannot start negative") then fail ("unexpected message: " ^ message))

(* ------------------------------------------------------------------ *)
(* 3. One module, drawn once per question                               *)
(* ------------------------------------------------------------------ *)

(* Two aliases for one file name one module: the truth assignment drawn for
   `a` is the one `b` sees, and each alias is a separate route to it. *)
let () =
  match
    expect_ok "twice_test.rhm"
      {|import "boolean.rhm" as a
import "boolean.rhm" as b
attribute cost = 4 split
synth text on M
synth value on M
start M
M -> a.E(cost = cost) "," b.E(cost = cost) {
  text = bool_latex($1.f) ++ " and " ++ bool_latex($3.f)
  value = bool_evaluate($1.f, a.names, a.mask) = bool_evaluate($3.f, b.names, b.mask)
}
prompt "{M.text}"
answer M.value
|}
  with
  | None -> ()
  | Some spec ->
      if List.length spec.Rhema_check.imports <> 2 then fail "two aliases should give two imports";
      (match spec.Rhema_check.imports with
      | [ (_, first); (_, second) ] ->
          if first.Rhema_check.source <> second.Rhema_check.source then
            fail "two imports of one file should name the same module"
      | _ -> ());
      for seed = 0 to 19 do
        match generate spec seed with
        | None -> ()
        | Some question ->
            List.iter
              (fun name ->
                if truth_global question ("a." ^ name) <> truth_global question ("b." ^ name) then
                  fail (Printf.sprintf "seed %d: a.%s and b.%s differ" seed name name))
              [ "p"; "q"; "r" ]
      done

(* ------------------------------------------------------------------ *)
(* 4. A library module and a module that imports modules                *)
(* ------------------------------------------------------------------ *)

(* polynomial_core.rhm has no start symbol; imported, its E still expands. *)
let () =
  match
    expect_ok "library_module_test.rhm"
      {|import "polynomial_core.rhm" as poly
attribute cost = 5 copy
synth text on M
synth poly on M
start M
M -> poly.E(cost = cost) { text = $1.latex  poly = $1.poly }
prompt "Expand [`{M.text}`]."
answer M.poly
|}
  with
  | None -> ()
  | Some spec ->
      for seed = 0 to 9 do
        match generate spec seed with
        | None -> ()
        | Some question -> (
            if Rhema_engine.consumption question.Rhema_engine.tree "cost" <> 5 then
              fail (Printf.sprintf "seed %d: the library module did not spend 5" seed);
            match question.Rhema_engine.answer with
            | Rhema_engine.Polynomial _ -> ()
            | other -> fail (Printf.sprintf "seed %d: answer %s" seed (Rhema_engine.describe_value other)))
      done

(* logic_forms.rhm imports two modules; importing it imports them too, once. *)
let () =
  match
    expect_ok "nested_test.rhm"
      {|import "logic_forms.rhm" as forms
import "boolean.rhm" as bool
attribute cost = 6 copy
synth text on M
synth answer_value on M
start M
M -> forms.K(cost = cost) { text = $1.text  answer_value = $1.answer_value }
prompt "{M.text}"
answer M.answer_value
|}
  with
  | None -> ()
  | Some spec ->
      (* The importer may not reach through: forms.bool.E is not a name. *)
      for seed = 0 to 9 do
        match generate spec seed with
        | None -> ()
        | Some question ->
            if Rhema_engine.consumption question.Rhema_engine.tree "cost" <> 6 then
              fail (Printf.sprintf "seed %d: the nested modules did not spend 6" seed)
      done

(* ------------------------------------------------------------------ *)
(* 5. Mistakes, each named at the importer                              *)
(* ------------------------------------------------------------------ *)

let () =
  let importer body =
    {|import "boolean.rhm" as bool
attribute cost = 4 copy
synth f on M
start M
|}
    ^ body
    ^ {|
prompt "[`{M.f}`]"
answer M.f
|}
  in
  expect_error "unknown_alias_test.rhm"
    (importer "M -> calc.E(cost = cost) { f = $1.f }")
    ~mentions:"'calc' is not an imported module";
  expect_error "unknown_nonterminal_test.rhm"
    (importer "M -> bool.Z(cost = cost) { f = $1.f }")
    ~mentions:"module bool has no nonterminal 'Z'";
  expect_error "unknown_attribute_test.rhm"
    (importer "M -> bool.E(depth = 3) { f = $1.f }")
    ~mentions:"module bool has no inherited attribute 'depth'";
  expect_error "twice_attribute_test.rhm"
    (importer "M -> bool.E(cost = 1, cost = 2) { f = $1.f }")
    ~mentions:"sets 'cost' twice";
  expect_error "missing_synth_test.rhm"
    (importer "M -> bool.E(cost = cost) { f = $1.value }")
    ~mentions:"$1 is bool.E, which does not carry 'value'";
  expect_error "unknown_value_test.rhm"
    (importer "M -> bool.E(cost = cost) { f = $1.f  require bool.nothing = 1 }")
    ~mentions:"module bool has no random or let named 'nothing'";
  expect_error "prompt_value_test.rhm"
    ({|import "boolean.rhm" as bool
attribute cost = 4 copy
synth f on M
start M
M -> bool.E(cost = cost) { f = $1.f }
prompt "{bool.nothing} [`{M.f}`]"
answer M.f
|})
    ~mentions:"{bool.nothing}: module bool has no random or let named 'nothing'";
  expect_error "duplicate_alias_test.rhm"
    ({|import "boolean.rhm" as bool
import "calculus.rhm" as bool
attribute cost = 4 copy
synth f on M
start M
M -> bool.E(cost = cost) { f = $1.f }
prompt "[`{M.f}`]"
answer M.f
|})
    ~mentions:"'bool' is already the alias of another import";
  expect_error "child_argument_test.rhm"
    (importer "M -> bool.E(cost = $1.f) { f = $1.f }")
    ~mentions:"does not exist yet"

(* A cycle of imports is refused, naming the files. *)
let () =
  let a = write "cycle_a_test.rhm" "import \"cycle_b_test.rhm\" as b\nsynth v\nstart X\nX -> b.X { v = 1 }\nprompt \"{X.v}\"\nanswer X.v\n" in
  let b = write "cycle_b_test.rhm" "import \"cycle_a_test.rhm\" as a\nsynth v\nstart X\nX -> a.X { v = 1 }\nprompt \"{X.v}\"\nanswer X.v\n" in
  (match Rhema_load.parse_file a with
  | Ok _ -> fail "a cycle of imports was accepted"
  | Error errors ->
      if not (List.exists (fun error -> contains (Rhema_load.string_of_failure error) "closes a cycle") errors)
      then fail "the import cycle was not named as such");
  Sys.remove a;
  Sys.remove b

(* An error inside a module is reported with the module's file, after a
   line at the importer saying which import brought it in. *)
let () =
  let broken = write "broken_module_test.rhm" "synth value\nE -> E \"+\" E { value = $1.value + $3.value }\n" in
  (match
     load_source "uses_broken_module_test.rhm"
       "import \"broken_module_test.rhm\" as m\nsynth v\nstart X\nX -> m.E { v = $1.value }\nprompt \"{X.v}\"\nanswer X.v\n"
   with
  | Ok _ -> fail "a grammar on a broken module was accepted"
  | Error errors -> (
      match errors with
      | first :: rest ->
          if not (contains first.Rhema_load.what "the module has problems of its own") then
            fail ("the first error should blame the import: " ^ Rhema_load.string_of_failure first);
          if not (List.exists (fun error -> contains error.Rhema_load.where "broken_module_test.rhm") rest) then
            fail "the module's own error was not reported with the module's file"
      | [] -> fail "no errors at all"));
  Sys.remove broken

(* ------------------------------------------------------------------ *)
(* 6. The shipped importers                                             *)
(* ------------------------------------------------------------------ *)

let () =
  List.iter
    (fun (file, aliases) ->
      match Rhema_load.parse_file file with
      | Error errors -> List.iter (fun error -> fail (file ^ ": " ^ Rhema_load.string_of_failure error)) errors
      | Ok spec ->
          if List.map fst spec.Rhema_check.imports <> aliases then
            fail (file ^ " imports " ^ String.concat ", " (List.map fst spec.Rhema_check.imports)))
    [ ("derivative_or_boolean.rhm", [ "calc"; "bool" ]); ("logic_forms.rhm", [ "bool"; "laws" ]) ]

let () =
  if !failures = 0 then print_endline "Ag module tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG module test(s) failed." !failures);
    exit 1
  end
