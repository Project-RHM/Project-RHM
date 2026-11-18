(* Checks for mistakes: `mistake NAME "..."` and the lines
   `mistake NAME ATTRIBUTE = EXPRESSION` inside rules.

   A grammar says what a student who makes a mistake computes. The engine
   then evaluates every finished tree again under each mistake. A mistake
   that changes the working must change an answer: a question in which it
   would not is built afresh, and the others report what the mistake leads
   to. The tests below write small grammars and check, with readers of their
   own, that

     - the checker refuses every malformed declaration and line;
     - the answers reported for a mistake are the ones the mistake leads to;
     - a mistake is reported exactly where it changes a value;
     - no generated question hides a mistake that changed its working,
       while the same grammar without the mistake does generate such
       questions;
     - a mistake whose values do not reach the answer is left out;
     - a module's subtree is not evaluated under the importer's mistakes;
     - formulas are compared as functions, not as written. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let check label condition = if not condition then fail label

let contains text fragment =
  let rec search index =
    index + String.length fragment <= String.length text
    && (String.sub text index (String.length fragment) = fragment || search (index + 1))
  in
  search 0

let write name content =
  let channel = open_out name in
  output_string channel content;
  close_out channel

let load_source name content =
  write name content;
  let result = Rhema_load.parse_file name in
  Sys.remove name;
  result

let expect_ok name content =
  match load_source name content with
  | Ok spec -> Some spec
  | Error errors ->
      List.iter (fun error -> fail (name ^ ": " ^ Rhema_load.string_of_failure error)) errors;
      None

let expect_error name content ~mentions =
  match load_source name content with
  | Ok _ -> fail (Printf.sprintf "%s was accepted although %s" name mentions)
  | Error errors ->
      if not (List.exists (fun error -> contains (Rhema_load.string_of_failure error) mentions) errors)
      then
        fail
          (Printf.sprintf "%s: no error mentions %S; got: %s" name mentions
             (errors |> List.map Rhema_load.string_of_failure |> String.concat " | "))

let questions ?(seed = 7) spec count =
  Random.init seed;
  List.init count (fun _ -> Rhema_engine.generate spec)

let expect_generation_error name content ~mentions =
  match expect_ok name content with
  | None -> ()
  | Some spec -> (
      match questions spec 20 with
      | _ -> fail (Printf.sprintf "%s generated although %s" name mentions)
      | exception Rhema_engine.Generation_error message ->
          if not (contains message mentions) then
            fail (Printf.sprintf "%s: the error does not mention %S: %s" name mentions message))

let number = function
  | Rhema_engine.Num value -> Rhema_number.to_float value
  | other -> fail ("expected a number, got " ^ Rhema_engine.describe_value other); nan

let made (question : Rhema_engine.question) name =
  List.find_opt (fun (made : Rhema_engine.mistaken) -> made.mistake = name) question.mistakes

(* ------------------------------------------------------------------ *)
(* 1. What the checker refuses                                          *)
(* ------------------------------------------------------------------ *)

(* A grammar of sums and differences. [declarations] and [lines] are put in
   as written, so each test changes one thing. *)
let arithmetic ~declarations ~lines =
  Printf.sprintf
    {|attribute cost = 4 split
%s
synth value on E
synth latex on E
precedence 1 left + -
start E

E -> E + E when cost >= 1 {
  cost = -1
  value = $1.value + $3.value
  latex = infix($1, "+", $3)
}

E -> E - E when cost >= 1 {
  cost = -1
  value = $1.value - $3.value
%s
  latex = infix($1, "-", $3)
}

E -> integer_between(1, 9) when cost = 0 {
  value = $1.value
  latex = str($1.value)
}

prompt "What is [`{E.latex}`]?"
answer E.value
|}
    declarations lines

let smaller_from_larger = {|mistake smaller_from_larger "takes the smaller number from the larger"|}
let smaller_line = "  mistake smaller_from_larger value = cond(value < 0, -value, value)"

let () =
  expect_error "mistake_undeclared.rhm"
    (arithmetic ~declarations:"" ~lines:smaller_line)
    ~mentions:"mistake 'smaller_from_larger' is not declared";
  expect_error "mistake_twice.rhm"
    (arithmetic
       ~declarations:
         (smaller_from_larger ^ "\n" ^ {|mistake smaller_from_larger "subtracts the wrong way"|})
       ~lines:smaller_line)
    ~mentions:"mistake 'smaller_from_larger' is declared more than once";
  expect_error "mistake_no_description.rhm"
    (arithmetic ~declarations:{|mistake smaller_from_larger " "|} ~lines:smaller_line)
    ~mentions:"needs a description";
  expect_error "mistake_never_made.rhm"
    (arithmetic ~declarations:smaller_from_larger ~lines:"")
    ~mentions:"mistake 'smaller_from_larger' is made in no rule";
  expect_error "mistake_before_value.rhm"
    (arithmetic ~declarations:smaller_from_larger
       ~lines:"  mistake smaller_from_larger latex = \"?\"")
    ~mentions:"'latex' is not computed above this line";
  expect_error "mistake_budget.rhm"
    (arithmetic ~declarations:smaller_from_larger
       ~lines:(smaller_line ^ "\n  mistake smaller_from_larger cost = 0"))
    ~mentions:"'cost' is an inherited attribute";
  expect_error "mistake_two_lines.rhm"
    (arithmetic ~declarations:smaller_from_larger ~lines:(smaller_line ^ "\n" ^ smaller_line))
    ~mentions:"already has a line for the mistake 'smaller_from_larger'";
  expect_error "mistake_unknown_name.rhm"
    (arithmetic ~declarations:smaller_from_larger
       ~lines:"  mistake smaller_from_larger value = nothing + 1")
    ~mentions:"nothing";
  (* The word is reserved: it cannot name a local value. *)
  expect_error "mistake_reserved.rhm"
    (arithmetic ~declarations:smaller_from_larger
       ~lines:(smaller_line ^ "\n  let mistake = 1"))
    ~mentions:"unexpected mistake"

(* ------------------------------------------------------------------ *)
(* 2. The reported answers, and no question that lets the mistake pass   *)
(* ------------------------------------------------------------------ *)

(* An independent reader of a tree of this grammar: the right value, the
   value with every difference taken as larger minus smaller, and whether
   that changed the working anywhere, which it does at a difference that
   comes out negative. *)
let rec read_arithmetic (node : Rhema_engine.node) =
  match node.children with
  | [ left; operator; right ] ->
      let left_value, left_wrong, left_changed = read_arithmetic left in
      let right_value, right_wrong, right_changed = read_arithmetic right in
      if operator.symbol = "+" then
        (left_value +. right_value, left_wrong +. right_wrong, left_changed || right_changed)
      else
        ( left_value -. right_value,
          Float.abs (left_wrong -. right_wrong),
          left_changed || right_changed || left_wrong < right_wrong )
  | [ leaf ] ->
      let value = number (Rhema_engine.attribute leaf "value") in
      (value, value, false)
  | _ -> fail "unexpected node in the arithmetic grammar"; (nan, nan, false)

let () =
  match
    expect_ok "mistake_arithmetic.rhm"
      (arithmetic ~declarations:smaller_from_larger ~lines:smaller_line)
  with
  | None -> ()
  | Some spec ->
      check "the specification lists the mistake"
        (spec.Rhema_check.mistakes
        = [ ("smaller_from_larger", "takes the smaller number from the larger") ]);
      let with_difference = ref 0 and without = ref 0 and unchanged = ref 0 in
      List.iter
        (fun (question : Rhema_engine.question) ->
          let value, wrong, changed = read_arithmetic question.tree in
          check "the answer is the value of the tree" (number question.answer = value);
          match made question "smaller_from_larger" with
          | None ->
              incr without;
              (* 7 - 3 is kept: the mistake changes nothing in it. *)
              if contains question.prompt "-" then incr unchanged;
              check
                (Printf.sprintf "%s: the mistake changes the working but is not reported"
                   question.prompt)
                (not changed)
          | Some { mistaken_answers = Some [ answer ]; description; _ } ->
              incr with_difference;
              check "a mistake is reported only where it changes the working" changed;
              check "the description comes with the mistake"
                (description = "takes the smaller number from the larger");
              check
                (Printf.sprintf "%s: the mistake leads to %g, but %g was reported"
                   question.prompt wrong (number answer))
                (number answer = wrong);
              check
                (Printf.sprintf "%s lets the mistake pass" question.prompt)
                (wrong <> value)
          | Some _ -> fail "one answer was expected for the mistake")
        (questions spec 400);
      check "questions that show the mistake were generated" (!with_difference > 50);
      check "questions without it were generated" (!without > 5);
      check "a difference the mistake does not change is kept" (!unchanged > 5);
      (* The listing shows what the mistake leads to under the answer. *)
      let listing = Rhema_cli.questions_listing (questions spec 30) in
      check "the listing names the mistake" (contains listing "\n    mistake smaller_from_larger: ")

(* Without the mistake the same grammar does generate questions that hide
   it, such as 2 - 5 - (1 - 9): the right working gives -3 - (-8) = 5, and
   the mistaken one 3 - 8, taken as 8 - 3 = 5. This is what the filter
   removes. *)
let () =
  match expect_ok "mistake_arithmetic_plain.rhm" (arithmetic ~declarations:"" ~lines:"") with
  | None -> ()
  | Some spec ->
      let blind =
        questions spec 2000
        |> List.filter (fun (question : Rhema_engine.question) ->
               let value, wrong, changed = read_arithmetic question.tree in
               check "a grammar without mistakes reports none" (question.mistakes = []);
               changed && value = wrong)
      in
      check "the unfiltered grammar has questions that hide the mistake" (List.length blind > 5)

(* ------------------------------------------------------------------ *)
(* 3. Derivatives: two mistakes, and an answer they do not reach         *)
(* ------------------------------------------------------------------ *)

(* The derivative is worked out rule by rule, so a mistake at one node goes
   up through the right rules above it. The question `function` asks for the
   function itself: the same rules build it, and no mistake reaches it. *)
let derivative_source =
  {|attribute cost = 5 split

mistake factor_by_factor "differentiates a product factor by factor"
mistake no_chain "leaves out the derivative of the inside"

synth f on F
synth d on F
synth latex on F
synth f on T
synth d on T
synth latex on T

F -> F "+" F when cost >= 1 {
  cost = -1
  require $1.latex != $3.latex
  f = formula_add($1.f, $3.f)
  d = formula_add($1.d, $3.d)
  latex = formula_latex(f)
}

F -> F "\cdot" F when cost >= 3 {
  cost = -3
  require $1.latex != $3.latex
  f = formula_multiply($1.f, $3.f)
  d = formula_add(formula_multiply($1.d, $3.f), formula_multiply($1.f, $3.d))
  mistake factor_by_factor d = formula_multiply($1.d, $3.d)
  latex = formula_latex(f)
}

F -> "sin" F when cost >= 2 {
  cost = -2
  f = formula_sin($2.f)
  d = formula_multiply(formula_cos($2.f), $2.d)
  mistake no_chain d = formula_cos($2.f)
  latex = formula_latex(f)
}

F -> T when cost <= 1 {
  f = $1.f
  d = $1.d
  latex = $1.latex
}

T -> "x" when cost = 0 {
  f = formula_variable("x")
  d = formula_constant(1)
  latex = formula_latex(f)
}

T -> integer_between(2, 6) "x" when cost = 1 {
  cost = -1
  f = formula_multiply(formula_constant($1.value), formula_variable("x"))
  d = formula_constant($1.value)
  latex = formula_latex(f)
}

question derivative {
  start F
  prompt "Differentiate [`{F.latex}`]."
  answer F.d
}

question function {
  start F
  prompt "Write [`{F.latex}`] again."
  answer F.f
}
|}

let formula = function
  | Rhema_engine.Formula formula -> formula
  | other ->
      fail ("expected a formula, got " ^ Rhema_engine.describe_value other);
      Rhema_formula.zero

let count text fragment =
  let rec go index found =
    if index + String.length fragment > String.length text then found
    else if String.sub text index (String.length fragment) = fragment then
      go (index + String.length fragment) (found + 1)
    else go (index + 1) found
  in
  go 0 0

(* Sines in the question, and those of a bare x: leaving out the derivative
   of the inside changes nothing in sin(x), and something in every other. *)
let sines (question : Rhema_engine.question) = count question.prompt "\\sin"
let sines_of_x (question : Rhema_engine.question) = count question.prompt "\\sin\\left(x\\right)"

let rec holds (node : Rhema_engine.node) symbol =
  List.exists (fun (child : Rhema_engine.node) -> child.symbol = symbol) node.children
  || List.exists (fun child -> holds child symbol) node.children

let () =
  match expect_ok "mistake_derivative.rhm" derivative_source with
  | None -> ()
  | Some file -> (
      (match Rhema_check.select_question file "derivative" with
      | Error message -> fail message
      | Ok spec ->
          let seen = Hashtbl.create 2 in
          List.iter
            (fun (question : Rhema_engine.question) ->
              let right =
                Rhema_formula.differentiate ~variable:"x"
                  (formula (Rhema_engine.attribute question.tree "f"))
              in
              check
                (Printf.sprintf "%s: the rule-by-rule derivative is not the derivative"
                   question.prompt)
                (Rhema_engine.same_value (Rhema_engine.Formula right) question.answer);
              List.iter
                (fun (made : Rhema_engine.mistaken) ->
                  Hashtbl.replace seen made.mistake ();
                  match made.mistaken_answers with
                  | Some [ answer ] ->
                      check
                        (Printf.sprintf "%s: '%s' gives the right answer" question.prompt
                           made.mistake)
                        (not (Rhema_engine.same_value answer question.answer))
                  | _ -> fail "one answer was expected for the mistake")
                question.mistakes;
              (* A product or a function of a function is where the mistakes
                 are made, and every such question must show them. *)
              check
                (Printf.sprintf "%s has a product but does not report factor_by_factor"
                   question.prompt)
                ((not (holds question.tree "\\cdot")) || made question "factor_by_factor" <> None);
              check
                (Printf.sprintf "%s: no_chain is reported exactly for a sine of more than x"
                   question.prompt)
                (sines question > sines_of_x question = (made question "no_chain" <> None));
              if sines question > 0 && sines question = sines_of_x question then
                Hashtbl.replace seen "sin(x) alone" ())
            (questions spec 300);
          check "both mistakes were seen"
            (Hashtbl.mem seen "factor_by_factor" && Hashtbl.mem seen "no_chain");
          check "a question whose sines are all of x is still asked"
            (Hashtbl.mem seen "sin(x) alone"));
      match Rhema_check.select_question file "function" with
      | Error message -> fail message
      | Ok spec ->
          let asked = questions spec 300 in
          check "no mistake reaches an answer that is the function itself"
            (List.for_all (fun (question : Rhema_engine.question) -> question.mistakes = []) asked);
          check "such questions still hold products and sines"
            (List.exists (fun (question : Rhema_engine.question) -> holds question.tree "\\cdot") asked
            && List.exists (fun (question : Rhema_engine.question) -> holds question.tree "sin") asked))

(* ------------------------------------------------------------------ *)
(* 4. A module's subtree is its own                                     *)
(* ------------------------------------------------------------------ *)

let () =
  write "mistake_module_core.rhm" derivative_source;
  (match
     expect_ok "mistake_importer.rhm"
       {|import "mistake_module_core.rhm" as core

attribute cost = 5 copy
synth text on Q
synth answer_value on Q
start Q

Q -> core.F(cost = cost) {
  text = "Differentiate [`" ++ $1.latex ++ "`]."
  answer_value = $1.d
}

prompt "{Q.text}"
answer Q.answer_value
|}
   with
  | None -> ()
  | Some spec ->
      let asked = questions spec 300 in
      check "an importer has no mistakes of its own" (spec.Rhema_check.mistakes = []);
      check "a module's subtree is not evaluated under mistakes"
        (List.for_all (fun (question : Rhema_engine.question) -> question.mistakes = []) asked);
      check "although such subtrees hold what the module's mistakes change"
        (List.exists (fun question -> sines question > sines_of_x question) asked));
  Sys.remove "mistake_module_core.rhm"

(* An included file's mistakes are the including file's: declarations and
   lines are merged, and a mistake both files declare is kept once. *)
let () =
  write "mistake_included.rhm"
    (arithmetic ~declarations:smaller_from_larger ~lines:smaller_line);
  (match
     expect_ok "mistake_including.rhm"
       ({|include "mistake_included.rhm"
|} ^ smaller_from_larger ^ "\n")
   with
  | None -> ()
  | Some spec ->
      check "an included mistake is declared once" (List.length spec.Rhema_check.mistakes = 1);
      check "an included mistake is looked for"
        (List.exists
           (fun (question : Rhema_engine.question) -> question.mistakes <> [])
           (questions spec 40)));
  Sys.remove "mistake_included.rhm"

(* ------------------------------------------------------------------ *)
(* 5. Local names, blanks in text, no value, and mistakes that cannot show *)
(* ------------------------------------------------------------------ *)

(* The mistake changes a local name; the attribute below it follows. Both
   answers are blanks in the text. *)
let () =
  match
    expect_ok "mistake_local.rhm"
      {|mistake forgot_half "forgets to halve the product"

synth text on Q
start Q

Q -> integer_between(2, 9) integer_between(2, 9) {
  let product = $1.value * $2.value
  let area = product / 2
  mistake forgot_half area = product
  text = "Base " ++ str($1.value) ++ ", height " ++ str($2.value) ++ ". Area: " ++ blank(area)
         ++ " Twice the area: " ++ blank(2 * area)
}

prompt "{Q.text}"
|}
  with
  | None -> ()
  | Some spec ->
      List.iter
        (fun (question : Rhema_engine.question) ->
          match (question.answers, made question "forgot_half") with
          | [ area; twice ], Some { mistaken_answers = Some [ wrong_area; wrong_twice ]; _ } ->
              check "the local name's mistake reaches the first blank"
                (number wrong_area = 2. *. number area);
              check "and the value computed from it" (number wrong_twice = 2. *. number twice)
          | _ -> fail "two answers and two mistaken answers were expected")
        (questions spec 40)

(* Dividing the wrong way round has no value when the dividend is 0. The
   question is kept, and the mistake is reported without an answer. *)
let () =
  match
    expect_ok "mistake_no_value.rhm"
      {|mistake wrong_way "divides the divisor by the dividend"

synth value on Q
start Q

Q -> integer_between(0, 1) integer_between(2, 5) {
  value = $1.value / $2.value
  mistake wrong_way value = $2.value / $1.value
}

prompt "Divide."
answer Q.value
|}
  with
  | None -> ()
  | Some spec ->
      let asked = questions spec 60 in
      check "a mistake with no value is reported as such"
        (List.exists
           (fun question ->
             match made question "wrong_way" with
             | Some { mistaken_answers = None; _ } -> number question.answer = 0.
             | _ -> false)
           asked);
      check "the listing says so"
        (contains (Rhema_cli.questions_listing asked) "mistake wrong_way: no answer")

(* A line that gives the same function written another way changes
   nothing: the questions are asked and the mistake is never reported. *)
let () =
  match
    expect_ok "mistake_same_function.rhm"
      {|mistake other_order "adds the terms in the other order"

synth f on Q
start Q

Q -> integer_between(2, 9) {
  f = formula_add(formula_variable("x"), formula_constant($1.value))
  mistake other_order f = formula_add(formula_constant($1.value), formula_variable("x"))
}

prompt "Write the function."
answer Q.f
|}
  with
  | None -> ()
  | Some spec ->
      check "a line that changes nothing is no mistake"
        (List.for_all
           (fun (question : Rhema_engine.question) -> question.mistakes = [])
           (questions spec 20))

(* A mistake that always changes the working and never the answer leaves no
   question to generate, and the message names it. *)
let () =
  expect_generation_error "mistake_always_hidden.rhm"
    {|mistake one_more "counts one too many"

synth value on N
synth result on Q
start Q

Q -> N { result = $1.value * 0 }

N -> integer_between(2, 9) {
  value = $1.value
  mistake one_more value = value + 1
}

prompt "Multiply by zero."
answer Q.result
|}
    ~mentions:"the mistake 'one_more' gives the right answer"

(* A line that cannot be evaluated is the grammar's fault, and says where.
   Written through `cond`, the wrong type is the engine's to find. *)
let () =
  expect_generation_error "mistake_wrong_type.rhm"
    {|mistake muddled "adds text to a number"

synth value on Q
start Q

Q -> integer_between(2, 9) {
  value = $1.value
  mistake muddled value = $1.value + cond(true, "one", 1)
}

prompt "Copy the number."
answer Q.value
|}
    ~mentions:"under the mistake 'muddled'"

(* ------------------------------------------------------------------ *)
(* 6. Answers are compared as a marker compares them                    *)
(* ------------------------------------------------------------------ *)

let () =
  let x = Rhema_formula.variable "x" and y = Rhema_formula.variable "y" in
  let constant value = Rhema_formula.constant (Rhema_number.of_int value) in
  let same left right = Rhema_engine.same_value (Rhema_engine.Formula left) (Rhema_engine.Formula right) in
  check "x + 2 and 2 + x are the same answer"
    (same (Rhema_formula.add x (constant 2)) (Rhema_formula.add (constant 2) x));
  check "(x + 1)^2 and x^2 + 2x + 1 are the same answer"
    (same
       (Rhema_formula.power (Rhema_formula.add x (constant 1)) 2)
       (Rhema_formula.add
          (Rhema_formula.add (Rhema_formula.power x 2) (Rhema_formula.multiply (constant 2) x))
          (constant 1)));
  check "x and 2x are not" (not (same x (Rhema_formula.multiply (constant 2) x)));
  check "x + y and x - y are not" (not (same (Rhema_formula.add x y) (Rhema_formula.subtract x y)));
  check "x y and y x are" (same (Rhema_formula.multiply x y) (Rhema_formula.multiply y x));
  check "sin and cos are not" (not (same (Rhema_formula.sin x) (Rhema_formula.cos x)));
  let three = Rhema_number.of_int 3 in
  check "a number is the same with or without exactly()"
    (Rhema_engine.same_value (Rhema_engine.Num three) (Rhema_engine.Exactly three));
  check "a number and a text are different answers"
    (not (Rhema_engine.same_value (Rhema_engine.Num three) (Rhema_engine.Text "3")))

(* ------------------------------------------------------------------ *)
(* 7. The library's mistakes                                            *)
(* ------------------------------------------------------------------ *)

let load_library filename ?question () =
  match Rhema_load.parse_file filename with
  | Error errors ->
      List.iter (fun error -> fail (filename ^ ": " ^ Rhema_load.string_of_failure error)) errors;
      None
  | Ok spec -> (
      match question with
      | None -> Some spec
      | Some name -> (
          match Rhema_check.select_question spec name with
          | Ok spec -> Some spec
          | Error message -> fail message; None))

(* Every reported mistake is one of [expected], has one answer per blank,
   and never leaves every answer right. Returns how often each was seen. *)
let check_reported label ~expected asked =
  let seen = Hashtbl.create 4 in
  List.iter
    (fun (question : Rhema_engine.question) ->
      List.iter
        (fun (made : Rhema_engine.mistaken) ->
          check (label ^ ": unexpected mistake " ^ made.mistake) (List.mem made.mistake expected);
          Hashtbl.replace seen made.mistake
            (1 + Option.value ~default:0 (Hashtbl.find_opt seen made.mistake));
          match made.mistaken_answers with
          | None -> ()
          | Some answers ->
              check
                (Printf.sprintf "%s: '%s' leaves %s right" label made.mistake question.prompt)
                (List.length answers = List.length question.answers
                && not (List.for_all2 Rhema_engine.same_value question.answers answers)))
        question.mistakes)
    asked;
  fun name -> Option.value ~default:0 (Hashtbl.find_opt seen name)

(* calculus.rhm: the derivative worked out production by production is the
   derivative, at every budget; the three mistakes show; and an integral,
   which does not read it, reports none. *)
let () =
  (match load_library "calculus.rhm" ~question:"derivative" () with
  | None -> ()
  | Some spec ->
      let total = ref 0 and counts = Hashtbl.create 3 in
      List.iter
        (fun budget ->
          match Rhema_check.with_initial spec "cost" budget with
          | Error message -> fail message
          | Ok spec ->
              let asked = questions ~seed:(40 + budget) spec 150 in
              List.iter
                (fun (question : Rhema_engine.question) ->
                  incr total;
                  let body =
                    match question.tree.children with
                    | body :: _ -> body
                    | [] -> question.tree
                  in
                  let right =
                    Rhema_formula.differentiate ~variable:"x"
                      (formula (Rhema_engine.attribute body "formula"))
                  in
                  check
                    (Printf.sprintf "%s: the answer is not the derivative" question.prompt)
                    (Rhema_engine.same_value (Rhema_engine.Formula right) question.answer))
                asked;
              let seen =
                check_reported "calculus.rhm"
                  ~expected:[ "factor_by_factor"; "no_chain"; "top_and_bottom" ]
                  asked
              in
              List.iter
                (fun name ->
                  Hashtbl.replace counts name
                    (seen name + Option.value ~default:0 (Hashtbl.find_opt counts name)))
                [ "factor_by_factor"; "no_chain"; "top_and_bottom" ];
              (* At a budget of 1 there is a single rule and a leaf: nothing
                 to multiply, nothing inside, nothing to divide. *)
              if budget = 1 then
                check "the simplest derivatives report no mistake"
                  (List.for_all
                     (fun (question : Rhema_engine.question) -> question.mistakes = [])
                     asked))
        [ 1; 2; 4; 7; 10; 13 ];
      List.iter
        (fun name ->
          check
            (Printf.sprintf "calculus.rhm: '%s' shows in too few of %d questions" name !total)
            (Option.value ~default:0 (Hashtbl.find_opt counts name) > 40))
        [ "factor_by_factor"; "no_chain"; "top_and_bottom" ]);
  match load_library "calculus.rhm" ~question:"integral" () with
  | None -> ()
  | Some spec ->
      check "an integral question reports no mistake"
        (List.for_all
           (fun (question : Rhema_engine.question) -> question.mistakes = [])
           (questions spec 200))

(* complex.rhm: both slips show, and a modulus question reports none. *)
let () =
  match load_library "complex.rhm" () with
  | None -> ()
  | Some spec ->
      let asked = questions spec 600 in
      let seen =
        check_reported "complex.rhm" ~expected:[ "i_squared_one"; "minus_real_only" ] asked
      in
      check "complex.rhm: taking i squared to be 1 shows" (seen "i_squared_one" > 60);
      check "complex.rhm: a minus kept from the imaginary part shows" (seen "minus_real_only" > 60);
      let modulus =
        List.filter
          (fun (question : Rhema_engine.question) ->
            Rhema_engine.attribute question.tree "kind" = Rhema_engine.Text "modulus")
          asked
      in
      check "complex.rhm: modulus questions were asked" (List.length modulus > 40);
      check "complex.rhm: a modulus question reports no mistake"
        (List.for_all (fun (question : Rhema_engine.question) -> question.mistakes = []) modulus)

(* boolean.rhm: the value worked out connective by connective is the value
   of the proposition, and a reported mistake leads to the other answer. *)
let () =
  match load_library "boolean.rhm" () with
  | None -> ()
  | Some spec ->
      List.iter
        (fun budget ->
          match Rhema_check.with_initial spec "cost" budget with
          | Error message -> fail message
          | Ok spec ->
              let asked = questions ~seed:(60 + budget) spec 300 in
              List.iter
                (fun (question : Rhema_engine.question) ->
                  let proposition =
                    match question.tree.children with
                    | body :: _ -> (
                        match Rhema_engine.attribute body "f" with
                        | Rhema_engine.Boolean proposition -> Some proposition
                        | _ -> None)
                    | [] -> None
                  and mask =
                    match List.assoc_opt "mask" question.globals with
                    | Some (Rhema_engine.Num mask) -> Rhema_number.require_integer "mask" mask
                    | _ -> -1
                  in
                  match proposition with
                  | None -> fail "boolean.rhm: no proposition under the root"
                  | Some proposition ->
                      check
                        (Printf.sprintf "%s: the answer is not the proposition's value"
                           question.prompt)
                        (question.answer
                        = Rhema_engine.Truth (Rhema_boolean.evaluate_mask proposition "p,q,r" mask));
                      List.iter
                        (fun (made : Rhema_engine.mistaken) ->
                          check "boolean.rhm: a mistake leads to the other truth value"
                            (match (made.mistaken_answers, question.answer) with
                            | Some [ Rhema_engine.Truth wrong ], Rhema_engine.Truth right ->
                                wrong <> right
                            | _ -> false))
                        question.mistakes)
                asked;
              let seen =
                check_reported "boolean.rhm" ~expected:[ "false_antecedent"; "exclusive_or" ] asked
              in
              if budget >= 10 then begin
                check "boolean.rhm: a false antecedent taken for a false conditional shows"
                  (seen "false_antecedent" > 15);
                check "boolean.rhm: or read as exclusive shows" (seen "exclusive_or" > 2)
              end)
        [ 4; 10; 14 ]

(* The polynomial core: an expansion shows a power taken term by term
   exactly when it holds a power, and a factoring question, built from the
   same rules, reports nothing since it does not read the expansion. *)
let () =
  (match load_library "polynomial_expand.rhm" () with
  | None -> ()
  | Some spec ->
      let asked = questions spec 300 in
      let seen = check_reported "polynomial_expand.rhm" ~expected:[ "power_term_by_term" ] asked in
      check "polynomial_expand.rhm: powers were asked" (seen "power_term_by_term" > 60);
      List.iter
        (fun (question : Rhema_engine.question) ->
          check
            (Printf.sprintf "%s: the mistake is reported exactly when a power is expanded"
               question.prompt)
            (contains question.prompt ")^{" = (question.mistakes <> [])))
        asked);
  match load_library "factoring.rhm" () with
  | None -> ()
  | Some spec ->
      check "factoring.rhm declares the core's mistake"
        (List.mem_assoc "power_term_by_term" spec.Rhema_check.mistakes);
      check "a factoring question reports no mistake"
        (List.for_all
           (fun (question : Rhema_engine.question) -> question.mistakes = [])
           (questions spec 200))

let () =
  if !failures = 0 then print_endline "Rhema mistakes tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d mistakes test(s) failed." !failures);
    exit 1
  end
