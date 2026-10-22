(* Independent checks for the four linear-algebra grammars. The arithmetic
   is written out here over lists of exact numbers, without the matrix
   library, and applied to the matrices the question defines. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let load_file filename =
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
      exit 1

let with_initial spec name value =
  match Ag_check.with_initial spec name value with
  | Ok changed -> changed
  | Error message -> fail message; spec

let text_attribute node name =
  match Ag_engine.attribute node name with
  | Ag_engine.Text text -> text
  | other -> fail (name ^ " expected text, got " ^ Ag_engine.describe_value other); ""

let matrix_global question name =
  match List.assoc_opt name question.Ag_engine.globals with
  | Some (Ag_engine.Matrix m) -> Ag_matrix.entries m
  | _ -> fail ("missing matrix " ^ name); []

let number_global question name =
  match List.assoc_opt name question.Ag_engine.globals with
  | Some (Ag_engine.Num n) -> n
  | _ -> fail ("missing number " ^ name); Ag_number.zero

(* ---- the arithmetic, written out ---- *)
let rows_equal a b = List.length a = List.length b && List.for_all2 (fun r s -> List.length r = List.length s && List.for_all2 Ag_number.equal r s) a b
let plus = List.map2 (List.map2 Ag_number.add)
let minus = List.map2 (List.map2 Ag_number.subtract)
let times k = List.map (List.map (Ag_number.multiply k))
let rec transpose = function [] | [] :: _ -> [] | m -> List.map List.hd m :: transpose (List.map List.tl m)
let dot a b = List.fold_left2 (fun t x y -> Ag_number.add t (Ag_number.multiply x y)) Ag_number.zero a b
let product a b = let bt = transpose b in List.map (fun row -> List.map (dot row) bt) a
let rec det = function
  | [ [ a ] ] -> a
  | m ->
      let first = List.hd m in
      List.fold_left
        (fun total (j, entry) ->
          let minor = List.tl m |> List.map (fun row -> List.filteri (fun c _ -> c <> j) row) in
          let signed = if j mod 2 = 0 then det minor else Ag_number.negate (det minor) in
          Ag_number.add total (Ag_number.multiply entry signed))
        Ag_number.zero (List.mapi (fun j e -> (j, e)) first)
let identity n = List.init n (fun i -> List.init n (fun j -> if i = j then Ag_number.of_int 1 else Ag_number.zero))

(* ---- evaluating a matrix expression from the derivation ---- *)
let rec evaluate question dim (node : Ag_engine.node) =
  let leaf name = matrix_global question (String.lowercase_ascii name ^ string_of_int dim) in
  match (node.symbol, node.applied_rule, node.children) with
  | ("E" | "D"), Some rule, children -> (
      match (rule.Ag_ast.rhs, children) with
      | [ Ag_ast.Symbol _; Ag_ast.Literal "+"; Ag_ast.Symbol _ ], [ l; _; r ] -> plus (evaluate question dim l) (evaluate question dim r)
      | [ Ag_ast.Symbol _; Ag_ast.Literal "-"; Ag_ast.Symbol _ ], [ l; _; r ] -> minus (evaluate question dim l) (evaluate question dim r)
      | [ Ag_ast.Symbol _; Ag_ast.Literal "\\times"; Ag_ast.Symbol _ ], [ l; _; r ] -> product (evaluate question dim l) (evaluate question dim r)
      | [ Ag_ast.Symbol _; Ag_ast.Literal "^T" ], [ inner; _ ] -> transpose (evaluate question dim inner)
      | [ _; Ag_ast.Literal "\\cdot"; Ag_ast.Symbol _ ], [ k; _; inner ] ->
          (match Ag_engine.attribute k "value" with
           | Ag_engine.Num k -> times k (evaluate question dim inner)
           | other -> fail ("scalar is not a number: " ^ Ag_engine.describe_value other); [])
      | [ Ag_ast.Symbol "V" ], [ v ] -> evaluate question dim v
      | _ -> fail ("unexpected rule for " ^ node.symbol); [])
  | "V", Some rule, _ -> (match rule.Ag_ast.rhs with [ Ag_ast.Literal name ] -> leaf name | _ -> fail "unexpected V rule"; [])
  | _ -> fail ("unexpected node " ^ node.symbol); []

let expression_child (root : Ag_engine.node) symbol =
  match List.find_opt (fun (node : Ag_engine.node) -> node.symbol = symbol) root.children with
  | Some node -> node
  | None -> fail ("no " ^ symbol ^ " child"); root

let sweep name budgets check =
  let base = load_file name in
  let kinds = Hashtbl.create 4 in
  List.iter
    (fun cost ->
      let spec = with_initial base "cost" cost in
      for seed = 0 to 24 do
        Random.init (seed + (cost * 1000));
        match Ag_engine.generate spec with
        | exception Ag_engine.Generation_error message -> fail (Printf.sprintf "%s cost %d seed %d: %s" name cost seed message)
        | question ->
            if Ag_engine.consumption question.Ag_engine.tree "cost" <> cost then
              fail (Printf.sprintf "%s cost %d seed %d: the budget was not spent exactly" name cost seed);
            let kind = text_attribute question.Ag_engine.tree "kind" in
            Hashtbl.replace kinds kind true;
            check cost seed kind question
      done)
    budgets;
  kinds

let () =
  (* matrix_expr: the value re-computed from the derivation *)
  let kinds =
    sweep "matrix_expr.ag" [ 1; 2; 3; 4; 5; 6; 8 ] (fun cost seed kind question ->
        let dim = if kind = "small" then 2 else 3 in
        let expected = evaluate question dim (expression_child question.Ag_engine.tree "E") in
        match question.Ag_engine.answer with
        | Ag_engine.Matrix answer when rows_equal (Ag_matrix.entries answer) expected -> ()
        | other -> fail (Printf.sprintf "matrix_expr cost %d seed %d: wrong value %s" cost seed (Ag_engine.describe_value other)))
  in
  List.iter (fun k -> if not (Hashtbl.mem kinds k) then fail ("matrix_expr never asked " ^ k)) [ "small"; "large" ];
  (* determinant: cofactor expansion written here *)
  let kinds =
    sweep "determinant.ag" [ 1; 2; 3; 4; 5; 6; 8 ] (fun cost seed kind question ->
        let dim = if kind = "small" then 2 else 3 in
        let expected = det (evaluate question dim (expression_child question.Ag_engine.tree "D")) in
        match question.Ag_engine.answer with
        | Ag_engine.Num answer when Ag_number.equal answer expected -> ()
        | other -> fail (Printf.sprintf "determinant cost %d seed %d: expected %s, got %s" cost seed (Ag_number.to_string expected) (Ag_engine.describe_value other)))
  in
  List.iter (fun k -> if not (Hashtbl.mem kinds k) then fail ("determinant never asked " ^ k)) [ "small"; "large" ];
  (* inverse: A times the answer is the identity, and the entries are whole where promised *)
  let kinds =
    sweep "matrix_inverse.ag" [ 2; 3; 5; 6 ] (fun cost seed kind question ->
        let a =
          match Ag_engine.attribute question.Ag_engine.tree "matrix" with
          | Ag_engine.Matrix m -> Ag_matrix.entries m
          | other -> fail ("matrix is not a matrix: " ^ Ag_engine.describe_value other); []
        in
        match question.Ag_engine.answer with
        | Ag_engine.Matrix answer ->
            let inverse = Ag_matrix.entries answer in
            if not (rows_equal (product a inverse) (identity (List.length a))) then
              fail (Printf.sprintf "matrix_inverse cost %d seed %d: A times the answer is not I" cost seed);
            let whole = List.for_all (List.for_all Ag_number.is_integer) inverse in
            if (kind = "small" || kind = "large") && not whole then
              fail (Printf.sprintf "matrix_inverse cost %d seed %d: the inverse should have whole entries" cost seed);
            if (kind = "small_scaled" || kind = "large_scaled") && whole then
              fail (Printf.sprintf "matrix_inverse cost %d seed %d: the scaled inverse should have fractions" cost seed)
        | other -> fail (Printf.sprintf "matrix_inverse cost %d seed %d: answer %s" cost seed (Ag_engine.describe_value other)))
  in
  List.iter (fun k -> if not (Hashtbl.mem kinds k) then fail ("matrix_inverse never asked " ^ k)) [ "small"; "small_scaled"; "large"; "large_scaled" ];
  (* linear system: the three answers satisfy every equation *)
  let kinds =
    sweep "linear_system.ag" [ 3; 5 ] (fun cost seed kind question ->
        let a =
          match Ag_engine.attribute question.Ag_engine.tree "matrix" with
          | Ag_engine.Matrix m -> Ag_matrix.entries m
          | other -> fail ("matrix is not a matrix: " ^ Ag_engine.describe_value other); []
        in
        let b =
          match Ag_engine.attribute question.Ag_engine.tree "rhs" with
          | Ag_engine.Vector v -> Ag_vector.components v
          | other -> fail ("rhs is not a vector: " ^ Ag_engine.describe_value other); []
        in
        let x = List.map (fun v -> match v with Ag_engine.Num n -> n | _ -> fail "an answer is not a number"; Ag_number.zero) question.Ag_engine.answers in
        if List.length x <> 3 then fail (Printf.sprintf "linear_system cost %d seed %d: %d answers" cost seed (List.length x))
        else begin
          List.iteri (fun i row -> if not (Ag_number.equal (dot row x) (List.nth b i)) then
            fail (Printf.sprintf "linear_system cost %d seed %d: equation %d is not satisfied" cost seed (i + 1))) a;
          if Ag_number.is_zero (det a) then fail (Printf.sprintf "linear_system cost %d seed %d: singular system" cost seed);
          if kind = "triangular" && not (Ag_number.is_zero (List.nth (List.nth a 1) 0) && Ag_number.is_zero (List.nth (List.nth a 2) 0) && Ag_number.is_zero (List.nth (List.nth a 2) 1)) then
            fail (Printf.sprintf "linear_system cost %d seed %d: not triangular" cost seed);
          List.iteri (fun i value ->
            let name = List.nth [ "x1"; "x2"; "x3" ] i in
            if not (Ag_number.equal value (number_global question name)) then
              fail (Printf.sprintf "linear_system cost %d seed %d: answer %d is not the chosen %s" cost seed (i + 1) name)) x
        end)
  in
  List.iter (fun k -> if not (Hashtbl.mem kinds k) then fail ("linear_system never asked " ^ k)) [ "triangular"; "full" ];
  (* PG: a Matrix context for matrix answers, three blanks for a system *)
  let contains text fragment =
    let rec search i = i + String.length fragment <= String.length text && (String.sub text i (String.length fragment) = fragment || search (i + 1)) in
    search 0
  in
  Random.init 3;
  let document = Ag_pgml.of_spec ~count:2 (load_file "matrix_expr.ag") in
  if not (contains document "Context(\"Matrix\");" && contains document "Matrix([[") then fail "matrix_expr PG lacks the Matrix context or a Matrix answer";
  Random.init 3;
  let document = Ag_pgml.of_spec ~count:1 (load_file "linear_system.ag") in
  let rec count i found = if i + 7 > String.length document then found else if String.sub document i 7 = "[_____]" then count (i + 7) (found + 1) else count (i + 1) found in
  if count 0 0 <> 3 then fail (Printf.sprintf "linear_system PG has %d blanks for one question" (count 0 0));
  if !failures = 0 then print_endline "Ag matrix tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG matrix test(s) failed." !failures);
    exit 1
  end
