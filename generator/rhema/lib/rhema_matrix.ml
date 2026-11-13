(* rhema_matrix.ml -- exact matrices for linear-algebra questions.

   A matrix is a non-empty rectangular list of rows of exact rationals.
   Everything here is the schoolbook definition: cofactor expansion for the
   determinant, the adjugate for the inverse. Sizes stay small (2 to 4), so
   nothing cleverer is needed, and the schoolbook forms are what a test can
   check by hand. Shape errors raise Invalid_argument; the engine turns
   those into generation errors with the builtin's name. *)

type t = Rhema_number.t list list

let make rows =
  (match rows with
  | [] | [] :: _ -> invalid_arg "a matrix needs at least one row and one column"
  | first :: rest ->
      let width = List.length first in
      if List.exists (fun row -> List.length row <> width) rest then
        invalid_arg "every row of a matrix must have the same length");
  rows

let rows (matrix : t) = List.length matrix
let columns (matrix : t) = match matrix with [] -> 0 | row :: _ -> List.length row
let is_square matrix = rows matrix = columns matrix
let entries (matrix : t) = matrix

let equal (left : t) (right : t) =
  rows left = rows right && columns left = columns right
  && List.for_all2 (fun a b -> List.for_all2 Rhema_number.equal a b) left right

let map2 operation left right =
  if rows left <> rows right || columns left <> columns right then
    invalid_arg "the two matrices have different shapes";
  List.map2 (List.map2 operation) left right

let add = map2 Rhema_number.add
let subtract = map2 Rhema_number.subtract
let scale scalar matrix = List.map (List.map (Rhema_number.multiply scalar)) matrix

let rec transpose (matrix : t) : t =
  match matrix with
  | [] | [] :: _ -> []
  | rows -> List.map List.hd rows :: transpose (List.map List.tl rows)

let identity size =
  List.init size (fun i -> List.init size (fun j -> if i = j then Rhema_number.of_int 1 else Rhema_number.zero))

let multiply (left : t) (right : t) : t =
  if columns left <> rows right then
    invalid_arg "the matrices cannot be multiplied: the inner dimensions differ";
  let right_columns = transpose right in
  List.map
    (fun row ->
      List.map
        (fun column ->
          List.fold_left2 (fun total a b -> Rhema_number.add total (Rhema_number.multiply a b)) Rhema_number.zero row column)
        right_columns)
    left

(* The matrix with row i and column j (0-based) removed. *)
let minor (matrix : t) i j =
  matrix |> List.filteri (fun r _ -> r <> i)
  |> List.map (fun row -> List.filteri (fun c _ -> c <> j) row)

let rec determinant (matrix : t) =
  if not (is_square matrix) then invalid_arg "the determinant needs a square matrix";
  match matrix with
  | [ [ a ] ] -> a
  | [ [ a; b ]; [ c; d ] ] -> Rhema_number.subtract (Rhema_number.multiply a d) (Rhema_number.multiply b c)
  | first :: _ ->
      (* cofactor expansion along the first row *)
      List.fold_left
        (fun total (j, entry) ->
          let cofactor = determinant (minor matrix 0 j) in
          let signed = if j mod 2 = 0 then cofactor else Rhema_number.negate cofactor in
          Rhema_number.add total (Rhema_number.multiply entry signed))
        Rhema_number.zero
        (List.mapi (fun j entry -> (j, entry)) first)
  | [] -> invalid_arg "an empty matrix has no determinant"

let is_invertible matrix = is_square matrix && not (Rhema_number.is_zero (determinant matrix))

(* The adjugate divided by the determinant. *)
let inverse (matrix : t) : t =
  let det = determinant matrix in
  if Rhema_number.is_zero det then invalid_arg "the matrix is singular and has no inverse";
  let size = rows matrix in
  let cofactor i j =
    let value = determinant (minor matrix i j) in
    if (i + j) mod 2 = 0 then value else Rhema_number.negate value
  in
  (* entry (i, j) of the inverse is cofactor (j, i) / det *)
  List.init size (fun i -> List.init size (fun j -> Rhema_number.divide (cofactor j i) det))

(* A list of numbers as a matrix of one row, or of one column. *)
let of_row components : t = make [ components ]
let of_column components : t = make (List.map (fun component -> [ component ]) components)

(* One matrix above the other, and one beside the other (an augmented
   matrix [A | B]). *)
let stack (upper : t) (lower : t) : t =
  if columns upper <> columns lower then
    invalid_arg "the two matrices have different numbers of columns";
  upper @ lower

let augment (left : t) (right : t) : t =
  if rows left <> rows right then invalid_arg "the two matrices have different numbers of rows";
  List.map2 ( @ ) left right

(* The reduced row echelon form, by Gauss-Jordan elimination on exact
   rationals: each pivot is 1, the only non-zero entry of its column, and to
   the right of the pivot above it; rows of zeros are at the bottom. Also
   returns the pivot columns (0-based), whose number is the rank. *)
let reduce (matrix : t) : t * int list =
  let work = Array.of_list (List.map Array.of_list matrix) in
  let height = Array.length work and width = columns matrix in
  let pivots = ref [] and row = ref 0 in
  for column = 0 to width - 1 do
    if !row < height then begin
      let found = ref None in
      for candidate = height - 1 downto !row do
        if not (Rhema_number.is_zero work.(candidate).(column)) then found := Some candidate
      done;
      match !found with
      | None -> ()
      | Some candidate ->
          let pivot_row = work.(candidate) in
          work.(candidate) <- work.(!row);
          let pivot = pivot_row.(column) in
          let pivot_row = Array.map (fun entry -> Rhema_number.divide entry pivot) pivot_row in
          work.(!row) <- pivot_row;
          for other = 0 to height - 1 do
            if other <> !row then begin
              let factor = work.(other).(column) in
              if not (Rhema_number.is_zero factor) then
                work.(other) <-
                  Array.mapi
                    (fun j entry -> Rhema_number.subtract entry (Rhema_number.multiply factor pivot_row.(j)))
                    work.(other)
            end
          done;
          pivots := column :: !pivots;
          incr row
    end
  done;
  (Array.to_list (Array.map Array.to_list work), List.rev !pivots)

let row_echelon matrix = fst (reduce matrix)
let rank matrix = List.length (snd (reduce matrix))

let entry (matrix : t) i j =
  if i < 1 || i > rows matrix || j < 1 || j > columns matrix then
    invalid_arg (Printf.sprintf "there is no entry (%d, %d) in a %d by %d matrix" i j (rows matrix) (columns matrix));
  List.nth (List.nth matrix (i - 1)) (j - 1)

(* The matrix applied to a column vector, as a list of components. *)
let apply (matrix : t) components =
  if columns matrix <> List.length components then
    invalid_arg "the matrix and the vector have different sizes";
  List.map
    (fun row -> List.fold_left2 (fun total a x -> Rhema_number.add total (Rhema_number.multiply a x)) Rhema_number.zero row components)
    matrix

(* Row i (1-based) as a linear expression in x, y, z, w, written term by
   term with its sign, as a system of equations is written: 2x - y + 3z.
   Zero coefficients are left out; a row of zeros reads 0. *)
let row_latex (matrix : t) i =
  let names = [ "x"; "y"; "z"; "w" ] in
  if i < 1 || i > rows matrix then invalid_arg (Printf.sprintf "there is no row %d" i);
  if columns matrix > List.length names then invalid_arg "row_latex handles at most four unknowns";
  let magnitude value =
    let size = Rhema_number.absolute value in
    if Rhema_number.equal size (Rhema_number.of_int 1) then "" else Rhema_number.to_string size
  in
  let terms =
    List.nth matrix (i - 1)
    |> List.mapi (fun j coefficient -> (coefficient, List.nth names j))
    |> List.filter (fun (coefficient, _) -> not (Rhema_number.is_zero coefficient))
  in
  match terms with
  | [] -> "0"
  | (first, name) :: rest ->
      let head = (if Rhema_number.compare first Rhema_number.zero < 0 then "-" else "") ^ magnitude first ^ name in
      List.fold_left
        (fun text (coefficient, name) ->
          text ^ (if Rhema_number.compare coefficient Rhema_number.zero < 0 then " - " else " + ") ^ magnitude coefficient ^ name)
        head rest

let number_latex value =
  if Rhema_number.is_integer value then Rhema_number.to_string value
  else
    Printf.sprintf "%s\\frac{%d}{%d}"
      (if value.Rhema_number.numerator < 0 then "-" else "")
      (abs value.Rhema_number.numerator) value.Rhema_number.denominator

let to_latex (matrix : t) =
  "\\begin{pmatrix} "
  ^ String.concat " \\\\ " (List.map (fun row -> String.concat " & " (List.map number_latex row)) matrix)
  ^ " \\end{pmatrix}"

(* MathObjects: Matrix([[1,2],[3,4]]); a fraction is written as a quotient. *)
let to_pg (matrix : t) =
  "Matrix(["
  ^ String.concat "," (List.map (fun row -> "[" ^ String.concat "," (List.map Rhema_number.to_string row) ^ "]") matrix)
  ^ "])"
