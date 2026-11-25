(* Independent checks for vector_spaces.rhm. Every question is matched
   against the whole sentence of its form, the numbers are read back from it,
   and the answer is found again on exact fractions from what the question
   says, by the test's own elimination, never by the product, the inverse,
   the rank or the closed formula the grammar itself calls for:

   coordinates,           the coordinates are found by solving
   coordinates_space      c_1 b_1 + c_2 b_2 (+ c_3 b_3) = v with the test's
                          own elimination, and the combination they give is
                          the printed vector. The basis is independent (its
                          rank is its size, and its determinant, by expansion
                          along the first row, is 1), so no other coordinates
                          do. The vector shown is not its own coordinates.
   dimension_polynomials, the space is described by one function, the defect,
   dimension_matrices     that is zero on its members and on nothing else
                          (A^T - A, A^T + A, the trace, the entries below the
                          diagonal, p(0)). The dimension is counted twice:
                          the number of monomials or of matrix units, less
                          the rank of the defect on them; and the rank of the
                          members shown outright: the monomials, the matrix
                          units E_ij and the matrices E_ij + E_ji,
                          E_ij - E_ji and E_ii - E_jj that the defect sends
                          to zero. The two counts must agree, so the members
                          shown are a spanning set and the count is the
                          dimension.
   sum_dimension          two subspaces of R^n are built: U is spanned by the
                          first standard basis vectors and W by as many in a
                          row as its dimension says, beginning so that it
                          shares the stated number with U. The intersection
                          of the two is shown (see intersection below) and
                          has the stated dimension, and the dimension of the
                          sum is the rank of all the spanning vectors.
   intersection_from_sum  the same subspaces are built with every overlap
                          that fits in R^n; exactly one overlap gives the sum
                          the stated dimension, and the dimension of the
                          intersection shown for it is the answer.
   dependence             the determinant of the three vectors is worked out
                          by expansion along the first row for t = 0, 1 and
                          2: it is a linear function of t that is not
                          constant, and its one root is the answer. At the
                          answer the three vectors have rank 2 and the third
                          is the combination of the first two that the test
                          solves for; one further and the rank is 3.
   polynomial_coordinates 1, (x - r) and (x - r)^2 are multiplied out by the
                          test's own polynomial product, the coordinates are
                          found by solving on the coefficients, and the
                          combination they give is the printed polynomial,
                          coefficient by coefficient. The three are
                          independent. The two sides are also compared as
                          numbers at five values of x.
   transition             column j of the matrix is the coordinates of b_j
                          relative to c_1, c_2, found by the test's own
                          solving. For the two standard vectors and three
                          others taken as coordinates x, the vector
                          x_1 b_1 + x_2 b_2 is formed, its coordinates
                          relative to c_1, c_2 are solved for, and the
                          answer applied to x must give them.
   intersection           the dimension is found in three ways that must
                          agree. By ranks: rank U + rank W less the rank of
                          all four vectors. By showing the intersection:
                          every solution of a u_1 + b u_2 = c w_1 + d w_2 is
                          found, the vectors a u_1 + b u_2 they give lie in
                          both subspaces, and their rank is counted. And by
                          the orthogonal complements: the vectors orthogonal
                          to U and those orthogonal to W are found, and 4
                          less the rank of all of them is the dimension.

   The mistakes are worked out from their descriptions. basis_applied on
   coordinates and coordinates_space is the combination of the basis vectors
   with the entries of the printed vector as coefficients.
   degree_for_dimension on dimension_polynomials counts the degree n where
   the n + 1 monomials are to be counted, and takes the rank of the condition
   p(0) = 0 off that. intersection_not_removed on sum_dimension adds the two
   printed dimensions. standard_coordinates on polynomial_coordinates is the
   three printed coefficients, the constant first. direction_reversed on
   transition is the matrix whose columns are the coordinates of c_1 and c_2
   relative to b_1, b_2, by the test's own solving. The engine must list
   exactly these mistakes on these forms, in this order, with these values
   and these descriptions, each different from the right answer and more
   than 1% away from it in some entry (WeBWorK compares with a tolerance of
   one part in a thousand), and none on the other forms.

   For every question: the prompt is the text of the question, there is one
   blank and it holds answer_value, the WeBWorK context is "Numeric" for a
   number, "Vector" for a vector and "Matrix" for a matrix, and nothing
   asked for is a fraction. Each kind appears at its price and at no other,
   no other kind appears, the budget is spent, the grammar's own budget
   gives a question of price 2, and a budget outside 1..3 gives no question.

   The numbers stay in the ranges the grammar says, and every choice it
   offers is seen at least once in every form that has it. A basis of the
   plane is (1, p) and (q, p q + 1) with p and q from -3 to 3, not 0, and
   p q not -1: 34 pairs, of determinant 1 and without a 0. The coordinates
   in the plane are not 0 and go to 5. The standard spaces are six with n
   from 2 to 5 and the n by m matrices with both from 2 to 5. The shared
   dimension of sum_dimension and intersection_from_sum is 1 to 3, each
   subspace has 1 to 3 dimensions more, and the whole space 0 to 2 more
   than the sum: all 81 choices come up in either form. The entries of the
   first two vectors of dependence go to 3 and may be 0, their first two
   entries are not in proportion, and the third vector is s times the first
   plus t times the second in its first two entries, with s and t not 0 and
   up to 2. The first two coordinates of a polynomial go to 5 and may be 0,
   the third and r go to 3 and are not 0, and the polynomial is written the
   one usual way. A basis of space is the columns of a lower triangular
   matrix times an upper triangular one, both with 1s on the diagonal and
   the other six entries not 0 and up to 2, and the coordinates there are
   not 0 and go to 4. The two bases of transition differ, the matrix is not
   its own inverse, and its entries stay within 30: the test goes through
   all pairs of bases itself, and the largest entry seen in each place is
   the largest there is under that limit (19, 30, 6 and 19). The two
   vectors that span U in intersection have entries up to 2 and may have
   0s, and every such vector but the zero vector spans U in some question.
   Each vector of W is either such a vector or a combination of those of U
   (the first with both coefficients not 0 and up to 2, the second with the
   first coefficient so and the other from -2 to 2, and the second only
   where the first is one); the coefficients are solved for where they can
   be told, in a vector that goes beyond 2, and every pair of them comes up
   for either vector (but u_1 itself or its opposite, which does not go
   beyond 2), with no two of the four tied to each other. Each pair of
   spanning vectors is independent, and the dimensions 0, 1 and 2 each come
   up in at least a fifth of the questions. No two numbers of a form are
   tied to each other: each two are seen both equal and different. The
   grammar declares the five mistakes in the order given here. The weights
   of the forms are not tested. *)

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

let between first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)

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
let less a b = a.top * b.bottom < b.top * a.bottom
let absolute a = { a with top = abs a.top }
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

(* ---- Vectors, elimination, determinants ---------------------------------- *)

(* A vector is a list of fractions and a matrix the list of its rows. *)
let exact = List.map whole
let plus = List.map2 ( +: )
let minus = List.map2 ( -: )
let scale k = List.map (fun x -> k *: x)
let dot a b = List.fold_left ( +: ) zero (List.map2 ( *: ) a b)
let null = List.for_all (fun x -> x = zero)
let apply matrix v = List.map (fun row -> dot row v) matrix

(* The standard basis of R^size. *)
let basis size = List.init size (fun i -> List.init size (fun j -> if i = j then one else zero))

let columns rows =
  match rows with
  | [] -> []
  | first :: _ -> List.mapi (fun place _ -> List.map (fun row -> List.nth row place) rows) first

(* The combination of some vectors with the given coefficients. *)
let combination coefficients vectors =
  match vectors with
  | [] -> failwith "a combination of no vectors"
  | first :: _ ->
      List.fold_left2 (fun total c v -> plus total (scale c v)) (List.map (fun _ -> zero) first) coefficients vectors

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

(* The coordinates of v relative to a family of vectors: the system whose
   columns are the family and whose right side is v is reduced. Where the
   family is independent every column gets a pivot and the right side then
   holds the coefficients; they are tested by forming the combination. None
   if the family is not independent or v is not a combination of it. *)
let coordinates family v =
  let count = List.length family in
  let system = List.map2 (fun row last -> row @ [ last ]) (columns family) v in
  let reduced = reduce count system in
  if List.length reduced <> count then None
  else
    let found = List.map (fun row -> List.nth row count) reduced in
    if combination found family = v then Some found else None

(* Every solution x of the system `rows` x = 0 in `width` unknowns, as a
   basis: one solution for each column without a pivot, with 1 in that
   place, 0 in the other such places, and the pivot places read off the
   reduced rows. Each is tested on the system. *)
let kernel width rows =
  let reduced = reduce width rows in
  let pivot row =
    match List.filter (fun column -> List.nth row column <> zero) (between 0 (width - 1)) with
    | first :: _ -> first
    | [] -> failwith "the test's own kernel: a reduced row without a pivot"
  in
  let pivots = List.map (fun row -> (pivot row, row)) reduced in
  let free = List.filter (fun column -> not (List.mem_assoc column pivots)) (between 0 (width - 1)) in
  let found =
    List.map
      (fun chosen ->
        List.init width (fun column ->
            if column = chosen then one
            else match List.assoc_opt column pivots with Some row -> zero -: List.nth row chosen | None -> zero))
      free
  in
  if List.length found + List.length reduced <> width then failwith "the test's own kernel: the count is wrong";
  List.iter
    (fun x -> if List.exists (fun row -> dot row x <> zero) rows then failwith "the test's own kernel: not a solution")
    found;
  found

(* The intersection of the span of `us` and the span of `ws`, shown: every
   solution of a_1 u_1 + ... = c_1 w_1 + ... is found, and each gives the
   vector a_1 u_1 + ..., which is tested to be c_1 w_1 + ... as well. The
   vectors so found span the intersection; its dimension is their rank. *)
let intersection us ws =
  let count = List.length us in
  let system = columns (us @ List.map (scale (whole (-1))) ws) in
  List.map
    (fun solution ->
      let of_u = List.filteri (fun place _ -> place < count) solution in
      let of_w = List.filteri (fun place _ -> place >= count) solution in
      let v = combination of_u us in
      if v <> combination of_w ws then failwith "the test's own intersection: a vector that is not in both";
      v)
    (kernel (count + List.length ws) system)

(* The determinant, by expansion along the first row. *)
let rec determinant rows =
  match rows with
  | [] -> one
  | first :: rest ->
      let without place = List.map (List.filteri (fun column _ -> column <> place)) rest in
      snd
        (List.fold_left
           (fun (place, total) x ->
             let signed = if place mod 2 = 0 then x else zero -: x in
             (place + 1, total +: (signed *: determinant (without place))))
           (0, zero) first)

(* ---- Polynomials --------------------------------------------------------- *)

(* A polynomial is the list of its coefficients, the constant first. *)
let multiply a b =
  List.init
    (List.length a + List.length b - 1)
    (fun degree ->
      List.fold_left ( +: ) zero
        (List.mapi
           (fun i x ->
             if degree < i then zero else match List.nth_opt b (degree - i) with Some y -> x *: y | None -> zero)
           a))

let value polynomial x = List.fold_right (fun c total -> c +: (x *: total)) polynomial zero
let padded size polynomial = List.init size (fun i -> Option.value ~default:zero (List.nth_opt polynomial i))

(* ---- The dimension of a standard space ----------------------------------- *)

(* A space is given inside a space of known coordinates (the coefficients of
   a polynomial, the entries of a matrix) by its defect: a linear function
   that is zero on the members of the space and on nothing else. The
   dimension is counted twice. First, the number of coordinates less the
   rank of the defect, whose matrix has the defects of the unit vectors as
   its columns. Second, the rank of the candidates that are members. The
   second count cannot be more than the dimension; when it is the first
   count, the members shown span the space. The result is the dimension and
   the rank of the defect. *)
let counted units candidates defect =
  let conditions = columns (List.map defect units) in
  let tied = rank conditions in
  let members = List.filter (fun candidate -> null (defect candidate)) candidates in
  let shown = rank members in
  if List.length units - tied <> shown then
    failwith
      (Printf.sprintf "the test's own dimension: %d coordinates, %d conditions, but %d independent members shown"
         (List.length units) tied shown);
  (shown, tied)

let dimensions = Hashtbl.create 64

(* The seven spaces, numbered as in the grammar's table. n is the degree or
   the number of rows, and m the number of columns of the last one. *)
let standard_dimension space n m =
  match Hashtbl.find_opt dimensions (space, n, m) with
  | Some result -> result
  | None ->
      let result =
        if space <= 1 then begin
          (* the monomials 1, x, ..., x^n *)
          let monomials = basis (List.length (between 0 n)) in
          let defect polynomial = if space = 1 then [ value polynomial zero ] else [] in
          counted monomials monomials defect
        end
        else begin
          let across = if space = 6 then m else n in
          let places = List.concat_map (fun i -> List.map (fun j -> (i, j)) (between 0 (across - 1))) (between 0 (n - 1)) in
          let unit at = List.map (fun place -> if place = at then one else zero) places in
          let entry a i j = List.nth a ((i * across) + j) in
          let defect a =
            match space with
            | 2 -> List.map (fun (i, j) -> entry a j i -: entry a i j) places
            | 3 -> List.map (fun (i, j) -> entry a j i +: entry a i j) places
            | 4 -> [ List.fold_left (fun total i -> total +: entry a i i) zero (between 0 (n - 1)) ]
            | 5 -> List.filter_map (fun (i, j) -> if i > j then Some (entry a i j) else None) places
            | _ -> []
          in
          let units = List.map unit places in
          let mixed =
            if across <> n then []
            else
              List.concat_map
                (fun (i, j) ->
                  if i >= j then []
                  else
                    [ plus (unit (i, j)) (unit (j, i)); minus (unit (i, j)) (unit (j, i)); minus (unit (i, i)) (unit (j, j)) ])
                places
          in
          counted units (units @ mixed) defect
        end
      in
      Hashtbl.replace dimensions (space, n, m) result;
      result

(* ---- Two subspaces of R^size spanned by standard basis vectors ----------- *)

let placed = Hashtbl.create 64

(* U is spanned by the first `first` standard basis vectors and W by
   `second` of them in a row, the first `overlap` of which are the last of
   U. The result is the dimension of the sum, the rank of all the spanning
   vectors, and that of the intersection, which is shown and must be what
   the two have in common. None if R^size has no room for W. *)
let coordinate_subspaces size first second overlap =
  let key = (size, first, second, overlap) in
  match Hashtbl.find_opt placed key with
  | Some result -> result
  | None ->
      let result =
        let take from count = List.filteri (fun place _ -> place >= from && place < from + count) (basis size) in
        let u = take 0 first and w = take (first - overlap) second in
        if overlap > first || List.length u <> first || List.length w <> second then None
        else begin
          let common = List.filter (fun v -> List.mem v w) u in
          let shared = rank (intersection u w) in
          if shared <> List.length common || shared <> overlap then
            failwith "the test's own subspaces do not share what they were built to share";
          Some (rank (u @ w), shared)
        end
      in
      Hashtbl.replace placed key result;
      result

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

(* The numbers an answer is made of, in order. *)
let entries = function Number n -> [ n ] | Arrow v -> v | Table rows -> List.concat rows

(* A marker with a tolerance of one part in a thousand must not take the
   mistaken answer for the right one: some entry is more than 1% away. *)
let apart mistaken right =
  let theirs = entries mistaken and ours = entries right in
  List.length theirs <> List.length ours
  || List.exists2 (fun wrong good -> less (absolute good) (whole 100 *: absolute (wrong -: good))) theirs ours

(* ---- Reading the question ----------------------------------------------- *)

(* The fields of a prompt: the pattern is the whole sentence, with a group
   wherever a number of the question stands. *)
let words = Str.quote
let a_whole = "\\(0\\|-?[1-9][0-9]*\\)"
let a_count = "\\([1-9][0-9]*\\)"
let arrow_of count = words "\\langle " ^ String.concat ", " (List.init count (fun _ -> a_whole)) ^ words " \\rangle"

let fields_opt count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    Some (List.init count (fun n -> Str.matched_group (n + 1) prompt))
  else None

let fields count pattern prompt =
  match fields_opt count pattern prompt with Some found -> found | None -> failwith "the wording is not the expected one"

(* Consecutive pieces of a list, each `size` long. *)
let rec pieces size = function
  | [] -> []
  | all ->
      let here = List.filteri (fun place _ -> place < size) all in
      here :: pieces size (List.filteri (fun place _ -> place >= size) all)

(* A polynomial c x^2 + b x + a as it should be written: no digit for a
   coefficient 1 or -1, no term with coefficient 0, and the sign of a later
   term as the operation. The result of reading is (a, b, c). *)
let polynomial_text (alone, in_x, lead) =
  (match lead with 1 -> "" | -1 -> "-" | c -> string_of_int c)
  ^ "x^{2}"
  ^ (if in_x = 0 then "" else (if in_x > 0 then " + " else " - ") ^ (if abs in_x = 1 then "" else string_of_int (abs in_x)) ^ "x")
  ^ if alone = 0 then "" else (if alone > 0 then " + " else " - ") ^ string_of_int (abs alone)

let polynomial_of text =
  let pattern = "\\(-?[0-9]*\\)x\\^{2}\\( \\([-+]\\) \\([0-9]*\\)x\\)?\\( \\([-+]\\) \\([0-9]+\\)\\)?" in
  if not (Str.string_match (Str.regexp pattern) text 0 && Str.match_end () = String.length text) then
    failwith ("not a polynomial of degree 2: " ^ text);
  let group i = try Some (Str.matched_group i text) with Not_found -> None in
  let signed sign size = if sign = Some "-" then -size else size in
  let lead = match group 1 with Some "" | None -> 1 | Some "-" -> -1 | Some digits -> int_of_string digits in
  let in_x =
    match (group 2, group 4) with
    | None, _ -> 0
    | Some _, (Some "" | None) -> signed (group 3) 1
    | Some _, Some digits -> signed (group 3) (int_of_string digits)
  in
  let alone = match (group 5, group 7) with Some _, Some digits -> signed (group 6) (int_of_string digits) | _ -> 0 in
  if polynomial_text (alone, in_x, lead) <> text then failwith ("a polynomial written in an unusual way: " ^ text);
  (alone, in_x, lead)

(* ---- What was generated besides the kinds ------------------------------- *)

let noted = Hashtbl.create 1024
let note what = Hashtbl.replace noted what ()

(* How often something was generated. *)
let tallies = Hashtbl.create 16
let tally what = Hashtbl.replace tallies what (1 + Option.value ~default:0 (Hashtbl.find_opt tallies what))
let tallied what = Option.value ~default:0 (Hashtbl.find_opt tallies what)

(* The sizes of the entries of the matrix of transition, by place. *)
let sizes = Hashtbl.create 128

(* The vectors that U was spanned by in intersection. *)
let spanning = Hashtbl.create 1024

(* What is noted of the numbers of a form: number `place` of the sort `name`
   has this value. *)
let number_text k name place value = Printf.sprintf "%s: %s %d is %d" k name place value

(* And of two of them: they are the same number, or they are not. No two
   numbers of a form are tied to each other unless the grammar says so. *)
let pair_text k name first second same =
  Printf.sprintf "%s: %s %d and %d %s" k name first second (if same then "are equal" else "differ")

let basis_text k which p q = Printf.sprintf "%s: the %s basis with p = %d, q = %d" k which p q
let space_text space n = Printf.sprintf "dimension: space %d with n = %d" space n
let shape_text n m = Printf.sprintf "dimension: %d by %d matrices" n m

let sum_text k shared more_u more_w room =
  Printf.sprintf "%s: %d shared, %d and %d more, %d to spare" k shared more_u more_w room

(* A vector of W in intersection that is a combination of those of U. *)
let combined_text which s t = Printf.sprintf "intersection: the %s vector of W is %d times u_1 plus %d times u_2" which s t

(* The 34 pairs (p, q) a basis of the plane is made of. *)
let unit_pairs =
  List.concat_map
    (fun p -> List.filter_map (fun q -> if p <> 0 && q <> 0 && p * q <> -1 then Some (p, q) else None) (between (-3) 3))
    (between (-3) 3)

(* The vectors (1, p) and (q, p q + 1). *)
let unit_basis (p, q) = [ exact [ 1; p ]; exact [ q; (p * q) + 1 ] ]

(* The matrix that changes coordinates relative to the basis `from` into
   coordinates relative to the basis `into`: column j is the coordinates of
   vector j of `from` relative to `into`, solved for. *)
let change from into =
  columns
    (List.map
       (fun b ->
         match coordinates into b with
         | Some found -> found
         | None -> failwith "the test's own change of basis: no coordinates")
       from)

(* The vectors the transition matrix is tried on, as coordinates. *)
let tried = basis 2 @ List.map exact [ [ 1; 1 ]; [ 2; -3 ]; [ -5; 7 ] ]

(* The right answer is tested here by what defines it. The result is the
   WeBWorK context the form needs and the answer of each mistake the form is
   open to, worked out from the printed question. *)
let check (q : Rhema_engine.question) got =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what (show_answer got) p) in
  let number () = match got with Number n -> n | _ -> failwith "the answer is not a number" in
  let numbers = List.map int_of_string in
  (* Fractions that must be whole numbers. *)
  let wholes what =
    List.map (fun x -> if x.bottom <> 1 then failwith (what ^ " is a fraction: " ^ show x) else x.top)
  in
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
  let unit_columns which first second =
    match (first, second) with
    | [ 1; p ], [ q; r ] ->
        if not (List.mem (p, q) unit_pairs) then
          wrong (Printf.sprintf "p = %d and q = %d are not a choice of the grammar" p q);
        if r <> (p * q) + 1 then wrong "the two vectors are not (1, p) and (q, p q + 1)";
        if r = 0 then wrong "a 0 among the two vectors";
        if determinant (columns [ exact first; exact second ]) <> one then
          wrong "the two vectors do not make a matrix of determinant 1";
        note (basis_text k which p q)
    | _ -> wrong "the first vector does not begin with 1"
  in
  (* The coordinates of v relative to a basis: the basis is independent, so
     there is one set of them. *)
  let relative what family v =
    if rank family <> List.length family then failwith (what ^ " are not independent");
    match coordinates family v with Some found -> found | None -> failwith ("no coordinates relative to " ^ what)
  in
  match k with
  | "coordinates" -> (
      match
        fields 6
          (words "The vectors [`b_1 = " ^ arrow_of 2 ^ words "`] and [`b_2 = " ^ arrow_of 2
         ^ words "`] are a basis of the plane. Find the coordinates of [`v = " ^ arrow_of 2
         ^ words "`] relative to this basis: the vector [`\\langle c_1, c_2 \\rangle`] with [`v = c_1 b_1 + c_2 b_2`].")
          p
      with
      | [ b11; b12; b21; b22; v1; v2 ] ->
          let first = numbers [ b11; b12 ] and second = numbers [ b21; b22 ] and v = exact (numbers [ v1; v2 ]) in
          unit_columns "only" first second;
          let family = [ exact first; exact second ] in
          let found = relative "the two vectors" family v in
          ranged 5 "coordinate" (wholes "a coordinate" found);
          if got <> Arrow found then wrong ("solving gives the coordinates " ^ show_row found);
          if v = found then wrong "the vector shown is its own coordinates";
          ("Vector", [ ("basis_applied", Arrow (combination v family)) ])
      | _ -> failwith "six fields were expected")
  | "dimension_polynomials" | "dimension_matrices" -> (
      let size = words "[`" ^ a_count ^ words "`]" in
      let by = size ^ " by " ^ size in
      let start = words "Find the dimension of the vector space of all " in
      let forms =
        [ (0, start ^ "polynomials of degree at most " ^ size ^ words ".");
          (1, start ^ words "polynomials [`p`] of degree at most " ^ size ^ words " with [`p(0) = 0`].");
          (2, start ^ "symmetric " ^ by ^ words " matrices.");
          (3, start ^ by ^ words " matrices [`A`] with [`A^{T} = -A`].");
          (4, start ^ by ^ words " matrices whose trace is [`0`].");
          (5, start ^ "upper triangular " ^ by ^ words " matrices.");
          (6, start ^ by ^ words " matrices.") ]
      in
      let read_as (space, pattern) =
        Option.map (fun found -> (space, numbers found)) (fields_opt (if space <= 1 then 1 else 2) pattern p)
      in
      match List.filter_map read_as forms with
      | [ (space, n :: rest) ] ->
          let m = match rest with [ m ] -> m | _ -> n in
          if (space <= 1) <> (k = "dimension_polynomials") then wrong "the kind does not say what the space is made of";
          if space <= 5 && m <> n then wrong "a matrix that is not square";
          if n < 2 || n > 5 || m < 2 || m > 5 then wrong "a size outside the grammar's range";
          note (if space = 6 then shape_text n m else space_text space n);
          let dimension, tied = standard_dimension space n m in
          if number () <> whole dimension then wrong (Printf.sprintf "counting gives the dimension %d" dimension);
          (* the mistake: the degree n counted where the n + 1 monomials are *)
          ("Numeric", if space <= 1 then [ ("degree_for_dimension", Number (whole (n - tied))) ] else [])
      | _ -> failwith "the wording is not the expected one")
  | "sum_dimension" | "intersection_from_sum" -> (
      let given, asked =
        if k = "sum_dimension" then ("[`\\dim(U \\cap W) = ", "`]. Find [`\\dim(U + W)`].")
        else ("[`\\dim(U + W) = ", "`]. Find [`\\dim(U \\cap W)`].")
      in
      match
        fields 4
          (words "[`U`] and [`W`] are subspaces of [`\\mathbb{R}^{" ^ a_count ^ words "}`] with [`\\dim U = " ^ a_count
         ^ words "`], [`\\dim W = " ^ a_count ^ words "`] and " ^ words given ^ a_count ^ words asked)
          p
      with
      | [ size; first; second; stated ] ->
          let size = int_of_string size and first = int_of_string first in
          let second = int_of_string second and stated = int_of_string stated in
          let shared, sum =
            if k = "sum_dimension" then
              match coordinate_subspaces size first second stated with
              | Some (sum, shared) -> (shared, sum)
              | None -> failwith "no two such subspaces can be built"
            else
              (* every overlap that fits, and the one that gives this sum *)
              let fitting =
                List.filter_map
                  (fun overlap ->
                    match coordinate_subspaces size first second overlap with
                    | Some (sum, shared) when sum = stated -> Some (shared, sum)
                    | _ -> None)
                  (between 0 (min first second))
              in
              match fitting with [ only ] -> only | _ -> failwith "not exactly one overlap gives the stated sum"
          in
          if shared < 1 || shared > 3 then wrong "the shared dimension is not from 1 to 3";
          if first - shared < 1 || first - shared > 3 then wrong "U does not reach 1 to 3 dimensions beyond the shared";
          if second - shared < 1 || second - shared > 3 then wrong "W does not reach 1 to 3 dimensions beyond the shared";
          if size - sum < 0 || size - sum > 2 then wrong "the whole space is not 0 to 2 dimensions more than the sum";
          note (sum_text k shared (first - shared) (second - shared) (size - sum));
          if k = "sum_dimension" then begin
            if number () <> whole sum then wrong (Printf.sprintf "the sum built has dimension %d" sum);
            ("Numeric", [ ("intersection_not_removed", Number (whole (first + second))) ])
          end
          else begin
            if number () <> whole shared then wrong (Printf.sprintf "the intersection built has dimension %d" shared);
            ("Numeric", [])
          end
      | _ -> failwith "four fields were expected")
  | "dependence" -> (
      match
        fields 8
          (words "For which value of [`t`] are the vectors [`" ^ arrow_of 3 ^ words "`], [`" ^ arrow_of 3
         ^ words "`] and [`\\langle " ^ a_whole ^ ", " ^ a_whole ^ words ", t \\rangle`] linearly dependent?")
          p
      with
      | [ a1; a2; a3; b1; b2; b3; x; y ] ->
          let u = numbers [ a1; a2; a3 ] and v = numbers [ b1; b2; b3 ] in
          let x = int_of_string x and y = int_of_string y in
          ranged ~with_zero:true 3 "entry" (u @ v);
          let third t = [ whole x; whole y; t ] in
          let of_t t = determinant [ exact u; exact v; third t ] in
          let at_0 = of_t zero and at_1 = of_t one and at_2 = of_t (whole 2) in
          let slope = at_1 -: at_0 in
          if at_2 -: at_1 <> slope then failwith "the test's own determinant is not linear in t";
          if slope = zero then wrong "the determinant does not change with t"
          else begin
            let root = zero -: (at_0 /: slope) in
            let t = number () in
            if t <> root then wrong ("the determinant vanishes at t = " ^ show root);
            if of_t t <> zero then wrong "the determinant is not 0 at the answer";
            if rank [ exact u; exact v; third t ] <> 2 then wrong "the rank of the three vectors is not 2 at the answer";
            if rank [ exact u; exact v; third (t +: one) ] <> 3 then wrong "the three vectors are dependent for another t too";
            (* the dependence itself: the third vector is s u + t v, and its
               first two entries alone say which s and t *)
            let short = List.filteri (fun place _ -> place < 2) in
            match coordinates [ exact (short u); exact (short v) ] [ whole x; whole y ] with
            | None -> wrong "the first two entries of the first two vectors are in proportion"
            | Some found ->
                if combination found [ exact u; exact v ] <> third t then
                  wrong "the third vector is not a combination of the first two at the answer";
                ranged 2 "coefficient" (wholes "a coefficient" found)
          end;
          ("Numeric", [])
      | _ -> failwith "eight fields were expected")
  | "polynomial_coordinates" -> (
      let bracket = words "(x " ^ "\\([-+]\\) " ^ a_count ^ words ")" in
      match
        fields 9
          (words "The polynomials [`1`], [`" ^ bracket ^ words "`] and [`" ^ bracket
         ^ words "^{2}`] are a basis of the polynomials of degree at most [`2`]. Find the coordinates of [`p(x) = "
         ^ "\\([-+0-9x^{} ]+\\)"
         ^ words "`] relative to this basis: the vector [`\\langle c_0, c_1, c_2 \\rangle`] with [`p(x) = c_0 + c_1 "
         ^ bracket ^ words " + c_2 " ^ bracket ^ words "^{2}`].")
          p
      with
      | [ sign1; size1; sign2; size2; text; sign3; size3; sign4; size4 ] ->
          if List.exists (fun other -> other <> (sign1, size1)) [ (sign2, size2); (sign3, size3); (sign4, size4) ] then
            wrong "the brackets of the question are not all the same";
          (* (x - r), so (x + 3) has r = -3 *)
          let r = if sign1 = "-" then int_of_string size1 else -int_of_string size1 in
          let alone, in_x, lead = polynomial_of text in
          let printed = exact [ alone; in_x; lead ] in
          let step = exact [ -r; 1 ] in
          let family = List.map (padded 3) [ [ one ]; step; multiply step step ] in
          let found = relative "the three polynomials" family printed in
          if got <> Arrow found then wrong ("solving gives the coordinates " ^ show_row found);
          (match found with
          | [ c0; c1; c2 ] ->
              (* the two sides as numbers *)
              List.iter
                (fun x ->
                  let x = whole x in
                  let away = x -: whole r in
                  if value printed x <> c0 +: (c1 *: away) +: (c2 *: away *: away) then
                    wrong ("the two sides differ at x = " ^ show x))
                [ r; r + 1; r - 1; 0; 7 ];
              ranged ~with_zero:true 5 "coordinate" (wholes "a coordinate" [ c0; c1 ]);
              ranged 3 "last coordinate or r" (wholes "a coordinate" [ c2 ] @ [ r ])
          | _ -> failwith "three coordinates were expected");
          ("Vector", [ ("standard_coordinates", Arrow printed) ])
      | _ -> failwith "nine fields were expected")
  | "coordinates_space" -> (
      match
        fields 12
          (words "The vectors [`b_1 = " ^ arrow_of 3 ^ words "`], [`b_2 = " ^ arrow_of 3 ^ words "`] and [`b_3 = "
         ^ arrow_of 3 ^ words "`] are a basis of space. Find the coordinates of [`v = " ^ arrow_of 3
         ^ words
             "`] relative to this basis: the vector [`\\langle c_1, c_2, c_3 \\rangle`] with [`v = c_1 b_1 + c_2 b_2 + c_3 b_3`].")
          p
      with
      | [ _; _; _; _; _; _; _; _; _; _; _; _ ] as found -> (
          match pieces 3 (numbers found) with
          | [ ([ b11; l21; l31 ] as b1); ([ u12; _; b32 ] as b2); ([ u13; b23; _ ] as b3); v ] ->
              (* the basis as a lower triangular matrix times an upper
                 triangular one, both with 1s on the diagonal: the six other
                 entries are read off, and the product must give the basis *)
              let l32 = b32 - (l31 * u12) and u23 = b23 - (l21 * u13) in
              let lower = List.map exact [ [ 1; 0; 0 ]; [ l21; 1; 0 ]; [ l31; l32; 1 ] ] in
              let upper = List.map exact [ [ 1; u12; u13 ]; [ 0; 1; u23 ]; [ 0; 0; 1 ] ] in
              let family = List.map exact [ b1; b2; b3 ] and v = exact v in
              if b11 <> 1 || List.map (fun e -> apply lower (apply upper e)) (basis 3) <> family then
                wrong "the basis is not a lower triangular matrix times an upper triangular one, with 1s on the diagonals";
              ranged 2 "factor entry" [ l21; l31; l32; u12; u13; u23 ];
              if determinant (columns family) <> one then wrong "the three vectors do not make a matrix of determinant 1";
              let found = relative "the three vectors" family v in
              ranged 4 "coordinate" (wholes "a coordinate" found);
              if got <> Arrow found then wrong ("solving gives the coordinates " ^ show_row found);
              if v = found then wrong "the vector shown is its own coordinates";
              ("Vector", [ ("basis_applied", Arrow (combination v family)) ])
          | _ -> failwith "four vectors of space were expected")
      | _ -> failwith "twelve fields were expected")
  | "transition" -> (
      match
        fields 8
          (words "The plane has the basis [`b_1 = " ^ arrow_of 2 ^ words "`], [`b_2 = " ^ arrow_of 2
         ^ words "`] and the basis [`c_1 = " ^ arrow_of 2 ^ words "`], [`c_2 = " ^ arrow_of 2
         ^ words
             "`]. Find the matrix [`M`] that changes coordinates relative to [`b_1, b_2`] into coordinates relative to [`c_1, c_2`]: if [`v = x_1 b_1 + x_2 b_2 = y_1 c_1 + y_2 c_2`], then [`\\langle y_1, y_2 \\rangle = M \\langle x_1, x_2 \\rangle`].")
          p
      with
      | [ _; _; _; _; _; _; _; _ ] as found -> (
          match pieces 2 (numbers found) with
          | [ b1; b2; c1; c2 ] ->
              unit_columns "first" b1 b2;
              unit_columns "second" c1 c2;
              let from = List.map exact [ b1; b2 ] and into = List.map exact [ c1; c2 ] in
              if rank from <> 2 || rank into <> 2 then wrong "a basis that is not independent";
              if from = into then wrong "the two bases are the same";
              let matrix = change from into in
              if got <> Table matrix then wrong ("solving gives the matrix " ^ show_answer (Table matrix));
              let answer = match got with Table rows -> rows | _ -> failwith "the answer is not a matrix" in
              (* the definition, on several vectors given by their coordinates *)
              List.iter
                (fun x ->
                  let v = combination x from in
                  if Some (apply answer x) <> coordinates into v then
                    wrong ("the matrix does not change the coordinates " ^ show_row x))
                tried;
              if List.for_all (fun e -> apply answer (apply answer e) = e) (basis 2) then wrong "the matrix is its own inverse";
              List.iteri
                (fun place x ->
                  if abs x > 30 then wrong (Printf.sprintf "an entry beyond 30: %d" x);
                  Hashtbl.replace sizes (place + 1, abs x) ())
                (wholes "an entry" (List.concat answer));
              ("Matrix", [ ("direction_reversed", Table (change into from)) ])
          | _ -> failwith "four vectors of the plane were expected")
      | _ -> failwith "eight fields were expected")
  | "intersection" -> (
      match
        fields 16
          (words "In [`\\mathbb{R}^{4}`], the subspace [`U`] is spanned by [`" ^ arrow_of 4 ^ words "`] and [`" ^ arrow_of 4
         ^ words "`], and the subspace [`W`] by [`" ^ arrow_of 4 ^ words "`] and [`" ^ arrow_of 4
         ^ words "`]. Find the dimension of [`U \\cap W`].")
          p
      with
      | [ _; _; _; _; _; _; _; _; _; _; _; _; _; _; _; _ ] as found -> (
          match pieces 4 (numbers found) with
          | [ u1; u2; w1; w2 ] ->
              ranged ~with_zero:true 2 "entry of the first vector" u1;
              ranged ~with_zero:true 2 "entry of the second vector" u2;
              Hashtbl.replace spanning u1 ();
              Hashtbl.replace spanning u2 ();
              let us = List.map exact [ u1; u2 ] and ws = List.map exact [ w1; w2 ] in
              if rank us <> 2 then wrong "the two vectors of U are not independent";
              if rank ws <> 2 then wrong "the two vectors of W are not independent";
              (* a vector of W is drawn like those of U, or it is a
                 combination of them: only then may it go beyond 2 *)
              let small = List.for_all (fun x -> abs x <= 2) in
              let combined limits w =
                match coordinates us (exact w) with
                | Some found
                  when List.for_all2
                         (fun x with_zero -> x.bottom = 1 && abs x.top <= 2 && (with_zero || x.top <> 0))
                         found limits ->
                    Some (List.map (fun x -> x.top) found)
                | _ -> None
              in
              let first = combined [ false; false ] w1 and second = combined [ false; true ] w2 in
              if (not (small w1)) && first = None then
                wrong "the first vector of W is neither drawn like those of U nor a combination of them";
              if not (small w2) then begin
                if second = None then wrong "the second vector of W is neither drawn like those of U nor a combination of them";
                (* the second is a combination only where the first is one *)
                if first = None then wrong "the second vector of W is a combination of those of U and the first is not"
              end;
              (* by ranks *)
              let by_ranks = rank us + rank ws - rank (us @ ws) in
              (* by showing the intersection *)
              let shared = intersection us ws in
              List.iter
                (fun v ->
                  if rank (v :: us) <> 2 || rank (v :: ws) <> 2 then
                    failwith "the test's own intersection: a vector outside one of the subspaces")
                shared;
              let shown = rank shared in
              (* by the orthogonal complements *)
              let across = kernel 4 us @ kernel 4 ws in
              let by_complements = 4 - rank across in
              if by_ranks <> shown || shown <> by_complements then
                failwith
                  (Printf.sprintf "the test's three ways give the dimensions %d, %d and %d" by_ranks shown by_complements);
              if shown < 0 || shown > 2 then wrong "a dimension that is not 0, 1 or 2";
              tally (Printf.sprintf "intersection: dimension %d" shown);
              tally "intersection";
              (* the coefficients of the combinations, where they can be
                 told: those of a vector of W that goes beyond 2 and so
                 cannot have been drawn. The second vector is a combination
                 only where both are, and the four coefficients are not tied
                 to each other. *)
              let coefficients from = List.iteri (fun place x -> note (number_text k "coefficient" (from + place) x)) in
              (match first with
              | Some ([ s; t ] as found) when not (small w1) ->
                  coefficients 1 found;
                  note (combined_text "first" s t)
              | _ -> ());
              (match (first, second) with
              | Some of_first, Some ([ s; t ] as of_second) when not (small w2) ->
                  coefficients 3 of_second;
                  note (combined_text "second" s t);
                  let four = of_first @ of_second in
                  List.iteri
                    (fun place x ->
                      List.iteri
                        (fun other y ->
                          if other > place then note (pair_text k "coefficient" (place + 1) (other + 1) (x = y)))
                        four)
                    four
              | _ -> ());
              if number () <> whole shown then wrong (Printf.sprintf "the intersection shown has dimension %d" shown);
              ("Numeric", [])
          | _ -> failwith "four vectors were expected")
      | _ -> failwith "sixteen fields were expected")
  | k -> failwith ("unknown kind " ^ k)

(* The mistakes as the grammar's header describes them, in the order it
   declares them. *)
let described =
  [ ("basis_applied", "uses the entries of the vector as the coefficients of the basis vectors, where its coordinates are asked for");
    ("degree_for_dimension", "takes the degree n for the dimension of the polynomials of degree at most n, which is n + 1");
    ("intersection_not_removed", "adds the dimensions of the two subspaces and does not take off the dimension of what they share");
    ("standard_coordinates", "gives the coefficients of the polynomial as they stand, its coordinates relative to 1, x, x^2");
    ("direction_reversed", "changes basis the wrong way: the matrix from the second basis to the first") ]

let () =
  let base = load_file "vector_spaces.rhm" in
  (* The grammar declares these mistakes, in this order, and no other. *)
  if base.Rhema_check.mistakes <> described then fail "the mistakes declared are not the five of the header, in its order";
  let prices =
    [ ("coordinates", 1); ("dimension_polynomials", 1); ("dimension_matrices", 1); ("sum_dimension", 1);
      ("intersection_from_sum", 1); ("dependence", 2); ("polynomial_coordinates", 2); ("coordinates_space", 3);
      ("transition", 3); ("intersection", 3) ]
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
                (* nothing asked for has a fraction in it *)
                if List.exists (fun x -> x.bottom <> 1) (entries got) then
                  fail (Printf.sprintf "%s: the answer %s has a fraction in it, for %S" k (show_answer got) p);
                (* a question in which the mistake comes to the right answer
                   is not to be asked, nor one in which a marker with a
                   tolerance of one part in a thousand could take it for the
                   right answer *)
                List.iter
                  (fun (name, slip) ->
                    if slip = got then
                      fail (Printf.sprintf "%s: %s gives the right answer %s, for %S" k name (show_answer got) p)
                    else if not (apart slip got) then
                      fail
                        (Printf.sprintf "%s: %s gives %s, within 1%% of the answer %s, for %S" k name (show_answer slip)
                           (show_answer got) p))
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
  (* The upper right entry of the matrix of transition is 30 in size for 6
     of the 1044 pairs of bases that are asked about; the basis applied to
     the vector shown gives its coordinates back, so that the mistake would
     be the right answer, in one of 170 draws of a basis and coordinates in
     the plane and one of 285 in space; each of the 162 choices of
     sum_dimension and intersection_from_sum is drawn about once in 490
     questions of price 1; and each of the 624 vectors that may span U
     about once in 830 questions of price 3. The run is long enough to meet
     all of these many times: to see that the grammar turns the second away
     and that the others come up. *)
  let per_budget = 20000 in
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
    [ "basis_applied on coordinates"; "degree_for_dimension on dimension_polynomials";
      "intersection_not_removed on sum_dimension"; "standard_coordinates on polynomial_coordinates";
      "basis_applied on coordinates_space"; "direction_reversed on transition" ];
  (* Every choice the grammar offers is taken at least once, in every form
     that has it. *)
  if List.length unit_pairs <> 34 then fail "the test's own list of pairs p, q does not hold 34 pairs";
  let without_zero limit = List.filter (fun x -> x <> 0) (between (-limit) limit) in
  (* each number of a list takes every value, and each two of them are seen
     both equal and different *)
  let all k name places values =
    List.concat_map (fun place -> List.map (fun x -> number_text k name place x) values) (between 1 places)
    @ List.concat_map
        (fun first ->
          List.concat_map
            (fun second ->
              if second <= first then [] else [ pair_text k name first second true; pair_text k name first second false ])
            (between 1 places))
        (between 1 places)
  in
  let choices =
    List.map (fun (p, q) -> basis_text "coordinates" "only" p q) unit_pairs
    @ all "coordinates" "coordinate" 2 (without_zero 5)
    @ List.concat_map (fun space -> List.map (space_text space) (between 2 5)) (between 0 5)
    @ List.concat_map (fun n -> List.map (shape_text n) (between 2 5)) (between 2 5)
    @ List.concat_map
        (fun k ->
          List.concat_map
            (fun shared ->
              List.concat_map
                (fun more_u ->
                  List.concat_map
                    (fun more_w -> List.map (sum_text k shared more_u more_w) (between 0 2))
                    (between 1 3))
                (between 1 3))
            (between 1 3))
        [ "sum_dimension"; "intersection_from_sum" ]
    @ all "dependence" "entry" 6 (between (-3) 3)
    @ all "dependence" "coefficient" 2 (without_zero 2)
    @ all "polynomial_coordinates" "coordinate" 2 (between (-5) 5)
    @ all "polynomial_coordinates" "last coordinate or r" 2 (without_zero 3)
    @ all "coordinates_space" "factor entry" 6 (without_zero 2)
    @ all "coordinates_space" "coordinate" 3 (without_zero 4)
    @ List.concat_map
        (fun which -> List.map (fun (p, q) -> basis_text "transition" which p q) unit_pairs)
        [ "first"; "second" ]
    @ all "intersection" "entry of the first vector" 4 (between (-2) 2)
    @ all "intersection" "entry of the second vector" 4 (between (-2) 2)
    @ List.concat_map
        (fun place -> List.map (number_text "intersection" "coefficient" place) (without_zero 2))
        [ 1; 2; 3 ]
    @ List.map (number_text "intersection" "coefficient" 4) (between (-2) 2)
    @ List.concat_map
        (fun first ->
          List.concat_map
            (fun second ->
              if second <= first then []
              else List.map (pair_text "intersection" "coefficient" first second) [ true; false ])
            (between 1 4))
        (between 1 4)
    @ List.concat_map (fun s -> List.map (combined_text "first" s) (without_zero 2)) (without_zero 2)
    (* u_1 or its opposite is not beyond 2: it is never known to be a
       combination *)
    @ List.concat_map
        (fun s -> List.filter_map (fun t -> if abs s = 1 && t = 0 then None else Some (combined_text "second" s t)) (between (-2) 2))
        (without_zero 2)
  in
  List.iter (fun what -> if not (Hashtbl.mem noted what) then fail ("never generated: " ^ what)) choices;
  (* Nothing else of these sorts was generated. *)
  Hashtbl.iter
    (fun what () -> if not (List.mem what choices) then fail ("not a choice of the grammar: " ^ what))
    noted;
  (* The entries of the matrix of transition: the test goes through every
     pair of different bases itself, keeps those whose matrix stays within
     30, and the sizes seen in each place must be among theirs, the largest
     of them included. *)
  let possible = Hashtbl.create 128 in
  List.iter
    (fun from ->
      List.iter
        (fun into ->
          if from <> into then begin
            let matrix = List.concat (change (unit_basis from) (unit_basis into)) in
            if List.for_all (fun x -> x.bottom = 1 && abs x.top <= 30) matrix then
              List.iteri (fun place x -> Hashtbl.replace possible (place + 1, abs x.top) ()) matrix
          end)
        unit_pairs)
    unit_pairs;
  Hashtbl.iter
    (fun (place, size) () ->
      if not (Hashtbl.mem possible (place, size)) then
        fail (Printf.sprintf "transition: entry %d of size %d is not one the test finds" place size))
    sizes;
  let largest table place = Hashtbl.fold (fun (at, size) () most -> if at = place then max most size else most) table (-1) in
  List.iter2
    (fun place expected ->
      if largest possible place <> expected then
        fail (Printf.sprintf "transition: the test finds entry %d as large as %d, not %d" place (largest possible place) expected);
      if largest sizes place <> expected then
        fail (Printf.sprintf "transition: entry %d goes to %d, not to %d" place (largest sizes place) expected))
    [ 1; 2; 3; 4 ] [ 19; 30; 6; 19 ];
  (* Every vector with entries from -2 to 2 but the zero vector is one of
     the two that span U in some question. *)
  let small = between (-2) 2 in
  List.iter
    (fun a ->
      List.iter
        (fun b ->
          List.iter
            (fun c ->
              List.iter
                (fun d ->
                  let v = [ a; b; c; d ] in
                  if List.exists (fun x -> x <> 0) v && not (Hashtbl.mem spanning v) then
                    fail (Printf.sprintf "intersection: U is never spanned by <%d, %d, %d, %d>" a b c d))
                small)
            small)
        small)
    small;
  (* The intersection of two subspaces of R^4 has no dimension that is
     nearly always the answer: each of 0, 1 and 2 comes up in at least a
     fifth of the questions. *)
  List.iter
    (fun dimension ->
      let count = tallied (Printf.sprintf "intersection: dimension %d" dimension) and total = tallied "intersection" in
      if 5 * count < total then
        fail (Printf.sprintf "intersection: the dimension is %d in only %d questions of %d" dimension count total))
    [ 0; 1; 2 ];
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
  if !failures = 0 then print_endline "Rhema vector_spaces tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d vector_spaces test(s) failed." !failures);
    exit 1
  end
