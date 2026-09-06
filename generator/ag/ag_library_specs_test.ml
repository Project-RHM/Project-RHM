(* Exercise each shipped library example against independent mathematical
   formulas, including every single mode and mixed generation. *)
let check condition message = if not condition then failwith message

let close label expected actual =
  check (Float.is_finite actual && abs_float (expected -. actual) <= 1e-8 *. max 1.0 (abs_float expected))
    (Printf.sprintf "%s: expected %.12g, got %.12g" label expected actual)

let number = function
  | Ag_engine.Num n -> n
  | value -> failwith ("expected number: " ^ Ag_engine.describe_value value)

let global q name = List.assoc name q.Ag_engine.globals |> number
let float q name = Ag_number.to_float (global q name)
let kind q = match Ag_engine.attribute q.Ag_engine.tree "kind" with
  | Ag_engine.Text value -> value
  | _ -> failwith "missing kind"

let eval_answer q x = match q.Ag_engine.answer with
  | Ag_engine.Formula f -> Ag_formula.evaluate ~variable:"x" ~at:x f
  | Ag_engine.Polynomial p ->
      (* Independent evaluation of coefficient storage, without Polynomial.evaluate. *)
      Ag_polynomial.coefficients p
      |> List.mapi (fun degree c -> Ag_number.to_float c *. x ** float_of_int degree)
      |> List.fold_left ( +. ) 0.0
  | value -> Ag_number.to_float (number value)

let formula_oracle q =
  let a = float q "a" and b = float q "b" and c = float q "c" in
  List.iter (fun x ->
    let expected = match kind q with
      | "quotient" -> (a *. (x *. x +. b) -. (a *. x +. c) *. 2.0 *. x) /. ((x *. x +. b) ** 2.0)
      | "logarithm" -> 2.0 *. x /. (x *. x +. b)
      | "radical" -> x /. sqrt (x *. x +. b)
      | "tangent" -> a /. ((cos (a *. x)) ** 2.0)
      | "composition" -> ((a *. x +. c) ** 2.0) +. c *. (a *. x +. c)
      | "combined" -> exp x *. sin (a *. x) +. a *. exp x *. cos (a *. x) +. sin x
      | _ -> failwith "unexpected Formula kind"
    in close (kind q) expected (eval_answer q x)
  ) [-0.2; 0.0; 0.13; 0.3]

let polynomial_oracle q =
  let a = float q "a" and b = float q "b" and c = float q "c"
  and n = float q "exponent" and point = float q "point" in
  List.iter (fun x ->
    let expected = match kind q with
      | "evaluation" -> a *. point *. point +. b *. point +. c
      | "expansion" -> ((a *. x +. b) ** n) *. (x +. c)
      | "coefficient" -> c *. (a ** n) +. n *. (a ** (n -. 1.0)) *. b
      | "derivative" -> n *. a *. ((a *. x +. b) ** (n -. 1.0)) *. (x +. c) +. ((a *. x +. b) ** n)
      | "degree" -> 2.0
      | _ -> failwith "unexpected Polynomial kind"
    in close (kind q) expected (eval_answer q x)
  ) [-2.0; -0.5; 0.0; 0.75; 2.0]

let linear_oracle q =
  let root = global q "root" in
  check (Ag_number.equal root (number q.Ag_engine.answer)) "linear root differs from intended root";
  let x = Ag_number.to_float root in
  let a = float q "a" and b = float q "b" and c = float q "c"
  and shift = float q "shift" and d = float q "d"
  and den = float q "denominator" in
  let lhs, rhs = match kind q with
    | "one_bracket" -> (a *. (x +. b), c *. x +. d)
    | "two_brackets" -> (a *. (x +. b), c *. (x +. shift) +. float q "offset")
    | "fraction" -> (a *. (x +. b) /. den, c *. x +. float q "fraction_offset" /. den)
    | _ -> failwith "unexpected Linear kind"
  in close (kind q) lhs rhs

let quadratic_oracle q =
  let expected = match kind q with
    | "two_integer_roots" -> [global q "root"; global q "second_root"]
    | "repeated_root" -> [global q "root"]
    | "two_rational_roots" -> [global q "rational_root"; global q "rational_second"]
    | "no_real_roots" -> []
    | _ -> failwith "unexpected Quadratic kind"
  in
  let expected = List.sort_uniq Ag_number.compare expected in
  match q.Ag_engine.answer with
  | Ag_engine.Set (Ag_set.Finite actual) ->
      check (List.length expected = List.length actual && List.for_all2 Ag_number.equal expected actual)
        ("incorrect solution set for " ^ kind q)
  | _ -> failwith "quadratic answer is not a finite set"

let cases = [
  ("library_formula", ["quotient"; "logarithm"; "radical"; "tangent"; "composition"; "combined"], formula_oracle);
  ("library_polynomial", ["evaluation"; "expansion"; "coefficient"; "derivative"; "degree"], polynomial_oracle);
  ("library_linear", ["one_bracket"; "two_brackets"; "fraction"], linear_oracle);
  ("library_quadratic", ["two_integer_roots"; "repeated_root"; "two_rational_roots"; "no_real_roots"], quadratic_oracle)
]

let load filename = match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors -> failwith (String.concat "\n" (List.map Ag_load.string_of_failure errors))

let contains text fragment =
  let rec loop i = i + String.length fragment <= String.length text &&
    (String.sub text i (String.length fragment) = fragment || loop (i + 1)) in
  loop 0

let () =
  let total = ref 0 in
  List.iter (fun (name, kinds, oracle) ->
    let original = load (name ^ ".ag") in
    for mode = 0 to List.length kinds do
      let spec = match Ag_check.with_initial original "question_mode" mode with
        | Ok spec -> spec | Error message -> failwith message in
      let seen = Hashtbl.create 8 in
      for seed = 0 to 99 do
        Random.init seed;
        let q = Ag_engine.generate spec in
        (try oracle q with Failure message -> failwith
          (Printf.sprintf "%s mode=%d seed=%d: %s" name mode seed message));
        Hashtbl.replace seen (kind q) ();
        if mode > 0 then check (kind q = List.nth kinds (mode - 1)) "single-mode selected wrong rule";
        let pg = Ag_pgml.document ~context:spec.context [q] in
        check (contains pg "BEGIN_PGML" && contains pg "END_PGML" && contains pg "[_____]") "missing PGML structure";
        Random.init seed;
        let repeat = Ag_engine.generate spec in
        check (q.prompt = repeat.prompt && q.answer_text = repeat.answer_text) "seed is not deterministic";
        incr total
      done;
      if mode = 0 then List.iter (fun k -> check (Hashtbl.mem seen k) ("mixed mode missed " ^ k)) kinds;
      Random.init 21;
      let q = Ag_engine.generate spec in
      let tree = Ag_visualization.question_json 0 q in
      check (contains tree "production" && contains tree "attributes") "missing native tree";
      (* Optional CLI argument exports one real example for every mode. *)
      if Array.length Sys.argv = 2 then begin
        let path = Filename.concat Sys.argv.(1) (Printf.sprintf "%s_mode_%d.pg" name mode) in
        let channel = open_out path in
        Fun.protect ~finally:(fun () -> close_out channel)
          (fun () -> output_string channel (Ag_pgml.document ~context:spec.context [q]))
      end
    done;
    Printf.printf "%s: mixed and %d single modes passed.\n" name (List.length kinds)
  ) cases;
  Printf.printf "%d generated questions checked, plus deterministic replay, PGML and native trees.\n" !total
