(* Independent checks for complex.rhm. The oracle below mirrors the mathematics
   used by the Stage 1 semantic validator, rather than trusting the attributes
   that the specification itself computed. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let contains text fragment =
  let text_length = String.length text and fragment_length = String.length fragment in
  let rec search index =
    if index + fragment_length > text_length then false
    else if String.sub text index fragment_length = fragment then true
    else search (index + 1)
  in
  fragment_length = 0 || search 0

let load_file filename =
  match Rhema_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Rhema_load.string_of_failure error)) errors;
      exit 1

let integer context number = Rhema_number.require_integer context number

let number_value context = function
  | Rhema_engine.Num number -> number
  | value ->
      fail (context ^ " expected a number, got " ^ Rhema_engine.describe_value value);
      Rhema_number.zero

let integer_global question name =
  match List.assoc_opt name question.Rhema_engine.globals with
  | Some value -> integer name (number_value name value)
  | None ->
      fail ("missing question-level value " ^ name);
      0

let text_attribute node name =
  match Rhema_engine.attribute node name with
  | Rhema_engine.Text text -> text
  | value ->
      fail (name ^ " expected text, got " ^ Rhema_engine.describe_value value);
      ""

let equal_number left right = Rhema_number.equal left right

let equal_complex (left_real, left_imaginary) (right_real, right_imaginary) =
  equal_number left_real right_real && equal_number left_imaginary right_imaginary

let negate_pair (real, imaginary) = (real, Rhema_number.negate imaginary)

let add_pair (a, b) (c, d) =
  (Rhema_number.add a c, Rhema_number.add b d)

let subtract_pair (a, b) (c, d) =
  (Rhema_number.subtract a c, Rhema_number.subtract b d)

let multiply_pair (a, b) (c, d) =
  ( Rhema_number.subtract (Rhema_number.multiply a c) (Rhema_number.multiply b d),
    Rhema_number.add (Rhema_number.multiply a d) (Rhema_number.multiply b c) )

let rec evaluate_expression operators (node : Rhema_engine.node) =
  match (node.symbol, node.applied_rule, node.children) with
  | "E", Some rule, [ left; _operator_node; right ] -> (
      let operator =
        match rule.Rhema_ast.rhs with
        | [ Rhema_ast.Symbol "E"; Rhema_ast.Literal operator; Rhema_ast.Symbol "E" ] ->
            operator
        | _ ->
            fail "unexpected recursive E production";
            "?"
      in
      Hashtbl.replace operators operator (1 + Option.value ~default:0 (Hashtbl.find_opt operators operator));
      let left = evaluate_expression operators left in
      let right = evaluate_expression operators right in
      match operator with
      | "+" -> add_pair left right
      | "-" -> subtract_pair left right
      | "\\cdot" -> multiply_pair left right
      | other ->
          fail ("unknown complex operator " ^ other);
          (Rhema_number.zero, Rhema_number.zero))
  | "E", Some _, [ child ] -> evaluate_expression operators child
  | "Z", Some _, [ real; imaginary ] ->
      ( number_value "complex real component" (Rhema_engine.attribute real "value"),
        number_value "complex imaginary component" (Rhema_engine.attribute imaginary "value") )
  | _ ->
      fail ("unexpected complex expression node " ^ node.symbol);
      (Rhema_number.zero, Rhema_number.zero)

let expression_child root =
  match List.find_opt (fun (node : Rhema_engine.node) -> node.symbol = "E") root.Rhema_engine.children with
  | Some expression -> expression
  | None ->
      fail "complex question is missing its E child";
      root

let check_answer seed expected question =
  match question.Rhema_engine.answer with
  | Rhema_engine.Complex (real, imaginary) ->
      if not (equal_complex expected (real, imaginary)) then
        let expected_real, expected_imaginary = expected in
        fail
          (Printf.sprintf "seed %d: expected Complex(%s,%s), got %s" seed
             (Rhema_number.to_string expected_real) (Rhema_number.to_string expected_imaginary)
             question.Rhema_engine.answer_text)
  | other ->
      fail
        (Printf.sprintf "seed %d: expected a complex answer, got %s" seed
           (Rhema_engine.describe_value other))

let check_rendering () =
  let number value = Rhema_number.of_int value in
  let cases =
    [ ((0, 0), "0");
      ((3, 4), "3 + 4i");
      ((3, -4), "3 - 4i");
      ((0, 1), "i");
      ((0, -1), "-i");
      ((2, 1), "2 + i");
      ((-2, -1), "-2 - i") ]
  in
  List.iter
    (fun ((real, imaginary), expected) ->
      let actual = Rhema_engine.format_complex_latex (number real) (number imaginary) in
      if actual <> expected then
        fail (Printf.sprintf "complex_latex(%d,%d) produced %S, expected %S" real
                imaginary actual expected))
    cases

(* A modulus expression, evaluated from the shapes of its rules: a product,
   a conjugate, a whole-number multiple, or a Pythagorean-triple leaf built
   from its four drawn numbers (m, swap, two signs). *)
let number_of node name =
  match Rhema_engine.attribute node name with
  | Rhema_engine.Num n -> n
  | other -> fail (name ^ " expected a number, got " ^ Rhema_engine.describe_value other); Rhema_number.zero

let rec evaluate_modulus (node : Rhema_engine.node) =
  match (node.symbol, node.applied_rule, node.children) with
  | "M", Some rule, children -> (
      match (rule.Rhema_ast.rhs, children) with
      | [ Rhema_ast.Symbol "M"; Rhema_ast.Literal "\\cdot"; Rhema_ast.Symbol "M" ], [ left; _; right ] ->
          let a, b, m = evaluate_modulus left and c, d, n = evaluate_modulus right in
          ( Rhema_number.subtract (Rhema_number.multiply a c) (Rhema_number.multiply b d),
            Rhema_number.add (Rhema_number.multiply a d) (Rhema_number.multiply b c),
            Rhema_number.multiply m n )
      | [ Rhema_ast.Literal "\\overline"; Rhema_ast.Symbol "M" ], [ _; inner ] ->
          let a, b, m = evaluate_modulus inner in
          (a, Rhema_number.negate b, m)
      | [ _; Rhema_ast.Literal "\\cdot"; Rhema_ast.Symbol "M" ], [ scalar; _; inner ] ->
          let k = number_of scalar "value" in
          let a, b, m = evaluate_modulus inner in
          (Rhema_number.multiply k a, Rhema_number.multiply k b, Rhema_number.multiply k m)
      | [ Rhema_ast.Symbol "T" ], [ leaf ] -> evaluate_modulus leaf
      | _ -> fail "unexpected M production"; (Rhema_number.zero, Rhema_number.zero, Rhema_number.zero))
  | "T", Some _, m_node :: swap :: sign_re :: sign_im :: _ ->
      let m = integer "m" (number_of m_node "value") in
      let flag node = integer "flag" (number_of node "value") = 1 in
      let a = (m * m) - 1 and b = 2 * m in
      let real = (if flag sign_re then 1 else -1) * (if flag swap then b else a)
      and imaginary = (if flag sign_im then 1 else -1) * (if flag swap then a else b) in
      (Rhema_number.of_int real, Rhema_number.of_int imaginary, Rhema_number.of_int ((m * m) + 1))
  | _ -> fail ("unexpected node in a modulus expression: " ^ node.symbol); (Rhema_number.zero, Rhema_number.zero, Rhema_number.zero)

let modulus_child (root : Rhema_engine.node) =
  match List.find_opt (fun (node : Rhema_engine.node) -> node.symbol = "M") root.children with
  | Some node -> node
  | None -> fail "modulus question has no M child"; root

(* Every check on one generated question, whatever budget it was built at:
   the answer against an independent oracle, the signs in the prompt, and the
   bookkeeping of which kinds and operators were seen. *)
let check_question kinds operators seed question =
  let root = question.Rhema_engine.tree in
  let kind = text_attribute root "kind" in
  Hashtbl.replace kinds kind (1 + Option.value ~default:0 (Hashtbl.find_opt kinds kind));
  if contains question.prompt "+ -" || contains question.prompt "- -" then
    fail (Printf.sprintf "seed %d: ambiguous complex signs in %S" seed question.prompt);
  (match kind with
  | "arithmetic" ->
      let expected = evaluate_expression operators (expression_child root) in
      check_answer seed expected question
  | "conjugate" ->
      let value = evaluate_expression operators (expression_child root) in
      check_answer seed (negate_pair value) question
  | "modulus" ->
      let real, imaginary, modulus = evaluate_modulus (modulus_child root) in
      (match question.answer with
      | Rhema_engine.Num number when Rhema_number.equal number modulus -> ()
      | value ->
          fail
            (Printf.sprintf "seed %d: modulus expected %s, got %s" seed
               (Rhema_number.to_string modulus) (Rhema_engine.describe_value value)));
      let square x = Rhema_number.multiply x x in
      if not (Rhema_number.equal (Rhema_number.add (square real) (square imaginary)) (square modulus)) then
        fail (Printf.sprintf "seed %d: the modulus expression is not Pythagorean" seed)
  | "power_i" ->
      let exponent = integer_global question "exponent" in
      let re, im = evaluate_expression operators (expression_child root) in
      let expected =
        match exponent mod 4 with
        | 0 -> (re, im)
        | 1 -> (Rhema_number.negate im, re)
        | 2 -> (Rhema_number.negate re, Rhema_number.negate im)
        | _ -> (im, Rhema_number.negate re)
      in
      check_answer seed expected question
  | other -> fail ("unknown complex question kind " ^ other));
  if Rhema_engine.describe_value (Rhema_engine.attribute root "answer_value")
     <> question.answer_text
  then fail (Printf.sprintf "seed %d: Q.answer_value differs from final answer" seed)

(* ------------------------------------------------------------------ *)
(* Re-pricing what the student sees                                    *)
(* ------------------------------------------------------------------ *)

(* complex.rhm prices a sum or difference at 1, a product at 3 and a leaf at
   0; the fixed forms cost 2 (modulus) and 1 (power of i). In the printed
   expression every leaf is an innermost bracketed group such as (3 - 4i),
   so once those are removed each remaining + or - is a binary operator. *)
let strip_leaves text =
  let length = String.length text in
  let buffer = Buffer.create length in
  let rec copy index =
    if index >= length then ()
    else if text.[index] = '(' then begin
      let rec scan position =
        if position >= length then None
        else
          match text.[position] with
          | ')' -> Some position
          | '(' -> None
          | _ -> scan (position + 1)
      in
      match scan (index + 1) with
      | Some close -> copy (close + 1)
      | None ->
          Buffer.add_char buffer '(';
          copy (index + 1)
    end
    else begin
      Buffer.add_char buffer text.[index];
      copy (index + 1)
    end
  in
  copy 0;
  Buffer.contents buffer

let count_occurrences text fragment =
  let text_length = String.length text and fragment_length = String.length fragment in
  let rec count index found =
    if index + fragment_length > text_length then found
    else if String.sub text index fragment_length = fragment then
      count (index + fragment_length) (found + 1)
    else count (index + 1) found
  in
  count 0 0

let count_digit_runs text =
  let count = ref 0 and in_digits = ref false in
  String.iter
    (fun c ->
      let digit = c >= '0' && c <= '9' in
      if digit && not !in_digits then incr count;
      in_digits := digit)
    text;
  !count

(* complex.rhm prices a sum or difference 1, a product 3, a leaf 0; the
   modulus form 2 plus its expression (product 2, conjugate 1, multiple 1);
   the power form 1 plus its expression. Leaves are innermost bracketed
   groups, so once they are removed every operator left is a real one. *)
let price_of_question question =
  let prompt = question.Rhema_engine.prompt in
  let expression =
    match (String.index_opt prompt '`', String.rindex_opt prompt '`') with
    | Some first, Some last when last > first -> String.sub prompt (first + 1) (last - first - 1)
    | _ -> fail ("no [`...`] found in: " ^ prompt); ""
  in
  let arithmetic text =
    let operators = strip_leaves text in
    count_occurrences operators "+" + count_occurrences operators "-"
    + (3 * count_occurrences operators "\\cdot")
  in
  match text_attribute question.Rhema_engine.tree "kind" with
  | "modulus" ->
      let operators = strip_leaves expression in
      2 + (2 * count_occurrences operators "\\cdot") + count_occurrences operators "\\overline"
      + count_digit_runs operators
  | "power_i" ->
      let marker = "\\cdot " in
      let rec after index =
        if index + String.length marker > String.length expression then expression
        else if String.sub expression index (String.length marker) = marker then
          String.sub expression (index + String.length marker) (String.length expression - index - String.length marker)
        else after (index + 1)
      in
      1 + arithmetic (after 0)
  | _ -> arithmetic expression

let () =
  check_rendering ();
  let spec = load_file "complex.rhm" in
  if spec.Rhema_check.context <> "Complex" then
    fail ("complex.rhm selected context " ^ spec.Rhema_check.context);
  let kinds = Hashtbl.create 4 in
  let operators = Hashtbl.create 3 in
  for seed = 0 to 499 do
    Random.init seed;
    let question = Rhema_engine.generate spec in
    check_question kinds operators seed question;
    if Rhema_engine.consumption question.Rhema_engine.tree "cost" <> 4 then
      fail (Printf.sprintf "seed %d: did not spend exactly the default cost of 4" seed)
  done;
  (* The budget sweep: every budget generates, is spent exactly, and prices
     the printed question to the same number. The fixed forms appear only at
     their own price, so this is also where modulus and power_i are seen. *)
  for cost = 0 to 6 do
    match Rhema_check.with_initial spec "cost" cost with
    | Error message -> fail message
    | Ok spec ->
        for seed = 0 to 29 do
          Random.init (seed + (cost * 1000));
          match Rhema_engine.generate spec with
          | exception Rhema_engine.Generation_error message ->
              fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
          | question ->
              check_question kinds operators seed question;
              let spent = Rhema_engine.consumption question.Rhema_engine.tree "cost" in
              if spent <> cost then
                fail (Printf.sprintf "cost %d: the tree spent %d" cost spent);
              let priced = price_of_question question in
              if priced <> cost then
                fail
                  (Printf.sprintf "cost %d: %S re-prices as %d" cost
                     question.Rhema_engine.prompt priced)
        done
  done;
  List.iter
    (fun kind ->
      if not (Hashtbl.mem kinds kind) then fail ("no generated question used kind " ^ kind))
    [ "arithmetic"; "conjugate"; "modulus"; "power_i" ];
  List.iter
    (fun operator ->
      if not (Hashtbl.mem operators operator) then
        fail ("recursive complex expressions never used operator " ^ operator))
    [ "+"; "-"; "\\cdot" ];

  Random.init 9102;
  let first = Rhema_engine.generate spec in
  Random.init 9102;
  let second = Rhema_engine.generate spec in
  if first.prompt <> second.prompt || first.answer_text <> second.answer_text then
    fail "the same seed did not reproduce the same complex question";

  Random.init 41;
  let document = Rhema_pgml.of_spec ~count:30 spec in
  if not (contains document "Context(\"Complex\");") then
    fail "complex PGML did not select Context(\"Complex\")";
  if not (contains document "Complex(") then
    fail "complex PGML did not contain a typed Complex answer";
  let direct =
    Rhema_pgml.answer_of_value
      (Rhema_engine.Complex (Rhema_number.of_int (-3), Rhema_number.of_int 4))
  in
  if direct <> "Complex(-3,4)" then
    fail ("typed complex answer rendered as " ^ direct);

  if !failures = 0 then print_endline "Ag complex tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG complex test(s) failed." !failures);
    exit 1
  end
