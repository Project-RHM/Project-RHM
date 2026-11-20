(* Independent checks for modular_arithmetic.rhm. The numbers are read back
   from the printed question and every answer is found again by going
   through all the candidates, in whole numbers only:

   - Euler's function of n is the count of the integers from 1 to n whose
     greatest common divisor with n, by Euclid's algorithm, is 1; n is a
     product of two different primes, or a prime power up to 400;
   - the number of divisors and their sum come from trying every integer
     from 1 to n; n has two prime factors and is more than their product,
     up to 2000 for the count and 1000 for the sum;
   - a system of congruences is tried on every x of the range asked for:
     exactly one satisfies them all and it is the answer; the range is the
     product of the moduli, which are coprime in pairs, each remainder is
     below its modulus and the remainders are not all the same number;
   - an RSA key (two blanks): n is the product of two different primes, the
     range for d is (p - 1)(q - 1), exactly one d of that range has
     e d = 1 modulo it and it is the first answer, and d is not e; the
     second answer m is below n, m^e is the printed c modulo n and c^d is m
     again, both powers by repeated multiplication, and c is not m. *)

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

(* An answer that is a whole number. *)
let whole = function
  | Rhema_engine.Num n when Rhema_number.is_integer n -> int_of_string (Rhema_number.to_string n)
  | other -> failwith ("not a whole number: " ^ Rhema_engine.describe_value other)

(* Every match of a regular expression, as the whole numbers of its groups. *)
let matches re groups text =
  let re = Str.regexp re in
  let rec go start found =
    match Str.search_forward re text start with
    | exception Not_found -> List.rev found
    | _ ->
        let next = Str.match_end () in
        let row = List.init groups (fun i -> int_of_string (Str.matched_group (i + 1) text)) in
        go next (row :: found)
  in
  go 0 []

(* The number of a pattern that the question must show exactly once. *)
let one re text =
  match matches re 1 text with
  | [ [ n ] ] -> n
  | found -> failwith (Printf.sprintf "%d matches of %s" (List.length found) re)

(* The numbers the question shows on their own, [`15`], in order. *)
let plain text = List.concat (matches "\\[`\\([0-9]+\\)`\\]" 1 text)

(* How many times a piece of text is in the question. *)
let occurrences piece text =
  Str.full_split (Str.regexp_string piece) text
  |> List.filter (function Str.Delim _ -> true | Str.Text _ -> false)
  |> List.length

let contains piece text = occurrences piece text > 0

let rec gcd a b = if b = 0 then a else gcd b (a mod b)

let from_to low high = List.init (max 0 (high - low + 1)) (fun i -> low + i)

let totient n = List.length (List.filter (fun k -> gcd k n = 1) (from_to 1 n))

let divisors n = List.filter (fun d -> n mod d = 0) (from_to 1 n)

let is_prime n = n >= 2 && List.for_all (fun d -> n mod d <> 0) (from_to 2 (n - 1))

(* The primes of n with their exponents, by trial division. *)
let factors n =
  let rec strip n p a = if n mod p = 0 then strip (n / p) p (a + 1) else (n, a) in
  let rec go n p found =
    if n = 1 then List.rev found
    else
      let rest, a = strip n p 0 in
      go rest (p + 1) (if a > 0 then (p, a) :: found else found)
  in
  go n 2 []

(* base^exponent modulo m, one multiplication at a time. *)
let power_mod base exponent m =
  let result = ref (1 mod m) in
  for _ = 1 to exponent do
    result := !result * base mod m
  done;
  !result

let rec coprime_in_pairs = function
  | [] -> true
  | m :: rest -> List.for_all (fun n -> gcd m n = 1) rest && coprime_in_pairs rest

(* What the test saw of the forms that have more than one shape. *)
let shapes = Hashtbl.create 8

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" (kind q) what q.Rhema_engine.answer_text p) in
  let answers = List.map whole q.Rhema_engine.answers in
  match (kind q, answers) with
  | (("totient_product" | "totient_power") as k), [ got ] -> (
      let n = one "\\\\varphi(\\([0-9]+\\))" p in
      (* the words describe the same count: from 1 to n, no common factor with n other than 1 *)
      if plain p <> [ 1; n; n; 1 ] then wrong "the text is not about one number";
      if got <> totient n then wrong (Printf.sprintf "%d integers are coprime to %d" (totient n) n);
      match (k, factors n) with
      | "totient_product", [ (_, 1); (_, 1) ] -> if n <= 10 then wrong "a product of two primes that is too small"
      | "totient_power", [ (_, a) ] when a >= 2 -> if n < 8 || n > 400 then wrong "a prime power outside 8 to 400"
      | _ -> wrong "not the kind of number its form is about")
  | (("divisor_count" | "divisor_sum") as k), [ got ] -> (
      let n = match plain p with [ n; 1; again ] when again = n -> n | _ -> failwith "expected one number, 1 and itself" in
      let count = k = "divisor_count" in
      if contains "How many positive divisors" p <> count || contains "sum of all the positive divisors" p = count then
        wrong "the text asks for the other thing";
      let want = if count then List.length (divisors n) else List.fold_left ( + ) 0 (divisors n) in
      if got <> want then wrong (Printf.sprintf "recomputed %d" want);
      if n > (if count then 2000 else 1000) then wrong "the number is too large";
      match factors n with
      | [ (_, a); (_, b) ] -> if a + b < 3 then wrong "only a product of two primes"
      | _ -> wrong "not two prime factors")
  | (("two_congruences" | "three_congruences") as k), [ got ] ->
      let bound = one "0 \\\\le x < \\([0-9]+\\)" p in
      let system =
        matches "x \\\\equiv \\([0-9]+\\) \\\\pmod{\\([0-9]+\\)}" 2 p
        |> List.map (function [ r; m ] -> (r, m) | _ -> assert false)
      in
      let moduli = List.map snd system and remainders = List.map fst system in
      if List.length system <> (if k = "two_congruences" then 2 else 3) then wrong "the wrong number of congruences";
      if occurrences "\\pmod" p <> List.length system then wrong "a congruence that was not read";
      if List.exists (fun m -> m < 2) moduli then wrong "a modulus below 2";
      if not (coprime_in_pairs moduli) then wrong "moduli with a common factor";
      if bound <> List.fold_left ( * ) 1 moduli then wrong "the range is not the product of the moduli";
      if List.exists (fun (r, m) -> r >= m) system then wrong "a remainder that is not below its modulus";
      if List.length (List.sort_uniq compare remainders) < 2 then wrong "every remainder is the same number";
      (* the solution may be anywhere in the range, its last fifth included *)
      if 5 * got >= 4 * bound then Hashtbl.replace shapes (Printf.sprintf "%s below %d, in the last fifth" k bound) ();
      let solutions = List.filter (fun x -> List.for_all (fun (r, m) -> x mod m = r) system) (from_to 0 (bound - 1)) in
      if solutions <> [ got ] then
        wrong (Printf.sprintf "the solutions in the range are [%s]" (String.concat "; " (List.map string_of_int solutions)));
      List.iter (fun m -> if m mod 2 = 0 then Hashtbl.replace shapes (Printf.sprintf "%s with modulus %d" k m) ()) moduli
  | "rsa", [ d; m ] ->
      let prime_p, prime_q, n =
        match matches "n = \\([0-9]+\\) \\\\cdot \\([0-9]+\\) = \\([0-9]+\\)" 3 p with
        | [ [ a; b; n ] ] -> (a, b, n)
        | _ -> failwith "expected one modulus n = p q"
      in
      let e = one "\\[`e = \\([0-9]+\\)`\\]" p in
      let bound = one "0 < d < \\([0-9]+\\)" p in
      let modulus = one "e d \\\\equiv 1 \\\\pmod{\\([0-9]+\\)}" p in
      let c = one "\\[`c = \\([0-9]+\\)`\\]" p in
      if n <> prime_p * prime_q then wrong "n is not the product shown";
      if not (is_prime prime_p && is_prime prime_q) then wrong "a factor of n that is not prime";
      if prime_p = prime_q then wrong "the same prime twice";
      if bound <> (prime_p - 1) * (prime_q - 1) then wrong "the range for d is not (p - 1)(q - 1)";
      if modulus <> bound then wrong "the congruence for d is not modulo (p - 1)(q - 1)";
      let inverses = List.filter (fun d -> e * d mod bound = 1) (from_to 1 (bound - 1)) in
      if inverses <> [ d ] then
        wrong (Printf.sprintf "the exponents in the range are [%s]" (String.concat "; " (List.map string_of_int inverses)));
      if d = e then wrong "the private exponent is the public one";
      if e >= bound then wrong "a public exponent that is not below (p - 1)(q - 1)";
      if e = prime_p || e = prime_q then wrong "the public exponent is one of the two primes";
      if m < 0 || m >= n then wrong "a message that is not below n";
      if c < 0 || c >= n then wrong "a cipher that is not below n";
      if power_mod m e n <> c then wrong (Printf.sprintf "the message enciphers to %d" (power_mod m e n));
      if power_mod c d n <> m then wrong (Printf.sprintf "the cipher deciphers to %d" (power_mod c d n));
      if c = m then wrong "the cipher is the message";
      (* the blank for d comes before the one for the message *)
      (match Str.full_split (Str.regexp_string "[___]") p with
      | [ Str.Text before; Str.Delim _; Str.Text between; Str.Delim _ ] ->
          if not (contains "private exponent" before && contains "decipher" between) || contains "decipher" before then
            wrong "the blanks are not after their own questions"
      | _ -> wrong "the two blanks are not where they should be")
  | k, _ -> fail (Printf.sprintf "%s: unknown kind, or the wrong number of answers, for %S" k p)

let () =
  let base = load_file "modular_arithmetic.rhm" in
  let prices =
    [ ("totient_product", 1); ("totient_power", 1); ("divisor_count", 1); ("two_congruences", 2); ("divisor_sum", 2);
      ("three_congruences", 3); ("rsa", 3) ]
  in
  let seen = Hashtbl.create 8 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          let k = kind q and p = q.Rhema_engine.prompt in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          (* Every form places its own blanks: one, or two for the RSA key. *)
          let blanks = if k = "rsa" then 2 else 1 in
          if List.length q.Rhema_engine.answers <> blanks then
            fail (Printf.sprintf "%s has %d blanks" k (List.length q.Rhema_engine.answers));
          if occurrences "[___]" p <> blanks then fail (Printf.sprintf "%s shows %d blanks: %S" k (occurrences "[___]" p) p);
          (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) p))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  (* The widest range, of the moduli 8, 9 and 11, is rare: more questions at
     price 3, checked in the same way, until its end has been reached. *)
  let spec = with_initial base "cost" 3 in
  for seed = 150 to 2999 do
    Random.init (seed + 3000);
    match Rhema_engine.generate spec with
    | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost 3 seed %d: %s" seed m)
    | q -> ( try check q with e -> fail (Printf.sprintf "%s: %s for %S" (kind q) (Printexc.to_string e) q.Rhema_engine.prompt))
  done;
  (* the third modulus of a system of three is 4 in some questions and 8 in others *)
  List.iter
    (fun shape -> if not (Hashtbl.mem shapes shape) then fail ("never generated: " ^ shape))
    [ "three_congruences with modulus 4"; "three_congruences with modulus 8";
      "three_congruences below 792, in the last fifth" ];
  if !failures = 0 then print_endline "Rhema modular arithmetic tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d modular arithmetic test(s) failed." !failures);
    exit 1
  end
