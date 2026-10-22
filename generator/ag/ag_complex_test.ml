(* Independent checks for complex.ag. The oracle below mirrors the mathematics
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
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
      exit 1

let integer context number = Ag_number.require_integer context number

let number_value context = function
  | Ag_engine.Num number -> number
  | value ->
      fail (context ^ " expected a number, got " ^ Ag_engine.describe_value value);
      Ag_number.zero

let integer_global question name =
  match List.assoc_opt name question.Ag_engine.globals with
  | Some value -> integer name (number_value name value)
  | None ->
      fail ("missing question-level value " ^ name);
      0

let text_attribute node name =
  match Ag_engine.attribute node name with
  | Ag_engine.Text text -> text
  | value ->
      fail (name ^ " expected text, got " ^ Ag_engine.describe_value value);
      ""

let equal_number left right = Ag_number.equal left right

let equal_complex (left_real, left_imaginary) (right_real, right_imaginary) =
  equal_number left_real right_real && equal_number left_imaginary right_imaginary

let negate_pair (real, imaginary) = (real, Ag_number.negate imaginary)

let add_pair (a, b) (c, d) =
  (Ag_number.add a c, Ag_number.add b d)

let subtract_pair (a, b) (c, d) =
  (Ag_number.subtract a c, Ag_number.subtract b d)

let multiply_pair (a, b) (c, d) =
  ( Ag_number.subtract (Ag_number.multiply a c) (Ag_number.multiply b d),
    Ag_number.add (Ag_number.multiply a d) (Ag_number.multiply b c) )

let rec evaluate_expression operators (node : Ag_engine.node) =
  match (node.symbol, node.applied_rule, node.children) with
  | "E", Some rule, [ left; _operator_node; right ] -> (
      let operator =
        match rule.Ag_ast.rhs with
        | [ Ag_ast.Symbol "E"; Ag_ast.Literal operator; Ag_ast.Symbol "E" ] ->
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
          (Ag_number.zero, Ag_number.zero))
  | "E", Some _, [ child ] -> evaluate_expression operators child
  | "Z", Some _, [ real; imaginary ] ->
      ( number_value "complex real component" (Ag_engine.attribute real "value"),
        number_value "complex imaginary component" (Ag_engine.attribute imaginary "value") )
  | _ ->
      fail ("unexpected complex expression node " ^ node.symbol);
      (Ag_number.zero, Ag_number.zero)

let expression_child root =
  match List.find_opt (fun (node : Ag_engine.node) -> node.symbol = "E") root.Ag_engine.children with
  | Some expression -> expression
  | None ->
      fail "complex question is missing its E child";
      root

let check_answer seed expected question =
  match question.Ag_engine.answer with
  | Ag_engine.Complex (real, imaginary) ->
      if not (equal_complex expected (real, imaginary)) then
        let expected_real, expected_imaginary = expected in
        fail
          (Printf.sprintf "seed %d: expected Complex(%s,%s), got %s" seed
             (Ag_number.to_string expected_real) (Ag_number.to_string expected_imaginary)
             question.Ag_engine.answer_text)
  | other ->
      fail
        (Printf.sprintf "seed %d: expected a complex answer, got %s" seed
           (Ag_engine.describe_value other))

let check_rendering () =
  let number value = Ag_number.of_int value in
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
      let actual = Ag_engine.format_complex_latex (number real) (number imaginary) in
      if actual <> expected then
        fail (Printf.sprintf "complex_latex(%d,%d) produced %S, expected %S" real
                imaginary actual expected))
    cases

(* Every check on one generated question, whatever budget it was built at:
   the answer against an independent oracle, the signs in the prompt, and the
   bookkeeping of which kinds and operators were seen. *)
let check_question kinds operators seed question =
  let root = question.Ag_engine.tree in
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
      let m = integer_global question "modulus_m" in
      let expected = (m * m) + 1 in
      (match question.answer with
      | Ag_engine.Num number when integer "modulus" number = expected -> ()
      | value ->
          fail
            (Printf.sprintf "seed %d: modulus expected %d, got %s" seed expected
               (Ag_engine.describe_value value)));
      let sign_re = integer_global question "modulus_sign_re" in
      let sign_im = integer_global question "modulus_sign_im" in
      let swap =
        match List.assoc_opt "modulus_swap" question.globals with
        | Some (Ag_engine.Truth value) -> value
        | _ ->
            fail "modulus_swap is missing or not Boolean";
            false
      in
      let a = (m * m) - 1 and b = 2 * m in
      let real, imaginary =
        if swap then (sign_re * b, sign_im * a)
        else (sign_re * a, sign_im * b)
      in
      if (real * real) + (imaginary * imaginary) <> expected * expected then
        fail (Printf.sprintf "seed %d: modulus components are not Pythagorean" seed);
      let rendered =
        Ag_engine.format_complex_latex (Ag_number.of_int real)
          (Ag_number.of_int imaginary)
      in
      if not (contains question.prompt rendered) then
        fail (Printf.sprintf "seed %d: modulus prompt does not show %S" seed rendered)
  | "power_i" ->
      let exponent = integer_global question "exponent" in
      let expected =
        match exponent mod 4 with
        | 0 -> (Ag_number.of_int 1, Ag_number.zero)
        | 1 -> (Ag_number.zero, Ag_number.of_int 1)
        | 2 -> (Ag_number.of_int (-1), Ag_number.zero)
        | _ -> (Ag_number.zero, Ag_number.of_int (-1))
      in
      check_answer seed expected question
  | other -> fail ("unknown complex question kind " ^ other));
  if Ag_engine.describe_value (Ag_engine.attribute root "answer_value")
     <> question.answer_text
  then fail (Printf.sprintf "seed %d: Q.answer_value differs from final answer" seed)

(* ------------------------------------------------------------------ *)
(* Re-pricing what the student sees                                    *)
(* ------------------------------------------------------------------ *)

(* complex.ag prices a sum or difference at 1, a product at 3 and a leaf at
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

let price_of_question question =
  match text_attribute question.Ag_engine.tree "kind" with
  | "modulus" -> 2
  | "power_i" -> 1
  | _ ->
      let prompt = question.Ag_engine.prompt in
      let expression =
        match (String.index_opt prompt '`', String.rindex_opt prompt '`') with
        | Some first, Some last when last > first ->
            String.sub prompt (first + 1) (last - first - 1)
        | _ ->
            fail ("no [`...`] found in: " ^ prompt);
            ""
      in
      let operators = strip_leaves expression in
      count_occurrences operators "+" + count_occurrences operators "-"
      + (3 * count_occurrences operators "\\cdot")

let () =
  check_rendering ();
  let spec = load_file "complex.ag" in
  if spec.Ag_check.context <> "Complex" then
    fail ("complex.ag selected context " ^ spec.Ag_check.context);
  let kinds = Hashtbl.create 4 in
  let operators = Hashtbl.create 3 in
  for seed = 0 to 499 do
    Random.init seed;
    let question = Ag_engine.generate spec in
    check_question kinds operators seed question;
    if Ag_engine.consumption question.Ag_engine.tree "cost" <> 4 then
      fail (Printf.sprintf "seed %d: did not spend exactly the default cost of 4" seed)
  done;
  (* The budget sweep: every budget generates, is spent exactly, and prices
     the printed question to the same number. The fixed forms appear only at
     their own price, so this is also where modulus and power_i are seen. *)
  for cost = 0 to 6 do
    match Ag_check.with_initial spec "cost" cost with
    | Error message -> fail message
    | Ok spec ->
        for seed = 0 to 29 do
          Random.init (seed + (cost * 1000));
          match Ag_engine.generate spec with
          | exception Ag_engine.Generation_error message ->
              fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
          | question ->
              check_question kinds operators seed question;
              let spent = Ag_engine.consumption question.Ag_engine.tree "cost" in
              if spent <> cost then
                fail (Printf.sprintf "cost %d: the tree spent %d" cost spent);
              let priced = price_of_question question in
              if priced <> cost then
                fail
                  (Printf.sprintf "cost %d: %S re-prices as %d" cost
                     question.Ag_engine.prompt priced)
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
  let first = Ag_engine.generate spec in
  Random.init 9102;
  let second = Ag_engine.generate spec in
  if first.prompt <> second.prompt || first.answer_text <> second.answer_text then
    fail "the same seed did not reproduce the same complex question";

  Random.init 41;
  let document = Ag_pgml.of_spec ~count:30 spec in
  if not (contains document "Context(\"Complex\");") then
    fail "complex PGML did not select Context(\"Complex\")";
  if not (contains document "Complex(") then
    fail "complex PGML did not contain a typed Complex answer";
  let direct =
    Ag_pgml.answer_of_value
      (Ag_engine.Complex (Ag_number.of_int (-3), Ag_number.of_int 4))
  in
  if direct <> "Complex(-3,4)" then
    fail ("typed complex answer rendered as " ^ direct);

  if !failures = 0 then print_endline "Ag complex tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG complex test(s) failed." !failures);
    exit 1
  end
