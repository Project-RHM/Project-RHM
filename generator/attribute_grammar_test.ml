open Ast
open Attribute_grammar

let fail message =
  prerr_endline ("Attribute grammar test failed: " ^ message);
  exit 1

let assert_equal_int label expected actual =
  if expected <> actual then
    fail
      (Printf.sprintf "%s: expected %d, received %d" label expected actual)

let rec maximum_integer_digits_expr = function
  | ME_Add (left, right) | ME_Sub (left, right) ->
      max (maximum_integer_digits_expr left) (maximum_integer_digits_term right)
  | ME_Term term -> maximum_integer_digits_term term

and maximum_integer_digits_term = function
  | T_Mul (left, right) | T_Div (left, right) ->
      max (maximum_integer_digits_term left) (maximum_integer_digits_factor right)
  | T_Fac factor -> maximum_integer_digits_factor factor

and maximum_integer_digits_factor = function
  | F_Paren expression -> maximum_integer_digits_expr expression
  | F_Num number -> String.length (string_of_int (int_of_float number))
  | F_Int number -> String.length (string_of_int (abs number))

let () =
  let specification = parse arithmetic_specification in
  let file_specification = load_arithmetic_specification () in
  if file_specification.start <> "E" then
    fail "generator/arithmetic.ag did not load with start symbol E";
  for len = 0 to 6 do
    for seed = 0 to 49 do
      Random.init (seed + (len * 1000));
      let expression =
        generate_math_expr
          ~specification
          ~len
          ~digit:3
          ~allow_float:false
          ()
      in
      assert_equal_int
        "operator budget"
        len
        (operator_count_math_expr expression);
      if maximum_integer_digits_expr expression > 3 then
        fail "digit budget was exceeded";
      ignore (evaluate_math_expr expression)
    done
  done;
  Random.init 20260626;
  let first =
    generate_math_expr
      ~specification
      ~len:5
      ~digit:2
      ~allow_float:false
      ()
  in
  Random.init 20260626;
  let second =
    generate_math_expr
      ~specification
      ~len:5
      ~digit:2
      ~allow_float:false
      ()
  in
  if first <> second then fail "the same seed did not reproduce the same AST";
  print_endline "Attribute grammar tests passed."
