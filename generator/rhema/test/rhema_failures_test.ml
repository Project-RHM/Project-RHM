(* Checks that the engine stops with a message, never with an exception of
   the libraries below it.

   A grammar can pass `rhema check` and still ask for something that has no
   value: a variable named 2, a zero divisor met while differentiating, a
   matrix of negative size, a number too large to be kept exact. Each of
   these used to end the command with OCaml's "Fatal error: exception ...".
   Here every one is generated from and must raise Generation_error, with
   words that name the function or say what is wrong.

   Three things changed underneath and are held here as well: exact numbers
   are checked for overflow, where they used to wrap round silently; a
   generator draws from a range of any width, where a range of more than
   2^30 - 1 values used to raise; and an answer that is an equation, or text
   holding a blank, is refused when the question is generated, where it used
   to reach the writers. *)

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

let load name source =
  match Rhema_load.parse_string ~filename:name source with
  | Ok spec -> Some spec
  | Error errors ->
      fail
        (Printf.sprintf "%s was refused by the checker: %s" name
           (String.concat " | " (List.map Rhema_load.string_of_failure errors)));
      None

(* What generating a few questions ends in: the questions, or the message
   of a Generation_error. Any other exception is the defect this file is
   about, and is reported with its name. *)
let generate ?(count = 5) name source =
  match load name source with
  | None -> Error "not loaded"
  | Some spec -> (
      Random.init 7;
      match List.init count (fun _ -> Rhema_engine.generate spec) with
      | questions -> Ok questions
      | exception Rhema_engine.Generation_error message -> Error message
      | exception other ->
          fail (Printf.sprintf "%s ended with the exception %s" name (Printexc.to_string other));
          Error "")

let stops name source ~mentions =
  match generate name source with
  | Ok _ -> fail (Printf.sprintf "%s generated; an error mentioning %S was expected" name mentions)
  | Error message ->
      if message <> "" && not (contains message mentions) then
        fail (Printf.sprintf "%s: the error does not mention %S: %s" name mentions message)

(* A one-rule question around one expression, kept in a local name. *)
let around expression =
  Printf.sprintf
    {|synth v on Q
start Q

Q -> integer_between(1, 2) {
  let probe = %s
  v = $1.value
}

prompt "Go."
answer Q.v
|}
    expression

(* ------------------------------------------------------------------ *)
(* 1. A name that is not a variable name                                *)
(* ------------------------------------------------------------------ *)

(* A number is written out wherever text is taken, so 2 passes the checker
   as a variable name; no variable is named 2. *)
let () =
  let equation = {|equation(formula_variable("x"), formula_constant(1))|} in
  List.iter
    (fun (name, call) ->
      stops (name ^ "_name.rhm") (around call) ~mentions:(name ^ ": \"2\" is not a valid formula variable"))
    [
      ("polynomial_variable", "polynomial_variable(2)");
      ("polynomial_constant", "polynomial_constant(1, 2)");
      ("polynomial_linear", "polynomial_linear(1, 1, 2)");
      ("polynomial_quadratic", "polynomial_quadratic(1, 1, 1, 2)");
      ("formula_to_polynomial", "formula_to_polynomial(formula_constant(1), 2)");
      ("equation_has_exact_solutions", Printf.sprintf "equation_has_exact_solutions(%s, 2)" equation);
      ("equation_solution_count", Printf.sprintf "equation_solution_count(%s, 2)" equation);
      ("equation_solution_set", Printf.sprintf "equation_solution_set(%s, 2)" equation);
      ("equation_unique_solution", Printf.sprintf "equation_unique_solution(%s, 2)" equation);
    ];
  (* These already said so; they must go on saying it. *)
  stops "formula_variable_name.rhm" (around "formula_variable(2)") ~mentions:"is not a valid formula variable";
  stops "polynomial_monomial_name.rhm" (around "polynomial_monomial(1, 2, 2)") ~mentions:"is not a valid formula variable";
  stops "bool_var_name.rhm" (around "bool_var(2)") ~mentions:"is not a valid propositional variable"

(* ------------------------------------------------------------------ *)
(* 2. A value a function has no result for                              *)
(* ------------------------------------------------------------------ *)

let () =
  (* ln(0) differentiates to 0/0, and 1/x has no value at 0. *)
  stops "differentiate_zero.rhm"
    (around {|differentiate(formula_ln(formula_constant(0)), "x")|})
    ~mentions:"differentiate: formula division by zero";
  stops "substitute_zero.rhm"
    (around
       {|formula_substitute(formula_divide(formula_constant(1), formula_variable("x")), "x", formula_constant(0))|})
    ~mentions:"formula_substitute: formula division by zero";
  stops "identity_negative.rhm" (around "matrix_identity(0 - 1)")
    ~mentions:"matrix_identity: a size of -1 is negative";
  (* What worked goes on working. *)
  match generate "identity_two.rhm" (around "matrix_determinant(matrix_identity(2))") with
  | Ok _ -> ()
  | Error message -> fail ("matrix_identity(2) no longer generates: " ^ message)

(* ------------------------------------------------------------------ *)
(* 3. Exact numbers do not wrap round                                   *)
(* ------------------------------------------------------------------ *)

let overflows label compute =
  match compute () with
  | value ->
      fail (Printf.sprintf "%s gave %s where it cannot fit" label (Rhema_number.to_string value))
  | exception Rhema_number.Arithmetic_error message ->
      check (label ^ ": the message does not say the number is too large") (contains message "too large")

let () =
  let n = Rhema_number.of_int in
  (* An OCaml integer has 63 bits: the largest is 2^62 - 1. *)
  let big = n (1 lsl 60) in
  (* inside the range, nothing changes *)
  check "a sum that fits" (Rhema_number.equal (Rhema_number.add big big) (n (1 lsl 61)));
  check "the largest integer is reached without an error"
    (Rhema_number.equal (Rhema_number.add (n (max_int - 1)) (n 1)) (n max_int));
  check "a product that fits"
    (Rhema_number.equal (Rhema_number.multiply (n 1_000_000_000) (n 1_000_000_000)) (n 1_000_000_000_000_000_000));
  check "a difference of large numbers that fits"
    (Rhema_number.equal (Rhema_number.subtract (n max_int) (n max_int)) Rhema_number.zero);
  check "a fraction is still reduced"
    (Rhema_number.to_string (Rhema_number.divide (n 6) (n (-4))) = "-3/2");
  check "fractions still add" (Rhema_number.to_string (Rhema_number.add (Rhema_number.make 1 3) (Rhema_number.make 1 6)) = "1/2");
  check "numbers are still ordered"
    (Rhema_number.compare (Rhema_number.make 1 3) (Rhema_number.make 1 2) < 0
    && Rhema_number.compare (n (-5)) (n 2) < 0
    && Rhema_number.compare (n 7) (n 7) = 0);
  (* outside it, an error and never a wrong number *)
  overflows "max_int + 1" (fun () -> Rhema_number.add (n max_int) (n 1));
  overflows "min_int + 1 - 2" (fun () -> Rhema_number.subtract (n (min_int + 1)) (n 2));
  overflows "10^12 * 10^12" (fun () ->
      Rhema_number.multiply (n 1_000_000_000_000) (n 1_000_000_000_000));
  overflows "a negative product" (fun () -> Rhema_number.multiply (n (-(1 lsl 40))) (n (1 lsl 40)));
  overflows "10^30" (fun () -> Rhema_number.power (n 10) (n 30));
  overflows "the negative of the least integer" (fun () -> Rhema_number.negate (n min_int));
  overflows "a fraction with the least integer" (fun () -> Rhema_number.make min_int 3);
  overflows "denominators whose product does not fit" (fun () ->
      Rhema_number.add (Rhema_number.make 1 ((1 lsl 40) + 1)) (Rhema_number.make 1 ((1 lsl 40) + 3)));
  overflows "comparing fractions whose cross products do not fit" (fun () ->
      n (Rhema_number.compare (Rhema_number.make max_int 2) (Rhema_number.make 3 max_int)))

(* In a grammar an overflow stops the question like a division by zero. A
   power of 100 used to end in a stack overflow. *)
let () =
  stops "overflow_product.rhm" (around "(10 ^ 12) * (10 ^ 12)") ~mentions:"a number grew too large";
  stops "overflow_power.rhm"
    (around {|polynomial_power(polynomial_linear(1, 2, "x"), 100)|})
    ~mentions:"a number grew too large";
  match generate "large_but_exact.rhm" (around "(10 ^ 9) * (10 ^ 9)") with
  | Ok _ -> ()
  | Error message -> fail ("10^9 * 10^9 fits and must generate: " ^ message)

(* ------------------------------------------------------------------ *)
(* 4. Generators draw from a range of any width                         *)
(* ------------------------------------------------------------------ *)

let leaf generator =
  Printf.sprintf
    {|synth v on Q
start Q

Q -> %s {
  v = $1.value
}

prompt "Go."
answer Q.v
|}
    generator

let drawn name generator count =
  match generate ~count name (leaf generator) with
  | Error message ->
      fail (Printf.sprintf "%s does not generate: %s" generator message);
      []
  | Ok questions ->
      List.map
        (fun (question : Rhema_engine.question) ->
          match question.answer with
          | Rhema_engine.Num value -> Rhema_number.require_integer "answer" value
          | _ -> 0)
        questions

let () =
  (* Ten digits is more than Random.int takes. *)
  List.iter
    (fun digits ->
      let lower = int_of_float (10. ** float_of_int (digits - 1)) in
      let values = drawn "wide_integer.rhm" (Printf.sprintf "integer(%d)" digits) 40 in
      check
        (Printf.sprintf "integer(%d) draws numbers of %d digits" digits digits)
        (values <> []
        && List.for_all (fun value -> value >= lower && String.length (string_of_int value) = digits) values);
      check
        (Printf.sprintf "integer(%d) draws more than one number" digits)
        (List.length (List.sort_uniq compare values) > 20))
    [ 10; 12; 18 ];
  let values = drawn "wide_between.rhm" "integer_between(0 - 2000000000, 2000000000)" 60 in
  check "a range of four thousand million is drawn from, on both sides of zero"
    (List.for_all (fun value -> value >= -2_000_000_000 && value <= 2_000_000_000) values
    && List.exists (fun value -> value < 0) values
    && List.exists (fun value -> value > 1_100_000_000) values);
  let values = drawn "wide_nonzero.rhm" "nonzero_integer_between(0 - 2000000000, 2000000000)" 60 in
  check "the same without zero" (values <> [] && not (List.mem 0 values));
  check "nonzero_integer(12) draws" (drawn "wide_nonzero_digits.rhm" "nonzero_integer(12)" 5 <> []);
  (* Nineteen digits do not fit in an integer. *)
  stops "too_many_digits.rhm" (leaf "integer(19)") ~mentions:"at most 18 can be kept exact";
  stops "far_too_many_digits.rhm" (leaf "integer(40)") ~mentions:"at most 18 can be kept exact";
  (* A random of the file draws the same way. *)
  match
    generate "wide_random.rhm"
      {|random n = integer_between(0, 2000000000)
synth v on Q
start Q
Q -> integer_between(1, 2) { v = n }
prompt "Go."
answer Q.v
|}
  with
  | Ok _ -> ()
  | Error message -> fail ("a wide random does not generate: " ^ message)

(* A range Random.int takes is drawn exactly as before: no paper already
   generated changes. *)
let () =
  List.iter
    (fun bound ->
      Random.init 2026;
      let before = List.init 200 (fun _ -> Random.int bound) in
      Random.init 2026;
      let after = List.init 200 (fun _ -> Rhema_engine.random_below bound) in
      check (Printf.sprintf "a bound of %d is drawn as Random.int draws it" bound) (before = after))
    [ 1; 2; 10; 9000; 1_000_000; 0x3FFFFFFF ];
  Random.init 2026;
  check "a wider bound is drawn within it"
    (List.for_all
       (fun value -> value >= 0 && value < 4_000_000_001)
       (List.init 200 (fun _ -> Rhema_engine.random_below 4_000_000_001)))

(* ------------------------------------------------------------------ *)
(* 5. What is graded is an answer                                       *)
(* ------------------------------------------------------------------ *)

(* Through `cond` the checker cannot tell, and leaves it to the engine. An
   equation used to be listed by `rhema run` and to stop the PG writer. *)
let through_cond wrong =
  Printf.sprintf
    {|random flag = boolean
synth v on Q
start Q

Q -> integer_between(1, 2) {
  v = cond(flag, %s, 1)
}

prompt "Go."
answer Q.v
|}
    wrong

let () =
  stops "answer_equation.rhm"
    (through_cond {|equation(formula_variable("x"), formula_constant($1.value))|})
    ~mentions:"the answer is an equation, which cannot be graded";
  stops "answer_blanked.rhm" (through_cond "blank(1)")
    ~mentions:"the answer is text that holds an answer blank";
  (* The same through an {answer ...} hole. *)
  stops "hole_equation.rhm"
    {|random flag = boolean
synth v on Q
start Q

Q -> integer_between(1, 2) {
  v = cond(flag, equation(formula_variable("x"), formula_constant($1.value)), 1)
}

prompt "Go. {answer Q.v}"
|}
    ~mentions:"the answer is an equation, which cannot be graded";
  (* And the other branch alone is an answer like any other. *)
  match generate "answer_number.rhm" (through_cond "2") with
  | Ok _ -> ()
  | Error message -> fail ("a number through cond no longer generates: " ^ message)

(* ------------------------------------------------------------------ *)
(* 6. The library still generates, and writes                           *)
(* ------------------------------------------------------------------ *)

(* Checked arithmetic must not stop a question that was right: every
   question type of the library is generated and written as PG and LaTeX. *)
(* The files of the library, given by name on the command line (see the
   dune file). The suites run side by side in this directory and write
   temporary grammars into it, so listing the directory would pick up a file
   of another suite that is malformed on purpose, or gone a moment later. *)
let library_files =
  Array.to_list Sys.argv |> List.tl |> List.map Filename.basename
  |> List.filter (fun name -> Filename.check_suffix name ".rhm")
  |> List.sort_uniq String.compare

let () =
  let files = library_files in
  check "the library's files were given by name" (List.length files > 40);
  let asked = ref 0 in
  List.iter
    (fun filename ->
      match Rhema_load.parse_file filename with
      | Error errors ->
          List.iter (fun error -> fail (filename ^ ": " ^ Rhema_load.string_of_failure error)) errors
      | Ok file ->
          List.iter
            (fun (question : Rhema_check.question) ->
              match Rhema_check.select_question file question.q_name with
              | Error message -> fail message
              | Ok spec -> (
                  Random.init 5;
                  match List.init 30 (fun _ -> Rhema_engine.generate spec) with
                  | questions ->
                      asked := !asked + List.length questions;
                      (match Rhema_cli.questions_document spec questions with
                      | document -> check (filename ^ ": an empty PG document") (String.length document > 0)
                      | exception other ->
                          fail
                            (Printf.sprintf "%s (%s): writing PG ended with %s" filename question.q_name
                               (Printexc.to_string other)))
                  | exception other ->
                      fail
                        (Printf.sprintf "%s (%s): generation ended with %s" filename question.q_name
                           (Printexc.to_string other))))
            file.questions)
    files;
  check "the library's questions were generated" (!asked > 1000)

let () =
  if !failures = 0 then print_endline "Rhema failure-message tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d failure-message test(s) failed." !failures);
    exit 1
  end
