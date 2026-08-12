open Ast

exception Grammar_error of string

type distribution =
  | Copy
  | Split

type attribute_decl = {
  name : string;
  initial : int;
  distribution : distribution;
}

type comparison =
  | Equal
  | Greater
  | Greater_equal

type guard = {
  attribute : string;
  comparison : comparison;
  value : int;
}

type rule = {
  lhs : string;
  rhs : string list;
  updates : (string * int) list;
  guard : guard option;
  weight : int;
}

type specification = {
  attributes : attribute_decl list;
  start : string;
  rules : rule list;
}

type environment = (string * int) list

type tree =
  | Node of string * rule * tree list
  | Leaf of string * environment

let trim = String.trim

let starts_with text prefix =
  let text_len = String.length text in
  let prefix_len = String.length prefix in
  text_len >= prefix_len && String.sub text 0 prefix_len = prefix

let split_words text =
  text
  |> String.split_on_char ' '
  |> List.filter (fun part -> part <> "")

let split_once text separator =
  match String.index_opt text separator with
  | None -> raise (Grammar_error ("Expected '" ^ String.make 1 separator ^ "' in: " ^ text))
  | Some index ->
      let left = String.sub text 0 index |> trim in
      let right =
        String.sub text (index + 1) (String.length text - index - 1) |> trim
      in
      (left, right)

let int_of_text context text =
  try int_of_string (trim text)
  with Failure _ -> raise (Grammar_error ("Expected an integer for " ^ context ^ ": " ^ text))

let remove_comment line =
  match String.index_opt line '#' with
  | None -> line
  | Some index -> String.sub line 0 index

let parse_attribute line =
  let body = String.sub line 10 (String.length line - 10) |> trim in
  let name, value_and_mode = split_once body '=' in
  let parts = split_words value_and_mode in
  match parts with
  | [value] ->
      { name; initial = int_of_text name value; distribution = Copy }
  | [value; "copy"] ->
      { name; initial = int_of_text name value; distribution = Copy }
  | [value; "split"] ->
      { name; initial = int_of_text name value; distribution = Split }
  | _ ->
      raise
        (Grammar_error
           ("Attribute syntax is: attribute NAME = INTEGER [copy|split]: " ^ line))

let find_substring text needle start_index =
  let text_len = String.length text in
  let needle_len = String.length needle in
  let rec search index =
    if index + needle_len > text_len then None
    else if String.sub text index needle_len = needle then Some index
    else search (index + 1)
  in
  search start_index

let parse_updates text =
  let text = trim text in
  if text = "" then []
  else
    text
    |> String.split_on_char ','
    |> List.map (fun update ->
           let name, delta = split_once update '=' in
           (name, int_of_text ("update " ^ name) delta))

let parse_guard text =
  match split_words text with
  | [attribute; "="; value] ->
      { attribute; comparison = Equal; value = int_of_text attribute value }
  | [attribute; ">"; value] ->
      { attribute; comparison = Greater; value = int_of_text attribute value }
  | [attribute; ">="; value] ->
      { attribute; comparison = Greater_equal; value = int_of_text attribute value }
  | _ ->
      raise (Grammar_error ("Guard syntax is: when NAME (=|>|>=) INTEGER: " ^ text))

let parse_rule line =
  let arrow =
    match find_substring line "->" 0 with
    | Some index -> index
    | None -> raise (Grammar_error ("Missing '->' in rule: " ^ line))
  in
  let open_brace =
    match String.index_opt line '{' with
    | Some index -> index
    | None -> raise (Grammar_error ("Missing '{' in rule: " ^ line))
  in
  let close_brace =
    match String.index_opt line '}' with
    | Some index when index > open_brace -> index
    | _ -> raise (Grammar_error ("Missing '}' in rule: " ^ line))
  in
  let lhs = String.sub line 0 arrow |> trim in
  let rhs =
    String.sub line (arrow + 2) (open_brace - arrow - 2)
    |> trim
    |> split_words
  in
  let updates =
    String.sub line (open_brace + 1) (close_brace - open_brace - 1)
    |> parse_updates
  in
  let suffix =
    String.sub line (close_brace + 1) (String.length line - close_brace - 1)
    |> trim
  in
  let suffix_words = split_words suffix in
  let guard, weight =
    match suffix_words with
    | [] -> (None, 1)
    | ["weight"; weight] -> (None, int_of_text "weight" weight)
    | ["when"; name; operator; value] ->
        (Some (parse_guard (String.concat " " [name; operator; value])), 1)
    | ["when"; name; operator; value; "weight"; weight] ->
        ( Some (parse_guard (String.concat " " [name; operator; value])),
          int_of_text "weight" weight )
    | _ ->
        raise
          (Grammar_error
             ("Rule suffix is: [when NAME OP INTEGER] [weight INTEGER]: " ^ line))
  in
  { lhs; rhs; updates; guard; weight }

let validate specification =
  let attribute_names =
    List.map (fun declaration -> declaration.name) specification.attributes
  in
  let ensure_attribute name context =
    if not (List.mem name attribute_names) then
      raise (Grammar_error ("Unknown attribute '" ^ name ^ "' in " ^ context))
  in
  if specification.attributes = [] then
    raise (Grammar_error "At least one attribute must be declared");
  if not (List.exists (fun rule -> rule.lhs = specification.start) specification.rules) then
    raise (Grammar_error ("No rules found for start symbol " ^ specification.start));
  List.iter
    (fun declaration ->
      if declaration.initial < 0 then
        raise (Grammar_error ("Attribute " ^ declaration.name ^ " cannot start negative")))
    specification.attributes;
  List.iter
    (fun rule ->
      if rule.lhs = "" || rule.rhs = [] then
        raise (Grammar_error "Rules need a left-hand side and a non-empty right-hand side");
      if rule.weight <= 0 then
        raise (Grammar_error ("Rule weight must be positive for " ^ rule.lhs));
      List.iter
        (fun (name, delta) ->
          ensure_attribute name ("rule " ^ rule.lhs);
          if delta > 0 then
            raise
              (Grammar_error
                 ("Attribute updates consume budgets and must be <= 0: " ^ name)))
        rule.updates;
      match rule.guard with
      | None -> ()
      | Some guard -> ensure_attribute guard.attribute ("guard for " ^ rule.lhs))
    specification.rules

let parse text =
  let attributes = ref [] in
  let start = ref None in
  let rules = ref [] in
  text
  |> String.split_on_char '\n'
  |> List.iteri (fun index raw_line ->
         let line = raw_line |> remove_comment |> trim in
         if line <> "" then
           try
             if starts_with line "attribute " then
               attributes := parse_attribute line :: !attributes
             else if starts_with line "start " then
               start := Some (String.sub line 6 (String.length line - 6) |> trim)
             else
               rules := parse_rule line :: !rules
           with Grammar_error message ->
             raise
               (Grammar_error
                  (Printf.sprintf "Line %d: %s" (index + 1) message)));
  let start =
    match !start with
    | Some symbol when symbol <> "" -> symbol
    | _ -> raise (Grammar_error "A 'start SYMBOL' declaration is required")
  in
  let specification =
    {
      attributes = List.rev !attributes;
      start;
      rules = List.rev !rules;
    }
  in
  validate specification;
  specification

let value_of environment name =
  match List.assoc_opt name environment with
  | Some value -> value
  | None -> raise (Grammar_error ("Attribute is missing from environment: " ^ name))

let set_value environment name value =
  (name, value) :: List.remove_assoc name environment

let initial_environment specification =
  List.map
    (fun declaration -> (declaration.name, declaration.initial))
    specification.attributes

let guard_holds environment = function
  | None -> true
  | Some guard ->
      let actual = value_of environment guard.attribute in
      (match guard.comparison with
       | Equal -> actual = guard.value
       | Greater -> actual > guard.value
       | Greater_equal -> actual >= guard.value)

let apply_updates environment updates =
  List.fold_left
    (fun current (name, delta) ->
      let next = value_of current name + delta in
      if next < 0 then
        raise (Grammar_error ("Attribute budget became negative: " ^ name));
      set_value current name next)
    environment updates

let weighted_pick rules =
  let total = List.fold_left (fun sum rule -> sum + rule.weight) 0 rules in
  let target = Random.int total in
  let rec choose offset = function
    | [] -> raise (Grammar_error "Cannot select from an empty rule list")
    | rule :: rest ->
        if target < offset + rule.weight then rule
        else choose (offset + rule.weight) rest
  in
  choose 0 rules

let random_partition total count =
  if count <= 0 then []
  else
    let rec build remaining slots accumulator =
      if slots = 1 then List.rev (remaining :: accumulator)
      else
        let part = Random.int (remaining + 1) in
        build (remaining - part) (slots - 1) (part :: accumulator)
    in
    let parts = build total count [] |> Array.of_list in
    for index = Array.length parts - 1 downto 1 do
      let other = Random.int (index + 1) in
      let temporary = parts.(index) in
      parts.(index) <- parts.(other);
      parts.(other) <- temporary
    done;
    Array.to_list parts

let generate_tree specification ~terminal =
  let nonterminals =
    specification.rules
    |> List.map (fun rule -> rule.lhs)
    |> List.sort_uniq String.compare
  in
  let is_nonterminal symbol = List.mem symbol nonterminals in
  let fuel = ref 10000 in
  let rec expand symbol environment =
    decr fuel;
    if !fuel < 0 then
      raise (Grammar_error "Generation exceeded its safety limit");
    if not (is_nonterminal symbol) then
      Leaf (terminal symbol environment, environment)
    else
      let candidates =
        specification.rules
        |> List.filter (fun rule ->
               rule.lhs = symbol
               && guard_holds environment rule.guard
               &&
               try
                 ignore (apply_updates environment rule.updates);
                 true
               with Grammar_error _ -> false)
      in
      if candidates = [] then (
        let budgets =
          environment
          |> List.map (fun (name, value) -> name ^ "=" ^ string_of_int value)
          |> String.concat ", "
        in
        raise
          (Grammar_error
             ("No applicable rule for " ^ symbol ^ " with {" ^ budgets ^ "}"))
      );
      let rule = weighted_pick candidates in
      let updated = apply_updates environment rule.updates in
      let expandable_positions =
        rule.rhs
        |> List.mapi (fun index child -> (index, child))
        |> List.filter (fun (_, child) -> is_nonterminal child)
      in
      let child_environments =
        List.map (fun _ -> updated) expandable_positions |> Array.of_list
      in
      List.iter
        (fun declaration ->
          match declaration.distribution with
          | Copy -> ()
          | Split ->
              let total = value_of updated declaration.name in
              let shares = random_partition total (Array.length child_environments) in
              List.iteri
                (fun index share ->
                  child_environments.(index) <-
                    set_value child_environments.(index) declaration.name share)
                shares)
        specification.attributes;
      let next_environment index =
        let rec find child_index = function
          | [] -> updated
          | (position, _) :: rest ->
              if position = index then child_environments.(child_index)
              else find (child_index + 1) rest
        in
        find 0 expandable_positions
      in
      let children =
        List.mapi
          (fun index child -> expand child (next_environment index))
          rule.rhs
      in
      Node (symbol, rule, children)
  in
  expand specification.start (initial_environment specification)

let arithmetic_specification = {|
# Structural budget is divided between expression children.
attribute len = 2 split
# Digit budget is inherited unchanged by every numeric leaf.
attribute digit = 2 copy

start E

E -> E + E { len = -1 } when len > 0 weight 3
E -> E - E { len = -1 } when len > 0 weight 3
E -> E * E { len = -1 } when len > 0 weight 2
E -> E / E { len = -1 } when len > 0 weight 1
E -> num { len = -0 } when len = 0 weight 1

num -> integer { digit = -0 } when digit > 0 weight 1
|}

let with_initial specification name value =
  if value < 0 then
    raise (Grammar_error ("Initial attribute cannot be negative: " ^ name));
  if not (List.exists (fun declaration -> declaration.name = name) specification.attributes)
  then raise (Grammar_error ("Unknown initial attribute: " ^ name));
  {
    specification with
    attributes =
      List.map
        (fun declaration ->
          if declaration.name = name then { declaration with initial = value }
          else declaration)
        specification.attributes;
  }

let read_file filename =
  let channel = open_in filename in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))

let load_arithmetic_specification () =
  let explicit = Sys.getenv_opt "ATTRIBUTE_GRAMMAR_FILE" in
  let candidates =
    match explicit with
    | Some filename -> [filename]
    | None -> ["arithmetic.ag"; Filename.concat "generator" "arithmetic.ag"]
  in
  match List.find_opt Sys.file_exists candidates with
  | Some filename -> parse (read_file filename)
  | None -> parse arithmetic_specification

let digits_of environment =
  match List.assoc_opt "digit" environment with
  | Some value -> max 1 value
  | None -> 1

let generate_integer digits =
  if digits <= 1 then Random.int 10
  else
    let rec power_of_ten accumulator exponent =
      if exponent <= 0 then accumulator
      else power_of_ten (accumulator * 10) (exponent - 1)
    in
    let lower = power_of_ten 1 (digits - 1) in
    let upper = power_of_ten 1 digits - 1 in
    lower + Random.int (upper - lower + 1)

let rec expression_of_tree = function
  | Node ("E", _, [left; Leaf ("+", _); right]) ->
      ME_Add (expression_of_tree left, term_with_parentheses right)
  | Node ("E", _, [left; Leaf ("-", _); right]) ->
      ME_Sub (expression_of_tree left, term_with_parentheses right)
  | Node ("E", _, [left; Leaf ("*", _); right]) ->
      ME_Term (T_Mul (term_with_parentheses left, factor_of_tree right))
  | Node ("E", _, [left; Leaf ("/", _); right]) ->
      ME_Term (T_Div (term_with_parentheses left, factor_of_tree right))
  | Node ("E", _, [number]) ->
      ME_Term (T_Fac (factor_of_tree number))
  | tree ->
      raise (Grammar_error ("Cannot lower generated tree node to math_expr: " ^ tree_name tree))

and term_with_parentheses tree =
  match tree with
  | Node ("E", _, [Node ("num", _, _) as number]) -> T_Fac (factor_of_tree number)
  | _ -> T_Fac (F_Paren (expression_of_tree tree))

and factor_of_tree = function
  | Node ("num", _, [Leaf (number, _)]) ->
      if String.contains number '.' then F_Num (float_of_string number)
      else F_Int (int_of_string number)
  | tree -> F_Paren (expression_of_tree tree)

and tree_name = function
  | Node (name, _, _) -> name
  | Leaf (name, _) -> name

let rec evaluate_math_expr = function
  | ME_Add (left, right) -> evaluate_math_expr left +. evaluate_term right
  | ME_Sub (left, right) -> evaluate_math_expr left -. evaluate_term right
  | ME_Term term -> evaluate_term term

and evaluate_term = function
  | T_Mul (left, right) -> evaluate_term left *. evaluate_factor right
  | T_Div (left, right) ->
      let denominator = evaluate_factor right in
      if denominator = 0.0 then raise Division_by_zero;
      evaluate_term left /. denominator
  | T_Fac factor -> evaluate_factor factor

and evaluate_factor = function
  | F_Paren expression -> evaluate_math_expr expression
  | F_Num number -> number
  | F_Int number -> float_of_int number

let generate_math_expr ?specification ?digit ~len ~allow_float () =
  let base =
    match specification with
    | Some specification -> specification
    | None -> load_arithmetic_specification ()
  in
  let specification = with_initial base "len" len in
  let specification =
    match digit with
    | Some value -> with_initial specification "digit" value
    | None -> specification
  in
  let terminal symbol environment =
    match symbol with
    | "integer" ->
        let number = generate_integer (digits_of environment) in
        if allow_float && Random.bool () then
          Printf.sprintf "%.2f" (float_of_int number +. Random.float 1.0)
        else string_of_int number
    | token -> token
  in
  let rec attempt remaining_attempts =
    if remaining_attempts <= 0 then
      raise (Grammar_error "Could not generate an expression without division by zero");
    let expression =
      generate_tree specification ~terminal |> expression_of_tree
    in
    try
      ignore (evaluate_math_expr expression);
      expression
    with Division_by_zero -> attempt (remaining_attempts - 1)
  in
  attempt 100

let rec operator_count_math_expr = function
  | ME_Add (left, right) | ME_Sub (left, right) ->
      1 + operator_count_math_expr left + operator_count_term right
  | ME_Term term -> operator_count_term term

and operator_count_term = function
  | T_Mul (left, right) | T_Div (left, right) ->
      1 + operator_count_term left + operator_count_factor right
  | T_Fac factor -> operator_count_factor factor

and operator_count_factor = function
  | F_Paren expression -> operator_count_math_expr expression
  | F_Num _ | F_Int _ -> 0
