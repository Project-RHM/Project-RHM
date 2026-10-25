(* rhema_check.ml — fold a parsed .rhm file into a validated specification.

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

open Rhema_ast

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

(* One question type of a file: where it starts and how it asks. The
   file-level start, prompt, answer, context and width form the question
   `main`; a `question NAME { ... }` block adds another. All questions of a
   file share its rules, attributes, randoms and lets. *)
type question = {
  q_name : string;
  q_start : string;
  q_context : string;
  q_prompt : template_piece list;
  q_answer : expr option;
  q_width : int option;
  q_per_question_context : bool;
  q_per_question_width : bool;
  (* The starting value of every inherited attribute at this question's root:
     the declared initial unless the block says otherwise (`cost = 7`). *)
  q_initials : (string * int) list;
}

type spec = {
  inherited : inherited_attribute list;
  (* Drawn once per question, in declaration order. *)
  randoms : (string * Rhema_ast.draw) list;
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
  (* The file this specification was read from ("" for an inline source).
     Two imports of one file name the same module, and the engine draws that
     module's randoms once per question, so the file is the module's identity. *)
  source : string;
  (* The modules this file imports, by alias. Each is a checked specification
     of its own; the engine expands `alias.F` with that module's rules. *)
  imports : (string * spec) list;
  (* Every question of the file, `main` first when it exists. The fields
     start, context, prompt, answer, width, per_question_* above describe the
     selected one: `main`, or the first block when there is no `main`.
     [select_question] switches to another. *)
  questions : question list;
  (* The sets the file declares, validated: every question they name exists
     and every budget they draw is an inherited attribute of its grammar. *)
  sets : Rhema_ast.set_decl list;
}

(* Make another of the file's questions the one the engine generates. *)
let select_question spec name =
  match List.find_opt (fun question -> question.q_name = name) spec.questions with
  | None ->
      Error
        (Printf.sprintf "'%s' is not a question of this grammar; it has %s" name
           (match spec.questions with
           | [] -> "none"
           | questions -> questions |> List.map (fun q -> q.q_name) |> String.concat ", "))
  | Some question ->
      Ok
        {
          spec with
          start = question.q_start;
          context = question.q_context;
          prompt = question.q_prompt;
          answer = question.q_answer;
          width = question.q_width;
          per_question_context = question.q_per_question_context;
          per_question_width = question.q_per_question_width;
          inherited =
            List.map
              (fun attribute ->
                match List.assoc_opt attribute.attribute_name question.q_initials with
                | Some initial -> { attribute with initial }
                | None -> attribute)
              spec.inherited;
        }

(* What an importer may see of a module: the names, not the rules. *)
let nonterminals_of spec =
  spec.rules |> List.map (fun rule -> rule.lhs) |> List.sort_uniq String.compare

let synthesized_of_nonterminal spec nonterminal =
  spec.synthesized
  |> List.filter (fun (_, scope) ->
         match scope with None -> true | Some owner -> owner = nonterminal)
  |> List.map fst

let inherited_names spec = List.map (fun a -> a.attribute_name) spec.inherited

let inherited_names_of_attributes attributes =
  List.map (fun a -> a.attribute_name) attributes

let is_question_level_of spec name =
  List.mem_assoc name spec.randoms || List.mem_assoc name spec.lets

let valid_context_name name =
  let valid_character = function
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | ' ' | '-' | '_' -> true
    | _ -> false
  in
  name <> "" && String.trim name = name && String.for_all valid_character name

(* Override the starting value of an inherited attribute from outside the file.
   This is how the web configuration sets difficulty: the .rhm file owns the
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
    ("bool_var", 1);
    ("bool_true", 0);
    ("bool_false", 0);
    ("bool_not", 1);
    ("bool_and", 2);
    ("bool_or", 2);
    ("bool_xor", 2);
    ("bool_imp", 2);
    ("bool_iff", 2);
    ("bool_latex", 1);
    ("bool_equivalent", 2);
    ("bool_evaluate", 3);
    ("bool_sensitivity", 3);
    ("bool_is_tautology", 1);
    ("bool_is_contradiction", 1);
    ("bool_is_tidy", 1);
    ("bool_is_atom", 1);
    ("bool_top", 1);
    ("bool_size", 1);
    ("bool_negations", 1);
    ("bool_depth", 1);
    ("bool_count", 2);
    ("bool_variable_count", 1);
    ("bool_model_count", 1);
    ("bool_without_conditionals", 1);
    ("matrix2", 4);
    ("matrix3", 9);
    ("matrix_identity", 1);
    ("matrix_add", 2);
    ("matrix_subtract", 2);
    ("matrix_multiply", 2);
    ("matrix_scale", 2);
    ("matrix_transpose", 1);
    ("matrix_determinant", 1);
    ("matrix_inverse", 1);
    ("matrix_is_invertible", 1);
    ("matrix_entry", 3);
    ("matrix_vector", 2);
    ("matrix_latex", 1);
    ("matrix_row_latex", 2);
    ("vector_entry", 2);
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

(* A question as written, before validation: `main` from the file-level
   declarations, or one block. *)
type draft = {
  d_name : string;
  d_position : position;
  d_start : (string * position) option;
  d_context : (string * position) option;
  d_prompt : (string * position) option;
  d_answer : (expr * position) option;
  d_width : (int * position) option;
  d_defaults : (string * int * position) list;
}

let check ?(source = "") ?(modules : (string * spec) list = []) (declarations : file) :
    (spec, error list) result =
  let errors = ref [] in
  let report position message = errors := { message; position } :: !errors in
  let module_of alias = List.assoc_opt alias modules in
  let module_names () = modules |> List.map fst |> String.concat ", " in
  let imports = ref [] in

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
  let blocks = ref [] in
  let sets = ref [] in

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
      | Import_decl (name, alias, position) -> (
          if List.mem_assoc alias !imports then
            report position
              (Printf.sprintf "'%s' is already the alias of another import" alias);
          match module_of alias with
          | None ->
              report position
                (Printf.sprintf
                   "import \"%s\" as %s was not resolved; imports are loaded by the loader"
                   name alias)
          | Some module_spec -> imports := !imports @ [ (alias, module_spec) ])
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
      | Question_decl (name, items, position) ->
          if name = "main" then
            report position
              "'main' is the file-level question: declare it with start, prompt and \
               answer outside a block, or give this block another name";
          if List.exists (fun (other, _, _) -> other = name) !blocks then
            report position (Printf.sprintf "question '%s' is declared more than once" name);
          blocks := !blocks @ [ (name, items, position) ]
      | Set_decl set ->
          if List.exists (fun (other : Rhema_ast.set_decl) -> other.set_name = set.set_name) !sets then
            report set.set_position
              (Printf.sprintf "set '%s' is declared more than once" set.set_name);
          sets := !sets @ [ set ]
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

  (* ---- the questions of the file ---- *)
  (* The file-level declarations form `main`; each block is one more. A file
     with neither is a library. The drafts are validated after the rules,
     once the nonterminals and the question-level names are known. *)
  let main_present = !start <> None || !prompt <> None || !answer <> None in
  let library = (not main_present) && !blocks = [] in
  let main_draft =
    {
      d_name = "main";
      d_position = dummy_position;
      d_start = Option.map (fun name -> (name, dummy_position)) !start;
      d_context = Option.map (fun name -> (name, dummy_position)) !output_context;
      d_prompt = !prompt;
      d_answer = !answer;
      d_width = Option.map (fun columns -> (columns, dummy_position)) !width;
      d_defaults = [];
    }
  in
  let block_draft (name, items, position) =
    let draft =
      ref
        {
          d_name = name;
          d_position = position;
          d_start = None;
          d_context = None;
          d_prompt = None;
          d_answer = None;
          d_width = None;
          d_defaults = [];
        }
    in
    let once what current position =
      if current <> None then
        report position (Printf.sprintf "question '%s' declares '%s' more than once" name what)
    in
    List.iter
      (fun item ->
        match item with
        | Q_start (symbol, position) ->
            once "start" !draft.d_start position;
            draft := { !draft with d_start = Some (symbol, position) }
        | Q_context (context, position) ->
            once "context" !draft.d_context position;
            draft := { !draft with d_context = Some (context, position) }
        | Q_prompt (template, position) ->
            once "prompt" !draft.d_prompt position;
            draft := { !draft with d_prompt = Some (template, position) }
        | Q_answer (body, position) ->
            once "answer" !draft.d_answer position;
            draft := { !draft with d_answer = Some (body, position) }
        | Q_width (columns, position) ->
            once "width" !draft.d_width position;
            draft := { !draft with d_width = Some (columns, position) }
        | Q_default (attribute, value, position) ->
            if List.exists (fun (other, _, _) -> other = attribute) !draft.d_defaults then
              report position
                (Printf.sprintf "question '%s' sets '%s' more than once" name attribute);
            draft := { !draft with d_defaults = !draft.d_defaults @ [ (attribute, value, position) ] })
      items;
    !draft
  in
  let drafts = (if main_present then [ main_draft ] else []) @ List.map block_draft !blocks in
  List.iter
    (fun (name, scope) ->
      match scope with
      | Some owner when not (is_nonterminal owner) ->
          report dummy_position
            (Printf.sprintf "synth '%s' is declared on '%s', which has no rules" name
               owner)
      | _ -> ())
    synthesized;
  (* A file of imports and sets alone has no rules of its own; that is fine. *)
  let set_file = rules = [] && !sets <> [] && !blocks = [] && not main_present in
  if synthesized = [] && not set_file then
    report dummy_position
      "declare at least one synthesized attribute, for example: synth value";
  if rules = [] && not set_file then report dummy_position "the grammar has no rules";

  (* ---- expression checking ---- *)
  (* [context] describes what an expression is allowed to look at:
       `Downward — evaluated before the children exist (guards, inherited
                   equations, generator arguments)
       `Upward   — evaluated after the children are built (synthesized
                   equations, require clauses) *)
  (* [assigned_here] lists the synthesized attributes this rule has already
     computed. Referring to one by its bare name is how a rule reuses its own
     earlier work, as in `safe = "(" ++ latex ++ ")"`. *)
  (* The module child at a position of the rule's right-hand side, if any:
     its synthesized attributes come from that module, not from this file. *)
  let module_child rhs index =
    match List.nth_opt rhs (index - 1) with
    | Some (Module_symbol (alias, nonterminal, _)) -> (
        match module_of alias with
        | Some module_spec -> Some (alias, nonterminal, module_spec)
        | None -> None)
    | _ -> None
  in
  let check_expr ?(assigned_here = []) ?(rhs = []) ~context ~arity ~position expression =
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
            else (
              match module_child rhs index with
              | Some (alias, nonterminal, module_spec) ->
                  let carried = synthesized_of_nonterminal module_spec nonterminal in
                  if not (List.mem name carried) then
                    report position
                      (Printf.sprintf
                         "$%d is %s.%s, which does not carry '%s'; it has %s" index alias
                         nonterminal name
                         (if carried = [] then "no synthesized attribute"
                          else String.concat ", " carried))
              | None ->
                  if not (is_synthesized name) then
                    report position
                      (Printf.sprintf
                         "'%s' is not a synthesized attribute, so a child does not \
                          carry it"
                         name))
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
        | Attr_child_named (owner, name) -> (
            match module_of owner with
            | Some module_spec ->
                if not (is_question_level_of module_spec name) then
                  report position
                    (Printf.sprintf
                       "%s.%s: module %s has no random or let named '%s'" owner name
                       owner name)
            | None ->
                report position
                  (Printf.sprintf
                     "%s.%s may only be used in a 'prompt' or 'answer' \
                      declaration; inside a rule, refer to children as $1.%s%s"
                     owner name name
                     (if modules = [] then ""
                      else "; the imported modules are " ^ module_names ())))
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
          | Attr_child_named (owner, referenced) when module_of owner <> None ->
              let module_spec = Option.get (module_of owner) in
              if not (is_question_level_of module_spec referenced) then
                report position
                  (Printf.sprintf "%s.%s: module %s has no random or let named '%s'"
                     owner referenced owner referenced)
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
          | Module_symbol (alias, nonterminal, arguments) -> (
              match module_of alias with
              | None ->
                  report position
                    (Printf.sprintf "'%s' is not an imported module%s" alias
                       (if modules = [] then "; this file imports nothing"
                        else "; the imported modules are " ^ module_names ()))
              | Some module_spec ->
                  if not (List.mem nonterminal (nonterminals_of module_spec)) then
                    report position
                      (Printf.sprintf "module %s has no nonterminal '%s'; it has %s" alias
                         nonterminal
                         (match nonterminals_of module_spec with
                         | [] -> "none"
                         | names -> String.concat ", " names));
                  let seen = ref [] in
                  List.iter
                    (fun (name, body) ->
                      if List.mem name !seen then
                        report position
                          (Printf.sprintf "%s.%s sets '%s' twice" alias nonterminal name);
                      seen := name :: !seen;
                      if not (List.mem name (inherited_names module_spec)) then
                        report position
                          (Printf.sprintf
                             "module %s has no inherited attribute '%s' to start; it has %s"
                             alias name
                             (match inherited_names module_spec with
                             | [] -> "none"
                             | names -> String.concat ", " names));
                      (* Evaluated before the child exists, from this rule's own
                         inherited attributes and the question-level values. *)
                      check_expr ~context:`Downward ~arity ~position body)
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
              check_expr ~assigned_here:(List.rev !assigned) ~rhs:rule.rhs ~context:`Upward
                ~arity ~position condition
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
                check_expr ~assigned_here:(List.rev !assigned) ~rhs:rule.rhs ~context:`Upward
                  ~arity ~position body
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

  (* ---- each question: start, prompt, answer, context, width ---- *)
  let validate (draft : draft) =
    let named = draft.d_name <> "main" in
    let report_here message = report draft.d_position message in
    let start_symbol =
      match draft.d_start with
      | None ->
          report_here
            (if named then
               Printf.sprintf
                 "question '%s' needs a 'start SYMBOL' line (which nonterminal does it \
                  begin at?)"
                 draft.d_name
             else
               "a 'start SYMBOL' declaration is required (which nonterminal does a \
                question begin at?)");
          ""
      | Some (name, position) ->
          if not (is_nonterminal name) then
            report position (Printf.sprintf "start symbol '%s' has no rules" name);
          name
    in
    let context =
      match draft.d_context with
      | Some (name, position) ->
          if named && not (valid_context_name name) then
            report position
              "context must be a non-empty WeBWorK context name containing only \
               letters, numbers, spaces, underscores, or hyphens";
          name
      | None -> (
          (* A block without a context takes the file-level one, if any. *)
          match !output_context with Some name -> name | None -> "Numeric")
    in
    let prompt_pieces =
      match draft.d_prompt with
      | None ->
          report_here
            (if named then
               Printf.sprintf "question '%s' needs a 'prompt \"...\"' line (how does it read?)"
                 draft.d_name
             else
               "a 'prompt \"...\"' declaration is required (how does the question \
                read?)");
          []
      | Some (template, position) ->
          let pieces, template_errors = parse_template position template in
          List.iter (fun error -> errors := error :: !errors) template_errors;
          (* {calc.given} and {answer calc.total} name a module's random or let;
             the engine keeps those under their qualified names. *)
          let qualify owner attribute module_spec make =
            if not (is_question_level_of module_spec attribute) then
              report position
                (Printf.sprintf "{%s.%s}: module %s has no random or let named '%s'" owner
                   attribute owner attribute);
            make (owner ^ "." ^ attribute)
          in
          let pieces =
            List.map
              (fun piece ->
                match piece with
                | Hole (owner, attribute) when module_of owner <> None ->
                    qualify owner attribute (Option.get (module_of owner)) (fun q -> Value_hole q)
                | Answer_hole (owner, attribute) when module_of owner <> None ->
                    qualify owner attribute (Option.get (module_of owner)) (fun q ->
                        Answer_value_hole q)
                | other -> other)
              pieces
          in
          List.iter
            (fun piece ->
              match piece with
              | Text _ -> ()
              | Value_hole name ->
                  if not (is_question_level name || String.contains name '.') then
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
                  if not (is_question_level name || String.contains name '.') then
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
      match draft.d_answer with
      | None ->
          if not inline_blanks then
            report_here
              (if named then
                 Printf.sprintf
                   "question '%s' needs an 'answer ...' line (what is the correct answer?), \
                    or blanks in its prompt with {answer ...}"
                   draft.d_name
               else
                 "an 'answer ...' declaration is required (what is the correct \
                  answer?), or place the blanks in the prompt with {answer ...}");
          None
      | Some (body, position) ->
          if inline_blanks then
            report position
              "the prompt already places its answer blanks with {answer ...}; \
               drop the 'answer' declaration";
          iter_expr
            (fun node ->
              match node with
              | Attr_child_named (owner, attribute) when module_of owner <> None ->
                  if not (is_question_level_of (Option.get (module_of owner)) attribute) then
                    report position
                      (Printf.sprintf "%s.%s: module %s has no random or let named '%s'"
                         owner attribute owner attribute)
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
    let width =
      match draft.d_width with
      | Some (columns, position) ->
          if named && columns <= 0 then report position "width must be positive";
          Some columns
      | None -> !width
    in
    (* The start symbol may compute the context and width of each question. *)
    let computed_by_start name =
      List.exists
        (fun (attribute, scope) ->
          attribute = name && (scope = None || scope = Some start_symbol))
        synthesized
    in
    (* The root's starting budgets: declared, unless this question says. *)
    List.iter
      (fun (attribute, value, position) ->
        if not (is_inherited attribute) then
          report position
            (Printf.sprintf
               "question '%s' sets '%s', which is not an inherited attribute; a block \
                may only hold start, context, prompt, answer, width and attribute \
                starting values"
               draft.d_name attribute)
        else if value < 0 then
          report position
            (Printf.sprintf "question '%s' starts '%s' at %d; a budget cannot start negative"
               draft.d_name attribute value))
      draft.d_defaults;
    let initials =
      List.map
        (fun attribute ->
          let value =
            match
              List.find_opt (fun (name, _, _) -> name = attribute.attribute_name) draft.d_defaults
            with
            | Some (_, value, _) -> value
            | None -> attribute.initial
          in
          (attribute.attribute_name, value))
        inherited
    in
    {
      q_name = draft.d_name;
      q_start = start_symbol;
      q_context = context;
      q_prompt = prompt_pieces;
      q_answer = answer_expr;
      q_width = width;
      q_per_question_context = computed_by_start "pg_context";
      q_per_question_width = computed_by_start "pg_width";
      q_initials = initials;
    }
  in
  let questions = List.map validate drafts in

  (* ---- sets ---- *)
  (* Each question a set names must exist, here or in the module named, and
     each budget it draws must be an inherited attribute of that grammar. *)
  let question_names (spec_questions : question list) =
    List.map (fun question -> question.q_name) spec_questions
  in
  let check_set (set : Rhema_ast.set_decl) =
    let check_question (target : Rhema_ast.set_question) =
      let position = target.sq_position in
      let grammar =
        match target.sq_alias with
        | None ->
            if not (List.mem target.sq_name (question_names questions)) then (
              report position
                (Printf.sprintf "set '%s' asks for '%s', which is not a question of this file; it has %s"
                   set.set_name target.sq_name
                   (match question_names questions with
                   | [] -> "none"
                   | names -> String.concat ", " names));
              None)
            else Some (inherited_names_of_attributes inherited)
        | Some alias -> (
            match module_of alias with
            | None ->
                report position
                  (Printf.sprintf "set '%s' asks for %s.%s, but '%s' is not an imported module"
                     set.set_name alias target.sq_name alias);
                None
            | Some module_spec ->
                if not (List.mem target.sq_name (question_names module_spec.questions)) then (
                  report position
                    (Printf.sprintf
                       "set '%s' asks for %s.%s, but module %s has no such question; it has %s"
                       set.set_name alias target.sq_name alias
                       (match question_names module_spec.questions with
                       | [] -> "none"
                       | names -> String.concat ", " names));
                  None)
                else Some (inherited_names module_spec))
      in
      let seen = ref [] in
      List.iter
        (fun (attribute, draw) ->
          if List.mem attribute !seen then
            report position
              (Printf.sprintf "set '%s' draws '%s' twice for %s" set.set_name attribute
                 target.sq_name);
          seen := attribute :: !seen;
          (match grammar with
          | Some attributes when not (List.mem attribute attributes) ->
              report position
                (Printf.sprintf
                   "set '%s' draws '%s' for %s, which has no such inherited attribute; it has %s"
                   set.set_name attribute target.sq_name
                   (match attributes with [] -> "none" | names -> String.concat ", " names))
          | _ -> ());
          let non_negative what value =
            if value < 0 then
              report position
                (Printf.sprintf "set '%s': %s of '%s' cannot be negative (%d)" set.set_name what
                   attribute value)
          in
          match draw with
          | Rhema_ast.Fixed value -> non_negative "the value" value
          | Rhema_ast.Among values -> List.iter (non_negative "a value") values
          | Rhema_ast.Around { mean; spread; low; allowed } ->
              non_negative "the mean" mean;
              non_negative "the spread" spread;
              non_negative "low" low;
              Option.iter (List.iter (non_negative "an allowed value")) allowed)
        target.sq_draws
    in
    let constraints = ref [] in
    let once what position =
      if List.mem what !constraints then
        report position (Printf.sprintf "set '%s' says '%s' more than once" set.set_name what);
      constraints := what :: !constraints
    in
    let entries = ref 0 in
    List.iter
      (fun item ->
        match item with
        | Rhema_ast.Set_part _ -> ()
        | Rhema_ast.Set_distinct position -> once "distinct" position
        | Rhema_ast.Set_balanced position -> once "balanced" position
        | Rhema_ast.Set_ordered position -> once "ordered" position
        | Rhema_ast.Set_entry entry ->
            incr entries;
            if entry.se_count <= 0 then
              report entry.se_position
                (Printf.sprintf "set '%s' asks for %d questions; the count must be positive"
                   set.set_name entry.se_count);
            List.iter check_question entry.se_choices)
      set.set_items;
    if !entries = 0 then
      report set.set_position (Printf.sprintf "set '%s' asks for no questions" set.set_name)
  in
  List.iter check_set !sets;
  (* The fields the engine reads describe the selected question: `main` when
     the file has one, else the first block; a library has none. *)
  let selected =
    match questions with
    | first :: _ -> first
    | [] ->
        {
          q_name = "";
          q_start = "";
          q_context = Option.value ~default:"Numeric" !output_context;
          q_prompt = [];
          q_answer = None;
          q_width = !width;
          q_per_question_context = false;
          q_per_question_width = false;
          q_initials = List.map (fun a -> (a.attribute_name, a.initial)) inherited;
        }
  in

  match List.rev !errors with
  | [] ->
      let spec =
        {
          inherited;
          randoms;
          lets;
          synthesized;
          start = selected.q_start;
          context = selected.q_context;
          precedences = !precedences;
          rules;
          prompt = selected.q_prompt;
          answer = selected.q_answer;
          width = selected.q_width;
          library;
          per_question_context = selected.q_per_question_context;
          per_question_width = selected.q_per_question_width;
          source;
          imports = !imports;
          questions;
          sets = !sets;
        }
      in
      (* The selected question's starting budgets apply; a library has none. *)
      Ok (match select_question spec selected.q_name with Ok selected -> selected | Error _ -> spec)
  | errors -> Error errors
