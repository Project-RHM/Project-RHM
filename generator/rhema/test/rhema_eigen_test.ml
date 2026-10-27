(* Independent checks for eigen.rhm. The matrix is read back from the
   printed question; the answer is checked against it directly: claimed
   eigenvalues must be roots of det(A - tI) and account for its trace and
   determinant, a characteristic polynomial must be x^2 - tr(A) x + det(A),
   and an eigenvector v must satisfy A v = lambda v. *)

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
  match Rhema_check.with_initial spec name value with Ok s -> s | Error m -> fail m; spec

let kind (q : Rhema_engine.question) =
  match Rhema_engine.attribute q.Rhema_engine.tree "kind" with Rhema_engine.Text t -> t | _ -> "?"

let integers text =
  let found = ref [] and re = Str.regexp "-?[0-9]+" in
  let rec go start =
    match Str.search_forward re text start with
    | exception Not_found -> ()
    | i ->
        found := int_of_string (Str.matched_string text) :: !found;
        go (i + String.length (Str.matched_string text))
  in
  go 0;
  List.rev !found

(* The first pmatrix of the prompt, as rows. *)
let matrix prompt =
  ignore (Str.search_forward (Str.regexp "\\\\begin{pmatrix}\\(.*\\)\\\\end{pmatrix}") prompt 0);
  let body = Str.matched_group 1 prompt in
  Str.split (Str.regexp_string "\\\\") body |> List.map (fun row -> Array.of_list (integers row)) |> Array.of_list

let det2 m = (m.(0).(0) * m.(1).(1)) - (m.(0).(1) * m.(1).(0))

let det3 m =
  (m.(0).(0) * ((m.(1).(1) * m.(2).(2)) - (m.(1).(2) * m.(2).(1))))
  - (m.(0).(1) * ((m.(1).(0) * m.(2).(2)) - (m.(1).(2) * m.(2).(0))))
  + (m.(0).(2) * ((m.(1).(0) * m.(2).(1)) - (m.(1).(1) * m.(2).(0))))

let shifted m t = Array.mapi (fun i row -> Array.mapi (fun j x -> if i = j then x - t else x) row) m

let det m = if Array.length m = 2 then det2 m else det3 m

let trace m = Array.fold_left ( + ) 0 (Array.mapi (fun i row -> row.(i)) m)

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt and answer = Rhema_engine.describe_value q.Rhema_engine.answer in
  let a = matrix p in
  let n = Array.length a in
  match kind q with
  | "triangular" | "eigenvalues2" | "eigenvalues3" ->
      let values = integers answer in
      if List.length values <> n then fail (Printf.sprintf "%d eigenvalues for a %d by %d matrix: %s" (List.length values) n n answer);
      if List.length (List.sort_uniq compare values) <> n then fail ("repeated eigenvalue: " ^ answer);
      List.iter (fun t -> if det (shifted a t) <> 0 then fail (Printf.sprintf "%d is not an eigenvalue of %S" t p)) values;
      if List.fold_left ( + ) 0 values <> trace a then fail ("trace does not match: " ^ p);
      if List.fold_left ( * ) 1 values <> det a then fail ("determinant does not match: " ^ p);
      if kind q <> "triangular" && (a.(0).(1) = 0 || a.(1).(0) = 0) then fail ("triangular matrix in " ^ p)
  | "characteristic" ->
      let want = Printf.sprintf "x^2%s%s" (match - trace a with 0 -> "" | 1 -> "+x" | -1 -> "-x" | c when c > 0 -> Printf.sprintf "+%d*x" c | c -> Printf.sprintf "%d*x" c)
          (match det a with 0 -> "" | d when d > 0 -> Printf.sprintf "+%d" d | d -> string_of_int d) in
      if answer <> "Polynomial(" ^ want ^ ")" then fail (Printf.sprintf "characteristic polynomial %s, wanted %s, for %S" answer want p)
  | "eigenvector" ->
      let lambda = List.nth (integers (Str.string_after p (Str.search_forward (Str.regexp "lambda = ") p 0))) 0 in
      (match integers answer with
      | [ x; y ] ->
          if (x, y) = (0, 0) then fail "zero eigenvector";
          let ax = (a.(0).(0) * x) + (a.(0).(1) * y) and ay = (a.(1).(0) * x) + (a.(1).(1) * y) in
          if ax <> lambda * x || ay <> lambda * y then fail (Printf.sprintf "(%d, %d) is not an eigenvector for %d of %S" x y lambda p);
          if det (shifted a lambda) <> 0 then fail (Printf.sprintf "%d is not an eigenvalue of %S" lambda p)
      | _ -> fail ("eigenvector answer " ^ answer))
  | k -> fail ("unknown kind " ^ k)

let () =
  let base = load_file "eigen.rhm" in
  let prices = [ ("triangular", 1); ("eigenvalues2", 2); ("characteristic", 2); ("eigenvector", 3); ("eigenvalues3", 3) ] in
  let contexts = [ ("triangular", "Interval"); ("eigenvalues2", "Interval"); ("characteristic", "Numeric"); ("eigenvector", "Vector"); ("eigenvalues3", "Interval") ] in
  let seen = Hashtbl.create 8 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 199 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          let k = kind q in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if List.assoc_opt k contexts <> Some q.Rhema_engine.context then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          check q
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  if !failures = 0 then print_endline "Rhema eigen tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d eigen test(s) failed." !failures);
    exit 1
  end
