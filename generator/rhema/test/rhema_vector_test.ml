(* Independent semantic and generation checks for vector.rhm. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let contains text fragment =
  let text_length = String.length text and fragment_length = String.length fragment in
  let rec search index =
    index + fragment_length <= text_length
    && (String.sub text index fragment_length = fragment || search (index + 1))
  in
  fragment_length = 0 || search 0

let load_file filename =
  match Rhema_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Rhema_load.string_of_failure error)) errors;
      exit 1

let with_initial spec name value =
  match Rhema_check.with_initial spec name value with
  | Ok changed -> changed
  | Error message ->
      fail message;
      spec

let vector_value context = function
  | Rhema_engine.Vector vector -> vector
  | other ->
      fail (context ^ " expected Vector, got " ^ Rhema_engine.describe_value other);
      Rhema_vector.make [ Rhema_number.zero; Rhema_number.zero; Rhema_number.zero ]

let text_attribute node name =
  match Rhema_engine.attribute node name with
  | Rhema_engine.Text text -> text
  | other ->
      fail (name ^ " expected text, got " ^ Rhema_engine.describe_value other);
      ""

let vector_attribute node name = vector_value name (Rhema_engine.attribute node name)

let vector_children root =
  List.filter (fun (node : Rhema_engine.node) -> node.symbol = "V") root.Rhema_engine.children

let independent_dot left right =
  List.map2 Rhema_number.multiply left right
  |> List.fold_left Rhema_number.add Rhema_number.zero

let independent_cross left right =
  match (left, right) with
  | [ a1; a2; a3 ], [ b1; b2; b3 ] ->
      [ Rhema_number.subtract (Rhema_number.multiply a2 b3) (Rhema_number.multiply a3 b2);
        Rhema_number.subtract (Rhema_number.multiply a3 b1) (Rhema_number.multiply a1 b3);
        Rhema_number.subtract (Rhema_number.multiply a1 b2) (Rhema_number.multiply a2 b1) ]
  | _ ->
      fail "cross product received a non-3D vector";
      []

let check_answer seed kind vectors answer =
  match (kind, vectors, answer) with
  | "dot", [ left; right ], Rhema_engine.Num actual ->
      let expected = independent_dot left right in
      if not (Rhema_number.equal expected actual) then
        fail
          (Printf.sprintf "seed %d: dot expected %s, got %s" seed
             (Rhema_number.to_string expected) (Rhema_number.to_string actual))
  | "cross", [ left; right ], Rhema_engine.Vector actual ->
      let expected = independent_cross left right in
      if not (Rhema_vector.equal expected actual) then
        fail (Printf.sprintf "seed %d: incorrect cross product" seed);
      if Rhema_vector.is_zero actual then
        fail (Printf.sprintf "seed %d: cross product is the zero vector" seed)
  | "norm", [ source ], Rhema_engine.VectorNormAnswer actual
  | "unit", [ source ], Rhema_engine.VectorUnitAnswer actual ->
      if not (Rhema_vector.equal source actual) then
        fail (Printf.sprintf "seed %d: %s answer uses the wrong source vector" seed kind)
  | "parallel", [ source ], Rhema_engine.VectorDirectionAnswer (actual, false)
  | "same_direction", [ source ], Rhema_engine.VectorDirectionAnswer (actual, true) ->
      if not (Rhema_vector.equal source actual) then
        fail (Printf.sprintf "seed %d: %s comparator uses the wrong vector" seed kind)
  | _ ->
      fail
        (Printf.sprintf "seed %d: answer shape does not match %s (%s)" seed kind
           (Rhema_engine.describe_value answer))

let expected_kind = function
  | 1 -> "dot"
  | 2 -> "cross"
  | 3 -> "norm"
  | 4 -> "unit"
  | 5 -> "parallel"
  | 6 -> "same_direction"
  | _ -> invalid_arg "unknown vector mode"

(* vector.rhm offers each fixed form at its price alone. *)
let price_of_kind = function
  | "parallel" -> 1
  | "dot" | "norm" | "same_direction" -> 2
  | "unit" -> 3
  | "cross" -> 4
  | other -> invalid_arg ("unknown vector kind " ^ other)

let check_modes base =
  for mode = 1 to 6 do
    let spec = with_initial base "vector_mode" mode in
    let spec = with_initial spec "cost" (price_of_kind (expected_kind mode)) in
    for seed = 0 to 59 do
      Random.init (20_000 + (mode * 100) + seed);
      let question = Rhema_engine.generate spec in
      let actual = text_attribute question.tree "kind" in
      if actual <> expected_kind mode then
        fail
          (Printf.sprintf "vector_mode=%d generated %s instead of %s" mode actual
             (expected_kind mode))
    done
  done

(* Every check on one generated question, at whatever budget it was built. *)
let check_question kinds seed question =
  let root = question.Rhema_engine.tree in
  let kind = text_attribute root "kind" in
  Hashtbl.replace kinds kind true;
  let vectors = List.map (fun node -> vector_attribute node "value") (vector_children root) in
  List.iter
    (fun vector ->
      if Rhema_vector.dimension vector <> 3 then
        fail (Printf.sprintf "seed %d: generated vector is not 3D" seed);
      if Rhema_vector.is_zero vector then
        fail (Printf.sprintf "seed %d: generated the zero vector" seed);
      if not (contains question.prompt (Rhema_vector.to_latex vector)) then
        fail (Printf.sprintf "seed %d: prompt omits an operand vector" seed))
    vectors;
  (match vectors with
  | first :: second :: _ when Rhema_vector.equal first second ->
      fail (Printf.sprintf "seed %d: binary question selected the same vector twice" seed)
  | _ -> ());
  check_answer seed kind vectors question.answer

let () =
  let spec = load_file "vector.rhm" in
  if spec.Rhema_check.context <> "Vector" then
    fail ("vector.rhm selected context " ^ spec.context);
  let kinds = Hashtbl.create 6 in
  for seed = 0 to 499 do
    Random.init seed;
    let question = Rhema_engine.generate spec in
    check_question kinds seed question;
    if Rhema_engine.consumption question.Rhema_engine.tree "cost" <> 2 then
      fail (Printf.sprintf "seed %d: did not spend exactly the default cost of 2" seed)
  done;
  (* Every form is fixed and offered at its price alone, so the kinds are
     collected over the budgets 1 to 4. *)
  for cost = 1 to 4 do
    let spec = with_initial spec "cost" cost in
    for seed = 0 to 59 do
      Random.init (seed + (cost * 1000));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error message ->
          fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
      | question ->
          check_question kinds seed question;
          let kind = text_attribute question.Rhema_engine.tree "kind" in
          if price_of_kind kind <> cost then
            fail (Printf.sprintf "cost %d produced a %s question, priced %d" cost kind (price_of_kind kind));
          if Rhema_engine.consumption question.Rhema_engine.tree "cost" <> cost then
            fail (Printf.sprintf "cost %d: the tree spent something else" cost)
    done
  done;
  List.iter
    (fun kind ->
      if not (Hashtbl.mem kinds kind) then fail ("mixed vector generation never used " ^ kind))
    [ "dot"; "cross"; "norm"; "unit"; "parallel"; "same_direction" ];

  check_modes spec;

  Random.init 9105;
  let first = Rhema_engine.generate spec in
  Random.init 9105;
  let second = Rhema_engine.generate spec in
  if first.prompt <> second.prompt || first.answer_text <> second.answer_text then
    fail "the same seed did not reproduce the same vector question";

  (* Each form is offered at its price alone, so a document that shows every
     answer type is assembled from one batch per budget. *)
  let document =
    String.concat "\n"
      (List.map
         (fun cost ->
           Random.init (42 + cost);
           Rhema_pgml.of_spec ~count:30 (with_initial spec "cost" cost))
         [ 1; 2; 3; 4 ])
  in
  List.iter
    (fun marker ->
      if not (contains document marker) then
        fail (Printf.sprintf "vector PGML is missing %S" marker))
    [ "Context(\"Vector\");";
      "Compute(\"<";
      "norm(Compute(";
      "unit(Compute(";
      "->cmp(parallel=>1)";
      "sameDirection=>1" ];

  let sample =
    Rhema_vector.make
      [ Rhema_number.of_int 2; Rhema_number.of_int (-3); Rhema_number.of_int 4 ]
  in
  if Rhema_pgml.answer_of_value (Rhema_engine.Vector sample) <> "Compute(\"<2, -3, 4>\")"
  then fail "typed Vector answer has incorrect PGML";

  if !failures = 0 then print_endline "Ag vector tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG vector test(s) failed." !failures);
    exit 1
  end
