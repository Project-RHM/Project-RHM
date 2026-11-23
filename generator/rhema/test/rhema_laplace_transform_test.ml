(* Independent checks for laplace_transform.rhm. Nothing here uses the
   grammar's closed formulas: no transform is taken from a table. The
   function of the question is read back from the printed text, whose whole
   wording must be that of these questions (a text that cannot be read is a
   failure), and every answer is tried against the definition,

     F(s) = the integral from 0 to infinity of f(t) e^(-st) dt,

   worked out in floating point. The half line is cut where e^(-(s - a) t),
   a the largest rate of an exponential in f, has fallen to e^(-45); what is
   left is cut into 64 panels, each integrated with the 8-point
   Gauss-Legendre rule, whose nodes are found here by Newton's method. The
   result is within about 1e-12 of the truth and must be within 1e-8
   (relative) of the engine's formula.

   A function of t is held as a sum of terms k t^n e^(at), each alone or
   multiplied by sin(bt) or cos(bt).

   Transforms (power, exponential, sine, cosine, combination, shifted_power,
   shifted_sine, shifted_cosine): f(t) is read from the text as such a sum.
   Its integral is taken at four values of s to the right of every rate of
   f, taken with either sign, and the engine's answer, a formula in s
   alone, must come to the same four numbers.

   Inverses (inverse_power, inverse_exponential, inverse_partial_fractions,
   inverse_trigonometric): the numerator and the denominator of F(s) are
   read from the text. The engine's answer, a formula in t alone, is itself
   put through the integral at four values of s to the right of every pole
   of F, and must give back the printed fraction there. The function is
   also found again here, and must agree with the engine's at four values
   of t:

     c / s^n          c t^(n-1) divided by the integral of t^(n-1) e^(-t)
                      from 0 to infinity, found numerically; the quotient
                      must be a whole number, as the grammar promises
     k / (s - a)      k e^(at)
     (p s + q) / (s^2 + m s + n), with m^2 > 4 n
                      the two roots are searched among the whole numbers;
                      they must be two, different and not 0; the constant
                      over each root is found by covering it up, and must
                      be a whole number and not 0
     (p s + q) / (s^2 + n), with n > 0
                      n must be a square b^2, and the function is
                      p cos(bt) + (q / b) sin(bt), with q / b whole

   and any other fraction is refused. What is found here is put through the
   integral as well, and must give the printed fraction too.

   Mistakes. Each is redone on the function, as its description says:

     factorial_forgotten   k / s^(n+1) is taken for the transform of k t^n:
                           going forward each term loses its n!, going back
                           each term gains it
     shift_sign            every rate changes sign: e^(-at) for e^(at),
                           which puts s + a where s - a belongs
     sine_cosine_swapped   every sine becomes a cosine and every cosine a
                           sine

   Going forward, the changed function is put through the integral; going
   back, it is the student's answer. A mistake can be made in a question
   exactly when it changes the function as it is written, so k t e^(at) and
   c / s^2, whose factorial is 1, do not have factorial_forgotten. The
   engine must list exactly these mistakes, in the order they are declared,
   each with a formula in the same variable that comes to these values, and
   each a function other than the right answer: this is the promise that
   partial fractions with m e^(at) + m e^(-at) are not asked, and that the
   two constants of p cos(bt) + q sin(bt) are different.

   The working of this file is itself tried first, on transforms and
   fractions written by hand.

   Besides the answers: every kind of the header has the function its
   header gives it; each kind appears at its price alone and spends its
   budget; a budget outside 1..3 gives no question; the budget the grammar
   sets itself is the middle price; there is one answer, a formula, in a
   blank that knows both s and t; a coefficient 1, a power 1 and a term 0
   are never written; and each printed number of each form takes exactly
   the values expected, none missing and none more. *)

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

(* ---- Functions of t -------------------------------------------------------- *)

type wave = Flat | Sine of int | Cosine of int

(* scale t^degree e^(rate t), alone or times sin(b t) or cos(b t). A
   function is a list of terms, added. *)
type term = { scale : float; degree : int; rate : int; wave : wave }

let power_of x n =
  let rec go product n = if n = 0 then product else go (product *. x) (n - 1) in
  go 1. n

(* f(t) e^(-st), with the two exponentials taken as one so that neither
   grows out of range. *)
let damped terms s t =
  List.fold_left
    (fun total { scale; degree; rate; wave } ->
      let turning = match wave with Flat -> 1. | Sine b -> sin (float b *. t) | Cosine b -> cos (float b *. t) in
      total +. (scale *. power_of t degree *. exp ((float rate -. s) *. t) *. turning))
    0. terms

let value terms t = damped terms 0. t

(* The largest rate of an exponential in the function: its transform is
   defined to the right of it. *)
let growth terms = List.fold_left (fun most term -> max most term.rate) min_int terms

(* ---- The integral ---------------------------------------------------------- *)

(* The nodes and weights of the Gauss-Legendre rule with n points on
   [-1, 1]: the roots of the Legendre polynomial P_n, by Newton's method. *)
let gauss_legendre n =
  Array.init n (fun i ->
      let x = ref (cos (Float.pi *. (float i +. 0.75) /. (float n +. 0.5))) in
      let slope = ref 0. in
      for _ = 1 to 50 do
        (* P_n and P_(n-1) at x, by the three-term recurrence *)
        let before = ref 1. and current = ref !x in
        for j = 2 to n do
          let next = (((2. *. float j) -. 1.) *. !x *. !current -. ((float j -. 1.) *. !before)) /. float j in
          before := !current;
          current := next
        done;
        slope := float n *. ((!x *. !current) -. !before) /. ((!x *. !x) -. 1.);
        x := !x -. (!current /. !slope)
      done;
      (!x, 2. /. ((1. -. (!x *. !x)) *. !slope *. !slope)))

let nodes = gauss_legendre 8
let panels = 64

let over_interval g a b =
  let h = (b -. a) /. float panels in
  let total = ref 0. in
  for i = 0 to panels - 1 do
    let middle = a +. (h *. (float i +. 0.5)) in
    Array.iter (fun (x, w) -> total := !total +. (w *. g (middle +. (0.5 *. h *. x)))) nodes
  done;
  0.5 *. h *. !total

(* From 0 to infinity, for g that falls like e^(-decay t) times a power of
   t: beyond 45 / decay there is nothing left of it. *)
let to_infinity g decay =
  if not (decay >= 1.) then failwith "the integral is asked for too near the point where it stops converging";
  over_interval g 0. (45. /. decay)

(* The transform at s of a function held as terms, and of a formula in t
   that grows no faster than e^(growth t). *)
let transform terms s = to_infinity (damped terms s) (s -. float (growth terms))

let transform_of_formula f ~growth s =
  to_infinity (fun t -> F.evaluate ~variable:"t" ~at:t f *. exp (-.s *. t)) (s -. float growth)

(* ---- The mistakes, made on the function ----------------------------------- *)

let rec factorial n = if n <= 1 then 1 else n * factorial (n - 1)

(* k / s^(n+1) for the transform of k t^n is the transform of k t^n / n!;
   and read backwards, c / s^(n+1) is taken to come from c t^n, which is n!
   times what it comes from. *)
let without_factorial ~forward terms =
  List.map
    (fun term ->
      let lost = float (factorial term.degree) in
      { term with scale = (if forward then term.scale /. lost else term.scale *. lost) })
    terms

let shifted_wrongly terms = List.map (fun term -> { term with rate = -term.rate }) terms

let swapped terms =
  List.map
    (fun term -> { term with wave = (match term.wave with Flat -> Flat | Sine b -> Cosine b | Cosine b -> Sine b) })
    terms

(* The mistakes that can be made on a function, in the order they are
   declared, each with the function it leads to: one that leaves the
   function as it is written cannot be made on it. *)
let slips ~forward terms =
  List.filter
    (fun (_, changed) -> changed <> terms)
    [ ("factorial_forgotten", without_factorial ~forward terms);
      ("shift_sign", shifted_wrongly terms);
      ("sine_cosine_swapped", swapped terms) ]

(* ---- Reading the text ------------------------------------------------------ *)

(* The whole of `text` must be the pattern. Its groups are given back, all
   taken at once, before any other pattern is tried: a group that took no
   part in the match is None. *)
let fields re count text =
  if Str.string_match (Str.regexp re) text 0 && Str.match_end () = String.length text then
    Some (Array.init count (fun i -> match Str.matched_group (i + 1) text with s -> Some s | exception Not_found -> None))
  else None

let field groups n = match groups.(n - 1) with Some s -> s | None -> failwith "a part of the text is missing"

(* A whole number written without a sign and without a 0 in front. *)
let number text =
  match fields "0\\|[1-9][0-9]*" 0 text with
  | Some _ -> int_of_string text
  | None -> failwith ("cannot read the number \"" ^ text ^ "\"")

(* A number that stands alone: 0 is never written. *)
let positive text =
  let n = number text in
  if n = 0 then failwith "a 0 is written out";
  n

(* A number written in front of something: nothing stands for 1, and 0 and
   1 are never written. *)
let coefficient text =
  if text = "" then 1
  else
    let n = number text in
    if n < 2 then failwith ("a coefficient " ^ text ^ " is written out");
    n

(* A power written with ^{ }: no ^{ } stands for 1, and 0 and 1 are never
   written. *)
let written_power = function
  | None -> 1
  | Some text ->
      let n = number text in
      if n < 2 then failwith ("a power " ^ text ^ " is written out");
      n

let signed sign n = if sign = "-" then -n else n

(* The parts of a sum written with " + " and " - " between them, each with
   its sign. Nothing stands in front of the first. *)
let summands text =
  match Str.full_split (Str.regexp " [-+] ") text with
  | Str.Text first :: rest ->
      let rec following = function
        | Str.Delim sign :: Str.Text part :: more -> ((if sign = " - " then -1 else 1), part) :: following more
        | [] -> []
        | _ -> failwith "a sign with nothing after it"
      in
      (1, first) :: following rest
  | _ -> failwith "a sum that does not start with a term"

(* One term of f(t), in the shapes these questions print: a number alone;
   k t^{n}, alone or followed by a space and e^{a t}; k e^{a t}, alone or
   followed by a space and \sin(b t) or \cos(b t); k \sin(b t) or
   k \cos(b t). *)
let term_shapes =
  let wave which b = if which = "sin" then Sine (coefficient b) else Cosine (coefficient b) in
  [ ("\\([0-9]+\\)", 1, fun g -> { scale = float (positive (field g 1)); degree = 0; rate = 0; wave = Flat });
    ( "\\([0-9]*\\)t\\(\\^{\\([0-9]+\\)}\\)?\\( e\\^{\\(-?\\)\\([0-9]*\\)t}\\)?",
      6,
      fun g ->
        let rate = match g.(3) with None -> 0 | Some _ -> signed (field g 5) (coefficient (field g 6)) in
        { scale = float (coefficient (field g 1)); degree = written_power g.(2); rate; wave = Flat } );
    ( "\\([0-9]*\\)e\\^{\\(-?\\)\\([0-9]*\\)t}\\( \\\\\\(sin\\|cos\\)(\\([0-9]*\\)t)\\)?",
      6,
      fun g ->
        let wave = match g.(3) with None -> Flat | Some _ -> wave (field g 5) (field g 6) in
        { scale = float (coefficient (field g 1)); degree = 0; rate = signed (field g 2) (coefficient (field g 3)); wave } );
    ( "\\([0-9]*\\)\\\\\\(sin\\|cos\\)(\\([0-9]*\\)t)",
      3,
      fun g -> { scale = float (coefficient (field g 1)); degree = 0; rate = 0; wave = wave (field g 2) (field g 3) } ) ]

let term text =
  let rec first = function
    | (re, count, build) :: rest -> ( match fields re count text with Some g -> build g | None -> first rest)
    | [] -> failwith ("cannot read the term \"" ^ text ^ "\"")
  in
  first term_shapes

let forward_re = "Find the Laplace transform \\[`F(s)`\\] of \\[`f(t) = \\([^`]*\\)`\\]\\."

let backward_re =
  "Find the function \\[`f(t)`\\] whose Laplace transform is \\[`F(s) = \\\\frac{\\([^{}`]*\\)}{\\([^`]*\\)}`\\]\\."

(* What stands under the line of F(s): s^n, s + d, or s^2 + m s + n. *)
type below = Power_of_s of int | Linear of int | Quadratic of int * int

(* What stands above it: p s + q, as (p, q). Either part may be missing,
   not both. *)
let numerator text =
  match fields "\\(-?\\)\\([0-9]*\\)s\\( \\([-+]\\) \\([0-9]+\\)\\)?" 5 text with
  | Some g ->
      let q = match g.(2) with None -> 0 | Some _ -> signed (field g 4) (positive (field g 5)) in
      (signed (field g 1) (coefficient (field g 2)), q)
  | None -> (
      match fields "\\(-?\\)\\([0-9]+\\)" 2 text with
      | Some g -> (0, signed (field g 1) (positive (field g 2)))
      | None -> failwith ("cannot read the numerator \"" ^ text ^ "\""))

let denominator text =
  match fields "s\\(\\^{\\([0-9]+\\)}\\)?" 2 text with
  | Some g -> Power_of_s (written_power g.(1))
  | None -> (
      match fields "s \\([-+]\\) \\([0-9]+\\)" 2 text with
      | Some g -> Linear (signed (field g 1) (positive (field g 2)))
      | None -> (
          match fields "s\\^{2}\\( \\([-+]\\) \\([0-9]*\\)s\\)?\\( \\([-+]\\) \\([0-9]+\\)\\)?" 6 text with
          | Some g ->
              let m = match g.(0) with None -> 0 | Some _ -> signed (field g 2) (coefficient (field g 3)) in
              let n = match g.(3) with None -> 0 | Some _ -> signed (field g 5) (positive (field g 6)) in
              Quadratic (m, n)
          | None -> failwith ("cannot read the denominator \"" ^ text ^ "\"")))

(* A question read: a function of t to transform, or a fraction in s to
   find the function of. *)
type asked = Transform of term list | Inverse of (int * int) * below

let read text =
  match fields forward_re 1 text with
  | Some g ->
      let with_sign (sign, part) =
        let read = term part in
        { read with scale = float sign *. read.scale }
      in
      Transform (List.map with_sign (summands (field g 1)))
  | None -> (
      match fields backward_re 2 text with
      | Some g -> Inverse (numerator (field g 1), denominator (field g 2))
      | None -> failwith "the text is not worded as a question on Laplace transforms is")

(* The printed fraction at s. *)
let fraction_at (p, q) below s =
  ((float p *. s) +. float q)
  /. (match below with
     | Power_of_s n -> power_of s n
     | Linear d -> s +. float d
     | Quadratic (m, n) -> (s *. s) +. (float m *. s) +. float n)

(* ---- The inverse, found here ---------------------------------------------- *)

let whole_quotient a b what = if b <> 0 && a mod b = 0 then a / b else failwith (what ^ " is not a whole number")

let square_root n =
  let rec up r = if r * r >= n then r else up (r + 1) in
  let r = up 0 in
  if n >= 0 && r * r = n then Some r else None

(* The integral of t^n e^(-t) from 0 to infinity: the transform of t^n at 1. *)
let moment n = transform [ { scale = 1.; degree = n; rate = 0; wave = Flat } ] 1.

let inverse (p, q) below =
  match below with
  | Power_of_s n ->
      if p <> 0 then failwith "s stands above a power of s";
      (* c / s^n is the transform of c t^(n-1) / moment (n - 1), since the
         transform of t^(n-1) at s is moment (n - 1) / s^n (put u = s t) *)
      let exactly = float q /. moment (n - 1) in
      let scale = Float.round exactly in
      if Float.abs (exactly -. scale) > 1e-9 then failwith "the coefficient of the answer is not a whole number";
      [ { scale; degree = n - 1; rate = 0; wave = Flat } ]
  | Linear d ->
      if p <> 0 then failwith "the degree above the line is not below the degree under it";
      [ { scale = float q; degree = 0; rate = -d; wave = Flat } ]
  | Quadratic (m, n) ->
      let discriminant = (m * m) - (4 * n) in
      if discriminant > 0 then begin
        (* a whole root divides n, or is 0 when n is 0 *)
        let bound = max 1 (abs n) in
        let rec roots r = if r > bound then [] else if (r * r) + (m * r) + n = 0 then r :: roots (r + 1) else roots (r + 1) in
        match roots (-bound) with
        | [ low; high ] ->
            if low = 0 || high = 0 then failwith "0 is a root of the denominator";
            (* covering up: the constant over s - r is the numerator at r
               over r minus the other root *)
            let over root other = whole_quotient ((p * root) + q) (root - other) "a constant of the partial fractions" in
            let first = over low high and second = over high low in
            if first = 0 || second = 0 then failwith "a root of the denominator is a root of the numerator too";
            [ { scale = float first; degree = 0; rate = low; wave = Flat };
              { scale = float second; degree = 0; rate = high; wave = Flat } ]
        | _ -> failwith "the denominator does not have two whole roots"
      end
      else if discriminant < 0 && m = 0 then begin
        match square_root n with
        | None -> failwith "the denominator is not s^2 plus a square"
        | Some b ->
            let of_sine = whole_quotient q b "the constant of the sine" in
            List.filter
              (fun term -> term.scale <> 0.)
              [ { scale = float p; degree = 0; rate = 0; wave = Cosine b };
                { scale = float of_sine; degree = 0; rate = 0; wave = Sine b } ]
      end
      else failwith "the denominator has a double root, or roots that are not real and not on the axis"

(* ---- What was generated ---------------------------------------------------- *)

(* The numbers of each form, to compare at the end with the values expected:
   none outside them, and none of them missing. *)
let noted : (string * string, string list) Hashtbl.t = Hashtbl.create 64

let note k name value =
  let before = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
  if not (List.mem value before) then Hashtbl.replace noted (k, name) (value :: before)

let note_number k name n = note k name (string_of_int n)
let pair a b = Printf.sprintf "(%d, %d)" a b
let whole x = int_of_float x

(* Each kind has the function its header gives it. Its numbers are noted. *)
let of_its_kind k asked =
  let not_so () = failwith "the function is not the one of its kind" in
  let flat term = term.wave = Flat in
  match (k, asked) with
  | "power", Transform [ ({ rate = 0; _ } as only) ] when flat only ->
      if only.degree < 2 then failwith "the power is below 2: its factorial is 1";
      note_number k "coefficient" (whole only.scale);
      note_number k "power" only.degree
  | "exponential", Transform [ ({ degree = 0; _ } as only) ] when flat only && only.rate <> 0 ->
      note_number k "coefficient" (whole only.scale);
      note_number k "rate" only.rate
  | "sine", Transform [ { scale; degree = 0; rate = 0; wave = Sine b } ]
  | "cosine", Transform [ { scale; degree = 0; rate = 0; wave = Cosine b } ] ->
      note_number k "coefficient" (whole scale);
      note_number k "frequency" b
  | ( "combination",
      Transform [ ({ degree = 0; rate = 0; _ } as constant); ({ degree = 1; rate = 0; _ } as line); ({ degree = 0; _ } as last) ] )
    when flat constant && flat line && flat last && last.rate <> 0 ->
      if last.scale < 0. then failwith "the exponential is taken away";
      note_number k "constant" (whole constant.scale);
      note_number k "coefficient of t" (whole line.scale);
      note_number k "coefficient" (whole last.scale);
      note_number k "rate" last.rate
  | "shifted_power", Transform [ only ] when flat only && only.rate <> 0 && only.degree >= 1 ->
      note_number k "coefficient" (whole only.scale);
      note_number k "power" only.degree;
      note_number k "rate" only.rate
  | "shifted_sine", Transform [ { scale = 1.; degree = 0; rate; wave = Sine b } ]
  | "shifted_cosine", Transform [ { scale = 1.; degree = 0; rate; wave = Cosine b } ] ->
      if rate = 0 then not_so ();
      note_number k "rate" rate;
      note_number k "frequency" b
  | "inverse_power", Inverse (((0, above) as top), (Power_of_s n as below)) -> (
      if above < 0 then failwith "the numerator is negative";
      match inverse top below with
      | [ only ] ->
          note_number k "power of s" n;
          note_number k "coefficient of the answer" (whole only.scale)
      | _ -> not_so ())
  | "inverse_exponential", Inverse ((0, above), Linear d) ->
      if above < 0 then failwith "the numerator is negative";
      note_number k "coefficient" above;
      note_number k "rate" (-d)
  | "inverse_partial_fractions", Inverse (top, (Quadratic _ as below)) -> (
      match inverse top below with
      | [ ({ wave = Flat; _ } as first); ({ wave = Flat; _ } as second) ] ->
          note k "rates" (pair first.rate second.rate);
          note k "constants" (pair (whole first.scale) (whole second.scale))
      | _ -> failwith "the denominator does not have two real roots")
  | "inverse_trigonometric", Inverse (top, (Quadratic _ as below)) -> (
      match inverse top below with
      | [ { scale = of_cosine; wave = Cosine b; _ }; { scale = of_sine; wave = Sine _; _ } ] ->
          note k "constants" (pair (whole of_cosine) (whole of_sine));
          note_number k "frequency" b
      | _ -> failwith "the function is not a cosine plus a sine")
  | _ -> not_so ()

let rec range a b = if a > b then [] else a :: range (a + 1) b
let numbers a b = List.map string_of_int (range a b)
let not_zero a b = List.filter (fun n -> n <> 0) (range a b)
let numbers_not_zero a b = List.map string_of_int (not_zero a b)

(* The values each form's numbers take, all of which must appear. *)
let allowed =
  let rate = ("rate", numbers_not_zero (-4) 4) and coefficient = ("coefficient", numbers 1 6) in
  let frequency = ("frequency", numbers 1 5) in
  let constants = List.concat_map (fun m -> List.map (fun n -> (m, n)) (not_zero (-5) 5)) (not_zero (-5) 5) in
  let rates =
    List.concat_map
      (fun a -> List.filter_map (fun b -> if a < b then Some (a, b) else None) (not_zero (-4) 4))
      (not_zero (-4) 4)
  in
  let pairs = List.map (fun (a, b) -> pair a b) in
  let sometimes = ("factorial_forgotten", [ "listed"; "not listed" ]) in
  [ ("power", [ coefficient; ("power", numbers 2 4); ("factorial_forgotten", [ "listed" ]) ]);
    ("exponential", [ coefficient; rate ]);
    ("sine", [ coefficient; frequency ]);
    ("cosine", [ coefficient; frequency ]);
    ("combination", [ ("constant", numbers 1 9); ("coefficient of t", numbers_not_zero (-6) 6); coefficient; rate ]);
    ("inverse_power", [ ("power of s", numbers 2 4); ("coefficient of the answer", numbers 1 6); sometimes ]);
    ("inverse_exponential", [ coefficient; rate ]);
    ("shifted_power", [ coefficient; ("power", numbers 1 2); rate; sometimes ]);
    ("shifted_sine", [ rate; frequency ]);
    ("shifted_cosine", [ rate; frequency ]);
    ("inverse_partial_fractions", [ ("rates", pairs rates); ("constants", pairs constants) ]);
    ("inverse_trigonometric", [ ("constants", pairs (List.filter (fun (p, q) -> p <> q) constants)); frequency ]) ]

let prices =
  [ ("power", 1); ("exponential", 1); ("sine", 2); ("cosine", 2); ("combination", 2); ("inverse_power", 2);
    ("inverse_exponential", 2); ("shifted_power", 3); ("shifted_sine", 3); ("shifted_cosine", 3);
    ("inverse_partial_fractions", 3); ("inverse_trigonometric", 3) ]

(* Which mistakes must have been listed on which kinds, and on no other. *)
let made_on =
  [ ("factorial_forgotten", [ "power"; "inverse_power"; "shifted_power" ]);
    ( "shift_sign",
      [ "exponential"; "combination"; "inverse_exponential"; "shifted_power"; "shifted_sine"; "shifted_cosine";
        "inverse_partial_fractions" ] );
    ("sine_cosine_swapped", [ "sine"; "cosine"; "shifted_sine"; "shifted_cosine"; "inverse_trigonometric" ]) ]

(* What the description of each mistake must speak of. *)
let spoken =
  [ ("factorial_forgotten", [ "1 / s^(n+1)"; "factorial" ]);
    ("shift_sign", [ "s + a where s - a belongs"; "e^(-at) where e^(at) belongs" ]);
    ("sine_cosine_swapped", [ "sine"; "cosine" ]) ]

let made : (string * string, unit) Hashtbl.t = Hashtbl.create 16
let seen : (string, int) Hashtbl.t = Hashtbl.create 16
let times k = Option.value (Hashtbl.find_opt seen k) ~default:0

let close found wanted =
  Float.abs (found -. wanted) <= (1e-8 *. Float.max (Float.abs found) (Float.abs wanted)) +. 1e-11

let all_close found wanted = List.for_all2 close found wanted

(* Two lists of values of two functions that are not the same function. *)
let apart found wanted =
  List.exists2 (fun a b -> Float.abs (a -. b) > 1e-5 *. Float.max (Float.abs a) (Float.abs b)) found wanted

let show values = String.concat ", " (List.map (Printf.sprintf "%.10g") values)

(* Where formulas in s are compared: this far to the right of every rate.
   And where formulas in t are. *)
let offsets = [ 1.3; 2.1; 3.4; 5.2 ]
let instants = [ 0.31; 0.77; 1.23; -0.58 ]

(* A formula that holds the one variable it is in, and no other. *)
let formula_in name what = function
  | Rhema_engine.Formula f ->
      let held = F.variables f in
      if held <> [ name ] then
        failwith (Printf.sprintf "%s is a formula in [%s], not in %s alone" what (String.concat ", " held) name);
      f
  | other -> failwith (Printf.sprintf "%s is not a formula: %s" what (Rhema_engine.describe_value other))

(* What a question comes to, worked out here: the variable of its answer,
   the points where formulas are compared, the right answer there, and each
   mistake that can be made with its answer there. *)
type worked = { variable : string; points : float list; right : float list; wrong : (string * float list) list }

let work asked =
  match asked with
  | Transform terms ->
      (* to the right of every rate, and of every rate with its sign changed *)
      let furthest = float (List.fold_left (fun most term -> max most (abs term.rate)) 0 terms) in
      let points = List.map (fun offset -> furthest +. offset) offsets in
      let at terms = List.map (transform terms) points in
      let wrong = List.map (fun (name, changed) -> (name, at changed)) (slips ~forward:true terms) in
      { variable = "s"; points; right = at terms; wrong }
  | Inverse (top, below) ->
      let terms = inverse top below in
      let at terms = List.map (value terms) instants in
      let wrong = List.map (fun (name, changed) -> (name, at changed)) (slips ~forward:false terms) in
      { variable = "t"; points = instants; right = at terms; wrong }

(* One question: Failure says what is wrong with it. *)
let examine k (q : Rhema_engine.question) =
  let only =
    match q.Rhema_engine.answers with
    | [ only ] -> only
    | answers -> failwith (Printf.sprintf "%d answers and not one" (List.length answers))
  in
  if only <> q.Rhema_engine.answer then failwith "the answer is not the one of the only blank";
  let asked = read q.Rhema_engine.prompt in
  of_its_kind k asked;
  let { variable; points; right; wrong } = work asked in
  let at f = List.map (fun x -> F.evaluate ~variable ~at:x f) points in
  let answer = formula_in variable "the answer" only in
  if not (all_close (at answer) right) then
    failwith
      (Printf.sprintf "worked out here, the answer is [%s] at %s = [%s], not [%s]" (show right) variable (show points)
         (show (at answer)));
  (match asked with
  | Transform _ -> ()
  | Inverse (top, below) ->
      (* the definition: the transform of the engine's answer is the printed
         fraction, and so is the transform of what was found here *)
      let terms = inverse top below in
      let growth = growth terms in
      let beyond = List.map (fun offset -> float growth +. offset) offsets in
      let printed = List.map (fraction_at top below) beyond in
      let transformed = List.map (transform_of_formula answer ~growth) beyond in
      if not (all_close transformed printed) then
        failwith
          (Printf.sprintf "the transform of the answer is [%s] at s = [%s], and the fraction is [%s]" (show transformed)
             (show beyond) (show printed));
      if not (all_close (List.map (transform terms) beyond) printed) then
        failwith "the transform of the function found here is not the printed fraction");
  (* the mistakes *)
  List.iter
    (fun (name, values) -> if not (apart values right) then failwith (name ^ " can be made and gives the right answer"))
    wrong;
  let listed = q.Rhema_engine.mistakes in
  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
  if names <> List.map fst wrong then
    failwith
      (Printf.sprintf "the mistakes listed are [%s], not [%s]" (String.concat ", " names)
         (String.concat ", " (List.map fst wrong)));
  if List.mem_assoc "factorial_forgotten" (List.assoc k allowed) then
    note k "factorial_forgotten" (if List.mem "factorial_forgotten" names then "listed" else "not listed");
  List.iter
    (fun (m : Rhema_engine.mistaken) ->
      Hashtbl.replace made (m.mistake, k) ();
      (* each mistake is described as itself *)
      List.iter
        (fun part ->
          match Str.search_forward (Str.regexp_string part) m.description 0 with
          | _ -> ()
          | exception Not_found -> failwith (Printf.sprintf "%s is described as %S" m.mistake m.description))
        (List.assoc m.mistake spoken);
      match m.mistaken_answers with
      | Some [ given ] ->
          let mistaken = formula_in variable ("the answer of " ^ m.mistake) given in
          let values = List.assoc m.mistake wrong in
          if not (all_close (at mistaken) values) then
            failwith
              (Printf.sprintf "%s gives [%s] at %s = [%s], and redone here [%s]" m.mistake (show (at mistaken)) variable
                 (show points) (show values));
          if not (apart (at mistaken) (at answer)) then failwith (m.mistake ^ " gives the right answer")
      | _ -> failwith (m.mistake ^ " does not give one answer"))
    listed

(* A question that was looked at already, with the same answer and the same
   mistakes, is not worked out again. *)
let examined : (string, unit) Hashtbl.t = Hashtbl.create 4096

let check cost seed (q : Rhema_engine.question) =
  let k = kind q and p = q.Rhema_engine.prompt in
  Hashtbl.replace seen k (times k + 1);
  (match List.assoc_opt k prices with
  | Some price -> if price <> cost then fail (Printf.sprintf "%s at cost %d (seed %d)" k cost seed)
  | None -> fail (Printf.sprintf "a kind the header does not list: %s" k));
  if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
  if q.Rhema_engine.variables <> [ "s"; "t" ] then
    fail (Printf.sprintf "%s: the blank knows [%s], not s and t" k (String.concat ", " q.Rhema_engine.variables));
  if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s, not Numeric" k q.Rhema_engine.context);
  let whole_question = String.concat "\n" (k :: p :: q.Rhema_engine.answer_text :: Rhema_engine.describe_mistakes q) in
  if not (Hashtbl.mem examined whole_question) then begin
    Hashtbl.replace examined whole_question ();
    let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
    if not (List.mem_assoc k allowed) then wrong "a kind with no numbers expected"
    else try examine k q with Failure m -> wrong m | e -> wrong (Printexc.to_string e)
  end

(* ---- The working of this file, tried on its own --------------------------- *)

let forward_text body = "Find the Laplace transform [`F(s)`] of [`f(t) = " ^ body ^ "`]."
let backward_text body = "Find the function [`f(t)`] whose Laplace transform is [`F(s) = " ^ body ^ "`]."

let check_own_working () =
  let flat scale degree rate = { scale; degree; rate; wave = Flat } in
  let sine scale rate b = { scale; degree = 0; rate; wave = Sine b } in
  let cosine scale rate b = { scale; degree = 0; rate; wave = Cosine b } in
  let tight found wanted = Float.abs (found -. wanted) <= 1e-10 *. Float.abs wanted in
  (* the integral, on functions whose transforms are known: read from a
     text, transformed at s *)
  List.iter
    (fun (body, s, wanted) ->
      match read (forward_text body) with
      | exception Failure m -> fail (Printf.sprintf "own working: %s is not read: %s" body m)
      | Inverse _ -> fail (Printf.sprintf "own working: %s is read as a fraction" body)
      | Transform terms ->
          let found = transform terms s in
          if not (tight found wanted) then
            fail (Printf.sprintf "own working: the transform of %s at %g is %.14g, not %.14g" body s found wanted))
    [ ({|3t^{3}|}, 2., 18. /. 16.);
      ({|t^{4}|}, 1.3, 24. /. power_of 1.3 5);
      ({|6e^{-3t}|}, 9.2, 6. /. 12.2);
      ({|e^{4t}|}, 5.3, 1. /. 1.3);
      ({|\cos(5t)|}, 1.3, 1.3 /. (1.69 +. 25.));
      ({|2\sin(5t)|}, 1.3, 10. /. (1.69 +. 25.));
      ({|7 - 6t + 4e^{4t}|}, 5.3, (7. /. 5.3) -. (6. /. (5.3 *. 5.3)) +. (4. /. 1.3));
      ({|2t^{2} e^{-4t}|}, 9.2, 4. /. power_of 13.2 3);
      ({|t e^{4t}|}, 5.3, 1. /. (1.3 *. 1.3));
      ({|e^{2t} \sin(3t)|}, 4., 3. /. 13.);
      ({|e^{-4t} \cos(5t)|}, 5.3, 9.3 /. ((9.3 *. 9.3) +. 25.)) ];
  (* texts that are not read at all *)
  List.iter
    (fun text ->
      match read text with
      | exception Failure _ -> ()
      | _ -> fail (Printf.sprintf "own working: %s is read" text))
    (List.map forward_text
       [ {|1t^{2}|}; {|t^{1}|}; {|2t^{0}|}; {|e^{1t}|}; {|e^{-1t}|}; {|e^{0t}|}; {|\sin(1t)|}; {|\sin(0t)|}; {|2 t|}; {|0|};
         {|3 + 0t|}; {|-t|}; {|- t|}; {|2e^{t}\sin(t)|}; {|t^{2}e^{t}|}; {|02t|}; {|e^{2x}|}; {|3 + |}; {|\tan(t)|};
         {|t e^{t} \sin(t)|} ]
    @ List.map backward_text
        [ {|\frac{0}{s + 1}|}; {|\frac{1s}{s^{2} + 1}|}; {|\frac{s + 0}{s^{2} + 1}|}; {|\frac{2}{s^{1}}|};
          {|\frac{2}{s + 0}|}; {|\frac{2}{s^{2} + 1s + 3}|}; {|\frac{2}{2s + 1}|}; {|\frac{+2}{s + 1}|};
          {|\frac{2}{s^{2} + 0s + 4}|}; {|\frac{2}{t + 1}|}; {|\frac{s^{2}}{s + 1}|}; {|2|} ]
    @ [ {|Find the Laplace transform [`F(s)`] of [`f(t) = t^{2}`]|};
        {|Find the Laplace transform [`F(s)`] of [`g(t) = t^{2}`].|} ]);
  (* fractions and the functions they come from; None where no answer of
     the kinds asked here exists *)
  List.iter
    (fun (body, wanted) ->
      match read (backward_text body) with
      | exception Failure m -> fail (Printf.sprintf "own working: %s is not read: %s" body m)
      | Transform _ -> fail (Printf.sprintf "own working: %s is read as a function of t" body)
      | Inverse (top, below) -> (
          match (inverse top below, wanted) with
          | exception Failure _ -> if wanted <> None then fail (Printf.sprintf "own working: %s is refused" body)
          | _, None -> fail (Printf.sprintf "own working: %s is given an inverse" body)
          | found, Some terms ->
              if found <> terms then
                fail (Printf.sprintf "own working: the inverse of %s is not the one written by hand" body);
              let s = float (growth terms) +. 1.3 in
              if not (tight (transform found s) (fraction_at top below s)) then
                fail (Printf.sprintf "own working: the inverse of %s does not transform back into it" body)))
    [ ({|\frac{6}{s^{4}}|}, Some [ flat 1. 3 0 ]);
      ({|\frac{5}{s}|}, Some [ flat 5. 0 0 ]);
      ({|\frac{12}{s^{2}}|}, Some [ flat 12. 1 0 ]);
      ({|\frac{3}{s - 2}|}, Some [ flat 3. 0 2 ]);
      ({|\frac{4}{s + 4}|}, Some [ flat 4. 0 (-4) ]);
      ({|\frac{-8}{s^{2} + 2s - 3}|}, Some [ flat 2. 0 (-3); flat (-2.) 0 1 ]);
      ({|\frac{2s}{s^{2} - 4}|}, Some [ flat 1. 0 (-2); flat 1. 0 2 ]);
      ({|\frac{s - 22}{s^{2} + s - 6}|}, Some [ flat 5. 0 (-3); flat (-4.) 0 2 ]);
      ( {|\frac{5s - 5}{s^{2} + 25}|},
        Some [ cosine 5. 0 5; sine (-1.) 0 5 ] );
      ({|\frac{-s}{s^{2} + 1}|}, Some [ cosine (-1.) 0 1 ]);
      ({|\frac{1}{s^{3}}|}, None);
      ({|\frac{s}{s^{3}}|}, None);
      ({|\frac{s}{s + 1}|}, None);
      ({|\frac{1}{s^{2} + 2s + 1}|}, None);
      ({|\frac{1}{s^{2} + 2s + 5}|}, None);
      ({|\frac{s}{s^{2} + 3}|}, None);
      ({|\frac{s + 1}{s^{2} + 4}|}, None);
      ({|\frac{s}{s^{2} - 3s}|}, None);
      ({|\frac{s - 1}{s^{2} - 3s + 2}|}, None);
      ({|\frac{1}{s^{2} - 1}|}, None);
      ({|\frac{1}{s^{2} - 2}|}, None) ];
  (* the mistakes that can be made on a function *)
  List.iter
    (fun (name, forward, terms, wanted) ->
      if slips ~forward terms <> wanted then fail ("own working: the mistakes that can be made on " ^ name))
    [ ("3 t^2", true, [ flat 3. 2 0 ], [ ("factorial_forgotten", [ flat 1.5 2 0 ]) ]);
      ("3 t", true, [ flat 3. 1 0 ], []);
      ("2 t e^t", true, [ flat 2. 1 1 ], [ ("shift_sign", [ flat 2. 1 (-1) ]) ]);
      ( "2 t^2 e^t", true, [ flat 2. 2 1 ],
        [ ("factorial_forgotten", [ flat 1. 2 1 ]); ("shift_sign", [ flat 2. 2 (-1) ]) ] );
      ( "e^-t sin(2t)", true, [ sine 1. (-1) 2 ],
        [ ("shift_sign", [ sine 1. 1 2 ]); ("sine_cosine_swapped", [ cosine 1. (-1) 2 ]) ] );
      ( "3 - t + 4 e^-2t", true, [ flat 3. 0 0; flat (-1.) 1 0; flat 4. 0 (-2) ],
        [ ("shift_sign", [ flat 3. 0 0; flat (-1.) 1 0; flat 4. 0 2 ]) ] );
      ("6 t, going back", false, [ flat 6. 1 0 ], []);
      ("6 t^3, going back", false, [ flat 6. 3 0 ], [ ("factorial_forgotten", [ flat 36. 3 0 ]) ]);
      ( "2 cos(3t) - sin(3t), going back", false, [ cosine 2. 0 3; sine (-1.) 0 3 ],
        [ ("sine_cosine_swapped", [ sine 2. 0 3; cosine (-1.) 0 3 ]) ] ) ];
  (* two functions the mistakes do not tell from the right answer, which is
     why the grammar does not ask them: they are seen to be the same *)
  let same terms changed = not (apart (List.map (value changed) instants) (List.map (value terms) instants)) in
  let even = [ flat 2. 0 (-3); flat 2. 0 3 ] and equal = [ cosine 4. 0 2; sine 4. 0 2 ] in
  if not (same even (shifted_wrongly even)) then
    fail "own working: 2 e^(-3t) + 2 e^(3t) with its shifts changed is told apart from itself";
  if not (same equal (swapped equal)) then
    fail "own working: 4 cos(2t) + 4 sin(2t) with sine and cosine exchanged is told apart from itself";
  let odd = [ flat 2. 0 (-3); flat (-2.) 0 3 ] in
  if same odd (shifted_wrongly odd) then fail "own working: 2 e^(-3t) - 2 e^(3t) with its shifts changed is not told apart"

let () =
  check_own_working ();
  let base = load_file "laplace_transform.rhm" in
  let per_budget = function 1 -> 600 | 2 -> 3000 | _ -> 6000 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to per_budget cost - 1 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> check cost seed q
    done
  done;
  (* left alone, the budget is the middle price *)
  for seed = 0 to 99 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q -> check 2 seed q
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
  List.iter (fun (k, _) -> if times k = 0 then fail ("never generated: " ^ k)) prices;
  (* the numbers of each form: all of these and no others *)
  List.iter
    (fun (k, names) ->
      List.iter
        (fun (name, values) ->
          let found = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
          let missing = List.filter (fun value -> not (List.mem value found)) values in
          let more = List.filter (fun value -> not (List.mem value values)) found in
          if missing <> [] then
            fail (Printf.sprintf "%s: the %s never takes the values [%s]" k name (String.concat "; " missing));
          if more <> [] then fail (Printf.sprintf "%s: the %s takes the values [%s] too" k name (String.concat "; " more)))
        names)
    allowed;
  Hashtbl.iter
    (fun (k, name) _ ->
      match List.assoc_opt k allowed with
      | Some names when List.mem_assoc name names -> ()
      | _ -> fail (Printf.sprintf "%s: the %s was noted and is not looked at" k name))
    noted;
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
  if !failures = 0 then print_endline "Rhema Laplace transform tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d Laplace transform test(s) failed." !failures);
    exit 1
  end
