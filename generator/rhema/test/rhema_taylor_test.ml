(* Independent checks for taylor.rhm. The function and the degree are read
   back from the printed question, and the function is computed by the
   floating-point library. The Taylor polynomial T of degree n at 0 is the
   only polynomial of degree at most n with f(x) - T(x) = o(x^n), so the
   answer must have degree at most n and (f(h) - T(h)) / h^n must shrink as
   h does: a wrong coefficient of x^j leaves a term of size h^(j-n), which
   does not. *)

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

let () =
  let base = load_file "taylor.rhm" in
  let prices =
    [ ("exponential", 1); ("geometric", 1); ("sine", 2); ("cosine", 2); ("logarithm", 2); ("product", 3);
      ("square_argument", 3) ]
  in
  let seen = Hashtbl.create 8 and degrees = Hashtbl.create 8 in
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
