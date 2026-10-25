(* Checks on the matrix library against identities a textbook states, over
   random small integer matrices. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let random_matrix size =
  Rhema_matrix.make (List.init size (fun _ -> List.init size (fun _ -> Rhema_number.of_int (Random.int 11 - 5))))

let check label condition = if not condition then fail label

let () =
  Random.init 7;
  for trial = 1 to 200 do
    let size = 2 + Random.int 2 in
    let a = random_matrix size and b = random_matrix size in
    let det_a = Rhema_matrix.determinant a and det_b = Rhema_matrix.determinant b in
    let label text = Printf.sprintf "trial %d (%dx%d): %s" trial size size text in
    (* det(AB) = det A det B *)
    check (label "det(AB) = det A det B")
      (Rhema_number.equal (Rhema_matrix.determinant (Rhema_matrix.multiply a b)) (Rhema_number.multiply det_a det_b));
    (* (AB)^T = B^T A^T *)
    check (label "(AB)^T = B^T A^T")
      (Rhema_matrix.equal (Rhema_matrix.transpose (Rhema_matrix.multiply a b))
         (Rhema_matrix.multiply (Rhema_matrix.transpose b) (Rhema_matrix.transpose a)));
    (* det(kA) = k^n det A *)
    let k = Rhema_number.of_int 3 in
    check (label "det(3A) = 3^n det A")
      (Rhema_number.equal (Rhema_matrix.determinant (Rhema_matrix.scale k a))
         (Rhema_number.multiply (Rhema_number.power k (Rhema_number.of_int size)) det_a));
    (* (A^T)^T = A, A + B - B = A *)
    check (label "(A^T)^T = A") (Rhema_matrix.equal (Rhema_matrix.transpose (Rhema_matrix.transpose a)) a);
    check (label "A + B - B = A") (Rhema_matrix.equal (Rhema_matrix.subtract (Rhema_matrix.add a b) b) a);
    (* A A^-1 = I and A^-1 A = I when A is invertible *)
    if Rhema_matrix.is_invertible a then begin
      let inverse = Rhema_matrix.inverse a in
      check (label "A A^-1 = I") (Rhema_matrix.equal (Rhema_matrix.multiply a inverse) (Rhema_matrix.identity size));
      check (label "A^-1 A = I") (Rhema_matrix.equal (Rhema_matrix.multiply inverse a) (Rhema_matrix.identity size));
      check (label "det A^-1 = 1 / det A")
        (Rhema_number.equal (Rhema_matrix.determinant inverse) (Rhema_number.divide (Rhema_number.of_int 1) det_a))
    end
    else check (label "a singular matrix has determinant zero") (Rhema_number.is_zero det_a);
    (* A applied to a vector agrees with multiplication by a column *)
    let v = List.init size (fun _ -> Rhema_number.of_int (Random.int 7 - 3)) in
    let as_column = Rhema_matrix.make (List.map (fun x -> [ x ]) v) in
    check (label "A v = A [v]")
      (List.for_all2 Rhema_number.equal (Rhema_matrix.apply a v) (List.map List.hd (Rhema_matrix.multiply a as_column)))
  done;
  (* rendering *)
  let m = Rhema_matrix.make [ [ Rhema_number.of_int 1; Rhema_number.make 1 2 ]; [ Rhema_number.of_int (-3); Rhema_number.zero ] ] in
  check "pg rendering" (Rhema_matrix.to_pg m = "Matrix([[1,1/2],[-3,0]])");
  check "latex rendering"
    (Rhema_matrix.to_latex m = "\\begin{pmatrix} 1 & \\frac{1}{2} \\\\ -3 & 0 \\end{pmatrix}");
  (match Rhema_matrix.inverse (Rhema_matrix.make [ [ Rhema_number.of_int 1; Rhema_number.of_int 2 ]; [ Rhema_number.of_int 2; Rhema_number.of_int 4 ] ]) with
  | exception Invalid_argument _ -> ()
  | _ -> fail "a singular matrix was inverted");
  if !failures = 0 then print_endline "Ag matrix core tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d matrix core test(s) failed." !failures);
    exit 1
  end
