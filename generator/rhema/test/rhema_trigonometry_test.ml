(* Independent checks for trigonometry.rhm. Angles and values are read back
   from the printed question as floating-point numbers and the functions of
   the standard library are used. A conversion is checked against
   180 degrees = pi; an exact value against the function at the printed
   angle; the other functions of an angle against the angle found in the
   stated quadrant; and the solutions of an equation against a scan of the
   whole interval, which must find exactly the two answered, in order. A
   value or an angle that could be typed back as a function must be a plain
   answer. *)

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

(* The groups of the first match, read at once. *)
let groups re text =
  ignore (Str.search_forward (Str.regexp re) text 0);
  Array.init 8 (fun n -> try Some (Str.matched_group n text) with Not_found | Invalid_argument _ -> None)

let present g n = match g.(n) with Some s -> s | None -> ""

(* An exact number as it is written in LaTeX here: a whole number, \sqrt{n},
   \frac{a}{b} with a and b either of those, a multiple of \pi such as
   \frac{5\pi}{6} or 2\pi, and a minus sign in front of any of them. *)
let rec number text =
  let text = String.trim text in
  if text = "" then failwith "an empty number"
  else if text.[0] = '-' then -.number (String.sub text 1 (String.length text - 1))
  else if Str.string_match (Str.regexp "^\\\\frac{\\(.*\\)}{\\([^{}]*\\)}$") text 0 then
    let top = Str.matched_group 1 text and bottom = Str.matched_group 2 text in
    number top /. number bottom
  else if Str.string_match (Str.regexp "^\\\\sqrt{\\([0-9]+\\)}$") text 0 then sqrt (float_of_string (Str.matched_group 1 text))
  else if Str.string_match (Str.regexp "^\\([0-9]*\\)\\\\pi$") text 0 then
    (match Str.matched_group 1 text with "" -> 1. | digits -> float_of_string digits) *. pi
  else float_of_string text

let apply name x =
  match name with
  | "sin" -> sin x
  | "cos" -> cos x
  | "tan" -> tan x
  | _ -> failwith ("unknown function " ^ name)

(* What an answer comes to, and whether it is graded with functions off. *)
let value = function
  | Rhema_engine.Plain (Rhema_engine.Formula f) -> (Rhema_formula.evaluate_with (fun _ -> None) f, true)
  | Rhema_engine.Plain (Rhema_engine.Num n) -> (Rhema_number.to_float n, true)
  | Rhema_engine.Formula f -> (Rhema_formula.evaluate_with (fun _ -> None) f, false)
  | Rhema_engine.Num n -> (Rhema_number.to_float n, false)
  | other -> failwith ("not a number: " ^ Rhema_engine.describe_value other)

(* The solutions of g(x) = 0 on [0, limit), by sign changes on a fine grid
   and bisection. A jump of the tangent is a sign change between two large
   values and is not counted. *)
let solutions g limit =
  let steps = 20_000 in
  let found = ref [] in
  for i = 0 to steps - 1 do
    let a = limit *. float i /. float steps and b = limit *. float (i + 1) /. float steps in
    let ga = g a and gb = g b in
    if ga = 0. then found := a :: !found
    else if ga *. gb < 0. && Float.abs ga < 1. && Float.abs gb < 1. then begin
      let low = ref a and high = ref b in
      for _ = 1 to 60 do
        let middle = (!low +. !high) /. 2. in
        if g !low *. g middle <= 0. then high := middle else low := middle
      done;
      found := ((!low +. !high) /. 2.) :: !found
    end
  done;
  List.rev !found

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answers %s, for %S" k what q.Rhema_engine.answer_text p) in
  let answers = List.map value q.Rhema_engine.answers in
  match (k, answers) with
  | "to_radians", [ (radians, _) ] ->
      let degrees = float_of_string (present (groups "\\[`\\([0-9]+\\)\\^\\\\circ`\\]" p) 1) in
      if not (close radians (degrees *. pi /. 180.)) then wrong "not that many radians"
  | "to_degrees", [ (degrees, _) ] ->
      let radians = number (present (groups "Convert \\[`\\([^`]*\\)`\\] radians" p) 1) in
      if not (close degrees (radians *. 180. /. pi)) then wrong "not that many degrees"
  | ("first_quadrant" | "any_quadrant"), [ (answer, plain) ] ->
      let g = groups "\\[`\\\\\\(sin\\|cos\\|tan\\)\\\\left(\\(.*\\)\\\\right)`\\]" p in
      let angle = number (present g 2) in
      let expected = apply (present g 1) angle in
      if Float.abs expected > 1e6 then wrong "the tangent is not defined there";
      if Float.abs (answer -. expected) > 1e-9 then wrong (Printf.sprintf "the value is %g" expected);
      if not plain then wrong "the question could be typed back as its answer";
      let turn = angle /. pi in
      if k = "first_quadrant" && not (turn >= 0. && turn <= 0.5 +. 1e-12) then wrong "not in the first quadrant";
      if k = "any_quadrant" && turn >= 0. && turn <= 0.5 +. 1e-12 then wrong "in the first quadrant"
  | "from_one", [ (first, plain1); (tangent, plain2) ] ->
      let g = groups "in the \\(second\\|third\\|fourth\\) quadrant and \\[`\\\\\\(sin\\|cos\\) \\\\theta = \\([^`]*\\)`\\]" p in
      let given = number (present g 3) in
      (* the angle of that quadrant with the given sine or cosine *)
      let low, high =
        match present g 1 with "second" -> (pi /. 2., pi) | "third" -> (pi, 1.5 *. pi) | _ -> (1.5 *. pi, 2. *. pi)
      in
      let theta =
        match List.filter (fun x -> x > low +. 1e-9 && x < high -. 1e-9) (solutions (fun x -> apply (present g 2) x -. given) (2. *. pi)) with
        | [ theta ] -> theta
        | found -> failwith (Printf.sprintf "%d angles of that quadrant fit" (List.length found))
      in
      let other = if present g 2 = "sin" then "cos" else "sin" in
      if not (Str.string_match (Str.regexp (".*\\[`\\\\" ^ other ^ " \\\\theta = `\\]")) p 0) then wrong "the wrong function is asked for";
      if Float.abs (first -. apply other theta) > 1e-9 then wrong (Printf.sprintf "%s is %g" other (apply other theta));
      if Float.abs (tangent -. tan theta) > 1e-9 then wrong (Printf.sprintf "the tangent is %g" (tan theta));
      if not (plain1 && plain2) then wrong "an answer could be typed back with a function"
  | "equation", [ (smaller, plain1); (larger, plain2) ] ->
      let g = groups "\\[`\\\\\\(sin\\|cos\\|tan\\) \\(2\\)?x = \\([^`]*\\)`\\] with \\[`0 \\\\le x < \\([^`]*\\)`\\]" p in
      let scale = if present g 2 = "2" then 2. else 1. in
      let target = number (present g 3) and limit = number (present g 4) in
      if not (close (limit *. scale) (2. *. pi)) then wrong "the interval is not one turn of the argument";
      (match solutions (fun x -> apply (present g 1) (scale *. x) -. target) limit with
      | [ a; b ] ->
          if Float.abs (a -. smaller) > 1e-7 || Float.abs (b -. larger) > 1e-7 then
            wrong (Printf.sprintf "the solutions are %g and %g" a b)
      | found -> wrong (Printf.sprintf "%d solutions on the interval" (List.length found)));
      if not (smaller < larger) then wrong "the solutions are not in order";
      if not (plain1 && plain2) then wrong "an angle could be typed back as an inverse function"
  | _ -> wrong "unexpected answers"

let () =
  let base = load_file "trigonometry.rhm" in
  let prices =
    [ ("to_radians", 1); ("to_degrees", 1); ("first_quadrant", 1); ("any_quadrant", 2); ("from_one", 2); ("equation", 3) ]
  in
  let seen = Hashtbl.create 8 and variety = Hashtbl.create 16 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 199 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p));
          (* which function, and for an equation which argument and sign *)
          List.iter
            (fun name -> if Str.string_match (Str.regexp (".*\\\\" ^ name ^ "[ \\\\]")) p 0 then Hashtbl.replace variety (k, name) ())
            [ "sin"; "cos"; "tan" ];
          if k = "equation" then begin
            Hashtbl.replace variety (k, if Str.string_match (Str.regexp ".* 2x = ") p 0 then "2x" else "x") ();
            Hashtbl.replace variety (k, if Str.string_match (Str.regexp ".*x = -") p 0 then "negative" else "positive") ()
          end
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  List.iter
    (fun wanted -> if not (Hashtbl.mem variety wanted) then fail (Printf.sprintf "never asked: %s with %s" (fst wanted) (snd wanted)))
    [ ("first_quadrant", "sin"); ("first_quadrant", "cos"); ("first_quadrant", "tan"); ("any_quadrant", "sin");
      ("any_quadrant", "cos"); ("any_quadrant", "tan"); ("equation", "sin"); ("equation", "cos"); ("equation", "tan");
      ("equation", "x"); ("equation", "2x"); ("equation", "negative"); ("equation", "positive") ];
  if !failures = 0 then print_endline "Rhema trigonometry tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d trigonometry test(s) failed." !failures);
    exit 1
  end
