(* Independent checks for row_reduction.rhm. The matrix is read back from
   the printed question and reduced here by elimination on exact fractions
   (pairs of integers), written apart from the engine's own. A rank must be
   the number of pivots found; a reduced form must have the defining shape
   (leading ones moving right, alone in their columns, zero rows last) and
   the same row space as the matrix; a null vector must be sent to zero,
   must not be zero, and the matrix must have rank 2, so that the null
   space is the line through it. *)

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

(* ---- fractions as (numerator, denominator), denominator > 0 ---- *)

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let fraction n d =
  if d = 0 then failwith "division by zero";
  let g = max 1 (gcd n d) in
  let s = if d < 0 then -1 else 1 in
  (s * n / g, s * d / g)

let sub (a, b) (c, d) = fraction ((a * d) - (c * b)) (b * d)
let mul (a, b) (c, d) = fraction (a * c) (b * d)
let div (a, b) (c, d) = fraction (a * d) (b * c)
let is_zero (n, _) = n = 0

(* The reduced form of a matrix of fractions, and its pivot columns. *)
let reduce rows =
  let m = Array.map Array.copy rows in
  let height = Array.length m and width = Array.length m.(0) in
  let pivots = ref [] and row = ref 0 in
  for column = 0 to width - 1 do
    if !row < height then begin
      let candidate = ref (-1) in
      for r = height - 1 downto !row do
        if not (is_zero m.(r).(column)) then candidate := r
      done;
      if !candidate >= 0 then begin
        let chosen = m.(!candidate) in
        m.(!candidate) <- m.(!row);
        let pivot = chosen.(column) in
        m.(!row) <- Array.map (fun entry -> div entry pivot) chosen;
        for r = 0 to height - 1 do
          if r <> !row && not (is_zero m.(r).(column)) then begin
            let factor = m.(r).(column) in
            m.(r) <- Array.mapi (fun j entry -> sub entry (mul factor m.(!row).(j))) m.(r)
          end
        done;
        pivots := column :: !pivots;
        incr row
      end
    end
  done;
  (m, List.rev !pivots)

let rank rows = List.length (snd (reduce rows))

(* The defining shape of a reduced row echelon form. *)
let is_reduced rows =
  let leading row =
    let found = ref None in
    Array.iteri (fun j entry -> if !found = None && not (is_zero entry) then found := Some (j, entry)) row;
    !found
  in
  let leads = Array.to_list (Array.map leading rows) in
  let rec ordered last = function
    | [] -> true
    | None :: rest -> List.for_all (fun lead -> lead = None) rest
    | Some (column, entry) :: rest -> column > last && entry = (1, 1) && ordered column rest
  in
  ordered (-1) leads
  && List.for_all
       (function
         | None -> true
         | Some (column, _) -> Array.fold_left (fun count row -> if is_zero row.(column) then count else count + 1) 0 rows = 1)
       leads

(* ---- reading the question ---- *)

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

(* The pmatrix of the prompt, as rows of fractions. *)
let matrix prompt =
  ignore (Str.search_forward (Str.regexp "\\\\begin{pmatrix}\\(.*\\)\\\\end{pmatrix}") prompt 0);
  let body = Str.matched_group 1 prompt in
  Str.split (Str.regexp_string "\\\\") body
  |> List.map (fun row -> Array.of_list (List.map (fun n -> (n, 1)) (integers row)))
  |> Array.of_list

let of_number n = (n.Rhema_number.numerator, n.Rhema_number.denominator)

let check (q : Rhema_engine.question) shapes =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
  let a = matrix p in
  let height = Array.length a and width = Array.length a.(0) in
  if Array.exists (fun row -> Array.length row <> width) a then wrong "the matrix is not rectangular";
  if is_reduced a then wrong "the matrix is already reduced";
  match (k, q.Rhema_engine.answer) with
  | "rank", Rhema_engine.Num n ->
      if (height, width) <> (3, 3) then wrong "not a 3 by 3 matrix";
      if of_number n <> (rank a, 1) then wrong (Printf.sprintf "the rank is %d" (rank a));
      Hashtbl.replace shapes (k, string_of_int (rank a)) ()
  | ("rref_small" | "rref_large"), Rhema_engine.Matrix answer ->
      let r = Array.of_list (List.map (fun row -> Array.of_list (List.map of_number row)) (Rhema_matrix.entries answer)) in
      if (height, width) <> (if k = "rref_small" then (2, 3) else (3, 4)) then wrong "the matrix has the wrong shape";
      if Array.length r <> height || Array.length r.(0) <> width then wrong "the answer has another shape";
      if not (is_reduced r) then wrong "the answer is not in reduced row echelon form";
      (* the same row space: stacking one on the other adds no rank *)
      let both = Array.append a r in
      if not (rank a = rank r && rank both = rank a) then wrong "the answer is not row equivalent to the matrix";
      Hashtbl.replace shapes (k, String.concat "," (List.map string_of_int (snd (reduce a)))) ()
  | "null_vector", Rhema_engine.VectorDirectionAnswer (vector, same_direction) ->
      let v = Array.of_list (List.map of_number (Rhema_vector.components vector)) in
      if same_direction then wrong "only one direction is accepted";
      if (height, width) <> (3, 3) || Array.length v <> 3 then wrong "not a 3 by 3 matrix and a vector of three";
      if Array.for_all is_zero v then wrong "the zero vector";
      Array.iter
        (fun row ->
          let image = ref (0, 1) in
          Array.iteri (fun j entry -> image := sub !image (mul (-fst entry, snd entry) v.(j))) row;
          if not (is_zero !image) then wrong "the vector is not sent to zero")
        a;
      if rank a <> 2 then wrong (Printf.sprintf "the rank is %d, so the null space is not a line" (rank a))
  | _ -> wrong "unexpected answer"

let () =
  let base = load_file "row_reduction.rhm" in
  let prices = [ ("rank", 1, "Numeric"); ("rref_small", 2, "Matrix"); ("rref_large", 3, "Matrix"); ("null_vector", 3, "Vector") ] in
  let seen = Hashtbl.create 8 and shapes = Hashtbl.create 8 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q in
          Hashtbl.replace seen k ();
          match List.find_opt (fun (name, _, _) -> name = k) prices with
          | None -> fail ("unknown kind " ^ k)
          | Some (_, price, context) ->
              if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost);
              if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
              if q.Rhema_engine.context <> context then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
              (try check q shapes with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) q.Rhema_engine.prompt)))
    done
  done;
  List.iter (fun (k, _, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  (* both ranks, and every pattern of pivot columns, are asked *)
  List.iter
    (fun shape -> if not (Hashtbl.mem shapes shape) then fail (Printf.sprintf "never asked: %s with %s" (fst shape) (snd shape)))
    [ ("rank", "2"); ("rank", "3"); ("rref_small", "0,1"); ("rref_small", "0,2"); ("rref_large", "0,1");
      ("rref_large", "0,2"); ("rref_large", "0,1,2") ];
  if !failures = 0 then print_endline "Rhema row reduction tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d row reduction test(s) failed." !failures);
    exit 1
  end
