(* Independent checks for polynomial_expand.ag.

   The question is read back from its printed form: each bracketed group is
   a factor, an optional ^{n} its multiplicity. The factors' polynomials are
   taken from the leaves of the derivation in order, so the product of their
   values at a point, with those multiplicities, is an independent oracle
   for the answer, which the engine built by multiplying polynomials. The
   same reading re-prices the question. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let load_file filename =
  match Ag_load.parse_file filename with
  | Ok spec -> spec
  | Error errors ->
      List.iter (fun error -> fail (Ag_load.string_of_failure error)) errors;
      exit 1

let with_initial spec name value =
  match Ag_check.with_initial spec name value with
  | Ok changed -> changed
  | Error message ->
      fail message;
      spec

let polynomial_answer question =
  match question.Ag_engine.answer with
  | Ag_engine.Polynomial polynomial -> polynomial
  | other ->
      fail ("answer expected a polynomial, got " ^ Ag_engine.describe_value other);
      Ag_polynomial.zero ~variable:"x"

(* The L leaves of the derivation, left to right. *)
let rec leaves (node : Ag_engine.node) =
  if node.symbol = "L" then
    match Ag_engine.attribute node "poly" with
    | Ag_engine.Polynomial polynomial -> [ polynomial ]
    | _ -> fail "an L node carries no polynomial"; []
  else List.concat_map leaves node.children

let expression_of_prompt prompt =
  match (String.index_opt prompt '`', String.rindex_opt prompt '`') with
  | Some first, Some last when last > first ->
      String.sub prompt (first + 1) (last - first - 1)
  | _ -> fail ("no [`...`] found in: " ^ prompt); ""

(* (text inside the brackets, multiplicity) for each bracketed group. *)
let groups text =
  let length = String.length text in
  let rec scan index found =
    if index >= length then List.rev found
    else if text.[index] = '(' then begin
      let close = String.index_from text index ')' in
      let inner = String.sub text (index + 1) (close - index - 1) in
      let after = close + 1 in
      if after + 3 < length && text.[after] = '^' && text.[after + 1] = '{' then
        let digit = Char.code text.[after + 2] - Char.code '0' in
        scan (after + 4) ((inner, digit) :: found)
      else scan after ((inner, 1) :: found)
    end
    else scan (index + 1) found
  in
  scan 0 []

let contains text fragment =
  let rec search index =
    index + String.length fragment <= String.length text
    && (String.sub text index (String.length fragment) = fragment || search (index + 1))
  in
  search 0

let base_price inner =
  if contains inner "x^{2}" then 2
  else if String.length inner > 0 && inner.[0] = 'x' then 0
  else 1

let power_price = function 1 -> 0 | 2 -> 1 | 3 -> 2 | _ -> -1000

let () =
  let base = load_file "polynomial_expand.ag" in
  let seen_bases = Hashtbl.create 3 and seen_powers = Hashtbl.create 3 in
  for cost = 1 to 10 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 29 do
      Random.init (seed + (cost * 1000));
      match Ag_engine.generate spec with
      | exception Ag_engine.Generation_error message ->
          fail (Printf.sprintf "cost %d seed %d: %s" cost seed message)
      | question ->
          let spent = Ag_engine.consumption question.Ag_engine.tree "cost" in
          if spent <> cost then fail (Printf.sprintf "cost %d: the tree spent %d" cost spent);
          let text = expression_of_prompt question.Ag_engine.prompt in
          let parts = groups text and factors = leaves question.Ag_engine.tree in
          if List.length parts <> List.length factors then
            fail (Printf.sprintf "cost %d seed %d: %S shows %d groups but the tree has %d factors"
                    cost seed text (List.length parts) (List.length factors));
          if List.length parts > 0 && List.length factors = List.length parts then begin
            let answer = polynomial_answer question in
            (* the expansion agrees with the product of the factors *)
            List.iter
              (fun x ->
                let point = Ag_number.make x 1 in
                let expected =
                  List.fold_left2
                    (fun total (_, n) factor ->
                      let value = Ag_number.to_float (Ag_polynomial.evaluate factor point) in
                      total *. (value ** float_of_int n))
                    1.0 parts factors
                in
                let actual = Ag_number.to_float (Ag_polynomial.evaluate answer point) in
                if Float.abs (expected -. actual) > 1e-6 *. Float.max 1. (Float.abs expected) then
                  fail (Printf.sprintf "cost %d seed %d: %S expands to %s, not what its factors give at x = %d"
                          cost seed text (Ag_polynomial.to_pg answer) x))
              [ -3; -1; 0; 2; 5 ];
            (* the degree is the sum of the factors' degrees *)
            let degree =
              List.fold_left (fun total (inner, n) -> total + n * (if contains inner "x^{2}" then 2 else 1)) 0 parts
            in
            (match Ag_polynomial.degree answer with
            | Some found when found = degree -> ()
            | _ -> fail (Printf.sprintf "cost %d seed %d: %S has the wrong degree" cost seed text));
            (* a single factor is nothing to expand *)
            if List.length parts = 1 && snd (List.hd parts) = 1 then
              fail (Printf.sprintf "cost %d seed %d: %S is a single factor" cost seed text);
            (* re-pricing *)
            let priced =
              (2 * (List.length parts - 1))
              + List.fold_left (fun total (inner, n) -> total + power_price n + base_price inner) 0 parts
            in
            if priced <> cost then
              fail (Printf.sprintf "cost %d seed %d: %S re-prices as %d" cost seed text priced);
            List.iter (fun (inner, n) -> Hashtbl.replace seen_bases (base_price inner) true; Hashtbl.replace seen_powers n true) parts
          end
    done
  done;
  List.iter (fun price -> if not (Hashtbl.mem seen_bases price) then fail (Printf.sprintf "no factor of price %d was generated" price)) [ 0; 1; 2 ];
  List.iter (fun n -> if not (Hashtbl.mem seen_powers n) then fail (Printf.sprintf "no multiplicity %d was generated" n)) [ 1; 2; 3 ];
  if !failures = 0 then print_endline "Ag polynomial expansion tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG polynomial expansion test(s) failed." !failures);
    exit 1
  end
