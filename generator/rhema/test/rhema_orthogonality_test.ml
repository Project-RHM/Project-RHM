(* Independent checks for orthogonality.rhm. Every question is matched against
   the whole sentence of its form, the vectors, the plane and the direction
   are read back from it, and the engine's answer is tested, on exact
   fractions, against the properties that define what was asked. The
   projection formula of the grammar is not used to find an answer again:

   - component: the answer c is the number with c |v| = u . v. Without a
     square root: c^2 (v . v) = (u . v)^2, and c has the sign of u . v. The
     vector v has whole length and u . v is not 0.
   - orthogonal_entry: the answer is put in the place of t in the first
     printed vector, and the dot product with the second one is exactly 0.
     t is not 0: the first two entries are not orthogonal on their own.
   - projection: the answer p is parallel to v (their cross product is zero)
     and u - p is orthogonal to v. Only one vector has both properties. p is
     not the zero vector, and u is not parallel to v, where the projection
     would be u itself.
   - orthogonal_part: the answer w is orthogonal to v and u - w is parallel
     to v. w is not zero, and u is not orthogonal to v (w would be u).
   - gram_schmidt: the answer u2 is orthogonal to v1 and v2 - u2 is parallel
     to v1. u2 is not zero, and v1 and v2 are neither parallel nor orthogonal
     already.
   - plane_projection: the normal n is read from the printed equation, which
     must be written the one usual way (no digit for a coefficient 1) and
     have 0 on the right. The answer q is in the plane (n . q = 0) and u - q
     is parallel to n. u is neither in the plane nor along the normal.
   - projection_matrix: the direction v = (a, b) is read; the answer M is a
     2 by 2 matrix with M v = v and M w = 0 for w = (-b, a), which is
     orthogonal to v; also M M = M and M is symmetric. a and b share no
     factor.

   The mistakes are worked out from their descriptions. not_divided on
   component gives the dot product u . v. length_not_squared divides by the
   length |v|, a whole number found as the exact integer square root of
   v . v, where |v|^2 belongs: (u . v / |v|) v for projection,
   u - (u . v / |v|) v for orthogonal_part and u - (u . n / |n|) n for
   plane_projection. The engine must list exactly these mistakes on these
   forms, with these values, each different from the right answer, and none
   on the other forms.

   For every question: the prompt is the text of the question, there is one
   blank and it holds answer_value, the WeBWorK context is "Vector" for a
   vector answer, "Matrix" for projection_matrix and "Numeric" otherwise.
   Each kind appears at its price and at no other, no other kind appears, the
   budget is spent, the grammar's own budget gives a question of price 2, and
   a budget outside 1..3 gives no question.

   The numbers stay in the ranges the grammar says, and every choice it
   offers is seen at least once in every form that has it: a vector of whole
   length is one of three Pythagorean quadruples in a cyclic order, its first
   component positive and the other two of either sign (36 vectors); a
   general vector has components from -4 to 4; the numbers of
   orthogonal_entry are not 0 and go to 5, the last one to 4; the direction
   of a line is one of the 22 pairs (a, b) with a from 1 to 4, b from -4 to
   4 and no common factor. The dot product is seen with either sign, and t
   as positive, negative, whole and a fraction. The weights of the forms
   are not tested. *)

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

(* ---- Exact fractions -------------------------------------------------- *)

(* Fractions on OCaml integers, in lowest terms with a positive denominator,
   so that two equal fractions are equal as records. The numbers of these
   questions are small. *)
type fraction = { top : int; bottom : int }

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let fraction top bottom =
  if bottom = 0 then failwith "division by zero";
  let top, bottom = if bottom < 0 then (-top, -bottom) else (top, bottom) in
  let divisor = gcd top bottom in
  { top = top / divisor; bottom = bottom / divisor }

let whole n = { top = n; bottom = 1 }
let zero = whole 0
let ( +: ) a b = fraction ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( -: ) a b = fraction ((a.top * b.bottom) - (b.top * a.bottom)) (a.bottom * b.bottom)
let ( *: ) a b = fraction (a.top * b.top) (a.bottom * b.bottom)
let sign a = compare a.top 0
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

(* ---- Vectors, as lists of fractions ------------------------------------ *)

let exact = List.map whole
let minus = List.map2 ( -: )
let scale k = List.map (fun x -> k *: x)
let dot a b = List.fold_left ( +: ) zero (List.map2 ( *: ) a b)

let cross a b =
  match (a, b) with
  | [ a1; a2; a3 ], [ b1; b2; b3 ] -> [ (a2 *: b3) -: (a3 *: b2); (a3 *: b1) -: (a1 *: b3); (a1 *: b2) -: (a2 *: b1) ]
  | _ -> failwith "a cross product of vectors that are not in space"

let null = List.for_all (fun x -> x = zero)
let parallel a b = null (cross a b)
let orthogonal a b = dot a b = zero

(* The dot product of two printed vectors, a whole number. *)
let whole_dot a b = List.fold_left ( + ) 0 (List.map2 ( * ) a b)

(* The length of a printed vector when it is a whole number: the integer
   square root of v . v, which must be exact. *)
let whole_length v =
  let squared = whole_dot v v in
  let rec root r = if r * r >= squared then r else root (r + 1) in
  let r = root 0 in
  if r * r = squared then Some r else None

(* ---- The engine's answers ----------------------------------------------- *)

type answer = Number of fraction | Arrow of fraction list | Table of fraction list list

let of_number (n : Rhema_number.t) = fraction n.Rhema_number.numerator n.Rhema_number.denominator

let read = function
  | Rhema_engine.Num n -> Number (of_number n)
  | Rhema_engine.Vector v -> Arrow (List.map of_number (Rhema_vector.components v))
  | Rhema_engine.Matrix m -> Table (List.map (List.map of_number) (Rhema_matrix.entries m))
  | other -> failwith ("neither a number, a vector nor a matrix: " ^ Rhema_engine.describe_value other)

let show_row row = String.concat ", " (List.map show row)

let show_answer = function
  | Number n -> show n
  | Arrow v -> "<" ^ show_row v ^ ">"
  | Table rows -> "[" ^ String.concat "; " (List.map show_row rows) ^ "]"

(* ---- Reading the question ----------------------------------------------- *)

(* The fields of a prompt: the pattern is the whole sentence, with a group
   wherever a number of the question stands. *)
let words = Str.quote
let a_whole = "\\(0\\|-?[1-9][0-9]*\\)"
let in_space = words "\\langle " ^ a_whole ^ ", " ^ a_whole ^ ", " ^ a_whole ^ words " \\rangle"
let how_to_enter = words " Enter it as a vector, such as [`\\langle 1, -2, 3 \\rangle`]; its entries may be fractions."

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* A left side a x + b y + c z as it should be written: no digit for 1 or
   -1, and the sign of the second and the third term as the operation. *)
let plane_text = function
  | [ a; b; c ] ->
      let first = match a with 1 -> "" | -1 -> "-" | a -> string_of_int a in
      let next k name = (if k < 0 then " - " else " + ") ^ (if abs k = 1 then "" else string_of_int (abs k)) ^ name in
      first ^ "x" ^ next b "y" ^ next c "z"
  | _ -> failwith "a plane needs three coefficients"

(* The normal of a plane from the left side of its equation. *)
let normal_of left =
  if not (Str.string_match (Str.regexp "^\\(-?[0-9]*\\)x \\([+-]\\) \\([0-9]*\\)y \\([+-]\\) \\([0-9]*\\)z$") left 0) then
    failwith ("not the left side of a plane: " ^ left);
  let group i = Str.matched_group i left in
  let size = function "" -> 1 | digits -> int_of_string digits in
  let signed sign digits = if sign = "-" then -size digits else size digits in
  let a = match group 1 with "" -> 1 | "-" -> -1 | digits -> int_of_string digits in
  let normal = [ a; signed (group 2) (group 3); signed (group 4) (group 5) ] in
  if plane_text normal <> left then failwith ("a plane written in an unusual way: " ^ left);
  normal

(* ---- What was generated besides the kinds ------------------------------- *)

let noted = Hashtbl.create 256
let note what = Hashtbl.replace noted what ()
let show_whole v = String.concat ", " (List.map string_of_int v)

(* The quadruples a^2 + b^2 + c^2 = d^2 the grammar takes its vectors of
   whole length from, each as the sizes of its components in rising order. *)
let quadruples = [ [ 1; 2; 2 ]; [ 2; 3; 6 ]; [ 4; 4; 7 ] ]

(* The right answer is tested here by what defines it. The result is the
   WeBWorK context the form needs and the answer of each mistake the form is
   open to, worked out from the printed question. *)
let check (q : Rhema_engine.question) got =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what (show_answer got) p) in
  let number () = match got with Number n -> n | _ -> failwith "the answer is not a number" in
  let arrow () = match got with Arrow ([ _; _; _ ] as v) -> v | _ -> failwith "the answer is not a vector of space" in
  let numbers = List.map int_of_string in
  (* A vector with whole components from -4 to 4, not all zero. *)
  let general name v =
    if List.exists (fun x -> abs x > 4) v then wrong ("a component beyond 4 in " ^ show_whole v);
    if List.for_all (fun x -> x = 0) v then wrong "the zero vector is given";
    List.iteri (fun i x -> note (Printf.sprintf "%s: component %d of %s is %d" k (i + 1) name x)) v
  in
  (* Which side of the other vector the first one is on. *)
  let side product = note (Printf.sprintf "%s: the dot product is %s" k (if product > 0 then "positive" else "negative")) in
  (* A vector of whole length, with that length. *)
  let of_whole_length v =
    match whole_length v with
    | None -> failwith ("the length of " ^ show_whole v ^ " is not a whole number")
    | Some length ->
        if List.hd v <= 0 then wrong ("the first component of " ^ show_whole v ^ " is not positive");
        if not (List.mem (List.sort compare (List.map abs v)) quadruples) then
          wrong (show_whole v ^ " is not one of the grammar's quadruples");
        note (k ^ ": whole length " ^ show_whole v);
        length
  in
  match k with
  | "component" -> (
      match
        fields 6
          (words "Find the component (the scalar projection) of [`\\mathbf{u} = " ^ in_space
         ^ words "`] along [`\\mathbf{v} = " ^ in_space ^ words "`].")
          p
      with
      | [ u1; u2; u3; v1; v2; v3 ] ->
          let u = numbers [ u1; u2; u3 ] and v = numbers [ v1; v2; v3 ] and c = number () in
          general "u" u;
          let length = of_whole_length v in
          let product = whole_dot u v in
          if product = 0 then wrong "u is orthogonal to v, the component is 0" else side product;
          (* c |v| = u . v, squared, and with the sign told apart *)
          if c *: c *: whole (whole_dot v v) <> whole (product * product) then wrong "c |v| is not u . v";
          if sign c <> compare product 0 then wrong "the component does not have the sign of u . v";
          if c *: whole length <> whole product then wrong "c times the whole length is not u . v";
          ("Numeric", [ ("not_divided", Number (whole product)) ])
      | _ -> failwith "six fields were expected")
  | "orthogonal_entry" -> (
      match
        fields 5
          (words "Find the number [`t`] for which [`\\langle " ^ a_whole ^ ", " ^ a_whole
         ^ words ", t \\rangle`] is orthogonal to [`" ^ in_space ^ words "`].")
          p
      with
      | [ a; b; c; d; e ] ->
          let t = number () in
          let first = [ whole (int_of_string a); whole (int_of_string b); t ] and second = numbers [ c; d; e ] in
          if not (orthogonal first (exact second)) then wrong "with this t the two vectors are not orthogonal";
          if sign t = 0 then wrong "t is 0, the first two entries are orthogonal on their own"
          else note ("orthogonal_entry: t is " ^ if sign t > 0 then "positive" else "negative");
          note ("orthogonal_entry: t is " ^ if t.bottom = 1 then "whole" else "a fraction");
          List.iteri
            (fun i x ->
              let x = int_of_string x in
              let limit = if i = 4 then 4 else 5 in
              if x = 0 || abs x > limit then wrong (Printf.sprintf "the number %d is 0 or beyond %d" x limit);
              note (Printf.sprintf "orthogonal_entry: number %d is %d" (i + 1) x))
            [ a; b; c; d; e ];
          ("Numeric", [])
      | _ -> failwith "five fields were expected")
  | "projection" -> (
      match
        fields 6
          (words "Find the projection of [`\\mathbf{u} = " ^ in_space ^ words "`] onto [`\\mathbf{v} = " ^ in_space
         ^ words "`]." ^ how_to_enter)
          p
      with
      | [ u1; u2; u3; v1; v2; v3 ] ->
          let u = numbers [ u1; u2; u3 ] and v = numbers [ v1; v2; v3 ] and projection = arrow () in
          general "u" u;
          let length = of_whole_length v in
          if null projection then wrong "the projection is the zero vector" else side (whole_dot u v);
          if not (parallel projection (exact v)) then wrong "the answer is not parallel to v";
          if not (orthogonal (minus (exact u) projection) (exact v)) then wrong "u less the answer is not orthogonal to v";
          if parallel (exact u) (exact v) then wrong "u is parallel to v, the projection is u itself";
          ("Vector", [ ("length_not_squared", Arrow (scale (fraction (whole_dot u v) length) (exact v))) ])
      | _ -> failwith "six fields were expected")
  | "orthogonal_part" -> (
      match
        fields 6
          (words "The vector [`\\mathbf{u} = " ^ in_space
         ^ words "`] is written as [`\\mathbf{p} + \\mathbf{w}`], with [`\\mathbf{p}`] parallel to [`\\mathbf{v} = "
         ^ in_space
         ^ words "`] and [`\\mathbf{w}`] orthogonal to it. Find [`\\mathbf{w}`]."
         ^ how_to_enter)
          p
      with
      | [ u1; u2; u3; v1; v2; v3 ] ->
          let u = numbers [ u1; u2; u3 ] and v = numbers [ v1; v2; v3 ] and part = arrow () in
          general "u" u;
          let length = of_whole_length v in
          if null part then wrong "w is the zero vector, u is along v";
          if whole_dot u v = 0 then wrong "u is orthogonal to v, w is u itself" else side (whole_dot u v);
          if not (orthogonal part (exact v)) then wrong "the answer is not orthogonal to v";
          if not (parallel (minus (exact u) part) (exact v)) then wrong "u less the answer is not parallel to v";
          ( "Vector",
            [ ("length_not_squared", Arrow (minus (exact u) (scale (fraction (whole_dot u v) length) (exact v)))) ] )
      | _ -> failwith "six fields were expected")
  | "gram_schmidt" -> (
      match
        fields 6
          (words "The Gram-Schmidt process is applied to [`\\mathbf{v}_1 = " ^ in_space
         ^ words "`] and [`\\mathbf{v}_2 = " ^ in_space
         ^ words
             "`], in that order, without making the vectors unit vectors: [`\\mathbf{u}_1 = \\mathbf{v}_1`]. Find \
              [`\\mathbf{u}_2`]."
         ^ how_to_enter)
          p
      with
      | [ a1; a2; a3; b1; b2; b3 ] ->
          let first = numbers [ a1; a2; a3 ] and second = numbers [ b1; b2; b3 ] and u2 = arrow () in
          general "v1" first;
          general "v2" second;
          if parallel (exact first) (exact second) then wrong "v1 and v2 are parallel";
          if whole_dot first second = 0 then wrong "v1 and v2 are orthogonal already" else side (whole_dot first second);
          if null u2 then wrong "u2 is the zero vector";
          if not (orthogonal u2 (exact first)) then wrong "the answer is not orthogonal to v1";
          if not (parallel (minus (exact second) u2) (exact first)) then wrong "v2 less the answer is not parallel to v1";
          ("Vector", [])
      | _ -> failwith "six fields were expected")
  | "plane_projection" -> (
      match
        fields 4
          (words "Find the orthogonal projection of [`\\mathbf{u} = " ^ in_space ^ words "`] onto the plane [`"
         ^ "\\([^`=]*\\)" ^ words " = 0`]." ^ how_to_enter)
          p
      with
      | [ u1; u2; u3; left ] ->
          let u = numbers [ u1; u2; u3 ] and normal = normal_of left and image = arrow () in
          general "u" u;
          let length = of_whole_length normal in
          if whole_dot u normal = 0 then wrong "u is in the plane already" else side (whole_dot u normal);
          if parallel (exact u) (exact normal) then wrong "u is along the normal, its projection is the origin";
          if not (orthogonal image (exact normal)) then wrong "the answer is not in the plane";
          if not (parallel (minus (exact u) image) (exact normal)) then wrong "u less the answer is not along the normal";
          ( "Vector",
            [ ( "length_not_squared",
                Arrow (minus (exact u) (scale (fraction (whole_dot u normal) length) (exact normal))) ) ] )
      | _ -> failwith "four fields were expected")
  | "projection_matrix" -> (
      match
        fields 2
          (words
             "Find the matrix of the orthogonal projection of the [`xy`]-plane onto its line through the origin in \
              the direction of [`\\langle "
         ^ a_whole ^ ", " ^ a_whole
         ^ words " \\rangle`]. Its entries may be fractions.")
          p
      with
      | [ a; b ] -> (
          let a = int_of_string a and b = int_of_string b in
          if a < 1 || a > 4 || b = 0 || abs b > 4 then wrong "a direction outside the grammar's range";
          if gcd a b <> 1 then wrong "the two components of the direction share a factor";
          note (Printf.sprintf "direction: %d, %d" a b);
          match got with
          | Table [ [ m11; m12 ]; [ m21; m22 ] ] ->
              let apply x y = [ (m11 *: x) +: (m12 *: y); (m21 *: x) +: (m22 *: y) ] in
              let along = exact [ a; b ] and across = exact [ -b; a ] in
              if apply (whole a) (whole b) <> along then wrong "the matrix moves the direction of the line";
              if not (null (apply (whole (-b)) (whole a))) then wrong "the matrix does not send the orthogonal direction to 0";
              let column1 = apply m11 m21 and column2 = apply m12 m22 in
              if column1 <> [ m11; m21 ] || column2 <> [ m12; m22 ] then wrong "the matrix applied twice is not the matrix";
              if m12 <> m21 then wrong "the matrix is not symmetric";
              if not (orthogonal along across) then failwith "the test's own orthogonal direction is not orthogonal";
              ("Matrix", [])
          | _ -> failwith "the answer is not a 2 by 2 matrix")
      | _ -> failwith "two fields were expected")
  | k -> failwith ("unknown kind " ^ k)

(* The words a mistake's description must hold. *)
let described = [ ("not_divided", "does not divide by the length"); ("length_not_squared", "square of the length") ]

let () =
  let base = load_file "orthogonality.rhm" in
  let prices =
    [ ("component", 1); ("orthogonal_entry", 1); ("projection", 2); ("orthogonal_part", 2); ("gram_schmidt", 3);
      ("plane_projection", 3); ("projection_matrix", 3) ]
  in
  let seen = Hashtbl.create 8 and made = Hashtbl.create 8 and generated = Hashtbl.create 4 in
  let one spec cost seed =
    Random.init (seed + (100000 * cost));
    match Rhema_engine.generate spec with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
    | q -> (
        let k = kind q and p = q.Rhema_engine.prompt in
        Hashtbl.replace seen k ();
        Hashtbl.replace generated cost (1 + Option.value ~default:0 (Hashtbl.find_opt generated cost));
        if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
        if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
        (match Rhema_engine.attribute q.Rhema_engine.tree "text" with
        | Rhema_engine.Text t when t = p -> ()
        | _ -> fail (Printf.sprintf "%s: the prompt is not the text of the question, for %S" k p));
        match q.Rhema_engine.answers with
        | [ only ] -> (
            match
              let got = read only in
              (got, check q got)
            with
            | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
            | got, (context, slips) ->
                (match read q.Rhema_engine.answer with
                | first when first = got -> ()
                | _ | (exception Failure _) -> fail (Printf.sprintf "%s: the answer is not the answer of the blank, for %S" k p));
                (match Rhema_engine.attribute q.Rhema_engine.tree "answer_value" with
                | value when (try read value = got with Failure _ -> false) -> ()
                | _ -> fail (Printf.sprintf "%s: the blank does not hold answer_value, for %S" k p));
                (match Rhema_engine.attribute q.Rhema_engine.tree "pg_context" with
                | Rhema_engine.Text c when c = context -> ()
                | Rhema_engine.Text c -> fail (Printf.sprintf "%s: pg_context is %s, not %s" k c context)
                | _ -> fail (k ^ ": pg_context is not a text"));
                if q.Rhema_engine.context <> context then
                  fail (Printf.sprintf "%s: the question is in context %s, not %s" k q.Rhema_engine.context context);
                List.iter
                  (fun (name, slip) ->
                    if slip = got then
                      fail (Printf.sprintf "%s: %s gives the right answer %s, for %S" k name (show_answer got) p))
                  slips;
                let listed = q.Rhema_engine.mistakes in
                let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
                if names <> List.map fst slips then
                  fail
                    (Printf.sprintf "%s: the mistakes listed are [%s], not [%s], for %S" k (String.concat ", " names)
                       (String.concat ", " (List.map fst slips))
                       p);
                List.iter
                  (fun (m : Rhema_engine.mistaken) ->
                    Hashtbl.replace made (m.mistake ^ " on " ^ k) ();
                    (match List.assoc_opt m.mistake described with
                    | None -> fail ("a mistake the grammar does not declare in its header: " ^ m.mistake)
                    | Some phrase -> (
                        match Str.search_forward (Str.regexp_string phrase) m.description 0 with
                        | _ -> ()
                        | exception Not_found ->
                            fail (Printf.sprintf "%s is described without %S: %S" m.mistake phrase m.description)));
                    match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                    | Some [ value ], Some slip -> (
                        match read value with
                        | exception Failure message -> fail (Printf.sprintf "%s: %s gives %s, for %S" k m.mistake message p)
                        | mistaken ->
                            if mistaken <> slip then
                              fail
                                (Printf.sprintf "%s: %s gives %s, worked out %s, for %S" k m.mistake (show_answer mistaken)
                                   (show_answer slip) p);
                            if mistaken = got then
                              fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p))
                    | _, None -> ()
                    | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                  listed)
        | answers -> fail (Printf.sprintf "%s: %d blanks, one was expected, for %S" k (List.length answers) p))
  in
  (* A vector along the one it is projected onto, or along the normal of the
     plane, is drawn about once in 550 questions of a form, so the run is
     long enough to meet that case many times and to see that the grammar
     turns it away where it must. *)
  let per_budget = 6000 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to per_budget - 1 do
      one spec cost seed
    done
  done;
  for cost = 1 to 3 do
    let count = Option.value ~default:0 (Hashtbl.find_opt generated cost) in
    if count < per_budget then fail (Printf.sprintf "only %d questions at cost %d" count cost)
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k () -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  List.iter
    (fun what -> if not (Hashtbl.mem made what) then fail ("never listed: " ^ what))
    [ "not_divided on component"; "length_not_squared on projection"; "length_not_squared on orthogonal_part";
      "length_not_squared on plane_projection" ];
  (* Every choice the grammar offers is taken at least once, in every form
     that has it. A vector of whole length is one of the three cyclic orders
     of a quadruple as the grammar writes it (the sizes rising), with the two
     last components of either sign. For 2, 3, 6 the other three orders of
     the sizes are never made. *)
  let whole_vectors =
    List.concat_map
      (function
        | [ a; b; c ] ->
            List.concat_map
              (function
                | [ x; y; z ] -> [ [ x; y; z ]; [ x; -y; z ]; [ x; y; -z ]; [ x; -y; -z ] ]
                | _ -> [])
              [ [ a; b; c ]; [ b; c; a ]; [ c; a; b ] ]
        | _ -> [])
      quadruples
  in
  if List.length (List.sort_uniq compare whole_vectors) <> 36 then
    fail "the test's own list of vectors of whole length does not hold 36 vectors";
  let with_whole_length = [ "component"; "projection"; "orthogonal_part"; "plane_projection" ] in
  let general_vectors =
    [ ("component", "u"); ("projection", "u"); ("orthogonal_part", "u"); ("plane_projection", "u"); ("gram_schmidt", "v1");
      ("gram_schmidt", "v2") ]
  in
  let choices =
    List.concat_map (fun k -> List.map (fun v -> k ^ ": whole length " ^ show_whole v) whole_vectors) with_whole_length
    @ List.concat_map
        (fun (k, name) ->
          List.concat_map
            (fun place -> List.init 9 (fun x -> Printf.sprintf "%s: component %d of %s is %d" k place name (x - 4)))
            [ 1; 2; 3 ])
        general_vectors
    @ List.concat_map
        (fun k -> [ k ^ ": the dot product is positive"; k ^ ": the dot product is negative" ])
        ("gram_schmidt" :: with_whole_length)
    @ List.concat_map
        (fun place ->
          let limit = if place = 5 then 4 else 5 in
          List.concat
            (List.init limit (fun x ->
                 [ Printf.sprintf "orthogonal_entry: number %d is %d" place (x + 1);
                   Printf.sprintf "orthogonal_entry: number %d is %d" place (-(x + 1)) ])))
        [ 1; 2; 3; 4; 5 ]
    @ List.map (fun what -> "orthogonal_entry: t is " ^ what) [ "positive"; "negative"; "whole"; "a fraction" ]
    @ List.concat_map
        (fun a ->
          List.filter_map
            (fun b -> if b <> 0 && gcd a b = 1 then Some (Printf.sprintf "direction: %d, %d" a b) else None)
            [ -4; -3; -2; -1; 1; 2; 3; 4 ])
        [ 1; 2; 3; 4 ]
  in
  List.iter (fun what -> if not (Hashtbl.mem noted what) then fail ("never generated: " ^ what)) choices;
  (* Nothing else of these sorts was generated: no other vector of whole
     length, for one. *)
  Hashtbl.iter
    (fun what () -> if not (List.mem what choices) then fail ("not a choice of the grammar: " ^ what))
    noted;
  (* The grammar as it is written, with the budget it sets itself, gives a
     question of price 2. *)
  for seed = 0 to 19 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 || Rhema_engine.consumption q.Rhema_engine.tree "cost" <> 2 then
          fail (Printf.sprintf "the grammar's own budget gave a question that is not of price 2: %s" (kind q))
  done;
  (* A budget that no form is priced at gives no question. *)
  List.iter
    (fun cost ->
      for seed = 0 to 19 do
        Random.init seed;
        match Rhema_engine.generate (with_initial base "cost" cost) with
        | exception Rhema_engine.Generation_error _ -> ()
        | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
      done)
    [ 0; 4; 5; 6 ];
  if !failures = 0 then print_endline "Rhema orthogonality tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d orthogonality test(s) failed." !failures);
    exit 1
  end
