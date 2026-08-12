# Direct parse → unparse

printf "1+2*3\n" | dune exec _build/default/unparser.exe


# Generation: use student id 2230026100 as the seed

dune exec _build/default/unparser.exe 2230026100


If you want to debug a menhir grammar, you can use menhir intepreter mode with menhir --interpret

menhir --interpret parser.mly
or list all possible syntax errors in your grammar with menhir --list-errors.

menhir --list-errors parser.mly
Both options should make the reason why `"hi." is a syntax error in your grammar relatively clear.


Example 1:

DOCUMENT();
loadMacros(“PGstandard.pl”, “PGML.pl”);
Context(“Numeric”);
Context()->strings->add(True=>{},False=>{});
$f = Formula("2*(7+3)-3*5");
BEGIN_PGML
What is the value of [`[$f]`] ? [_____]{Real(5)}
END_PGML
BEGIN_PGML_SOLUTION
Correct answer: [`[Real(5)]`]

Solution text here.
END_PGML_SOLUTION
ENDDOCUMENT();


printf 'DOCUMENT();
 loadMacros("PGstandard.pl", "PGML.pl");
 Context("Numeric");
 Context()->strings->add(True=>{},False=>{});
 $f = Formula("2*(7+3)-3*5");
 BEGIN_PGML
 What is the value of [`[$f]`] ? [_____]{Real(5)}
 END_PGML
 BEGIN_PGML_SOLUTION
 Correct answer: [`[Real(5)]`]

 Solution text here.
 END_PGML_SOLUTION
 ENDDOCUMENT();' | dune exec _build/default/unparser.exe


Example 2:

DOCUMENT();
loadMacros(“PGstandard.pl”, “PGML.pl”);
Context(“Numeric”);
BEGIN_PGML
What is the value of [`2*(7+3)-3*5`] ? [_____]{Real(5)}
END_PGML
ENDDOCUMENT();

printf 'DOCUMENT();\n loadMacros(“PGstandard.pl”, “PGML.pl”);\n Context(“Numeric”);\n BEGIN_PGML \n What is the value of [`2*(7+3)-3*5`] ? [_____]{Real(5)} \n END_PGML \n ENDDOCUMENT();' | dune exec _build/default/unparser.exe

printf 'DOCUMENT();
 loadMacros("PGstandard.pl", "PGML.pl");
 Context("Numeric");
 BEGIN_PGML
 What is the value of [`2*(7+3)-3*5`] ? [_____]{Real(5)}
 END_PGML
 ENDDOCUMENT();' | dune exec _build/default/unparser.exe

printf 'DOCUMENT();
 loadMacros("PGstandard.pl", "PGML.pl");
 Context("Numeric");
 BEGIN_PGML
 What is the value of [`2*(7+3)-3*5`] ? [_____]{answer => 5, width => 10}
 END_PGML
 ENDDOCUMENT();' | dune exec _build/default/unparser.exe

========================================================
Successful parsing:


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");
BEGIN_PGML
What is the value of [`5`]? [_____]{5}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl", "Macro1.pl", "Macro_2.pl");
Context("Numeric");
BEGIN_PGML
What is the value of [`5`]? [_____]{5}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Vector");
BEGIN_PGML
[`2`] is equal to [_____]{Real(2.)}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Abc");
BEGIN_PGML
[`2`] is equal to [_____]{$a}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");
BEGIN_PGML
[`2`] is equal to [_____]{Formula("1+1")}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Abc");
BEGIN_PGML
[`2`] is equal to [_____]{random(1,2,3)}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe

printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");
BEGIN_PGML
[`2`] is equal to [_____]{$x->Formula("1+1")}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");
BEGIN_PGML
What is the value of [`2.+3.`]? [_____]{5.}

[`[$f]`] is equal to [_____]{Formula("2*(3+7)")}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Abc");
BEGIN_PGML
[`2`] is equal to [_____]{eval($x => 2)}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf "DOCUMENT();
loadMacros(\"PGstandard.pl\", \"MathObjects.pl\", \"PGML.pl\");
Context(\"Abc\");
BEGIN_PGML
[\`2\`] is equal to [_____]{D('xxx')}
END_PGML
ENDDOCUMENT();" \
| dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Abc");
BEGIN_PGML
What is the value of [`2.+3.`]? [_____]{5.}

[`2`] is equal to [_____]{D('\''x'\'')}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Abc");
BEGIN_PGML
[`2`] is equal to [_____]{with(period => 2)}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Abc");
BEGIN_PGML
What is the value of [`2.+3.`]? [_____]{Real(10.) -> with(period=>2)}

[`[$f]`] is equal to [_____]{Formula("2*(3+7)")}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");
Context()->strings->add(True=>{a=>0});
BEGIN_PGML
What is the value of [`5`]? [_____]{5}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");
Context()->strings->add(True=>{});
BEGIN_PGML
What is the value of [`5`]? [_____]{5}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl", "PGcourse.pl");
Context("Numeric");
BEGIN_PGML
What is the value of [`(2+3)*2`]? [_____]{Real(10.)}

[`2*(3+7)`] is equal to [_____]{Formula("2*(3+7)")}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe

printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl", "PGcourse.pl");
Context("Numeric");
BEGIN_PGML
What is the value of [`(2+3)*2`]? [_____]{D()}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe


printf "DOCUMENT();
loadMacros(\"PGstandard.pl\", \"MathObjects.pl\", \"PGML.pl\");
Context(\"Numeric\");
Context()->variables->are(t=>\'Real\');
BEGIN_PGML
What is the value of [\`(2+3)*2\`]? [_____]{10}
END_PGML
ENDDOCUMENT();" \
| dune exec _build/default/main.exe


printf "DOCUMENT();
loadMacros(\"PGstandard.pl\", \"MathObjects.pl\", \"PGML.pl\");
Context(\"Numeric\");
Context()->strings->add(True=>{},False=>{});
Context()->variables->are(t=>\'Real\');
BEGIN_PGML
What is the value of [\`(2+3)*2\`]? [_____]{10}
END_PGML
ENDDOCUMENT();" \
| dune exec _build/default/main.exe


printf 'DOCUMENT();
loadMacros("PGstandard.pl", "MathObjects.pl", "PGML.pl");
Context("Numeric");
Context()->operators->undefine("+","-","*","/");
BEGIN_PGML
What is the value of [`5`]? [_____]{5}
END_PGML
ENDDOCUMENT();' | dune exec _build/default/main.exe

========================================================






printf 'DOCUMENT(); \n loadMacros("PGstandard.pl", "PGML.pl"); \n Context("Numeric"); \n BEGIN_PGML \n What is the value of [`5`]? [_____]{5} \n END_PGML \n ENDDOCUMENT();' | dune exec _build/default/unparser.exe -- --trace


DOCUMENT LPAREN RPAREN SEMI NEWLINE LOADMACROS LPAREN DOUBLE_QUOTE PGSTANDARD DOUBLE_QUOTE COMMA DOUBLE_QUOTE MATHOBJECTS DOUBLE_QUOTE COMMA DOUBLE_QUOTE PGML DOUBLE_QUOTE RPAREN SEMI NEWLINE CONTEXT LPAREN DOUBLE_QUOTE ID DOUBLE_QUOTE RPAREN SEMI NEWLINE BEGIN_PGML NEWLINE WHAT_WORD IS_WORD THE_WORD VALUE_WORD OF_WORD IT_VAR_OPEN NAMING ID IT_VAR_CLOSE QUESTION_MARK BLANK LBRACE 
math_object_method 
RBRACE NEWLINE END_PGML NEWLINE ENDDOCUMENT LPAREN RPAREN SEMI EOF


========================================================
menhir --interpret parser.mly

Accept:


DOCUMENT LPAREN RPAREN SEMI NEWLINE LOADMACROS LPAREN DOUBLE_QUOTE PGSTANDARD DOUBLE_QUOTE COMMA DOUBLE_QUOTE MATHOBJECTS DOUBLE_QUOTE COMMA DOUBLE_QUOTE PGML DOUBLE_QUOTE RPAREN SEMI NEWLINE CONTEXT LPAREN DOUBLE_QUOTE ID DOUBLE_QUOTE RPAREN SEMI NEWLINE BEGIN_PGML NEWLINE WHAT_WORD IS_WORD THE_WORD VALUE_WORD OF_WORD IT_VAR_OPEN NAMING ID IT_VAR_CLOSE QUESTION_MARK BLANK LBRACE RANDOM_METH LPAREN INT COMMA INT COMMA INT RPAREN RBRACE NEWLINE END_PGML NEWLINE ENDDOCUMENT LPAREN RPAREN SEMI EOF


DOCUMENT LPAREN RPAREN SEMI NEWLINE LOADMACROS LPAREN DOUBLE_QUOTE PGSTANDARD DOUBLE_QUOTE COMMA DOUBLE_QUOTE MATHOBJECTS DOUBLE_QUOTE COMMA DOUBLE_QUOTE PGML DOUBLE_QUOTE RPAREN SEMI NEWLINE CONTEXT LPAREN DOUBLE_QUOTE ID DOUBLE_QUOTE RPAREN SEMI NEWLINE BEGIN_PGML NEWLINE WHAT_WORD IS_WORD THE_WORD VALUE_WORD OF_WORD IT_VAR_OPEN NAMING ID IT_VAR_CLOSE QUESTION_MARK BLANK LBRACE D_METH LPAREN SINGLE_QUOTE ID; SINGLE_QUOTE RPAREN RBRACE NEWLINE END_PGML NEWLINE ENDDOCUMENT LPAREN RPAREN SEMI EOF


DOCUMENT LPAREN RPAREN SEMI NEWLINE LOADMACROS LPAREN DOUBLE_QUOTE PGSTANDARD DOUBLE_QUOTE COMMA DOUBLE_QUOTE MATHOBJECTS DOUBLE_QUOTE COMMA DOUBLE_QUOTE PGML DOUBLE_QUOTE RPAREN SEMI NEWLINE CONTEXT LPAREN DOUBLE_QUOTE ID DOUBLE_QUOTE RPAREN SEMI NEWLINE BEGIN_PGML NEWLINE WHAT_WORD IS_WORD THE_WORD VALUE_WORD OF_WORD IT_VAR_OPEN NAMING ID IT_VAR_CLOSE QUESTION_MARK BLANK LBRACE 
WITH_METH LPAREN NAMING ID FAT_COMMA value = value RPAREN 
RBRACE NEWLINE END_PGML NEWLINE ENDDOCUMENT LPAREN RPAREN SEMI EOF


========================================================

Regenerating lexer.ml / parser.ml / parser.mli
----------------------------------------------
lexer.ml, parser.ml and parser.mli are all generated and checked in; dune runs
neither ocamllex nor menhir on lexer.mll and parser.mly. After editing either
source, regenerate by hand.

For the lexer:

    ocamllex lexer.mll

Note that the checked-in lexer.ml uses CRLF line endings while ocamllex writes
LF, so convert before overwriting if you want to keep the diff small. Run it
under the name lexer.mll, not a copy under another name: the generated file
embeds the source filename in its # line directives.

For the parser:

    ocamlfind ocamlc -c ast.ml
    menhir --table --unparsing --infer --inspection --explain parser.mly

Adding a token also means adding a `method visit_<TOKEN>` to print_pprint.ml
and a case to the token printer in visualization.ml; both fail to compile
otherwise, which is the intended reminder.

All four flags matter: --unparsing produces the DCST/CST/Settle modules,
--infer fills in concrete types (it needs ast.cmi, hence the ocamlc line),
and --inspection produces the MenhirInterpreter indexed types. Running this on
an unmodified parser.mly reproduces the checked-in files byte for byte, so the
step is verifiable. --explain writes parser.conflicts; the file is created even
when empty, so check its size rather than its presence.

Do the regeneration in a scratch directory and copy the results in: a failed
--infer run leaves a truncated parser.ml behind.
