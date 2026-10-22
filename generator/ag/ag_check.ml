(* ag_check.ml — fold a parsed .ag file into a validated specification.

   The parser is deliberately dumb: it accepts any [name = expression] equation
   without caring what the name means. Everything that gives the language its
   meaning is decided here, which is also where the error messages come from.

   The central rule this module enforces is the two-pass model:

     inherited attributes travel down   (budgets: len, digit)
     synthesized attributes travel up   (results: value, latex)

   So an inherited equation may not look at children (they do not exist yet)
   and a guard may not look at synthesized attributes (they are not computed
   yet). Keeping those two directions apart is what makes generation a single
   walk with no dependency analysis. *)

open Ag_ast

type error = { message : string; position : position }

type inherited_attribute = {
  attribute_name : string;
  initial : int;
  distribution : distribution;
}

type template_piece =
  | Text of string
  | Hole of string * string (* {E.latex} — an attribute of the start symbol *)
  | Value_hole of string    (* {ta}      — a question-level random or let *)
  | Answer_hole of string * string
      (* {answer Q.nth} -- an answer blank here, graded against that attribute *)
  | Answer_value_hole of string
      (* {answer total} -- an answer blank graded against a random or let *)

type spec = {
  inherited : inherited_attribute list;
  (* Drawn once per question, in declaration order. *)
  randoms : (string * Ag_ast.draw) list;
  (* Computed once per question, in declaration order, so a later one may use
     an earlier one. *)
  lets : (string * expr) list;
  (* name, and the nonterminal it belongs to (None = every nonterminal) *)
  synthesized : (string * string option) list;
  start : string;
  context : string;
  precedences : (string * int * associativity) list;
  rules : rule list;
  prompt : template_piece list;
  (* The trailing answer blank; None when the prompt places its own blanks. *)
  answer : expr option;
  width : int option;
  (* A file without start, prompt and answer is a library: it is meant to be
     included by a grammar and cannot generate on its own. *)
  library : bool;
  (* The start symbol computes `pg_context` / `pg_width` itself, per question. *)
  per_question_context : bool;
  per_question_width : bool;
}

let valid_context_name name =
  let valid_character = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | ' ' | '-' | '_' -> true
    | _ -> false
  in
  name <> "" && String.trim name = name && String.for_all valid_character name

(* Override the starting value of an inherited attribute from outside the file.
   This is how the web configuration sets difficulty: the .ag file owns the
   structure of a question, the caller owns the budgets it starts with. *)
let with_initial spec name value =
  if value < 0 then
    Error (Printf.sprintf "'%s' cannot start negative (%d was given)" name value)
  else if not (List.exists (fun a -> a.attribute_name = name) spec.inherited) then
    Error
      (Printf.sprintf "'%s' is not an inherited attribute of this grammar; it has %s"
         name
         (match spec.inherited with
         | [] -> "none"
         | attributes ->
             attributes |> List.map (fun a -> a.attribute_name) |> String.concat ", "))
  else
    Ok
      {
        spec with
        inherited =
          List.map
            (fun attribute ->
              if attribute.attribute_name = name then { attribute with initial = value }
              else attribute)
            spec.inherited;
      }

(* Builtins usable inside an attribute equation. *)
let expression_builtins =
  [
    ("str", 1);   (* str($1.value)          number -> text            *)
    ("paren", 1); (* paren($1)              force surrounding parens  *)
    ("infix", 3); (* infix($1, "+", $3)     precedence-aware rendering*)
    ("prefix", 2);(* prefix("\\neg", $2)    the same for a unary operator  *)
    ("cond", 3);  (* cond(A, "T", "F")      pick between two values        *)
    ("abs", 1);
    ("min", 2);
    ("max", 2);
    ("complex", 2);
    ("complex_latex", 2);
    ("formula_constant", 1);
    ("formula_variable", 1);
    ("formula_add", 2);
    ("formula_subtract", 2);
    ("formula_multiply", 2);
    ("formula_divide", 2);
    ("formula_power", 2);
    ("formula_negate", 1);
    ("formula_sin", 1);
    ("formula_cos", 1);
    ("formula_tan", 1);
    ("formula_exp", 1);
    ("formula_ln", 1);
    ("formula_sqrt", 1);
    ("formula_substitute", 3);
    ("differentiate", 2);
    ("formula_latex", 1);
    ("formula_is_zero", 1);
    ("formula_to_polynomial", 2);
    ("polynomial_constant", 2);
    ("polynomial_variable", 1);
    ("polynomial_monomial", 3);
    ("polynomial_linear", 3);
    ("polynomial_quadratic", 4);
    ("polynomial_add", 2);
    ("polynomial_subtract", 2);
    ("polynomial_multiply", 2);
    ("polynomial_scale", 2);
    ("polynomial_power", 2);
    ("polynomial_derivative", 1);
    ("polynomial_evaluate", 2);
    ("polynomial_coefficient", 2);
    ("polynomial_degree", 1);
    ("polynomial_is_zero", 1);
    ("polynomial_formula", 1);
    ("polynomial_latex", 1);
    ("equation", 2);
    ("polynomial_equation", 2);
    ("equation_normal_form", 1);
    ("equation_latex", 1);
    ("equation_is_satisfied", 3);
    ("equation_has_exact_solutions", 2);
    ("equation_solution_count", 2);
    ("equation_solution_set", 2);
    ("equation_unique_solution", 2);
    ("set_empty", 0);
    ("set_insert", 2);
    ("set_interval", 4);
    ("set_union", 2);
    ("set_intersection", 2);
    ("set_difference", 2);
    ("set_latex", 1);
    ("vector2", 2);
    ("vector3", 3);
    ("vector4", 4);
    ("vector_add", 2);
    ("vector_subtract", 2);
    ("vector_scale", 2);
    ("vector_dot", 2);
    ("vector_cross", 2);
    ("vector_latex", 1);
    ("vector_is_zero", 1);
    ("vector_norm_answer", 1);
    ("vector_unit_answer", 1);
    ("vector_parallel_answer", 1);
    ("vector_same_direction_answer", 1);
    (* Bitwise operations on whole numbers. A question that asks whether two
       expressions are equivalent has to compare them under every assignment,
       not just one; the usual way to carry that is a truth table, and a truth
       table over n variables is exactly a 2^n-bit number. *)
    ("bit_and", 2);
    ("bit_or", 2);
    ("bit_xor", 2);
  ]

(* Builtins usable as a right-hand side symbol, i.e. leaves that draw a random
   value during generation. *)
let generator_builtins =
  [
    ("integer", 1);
    ("nonzero_integer", 1);
    ("integer_between", 2);
    ("nonzero_integer_between", 2);
  ]

(* Draws available to a `random` declaration. boolean is handled separately
   because it takes no argument. *)
let random_builtins = generator_builtins

let integer_literal = function
  | Int value -> Some value
  | Unary ("-", Int value) -> Some (-value)
  | _ -> None

let check_known_generator_range report position name arguments =
  match (name, arguments) with
  | ("integer_between" | "nonzero_integer_between"), [ lower; upper ] -> (
      match (integer_literal lower, integer_literal upper) with
      | Some lower, Some upper when lower > upper ->
          report position
            (Printf.sprintf "%s lower bound %d is greater than upper bound %d" name
               lower upper)
      | Some 0, Some 0 when name = "nonzero_integer_between" ->
          report position
            "nonzero_integer_between(0, 0) has no non-zero value to draw"
      | _ -> ())
  | _ -> ()

(* ------------------------------------------------------------------ *)
(* Walking expressions                                                 *)
(* ------------------------------------------------------------------ *)

let rec iter_expr f expression =
  f expression;
  match expression with
  | Int _ | Str _ | Attr_here _ | Attr_child _ | Attr_child_named _ | Child _ ->
      ()
  | Unary (_, body) -> iter_expr f body
  | Binary (_, left, right) ->
      iter_expr f left;
      iter_expr f right
  | Call (_, arguments) -> List.iter (iter_expr f) arguments

(* ------------------------------------------------------------------ *)
(* Prompt templates                                                    *)
(* ------------------------------------------------------------------ *)

(* Split "What is [`{E.latex}`]?" into literal text and {symbol.attribute}
   holes. A doubled brace is an escaped literal brace. *)
let parse_template position text =
  let errors = ref [] in
  let pieces = ref [] in
  let buffer = Buffer.create (String.length text) in
  let flush () =
    if Buffer.length buffer > 0 then (
      pieces := Text (Buffer.contents buffer) :: !pieces;
      Buffer.clear buffer)
  in
  let length = String.length text in
  let rec scan index =
    if index >= length then ()
    else
      match text.[index] with
      | '{' when index + 1 < length && text.[index + 1] = '{' ->
          Buffer.add_char buffer '{';
          scan (index + 2)
      | '}' when index + 1 < length && text.[index + 1] = '}' ->
          Buffer.add_char buffer '}';
          scan (index + 2)
      | '{' -> (
          match String.index_from_opt text index '}' with
          | None ->
              errors :=
                {
                  message = "unclosed '{' in the prompt template";
                  position;
                }
                :: !errors
          | Some close ->
              let body =
                String.sub text (index + 1) (close - index - 1) |> String.trim
              in
              let answer_target =
                if String.length body > 7 && String.sub body 0 7 = "answer " then
                  Some (String.trim (String.sub body 7 (String.length body - 7)))
                else None
              in
              (match answer_target with
              | Some target -> (
                  flush ();
                  match String.index_opt target '.' with
                  | Some dot when dot > 0 && dot < String.length target - 1 ->
                      pieces :=
                        Answer_hole
                          ( String.sub target 0 dot |> String.trim,
                            String.sub target (dot + 1) (String.length target - dot - 1)
                            |> String.trim )
                        :: !pieces
                  | _ when target <> "" && not (String.contains target '.') ->
                      pieces := Answer_value_hole target :: !pieces
                  | _ ->
                      errors :=
                        {
                          message =
                            "{answer ...} must name an attribute of the start symbol, as \
                             in {answer Q.value}, or a random or let, as in {answer total}";
                          position;
                        }
                        :: !errors)
              | None ->
              match String.index_opt body '.' with
              | Some dot when dot > 0 && dot < String.length body - 1 ->
                  flush ();
                  let owner = String.sub body 0 dot |> String.trim in
                  let attribute =
                    String.sub body (dot + 1) (String.length body - dot - 1)
                    |> String.trim
                  in
                  pieces := Hole (owner, attribute) :: !pieces
              | None when body <> "" ->
                  flush ();
                  pieces := Value_hole body :: !pieces
              | _ ->
                  errors :=
                    {
                      message =
                        Printf.sprintf
                          "prompt placeholder {%s} must name either an attribute \
                           of the start symbol, as in {E.latex}, or a random or \
                           let, as in {ta}"
                          body;
                      position;
                    }
                    :: !errors);
              scan (close + 1))
      | character ->
          Buffer.add_char buffer character;
          scan (index + 1)
  in
  scan 0;
  flush ();
  (List.rev !pieces, List.rev !errors)

(* ------------------------------------------------------------------ *)
(* Checking                                                            *)
(* ------------------------------------------------------------------ *)

let check (declarations : file) : (spec, error list) result =
  let errors = ref [] in
  let report position message = errors := { message; position } :: !errors in

  (* ---- collect declarations ---- *)
  let inherited = ref [] in
  let randoms = ref [] in
  let lets = ref [] in
  let synthesized : (string * string option) list ref = ref [] in
  let start = ref None in
  let output_context = ref None in
  let precedences = ref [] in
  let prompt = ref None in
  let answer = ref None in
  let width = ref None in
  let rules = ref [] in

  let declared_once what current position set =
    match !current with
    | Some _ ->
        report position (Printf.sprintf "duplicate '%s' declaration" what)
    | None -> current := Some set
  in

  List.iter
    (fun declaration ->
      match declaration with
      | Inherited_decl (name, initial, distribution, position) ->
          if List.exists (fun a -> a.attribute_name = name) !inherited then
            report position
              (Printf.sprintf "attribute '%s' is declared more than once" name);
          if List.mem_assoc name !synthesized then
            report position
              (Printf.sprintf
                 "'%s' is already declared as a synthesized attribute" name);
          if initial < 0 then
            report position
              (Printf.sprintf
                 "attribute '%s' starts at %d; a budget cannot start negative"
                 name initial);
          inherited :=
            !inherited
            @ [ { attribute_name = name; initial; distribution } ]
      | Random_decl (name, how, position) ->
          if List.mem_assoc name !randoms || List.mem_assoc name !lets then
            report position (Printf.sprintf "'%s' is declared more than once" name);
          (match how with
          | Draw_boolean -> ()
          | Draw_generator (generator, arguments) -> (
              match List.assoc_opt generator random_builtins with
              | None ->
                  report position
                    (Printf.sprintf
                       "unknown draw '%s'; a random is drawn with boolean or %s"
                       generator
                       (random_builtins |> List.map fst |> String.concat " or "))
              | Some expected ->
                  if expected <> List.length arguments then
                    report position
                      (Printf.sprintf "%s takes %d argument(s), but %d were given"
                         generator expected (List.length arguments));
                  List.iter
                    (fun argument ->
                      if integer_literal argument = None then
                        report position
                          (Printf.sprintf
                             "random %s arguments must be integer literals" generator))
                    arguments;
                  check_known_generator_range report position generator arguments));
          randoms := !randoms @ [ (name, how) ]
      | Let_decl (name, body, position) ->
          if List.mem_assoc name !randoms || List.mem_assoc name !lets then
            report position (Printf.sprintf "'%s' is declared more than once" name);
          lets := !lets @ [ (name, body) ]
      | Synthesized_decl (name, scope, position) ->
          (* The same attribute may be declared on several nonterminals, so a
             repeat is only wrong when it repeats the same scope, or when it
             mixes a scoped and an unscoped declaration. *)
          if List.mem (name, scope) !synthesized then
            report position
              (Printf.sprintf "synth '%s' is declared more than once for the same \
                               symbol"
                 name)
          else if
            List.exists
              (fun (other, other_scope) ->
                other = name && (other_scope = None || scope = None))
              !synthesized
          then
            report position
              (Printf.sprintf
                 "synth '%s' is declared both with and without an 'on' symbol; \
                  pick one"
                 name);
          if List.exists (fun a -> a.attribute_name = name) !inherited then
            report position
              (Printf.sprintf
                 "'%s' is already declared as an inherited attribute" name);
          synthesized := !synthesized @ [ (name, scope) ]
      | Start_decl (name, position) -> declared_once "start" start position name
      | Include_decl (name, position) ->
          report position
            (Printf.sprintf
               "include \"%s\" was not resolved; includes are expanded by the loader"
               name)
      | Context_decl (name, position) ->
          if not (valid_context_name name) then
            report position
              "context must be a non-empty WeBWorK context name containing only \
               letters, numbers, spaces, underscores, or hyphens";
          declared_once "context" output_context position name
      | Precedence_decl (level, associativity, operators, position) ->
          if level < 0 then
            report position "a precedence level cannot be negative";
          List.iter
            (fun operator ->
              if List.exists (fun (o, _, _) -> o = operator) !precedences then
                report position
                  (Printf.sprintf
                     "operator '%s' is given a precedence more than once"
                     operator);
              precedences :=
                !precedences @ [ (operator, level, associativity) ])
            operators
      | Prompt_decl (template, position) ->
          declared_once "prompt" prompt position (template, position)
      | Answer_decl (body, position) ->
          declared_once "answer" answer position (body, position)
      | Width_decl (columns, position) ->
          if columns <= 0 then report position "width must be positive";
          declared_once "width" width position columns
      | Rule_decl rule -> rules := !rules @ [ rule ])
    declarations;

  let inherited = !inherited in
  let randoms = !randoms in
  let lets = !lets in
  let synthesized = !synthesized in
  let is_question_level name =
    List.mem_assoc name randoms || List.mem_assoc name lets
  in
  let rules = !rules in
  let is_inherited name =
    List.exists (fun a -> a.attribute_name = name) inherited
  in
  let is_synthesized name = List.mem_assoc name synthesized in
  (* Which synthesized attributes a given nonterminal has to compute. *)
  let synthesized_of nonterminal =
    synthesized
    |> List.filter (fun (_, scope) ->
           match scope with None -> true | Some owner -> owner = nonterminal)
    |> List.map fst
  in
  let nonterminals =
    rules |> List.map (fun rule -> rule.lhs) |> List.sort_uniq String.compare
  in
  let is_nonterminal name = List.mem name nonterminals in

  (* ---- top-level coherence ---- *)
  let library = !start = None && !prompt = None && !answer = None in
  let start_symbol =
    match !start with
    | None ->
        if not library then
        report dummy_position
          "a 'start SYMBOL' declaration is required (which nonterminal does a \
           question begin at?)";
        ""
    | Some name ->
        if not (is_nonterminal name) then
          report dummy_position
            (Printf.sprintf "start symbol '%s' has no rules" name);
        name
  in
  List.iter
    (fun (name, scope) ->
      match scope with
      | Some owner when not (is_nonterminal owner) ->
          report dummy_position
            (Printf.sprintf "synth '%s' is declared on '%s', which has no rules" name
               owner)
      | _ -> ())
    synthesized;
  if synthesized = [] then
    report dummy_position
      "declare at least one synthesized attribute, for example: synth value";
  if rules = [] then report dummy_position "the grammar has no rules";

  (* ---- expression checking ---- *)
  (* [context] describes what an expression is allowed to look at:
       `Downward — evaluated before the children exist (guards, inherited
                   equations, generator arguments)
       `Upward   — evaluated after the children are built (synthesized
                   equations, require clauses) *)
  (* [assigned_here] lists the synthesized attributes this rule has already
     computed. Referring to one by its bare name is how a rule reuses its own
     earlier work, as in `safe = "(" ++ latex ++ ")"`. *)
  let check_expr ?(assigned_here = []) ~context ~arity ~position expression =
    iter_expr
      (fun node ->
        match node with
        | Attr_here name ->
            if is_question_level name then ()
            else if List.mem name assigned_here then ()
            else if is_synthesized name then
              report position
                (Printf.sprintf
                   "'%s' is a synthesized attribute; write $1.%s for a child's, \
                    or assign %s earlier in this rule to reuse it here"
                   name name name)
            else if not (is_inherited name) then
              report position
                (Printf.sprintf "unknown name '%s'" name)
        | Attr_child (index, name) ->
            if context = `Downward then
              report position
                (Printf.sprintf
                   "$%d.%s refers to a child, which does not exist yet here; \
                    only inherited attributes are available at this point"
                   index name)
            else if index < 1 || index > arity then
              report position
                (Printf.sprintf
                   "$%d is out of range: this rule has %d symbols on the right"
                   index arity)
            else if not (is_synthesized name) then
              report position
                (Printf.sprintf
                   "'%s' is not a synthesized attribute, so a child does not \
                    carry it"
                   name)
        | Child index ->
            if context = `Downward then
              report position
                (Printf.sprintf
                   "$%d refers to a child, which does not exist yet here" index)
            else if index < 1 || index > arity then
              report position
                (Printf.sprintf
                   "$%d is out of range: this rule has %d symbols on the right"
                   index arity)
        | Attr_child_named (owner, name) ->
            report position
              (Printf.sprintf
                 "%s.%s may only be used in a 'prompt' or 'answer' \
                  declaration; inside a rule, refer to children as $1.%s"
                 owner name name)
        | Call (name, arguments) -> (
            match List.assoc_opt name expression_builtins with
            | Some expected when expected <> List.length arguments ->
                report position
                  (Printf.sprintf
                     "%s takes %d argument(s), but %d were given" name expected
                     (List.length arguments))
            | Some _ -> ()
            | None ->
                if List.mem_assoc name generator_builtins then
                  report position
                    (Printf.sprintf
                       "%s() produces a value and may only appear as a symbol \
                        on the right of '->', not inside an equation"
                       name)
                else
                  report position (Printf.sprintf "unknown function '%s'" name))
        | Int _ | Str _ | Unary _ | Binary _ -> ())
      expression
  in

  (* ---- question-level lets ----
     Evaluated once per question, before any tree exists, so a let may only
     refer to a random or to a let declared earlier. *)
  List.iteri
    (fun index (name, body) ->
      let position =
        match
          List.find_opt
            (function Let_decl (n, _, _) -> n = name | _ -> false)
            declarations
        with
        | Some declaration -> declaration_position declaration
        | None -> dummy_position
      in
      let visible =
        List.mem_assoc name randoms
        :: List.mapi (fun other (n, _) -> other < index && n = name) lets
        |> ignore;
        fun candidate ->
          List.mem_assoc candidate randoms
          || List.exists
               (fun (other, (n, _)) -> other < index && n = candidate)
               (List.mapi (fun i entry -> (i, entry)) lets)
      in
      iter_expr
        (fun node ->
          match node with
          | Attr_here referenced ->
              if not (visible referenced) then
                report position
                  (Printf.sprintf
                     "let '%s' refers to '%s', which is not a random or an \
                      earlier let"
                     name referenced)
          | Attr_child _ | Child _ | Attr_child_named _ ->
              report position
                (Printf.sprintf
                   "let '%s' cannot refer to a node; it is computed before any \
                    expression is generated"
                   name)
          | Call (called, arguments) -> (
              match List.assoc_opt called expression_builtins with
              | Some expected when expected <> List.length arguments ->
                  report position
                    (Printf.sprintf "%s takes %d argument(s), but %d were given"
                       called expected (List.length arguments))
              | Some _ -> ()
              | None -> report position (Printf.sprintf "unknown function '%s'" called))
          | _ -> ())
        body)
    lets;

  (* ---- rules ---- *)
  List.iter
    (fun rule ->
      let position = rule.rule_position in
      let arity = List.length rule.rhs in
      if rule.weight <= 0 then
        report position
          (Printf.sprintf "weight must be positive, but rule '%s' has weight %d"
             rule.lhs rule.weight);

      (* generator arguments are drawn before the children exist *)
      List.iter
        (fun symbol ->
          match symbol with
          | Generator (name, arguments) -> (
              match List.assoc_opt name generator_builtins with
              | None ->
                  report position
                    (Printf.sprintf "unknown generator '%s'" name)
              | Some expected ->
                  if expected <> List.length arguments then
                    report position
                      (Printf.sprintf
                         "%s takes %d argument(s), but %d were given" name
                         expected (List.length arguments));
                  check_known_generator_range report position name arguments;
                  List.iter
                    (check_expr ~context:`Downward ~arity ~position)
                    arguments)
          | Symbol _ | Literal _ -> ())
        rule.rhs;

      (match rule.guard with
      | None -> ()
      | Some condition ->
          check_expr ~context:`Downward ~arity ~position condition);

      let assigned = ref [] in
      List.iter
        (fun equation ->
          match equation with
          | Require (condition, position) ->
              check_expr ~assigned_here:(List.rev !assigned) ~context:`Upward ~arity
                ~position condition
          | Assign (name, body, position) ->
              if List.mem name !assigned then
                report position
                  (Printf.sprintf "'%s' is assigned twice in the same rule"
                     name);
              if is_inherited name then (
                (* a budget update is applied on the way down *)
                check_expr ~context:`Downward ~arity ~position body;
                match body with
                | Int value when value > 0 ->
                    report position
                      (Printf.sprintf
                         "'%s = %d' would grow the budget; an inherited update \
                          must consume it, so use 0 or a negative number"
                         name value)
                | _ -> ())
              else if is_synthesized name then
                check_expr ~assigned_here:(List.rev !assigned) ~context:`Upward ~arity
                  ~position body
              else
                report position
                  (Printf.sprintf
                     "'%s' is not declared; add 'attribute %s = ...' or 'synth \
                      %s'"
                     name name name);
              assigned := name :: !assigned)
        rule.equations;

      (* Every rule must say how each synthesized attribute is computed,
         otherwise the value is simply missing at generation time. *)
      List.iter
        (fun name ->
          if not (List.mem name !assigned) then
            report position
              (Printf.sprintf
                 "rule '%s' does not say how to compute '%s'; add '%s = ...' \
                  inside its braces"
                 rule.lhs name name))
        (synthesized_of rule.lhs))
    rules;

  (* ---- termination ---- *)
  (* Both checks below are conservative shape checks, not proofs: they ignore
     guards entirely and only ask whether the bare productions allow every
     derivation to reach a floor. Their job is to catch the two classic
     authoring mistakes — no base case, and a recursion that forgets to spend
     its budget — before generation runs into the fuel limit. *)
  let rhs_nonterminals rule =
    rule.rhs
    |> List.filter_map (fun symbol ->
           match symbol with
           | Symbol name when is_nonterminal name -> Some name
           | _ -> None)
  in

  (* 1. A derivation can finish at 'X' only if some rule for X has every
     nonterminal on its right-hand side already able to finish. *)
  let can_finish : (string, unit) Hashtbl.t = Hashtbl.create 8 in
  let keep_looking = ref true in
  while !keep_looking do
    keep_looking := false;
    List.iter
      (fun rule ->
        if
          (not (Hashtbl.mem can_finish rule.lhs))
          && List.for_all (Hashtbl.mem can_finish) (rhs_nonterminals rule)
        then (
          Hashtbl.add can_finish rule.lhs ();
          keep_looking := true))
      rules
  done;
  List.iter
    (fun name ->
      if not (Hashtbl.mem can_finish name) then
        let position =
          match List.find_opt (fun rule -> rule.lhs = name) rules with
          | Some rule -> rule.rule_position
          | None -> dummy_position
        in
        report position
          (Printf.sprintf
             "every rule for '%s' keeps the derivation going; give it a rule \
              whose right-hand side can finish"
             name))
    nonterminals;

  (* 2. A cycle that spends nothing repeats the exact same attribute
     environment forever (copy passes values through unchanged, and guards
     see the same environment every lap). So on every cycle of the grammar at
     least one rule must shrink an inherited budget. Equivalently: after
     removing the rules that do spend, what is left must be acyclic. An
     update that is not a plain constant is given the benefit of the doubt. *)
  let spends rule =
    List.exists
      (fun equation ->
        match equation with
        | Assign (name, body, _) when is_inherited name -> (
            match body with
            | Int value -> value < 0
            | Unary ("-", Int value) -> value > 0
            | _ -> true)
        | _ -> false)
      rule.equations
  in
  let free_rules = List.filter (fun rule -> not (spends rule)) rules in
  (* Can [source] come back around to [target] using only non-spending rules?
     Zero steps count: a rule whose own right-hand side mentions its
     left-hand side is already a loop. *)
  let reaches_freely source target =
    let visited : (string, unit) Hashtbl.t = Hashtbl.create 8 in
    let rec walk name =
      name = target
      || (not (Hashtbl.mem visited name))
         && (Hashtbl.add visited name ();
             free_rules
             |> List.exists (fun rule ->
                    rule.lhs = name && List.exists walk (rhs_nonterminals rule)))
    in
    walk source
  in
  List.iter
    (fun rule ->
      if List.exists (fun child -> reaches_freely child rule.lhs) (rhs_nonterminals rule)
      then
        report rule.rule_position
          (Printf.sprintf
             "this rule can reach '%s' again without spending any inherited \
              attribute, so a derivation could circle forever; make the loop \
              consume a budget, for example 'len = -1'"
             rule.lhs))
    free_rules;

  (* ---- prompt and answer ---- *)
  let prompt_pieces =
    match !prompt with
    | None ->
        if not library then
          report dummy_position
            "a 'prompt \"...\"' declaration is required (how does the question \
             read?)";
        []
    | Some (template, position) ->
        let pieces, template_errors = parse_template position template in
        List.iter (fun error -> errors := error :: !errors) template_errors;
        List.iter
          (fun piece ->
            match piece with
            | Text _ -> ()
            | Value_hole name ->
                if not (is_question_level name) then
                  report position
                    (Printf.sprintf
                       "{%s} is not a random or a let; to use an attribute of \
                        the expression write {%s.%s}"
                       name start_symbol name)
            | Hole (owner, attribute) | Answer_hole (owner, attribute) ->
                if owner <> start_symbol then
                  report position
                    (Printf.sprintf
                       "{%s.%s} refers to '%s', but a prompt can only use the \
                        start symbol '%s'"
                       owner attribute owner start_symbol)
                else if not (is_synthesized attribute) then
                  report position
                    (Printf.sprintf
                       "{%s.%s} refers to '%s', which is not a synthesized \
                        attribute"
                       owner attribute attribute)
            | Answer_value_hole name ->
                if not (is_question_level name) then
                  report position
                    (Printf.sprintf "{answer %s} is not a random or a let" name))
          pieces;
        pieces
  in
  let inline_blanks =
    List.exists
      (function Answer_hole _ | Answer_value_hole _ -> true | _ -> false)
      prompt_pieces
  in

  let answer_expr =
    match !answer with
    | None ->
        if not (library || inline_blanks) then
          report dummy_position
            "an 'answer ...' declaration is required (what is the correct \
             answer?), or place the blanks in the prompt with {answer ...}";
        None
    | Some (body, position) ->
        if inline_blanks then
          report position
            "the prompt already places its answer blanks with {answer ...}; \
             drop the 'answer' declaration";
        iter_expr
          (fun node ->
            match node with
            | Attr_child_named (owner, attribute) ->
                if owner <> start_symbol then
                  report position
                    (Printf.sprintf
                       "%s.%s refers to '%s', but an answer can only use the \
                        start symbol '%s'"
                       owner attribute owner start_symbol)
                else if not (is_synthesized attribute) then
                  report position
                    (Printf.sprintf
                       "%s.%s refers to '%s', which is not a synthesized \
                        attribute"
                       owner attribute attribute)
            | Attr_here name ->
                report position
                  (Printf.sprintf
                     "'%s' on its own is ambiguous here; write %s.%s" name
                     start_symbol name)
            | Attr_child (index, _) | Child index ->
                report position
                  (Printf.sprintf
                     "$%d has no meaning in an 'answer' declaration; write \
                      %s.value"
                     index start_symbol)
            | _ -> ())
          body;
        Some body
  in
  (* The start symbol may compute the context and width of each question. *)
  let computed_by_start name =
    List.exists
      (fun (attribute, scope) ->
        attribute = name && (scope = None || scope = Some start_symbol))
      synthesized
  in

  match List.rev !errors with
  | [] ->
      Ok
        {
          inherited;
          randoms;
          lets;
          synthesized;
          start = start_symbol;
          context = Option.value ~default:"Numeric" !output_context;
          precedences = !precedences;
          rules;
          prompt = prompt_pieces;
          answer = answer_expr;
          width = !width;
          library;
          per_question_context = computed_by_start "pg_context";
          per_question_width = computed_by_start "pg_width";
        }
  | errors -> Error errors
