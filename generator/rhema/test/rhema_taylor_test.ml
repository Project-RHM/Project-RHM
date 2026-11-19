(* Independent checks for taylor.rhm. The function and the degree are read
   back from the printed question, and the function is computed by the
   floating-point library. The Taylor polynomial T of degree n at 0 is the
   only polynomial of degree at most n with f(x) - T(x) = o(x^n), so the
   answer must have degree at most n and (f(h) - T(h)) / h^n must shrink as
   h does: a wrong coefficient of x^j leaves a term of size h^(j-n), which
   does not.

   A function built from parts (budgets 4 to 8) is read by a small parser
   into a tree. Its series is then worked out here, from the factorials and
   by multiplying series term by term, and every coefficient of the answer
   is compared with it; the tree is priced, and the price must be the
   budget; and the function the tree stands for, computed by the
   floating-point library, must agree with that series near 0. *)

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

(* The groups of the first match, read at once. *)
let groups re text =
  ignore (Str.search_forward (Str.regexp re) text 0);
  Array.init 8 (fun n -> try Some (Str.matched_group n text) with Not_found | Invalid_argument _ -> None)

let present g n = match g.(n) with Some s -> s | None -> ""

(* A number written in front of x: "" is 1, "-" is -1. *)
let coefficient = function "" -> 1. | "-" -> -1. | s -> float_of_string s

(* "+ 2" or "- " read as a signed number; absent digits are 1. *)
let signed sign digits = (if sign = "-" then -1. else 1.) *. (if digits = "" then 1. else float_of_string digits)

(* The function of the prompt, from the text after f(x) =. *)
let function_of p =
  let body = present (groups "\\[`f(x) = \\([^`]*\\)`\\]" p) 1 in
  let found re = try Some (groups re body) with Not_found -> None in
  let k = "\\(-?[0-9]*\\)" in
  match found ("^e\\^{" ^ k ^ "x}$") with
  | Some g -> let k = coefficient (present g 1) in fun x -> exp (k *. x)
  | None -> (
      match found ("^e\\^{" ^ k ^ "x\\^{2}}$") with
      | Some g -> let k = coefficient (present g 1) in fun x -> exp (k *. x *. x)
      | None -> (
          match found "^\\\\dfrac{1}{1 \\([+-]\\) \\([0-9]*\\)x}$" with
          | Some g -> let c = signed (present g 1) (present g 2) in fun x -> 1. /. (1. +. (c *. x))
          | None -> (
              match found ("^\\\\sin\\\\left(" ^ k ^ "x\\\\right)$") with
              | Some g -> let k = coefficient (present g 1) in fun x -> sin (k *. x)
              | None -> (
                  match found ("^\\\\cos\\\\left(" ^ k ^ "x\\\\right)$") with
                  | Some g -> let k = coefficient (present g 1) in fun x -> cos (k *. x)
                  | None -> (
                      match found "^\\\\ln\\\\left(1 \\([+-]\\) \\([0-9]*\\)x\\\\right)$" with
                      | Some g -> let c = signed (present g 1) (present g 2) in fun x -> log (1. +. (c *. x))
                      | None -> (
                          match found ("^\\\\left(\\(-?[0-9]+\\) \\([+-]\\) \\([0-9]*\\)x\\\\right) e\\^{" ^ k ^ "x}$") with
                          | Some g ->
                              let a = float_of_string (present g 1) and b = signed (present g 2) (present g 3) in
                              let k = coefficient (present g 4) in
                              fun x -> (a +. (b *. x)) *. exp (k *. x)
                          | None -> failwith ("unknown function " ^ body)))))))

(* ---- Functions built from parts ------------------------------------- *)

type built =
  | Base of string * float * int  (* the function, k, and the power of x in its argument *)
  | Linear of float * float * built  (* (a + bx) f *)
  | Sum of built * built
  | Product of built * built

exception Unread of string

(* Read one function from [text] at [position]; the position after it. *)
let rec read_sum text position =
  let first, position = read_product text position in
  read_more_terms text first position

and read_more_terms text so_far position =
  if position + 3 <= String.length text && String.sub text position 3 = " + " then
    let next, position = read_product text (position + 3) in
    read_more_terms text (Sum (so_far, next)) position
  else (so_far, position)

and read_product text position =
  let first, position = read_factor text position in
  read_more_factors text first position

and read_more_factors text so_far position =
  let dot = " \\cdot " in
  if position + String.length dot <= String.length text && String.sub text position (String.length dot) = dot then
    let next, position = read_factor text (position + String.length dot) in
    read_more_factors text (Product (so_far, next)) position
  else (so_far, position)

and read_factor text position =
  let at re = Str.string_match (Str.regexp re) text position in
  let group n = try Str.matched_group n text with Not_found -> "" in
  let power n = if group n = "" then 1 else 2 in
  let k = "\\(-?[0-9]*\\)x\\(\\^{2}\\)?" in
  if at "\\\\left(\\(-?[0-9]+\\) \\([+-]\\) \\([0-9]*\\)x\\\\right) " then begin
    let a = float_of_string (group 1) and b = signed (group 2) (group 3) and after = Str.match_end () in
    let inner, position = read_factor text after in
    (Linear (a, b, inner), position)
  end
  else if at ("e\\^{" ^ k ^ "}") then
    let found = Base ("exp", coefficient (group 1), power 2) in
    (found, Str.match_end ())
  else if at "\\\\dfrac{1}{1 \\([+-]\\) \\([0-9]*\\)x\\(\\^{2}\\)?}" then
    (* 1 - 2x is the function with k = 2 *)
    let found = Base ("geometric", -.signed (group 1) (group 2), power 3) in
    (found, Str.match_end ())
  else if at ("\\\\sin\\\\left(" ^ k ^ "\\\\right)") then
    let found = Base ("sin", coefficient (group 1), power 2) in
    (found, Str.match_end ())
  else if at ("\\\\cos\\\\left(" ^ k ^ "\\\\right)") then
    let found = Base ("cos", coefficient (group 1), power 2) in
    (found, Str.match_end ())
  else if at "\\\\ln\\\\left(1 \\([+-]\\) \\([0-9]*\\)x\\(\\^{2}\\)?\\\\right)" then
    let found = Base ("ln", signed (group 1) (group 2), power 3) in
    (found, Str.match_end ())
  else if at "\\\\left(" then begin
    let inner, position = read_sum text (Str.match_end ()) in
    let close = "\\right)" in
    if position + String.length close <= String.length text && String.sub text position (String.length close) = close
    then (inner, position + String.length close)
    else raise (Unread text)
  end
  else raise (Unread text)

let read_built text =
  let tree, position = read_sum text 0 in
  if position <> String.length text then raise (Unread text);
  tree

let rec value tree x =
  match tree with
  | Base (name, k, power) -> (
      let u = k *. (x ** float power) in
      match name with
      | "exp" -> exp u
      | "geometric" -> 1. /. (1. -. u)
      | "sin" -> sin u
      | "cos" -> cos u
      | _ -> log (1. +. u))
  | Linear (a, b, inner) -> (a +. (b *. x)) *. value inner x
  | Sum (l, r) -> value l x +. value r x
  | Product (l, r) -> value l x *. value r x

(* The coefficients of 1, x, ..., x^6. *)
let top_degree = 6

let rec factorial n = if n <= 1 then 1. else float n *. factorial (n - 1)

let multiply l r =
  Array.init (top_degree + 1) (fun d ->
      let total = ref 0. in
      for i = 0 to d do
        total := !total +. (l.(i) *. r.(d - i))
      done;
      !total)

let rec series = function
  | Base (name, k, power) ->
      (* the coefficient of u^j in the function of u *)
      let of_u j =
        match name with
        | "exp" -> 1. /. factorial j
        | "geometric" -> 1.
        | "sin" -> if j mod 2 = 1 then (if j mod 4 = 1 then 1. else -1.) /. factorial j else 0.
        | "cos" -> if j mod 2 = 0 then (if j mod 4 = 0 then 1. else -1.) /. factorial j else 0.
        | _ -> if j = 0 then 0. else (if j mod 2 = 1 then 1. else -1.) /. float j
      in
      Array.init (top_degree + 1) (fun d -> if d mod power = 0 then of_u (d / power) *. (k ** float (d / power)) else 0.)
  | Linear (a, b, inner) ->
      let factor = Array.make (top_degree + 1) 0. in
      factor.(0) <- a;
      factor.(1) <- b;
      multiply factor (series inner)
  | Sum (l, r) -> Array.map2 ( +. ) (series l) (series r)
  | Product (l, r) -> multiply (series l) (series r)

let rec price = function
  | Base (name, _, power) -> (if name = "exp" || name = "geometric" then 1 else 2) + if power = 2 then 2 else 0
  | Linear (_, _, inner) -> 2 + price inner
  | Sum (l, r) -> 1 + price l + price r
  | Product (l, r) -> 3 + price l + price r

let rec parts = function
  | Base (name, _, power) -> [ name ] @ if power = 2 then [ "an argument in x^2" ] else []
  | Linear (_, _, inner) -> "a linear factor" :: parts inner
  | Sum (l, r) -> ("a sum" :: parts l) @ parts r
  | Product (l, r) -> ("a product" :: parts l) @ parts r

let rec two_exponentials = function
  | Product (Base ("exp", _, _), Base ("exp", _, _)) -> true
  | Base _ -> false
  | Linear (_, _, inner) -> two_exponentials inner
  | Sum (l, r) | Product (l, r) -> two_exponentials l || two_exponentials r

let check_built ~cost ~seen_parts (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let wrong what = fail (Printf.sprintf "built: %s, answer %s, for %S" what q.Rhema_engine.answer_text p) in
  match q.Rhema_engine.answer with
  | Rhema_engine.Polynomial answer -> (
      try
        let tree = read_built (present (groups "\\[`f(x) = \\([^`]*\\)`\\]" p) 1) in
        let n = int_of_string (present (groups "of degree \\[`\\([0-9]+\\)`\\]" p) 1) in
        if price tree <> cost then wrong (Printf.sprintf "a function worth %d at budget %d" (price tree) cost);
        if two_exponentials tree then wrong "two exponentials multiplied";
        List.iter (fun part -> Hashtbl.replace seen_parts part ()) (parts tree);
        Hashtbl.replace seen_parts (Printf.sprintf "degree %d" n) ();
        if n < 3 || n > top_degree then wrong (Printf.sprintf "degree %d asked" n);
        let expected = series tree in
        (match Rhema_polynomial.degree answer with
        | Some d when d > n -> wrong (Printf.sprintf "degree %d, above %d" d n)
        | _ -> ());
        for d = 0 to n do
          let given = Rhema_number.to_float (Rhema_polynomial.coefficient answer d) in
          if Float.abs (given -. expected.(d)) > 1e-9 *. Float.max 1. (Float.abs expected.(d)) then
            wrong (Printf.sprintf "the coefficient of x^%d is %g, not %g" d given expected.(d))
        done;
        if Float.abs expected.(n) < 1e-9 then wrong (Printf.sprintf "no term of degree %d, the degree asked" n);
        if n > 4 && (Float.abs expected.(3) > 1e-9 || Float.abs expected.(4) > 1e-9) then
          wrong (Printf.sprintf "degree %d asked of a function with a term of degree 3 or 4" n);
        (* the series worked out here is the series of the function read *)
        let size = Array.fold_left (fun total c -> total +. Float.abs c) 1. expected in
        List.iter
          (fun h ->
            let partial = ref 0. in
            for d = top_degree downto 0 do
              partial := (!partial *. h) +. expected.(d)
            done;
            if Float.abs (value tree h -. !partial) > 1e-9 *. size then
              wrong (Printf.sprintf "the function and its series differ by %g at %g" (value tree h -. !partial) h))
          [ 0.01; -0.01 ]
      with
      | Unread text -> wrong ("a function this test cannot read: " ^ text)
      | e -> wrong (Printexc.to_string e))
  | _ -> wrong "not a polynomial"

let () =
  let base = load_file "taylor.rhm" in
  let prices =
    [ ("exponential", 1); ("geometric", 1); ("sine", 2); ("cosine", 2); ("logarithm", 2); ("product", 3);
      ("square_argument", 3) ]
  in
  let seen = Hashtbl.create 8 and degrees = Hashtbl.create 8 in
  let seen_parts = Hashtbl.create 16 and built_at = Hashtbl.create 8 in
  for cost = 4 to 8 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          if kind q <> "built" then fail (Printf.sprintf "%s at cost %d" (kind q) cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then
            fail (Printf.sprintf "built did not spend its budget %d" cost);
          Hashtbl.replace built_at cost ();
          check_built ~cost ~seen_parts q
    done
  done;
  for cost = 4 to 8 do
    if not (Hashtbl.mem built_at cost) then fail (Printf.sprintf "nothing built at budget %d" cost)
  done;
  List.iter
    (fun part -> if not (Hashtbl.mem seen_parts part) then fail ("never built: " ^ part))
    [ "exp"; "geometric"; "sin"; "cos"; "ln"; "an argument in x^2"; "a linear factor"; "a sum"; "a product";
      "degree 3"; "degree 4"; "degree 6" ];
  (* a budget above the highest is refused *)
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
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
          match q.Rhema_engine.answer with
          | Rhema_engine.Polynomial answer -> (
              try
                let f = function_of p in
                let n = int_of_string (present (groups "of degree \\[`\\([0-9]+\\)`\\]" p) 1) in
                Hashtbl.replace degrees (k, n) ();
                let t x = Rhema_formula.evaluate ~variable:"x" ~at:x (Rhema_polynomial.to_formula answer) in
                (match Rhema_polynomial.degree answer with
                | Some d when d > n -> wrong (Printf.sprintf "degree %d, above %d" d n)
                | _ -> ());
                let error h = Float.abs (f h -. t h) /. (Float.abs h ** float n) in
                if not (error 0.05 <= (0.7 *. error 0.1) +. 1e-7) then
                  wrong (Printf.sprintf "f - T does not vanish to order %d: %g at 0.1, %g at 0.05" n (error 0.1) (error 0.05));
                (* the same from the other side *)
                if not (error (-0.05) <= (0.7 *. error (-0.1)) +. 1e-7) then
                  wrong (Printf.sprintf "f - T does not vanish to order %d on the left" n)
              with e -> wrong (Printexc.to_string e))
          | _ -> wrong "not a polynomial")
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  (* the forms with two degrees ask for both *)
  List.iter
    (fun (k, n) -> if not (Hashtbl.mem degrees (k, n)) then fail (Printf.sprintf "%s was never asked to degree %d" k n))
    [ ("exponential", 2); ("exponential", 3); ("sine", 3); ("sine", 5); ("cosine", 2); ("cosine", 4);
      ("square_argument", 4); ("square_argument", 6) ];
  if !failures = 0 then print_endline "Rhema Taylor polynomial tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d Taylor polynomial test(s) failed." !failures);
    exit 1
  end
