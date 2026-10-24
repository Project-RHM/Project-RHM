(* agcheck.ml — check a .ag file and report what it says.

   Usage: agcheck FILE.ag

   Exits 0 and prints a summary when the grammar is well formed, otherwise
   prints every problem found with its line and column and exits 1. *)

let describe_distribution = function
  | Ag_ast.Copy -> "copy"
  | Ag_ast.Split -> "split"

let describe_associativity = function
  | Ag_ast.Left -> "left"
  | Ag_ast.Right -> "right"
  | Ag_ast.Nonassoc -> "nonassoc"

let describe_symbol = function
  | Ag_ast.Symbol name -> name
  | Ag_ast.Literal text -> "\"" ^ text ^ "\""
  | Ag_ast.Generator (name, arguments) ->
      Printf.sprintf "%s(%d arg%s)" name (List.length arguments)
        (if List.length arguments = 1 then "" else "s")
  | Ag_ast.Module_symbol (alias, name, []) -> alias ^ "." ^ name
  | Ag_ast.Module_symbol (alias, name, arguments) ->
      Printf.sprintf "%s.%s(%s)" alias name
        (arguments |> List.map (fun (attribute, _) -> attribute ^ " = ...") |> String.concat ", ")

let summarize (spec : Ag_check.spec) =
  print_endline "OK";
  if spec.Ag_check.library then
    print_endline
      (if spec.Ag_check.sets <> [] then
         "  set file     : no question of its own; run a set with agrun --run NAME"
       else "  library      : no start symbol; include this file from a grammar");
  if spec.Ag_check.sets <> [] then
    Printf.printf "  sets         : %s\n"
      (spec.Ag_check.sets
      |> List.map (fun (set : Ag_ast.set_decl) ->
             let count =
               List.fold_left
                 (fun total item ->
                   match item with
                   | Ag_ast.Set_entry entry -> total + entry.Ag_ast.se_count
                   | _ -> total)
                 0 set.Ag_ast.set_items
             in
             Printf.sprintf "%s (%d questions)" set.Ag_ast.set_name count)
      |> String.concat ", ");
  Printf.printf "  start symbol : %s\n" spec.Ag_check.start;
  if List.length spec.Ag_check.questions > 1 then
    Printf.printf "  questions    : %s\n"
      (spec.Ag_check.questions
      |> List.map (fun (question : Ag_check.question) ->
             Printf.sprintf "%s (start %s, context %s)" question.Ag_check.q_name
               question.Ag_check.q_start question.Ag_check.q_context)
      |> String.concat ", ");
  if spec.Ag_check.imports <> [] then
    Printf.printf "  imports      : %s\n"
      (spec.Ag_check.imports
      |> List.map (fun (alias, (module_spec : Ag_check.spec)) ->
             alias ^ " = " ^ module_spec.Ag_check.source)
      |> String.concat ", ");
  Printf.printf "  context      : %s\n" spec.Ag_check.context;
  let inherited =
    spec.Ag_check.inherited
    |> List.map (fun (a : Ag_check.inherited_attribute) ->
           Printf.sprintf "%s = %d %s" a.Ag_check.attribute_name
             a.Ag_check.initial
             (describe_distribution a.Ag_check.distribution))
    |> String.concat ", "
  in
  Printf.printf "  inherited    : %s\n"
    (if inherited = "" then "(none)" else inherited);
  Printf.printf "  synthesized  : %s\n"
    (spec.Ag_check.synthesized
    |> List.map (fun (name, scope) ->
           match scope with None -> name | Some owner -> name ^ " on " ^ owner)
    |> String.concat ", ");
  if spec.Ag_check.randoms <> [] then
    Printf.printf "  per question : %s\n"
      (spec.Ag_check.randoms
      |> List.map (fun (name, how) ->
             match how with
             | Ag_ast.Draw_boolean -> name ^ " = boolean"
             | Ag_ast.Draw_generator (generator, _) -> name ^ " = " ^ generator)
      |> String.concat ", ");
  if spec.Ag_check.lets <> [] then
    Printf.printf "  let          : %s\n"
      (spec.Ag_check.lets |> List.map fst |> String.concat ", ");
  Printf.printf "  precedence   : %s\n"
    (spec.Ag_check.precedences
    |> List.map (fun (operator, level, associativity) ->
           Printf.sprintf "%s=%d/%s" operator level
             (describe_associativity associativity))
    |> String.concat ", ");
  Printf.printf "  rules        : %d\n" (List.length spec.Ag_check.rules);
  List.iter
    (fun (rule : Ag_ast.rule) ->
      Printf.printf "    %-4s -> %-16s weight %d%s\n" rule.Ag_ast.lhs
        (rule.Ag_ast.rhs |> List.map describe_symbol |> String.concat " ")
        rule.Ag_ast.weight
        (match rule.Ag_ast.guard with None -> "" | Some _ -> "  (guarded)"))
    spec.Ag_check.rules;
  Printf.printf "  prompt       : %s\n"
    (spec.Ag_check.prompt
    |> List.map (function
         | Ag_check.Text text -> text
         | Ag_check.Value_hole name -> Printf.sprintf "<%s>" name
         | Ag_check.Hole (owner, attribute) ->
             Printf.sprintf "<%s.%s>" owner attribute
         | Ag_check.Answer_hole (owner, attribute) ->
             Printf.sprintf "[answer %s.%s]" owner attribute
         | Ag_check.Answer_value_hole name -> Printf.sprintf "[answer %s]" name)
    |> String.concat "")

let () =
  match Sys.argv with
  | [| _; filename |] -> (
      match Ag_load.parse_file filename with
      | Ok spec -> summarize spec
      | Error errors ->
          List.iter
            (fun error ->
              prerr_endline (Ag_load.string_of_failure error))
            errors;
          Printf.eprintf "\n%d problem(s) found.\n" (List.length errors);
          exit 1)
  | _ ->
      prerr_endline "usage: agcheck FILE.ag";
      exit 2
