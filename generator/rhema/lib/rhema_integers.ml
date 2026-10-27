(* rhema_integers.ml -- whole-number functions for counting and number
   theory: factorial, binomial coefficients, permutations, gcd, lcm, modular
   powers and inverses.

   Values are OCaml native integers (63 bits). Every function checks its
   range and raises Arithmetic_error with a message naming the call rather
   than overflowing silently: a question whose numbers run out of range is
   a grammar mistake the author should see. *)

let error message = raise (Rhema_number.Arithmetic_error message)

(* 20! is the largest factorial below 2^62. *)
let factorial n =
  if n < 0 then error (Printf.sprintf "factorial(%d): the argument must not be negative" n);
  if n > 20 then error (Printf.sprintf "factorial(%d): too large; the largest is factorial(20)" n);
  let rec go accumulator k = if k <= 1 then accumulator else go (accumulator * k) (k - 1) in
  go 1 n

let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

(* Multiply step by step, dividing as soon as possible, so the intermediate
   values stay as small as the result allows. *)
let choose n k =
  if n < 0 || k < 0 then error (Printf.sprintf "choose(%d, %d): arguments must not be negative" n k);
  if k > n then 0
  else begin
    let k = min k (n - k) in
    let result = ref 1 in
    for i = 1 to k do
      let numerator = n - k + i in
      let g = gcd !result i in
      let reduced = !result / g and divisor = i / g in
      if reduced > max_int / numerator then
        error (Printf.sprintf "choose(%d, %d): the result is too large" n k);
      result := reduced * numerator / divisor
    done;
    !result
  end

let permutations n k =
  if n < 0 || k < 0 then
    error (Printf.sprintf "permutations(%d, %d): arguments must not be negative" n k);
  if k > n then 0
  else begin
    let result = ref 1 in
    for factor = n - k + 1 to n do
      if !result > max_int / factor then
        error (Printf.sprintf "permutations(%d, %d): the result is too large" n k);
      result := !result * factor
    done;
    !result
  end

let lcm a b =
  if a = 0 || b = 0 then 0
  else begin
    let a = abs a and b = abs b in
    let reduced = a / gcd a b in
    if reduced > max_int / b then error (Printf.sprintf "lcm(%d, %d): the result is too large" a b);
    reduced * b
  end

let normalize a n = ((a mod n) + n) mod n

(* a^k mod n by repeated squaring; the result lies in [0, n). *)
let pow_mod a k n =
  if n <= 0 then error (Printf.sprintf "pow_mod(%d, %d, %d): the modulus must be positive" a k n);
  if k < 0 then error (Printf.sprintf "pow_mod(%d, %d, %d): the exponent must not be negative" a k n);
  if n > 3037000499 then
    error (Printf.sprintf "pow_mod(%d, %d, %d): the modulus is too large" a k n);
  let rec go base exponent accumulator =
    if exponent = 0 then accumulator
    else
      let accumulator = if exponent land 1 = 1 then accumulator * base mod n else accumulator in
      go (base * base mod n) (exponent lsr 1) accumulator
  in
  go (normalize a n) k (1 mod n)

(* The x in [0, n) with a x = 1 (mod n), by the extended Euclidean algorithm. *)
let mod_inverse a n =
  if n <= 1 then error (Printf.sprintf "mod_inverse(%d, %d): the modulus must be at least 2" a n);
  let rec extended r0 r1 s0 s1 =
    if r1 = 0 then (r0, s0) else
      let q = r0 / r1 in
      extended r1 (r0 - (q * r1)) s1 (s0 - (q * s1))
  in
  let g, s = extended (normalize a n) n 1 0 in
  if g <> 1 then
    error (Printf.sprintf "mod_inverse(%d, %d): %d has no inverse modulo %d (their gcd is %d)" a n a n g);
  normalize s n

let apply name arguments =
  match (name, arguments) with
  | "factorial", [ n ] -> factorial n
  | "choose", [ n; k ] -> choose n k
  | "permutations", [ n; k ] -> permutations n k
  | "gcd", [ a; b ] -> gcd a b
  | "lcm", [ a; b ] -> lcm a b
  | "pow_mod", [ a; k; n ] -> pow_mod a k n
  | "mod_inverse", [ a; n ] -> mod_inverse a n
  | _ -> error (Printf.sprintf "%s: wrong number of arguments" name)
