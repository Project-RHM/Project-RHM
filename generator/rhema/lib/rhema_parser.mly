(* rhema_parser.mly — grammar of the Rhema question-grammar language.

   This is the "grammar of the grammar file": menhir turns it into the parser
   that reads whatever a user writes in a .rhm file. *)

%{
open Rhema_ast

let position (start : Lexing.position) =
  {
    file = start.Lexing.pos_fname;
    line = start.Lexing.pos_lnum;
    column = start.Lexing.pos_cnum - start.Lexing.pos_bol + 1;
  }

(* The words inside a `set` block -- part, of, any, in, spread, low, allowed,
   distinct, balanced, ordered -- are not reserved: a grammar may still name
   an attribute `low`. They are plain identifiers that the actions below
   check, so a wrong word is reported as the word that was expected. *)
let expect_word expected (found : string) start =
  if found <> expected then
    raise
      (Syntax_error
         (Printf.sprintf "expected '%s' here, not '%s'" expected found, position start))

let expect_one_of expected (found : string) start =
  if not (List.mem found expected) then
    raise
      (Syntax_error
         ( Printf.sprintf "expected one of %s here, not '%s'"
             (String.concat ", " (List.map (fun word -> "'" ^ word ^ "'") expected))
             found,
           position start ))
%}

%token ATTRIBUTE SYNTH START CONTEXT PRECEDENCE LEFT RIGHT NONASSOC
%token RANDOM LET BOOLEAN ON
%token COPY SPLIT WHEN WEIGHT REQUIRE PROMPT ANSWER WIDTH INCLUDE IMPORT AS QUESTION SET
%token TILDE
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

%start <Rhema_ast.file> file

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

  | INCLUDE; name = STRING
      { Include_decl (name, position $startpos) }

  | IMPORT; name = STRING; AS; alias = IDENT
      { Import_decl (name, alias, position $startpos) }

  (* A named question type. Its body holds the declarations a grammar makes
     once, for this question, and starting values for inherited attributes. *)
  | QUESTION; name = IDENT; LBRACE; items = question_item*; RBRACE
      { Question_decl (name, items, position $startpos) }

  (* A whole assignment: parts, entries and constraints. *)
  | SET; name = IDENT; LBRACE; items = set_item*; RBRACE
      { Set_decl { set_name = name; set_items = items; set_position = position $startpos } }

  | rule = rule
      { Rule_decl rule }

(* ------------------------------------------------------------------ *)
(* Sets                                                                *)
(* ------------------------------------------------------------------ *)

set_item:
  (* part "Heading" -- or a bare word: part, distinct, balanced, ordered *)
  | word = IDENT; heading = STRING
      { expect_word "part" word $startpos;
        Set_part (Some heading, position $startpos) }
  | word = IDENT
      { expect_one_of [ "part"; "distinct"; "balanced"; "ordered" ] word $startpos;
        match word with
        | "part" -> Set_part (None, position $startpos)
        | "distinct" -> Set_distinct (position $startpos)
        | "balanced" -> Set_balanced (position $startpos)
        | _ -> Set_ordered (position $startpos) }
  | count = INT; word = IDENT; choices = set_choice
      { expect_word "of" word $startpos(word);
        Set_entry { se_count = count; se_choices = choices; se_position = position $startpos } }

(* One question type, or any(...) of several. *)
set_choice:
  | question = set_question                                      { [ question ] }
  | word = IDENT; LPAREN;
    questions = separated_nonempty_list(COMMA, set_question); RPAREN
      { expect_word "any" word $startpos; questions }

set_question:
  | name = IDENT; draws = ioption(set_draws)
      { { sq_alias = None; sq_name = name;
          sq_draws = (match draws with Some draws -> draws | None -> []);
          sq_position = position $startpos } }
  | alias = IDENT; DOT; name = IDENT; draws = ioption(set_draws)
      { { sq_alias = Some alias; sq_name = name;
          sq_draws = (match draws with Some draws -> draws | None -> []);
          sq_position = position $startpos } }

set_draws:
  | LPAREN; draws = separated_list(COMMA, set_draw); RPAREN { draws }

set_draw:
  | name = IDENT; EQ; value = signed_int
      { (name, Fixed value) }
  | name = IDENT; word = IDENT; LBRACE; values = separated_nonempty_list(COMMA, signed_int); RBRACE
      { expect_word "in" word $startpos(word); (name, Among values) }
  | name = IDENT; TILDE; mean = signed_int; options = around_option*
      { let spread = ref 2 and low = ref 0 and allowed = ref None in
        List.iter
          (fun (word, value, start) ->
            match (word, value) with
            | "spread", Around_int value -> spread := value
            | "low", Around_int value -> low := value
            | "allowed", Around_list values -> allowed := Some values
            | ("spread" | "low"), Around_list _ ->
                raise (Syntax_error (word ^ " takes one whole number", position start))
            | "allowed", Around_int _ ->
                raise (Syntax_error ("allowed takes a list in braces, such as {4, 6, 8}", position start))
            | _ -> expect_one_of [ "spread"; "low"; "allowed" ] word start)
          options;
        (name, Around { mean; spread = !spread; low = !low; allowed = !allowed }) }

around_option:
  | word = IDENT; value = signed_int                                        { (word, Around_int value, $startpos) }
  | word = IDENT; LBRACE; values = separated_nonempty_list(COMMA, signed_int); RBRACE
      { (word, Around_list values, $startpos) }

question_item:
  | START; name = IDENT                     { Q_start (name, position $startpos) }
  | CONTEXT; name = STRING                  { Q_context (name, position $startpos) }
  | PROMPT; template = STRING               { Q_prompt (template, position $startpos) }
  | ANSWER; body = expr                     { Q_answer (body, position $startpos) }
  | WIDTH; columns = INT                    { Q_width (columns, position $startpos) }
  | name = IDENT; EQ; value = signed_int    { Q_default (name, value, position $startpos) }

(* The generator name is not checked here; Rhema_check reports an unknown one
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
  (* A nonterminal of an imported module, with the starting values of the
     module's inherited attributes. The dot tells it apart from a generator. *)
  | alias = IDENT; DOT; name = IDENT                      { Module_symbol (alias, name, []) }
  | alias = IDENT; DOT; name = IDENT;
    LPAREN; args = named_arguments; RPAREN                { Module_symbol (alias, name, args) }
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

named_arguments:
  | args = separated_list(COMMA, named_argument) { args }

named_argument:
  | name = IDENT; EQ; body = expr { (name, body) }

expr:
  | value = INT                       { Int value }
  | text = STRING                     { Str text }
  | name = IDENT                      { At (position $startpos, Attr_here name) }
  | owner = IDENT; DOT; name = IDENT  { At (position $startpos, Attr_child_named (owner, name)) }
  | index = DOLLAR                    { At (position $startpos, Child index) }
  | index = DOLLAR; DOT; name = IDENT { At (position $startpos, Attr_child (index, name)) }

  | name = IDENT; LPAREN; args = arguments; RPAREN { At (position $startpos, Call (name, args)) }

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
