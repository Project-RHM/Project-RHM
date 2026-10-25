(* Unit and DSL integration tests for the reusable Formula, Polynomial and
   Equation foundations. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let number value = Rhema_number.of_int value

let check_number label expected actual =
  if not (Rhema_number.equal expected actual) then
    fail
      (Printf.sprintf "%s: expected %s, received %s" label
         (Rhema_number.to_string expected) (Rhema_number.to_string actual))

let check_text label expected actual =
  if expected <> actual then
    fail (Printf.sprintf "%s: expected %S, received %S" label expected actual)

let contains text fragment =
  let text_length = String.length text and fragment_length = String.length fragment in
  let rec search index =
    index + fragment_length <= text_length
    &&
    (String.sub text index fragment_length = fragment || search (index + 1))
  in
  fragment_length = 0 || search 0

let load source =
  match Rhema_load.parse_string ~filename:"algebra-core.rhm" source with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Rhema_load.string_of_failure error)) errors;
      exit 1

let check_formula () =
  let x = Rhema_formula.variable "x" in
  let derivative expression = Rhema_formula.differentiate ~variable:"x" expression in
  check_text "quotient derivative" "1/x"
    (Rhema_formula.to_pg (derivative (Rhema_formula.ln x)));
  check_text "square-root derivative" "1/(2*sqrt(x))"
    (Rhema_formula.to_pg (derivative (Rhema_formula.sqrt x)));
  check_text "tangent derivative" "1/cos(x)^2"
    (Rhema_formula.to_pg (derivative (Rhema_formula.tan x)));
  let expression = Rhema_formula.add (Rhema_formula.power x 2) (Rhema_formula.constant (number 1)) in
  let substituted =
    Rhema_formula.substitute ~variable:"x" ~replacement:(Rhema_formula.constant (number 3))
      expression
  in
  check_text "formula substitution" "3^2+1" (Rhema_formula.to_pg substituted);
  let substituted_value = Rhema_formula.evaluate_with (fun _ -> None) substituted in
  if Float.abs (substituted_value -. 10.0) > 1e-12 then
    fail "the substituted formula did not evaluate to 10";
  if Rhema_formula.variables (Rhema_formula.add x (Rhema_formula.variable "y")) <> [ "x"; "y" ]
  then fail "formula variable collection did not return x and y";
  match Rhema_number.square_root_exact (Rhema_number.make 9 16) with
  | Some root -> check_number "exact rational square root" (Rhema_number.make 3 4) root
  | None -> fail "9/16 was not recognized as an exact rational square"

let check_polynomial () =
  let x = Rhema_polynomial.variable "x" in
  let two = Rhema_polynomial.constant ~variable:"x" (number 2)
  and three = Rhema_polynomial.constant ~variable:"x" (number 3) in
  let polynomial =
    Rhema_polynomial.multiply (Rhema_polynomial.subtract x two)
      (Rhema_polynomial.subtract x three)
  in
  check_text "expanded polynomial" "x^2-5*x+6" (Rhema_polynomial.to_pg polynomial);
  check_text "polynomial derivative" "2*x-5"
    (Rhema_polynomial.to_pg (Rhema_polynomial.derivative polynomial));
  check_number "polynomial exact evaluation" Rhema_number.zero
    (Rhema_polynomial.evaluate polynomial (number 2));
  (match Rhema_polynomial.roots_exact polynomial with
  | Some [ first; second ] ->
      check_number "first quadratic root" (number 2) first;
      check_number "second quadratic root" (number 3) second
  | _ -> fail "factorable quadratic did not produce roots 2 and 3");
  match Rhema_polynomial.of_formula ~variable:"x" (Rhema_polynomial.to_formula polynomial) with
  | Some reconstructed when Rhema_polynomial.equal reconstructed polynomial -> ()
  | _ -> fail "Formula-to-Polynomial conversion did not round trip"

let check_random_polynomials () =
  Random.init 74_201;
  for case = 1 to 300 do
    let coefficients () =
      List.init 4 (fun _ -> number (Random.int 15 - 7))
    in
    let left = Rhema_polynomial.make ~variable:"x" (coefficients ())
    and right = Rhema_polynomial.make ~variable:"x" (coefficients ())
    and point = number (Random.int 11 - 5) in
    let product = Rhema_polynomial.multiply left right in
    let expected =
      Rhema_number.multiply (Rhema_polynomial.evaluate left point)
        (Rhema_polynomial.evaluate right point)
    in
    check_number (Printf.sprintf "random product evaluation %d" case) expected
      (Rhema_polynomial.evaluate product point);
    let root1 = number (Random.int 13 - 6) and root2 = number (Random.int 13 - 6) in
    let x = Rhema_polynomial.variable "x" in
    let from_roots =
      Rhema_polynomial.multiply
        (Rhema_polynomial.subtract x (Rhema_polynomial.constant ~variable:"x" root1))
        (Rhema_polynomial.subtract x (Rhema_polynomial.constant ~variable:"x" root2))
    in
    match Rhema_polynomial.roots_exact from_roots with
    | Some roots ->
        let expected = List.sort_uniq Rhema_number.compare [ root1; root2 ] in
        if
          List.length roots <> List.length expected
          || not (List.for_all2 Rhema_number.equal roots expected)
        then fail (Printf.sprintf "random factorable roots %d were incorrect" case)
    | None -> fail (Printf.sprintf "random factorable quadratic %d was unsupported" case)
  done

let check_equation () =
  let polynomial =
    Rhema_polynomial.quadratic ~variable:"x" (number 1) (number (-5)) (number 6)
  in
  let equation =
    Rhema_equation.of_polynomials polynomial
      (Rhema_polynomial.zero ~variable:"x")
  in
  if not (Rhema_equation.satisfies ~variable:"x" ~value:(number 3) equation) then
    fail "x=3 should satisfy x^2-5x+6=0";
  if Rhema_equation.satisfies ~variable:"x" ~value:(number 4) equation then
    fail "x=4 should not satisfy x^2-5x+6=0";
  match Rhema_equation.solve ~variable:"x" equation with
  | Rhema_equation.Finite [ first; second ] ->
      check_number "equation first root" (number 2) first;
      check_number "equation second root" (number 3) second
  | _ -> fail "factorable quadratic equation was not solved exactly"

let check_dsl_integration () =
  let source =
    "context \"Interval\"\n\
     let p = polynomial_quadratic(1, -5, 6, \"x\")\n\
     let z = polynomial_constant(0, \"x\")\n\
     let eq = polynomial_equation(p, z)\n\
     synth text on Q\n\
     synth answer_value on Q\n\
     start Q\n\
     Q -> \"quadratic\" {\n\
       text = equation_latex(eq)\n\
       answer_value = equation_solution_set(eq, \"x\")\n\
     }\n\
     prompt \"Solve [`{Q.text}`].\"\n\
     answer Q.answer_value\n"
  in
  let spec = load source in
  Random.init 19;
  let question = Rhema_engine.generate spec in
  (match question.answer with
  | Rhema_engine.Set (Rhema_set.Finite [ first; second ]) ->
      check_number "DSL first root" (number 2) first;
      check_number "DSL second root" (number 3) second
  | other ->
      fail
        ("DSL equation_solution_set returned " ^ Rhema_engine.describe_value other));
  if not (contains question.prompt "x^{2} - 5 \\cdot x + 6 = 0") then
    fail ("DSL equation prompt was unexpected: " ^ question.prompt);
  let pgml = Rhema_pgml.of_spec ~count:1 spec in
  if not (contains pgml "Context(\"Interval\");") then
    fail "equation solution-set PGML did not retain the Interval context";
  if not (contains pgml "Compute(\"{2, 3}\")") then
    fail ("equation solution-set PGML was unexpected: " ^ pgml)

let check_extended_formula_dsl () =
  let source =
    "context \"Numeric\"\n\
     let x = formula_variable(\"x\")\n\
     let one = formula_constant(1)\n\
     let shifted = formula_add(x, one)\n\
     let body = formula_divide(formula_ln(shifted), formula_sqrt(shifted))\n\
     let replaced = formula_substitute(body, \"x\", formula_constant(3))\n\
     let ignored_negation = formula_negate(one)\n\
     let ignored_polynomial = formula_to_polynomial(formula_power(x, 2), \"x\")\n\
     synth text on Q\n\
     synth answer_value on Q\n\
     start Q\n\
     Q -> \"formula\" {\n\
       text = formula_latex(replaced)\n\
       answer_value = differentiate(formula_tan(x), \"x\")\n\
     }\n\
     prompt \"Differentiate after checking [`{Q.text}`].\"\n\
     answer Q.answer_value\n"
  in
  let spec = load source in
  Random.init 20;
  let question = Rhema_engine.generate spec in
  (match question.answer with
  | Rhema_engine.Formula answer ->
      check_text "extended Formula DSL derivative" "1/cos(x)^2"
        (Rhema_formula.to_pg answer)
  | other -> fail ("extended Formula DSL returned " ^ Rhema_engine.describe_value other));
  if not (contains question.prompt "\\frac{\\ln\\left(4\\right)}{2}") then
    fail ("extended Formula DSL prompt was unexpected: " ^ question.prompt)

let check_linear_equation_dsl () =
  let source =
    "context \"Numeric\"\n\
     let p = polynomial_linear(2, -4, \"x\")\n\
     let z = polynomial_constant(0, \"x\")\n\
     let eq = polynomial_equation(p, z)\n\
     synth valid on Q\n\
     synth exact on Q\n\
     synth count on Q\n\
     synth text on Q\n\
     synth answer_value on Q\n\
     start Q\n\
     Q -> \"linear\" {\n\
       valid = equation_is_satisfied(eq, \"x\", 2)\n\
       exact = equation_has_exact_solutions(eq, \"x\")\n\
       count = equation_solution_count(eq, \"x\")\n\
       require valid and exact and count = 1\n\
       text = equation_latex(eq)\n\
       answer_value = equation_unique_solution(eq, \"x\")\n\
     }\n\
     prompt \"Solve [`{Q.text}`].\"\n\
     answer Q.answer_value\n"
  in
  let spec = load source in
  Random.init 21;
  let question = Rhema_engine.generate spec in
  match question.answer with
  | Rhema_engine.Num answer -> check_number "linear Equation DSL solution" (number 2) answer
  | other -> fail ("linear Equation DSL returned " ^ Rhema_engine.describe_value other)

let check_equation_answer_guard () =
  let x = Rhema_formula.variable "x" in
  let equation = Rhema_equation.make x (Rhema_formula.constant (number 2)) in
  match Rhema_pgml.answer_of_value (Rhema_engine.Equation equation) with
  | _ -> fail "a direct Equation answer should be rejected"
  | exception Invalid_argument _ -> ()

let () =
  check_formula ();
  check_polynomial ();
  check_random_polynomials ();
  check_equation ();
  check_dsl_integration ();
  check_extended_formula_dsl ();
  check_linear_equation_dsl ();
  check_equation_answer_guard ();
  if !failures = 0 then print_endline "Ag algebra core tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d algebra core test(s) failed." !failures);
    exit 1
  end
