(* rhema_ast.ml
   The abstract syntax of the Rhema question-grammar language.

   A .rhm file describes one question type completely: what shapes to generate
   (productions + budgets), what the answer is, and how the question reads.
   This module is only the shape of a parsed file; Rhema_check turns a declaration
   list into a validated [spec], and the generation engine consumes that. *)

type position = { file : string; line : int; column : int }

let dummy_position = { file = ""; line = 0; column = 0 }

let string_of_position position =
  Printf.sprintf "%d:%d" position.line position.column

(* ------------------------------------------------------------------ *)
(* Expressions on the right-hand side of an attribute equation.        *)
(* ------------------------------------------------------------------ *)

type expr =
  | Int of int
  | Str of string
  | Attr_here of string
      (* [len] — an inherited attribute of the node being built *)
  | Attr_child of int * string
      (* [$1.value] — an attribute of the child at that position *)
  | Attr_child_named of string * string
      (* [E.latex] — an attribute of a symbol named by its nonterminal, used by
         the top-level [prompt] and [answer] declarations *)
  | Child of int
      (* [$1] — the child node itself, for builtins such as infix *)
  | Unary of string * expr
  | Binary of string * expr * expr
  | Call of string * expr list
      (* [infix($1, "+", $3)], [str($1.value)] *)
  | At of position * expr
      (* Where the expression inside was written. The parser wraps every
         name, child reference and call in one, so that a message about it
         points at it rather than at the start of its equation; evaluation
         looks straight through it. *)

(* ------------------------------------------------------------------ *)
(* Clauses inside a rule body.                                         *)
(* ------------------------------------------------------------------ *)

type equation =
  | Assign of string * expr * position
      (* [len = -1] for an inherited budget, [value = ...] for a synthesized
         attribute. Which one it is depends on how the name was declared, so
         the parser does not distinguish them; Rhema_check does. *)
  | Require of expr * position
      (* [require $3.value != 0] — a generation-time constraint. *)

(* ------------------------------------------------------------------ *)
(* Right-hand side symbols.                                            *)
(* ------------------------------------------------------------------ *)

type symbol =
  | Symbol of string
      (* [E] (a nonterminal, if some rule defines it) or a bare terminal *)
  | Generator of string * expr list
      (* [integer(digit)] — a terminal that produces a random value *)
  | Literal of string
      (* ["\\div"] — a quoted terminal *)
  | Module_symbol of string * string * (string * expr) list
      (* [calc.F(cost = cost - 1)] — a nonterminal of an imported module,
         expanded with that module's rules. The arguments give the starting
         values of the module's inherited attributes for this subtree; any
         not named take the module's declared defaults. *)

let symbol_name = function
  | Symbol name -> name
  | Generator (name, _) -> name
  | Literal text -> text
  | Module_symbol (alias, name, _) -> alias ^ "." ^ name

(* ------------------------------------------------------------------ *)
(* Declarations.                                                       *)
(* ------------------------------------------------------------------ *)

type distribution =
  | Copy
      (* the same value reaches every child *)
  | Split
      (* the remaining budget is divided between the children *)

type associativity =
  | Left
  | Right
  | Nonassoc

type rule = {
  lhs : string;
  rhs : symbol list;
  guard : expr option;
  weight : int;
  equations : equation list;
  rule_position : position;
}

(* How a question-level random value is drawn. *)
type draw =
  | Draw_boolean
  | Draw_generator of string * expr list

(* What a `question NAME { ... }` block may say: the declarations a grammar
   makes once, for this question, plus starting values for the inherited
   attributes at this question's root. *)
type question_item =
  | Q_start of string * position
  | Q_context of string * position
  | Q_prompt of string * position
  | Q_answer of expr * position
  | Q_width of int * position
  | Q_default of string * int * position
      (* cost = 7 -- this question's root starts the attribute there *)

let question_item_position = function
  | Q_start (_, position)
  | Q_context (_, position)
  | Q_prompt (_, position)
  | Q_answer (_, position)
  | Q_width (_, position)
  | Q_default (_, _, position) -> position

(* ------------------------------------------------------------------ *)
(* Sets: a whole assignment described in the file.                      *)
(* ------------------------------------------------------------------ *)

(* How a set draws the starting value of one inherited attribute for the
   questions of an entry. *)
type budget_draw =
  | Fixed of int
      (* cost = 5           every question starts there *)
  | Among of int list
      (* cost in {8, 10, 12}   each question draws one; the list is used
                               evenly before any value repeats *)
  | Around of { mean : int; spread : int; low : int; allowed : int list option }
      (* cost ~ 6 spread 2 [low 1] [allowed {4, 6, 8}]   drawn around the
         mean and adjusted so the entry's mean is exactly the mean *)

(* One question type a set asks for: this file's `main` or a block, or a
   module's through its alias, with the draws for its budgets. *)
type set_question = {
  sq_alias : string option;
  sq_name : string;
  sq_draws : (string * budget_draw) list;
  sq_position : position;
}

(* `4 of calc.derivative(cost ~ 6 spread 2)`, or `2 of any(A, B)`: the
   questions of an entry are drawn evenly from its choices. *)
type set_entry = { se_count : int; se_choices : set_question list; se_position : position }

type set_item =
  | Set_part of string option * position
      (* part "Heading"   the entries that follow are lettered under one number *)
  | Set_entry of set_entry
  | Set_distinct of position
      (* no two questions of the set have the same tree shape *)
  | Set_balanced of position
      (* no three equal coded answers in a row *)
  | Set_ordered of position
      (* within a part, easier first *)

type set_decl = { set_name : string; set_items : set_item list; set_position : position }

(* An option after `~ mean`: `spread 2`, `low 1` or `allowed {4, 6, 8}`. *)
type around_value = Around_int of int | Around_list of int list

(* A word the parser expects at some place inside a set, and did not find. *)
exception Syntax_error of string * position

type declaration =
  | Inherited_decl of string * int * distribution * position
      (* attribute len = 3 split *)
  | Random_decl of string * draw * position
      (* random A = boolean — drawn once per question, constant thereafter.
         A truth assignment cannot be drawn at the leaves, because every
         occurrence of A in one expression has to agree. *)
  | Let_decl of string * expr * position
      (* let ta = cond(A, "T", "F") — computed once per question from the
         randoms, for use in the prompt. *)
  | Synthesized_decl of string * string option * position
      (* synth value          — carried by every nonterminal
         synth left on Q      — carried only by Q, so the other rules are not
                                asked to compute something meaningless to them *)
  | Start_decl of string * position
  | Context_decl of string * position
  | Precedence_decl of int * associativity * string list * position
  | Prompt_decl of string * position
  | Answer_decl of expr * position
  | Width_decl of int * position
  | Include_decl of string * position
      (* include "core.rhm" -- the declarations of another file, resolved by
         the loader before checking *)
  | Import_decl of string * string * position
      (* import "calculus.rhm" as calc -- another file as a module of its own:
         its names are reached as calc.F, calc.cost, calc.given and never
         clash with this file's. Resolved by the loader, which checks the
         module separately. *)
  | Question_decl of string * question_item list * position
      (* question integral { start I  prompt "..."  answer I.value  cost = 5 }
         -- a named question type sharing this file's rules. The file-level
         start, prompt, answer, context and width form the question `main`. *)
  | Set_decl of set_decl
      (* set homework { part "A"  4 of calc.derivative(cost ~ 6 spread 2) ... }
         -- a whole assignment, run with `rhema --run homework`. *)
  | Rule_decl of rule

let declaration_position = function
  | Inherited_decl (_, _, _, position)
  | Random_decl (_, _, position)
  | Let_decl (_, _, position)
  | Synthesized_decl (_, _, position)
  | Start_decl (_, position)
  | Context_decl (_, position)
  | Precedence_decl (_, _, _, position)
  | Prompt_decl (_, position)
  | Answer_decl (_, position)
  | Width_decl (_, position)
  | Include_decl (_, position)
  | Import_decl (_, _, position)
  | Question_decl (_, _, position) -> position
  | Set_decl set -> set.set_position
  | Rule_decl rule -> rule.rule_position

type file = declaration list
