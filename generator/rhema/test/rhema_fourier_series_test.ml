(* Independent checks for fourier_series.rhm. Nothing here uses the
   grammar's closed formulas: no coefficient is taken from a table. The
   whole printed text of each question must be one of the four wordings of
   these questions (a text that cannot be read is a failure), and the
   function is read back from it as one or two pieces, each of the form

     c + l x + s x^2 + a |x|,

   the first on the left half of the interval and the second on the right
   (an expression printed alone is both). Every coefficient is then worked
   out from the definition printed in the question,

     a_n = (1 / pi) * integral from -pi to pi of f(x) cos nx dx,
     b_n = (1 / pi) * integral from -pi to pi of f(x) sin nx dx,

   whose wording, a_0 / 2 as the constant term and 1 / pi in front of each
   integral, must be exactly the one these checks use. The integral is
   taken over each half separately, so that the jump or the kink at 0 does
   not spoil it: each half is cut into 64 panels, each integrated with the
   8-point Gauss-Legendre rule, whose nodes are found here by Newton's
   method. That is within about 1e-14 of the truth, and the engine's answer,
   a number or a formula in pi alone, must come within 1e-9 of it.

   Form by form:

     line, step_mean, square_wave, parabola_mean, parabola_cosine,
     absolute_value, half_line_mean, half_line_cosine, half_line_sine
                     the coefficient named in the text (a_0, a_n or b_n),
                     by the integral above
     other_interval  the text prints its own definition on (-L, L),
                       b_n = (1 / L) * integral from -L to L of
                             f(x) sin(n pi x / L) dx;
                     every L of it is read and must be the same number,
                     with the period 2 L, and the integral is taken as
                     printed
     jump_at_zero, jump_at_pi
                     the value of the series at the point, found twice:
                     by Dirichlet's theorem, as the average of the two
                     one-sided limits of the periodic extension there,
                     read off the pieces (at pi: the right piece just
                     below pi and the left piece just above -pi), which
                     must differ (it is a jump); and as the limit of the
                     partial sums of the series at the point, with every
                     coefficient up to n = 400 integrated here (on 512
                     panels a half) and the error, which falls like 1 / N,
                     taken out by Richardson's rule from N = 200 and 400:
                     the two must agree within 1e-6

   Where only an odd n is asked (square_wave, absolute_value,
   half_line_cosine), every n that comes up must be odd, and the integral
   must give 0 for n = 2, 4, 6 and 8, as the grammar's comments promise;
   and every coefficient asked must not be 0.

   Mistakes. Each is redone as its description says:

     half_factor          1 / (2 pi) in front of the same integral: listed
                          for every a_n and b_n with n >= 1 on (-pi, pi)
     constant_term_given  a_0 / 2, the constant term of the series: listed
                          for every a_0 (where 1 / (2 pi) in front of the
                          integral comes to the same number, and only this
                          one is listed, as the comments say)
     one_sided            the limit at the point of the piece printed for
                          0 < x < pi
     pi_for_length        b_n of the same f(x) on (-pi, pi), with 1 / pi in
                          front and sin nx, worked out by the integral

   The engine must list exactly these, in the order they are declared, each
   with a plain answer that comes to this value and is not the right
   answer; each mistake's description must be the one of its name.

   The answer must be the one blank's, a plain answer (graded with the
   functions switched off), and a number where it has no pi; where it has
   pi it is read exactly as a sum of fractions times powers of pi, and the
   powers must be those of its kind (pi^2 for parabola_mean, pi for
   half_line_mean, 1 / pi for square_wave, absolute_value, half_line_cosine
   and other_interval, a number and a multiple of pi for jump_at_pi). The
   sentence asking for pi to be written as pi is there in exactly the kinds
   that print it.

   The working of this file is itself tried first, on texts, integrals,
   series and formulas written by hand.

   Besides the answers: every kind appears at its price alone and spends its
   budget; a budget outside 1..3 gives no question; the budget the grammar
   sets itself is the middle price; and each printed number of each form
   takes exactly the values expected, none missing and none more. *)

module F = Rhema_formula
module N = Rhema_number

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

(* ---- Functions of x -------------------------------------------------------- *)

(* constant + linear x + square x^2 + absolute |x| *)
type piece = { constant : int; linear : int; square : int; absolute : int }

let nothing = { constant = 0; linear = 0; square = 0; absolute = 0 }

let value_of p x =
  float p.constant +. (float p.linear *. x) +. (float p.square *. x *. x) +. (float p.absolute *. Float.abs x)

(* One piece on the left half of the interval and one on the right; printed
   as one expression, the two are the same, and `single` says so. *)
type func = { left : piece; right : piece; single : bool }

(* ---- The integral ---------------------------------------------------------- *)

(* The nodes and weights of the Gauss-Legendre rule with n points on
   [-1, 1]: the roots of the Legendre polynomial P_n, by Newton's method. *)
let gauss_legendre n =
  Array.init n (fun i ->
      let x = ref (cos (pi *. (float i +. 0.75) /. (float n +. 0.5))) in
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

let integrate ~panels g a b =
  let h = (b -. a) /. float panels in
  let total = ref 0. in
  for i = 0 to panels - 1 do
    let middle = a +. (h *. (float i +. 0.5)) in
    Array.iter (fun (x, w) -> total := !total +. (w *. g (middle +. (0.5 *. h *. x)))) nodes
  done;
  0.5 *. h *. !total

type wave = Cosine | Sine

(* The integral from -half to half of f(x) times cos or sin of
   n pi x / half, taken over each half of the interval separately. *)
let integral ?(panels = 64) f ~half wave n =
  let turn x = match wave with Cosine -> cos (float n *. pi *. x /. half) | Sine -> sin (float n *. pi *. x /. half) in
  let over p a b = if p = nothing then 0. else integrate ~panels (fun x -> value_of p x *. turn x) a b in
  over f.left (-.half) 0. +. over f.right 0. half

(* The coefficient as the questions define it: 1 / half in front. *)
let coefficient ?panels f ~half wave n = integral ?panels f ~half wave n /. half

(* ---- The series at a point ------------------------------------------------- *)

(* The coefficients a_0..a_400 and b_0..b_400 on (-pi, pi), for a function
   that is one monomial on one half and 0 on the other. Integration is
   linear, so those of any function of the pieces here are sums of these;
   each is worked out once. *)
let terms = 400

type side = Left | Right

let monomials = [ `Constant; `Linear; `Square; `Absolute ]

let unit = function
  | `Constant -> { nothing with constant = 1 }
  | `Linear -> { nothing with linear = 1 }
  | `Square -> { nothing with square = 1 }
  | `Absolute -> { nothing with absolute = 1 }

let weight p = function
  | `Constant -> p.constant
  | `Linear -> p.linear
  | `Square -> p.square
  | `Absolute -> p.absolute

let bases : (side * [ `Constant | `Linear | `Square | `Absolute ], (float * float) array) Hashtbl.t = Hashtbl.create 8

let basis side monomial =
  match Hashtbl.find_opt bases (side, monomial) with
  | Some table -> table
  | None ->
      let p = unit monomial in
      let f = match side with Left -> { left = p; right = nothing; single = false } | Right -> { left = nothing; right = p; single = false } in
      let table =
        Array.init (terms + 1) (fun n ->
            (coefficient ~panels:512 f ~half:pi Cosine n, coefficient ~panels:512 f ~half:pi Sine n))
      in
      Hashtbl.replace bases (side, monomial) table;
      table

let series_coefficients f =
  let a = Array.make (terms + 1) 0. and b = Array.make (terms + 1) 0. in
  List.iter
    (fun (side, p) ->
      List.iter
        (fun m ->
          let w = weight p m in
          if w <> 0 then
            Array.iteri
              (fun n (an, bn) ->
                a.(n) <- a.(n) +. (float w *. an);
                b.(n) <- b.(n) +. (float w *. bn))
              (basis side m))
        monomials)
    [ (Left, f.left); (Right, f.right) ];
  (a, b)

(* The partial sum with the terms up to n = count at x. *)
let partial_sum (a, b) count x =
  let total = ref (a.(0) /. 2.) in
  for n = 1 to count do
    total := !total +. (a.(n) *. cos (float n *. x)) +. (b.(n) *. sin (float n *. x))
  done;
  !total

(* The limit of the partial sums at x: S_N comes to it with an error c / N,
   which 2 S_2N - S_N takes out. *)
let series_at f x =
  let c = series_coefficients f in
  (2. *. partial_sum c terms x) -. partial_sum c (terms / 2) x

(* Dirichlet's theorem: the average of the two one-sided limits of the
   periodic extension at x = 0 or x = pi, which must differ. *)
let one_sided_limits f ~at_pi =
  if at_pi then
    (* just below pi the right piece; just above pi the extension repeats
       what is just above -pi, the left piece *)
    (value_of f.right pi, value_of f.left (-.pi))
  else (value_of f.left 0., value_of f.right 0.)

(* ---- Exact formulas in pi -------------------------------------------------- *)

(* A formula made of numbers and pi with sums, products, quotients by a
   single term and whole powers, read as a sum of fractions times powers of
   pi: (power, fraction) pairs, by increasing power, with no fraction 0.
   Anything else (a function, a root, a variable) is refused. *)
let rec laurent formula =
  let tidy pairs =
    let powers = List.sort_uniq compare (List.map fst pairs) in
    List.filter_map
      (fun e ->
        let sum = List.fold_left (fun s (e', c) -> if e = e' then N.add s c else s) N.zero pairs in
        if N.is_zero sum then None else Some (e, sum))
      powers
  in
  let times a b = tidy (List.concat_map (fun (e, c) -> List.map (fun (e', c') -> (e + e', N.multiply c c')) b) a) in
  match formula with
  | F.Constant c -> tidy [ (0, c) ]
  | F.Pi -> [ (1, N.of_int 1) ]
  | F.Add (a, b) -> tidy (laurent a @ laurent b)
  | F.Subtract (a, b) -> tidy (laurent a @ List.map (fun (e, c) -> (e, N.negate c)) (laurent b))
  | F.Negate a -> List.map (fun (e, c) -> (e, N.negate c)) (laurent a)
  | F.Multiply (a, b) -> times (laurent a) (laurent b)
  | F.Divide (a, b) -> (
      match laurent b with
      | [ (e, c) ] -> times (laurent a) [ (-e, N.divide (N.of_int 1) c) ]
      | _ -> failwith "a formula divided by a sum or by 0")
  | F.Power (a, k) when k >= 0 ->
      let rec go acc k = if k = 0 then acc else go (times acc (laurent a)) (k - 1) in
      go [ (0, N.of_int 1) ] k
  | _ -> failwith "a formula with something other than numbers and pi in it"

let worth pairs = List.fold_left (fun t (e, c) -> t +. (N.to_float c *. (pi ** float e))) 0. pairs

(* A plain answer: a number, or a formula in pi that holds pi. *)
let read_value what = function
  | Rhema_engine.Plain (Rhema_engine.Num n) -> if N.is_zero n then [] else [ (0, n) ]
  | Rhema_engine.Plain (Rhema_engine.Formula f) ->
      if F.variables f <> [] then failwith (what ^ " is a formula with a variable in it");
      let pairs = laurent f in
      if List.for_all (fun (e, _) -> e = 0) pairs then
        failwith (what ^ " is a formula with no pi in it: a number is not given as a formula");
      pairs
  | Rhema_engine.Plain other -> failwith (what ^ " is not a number: " ^ Rhema_engine.describe_value other)
  | other -> failwith (what ^ " is not a plain answer: " ^ Rhema_engine.describe_value other)

(* ---- Reading the text ------------------------------------------------------ *)

(* The whole of `text` must be the pattern. Its groups are given back, all
   taken at once, before any other pattern is tried: a group that took no
   part in the match is None. *)
let fields re count text =
  if Str.string_match (Str.regexp re) text 0 && Str.match_end () = String.length text then
    Some (Array.init count (fun i -> match Str.matched_group (i + 1) text with s -> Some s | exception Not_found -> None))
  else None

let field groups n = match groups.(n - 1) with Some s -> s | None -> failwith "a part of the text is missing"

(* A pattern from parts: words written as they are, groups, and words that
   may be missing (a group too). *)
type part = Words of string | Group of string | Maybe of string

let pattern parts =
  String.concat ""
    (List.map
       (function Words s -> Str.quote s | Group g -> "\\(" ^ g ^ "\\)" | Maybe s -> "\\(" ^ Str.quote s ^ "\\)?")
       parts)

let groups parts = List.length (List.filter (function Words _ -> false | _ -> true) parts)
let match_parts parts text = fields (pattern parts) (groups parts) text

(* A whole number written without a sign and without a 0 in front. *)
let number text =
  match fields "0\\|[1-9][0-9]*" 0 text with
  | Some _ -> int_of_string text
  | None -> failwith ("cannot read the number \"" ^ text ^ "\"")

(* A whole number with its sign: no -0, no 0 in front. *)
let integer text =
  match fields "0\\|-?[1-9][0-9]*" 0 text with
  | Some _ -> int_of_string text
  | None -> failwith ("cannot read the number \"" ^ text ^ "\"")

(* A number written in front of x: nothing stands for 1, and 0 and 1 are
   never written. *)
let coefficient_of text =
  if text = "" then 1
  else
    let n = number text in
    if n < 2 then failwith ("a coefficient " ^ text ^ " is written out");
    n

let signed sign n = if sign = "-" then -n else n

(* One piece, in the shapes these questions print: a number; k x; k x^{2};
   k |x|; c + k x or c - k x with c not 0. *)
let piece_shapes =
  let scaled g = signed (field g 1) (coefficient_of (field g 2)) in
  [ ("\\(0\\|-?[1-9][0-9]*\\)", 1, fun g -> { nothing with constant = integer (field g 1) });
    ("\\(-?\\)\\([0-9]*\\)x", 2, fun g -> { nothing with linear = scaled g });
    ("\\(-?\\)\\([0-9]*\\)x\\^{2}", 2, fun g -> { nothing with square = scaled g });
    ("\\(-?\\)\\([0-9]*\\)|x|", 2, fun g -> { nothing with absolute = scaled g });
    ( "\\(-?[1-9][0-9]*\\) \\([-+]\\) \\([0-9]*\\)x",
      3,
      fun g ->
        { nothing with
          constant = integer (field g 1);
          linear = signed (if field g 2 = " - " || field g 2 = "-" then "-" else "") (coefficient_of (field g 3)) } ) ]

let piece text =
  let rec first = function
    | (re, count, build) :: rest -> ( match fields re count text with Some g -> build g | None -> first rest)
    | [] -> failwith ("cannot read the piece \"" ^ text ^ "\"")
  in
  first piece_shapes

let cases =
  [ Words {|\begin{cases} |}; Group "[^&]*"; Words {| & -\pi < x < 0 \\ |}; Group "[^&]*";
    Words {| & 0 < x < \pi \end{cases}|} ]

(* f(x) as printed: an expression alone (on the whole interval) or two
   pieces in `cases`. *)
let read_function ~single body =
  if single then
    let p = piece body in
    { left = p; right = p; single = true }
  else
    match match_parts cases body with
    | Some g -> { left = piece (field g 1); right = piece (field g 2); single = false }
    | None -> failwith ("cannot read the function \"" ^ body ^ "\"")

let series =
  {| The function is extended with period [`2\pi`], and its Fourier series is [`\frac{a_0}{2} + \sum_{n=1}^{\infty} (a_n \cos nx + b_n \sin nx)`], with [`a_n = \frac{1}{\pi} \int_{-\pi}^{\pi} f(x) \cos nx \, dx`] and [`b_n = \frac{1}{\pi} \int_{-\pi}^{\pi} f(x) \sin nx \, dx`].|}

let exact = {| Give the exact value, with [`\pi`] written as pi where it is needed.|}

let standard_form =
  [ Words "Let [`f(x) = "; Group "[^`]*"; Words "`]"; Maybe {| for [`-\pi < x < \pi`]|}; Words "."; Words series;
    Words " Find [`"; Group "[^`]*"; Words "`]."; Maybe exact ]

let jump_form =
  [ Words "Let [`f(x) = "; Group "[^`]*";
    Words {|`], extended with period [`2\pi`]. To what value does its Fourier series converge at [`x = |};
    Group "[^`]*"; Words "`]?"; Maybe exact ]

let length = "[^ `{}]*"

let other_form =
  [ Words "Let [`f(x) = "; Group "[^`]*"; Words "`] for [`-"; Group length; Words " < x < "; Group length;
    Words "`], extended with period [`"; Group length;
    Words {|`]. Its Fourier series is [`\frac{a_0}{2} + \sum_{n=1}^{\infty} \left(a_n \cos \frac{n \pi x}{|};
    Group length; Words {|} + b_n \sin \frac{n \pi x}{|}; Group length; Words {|}\right)`], with [`b_n = \frac{1}{|};
    Group length; Words {|} \int_{-|}; Group length; Words "}^{"; Group length;
    Words {|} f(x) \sin \frac{n \pi x}{|}; Group length; Words {|} \, dx`]. Find [`|}; Group "[^`]*"; Words "`].";
    Maybe exact ]

(* a_0, a_{n} or b_{n} with n from 1 on. *)
let coefficient_name text =
  if text = "a_0" then (Cosine, 0)
  else
    match fields "\\([ab]\\)_{\\([1-9][0-9]*\\)}" 2 text with
    | Some g -> ((if field g 1 = "a" then Cosine else Sine), int_of_string (field g 2))
    | None -> failwith ("cannot read the coefficient \"" ^ text ^ "\"")

(* What a question asks: a coefficient on (-pi, pi), the value of the
   series at 0 or at pi, or b_n on (-L, L). *)
type asked = Coefficient of func * wave * int | Jump of func * bool | Other of func * int * int

(* The question asked, and whether the text asks for pi to be written as
   pi. *)
let read text =
  match match_parts standard_form text with
  | Some g ->
      let wave, n = coefficient_name (field g 3) in
      (Coefficient (read_function ~single:(g.(1) <> None) (field g 1), wave, n), g.(3) <> None)
  | None -> (
      match match_parts jump_form text with
      | Some g ->
          let at_pi =
            match field g 2 with "0" -> false | {|\pi|} -> true | other -> failwith ("a jump asked at " ^ other)
          in
          (Jump (read_function ~single:false (field g 1), at_pi), g.(2) <> None)
      | None -> (
          match match_parts other_form text with
          | Some g ->
              let ls = List.map (fun i -> number (field g i)) [ 2; 3; 5; 6; 7; 8; 9; 10 ] in
              let l = List.hd ls in
              if l < 1 || List.exists (fun x -> x <> l) ls then failwith "the numbers L of the interval are not one number";
              if number (field g 4) <> 2 * l then failwith "the period is not twice L";
              let wave, n = coefficient_name (field g 11) in
              if wave <> Sine || n = 0 then failwith "the coefficient asked on (-L, L) is not b_n";
              (Other (read_function ~single:true (field g 1), l, n), g.(11) <> None)
          | None -> failwith "the text is not worded as a question on Fourier series is"))

(* ---- What a question comes to ---------------------------------------------- *)

(* The right answer, and each mistake that can be made with its answer, in
   the order they are declared. Failure if the question is not sound. *)
let work asked =
  match asked with
  | Coefficient (f, wave, n) ->
      let whole = integral f ~half:pi wave n in
      let right = whole /. pi in
      if Float.abs right < 1e-6 then failwith "the coefficient asked is 0";
      if n = 0 then (right, [ ("constant_term_given", right /. 2.) ])
      else (right, [ ("half_factor", whole /. (2. *. pi)) ])
  | Jump (f, at_pi) ->
      let below, above = one_sided_limits f ~at_pi in
      if Float.abs (below -. above) < 1e-6 then failwith "there is no jump at the point";
      let right = (below +. above) /. 2. in
      let x = if at_pi then pi else 0. in
      let summed = series_at f x in
      if Float.abs (summed -. right) > 1e-6 then
        failwith (Printf.sprintf "the partial sums at the point come to %.9g, not to the average %.9g" summed right);
      (right, [ ("one_sided", value_of f.right x) ])
  | Other (f, l, n) ->
      let right = coefficient f ~half:(float l) Sine n in
      if Float.abs right < 1e-6 then failwith "the coefficient asked is 0";
      (right, [ ("pi_for_length", coefficient f ~half:pi Sine n) ])

(* ---- What was generated ---------------------------------------------------- *)

(* The numbers of each form, to compare at the end with the values expected:
   none outside them, and none of them missing. *)
let noted : (string * string, string list) Hashtbl.t = Hashtbl.create 64

let note k name value =
  let before = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
  if not (List.mem value before) then Hashtbl.replace noted (k, name) (value :: before)

let note_number k name n = note k name (string_of_int n)
let pair a b = Printf.sprintf "(%d, %d)" a b

let is_constant p = p = { nothing with constant = p.constant }
let is_line p = p = { nothing with linear = p.linear } && p.linear <> 0
let is_square p = p = { nothing with square = p.square } && p.square <> 0
let is_absolute p = p = { nothing with absolute = p.absolute } && p.absolute <> 0

(* Each kind asks what its header gives it, of the function it gives it.
   Its numbers are noted. *)
let of_its_kind k asked exactly =
  let not_so () = failwith "the function or what is asked of it is not the one of its kind" in
  note k "exact sentence" (if exactly then "yes" else "no");
  let odd_only f wave =
    List.iter
      (fun m ->
        if Float.abs (coefficient f ~half:pi wave m) > 1e-10 then
          failwith (Printf.sprintf "the coefficient for the even n = %d is not 0" m))
      [ 2; 4; 6; 8 ]
  in
  match (k, asked) with
  | "line", Coefficient ({ single = true; left; _ }, Sine, n) when is_line left ->
      note_number k "k" left.linear;
      note_number k "n" n
  | "step_mean", Coefficient ({ single = false; left; right }, Cosine, 0) when is_constant left && is_constant right ->
      note k "values" (pair left.constant right.constant)
  | "square_wave", Coefficient (({ single = false; left; right } as f), Sine, n)
    when is_constant left && is_constant right && left.constant = -right.constant && right.constant > 0 ->
      odd_only f Sine;
      note_number k "c" right.constant;
      note_number k "n" n
  | "parabola_mean", Coefficient ({ single = true; left; _ }, Cosine, 0) when is_square left -> note_number k "k" left.square
  | "parabola_cosine", Coefficient ({ single = true; left; _ }, Cosine, n) when is_square left && n > 0 ->
      note_number k "k" left.square;
      note_number k "n" n
  | ("jump_at_zero" | "jump_at_pi"), Jump ({ single = false; left; right }, at_pi)
    when is_constant left && is_line { right with constant = 0 } && at_pi = (k = "jump_at_pi") ->
      note k "left value, right constant" (pair left.constant right.constant);
      note_number k "right slope" right.linear
  | "absolute_value", Coefficient (({ single = true; left; _ } as f), Cosine, n) when is_absolute left && n > 0 ->
      if left.absolute < 0 then not_so ();
      odd_only f Cosine;
      note_number k "c" left.absolute;
      note_number k "n" n
  | ( ("half_line_mean" | "half_line_cosine" | "half_line_sine"),
      Coefficient (({ single = false; left; right } as f), wave, n) )
    when left = { nothing with constant = 0 } && is_line right ->
      (match (k, wave, n) with
      | "half_line_mean", Cosine, 0 -> ()
      | "half_line_cosine", Cosine, n when n > 0 -> odd_only f Cosine
      | "half_line_sine", Sine, n when n > 0 -> ()
      | _ -> not_so ());
      note_number k "k" right.linear;
      if n > 0 then note_number k "n" n
  | "other_interval", Other ({ single = true; left; _ }, l, n) when is_line left ->
      note_number k "k" left.linear;
      note_number k "L" l;
      note_number k "n" n
  | _ -> not_so ()

let rec range a b = if a > b then [] else a :: range (a + 1) b
let numbers a b = List.map string_of_int (range a b)
let not_zero a b = List.filter (fun n -> n <> 0) (range a b)
let numbers_not_zero a b = List.map string_of_int (not_zero a b)
let odd = [ "1"; "3"; "5"; "7" ]

(* The values each form's numbers take, all of which must appear. *)
let allowed =
  let k = ("k", numbers_not_zero (-5) 5) and yes = ("exact sentence", [ "yes" ]) in
  let steps =
    List.concat_map
      (fun a -> List.filter_map (fun b -> if a <> b && a + b <> 0 then Some (pair a b) else None) (not_zero (-6) 6))
      (not_zero (-6) 6)
  in
  (* at 0 the two sides must differ; at pi they always do *)
  let jump at_pi =
    let values =
      List.concat_map
        (fun a -> List.filter_map (fun b -> if at_pi || a <> b then Some (pair a b) else None) (range (-6) 6))
        (range (-6) 6)
    in
    [ ("left value, right constant", values); ("right slope", numbers_not_zero (-5) 5); yes ]
  in
  [ ("line", [ k; ("n", numbers 1 6); ("exact sentence", [ "no" ]) ]);
    ("step_mean", [ ("values", steps); ("exact sentence", [ "no" ]) ]);
    ("square_wave", [ ("c", numbers 1 6); ("n", odd); yes ]);
    ("parabola_mean", [ k; yes ]);
    ("parabola_cosine", [ k; ("n", numbers 1 5); yes ]);
    ("jump_at_zero", jump false);
    ("jump_at_pi", jump true);
    ("absolute_value", [ ("c", numbers 1 5); ("n", odd); yes ]);
    ("half_line_mean", [ k; yes ]);
    ("half_line_cosine", [ k; ("n", odd); yes ]);
    ("half_line_sine", [ k; ("n", numbers 2 6); yes ]);
    ("other_interval", [ k; ("L", numbers 1 4); ("n", numbers 1 5); yes ]) ]

let prices =
  [ ("line", 1); ("step_mean", 1); ("square_wave", 2); ("parabola_mean", 2); ("parabola_cosine", 2);
    ("jump_at_zero", 2); ("jump_at_pi", 2); ("absolute_value", 3); ("half_line_mean", 3); ("half_line_cosine", 3);
    ("half_line_sine", 3); ("other_interval", 3) ]

(* The powers of pi in each kind's answer: those it may hold, and one it
   must. *)
let powers_of_pi =
  [ ("line", ([ 0 ], None)); ("step_mean", ([ 0 ], None)); ("square_wave", ([ -1 ], Some (-1)));
    ("parabola_mean", ([ 2 ], Some 2)); ("parabola_cosine", ([ 0 ], None)); ("jump_at_zero", ([ 0 ], None));
    ("jump_at_pi", ([ 0; 1 ], Some 1)); ("absolute_value", ([ -1 ], Some (-1))); ("half_line_mean", ([ 1 ], Some 1));
    ("half_line_cosine", ([ -1 ], Some (-1))); ("half_line_sine", ([ 0 ], None)); ("other_interval", ([ -1 ], Some (-1))) ]

(* Which mistakes must have been listed on which kinds, and on no other. *)
let made_on =
  [ ( "half_factor",
      [ "line"; "square_wave"; "parabola_cosine"; "absolute_value"; "half_line_cosine"; "half_line_sine" ] );
    ("constant_term_given", [ "step_mean"; "parabola_mean"; "half_line_mean" ]);
    ("one_sided", [ "jump_at_zero"; "jump_at_pi" ]);
    ("pi_for_length", [ "other_interval" ]) ]

(* What the description of each mistake must speak of. *)
let spoken =
  [ ("half_factor", [ "1 / (2 pi)"; "where 1 / pi belongs" ]);
    ("constant_term_given", [ "a_0 / 2"; "where a_0 is asked for" ]);
    ("one_sided", [ "one side of the jump"; "average of the two sides" ]);
    ("pi_for_length", [ "from -pi to pi"; "from -L to L" ]) ]

let made : (string * string, unit) Hashtbl.t = Hashtbl.create 16
let seen : (string, int) Hashtbl.t = Hashtbl.create 16
let times k = Option.value (Hashtbl.find_opt seen k) ~default:0

let close found wanted =
  Float.abs (found -. wanted) <= (1e-9 *. Float.max (Float.abs found) (Float.abs wanted)) +. 1e-12

let apart a b = Float.abs (a -. b) > 1e-6 *. Float.max 1. (Float.max (Float.abs a) (Float.abs b))

(* One question: Failure says what is wrong with it. *)
let examine k (q : Rhema_engine.question) =
  let only =
    match q.Rhema_engine.answers with
    | [ only ] -> only
    | answers -> failwith (Printf.sprintf "%d answers and not one" (List.length answers))
  in
  if only <> q.Rhema_engine.answer then failwith "the answer is not the one of the only blank";
  let asked, exactly = read q.Rhema_engine.prompt in
  of_its_kind k asked exactly;
  let right, wrong = work asked in
  let shape = read_value "the answer" only in
  let may, must = List.assoc k powers_of_pi in
  if List.exists (fun (e, _) -> not (List.mem e may)) shape then failwith "the answer holds a power of pi not of its kind";
  (match must with
  | Some e -> if not (List.mem_assoc e shape) then failwith (Printf.sprintf "the answer does not hold pi^%d" e)
  | None -> ());
  if List.exists (fun (e, _) -> e <> 0) shape && not exactly then
    failwith "the answer holds pi and the text does not say how to write pi";
  let answer = worth shape in
  if not (close answer right) then failwith (Printf.sprintf "worked out here, the answer is %.12g, not %.12g" right answer);
  (* the mistakes *)
  List.iter (fun (name, value) -> if not (apart value right) then failwith (name ^ " gives the right answer")) wrong;
  let listed = q.Rhema_engine.mistakes in
  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
  if names <> List.map fst wrong then
    failwith
      (Printf.sprintf "the mistakes listed are [%s], not [%s]" (String.concat ", " names)
         (String.concat ", " (List.map fst wrong)));
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
          let value = worth (read_value ("the answer of " ^ m.mistake) given) in
          let redone = List.assoc m.mistake wrong in
          if not (close value redone) then
            failwith (Printf.sprintf "%s gives %.12g, and redone here %.12g" m.mistake value redone);
          if not (apart value answer) then failwith (m.mistake ^ " gives the right answer")
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
  if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s, not Numeric" k q.Rhema_engine.context);
  let whole_question = String.concat "\n" (k :: p :: q.Rhema_engine.answer_text :: Rhema_engine.describe_mistakes q) in
  if not (Hashtbl.mem examined whole_question) then begin
    Hashtbl.replace examined whole_question ();
    let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
    if not (List.mem_assoc k allowed) then wrong "a kind with no numbers expected"
    else try examine k q with Failure m -> wrong m | e -> wrong (Printexc.to_string e)
  end

(* ---- The working of this file, tried on its own --------------------------- *)

let standard_text body ~whole name tail =
  "Let [`f(x) = " ^ body ^ "`]" ^ (if whole then {| for [`-\pi < x < \pi`]|} else "") ^ "." ^ series ^ " Find [`" ^ name
  ^ "`]." ^ tail

let cases_text l r = {|\begin{cases} |} ^ l ^ {| & -\pi < x < 0 \\ |} ^ r ^ {| & 0 < x < \pi \end{cases}|}

let jump_text l r at =
  "Let [`f(x) = " ^ cases_text l r ^ {|`], extended with period [`2\pi`]. To what value does its Fourier series converge at [`x = |}
  ^ at ^ "`]?" ^ exact

let other_text body l n =
  let s = string_of_int l in
  "Let [`f(x) = " ^ body ^ "`] for [`-" ^ s ^ " < x < " ^ s ^ "`], extended with period [`" ^ string_of_int (2 * l)
  ^ {|`]. Its Fourier series is [`\frac{a_0}{2} + \sum_{n=1}^{\infty} \left(a_n \cos \frac{n \pi x}{|} ^ s
  ^ {|} + b_n \sin \frac{n \pi x}{|} ^ s ^ {|}\right)`], with [`b_n = \frac{1}{|} ^ s ^ {|} \int_{-|} ^ s ^ "}^{" ^ s
  ^ {|} f(x) \sin \frac{n \pi x}{|} ^ s ^ {|} \, dx`]. Find [`b_{|} ^ string_of_int n ^ "}`]." ^ exact

let check_own_working () =
  let tight found wanted = Float.abs (found -. wanted) <= 1e-11 *. Float.max 1. (Float.abs wanted) in
  (* texts read, and the right answer worked out from them, against values
     found by hand *)
  List.iter
    (fun (text, wanted) ->
      match read text with
      | exception Failure m -> fail (Printf.sprintf "own working: %S is not read: %s" text m)
      | asked, _ -> (
          match work asked with
          | exception Failure m -> fail (Printf.sprintf "own working: %S is refused: %s" text m)
          | found, _ -> if not (tight found wanted) then fail (Printf.sprintf "own working: %S comes to %.14g, not %.14g" text found wanted)))
    [ (standard_text "x" ~whole:true "b_{1}" "", 2.);
      (standard_text "-3x" ~whole:true "b_{2}" "", 3.);
      (standard_text "x^{2}" ~whole:true "a_0" exact, 2. *. pi *. pi /. 3.);
      (standard_text "2x^{2}" ~whole:true "a_{1}" exact, -8.);
      (standard_text "|x|" ~whole:true "a_0" exact, pi);
      (standard_text "|x|" ~whole:true "a_{1}" exact, -4. /. pi);
      (standard_text (cases_text "-1" "1") ~whole:false "b_{1}" exact, 4. /. pi);
      (standard_text (cases_text "2" "5") ~whole:false "a_0" "", 7.);
      (standard_text (cases_text "0" "x") ~whole:false "a_0" exact, pi /. 2.);
      (standard_text (cases_text "0" "x") ~whole:false "b_{2}" exact, -0.5);
      (standard_text (cases_text "0" "x") ~whole:false "a_{3}" exact, -2. /. (9. *. pi));
      (jump_text "3" "1 + x" "0", 2.);
      (jump_text "3" "1 - 2x" {|\pi|}, (4. -. (2. *. pi)) /. 2.);
      (jump_text "-4" "x" {|\pi|}, (pi -. 4.) /. 2.);
      (other_text "x" 1 1, 2. /. pi);
      (other_text "-2x" 3 2, 6. /. pi) ];
  (* texts that are not read at all *)
  List.iter
    (fun text ->
      match read text with
      | exception Failure _ -> ()
      | _ -> fail (Printf.sprintf "own working: %S is read" text))
    ([ standard_text "1x" ~whole:true "b_{1}" ""; standard_text "0x" ~whole:true "b_{1}" "";
       standard_text "x^{3}" ~whole:true "b_{1}" ""; standard_text "02x" ~whole:true "b_{1}" "";
       standard_text "x" ~whole:true "b_{0}" ""; standard_text "x" ~whole:true "a_{0}" "";
       standard_text "x" ~whole:true "c_{1}" ""; standard_text "x" ~whole:false "b_{1}" "";
       standard_text (cases_text "1" "2") ~whole:true "a_0" ""; standard_text (cases_text "-0" "2") ~whole:false "a_0" "";
       standard_text (cases_text "1" "0 + x") ~whole:false "a_0" ""; standard_text "x" ~whole:true "b_{1}" " Thanks.";
       jump_text "1" "2 + x" "1"; jump_text "1" "2 + 1x" "0"; other_text "x" 0 1;
       "Let [`f(x) = x`] for [`-\\pi < x < \\pi`]. Find [`b_{1}`]." ]
    @ [ (let t = other_text "x" 2 1 in
         (* one L that is not the others *)
         Str.global_replace (Str.regexp_string "\\frac{1}{2}") "\\frac{1}{3}" t) ]);
  (* the series at a jump, against the average worked out by hand, and
     at a point where the extension is continuous, where it comes more
     slowly *)
  let f = { left = { nothing with constant = 3 }; right = { nothing with constant = 1; linear = -2 }; single = false } in
  if not (Float.abs (series_at f pi -. ((4. -. (2. *. pi)) /. 2.)) <= 1e-6) then
    fail "own working: the series of the jump does not come to its average at pi";
  if not (Float.abs (series_at f 0. -. 2.) <= 1e-6) then fail "own working: the series of the jump does not come to 2 at 0";
  let g = { left = { nothing with square = 1 }; right = { nothing with square = 1 }; single = false } in
  if not (Float.abs (series_at g 0.) <= 1e-4) then fail "own working: the series of x^2 does not come to 0 at 0";
  (* formulas in pi, on trees built by hand *)
  let c n = F.Constant (N.of_int n) and r a b = F.Constant (N.make a b) in
  List.iter
    (fun (name, tree, wanted) ->
      let found = match laurent tree with l -> Some l | exception Failure _ -> None in
      if found <> wanted then fail (Printf.sprintf "own working: the formula %s is misread" name))
    [ ("pi", F.Pi, Some [ (1, N.of_int 1) ]);
      ("(6 + pi - 5) / 2", F.Divide (F.Subtract (F.Add (c 6, F.Pi), c 5), c 2), Some [ (0, N.make 1 2); (1, N.make 1 2) ]);
      ("(5 + pi - 5) / 2", F.Divide (F.Subtract (F.Add (c 5, F.Pi), c 5), c 2), Some [ (1, N.make 1 2) ]);
      ("-(2/3 pi^2)", F.Negate (F.Multiply (r 2 3, F.Power (F.Pi, 2))), Some [ (2, N.make (-2) 3) ]);
      ("8/7/pi", F.Divide (r 8 7, F.Pi), Some [ (-1, N.make 8 7) ]);
      ("1 / (1 + pi)", F.Divide (c 1, F.Add (c 1, F.Pi)), None);
      ("sin(pi)", F.Sin F.Pi, None);
      ("x pi", F.Multiply (F.Variable "x", F.Pi), None) ]

let offset = 0

let () =
  check_own_working ();
  let base = load_file "fourier_series.rhm" in
  let per_budget = function 1 -> 5000 | 2 -> 15000 | _ -> 6000 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to per_budget cost - 1 do
      Random.init (seed + (100000 * cost) + offset);
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> check cost seed q
    done
  done;
  (* left alone, the budget is the middle price *)
  for seed = 0 to 99 do
    Random.init (seed + offset);
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
  if !failures = 0 then print_endline "Rhema Fourier series tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d Fourier series test(s) failed." !failures);
    exit 1
  end
