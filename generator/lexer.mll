{
open Parser
exception LexingError of string

(* Auxiliary function: Retrieve the surrounding context near the current position *)
let get_context lexbuf =
  let pos = Lexing.lexeme_start lexbuf in
  let buf = lexbuf.Lexing.lex_buffer in
  let len = Bytes.length buf in
  
  if len = 0 then " (empty buffer)"
  else
    let start = max 0 (pos - 10) in
    let finish = min (len - 1) (pos + 10) in
    
    let context = Bytes.sub_string buf start (finish - start + 1) in
    let marker_pos = pos - start in
    
    (* Create a string with markers *)
    let marked = 
      String.sub context 0 marker_pos ^ 
      ">>>" ^ String.make 1 (Bytes.get buf pos) ^ "<<<" ^
      String.sub context (marker_pos + 1) (String.length context - marker_pos - 1)
    in
    Printf.sprintf " near: '%s'" marked
}

let int = ['0'-'9']+
let id = ['a'-'z' 'A'-'Z' '_']['a'-'z' 'A'-'Z' '0'-'9' '_']*
let number = [ '0'-'9' ]+ '.' [ '0'-'9' ]*
let macro = ['a'-'z' 'A'-'Z']['a'-'z' 'A'-'Z' '0'-'9' '_']* ".pl"

rule read = 
  parse
  | [' ' '\t']+                     { read lexbuf }
  | '\n'                            { NEWLINE }

  | "DOCUMENT"                      { DOCUMENT }
  | "ENDDOCUMENT"                   { ENDDOCUMENT }

  | "loadMacros"                    { LOADMACROS }
  | "PGstandard.pl"                 { PGSTANDARD }
  | "MathObjects.pl"                { MATHOBJECTS }
  | "PGML.pl"                       { PGML }

  | "Context"                       { CONTEXT }
  | "add"                           { ADD_METH }
  | "set"                           { SET_METH }
  | "are"                           { ARE_METH }
  | "undefine"                      { UNDEFINE_METH }
  | "redefine"                      { REDEFINE_METH }

  | "[_____]"                       { BLANK }
  | "answer"                        { ANSWER_WORD }
  | "width"                         { WIDTH_WORD }
  | "What"                          { WHAT_WORD }
  | "is"                            { IS_WORD }
  | "the"                           { THE_WORD }
  | "value"                         { VALUE_WORD }
  | "of"                            { OF_WORD }
  | "equal"                         { EQUAL_WORD }
  | "to"                            { TO_WORD }
  | "?"                             { QUESTION_MARK }
  | "Given the sets:"               { GIVEN_PROB }
  | "Compute:"                      { COMPUTE_PROB }
  | "Suppose the vectors:"          { SUPPOSE_PROB }
  | "."                             { PERIOD }
  | "Enter a unit vector in the direction of "  { VECTOR_UNIT_PROB }
  | "Enter a vector parallel to "               { VECTOR_PARA_PROB }
  | "Enter a vector in the same direction as "  { VECTOR_SAME_PROB }
  (* ------------------- NEW CODE START ------------------- *)
  | "Given this function:"                      { GIVEN_FUN }
  | "Find an antiderivative F(x) with C = 0:"   { INDEFINITE_INTEGRAL_PROB }
  | "Evaluate the Boolean expression:"          { EVALUATE_BOOL_PROB }
  | "Determine whether the Boolean expressions are equivalent:" { BOOLEAN_EQUIV_PROB }
  | "Compute the complex number expression:"    { COMPLEX_ARITH_PROB }
  | "Find the conjugate of:"                    { COMPLEX_CONJ_PROB }
  | "Find the modulus of:"                      { COMPLEX_MOD_PROB }
  | "Simplify the power of i:"                  { COMPLEX_POWER_I_PROB }
  | "Arithmetic sequence: find a_n."            { ARITH_SEQ_NTH_PROB }
  | "Geometric sequence: find a_n."             { GEOM_SEQ_NTH_PROB }
  | "Arithmetic sequence: find the finite sum." { ARITH_SEQ_SUM_PROB }
  | "Geometric sequence: find the finite sum."  { GEOM_SEQ_SUM_PROB }
  | "When:"                                    { WHEN_WORD }
  | "Enter 1 for True and 0 for False."         { BOOL_ANSWER_HINT }
  | "Enter 1 if equivalent and 0 otherwise."    { BOOL_EQUIV_ANSWER_HINT }
  | "True"                                     { TRUE_WORD }
  | "False"                                    { FALSE_WORD }
  | "AND"                                      { AND_WORD }
  | "OR"                                       { OR_WORD }
  | "NOT"                                      { NOT_WORD }
  | "XOR"                                      { XOR_WORD }
  | "IMPLIES"                                  { IMPLIES_WORD }
  | "IFF"                                      { IFF_WORD }
  (* ------------------- NEW CODE END ------------------- *)

  | "infinity"                      { INFINITY }
  | "-infinity"                     { NEG_INFINITY }

  | "U"                             { UNION }
  | "\\cup"                         { CUP }
  | "\\cap"                         { CAP }

  | ">"                             { GT }
  | "<"                             { LT }
  | "\\geq"                         { GEQ_LATEX }
  | "\\leq"                         { LEQ_LATEX }
  | "\\vec"                         { VEC_LATEX }
  | "\\langle"                      { LANGLE_LATEX }
  | "\\rangle"                      { RANGLE_LATEX }
  | "\\cdot"                        { CDOT_LATEX }
  | "\\times"                       { TIMES_LATEX }
  | "\\left\\|"                     { LEFT_NORM_LATEX }
  | "\\right\\|"                    { RIGHT_NORM_LATEX }
  | "x"                             { X_VAR }
  | "i"                             { I_UNIT }
  (* ------------------- NEW CODE START ------------------- *)
  | "f"                             { F_FUN }
  | "e"                             { NAT_LOG }
  (* ------------------- NEW CODE END ------------------- *)

  | "\\{"                           { LBRACE_LATEX }
  | "\\}"                           { RBRACE_LATEX }

  | "|"                             { PIPE }

  | "BEGIN_PGML"                    { BEGIN_PGML }
  | "END_PGML"                      { END_PGML }

  (*| "Correct"                       { CORRECT_WORD }
  | ":"                             { COLON }*)
  | "[`["                           { IT_VAR_OPEN }   (* opens variable in‐text var-with-value *)
  | "[`"                            { IT_MATH_OPEN }   (* opens math expr *)
  | "]`]"                           { IT_VAR_CLOSE }   (* common closer for VAR and VARV *)
  | "`]"                            { IT_MATH_CLOSE }  (* common closer for MATH *)

  (*| "BEGIN_PGML_SOLUTION"           { BEGIN_PGML_SOLUTION }
  | "END_PGML_SOLUTION"             { END_PGML_SOLUTION }*)

  | '+'                             { ADD_OP }
  | '-'                             { SUB_OP }
  | '*'                             { MUL_OP }
  | '/'                             { DIV_OP }
  (* ------------------- NEW CODE START ------------------- *)
  | '^'                             { POWER_OP }
  | "sqrt"                          { SQRT_OP }
  | "ln"                            { LN_OP }
  | "sin"                           { SIN_OP }
  | "cos"                           { COS_OP }
  (* ------------------- NEW CODE END ------------------- *)

  | '='                             { EQ }
  | "=>"                            { FAT_COMMA }
  | "->"                            { ARROW }
  | ','                             { COMMA }
  | ';'                             { SEMI }
  | '('                             { LPAREN }
  | ')'                             { RPAREN }
  | '{'                             { LBRACE }
  | '}'                             { RBRACE }
  | '['                             { LBRACKET }
  | ']'                             { RBRACKET }

  | '\"'                            { DOUBLE_QUOTE }
  | '\''                            { SINGLE_QUOTE }
  | '$'                             { NAMING }

  | number                          { NUMBER (float_of_string (Lexing.lexeme lexbuf)) }
  | int                             { INT (int_of_string (Lexing.lexeme lexbuf)) }
  | macro                           { MACRO (Lexing.lexeme lexbuf) }
  (*| id                              { ID (Lexing.lexeme lexbuf) }*)
  | id as x
    { match x with
      | "add"      -> ADD_METH
      | "set"      -> SET_METH
      | "are"      -> ARE_METH
      | "undefine" -> UNDEFINE_METH
      | "redefine" -> REDEFINE_METH
      | "random"   -> RANDOM_METH
      | "Formula"  -> FORMULA_METH
      | "Real"     -> REAL_METH
      | "D"        -> D_METH
      | "eval"     -> EVAL_METH
      | "with"     -> WITH_METH
      | "Set"      -> SET_DEF_METH
      | "Compute"     -> COMPUTE_METH
      | "Complex"     -> COMPLEX_METH
      | "intersect"   -> INTERSECT_METH
      | "norm"     -> NORM_METH
	      | "unit"     -> UNIT_METH
	      | "True"     -> TRUE_WORD
	      | "False"    -> FALSE_WORD
	      | "AND"      -> AND_WORD
	      | "OR"       -> OR_WORD
	      | "NOT"      -> NOT_WORD
	      | "XOR"      -> XOR_WORD
	      | "IMPLIES"  -> IMPLIES_WORD
	      | "IFF"      -> IFF_WORD
	      | _          -> ID (Lexing.lexeme lexbuf)
	    }

  | "cmp(parallel=>1)"                  { CMP_1 }
  | "cmp(parallel=>1,sameDirection=>1)" { CMP_2 }

  | eof                             { EOF }
  | _ as c                          
    { 
      let context = get_context lexbuf in
      let msg = Printf.sprintf "Unexpected character: '%c' (code %d)%s" c (Char.code c) context in
      raise (LexingError msg)
    }
