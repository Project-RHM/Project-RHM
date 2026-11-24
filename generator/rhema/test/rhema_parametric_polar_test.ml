(* Independent checks for parametric_polar.rhm. Nothing here uses the
   grammar's closed formulas. Every question is read from its first
   character to its last against the whole sentence of its form (a text
   that cannot be read is a failure); each blank is met where the text
   places it, and the numbers of the question are read back from the
   printed LaTeX alone. A polynomial in t is read term by term and must be
   written the one way it should be: written again here from what was read,
   it must give back the printed text, so a 1 in front of t, a term with 0
   in front, a power 1 or a term out of its place is refused. The answers
   are then found again, form by form:

   - slope: dy/dx is dy/dt over dx/dt, both taken here by differentiating
     the polynomials read, term by term; the engine's number must be that
     fraction exactly. As a second opinion the slope of a short chord of the
     curve on either side of the point, (y(t+h) - y(t-h)) / (x(t+h) -
     x(t-h)), must agree with it in floating point.
   - tangent: the answer, a polynomial of the first degree in x, must pass
     exactly through the point (x(t), y(t)) of the curve and have the slope
     found as above; the chord is again a second opinion.
   - second_derivative: dy/dx is worked out in floating point at points on
     either side of t, and its change is divided by the change of x between
     them; two such quotients, with steps h and h/2, are combined by
     Richardson's rule, and the result must agree with the engine's fraction
     within 1e-7.
   - length: the speed sqrt(x'(t)^2 + y'(t)^2) is integrated by Simpson's
     rule between the printed limits, and a polyline of 20000 chords along
     the curve is summed as a second opinion; the answer must be that
     number, and a whole number.
   - polar_point: the angle is read as a fraction of pi; x = r cos(theta)
     and y = r sin(theta) are worked out in floating point, the two blanks
     in that order. Both answers must be plain answers written without a
     trigonometric function.
   - petal: r(theta) is scanned for its first two zeros, which are made
     exact by bisection; they must lie pi/k apart (the header's promise),
     and r^2/2 is integrated between them by Simpson's rule.
   - cardioid and circle: the smallest period T, a whole number of twelfths
     of pi, after which the traced point (r cos(theta), r sin(theta))
     returns to where it was is searched for; it must be pi for a circle
     and 2 pi for a cardioid (the header's promise), and r^2/2 is
     integrated over [0, T]. As a second opinion the shoelace area of the
     closed polygon of 20000 points along the curve must agree.
   - lune: the angles where the outer circle crosses r = b are found by a
     scan and bisection; the difference of the two r^2/2 is integrated
     between them. As a coarse cross-check the points of a 400 by 400 grid
     that lie inside the one circle and outside the other, each judged by
     its own polar coordinates, are counted. The answers for cos and for sin
     with the same b must be the same, as the header says.

   Areas must be plain answers: a fraction times pi (petal, cardioid,
   circle), or a fraction times pi plus a fraction times sqrt(3) (lune).

   Mistakes. Each is redone as its description says:

     inverted_slope        dx/dt over dy/dt for the slope; for the tangent,
                           the line through the same point with that slope
     sine_cosine_swapped   x = r sin(theta), y = r cos(theta); it is listed
                           exactly where it changes the answers, which is
                           where sin(theta) and cos(theta) differ
     half_forgotten        the integral of r^2, without the 1/2
     second_over_second    y''(t) / x''(t), the second derivatives taken as
                           second differences f(t+1) - 2f(t) + f(t-1),
                           which are exact for polynomials of degree 3

   The engine must list exactly the mistakes of the form, in the order they
   are declared, each with its description word for word and the values
   redone here, each different from the right answer; length lists none.

   Besides the answers: each kind appears at its price alone and spends its
   budget; a budget outside 1..3 gives no question; the budget the grammar
   sets itself is the middle price; every answer has the type of its form;
   the promises of the header and of the comments hold (dx/dt and dy/dt are
   not 0 and not equal in size for a slope or tangent, and the curve is not
   part of a straight line, three of its points never being on one line;
   the second
   derivative is not 0 and not y''/x'', with dx/dt not 0 and at most 6 in
   size; the length curve is k (t^3 - 3t) + h, 3k t^2 + v; the lune's outer
   circle has twice the radius of the inner one); and each printed number
   of each form takes exactly the values the grammar offers, none missing
   and none more (with dx/dt, and dy/dt for a slope or tangent, where
   they are at most 6 in size). The weights are not looked at. *)

module F = Rhema_formula

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

let pi = Float.pi
let close a b = Float.abs (a -. b) <= 1e-9 *. Float.max 1. (Float.abs b)
let near tolerance a b = Float.abs (a -. b) <= tolerance *. Float.max 1. (Float.abs b)

(* ---- Fractions -------------------------------------------------------------- *)

(* A fraction in lowest terms with a positive denominator, so that equal
   fractions are the same record. *)
type fraction = { top : int; bottom : int }

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

let ratio top bottom =
  if bottom = 0 then failwith "a division by zero";
  let divisor = if bottom < 0 then -gcd top bottom else gcd top bottom in
  { top = top / divisor; bottom = bottom / divisor }

let whole n = { top = n; bottom = 1 }
let ( +/ ) a b = ratio ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( */ ) a b = ratio (a.top * b.top) (a.bottom * b.bottom)
let to_float a = float_of_int a.top /. float_of_int a.bottom
let print a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom
let of_number (n : Rhema_number.t) = ratio n.Rhema_number.numerator n.Rhema_number.denominator

(* ---- Polynomials in t ------------------------------------------------------ *)

(* The coefficients of t^0, t^1, t^2 and t^3. *)
type poly = int array

let rec power_int b n = if n = 0 then 1 else b * power_int b (n - 1)
let at_int (p : poly) t = p.(0) + (p.(1) * t) + (p.(2) * t * t) + (p.(3) * power_int t 3)
let at (p : poly) t = float p.(0) +. (float p.(1) *. t) +. (float p.(2) *. t *. t) +. (float p.(3) *. t *. t *. t)
let derive (p : poly) : poly = [| p.(1); 2 * p.(2); 3 * p.(3); 0 |]

(* A polynomial written the way the grammar writes one: the highest power
   first, no term with 0 in front, no 1 in front of t, no power 1. *)
let write (p : poly) =
  let degrees = List.filter (fun d -> p.(d) <> 0) [ 3; 2; 1; 0 ] in
  if degrees = [] then "0"
  else
    String.concat ""
      (List.mapi
         (fun i d ->
           let c = p.(d) in
           let sign = if i = 0 then if c < 0 then "-" else "" else if c < 0 then " - " else " + " in
           let size = abs c in
           let body =
             if d = 0 then string_of_int size
             else (if size = 1 then "" else string_of_int size) ^ if d = 1 then "t" else Printf.sprintf "t^{%d}" d
           in
           sign ^ body)
         degrees)

let term_re = Str.regexp {|^\([0-9]*\)\(t\(\^{\([0-9]\)}\)?\)?$|}

let read_poly text : poly =
  let p = Array.make 4 0 in
  let sign = ref 1 and first = ref true in
  List.iter
    (function
      | Str.Delim d -> sign := if String.trim d = "-" then -1 else 1
      | Str.Text t ->
          let t =
            if !first && String.length t > 0 && t.[0] = '-' then begin
              sign := -1;
              String.sub t 1 (String.length t - 1)
            end
            else t
          in
          first := false;
          if not (Str.string_match term_re t 0) then failwith ("not a term: " ^ t);
          let digits = Str.matched_group 1 t in
          let has_t = (try ignore (Str.matched_group 2 t); true with Not_found -> false) in
          let degree =
            if not has_t then 0 else try int_of_string (Str.matched_group 4 t) with Not_found -> 1
          in
          if degree > 3 then failwith ("a power above 3: " ^ t);
          if digits = "" && not has_t then failwith ("an empty term in " ^ text);
          let c = if digits = "" then 1 else int_of_string digits in
          p.(degree) <- p.(degree) + (!sign * c))
    (Str.full_split (Str.regexp " [+-] ") text);
  if write p <> text then failwith (Printf.sprintf "%S is not written as %S" text (write p));
  p

(* ---- Numerical working ------------------------------------------------------ *)

let simpson f a b n =
  let h = (b -. a) /. float n in
  let total = ref (f a +. f b) in
  for i = 1 to n - 1 do
    total := !total +. ((if i mod 2 = 1 then 4. else 2.) *. f (a +. (float i *. h)))
  done;
  !total *. h /. 3.

(* A zero of f between lo and hi, where f changes sign. *)
let bisect f lo hi =
  let lo = ref lo and hi = ref hi in
  let below = f !lo < 0. in
  for _ = 1 to 200 do
    let mid = (!lo +. !hi) /. 2. in
    if (f mid < 0.) = below then lo := mid else hi := mid
  done;
  (!lo +. !hi) /. 2.

(* The places in [start, start + span] where f changes sign, in order. *)
let sign_changes f start span =
  let steps = 20000 in
  let h = span /. float steps in
  let found = ref [] in
  for i = 0 to steps - 1 do
    let a = start +. (float i *. h) in
    let b = a +. h in
    if (f a < 0.) <> (f b < 0.) then found := bisect f a b :: !found
  done;
  List.rev !found

(* The area of a closed polygon, by the shoelace formula. *)
let shoelace points =
  let n = Array.length points in
  let total = ref 0. in
  for i = 0 to n - 1 do
    let x1, y1 = points.(i) and x2, y2 = points.((i + 1) mod n) in
    total := !total +. ((x1 *. y2) -. (x2 *. y1))
  done;
  Float.abs !total /. 2.

(* ---- The answers -------------------------------------------------------------- *)

let rec has test formula =
  test formula
  ||
  match formula with
  | F.Constant _ | F.Pi | F.Variable _ -> false
  | F.Add (a, b) | F.Subtract (a, b) | F.Multiply (a, b) | F.Divide (a, b) -> has test a || has test b
  | F.Power (a, _) | F.Negate a | F.Sin a | F.Cos a | F.Tan a | F.Exp a | F.Ln a | F.Sqrt a -> has test a

let functions = has (function F.Sin _ | F.Cos _ | F.Tan _ | F.Exp _ | F.Ln _ | F.Variable _ -> true | _ -> false)

(* A plain answer, a number written as a formula: its value, refused if it
   is not plain or holds a function or a variable. *)
let plain_number what = function
  | Rhema_engine.Plain (Rhema_engine.Formula f) ->
      if functions f then failwith (what ^ " is written with a function or a variable");
      (F.evaluate_with (fun _ -> None) f, Some f)
  | Rhema_engine.Plain (Rhema_engine.Num n) -> (Rhema_number.to_float n, None)
  | other -> failwith (what ^ " is not a plain number: " ^ Rhema_engine.describe_value other)

let fraction_answer what = function
  | Rhema_engine.Num n -> of_number n
  | other -> failwith (what ^ " is not a number: " ^ Rhema_engine.describe_value other)

(* A fraction times pi, the fraction positive. *)
let times_pi = function
  | F.Pi -> true
  | F.Multiply (F.Constant c, F.Pi) -> Rhema_number.to_float c > 0.
  | _ -> false

(* A fraction times sqrt(3), the fraction positive. *)
let times_root_3 = function
  | F.Sqrt (F.Constant c) -> Rhema_number.equal c (Rhema_number.of_int 3)
  | F.Multiply (F.Constant c, F.Sqrt (F.Constant three)) ->
      Rhema_number.to_float c > 0. && Rhema_number.equal three (Rhema_number.of_int 3)
  | _ -> false

(* ---- Reading the printed question --------------------------------------------- *)

type reader = { text : string; mutable at : int; mutable blanks : Rhema_engine.value list }

let follows r s =
  let n = String.length s in
  r.at + n <= String.length r.text && String.sub r.text r.at n = s

let literal r s =
  if follows r s then r.at <- r.at + String.length s
  else failwith (Printf.sprintf "cannot read the text: %S was expected at character %d" s r.at)

let optional r s =
  let found = follows r s in
  if found then r.at <- r.at + String.length s;
  found

let take r re =
  if Str.string_match (Str.regexp re) r.text r.at then begin
    let found = Str.matched_string r.text in
    r.at <- Str.match_end ();
    found
  end
  else failwith (Printf.sprintf "cannot read the text at character %d" r.at)

let blank r =
  literal r "[___]";
  match r.blanks with
  | first :: rest ->
      r.blanks <- rest;
      first
  | [] -> failwith "a blank of the text has no answer"

let finish r =
  if r.at <> String.length r.text then failwith (Printf.sprintf "cannot read the text from character %d on" r.at);
  if r.blanks <> [] then failwith "there are more answers than blanks in the text"

(* A whole number, written as OCaml would write it. *)
let integer r =
  let s = take r "-?[0-9]+" in
  let n = int_of_string s in
  if string_of_int n <> s then failwith ("a number not written as it should be: " ^ s);
  n

(* A number in front of a letter: nothing for 1, never "1" or "0". *)
let factor r =
  match take r "[0-9]*" with
  | "" -> 1
  | s ->
      let n = int_of_string s in
      if n < 2 || string_of_int n <> s then failwith ("a factor not written as it should be: " ^ s);
      n

let polynomial r = read_poly (take r "[^`]+")

let trig r =
  if optional r {|\cos|} then "cos"
  else begin
    literal r {|\sin|};
    "sin"
  end

let apply name x = if name = "cos" then cos x else sin x
let exact_text = {| Give the exact value, with [`\pi`] written as pi where it is needed.|}

(* ---- What was generated ---------------------------------------------------- *)

let noted : (string * string, string list) Hashtbl.t = Hashtbl.create 64

let note k name value =
  let before = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
  if not (List.mem value before) then Hashtbl.replace noted (k, name) (value :: before)

let note_int k name n = note k name (string_of_int n)

let note_poly k letter (p : poly) =
  Array.iteri (fun d c -> note_int k (Printf.sprintf "%s t^%d" letter d) c) p

(* dx/dt and dy/dt where they are at most 6 in size: every such value
   comes up. *)
let note_small k dx dy =
  if abs dx <= 6 then note_int k "small dx/dt" dx;
  if abs dy <= 6 then note_int k "small dy/dt" dy

(* The answers of the lune, by b, to see that cos and sin give the same. *)
let lunes : (int, float) Hashtbl.t = Hashtbl.create 8

(* Which mistakes were listed on which kinds. *)
let made : (string * string, unit) Hashtbl.t = Hashtbl.create 16

(* The description of each mistake, word for word. *)
let spoken =
  [ ("inverted_slope", "takes dx/dt over dy/dt for the slope, where dy/dt over dx/dt belongs");
    ("sine_cosine_swapped", "takes r sin(theta) for x and r cos(theta) for y");
    ("half_forgotten", "leaves out the 1/2 of the area in polar coordinates, the integral of r^2 / 2");
    ("second_over_second", "takes y''(t) over x''(t) for the second derivative") ]

let made_on =
  [ ("inverted_slope", [ "slope"; "tangent" ]);
    ("sine_cosine_swapped", [ "polar_point" ]);
    ("half_forgotten", [ "petal"; "cardioid"; "circle"; "lune" ]);
    ("second_over_second", [ "second_derivative" ]) ]

(* The mistakes listed on a question against those expected: each name with
   a test of the answers it gives, which raises Failure when they are not
   the ones redone here or are the right ones. *)
let mistakes k (q : Rhema_engine.question) expected =
  let listed = q.Rhema_engine.mistakes in
  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
  if names <> List.map fst expected then
    failwith
      (Printf.sprintf "the mistakes listed are [%s], not [%s]" (String.concat ", " names)
         (String.concat ", " (List.map fst expected)));
  List.iter2
    (fun (m : Rhema_engine.mistaken) (_, test) ->
      Hashtbl.replace made (m.mistake, k) ();
      if m.description <> List.assoc m.mistake spoken then
        failwith (Printf.sprintf "%s is described as %S" m.mistake m.description);
      match m.mistaken_answers with
      | Some answers -> test answers
      | None -> failwith (m.mistake ^ " gives no answer"))
    listed expected

(* One mistaken number against the one redone here and the right one. *)
let one_number name redone right = function
  | [ given ] ->
      let value, _ = plain_number ("the answer of " ^ name) given in
      if not (close value redone) then failwith (Printf.sprintf "%s gives %.12g, redone here %.12g" name value redone);
      if close value right then failwith (name ^ " gives the right answer")
  | _ -> failwith (name ^ " does not give one answer")

let one_fraction name redone right = function
  | [ given ] ->
      let value = fraction_answer ("the answer of " ^ name) given in
      if value <> redone then failwith (Printf.sprintf "%s gives %s, redone here %s" name (print value) (print redone));
      if value = right then failwith (name ^ " gives the right answer")
  | _ -> failwith (name ^ " does not give one answer")

(* ---- The forms ------------------------------------------------------------------ *)

(* x and y of a curve, the point t, as "A curve is given by ..." prints them. *)
let curve r =
  literal r "A curve is given by [`x = ";
  let x = polynomial r in
  literal r "`], [`y = ";
  let y = polynomial r in
  literal r "`]. ";
  (x, y)

(* dx/dt and dy/dt at a whole t, by differentiating term by term. *)
let speeds x y t = (at_int (derive x) t, at_int (derive y) t)

(* The slope of a chord of the curve across t, in floating point. *)
let chord x y t =
  let h = 1e-4 in
  (at y (float t +. h) -. at y (float t -. h)) /. (at x (float t +. h) -. at x (float t -. h))

(* Whether the curve lies on a straight line: three of its points are then
   on one line, which three points of a parabola never are. *)
let straight x y t =
  let px s = at_int x s and py s = at_int y s in
  ((px t - px (t - 1)) * (py (t + 1) - py t)) - ((py t - py (t - 1)) * (px (t + 1) - px t)) = 0

(* A line answer m x + c: m and c. *)
let line what = function
  | Rhema_engine.Polynomial p ->
      if Rhema_polynomial.variable_name p <> "x" then failwith (what ^ " is not a polynomial in x");
      if Rhema_polynomial.degree p <> Some 1 then failwith (what ^ " is not of the first degree");
      (of_number (Rhema_polynomial.coefficient p 1), of_number (Rhema_polynomial.coefficient p 0))
  | other -> failwith (what ^ " is not a polynomial: " ^ Rhema_engine.describe_value other)

(* A line through the point (x(t), y(t)) of the curve with the slope
   dy / dx where dy and dx are given. *)
let line_through what x y t (slope, constant) ~dy ~dx =
  if slope */ whole dx <> whole dy then failwith (Printf.sprintf "%s has the slope %s" what (print slope));
  if (slope */ whole (at_int x t)) +/ constant <> whole (at_int y t) then failwith (what ^ " misses the point")

let examine k (q : Rhema_engine.question) =
  let r = { text = q.Rhema_engine.prompt; at = 0; blanks = q.Rhema_engine.answers } in
  match k with
  | "slope" ->
      let x, y = curve r in
      literal r {|Find the slope [`\frac{dy}{dx}`] of the curve at the point where [`t = |};
      let t = integer r in
      literal r "`]. ";
      let answer = fraction_answer "the answer" (blank r) in
      finish r;
      let dx, dy = speeds x y t in
      if dx = 0 || dy = 0 then failwith "dx/dt or dy/dt is 0 there";
      if abs dx = abs dy then failwith "dx/dt and dy/dt are equal in size";
      if straight x y t then failwith "the curve lies on a straight line";
      if answer <> ratio dy dx then failwith (Printf.sprintf "the slope is %s" (print (ratio dy dx)));
      if not (near 1e-6 (to_float answer) (chord x y t)) then failwith "the slope of a short chord is another";
      mistakes k q [ ("inverted_slope", one_fraction "inverted_slope" (ratio dx dy) answer) ];
      note_small k dx dy;
      note_poly k "x" x;
      note_poly k "y" y;
      note_int k "t" t
  | "tangent" ->
      let x, y = curve r in
      literal r "Find the tangent line to the curve at the point where [`t = ";
      let t = integer r in
      literal r "`], as [`y = mx + c`]. Enter the right-hand side. ";
      let answer = line "the answer" (blank r) in
      finish r;
      let dx, dy = speeds x y t in
      if dx = 0 || dy = 0 then failwith "dx/dt or dy/dt is 0 there";
      if abs dx = abs dy then failwith "dx/dt and dy/dt are equal in size";
      if straight x y t then failwith "the curve lies on a straight line";
      line_through "the answer" x y t answer ~dy ~dx;
      note_small k dx dy;
      if not (near 1e-6 (to_float (fst answer)) (chord x y t)) then failwith "the slope of a short chord is another";
      mistakes k q
        [ ( "inverted_slope",
            function
            | [ given ] ->
                let wrong = line "the answer of inverted_slope" given in
                line_through "the line of inverted_slope" x y t wrong ~dy:dx ~dx:dy;
                if wrong = answer then failwith "inverted_slope gives the right answer"
            | _ -> failwith "inverted_slope does not give one answer" ) ];
      note_poly k "x" x;
      note_poly k "y" y;
      note_int k "t" t
  | "second_derivative" ->
      let x, y = curve r in
      literal r {|Find [`\frac{d^{2}y}{dx^{2}}`] at the point where [`t = |};
      let t = integer r in
      literal r "`]. ";
      let answer = fraction_answer "the answer" (blank r) in
      finish r;
      let dx, _ = speeds x y t in
      if dx = 0 || abs dx > 6 then failwith (Printf.sprintf "dx/dt is %d there" dx);
      (* dy/dx along the curve, and its change against the change of x *)
      let slope s = at (derive y) s /. at (derive x) s in
      let quotient h =
        let a = float t -. h and b = float t +. h in
        (slope b -. slope a) /. (at x b -. at x a)
      in
      let h = 1e-4 in
      let found = ((4. *. quotient (h /. 2.)) -. quotient h) /. 3. in
      if not (near 1e-7 (to_float answer) found) then
        failwith (Printf.sprintf "the second derivative is %.10g, worked out here %.10g" (to_float answer) found);
      if answer.top = 0 then failwith "the second derivative is 0";
      (* the second derivatives in t, as second differences *)
      let second p = at_int p (t + 1) - (2 * at_int p t) + at_int p (t - 1) in
      note_int k "dx/dt" dx;
      mistakes k q [ ("second_over_second", one_fraction "second_over_second" (ratio (second y) (second x)) answer) ];
      note_poly k "x" x;
      note_poly k "y" y;
      note_int k "t" t
  | "length" ->
      literal r "Find the length of the curve [`x = ";
      let x = polynomial r in
      literal r "`], [`y = ";
      let y = polynomial r in
      literal r "`] from [`t = ";
      let a = integer r in
      literal r "`] to [`t = ";
      let b = integer r in
      literal r "`]. ";
      let answer = fraction_answer "the answer" (blank r) in
      finish r;
      if a >= b then failwith "the limits are not in order";
      let speed s = Float.hypot (at (derive x) s) (at (derive y) s) in
      let integral = simpson speed (float a) (float b) 2000 in
      let chords = 20000 in
      let polyline = ref 0. in
      for i = 0 to chords - 1 do
        let s0 = float a +. (float (b - a) *. float i /. float chords)
        and s1 = float a +. (float (b - a) *. float (i + 1) /. float chords) in
        polyline := !polyline +. Float.hypot (at x s1 -. at x s0) (at y s1 -. at y s0)
      done;
      if not (close (to_float answer) integral) then failwith (Printf.sprintf "the length is %.12g" integral);
      if not (near 1e-6 !polyline integral) then failwith "the polyline is not as long as the integral says";
      if answer.bottom <> 1 then failwith "the length is not a whole number";
      (* the curve of the header: k (t^3 - 3t) + h, 3k t^2 + v *)
      if not (x.(1) = -3 * x.(3) && x.(2) = 0 && y.(2) = 3 * x.(3) && y.(1) = 0 && y.(3) = 0) then
        failwith "the curve is not k (t^3 - 3t) + h, 3k t^2 + v";
      mistakes k q [];
      note_poly k "x" x;
      note_poly k "y" y;
      note k "limits" (Printf.sprintf "%d to %d" a b)
  | "polar_point" ->
      literal r "A point has the polar coordinates [`r = ";
      let radius = integer r in
      literal r {|`], [`\theta = \frac{|};
      let top = factor r in
      literal r {|\pi}{|};
      let bottom = integer r in
      literal r "}`]. Find its Cartesian coordinates, exactly, with a square root written as sqrt. [`x = `] ";
      let across, _ = plain_number "x" (blank r) in
      literal r " [`y = `] ";
      let up, _ = plain_number "y" (blank r) in
      finish r;
      if bottom < 2 || gcd top bottom <> 1 then failwith "the angle is not a fraction in lowest terms";
      if 12 * top mod bottom <> 0 then failwith "the angle is not a whole number of twelfths of pi";
      let theta = float top *. pi /. float bottom in
      let rx = float radius *. cos theta and ry = float radius *. sin theta in
      if not (close across rx) then failwith (Printf.sprintf "x is %.12g" rx);
      if not (close up ry) then failwith (Printf.sprintf "y is %.12g" ry);
      if Float.abs rx < 1e-9 || Float.abs ry < 1e-9 then failwith "the angle lies on an axis";
      let swapped =
        if close rx ry then []
        else
          [ ( "sine_cosine_swapped",
              function
              | [ a; b ] ->
                  let a, _ = plain_number "the x of sine_cosine_swapped" a
                  and b, _ = plain_number "the y of sine_cosine_swapped" b in
                  if not (close a ry && close b rx) then
                    failwith (Printf.sprintf "sine_cosine_swapped gives %.12g, %.12g" a b)
              | _ -> failwith "sine_cosine_swapped does not give two answers" ) ]
      in
      mistakes k q swapped;
      note k "swap" (if swapped = [] then "not listed" else "listed");
      note_int k "r" radius;
      note_int k "angle" (12 * top / bottom)
  | "petal" ->
      literal r "Find the area of one petal of the rose [`r = ";
      let a = factor r in
      let name = trig r in
      literal r "(";
      let n = integer r in
      literal r {|\theta)`].|};
      literal r exact_text;
      literal r " ";
      let answer, formula = plain_number "the answer" (blank r) in
      finish r;
      let radius theta = float a *. apply name (float n *. theta) in
      let zeros = sign_changes radius 0.0123 (2. *. pi) in
      let z1, z2 = match zeros with z1 :: z2 :: _ -> (z1, z2) | _ -> failwith "the rose has no petal" in
      if not (near 1e-9 (z2 -. z1) (pi /. float n)) then failwith "two zeros of r are not pi/k apart";
      let area = simpson (fun theta -> radius theta ** 2. /. 2.) z1 z2 4000 in
      if not (close answer area) then failwith (Printf.sprintf "the area is %.12g" area);
      if not (match formula with Some f -> times_pi f | None -> false) then failwith "the area is not a fraction times pi";
      mistakes k q [ ("half_forgotten", one_number "half_forgotten" (2. *. area) answer) ];
      note_int k "a" a;
      note_int k "k" n;
      note k "function" name
  | "cardioid" | "circle" ->
      literal r "Find the area of the region enclosed by the curve [`r = ";
      let cardioid = not (follows r "-" || Str.string_match (Str.regexp "[0-9]+\\\\") r.text r.at) in
      let radius, scale, sign, name =
        if cardioid then begin
          (* 1 - cos(theta) bare, a (1 - cos(theta)) in brackets for a above 1 *)
          let a = if follows r "1 " then 1 else factor r in
          if a > 1 then literal r "(";
          literal r "1 ";
          let sign = take r "[+-]" in
          literal r " ";
          let name = trig r in
          literal r {|\theta|};
          if a > 1 then literal r ")";
          let s = if sign = "+" then 1. else -1. in
          ((fun theta -> float a *. (1. +. (s *. apply name theta))), a, sign, name)
        end
        else begin
          let sign = if optional r "-" then "-" else "+" in
          let d = integer r in
          let name = trig r in
          literal r {|\theta|};
          if d mod 2 <> 0 || d < 2 then failwith "the diameter is not an even number";
          let s = if sign = "+" then 1. else -1. in
          ((fun theta -> s *. float d *. apply name theta), d / 2, sign, name)
        end
      in
      literal r "`].";
      literal r exact_text;
      literal r " ";
      let answer, formula = plain_number "the answer" (blank r) in
      finish r;
      if cardioid <> (k = "cardioid") then failwith "the curve is not of its kind";
      let point theta = (radius theta *. cos theta, radius theta *. sin theta) in
      let returns period =
        List.for_all
          (fun theta ->
            let x0, y0 = point theta and x1, y1 = point (theta +. period) in
            Float.abs (x0 -. x1) +. Float.abs (y0 -. y1) < 1e-9 *. float scale)
          [ 0.3; 1.1; 2.9; 4.4; 5.7 ]
      in
      let period =
        match List.find_opt (fun j -> returns (float j *. pi /. 12.)) (List.init 24 (fun j -> j + 1)) with
        | Some j -> float j *. pi /. 12.
        | None -> failwith "the curve does not close"
      in
      if not (close period (if cardioid then 2. *. pi else pi)) then failwith (Printf.sprintf "the curve is traced once in %g" period);
      let area = simpson (fun theta -> radius theta ** 2. /. 2.) 0. period 4000 in
      let polygon = Array.init 20000 (fun i -> point (period *. float i /. 20000.)) in
      if not (near 1e-6 (shoelace polygon) area) then failwith "the polygon along the curve has another area";
      if not (close answer area) then failwith (Printf.sprintf "the area is %.12g" area);
      if not (match formula with Some f -> times_pi f | None -> false) then failwith "the area is not a fraction times pi";
      mistakes k q [ ("half_forgotten", one_number "half_forgotten" (2. *. area) answer) ];
      note_int k "a" scale;
      note k "sign" sign;
      note k "function" name;
      (* the sign and the function are drawn together, so both are pinned
         together as well *)
      note k "curve" (sign ^ " " ^ name)
  | "lune" ->
      literal r "Find the area of the region inside the circle [`r = ";
      let d = integer r in
      let name = trig r in
      literal r {|\theta`] and outside the circle [`r = |};
      let b = integer r in
      literal r {|`]. Give the exact value, with [`\pi`] written as pi and a square root as sqrt. |};
      let answer, formula = plain_number "the answer" (blank r) in
      finish r;
      if d <> 2 * b then failwith "the outer circle is not twice the inner one";
      let outer theta = float d *. apply name theta in
      let gap theta = outer theta -. float b in
      let t1, t2 =
        match sign_changes gap (-.pi +. 0.0123) (2. *. pi) with
        | [ t1; t2 ] -> (t1, t2)
        | _ -> failwith "the circles do not cross twice"
      in
      if not (gap ((t1 +. t2) /. 2.) > 0.) then failwith "the outer circle is not outside between the crossings";
      let area = simpson (fun theta -> ((outer theta ** 2.) -. float (b * b)) /. 2.) t1 t2 4000 in
      if not (close answer area) then failwith (Printf.sprintf "the area is %.12g" area);
      (* a coarse count of the points of a grid in the region *)
      let n = 400 in
      let side = 2. *. float d in
      let cell = side /. float n in
      let count = ref 0 in
      for i = 0 to n - 1 do
        for j = 0 to n - 1 do
          let px = (-.float d) +. ((float i +. 0.5) *. cell) and py = (-.float d) +. ((float j +. 0.5) *. cell) in
          let rho = Float.hypot px py and phi = atan2 py px in
          if rho < outer phi && rho > float b then incr count
        done
      done;
      let counted = float !count *. cell *. cell in
      if not (Float.abs (counted -. area) <= 0.02 *. area) then
        failwith (Printf.sprintf "a grid counts %g for the area %g" counted area);
      (match formula with
      | Some (F.Add (p, s)) when times_pi p && times_root_3 s -> ()
      | _ -> failwith "the area is not a fraction times pi plus a fraction times sqrt(3)");
      Hashtbl.add lunes b answer;
      mistakes k q [ ("half_forgotten", one_number "half_forgotten" (2. *. area) answer) ];
      note_int k "b" b;
      note k "function" name
  | _ -> failwith "an unknown kind"

(* ---- Kinds, prices and numbers --------------------------------------------- *)

let prices =
  [ ("slope", 1); ("polar_point", 1); ("tangent", 2); ("petal", 2); ("cardioid", 2); ("circle", 2);
    ("second_derivative", 3); ("length", 3); ("lune", 3) ]

let blanks_of k = if k = "polar_point" then 2 else 1
let ints a b = List.init (b - a + 1) (fun i -> string_of_int (a + i))
let nonzero a b = List.filter (fun s -> s <> "0") (ints a b)
let only values = List.map string_of_int values

let quadratic letter =
  [ (letter ^ " t^3", only [ 0 ]); (letter ^ " t^2", nonzero (-3) 3); (letter ^ " t^1", ints (-5) 5);
    (letter ^ " t^0", ints (-5) 5) ]

let small = [ ("small dx/dt", nonzero (-6) 6); ("small dy/dt", nonzero (-6) 6) ]
let curves = [ "+ cos"; "- cos"; "+ sin"; "- sin" ]

let allowed =
  [ ("slope", quadratic "x" @ quadratic "y" @ [ ("t", ints (-3) 3) ] @ small);
    ("tangent", quadratic "x" @ quadratic "y" @ [ ("t", ints (-3) 3) ] @ small);
    ( "polar_point",
      [ ("r", ints 1 6); ("angle", only [ 2; 3; 4; 8; 9; 10; 14; 15; 16; 20; 21; 22 ]); ("swap", [ "listed"; "not listed" ]) ]
    );
    ("petal", [ ("a", ints 1 6); ("k", ints 2 5); ("function", [ "cos"; "sin" ]) ]);
    ("cardioid", [ ("a", ints 1 6); ("sign", [ "+"; "-" ]); ("function", [ "cos"; "sin" ]); ("curve", curves) ]);
    ("circle", [ ("a", ints 1 6); ("sign", [ "+"; "-" ]); ("function", [ "cos"; "sin" ]); ("curve", curves) ]);
    ( "second_derivative",
      [ ("x t^3", only [ 0 ]); ("x t^2", nonzero (-3) 3); ("x t^1", ints (-5) 5); ("x t^0", only [ 0 ]);
        ("y t^3", nonzero (-3) 3); ("y t^2", only [ 0 ]); ("y t^1", ints (-5) 5); ("y t^0", only [ 0 ]); ("t", ints (-2) 2);
        ("dx/dt", nonzero (-6) 6) ]
    );
    ( "length",
      [ ("x t^3", only [ 1; 2; 3 ]); ("x t^2", only [ 0 ]); ("x t^1", only [ -3; -6; -9 ]); ("x t^0", ints (-5) 5);
        ("y t^3", only [ 0 ]); ("y t^2", only [ 3; 6; 9 ]); ("y t^1", only [ 0 ]); ("y t^0", ints (-5) 5);
        ("limits", [ "0 to 1"; "0 to 2"; "0 to 3"; "1 to 2"; "1 to 3"; "2 to 3" ]) ] );
    ("lune", [ ("b", ints 1 5); ("function", [ "cos"; "sin" ]) ]) ]

let seen : (string, unit) Hashtbl.t = Hashtbl.create 16

(* A question looked at already, with the same answers and mistakes, is not
   worked out again. *)
let examined : (string, unit) Hashtbl.t = Hashtbl.create 4096

let check cost (q : Rhema_engine.question) =
  let k = kind q and p = q.Rhema_engine.prompt in
  Hashtbl.replace seen k ();
  (match List.assoc_opt k prices with
  | Some price -> if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost)
  | None -> fail ("a kind the header does not list: " ^ k));
  if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
  if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
  if List.length q.Rhema_engine.answers <> blanks_of k then
    fail (Printf.sprintf "%s has %d blanks: %S" k (List.length q.Rhema_engine.answers) p);
  if q.Rhema_engine.answers <> [] && List.hd q.Rhema_engine.answers <> q.Rhema_engine.answer then
    fail (k ^ ": the answer is not the one of the first blank");
  let whole_question = String.concat "\n" (k :: p :: q.Rhema_engine.answer_text :: Rhema_engine.describe_mistakes q) in
  if not (Hashtbl.mem examined whole_question) then begin
    Hashtbl.replace examined whole_question ();
    try examine k q with
    | Failure m -> fail (Printf.sprintf "%s: %s, answers %s, for %S" k m q.Rhema_engine.answer_text p)
    | e -> fail (Printf.sprintf "%s: %s, for %S" k (Printexc.to_string e) p)
  end

(* ---- The working of this file, tried on its own ---------------------------- *)

let check_own_working () =
  List.iter
    (fun (text, wanted) ->
      match read_poly text with
      | p -> if Some (Array.to_list p) <> wanted then fail ("own working: " ^ text ^ " is read wrongly")
      | exception Failure _ -> if wanted <> None then fail ("own working: " ^ text ^ " is refused"))
    [ ("t^{2} - 2t - 3", Some [ -3; -2; 1; 0 ]);
      ("-2t^{2} + 4t + 2", Some [ 2; 4; -2; 0 ]);
      ("-t^{3} - 3t", Some [ 0; -3; 0; -1 ]);
      ("3t^{3} - 9t + 4", Some [ 4; -9; 0; 3 ]);
      ("t^{2} + 3", Some [ 3; 0; 1; 0 ]);
      ("1t^{2}", None);
      ("t^{1}", None);
      ("t^{2} + 0", None);
      ("t^{2} + 0t", None);
      ("3 + t^{2}", None);
      ("+t^{2}", None);
      ("t^{2} + -3", None);
      ("t^{2}+3", None);
      ("2t^{4}", None) ];
  (* the areas, on curves whose areas are known *)
  let disc = simpson (fun _ -> 1. /. 2.) 0. (2. *. pi) 10 in
  if not (close disc pi) then fail "own working: the unit disc";
  let square = shoelace [| (0., 0.); (2., 0.); (2., 2.); (0., 2.) |] in
  if not (close square 4.) then fail "own working: the square of side 2";
  match sign_changes cos 0.0123 (2. *. pi) with
  | [ a; b ] -> if not (close a (pi /. 2.) && close b (3. *. pi /. 2.)) then fail "own working: the zeros of cos"
  | _ -> fail "own working: cos does not have two zeros in a turn"

let () =
  check_own_working ();
  let base = load_file "parametric_polar.rhm" in
  let per_budget = function 1 -> 2000 | 2 -> 4000 | _ -> 6000 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to per_budget cost - 1 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> check cost q
    done
  done;
  (* left alone, the budget is the middle price *)
  for seed = 0 to 99 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 then
          fail ("the grammar's own budget gave a question that is not of price 2: " ^ kind q);
        check 2 q
  done;
  (* no question outside the three prices *)
  List.iter
    (fun cost ->
      match Rhema_check.with_initial base "cost" cost with
      | Error _ -> ()
      | Ok spec ->
          for seed = 0 to 19 do
            Random.init seed;
            match Rhema_engine.generate spec with
            | exception Rhema_engine.Generation_error _ -> ()
            | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
          done)
    [ 0; 4; 5; 6 ];
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  (* the numbers of each form: all of these and no others *)
  List.iter
    (fun (k, names) ->
      List.iter
        (fun (name, values) ->
          let found = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
          let missing = List.filter (fun v -> not (List.mem v found)) values in
          let more = List.filter (fun v -> not (List.mem v values)) found in
          if missing <> [] then fail (Printf.sprintf "%s: the %s never takes the values [%s]" k name (String.concat "; " missing));
          if more <> [] then fail (Printf.sprintf "%s: the %s takes the values [%s] too" k name (String.concat "; " more)))
        names)
    allowed;
  Hashtbl.iter
    (fun (k, name) _ ->
      match List.assoc_opt k allowed with
      | Some names when List.mem_assoc name names -> ()
      | _ -> fail (Printf.sprintf "%s: the %s was noted and is not looked at" k name))
    noted;
  (* the lune with sin has the area of the lune with cos *)
  Hashtbl.iter
    (fun b area ->
      List.iter
        (fun other -> if not (close other area) then fail (Printf.sprintf "lune: two areas for b = %d" b))
        (Hashtbl.find_all lunes b))
    lunes;
  (* each mistake was listed on each kind it can be made in, and on no other *)
  List.iter
    (fun (mistake, kinds) ->
      List.iter
        (fun k -> if not (Hashtbl.mem made (mistake, k)) then fail (Printf.sprintf "%s never listed on %s" mistake k))
        kinds)
    made_on;
  Hashtbl.iter
    (fun (mistake, k) () ->
      match List.assoc_opt mistake made_on with
      | Some kinds when List.mem k kinds -> ()
      | _ -> fail (Printf.sprintf "%s listed on %s" mistake k))
    made;
  if !failures = 0 then print_endline "Rhema parametric and polar tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d parametric and polar test(s) failed." !failures);
    exit 1
  end
