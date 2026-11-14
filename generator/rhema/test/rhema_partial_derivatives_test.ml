(* Independent checks for partial_derivatives.rhm. The function is read back
   from the printed question by a small parser for the LaTeX the engine
   writes (sums, products with \cdot, whole powers, brackets) and is then
   differentiated numerically, by differences, at several points. A partial
   derivative must agree with the difference quotient in its variable; a
   gradient with both; a tangent plane must touch the surface at the point
   with the surface's slopes and be linear; at a critical point both
   difference quotients must vanish, and the determinant of the second
   derivatives must not, so the point is the only one.

   A function of budgets 4 to 8 holds sin, cos and e as well, which the
   parser reads too. It is priced from its text, 2 for a function of
   a x + b y, 3 for a function of a product and 5 for one multiplied by a
   power of x or y, and with the price of the question that must come to
   the budget. *)

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

(* ---- a polynomial in x and y, from the LaTeX of formula_latex ---- *)

type token =
  | Number of float
  | Name of char
  | Times
  | Plus
  | Minus
  | Open
  | Close
  | Power of int
  | Sine
  | Cosine
  | Exp_open  (* e^{ *)
  | Exp_close  (* the } that ends it *)

let tokens text =
  let length = String.length text in
  let starts at word = at + String.length word <= length && String.sub text at (String.length word) = word in
  let rec go at found =
    if at >= length then List.rev found
    else if text.[at] = ' ' then go (at + 1) found
    else if starts at "\\cdot" then go (at + 5) (Times :: found)
    else if starts at "\\left(" then go (at + 6) (Open :: found)
    else if starts at "\\right)" then go (at + 7) (Close :: found)
    else if starts at "\\sin" then go (at + 4) (Sine :: found)
    else if starts at "\\cos" then go (at + 4) (Cosine :: found)
    else if starts at "e^{" then go (at + 3) (Exp_open :: found)
    else if text.[at] = '}' then go (at + 1) (Exp_close :: found)
    else if starts at "^{" then begin
      let close = String.index_from text at '}' in
      go (close + 1) (Power (int_of_string (String.sub text (at + 2) (close - at - 2))) :: found)
    end
    else
      match text.[at] with
      | '+' -> go (at + 1) (Plus :: found)
      | '-' -> go (at + 1) (Minus :: found)
      | '(' -> go (at + 1) (Open :: found)
      | ')' -> go (at + 1) (Close :: found)
      | ('x' | 'y') as name -> go (at + 1) (Name name :: found)
      | '0' .. '9' ->
          let stop = ref at in
          while !stop < length && text.[!stop] >= '0' && text.[!stop] <= '9' do incr stop done;
          go !stop (Number (float_of_string (String.sub text at (!stop - at))) :: found)
      | other -> failwith (Printf.sprintf "unexpected %c in %s" other text)
  in
  go 0 []

(* expression := term { (+ | -) term };  term := factor { \cdot factor };
   factor := - factor | number | name [^{n}] | ( expression ) [^{n}]
           | \sin ( expression ) | \cos ( expression ) | e^{ expression } *)
let parse text =
  let rest = ref (tokens text) in
  let next () = match !rest with [] -> None | token :: _ -> Some token in
  let advance () = rest := List.tl !rest in
  let powered base =
    match next () with
    | Some (Power n) ->
        advance ();
        fun point -> base point ** float n
    | _ -> base
  in
  let rec expression () =
    let first = term () in
    let rec more left =
      match next () with
      | Some Plus ->
          advance ();
          let right = term () in
          more (fun point -> left point +. right point)
      | Some Minus ->
          advance ();
          let right = term () in
          more (fun point -> left point -. right point)
      | _ -> left
    in
    more first
  and term () =
    let first = factor () in
    let rec more left =
      match next () with
      | Some Times ->
          advance ();
          let right = factor () in
          more (fun point -> left point *. right point)
      | _ -> left
    in
    more first
  and factor () =
    match next () with
    | Some Minus ->
        advance ();
        (* a minus sign applies to the whole product that follows it *)
        let body = term () in
        fun point -> -.body point
    | Some (Number value) ->
        advance ();
        fun _ -> value
    | Some (Name name) ->
        advance ();
        powered (fun (x, y) -> if name = 'x' then x else y)
    | Some Open ->
        advance ();
        let body = expression () in
        (match next () with Some Close -> advance () | _ -> failwith "a bracket is not closed");
        powered body
    | Some ((Sine | Cosine) as name) ->
        advance ();
        (match next () with Some Open -> advance () | _ -> failwith "a function without its bracket");
        let body = expression () in
        (match next () with Some Close -> advance () | _ -> failwith "a bracket is not closed");
        if name = Sine then fun point -> sin (body point) else fun point -> cos (body point)
    | Some Exp_open ->
        advance ();
        let body = expression () in
        (match next () with Some Exp_close -> advance () | _ -> failwith "an exponent is not closed");
        fun point -> exp (body point)
    | _ -> failwith ("cannot read " ^ text)
  in
  let result = expression () in
  if !rest <> [] then failwith ("something is left over in " ^ text);
  result

(* ---- differences ---- *)

let h = 1e-4

let d_x f (x, y) = (f (x +. h, y) -. f (x -. h, y)) /. (2. *. h)
let d_y f (x, y) = (f (x, y +. h) -. f (x, y -. h)) /. (2. *. h)

let d_xy f (x, y) =
  let k = 1e-3 in
  (f (x +. k, y +. k) -. f (x +. k, y -. k) -. f (x -. k, y +. k) +. f (x -. k, y -. k)) /. (4. *. k *. k)

let d_xx f (x, y) =
  let k = 1e-3 in
  (f (x +. k, y) -. (2. *. f (x, y)) +. f (x -. k, y)) /. (k *. k)

let d_yy f (x, y) =
  let k = 1e-3 in
  (f (x, y +. k) -. (2. *. f (x, y)) +. f (x, y -. k)) /. (k *. k)

let close a b = Float.abs (a -. b) <= 1e-4 *. Float.max 1. (Float.abs b)

let points = [ (0.7, -1.3); (1.9, 0.4); (-0.6, 2.2); (-1.4, -0.8) ]

(* ---- reading the question ---- *)

let group re text n =
  ignore (Str.search_forward (Str.regexp re) text 0);
  Str.matched_group n text

(* The function: the formula after "f(x, y) = " or "z = ". *)
let surface p = parse (group "\\[`\\(f(x, y)\\|z\\) = \\([^`]*\\)`\\]" p 2)

let at_point p =
  let re = "\\\\left(\\(-?[0-9]+\\), \\(-?[0-9]+\\)\\\\right)`\\]" in
  (float_of_string (group re p 1), float_of_string (group re p 2))

(* The terms of a built function that are not its first: every sin, cos
   and e in the text, as (function, whether its argument is a x + b y,
   whether a power of x or y multiplies it). *)
let function_terms text =
  let re =
    Str.regexp
      "\\(\\\\sin\\|\\\\cos\\)\\\\left(\\([^()]*\\)\\\\right)\\|e\\^{\\(\\([^{}]\\|{[0-9]+}\\)*\\)}"
  in
  let multiplied_before = Str.regexp ".*[xy]\\(\\^{[0-9]+}\\)? \\\\cdot $" in
  let rec go start found =
    match Str.search_forward re text start with
    | exception Not_found -> List.rev found
    | at ->
        let stop = Str.match_end () in
        let name, argument =
          match Str.matched_group 1 text with
          | name -> (String.sub name 1 3, Str.matched_group 2 text)
          | exception Not_found -> ("exp", Str.matched_group 3 text)
        in
        let linear =
          (try ignore (Str.search_forward (Str.regexp " [+-] ") argument 0); true with Not_found -> false)
        in
        let multiplied = Str.string_match multiplied_before (String.sub text 0 at) 0 in
        go stop ((name, linear, multiplied) :: found)
  in
  go 0 []

let function_price terms =
  List.fold_left (fun total (_, linear, multiplied) -> total + if multiplied then 5 else if linear then 2 else 3) 0 terms

(* Which second derivative a question asks for. *)
let second_derivative p =
  let holds text = try ignore (Str.search_forward (Str.regexp_string text) p 0); true with Not_found -> false in
  if holds "{\\partial x^{2}}" then "twice in x"
  else if holds "{\\partial y^{2}}" then "twice in y"
  else if holds "{\\partial y \\, \\partial x}" then "in x and in y"
  else failwith "no second derivative asked"

let as_function = function
  | Rhema_engine.Formula formula ->
      fun (x, y) -> Rhema_formula.evaluate_with (function "x" -> Some x | "y" -> Some y | _ -> None) formula
  | Rhema_engine.Num n -> fun _ -> Rhema_number.to_float n
  | other -> failwith ("not a formula: " ^ Rhema_engine.describe_value other)

let number = function
  | Rhema_engine.Num n -> Rhema_number.to_float n
  | other -> failwith ("not a number: " ^ Rhema_engine.describe_value other)

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answers %s, for %S" k what q.Rhema_engine.answer_text p) in
  let f = surface p in
  let agrees name derivative answer =
    List.iter
      (fun point ->
        if not (close (answer point) (derivative f point)) then
          wrong (Printf.sprintf "%s is %g at (%g, %g), not %g" name (derivative f point) (fst point) (snd point) (answer point)))
      points
  in
  match (k, q.Rhema_engine.answers) with
  | "first_partial", [ answer ] ->
      let name = group "\\\\partial f}{\\\\partial \\([xy]\\)}" p 1 in
      agrees ("the derivative in " ^ name) (if name = "x" then d_x else d_y) (as_function answer)
  | "both_partials", [ in_x; in_y ] ->
      agrees "the derivative in x" d_x (as_function in_x);
      agrees "the derivative in y" d_y (as_function in_y)
  | "mixed_partial", [ answer ] -> agrees "the mixed derivative" d_xy (as_function answer)
  | "built_first", [ answer ] ->
      let name = group "\\\\partial f}{\\\\partial \\([xy]\\)}" p 1 in
      agrees ("the derivative in " ^ name) (if name = "x" then d_x else d_y) (as_function answer)
  | "built_both", [ in_x; in_y ] ->
      agrees "the derivative in x" d_x (as_function in_x);
      agrees "the derivative in y" d_y (as_function in_y)
  | "built_second", [ answer ] ->
      let which = second_derivative p in
      if which = "twice in x" then agrees "the second derivative in x" d_xx (as_function answer)
      else if which = "twice in y" then agrees "the second derivative in y" d_yy (as_function answer)
      else agrees "the mixed derivative" d_xy (as_function answer)
  | "gradient", [ in_x; in_y ] ->
      let point = at_point p in
      if not (close (number in_x) (d_x f point) && close (number in_y) (d_y f point)) then
        wrong (Printf.sprintf "the gradient is (%g, %g)" (d_x f point) (d_y f point))
  | "tangent_plane", [ answer ] ->
      let plane = as_function answer and ((a, b) as point) = at_point p in
      if not (close (plane point) (f point)) then wrong "the plane misses the surface at the point";
      if not (close (d_x plane point) (d_x f point) && close (d_y plane point) (d_y f point)) then
        wrong "the plane does not have the surface's slopes";
      (* linear: the value at a far point is given by the slopes *)
      let far = (a +. 3., b -. 2.) in
      if not (close (plane far) (plane point +. (3. *. d_x plane point) -. (2. *. d_y plane point))) then
        wrong "not a plane";
      if Float.abs (d_x f point) < 1e-6 || Float.abs (d_y f point) < 1e-6 then wrong "a slope of the plane is zero"
  | "critical_point", [ Rhema_engine.Point [ x; y ] ] ->
      let point = (Rhema_number.to_float x, Rhema_number.to_float y) in
      if Float.abs (d_x f point) > 1e-6 || Float.abs (d_y f point) > 1e-6 then wrong "the derivatives do not vanish there";
      let k2 = 1e-2 in
      let second g (px, py) (ux, uy) = (g (px +. (k2 *. ux), py +. (k2 *. uy)) -. (2. *. g (px, py)) +. g (px -. (k2 *. ux), py -. (k2 *. uy))) /. (k2 *. k2) in
      let fxx = second f point (1., 0.) and fyy = second f point (0., 1.) and fxy = d_xy f point in
      if Float.abs ((fxx *. fyy) -. (fxy *. fxy)) < 1e-3 then wrong "the second derivatives do not make the point the only one"
  | _ -> wrong "unexpected answers"

let () =
  (* The parser itself, on shapes the engine writes. *)
  List.iter
    (fun (text, expected) ->
      match parse text (2., 3.) with
      | value -> if Float.abs (value -. expected) > 1e-9 then fail (Printf.sprintf "%s read as %g at (2, 3), not %g" text value expected)
      | exception Failure message -> fail message)
    [ ("3 \\cdot x^{2} \\cdot y + 2 \\cdot y^{3}", 90.); ("-(x^{2} \\cdot y^{2} + 5 \\cdot x^{3})", -76.);
      ("2 \\cdot x \\cdot y - x^{2} + 2 \\cdot y^{2} - 4 \\cdot x + 4 \\cdot y", 30.); ("x - \\left(y - 1\\right)^{2}", -2.);
      ("-x \\cdot y + 4", -2.);
      ("\\sin\\left(2 \\cdot x - y\\right) + 3", sin 1. +. 3.); ("x \\cdot \\cos\\left(x + y\\right)", 2. *. cos 5.);
      ("e^{x^{2} \\cdot y} - 2 \\cdot x \\cdot y", exp 12. -. 12.); ("y^{2} \\cdot e^{x - 2 \\cdot y}", 9. *. exp (-4.)) ];
  (* and the pricing of a function's text *)
  List.iter
    (fun (text, expected) ->
      if function_price (function_terms text) <> expected then
        fail (Printf.sprintf "%s priced %d, not %d" text (function_price (function_terms text)) expected))
    [ ("3 \\cdot x \\cdot y^{2} + \\sin\\left(x + 2 \\cdot y\\right)", 2);
      ("e^{x^{2} \\cdot y} - 2 \\cdot x \\cdot y", 3);
      ("2 \\cdot x \\cdot y + y^{2} \\cdot e^{x - 2 \\cdot y} + \\cos\\left(x \\cdot y\\right)", 8);
      ("x \\cdot y + \\sin\\left(x + y\\right) + e^{2 \\cdot x + 3 \\cdot y} + \\cos\\left(2 \\cdot x - 3 \\cdot y\\right)", 6) ];
  let base = load_file "partial_derivatives.rhm" in
  let prices =
    [ ("first_partial", 1, 1); ("both_partials", 2, 2); ("mixed_partial", 2, 1); ("gradient", 2, 2);
      ("tangent_plane", 3, 1); ("critical_point", 3, 1) ]
  in
  let seen = Hashtbl.create 8 and asked = Hashtbl.create 2 in
  let built = [ ("built_first", 1, 1); ("built_both", 2, 2); ("built_second", 2, 1) ] in
  let built_at = Hashtbl.create 16 and parts = Hashtbl.create 16 in
  for cost = 4 to 8 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          match List.find_opt (fun (name, _, _) -> name = k) built with
          | None -> fail (Printf.sprintf "%s at cost %d" k cost)
          | Some (_, asking, blanks) -> (
              Hashtbl.replace built_at (k, cost) ();
              if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then
                fail (Printf.sprintf "%s did not spend its budget %d" k cost);
              if List.length q.Rhema_engine.answers <> blanks then
                fail (Printf.sprintf "%s has %d blanks" k (List.length q.Rhema_engine.answers));
              if q.Rhema_engine.variables <> [ "x"; "y" ] then fail (k ^ ": the question does not declare x and y");
              try
                let text = group "\\[`f(x, y) = \\([^`]*\\)`\\]" p 1 in
                let terms = function_terms text in
                if asking + function_price terms <> cost then
                  fail (Printf.sprintf "%s: a question worth %d at budget %d: %S" k (asking + function_price terms) cost p);
                if List.length terms > 3 then fail (k ^ ": more than three further terms: " ^ text);
                let kinds_of_term =
                  List.map
                    (fun (name, linear, multiplied) ->
                      if multiplied then "a product" else if linear then name ^ " of a x + b y" else "a function of a product")
                    terms
                in
                if List.length (List.sort_uniq compare kinds_of_term) <> List.length kinds_of_term then
                  fail (k ^ ": two terms of a kind: " ^ text);
                if List.exists (fun (_, linear, multiplied) -> multiplied && not linear) terms then
                  fail (k ^ ": a product with a function of a product: " ^ text);
                List.iter (fun part -> Hashtbl.replace parts part ()) kinds_of_term;
                Hashtbl.replace parts (Printf.sprintf "%d further terms" (List.length terms)) ();
                if k = "built_second" then Hashtbl.replace parts (second_derivative p) ();
                check q
              with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)))
    done
  done;
  for cost = 4 to 8 do
    List.iter
      (fun (k, _, _) -> if not (Hashtbl.mem built_at (k, cost)) then fail (Printf.sprintf "%s never generated at budget %d" k cost))
      built
  done;
  List.iter
    (fun part -> if not (Hashtbl.mem parts part) then fail ("never built: " ^ part))
    [ "sin of a x + b y"; "cos of a x + b y"; "exp of a x + b y"; "a function of a product"; "a product";
      "1 further terms"; "2 further terms"; "3 further terms"; "twice in x"; "in x and in y"; "twice in y" ];
  (Random.init 1;
   match Rhema_engine.generate (with_initial base "cost" 9) with
   | exception Rhema_engine.Generation_error _ -> ()
   | q -> fail ("budget 9 gave a question: " ^ q.Rhema_engine.prompt));
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q -> (
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          match List.find_opt (fun (name, _, _) -> name = k) prices with
          | None -> fail ("unknown kind " ^ k)
          | Some (_, price, blanks) ->
              if price <> cost then fail (Printf.sprintf "%s at cost %d" k cost);
              if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
              if List.length q.Rhema_engine.answers <> blanks then
                fail (Printf.sprintf "%s has %d blanks" k (List.length q.Rhema_engine.answers));
              if q.Rhema_engine.context <> "Numeric" then fail (Printf.sprintf "%s in context %s" k q.Rhema_engine.context);
              if k = "first_partial" then Hashtbl.replace asked (group "\\\\partial f}{\\\\partial \\([xy]\\)}" p 1) ();
              (* every formula answer knows x and y, also one that holds only
                 one of them: the file declares both with pg_variables *)
              let pg = Rhema_pgml.document [ q ] in
              if q.Rhema_engine.variables <> [ "x"; "y" ] then fail (k ^ ": the question does not declare x and y");
              let two_variables =
                List.exists
                  (function
                    | Rhema_engine.Formula formula -> Rhema_formula.variables formula <> []
                    | _ -> false)
                  q.Rhema_engine.answers
              in
              let declared =
                try ignore (Str.search_forward (Str.regexp_string "$c->variables->are(x=>\"Real\",y=>\"Real\")") pg 0); true
                with Not_found -> false
              in
              if two_variables && not declared then fail (k ^ ": a formula answer does not declare x and y: " ^ pg);
              if two_variables && (try ignore (Str.search_forward (Str.regexp_string "{Formula('") pg 0); true with Not_found -> false) then
                fail (k ^ ": a formula answer is left in the context that knows only x: " ^ pg);
              (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p)))
    done
  done;
  List.iter (fun (k, _, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  List.iter (fun name -> if not (Hashtbl.mem asked name) then fail ("a first partial derivative was never asked in " ^ name)) [ "x"; "y" ];
  if !failures = 0 then print_endline "Rhema partial derivatives tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d partial derivatives test(s) failed." !failures);
    exit 1
  end
