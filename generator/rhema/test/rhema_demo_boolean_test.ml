(* Re-read the visible formula and assignment with the existing independent reader. *)
open Rhema_boolean_reader

let check condition message = if not condition then failwith message
let initial spec name value = match Rhema_check.with_initial spec name value with
  | Ok spec -> spec | Error error -> failwith error
let rec operators = function Var _ -> 0 | Not e -> 1 + operators e
  | Bin (_,a,b) -> 1 + operators a + operators b
let rec negations = function Var _ -> 0 | Not e -> 1 + negations e
  | Bin (_,a,b) -> negations a + negations b

let () =
  let spec = match Rhema_load.parse_file "../grammars/boolean_demo_flexible.rhm" with
    | Ok s -> s | Error errors -> failwith (String.concat "\n" (List.map Rhema_load.string_of_failure errors)) in
  let total = ref 0 in
  for variables = 2 to 4 do
    for cost = 1 to 10 do
      let configured = initial (initial spec "variables_mode" variables) "cost" cost in
      for seed = 0 to 19 do
        Random.init (variables * 10000 + cost * 100 + seed);
        let q = Rhema_engine.generate configured in
        let blocks = math_blocks q.prompt in
        let assignment, formulas = List.fold_left (fun (assignment,formulas) text ->
          match String.split_on_char '=' text with
          | [name;value] when String.trim value = "0" || String.trim value = "1" ->
              (assignment @ [String.trim name,String.trim value="1"],formulas)
          | _ -> (assignment,formulas @ [text])) ([],[]) blocks in
        check (List.length assignment = variables) "wrong displayed variable pool";
        let formula = match formulas with [f] -> parse f | _ -> failwith "missing displayed formula" in
        let expected = evaluate assignment formula in
        let actual = match q.answer with
          | Rhema_engine.Num n -> Rhema_number.to_string n = "1"
          | _ -> failwith "answer is not numeric" in
        check (actual=expected) "displayed question and standard answer disagree";
        check (operators formula=cost) "budget does not equal operator count";
        check (negations formula<=3) "negation limit exceeded";
        let names = variable_set formula in
        check (List.length names >= min (cost+1) variables) "insufficient variable coverage";
        let outcomes = List.init (1 lsl List.length names) (fun mask ->
          evaluate (List.mapi (fun i name -> name,mask land (1 lsl i) <> 0) names) formula) in
        check (List.mem true outcomes && List.mem false outcomes) "constant-valued evaluation question";
        incr total
      done
    done
  done;
  Printf.printf "Flexible Boolean demo: %d independently checked questions across 2-4 variables and budgets 1-10.\n" !total
