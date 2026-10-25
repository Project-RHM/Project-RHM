(* Independent checks for vector_expr.rhm.

   The expression is evaluated again from the derivation and the three
   vectors the question defines, with the arithmetic written out here, and
   compared with the engine's answer. The same walk re-prices the question. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

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

let text_attribute node name =
  match Rhema_engine.attribute node name with
  | Rhema_engine.Text text -> text
  | other ->
      fail (name ^ " expected text, got " ^ Rhema_engine.describe_value other);
      ""

let global_vector question name =
  match List.assoc_opt name question.Rhema_engine.globals with
  | Some (Rhema_engine.Vector vector) -> Rhema_vector.components vector
  | _ ->
      fail ("missing vector " ^ name);
      []

let zip3 f a b = List.map2 f a b
let plus = zip3 Rhema_number.add
let minus = zip3 Rhema_number.subtract
let times k = List.map (Rhema_number.multiply k)
let dot a b = List.fold_left Rhema_number.add Rhema_number.zero (zip3 Rhema_number.multiply a b)
let cross a b =
  match (a, b) with
  | [ a1; a2; a3 ], [ b1; b2; b3 ] ->
      let m = Rhema_number.multiply and s = Rhema_number.subtract in
      [ s (m a2 b3) (m a3 b2); s (m a3 b1) (m a1 b3); s (m a1 b2) (m a2 b1) ]
  | _ -> fail "a vector is not three-dimensional"; []

(* (value, price) of an expression node, from its rule's shape. *)
let rec evaluate question (node : Rhema_engine.node) =
  match (node.symbol, node.applied_rule, node.children) with
  | "E", Some rule, [ left; _; right ] -> (
      match rule.Rhema_ast.rhs with
      | [ Rhema_ast.Symbol "E"; Rhema_ast.Literal "+"; Rhema_ast.Symbol "E" ] ->
          let a, pa = evaluate question left and b, pb = evaluate question right in
          (plus a b, 1 + pa + pb)
      | [ Rhema_ast.Symbol "E"; Rhema_ast.Literal "-"; Rhema_ast.Symbol "E" ] ->
          let a, pa = evaluate question left and b, pb = evaluate question right in
          (minus a b, 1 + pa + pb)
      | [ _; Rhema_ast.Literal "\\cdot"; Rhema_ast.Symbol "E" ] ->
          let k =
            match Rhema_engine.attribute left "value" with
            | Rhema_engine.Num k -> k
            | other -> fail ("scalar expected a number, got " ^ Rhema_engine.describe_value other); Rhema_number.zero
          in
          let b, pb = evaluate question right in
          (times k b, 1 + pb)
      | _ -> fail "unexpected E production"; ([], 0))
  | "E", Some _, [ leaf ] -> evaluate question leaf
  | "V", Some rule, _ -> (
      match rule.Rhema_ast.rhs with
      | [ Rhema_ast.Literal name ] -> (global_vector question ("vec_" ^ name), 0)
      | _ -> fail "unexpected V production"; ([], 0))
  | _ -> fail ("unexpected node " ^ node.symbol); ([], 0)

let expression_children (root : Rhema_engine.node) =
  List.filter (fun (node : Rhema_engine.node) -> node.symbol = "E") root.children

let equal_vectors a b = List.length a = List.length b && List.for_all2 Rhema_number.equal a b

let form_price = function
  | "compute" -> 0 | "dot" -> 2 | "norm" -> 2 | "cross" -> 4
  | other -> fail ("unknown kind " ^ other); 0

let () =
  let base = load_file "vector_expr.rhm" in
  if base.Rhema_check.context <> "Vector" then fail ("vector_expr.rhm selected context " ^ base.context);
  let kinds = Hashtbl.create 4 in
  for cost = 1 to 10 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 29 do
      Random.init (seed + (cost * 1000));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error message ->
          fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
      | question ->
          let root = question.Rhema_engine.tree in
          let kind = text_attribute root "kind" in
          Hashtbl.replace kinds kind true;
          let spent = Rhema_engine.consumption root "cost" in
          if spent <> cost then fail (Printf.sprintf "cost %d: the tree spent %d" cost spent);
          let operands = List.map (evaluate question) (expression_children root) in
          let priced = form_price kind + List.fold_left (fun total (_, price) -> total + price) 0 operands in
          if priced <> cost then
            fail (Printf.sprintf "cost %d seed %d: %s re-prices as %d" cost seed question.Rhema_engine.prompt priced);
          let bad message = fail (Printf.sprintf "cost %d seed %d (%s): %s" cost seed kind message) in
          (match (kind, operands, question.Rhema_engine.answer) with
          | "compute", [ (a, _) ], Rhema_engine.Vector answer ->
              if not (equal_vectors a (Rhema_vector.components answer)) then bad "the computed vector is wrong"
          | "dot", [ (a, _); (b, _) ], Rhema_engine.Num answer ->
              if not (Rhema_number.equal (dot a b) answer) then bad "the dot product is wrong"
          | "cross", [ (a, _); (b, _) ], Rhema_engine.Vector answer ->
              if not (equal_vectors (cross a b) (Rhema_vector.components answer)) then bad "the cross product is wrong"
          | "norm", [ (a, _) ], Rhema_engine.VectorNormAnswer answer ->
              if not (equal_vectors a (Rhema_vector.components answer)) then bad "the norm is of the wrong vector"
          | _ -> bad ("unexpected answer " ^ Rhema_engine.describe_value question.Rhema_engine.answer));
          if kind = "compute" && cost < 1 then bad "a bare vector was asked for"
    done
  done;
  List.iter (fun kind -> if not (Hashtbl.mem kinds kind) then fail ("never generated " ^ kind))
    [ "compute"; "dot"; "cross"; "norm" ];
  if !failures = 0 then print_endline "Ag vector expression tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG vector expression test(s) failed." !failures);
    exit 1
  end
