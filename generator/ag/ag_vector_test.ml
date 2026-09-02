(* Independent semantic and generation checks for vector.ag. *)

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
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
      exit 1

let with_initial spec name value =
  match Ag_check.with_initial spec name value with
  | Ok changed -> changed
  | Error message ->
      fail message;
      spec

let vector_value context = function
  | Ag_engine.Vector vector -> vector
  | other ->
      fail (context ^ " expected Vector, got " ^ Ag_engine.describe_value other);
      Ag_vector.make [ Ag_number.zero; Ag_number.zero; Ag_number.zero ]

let text_attribute node name =
  match Ag_engine.attribute node name with
  | Ag_engine.Text text -> text
  | other ->
      fail (name ^ " expected text, got " ^ Ag_engine.describe_value other);
      ""

let vector_attribute node name = vector_value name (Ag_engine.attribute node name)

let vector_children root =
  List.filter (fun (node : Ag_engine.node) -> node.symbol = "V") root.Ag_engine.children

let independent_dot left right =
  List.map2 Ag_number.multiply left right
  |> List.fold_left Ag_number.add Ag_number.zero

let independent_cross left right =
  match (left, right) with
  | [ a1; a2; a3 ], [ b1; b2; b3 ] ->
      [ Ag_number.subtract (Ag_number.multiply a2 b3) (Ag_number.multiply a3 b2);
        Ag_number.subtract (Ag_number.multiply a3 b1) (Ag_number.multiply a1 b3);
        Ag_number.subtract (Ag_number.multiply a1 b2) (Ag_number.multiply a2 b1) ]
  | _ ->
      fail "cross product received a non-3D vector";
      []

let check_answer seed kind vectors answer =
  match (kind, vectors, answer) with
  | "dot", [ left; right ], Ag_engine.Num actual ->
      let expected = independent_dot left right in
      if not (Ag_number.equal expected actual) then
        fail
          (Printf.sprintf "seed %d: dot expected %s, got %s" seed
             (Ag_number.to_string expected) (Ag_number.to_string actual))
  | "cross", [ left; right ], Ag_engine.Vector actual ->
      let expected = independent_cross left right in
      if not (Ag_vector.equal expected actual) then
        fail (Printf.sprintf "seed %d: incorrect cross product" seed);
      if Ag_vector.is_zero actual then
        fail (Printf.sprintf "seed %d: cross product is the zero vector" seed)
  | "norm", [ source ], Ag_engine.VectorNormAnswer actual
  | "unit", [ source ], Ag_engine.VectorUnitAnswer actual ->
      if not (Ag_vector.equal source actual) then
        fail (Printf.sprintf "seed %d: %s answer uses the wrong source vector" seed kind)
  | "parallel", [ source ], Ag_engine.VectorDirectionAnswer (actual, false)
  | "same_direction", [ source ], Ag_engine.VectorDirectionAnswer (actual, true) ->
      if not (Ag_vector.equal source actual) then
        fail (Printf.sprintf "seed %d: %s comparator uses the wrong vector" seed kind)
  | _ ->
      fail
        (Printf.sprintf "seed %d: answer shape does not match %s (%s)" seed kind
           (Ag_engine.describe_value answer))

let expected_kind = function
  | 1 -> "dot"
  | 2 -> "cross"
  | 3 -> "norm"
  | 4 -> "unit"
  | 5 -> "parallel"
  | 6 -> "same_direction"
  | _ -> invalid_arg "unknown vector mode"

let check_modes base =
  for mode = 1 to 6 do
    let spec = with_initial base "vector_mode" mode in
    for seed = 0 to 59 do
      Random.init (20_000 + (mode * 100) + seed);
      let question = Ag_engine.generate spec in
      let actual = text_attribute question.tree "kind" in
      if actual <> expected_kind mode then
        fail
          (Printf.sprintf "vector_mode=%d generated %s instead of %s" mode actual
             (expected_kind mode))
    done
  done

let () =
  let spec = load_file "vector.ag" in
  if spec.Ag_check.context <> "Vector" then
    fail ("vector.ag selected context " ^ spec.context);
  let kinds = Hashtbl.create 6 in
  for seed = 0 to 499 do
    Random.init seed;
    let question = Ag_engine.generate spec in
    let root = question.Ag_engine.tree in
    let kind = text_attribute root "kind" in
    Hashtbl.replace kinds kind true;
    let vectors = List.map (fun node -> vector_attribute node "value") (vector_children root) in
    List.iter
      (fun vector ->
        if Ag_vector.dimension vector <> 3 then
          fail (Printf.sprintf "seed %d: generated vector is not 3D" seed);
        if Ag_vector.is_zero vector then
          fail (Printf.sprintf "seed %d: generated the zero vector" seed);
        if not (contains question.prompt (Ag_vector.to_latex vector)) then
          fail (Printf.sprintf "seed %d: prompt omits an operand vector" seed))
      vectors;
    (match vectors with
    | first :: second :: _ when Ag_vector.equal first second ->
        fail (Printf.sprintf "seed %d: binary question selected the same vector twice" seed)
    | _ -> ());
    check_answer seed kind vectors question.answer
  done;
  List.iter
    (fun kind ->
      if not (Hashtbl.mem kinds kind) then fail ("mixed vector generation never used " ^ kind))
    [ "dot"; "cross"; "norm"; "unit"; "parallel"; "same_direction" ];

  check_modes spec;

  Random.init 9105;
  let first = Ag_engine.generate spec in
  Random.init 9105;
  let second = Ag_engine.generate spec in
  if first.prompt <> second.prompt || first.answer_text <> second.answer_text then
    fail "the same seed did not reproduce the same vector question";

  Random.init 42;
  let document = Ag_pgml.of_spec ~count:120 spec in
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
    Ag_vector.make
      [ Ag_number.of_int 2; Ag_number.of_int (-3); Ag_number.of_int 4 ]
  in
  if Ag_pgml.answer_of_value (Ag_engine.Vector sample) <> "Compute(\"<2, -3, 4>\")"
  then fail "typed Vector answer has incorrect PGML";

  if !failures = 0 then print_endline "Ag vector tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG vector test(s) failed." !failures);
    exit 1
  end
