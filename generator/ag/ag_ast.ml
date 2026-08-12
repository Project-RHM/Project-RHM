(* ag_ast.ml
   The abstract syntax of the .ag question-grammar language.

   A .ag file describes one question type completely: what shapes to generate
   (productions + budgets), what the answer is, and how the question reads.
   This module is only the shape of a parsed file; Ag_check turns a declaration
   list into a validated [spec], and the generation engine consumes that. *)

type position = { line : int; column : int }

let dummy_position = { line = 0; column = 0 }

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

(* ------------------------------------------------------------------ *)
(* Clauses inside a rule body.                                         *)
(* ------------------------------------------------------------------ *)

type equation =
  | Assign of string * expr * position
      (* [len = -1] for an inherited budget, [value = ...] for a synthesized
         attribute. Which one it is depends on how the name was declared, so
         the parser does not distinguish them; Ag_check does. *)
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

let symbol_name = function
  | Symbol name -> name
  | Generator (name, _) -> name
  | Literal text -> text

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
  | Precedence_decl of int * associativity * string list * position
  | Prompt_decl of string * position
  | Answer_decl of expr * position
  | Width_decl of int * position
  | Rule_decl of rule

let declaration_position = function
  | Inherited_decl (_, _, _, position)
  | Random_decl (_, _, position)
  | Let_decl (_, _, position)
  | Synthesized_decl (_, _, position)
  | Start_decl (_, position)
  | Precedence_decl (_, _, _, position)
  | Prompt_decl (_, position)
  | Answer_decl (_, position)
  | Width_decl (_, position) -> position
  | Rule_decl rule -> rule.rule_position

type file = declaration list
