(* rhema_sets.ml -- generate the questions a `set` declaration asks for.

   A set is a whole assignment: parts, entries of `N of question(draws)`,
   and constraints. This module draws the budgets each entry asks for,
   generates every question from the grammar it names with those budgets,
   keeps the constraints, and numbers the result. The paper's variant (an
   integer rhema derives from the student and the assignment) fixes all of
   it: the same variant gives the same assignment, and each question starts
   from a value derived from the variant and its position, so adding a
   question at the end leaves the earlier ones as they were. *)

type drawn = {
  label : string;  (* "3" or "2(b)" *)
  part : int;  (* 1-based *)
  heading : string option;
  kind : string;  (* the question asked for, as written: calc.derivative, main *)
  budgets : (string * int) list;  (* the starting values this question got *)
  question : Rhema_engine.question;
}

type result = {
  name : string;
  paper : string;  (* which paper this is: "homework", or "homework for 2330026211" *)
  variant : int;  (* what the draws started from; derived, never chosen *)
  parts : (string option * drawn list) list;
}

let error message = raise (Rhema_engine.Generation_error message)

(* ------------------------------------------------------------------ *)
(* Drawing budgets                                                     *)
(* ------------------------------------------------------------------ *)

(* A standard normal deviate (Box-Muller) from the engine's generator. *)
let gauss () =
  let u = max 1e-12 (Random.float 1.0) and v = Random.float 1.0 in
  sqrt (-2.0 *. log u) *. cos (2.0 *. Float.pi *. v)

let shuffle items =
  let array = Array.of_list items in
  for index = Array.length array - 1 downto 1 do
    let other = Random.int (index + 1) in
    let held = array.(index) in
    array.(index) <- array.(other);
    array.(other) <- held
  done;
  Array.to_list array

(* [count] picks from [values], each value used once before any is used
   again, in a random order: `cost in {8, 10, 12}` over three questions gives
   each budget once. *)
let evenly values count =
  let rec rounds collected remaining =
    if remaining <= 0 then collected
    else
      let round = shuffle values in
      let taken = List.filteri (fun index _ -> index < remaining) round in
      rounds (collected @ taken) (remaining - List.length taken)
  in
  rounds [] count

(* Whole-number budgets around [mean], adjusted so that their sum is exactly
   mean * count when every whole number from [low] up is allowed, and as close
   as the allowed values permit otherwise. The algorithm of
   tools/rhema_difficulty.py (draw_targets), moved into the engine. *)
let around ~mean ~spread ~low ~allowed count =
  let values = Option.map (fun list -> List.sort_uniq compare list) allowed in
  let nearest x =
    match values with
    | None -> max low (Float.to_int (Float.round x))
    | Some values ->
        List.fold_left
          (fun best value ->
            let distance v = Float.abs (Float.of_int v -. x) in
            if distance value < distance best || (distance value = distance best && value < best)
            then value
            else best)
          (List.hd values) values
  in
  let step value up =
    match values with
    | None -> if up then Some (value + 1) else if value > low then Some (value - 1) else None
    | Some values -> (
        let rec find index = function
          | [] -> None
          | v :: rest -> if v = value then Some index else find (index + 1) rest
        in
        match find 0 values with
        | None -> None
        | Some index ->
            let target = if up then index + 1 else index - 1 in
            List.nth_opt values (max 0 target) |> fun found ->
            if target < 0 || target >= List.length values then None else found)
  in
  let targets =
    Array.init count (fun _ -> nearest (Float.of_int mean +. (Float.of_int spread *. gauss ())))
  in
  let wanted = mean * count in
  let sum () = Array.fold_left ( + ) 0 targets in
  let attempts = ref (100 * count) in
  while sum () <> wanted && !attempts > 0 do
    decr attempts;
    let index = Random.int count in
    let current = sum () in
    match step targets.(index) (current < wanted) with
    | Some moved when abs (current - targets.(index) + moved - wanted) <= abs (current - wanted) ->
        targets.(index) <- moved
    | _ -> ()
  done;
  Array.to_list targets

(* The budgets of the questions of one choice within an entry, attribute by
   attribute. *)
let budgets_for (draws : (string * Rhema_ast.budget_draw) list) count =
  let per_attribute =
    List.map
      (fun (attribute, draw) ->
        let values =
          match draw with
          | Rhema_ast.Fixed value -> List.init count (fun _ -> value)
          | Rhema_ast.Among values -> evenly values count
          | Rhema_ast.Around { mean; spread; low; allowed } -> around ~mean ~spread ~low ~allowed count
        in
        (attribute, values))
      draws
  in
  List.init count (fun index ->
      List.map (fun (attribute, values) -> (attribute, List.nth values index)) per_attribute)

(* ------------------------------------------------------------------ *)
(* Constraints                                                         *)
(* ------------------------------------------------------------------ *)

(* The shape of a derivation: which rule was applied at each node, in order,
   with the leaves' values erased, so 3 + 4 and 7 + 2 are one shape. A rule
   is named by its file and line, so rules of two files never collide. *)
let rec skeleton (node : Rhema_engine.node) =
  match node.Rhema_engine.applied_rule with
  | None -> "."
  | Some rule ->
      let position = rule.Rhema_ast.rule_position in
      Printf.sprintf "%s@%s:%d(%s)" node.Rhema_engine.symbol position.Rhema_ast.file
        position.Rhema_ast.line
        (node.Rhema_engine.children |> List.map skeleton |> String.concat ",")

(* An answer a student picks from a few codes: true/false, or a small whole
   number such as 0, 1, 2. Only these are balanced. *)
let coded_answer (question : Rhema_engine.question) =
  match question.Rhema_engine.answer with
  | Rhema_engine.Truth truth -> Some (if truth then "1" else "0")
  | Rhema_engine.Num number when Rhema_number.is_integer number ->
      let text = Rhema_number.to_string number in
      if String.length text <= 1 then Some text else None
  | _ -> None

(* ------------------------------------------------------------------ *)
(* Running a set                                                       *)
(* ------------------------------------------------------------------ *)

let question_name (target : Rhema_ast.set_question) =
  match target.Rhema_ast.sq_alias with
  | None -> target.Rhema_ast.sq_name
  | Some alias -> alias ^ "." ^ target.Rhema_ast.sq_name

(* The grammar a target names, with that question selected. *)
let grammar_of (spec : Rhema_check.spec) (target : Rhema_ast.set_question) =
  let base =
    match target.Rhema_ast.sq_alias with
    | None -> spec
    | Some alias -> (
        match List.assoc_opt alias spec.Rhema_check.imports with
        | Some module_spec -> module_spec
        | None -> error (Printf.sprintf "'%s' is not an imported module" alias))
  in
  match Rhema_check.select_question base target.Rhema_ast.sq_name with
  | Ok selected -> selected
  | Error message -> error message

let retries_per_question = 60

(* The questions a set asks for, in the order its entries list them, grouped
   into parts. *)
let plan (spec : Rhema_check.spec) (set : Rhema_ast.set_decl) =
  let items = set.Rhema_ast.set_items in
  let has_parts = List.exists (function Rhema_ast.Set_part _ -> true | _ -> false) items in
  (* Each entry becomes a list of (kind, grammar, budgets) slots. *)
  let slots_of (entry : Rhema_ast.set_entry) =
    let choices = entry.Rhema_ast.se_choices in
    let picks = evenly (List.init (List.length choices) Fun.id) entry.Rhema_ast.se_count in
    (* budgets are drawn per choice, over the slots that use it *)
    let per_choice =
      List.mapi
        (fun index choice ->
          let uses = List.length (List.filter (( = ) index) picks) in
          (index, (choice, ref (budgets_for choice.Rhema_ast.sq_draws uses))))
        choices
    in
    List.map
      (fun pick ->
        let choice, remaining = List.assoc pick per_choice in
        match !remaining with
        | budgets :: rest ->
            remaining := rest;
            (question_name choice, grammar_of spec choice, budgets)
        | [] -> error "internal: a choice ran out of budgets")
      picks
  in
  (* Group into parts: everything before the first `part` line is a leading
     part without heading; without any `part` line, each question stands
     alone under its own number. *)
  let parts = ref [] and current = ref (None, []) and started = ref false in
  List.iter
    (fun item ->
      match item with
      | Rhema_ast.Set_part (heading, _) ->
          if !started then parts := !current :: !parts;
          current := (heading, []);
          started := true
      | Rhema_ast.Set_entry entry ->
          let heading, members = !current in
          current := (heading, members @ slots_of entry);
          started := true
      | Rhema_ast.Set_distinct _ | Rhema_ast.Set_balanced _ | Rhema_ast.Set_ordered _ -> ())
    items;
  if !started then parts := !current :: !parts;
  let parts = List.rev !parts |> List.filter (fun (_, members) -> members <> []) in
  if has_parts then parts
  else List.concat_map (fun (_, members) -> List.map (fun slot -> (None, [ slot ])) members) parts

let run ?paper (spec : Rhema_check.spec) (set : Rhema_ast.set_decl) ~variant =
  let paper = Option.value ~default:set.Rhema_ast.set_name paper in
  let seed = variant in
  let items = set.Rhema_ast.set_items in
  let wants constraint_ = List.exists constraint_ items in
  let distinct = wants (function Rhema_ast.Set_distinct _ -> true | _ -> false) in
  let balanced = wants (function Rhema_ast.Set_balanced _ -> true | _ -> false) in
  let ordered = wants (function Rhema_ast.Set_ordered _ -> true | _ -> false) in
  (* All the set-level draws come from the set's seed, before any question. *)
  Random.init seed;
  let parts = plan spec set in
  (* `ordered`: easier first within a part. The order is settled before any
     question is generated, so the balance of answers is kept in the order
     the student reads. *)
  let total (_, _, budgets) = List.fold_left (fun sum (_, value) -> sum + value) 0 budgets in
  let parts =
    if ordered then
      List.map
        (fun (heading, slots) -> (heading, List.stable_sort (fun a b -> compare (total a) (total b)) slots))
        parts
    else parts
  in
  let seen_shapes = Hashtbl.create 32 in
  let recent_answers = ref [] in
  let index = ref 0 in
  let generate (kind, grammar, budgets) =
    let position = !index in
    incr index;
    let grammar =
      List.fold_left
        (fun grammar (attribute, value) ->
          match Rhema_check.with_initial grammar attribute value with
          | Ok grammar -> grammar
          | Error message -> error (Printf.sprintf "set '%s', %s: %s" set.Rhema_ast.set_name kind message))
        grammar budgets
    in
    let rec attempt remaining =
      if remaining <= 0 then
        error
          (Printf.sprintf
             "set '%s': question %d (%s) could not satisfy the set's constraints in %d attempts"
             set.Rhema_ast.set_name (position + 1) kind retries_per_question)
      else begin
        Random.init (Hashtbl.hash (seed, position, retries_per_question - remaining));
        let question = Rhema_engine.generate grammar in
        (* Two different questions are never repeats of each other, even
           when they are built on the same rules (seq.nth and seq.sum). *)
        let shape = kind ^ "|" ^ skeleton question.Rhema_engine.tree in
        let code = coded_answer question in
        let repeats_shape = distinct && Hashtbl.mem seen_shapes shape in
        let third_in_a_row =
          balanced
          &&
          match (code, !recent_answers) with
          | Some code, a :: b :: _ -> code = a && code = b
          | _ -> false
        in
        if repeats_shape || third_in_a_row then attempt (remaining - 1)
        else begin
          Hashtbl.replace seen_shapes shape ();
          (match code with Some code -> recent_answers := code :: !recent_answers | None -> ());
          (kind, budgets, question)
        end
      end
    in
    attempt retries_per_question
  in
  let generated = List.map (fun (heading, slots) -> (heading, List.map generate slots)) parts in
  let letter index = String.make 1 (Char.chr (Char.code 'a' + index)) in
  let parts =
    List.mapi
      (fun part_index (heading, members) ->
        let number = part_index + 1 in
        let several = List.length members > 1 in
        ( heading,
          List.mapi
            (fun member_index (kind, budgets, question) ->
              {
                label =
                  (if several then Printf.sprintf "%d(%s)" number (letter member_index)
                   else string_of_int number);
                part = number;
                heading;
                kind;
                budgets;
                question;
              })
            members ))
      generated
  in
  { name = set.Rhema_ast.set_name; paper; variant; parts }

let questions result = List.concat_map (fun (_, members) -> List.map (fun d -> d.question) members) result.parts

(* ------------------------------------------------------------------ *)
(* Reporting                                                           *)
(* ------------------------------------------------------------------ *)

let describe_budgets budgets =
  budgets |> List.map (fun (attribute, value) -> Printf.sprintf "%s %d" attribute value) |> String.concat ", "

(* The mean of each budget over a part: the statistic the expectation method
   of difficulty is about. *)
let means members =
  let attributes =
    members |> List.concat_map (fun d -> List.map fst d.budgets) |> List.sort_uniq compare
  in
  List.map
    (fun attribute ->
      let values = List.filter_map (fun d -> List.assoc_opt attribute d.budgets) members in
      let mean = Float.of_int (List.fold_left ( + ) 0 values) /. Float.of_int (max 1 (List.length values)) in
      (attribute, mean, List.length values))
    attributes

let listing result =
  let buffer = Buffer.create 4096 in
  Printf.bprintf buffer "%s: %d questions in %d part%s\n" result.paper
    (List.length (questions result)) (List.length result.parts)
    (if List.length result.parts = 1 then "" else "s");
  List.iter
    (fun (heading, members) ->
      (match (heading, members) with
      | Some heading, first :: _ -> Printf.bprintf buffer "\n%d. %s\n" first.part heading
      | None, first :: _ when List.length members > 1 -> Printf.bprintf buffer "\n%d.\n" first.part
      | _ -> ());
      List.iter
        (fun drawn ->
          Printf.bprintf buffer "%s%s  [%s%s]\n%s\n    %s: %s\n"
            (if List.length members > 1 then "  " else "\n")
            drawn.label drawn.kind
            (match drawn.budgets with [] -> "" | budgets -> "; " ^ describe_budgets budgets)
            drawn.question.Rhema_engine.prompt
            (if List.length drawn.question.Rhema_engine.answers > 1 then "answers" else "answer")
            drawn.question.Rhema_engine.answer_text)
        members)
    result.parts;
  Buffer.add_string buffer "\nbudget means:";
  List.iter
    (fun (heading, members) ->
      match members with
      | [] -> ()
      | first :: _ ->
          Printf.bprintf buffer "\n  part %d%s:" first.part
            (match heading with Some heading -> " " ^ heading | None -> "");
          List.iter
            (fun (attribute, mean, count) ->
              Printf.bprintf buffer " %s %.2f over %d" attribute mean count)
            (means members))
    result.parts;
  Buffer.add_char buffer '\n';
  Buffer.contents buffer

(* The whole set as one PG document: numbered questions, lettered parts,
   headings as paragraphs, one PGML block per run of equal contexts. *)
let document result =
  let items =
    result.parts
    |> List.concat_map (fun (heading, members) ->
           List.mapi
             (fun index drawn ->
               {
                 Rhema_pgml.label = drawn.label ^ ".";
                 heading = (if index = 0 then heading else None);
                 question = drawn.question;
               })
             members)
  in
  Rhema_pgml.document_items items

(* One PG document per question, named by its position. *)
let documents result =
  questions result
  |> List.mapi (fun index question ->
         (Printf.sprintf "question%02d.pg" (index + 1), Rhema_pgml.document [ question ]))
