# Rhema inline completion reference

Rhema is a declarative attribute-grammar language. It does not support arbitrary
OCaml, Python, user-defined functions, loops, or statements ending in semicolons.
Comments start with #. Strings use double quotes. Only quote and backslash escapes
are special; other backslashes are literal LaTeX. Expressions use ++ for text
concatenation, = for equality, != for inequality, and/or/not for truth operators.
left, right, on, start, synth, attribute, random, let and the other language
keywords are reserved: never use left/right as variable names.

attribute cost = 3 split declares a nonnegative root budget divided among grammar
children. copy distributes the same value to all grammar children. cost = -1
inside a rule SPENDS one unit before constructing children; it is not assignment
to negative one. when is checked BEFORE children exist, and must not use $n.
require is checked AFTER children are generated and prior equations computed.
synth expr on E requires every E rule to compute expr. $n.attr counts EVERY RHS
symbol from 1, including quoted terminals. E -> E "AND" E therefore uses
$1.expr and $3.expr; "NOT" E uses $2.expr. A bare computed attr refers to this node.
start Q selects the question root. prompt strings interpolate {Q.text}, not Q.text
without braces. answer Q.value selects the typed answer. width 8 sets blank width.
Question-level randoms are drawn for each question, not once per document.

Examples of valid rules (reuse the current file's declarations, not these names):

E -> E "AND" E when cost >= 1 { cost = -1 expr = bool_and($1.expr, $3.expr) }
E -> "NOT" E when cost >= 1 { cost = -1 expr = bool_not($2.expr) }
E -> "p" when cost = 0 { expr = bool_var("p") }
E -> integer_between(1, 9) when cost = 0 { value = $1.value }
E -> E "+" E when cost >= 1 { cost = -1 value = $1.value + $3.value }
prompt "Evaluate [`{Q.text}`]."
answer Q.value

Type hints, ONLY when the named function appears in the registered list:
bool_var(text) -> Boolean formula; bool_and/or/xor/imp/iff(formula,formula) -> Boolean
formula; bool_not(formula) -> Boolean formula; bool_latex(formula) -> text;
bool_equivalent(formula,formula) -> truth; bool_variable_count(formula) -> number;
bool_evaluate(formula, comma_separated_variable_names_text, assignment_mask_number)
-> truth. Mask p,q,r uses bit weights 1,2,4 respectively. cond(truth,a,b) returns
one branch of the same type; str(number) -> text. Booleans are not numeric answers:
use cond(truth,1,0) when a Numeric answer is required.
formula_variable(text), formula_constant(number), formula_add/subtract/multiply
(formula,formula) produce typed symbolic formulas, not ordinary strings.
complex(real_number,imaginary_number) produces a typed complex value.
Never mix formulas, Boolean formulas, plain numbers, and text without the proper
constructor or renderer. Unknown domains still use the registered builtin list;
do not guess signatures or mathematical behavior not present in the source.
