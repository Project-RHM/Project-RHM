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
  (* The mistakes the file declares, each with what the student does, in
     declaration order. Every one has a line in some rule. *)
  mistakes : (string * string) list;
  (* The types the checker inferred: of each synthesized attribute, by
     nonterminal and name, and of each random and let. An importer reads
     them to check what it does with `alias.F` and `alias.NAME`; nothing in
     the language declares them. *)
  attribute_types : ((string * string) * Rhema_types.set) list;
  value_types : (string * Rhema_types.set) list;
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

(* Builtins usable inside an attribute equation, with how many arguments each
   takes. The names, the arities and the types all come from one table, in
   Rhema_types, which the tests hold against the engine. *)
let expression_builtins =
  List.map
    (fun (entry : Rhema_types.signature) -> (entry.builtin, List.length entry.parameters))
    Rhema_types.builtins

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

(* Calls [f position node] on every node of [expression]. [position] is
   where that node was written: the place the nearest [At] around it records,
   or the given [position] (its declaration's) when there is none. *)
let rec iter_expr ~position f expression =
  match expression with
  | At (here, body) -> iter_expr ~position:here f body
  | _ -> (
      f position expression;
      match expression with
      | Int _ | Str _ | Bool _ | Attr_here _ | Attr_child _ | Attr_child_named _ | Child _ | At _ -> ()
      | Unary (_, body) -> iter_expr ~position f body
      | Binary (_, left, right) ->
          iter_expr ~position f left;
          iter_expr ~position f right
      | Call (_, arguments) -> List.iter (iter_expr ~position f) arguments)

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
(* Types                                                               *)
(* ------------------------------------------------------------------ *)

(* What an expression can see, as types. Each lookup answers None for a name
   that carries no type here (the checks above have already refused names
   that do not exist), and the expression is then taken to be of any type. *)
type type_scope = {
  here : string -> Rhema_types.set option;  (* a bare name *)
  child : int -> string -> Rhema_types.set option;  (* $n.NAME *)
  named : string -> string -> Rhema_types.set option;  (* S.NAME, alias.NAME *)
  target : string;  (* the attribute being computed, which infix joins *)
}

(* How an expression is named in a message. *)
let rec expression_subject = function
  | At (_, body) -> expression_subject body
  | Int value -> string_of_int value
  | Str text ->
      if String.length text <= 20 then "\"" ^ text ^ "\"" else "this text"
  | Bool truth -> string_of_bool truth
  | Attr_here name -> "'" ^ name ^ "'"
  | Attr_child (index, name) -> Printf.sprintf "$%d.%s" index name
  | Attr_child_named (owner, name) -> owner ^ "." ^ name
  | Child index -> Printf.sprintf "$%d" index
  | Call (name, _) -> name ^ "(...)"
  | Unary _ | Binary _ -> "this expression"

let expression_position ~position = function At (here, _) -> here | _ -> position

let ordinal index =
  match index with 1 -> "first" | 2 -> "second" | 3 -> "third" | 4 -> "fourth"
  | n -> string_of_int n ^ "th"

(* The types [expression] can have, and a report of every use in it that no
   type its operand can have allows. A use that some type allows is left to
   the engine, and so is anything about the value itself: whether a number
   is whole, a divisor zero, a matrix the right shape.

   An operator or function gives its result only when each operand can have
   a type it takes; otherwise the expression has no type at all (the empty
   set), as an expression that can never be evaluated. Two things follow.
   What is built on a wrong use is not reported again, since nothing is ever
   refused for having no type. And a set never loses a type as the sets it
   is computed from grow, which is what makes the result the same whatever
   order the rules are read in: a wrong leaf in a recursive rule is found
   because the rule's own operator does not vouch for it. *)
let rec infer_type ~report ~position scope expression : Rhema_types.set =
  let open Rhema_types in
  let recurse = infer_type ~report ~position scope in
  match expression with
  | At (here, body) -> infer_type ~report ~position:here scope body
  | Int _ -> [ Number ]
  | Str _ -> [ Text ]
  | Bool _ -> [ Truth ]
  | Attr_here name -> Option.value ~default:any (scope.here name)
  | Attr_child (index, name) -> Option.value ~default:any (scope.child index name)
  | Attr_child_named (owner, name) -> Option.value ~default:any (scope.named owner name)
  | Child index ->
      (* Only infix and prefix take a child itself; they do not come here. *)
      report position
        (Printf.sprintf "$%d is a node, not a value; write $%d.value, or pass it to infix()" index
           index);
      unknown
  | Unary (operator, body) -> (
      let actual = recurse body in
      match unary operator with
      | None -> any
      | Some (accepted, result) ->
          if never actual accepted then
            report
              (expression_position ~position body)
              (Printf.sprintf "'%s' takes %s, but %s is %s" operator (describe accepted)
                 (expression_subject body) (describe actual));
          if inter actual accepted = [] then unknown else result)
  | Binary (operator, left, right) -> (
      let left_type = recurse left and right_type = recurse right in
      let side which body actual accepted =
        if never actual accepted then
          report
            (expression_position ~position body)
            (Printf.sprintf "'%s' takes %s on its %s, but %s is %s" operator
               (describe accepted) which (expression_subject body) (describe actual))
      in
      match binary operator with
      | None -> any
      | Some (Both (accepted, result)) ->
          side "left" left left_type accepted;
          side "right" right right_type accepted;
          if inter left_type accepted = [] || inter right_type accepted = [] then unknown
          else result
      | Some Join ->
          side "left" left left_type joinable;
          side "right" right right_type joinable;
          (* Blanks on either side make text with blanks; text needs both
             sides without them. *)
          let left_type = inter left_type joinable and right_type = inter right_type joinable in
          if left_type = [] || right_type = [] then unknown
          else
            let plain actual = without actual [ Blanked ] <> [] in
            union
              (if List.mem Blanked left_type || List.mem Blanked right_type then [ Blanked ]
               else [])
              (if plain left_type && plain right_type then [ Text ] else [])
      | Some Same ->
          if
            left_type <> [] && right_type <> []
            && inter (inter left_type right_type) comparable = []
          then
            report
              (expression_position ~position left)
              (if inter left_type comparable = [] then
                 Printf.sprintf "'%s' cannot compare %s (%s)" operator (describe left_type)
                   (expression_subject left)
               else if inter right_type comparable = [] then
                 Printf.sprintf "'%s' cannot compare %s (%s)" operator (describe right_type)
                   (expression_subject right)
               else
                 Printf.sprintf
                   "'%s' compares two values of one type, but %s is %s and %s is %s" operator
                   (expression_subject left) (describe left_type) (expression_subject right)
                   (describe right_type));
          if inter (inter left_type right_type) comparable = [] then unknown else [ Truth ])
  | Call (name, arguments) -> (
      match signature name with
      | Some entry when List.length entry.parameters = List.length arguments -> (
          (* For each argument: the types it can have, and whether one of
             them is taken. *)
          let actuals =
            List.mapi
              (fun index (parameter, argument) ->
                match parameter with
                | Node -> (
                    (* infix and prefix write a child's own copy of the
                       attribute being computed, as text. *)
                    match argument with
                    | Child child | At (_, Child child) -> (
                        match scope.child child scope.target with
                        | Some actual ->
                            if never actual textual then
                              report
                                (expression_position ~position argument)
                                (Printf.sprintf
                                   "%s writes the '%s' of $%d as text, but $%d.%s is %s" name
                                   scope.target child child scope.target (describe actual));
                            (any, inter actual textual <> [])
                        | None -> (any, true))
                    | _ ->
                        report
                          (expression_position ~position argument)
                          (Printf.sprintf
                             "%s takes a child written $n as its %s argument, for example \
                              %s, but %s is a value"
                             name (ordinal (index + 1))
                             (if name = "infix" then "infix($1, \"+\", $3)"
                              else "prefix(\"-\", $2)")
                             (expression_subject argument));
                        (any, false))
                | Takes accepted ->
                    let actual = recurse argument in
                    if never actual accepted then
                      report
                        (expression_position ~position argument)
                        (Printf.sprintf "%s takes %s as its %s argument, but %s is %s" name
                           (describe accepted) (ordinal (index + 1))
                           (expression_subject argument) (describe actual));
                    (actual, inter actual accepted <> []))
              (List.combine entry.parameters arguments)
          in
          match entry.result with
          | Gives result -> if List.for_all snd actuals then result else unknown
          | Either ->
              (* Only the test decides whether cond has a value; a branch
                 that has none simply adds nothing. *)
              if snd (List.nth actuals 0) then
                union (fst (List.nth actuals 1)) (fst (List.nth actuals 2))
              else unknown)
      | _ ->
          (* An unknown name or a wrong count is reported elsewhere. *)
          List.iter (fun argument -> ignore (recurse argument)) arguments;
          any)

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
  let mistakes : (string * string * position) list ref = ref [] in

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
      | Mistake_decl (name, description, position) ->
          if List.exists (fun (other, _, _) -> other = name) !mistakes then
            report position (Printf.sprintf "mistake '%s' is declared more than once" name);
          if String.trim description = "" then
            report position
              (Printf.sprintf
                 "mistake '%s' needs a description: say in a few words what the student does"
                 name);
          mistakes := !mistakes @ [ (name, description, position) ]
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
  let mistakes = !mistakes in
  let is_mistake name = List.exists (fun (other, _, _) -> other = name) mistakes in
  (* The mistakes some rule has a line for; one with none is refused below. *)
  let mistakes_made = ref [] in

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
    iter_expr ~position
      (fun position node ->
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
              | None -> (
                  (* A leaf -- a generator, a quoted word, an operator or any
                     symbol with no productions -- carries exactly one
                     attribute, `value`, whether or not the file declares it. *)
                  let leaf =
                    match List.nth_opt rhs (index - 1) with
                    | Some (Generator _ | Literal _) -> true
                    | Some (Symbol symbol) -> not (is_nonterminal symbol)
                    | _ -> false
                  in
                  if leaf then begin
                    if name <> "value" then
                      report position
                        (Printf.sprintf
                           "$%d is a leaf, which carries only 'value'; write str($%d.value) to \
                            render it"
                           index index)
                  end
                  else if not (is_synthesized name) then
                    report position
                      (Printf.sprintf
                         "'%s' is not a synthesized attribute, so a child does not \
                          carry it"
                         name)))
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
        | Int _ | Str _ | Bool _ | Unary _ | Binary _ | At _ -> ())
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
      iter_expr ~position
        (fun position node ->
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
      let mistaken = ref [] in
      List.iter
        (fun equation ->
          match equation with
          | Mistake (mistake, name, body, position) ->
              (* What a student who makes the mistake computes in place of a
                 value the rule has already computed. It is evaluated where it
                 is written, so it may use everything above it, the right
                 value of its own name included. *)
              if not (is_mistake mistake) then
                report position
                  (Printf.sprintf
                     "mistake '%s' is not declared; add 'mistake %s \"...\"' with what the \
                      student does%s"
                     mistake mistake
                     (match mistakes with
                     | [] -> ""
                     | declared ->
                         "; the declared mistakes are "
                         ^ String.concat ", " (List.map (fun (other, _, _) -> other) declared)))
              else if not (List.mem mistake !mistakes_made) then
                mistakes_made := mistake :: !mistakes_made;
              if is_inherited name then
                report position
                  (Printf.sprintf
                     "'%s' is an inherited attribute; a mistake changes what is computed \
                      from the tree, not the budget that built it"
                     name)
              else if not (List.mem name !assigned) then
                report position
                  (Printf.sprintf
                     "a mistake line gives another value to something the rule has \
                      computed; '%s' is not computed above this line"
                     name)
              else if List.mem (mistake, name) !mistaken then
                report position
                  (Printf.sprintf "'%s' already has a line for the mistake '%s' in this rule"
                     name mistake);
              mistaken := (mistake, name) :: !mistaken;
              check_expr ~assigned_here:(List.rev !assigned) ~rhs:rule.rhs ~context:`Upward
                ~arity ~position body
          | Require (condition, position) ->
              check_expr ~assigned_here:(List.rev !assigned) ~rhs:rule.rhs ~context:`Upward
                ~arity ~position condition
          | Local (name, body, position) ->
              (* A name for this rule only. It must be new: hiding an
                 attribute or a question-level value would make the lines
                 below it mean something else than they do everywhere else. *)
              let clash =
                if is_inherited name then
                  Some
                    (Printf.sprintf
                       "let '%s' would hide the inherited attribute '%s'; choose another name"
                       name name)
                else if is_synthesized name then
                  Some
                    (Printf.sprintf
                       "'%s' is a synthesized attribute; write '%s = ...' without 'let' to \
                        compute it, or choose another name for a local value"
                       name name)
                else if is_question_level name then
                  Some
                    (Printf.sprintf
                       "let '%s' would hide the question-level '%s'; choose another name" name
                       name)
                else if List.mem name !assigned then
                  Some (Printf.sprintf "'%s' is assigned twice in the same rule" name)
                else None
              in
              check_expr ~assigned_here:(List.rev !assigned) ~rhs:rule.rhs ~context:`Upward
                ~arity ~position body;
              (* A refused name is not recorded, so the one mistake is
                 reported once and the attribute of that name is still asked
                 for below. *)
              (match clash with
              | Some message -> report position message
              | None -> assigned := name :: !assigned)
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

  (* A mistake no rule makes would never be looked for, and a file that
     declares it would seem to guard against it. *)
  List.iter
    (fun (name, _, position) ->
      if not (List.mem name !mistakes_made) then
        report position
          (Printf.sprintf
             "mistake '%s' is made in no rule; add a line 'mistake %s ATTRIBUTE = ...' to \
              the rule where a student makes it"
             name name))
    mistakes;

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
              consume a budget, for example 'cost = -1'"
             rule.lhs))
    free_rules;

  (* Whether some text of this file, or of a module it imports, may hold an
     answer blank: a rule or a let calls blank or blank_wide. *)
  let text_may_hold_blanks =
    let calls_blank expression =
      let found = ref false in
      iter_expr ~position:dummy_position
        (fun _ node ->
          match node with
          | Call (name, _) -> (
              match Rhema_types.signature name with
              | Some { result = Rhema_types.Gives [ Rhema_types.Blanked ]; _ } -> found := true
              | _ -> ())
          | _ -> ())
        expression;
      !found
    in
    let in_rules rules =
      List.exists
        (fun rule ->
          List.exists
            (function
              | Assign (_, body, _)
              | Local (_, body, _)
              | Require (body, _)
              | Mistake (_, _, body, _) -> calls_blank body)
            rule.equations)
        rules
    in
    let in_lets lets = List.exists (fun (_, body) -> calls_blank body) lets in
    let rec in_module (module_spec : spec) =
      in_rules module_spec.rules || in_lets module_spec.lets
      || List.exists (fun (_, imported) -> in_module imported) module_spec.imports
    in
    in_rules rules || in_lets lets || List.exists (fun (_, imported) -> in_module imported) modules
  in

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
          (* Text may bring its own blanks (blank(...) joined with ++); which
             text reaches the prompt is known only when a question is made,
             so a file that calls blank anywhere is given the benefit of the
             doubt, and a question that ends up with no blank is refused then. *)
          if not (inline_blanks || text_may_hold_blanks) then
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
          iter_expr ~position
            (fun position node ->
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

  (* ---- types ----
     Only a file that passes everything above is typed: an undeclared name
     has no type, and guessing one would report the same mistake twice.

     The type of a synthesized attribute is the set of types its equations
     can give it, over every rule of its nonterminal, and it is kept by
     nonterminal: `value` on E and `value` on Q are different attributes.
     The sets start empty and the rules are read until none grows, so a
     recursive rule and the order of declarations make no difference. *)
  let attribute_types : (string * string, Rhema_types.set) Hashtbl.t = Hashtbl.create 64 in
  let value_types = ref [] in
  if !errors = [] then begin
    let module T = Rhema_types in
    let silent _ _ = () in
    (* A hole written twice in one prompt is one mistake, not two. *)
    let said = ref [] in
    let report position message =
      if not (List.mem (position, message) !said) then begin
        said := (position, message) :: !said;
        report position message
      end
    in
    let module_value alias name =
      match module_of alias with
      | Some module_spec -> List.assoc_opt name module_spec.value_types
      | None -> None
    in
    (* A random is a truth value or a drawn number; a let is whatever its
       expression gives, read in order. *)
    List.iter
      (fun (name, how) ->
        value_types :=
          !value_types @ [ (name, match how with Draw_boolean -> [ T.Truth ] | Draw_generator _ -> [ T.Number ]) ])
      randoms;
    let value_scope () =
      let known = !value_types in
      {
        here = (fun name -> List.assoc_opt name known);
        child = (fun _ _ -> None);
        named = module_value;
        target = "";
      }
    in
    List.iter
      (fun (name, body) ->
        let position =
          match
            List.find_opt (function Let_decl (other, _, _) -> other = name | _ -> false) declarations
          with
          | Some declaration -> declaration_position declaration
          | None -> dummy_position
        in
        let inferred = infer_type ~report ~position (value_scope ()) body in
        value_types := !value_types @ [ (name, inferred) ])
      lets;
    let value_types = !value_types in
    let attribute_type nonterminal name =
      if List.mem name (synthesized_of nonterminal) then
        Some (Option.value ~default:T.unknown (Hashtbl.find_opt attribute_types (nonterminal, name)))
      else None
    in
    (* Before the children exist: the question-level values and the
       budgets, which are whole numbers. *)
    let downward =
      {
        here =
          (fun name ->
            match List.assoc_opt name value_types with
            | Some known -> Some known
            | None -> if is_inherited name then Some [ T.Number ] else None);
        child = (fun _ _ -> None);
        named = module_value;
        target = "";
      }
    in
    (* After them: what this rule has computed so far, then the same. The
       children's attributes are read through [attribute_type], which is the
       right working's or a mistake's. *)
    let upward_with attribute_type rule known target =
      {
        here =
          (fun name ->
            match List.assoc_opt name known with
            | Some computed -> Some computed
            | None -> downward.here name);
        child =
          (fun index name ->
            match List.nth_opt rule.rhs (index - 1) with
            | Some (Symbol symbol) when is_nonterminal symbol -> attribute_type symbol name
            | Some (Symbol _ | Literal _) -> if name = "value" then Some T.terminal_value else None
            | Some (Generator _) -> if name = "value" then Some T.generator_value else None
            | Some (Module_symbol (alias, nonterminal, _)) -> (
                match module_of alias with
                | Some module_spec -> List.assoc_opt (nonterminal, name) module_spec.attribute_types
                | None -> None)
            | None -> None);
        named = module_value;
        target;
      }
    in
    let upward = upward_with attribute_type in
    (* One reading of a rule's body, as the right working. [report] is silent
       while the sets are still growing. A mistake line is no part of it. *)
    let read_rule ~report rule =
      let grew = ref false in
      let known = ref [] in
      List.iter
        (fun equation ->
          match equation with
          | Assign (name, body, position) when is_inherited name ->
              let actual = infer_type ~report ~position downward body in
              if T.never actual [ T.Number ] then
                report position
                  (Printf.sprintf
                     "the budget '%s' changes by a whole number, but this update is %s" name
                     (T.describe actual))
          | Assign (name, body, position) ->
              let inferred = infer_type ~report ~position (upward rule !known name) body in
              known := (name, inferred) :: List.remove_assoc name !known;
              let before =
                Option.value ~default:T.unknown (Hashtbl.find_opt attribute_types (rule.lhs, name))
              in
              let after = T.union before inferred in
              if after <> before then begin
                Hashtbl.replace attribute_types (rule.lhs, name) after;
                grew := true
              end
          | Local (name, body, position) ->
              let inferred = infer_type ~report ~position (upward rule !known name) body in
              known := (name, inferred) :: List.remove_assoc name !known
          | Require (condition, position) ->
              let actual = infer_type ~report ~position (upward rule !known "") condition in
              if T.never actual [ T.Truth ] then
                report position
                  (Printf.sprintf "a 'require' must be true or false, but this one is %s"
                     (T.describe actual))
          | Mistake _ -> ())
        rule.equations;
      !grew
    in
    let growing = ref true in
    while !growing do
      growing := false;
      List.iter (fun rule -> if read_rule ~report:silent rule then growing := true) rules
    done;
    (* The same grammar as each mistake works it out. The engine evaluates a
       finished tree again with that mistake's lines read and no requirement
       checked, so the types are found the same way: every rule is read with
       the lines for the mistake giving their names new values, and an
       attribute has, under the mistake, every type some rule then gives it.
       A mistake line may give a value of any kind: one root where a set of
       roots is the answer, the words "no solution" where a number is. What
       is refused is a use that, under the mistake, can never be evaluated,
       because generation stops there every time the mistake is tried. *)
    let read_under ~report mistake table rule =
      let lookup nonterminal name =
        if List.mem name (synthesized_of nonterminal) then
          Some (Option.value ~default:T.unknown (Hashtbl.find_opt table (nonterminal, name)))
        else None
      in
      let known = ref [] in
      let bind name body position =
        let inferred = infer_type ~report ~position (upward_with lookup rule !known name) body in
        known := (name, inferred) :: List.remove_assoc name !known
      in
      List.iter
        (fun equation ->
          match equation with
          | Assign (name, _, _) when is_inherited name -> ()
          | Require _ -> ()
          | Assign (name, body, position) | Local (name, body, position) -> bind name body position
          | Mistake (made, name, body, position) -> if made = mistake then bind name body position)
        rule.equations;
      List.fold_left
        (fun grew (name, inferred) ->
          if List.mem name (synthesized_of rule.lhs) then begin
            let before = Option.value ~default:T.unknown (Hashtbl.find_opt table (rule.lhs, name)) in
            let after = T.union before inferred in
            if after <> before then Hashtbl.replace table (rule.lhs, name) after;
            grew || after <> before
          end
          else grew)
        false !known
    in
    let mistakes_read =
      List.map
        (fun (mistake, _, _) ->
          let table = Hashtbl.create 64 in
          let growing = ref true in
          while !growing do
            growing := false;
            List.iter (fun rule -> if read_under ~report:silent mistake table rule then growing := true) rules
          done;
          (mistake, table))
        mistakes
    in
    (* The sets are final: read everything once more, aloud. *)
    List.iter
      (fun rule ->
        let position = rule.rule_position in
        (match rule.guard with
        | None -> ()
        | Some condition ->
            let actual = infer_type ~report ~position downward condition in
            if T.never actual [ T.Truth ] then
              report
                (expression_position ~position condition)
                (Printf.sprintf "a 'when' condition must be true or false, but this one is %s"
                   (T.describe actual)));
        List.iter
          (fun symbol ->
            match symbol with
            | Generator (name, arguments) ->
                List.iteri
                  (fun index argument ->
                    let actual = infer_type ~report ~position downward argument in
                    if T.never actual [ T.Number ] then
                      report
                        (expression_position ~position argument)
                        (Printf.sprintf "%s takes a number as its %s argument, but %s is %s" name
                           (ordinal (index + 1)) (expression_subject argument) (T.describe actual)))
                  arguments
            | Module_symbol (alias, nonterminal, arguments) ->
                List.iter
                  (fun (name, body) ->
                    let actual = infer_type ~report ~position downward body in
                    if T.never actual [ T.Number ] then
                      report
                        (expression_position ~position body)
                        (Printf.sprintf
                           "%s.%s starts '%s' at a whole number, but %s is %s" alias nonterminal
                           name (expression_subject body) (T.describe actual)))
                  arguments
            | Symbol _ | Literal _ -> ())
          rule.rhs;
        ignore (read_rule ~report rule))
      rules;
    (* Then as each mistake reads it. What the right working already
       reported at the same place is not said again. *)
    List.iter
      (fun (mistake, table) ->
        let report position message =
          if not (List.mem (position, message) !said) then
            report position (Printf.sprintf "under the mistake '%s', %s" mistake message)
        in
        List.iter (fun rule -> ignore (read_under ~report mistake table rule)) rules)
      mistakes_read;
    (* Each question: what its prompt shows, what its blanks are graded
       against, and the attributes the start symbol answers WeBWorK with. *)
    List.iter2
      (fun (draft : draft) (question : question) ->
        let start = question.q_start in
        let prompt_position =
          match draft.d_prompt with Some (_, position) -> position | None -> draft.d_position
        in
        let value_type name =
          match String.index_opt name '.' with
          | Some dot ->
              module_value (String.sub name 0 dot)
                (String.sub name (dot + 1) (String.length name - dot - 1))
          | None -> List.assoc_opt name value_types
        in
        let shown written = function
          | Some actual when T.never actual T.showable ->
              report prompt_position
                (Printf.sprintf "{%s} is %s, which a prompt cannot show; a prompt shows text and numbers%s"
                   written (T.describe actual)
                   (if
                      List.exists
                        (fun ty ->
                          List.mem ty
                            T.[ Formula; Polynomial; Equation; Proposition; Matrix; Set; Vector; Point ])
                        actual
                    then ", so write it out first, with the function ending in _latex for its type"
                    else ""))
          | _ -> ()
        and graded position written = function
          | Some actual when T.never actual T.answerable ->
              report position
                (Printf.sprintf
                   "%s is %s, which cannot be graded%s" written (T.describe actual)
                   (if List.mem T.Equation actual then
                      "; ask for its solutions with equation_solution_set or \
                       equation_unique_solution"
                    else "; it already holds its own blanks"))
          | _ -> ()
        in
        List.iter
          (function
            | Text _ -> ()
            | Hole (owner, name) -> shown (owner ^ "." ^ name) (attribute_type start name)
            | Value_hole name -> shown name (value_type name)
            | Answer_hole (owner, name) ->
                graded prompt_position
                  (Printf.sprintf "{answer %s.%s}" owner name)
                  (attribute_type start name)
            | Answer_value_hole name ->
                graded prompt_position (Printf.sprintf "{answer %s}" name) (value_type name))
          question.q_prompt;
        (match (question.q_answer, draft.d_answer) with
        | Some body, Some (_, position) ->
            let scope =
              {
                here = (fun _ -> None);
                child = (fun _ _ -> None);
                named =
                  (fun owner name ->
                    if owner = start then attribute_type start name else module_value owner name);
                target = "";
              }
            in
            graded position "the answer" (Some (infer_type ~report ~position scope body))
        | _ -> ());
        let reserved name accepted =
          let actual =
            match attribute_type start name with
            | Some actual -> Some actual
            | None -> if name = "pg_variables" then List.assoc_opt name value_types else None
          in
          match actual with
          | Some actual when T.never actual accepted ->
              report
                (if draft.d_position = dummy_position then prompt_position else draft.d_position)
                (Printf.sprintf "'%s' must be %s, but %s computes it as %s" name
                   (T.describe accepted)
                   (if attribute_type start name <> None then "'" ^ start ^ "'" else "the file")
                   (T.describe actual))
          | _ -> ()
        in
        reserved "pg_context" T.textual;
        reserved "pg_width" [ T.Number ];
        reserved "pg_variables" T.textual)
      drafts questions
  end;

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
          mistakes = List.map (fun (name, description, _) -> (name, description)) mistakes;
          attribute_types =
            Hashtbl.fold (fun key types collected -> (key, types) :: collected) attribute_types []
            |> List.sort compare;
          value_types = !value_types;
        }
      in
      (* The selected question's starting budgets apply; a library has none. *)
      Ok (match select_question spec selected.q_name with Ok selected -> selected | Error _ -> spec)
  | errors -> Error errors
