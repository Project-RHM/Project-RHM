(* Independent checks for complex_polar.rhm. Nothing is taken from the
   grammar but the printed question: the whole text is read from its first
   character to its last, each blank is paired with the words written just
   before it, and the numbers of the question (moduli, angles such as
   \frac{5\pi}{6}, numbers a + bi with their \sqrt{3} parts, exponents, the
   right-hand side of z^n = w, the limits of the range asked for) are read
   back as floating-point numbers. Every answer is then found again here
   with complex arithmetic on floats and must agree with the engine's within
   1e-9. A text that cannot be read is a failure.

   Every answer must be a plain answer. An argument given as an answer must
   also be exact in form: written with pi alone and a multiple of pi/24. It
   must lie in the range the question prints, read with its two inequality
   signs and applied as printed: -pi < theta <= pi takes pi and refuses -pi,
   0 <= theta < 2 pi takes 0. That range must be one whole turn with exactly
   one of its ends in it, and the argument worked out here is brought into
   it by whole turns before it is compared.

   Product and quotient: z and w are built from the two printed polar forms
   and multiplied or divided. The modulus answered must be the modulus of
   the result, the argument its atan2, and r (cos t + i sin t) with the two
   answers must be the result.

   To a + bi: the number is built from the printed modulus and angle; the
   two blanks must be its real and imaginary parts, and the angle must not
   lie along an axis. Each part must be in its simplest form, which is
   looked for in the tree of the answer's formula: a whole number, sqrt(2)
   or sqrt(3), or one whole number other than 1, -1 and 0 times such a
   root, with at most one minus sign; no fraction and no further product.

   Modulus and argument of a + bi: the modulus is sqrt(a^2 + b^2), in its
   simplest form as above, and the argument atan2(b, a). The number must
   point in one of the twelve directions the header names: parts k and k,
   or k sqrt(3) and k.

   Power of a polar form: z is built from the printed modulus and angle and
   multiplied by itself as often as the exponent says; the answers must be
   the modulus and the atan2 of that product.

   De Moivre: the printed a + bi is multiplied by itself as often as the
   exponent says; the two blanks must be the real and imaginary parts of the
   product, both whole numbers, one of them 0.

   Roots of z^n = w: the modulus answered, with each of the two arguments
   answered, must give a number whose n-th power (by repeated
   multiplication) is w. The text must say there are n solutions. All n
   roots are listed here as (arg w + 2 pi j) / n brought into the stated
   range and sorted; the two answers must be the first two of that list, so
   they are different, in increasing order and the smallest.

   Besides the answers: each kind appears at its price alone and spends its
   budget, each form has the number of blanks its text announces, a budget
   outside 1..3 gives no question, the budget the grammar sets itself is the
   middle price, and the numbers that were generated for
   each form (moduli, angles, exponents, shapes, quadrants) are exactly the
   ones expected, none missing and none more. *)

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
let turn = 2. *. pi
let close a b = Float.abs (a -. b) <= 1e-9 *. Float.max 1. (Float.abs b)

(* Two complex numbers that are the same within the tolerance. *)
let near z w = Complex.norm (Complex.sub z w) <= 1e-9 *. Float.max 1. (Complex.norm w)
let of_polar modulus angle = { Complex.re = modulus *. cos angle; im = modulus *. sin angle }
let rec power z n = if n <= 0 then Complex.one else Complex.mul z (power z (n - 1))

(* The range an argument is asked in, as the question prints it: the two
   limits, and for each whether it belongs to the range. *)
type range = { low : float; low_in : bool; high : float; high_in : bool }

(* An angle brought into the range by whole turns. An angle at an end of
   the range, or a rounding error away from it, goes to the end that
   belongs to the range. *)
let into_range range t =
  let s = t -. range.low in
  let s = s -. (turn *. Float.floor (s /. turn)) in
  if s < 1e-9 || s > turn -. 1e-9 then if range.low_in then range.low else range.high else range.low +. s

(* ---- The answers ---------------------------------------------------------- *)

(* What an answer comes to, whether it is graded with the functions switched
   off, what it is written with, and whether it is written in the simplest
   form of a whole number or a whole multiple of sqrt(2) or sqrt(3). *)
type answer = { number : float; plain : bool; functions : bool; surds : bool; simplest : bool }

let rec has test formula =
  test formula
  ||
  match formula with
  | F.Constant _ | F.Pi | F.Variable _ -> false
  | F.Add (a, b) | F.Subtract (a, b) | F.Multiply (a, b) | F.Divide (a, b) -> has test a || has test b
  | F.Power (a, _) | F.Negate a | F.Sin a | F.Cos a | F.Tan a | F.Exp a | F.Ln a | F.Sqrt a -> has test a

(* The simplest form: 3, -3, sqrt(2), -sqrt(3), 2 sqrt(3), -2 sqrt(3). The
   minus sign is a negative number or one negation around the rest, never
   both; a root is of 2 or of 3; a number in front of a root is not 1, -1
   or 0. So 4 sqrt(2)/2, 2 * 1/2 and 1 sqrt(2) are all refused. *)
let simplest formula =
  let root = function
    | F.Sqrt (F.Constant c) -> Rhema_number.to_float c = 2. || Rhema_number.to_float c = 3.
    | _ -> false
  in
  let multiple ~signed = function
    | F.Constant c -> Rhema_number.is_integer c && (signed || Rhema_number.to_float c > 0.)
    | F.Multiply (F.Constant c, r) ->
        let v = Rhema_number.to_float c in
        Rhema_number.is_integer c && root r && if signed then Float.abs v > 1. else v > 1.
    | r -> root r
  in
  match formula with F.Negate body -> multiple ~signed:false body | body -> multiple ~signed:true body

let answer value =
  let of_formula plain f =
    { number = F.evaluate_with (fun _ -> None) f;
      plain;
      functions = has (function F.Sin _ | F.Cos _ | F.Tan _ | F.Exp _ | F.Ln _ | F.Variable _ -> true | _ -> false) f;
      surds = has (function F.Sqrt _ -> true | _ -> false) f;
      simplest = simplest f }
  and of_number plain n =
    { number = Rhema_number.to_float n; plain; functions = false; surds = false; simplest = Rhema_number.is_integer n }
  in
  match value with
  | Rhema_engine.Plain (Rhema_engine.Formula f) -> of_formula true f
  | Rhema_engine.Plain (Rhema_engine.Num n) -> of_number true n
  | Rhema_engine.Formula f -> of_formula false f
  | Rhema_engine.Num n -> of_number false n
  | other -> failwith ("not a number: " ^ Rhema_engine.describe_value other)

(* ---- Reading the printed question ----------------------------------------- *)

(* The text is read from left to right; `at` is how far it has been read and
   `blanks` the answers of the blanks not yet met. *)
type reader = { text : string; mutable at : int; mutable blanks : answer list }

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

(* A blank of the text, shown as [___], with the answer it is graded against. *)
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

let whole r = int_of_string (take r "[0-9]+")

(* An exact number as it is written in LaTeX here: a whole number, \sqrt{n},
   \frac{a}{b} with a and b either of those, a multiple of \pi such as
   \frac{5\pi}{6} or 2\pi, and a minus sign in front of any of them. *)
let exact_re = "\\(-\\|[0-9{}]\\|\\\\frac\\|\\\\pi\\|\\\\sqrt\\)+"

let rec number text =
  if text = "" then failwith "an empty number"
  else if text.[0] = '-' then -.number (String.sub text 1 (String.length text - 1))
  else if Str.string_match (Str.regexp "^\\\\frac{\\([^{}]*\\)}{\\([^{}]*\\)}$") text 0 then
    let top = Str.matched_group 1 text and bottom = Str.matched_group 2 text in
    number top /. number bottom
  else if Str.string_match (Str.regexp "^\\\\sqrt{\\([0-9]+\\)}$") text 0 then sqrt (float_of_string (Str.matched_group 1 text))
  else if Str.string_match (Str.regexp "^\\([0-9]*\\)\\\\pi$") text 0 then
    (match Str.matched_group 1 text with "" -> 1. | digits -> float_of_string digits) *. pi
  else if Str.string_match (Str.regexp "^[0-9]+$") text 0 then float_of_string text
  else failwith ("cannot read the number " ^ text)

let exact r = number (take r exact_re)

(* r \left(\cos t + i \sin t\right), the angle bare or in brackets of its
   own: the modulus and the angle. The angle is printed twice and must be
   the same both times. *)
let polar r =
  let modulus = float (whole r) in
  literal r {|\left(\cos|};
  let angle () =
    if optional r {|\left(|} then begin
      let text = take r exact_re in
      literal r {|\right)|};
      text
    end
    else begin
      literal r " ";
      take r exact_re
    end
  in
  let first = angle () in
  literal r {| + i \sin|};
  let second = angle () in
  literal r {|\right)|};
  if first <> second then failwith "the cosine and the sine are of different angles";
  (modulus, number first)

(* A part of a + bi: a whole number, a square root, or the two together.
   Nothing written is 1, and a 1 is never written in front of a root. *)
let part r =
  let digits = take r "[0-9]*" in
  let radicand =
    if optional r {|\sqrt{|} then begin
      let n = whole r in
      literal r "}";
      Some n
    end
    else None
  in
  if digits = "1" && radicand <> None then failwith "a 1 is written in front of a square root";
  (digits, radicand)

let size (digits, radicand) =
  (if digits = "" then 1. else float_of_string digits) *. match radicand with Some n -> sqrt (float n) | None -> 1.

(* a + bi as it is printed: "-1 + i", "2\sqrt{3} - 2i", "1 - \sqrt{3}\,i". *)
let rectangular r =
  let minus = optional r "-" in
  let real = part r in
  if real = ("", None) then failwith "a + bi has no real part";
  let below =
    if optional r " + " then false
    else begin
      literal r " - ";
      true
    end
  in
  let imaginary = part r in
  if fst imaginary = "1" then failwith "1i is written for i";
  if snd imaginary <> None then literal r {|\,|};
  literal r "i";
  { Complex.re = (if minus then -1. else 1.) *. size real; im = (if below then -1. else 1.) *. size imaginary }

(* The right-hand side of z^n = w: a whole number or a whole multiple of i,
   of either sign: "81", "-27i", "i". *)
let on_axis r =
  let minus = optional r "-" in
  let digits = take r "[0-9]*" in
  let imaginary = optional r "i" in
  if digits = "" && not imaginary then failwith "z^n = w has no right-hand side";
  if digits = "1" && imaginary then failwith "1i is written for i";
  let value = (if minus then -1. else 1.) *. if digits = "" then 1. else float_of_string digits in
  if imaginary then { Complex.re = 0.; im = value } else { Complex.re = value; im = 0. }

(* "[`-\pi < \theta \le \pi`]": the two limits, each with its own sign,
   < leaving the limit out and \le taking it in. *)
let range r =
  let sign () =
    if optional r {| \le |} then true
    else begin
      literal r " < ";
      false
    end
  in
  literal r "[`";
  let low = exact r in
  let low_in = sign () in
  literal r {|\theta|};
  let high_in = sign () in
  let high = exact r in
  literal r "`]";
  { low; low_in; high; high_in }

(* An angle of these questions is a multiple of pi/6 or of pi/4. It is given
   back in twelfths of pi. *)
let twelfths angle =
  let m = angle /. pi *. 12. in
  if Float.abs (m -. Float.round m) > 1e-9 then failwith "an angle that is not a multiple of pi/12";
  let m = int_of_float (Float.round m) in
  if m mod 2 <> 0 && m mod 3 <> 0 then failwith "an angle that is a multiple of neither pi/6 nor pi/4";
  m

(* ---- What was generated --------------------------------------------------- *)

(* The numbers met in each form, to compare at the end with the ones
   expected: none may be missing and none may be new. *)
let noted : (string, string list) Hashtbl.t = Hashtbl.create 32

let note what value =
  let seen = Option.value (Hashtbl.find_opt noted what) ~default:[] in
  if not (List.mem value seen) then Hashtbl.replace noted what (value :: seen)

let note_int what value = note what (string_of_int value)

(* The shape of a + bi, the whole number k in it, and its quadrant. A number
   that is not k and k, or k sqrt(3) and k, has no shape. *)
let note_direction k wrong (z : Complex.t) =
  let a = Float.abs z.re and b = Float.abs z.im in
  let smaller = Float.min a b and larger = Float.max a b in
  if smaller < 1e-9 then wrong "the number lies along an axis"
  else begin
    if Float.abs (smaller -. Float.round smaller) > 1e-9 then wrong "the smaller part is not a whole number";
    let shape =
      if close a b then "k + ki"
      else if close larger (smaller *. sqrt 3.) then if a > b then "k sqrt(3) + ki" else "k + k sqrt(3) i"
      else begin
        wrong "the parts are neither k and k nor k sqrt(3) and k";
        "?"
      end
    in
    note (k ^ ": shape") shape;
    note_int (k ^ ": k") (int_of_float (Float.round smaller));
    note_int (k ^ ": quadrant") (if z.re > 0. then if z.im > 0. then 1 else 4 else if z.im > 0. then 2 else 3)
  end

(* ---- The checks, form by form --------------------------------------------- *)

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answers %s, for %S" k what q.Rhema_engine.answer_text p) in
  let r = { text = p; at = 0; blanks = List.map answer q.Rhema_engine.answers } in
  (* Every answer is graded with the functions switched off. *)
  if List.exists (fun a -> not a.plain) r.blanks then wrong "an answer is not a plain answer";
  (* An argument as an answer: exact in form, and inside the range as it is
     printed, each end in or out as its own sign says. *)
  let argument what a range =
    let parts = a.number /. pi *. 24. in
    if Float.abs (parts -. Float.round parts) > 24e-9 then wrong (what ^ " is not a multiple of pi/24");
    if a.functions || a.surds then wrong (what ^ " is not written with pi alone");
    if not (close (range.high -. range.low) turn) then wrong "the range asked for is not one whole turn";
    if range.low_in = range.high_in then wrong "the range asked for does not take in exactly one of its ends";
    let above = if range.low_in then a.number >= range.low -. 1e-9 else a.number > range.low +. 1e-9
    and below = if range.high_in then a.number <= range.high +. 1e-9 else a.number < range.high -. 1e-9 in
    if not (above && below) then wrong (what ^ " is outside the range asked for")
  in
  (* A modulus and an argument against the number they describe. The range
     of these three forms is the one of the header, -pi < theta <= pi. *)
  let modulus_and_argument modulus arg range (result : Complex.t) =
    let expected = into_range range (atan2 result.im result.re) in
    if not (close modulus.number (Complex.norm result)) then wrong (Printf.sprintf "the modulus is %g" (Complex.norm result));
    if not (close arg.number expected) then wrong (Printf.sprintf "the argument is %g" expected);
    if not (near (of_polar modulus.number arg.number) result) then wrong "the modulus and the argument do not give the number";
    if not (close range.low (-.pi) && close range.high pi && (not range.low_in) && range.high_in) then
      wrong "the range is not -pi < theta <= pi";
    argument "the argument" arg range
  in
  match k with
  | "product" ->
      literal r "Let [`z = ";
      let modulus_z, angle_z = polar r in
      literal r "`] and [`w = ";
      let modulus_w, angle_w = polar r in
      literal r {|`]. Find the modulus and the argument [`\theta`] of [`|};
      let times =
        if optional r "zw" then true
        else begin
          literal r {|\dfrac{z}{w}|};
          false
        end
      in
      literal r "`], with ";
      let range = range r in
      literal r ". Modulus: ";
      let modulus = blank r in
      literal r " Argument: ";
      let arg = blank r in
      finish r;
      let z = of_polar modulus_z angle_z and w = of_polar modulus_w angle_w in
      modulus_and_argument modulus arg range (if times then Complex.mul z w else Complex.div z w);
      if close angle_z angle_w then wrong "z and w have the same angle";
      note (k ^ ": operation") (if times then "product" else "quotient");
      note_int (k ^ ": modulus of z") (int_of_float modulus_z);
      note_int (k ^ ": modulus of w") (int_of_float modulus_w);
      note_int (k ^ ": angle") (twelfths angle_z);
      note_int (k ^ ": angle") (twelfths angle_w)
  | "to_rectangular" ->
      literal r "Write [`z = ";
      let modulus, angle = polar r in
      literal r "`] in the form [`a + bi`], with exact values. [`a = `] ";
      let a = blank r in
      literal r " [`b = `] ";
      let b = blank r in
      finish r;
      let z = of_polar modulus angle in
      if not (close a.number z.re) then wrong (Printf.sprintf "the real part is %g" z.re);
      if not (close b.number z.im) then wrong (Printf.sprintf "the imaginary part is %g" z.im);
      if Float.abs z.re < 1e-9 || Float.abs z.im < 1e-9 then wrong "the angle lies along an axis";
      if not a.simplest then wrong "the real part is not in its simplest form";
      if not b.simplest then wrong "the imaginary part is not in its simplest form";
      note_int (k ^ ": modulus") (int_of_float modulus);
      note_int (k ^ ": angle") (twelfths angle)
  | "polar_form" ->
      literal r {|Find the modulus and the argument [`\theta`], with |};
      let range = range r in
      literal r ", of [`z = ";
      let z = rectangular r in
      literal r "`]. Modulus: ";
      let modulus = blank r in
      literal r " Argument: ";
      let arg = blank r in
      finish r;
      if not (close modulus.number (sqrt ((z.re *. z.re) +. (z.im *. z.im)))) then wrong "the modulus is not sqrt(a^2 + b^2)";
      if not (close arg.number (atan2 z.im z.re)) then wrong (Printf.sprintf "the argument is %g" (atan2 z.im z.re));
      modulus_and_argument modulus arg range z;
      if not modulus.simplest then wrong "the modulus is not in its simplest form";
      note_direction k wrong z
  | "power" ->
      literal r "Let [`z = ";
      let modulus_z, angle_z = polar r in
      literal r {|`]. Find the modulus and the argument [`\theta`], with |};
      let range = range r in
      literal r ", of [`z^{";
      let n = whole r in
      literal r "}`]. Modulus: ";
      let modulus = blank r in
      literal r " Argument: ";
      let arg = blank r in
      finish r;
      modulus_and_argument modulus arg range (power (of_polar modulus_z angle_z) n);
      if close angle_z 0. then wrong "the angle is 0";
      note_int (k ^ ": modulus") (int_of_float modulus_z);
      note_int (k ^ ": exponent") n;
      note_int (k ^ ": angle") (twelfths angle_z)
  | "de_moivre" ->
      literal r {|Use De Moivre's theorem to write [`\left(|};
      let z = rectangular r in
      literal r {|\right)^{|};
      let n = whole r in
      literal r "}`] in the form [`a + bi`]. [`a = `] ";
      let a = blank r in
      literal r " [`b = `] ";
      let b = blank r in
      finish r;
      let result = power z n in
      if not (close a.number result.re) then wrong (Printf.sprintf "the real part is %g" result.re);
      if not (close b.number result.im) then wrong (Printf.sprintf "the imaginary part is %g" result.im);
      if not (Float.is_integer a.number && Float.is_integer b.number) then wrong "a part is not a whole number";
      if a.number <> 0. && b.number <> 0. then wrong "neither part is 0";
      note_direction k wrong z;
      note_int (k ^ if close (Float.abs z.re) (Float.abs z.im) then ": exponent of k + ki" else ": exponent with sqrt(3)") n
  | "roots" ->
      literal r "The equation [`z^{";
      let n = whole r in
      literal r "} = ";
      let w = on_axis r in
      literal r "`] has [`";
      let count = whole r in
      literal r "`] solutions, all of the same modulus. That modulus: ";
      let modulus = blank r in
      literal r {| Give the two smallest of their arguments [`\theta`] with |};
      let range = range r in
      literal r ". The smallest: ";
      let first = blank r in
      literal r " The next: ";
      let second = blank r in
      finish r;
      if n < 1 then failwith "the degree is not positive";
      if count <> n then wrong (Printf.sprintf "there are %d solutions" n);
      if not (modulus.number > 0.) then wrong "the modulus is not positive";
      List.iter
        (fun (what, arg) ->
          argument what arg range;
          if not (near (power (of_polar modulus.number arg.number) n) w) then wrong (what ^ " does not give a solution"))
        [ ("the smallest argument", first); ("the next argument", second) ];
      if not (first.number < second.number -. 1e-9) then wrong "the two arguments are not different and in order";
      (* every root, its argument brought into the range, smallest first *)
      (match List.sort compare (List.init n (fun j -> into_range range ((Complex.arg w +. (turn *. float j)) /. float n))) with
      | smallest :: next :: _ ->
          if not (close first.number smallest && close second.number next) then
            wrong (Printf.sprintf "the two smallest arguments are %g and %g" smallest next)
      | _ -> wrong "the equation has fewer than two solutions");
      if n = 2 && w.im = 0. && w.re > 0. then wrong "the square roots of a positive number are asked for";
      note_int (k ^ ": degree") n;
      note_int (k ^ ": modulus") (int_of_float (Float.round modulus.number));
      note (k ^ ": right-hand side")
        (if w.im = 0. then if w.re > 0. then "positive" else "negative" else if w.im > 0. then "a multiple of i" else "a multiple of -i")
  | _ -> wrong "an unknown kind"

(* The check of the simplest form, tried on trees built by hand: the
   engine's own formula functions already drop a factor 1, so a grammar
   cannot be made to show that the check refuses 1 sqrt(2). *)
let check_simplest () =
  let whole n = F.Constant (Rhema_number.of_int n) in
  let root n = F.Sqrt (whole n) and half = F.Constant (Rhema_number.divide (Rhema_number.of_int 1) (Rhema_number.of_int 2)) in
  List.iter
    (fun (name, tree, wanted) ->
      if simplest tree <> wanted then fail (Printf.sprintf "simplest form: %s is %s" name (if wanted then "refused" else "accepted")))
    [ ("3", whole 3, true);
      ("-3", whole (-3), true);
      ("-(3)", F.Negate (whole 3), true);
      ("sqrt(2)", root 2, true);
      ("-sqrt(3)", F.Negate (root 3), true);
      ("2 sqrt(3)", F.Multiply (whole 2, root 3), true);
      ("-(2 sqrt(2))", F.Negate (F.Multiply (whole 2, root 2)), true);
      ("-2 sqrt(2)", F.Multiply (whole (-2), root 2), true);
      ("1 sqrt(2)", F.Multiply (whole 1, root 2), false);
      ("-1 sqrt(3)", F.Multiply (whole (-1), root 3), false);
      ("0 sqrt(3)", F.Multiply (whole 0, root 3), false);
      ("-(-2 sqrt(2))", F.Negate (F.Multiply (whole (-2), root 2)), false);
      ("-(-3)", F.Negate (whole (-3)), false);
      ("-(-(sqrt(2)))", F.Negate (F.Negate (root 2)), false);
      ("4 (sqrt(2)/2)", F.Multiply (whole 4, F.Divide (root 2, whole 2)), false);
      ("(4 sqrt(2))/2", F.Divide (F.Multiply (whole 4, root 2), whole 2), false);
      ("2 * 1/2", F.Multiply (whole 2, half), false);
      ("1/2", half, false);
      ("sqrt(2) 2", F.Multiply (root 2, whole 2), false);
      ("2 (2 sqrt(2))", F.Multiply (whole 2, F.Multiply (whole 2, root 2)), false);
      ("sqrt(5)", root 5, false);
      ("sqrt(4)", root 4, false);
      ("2 sqrt(2) sqrt(3)", F.Multiply (F.Multiply (whole 2, root 2), root 3), false);
      ("pi", F.Pi, false);
      ("2 cos(pi)", F.Multiply (whole 2, F.Cos F.Pi), false) ]

let () =
  check_simplest ();
  let base = load_file "complex_polar.rhm" in
  (* each kind with its price and the number of blanks its text announces *)
  let forms =
    [ ("product", (1, 2)); ("to_rectangular", (1, 2)); ("polar_form", (2, 2)); ("power", (2, 2)); ("de_moivre", (3, 2));
      ("roots", (3, 3)) ]
  in
  let seen = Hashtbl.create 8 in
  (* no question outside the three prices *)
  List.iter
    (fun cost ->
      match Rhema_check.with_initial base "cost" cost with
      | Error _ -> ()
      | Ok spec ->
          for seed = 0 to 4 do
            Random.init seed;
            match Rhema_engine.generate spec with
            | exception Rhema_engine.Generation_error _ -> ()
            | q -> fail (Printf.sprintf "budget %d gave a question: %s" cost q.Rhema_engine.prompt)
          done)
    [ 0; 4; 5; 6 ];
  (* left alone, the budget is the middle price *)
  for seed = 0 to 19 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if Option.map fst (List.assoc_opt (kind q) forms) <> Some 2 then
          fail (Printf.sprintf "the grammar's own budget gave a question that is not of price 2: %s" (kind q))
  done;
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 599 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          (match List.assoc_opt k forms with
          | Some (price, blanks) ->
              if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost);
              if List.length q.Rhema_engine.answers <> blanks then
                fail (Printf.sprintf "%s: %d blanks for %S" k (List.length q.Rhema_engine.answers) p)
          | None -> fail (Printf.sprintf "a kind the header does not list: %s" k));
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) forms;
  (* the numbers of each form: all of these and no others *)
  let ints = List.map string_of_int in
  let either_sign values = List.map (fun v -> -v) values @ values in
  let shapes = [ "k + ki"; "k sqrt(3) + ki"; "k + k sqrt(3) i" ] in
  let expected =
    [ ("product: operation", [ "product"; "quotient" ]);
      ("product: modulus of z", ints [ 2; 3; 4; 5; 6 ]);
      ("product: modulus of w", ints [ 2; 3; 4; 5 ]);
      ("product: angle", ints [ 2; 3; 4; 6; 8; 9; 10 ]);
      ("to_rectangular: modulus", ints [ 2; 4; 6; 8 ]);
      ("to_rectangular: angle", ints (either_sign [ 2; 3; 4; 8; 9; 10 ]));
      ("polar_form: shape", shapes);
      ("polar_form: k", ints [ 1; 2; 3; 4 ]);
      ("polar_form: quadrant", ints [ 1; 2; 3; 4 ]);
      ("power: modulus", ints [ 2; 3 ]);
      ("power: exponent", ints [ 2; 3; 4 ]);
      ("power: angle", ints (either_sign [ 2; 3; 4; 6; 8; 9; 10 ]));
      ("de_moivre: shape", shapes);
      ("de_moivre: k", ints [ 1 ]);
      ("de_moivre: quadrant", ints [ 1; 2; 3; 4 ]);
      ("de_moivre: exponent of k + ki", ints [ 4; 6; 8 ]);
      ("de_moivre: exponent with sqrt(3)", ints [ 3; 6; 9 ]);
      ("roots: degree", ints [ 2; 3; 4 ]);
      ("roots: modulus", ints [ 1; 2; 3 ]);
      ("roots: right-hand side", [ "positive"; "negative"; "a multiple of i"; "a multiple of -i" ]) ]
  in
  List.iter
    (fun (what, values) ->
      let found = Option.value (Hashtbl.find_opt noted what) ~default:[] in
      List.iter (fun v -> if not (List.mem v found) then fail (Printf.sprintf "never generated: %s %s" what v)) values;
      List.iter (fun v -> if not (List.mem v values) then fail (Printf.sprintf "not expected: %s %s" what v)) found)
    expected;
  Hashtbl.iter (fun what _ -> if not (List.mem_assoc what expected) then fail ("nothing is expected of: " ^ what)) noted;
  if !failures = 0 then print_endline "Rhema complex polar tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d complex polar test(s) failed." !failures);
    exit 1
  end
