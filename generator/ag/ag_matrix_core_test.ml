(* Checks on the matrix library against identities a textbook states, over
   random small integer matrices. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let random_matrix size =
  Ag_matrix.make (List.init size (fun _ -> List.init size (fun _ -> Ag_number.of_int (Random.int 11 - 5))))

let check label condition = if not condition then fail label

let () =
  Random.init 7;
  for trial = 1 to 200 do
    let size = 2 + Random.int 2 in
    let a = random_matrix size and b = random_matrix size in
    let det_a = Ag_matrix.determinant a and det_b = Ag_matrix.determinant b in
    let label text = Printf.sprintf "trial %d (%dx%d): %s" trial size size text in
    (* det(AB) = det A det B *)
    check (label "det(AB) = det A det B")
      (Ag_number.equal (Ag_matrix.determinant (Ag_matrix.multiply a b)) (Ag_number.multiply det_a det_b));
    (* (AB)^T = B^T A^T *)
    check (label "(AB)^T = B^T A^T")
      (Ag_matrix.equal (Ag_matrix.transpose (Ag_matrix.multiply a b))
         (Ag_matrix.multiply (Ag_matrix.transpose b) (Ag_matrix.transpose a)));
    (* det(kA) = k^n det A *)
    let k = Ag_number.of_int 3 in
    check (label "det(3A) = 3^n det A")
      (Ag_number.equal (Ag_matrix.determinant (Ag_matrix.scale k a))
         (Ag_number.multiply (Ag_number.power k (Ag_number.of_int size)) det_a));
    (* (A^T)^T = A, A + B - B = A *)
    check (label "(A^T)^T = A") (Ag_matrix.equal (Ag_matrix.transpose (Ag_matrix.transpose a)) a);
    check (label "A + B - B = A") (Ag_matrix.equal (Ag_matrix.subtract (Ag_matrix.add a b) b) a);
    (* A A^-1 = I and A^-1 A = I when A is invertible *)
    if Ag_matrix.is_invertible a then begin
      let inverse = Ag_matrix.inverse a in
      check (label "A A^-1 = I") (Ag_matrix.equal (Ag_matrix.multiply a inverse) (Ag_matrix.identity size));
      check (label "A^-1 A = I") (Ag_matrix.equal (Ag_matrix.multiply inverse a) (Ag_matrix.identity size));
      check (label "det A^-1 = 1 / det A")
        (Ag_number.equal (Ag_matrix.determinant inverse) (Ag_number.divide (Ag_number.of_int 1) det_a))
    end
    else check (label "a singular matrix has determinant zero") (Ag_number.is_zero det_a);
    (* A applied to a vector agrees with multiplication by a column *)
    let v = List.init size (fun _ -> Ag_number.of_int (Random.int 7 - 3)) in
    let as_column = Ag_matrix.make (List.map (fun x -> [ x ]) v) in
    check (label "A v = A [v]")
      (List.for_all2 Ag_number.equal (Ag_matrix.apply a v) (List.map List.hd (Ag_matrix.multiply a as_column)))
  done;
  (* rendering *)
  let m = Ag_matrix.make [ [ Ag_number.of_int 1; Ag_number.make 1 2 ]; [ Ag_number.of_int (-3); Ag_number.zero ] ] in
  check "pg rendering" (Ag_matrix.to_pg m = "Matrix([[1,1/2],[-3,0]])");
  check "latex rendering"
    (Ag_matrix.to_latex m = "\\begin{pmatrix} 1 & \\frac{1}{2} \\\\ -3 & 0 \\end{pmatrix}");
  (match Ag_matrix.inverse (Ag_matrix.make [ [ Ag_number.of_int 1; Ag_number.of_int 2 ]; [ Ag_number.of_int 2; Ag_number.of_int 4 ] ]) with
  | exception Invalid_argument _ -> ()
  | _ -> fail "a singular matrix was inverted");
  if !failures = 0 then print_endline "Ag matrix core tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d matrix core test(s) failed." !failures);
    exit 1
  end
