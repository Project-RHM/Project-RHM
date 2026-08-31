(* ag_parser.mly — grammar of the .ag question-grammar language.

   This is the "grammar of the grammar file": menhir turns it into the parser
   that reads whatever a user writes in a .ag file. *)

%{
open Ag_ast

let position (start : Lexing.position) =
  {
    line = start.Lexing.pos_lnum;
    column = start.Lexing.pos_cnum - start.Lexing.pos_bol + 1;
  }
%}

%token ATTRIBUTE SYNTH START CONTEXT PRECEDENCE LEFT RIGHT NONASSOC
%token RANDOM LET BOOLEAN ON
%token COPY SPLIT WHEN WEIGHT REQUIRE PROMPT ANSWER WIDTH
%token AND OR NOT
%token ARROW CONCAT NEQ LE GE EQ LT GT
%token PLUS MINUS STAR SLASH PERCENT CARET
%token DOT COMMA LPAREN RPAREN LBRACE RBRACE
%token UMINUS
%token <int> DOLLAR
%token <int> INT
%token <string> IDENT
%token <string> STRING
%token EOF

%left OR
%left AND
%right NOT
%nonassoc EQ NEQ LT LE GT GE
%right CONCAT
%left PLUS MINUS
%left STAR SLASH PERCENT
%right CARET
%nonassoc UMINUS

%start <Ag_ast.file> file

%%

file:
  | declarations = declaration* EOF { declarations }

declaration:
  | ATTRIBUTE; name = IDENT; EQ; initial = signed_int;
    mode = ioption(distribution)
      { Inherited_decl
          (name, initial,
           (match mode with Some mode -> mode | None -> Copy),
           position $startpos) }

  (* Drawn once per question. A truth assignment cannot be drawn at the leaves,
     because every occurrence of the same variable has to agree. *)
  | RANDOM; name = IDENT; EQ; how = draw
      { Random_decl (name, how, position $startpos) }

  (* Computed once per question, from the randoms; mainly for the prompt. *)
  | LET; name = IDENT; EQ; body = expr
      { Let_decl (name, body, position $startpos) }

  | SYNTH; name = IDENT; scope = ioption(preceded(ON, IDENT))
      { Synthesized_decl (name, scope, position $startpos) }

  | START; name = IDENT
      { Start_decl (name, position $startpos) }

  | CONTEXT; name = STRING
      { Context_decl (name, position $startpos) }

  | PRECEDENCE; level = INT; associativity = associativity;
    operators = nonempty_list(operator_name)
      { Precedence_decl (level, associativity, operators, position $startpos) }

  | PROMPT; template = STRING
      { Prompt_decl (template, position $startpos) }

  | ANSWER; body = expr
      { Answer_decl (body, position $startpos) }

  | WIDTH; columns = INT
      { Width_decl (columns, position $startpos) }

  | rule = rule
      { Rule_decl rule }

(* The generator name is not checked here; Ag_check reports an unknown one
   with its position, which reads better than a bare syntax error. *)
draw:
  | BOOLEAN                                        { Draw_boolean }
  | name = IDENT; LPAREN; args = arguments; RPAREN { Draw_generator (name, args) }

distribution:
  | COPY  { Copy }
  | SPLIT { Split }

associativity:
  | LEFT     { Left }
  | RIGHT    { Right }
  | NONASSOC { Nonassoc }

(* Precedence declarations name operators only. Bare identifiers are excluded
   on purpose: they would be indistinguishable from the left-hand side of the
   rule that follows. *)
operator_name:
  | PLUS    { "+" }
  | MINUS   { "-" }
  | STAR    { "*" }
  | SLASH   { "/" }
  | PERCENT { "%" }
  | CARET   { "^" }
  | text = STRING { text }

signed_int:
  | value = INT         { value }
  | MINUS; value = INT  { - value }

(* ------------------------------------------------------------------ *)
(* Rules                                                               *)
(* ------------------------------------------------------------------ *)

(* A rule always ends with a brace block, even an empty one. That makes the
   end of a rule unambiguous, so the rule that follows can begin with a bare
   identifier without any lookahead trickery. *)
rule:
  | lhs = IDENT; ARROW; rhs = nonempty_list(symbol);
    guard = ioption(guard); weight = ioption(weight);
    LBRACE; equations = equations; RBRACE
      { {
          lhs;
          rhs;
          guard;
          weight = (match weight with Some weight -> weight | None -> 1);
          equations;
          rule_position = position $startpos;
        } }

guard:
  | WHEN; condition = expr { condition }

weight:
  | WEIGHT; value = INT { value }

symbol:
  | name = IDENT                                          { Symbol name }
  | name = IDENT; LPAREN; args = arguments; RPAREN        { Generator (name, args) }
  | text = STRING                                         { Literal text }
  | PLUS                                                  { Symbol "+" }
  | MINUS                                                 { Symbol "-" }
  | STAR                                                  { Symbol "*" }
  | SLASH                                                 { Symbol "/" }
  | PERCENT                                               { Symbol "%" }
  | CARET                                                 { Symbol "^" }

equations:
  | equations = list(terminated(equation, ioption(COMMA))) { equations }

equation:
  | name = IDENT; EQ; body = expr
      { Assign (name, body, position $startpos) }
  | REQUIRE; condition = expr
      { Require (condition, position $startpos) }

(* ------------------------------------------------------------------ *)
(* Expressions                                                         *)
(* ------------------------------------------------------------------ *)

arguments:
  | args = separated_list(COMMA, expr) { args }

expr:
  | value = INT                       { Int value }
  | text = STRING                     { Str text }
  | name = IDENT                      { Attr_here name }
  | owner = IDENT; DOT; name = IDENT  { Attr_child_named (owner, name) }
  | index = DOLLAR                    { Child index }
  | index = DOLLAR; DOT; name = IDENT { Attr_child (index, name) }

  | name = IDENT; LPAREN; args = arguments; RPAREN { Call (name, args) }

  | LPAREN; body = expr; RPAREN       { body }

  | MINUS; body = expr %prec UMINUS   { Unary ("-", body) }
  | NOT; body = expr                  { Unary ("not", body) }

  | left = expr; PLUS;    right = expr { Binary ("+",   left, right) }
  | left = expr; MINUS;   right = expr { Binary ("-",   left, right) }
  | left = expr; STAR;    right = expr { Binary ("*",   left, right) }
  | left = expr; SLASH;   right = expr { Binary ("/",   left, right) }
  | left = expr; PERCENT; right = expr { Binary ("%",   left, right) }
  | left = expr; CARET;   right = expr { Binary ("^",   left, right) }
  | left = expr; CONCAT;  right = expr { Binary ("++",  left, right) }
  | left = expr; EQ;      right = expr { Binary ("=",   left, right) }
  | left = expr; NEQ;     right = expr { Binary ("!=",  left, right) }
  | left = expr; LT;      right = expr { Binary ("<",   left, right) }
  | left = expr; LE;      right = expr { Binary ("<=",  left, right) }
  | left = expr; GT;      right = expr { Binary (">",   left, right) }
  | left = expr; GE;      right = expr { Binary (">=",  left, right) }
  | left = expr; AND;     right = expr { Binary ("and", left, right) }
  | left = expr; OR;      right = expr { Binary ("or",  left, right) }
