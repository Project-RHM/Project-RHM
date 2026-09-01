(* ag_engine.ml — generate a question from a checked .ag specification.

   Generation is a single recursive walk that carries information in both
   directions, which is exactly the two-pass model the checker enforces:

     going down   inherited attributes (len, digit) choose the shape
     coming back  synthesized attributes (value, latex) compute the result

   Because a node's synthesized attributes depend only on its children, they
   are evaluated as soon as those children are built. A [require] clause is
   therefore checked while the engine is still standing at that node, so a
   violation retries just that subtree instead of discarding the whole
   expression and starting over. *)

open Ag_ast

exception Generation_error of string

let error message = raise (Generation_error message)

(* ------------------------------------------------------------------ *)
(* Runtime values                                                      *)
(* ------------------------------------------------------------------ *)

type value =
  | Num of Ag_number.t
  | Text of string
  | Truth of bool
  | Complex of Ag_number.t * Ag_number.t

let describe_value = function
  | Num number -> Ag_number.to_string number
  | Text text -> text
  | Truth true -> "true"
  | Truth false -> "false"
  | Complex (real, imaginary) ->
      Printf.sprintf "Complex(%s,%s)" (Ag_number.to_string real)
        (Ag_number.to_string imaginary)

let as_number context = function
  | Num number -> number
  | other ->
      error
        (Printf.sprintf "%s expected a number but received \"%s\"" context
           (describe_value other))

let as_text context = function
  | Text text -> text
  | Num number -> Ag_number.to_string number
  | Truth _ | Complex _ ->
      error
        (Printf.sprintf "%s expected text but received a non-text value" context)

let as_truth context = function
  | Truth truth -> truth
  | other ->
      error
        (Printf.sprintf "%s expected a true/false value but received \"%s\"" context
           (describe_value other))

let format_complex_latex real imaginary =
  let zero = Ag_number.zero and one = Ag_number.of_int 1 in
  let real_is_zero = Ag_number.equal real zero in
  let imaginary_is_zero = Ag_number.equal imaginary zero in
  let imaginary_is_negative = Ag_number.compare imaginary zero < 0 in
  let magnitude = Ag_number.absolute imaginary in
  let imaginary_term =
    if Ag_number.equal magnitude one then "i"
    else Ag_number.to_string magnitude ^ "i"
  in
  if imaginary_is_zero then Ag_number.to_string real
  else if real_is_zero then
    (if imaginary_is_negative then "-" else "") ^ imaginary_term
  else
    Ag_number.to_string real
    ^ (if imaginary_is_negative then " - " else " + ")
    ^ imaginary_term

(* ------------------------------------------------------------------ *)
(* Generated trees                                                     *)
(* ------------------------------------------------------------------ *)

(* [level] is the binding strength of the operator a node was built with,
   taken from the grammar's precedence table. Leaves, and rules that name no
   declared operator, are atoms and never need parentheses around them. *)
let atom_level = max_int

type node = {
  symbol : string;
  applied_rule : rule option;
  children : node list;
  inherited_attributes : (string * int) list;
  attributes : (string * value) list;
  level : int;
}

let attribute node name =
  match List.assoc_opt name node.attributes with
  | Some value -> value
  | None ->
      error
        (Printf.sprintf "'%s' has no attribute '%s'%s" node.symbol name
           (if node.applied_rule = None then
              " — it is a leaf, which carries only 'value'; write str($n.value) to \
               render it"
            else ""))

(* How much a budget was decreased across the whole tree. The tests use this to
   confirm that a budget of n really does produce n operators. *)
let rec consumption node name =
  let here =
    match node.applied_rule with
    | None -> 0
    | Some rule ->
        List.fold_left
          (fun total equation ->
            match equation with
            | Assign (assigned, Unary ("-", Int amount), _) when assigned = name ->
                total + amount
            | Assign (assigned, Int amount, _) when assigned = name && amount < 0 ->
                total - amount
            | _ -> total)
          0 rule.equations
  in
  List.fold_left (fun total child -> total + consumption child name) here node.children

(* ------------------------------------------------------------------ *)
(* Budgets                                                             *)
(* ------------------------------------------------------------------ *)

type environment = (string * int) list

let lookup environment name =
  match List.assoc_opt name environment with
  | Some value -> value
  | None -> error (Printf.sprintf "attribute '%s' is not in scope" name)

let bind environment name value = (name, value) :: List.remove_assoc name environment

(* Every random decision that could have gone another way bumps this counter.
   The retry loops compare it before and after a failed attempt: if nothing
   was drawn, the exact same failure would repeat forever, so they stop
   immediately instead of burning the remaining retries. A draw whose range
   holds a single value does not count — it could not have gone differently. *)
let choice_points = ref 0

let chose () = incr choice_points

(* Tag a failure message as unfixable-by-retry, once, no matter how many
   retry loops it bubbles up through on the way out. *)
let deterministic_tag = "; retrying cannot help, no random choice was involved"

let mark_deterministic message =
  let tag_length = String.length deterministic_tag in
  let message_length = String.length message in
  if
    message_length >= tag_length
    && String.sub message (message_length - tag_length) tag_length = deterministic_tag
  then message
  else message ^ deterministic_tag

(* Split [total] into [count] non-negative parts, uniformly across every way of
   doing so. Drawing each part in turn and shuffling, as an earlier version
   did, favours lopsided splits once there are more than two parts. *)
let random_partition total count =
  if count <= 0 then []
  else if count = 1 then [ total ]
  else begin
    if total > 0 then chose ();
    (* Stars and bars: pick count-1 distinct bar positions among
       total + count - 1 slots; the gaps between the bars are the parts. *)
    let slots = total + count - 1 in
    let bars = Array.make (count - 1) 0 in
    let chosen = Hashtbl.create (count - 1) in
    for index = 0 to count - 2 do
      let rec draw () =
        let candidate = Random.int slots in
        if Hashtbl.mem chosen candidate then draw ()
        else (
          Hashtbl.add chosen candidate ();
          candidate)
      in
      bars.(index) <- draw ()
    done;
    Array.sort Stdlib.compare bars;
    let parts = Array.make count 0 in
    let previous = ref (-1) in
    for index = 0 to count - 2 do
      parts.(index) <- bars.(index) - !previous - 1;
      previous := bars.(index)
    done;
    parts.(count - 1) <- slots - !previous - 1;
    Array.to_list parts
  end

let weighted_pick rules =
  let total = List.fold_left (fun sum rule -> sum + rule.weight) 0 rules in
  if total <= 0 then error "no candidate rule has a positive weight";
  if List.length rules > 1 then chose ();
  let target = Random.int total in
  let rec choose offset = function
    | [] -> error "internal: ran off the end of the candidate list"
    | rule :: rest ->
        if target < offset + rule.weight then rule else choose (offset + rule.weight) rest
  in
  choose 0 rules

let draw_integer digits =
  chose ();
  if digits <= 1 then Random.int 10
  else
    let rec power_of_ten accumulator exponent =
      if exponent <= 0 then accumulator
      else power_of_ten (accumulator * 10) (exponent - 1)
    in
    let lower = power_of_ten 1 (digits - 1) in
    let upper = (power_of_ten 1 digits) - 1 in
    lower + Random.int (upper - lower + 1)

let draw_integer_between name lower upper =
  if lower > upper then
    error
      (Printf.sprintf "%s lower bound %d is greater than upper bound %d" name lower
         upper);
  let width = upper - lower + 1 in
  if width <= 0 then error (Printf.sprintf "%s range is too wide" name);
  if width > 1 then chose ();
  lower + Random.int width

let draw_nonzero_integer_between lower upper =
  if lower > upper then
    error
      (Printf.sprintf
         "nonzero_integer_between lower bound %d is greater than upper bound %d"
         lower upper);
  if lower = 0 && upper = 0 then
    error "nonzero_integer_between(0, 0) has no non-zero value to draw";
  if upper < 0 || lower > 0 then
    draw_integer_between "nonzero_integer_between" lower upper
  else
    let negative_count = -lower in
    let positive_count = upper in
    if negative_count + positive_count > 1 then chose ();
    let choice = Random.int (negative_count + positive_count) in
    if choice < negative_count then lower + choice
    else 1 + (choice - negative_count)

let draw_generator name arguments =
  match (name, arguments) with
  | "integer", [ digits ] -> draw_integer digits
  | "nonzero_integer", [ digits ] ->
      let rec attempt remaining =
        if remaining <= 0 then error "nonzero_integer could not find a value"
        else
          let candidate = draw_integer digits in
          if candidate = 0 then attempt (remaining - 1) else candidate
      in
      attempt 50
  | "integer_between", [ lower; upper ] ->
      draw_integer_between name lower upper
  | "nonzero_integer_between", [ lower; upper ] ->
      draw_nonzero_integer_between lower upper
  | _ ->
      error
        (Printf.sprintf "cannot apply generator '%s' to %d argument(s)" name
           (List.length arguments))

(* ------------------------------------------------------------------ *)
(* Evaluating the right-hand side of an equation                       *)
(* ------------------------------------------------------------------ *)

(* [target] is the attribute currently being computed. [infix] renders its
   operands with that same attribute, so `latex = infix($1, "+", $3)` joins the
   children's `latex`, and a grammar that names its rendering attribute
   something else behaves identically without the engine hard-coding a name. *)
let rec evaluate ?(self = []) ~globals ~is_inherited ~rule_precedence ~environment
    ~children ~rule ~target expression =
  let recurse =
    evaluate ~self ~globals ~is_inherited ~rule_precedence ~environment ~children ~rule
      ~target
  in
  let child_at index =
    match List.nth_opt children (index - 1) with
    | Some node -> node
    | None ->
        error
          (Printf.sprintf "$%d is out of range: this rule has %d symbols on the right"
             index (List.length children))
  in
  let node_argument context = function
    | Child index -> child_at index
    | _ ->
        error
          (Printf.sprintf "%s needs its operands written as $n, for example %s($1, \"+\", $3)"
             context context)
  in
  match expression with
  | Int number -> Num (Ag_number.of_int number)
  | Str text -> Text text
  | Attr_here name -> (
      (* An attribute this rule computed earlier wins, so a rule can build on
         its own work; then a question-level random or let. The checker has
         already made sure those two sets of names do not overlap. *)
      match List.assoc_opt name self with
      | Some value -> value
      | None -> (
          match List.assoc_opt name globals with
          | Some value -> value
          | None ->
              if is_inherited name then Num (Ag_number.of_int (lookup environment name))
              else error (Printf.sprintf "'%s' is not in scope" name)))
  | Attr_child (index, name) -> attribute (child_at index) name
  | Attr_child_named (owner, name) ->
      error
        (Printf.sprintf "%s.%s cannot be used inside a rule; write $n.%s instead" owner
           name name)
  | Child index ->
      error
        (Printf.sprintf
           "$%d is a node, not a value; write $%d.value, or pass it to infix()" index
           index)
  | Unary ("-", body) -> Num (Ag_number.negate (as_number "-" (recurse body)))
  | Unary ("not", body) -> Truth (not (as_truth "not" (recurse body)))
  | Unary (operator, _) -> error (Printf.sprintf "unknown operator '%s'" operator)
  | Binary ("and", left, right) ->
      Truth (as_truth "and" (recurse left) && as_truth "and" (recurse right))
  | Binary ("or", left, right) ->
      Truth (as_truth "or" (recurse left) || as_truth "or" (recurse right))
  | Binary ("++", left, right) ->
      Text (as_text "++" (recurse left) ^ as_text "++" (recurse right))
  | Binary (operator, left, right) -> (
      let left = recurse left and right = recurse right in
      let arithmetic apply = Num (apply (as_number operator left) (as_number operator right)) in
      let comparison apply =
        match (left, right) with
        | Text left, Text right ->
            if operator = "=" then Truth (left = right)
            else if operator = "!=" then Truth (left <> right)
            else error (Printf.sprintf "'%s' cannot compare text" operator)
        (* Equality on truth values is how a biconditional is written, and
           inequality is exclusive or. *)
        | Truth left, Truth right ->
            if operator = "=" then Truth (left = right)
            else if operator = "!=" then Truth (left <> right)
            else
              error
                (Printf.sprintf "'%s' cannot order true/false values" operator)
        | Complex (left_real, left_imaginary), Complex (right_real, right_imaginary) ->
            let equal =
              Ag_number.equal left_real right_real
              && Ag_number.equal left_imaginary right_imaginary
            in
            if operator = "=" then Truth equal
            else if operator = "!=" then Truth (not equal)
            else error (Printf.sprintf "'%s' cannot order complex values" operator)
        | _ ->
            Truth
              (apply
                 (Ag_number.compare (as_number operator left) (as_number operator right)))
      in
      match operator with
      | "+" -> arithmetic Ag_number.add
      | "-" -> arithmetic Ag_number.subtract
      | "*" -> arithmetic Ag_number.multiply
      | "/" -> arithmetic Ag_number.divide
      | "%" -> arithmetic Ag_number.modulo
      | "^" -> arithmetic Ag_number.power
      | "=" -> comparison (fun result -> result = 0)
      | "!=" -> comparison (fun result -> result <> 0)
      | "<" -> comparison (fun result -> result < 0)
      | "<=" -> comparison (fun result -> result <= 0)
      | ">" -> comparison (fun result -> result > 0)
      | ">=" -> comparison (fun result -> result >= 0)
      | _ -> error (Printf.sprintf "unknown operator '%s'" operator))
  | Call ("infix", [ left; operator; right ]) ->
      let left = node_argument "infix" left and right = node_argument "infix" right in
      let operator = as_text "infix" (recurse operator) in
      let my_level, associativity =
        match rule with
        | Some rule -> (
            match rule_precedence rule with
            | Some (_, level, associativity) -> (level, associativity)
            | None -> (atom_level, Left))
        | None -> (atom_level, Left)
      in
      let render node ~is_left =
        let text = as_text "infix" (attribute node target) in
        let needs_parentheses =
          node.level < my_level
          || node.level = my_level
             && (match associativity with
                | Nonassoc -> true
                | Left -> not is_left
                | Right -> is_left)
        in
        if needs_parentheses then "(" ^ text ^ ")" else text
      in
      Text
        (String.concat " " [ render left ~is_left:true; operator; render right ~is_left:false ])
  | Call ("prefix", [ operator; operand ]) ->
      let operand = node_argument "prefix" operand in
      let operator = as_text "prefix" (recurse operator) in
      let my_level =
        match rule with
        | Some rule -> (
            match rule_precedence rule with
            | Some (_, level, _) -> level
            | None -> atom_level)
        | None -> atom_level
      in
      let text = as_text "prefix" (attribute operand target) in
      (* A prefix operator binds looser than anything tighter than itself, so
         its operand needs brackets only when the operand binds less tightly. *)
      Text (operator ^ " " ^ (if operand.level < my_level then "(" ^ text ^ ")" else text))
  | Call ("cond", [ test; consequence; alternative ]) ->
      if as_truth "cond" (recurse test) then recurse consequence
      else recurse alternative
  | Call ("paren", [ body ]) -> Text ("(" ^ as_text "paren" (recurse body) ^ ")")
  | Call ("str", [ body ]) -> Text (as_text "str" (recurse body))
  | Call ("complex", [ real; imaginary ]) ->
      Complex
        (as_number "complex" (recurse real), as_number "complex" (recurse imaginary))
  | Call ("complex_latex", [ real; imaginary ]) ->
      Text
        (format_complex_latex
           (as_number "complex_latex" (recurse real))
           (as_number "complex_latex" (recurse imaginary)))
  | Call (("bit_and" | "bit_or" | "bit_xor") as operation, [ left; right ]) ->
      let whole name value =
        Ag_number.require_integer name (as_number name value)
      in
      let left = whole operation (recurse left)
      and right = whole operation (recurse right) in
      Num
        (Ag_number.of_int
           (match operation with
           | "bit_and" -> left land right
           | "bit_or" -> left lor right
           | _ -> left lxor right))
  | Call ("abs", [ body ]) -> Num (Ag_number.absolute (as_number "abs" (recurse body)))
  | Call ("min", [ left; right ]) ->
      let left = as_number "min" (recurse left) and right = as_number "min" (recurse right) in
      Num (if Ag_number.compare left right <= 0 then left else right)
  | Call ("max", [ left; right ]) ->
      let left = as_number "max" (recurse left) and right = as_number "max" (recurse right) in
      Num (if Ag_number.compare left right >= 0 then left else right)
  | Call (name, arguments) ->
      error (Printf.sprintf "cannot apply '%s' to %d argument(s)" name (List.length arguments))

(* ------------------------------------------------------------------ *)
(* Generation                                                          *)
(* ------------------------------------------------------------------ *)

exception Requirement_failed of string

type question = {
  prompt : string;
  answer : value;
  answer_text : string;
  globals : (string * value) list;
  tree : node;
}

let retries_per_node = 40
let retries_per_question = 200

let generate_tree (spec : Ag_check.spec) ~globals =
  let open Ag_check in
  let nonterminals =
    spec.rules |> List.map (fun rule -> rule.lhs) |> List.sort_uniq String.compare
  in
  let is_nonterminal name = List.mem name nonterminals in
  let inherited_names = List.map (fun a -> a.attribute_name) spec.inherited in
  let is_inherited name = List.mem name inherited_names in
  let rule_precedence rule =
    List.fold_left
      (fun found symbol ->
        match found with
        | Some _ -> found
        | None ->
            List.find_opt
              (fun (name, _, _) -> name = symbol_name symbol)
              spec.precedences)
      None rule.rhs
  in
  let evaluate_in ?(self = []) ~environment ~children ~rule ~target expression =
    evaluate ~self ~globals ~is_inherited ~rule_precedence ~environment ~children ~rule
      ~target expression
  in
  (* Budget updates are applied before any child exists, so they may only read
     inherited attributes. The checker has already guaranteed that. *)
  let apply_updates environment rule =
    List.fold_left
      (fun current equation ->
        match equation with
        | Assign (name, body, _) when is_inherited name ->
            let delta =
              match
                evaluate_in ~environment:current ~children:[] ~rule:None ~target:name body
              with
              | Num number when Ag_number.is_integer number ->
                  Ag_number.require_integer name number
              | other ->
                  error
                    (Printf.sprintf "budget '%s' must change by a whole number, not \"%s\""
                       name (describe_value other))
            in
            let next = lookup current name + delta in
            if next < 0 then
              error (Printf.sprintf "budget '%s' would go negative" name);
            bind current name next
        | _ -> current)
      environment rule.equations
  in
  let guard_holds environment rule =
    match rule.guard with
    | None -> true
    | Some condition -> (
        match
          evaluate_in ~environment ~children:[] ~rule:None ~target:"" condition
        with
        | Truth truth -> truth
        | other ->
            error
              (Printf.sprintf "a 'when' condition must be true or false, but gave \"%s\""
                 (describe_value other)))
  in
  let fuel = ref 200_000 in
  let spend () =
    decr fuel;
    if !fuel <= 0 then error "generation exceeded its safety limit"
  in

  let rec expand_symbol symbol environment =
    spend ();
    match symbol with
    | Generator (name, arguments) ->
        let argument index =
          match List.nth_opt arguments index with
          | Some expression -> (
              match
                evaluate_in ~environment ~children:[] ~rule:None ~target:"" expression
              with
              | Num number -> Ag_number.require_integer name number
              | other ->
                  error
                    (Printf.sprintf "%s expects a whole number, but received \"%s\"" name
                       (describe_value other)))
          | None -> error (Printf.sprintf "%s is missing an argument" name)
        in
        let drawn =
          arguments |> List.mapi (fun index _ -> argument index) |> draw_generator name
        in
        {
          symbol = name;
          applied_rule = None;
          children = [];
          inherited_attributes = [];
          attributes = [ ("value", Num (Ag_number.of_int drawn)) ];
          level = atom_level;
        }
    | Literal text ->
        {
          symbol = text;
          applied_rule = None;
          children = [];
          inherited_attributes = [];
          attributes = [ ("value", Text text) ];
          level = atom_level;
        }
    | Symbol name when not (is_nonterminal name) ->
        {
          symbol = name;
          applied_rule = None;
          children = [];
          inherited_attributes = [];
          attributes = [ ("value", Text name) ];
          level = atom_level;
        }
    | Symbol name -> expand_nonterminal name environment

  and expand_nonterminal name environment =
    let candidates =
      spec.rules
      |> List.filter (fun rule ->
             rule.lhs = name
             && guard_holds environment rule
             &&
             try
               ignore (apply_updates environment rule);
               true
             with Generation_error _ -> false)
    in
    if candidates = [] then
      error
        (Printf.sprintf "no rule for '%s' fits {%s}" name
           (environment
           |> List.map (fun (attribute, value) -> attribute ^ "=" ^ string_of_int value)
           |> String.concat ", "));
    let rec attempt remaining last_failure =
      if remaining <= 0 then
        raise
          (Requirement_failed
             (Printf.sprintf "'%s' still failed after %d attempts; last failure: %s"
                name retries_per_node
                (match last_failure with
                | Some message -> message
                | None -> "no requirement could be satisfied")))
      else
        let before = !choice_points in
        match build_once name environment candidates with
        | node -> node
        | exception Requirement_failed message ->
            if !choice_points = before then
              (* Nothing random happened on the way to this failure, so every
                 retry would fail identically. Stop now instead of burning the
                 remaining attempts on a foregone conclusion. *)
              raise (Requirement_failed (mark_deterministic message))
            else attempt (remaining - 1) (Some message)
    in
    attempt retries_per_node None

  and build_once name environment candidates =
    let rule = weighted_pick candidates in
    let updated = apply_updates environment rule in
    (* Only nonterminal positions receive a share of a split budget. *)
    let expandable =
      rule.rhs
      |> List.mapi (fun index symbol -> (index, symbol))
      |> List.filter (fun (_, symbol) ->
             match symbol with Symbol name -> is_nonterminal name | _ -> false)
    in
    let child_environments = Array.make (max 1 (List.length expandable)) updated in
    List.iteri (fun index _ -> child_environments.(index) <- updated) expandable;
    List.iter
      (fun (declaration : Ag_check.inherited_attribute) ->
        match declaration.distribution with
        | Copy -> ()
        | Split ->
            let total = lookup updated declaration.attribute_name in
            let shares = random_partition total (List.length expandable) in
            List.iteri
              (fun index share ->
                child_environments.(index) <-
                  bind child_environments.(index) declaration.attribute_name share)
              shares)
      spec.inherited;
    let environment_for position =
      let rec find slot = function
        | [] -> updated
        | (index, _) :: rest ->
            if index = position then child_environments.(slot) else find (slot + 1) rest
      in
      find 0 expandable
    in
    let children =
      List.mapi
        (fun position symbol -> expand_symbol symbol (environment_for position))
        rule.rhs
    in
    (* Synthesized equations and requirements, in the order they were written. *)
    let attributes =
      List.fold_left
        (fun collected equation ->
          match equation with
          | Assign (attribute_name, _, _) when is_inherited attribute_name -> collected
          | Assign (attribute_name, body, _) ->
              let value =
                evaluate_in ~self:collected ~environment:updated ~children
                  ~rule:(Some rule) ~target:attribute_name body
              in
              collected @ [ (attribute_name, value) ]
          | Require (condition, position) -> (
              match
                evaluate_in ~self:collected ~environment:updated ~children
                  ~rule:(Some rule) ~target:"" condition
              with
              | Truth true -> collected
              | Truth false ->
                  raise
                    (Requirement_failed
                       (Printf.sprintf "a 'require' on line %d was not satisfied"
                          position.line))
              | other ->
                  error
                    (Printf.sprintf
                       "a 'require' must be true or false, but gave \"%s\""
                       (describe_value other))))
        [] rule.equations
    in
    {
      symbol = name;
      applied_rule = Some rule;
      children;
      inherited_attributes = environment;
      attributes;
      level =
        (match rule_precedence rule with Some (_, level, _) -> level | None -> atom_level);
    }
  in
  let initial =
    List.map
      (fun (declaration : Ag_check.inherited_attribute) ->
        (declaration.attribute_name, declaration.initial))
      spec.inherited
  in
  (expand_symbol (Symbol spec.start) initial, is_inherited, rule_precedence)

(* Rewrite the start symbol's name away so the top-level answer expression can
   be evaluated with the root standing in as child $1. *)
let rec bind_root start expression =
  match expression with
  | Attr_child_named (owner, name) when owner = start -> Attr_child (1, name)
  | Unary (operator, body) -> Unary (operator, bind_root start body)
  | Binary (operator, left, right) ->
      Binary (operator, bind_root start left, bind_root start right)
  | Call (name, arguments) -> Call (name, List.map (bind_root start) arguments)
  | other -> other

(* Question-level values are fixed before any expression is generated: every
   occurrence of the same random has to agree across the whole question, which
   a value drawn at the leaves could not guarantee. *)
let draw_globals (spec : Ag_check.spec) =
  let open Ag_check in
  let globals =
    List.map
      (fun (name, how) ->
        let value =
          match how with
          | Draw_boolean ->
              chose ();
              Truth (Random.bool ())
          | Draw_generator (generator, arguments) ->
              let constant_integer = function
                | Int value -> value
                | Unary ("-", Int value) -> -value
                | _ ->
                    error
                      (Printf.sprintf "%s needs constant integer arguments" generator)
              in
              let arguments = List.map constant_integer arguments in
              Num (Ag_number.of_int (draw_generator generator arguments))
        in
        (name, value))
      spec.randoms
  in
  (* Lets are evaluated in order, so a later one may use an earlier one. *)
  List.fold_left
    (fun known (name, body) ->
      let value =
        evaluate ~globals:known
          ~is_inherited:(fun _ -> false)
          ~rule_precedence:(fun _ -> None)
          ~environment:[] ~children:[] ~rule:None ~target:"" body
      in
      known @ [ (name, value) ])
    globals spec.lets

let generate_once (spec : Ag_check.spec) =
  let open Ag_check in
  let globals = draw_globals spec in
  let tree, is_inherited, rule_precedence = generate_tree spec ~globals in
  let answer =
    evaluate ~globals ~is_inherited ~rule_precedence ~environment:[] ~children:[ tree ]
      ~rule:None ~target:"value"
      (bind_root spec.start spec.answer)
  in
  let prompt =
    spec.prompt
    |> List.map (function
         | Ag_check.Text text -> text
         | Ag_check.Value_hole name -> (
             match List.assoc_opt name globals with
             | Some value -> as_text "prompt" value
             | None -> error (Printf.sprintf "'%s' has no value" name))
         | Ag_check.Hole (_, attribute_name) ->
             as_text "prompt" (attribute tree attribute_name))
    |> String.concat ""
  in
  { prompt; answer; answer_text = describe_value answer; globals; tree }

let generate spec =
  (* Which failure happened how often, so the final error tells the grammar
     author what to fix instead of just that generation gave up. *)
  let failure_counts : (string, int) Hashtbl.t = Hashtbl.create 8 in
  let record message =
    let seen = try Hashtbl.find failure_counts message with Not_found -> 0 in
    Hashtbl.replace failure_counts message (seen + 1)
  in
  let most_frequent_failure () =
    Hashtbl.fold
      (fun message count best ->
        match best with
        | Some (_, best_count) when best_count >= count -> best
        | _ -> Some (message, count))
      failure_counts None
  in
  let rec attempt remaining =
    if remaining <= 0 then
      error
        (match most_frequent_failure () with
        | Some (message, count) ->
            Printf.sprintf
              "could not generate a question after %d attempts; the most \
               frequent failure (%d of %d) was: %s"
              retries_per_question count retries_per_question message
        | None -> "could not generate a question")
    else
      let before = !choice_points in
      match generate_once spec with
      | question -> question
      | exception Requirement_failed message ->
          record message;
          if !choice_points = before then
            (* The whole question was built without a single random draw, so
               this grammar fails the same way every time. *)
            error ("this grammar can never satisfy its own constraints: " ^ message)
          else attempt (remaining - 1)
      | exception Ag_number.Arithmetic_error message ->
          record message;
          if !choice_points = before then
            error ("this grammar always fails the same way: " ^ message)
          else attempt (remaining - 1)
  in
  attempt retries_per_question
