(* Independent checks for nonhomogeneous_ode.rhm. Nothing here uses the
   grammar's closed formulas, and nothing of the grammar is read but the
   kind of a question. The equation, the form asked for and the initial
   values are read back from the printed text, whose whole wording must be
   that of these questions (a text that cannot be read is a failure). The
   grammar builds each question forwards from its answer; here the answer
   is found backwards from the question, and the engine's answer is put
   back into the equation as well.

   A function of x is held as a sum of terms c x^n e^(rx), each alone or
   times sin(kx) or cos(kx), with c an exact fraction. Different terms are
   independent functions, so two sums are the same function exactly when
   they are the same list. The derivative of a term is found by the product
   rule on its three factors. The engine's answer, a formula (or, for the
   linear trial solution, a polynomial), is brought into this shape by
   multiplying it out; what comes of that must take the engine's own values
   at the sample points.

   Every answer is tried in four ways.

   1. Put back, exactly. The answer goes into the left side read from the
      text, a2 y'' + a1 y' + a0 y, and must give the right side read from
      the text, term for term.
   2. Put back, in floating point, without this file's rules of
      differentiation: the engine's formula is differentiated numerically
      (central differences at h, h/2 and h/4, with Richardson's
      extrapolation taken twice) and the left side less the right side must
      vanish at eight points, to 1e-7 of the size of its terms.
   3. The form. A particular solution must be made of the functions the
      question names and of no other (A e^(kx); A sin(kx) or A cos(kx);
      A x + B; A x e^(rx); A cos(kx) + B sin(kx)). The left side is put
      to each of these functions; the unknown constants are then found
      here by elimination, in fractions, and the elimination must find
      exactly one set of them: this is the promise that there is one
      answer, and the engine's answer must be it. For the resonance
      questions the text also says that no A e^(rx) solves the equation:
      e^(rx) put into the left side must give 0, where the right side is
      not 0.
   4. Initial value problems. The answer must take the printed y(0), and
      for the second order the printed y'(0), exactly, and numerically too
      for the engine's formula. A linear equation with constant
      coefficients and these values has one solution, so a function that
      passes 1 and this is the solution. It is also found again here: the
      roots of the characteristic equation are searched among the whole
      numbers (one for the first order, two different ones for the second,
      as the grammar promises), the particular solution is the one of the
      right side's own form (a constant, or A e^(kx), k not a root), and
      the constants in front of e^(root x) are fitted to the initial
      values by elimination.

   Mistakes. Each is redone from its description as the same working with
   one step done wrongly:

     chain_factor_forgotten      every derivative of e^(kx) is taken to be
                                 e^(kx) itself when A is looked for. In the
                                 first-order problem the constant of the
                                 homogeneous solution is then fitted to
                                 y(0) with that A.
     second_derivative_sign      the second derivative of sin(kx) and of
                                 cos(kx) is taken to be k^2 times the
                                 function; the first derivative is right.
                                 The equation, or the two equations, for
                                 the constants are then solved.
     first_derivative_forgotten  A is found rightly; B is found from the
                                 left side without its y' term.
     constants_before_particular the two constants are fitted to y(0) and
                                 y'(0) with the particular solution left
                                 out, and it is added afterwards.

   The engine must list exactly the mistakes of the question's form, in
   the order they are declared, each described in the words of the header,
   each with one answer of the answer's type that is the function found
   here and is not the right answer. WeBWorK compares a formula at points
   of [-2, 2] to one part in a thousand, so every mistaken answer must be
   more than 1% of the right answer away from it at twelve at least of
   fifteen points of that interval, none of them 0, where the solutions of
   an initial value problem all meet. Twelve is what the worst question of
   the grammar reaches. No answer here is a number times pi or another
   constant, so the rule that such an answer stays below 1000 has nothing
   to bite on; the constants of the answers are pinned below, and the
   largest is 5.

   The working of this file is itself tried first: the fractions, the
   rules of differentiation and the numerical derivatives against each
   other and against derivatives written out by hand, the elimination, the
   roots, eleven questions with their answers and mistaken answers worked
   by hand, questions that must not be askable, texts that must not be
   read, and formulas multiplied out.

   How the answer is written is looked at where every constant of it is
   positive, so that the engine's sum keeps the order it is given: A
   before B; in the first-order problem the particular solution and then
   the homogeneous one; in the second-order problems the lower root, the
   higher root, and then the particular solution.

   Besides the answers: each kind appears at its price alone and spends its
   budget; a budget outside 1..3 gives no question; the budget the grammar
   sets itself is the middle price; the prompt is the question's text;
   there is one answer, a polynomial for the linear trial solution and a
   formula in x alone for every other form, in the Numeric context, which
   knows x; a coefficient 1 and a term 0 are never written. The numbers
   each form is asked with are pinned, none missing and none more: the
   constants of the answer (every pair of A and B, and of C1 and C2), and
   the equations. The equations asked are exactly those of the
   coefficients offered for which the promises of the grammar's comments
   hold as worked out here: there is one solution of the form named (the
   rate of the right side is not a root, or for resonance is a root and
   not a double one; q is not k^2 without damping; q is not 0 for the
   linear form); the mistake of the form can be made (it does not divide
   by 0) and does not give the right answer (so e^x, whose derivatives are
   itself, is never the right side where the chain factor can be
   forgotten, and y' is never missing where it can be left out); with
   damping, the left side makes a sine of a cosine, so that both are
   needed; the roots of a characteristic equation are two different whole
   numbers from those offered. That neither coefficient of the damped
   form's right side is 0 is seen in the text. The ranges of the
   coefficients offered and the words of the descriptions are the only
   things taken from the grammar. The weights are not looked at. *)

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

(* ---- Exact fractions ------------------------------------------------------- *)

(* In lowest terms, the denominator positive: equal numbers are equal
   records. *)
type fraction = { top : int; bottom : int }

let rec common a b = if b = 0 then abs a else common b (a mod b)

let over top bottom =
  if bottom = 0 then failwith "a division by 0";
  let g = if bottom < 0 then -common top bottom else common top bottom in
  { top = top / g; bottom = bottom / g }

let whole n = { top = n; bottom = 1 }
let nothing = whole 0
let plus a b = over ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let times a b = over (a.top * b.top) (a.bottom * b.bottom)
let minus a b = plus a (times (whole (-1)) b)
let divided a b = over (a.top * b.bottom) (a.bottom * b.top)
let to_float a = float a.top /. float a.bottom
let show_fraction a = if a.bottom = 1 then string_of_int a.top else Printf.sprintf "%d/%d" a.top a.bottom

(* ---- Functions of x -------------------------------------------------------- *)

type wave = Flat | Sine of int | Cosine of int

(* x^degree e^(rate x), alone or times sin(k x) or cos(k x) with k > 0. *)
type basis = { degree : int; rate : int; wave : wave }

(* A function: such terms, each with its constant, added. The terms are in
   order, no term comes twice and no constant is 0. *)
type func = (basis * fraction) list

let tidy terms : func =
  let rec merge = function
    | (a, c) :: (b, d) :: rest when a = b -> merge ((a, plus c d) :: rest)
    | (a, c) :: rest -> if c = nothing then merge rest else (a, c) :: merge rest
    | [] -> []
  in
  merge (List.sort (fun (a, _) (b, _) -> compare a b) terms)

let sum_of (parts : func list) = tidy (List.concat parts)
let scaled c (f : func) = tidy (List.map (fun (b, d) -> (b, times c d)) f)
let one_of b : func = [ (b, whole 1) ]
let coefficient_of (f : func) b = match List.assoc_opt b f with Some c -> c | None -> nothing
let unit = { degree = 0; rate = 0; wave = Flat }
let line = { unit with degree = 1 }
let exponential r = { unit with rate = r }
let sine k = { unit with wave = Sine k }
let cosine k = { unit with wave = Cosine k }

let power_of x n =
  let rec go product n = if n = 0 then product else go (product *. x) (n - 1) in
  go 1. n

let value (f : func) x =
  List.fold_left
    (fun total (b, c) ->
      let turning = match b.wave with Flat -> 1. | Sine k -> sin (float k *. x) | Cosine k -> cos (float k *. x) in
      total +. (to_float c *. power_of x b.degree *. exp (float b.rate *. x) *. turning))
    0. f

let show (f : func) =
  if f = [] then "0"
  else
    String.concat " + "
      (List.map
         (fun (b, c) ->
           Printf.sprintf "(%s)%s%s%s" (show_fraction c)
             (if b.degree = 0 then "" else if b.degree = 1 then " x" else Printf.sprintf " x^%d" b.degree)
             (if b.rate = 0 then "" else Printf.sprintf " e^(%dx)" b.rate)
             (match b.wave with Flat -> "" | Sine k -> Printf.sprintf " sin(%dx)" k | Cosine k -> Printf.sprintf " cos(%dx)" k))
         f)

(* The derivative of one term, by the product rule on its three factors. *)
let derived b : func =
  tidy
    ((if b.degree > 0 then [ ({ b with degree = b.degree - 1 }, whole b.degree) ] else [])
    @ [ (b, whole b.rate) ]
    @
    match b.wave with
    | Flat -> []
    | Sine k -> [ ({ b with wave = Cosine k }, whole k) ]
    | Cosine k -> [ ({ b with wave = Sine k }, whole (-k)) ])

let derivative (f : func) = sum_of (List.map (fun (b, c) -> scaled c (derived b)) f)

(* The value at 0: of the factors of a term, only x^n with n > 0 and the
   sine are 0 there, and the others are 1. *)
let at_zero (f : func) =
  List.fold_left
    (fun total (b, c) -> match b with { degree = 0; wave = Flat | Cosine _; _ } -> plus total c | _ -> total)
    nothing f

(* ---- The left side, and how a student differentiates ---------------------- *)

(* second y'' + first y' + plain y *)
type left_side = { second : int; first : int; plain : int }

let order left = if left.second = 0 then 1 else 2

(* The right way, and the two ways of going wrong in a derivative. *)
type working = Sound | Without_chain_factor | Plus_for_second

(* The derivative of order 1 or 2 of one term, as it is found in a working.
   A wrong working is only defined on the functions its mistake speaks of. *)
let derivative_in working n b : func =
  match (working, b) with
  | Sound, _ -> if n = 1 then derived b else derivative (derived b)
  | Without_chain_factor, { degree = 0; wave = Flat; rate } when rate <> 0 -> one_of b
  | Plus_for_second, { degree = 0; rate = 0; wave = Sine k | Cosine k } ->
      if n = 1 then derived b else [ (b, whole (k * k)) ]
  | _ -> failwith "this mistake cannot be made on this function"

(* What the left side makes of a function. *)
let put_in working left (f : func) =
  sum_of
    (List.concat_map
       (fun (b, c) ->
         let part amount g = if amount = 0 then [] else [ scaled (times c (whole amount)) (g ()) ] in
         part left.second (fun () -> derivative_in working 2 b)
         @ part left.first (fun () -> derivative_in working 1 b)
         @ part left.plain (fun () -> one_of b))
       f)

(* ---- Elimination ----------------------------------------------------------- *)

(* The one set of n unknowns that satisfies every equation, each given as
   its n coefficients and its right side. Failure when the equations leave
   an unknown free, or cannot all hold. *)
let eliminate n (equations : (fraction list * fraction) list) =
  let m = Array.of_list (List.map (fun (row, right) -> Array.of_list (row @ [ right ])) equations) in
  let rows = Array.length m in
  for j = 0 to n - 1 do
    let rec find i =
      if i >= rows then failwith "the equations for the constants do not settle them"
      else if m.(i).(j) <> nothing then i
      else find (i + 1)
    in
    let i = find j in
    let lead = m.(i).(j) in
    let pivot = Array.map (fun v -> divided v lead) m.(i) in
    m.(i) <- m.(j);
    m.(j) <- pivot;
    for r = 0 to rows - 1 do
      if r <> j && m.(r).(j) <> nothing then begin
        let factor = m.(r).(j) in
        m.(r) <- Array.mapi (fun c v -> minus v (times factor pivot.(c))) m.(r)
      end
    done
  done;
  for r = n to rows - 1 do
    if m.(r).(n) <> nothing then failwith "the equations for the constants cannot all hold"
  done;
  List.init n (fun j -> m.(j).(n))

(* The constants that make a sum of the given functions equal to the
   target: one equation for each term that appears anywhere. *)
let combination (columns : func list) (target : func) =
  let terms = List.sort_uniq compare (List.map fst (List.concat (target :: columns))) in
  eliminate (List.length columns)
    (List.map (fun b -> (List.map (fun column -> coefficient_of column b) columns, coefficient_of target b)) terms)

(* The solution made of the functions of the trial solution, as it is found
   in a working: the only one, or Failure. *)
let particular working left (right : func) trial : func =
  let constants = combination (List.map (fun b -> put_in working left (one_of b)) trial) right in
  tidy (List.combine trial constants)

(* ---- Initial value problems ------------------------------------------------ *)

let rec range a b = if a > b then [] else a :: range (a + 1) b

(* The whole roots of the characteristic equation, which must be as many as
   its degree. A whole root divides the last coefficient, or is 0 or minus
   the middle one when the last is 0. *)
let roots left =
  let bound = 1 + abs left.first + abs left.plain in
  let found = List.filter (fun r -> (left.second * r * r) + (left.first * r) + left.plain = 0) (range (-bound) bound) in
  if List.length found <> order left then failwith "the characteristic equation does not have as many whole roots as its degree";
  found

(* y(0), and y'(0) for the second order. *)
let at_start n (f : func) = if n = 1 then [ at_zero f ] else [ at_zero f; at_zero (derivative f) ]

(* The constants in front of the given functions that make their sum start
   with the given values. *)
let fitted (own : basis list) (wanted : fraction list) =
  let starts = List.map (fun b -> at_start (List.length wanted) (one_of b)) own in
  eliminate (List.length own) (List.mapi (fun j value -> (List.map (fun start -> List.nth start j) starts, value)) wanted)

(* The solution of an initial value problem. `working` is how the constant
   of the particular solution is found, and `early` says that the constants
   of the homogeneous solution are fitted before the particular solution is
   there. The particular solution has the form of the right side, which is
   one term. *)
let initial ?(working = Sound) ?(early = false) left (right : func) wanted : func =
  let own = List.map exponential (roots left) in
  let trial = match right with [ (b, _) ] -> [ b ] | _ -> failwith "the right side is not one term" in
  let forced = particular working left right trial in
  let left_to_fit = if early then wanted else List.map2 minus wanted (at_start (order left) forced) in
  sum_of [ forced; tidy (List.combine own (fitted own left_to_fit)) ]

(* ---- Numerical derivatives ------------------------------------------------- *)

(* Three estimates with steps h, h/2 and h/4, whose errors are in h^2, h^4
   and so on: the first two powers are taken out. *)
let extrapolated estimate =
  let h = 0.04 in
  let a = estimate h and b = estimate (h /. 2.) and c = estimate (h /. 4.) in
  let ab = ((4. *. b) -. a) /. 3. and bc = ((4. *. c) -. b) /. 3. in
  ((16. *. bc) -. ab) /. 15.

let slope_of f x = extrapolated (fun h -> (f (x +. h) -. f (x -. h)) /. (2. *. h))
let bend_of f x = extrapolated (fun h -> (f (x +. h) -. (2. *. f x) +. f (x -. h)) /. (h *. h))

(* Where an answer is put back in floating point. *)
let trial_points = [ -1.1; -0.83; -0.47; -0.19; 0.23; 0.52; 0.88; 1.07 ]

(* Where a mistaken answer is compared with the right one, and where a
   formula multiplied out is compared with the formula: fifteen points of
   [-2, 2], the interval WeBWorK takes its own points from. None is 0,
   where the solutions of an initial value problem all take the same
   value. *)
let sample_points =
  [ -1.93; -1.64; -1.37; -1.12; -0.85; -0.58; -0.31; -0.12; 0.17; 0.44; 0.71; 0.96; 1.29; 1.58; 1.87 ]

(* At how many of the sample points a mistaken answer is more than 1% of
   the right answer away from it. *)
let points_apart (mistaken : func) (right : func) =
  List.length
    (List.filter
       (fun x -> Float.abs (value mistaken x -. value right x) > 0.01 *. Float.abs (value right x))
       sample_points)

(* The left side less the right side for a function given by its values,
   differentiated numerically, at x; and the size of the terms there. *)
let residual left (right : func) f x =
  let parts =
    [ (if left.second = 0 then 0. else float left.second *. bend_of f x);
      (if left.first = 0 then 0. else float left.first *. slope_of f x);
      float left.plain *. f x;
      -.value right x ]
  in
  (List.fold_left ( +. ) 0. parts, List.fold_left (fun size part -> size +. Float.abs part) 0. parts)

(* ---- Reading the text ------------------------------------------------------ *)

(* The whole of `text` must be the pattern. Its groups are given back, all
   taken at once, before any other pattern is tried: a group that took no
   part in the match is None. *)
let compiled : (string, Str.regexp) Hashtbl.t = Hashtbl.create 32

let pattern re =
  match Hashtbl.find_opt compiled re with
  | Some ready -> ready
  | None ->
      let ready = Str.regexp re in
      Hashtbl.replace compiled re ready;
      ready

let fields re count text =
  if Str.string_match (pattern re) text 0 && Str.match_end () = String.length text then
    Some (Array.init count (fun i -> match Str.matched_group (i + 1) text with s -> Some s | exception Not_found -> None))
  else None

let field groups n = match groups.(n - 1) with Some s -> s | None -> failwith "a part of the text is missing"

(* A whole number written without a sign and without a 0 in front. *)
let number text =
  match fields "0\\|[1-9][0-9]*" 0 text with
  | Some _ -> int_of_string text
  | None -> failwith ("cannot read the number \"" ^ text ^ "\"")

(* A number that stands alone in a sum: 0 is never written. *)
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

let signed sign n = if sign = "-" then -n else n

(* A value of y or y' at 0: a whole number with its sign, and 0 has none. *)
let initial_value text =
  match fields "\\(-?\\)\\([0-9]+\\)" 2 text with
  | Some g ->
      let n = number (field g 2) in
      if n = 0 && field g 1 = "-" then failwith "a 0 with a sign";
      whole (signed (field g 1) n)
  | None -> failwith ("cannot read the initial value \"" ^ text ^ "\"")

(* The parts of a sum written with " + " and " - " between them, each with
   its sign. The first may have a - right in front of it. *)
let summands text =
  let first_sign, text =
    if text <> "" && text.[0] = '-' then (-1, String.sub text 1 (String.length text - 1)) else (1, text)
  in
  match Str.full_split (Str.regexp " [-+] ") text with
  | Str.Text first :: rest ->
      let rec following = function
        | Str.Delim sign :: Str.Text part :: more -> ((if sign = " - " then -1 else 1), part) :: following more
        | [] -> []
        | _ -> failwith "a sign with nothing after it"
      in
      (first_sign, first) :: following rest
  | _ -> failwith "a sum that does not start with a term"

let rate_re = "{\\(-?\\)\\([0-9]*\\)x}"
let wave_re = "\\\\\\(sin\\|cos\\)(\\([0-9]*\\)x)"
let wave_of which k = if which = "sin" then sine (coefficient k) else cosine (coefficient k)

(* One term of a right side, in the shapes these questions print: a number
   alone, k x, k e^{r x}, k \sin(b x) or k \cos(b x). *)
let term_shapes =
  [ ("\\([0-9]+\\)", 1, fun g -> (unit, positive (field g 1)));
    ("\\([0-9]*\\)x", 1, fun g -> (line, coefficient (field g 1)));
    ( "\\([0-9]*\\)e\\^" ^ rate_re,
      3,
      fun g -> (exponential (signed (field g 2) (coefficient (field g 3))), coefficient (field g 1)) );
    ("\\([0-9]*\\)" ^ wave_re, 3, fun g -> (wave_of (field g 2) (field g 3), coefficient (field g 1))) ]

let first_shape shapes what text =
  let rec first = function
    | (re, count, build) :: rest -> ( match fields re count text with Some g -> build g | None -> first rest)
    | [] -> failwith (Printf.sprintf "cannot read the %s \"%s\"" what text)
  in
  first shapes

(* A right side: its terms as they are written, in their order. *)
let right_side text =
  List.map
    (fun (sign, part) ->
      let b, c = first_shape term_shapes "term" part in
      (b, whole (sign * c)))
    (summands text)

(* y'' + p y' + q y with either of the last two terms left out, or
   y' + a y. *)
let left_side text =
  match fields "y''\\( \\([-+]\\) \\([0-9]*\\)y'\\)?\\( \\([-+]\\) \\([0-9]*\\)y\\)?" 6 text with
  | Some g ->
      let part there sign digits =
        match g.(there - 1) with None -> 0 | Some _ -> signed (field g sign) (coefficient (field g digits))
      in
      { second = 1; first = part 1 2 3; plain = part 4 5 6 }
  | None -> (
      match fields "y' \\([-+]\\) \\([0-9]*\\)y" 2 text with
      | Some g -> { second = 0; first = 1; plain = signed (field g 1) (coefficient (field g 2)) }
      | None -> failwith ("cannot read the left side \"" ^ text ^ "\""))

let equation text =
  match fields "\\([^=]*\\) = \\([^=]*\\)" 2 text with
  | Some g -> (left_side (field g 1), right_side (field g 2))
  | None -> failwith ("cannot read the equation \"" ^ text ^ "\"")

(* The functions of a trial solution, in the order of its letters. *)
let form_shapes =
  let rate g = signed (field g 1) (coefficient (field g 2)) in
  [ ("A e\\^" ^ rate_re, 2, fun g -> [ exponential (rate g) ]);
    ("A x e\\^" ^ rate_re, 2, fun g -> [ { (exponential (rate g)) with degree = 1 } ]);
    ("A " ^ wave_re, 2, fun g -> [ wave_of (field g 1) (field g 2) ]);
    ("Ax \\+ B", 0, fun _ -> [ line; unit ]);
    ( "A \\\\cos(\\([0-9]*\\)x) \\+ B \\\\sin(\\([0-9]*\\)x)",
      2,
      fun g -> [ cosine (coefficient (field g 1)); sine (coefficient (field g 2)) ] ) ]

let form text = first_shape form_shapes "form" text

let trial_re =
  "Find the particular solution of the form \\[`y = \\([^`]*\\)`\\] of the differential equation \\[`\\([^`]*\\)`\\]\\."

let resonance_re =
  "The differential equation \\[`\\([^`]*\\)`\\] has no solution of the form \\[`\\([^`]*\\)`\\]\\. Find its particular solution \
   of the form \\[`y = \\([^`]*\\)`\\]\\."

let initial_re =
  "Solve the initial value problem \\[`\\([^`]*\\)`\\], \\[`y(0) = \\([^`]*\\)`\\]\\(, \\[`y'(0) = \\([^`]*\\)`\\]\\)?\\. Give \
   \\[`y`\\] as a function of \\[`x`\\]\\."

(* A question read: a solution of a named form to find (with the form the
   text says does not work, if it names one), or an initial value problem
   with y(0) and, for the second order, y'(0). The right side is kept as it
   is written. *)
type asked =
  | Trial of { left : left_side; written : (basis * fraction) list; trial : basis list; refused : basis list }
  | Initial of { left : left_side; written : (basis * fraction) list; wanted : fraction list }

let read text =
  match fields trial_re 2 text with
  | Some g ->
      let left, written = equation (field g 2) in
      Trial { left; written; trial = form (field g 1); refused = [] }
  | None -> (
      match fields resonance_re 3 text with
      | Some g ->
          let left, written = equation (field g 1) in
          Trial { left; written; trial = form (field g 3); refused = form (field g 2) }
      | None -> (
          match fields initial_re 4 text with
          | Some g ->
              let left, written = equation (field g 1) in
              let slope = match g.(2) with None -> [] | Some _ -> [ initial_value (field g 4) ] in
              if List.length slope <> order left - 1 then failwith "the initial values are not those of the equation's order";
              Initial { left; written; wanted = initial_value (field g 2) :: slope }
          | None -> failwith "the text is not worded as a question on these equations is"))

(* The right side as a function: no term is written twice. *)
let function_written written =
  let f = tidy written in
  if List.length f <> List.length written then failwith "a term of the right side is written twice";
  f

(* ---- What was generated ---------------------------------------------------- *)

(* The numbers of each form, to compare at the end with the values expected:
   none outside them, and none of them missing. *)
let noted : (string * string, string list) Hashtbl.t = Hashtbl.create 64

let note k name value =
  let before = Option.value (Hashtbl.find_opt noted (k, name)) ~default:[] in
  if not (List.mem value before) then Hashtbl.replace noted (k, name) (value :: before)

let tuple numbers = "(" ^ String.concat ", " (List.map string_of_int numbers) ^ ")"

(* Each kind has the equation and the form its header gives it. The numbers
   of the equation are given back, each under its name, to be noted. *)
let of_its_kind k asked =
  let not_so () = failwith "the question is not the one of its kind" in
  match (k, asked) with
  | ( "exponential",
      Trial { left = { second = 1; first; plain }; written = [ (({ degree = 0; wave = Flat; rate } as b), _) ]; trial; refused = [] } )
    when rate <> 0 && trial = [ b ] ->
      [ ("equation", tuple [ first; plain; rate ]) ]
  | ( "undamped",
      Trial
        { left = { second = 1; first = 0; plain };
          written = [ (({ degree = 0; rate = 0; wave = (Sine frequency | Cosine frequency) as wave } as b), _) ];
          trial;
          refused = [] } )
    when trial = [ b ] ->
      [ ("equation", tuple [ plain; frequency ]); ("wave", match wave with Sine _ -> "sine" | _ -> "cosine") ]
  | "linear", Trial { left = { second = 1; first; plain }; written = (b, _) :: rest; trial; refused = [] }
    when b = line && trial = [ line; unit ] && (match rest with [] -> true | [ (b, _) ] -> b = unit | _ -> false) ->
      [ ("equation", tuple [ first; plain ]) ]
  | ( "resonance",
      Trial
        { left = { second = 1; first; plain };
          written = [ (({ degree = 0; wave = Flat; rate } as b), _) ];
          trial = [ with_x ];
          refused = [ without ] } )
    when rate <> 0 && without = b && with_x = { b with degree = 1 } ->
      [ ("equation", tuple [ first; plain; rate ]) ]
  | ( "damped",
      Trial
        { left = { second = 1; first; plain };
          written = [ ({ degree = 0; rate = 0; wave = Cosine frequency }, _); ({ degree = 0; rate = 0; wave = Sine again }, _) ];
          trial;
          refused = [] } )
    when again = frequency && trial = [ cosine frequency; sine frequency ] ->
      [ ("left side", tuple [ first; plain ]); ("frequency", tuple [ frequency ]) ]
  | "first_order", Initial { left = { second = 0; first = 1; plain }; written = [ ({ degree = 0; wave = Flat; rate }, _) ]; wanted = [ _ ] }
    when rate <> 0 ->
      [ ("equation", tuple [ plain; rate ]) ]
  | "initial_constant", Initial { left = { second = 1; first; plain }; written = [ (b, _) ]; wanted = [ _; _ ] } when b = unit ->
      [ ("equation", tuple [ first; plain ]) ]
  | ( "initial_exponential",
      Initial { left = { second = 1; first; plain }; written = [ ({ degree = 0; wave = Flat; rate }, _) ]; wanted = [ _; _ ] } )
    when rate <> 0 ->
      [ ("equation", tuple [ first; plain; rate ]) ]
  | _ -> not_so ()

(* The kinds, their prices and their mistakes in the order of the
   declarations. *)
let kinds =
  [ ("exponential", 1, [ "chain_factor_forgotten" ]); ("undamped", 1, [ "second_derivative_sign" ]);
    ("linear", 2, [ "first_derivative_forgotten" ]); ("resonance", 2, []); ("first_order", 2, [ "chain_factor_forgotten" ]);
    ("damped", 3, [ "second_derivative_sign" ]); ("initial_constant", 3, [ "constants_before_particular" ]);
    ("initial_exponential", 3, [ "constants_before_particular" ]) ]

(* The words of the header for each mistake. *)
let said =
  [ ( "chain_factor_forgotten",
      "differentiates e^(kx) without the factor k, so every derivative of the trial solution is the solution itself" );
    ("second_derivative_sign", "takes the second derivative of sin(kx) or cos(kx) with a plus sign: k^2 where -k^2 belongs");
    ("first_derivative_forgotten", "leaves the y' term out when the constant of the trial solution A x + B is found");
    ( "constants_before_particular",
      "fits the constants of the homogeneous solution to the initial values first and adds the particular solution afterwards" ) ]

(* What a question comes to, worked out here: the answer, and each mistake
   of its kind with the answer it leads to. *)
let work k asked =
  match asked with
  | Trial { left; written; trial; _ } ->
      let right = function_written written in
      let sound = particular Sound left right trial in
      let slips =
        match k with
        | "exponential" -> [ ("chain_factor_forgotten", particular Without_chain_factor left right trial) ]
        | "undamped" | "damped" -> [ ("second_derivative_sign", particular Plus_for_second left right trial) ]
        | "linear" ->
            (* A as it is; B from the equations without the y' term *)
            let without = particular Sound { left with first = 0 } right trial in
            [ ("first_derivative_forgotten", tidy [ (line, coefficient_of sound line); (unit, coefficient_of without unit) ]) ]
        | _ -> []
      in
      (sound, slips)
  | Initial { left; written; wanted } ->
      let right = function_written written in
      let sound = initial left right wanted in
      let slips =
        match k with
        | "first_order" -> [ ("chain_factor_forgotten", initial ~working:Without_chain_factor left right wanted) ]
        | _ -> [ ("constants_before_particular", initial ~early:true left right wanted) ]
      in
      (sound, slips)

(* ---- The engine's answers -------------------------------------------------- *)

let of_number (n : Rhema_number.t) = over n.Rhema_number.numerator n.Rhema_number.denominator

(* The product of two functions, of which at most one has a sine or a
   cosine in any term. *)
let product (f : func) (g : func) =
  tidy
    (List.concat_map
       (fun (a, c) ->
         List.map
           (fun (b, d) ->
             let wave =
               match (a.wave, b.wave) with
               | Flat, wave | wave, Flat -> wave
               | _ -> failwith "a product of two sines or cosines"
             in
             ({ degree = a.degree + b.degree; rate = a.rate + b.rate; wave }, times c d))
           g)
       f)

(* A formula multiplied out. What stands in e^( ), sin( ) and cos( ) must
   be a whole number, not 0, times x. *)
let rec multiplied_out formula : func =
  let inside body =
    match multiplied_out body with
    | [ (b, { top; bottom = 1 }) ] when b = line -> top
    | _ -> failwith "a function of something other than a whole number times x"
  in
  match formula with
  | F.Constant c -> tidy [ (unit, of_number c) ]
  | F.Variable "x" -> one_of line
  | F.Add (a, b) -> sum_of [ multiplied_out a; multiplied_out b ]
  | F.Subtract (a, b) -> sum_of [ multiplied_out a; scaled (whole (-1)) (multiplied_out b) ]
  | F.Negate a -> scaled (whole (-1)) (multiplied_out a)
  | F.Multiply (a, b) -> product (multiplied_out a) (multiplied_out b)
  | F.Exp a -> one_of (exponential (inside a))
  | F.Sin a ->
      let k = inside a in
      if k > 0 then one_of (sine k) else scaled (whole (-1)) (one_of (sine (-k)))
  | F.Cos a -> one_of (cosine (abs (inside a)))
  | _ -> failwith "the formula is not made of numbers, x, e^(kx), sin(kx) and cos(kx) by adding and multiplying"

(* The terms of a formula in the order they are written. *)
let rec terms_written formula =
  match formula with
  | F.Add (a, b) | F.Subtract (a, b) -> terms_written a @ terms_written b
  | F.Negate a -> terms_written a
  | term -> ( match multiplied_out term with [ (b, _) ] -> [ b ] | _ -> failwith "a term of the answer is not one term")

(* An answer of the engine as a function, and as the formula it is. The
   linear trial solution is a polynomial, every other answer a formula in x
   alone; a mistaken answer may be a formula without x. The function must
   take the formula's values. *)
let reading ~mistaken k what answer =
  let f, formula =
    match answer with
    | Rhema_engine.Polynomial p when k = "linear" ->
        if p.Rhema_polynomial.variable <> "x" then failwith (what ^ " is a polynomial in " ^ p.Rhema_polynomial.variable);
        ( tidy (List.mapi (fun degree c -> ({ unit with degree }, of_number c)) p.Rhema_polynomial.coefficients),
          Rhema_polynomial.to_formula p )
    | Rhema_engine.Formula formula when k <> "linear" ->
        let held = F.variables formula in
        if not (held = [ "x" ] || (mistaken && held = [])) then
          failwith (Printf.sprintf "%s is a formula in [%s], not in x alone" what (String.concat ", " held));
        (multiplied_out formula, formula)
    | other -> failwith (Printf.sprintf "%s is not of the type expected: %s" what (Rhema_engine.describe_value other))
  in
  List.iter
    (fun x ->
      let here = value f x and there = F.evaluate ~variable:"x" ~at:x formula in
      if Float.abs (here -. there) > 1e-12 *. (1. +. Float.abs there) then
        failwith (Printf.sprintf "%s, multiplied out, is %.15g at x = %g, and the formula is %.15g" what here x there))
    sample_points;
  (f, formula)

let seen : (string, int) Hashtbl.t = Hashtbl.create 16
let times_seen k = Option.value (Hashtbl.find_opt seen k) ~default:0

(* How many of the fifteen sample points must tell a mistaken answer from
   the right one. Of all the questions of the grammar, the worst has
   twelve: a second-order problem whose right side e^(-3x) is far larger,
   left of 0, than the homogeneous solution the mistake changes. *)
let points_needed = 12

(* One question: Failure says what is wrong with it. *)
let examine k (q : Rhema_engine.question) =
  let only =
    match q.Rhema_engine.answers with
    | [ only ] -> only
    | answers -> failwith (Printf.sprintf "%d answers and not one" (List.length answers))
  in
  if only <> q.Rhema_engine.answer then failwith "the answer is not the one of the only blank";
  let asked = read q.Rhema_engine.prompt in
  List.iter (fun (name, numbers) -> note k name numbers) (of_its_kind k asked);
  let sound, slips = work k asked in
  let _, _, declared = List.find (fun (name, _, _) -> name = k) kinds in
  if List.map fst slips <> declared then failwith "the mistakes worked out are not those of the kind";
  let answer, formula = reading ~mistaken:false k "the answer" only in
  if answer <> sound then failwith (Printf.sprintf "worked out here, the answer is %s, not %s" (show sound) (show answer));
  let left, right =
    match asked with
    | Trial { left; written; _ } | Initial { left; written; _ } -> (left, function_written written)
  in
  (* put back, exactly *)
  let made_of_it = put_in Sound left answer in
  if made_of_it <> right then
    failwith (Printf.sprintf "the left side makes %s of the answer, and the right side is %s" (show made_of_it) (show right));
  (* put back, numerically *)
  let f x = F.evaluate ~variable:"x" ~at:x formula in
  List.iter
    (fun x ->
      let off, size = residual left right f x in
      if not (Float.abs off <= 1e-7 *. size) then
        failwith (Printf.sprintf "differentiated numerically, the answer is off by %g at x = %g, where the terms are of size %g" off x size))
    trial_points;
  (* how the answer is written: where every constant is positive, so that
     the engine's sum keeps the order it is given *)
  let in_order =
    match asked with
    | Trial { trial; _ } -> trial
    | Initial _ -> (
        let own = List.map exponential (roots left) in
        match right with
        | [ (forced, _) ] -> if order left = 1 then forced :: own else own @ [ forced ]
        | _ -> failwith "the right side is not one term")
  in
  if k <> "linear" && List.for_all (fun (_, c) -> c.top > 0) answer && terms_written formula <> in_order then
    failwith "the terms of the answer are not written in the order of the form";
  (match asked with
  | Trial { trial; refused; _ } ->
      (* the form named, and its constants *)
      List.iter (fun (b, _) -> if not (List.mem b trial) then failwith "the answer is not of the form named") answer;
      note k "A" ("(" ^ String.concat ", " (List.map (fun b -> show_fraction (coefficient_of answer b)) trial) ^ ")");
      (* what the text says of the form that does not work *)
      List.iter
        (fun b ->
          if put_in Sound left (one_of b) <> [] || right = [] then
            failwith "the form said to give no solution gives one")
        refused
  | Initial { wanted; _ } ->
      if at_start (order left) answer <> wanted then failwith "the answer does not take the initial values";
      if Float.abs (f 0. -. to_float (List.hd wanted)) > 1e-12 then failwith (Printf.sprintf "y(0) is %.15g" (f 0.));
      (match wanted with
      | [ _; slope ] ->
          if Float.abs (slope_of f 0. -. to_float slope) > 1e-7 *. (1. +. Float.abs (to_float slope)) then
            failwith (Printf.sprintf "differentiated numerically, y'(0) is %.12g" (slope_of f 0.))
      | _ -> ());
      (* the constants: of the particular solution, which has the term of
         the right side, and of the homogeneous solution, lower root first *)
      let forced = match right with [ (b, _) ] -> b | _ -> failwith "the right side is not one term" in
      note k (if forced = unit then "K" else "A") ("(" ^ show_fraction (coefficient_of answer forced) ^ ")");
      let constants = List.map (fun r -> coefficient_of answer (exponential r)) (roots left) in
      note k "C" ("(" ^ String.concat ", " (List.map show_fraction constants) ^ ")"));
  (* the mistakes *)
  List.iter (fun (name, slip) -> if slip = sound then failwith (name ^ " can be made and gives the right answer")) slips;
  let listed = q.Rhema_engine.mistakes in
  let names = List.map (fun (m : Rhema_engine.mistaken) -> m.mistake) listed in
  if names <> declared then
    failwith (Printf.sprintf "the mistakes listed are [%s], not [%s]" (String.concat ", " names) (String.concat ", " declared));
  List.iter
    (fun (m : Rhema_engine.mistaken) ->
      (match List.assoc_opt m.mistake said with
      | Some words -> if m.description <> words then failwith (Printf.sprintf "%s is described as %S" m.mistake m.description)
      | None -> failwith ("a mistake the header does not name: " ^ m.mistake));
      match m.mistaken_answers with
      | Some [ given ] ->
          let mistaken, _ = reading ~mistaken:true k ("the answer of " ^ m.mistake) given in
          let slip = List.assoc m.mistake slips in
          if mistaken <> slip then
            failwith (Printf.sprintf "%s gives %s, and redone here %s" m.mistake (show mistaken) (show slip));
          if mistaken = answer then failwith (m.mistake ^ " gives the right answer");
          let apart = points_apart mistaken answer in
          if apart < points_needed then
            failwith
              (Printf.sprintf "%s gives %s, which is more than 1%% away from the answer at only %d of the %d sample points"
                 m.mistake (show mistaken) apart (List.length sample_points))
      | _ -> failwith (m.mistake ^ " does not give one answer"))
    listed

(* A question that was looked at already, with the same answer and the same
   mistakes, is not worked out again. *)
let examined : (string, unit) Hashtbl.t = Hashtbl.create 4096

let check cost seed (q : Rhema_engine.question) =
  let k = kind q and p = q.Rhema_engine.prompt in
  Hashtbl.replace seen k (times_seen k + 1);
  (match List.find_opt (fun (name, _, _) -> name = k) kinds with
  | Some (_, price, _) -> if price <> cost then fail (Printf.sprintf "%s at cost %d (seed %d)" k cost seed)
  | None -> fail (Printf.sprintf "a kind the header does not list: %s" k));
  if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
  (match Rhema_engine.attribute q.Rhema_engine.tree "text" with
  | Rhema_engine.Text t when t = p -> ()
  | _ -> fail (Printf.sprintf "%s: the prompt is not the text of the question, for %S" k p));
  if q.Rhema_engine.variables <> [] then
    fail (Printf.sprintf "%s: the blank is given the variables [%s]" k (String.concat ", " q.Rhema_engine.variables));
  if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s, not Numeric" k q.Rhema_engine.context);
  let whole_question = String.concat "\n" (k :: p :: q.Rhema_engine.answer_text :: Rhema_engine.describe_mistakes q) in
  if not (Hashtbl.mem examined whole_question) then begin
    Hashtbl.replace examined whole_question ();
    let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
    if not (List.exists (fun (name, _, _) -> name = k) kinds) then wrong "a kind that is not looked at"
    else try examine k q with Failure m -> wrong m | e -> wrong (Printexc.to_string e)
  end

(* ---- The questions expected ---------------------------------------------- *)

let not_zero a b = List.filter (fun n -> n <> 0) (range a b)
let holds trial = match trial () with held -> held | exception Failure _ -> false

(* A question can be asked when it can be worked out here and each mistake
   of its kind can be made on it and does not give the right answer. *)
let can_be_asked k asked =
  holds (fun () ->
      let sound, slips = work k asked in
      List.for_all (fun (_, slip) -> slip <> sound) slips)

(* The values each form's numbers take, all of which must appear. The
   coefficients offered are taken from the grammar: p and q of the left
   side from -5 to 5; rates of exponentials, and roots of a characteristic
   equation, from -3 to 3 and not 0; the frequency of a sine from 1 to 4
   alone and from 1 to 3 with damping; q from -9 to 9 and not 0 where
   there is no y'. Which of them make a question is worked out here, on a
   right side with 1 for each constant. *)
let allowed =
  let offered = range (-5) 5 and rates = not_zero (-3) 3 in
  let ( let* ) list f = List.concat_map f list in
  let one term = (term, whole 1) in
  let trial left written trial = Trial { left; written; trial; refused = [] } in
  (* left sides whose characteristic equation has two different roots among
     the rates: found by trying every left side they could have *)
  let rooted =
    let* first = range (-6) 6 in
    let* plain = range (-9) 9 in
    let left = { second = 1; first; plain } in
    if holds (fun () -> List.for_all (fun root -> List.mem root rates) (roots left)) then [ left ] else []
  in
  let tuples = List.map (fun numbers -> "(" ^ String.concat ", " (List.map string_of_int numbers) ^ ")") in
  let rec all_of = function
    | [] -> [ [] ]
    | choices :: rest ->
        let* first = choices in
        List.map (fun others -> first :: others) (all_of rest)
  in
  let small = not_zero (-4) 4 and smaller = not_zero (-3) 3 in
  [ ( "exponential",
      [ ( "equation",
          tuples
            (let* first = offered in
             let* plain = offered in
             let* rate = rates in
             let b = exponential rate in
             if can_be_asked "exponential" (trial { second = 1; first; plain } [ one b ] [ b ]) then [ [ first; plain; rate ] ]
             else []) );
        ("A", tuples (all_of [ small ])) ] );
    ( "undamped",
      [ ( "equation",
          tuples
            (let* plain = not_zero (-9) 9 in
             let* frequency = range 1 4 in
             let b = sine frequency in
             if can_be_asked "undamped" (trial { second = 1; first = 0; plain } [ one b ] [ b ]) then [ [ plain; frequency ] ]
             else []) );
        ("wave", [ "sine"; "cosine" ]);
        ("A", tuples (all_of [ small ])) ] );
    ( "linear",
      [ ( "equation",
          tuples
            (let* first = offered in
             let* plain = offered in
             if can_be_asked "linear" (trial { second = 1; first; plain } [ one line ] [ line; unit ]) then [ [ first; plain ] ]
             else []) );
        ("A", tuples (all_of [ small; range (-5) 5 ])) ] );
    ( "resonance",
      [ ( "equation",
          tuples
            (let* left = rooted in
             let* rate = rates in
             let b = exponential rate in
             if
               put_in Sound left (one_of b) = []
               && can_be_asked "resonance" (Trial { left; written = [ one b ]; trial = [ { b with degree = 1 } ]; refused = [ b ] })
             then [ [ left.first; left.plain; rate ] ]
             else []) );
        ("A", tuples (all_of [ small ])) ] );
    ( "first_order",
      [ ( "equation",
          tuples
            (let* root = rates in
             let* rate = rates in
             let left = { second = 0; first = 1; plain = -root } in
             if can_be_asked "first_order" (Initial { left; written = [ one (exponential rate) ]; wanted = [ nothing ] }) then
               [ [ -root; rate ] ]
             else []) );
        ("A", tuples (all_of [ small ]));
        ("C", tuples (all_of [ small ])) ] );
    ( "damped",
      [ ( "left side",
          tuples
            (let* first = offered in
             let* plain = offered in
             let left = { second = 1; first; plain } in
             (* both functions are needed: the left side makes a sine of a
                cosine. This does not depend on the frequency. *)
             if
               coefficient_of (put_in Sound left (one_of (cosine 1))) (sine 1) <> nothing
               && List.for_all
                    (fun k -> can_be_asked "damped" (trial left [ one (cosine k); one (sine k) ] [ cosine k; sine k ]))
                    (range 1 3)
             then [ [ first; plain ] ]
             else []) );
        ("frequency", tuples (all_of [ range 1 3 ]));
        ("A", tuples (all_of [ smaller; smaller ])) ] );
    ( "initial_constant",
      [ ( "equation",
          tuples
            (let* left = rooted in
             if can_be_asked "initial_constant" (Initial { left; written = [ one unit ]; wanted = [ nothing; nothing ] }) then
               [ [ left.first; left.plain ] ]
             else []) );
        ("K", tuples (all_of [ not_zero (-5) 5 ]));
        ("C", tuples (all_of [ small; small ])) ] );
    ( "initial_exponential",
      [ ( "equation",
          tuples
            (let* left = rooted in
             let* rate = rates in
             if
               can_be_asked "initial_exponential"
                 (Initial { left; written = [ one (exponential rate) ]; wanted = [ nothing; nothing ] })
             then [ [ left.first; left.plain; rate ] ]
             else []) );
        ("A", tuples (all_of [ smaller ]));
        ("C", tuples (all_of [ smaller; smaller ])) ] ) ]

(* ---- The working of this file, tried on its own --------------------------- *)

let trial_text form body =
  "Find the particular solution of the form [`y = " ^ form ^ "`] of the differential equation [`" ^ body ^ "`]."

let resonance_text body refused form =
  "The differential equation [`" ^ body ^ "`] has no solution of the form [`" ^ refused
  ^ "`]. Find its particular solution of the form [`y = " ^ form ^ "`]."

let initial_text body values =
  "Solve the initial value problem [`" ^ body ^ "`]"
  ^ String.concat "" (List.map (fun value -> ", [`" ^ value ^ "`]") values)
  ^ ". Give [`y`] as a function of [`x`]."

let check_own_working () =
  let own what = fail ("own working: " ^ what) in
  let fails trial = match trial () with exception Failure _ -> true | _ -> false in
  (* a function written by hand: each term with the two parts of its constant *)
  let fn terms : func = tidy (List.map (fun (b, top, bottom) -> (b, over top bottom)) terms) in
  (* fractions *)
  if over 6 (-4) <> { top = -3; bottom = 2 } then own "6 / -4";
  if plus (over 1 2) (over 1 3) <> over 5 6 then own "1/2 + 1/3";
  if minus (over 1 2) (over 2 4) <> nothing then own "1/2 - 2/4";
  if times (over 2 3) (over (-3) 4) <> over (-1) 2 then own "2/3 times -3/4";
  if divided (over 2 3) (over (-4) 9) <> over (-3) 2 then own "2/3 divided by -4/9";
  if not (fails (fun () -> divided (whole 1) nothing)) then own "1 / 0 is a number";
  (* the rules of differentiation, on derivatives written out by hand *)
  let x_e2 = { degree = 1; rate = 2; wave = Flat } in
  let mixed n wave = { degree = n; rate = -1; wave } in
  List.iter
    (fun (name, found, wanted) ->
      if found <> wanted then own (Printf.sprintf "%s is found to be %s, not %s" name (show found) (show wanted)))
    [ ("(x e^(2x))'", derivative (one_of x_e2), fn [ (exponential 2, 1, 1); (x_e2, 2, 1) ]);
      ("(x e^(2x))''", derivative (derivative (one_of x_e2)), fn [ (exponential 2, 4, 1); (x_e2, 4, 1) ]);
      ("(sin 3x)'", derivative (one_of (sine 3)), fn [ (cosine 3, 3, 1) ]);
      ("(cos 3x)'", derivative (one_of (cosine 3)), fn [ (sine 3, -3, 1) ]);
      ("(cos 3x)''", derivative (derivative (one_of (cosine 3))), fn [ (cosine 3, -9, 1) ]);
      ("5'", derivative (fn [ (unit, 5, 1) ]), []);
      ("(x / 2)'", derivative (fn [ (line, 1, 2) ]), fn [ (unit, 1, 2) ]);
      ("x''", derivative (derivative (one_of line)), []);
      ( "(x^2 e^(-x) cos 2x)'",
        derivative (one_of (mixed 2 (Cosine 2))),
        fn [ (mixed 1 (Cosine 2), 2, 1); (mixed 2 (Cosine 2), -1, 1); (mixed 2 (Sine 2), -2, 1) ] );
      ("a sum with the same term twice", tidy [ (line, whole 2); (unit, whole 1); (line, whole (-2)) ], fn [ (unit, 1, 1) ]);
      (* the left side, on functions put in by hand *)
      ( "x e^(2x) in y'' - y' - 2y",
        put_in Sound { second = 1; first = -1; plain = -2 } (one_of x_e2),
        fn [ (exponential 2, 3, 1) ] );
      ("e^(2x) in y'' - y' - 2y", put_in Sound { second = 1; first = -1; plain = -2 } (one_of (exponential 2)), []);
      ( "3 cos x + 2 sin x in y'' + y' + y",
        put_in Sound { second = 1; first = 1; plain = 1 } (fn [ (cosine 1, 3, 1); (sine 1, 2, 1) ]),
        fn [ (cosine 1, 2, 1); (sine 1, -3, 1) ] );
      ("e^(3x) in y' + 2y", put_in Sound { second = 0; first = 1; plain = 2 } (one_of (exponential 3)), fn [ (exponential 3, 5, 1) ]);
      (* the two wrong ways of differentiating *)
      ("(e^(3x))'' without its factor", derivative_in Without_chain_factor 2 (exponential 3), one_of (exponential 3));
      ("(e^(3x))' without its factor", derivative_in Without_chain_factor 1 (exponential 3), one_of (exponential 3));
      ("(sin 2x)'' with a plus", derivative_in Plus_for_second 2 (sine 2), fn [ (sine 2, 4, 1) ]);
      ("(cos 2x)'' with a plus", derivative_in Plus_for_second 2 (cosine 2), fn [ (cosine 2, 4, 1) ]);
      ("(cos 2x)' in that working", derivative_in Plus_for_second 1 (cosine 2), fn [ (sine 2, -2, 1) ]) ];
  if not (fails (fun () -> derivative_in Without_chain_factor 1 (sine 2))) then
    own "a sine is differentiated without the factor of e^(kx)";
  if not (fails (fun () -> derivative_in Without_chain_factor 1 x_e2)) then
    own "x e^(2x) is differentiated without the factor of e^(kx)";
  if not (fails (fun () -> derivative_in Plus_for_second 2 (exponential 2))) then
    own "e^(2x) is differentiated with the sign of a sine";
  if at_zero (fn [ (unit, 3, 1); (line, 2, 1); (exponential 1, 4, 1); (cosine 2, -1, 1); (sine 1, 7, 1); (x_e2, 5, 1) ]) <> whole 6
  then own "the value at 0";
  (* the numerical derivatives, on functions whose derivatives are known,
     and against the rules above *)
  let near found wanted size = Float.abs (found -. wanted) <= 1e-9 *. size in
  List.iter
    (fun x ->
      if not (near (slope_of exp x) (exp x) (exp x)) then own (Printf.sprintf "the slope of e^x at %g" x);
      if not (near (bend_of (fun x -> sin (4. *. x)) x) (-16. *. sin (4. *. x)) 16.) then
        own (Printf.sprintf "the second derivative of sin 4x at %g" x);
      if not (near (bend_of (fun x -> x *. x *. x) x) (6. *. x) 6.) then own (Printf.sprintf "the second derivative of x^3 at %g" x);
      List.iter
        (fun g ->
          let once = derivative g in
          let twice = derivative once in
          let size = 1. +. Float.abs (value g x) +. Float.abs (value once x) +. Float.abs (value twice x) in
          if not (near (slope_of (value g) x) (value once x) size && near (bend_of (value g) x) (value twice x) size) then
            own (Printf.sprintf "the rules and the numerical derivatives of %s do not agree at %g" (show g) x))
        [ one_of (exponential 3); one_of (exponential (-3)); one_of (sine 4); one_of x_e2; one_of (mixed 2 (Cosine 2));
          fn [ (cosine 3, 2, 1); (sine 3, -3, 1) ]; fn [ (exponential (-3), 4, 1); (exponential 3, -2, 1); (unit, 5, 1) ];
          fn [ (line, 3, 1); (unit, -32, 5) ] ])
    (0. :: trial_points);
  (* elimination *)
  let numbers = List.map whole in
  if eliminate 2 [ (numbers [ 1; 1 ], whole 3); (numbers [ 1; -1 ], whole 1) ] <> numbers [ 2; 1 ] then own "two equations";
  if eliminate 2 [ (numbers [ 0; 2 ], whole 4); (numbers [ 3; 1 ], whole 5) ] <> numbers [ 1; 2 ] then
    own "two equations, the first without the first unknown";
  if eliminate 2 [ (numbers [ 2; 1 ], whole 2); (numbers [ -1; 2 ], whole (-3)) ] <> [ over 7 5; over (-4) 5 ] then
    own "two equations with fractions for answers";
  if eliminate 1 [ (numbers [ 0 ], nothing); (numbers [ 4 ], whole 2); (numbers [ 2 ], whole 1) ] <> [ over 1 2 ] then
    own "three equations that agree";
  if not (fails (fun () -> eliminate 1 [ (numbers [ 4 ], whole 2); (numbers [ 2 ], whole 2) ])) then own "two equations that disagree";
  if not (fails (fun () -> eliminate 1 [ (numbers [ 0 ], whole 2) ])) then own "0 A = 2 is solved";
  if not (fails (fun () -> eliminate 1 [ (numbers [ 0 ], nothing) ])) then own "0 A = 0 settles A";
  if not (fails (fun () -> eliminate 2 [ (numbers [ 1; 1 ], whole 2); (numbers [ 2; 2 ], whole 4) ])) then
    own "one equation written twice settles two unknowns";
  if not (fails (fun () -> eliminate 2 [ (numbers [ 1; 1 ], whole 2) ])) then own "one equation settles two unknowns";
  (* the roots of characteristic equations *)
  List.iter
    (fun (second, first, plain, wanted) ->
      let found = match roots { second; first; plain } with found -> Some found | exception Failure _ -> None in
      if found <> wanted then own (Printf.sprintf "the roots of %d r^2 + %d r + %d" second first plain))
    [ (1, -3, 2, Some [ 1; 2 ]); (1, 0, -9, Some [ -3; 3 ]); (0, 1, 3, Some [ -3 ]); (1, 1, 0, Some [ -1; 0 ]);
      (1, 5, 6, Some [ -3; -2 ]); (1, -2, 1, None); (1, 0, 1, None); (1, 0, -2, None); (1, 1, 1, None) ];
  (* whole questions, with the answers and the mistaken answers worked out
     by hand *)
  List.iter
    (fun (k, text, answer, slips) ->
      match
        let asked = read text in
        ignore (of_its_kind k asked);
        work k asked
      with
      | exception Failure m -> own (Printf.sprintf "%s is not worked out: %s" text m)
      | sound, found ->
          if sound <> answer then own (Printf.sprintf "the answer of %s is found to be %s" text (show sound));
          if List.map snd found <> slips then
            own
              (Printf.sprintf "the mistaken answers of %s are found to be %s" text
                 (String.concat " and " (List.map (fun (_, f) -> show f) found))))
    [ (* 9 - 3 + 2 = 8; without the factors 1 - 1 + 2 = 2 *)
      ( "exponential",
        trial_text "A e^{3x}" "y'' - y' + 2y = 8e^{3x}",
        fn [ (exponential 3, 1, 1) ],
        [ fn [ (exponential 3, 4, 1) ] ] );
      (* 1 + 2 = 3; without the factors 1 - 2 = -1 *)
      ( "exponential",
        trial_text "A e^{-x}" "y'' - 2y' = -3e^{-x}",
        fn [ (exponential (-1), -1, 1) ],
        [ fn [ (exponential (-1), 3, 1) ] ] );
      (* (3 - 1) A = -8; with the plus (3 + 1) A = -8 *)
      ("undamped", trial_text {|A \sin(x)|} {|y'' + 3y = -8\sin(x)|}, fn [ (sine 1, -4, 1) ], [ fn [ (sine 1, -2, 1) ] ]);
      (* (-1 - 4) A = 10; with the plus (-1 + 4) A = 10 *)
      ("undamped", trial_text {|A \cos(2x)|} {|y'' - y = 10\cos(2x)|}, fn [ (cosine 2, -2, 1) ], [ fn [ (cosine 2, 10, 3) ] ]);
      (* 5 A = 15 and -4 A + 5 B = -32; without y', 5 B = -32 *)
      ( "linear",
        trial_text "Ax + B" "y'' - 4y' + 5y = 15x - 32",
        fn [ (line, 3, 1); (unit, -4, 1) ],
        [ fn [ (line, 3, 1); (unit, -32, 5) ] ] );
      (* -A = -1 and 2 A - B = 0; without y', -B = 0 *)
      ("linear", trial_text "Ax + B" "y'' + 2y' - y = -x", fn [ (line, 1, 1); (unit, 2, 1) ], [ fn [ (line, 1, 1) ] ]);
      (* worked above: x e^(2x) gives 3 e^(2x) *)
      ("resonance", resonance_text "y'' - y' - 2y = 3e^{2x}" "A e^{2x}" "A x e^{2x}", fn [ (x_e2, 1, 1) ], []);
      (* (3 - 2) A = 2 and A + C = -1; without the factor (1 - 2) A = 2 *)
      ( "first_order",
        initial_text "y' - 2y = 2e^{3x}" [ "y(0) = -1" ],
        fn [ (exponential 3, 2, 1); (exponential 2, -3, 1) ],
        [ fn [ (exponential 3, -2, 1); (exponential 2, 1, 1) ] ] );
      (* worked above: 3 cos x + 2 sin x gives 2 cos x - 3 sin x; with the
         plus, 2 A + B = 2 and 2 B - A = -3 *)
      ( "damped",
        trial_text {|A \cos(x) + B \sin(x)|} {|y'' + y' + y = 2\cos(x) - 3\sin(x)|},
        fn [ (cosine 1, 3, 1); (sine 1, 2, 1) ],
        [ fn [ (cosine 1, 7, 5); (sine 1, -4, 5) ] ] );
      (* roots 1 and 2, K = 4; C1 + C2 = 2 and C1 + 2 C2 = 1; fitted early,
         C1 + C2 = 6 and C1 + 2 C2 = 1 *)
      ( "initial_constant",
        initial_text "y'' - 3y' + 2y = 8" [ "y(0) = 6"; "y'(0) = 1" ],
        fn [ (exponential 1, 3, 1); (exponential 2, -1, 1); (unit, 4, 1) ],
        [ fn [ (exponential 1, 11, 1); (exponential 2, -5, 1); (unit, 4, 1) ] ] );
      (* roots -1 and 1, (4 - 1) A = 3; C1 + C2 = 3 and -C1 + C2 = 1;
         fitted early, C1 + C2 = 4 and -C1 + C2 = 3 *)
      ( "initial_exponential",
        initial_text "y'' - y = 3e^{2x}" [ "y(0) = 4"; "y'(0) = 3" ],
        fn [ (exponential (-1), 1, 1); (exponential 1, 2, 1); (exponential 2, 1, 1) ],
        [ fn [ (exponential (-1), 1, 2); (exponential 1, 7, 2); (exponential 2, 1, 1) ] ] ) ];
  (* questions that have no answer, or more than one, and questions on
     which the mistake of the kind cannot be made or does not show: these
     cannot be asked *)
  let trial left written trial = Trial { left; written; trial; refused = [] } in
  let second_order first plain = { second = 1; first; plain } and first_order plain = { second = 0; first = 1; plain } in
  let one b = (b, whole 1) in
  let e = exponential in
  let from_rest = [ nothing; nothing ] in
  List.iter
    (fun (name, k, asked, wanted) ->
      if can_be_asked k asked <> wanted then own (name ^ if wanted then " cannot be asked" else " can be asked"))
    [ ("y'' - y' + 2y = e^(3x)", "exponential", trial (second_order (-1) 2) [ one (e 3) ] [ e 3 ], true);
      ("y'' - 3y' + 2y = e^(2x), where 2 is a root", "exponential", trial (second_order (-3) 2) [ one (e 2) ] [ e 2 ], false);
      ("y'' + 2y' + 3y = e^x, whose derivatives are e^x", "exponential", trial (second_order 2 3) [ one (e 1) ] [ e 1 ], false);
      ( "y'' + 3y = e^(-x), where the missing factors do not show",
        "exponential",
        trial (second_order 0 3) [ one (e (-1)) ] [ e (-1) ],
        false );
      ( "y'' + y' - 2y = e^(3x), where the mistake divides by 0",
        "exponential",
        trial (second_order 1 (-2)) [ one (e 3) ] [ e 3 ],
        false );
      ("y'' + 4y = sin 2x", "undamped", trial (second_order 0 4) [ one (sine 2) ] [ sine 2 ], false);
      ("y'' - 4y = sin 2x", "undamped", trial (second_order 0 (-4)) [ one (sine 2) ] [ sine 2 ], false);
      ("y'' - 4y = sin x", "undamped", trial (second_order 0 (-4)) [ one (sine 1) ] [ sine 1 ], true);
      ("y'' + 2y = x, without y'", "linear", trial (second_order 0 2) [ one line ] [ line; unit ], false);
      ("y'' + 2y' = x, without y", "linear", trial (second_order 2 0) [ one line ] [ line; unit ], false);
      ("y'' + 2y' + y = x", "linear", trial (second_order 2 1) [ one line ] [ line; unit ], true);
      ( "y'' - 2y' + y = e^x by A x e^x, 1 a double root",
        "resonance",
        Trial { left = second_order (-2) 1; written = [ one (e 1) ]; trial = [ { (e 1) with degree = 1 } ]; refused = [ e 1 ] },
        false );
      ( "y' - y = e^(2x), where the mistake divides by 0",
        "first_order",
        Initial { left = first_order (-1); written = [ one (e 2) ]; wanted = [ nothing ] },
        false );
      ("y' + 2y = e^(-2x)", "first_order", Initial { left = first_order 2; written = [ one (e (-2)) ]; wanted = [ nothing ] }, false);
      ("y' + 2y = e^x", "first_order", Initial { left = first_order 2; written = [ one (e 1) ]; wanted = [ nothing ] }, false);
      ("y' + 2y = e^(3x)", "first_order", Initial { left = first_order 2; written = [ one (e 3) ]; wanted = [ nothing ] }, true);
      ( "y'' + y = 1, with no real root",
        "initial_constant",
        Initial { left = second_order 0 1; written = [ one unit ]; wanted = from_rest },
        false );
      ( "y'' - y' = 1, with the root 0",
        "initial_constant",
        Initial { left = second_order (-1) 0; written = [ one unit ]; wanted = from_rest },
        false );
      ( "y'' - 2y' + y = 1, with a double root",
        "initial_constant",
        Initial { left = second_order (-2) 1; written = [ one unit ]; wanted = from_rest },
        false );
      ( "y'' - y = e^x, where 1 is a root",
        "initial_exponential",
        Initial { left = second_order 0 (-1); written = [ one (e 1) ]; wanted = from_rest },
        false ) ];
  (* texts that are not read at all *)
  List.iter
    (fun text -> if not (fails (fun () -> read text)) then own (Printf.sprintf "%s is read" text))
    (List.map (trial_text "A e^{2x}")
       [ "y'' + 1y' + 2y = 3e^{2x}"; "y'' + 0y = 3e^{2x}"; "y'' + 2y = 0e^{2x}"; "y'' + 2y = 1e^{2x}"; "y'' + 2y = 03e^{2x}";
         "y'' + 2y = e^{1x}"; "y'' + 2y = e^{0x}"; "y'' + 2y = e^{-1x}"; "y'' + 2y = 3e^{2t}"; "y'' + 2y = +3e^{2x}";
         "y'' + 2y = - 3e^{2x}"; "y'' + -2y = 3e^{2x}"; "y'' +2y = 3e^{2x}"; "2y'' + y = e^{2x}"; "y''' + y = e^{2x}";
         "y'' + y + 2y' = e^{2x}"; "y'' + 2y' + 3 = e^{2x}"; "y'' + 2y"; "y'' + 2y = 3 = 3"; "y'' + 2y = "; "y'' + 2y =  3";
         {|y'' + 2y = \sin(1x)|}; {|y'' + 2y = \sin(0x)|}; {|y'' + 2y = \tan(x)|}; {|y'' + 2y = \sin(-x)|}; {|y'' + 2y = \sin x|};
         "y'' + 2y = 3x + 0"; "y'' + 2y = 1x"; "y'' + 2y = 3x + "; "y'' + 2y = x^{2}"; "y'' + 2y = 3e^{2x} "; "y + y'' = 3" ]
    @ List.map
        (fun form -> trial_text form "y'' + 2y = 3")
        [ "A e^{1x}"; "B e^{x}"; "Ae^{x}"; "A e^{x} + B"; {|A\sin(x)|}; "Ax+B"; "A x + B"; {|A \sin(x) + B \cos(x)|};
          {|A \cos(1x) + B \sin(x)|}; "A x e^{0x}"; "A x^{2} e^{x}"; "A" ]
    @ [ resonance_text "y'' - y = 2e^{x}" "y = A e^{x}" "A x e^{x}";
        resonance_text "y'' - y = 2e^{x}" "A e^{x}" "y = A x e^{x}";
        initial_text "y' + 2y = 3e^{x}" [ "y(0) = -0" ];
        initial_text "y' + 2y = 3e^{x}" [ "y(0) = 1.5" ];
        initial_text "y' + 2y = 3e^{x}" [ "y(0) = 01" ];
        initial_text "y' + 2y = 3e^{x}" [ "y(0) = +1" ];
        initial_text "y' + 2y = 3e^{x}" [ "y(1) = 1" ];
        initial_text "y' + 2y = 3e^{x}" [];
        initial_text "y' + 2y = 3e^{x}" [ "y(0) = 1"; "y'(0) = 1" ];
        initial_text "y'' + 2y = 3e^{x}" [ "y(0) = 1" ];
        initial_text "y'' + 2y = 3e^{x}" [ "y'(0) = 1"; "y(0) = 1" ];
        initial_text "y'' + 2y = 3e^{x}" [ "y(0) = 1"; "y'(0) = 1"; "y'(0) = 1" ];
        "Find the particular solution of the form [`y = Ax + B`] of the differential equation [`y'' + 2y = 3`]";
        "Find a particular solution of the form [`y = Ax + B`] of the differential equation [`y'' + 2y = 3`].";
        "Find the particular solution of the form [`Ax + B`] of the differential equation [`y'' + 2y = 3`].";
        " " ^ trial_text "Ax + B" "y'' + 2y = 3";
        trial_text "Ax + B" "y'' + 2y = 3" ^ " " ]);
  (* texts that are read, and are not the question of their kind *)
  List.iter
    (fun (k, text) ->
      match read text with
      | exception Failure m -> own (Printf.sprintf "%s is not read: %s" text m)
      | asked ->
          if not (fails (fun () -> of_its_kind k asked)) then own (Printf.sprintf "%s is taken for a question of the kind %s" text k))
    [ ("exponential", trial_text "A e^{2x}" "y'' + 2y = 3e^{3x}");
      ("exponential", trial_text "A x e^{2x}" "y'' + 2y = 3e^{2x}");
      ("exponential", trial_text "A e^{2x}" "y'' + 2y = 3e^{2x} + 1");
      ("exponential", trial_text "A e^{2x}" "y' + 2y = 3e^{2x}");
      ("undamped", trial_text {|A \sin(2x)|} {|y'' + 2y = 3\cos(2x)|});
      ("undamped", trial_text {|A \sin(2x)|} {|y'' + 2y = 3\sin(3x)|});
      ("undamped", trial_text {|A \sin(2x)|} {|y'' + y' + 2y = 3\sin(2x)|});
      ("linear", trial_text "Ax + B" "y'' + y' + 2y = 3");
      ("linear", trial_text "Ax + B" "y'' + y' + 2y = 3 + 2x");
      ("linear", trial_text "Ax + B" "y'' + y' + 2y = 2x + 3x");
      ("linear", trial_text "A e^{x}" "y'' + y' + 2y = 2x + 3");
      ("resonance", resonance_text "y'' - y = 2e^{x}" "A e^{-x}" "A x e^{x}");
      ("resonance", resonance_text "y'' - y = 2e^{x}" "A e^{x}" "A x e^{-x}");
      ("resonance", resonance_text "y'' - y = 2e^{x}" "A e^{x}" "A e^{x}");
      ("resonance", trial_text "A x e^{x}" "y'' - y = 2e^{x}");
      ("damped", trial_text {|A \cos(2x) + B \sin(2x)|} {|y'' + y' + 2y = 3\sin(2x) + \cos(2x)|});
      ("damped", trial_text {|A \cos(2x) + B \sin(2x)|} {|y'' + y' + 2y = 3\cos(2x)|});
      ("damped", trial_text {|A \cos(2x) + B \sin(3x)|} {|y'' + y' + 2y = 3\cos(2x) + \sin(2x)|});
      ("damped", trial_text {|A \cos(2x) + B \sin(2x)|} {|y'' + y' + 2y = 3\cos(2x) + \sin(3x)|});
      ("first_order", initial_text "y' + 2y = 3" [ "y(0) = 1" ]);
      ("first_order", initial_text "y'' + 2y = 3e^{x}" [ "y(0) = 1"; "y'(0) = 2" ]);
      ("initial_constant", initial_text "y'' + 2y = 3e^{x}" [ "y(0) = 1"; "y'(0) = 2" ]);
      ("initial_constant", initial_text "y'' + 2y = 3x" [ "y(0) = 1"; "y'(0) = 2" ]);
      ("initial_exponential", initial_text "y'' + 2y = 3" [ "y(0) = 1"; "y'(0) = 2" ]);
      ("initial_exponential", initial_text "y' + 2y = 3e^{x}" [ "y(0) = 1" ]);
      ("a kind there is not", trial_text "Ax + B" "y'' + y' + 2y = 2x + 3") ];
  (* formulas multiplied out *)
  let x = F.variable "x" and n k = F.constant (Rhema_number.of_int k) in
  let part top bottom = F.constant (Rhema_number.make top bottom) in
  List.iter
    (fun (name, formula, wanted) ->
      match multiplied_out formula with
      | exception Failure m -> own (Printf.sprintf "%s is not multiplied out: %s" name m)
      | found -> if found <> wanted then own (Printf.sprintf "%s multiplied out is %s" name (show found)))
    [ ( "2 e^(3x) - 3 x e^(-x)",
        F.Subtract (F.Multiply (n 2, F.Exp (F.Multiply (n 3, x))), F.Multiply (F.Multiply (n 3, x), F.Exp (F.Negate x))),
        fn [ (exponential 3, 2, 1); ({ degree = 1; rate = -1; wave = Flat }, -3, 1) ] );
      ( "7/5 cos x - 4/5 sin 2x",
        F.subtract (F.multiply (part 7 5) (F.cos x)) (F.multiply (part 4 5) (F.sin (F.multiply (n 2) x))),
        fn [ (cosine 1, 7, 5); (sine 2, -4, 5) ] );
      ("-(1 + x)", F.Negate (F.Add (n 1, x)), fn [ (unit, -1, 1); (line, -1, 1) ]);
      ("sin(-x)", F.Sin (F.Negate x), fn [ (sine 1, -1, 1) ]);
      ("cos(-(2x))", F.Cos (F.Negate (F.Multiply (n 2, x))), fn [ (cosine 2, 1, 1) ]);
      ( "e^x e^(2x) x",
        F.Multiply (F.Multiply (F.Exp x, F.Exp (F.Multiply (n 2, x))), x),
        fn [ ({ degree = 1; rate = 3; wave = Flat }, 1, 1) ] );
      ("e^x - e^x", F.Subtract (F.Exp x, F.Exp x), []);
      ( "2 e^(-3x) sin(2x)",
        F.Multiply (F.Multiply (n 2, F.Exp (F.Multiply (n (-3), x))), F.Sin (F.Multiply (x, n 2))),
        fn [ ({ degree = 0; rate = -3; wave = Sine 2 }, 2, 1) ] ) ];
  List.iter
    (fun (name, formula) -> if not (fails (fun () -> multiplied_out formula)) then own (name ^ " is multiplied out"))
    [ ("sin x cos x", F.Multiply (F.Sin x, F.Cos x)); ("e^(x^2)", F.Exp (F.Multiply (x, x))); ("ln x", F.Ln x);
      ("t", F.Variable "t"); ("e^(x/2)", F.Exp (F.Multiply (part 1 2, x))); ("e^(x + 1)", F.Exp (F.Add (x, n 1)));
      ("e^0", F.Exp (F.Multiply (n 0, x))); ("1 / x", F.Divide (n 1, x)); ("pi", F.Pi); ("x^2", F.Power (x, 2)) ];
  if
    terms_written (F.Add (F.Add (F.Exp (F.Negate x), F.Multiply (n 3, F.Exp (F.Multiply (n 2, x)))), n 4))
    <> [ exponential (-1); exponential 2; unit ]
  then own "the order of the terms of e^(-x) + 3 e^(2x) + 4";
  if
    terms_written (F.Negate (F.Subtract (F.Multiply (n 2, F.Cos x), F.Sin (F.Multiply (n 2, x)))))
    <> [ cosine 1; sine 2 ]
  then own "the order of the terms of -(2 cos x - sin 2x)";
  if not (fails (fun () -> terms_written (F.Multiply (n 2, F.Add (x, n 1))))) then own "2 (x + 1) is taken for one term";
  (* mistaken answers that are far enough from the right one, and not *)
  let e k top bottom = fn [ (exponential k, top, bottom) ] in
  List.iter
    (fun (name, mistaken, right, wanted) ->
      if points_apart mistaken right <> wanted then
        own (Printf.sprintf "%s are apart at %d sample points" name (points_apart mistaken right)))
    [ ("2 e^x and itself", e 1 2 1, e 1 2 1, 0);
      ("2.01 e^x and 2 e^x", e 1 201 100, e 1 2 1, 0);
      ("2.03 e^x and 2 e^x", e 1 203 100, e 1 2 1, 15);
      ("0 and 2 e^x", [], e 1 2 1, 15);
      (* 1.1 x is 10% from x everywhere *)
      ("1.1 x and x", fn [ (line, 11, 10) ], one_of line, 15);
      (* x + 0.001 is within 1% of x where x is beyond 0.1 on either side *)
      ("x + 0.001 and x", fn [ (line, 1, 1); (unit, 1, 1000) ], one_of line, 0);
      (* more than 1% apart where e^(-6x) > 0.01, which is x < 0.7675: the
         eleven sample points up to 0.71 *)
      ("e^(3x) + e^(-3x) and e^(3x)", fn [ (exponential 3, 1, 1); (exponential (-3), 1, 1) ], e 3 1 1, 11) ]

let () =
  check_own_working ();
  let base = load_file "nonhomogeneous_ode.rhm" in
  let per_budget = function 1 -> 16000 | 2 -> 6000 | _ -> 12000 in
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
  List.iter (fun (k, _, _) -> if times_seen k = 0 then fail ("never generated: " ^ k)) kinds;
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
  if !failures = 0 then print_endline "Rhema non-homogeneous differential equation tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d non-homogeneous differential equation test(s) failed." !failures);
    exit 1
  end
