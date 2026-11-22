(* Independent checks for vector_calculus.rhm. Every question is matched
   against the whole sentence of its form (a text that cannot be read is a
   failure). The function or the field, the point, the direction, the segment
   and the rectangle are read back from it. A function is read term by term
   into a polynomial in x, y and z with exact fractions as coefficients; the
   derivatives are taken here, term by term, and the point is put in. Nothing
   of the grammar's working and nothing of the engine's differentiate is
   used. The result must be the engine's answer, exactly.

   - gradient: (f_x, f_y, f_z) at the point, a vector; not the zero vector.
     The function is not linear: a term printed has degree 2 or 3, and so a
     partial derivative, as a polynomial, is not a constant.
   - divergence: P_x + Q_y + R_z at the point; not 0. At least two of the
     three components hold their own variable (x in P, y in Q, z in R), so
     that their derivatives do not vanish as polynomials, and at least one
     of those is of degree 2 or 3. The sum P_x + Q_y + R_z itself, as a
     polynomial, is not a constant: (x^2, -2xy, 4z), whose shares cancel,
     is turned away by this.
   - curl: (R_y - Q_z, P_z - R_x, Q_x - P_y) at the point; at least two of
     the three components are not 0.
   - directional: the direction printed has whole length (its squared length
     is a perfect square); the answer is the gradient at the point dotted
     with the direction, divided by that length; not 0. The function is
     not linear, and the derivative along the direction, as a polynomial, is
     not a constant.
   - laplacian: f_xx + f_yy + f_zz at the point; not 0. Each of the two
     terms printed has a squared variable, so that the Laplacian of each
     alone is not the zero polynomial; at least one term is of degree 3;
     the Laplacian of the whole function, compared with zero exactly as a
     polynomial, is not zero (4x^2 y - 4y z^2 is turned away by this) and is
     not a constant.
   - segment_work: the field (a x + b y, c x + d y) and the two ends are
     read. The segment is r(t) = start + t (end - start); it is put into
     F . (end - start), which gives a polynomial in t, and that is
     integrated from 0 to 1. The midpoint is not used. The ends differ and
     the answer is not 0.
   - green: P, Q and the rectangle are read. The line integral is found
     directly, with no theorem, as four integrals along the four sides taken
     anticlockwise: the bottom from left to right (y = 0), the right side
     upward (x = m), the top from right to left (y = n), the left side
     downward (x = 0), each side put in as r(t) like a segment. The double
     integral of Q_x - P_y over the rectangle is found as well, by an
     antiderivative in x and then one in y, and the two must agree. The
     answer is not 0. P has y in it and Q has x, so that P_y and Q_x are
     both nonzero polynomials.

   Every answer is found a second way, in floats, with no derivative taken
   of anything: central difference quotients of the function or of the
   components of the field for the gradient, the divergence and the curl; a
   difference quotient of f along the unit direction for the directional
   derivative; second differences for the Laplacian; and for the two line
   integrals the sum of the field dotted with each of many small steps along
   the path. It must agree with the exact answer to a loose tolerance.

   The mistake not_normalised is found again from its description: the
   gradient dotted with the direction as printed, with no division. It must
   be listed on the directional form with that value, which is never the
   right answer, and be the only mistake there; no other form lists any.

   What the header promises is checked as well: terms c x^i y^j z^k of degree
   1 to 3, written the usual way (no coefficient 1, no power 1), a function
   of two different terms, a field of three terms, a point of whole
   coordinates, a direction that is one of the quadruples of the grammar with
   its first component positive, pg_context "Vector" exactly where the answer
   is a vector and "Numeric" elsewhere, a vector answer of whole numbers,
   every kind at its price and no other, the budget spent, a budget of 2
   where none is set, and no question at a budget outside 1 to 3. Every value
   of every number the forms draw must turn up where the form allows it, and
   no value outside its range. The shares of the forms are not pinned: each
   form must only turn up. *)

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

(* ---- Exact fractions --------------------------------------------------

   On OCaml integers, in lowest terms with a positive denominator, so that
   two equal fractions are equal as records. The numbers of these questions
   are small. *)
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
let ( /: ) a b = fraction (a.top * b.bottom) (a.bottom * b.top)
let to_float a = float a.top /. float a.bottom
let show a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom
let rec raised base n = if n = 0 then whole 1 else base *: raised base (n - 1)
let of_number n = fraction n.Rhema_number.numerator n.Rhema_number.denominator

(* ---- Polynomials in x, y and z -----------------------------------------

   A list of terms, each the three powers and a coefficient, with no term
   twice and no coefficient 0, in a fixed order: two equal polynomials are
   equal as lists, and the zero polynomial is the empty list. *)
type polynomial = ((int * int * int) * fraction) list

let collect terms : polynomial =
  let rec merge = function
    | (powers, c) :: (same, d) :: rest when powers = same -> merge ((powers, c +: d) :: rest)
    | (powers, c) :: rest -> if c.top = 0 then merge rest else (powers, c) :: merge rest
    | [] -> []
  in
  merge (List.sort (fun (a, _) (b, _) -> compare a b) terms)

type axis = X | Y | Z

let power_of axis (i, j, k) = match axis with X -> i | Y -> j | Z -> k
let with_power axis n (i, j, k) = match axis with X -> (n, j, k) | Y -> (i, n, k) | Z -> (i, j, n)

(* The derivative along an axis: each term loses one from its power there
   and is multiplied by the power it had. *)
let derivative axis (p : polynomial) : polynomial =
  collect
    (List.filter_map
       (fun (powers, c) ->
         let n = power_of axis powers in
         if n = 0 then None else Some (with_power axis (n - 1) powers, c *: whole n))
       p)

let sum (p : polynomial) (q : polynomial) = collect (p @ q)
let difference (p : polynomial) (q : polynomial) = collect (p @ List.map (fun (powers, c) -> (powers, zero -: c)) q)

let value (p : polynomial) (a, b, c) =
  List.fold_left (fun total ((i, j, k), factor) -> total +: (factor *: raised a i *: raised b j *: raised c k)) zero p

let value_float (p : polynomial) (a, b, c) =
  List.fold_left
    (fun total ((i, j, k), factor) -> total +. (to_float factor *. (a ** float i) *. (b ** float j) *. (c ** float k)))
    0. p

(* The integral along an axis between two numbers: the antiderivative, term
   by term, at the upper limit less at the lower one. What is left is a
   polynomial in the other variables. *)
let integral axis low high (p : polynomial) : polynomial =
  let antiderivative =
    List.map
      (fun (powers, c) ->
        let n = power_of axis powers in
        (with_power axis (n + 1) powers, c /: whole (n + 1)))
      p
  in
  let put limit =
    collect (List.map (fun (powers, c) -> (with_power axis 0 powers, c *: raised limit (power_of axis powers))) antiderivative)
  in
  difference (put high) (put low)

let constant (p : polynomial) =
  match p with [] -> zero | [ ((0, 0, 0), c) ] -> c | _ -> failwith "a variable is left in what should be a number"

(* ---- Polynomials in t, and line integrals ------------------------------

   The coefficients from the constant up. *)
let rec add_t p q = match (p, q) with [], r | r, [] -> r | a :: p, b :: q -> (a +: b) :: add_t p q
let scale_t factor p = List.map (fun c -> factor *: c) p
let rec times_t p q = match p with [] -> [] | a :: rest -> add_t (scale_t a q) (zero :: times_t rest q)
let rec power_t p n = if n = 0 then [ whole 1 ] else times_t p (power_t p (n - 1))

(* from 0 to 1 *)
let integral_t p = fst (List.fold_left (fun (total, n) c -> (total +: (c /: whole (n + 1)), n + 1)) (zero, 0) p)

(* A polynomial in x and y with x and y each a polynomial in t. *)
let on_path (p : polynomial) xs ys =
  List.fold_left
    (fun total ((i, j, k), c) ->
      if k <> 0 then failwith "z in a field of the plane";
      add_t total (scale_t c (times_t (power_t xs i) (power_t ys j))))
    [] p

(* The integral of P dx + Q dy along the straight segment from one point to
   another: r(t) = start + t (end - start) for t from 0 to 1, so dx and dy
   are the displacement times dt. *)
let along_segment (p, q) (start_x, start_y) (end_x, end_y) =
  let across = end_x - start_x and up = end_y - start_y in
  let xs = [ whole start_x; whole across ] and ys = [ whole start_y; whole up ] in
  integral_t (add_t (scale_t (whole across) (on_path p xs ys)) (scale_t (whole up) (on_path q xs ys)))

(* The same in floats, as the sum of the field at the middle of each small
   step dotted with the step. *)
let along_segment_float (p, q) (start_x, start_y) (end_x, end_y) =
  let steps = 1000 in
  let across = float (end_x - start_x) /. float steps and up = float (end_y - start_y) /. float steps in
  let total = ref 0. in
  for step = 0 to steps - 1 do
    let s = float step +. 0.5 in
    let place = (float start_x +. (s *. across), float start_y +. (s *. up), 0.) in
    total := !total +. (value_float p place *. across) +. (value_float q place *. up)
  done;
  !total

(* ---- Difference quotients ---------------------------------------------- *)

let moved (a, b, c) axis h = match axis with X -> (a +. h, b, c) | Y -> (a, b +. h, c) | Z -> (a, b, c +. h)

let slope p axis place =
  let h = 1e-4 in
  (value_float p (moved place axis h) -. value_float p (moved place axis (-.h))) /. (2. *. h)

let bend p axis place =
  let h = 1e-3 in
  (value_float p (moved place axis h) -. (2. *. value_float p place) +. value_float p (moved place axis (-.h))) /. (h *. h)

(* ---- Reading the question ----------------------------------------------

   The fields of a prompt: the pattern is the whole sentence, with a group
   wherever something is read. *)
let words = Str.quote

let fields count pattern prompt =
  if Str.string_match (Str.regexp pattern) prompt 0 && Str.match_end () = String.length prompt then
    List.init count (fun n -> Str.matched_group (n + 1) prompt)
  else failwith "the wording is not the expected one"

let an_integer = "\\(-?[0-9]+\\)"
let a_function = "\\([^`,]*\\)"
let a_point = words "\\left(" ^ an_integer ^ ", " ^ an_integer ^ ", " ^ an_integer ^ words "\\right)"
let a_field = words "\\left\\langle " ^ a_function ^ words ",\\; " ^ a_function ^ words ",\\; " ^ a_function ^ words " \\right\\rangle"
let as_a_vector = words " Enter it as a vector, such as [`\\langle 1, -2, 3 \\rangle`]."

let gradient_sentence =
  words "Find the gradient of [`f(x, y, z) = " ^ a_function ^ words "`] at the point [`" ^ a_point ^ words "`]." ^ as_a_vector

let divergence_sentence =
  words "Find the divergence of [`\\mathbf{F}(x, y, z) = " ^ a_field ^ words "`] at the point [`" ^ a_point ^ words "`]."

let curl_sentence =
  words "Find the curl of [`\\mathbf{F}(x, y, z) = " ^ a_field ^ words "`] at the point [`" ^ a_point ^ words "`]." ^ as_a_vector

let directional_sentence =
  words "Find the directional derivative of [`f(x, y, z) = " ^ a_function ^ words "`] at the point [`" ^ a_point
  ^ words "`] in the direction of the vector [`\\langle " ^ an_integer ^ ", " ^ an_integer ^ ", " ^ an_integer
  ^ words " \\rangle`]."

let laplacian_sentence =
  words "Find the Laplacian [`\\nabla^{2} f = f_{xx} + f_{yy} + f_{zz}`] of [`f(x, y, z) = " ^ a_function
  ^ words "`] at the point [`" ^ a_point ^ words "`]."

let segment_sentence =
  words "Find the work done by the force [`\\mathbf{F}(x, y) = \\left\\langle " ^ a_function ^ words ",\\; " ^ a_function
  ^ words " \\right\\rangle`] along the straight line segment from [`(" ^ an_integer ^ ", " ^ an_integer
  ^ words ")`] to [`(" ^ an_integer ^ ", " ^ an_integer
  ^ words ")`], that is, [`\\int_{C} \\mathbf{F} \\cdot d\\mathbf{r}`]."

let green_sentence =
  words "Let [`C`] be the boundary of the rectangle [`0 \\le x \\le " ^ an_integer ^ words "`], [`0 \\le y \\le "
  ^ an_integer ^ words "`], taken anticlockwise. Evaluate [`\\oint_{C} " ^ "\\([^` ]*\\)" ^ words " \\, dx + "
  ^ "\\([^` ]*\\)" ^ words " \\, dy`]."

(* What was generated besides the kinds: every value of every number. *)
let noted = Hashtbl.create 256
let note what = Hashtbl.replace noted what ()
let between low high n = low <= n && n <= high

(* One term as the grammar writes it: "3x^{2}", "-yz^{2}", "2xy", "x". A
   coefficient of 1 is not written, a minus sign alone stands for -1, and a
   power of 1 is not written. *)
type term = { scale : int; powers : int * int * int }

let term_pattern =
  Str.regexp "\\(-?\\)\\([0-9]*\\)\\(x\\(\\^{\\([0-9]+\\)}\\)?\\)?\\(y\\(\\^{\\([0-9]+\\)}\\)?\\)?\\(z\\(\\^{\\([0-9]+\\)}\\)?\\)?"

let term text =
  if not (Str.string_match term_pattern text 0 && Str.match_end () = String.length text) then
    failwith ("cannot read the term " ^ text);
  let group n = match Str.matched_group n text with s -> Some s | exception Not_found -> None in
  let power letter exponent =
    match (group letter, group exponent) with
    | None, _ -> 0
    | Some _, None -> 1
    | Some _, Some e ->
        if String.length e <> 1 || int_of_string e < 2 then failwith ("a power written in an unusual way: " ^ text)
        else int_of_string e
  in
  let powers = (power 3 5, power 6 8, power 9 11) in
  if powers = (0, 0, 0) then failwith ("a term with no variable: " ^ text);
  let size =
    match group 2 with
    | None | Some "" -> 1
    | Some digits ->
        if digits.[0] = '0' || digits = "1" then failwith ("a coefficient written that need not be: " ^ text)
        else int_of_string digits
  in
  { scale = (if group 1 = Some "-" then -size else size); powers }

(* What a polynomial is made of. *)
let is_constant (p : polynomial) = match p with [] | [ ((0, 0, 0), _) ] -> true | _ -> false
let degree (i, j, l) = i + j + l
let has_square (i, j, l) = i = 2 || j = 2 || l = 2
let show_powers (i, j, l) = Printf.sprintf "%d %d %d" i j l

(* A term of a function or of a field of space: c from -4 to 4 and not 0,
   each power 0 to 2, of degree 1 to 3. *)
let space_term k t =
  let i, j, l = t.powers in
  if t.scale = 0 || not (between (-4) 4 t.scale) then failwith (Printf.sprintf "%s: a coefficient %d" k t.scale);
  if i > 2 || j > 2 || l > 2 then failwith (Printf.sprintf "%s: a power above 2" k);
  if not (between 1 3 (i + j + l)) then failwith (Printf.sprintf "%s: a term of degree %d" k (i + j + l));
  note (Printf.sprintf "%s: coefficient %d" k t.scale);
  note (Printf.sprintf "%s: powers %d %d %d" k i j l)

let polynomial terms : polynomial = collect (List.map (fun t -> (t.powers, whole t.scale)) terms)

(* Terms joined by " + " and " - ". Only the first term carries its own
   minus sign. *)
let terms text =
  match Str.full_split (Str.regexp " [+-] ") text with
  | Str.Text first :: rest ->
      let rec others = function
        | [] -> []
        | Str.Delim sign :: Str.Text t :: rest ->
            if t <> "" && t.[0] = '-' then failwith ("a minus sign after a sign: " ^ text);
            let read = term t in
            (if sign = " - " then { read with scale = -read.scale } else read) :: others rest
        | _ -> failwith ("cannot read " ^ text)
      in
      term first :: others rest
  | _ -> failwith ("cannot read " ^ text)

(* A function: two terms that differ in their variables. *)
let scalar_function k text =
  match terms text with
  | [ first; second ] ->
      space_term k first;
      space_term k second;
      if first.powers = second.powers then failwith (k ^ ": the two terms have the same variables");
      note (Printf.sprintf "%s: degrees %d then %d" k (degree first.powers) (degree second.powers));
      polynomial [ first; second ]
  | _ -> failwith (k ^ ": not a function of two terms")

(* A component of a field: one term. *)
let component k text =
  match terms text with
  | [ only ] ->
      space_term k only;
      polynomial [ only ]
  | _ -> failwith (k ^ ": a component that is not one term")

(* A point of space, each coordinate from -2 to 2. *)
let point k coordinates =
  match List.map int_of_string coordinates with
  | [ a; b; c ] ->
      List.iteri
        (fun place n ->
          if not (between (-2) 2 n) then failwith (Printf.sprintf "%s: a coordinate %d" k n);
          note (Printf.sprintf "%s: coordinate %d = %d" k (place + 1) n))
        [ a; b; c ];
      (a, b, c)
  | _ -> failwith "three coordinates were expected"

(* A function whose point matters: a term printed has degree 2 or 3. *)
let not_linear k (f : polynomial) =
  match List.filter (fun (powers, _) -> degree powers >= 2) f with
  | [] -> failwith (k ^ ": the function is linear, the point does not matter")
  | [ (powers, _) ] -> note (Printf.sprintf "%s: not linear by %s alone" k (show_powers powers))
  | _ -> ()

let exact (a, b, c) = (whole a, whole b, whole c)
let floats (a, b, c) = (float a, float b, float c)

(* The directions of the grammar: (1, 2, 2), (2, 3, 6) and (4, 4, 7), each
   in its three cyclic orders, without their signs. *)
let quadruples = [ (1, 2, 2); (2, 2, 1); (2, 1, 2); (2, 3, 6); (3, 6, 2); (6, 2, 3); (4, 4, 7); (4, 7, 4); (7, 4, 4) ]

(* The right answer of a question, the answer of each mistake its form has a
   line for, and the answer found again in floats with the tolerance it is
   held to, all from the prompt. An answer is one number or three. *)
type working = { right : fraction list; slips : (string * fraction) list; estimate : float list; tolerance : float }

let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "gradient" as k -> (
      match fields 4 gradient_sentence p with
      | f :: coordinates ->
          let f = scalar_function k f in
          let place = point k coordinates in
          not_linear k f;
          if List.for_all (fun axis -> is_constant (derivative axis f)) [ X; Y; Z ] then
            failwith (k ^ ": the gradient is the same at every point");
          let right = List.map (fun axis -> value (derivative axis f) (exact place)) [ X; Y; Z ] in
          if List.for_all (fun c -> c = zero) right then failwith (k ^ ": the gradient is the zero vector");
          { right; slips = []; estimate = List.map (fun axis -> slope f axis (floats place)) [ X; Y; Z ]; tolerance = 1e-5 }
      | [] -> failwith "four fields were expected")
  | "divergence" as k -> (
      match fields 6 divergence_sentence p with
      | [ first; second; third; a; b; c ] ->
          let first = component k first and second = component k second and third = component k third in
          let place = point k [ a; b; c ] in
          (* the components that hold their own variable, as printed *)
          let own =
            List.concat_map
              (fun (index, axis, part) ->
                List.filter_map (fun (powers, _) -> if power_of axis powers >= 1 then Some (index, powers) else None) part)
              [ (1, X, first); (2, Y, second); (3, Z, third) ]
          in
          if List.length own < 2 then failwith (k ^ ": fewer than two components hold their own variable");
          if not (List.exists (fun (_, powers) -> degree powers >= 2) own) then
            failwith (k ^ ": no component that holds its own variable is of degree 2 or 3");
          note (Printf.sprintf "%s: %d components take part" k (List.length own));
          (match List.filter (fun (_, powers) -> degree powers >= 2) own with
          | [ (index, powers) ] -> note (Printf.sprintf "%s: varies by component %d alone, %s" k index (show_powers powers))
          | _ -> ());
          List.iter
            (fun index -> if not (List.mem_assoc index own) then note (Printf.sprintf "%s: component %d takes no part" k index))
            [ 1; 2; 3 ];
          let parts = [ derivative X first; derivative Y second; derivative Z third ] in
          if List.length (List.filter (fun part -> part <> []) parts) < 2 then
            failwith (k ^ ": fewer than two of P_x, Q_y and R_z are there at all");
          if List.for_all is_constant parts then failwith (k ^ ": P_x, Q_y and R_z are all constants");
          (* two shares can cancel, as in (x^2, -2xy, 4z): the sum itself is looked at *)
          if is_constant (List.fold_left sum [] parts) then
            failwith (k ^ ": the divergence is the same at every point, its parts cancel");
          let right = List.fold_left (fun total part -> total +: value part (exact place)) zero parts in
          if right = zero then failwith (k ^ ": the divergence is 0 at the point");
          let estimate = slope first X (floats place) +. slope second Y (floats place) +. slope third Z (floats place) in
          { right = [ right ]; slips = []; estimate = [ estimate ]; tolerance = 1e-5 }
      | _ -> failwith "six fields were expected")
  | "curl" as k -> (
      match fields 6 curl_sentence p with
      | [ first; second; third; a; b; c ] ->
          let first = component k first and second = component k second and third = component k third in
          let place = point k [ a; b; c ] in
          let turn (upper, upper_axis) (lower, lower_axis) =
            value (difference (derivative upper_axis upper) (derivative lower_axis lower)) (exact place)
          in
          let right = [ turn (third, Y) (second, Z); turn (first, Z) (third, X); turn (second, X) (first, Y) ] in
          if List.length (List.filter (fun c -> c <> zero) right) < 2 then
            failwith (k ^ ": fewer than two components of the curl are not 0");
          let turn_float (upper, upper_axis) (lower, lower_axis) =
            slope upper upper_axis (floats place) -. slope lower lower_axis (floats place)
          in
          let estimate =
            [ turn_float (third, Y) (second, Z); turn_float (first, Z) (third, X); turn_float (second, X) (first, Y) ]
          in
          { right; slips = []; estimate; tolerance = 1e-5 }
      | _ -> failwith "six fields were expected")
  | "directional" as k -> (
      match fields 7 directional_sentence p with
      | [ f; a; b; c; u; v; w ] ->
          let f = scalar_function k f in
          let place = point k [ a; b; c ] in
          let u = int_of_string u and v = int_of_string v and w = int_of_string w in
          let squared = (u * u) + (v * v) + (w * w) in
          let length = int_of_float (Float.round (sqrt (float squared))) in
          if length * length <> squared then
            failwith (Printf.sprintf "%s: the direction has length the square root of %d, not a whole number" k squared);
          if u <= 0 then failwith (k ^ ": the first component of the direction is not positive");
          if not (List.mem (abs u, abs v, abs w) quadruples) then
            failwith (Printf.sprintf "%s: (%d, %d, %d) is not a direction of the grammar" k u v w);
          note (Printf.sprintf "%s: direction %d %d %d" k (abs u) (abs v) (abs w));
          note (Printf.sprintf "%s: second component %s" k (if v > 0 then "positive" else "negative"));
          note (Printf.sprintf "%s: third component %s" k (if w > 0 then "positive" else "negative"));
          not_linear k f;
          (* u f_x + v f_y + w f_z as a polynomial *)
          let along =
            collect
              (List.concat_map
                 (fun (axis, n) -> List.map (fun (powers, c) -> (powers, c *: whole n)) (derivative axis f))
                 [ (X, u); (Y, v); (Z, w) ])
          in
          if is_constant along then failwith (k ^ ": the directional derivative is the same at every point");
          let gradient = List.map (fun axis -> value (derivative axis f) (exact place)) [ X; Y; Z ] in
          let dotted = List.fold_left2 (fun total part n -> total +: (part *: whole n)) zero gradient [ u; v; w ] in
          let right = dotted /: whole length in
          if right = zero then failwith (k ^ ": the directional derivative is 0");
          note (k ^ if right.bottom = 1 then ": a whole answer" else ": a fraction for an answer");
          (* f a little way along the unit direction, either side *)
          let size = sqrt (float squared) in
          let h = 1e-4 in
          let x, y, z = floats place in
          let gone s = (x +. (s *. float u /. size), y +. (s *. float v /. size), z +. (s *. float w /. size)) in
          let estimate = (value_float f (gone h) -. value_float f (gone (-.h))) /. (2. *. h) in
          { right = [ right ]; slips = [ ("not_normalised", dotted) ]; estimate = [ estimate ]; tolerance = 1e-5 }
      | _ -> failwith "seven fields were expected")
  | "laplacian" as k -> (
      match fields 4 laplacian_sentence p with
      | f :: coordinates ->
          let f = scalar_function k f in
          let place = point k coordinates in
          let laplacian g =
            let twice axis = derivative axis (derivative axis g) in
            sum (twice X) (sum (twice Y) (twice Z))
          in
          (* each term takes part: it has a square, and its own Laplacian is there *)
          List.iter
            (fun (powers, c) ->
              if not (has_square powers) then failwith (k ^ ": a term with no squared variable");
              if laplacian [ (powers, c) ] = [] then failwith (k ^ ": a term whose Laplacian is 0 everywhere"))
            f;
          if not (List.exists (fun (powers, _) -> degree powers = 3) f) then failwith (k ^ ": no term of degree 3");
          note (Printf.sprintf "%s: terms %s" k (String.concat " and " (List.map (fun (powers, _) -> show_powers powers) f)));
          let total = laplacian f in
          if total = [] then failwith (k ^ ": the Laplacian is 0 everywhere");
          if is_constant total then failwith (k ^ ": the Laplacian is the same at every point");
          let right = value total (exact place) in
          if right = zero then failwith (k ^ ": the Laplacian is 0 at the point");
          let estimate = List.fold_left (fun sum axis -> sum +. bend f axis (floats place)) 0. [ X; Y; Z ] in
          { right = [ right ]; slips = []; estimate = [ estimate ]; tolerance = 1e-4 }
      | [] -> failwith "four fields were expected")
  | "segment_work" as k -> (
      match fields 6 segment_sentence p with
      | [ first; second; start_x; start_y; end_x; end_y ] ->
          (* a x + b y, with a and b from -3 to 3 and not 0 *)
          let linear name text =
            match terms text with
            | [ { scale = a; powers = 1, 0, 0 }; { scale = b; powers = 0, 1, 0 } ] as read ->
                List.iter
                  (fun (letter, n) ->
                    if n = 0 || not (between (-3) 3 n) then failwith (Printf.sprintf "%s: a coefficient %d" k n);
                    note (Printf.sprintf "%s: %s of %s = %d" k letter name n))
                  [ ("x", a); ("y", b) ];
                polynomial read
            | _ -> failwith (k ^ ": a component that is not a x + b y")
          in
          let first = linear "P" first and second = linear "Q" second in
          let start = (int_of_string start_x, int_of_string start_y) and finish = (int_of_string end_x, int_of_string end_y) in
          if start = finish then failwith (k ^ ": the two ends are the same point");
          List.iter
            (fun (name, from, upto) ->
              if not (between (-2) 2 from) then failwith (Printf.sprintf "%s: the segment starts at %s = %d" k name from);
              if upto = from || not (between (-3) 3 (upto - from)) then
                failwith (Printf.sprintf "%s: the segment moves %d in %s" k (upto - from) name);
              note (Printf.sprintf "%s: start %s = %d" k name from);
              note (Printf.sprintf "%s: moves %d in %s" k (upto - from) name))
            [ ("x", fst start, fst finish); ("y", snd start, snd finish) ];
          let right = along_segment (first, second) start finish in
          if right = zero then failwith (k ^ ": the work is 0");
          note (k ^ if right.bottom = 1 then ": a whole answer" else ": a fraction for an answer");
          { right = [ right ]; slips = []; estimate = [ along_segment_float (first, second) start finish ]; tolerance = 1e-6 }
      | _ -> failwith "six fields were expected")
  | "green" as k -> (
      match fields 4 green_sentence p with
      | [ m; n; first; second ] ->
          (* c x^i y^j with c from -4 to 5 and not 0, of degree 1 to 3, in
             brackets exactly when it starts with a minus sign *)
          let plane name text =
            let open_bracket = "\\left(" and close_bracket = "\\right)" in
            let bracketed =
              String.length text > String.length open_bracket + String.length close_bracket
              && String.sub text 0 (String.length open_bracket) = open_bracket
              && String.sub text (String.length text - String.length close_bracket) (String.length close_bracket)
                 = close_bracket
            in
            let inside =
              if bracketed then
                String.sub text (String.length open_bracket)
                  (String.length text - String.length open_bracket - String.length close_bracket)
              else text
            in
            let t = term inside in
            let i, j, l = t.powers in
            if bracketed <> (t.scale < 0) then failwith (k ^ ": brackets where they are not needed, or none where they are");
            if t.scale = 0 || not (between (-4) 5 t.scale) then failwith (Printf.sprintf "%s: a coefficient %d" k t.scale);
            if l <> 0 then failwith (k ^ ": z in a field of the plane");
            if i > 2 || j > 2 || not (between 1 3 (i + j)) then failwith (Printf.sprintf "%s: powers %d and %d" k i j);
            note (Printf.sprintf "%s: coefficient of %s = %d" k name t.scale);
            note (Printf.sprintf "%s: powers of %s %d %d" k name i j);
            polynomial [ t ]
          in
          let first = plane "P" first and second = plane "Q" second in
          (* both take part in Q_x - P_y *)
          if List.exists (fun (powers, _) -> power_of Y powers = 0) first || derivative Y first = [] then
            failwith (k ^ ": P has no y in it, it takes no part");
          if List.exists (fun (powers, _) -> power_of X powers = 0) second || derivative X second = [] then
            failwith (k ^ ": Q has no x in it, it takes no part");
          let m = int_of_string m and n = int_of_string n in
          List.iter
            (fun (name, side) ->
              if not (between 1 3 side) then failwith (Printf.sprintf "%s: a rectangle of %s %d" k name side);
              note (Printf.sprintf "%s: %s %d" k name side))
            [ ("width", m); ("height", n) ];
          (* anticlockwise from the origin: bottom, right side, top, left side *)
          let corners = [ (0, 0); (m, 0); (m, n); (0, n) ] in
          let sides = List.combine corners (List.tl corners @ [ List.hd corners ]) in
          let right = List.fold_left (fun total (from, upto) -> total +: along_segment (first, second) from upto) zero sides in
          let estimate =
            List.fold_left (fun total (from, upto) -> total +. along_segment_float (first, second) from upto) 0. sides
          in
          (* the double integral of Q_x - P_y over the rectangle *)
          let inside = difference (derivative X second) (derivative Y first) in
          let double = constant (integral Y zero (whole n) (integral X zero (whole m) inside)) in
          if double <> right then
            failwith
              (Printf.sprintf "%s: round the four sides %s, but the double integral is %s" k (show right) (show double));
          if right = zero then failwith (k ^ ": the circulation is 0");
          note (k ^ if right.bottom = 1 then ": a whole answer" else ": a fraction for an answer");
          { right = [ right ]; slips = []; estimate = [ estimate ]; tolerance = 1e-4 }
      | _ -> failwith "four fields were expected")
  | k -> failwith ("unknown kind " ^ k)

(* The answer of the one blank: a number, or a vector of three whole
   numbers. The flag says which. *)
let answer (q : Rhema_engine.question) =
  match q.Rhema_engine.answers with
  | [ Rhema_engine.Num n ] -> (false, [ of_number n ])
  | [ Rhema_engine.Vector v ] -> (
      match List.map of_number (Rhema_vector.components v) with
      | [ _; _; _ ] as parts ->
          if List.exists (fun c -> c.bottom <> 1) parts then failwith "a vector with a fraction in it";
          (true, parts)
      | _ -> failwith "a vector that does not have three components")
  | _ -> failwith ("not one number or one vector: " ^ q.Rhema_engine.answer_text)

let show_all parts = String.concat ", " (List.map show parts)

let () =
  let base = load_file "vector_calculus.rhm" in
  (* each kind with its price and whether its answer is a vector *)
  let prices =
    [ ("gradient", 1, true); ("divergence", 1, false); ("curl", 2, true); ("directional", 2, false);
      ("laplacian", 2, false); ("segment_work", 3, false); ("green", 3, false) ]
  in
  (* Enough for some two thousand Laplacians: a function that is harmonic
     by cancellation would be about one in a hundred of them if nothing
     turned it away. A divergence that is constant by cancellation would be
     only about one in a thousand, so the first budget has many more: some
     fourteen thousand divergences. *)
  let per_budget = function 1 -> 40000 | _ -> 6000 in
  let seen = Hashtbl.create 8 and made = Hashtbl.create 2 in
  let times k = match Hashtbl.find_opt seen k with Some n -> n | None -> 0 in
  (* No form is offered at any other budget. *)
  List.iter
    (fun cost ->
      let spec = with_initial base "cost" cost in
      for seed = 0 to 4 do
        Random.init seed;
        match Rhema_engine.generate spec with
        | exception Rhema_engine.Generation_error _ -> ()
        | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
      done)
    [ 0; 4; 5 ];
  let check cost (q : Rhema_engine.question) =
    let k = kind q and p = q.Rhema_engine.prompt in
    Hashtbl.replace seen k (times k + 1);
    if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
    (match Rhema_engine.attribute q.Rhema_engine.tree "text" with
    | Rhema_engine.Text t -> if t <> p then fail (Printf.sprintf "%s: the prompt %S is not the text %S" k p t)
    | _ -> fail (k ^ ": the text is not text"));
    match List.find_opt (fun (name, _, _) -> name = k) prices with
    | None -> fail (Printf.sprintf "unknown kind %s at cost %d: %S" k cost p)
    | Some (_, price, is_vector) -> (
        if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost);
        let context = if is_vector then "Vector" else "Numeric" in
        if q.Rhema_engine.context <> context then
          fail (Printf.sprintf "%s in context %s, not %s" k q.Rhema_engine.context context);
        (match Rhema_engine.attribute q.Rhema_engine.tree "pg_context" with
        | Rhema_engine.Text t when t = context -> ()
        | _ -> fail (Printf.sprintf "%s: pg_context is not %s" k context));
        match answer q with
        | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
        | vector, got -> (
            if vector <> is_vector then
              fail (Printf.sprintf "%s: the answer %s is %s" k (show_all got) (if vector then "a vector" else "a number"));
            match expected q with
            | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
            | { right; slips; estimate; tolerance } ->
                if got <> right then
                  fail (Printf.sprintf "%s: answer %s, recomputed %s, for %S" k (show_all got) (show_all right) p);
                (match right with
                | [ only ] -> note (k ^ if only.top > 0 then ": a positive answer" else ": a negative answer")
                | _ -> ());
                List.iter2
                  (fun exactly roughly ->
                    if Float.abs (roughly -. to_float exactly) > tolerance *. (1. +. Float.abs (to_float exactly)) then
                      fail
                        (Printf.sprintf "%s: differences and sums give %.9g, not %s, for %S" k roughly (show exactly) p))
                  right estimate;
                (* a question is asked only where each mistake gives another answer *)
                List.iter
                  (fun (name, slip) ->
                    if [ slip ] = right then
                      fail (Printf.sprintf "%s: %s gives the right answer %s, for %S" k name (show slip) p))
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
                    Hashtbl.replace made m.mistake ();
                    if m.description = "" then fail (m.mistake ^ " has no description");
                    match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                    | Some [ Rhema_engine.Num value ], Some slip ->
                        let wrong = of_number value in
                        if wrong <> slip then
                          fail
                            (Printf.sprintf "%s: %s gives %s, recomputed %s, for %S" k m.mistake (show wrong) (show slip) p);
                        if [ wrong ] = got then fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p)
                    | _, None -> ()
                    | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one number, for %S" k m.mistake p))
                  listed))
  in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to per_budget cost - 1 do
      Random.init (seed + (10000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> check cost q
    done
  done;
  (* left alone, the budget is 2 *)
  for seed = 0 to 99 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "default budget, seed %d: %s" seed m)
    | q -> check 2 q
  done;
  List.iter (fun (k, _, _) -> if times k = 0 then fail ("never generated: " ^ k)) prices;
  if not (Hashtbl.mem made "not_normalised") then fail "never listed: not_normalised";
  (* Every value of every number turns up. *)
  let range low high = List.init (high - low + 1) (fun i -> low + i) in
  let nonzero low high = List.filter (fun n -> n <> 0) (range low high) in
  let each k what values = List.map (fun n -> Printf.sprintf "%s: %s = %d" k what n) values in
  let bodies =
    List.concat_map
      (fun i ->
        List.concat_map
          (fun j -> List.filter_map (fun l -> if between 1 3 (i + j + l) then Some (i, j, l) else None) (range 0 2))
          (range 0 2))
      (range 0 2)
  in
  let wanted =
    List.concat_map
      (fun k ->
        List.map (fun n -> Printf.sprintf "%s: coefficient %d" k n) (nonzero (-4) 4)
        (* a term of the Laplacian has a square; any term may stand elsewhere *)
        @ List.filter_map
            (fun (i, j, l) ->
              if k = "laplacian" && not (has_square (i, j, l)) then None else Some (Printf.sprintf "%s: powers %d %d %d" k i j l))
            bodies
        @ List.concat_map (fun place -> each k (Printf.sprintf "coordinate %d" place) (range (-2) 2)) [ 1; 2; 3 ])
      [ "gradient"; "divergence"; "curl"; "directional"; "laplacian" ]
    @ [ "divergence: 2 components take part"; "divergence: 3 components take part";
        "divergence: component 1 takes no part"; "divergence: component 2 takes no part";
        "divergence: component 3 takes no part" ]
    (* the two degrees of a function in the order printed: one of them is 2
       or 3, and for the Laplacian each has a square and one is 3 *)
    @ List.concat_map
        (fun k ->
          List.concat_map
            (fun first ->
              List.filter_map
                (fun second ->
                  if (if k = "laplacian" then min first second >= 2 && max first second = 3 else max first second >= 2) then
                    Some (Printf.sprintf "%s: degrees %d then %d" k first second)
                  else None)
                (range 1 3))
            (range 1 3))
        [ "gradient"; "directional"; "laplacian" ]
    (* each term of degree 2 or 3 as the only one that is not linear *)
    @ List.concat_map
        (fun k ->
          List.filter_map
            (fun powers -> if degree powers >= 2 then Some (Printf.sprintf "%s: not linear by %s alone" k (show_powers powers)) else None)
            bodies)
        [ "gradient"; "directional" ]
    (* each component of degree 2 or 3 as the only one whose share of the
       divergence changes from point to point *)
    @ List.concat_map
        (fun (index, axis) ->
          List.filter_map
            (fun powers ->
              if degree powers >= 2 && power_of axis powers >= 1 then
                Some (Printf.sprintf "divergence: varies by component %d alone, %s" index (show_powers powers))
              else None)
            bodies)
        [ (1, X); (2, Y); (3, Z) ]
    (* each pair of terms with a square of which one is of degree 3 *)
    @ List.concat_map
        (fun first ->
          List.filter_map
            (fun second ->
              if first < second && has_square first && has_square second && max (degree first) (degree second) = 3 then
                Some (Printf.sprintf "laplacian: terms %s and %s" (show_powers first) (show_powers second))
              else None)
            bodies)
        bodies
    @ List.map (fun (u, v, w) -> Printf.sprintf "directional: direction %d %d %d" u v w) quadruples
    @ [ "directional: second component positive"; "directional: second component negative";
        "directional: third component positive"; "directional: third component negative" ]
    @ List.concat_map
        (fun name ->
          each "segment_work" ("x of " ^ name) (nonzero (-3) 3) @ each "segment_work" ("y of " ^ name) (nonzero (-3) 3))
        [ "P"; "Q" ]
    @ List.concat_map
        (fun name ->
          each "segment_work" ("start " ^ name) (range (-2) 2)
          @ List.map (fun n -> Printf.sprintf "segment_work: moves %d in %s" n name) (nonzero (-3) 3))
        [ "x"; "y" ]
    @ List.concat_map
        (fun name ->
          each "green" ("coefficient of " ^ name) (nonzero (-4) 5)
          (* P has y in it and Q has x *)
          @ List.filter_map
              (fun (i, j, l) ->
                if l = 0 && (if name = "P" then j else i) >= 1 then Some (Printf.sprintf "green: powers of %s %d %d" name i j)
                else None)
              bodies)
        [ "P"; "Q" ]
    @ List.concat_map (fun name -> List.map (fun n -> Printf.sprintf "green: %s %d" name n) (range 1 3)) [ "width"; "height" ]
    @ List.concat_map
        (fun k -> [ k ^ ": a whole answer"; k ^ ": a fraction for an answer" ])
        [ "directional"; "segment_work"; "green" ]
    @ List.concat_map
        (fun k -> [ k ^ ": a positive answer"; k ^ ": a negative answer" ])
        [ "divergence"; "directional"; "laplacian"; "segment_work"; "green" ]
  in
  List.iter (fun what -> if not (Hashtbl.mem noted what) then fail ("never generated: " ^ what)) wanted;
  if !failures = 0 then print_endline "Rhema vector calculus tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d vector calculus test(s) failed." !failures);
    exit 1
  end
