(* Independent checks for matrix_powers.rhm. Every question is matched
   against the whole sentence of its form, the numbers are read back from it,
   and the answer is found again on exact fractions from what the question
   says, with the test's own matrix product, elimination and determinant,
   never by the rule for the eigenvalues of a power, the product or the sum
   of the eigenvalues, P D^n P^(-1), the Cayley-Hamilton recurrences or the
   closed form of a power that the grammar itself uses:

   eigenvalues_of_power,  no matrix is shown, so the test builds one with the
   eigenvalues_of_inverse, stated eigenvalues that is not diagonal:
   eigenvalues_of_shift   F D F^(-1) with D the diagonal matrix of the two
                          eigenvalues and F a fixed matrix of the test's own,
                          inverted by the test's own elimination. It does
                          this twice, with an F of determinant -2 (the matrix
                          then has fractions in it) and one of determinant 1.
                          The matrix is first shown to have the stated
                          eigenvalues: the roots of t^2 - tr t + det, by the
                          quadratic formula with an exact square root, each
                          tested in det(A - t I) = 0. Then the power is
                          multiplied out, the inverse is found by elimination
                          or c I is added, and the eigenvalues of the result
                          are found the same way. The two matrices must
                          agree, and the answer is a set of two numbers.
   determinant, trace,    a 3 by 3 matrix with the three eigenvalues is built
   determinant_of_square, twice as F T F^(-1), with F a fixed matrix of
   trace_of_square        determinant 4: once with T diagonal, and once with
                          T upper triangular with 1, 2 and -1 above the
                          diagonal, which is not diagonal whatever the
                          eigenvalues are and cannot be diagonalised where
                          two of them are equal. Either is shown to have the
                          eigenvalues as often as they are stated:
                          det(t I - A), by expansion along the first row,
                          is (t - a)(t - b)(t - c) at four values of t. The
                          determinant is then expanded along the first row,
                          the trace is the sum of the diagonal, and the
                          square is multiplied out for its determinant and
                          its trace. The two matrices must agree.
   power, power_trace     the printed matrix is multiplied by itself n times;
                          the answer is the product, or the sum of its
                          diagonal.
   combination_cube,      the cube or the fourth power is multiplied out, or
   combination_fourth,    the inverse is found by elimination (and tested
   combination_inverse    from both sides). alpha is read off an entry beside
                          the diagonal, beta off the first entry, and
                          alpha A + beta I must then give all four entries.
                          The matrix is not a multiple of the identity, so no
                          other pair does.
   one_eigenvalue         the printed matrix is multiplied by itself n times.
                          It is triangular with one number a on the diagonal,
                          and a is the only root of det(A - t I) among the
                          whole numbers as far as 4.
   on_eigenvectors        the matrix is not shown; the test builds the one
                          matrix that has the printed eigenvectors for the
                          printed eigenvalues, F D F^(-1) with the
                          eigenvectors as the columns of F and F inverted by
                          elimination, and tests A u = lambda u on both. The
                          vector v is formed from the printed coefficients
                          and the matrix is applied to it n times.

   The mistakes are worked out from their descriptions. multiplied_by_power
   on eigenvalues_of_power is the set of k times each stated eigenvalue.
   negative_for_inverse on eigenvalues_of_inverse is the set of the stated
   eigenvalues with their signs changed. power_outside on trace_of_square is
   the square of the trace of the matrix built, and on power_trace the n-th
   power of the trace of the printed matrix. entries_raised on power and
   one_eigenvalue is the printed matrix with each entry raised to the power.
   power_dropped on on_eigenvectors is the matrix applied once to v. The
   engine must list exactly these mistakes on these forms, in this order,
   with these values and these descriptions, each different from the right
   answer, and none on the other forms. WeBWorK compares with a tolerance of
   one part in a thousand, so a mistaken set, matrix or vector must be more
   than 1% away from the right one in some entry; a whole number is written
   so that no other whole number passes for it, so a mistaken number must be
   another number and, where the right one is below 1000, more than 0.2%
   away.

   For every question: the prompt is the text of the question, there is one
   blank and it holds answer_value, the WeBWorK context is "Interval" for a
   set, "Numeric" for a number, "Matrix" for a matrix and "Vector" for a
   vector, no entry of a set, a matrix or a vector is beyond 900 in size, and
   nothing asked for is a fraction but the eigenvalues of an inverse and the
   two numbers of combination_inverse, where fractions do come up. Each kind
   appears at its price and at no other, no other kind appears, the budget is
   spent, the grammar's own budget gives a question of price 2, and a budget
   outside 1..3 gives no question.

   The promises of the grammar's comments: two eigenvalues that are stated,
   or that a printed matrix of power or power_trace has (found by trying the
   whole numbers as far as 3 in det(A - t I)), differ in size and neither is
   0; such a printed matrix is not triangular; the trace of the matrix of
   power_trace is not 0 or 1 and its power is not the answer; the matrix of
   a combination is not a multiple of the identity; the eigenvectors of
   on_eigenvectors are the columns (1, p) and (q, p q + 1) of a matrix of
   determinant 1 without a 0.

   The ranges are pinned by going through every question the grammar may
   ask, in the test's own way: each choice of the numbers is taken, the
   answer is found as above, and the choice is kept where the promises hold
   (an entry within 900, an inverse that exists, a mistake that is not the
   right answer, a trace that is not 1). What is noted of the questions
   generated must then be exactly what is noted of the questions kept:
   everything that should come up does, and nothing else.
   - eigenvalues_of_*: the 24 pairs of eigenvalues from -3 to 3 without 0 and
     of different sizes, each with each power from 2 to 4 and with each c
     from -5 to 5 but 0: all 72, 24 and 240 questions come up. c is written
     as "+ 2I", "- I".
   - the four kinds from three eigenvalues: all 216 triples from -3 to 3
     without 0 come up in every kind, but in trace_of_square the six whose
     trace squared is the trace of the square, which never do.
   - power: every one of the 288 matrices P D P^(-1), with P = (1, q; p,
     p q + 1) for p and q from -2 to 2 without 0 and p q not -1 and D of the
     24 pairs, with every power from 3 to 5 that keeps the entries within
     900: 768 questions, all of which come up.
   - power_trace: every such matrix whose trace is not 1 (240 of them) with
     every power from 3 to 6: 960 questions, all of which come up.
   - combination_*: the diagonal entries go from -4 to 4, the others too but
     are not 0; each two entries take each two values that some question
     kept has, in every kind. So does the determinant, as far as 6 either
     way and beyond, together with the sign of the trace; a matrix without
     an inverse comes up for the powers with every entry it can have, and
     never for the inverse. Whether alpha and beta go beyond 800 is noted
     as well: only beta does, and only in combination_fourth.
   - one_eigenvalue: a from -3 to 3 and b from -4 to 4, neither 0, n from 3
     to 6, on either side of the diagonal; all 336 questions that keep the
     entries within 900 come up.
   - on_eigenvectors: the 14 pairs p, q, the 24 pairs of eigenvalues, the
     coefficients from -3 to 3 without 0 and the powers from 2 to 5, in the
     twos and threes that of_eigenvectors lists, and whether each entry of
     the answer goes beyond 800: both do. v is written as "-u_1 + 3u_2".
   The run is long enough for the rarest of these to be expected about a
   dozen times. The grammar declares the five mistakes in the order given
   here. The weights of the forms are not tested. *)

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
let without_zero limit = List.filter (fun x -> x <> 0) (between (-limit) limit)

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
let in_order a b = if a = b then 0 else if less a b then -1 else 1

(* x to the power n, by multiplying n times. *)
let rec raised x n = if n <= 0 then one else x *: raised x (n - 1)

(* The square root of a fraction that is the square of a fraction. *)
let exact_root x =
  let root n =
    let near = int_of_float (sqrt (float_of_int n)) in
    List.find_opt (fun r -> r >= 0 && r * r = n) [ near - 1; near; near + 1 ]
  in
  if x.top < 0 then None
  else match (root x.top, root x.bottom) with Some top, Some bottom -> Some (fraction top bottom) | _ -> None

(* No number of the list is beyond the limit in size. *)
let within limit = List.for_all (fun x -> not (less (whole limit) (absolute x)))

(* ---- Vectors and matrices ------------------------------------------------ *)

(* A vector is a list of fractions and a matrix the list of its rows. *)
let exact = List.map whole
let plus = List.map2 ( +: )
let minus = List.map2 ( -: )
let scale k = List.map (fun x -> k *: x)
let dot a b = List.fold_left ( +: ) zero (List.map2 ( *: ) a b)
let apply matrix v = List.map (fun row -> dot row v) matrix

let columns rows =
  match rows with
  | [] -> []
  | first :: _ -> List.mapi (fun place _ -> List.map (fun row -> List.nth row place) rows) first

let times a b =
  let across = columns b in
  List.map (fun row -> List.map (dot row) across) a

let identity size = List.init size (fun i -> List.init size (fun j -> if i = j then one else zero))
let diagonal values = List.mapi (fun i x -> List.mapi (fun j _ -> if i = j then x else zero) values) values
let sum a b = List.map2 plus a b
let multiple k = List.map (scale k)
let trace a = List.fold_left ( +: ) zero (List.mapi (fun i row -> List.nth row i) a)

(* A multiplied by itself: the product of n copies of it. *)
let rec power a n = if n <= 0 then identity (List.length a) else times (power a (n - 1)) a

(* The matrix with rows (a, b) and (c, d), from the four whole numbers. *)
let square = function [ a; b; c; d ] -> [ exact [ a; b ]; exact [ c; d ] ] | _ -> failwith "four entries were expected"

(* The whole numbers a matrix is made of. *)
let whole_entries a =
  List.map
    (fun x -> if x.bottom <> 1 then failwith ("a fraction where a whole number belongs: " ^ show x) else x.top)
    (List.concat a)

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

(* det(A - t I). *)
let characteristic a t = determinant (sum a (multiple (zero -: t) (identity (List.length a))))

(* The inverse, by elimination on (A | I) with exact row operations: when
   every column has got its pivot, the left half is I and the right half the
   inverse. None for a matrix without one. The result is tested from both
   sides. *)
let inverse a =
  let size = List.length a in
  let rec go with_pivot rest column =
    if column >= size then Some (List.rev with_pivot)
    else
      match List.partition (fun row -> List.nth row column <> zero) rest with
      | [], _ -> None
      | chosen :: others, without ->
          let pivot = scale (one /: List.nth chosen column) chosen in
          let clear row = minus row (scale (List.nth row column) pivot) in
          go (pivot :: List.map clear with_pivot) (List.map clear others @ without) (column + 1)
  in
  match go [] (List.map2 (fun row unit -> row @ unit) a (identity size)) 0 with
  | None -> None
  | Some reduced ->
      let found = List.map (List.filteri (fun place _ -> place >= size)) reduced in
      if times a found <> identity size || times found a <> identity size then
        failwith "the test's own inverse is not the inverse";
      Some found

(* F M F^(-1). *)
let framed frame middle =
  match inverse frame with
  | Some back -> times (times frame middle) back
  | None -> failwith "the test's own frame has no inverse"

(* Every entry off the diagonal is 0. *)
let is_diagonal a =
  List.for_all (fun kept -> kept) (List.concat (List.mapi (fun i row -> List.mapi (fun j x -> i = j || x = zero) row) a))

(* The eigenvalues of a 2 by 2 matrix: the roots of t^2 - tr t + det, by the
   quadratic formula with an exact square root. Each is tested in
   det(A - t I) = 0. The result is in increasing order, a double root once. *)
let eigenvalues a =
  let t = trace a and d = determinant a in
  match exact_root ((t *: t) -: (whole 4 *: d)) with
  | None -> failwith "the eigenvalues of the test's own matrix are not fractions"
  | Some root ->
      let found = [ (t -: root) /: whole 2; (t +: root) /: whole 2 ] in
      if List.exists (fun x -> characteristic a x <> zero) found then
        failwith "the test's own eigenvalues are not roots of the characteristic polynomial";
      List.sort_uniq in_order found

(* The whole numbers as far as the limit that are eigenvalues. *)
let whole_eigenvalues limit a = List.filter (fun t -> characteristic a (whole t) = zero) (between (-limit) limit)

(* ---- The eigenvalues of what is done to a matrix that is not shown ------- *)

type change = To_power of int | Inverted | Shifted of int

(* The two frames: one of determinant -2, with which the matrix built has
   fractions in it, and one of determinant 1. *)
let frames = [ square [ 1; 2; 3; 4 ]; square [ 2; 1; 5; 3 ] ]

let worked = Hashtbl.create 512

let spectrum_of change first second =
  match Hashtbl.find_opt worked (change, first, second) with
  | Some result -> result
  | None ->
      let stated = List.sort_uniq in_order [ whole first; whole second ] in
      let found =
        List.map
          (fun frame ->
            let a = framed frame (diagonal (exact [ first; second ])) in
            if is_diagonal a then failwith "the test's own matrix is diagonal";
            if eigenvalues a <> stated then failwith "the test's own matrix does not have the stated eigenvalues";
            let changed =
              match change with
              | To_power n -> power a n
              | Inverted -> (
                  match inverse a with Some back -> back | None -> failwith "a matrix with these eigenvalues has no inverse")
              | Shifted c -> sum a (multiple (whole c) (identity 2))
            in
            eigenvalues changed)
          frames
      in
      let result =
        match found with
        | [ one_way; another ] when one_way = another -> one_way
        | _ -> failwith "the test's two matrices do not agree on the eigenvalues"
      in
      Hashtbl.replace worked (change, first, second) result;
      result

(* ---- A 3 by 3 matrix with three stated eigenvalues ----------------------- *)

let frame_of_three = [ exact [ 1; 1; 0 ]; exact [ 1; 2; 1 ]; exact [ 2; 1; 3 ] ]
let of_three = Hashtbl.create 256

(* The determinant and the trace of the matrix, and of its square. *)
let from_three a b c =
  match Hashtbl.find_opt of_three (a, b, c) with
  | Some result -> result
  | None ->
      let middles = [ diagonal (exact [ a; b; c ]); [ exact [ a; 1; 2 ]; exact [ 0; b; -1 ]; exact [ 0; 0; c ] ] ] in
      let found =
        List.mapi
          (fun which middle ->
            let m = framed frame_of_three middle in
            if which = 1 && is_diagonal m then failwith "the test's own matrix is diagonal";
            (* two polynomials of degree 3 that both begin with t^3 and agree
               at four points are the same *)
            List.iter
              (fun t ->
                let of_t = determinant (sum (multiple (whole t) (identity 3)) (multiple (whole (-1)) m)) in
                if of_t <> whole ((t - a) * (t - b) * (t - c)) then
                  failwith "the test's own matrix does not have the stated eigenvalues")
              [ 0; 1; 5; -7 ];
            let squared = times m m in
            (determinant m, trace m, determinant squared, trace squared))
          middles
      in
      let result =
        match found with
        | [ one_way; another ] when one_way = another -> one_way
        | _ -> failwith "the test's two matrices do not agree"
      in
      Hashtbl.replace of_three (a, b, c) result;
      result

let kinds_of_three = [ "determinant"; "trace"; "determinant_of_square"; "trace_of_square" ]

(* ---- The matrices that are shown for their powers ------------------------ *)

(* The pairs p, q of a matrix (1, q; p, p q + 1), and the pairs of
   eigenvalues. *)
let unit_pairs =
  List.concat_map
    (fun p -> List.filter_map (fun q -> if p * q <> -1 then Some (p, q) else None) (without_zero 2))
    (without_zero 2)

let spectra =
  List.concat_map
    (fun first -> List.filter_map (fun second -> if abs first <> abs second then Some (first, second) else None) (without_zero 3))
    (without_zero 3)

(* Every matrix P D P^(-1), by the test's own inverse, as its four whole
   entries. Some come from two choices of P and D. *)
let shown_matrices =
  List.sort_uniq compare
    (List.concat_map
       (fun (p, q) ->
         List.map
           (fun (first, second) -> whole_entries (framed (square [ 1; q; p; (p * q) + 1 ]) (diagonal (exact [ first; second ]))))
           spectra)
       unit_pairs)

let built = Hashtbl.create 512
let () = List.iter (fun shown -> Hashtbl.replace built shown ()) shown_matrices

(* ---- A power as a combination of the matrix and the identity ------------- *)

(* The power (3 or 4) or the inverse (-1) of the matrix is worked out, alpha
   is read off an entry where the identity has 0, or off the difference of
   the diagonal entries, and beta off the first entry. The pair is tested on
   all four entries. None where the matrix has no inverse, or is a multiple
   of the identity so that the pair is not the only one. *)
let combined which entries =
  let a = square entries in
  let target = if which < 0 then inverse a else Some (power a which) in
  match (target, a) with
  | Some ([ [ t11; t12 ]; [ t21; t22 ] ] as target), [ [ a11; a12 ]; [ a21; a22 ] ] -> (
      let alpha =
        if a12 <> zero then Some (t12 /: a12)
        else if a21 <> zero then Some (t21 /: a21)
        else if a11 <> a22 then Some ((t11 -: t22) /: (a11 -: a22))
        else None
      in
      match alpha with
      | None -> None
      | Some alpha ->
          let beta = t11 -: (alpha *: a11) in
          if sum (multiple alpha a) (multiple beta (identity 2)) <> target then
            failwith "the test's own combination does not give the matrix it should";
          Some [ alpha; beta ])
  | _ -> None

let kinds_of_combination = [ ("combination_cube", 3); ("combination_fourth", 4); ("combination_inverse", -1) ]

(* ---- A triangular matrix with one eigenvalue ----------------------------- *)

(* (a, b; 0, a) on side 0 and (a, 0; b, a) on side 1. *)
let one_sided a b side = if side = 0 then [ a; b; 0; a ] else [ a; 0; b; a ]

(* ---- A power applied to a combination of eigenvectors -------------------- *)

(* The one matrix with the eigenvectors u_1 and u_2 for the eigenvalues, the
   vector v = c_1 u_1 + c_2 u_2, and the matrix applied to it n times and
   once. *)
let carried u1 u2 (first, second) (c1, c2) n =
  match inverse (columns [ u1; u2 ]) with
  | None -> failwith "the two eigenvectors are not independent"
  | Some back ->
      let a = times (times (columns [ u1; u2 ]) (diagonal (exact [ first; second ]))) back in
      if apply a u1 <> scale (whole first) u1 || apply a u2 <> scale (whole second) u2 then
        failwith "the test's own matrix does not have the eigenvectors";
      let v = plus (scale (whole c1) u1) (scale (whole c2) u2) in
      let rec go v times_left = if times_left <= 0 then v else go (apply a v) (times_left - 1) in
      (go v n, apply a v)

(* ---- The engine's answers ----------------------------------------------- *)

type answer = Number of fraction | Arrow of fraction list | Table of fraction list list | Group of fraction list

let of_number (n : Rhema_number.t) = fraction n.Rhema_number.numerator n.Rhema_number.denominator
let group values = Group (List.sort_uniq in_order values)

let read = function
  | Rhema_engine.Num n -> Number (of_number n)
  | Rhema_engine.Vector v -> Arrow (List.map of_number (Rhema_vector.components v))
  | Rhema_engine.Matrix m -> Table (List.map (List.map of_number) (Rhema_matrix.entries m))
  | Rhema_engine.Set (Rhema_set.Finite elements) -> group (List.map of_number elements)
  | other -> failwith ("neither a number, a vector, a matrix nor a finite set: " ^ Rhema_engine.describe_value other)

let show_row row = String.concat ", " (List.map show row)

let show_answer = function
  | Number n -> show n
  | Arrow v -> "<" ^ show_row v ^ ">"
  | Table rows -> "[" ^ String.concat "; " (List.map show_row rows) ^ "]"
  | Group elements -> "{" ^ show_row elements ^ "}"

(* The numbers an answer is made of, in order; those of a set in increasing
   order. *)
let entries = function Number n -> [ n ] | Arrow v -> v | Table rows -> List.concat rows | Group elements -> elements

(* A marker with a tolerance of one part in a thousand must not take the
   mistaken answer for the right one: some entry is more than 1% away. A
   right answer that is a whole number is written so that no other whole
   number passes for it: there the mistake is to be another number and, below
   1000, more than 0.2% away. *)
let apart mistaken right =
  match (mistaken, right) with
  | Number wrong, Number good when good.bottom = 1 ->
      wrong <> good && (less (whole 999) (absolute good) || less (absolute good) (whole 500 *: absolute (wrong -: good)))
  | _ ->
      let theirs = entries mistaken and ours = entries right in
      List.length theirs <> List.length ours
      || List.exists2 (fun wrong good -> less (absolute good) (whole 100 *: absolute (wrong -: good))) theirs ours

(* ---- Reading the question ----------------------------------------------- *)

(* The fields of a prompt: the pattern is the whole sentence, with a group
   wherever a number of the question stands. *)
let words = Str.quote
let a_whole = "\\(0\\|-?[1-9][0-9]*\\)"
let a_count = "\\([1-9][0-9]*\\)"

(* A number that multiplies a letter: no digit where it is 1. *)
let a_factor = "\\([2-9]?\\)"
let a_sign = "\\([-+]\\)"
let a_matrix =
  words "\\begin{pmatrix} " ^ a_whole ^ " & " ^ a_whole ^ words " \\\\ " ^ a_whole ^ " & " ^ a_whole ^ words " \\end{pmatrix}"
let an_arrow = words "\\langle " ^ a_whole ^ ", " ^ a_whole ^ words " \\rangle"

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

let two_stated =
  words "A [`2`] by [`2`] matrix [`A`] has the eigenvalues [`" ^ a_whole ^ words "`] and [`" ^ a_whole
  ^ words "`]. Find the eigenvalues of [`"

let as_a_set = words "`]. Enter them as a set: in braces, with a comma between them."

let three_stated =
  words "A [`3`] by [`3`] matrix [`A`] has the eigenvalues [`" ^ a_whole ^ words "`], [`" ^ a_whole ^ words "`] and [`" ^ a_whole
  ^ words "`], counted as often as they occur. Find "

let asked_of_three =
  [ ("determinant", "[`\\det A`]."); ("trace", "the trace of [`A`]."); ("determinant_of_square", "[`\\det(A^{2})`].");
    ("trace_of_square", "the trace of [`A^{2}`].") ]

let power_of_shown lead = words lead ^ a_count ^ words "}`] for [`A = " ^ a_matrix ^ words "`]."

let asked_of_combination =
  [ ("combination_cube", ". Find the numbers with [`A^{3} = \\alpha A + \\beta I`].");
    ("combination_fourth", ". Find the numbers with [`A^{4} = \\alpha A + \\beta I`].");
    ("combination_inverse", ", and so is its inverse. Find the numbers with [`A^{-1} = \\alpha A + \\beta I`].") ]

let a_combination ending =
  words "By the Cayley-Hamilton theorem, every power of [`A = " ^ a_matrix
  ^ words "`] is a combination of [`A`] and the identity [`I`]"
  ^ words ending
  ^ words " Enter them as the vector [`\\langle \\alpha, \\beta \\rangle`]."

let on_two_eigenvectors =
  words "A matrix [`A`] has the eigenvector [`u_1 = " ^ an_arrow ^ words "`] for the eigenvalue [`" ^ a_whole
  ^ words "`] and the eigenvector [`u_2 = " ^ an_arrow ^ words "`] for the eigenvalue [`" ^ a_whole ^ words "`]. Find [`A^{"
  ^ a_count ^ words "} v`] for [`v = " ^ "\\(-?[2-9]?\\)" ^ words "u_1 " ^ a_sign ^ " " ^ a_factor ^ words "u_2`]."

(* ---- What is noted of a question ---------------------------------------- *)

(* The same is noted of a question that was generated and of a question the
   test finds the grammar may ask; the two collections must be the same. *)
let noted = Hashtbl.create 4096
let expected = Hashtbl.create 4096
let note what = Hashtbl.replace noted what ()
let expect what = Hashtbl.replace expected what ()

(* How often something was generated. *)
let tallies = Hashtbl.create 16
let tally what = Hashtbl.replace tallies what (1 + Option.value ~default:0 (Hashtbl.find_opt tallies what))
let tallied what = Option.value ~default:0 (Hashtbl.find_opt tallies what)

let in_a_row values = String.concat ", " (List.map string_of_int values)

(* Each two numbers of a list, with their places. *)
let in_twos k name values =
  List.concat
    (List.mapi
       (fun i x ->
         List.concat
           (List.mapi
              (fun j y ->
                if j > i then [ Printf.sprintf "%s: %s %d is %d and %s %d is %d" k name (i + 1) x name (j + 1) y ] else [])
              values))
       values)

(* Whether each number of an answer is beyond 800 in size: the grammar keeps
   them within 900, and how far they do go is to be seen. *)
let how_large k name values =
  List.mapi
    (fun place x -> Printf.sprintf "%s: %s %d is %s 800" k name (place + 1) (if within 800 [ x ] then "within" else "beyond"))
    values

let of_spectrum k (first, second) change =
  [ (match change with
    | To_power n -> Printf.sprintf "%s: the eigenvalues %d and %d, to the power %d" k first second n
    | Inverted -> Printf.sprintf "%s: the eigenvalues %d and %d" k first second
    | Shifted c -> Printf.sprintf "%s: the eigenvalues %d and %d, with %d times the identity added" k first second c) ]

let of_three_stated k values = [ Printf.sprintf "%s: the eigenvalues %s" k (in_a_row values) ]

let of_power shown n = [ Printf.sprintf "power: (%s) to the power %d" (in_a_row shown) n ]

let of_power_trace shown n = [ Printf.sprintf "power_trace: (%s) to the power %d" (in_a_row shown) n ]

(* Of a combination: its entries in twos; its determinant as far as 6 either
   way, and with the sign of its trace (either may be 0 and the formula then
   loses a term); the entries of a matrix without an inverse; and how large
   the two numbers are. *)
let of_combination k shown found =
  let a = square shown in
  let d = determinant a and t = trace a in
  let sign x = compare x.top 0 in
  in_twos k "entry" shown
  @ [ (if within 6 [ d ] then Printf.sprintf "%s: the determinant is %s" k (show d)
       else Printf.sprintf "%s: the determinant is %s" k (if sign d > 0 then "above 6" else "below -6"));
      Printf.sprintf "%s: the determinant has sign %d and the trace sign %d" k (sign d) (sign t) ]
  @ (if d = zero then List.mapi (fun place x -> Printf.sprintf "%s: no inverse, and entry %d is %d" k (place + 1) x) shown else [])
  @ how_large k "coefficient" found

let of_one_eigenvalue a b n side =
  [ Printf.sprintf "one_eigenvalue: %d on the diagonal and %d beside it on side %d, to the power %d" a b side n ]

let of_eigenvectors (p, q) (first, second) (c1, c2) n image =
  let k = "on_eigenvectors" in
  [ Printf.sprintf "%s: p = %d, q = %d, first coefficient %d" k p q c1;
    Printf.sprintf "%s: p = %d, q = %d, second coefficient %d" k p q c2;
    Printf.sprintf "%s: p = %d, q = %d, first eigenvalue %d" k p q first;
    Printf.sprintf "%s: p = %d, q = %d, second eigenvalue %d" k p q second;
    Printf.sprintf "%s: the eigenvalues %d and %d, to the power %d" k first second n;
    Printf.sprintf "%s: the eigenvalues %d and %d, first coefficient %d" k first second c1;
    Printf.sprintf "%s: the eigenvalues %d and %d, second coefficient %d" k first second c2;
    Printf.sprintf "%s: the coefficients %d and %d, to the power %d" k c1 c2 n ]
  @ how_large k "entry" image

(* Every question the grammar may ask, found in the test's own way, and what
   is to be noted of it. *)
let expect_all () =
  let expecting = List.iter expect in
  List.iter
    (fun pair ->
      List.iter (fun n -> expecting (of_spectrum "eigenvalues_of_power" pair (To_power n))) (between 2 4);
      expecting (of_spectrum "eigenvalues_of_inverse" pair Inverted);
      List.iter (fun c -> expecting (of_spectrum "eigenvalues_of_shift" pair (Shifted c))) (without_zero 5))
    spectra;
  let small = without_zero 3 in
  List.iter
    (fun a ->
      List.iter
        (fun b ->
          List.iter
            (fun c ->
              let _, sum_of_three, _, of_square = from_three a b c in
              List.iter
                (fun k ->
                  (* the mistake is not to give the right answer *)
                  if k <> "trace_of_square" || sum_of_three *: sum_of_three <> of_square then
                    expecting (of_three_stated k [ a; b; c ]))
                kinds_of_three)
            small)
        small)
    small;
  List.iter
    (fun shown ->
      let a = square shown in
      List.iter (fun n -> if within 900 (List.concat (power a n)) then expecting (of_power shown n)) (between 3 5);
      if trace a <> one then List.iter (fun n -> expecting (of_power_trace shown n)) (between 3 6))
    shown_matrices;
  let on_diagonal = between (-4) 4 and beside = without_zero 4 in
  List.iter
    (fun a11 ->
      List.iter
        (fun a12 ->
          List.iter
            (fun a21 ->
              List.iter
                (fun a22 ->
                  let shown = [ a11; a12; a21; a22 ] in
                  List.iter
                    (fun (k, which) ->
                      match combined which shown with
                      | Some found when within 900 found -> expecting (of_combination k shown found)
                      | _ -> ())
                    kinds_of_combination)
                on_diagonal)
            beside)
        beside)
    on_diagonal;
  List.iter
    (fun a ->
      List.iter
        (fun b ->
          List.iter
            (fun n ->
              List.iter
                (fun side ->
                  if within 900 (List.concat (power (square (one_sided a b side)) n)) then
                    expecting (of_one_eigenvalue a b n side))
                [ 0; 1 ])
            (between 3 6))
        (without_zero 4))
    (without_zero 3);
  List.iter
    (fun (p, q) ->
      let u1 = exact [ 1; p ] and u2 = exact [ q; (p * q) + 1 ] in
      List.iter
        (fun pair ->
          List.iter
            (fun c1 ->
              List.iter
                (fun c2 ->
                  List.iter
                    (fun n ->
                      let image, _ = carried u1 u2 pair (c1, c2) n in
                      if within 900 image then expecting (of_eigenvectors (p, q) pair (c1, c2) n image))
                    (between 2 5))
                small)
            small)
        spectra)
    unit_pairs

(* The right answer is tested here by what defines it. The result is the
   WeBWorK context the form needs and the answer of each mistake the form is
   open to, worked out from the printed question. *)
let check (q : Rhema_engine.question) got =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what (show_answer got) p) in
  let numbers = List.map int_of_string in
  let noting = List.iter note in
  (* two eigenvalues differ in size and neither is 0 *)
  let two_eigenvalues first second =
    if first = 0 || second = 0 then wrong "an eigenvalue is 0";
    if abs first = abs second then wrong "the two eigenvalues have the same size"
  in
  match k with
  | "eigenvalues_of_power" | "eigenvalues_of_inverse" | "eigenvalues_of_shift" ->
      let first, second, change =
        match k with
        | "eigenvalues_of_power" -> (
            match numbers (fields 3 (two_stated ^ words "A^{" ^ a_count ^ words "}" ^ as_a_set) p) with
            | [ first; second; n ] -> (first, second, To_power n)
            | _ -> failwith "three fields were expected")
        | "eigenvalues_of_inverse" -> (
            match numbers (fields 2 (two_stated ^ words "A^{-1}" ^ as_a_set) p) with
            | [ first; second ] -> (first, second, Inverted)
            | _ -> failwith "two fields were expected")
        | _ -> (
            match fields 4 (two_stated ^ "A " ^ a_sign ^ " " ^ a_factor ^ "I" ^ as_a_set) p with
            | [ first; second; sign; size ] ->
                let size = if size = "" then 1 else int_of_string size in
                (int_of_string first, int_of_string second, Shifted (if sign = "-" then -size else size))
            | _ -> failwith "four fields were expected")
      in
      two_eigenvalues first second;
      let found = spectrum_of change first second in
      if got <> Group found then wrong ("the matrices built have the eigenvalues " ^ show_row found);
      if List.length found <> 2 then wrong "not two eigenvalues";
      noting (of_spectrum k (first, second) change);
      ( "Interval",
        match change with
        | To_power n -> [ ("multiplied_by_power", group (exact [ n * first; n * second ])) ]
        | Inverted -> [ ("negative_for_inverse", group (exact [ -first; -second ])) ]
        | Shifted _ -> [] )
  | "determinant" | "trace" | "determinant_of_square" | "trace_of_square" -> (
      match numbers (fields 3 (three_stated ^ words (List.assoc k asked_of_three)) p) with
      | [ a; b; c ] as stated ->
          if List.mem 0 stated then wrong "an eigenvalue is 0";
          let product, sum_of_three, of_product, of_square = from_three a b c in
          let found, slips =
            match k with
            | "determinant" -> (product, [])
            | "trace" -> (sum_of_three, [])
            | "determinant_of_square" -> (of_product, [])
            | _ -> (of_square, [ ("power_outside", Number (sum_of_three *: sum_of_three)) ])
          in
          if got <> Number found then wrong ("the matrices built give " ^ show found);
          noting (of_three_stated k stated);
          ("Numeric", slips)
      | _ -> failwith "three fields were expected")
  | "power" | "power_trace" -> (
      let lead = if k = "power" then "Find [`A^{" else "Find the trace of [`A^{" in
      match numbers (fields 5 (power_of_shown lead) p) with
      | [ n; a11; a12; a21; a22 ] ->
          let shown = [ a11; a12; a21; a22 ] in
          let a = square shown in
          if a12 = 0 || a21 = 0 then wrong "the matrix shown is triangular";
          (match whole_eigenvalues 3 a with
          | [ first; second ] -> two_eigenvalues first second
          | _ -> wrong "the matrix shown does not have two whole eigenvalues as far as 3");
          if not (Hashtbl.mem built shown) then wrong "the matrix shown is not P D P^(-1) with a P and a D of the grammar";
          let product = power a n in
          if k = "power" then begin
            if got <> Table product then wrong ("multiplying out gives " ^ show_answer (Table product));
            noting (of_power shown n);
            ("Matrix", [ ("entries_raised", Table (List.map (List.map (fun x -> raised x n)) a)) ])
          end
          else begin
            let t = trace a in
            if t = zero || t = one then wrong "the trace of the matrix shown is 0 or 1";
            if got <> Number (trace product) then wrong ("multiplying out gives the trace " ^ show (trace product));
            noting (of_power_trace shown n);
            ("Numeric", [ ("power_outside", Number (raised t n)) ])
          end
      | _ -> failwith "five fields were expected")
  | "combination_cube" | "combination_fourth" | "combination_inverse" -> (
      match numbers (fields 4 (a_combination (List.assoc k asked_of_combination)) p) with
      | [ a11; a12; a21; a22 ] as shown ->
          if a12 = 0 && a21 = 0 && a11 = a22 then wrong "the matrix is a multiple of the identity";
          (match combined (List.assoc k kinds_of_combination) shown with
          | None -> wrong "the matrix has no inverse, or more than one pair of numbers will do"
          | Some found ->
              if got <> Arrow found then wrong ("working it out gives " ^ show_row found);
              noting (of_combination k shown found));
          ("Vector", [])
      | _ -> failwith "four fields were expected")
  | "one_eigenvalue" -> (
      match numbers (fields 5 (power_of_shown "Find [`A^{") p) with
      | [ n; a11; a12; a21; a22 ] ->
          let a = square [ a11; a12; a21; a22 ] in
          if a11 <> a22 then wrong "the two entries on the diagonal differ";
          if (a12 = 0) = (a21 = 0) then wrong "not exactly one entry beside the diagonal is 0";
          if whole_eigenvalues 4 a <> [ a11 ] then wrong "the entry on the diagonal is not the one eigenvalue";
          let side = if a21 = 0 then 0 else 1 in
          let product = power a n in
          if got <> Table product then wrong ("multiplying out gives " ^ show_answer (Table product));
          noting (of_one_eigenvalue a11 (if side = 0 then a12 else a21) n side);
          ("Matrix", [ ("entries_raised", Table (List.map (List.map (fun x -> raised x n)) a)) ])
      | _ -> failwith "five fields were expected")
  | "on_eigenvectors" -> (
      match fields 10 on_two_eigenvectors p with
      | [ x1; y1; first; x2; y2; second; n; c1; sign; c2 ] ->
          let x1 = int_of_string x1 and y1 = int_of_string y1 and x2 = int_of_string x2 and y2 = int_of_string y2 in
          let first = int_of_string first and second = int_of_string second and n = int_of_string n in
          let c1 = match c1 with "" -> 1 | "-" -> -1 | digits -> int_of_string digits in
          let c2 = (if sign = "-" then -1 else 1) * if c2 = "" then 1 else int_of_string c2 in
          two_eigenvalues first second;
          let u1 = exact [ x1; y1 ] and u2 = exact [ x2; y2 ] in
          if x1 <> 1 || y2 <> (y1 * x2) + 1 then wrong "the eigenvectors are not (1, p) and (q, p q + 1)";
          if List.mem 0 [ x1; y1; x2; y2 ] then wrong "a 0 in an eigenvector";
          if determinant (columns [ u1; u2 ]) <> one then wrong "the eigenvectors do not make a matrix of determinant 1";
          let image, once = carried u1 u2 (first, second) (c1, c2) n in
          if got <> Arrow image then wrong ("applying the matrix gives " ^ show_row image);
          noting (of_eigenvectors (y1, x2) (first, second) (c1, c2) n image);
          ("Vector", [ ("power_dropped", Arrow once) ])
      | _ -> failwith "ten fields were expected")
  | k -> failwith ("unknown kind " ^ k)

(* The mistakes as the grammar's header describes them, in the order it
   declares them. *)
let described =
  [ ("multiplied_by_power", "multiplies each eigenvalue by the power, where it is raised to the power");
    ("negative_for_inverse", "changes the sign of each eigenvalue for the inverse, where its reciprocal belongs");
    ("power_outside", "raises the trace to the power, where the trace of the power is asked for");
    ("entries_raised", "raises each entry of the matrix to the power");
    ("power_dropped", "applies the matrix once, where a power of it is asked for") ]

let () =
  let base = load_file "matrix_powers.rhm" in
  (* The grammar declares these mistakes, in this order, and no other. *)
  if base.Rhema_check.mistakes <> described then fail "the mistakes declared are not the five of the header, in its order";
  let prices =
    [ ("eigenvalues_of_power", 1); ("eigenvalues_of_inverse", 1); ("eigenvalues_of_shift", 1); ("determinant", 1); ("trace", 1);
      ("determinant_of_square", 1); ("trace_of_square", 1); ("power", 2); ("power_trace", 2); ("combination_cube", 3);
      ("combination_fourth", 3); ("combination_inverse", 3); ("one_eigenvalue", 3); ("on_eigenvectors", 3) ]
  in
  (* the kinds whose answer may have a fraction in it *)
  let with_fractions = [ "eigenvalues_of_inverse"; "combination_inverse" ] in
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
                | Number _, "Numeric" | Arrow _, "Vector" | Table _, "Matrix" | Group _, "Interval" -> ()
                | _ ->
                    fail (Printf.sprintf "%s: the answer %s is not what the context %s holds" k (show_answer got) context));
                (match Rhema_engine.attribute q.Rhema_engine.tree "pg_context" with
                | Rhema_engine.Text c when c = context -> ()
                | Rhema_engine.Text c -> fail (Printf.sprintf "%s: pg_context is %s, not %s" k c context)
                | _ -> fail (k ^ ": pg_context is not a text"));
                if q.Rhema_engine.context <> context then
                  fail (Printf.sprintf "%s: the question is in context %s, not %s" k q.Rhema_engine.context context);
                (* no entry of a set, a matrix or a vector is beyond 900 *)
                (match got with
                | Number _ -> ()
                | _ ->
                    if not (within 900 (entries got)) then
                      fail (Printf.sprintf "%s: the answer %s has an entry beyond 900, for %S" k (show_answer got) p));
                (* a fraction is asked for in two kinds only *)
                if List.exists (fun x -> x.bottom <> 1) (entries got) then begin
                  tally (k ^ " with a fraction");
                  if not (List.mem k with_fractions) then
                    fail (Printf.sprintf "%s: the answer %s has a fraction in it, for %S" k (show_answer got) p)
                end;
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
                        (Printf.sprintf "%s: %s gives %s, too near the answer %s, for %S" k name (show_answer slip)
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
  let per_budget = 50000 in
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
    [ "multiplied_by_power on eigenvalues_of_power"; "negative_for_inverse on eigenvalues_of_inverse";
      "power_outside on trace_of_square"; "entries_raised on power"; "power_outside on power_trace";
      "entries_raised on one_eigenvalue"; "power_dropped on on_eigenvectors" ];
  List.iter (fun k -> if tallied (k ^ " with a fraction") = 0 then fail (k ^ ": no answer with a fraction in it")) with_fractions;
  (* The test's own lists. *)
  if List.length unit_pairs <> 14 then fail "the test's own list of pairs p, q does not hold 14 pairs";
  if List.length spectra <> 24 then fail "the test's own list of pairs of eigenvalues does not hold 24 pairs";
  if List.length shown_matrices <> 288 then fail "the test's own list of matrices P D P^(-1) does not hold 288 matrices";
  (* Everything the grammar may ask comes up, and nothing else. *)
  expect_all ();
  let expected_of k =
    let start = k ^ ": " in
    let size = String.length start in
    Hashtbl.fold
      (fun what () count -> if String.length what >= size && String.sub what 0 size = start then count + 1 else count)
      expected 0
  in
  List.iter
    (fun (k, count) ->
      if expected_of k <> count then
        fail (Printf.sprintf "the test's own list for %s holds %d questions, not %d" k (expected_of k) count))
    [ ("eigenvalues_of_power", 72); ("eigenvalues_of_inverse", 24); ("eigenvalues_of_shift", 240); ("determinant", 216);
      ("trace", 216); ("determinant_of_square", 216); ("trace_of_square", 210); ("power", 768); ("power_trace", 960);
      ("one_eigenvalue", 336) ];
  Hashtbl.iter (fun what () -> if not (Hashtbl.mem noted what) then fail ("never generated: " ^ what)) expected;
  Hashtbl.iter (fun what () -> if not (Hashtbl.mem expected what) then fail ("not a choice of the grammar: " ^ what)) noted;
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
  if !failures = 0 then print_endline "Rhema matrix_powers tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d matrix_powers test(s) failed." !failures);
    exit 1
  end
