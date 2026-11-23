(* Independent checks for linear_transformations.rhm. Every question is
   matched against the whole sentence of its form, the vectors and the
   matrices are read back from it, and the answer is found again on exact
   fractions from what the question says, never by the product, the inverse
   or the determinant the grammar itself calls for:

   image               the two printed coordinates a x + b y are read, each
                       must be written the one usual way (no digit for a
                       coefficient 1, the sign of the second term as the
                       operation), and the printed vector is put in for x
                       and y.
   standard_matrix     the answer, applied to (1, 0) and to (0, 1), must
                       give the two printed images. It is also the one
                       matrix with whole entries up to 5 that does so, found
                       by trying every row.
   composition         both printed matrices are applied one after the
                       other, T first and then S, to the two standard basis
                       vectors and to three other vectors, and the answer,
                       applied to the same vectors, must give the same.
   area                the corners of the unit square are transformed, the
                       area of the parallelogram they make is found by the
                       shoelace formula and multiplied by the printed area.
                       The parallelogram is not flat. Both orientations come
                       up, so the area is not simply the signed one.
   kernel_dimension,   the rank is found by the test's own elimination on
   image_dimension     exact fractions, and the dimension of the kernel by
                       showing the kernel: where two rows are independent it
                       lies in the line of their cross product, and that
                       vector is sent to zero or not; where all rows are
                       along one of them it is the plane orthogonal to that
                       row, and two independent vectors of the plane are
                       shown to be sent to zero while the row itself is not.
                       The two numbers must add up to 3 in every question,
                       whichever of them is asked for. The third row is a
                       combination of the first two with coefficients from
                       -2 to 2 (searched for), no row is all 0, and the
                       dimension is 1 or 2, each of them often: neither
                       answer can be given without looking at the matrix.
   preimage            every vector with whole entries up to 12 is put
                       through the printed matrix; exactly one gives the
                       printed image, and it is the answer. The answer must
                       also give that image by the test's own product, the
                       corners of the unit square must not be sent to a flat
                       parallelogram (so no other vector has this image),
                       and the image is not the vector itself.
   matrix_from_images  the answer, applied to each of the two printed
                       vectors, must give its printed image, and the two
                       vectors are independent, so only one matrix does
                       that. It is found a second time by trying every row
                       with whole entries up to 4. The answer is not
                       singular.
   new_basis           the answer B must be what the definition says: for
                       each vector b_j of the new basis, A b_j is the
                       combination of b_1 and b_2 with the coefficients in
                       column j of B. b_1 and b_2 are independent, so only
                       one matrix does that. It is not A itself, and its
                       entries are whole and within 30.
   reflection          the answer R must leave the printed direction d where
                       it is, send n, a vector orthogonal to d, to -n, and
                       give every vector back when applied twice. The two
                       entries of d share no factor.

   The mistakes are worked out from their descriptions. images_as_rows on
   standard_matrix is the matrix whose rows are the two printed images.
   order_swapped on composition is the matrix of S first and then T, its
   columns found by applying the two printed matrices in that order to
   (1, 0) and (0, 1). basis_wrong_way on new_basis is P A P^(-1), with P the
   matrix whose columns are b_1 and b_2 and the inverse found by the test's
   own elimination (and checked: P after it and it after P leave the basis
   vectors alone). The engine must list exactly these mistakes on these
   forms, with these values and these descriptions, each different from the
   right answer, and none on the other forms. So the matrix of
   standard_matrix is not symmetric, the two matrices of composition do not
   commute, and the matrix of new_basis commutes neither with P nor with the
   square of P.

   For every question: the prompt is the text of the question, there is one
   blank and it holds answer_value, the WeBWorK context is "Numeric" for a
   number, "Vector" for a vector and "Matrix" for a matrix. Each kind appears
   at its price and at no other, no other kind appears, the budget is spent,
   the grammar's own budget gives a question of price 2, and a budget outside
   1..3 gives no question.

   The numbers stay in the ranges the grammar says, and every choice it
   offers is seen at least once in every form that has it: a coefficient or
   an entry of a matrix of the plane is not 0 and goes to 4, the components
   of the vector of image and of the answer of preimage are not 0 and go to
   5, the numbers of standard_matrix go to 5 and may be 0, the area goes
   from 1 to 6, the entries of the first two rows of a matrix of space go to
   3 (or the second row is the first one times 2 or -2 and goes to 6) and
   the two coefficients of the third row to 2, the entries of the matrix of
   matrix_from_images go to 4 and may be 0, and the direction of a
   reflection is one of the 22 pairs (a, b) with a from 1 to 4, b from -4 to
   4 and not 0, and no common factor. The two vectors of matrix_from_images
   and of a new basis, and the columns of the matrix of preimage, are (1, p)
   and (q, p q + 1) with p and q from -3 to 3, not 0, and p q not -1: 34
   pairs, of determinant 1 and without a 0. A new basis is never one of the
   four with p q = -2, where P P = -I and the mistake would give the right
   matrix. Both ranks come up for either dimension asked, rank 1 in at least
   a tenth of the questions, and the two entries off the diagonal of the
   matrix in a new basis reach 30 in size (those on it stay below), while
   the mistaken matrix goes beyond 30 in every entry: the limit is on the
   right one alone. No two numbers of a form are tied to each other: each
   two entries of a matrix, coefficients or components are seen both equal
   and different (the two entries off the diagonal of standard_matrix only
   different), and the first two rows of a matrix of space have their zeros
   in any places but all three. The weights of the forms are not tested. *)

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
let one = whole 1
let ( +: ) a b = fraction ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( -: ) a b = fraction ((a.top * b.bottom) - (b.top * a.bottom)) (a.bottom * b.bottom)
let ( *: ) a b = fraction (a.top * b.top) (a.bottom * b.bottom)
let ( /: ) a b = fraction (a.top * b.bottom) (a.bottom * b.top)
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

(* ---- Vectors and matrices ---------------------------------------------- *)

(* A vector is a list of fractions and a matrix the list of its rows. A
   matrix is only ever used through what it does to a vector. *)
let exact = List.map whole
let plus = List.map2 ( +: )
let minus = List.map2 ( -: )
let scale k = List.map (fun x -> k *: x)
let dot a b = List.fold_left ( +: ) zero (List.map2 ( *: ) a b)
let null = List.for_all (fun x -> x = zero)
let apply matrix v = List.map (fun row -> dot row v) matrix

(* The standard basis of the plane or of space. *)
let basis size = List.init size (fun i -> List.init size (fun j -> if i = j then one else zero))

let columns rows =
  match rows with
  | [] -> []
  | first :: _ -> List.mapi (fun place _ -> List.map (fun row -> List.nth row place) rows) first

(* The matrix of a linear map: its columns are the images of the standard
   basis vectors. *)
let matrix_of size map = columns (List.map map (basis size))

(* The plane only: whether two vectors are independent. *)
let independent a b =
  match (a, b) with
  | [ a1; a2 ], [ b1; b2 ] -> (a1 *: b2) -: (a2 *: b1) <> zero
  | _ -> failwith "two vectors of the plane were expected"

(* Twice the signed area of the image of the unit square, by the shoelace
   formula on its four corners in order. *)
let shoelace matrix =
  let corners = List.map (apply matrix) (List.map exact [ [ 0; 0 ]; [ 1; 0 ]; [ 1; 1 ]; [ 0; 1 ] ]) in
  let next = List.tl corners @ [ List.hd corners ] in
  List.fold_left2
    (fun total here there ->
      match (here, there) with
      | [ x1; y1 ], [ x2; y2 ] -> total +: ((x1 *: y2) -: (x2 *: y1))
      | _ -> failwith "a corner that is not in the plane")
    zero corners next

(* Elimination. The rows are brought to reduced echelon form by exact row
   operations, with pivots looked for in the first `limit` columns only. The
   result is the rows that got a pivot, in the order of their columns; there
   are as many of them as the rank of those columns. *)
let reduce limit rows =
  let rec go with_pivot rest column =
    if column >= limit || rest = [] then List.rev with_pivot
    else
      match List.partition (fun row -> List.nth row column <> zero) rest with
      | [], _ -> go with_pivot rest (column + 1)
      | chosen :: others, without ->
          let pivot = scale (one /: List.nth chosen column) chosen in
          let clear row = minus row (scale (List.nth row column) pivot) in
          go (pivot :: List.map clear with_pivot) (List.map clear others @ without) (column + 1)
  in
  go [] rows 0

let rank rows = match rows with [] -> 0 | first :: _ -> List.length (reduce (List.length first) rows)

(* The inverse of a square matrix: the matrix is written next to the
   identity and reduced; the identity is then on the left and the inverse on
   the right. The result is tested on the standard basis before it is used. *)
let inverse rows =
  let size = List.length rows in
  let reduced = reduce size (List.map2 ( @ ) rows (basis size)) in
  if List.length reduced <> size then failwith "the test's own inverse: the matrix is singular";
  let right = List.map (fun row -> List.filteri (fun place _ -> place >= size) row) reduced in
  List.iter
    (fun e ->
      if apply rows (apply right e) <> e || apply right (apply rows e) <> e then
        failwith "the test's own inverse is not an inverse")
    (basis size);
  right

let cross a b =
  match (a, b) with
  | [ a1; a2; a3 ], [ b1; b2; b3 ] -> [ (a2 *: b3) -: (a3 *: b2); (a3 *: b1) -: (a1 *: b3); (a1 *: b2) -: (a2 *: b1) ]
  | _ -> failwith "a cross product of vectors that are not in space"

(* The dimension of the kernel of a matrix of space, by showing the kernel.
   A vector of the kernel is orthogonal to every row. Where two rows are
   independent, such a vector is along their cross product k, so the kernel
   is the line of k if the matrix sends k to zero and only the zero vector
   if not. Where no two rows are independent and one row r is not zero,
   every row is a multiple of r and the kernel is the plane orthogonal to
   r: two independent vectors of that plane are shown, both sent to zero,
   while r itself is not. *)
let kernel_dimension rows =
  let pairs = List.concat_map (fun a -> List.map (fun b -> cross a b) rows) rows in
  match List.filter (fun k -> not (null k)) pairs with
  | k :: _ -> if null (apply rows k) then 1 else 0
  | [] -> (
      match List.filter (fun row -> not (null row)) rows with
      | [] -> 3
      | r :: _ -> (
          if null (apply rows r) then failwith "the test's own kernel: a row is orthogonal to itself";
          let across = List.filter (fun v -> not (null v)) (List.map (cross r) (basis 3)) in
          let both = List.concat_map (fun a -> List.filter (fun b -> not (null (cross a b))) across) across in
          match both with
          | [] -> failwith "the test's own kernel: no two independent vectors orthogonal to the row"
          | _ ->
              if List.exists (fun v -> not (null (apply rows v))) across then
                failwith "the test's own kernel: a vector orthogonal to the row is not sent to zero";
              2))

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
let in_plane = words "\\langle " ^ a_whole ^ ", " ^ a_whole ^ words " \\rangle"

(* A printed matrix: the rows apart by a double backslash, the entries of a
   row by an ampersand. *)
let table rows across =
  let row = String.concat " & " (List.init across (fun _ -> a_whole)) in
  words "\\begin{pmatrix} " ^ String.concat (words " \\\\ ") (List.init rows (fun _ -> row)) ^ words " \\end{pmatrix}"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

(* One coordinate of an image, a x + b y, as it should be written: no digit
   for 1 or -1, and the sign of the second term as the operation. *)
let a_coordinate = "\\([-+0-9xy ]*\\)"

let coordinate_text (a, b) =
  let first = match a with 1 -> "" | -1 -> "-" | a -> string_of_int a in
  first ^ "x" ^ (if b < 0 then " - " else " + ") ^ (if abs b = 1 then "" else string_of_int (abs b)) ^ "y"

let coordinate_of text =
  if not (Str.string_match (Str.regexp "^\\(-?[0-9]*\\)x \\([+-]\\) \\([0-9]*\\)y$") text 0) then
    failwith ("not a coordinate a x + b y: " ^ text);
  let group i = Str.matched_group i text in
  let a = match group 1 with "" -> 1 | "-" -> -1 | digits -> int_of_string digits in
  let size = match group 3 with "" -> 1 | digits -> int_of_string digits in
  let b = if group 2 = "-" then -size else size in
  if coordinate_text (a, b) <> text then failwith ("a coordinate written in an unusual way: " ^ text);
  (a, b)

(* ---- What was generated besides the kinds ------------------------------- *)

let noted = Hashtbl.create 1024
let note what = Hashtbl.replace noted what ()

(* How often something was generated. *)
let tallies = Hashtbl.create 16
let tally what = Hashtbl.replace tallies what (1 + Option.value ~default:0 (Hashtbl.find_opt tallies what))
let tallied what = Option.value ~default:0 (Hashtbl.find_opt tallies what)

let between first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)

(* What is noted of the numbers of a form: number `place` of the sort `name`
   has this value. *)
let number_text k name place value = Printf.sprintf "%s: %s %d is %d" k name place value

(* And of two of them: they are the same number, or they are not. No two
   numbers of a form are tied to each other unless the grammar says so. *)
let pair_text k name first second same =
  Printf.sprintf "%s: %s %d and %d %s" k name first second (if same then "are equal" else "differ")
let basis_text k p q = Printf.sprintf "%s: the basis with p = %d, q = %d" k p q

(* The 34 pairs (p, q) a matrix of determinant 1 is made of. *)
let unit_pairs =
  List.concat_map
    (fun p -> List.filter_map (fun q -> if p <> 0 && q <> 0 && p * q <> -1 then Some (p, q) else None) (between (-3) 3))
    (between (-3) 3)

(* The right answer is tested here by what defines it. The result is the
   WeBWorK context the form needs and the answer of each mistake the form is
   open to, worked out from the printed question. *)
let check (q : Rhema_engine.question) got =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what (show_answer got) p) in
  let number () = match got with Number n -> n | _ -> failwith "the answer is not a number" in
  let arrow () = match got with Arrow ([ _; _ ] as v) -> v | _ -> failwith "the answer is not a vector of the plane" in
  let square () =
    match got with Table ([ [ _; _ ]; [ _; _ ] ] as rows) -> rows | _ -> failwith "the answer is not a 2 by 2 matrix"
  in
  let numbers = List.map int_of_string in
  (* Numbers of the question that go from -limit to limit, without 0 unless
     it is allowed. *)
  let ranged ?(with_zero = false) limit name values =
    List.iteri
      (fun place x ->
        if abs x > limit || (x = 0 && not with_zero) then
          wrong (Printf.sprintf "%s %d is %d, outside the grammar's range" name (place + 1) x);
        note (number_text k name (place + 1) x);
        List.iteri (fun other y -> if other > place then note (pair_text k name (place + 1) (other + 1) (x = y))) values)
      values
  in
  (* Two vectors (1, p) and (q, p q + 1): the columns of a matrix of
     determinant 1 with no 0 in it. *)
  let unit_columns first second =
    match (first, second) with
    | [ 1; p ], [ q; r ] ->
        if not (List.mem (p, q) unit_pairs) then
          wrong (Printf.sprintf "p = %d and q = %d are not a choice of the grammar" p q);
        if r <> (p * q) + 1 then wrong "the two vectors are not (1, p) and (q, p q + 1)";
        if r = 0 then wrong "a 0 among the two vectors";
        if shoelace (columns [ exact first; exact second ]) <> whole 2 then
          wrong "the two vectors do not make a matrix of determinant 1";
        note (basis_text k p q)
    | _ -> wrong "the first vector does not begin with 1"
  in
  (* The rows a b with whole entries up to `limit` that give the number
     `left` with the vector u and `right` with the vector v. *)
  let rows_for limit u v left right =
    let sizes = between (-limit) limit in
    let candidates = List.concat_map (fun a -> List.map (fun b -> [ a; b ]) sizes) sizes in
    List.filter (fun row -> dot (exact row) (exact u) = whole left && dot (exact row) (exact v) = whole right) candidates
  in
  (* The one matrix with whole entries up to `limit` that sends u to its
     image and v to its image, found by trying every row. *)
  let found_by_rows limit u u_image v v_image =
    match (u_image, v_image) with
    | [ u1; u2 ], [ v1; v2 ] -> (
        match (rows_for limit u v u1 v1, rows_for limit u v u2 v2) with
        | [ upper ], [ lower ] ->
            if got <> Table [ exact upper; exact lower ] then wrong "trying every row gives another matrix"
        | _ -> wrong "trying every row does not give one matrix")
    | _ -> failwith "two images in the plane were expected"
  in
  match k with
  | "image" -> (
      match
        fields 4
          (words "The linear transformation [`T`] of the plane sends [`\\langle x, y \\rangle`] to [`\\langle "
         ^ a_coordinate ^ words ", \\; " ^ a_coordinate
         ^ words " \\rangle`]. Find the image of [`" ^ in_plane ^ words "`] under [`T`].")
          p
      with
      | [ first; second; x; y ] ->
          let a, b = coordinate_of first and c, d = coordinate_of second in
          let x = int_of_string x and y = int_of_string y in
          ranged 4 "coefficient" [ a; b; c; d ];
          ranged 5 "component" [ x; y ];
          if got <> Arrow (exact [ (a * x) + (b * y); (c * x) + (d * y) ]) then
            wrong "putting the vector in for x and y gives another image";
          ("Vector", [])
      | _ -> failwith "four fields were expected")
  | "standard_matrix" -> (
      match
        fields 4
          (words "A linear transformation [`T`] of the plane sends [`\\langle 1, 0 \\rangle`] to [`" ^ in_plane
         ^ words "`] and [`\\langle 0, 1 \\rangle`] to [`" ^ in_plane
         ^ words "`]. Find the matrix [`A`] with [`T(v) = Av`] for every vector [`v`].")
          p
      with
      | [ a; c; b; d ] ->
          let first = numbers [ a; c ] and second = numbers [ b; d ] and matrix = square () in
          ranged ~with_zero:true 5 "number" (first @ second);
          if apply matrix (exact [ 1; 0 ]) <> exact first then wrong "the matrix does not send (1, 0) to its image";
          if apply matrix (exact [ 0; 1 ]) <> exact second then wrong "the matrix does not send (0, 1) to its image";
          found_by_rows 5 [ 1; 0 ] first [ 0; 1 ] second;
          ("Matrix", [ ("images_as_rows", Table [ exact first; exact second ]) ])
      | _ -> failwith "four fields were expected")
  | "composition" -> (
      match
        fields 8
          (words "The linear transformations [`S`] and [`T`] of the plane have the matrices [`A_S = " ^ table 2 2
         ^ words "`] and [`A_T = " ^ table 2 2
         ^ words "`]. Find the matrix of the transformation that applies [`T`] first and then [`S`].")
          p
      with
      | [ s1; s2; s3; s4; t1; t2; t3; t4 ] ->
          let s_entries = numbers [ s1; s2; s3; s4 ] and t_entries = numbers [ t1; t2; t3; t4 ] in
          ranged 4 "entry of S" s_entries;
          ranged 4 "entry of T" t_entries;
          let s = [ exact (numbers [ s1; s2 ]); exact (numbers [ s3; s4 ]) ] in
          let t = [ exact (numbers [ t1; t2 ]); exact (numbers [ t3; t4 ]) ] in
          let matrix = square () in
          List.iter
            (fun v ->
              if apply matrix v <> apply s (apply t v) then wrong ("the matrix is not T and then S on " ^ show_row v))
            (basis 2 @ List.map exact [ [ 1; 1 ]; [ 2; -3 ]; [ -5; 7 ] ]);
          ("Matrix", [ ("order_swapped", Table (matrix_of 2 (fun v -> apply t (apply s v)))) ])
      | _ -> failwith "eight fields were expected")
  | "area" -> (
      match
        fields 5
          (words "A linear transformation of the plane has the matrix [`" ^ table 2 2
         ^ words "`]. A region of area [`" ^ "\\([1-9][0-9]*\\)"
         ^ words "`] is transformed by it. Find the area of its image.")
          p
      with
      | [ a; b; c; d; area ] ->
          let area = int_of_string area in
          ranged 4 "entry" (numbers [ a; b; c; d ]);
          if area > 6 then wrong "an area beyond 6";
          note (Printf.sprintf "area: the area is %d" area);
          let twice = shoelace [ exact (numbers [ a; b ]); exact (numbers [ c; d ]) ] in
          if twice = zero then wrong "the image of the unit square is flat"
          else note ("area: the orientation is " ^ if twice.top > 0 then "kept" else "reversed");
          let size = fraction (abs twice.top) (2 * twice.bottom) in
          if number () <> whole area *: size then
            wrong ("the shoelace formula gives the unit square the area " ^ show size);
          ("Numeric", [])
      | _ -> failwith "five fields were expected")
  | "kernel_dimension" | "image_dimension" -> (
      let asked =
        if k = "kernel_dimension" then "kernel, the set of vectors that [`T`] sends to the zero vector."
        else "image, the set of all vectors [`T(v)`]."
      in
      match
        fields 9
          (words "A linear transformation [`T`] of space has the matrix [`" ^ table 3 3
         ^ words ("`]. Find the dimension of its " ^ asked))
          p
      with
      | [ a1; a2; a3; b1; b2; b3; c1; c2; c3 ] ->
          let upper = numbers [ a1; a2; a3 ] and middle = numbers [ b1; b2; b3 ] and lower = numbers [ c1; c2; c3 ] in
          ranged ~with_zero:true 3 "entry of the first row" upper;
          (* the second row is drawn like the first, or it is a multiple of
             the first, as far as twice it with either sign: only then may
             it go beyond 3 *)
          if List.for_all (fun x -> abs x <= 3) middle then ranged ~with_zero:true 3 "entry of the second row" middle
          else begin
            match List.filter (fun m -> List.map (fun x -> m * x) upper = middle) [ 2; -2 ] with
            | [ m ] -> note (Printf.sprintf "%s: the second row is %d times the first" k m)
            | _ -> wrong "the second row goes beyond 3 and is not twice the first row"
          end;
          let rows = List.map exact [ upper; middle; lower ] in
          if List.exists null rows then wrong "a row is all 0";
          (* where the first two rows have their zeros: any places but all three *)
          List.iter
            (fun (name, row) ->
              let places = String.concat "" (List.map (fun x -> if x = 0 then "0" else "x") row) in
              note (Printf.sprintf "%s: the %s row is %s" k name places))
            [ ("first", upper); ("second", middle) ];
          (* the third row is a combination of the first two *)
          let ways =
            List.concat_map
              (fun s ->
                List.filter_map
                  (fun t ->
                    if plus (scale (whole s) (exact upper)) (scale (whole t) (exact middle)) = exact lower then Some (s, t)
                    else None)
                  (between (-2) 2))
              (between (-2) 2)
          in
          (match ways with
          | [] -> wrong "the third row is not a combination of the first two with coefficients up to 2"
          | [ (s, t) ] when not (null (cross (exact upper) (exact middle))) ->
              note (number_text k "coefficient" 1 s);
              note (number_text k "coefficient" 2 t)
          | _ -> ());
          let image = rank rows and kernel = kernel_dimension rows in
          if image + kernel <> 3 then
            wrong (Printf.sprintf "the test finds rank %d and a kernel of dimension %d" image kernel);
          if image < 1 || image > 2 then wrong (Printf.sprintf "the rank is %d, neither 1 nor 2" image);
          note (Printf.sprintf "%s: the rank is %d" k image);
          tally (Printf.sprintf "%s: rank %d" k image);
          let expected = if k = "kernel_dimension" then kernel else image in
          if number () <> whole expected then wrong (Printf.sprintf "the test finds the dimension %d" expected);
          ("Numeric", [])
      | _ -> failwith "nine fields were expected")
  | "preimage" -> (
      match
        fields 6
          (words "A linear transformation [`T`] of the plane has the matrix [`" ^ table 2 2
         ^ words "`]. Find the vector [`v`] with [`T(v) = " ^ in_plane ^ words "`].")
          p
      with
      | [ a; b; c; d; x; y ] ->
          let matrix = [ exact (numbers [ a; b ]); exact (numbers [ c; d ]) ] and image = exact (numbers [ x; y ]) in
          unit_columns (numbers [ a; c ]) (numbers [ b; d ]);
          let v = arrow () in
          if apply matrix v <> image then wrong "the matrix does not send the answer to the printed vector";
          if shoelace matrix = zero then wrong "the matrix is singular, other vectors have the same image";
          if v = image then wrong "the vector is its own image";
          (* every vector with whole entries up to 12 *)
          let candidates = List.concat_map (fun s -> List.map (fun t -> [ s; t ]) (between (-12) 12)) (between (-12) 12) in
          (match List.filter (fun candidate -> apply matrix (exact candidate) = image) candidates with
          | [ only ] ->
              if exact only <> v then wrong ("the search finds " ^ show_row (exact only));
              ranged 5 "component" only
          | found -> wrong (Printf.sprintf "the search finds %d vectors with this image" (List.length found)));
          ("Vector", [])
      | _ -> failwith "six fields were expected")
  | "matrix_from_images" -> (
      match
        fields 8
          (words "A linear transformation [`T`] of the plane sends [`" ^ in_plane ^ words "`] to [`" ^ in_plane
         ^ words "`] and [`" ^ in_plane ^ words "`] to [`" ^ in_plane
         ^ words "`]. Find the matrix [`A`] with [`T(v) = Av`] for every vector [`v`].")
          p
      with
      | [ u1; u2; r1; r2; v1; v2; s1; s2 ] ->
          let u = numbers [ u1; u2 ] and v = numbers [ v1; v2 ] in
          let u_image = numbers [ r1; r2 ] and v_image = numbers [ s1; s2 ] in
          unit_columns u v;
          let matrix = square () in
          if apply matrix (exact u) <> exact u_image then wrong "the matrix does not send the first vector to its image";
          if apply matrix (exact v) <> exact v_image then wrong "the matrix does not send the second vector to its image";
          if not (independent (exact u) (exact v)) then wrong "the two vectors are not independent";
          found_by_rows 4 u u_image v v_image;
          if shoelace matrix = zero then wrong "the matrix is singular";
          (match matrix with
          | [ [ a; b ]; [ c; d ] ] when List.for_all (fun x -> x.bottom = 1) [ a; b; c; d ] ->
              ranged ~with_zero:true 4 "entry" [ a.top; b.top; c.top; d.top ]
          | _ -> wrong "an entry of the matrix is a fraction");
          ("Matrix", [])
      | _ -> failwith "eight fields were expected")
  | "new_basis" -> (
      match
        fields 8
          (words "A linear transformation [`T`] of the plane has the matrix [`" ^ table 2 2
         ^ words "`] in the standard basis. Find its matrix in the basis [`b_1 = " ^ in_plane ^ words "`], [`b_2 = "
         ^ in_plane ^ words "`].")
          p
      with
      | [ a; b; c; d; u1; u2; v1; v2 ] -> (
          let standard = [ exact (numbers [ a; b ]); exact (numbers [ c; d ]) ] in
          let first = numbers [ u1; u2 ] and second = numbers [ v1; v2 ] in
          ranged 4 "entry" (numbers [ a; b; c; d ]);
          unit_columns first second;
          let b1 = exact first and b2 = exact second in
          if not (independent b1 b2) then wrong "the two vectors are not a basis";
          match square () with
          | [ [ m11; m12 ]; [ m21; m22 ] ] as matrix ->
              (* the definition: A b_j in the coordinates of the new basis *)
              if apply standard b1 <> plus (scale m11 b1) (scale m21 b2) then
                wrong "the first column is not A b_1 in the new basis";
              if apply standard b2 <> plus (scale m12 b1) (scale m22 b2) then
                wrong "the second column is not A b_2 in the new basis";
              if matrix = standard then wrong "the matrix is the same in both bases";
              List.iteri
                (fun place x ->
                  if x.bottom <> 1 || abs x.top > 30 then wrong ("an entry that is a fraction or beyond 30: " ^ show x)
                  else if abs x.top = 30 then note (Printf.sprintf "new_basis: entry %d reaches 30" (place + 1)))
                [ m11; m12; m21; m22 ];
              (* the mistake: P A P^(-1), column by column *)
              let change = columns [ b1; b2 ] in
              let back = inverse change in
              let slip = matrix_of 2 (fun e -> apply change (apply standard (apply back e))) in
              (* the limit of 30 is on the right matrix alone *)
              List.iteri
                (fun place x ->
                  if abs x.top > 30 then
                    note (Printf.sprintf "new_basis: entry %d of the mistaken matrix is beyond 30" (place + 1)))
                (List.concat slip);
              ("Matrix", [ ("basis_wrong_way", Table slip) ])
          | _ -> failwith "the answer is not a 2 by 2 matrix")
      | _ -> failwith "eight fields were expected")
  | "reflection" -> (
      match
        fields 2
          (words "Find the matrix of the reflection of the plane in its line through the origin in the direction of [`"
         ^ in_plane ^ words "`]. Its entries may be fractions.")
          p
      with
      | [ a; b ] ->
          let a = int_of_string a and b = int_of_string b in
          if a < 1 || a > 4 || b = 0 || abs b > 4 then wrong "a direction outside the grammar's range";
          if gcd a b <> 1 then wrong "the two components of the direction share a factor";
          note (Printf.sprintf "reflection: direction %d, %d" a b);
          let matrix = square () and along = exact [ a; b ] and across = exact [ -b; a ] in
          if dot along across <> zero then failwith "the test's own orthogonal direction is not orthogonal";
          if apply matrix along <> along then wrong "the matrix moves the direction of the line";
          if apply matrix across <> scale (whole (-1)) across then
            wrong "the matrix does not turn the orthogonal direction round";
          List.iter
            (fun e -> if apply matrix (apply matrix e) <> e then wrong "the matrix applied twice is not the identity")
            (basis 2);
          ("Matrix", [])
      | _ -> failwith "two fields were expected")
  | k -> failwith ("unknown kind " ^ k)

(* The mistakes as the grammar's header describes them. *)
let described =
  [ ("images_as_rows", "writes the images of the basis vectors as the rows of the matrix, where they are its columns");
    ("order_swapped", "multiplies the two matrices in the order the transformations are applied, the first on the left");
    ("basis_wrong_way", "changes basis the wrong way round: P A P^(-1) where P^(-1) A P belongs") ]

let () =
  let base = load_file "linear_transformations.rhm" in
  let prices =
    [ ("image", 1); ("standard_matrix", 1); ("composition", 2); ("area", 2); ("kernel_dimension", 2);
      ("image_dimension", 2); ("preimage", 2); ("matrix_from_images", 3); ("new_basis", 3); ("reflection", 3) ]
  in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 8 and generated = Hashtbl.create 4 in
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
                (match (got, context) with
                | Number _, "Numeric" | Arrow _, "Vector" | Table _, "Matrix" -> ()
                | _ ->
                    fail (Printf.sprintf "%s: the answer %s is not what the context %s holds" k (show_answer got) context));
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
                    | Some description ->
                        if m.description <> description then
                          fail (Printf.sprintf "%s is described as %S, not as %S" m.mistake m.description description));
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
  (* Two matrices of composition that commute are drawn about once in 300
     pairs, and the lower left entry of the matrix in a new basis is 30 in
     size about once in 340 questions of that form, so the run is long
     enough to meet these cases many times: to see that the grammar turns
     the first away and that the second comes up. *)
  let per_budget = 12000 in
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
    [ "images_as_rows on standard_matrix"; "order_swapped on composition"; "basis_wrong_way on new_basis" ];
  (* Every choice the grammar offers is taken at least once, in every form
     that has it. *)
  if List.length unit_pairs <> 34 then fail "the test's own list of pairs p, q does not hold 34 pairs";
  let without_zero limit = List.filter (fun x -> x <> 0) (between (-limit) limit) in
  (* each number of a list takes every value, and each two of them are seen
     both equal and different, but for the pairs that are never equal *)
  let all ?(never_equal = []) k name places values =
    List.concat_map (fun place -> List.map (fun x -> number_text k name place x) values) (between 1 places)
    @ List.concat_map
        (fun first ->
          List.concat_map
            (fun second ->
              if second <= first then []
              else if List.mem (first, second) never_equal then [ pair_text k name first second false ]
              else [ pair_text k name first second true; pair_text k name first second false ])
            (between 1 places))
        (between 1 places)
  in
  (* where a row of a matrix of space has its zeros *)
  let zeros k =
    List.concat_map
      (fun row ->
        List.map
          (fun places -> Printf.sprintf "%s: the %s row is %s" k row places)
          [ "xxx"; "0xx"; "x0x"; "xx0"; "00x"; "0x0"; "x00" ])
      [ "first"; "second" ]
  in
  let dimension k =
    all k "entry of the first row" 3 (between (-3) 3)
    @ all k "entry of the second row" 3 (between (-3) 3)
    @ zeros k
    @ List.concat_map (fun place -> List.map (fun x -> number_text k "coefficient" place x) (between (-2) 2)) [ 1; 2 ]
    @ [ k ^ ": the second row is 2 times the first"; k ^ ": the second row is -2 times the first"; k ^ ": the rank is 1";
        k ^ ": the rank is 2" ]
  in
  let choices =
    all "image" "coefficient" 4 (without_zero 4)
    @ all "image" "component" 2 (without_zero 5)
    (* the numbers stand in the order printed: the second and the third
       are the two entries off the diagonal, which are never the same *)
    @ all ~never_equal:[ (2, 3) ] "standard_matrix" "number" 4 (between (-5) 5)
    @ all "composition" "entry of S" 4 (without_zero 4)
    @ all "composition" "entry of T" 4 (without_zero 4)
    @ all "area" "entry" 4 (without_zero 4)
    @ List.map (Printf.sprintf "area: the area is %d") (between 1 6)
    @ [ "area: the orientation is kept"; "area: the orientation is reversed" ]
    @ dimension "kernel_dimension" @ dimension "image_dimension"
    @ List.map (fun (p, q) -> basis_text "preimage" p q) unit_pairs
    @ all "preimage" "component" 2 (without_zero 5)
    @ List.map (fun (p, q) -> basis_text "matrix_from_images" p q) unit_pairs
    @ all "matrix_from_images" "entry" 4 (between (-4) 4)
    (* with p q = -2 the basis matrix P has P P = -I, and changing basis the
       wrong way round gives the right matrix: never asked *)
    @ List.filter_map (fun (p, q) -> if p * q = -2 then None else Some (basis_text "new_basis" p q)) unit_pairs
    @ all "new_basis" "entry" 4 (without_zero 4)
    @ List.map (Printf.sprintf "new_basis: entry %d reaches 30") [ 2; 3 ]
    @ List.map (Printf.sprintf "new_basis: entry %d of the mistaken matrix is beyond 30") (between 1 4)
    @ List.concat_map
        (fun a ->
          List.filter_map
            (fun b -> if gcd a b = 1 then Some (Printf.sprintf "reflection: direction %d, %d" a b) else None)
            (without_zero 4))
        (between 1 4)
  in
  List.iter (fun what -> if not (Hashtbl.mem noted what) then fail ("never generated: " ^ what)) choices;
  (* Neither dimension has an answer that is nearly always the same: the
     rank is 1 in at least a tenth of the questions of either kind. *)
  List.iter
    (fun k ->
      let line = tallied (k ^ ": rank 1") and plane = tallied (k ^ ": rank 2") in
      if 10 * line < line + plane then
        fail (Printf.sprintf "%s: the rank is 1 in only %d questions of %d" k line (line + plane)))
    [ "kernel_dimension"; "image_dimension" ];
  (* Nothing else of these sorts was generated. *)
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
  if !failures = 0 then print_endline "Rhema linear_transformations tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d linear_transformations test(s) failed." !failures);
    exit 1
  end
