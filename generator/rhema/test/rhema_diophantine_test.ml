(* Independent checks for diophantine.rhm. Every question is matched against
   the whole sentence of its form, the numbers are read back from it, and the
   answer is found again by a search from the definitions, on whole numbers
   and exact fractions, never by the gcd, the inverse modulo b, the formulas
   a b - a - b and (a - 1)(b - 1) / 2, the convergents or the list of Pell
   solutions the grammar uses:

   solvable_count     every x from -b to b and every y from -(a + 200) to
                      a + 200 is tried, and the c from 1 to N that some
                      a x + b y comes to are counted. The box is wide enough:
                      with (x, y) the pair (x - b, y + a) is a solution too,
                      so a c that can be reached is reached with
                      0 <= x < b, and then y lies between -a and c / b.
   continued_value    the partial quotients are read from the list; the last
                      is at least 2. The nested fraction is worked out from
                      its innermost level outwards on exact fractions: the
                      last quotient, then each earlier one plus the
                      reciprocal of what stands below it. The value is not a
                      whole number.
   next_solution      the pair given solves the printed equation. Then
                      x_0 + 1, x_0 + 2, ... are tried until c - a x is a
                      multiple of b; that x and its y are the answer, and
                      the search needs no more than b steps.
   solution_in_range  every x from 0 to b - 1 is tried and those for which
                      c - a x is a multiple of b are kept: exactly one, as
                      the text claims. a and b share no factor.
   largest_gap,       every amount up to 2 a b that some numbers of the two
   gap_count          stamps, neither negative, make up is marked. The
                      amounts from 1 up that are not marked are the gaps:
                      the largest of them, and how many there are. Nothing
                      beyond the bound is a gap, since the a amounts that
                      follow the largest gap are all made within the bound,
                      and every later amount is one of them and some more
                      stamps of a cents. The two values share no factor.
   partial_quotient   the printed fraction, which is in lowest terms, is
                      expanded by the test's own loop: the whole part is
                      taken off and what is left is turned over, until
                      nothing is left. The expansion has exactly four
                      partial quotients, the last at least 2, and worked out
                      from the innermost level it gives the fraction back.
                      The quotient asked for is read off.
   ways               every number of stamps of the first value from 0 to
                      n / a is tried, and those that leave a multiple of the
                      second value are counted. There are at least two ways,
                      and the two values share no factor.
   pell_least,        x = 2, 3, ... up to 999 are tried: those for which
   pell_next          x^2 - 1 is d times the square of a whole number y, at
                      least 1, are the solutions, in order. The first is the
                      least and the second the second least. d is not a
                      square (no whole number squared gives it) and not 13.

   The mistakes are worked out from their descriptions. gcd_condition_missed
   on solvable_count counts every c from 1 to N. step_not_reduced on
   next_solution steps by b in x and by a in y: the pair it gives solves the
   equation and has a larger x, and it is the next solution exactly when a
   and b share no factor; then the working is not changed and the mistake is
   not listed, by the rules of the language. added_straight on
   continued_value adds the reciprocals of the partial quotients after the
   first to the first, one after the other. product_taken on largest_gap is
   the product of the two values; on gap_count nothing is taken for the
   count, and no mistake is listed. The engine must list exactly these
   mistakes on these forms, in the order they are declared, with these values
   and these descriptions, and none on the other forms.

   WeBWorK compares with a tolerance of one part in a thousand, so a mistaken
   answer must not pass for the right one: a mistaken fraction is more than
   1% away from the right one; a mistaken point is more than 1% away in some
   coordinate; and where the right answer is a whole number, which the engine
   writes so that no other whole number passes, the mistaken one is another
   number and, below 1000, more than 0.2% away. No coordinate of a point
   that is asked for reaches 1000.

   For every question: the prompt is the text of the question, there is one
   blank and it holds answer_value, the context is "Numeric" (a point carries
   its own), and the answer is what its form asks for: a whole number, a
   fraction that is not whole, or a point with whole coordinates. Each kind
   appears at its price and at no other, no other kind appears, the budget is
   spent, the grammar's own budget gives a question of price 2, and a budget
   outside 1 to 3 gives no question.

   What each form is asked with is pinned, from the ranges the grammar's
   comments and productions describe: every choice must come up, and nothing
   else. The two numbers a < b are the 29 pairs from 3 to 12 without a common
   factor. solvable_count has them times 2 to 6 and N from 20 to 100;
   next_solution has them times 1 to 4, with x_0 and y_0 from -9 to 9 (all
   361 pairs); solution_in_range has them as they are, with every x from 0 to
   b - 1 and the y that goes with it from -9 to 9; the stamps have them as
   they are, in either question. A continued fraction to work out has a_0
   from 0 to 5, the others from 1 to 6 and the last from 2 to 6: all 180 with
   three partial quotients, and for those with four each first three and
   each last three. A fraction to expand has a_0 from 0 to 4, a_1 and a_2
   from 1 to 5 and a_3 from 2 to 5, and each of the three quotients is asked
   for: all 500 expansions come up, and each first two and each last two
   with each of the three. The amount of
   ways is from 30 to 150: every pair of stamps comes up with every amount in
   that range for which the test's own count finds two ways or more, and
   with no other. Pell's d are the eleven from 2 to 15 that are neither a
   square nor 13, each in either question. The weights of the forms are not
   pinned. *)

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

(* ---- Exact fractions ------------------------------------------------------ *)

(* A fraction with a positive denominator. It is not brought to lowest terms:
   two fractions are compared by multiplying across, so the test needs no
   common divisor of its own. *)
type fraction = { top : int; bottom : int }

let whole n = { top = n; bottom = 1 }

let fraction top bottom =
  if bottom = 0 then failwith "a division by zero"
  else if bottom < 0 then { top = -top; bottom = -bottom }
  else { top; bottom }

let ( +: ) a b = fraction ((a.top * b.bottom) + (b.top * a.bottom)) (a.bottom * b.bottom)
let ( -: ) a b = fraction ((a.top * b.bottom) - (b.top * a.bottom)) (a.bottom * b.bottom)
let reciprocal a = fraction a.bottom a.top
let times n a = { a with top = n * a.top }
let absolute a = { a with top = abs a.top }
let same a b = a.top * b.bottom = b.top * a.bottom
let less a b = a.top * b.bottom < b.top * a.bottom
let is_whole a = a.top mod a.bottom = 0
let show a = if is_whole a then string_of_int (a.top / a.bottom) else Printf.sprintf "%d/%d" a.top a.bottom
let of_number (n : Rhema_number.t) = { top = n.Rhema_number.numerator; bottom = n.Rhema_number.denominator }

(* An answer: a number, or a point of the plane. *)
type answer = Number of fraction | Place of fraction * fraction

let show_answer = function Number x -> show x | Place (x, y) -> Printf.sprintf "(%s, %s)" (show x) (show y)

let equal_answers left right =
  match (left, right) with
  | Number x, Number y -> same x y
  | Place (x1, y1), Place (x2, y2) -> same x1 x2 && same y1 y2
  | _ -> false

let read = function
  | Rhema_engine.Num n -> Number (of_number n)
  | Rhema_engine.Point [ x; y ] -> Place (of_number x, of_number y)
  | other -> failwith ("neither a number nor a point of the plane: " ^ Rhema_engine.describe_value other)

let spot x y = Place (whole x, whole y)

(* Whether `wrong` is more than one part in `parts` of `right` away from it. *)
let beyond parts wrong right = less (absolute right) (times parts (absolute (wrong -: right)))

(* A marker with a tolerance of one part in a thousand must not take the
   mistaken answer for the right one. A fraction is more than 1% away, a
   point more than 1% away in some coordinate. A right answer that is a whole
   number is written by the engine so that no other whole number passes: the
   mistaken answer is then another number, and below 1000 more than 0.2%
   away. *)
let apart wrong right =
  match (wrong, right) with
  | Number w, Number r when is_whole r -> (not (same w r)) && ((not (less (absolute r) (whole 1000))) || beyond 500 w r)
  | Number w, Number r -> beyond 100 w r
  | Place (wx, wy), Place (rx, ry) -> beyond 100 wx rx || beyond 100 wy ry
  | _ -> true

(* What a form asks for. *)
type shape = Whole_number | Broken_number | Whole_point

let shape_of = function
  | "continued_value" -> Broken_number
  | "next_solution" | "pell_least" | "pell_next" -> Whole_point
  | _ -> Whole_number

let has_shape shape answer =
  match (shape, answer) with
  | Whole_number, Number x -> x.bottom = 1
  | Broken_number, Number x -> not (is_whole x)
  | Whole_point, Place (x, y) -> x.bottom = 1 && y.bottom = 1
  | _ -> false

(* ---- Reading a question --------------------------------------------------- *)

(* The pattern of a prompt is the whole sentence, with a group wherever a
   number stands. *)
let words = Str.quote
let a_whole = "\\(0\\|-?[1-9][0-9]*\\)"
let a_natural = "\\(0\\|[1-9][0-9]*\\)"
let a_count = "\\([1-9][0-9]*\\)"

let fields_opt count pattern text =
  if Str.string_match (Str.regexp pattern) text 0 && Str.match_end () = String.length text then
    Some (List.init count (fun n -> Str.matched_group (n + 1) text))
  else None

let numbers_opt count pattern text = Option.map (List.map int_of_string) (fields_opt count pattern text)

let numbers_of count pattern text =
  match numbers_opt count pattern text with Some list -> list | None -> failwith "the wording is not the expected one"

let range first last = List.init (max 0 (last - first + 1)) (fun i -> first + i)
let size = List.length
let count_if f list = size (List.filter f list)
let last_of list = List.nth list (size list - 1)

(* ---- Searches from the definitions ---------------------------------------- *)

(* Whether two numbers share a factor: some number from 2 up divides both. *)
let share_a_factor x y = List.exists (fun t -> x mod t = 0 && y mod t = 0) (range 2 (min x y))

(* The c from 1 to `reach` that a x + b y comes to for some whole x and y.
   With (x, y) the pair (x - b, y + a) gives the same c, so a c that can be
   reached is reached with 0 <= x < b, and then b y = c - a x lies between
   -a b and c: the box below holds that pair. *)
let reach = 200
let reached_table : (int * int, bool array) Hashtbl.t = Hashtbl.create 256

let reached a b =
  match Hashtbl.find_opt reached_table (a, b) with
  | Some table -> table
  | None ->
      if a < 1 || b < 1 || a > 1000 || b > 1000 then failwith "a coefficient out of reach";
      let table = Array.make (reach + 1) false in
      for x = -b to b do
        for y = -(a + reach) to a + reach do
          let c = (a * x) + (b * y) in
          if c >= 1 && c <= reach then table.(c) <- true
        done
      done;
      Hashtbl.replace reached_table (a, b) table;
      table

(* The first solution of a x + b y = c with x above x_0: x_0 + 1, x_0 + 2,
   ... are tried until c - a x is a multiple of b. *)
let next_solution a b c x0 =
  let rec go x =
    if x > x0 + b then failwith "no solution within b steps"
    else if (c - (a * x)) mod b = 0 then (x, (c - (a * x)) / b)
    else go (x + 1)
  in
  go (x0 + 1)

(* The amounts from 1 up that no numbers of stamps of a and b cents, neither
   negative, make up. Every amount up to 2 a b that can be made is marked.
   Nothing beyond the bound is left out: the a amounts after the largest gap
   are all made within the bound, and every later amount is one of them and
   some more stamps of a cents. *)
let gaps_table : (int * int, int list) Hashtbl.t = Hashtbl.create 64

let gaps a b =
  match Hashtbl.find_opt gaps_table (a, b) with
  | Some list -> list
  | None ->
      if a < 1 || b < 1 || a > 1000 || b > 1000 then failwith "a stamp out of reach";
      let bound = 2 * a * b in
      let made = Array.make (bound + 1) false in
      for x = 0 to bound / a do
        for y = 0 to (bound - (a * x)) / b do
          made.((a * x) + (b * y)) <- true
        done
      done;
      let list = List.filter (fun n -> not made.(n)) (range 1 bound) in
      if list <> [] && last_of list + a > bound then failwith "the gaps do not end within the bound";
      Hashtbl.replace gaps_table (a, b) list;
      list

(* The number of ways to make n from stamps of a and b cents: every number of
   the first stamp is tried. *)
let ways a b n = count_if (fun x -> (n - (a * x)) mod b = 0) (range 0 (n / a))

(* A continued fraction worked out from its innermost level: the last partial
   quotient, then each earlier one plus the reciprocal of what stands below. *)
let nested quotients =
  match List.rev quotients with
  | [] -> failwith "no partial quotients"
  | last :: earlier -> List.fold_left (fun below a -> whole a +: reciprocal below) (whole last) earlier

(* The partial quotients of top / bottom: the whole part is taken off, and
   what is left is turned over, until nothing is left. *)
let expansion top bottom =
  if top < 0 || bottom < 1 then failwith "not a fraction to expand";
  let rec go top bottom found =
    if size found > 60 then failwith "the expansion does not end";
    let quotient = top / bottom in
    let left = top - (quotient * bottom) in
    if left = 0 then List.rev (quotient :: found) else go bottom left (quotient :: found)
  in
  go top bottom []

(* The whole number, from 0 up, whose square is n, if there is one. *)
let root n =
  let rec go r = if r * r > n then None else if r * r = n then Some r else go (r + 1) in
  go 0

(* The solutions of x^2 - d y^2 = 1 in positive whole numbers with x below
   1000, the least x first. *)
let pell_table : (int, (int * int) list) Hashtbl.t = Hashtbl.create 16

let pell d =
  match Hashtbl.find_opt pell_table d with
  | Some list -> list
  | None ->
      if d < 1 then failwith "no d";
      let list =
        List.filter_map
          (fun x ->
            let rest = (x * x) - 1 in
            if rest mod d <> 0 then None
            else match root (rest / d) with Some y when y >= 1 -> Some (x, y) | _ -> None)
          (range 2 999)
      in
      Hashtbl.replace pell_table d list;
      list

(* ---- What each form was asked with ---------------------------------------- *)

let asked : (string * string, unit) Hashtbl.t = Hashtbl.create 4096
let note label what = Hashtbl.replace asked (label, what) ()
let numbers values = String.concat " " (List.map string_of_int values)

(* The amounts of the ways form. *)
let amounts = range 30 150

(* Every choice the grammar offers, form by form. *)
let offered =
  let product f xs ys = List.concat_map (fun x -> List.map (fun y -> f x y) ys) xs in
  (* a < b from 3 to 12 with no common factor *)
  let pairs =
    List.concat (product (fun a b -> if a < b && not (share_a_factor a b) then [ (a, b) ] else []) (range 3 11) (range 4 12))
  in
  let scaled factors = product (fun g (a, b) -> numbers [ g * a; g * b ]) factors pairs in
  let as_they_are = List.map (fun (a, b) -> numbers [ a; b ]) pairs in
  (* the stamps and the amounts with two ways or more *)
  let counted = List.concat (product (fun (a, b) n -> let w = ways a b n in if w >= 2 then [ (a, b, n, w) ] else []) pairs amounts) in
  let d_values = List.filter (fun d -> root d = None && d <> 13) (range 2 15) in
  [ ("solvable_count: equation", scaled (range 2 6));
    ("solvable_count: limit", List.map string_of_int (range 20 100));
    ( "continued_value: three",
      List.concat (product (fun a0 a1 -> List.map (fun a2 -> numbers [ a0; a1; a2 ]) (range 2 6)) (range 0 5) (range 1 6)) );
    ( "continued_value: four, first three",
      List.concat (product (fun a0 a1 -> List.map (fun a2 -> numbers [ a0; a1; a2 ]) (range 1 6)) (range 0 5) (range 1 6)) );
    ( "continued_value: four, last three",
      List.concat (product (fun a1 a2 -> List.map (fun a3 -> numbers [ a1; a2; a3 ]) (range 2 6)) (range 1 6) (range 1 6)) );
    ("next_solution: equation", scaled (range 1 4));
    ("next_solution: given", product (fun x y -> numbers [ x; y ]) (range (-9) 9) (range (-9) 9));
    ( "solution_in_range: equation and x",
      List.concat_map (fun (a, b) -> List.map (fun x -> numbers [ a; b; x ]) (range 0 (b - 1))) pairs );
    ("solution_in_range: y", List.map string_of_int (range (-9) 9));
    ("largest_gap", as_they_are);
    ("gap_count", as_they_are);
    ( "partial_quotient: expansion",
      List.concat
        (product
           (fun (a0, a1) (a2, a3) -> [ numbers [ a0; a1; a2; a3 ] ])
           (product (fun a0 a1 -> (a0, a1)) (range 0 4) (range 1 5))
           (product (fun a2 a3 -> (a2, a3)) (range 1 5) (range 2 5))) );
    ( "partial_quotient: first two",
      List.concat (product (fun a0 a1 -> List.map (fun i -> numbers [ a0; a1; i ]) (range 1 3)) (range 0 4) (range 1 5)) );
    ( "partial_quotient: last two",
      List.concat (product (fun a2 a3 -> List.map (fun i -> numbers [ a2; a3; i ]) (range 1 3)) (range 1 5) (range 2 5)) );
    ("ways: stamps and amount", List.map (fun (a, b, n, _) -> numbers [ a; b; n ]) counted);
    ("ways: number", List.map string_of_int (List.sort_uniq compare (List.map (fun (_, _, _, w) -> w) counted)));
    ("pell_least", List.map string_of_int d_values);
    ("pell_next", List.map string_of_int d_values) ]

(* ---- The answer of each form, found again --------------------------------- *)

let stamps_text = words "Stamps come in two values, [`" ^ a_count ^ words "`] cents and [`" ^ a_count ^ words "`] cents. "

(* The right answer of a question, and the answer of each mistake its form is
   open to, with whether that mistake may come to the right answer, all found
   again from the prompt. *)
let expected (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  match kind q with
  | "solvable_count" -> (
      match
        numbers_of 3
          (words "For how many of the whole numbers [`c`] from [`1`] to [`" ^ a_count ^ words "`] does the equation [`"
         ^ a_count ^ words "x + " ^ a_count ^ words "y = c`] have a solution in integers [`x`] and [`y`]?")
          p
      with
      | [ limit; a; b ] ->
          if limit > reach then failwith "the limit is out of reach";
          note "solvable_count: equation" (numbers [ a; b ]);
          note "solvable_count: limit" (string_of_int limit);
          let table = reached a b in
          let all = range 1 limit in
          (Number (whole (count_if (fun c -> table.(c)) all)), [ ("gcd_condition_missed", Number (whole (size all)), false) ])
      | _ -> failwith "three numbers were expected")
  | "continued_value" ->
      let list count =
        words "Write the continued fraction [`[" ^ a_natural ^ words "; "
        ^ String.concat (words ", ") (List.init count (fun _ -> a_count))
        ^ words "]`] as a single fraction. Here [`[a_0; a_1, a_2, \\ldots]`] stands for [`a_0 + \\frac{1}{a_1 + \\frac{1}{a_2 + \\cdots}}`]."
      in
      let quotients =
        match numbers_opt 4 (list 3) p with Some four -> four | None -> numbers_of 3 (list 2) p
      in
      if last_of quotients < 2 then failwith "the last partial quotient is below 2";
      (match quotients with
      | [ a0; a1; a2 ] -> note "continued_value: three" (numbers [ a0; a1; a2 ])
      | [ a0; a1; a2; a3 ] ->
          note "continued_value: four, first three" (numbers [ a0; a1; a2 ]);
          note "continued_value: four, last three" (numbers [ a1; a2; a3 ])
      | _ -> failwith "three or four partial quotients were expected");
      (* the reciprocals added to a_0 one after the other *)
      let straight =
        List.fold_left (fun sum a -> sum +: reciprocal (whole a)) (whole (List.hd quotients)) (List.tl quotients)
      in
      (Number (nested quotients), [ ("added_straight", Number straight, false) ])
  | "next_solution" -> (
      match
        numbers_of 6
          (words "The pair [`(x, y) = (" ^ a_whole ^ words ", " ^ a_whole ^ words ")`] is a solution in integers of [`"
         ^ a_count ^ words "x + " ^ a_count ^ words "y = " ^ a_whole
         ^ words "`]. Find the solution in integers with the least [`x`] greater than [`" ^ a_whole
         ^ words "`]. Enter it as a point [`(x, y)`].")
          p
      with
      | [ x0; y0; a; b; c; x0' ] ->
          if x0 <> x0' then failwith "the x of the pair is not repeated as it was";
          if (a * x0) + (b * y0) <> c then failwith "the pair given is not a solution";
          note "next_solution: equation" (numbers [ a; b ]);
          note "next_solution: given" (numbers [ x0; y0 ]);
          let x, y = next_solution a b c x0 in
          (* the step by b in x and by a in y: a solution further on, the
             next one only when a and b share no factor *)
          let far_x = x0 + b and far_y = y0 - a in
          if (a * far_x) + (b * far_y) <> c then failwith "the step by b and a does not give a solution";
          if far_x < x then failwith "the step by b and a stops before the next solution";
          if (far_x = x) <> not (share_a_factor a b) then
            failwith "the step by b and a is the next solution, though a and b share a factor, or the other way round";
          (spot x y, [ ("step_not_reduced", spot far_x far_y, true) ])
      | _ -> failwith "six numbers were expected")
  | "solution_in_range" -> (
      match
        numbers_of 4
          (words "The equation [`" ^ a_count ^ words "x + " ^ a_count ^ words "y = " ^ a_whole
         ^ words "`] has exactly one solution in integers with [`0 \\le x < " ^ a_count ^ words "`]. Find its [`x`].")
          p
      with
      | [ a; b; c; b' ] -> (
          if b <> b' then failwith "the range does not end at b";
          if share_a_factor a b then failwith "a and b share a factor";
          match List.filter (fun x -> (c - (a * x)) mod b = 0) (range 0 (b - 1)) with
          | [ x ] ->
              note "solution_in_range: equation and x" (numbers [ a; b; x ]);
              note "solution_in_range: y" (string_of_int ((c - (a * x)) / b));
              (Number (whole x), [])
          | found -> failwith (Printf.sprintf "%d solutions in the range, not one" (size found)))
      | _ -> failwith "four numbers were expected")
  | ("largest_gap" | "gap_count") as k -> (
      let question =
        if k = "largest_gap" then "What is the largest whole number of cents that cannot be made up exactly with such stamps?"
        else "How many whole numbers of cents, from [`1`] upwards, cannot be made up exactly with such stamps?"
      in
      match numbers_of 2 (stamps_text ^ words question) p with
      | [ a; b ] ->
          if share_a_factor a b then failwith "the two values share a factor";
          note k (numbers [ a; b ]);
          let list = gaps a b in
          if list = [] then failwith "every amount can be made";
          if k = "largest_gap" then (Number (whole (last_of list)), [ ("product_taken", Number (whole (a * b)), false) ])
          else (Number (whole (size list)), [])
      | _ -> failwith "two numbers were expected")
  | "partial_quotient" -> (
      match
        numbers_of 3
          (words "The fraction [`\\frac{" ^ a_count ^ words "}{" ^ a_count
         ^ words
             "}`] is the continued fraction [`[a_0; a_1, a_2, a_3] = a_0 + \\frac{1}{a_1 + \\frac{1}{a_2 + \\frac{1}{a_3}}}`] with whole numbers [`a_1, a_2 \\ge 1`] and [`a_3 \\ge 2`]. Find [`a_{"
         ^ "\\([123]\\)" ^ words "}`].")
          p
      with
      | [ top; bottom; index ] -> (
          if share_a_factor top bottom then failwith "the fraction is not in lowest terms";
          match expansion top bottom with
          | [ a0; a1; a2; a3 ] as quotients ->
              if a1 < 1 || a2 < 1 || a3 < 2 then failwith "the partial quotients are not as the text says";
              if not (same (nested quotients) (fraction top bottom)) then failwith "the expansion does not give the fraction back";
              note "partial_quotient: expansion" (numbers quotients);
              note "partial_quotient: first two" (numbers [ a0; a1; index ]);
              note "partial_quotient: last two" (numbers [ a2; a3; index ]);
              (Number (whole (List.nth quotients index)), [])
          | quotients -> failwith (Printf.sprintf "%d partial quotients, not four" (size quotients)))
      | _ -> failwith "three numbers were expected")
  | "ways" -> (
      match
        numbers_of 3
          (stamps_text ^ words "In how many ways can exactly [`" ^ a_count
         ^ words "`] cents be made up with such stamps? Two ways are different when they use different numbers of some stamp.")
          p
      with
      | [ a; b; n ] ->
          if share_a_factor a b then failwith "the two values share a factor";
          let count = ways a b n in
          if count < 2 then failwith "fewer than two ways";
          note "ways: stamps and amount" (numbers [ a; b; n ]);
          note "ways: number" (string_of_int count);
          (Number (whole count), [])
      | _ -> failwith "three numbers were expected")
  | ("pell_least" | "pell_next") as k -> (
      match
        numbers_of 1
          (words "Among the solutions in positive whole numbers of [`x^{2} - " ^ a_count ^ words "y^{2} = 1`], find the one with the "
          ^ words (if k = "pell_least" then "least" else "second least")
          ^ words " [`x`]. Enter it as a point [`(x, y)`].")
          p
      with
      | [ d ] -> (
          if root d <> None then failwith "d is a square";
          if d = 13 then failwith "d is 13, whose smallest solution has three digits";
          note k (string_of_int d);
          match pell d with
          | (x1, y1) :: (x2, y2) :: _ -> ((if k = "pell_least" then spot x1 y1 else spot x2 y2), [])
          | _ -> failwith "fewer than two solutions with x below 1000")
      | _ -> failwith "a number was expected")
  | k -> failwith ("unknown kind " ^ k)

let questions_at cost = if cost = 1 then 40000 else if cost = 2 then 60000 else 150000

(* The mistakes the grammar declares, in its order, each described word for
   word. *)
let described =
  [ ("gcd_condition_missed", "takes a x + b y = c to have a solution for every c, where c must be a multiple of gcd(a, b)");
    ( "step_not_reduced",
      "steps from one solution to the next by b in x and a in y, where b / gcd(a, b) and a / gcd(a, b) belong" );
    ( "added_straight",
      "adds the reciprocals of the partial quotients one after the other, where each fraction stands below the one before" );
    ("product_taken", "takes the product a b for the largest amount that cannot be made, where a b - a - b belongs") ]

let () =
  let base = load_file "diophantine.rhm" in
  if base.Rhema_check.mistakes <> described then fail "the mistakes declared are not the four of the header, in its order";
  let prices =
    [ ("solvable_count", 1); ("continued_value", 1); ("next_solution", 2); ("solution_in_range", 2); ("largest_gap", 2);
      ("gap_count", 2); ("partial_quotient", 2); ("ways", 3); ("pell_least", 3); ("pell_next", 3) ]
  in
  let seen = Hashtbl.create 16 and made = Hashtbl.create 8 in
  (* a budget below the lowest or above the highest is refused *)
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
    [ -1; 0; 4; 5; 6; 9 ];
  (* the grammar as it is written, with the budget it sets itself, gives a
     question of price 2 *)
  for seed = 0 to 19 do
    Random.init seed;
    match Rhema_engine.generate base with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "the grammar's own budget, seed %d: %s" seed m)
    | q ->
        if List.assoc_opt (kind q) prices <> Some 2 || Rhema_engine.consumption q.Rhema_engine.tree "cost" <> 2 then
          fail (Printf.sprintf "the grammar's own budget gave %s, not a question of price 2" (kind q))
  done;
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to questions_at cost - 1 do
      Random.init (seed + (100000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          (match Rhema_engine.attribute q.Rhema_engine.tree "text" with
          | Rhema_engine.Text t when t = p -> ()
          | _ -> fail (Printf.sprintf "%s: the prompt is not the text of the question, for %S" k p));
          (* a point carries its own context, so every form stays in the
             default one *)
          if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
          match q.Rhema_engine.answers with
          | [ only ] -> (
              match
                let got = read only in
                (got, expected q)
              with
              | exception e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)
              | got, (want, slips) ->
                  (match read q.Rhema_engine.answer with
                  | first when first = got -> ()
                  | _ | (exception Failure _) -> fail (Printf.sprintf "%s: the answer is not the answer of the blank, for %S" k p));
                  (match Rhema_engine.attribute q.Rhema_engine.tree "answer_value" with
                  | value when (try read value = got with Failure _ -> false) -> ()
                  | _ -> fail (Printf.sprintf "%s: the blank does not hold answer_value, for %S" k p));
                  if not (has_shape (shape_of k) got) then
                    fail (Printf.sprintf "%s: the answer %s is not what the form asks for, for %S" k (show_answer got) p);
                  if not (equal_answers got want) then
                    fail (Printf.sprintf "%s: answer %s, found again %s, for %S" k (show_answer got) (show_answer want) p);
                  (* no coordinate of a point reaches 1000 *)
                  (match got with
                  | Place (x, y) ->
                      if not (less (absolute x) (whole 1000) && less (absolute y) (whole 1000)) then
                        fail (Printf.sprintf "%s: a coordinate of %s reaches 1000, for %S" k (show_answer got) p)
                  | Number _ -> ());
                  (* a mistake that must change the answer and does not *)
                  List.iter
                    (fun (name, slip, may_coincide) ->
                      if equal_answers slip want && not may_coincide then
                        fail (Printf.sprintf "%s: %s gives the right answer %s, for %S" k name (show_answer want) p))
                    slips;
                  (* a mistake whose working leaves the answer as it is
                     concerns no question; any other must not pass for the
                     right answer with a marker of one part in a thousand *)
                  let slips =
                    List.filter_map (fun (name, slip, _) -> if equal_answers slip want then None else Some (name, slip)) slips
                  in
                  List.iter
                    (fun (name, slip) ->
                      if not (apart slip want) then
                        fail
                          (Printf.sprintf "%s: %s gives %s, too near the answer %s for a marker to tell apart, for %S" k name
                             (show_answer slip) (show_answer want) p))
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
                      Hashtbl.replace made (m.mistake, k) ();
                      (* each mistake is described as itself, not as another *)
                      (match List.assoc_opt m.mistake described with
                      | Some description ->
                          if m.description <> description then
                            fail (Printf.sprintf "%s is described as %S" m.mistake m.description)
                      | None -> fail ("an unknown mistake is listed: " ^ m.mistake));
                      match (m.mistaken_answers, List.assoc_opt m.mistake slips) with
                      | Some [ value ], Some slip -> (
                          match read value with
                          | exception Failure message -> fail (Printf.sprintf "%s: %s gives %s, for %S" k m.mistake message p)
                          | wrong ->
                              if not (equal_answers wrong slip) then
                                fail
                                  (Printf.sprintf "%s: %s gives %s, found again %s, for %S" k m.mistake (show_answer wrong)
                                     (show_answer slip) p);
                              if equal_answers wrong got then
                                fail (Printf.sprintf "%s: %s gives the right answer, for %S" k m.mistake p))
                      | _, None -> ()
                      | _, Some _ -> fail (Printf.sprintf "%s: %s does not give one answer, for %S" k m.mistake p))
                    listed)
          | answers -> fail (Printf.sprintf "%s: %d blanks, one was expected, for %S" k (size answers) p))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  Hashtbl.iter (fun k () -> if not (List.mem_assoc k prices) then fail ("a kind the header does not list: " ^ k)) seen;
  (* each mistake is listed on its form, and on no other *)
  let forms =
    [ ("gcd_condition_missed", "solvable_count"); ("step_not_reduced", "next_solution"); ("added_straight", "continued_value");
      ("product_taken", "largest_gap") ]
  in
  List.iter
    (fun (mistake, k) -> if not (Hashtbl.mem made (mistake, k)) then fail (Printf.sprintf "%s never listed on %s" mistake k))
    forms;
  Hashtbl.iter
    (fun (mistake, k) () -> if not (List.mem (mistake, k) forms) then fail (Printf.sprintf "%s is listed on %s" mistake k))
    made;
  (* every choice the grammar offers came up, and nothing else *)
  List.iter
    (fun (label, choices) ->
      if choices = [] then fail ("nothing is offered for " ^ label);
      List.iter
        (fun what -> if not (Hashtbl.mem asked (label, what)) then fail (label ^ ": never asked with " ^ what))
        choices)
    offered;
  let offered_set = Hashtbl.create 4096 in
  List.iter (fun (label, choices) -> List.iter (fun what -> Hashtbl.replace offered_set (label, what) ()) choices) offered;
  Hashtbl.iter
    (fun (label, what) () ->
      if not (List.mem_assoc label offered) then fail ("nothing is known of what is offered for " ^ label)
      else if not (Hashtbl.mem offered_set (label, what)) then fail (label ^ ": asked with " ^ what))
    asked;
  if !failures = 0 then print_endline "Rhema diophantine tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d diophantine test(s) failed." !failures);
    exit 1
  end
