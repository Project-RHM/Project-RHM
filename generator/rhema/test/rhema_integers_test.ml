(* Checks for the whole-number builtins, against definitions computed the
   slow way: factorials and binomials by their recurrences, gcd by trial,
   modular powers by repeated multiplication, inverses by search. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

let expect name got wanted =
  if got <> wanted then fail (Printf.sprintf "%s: got %d, wanted %d" name got wanted)

let raises name f =
  match f () with
  | _ -> fail (name ^ " should have stopped with an error")
  | exception Rhema_number.Arithmetic_error _ -> ()

let () =
  (* factorial *)
  let slow_factorial n = List.fold_left ( * ) 1 (List.init n (fun i -> i + 1)) in
  for n = 0 to 20 do expect (Printf.sprintf "factorial %d" n) (Rhema_integers.factorial n) (slow_factorial n) done;
  raises "factorial 21" (fun () -> Rhema_integers.factorial 21);
  raises "factorial -1" (fun () -> Rhema_integers.factorial (-1));
  (* choose by Pascal's rule *)
  let table = Array.make_matrix 61 61 0 in
  for n = 0 to 60 do
    table.(n).(0) <- 1;
    for k = 1 to n do table.(n).(k) <- table.(n - 1).(k - 1) + (if k <= n - 1 then table.(n - 1).(k) else 0) done
  done;
  for n = 0 to 60 do
    for k = 0 to n + 2 do
      expect (Printf.sprintf "choose %d %d" n k) (Rhema_integers.choose n k) (if k > n then 0 else table.(n).(k))
    done
  done;
  (* permutations *)
  for n = 0 to 15 do
    for k = 0 to n + 1 do
      let wanted = if k > n then 0 else slow_factorial n / slow_factorial (n - k) in
      expect (Printf.sprintf "permutations %d %d" n k) (Rhema_integers.permutations n k) wanted
    done
  done;
  (* gcd and lcm by trial *)
  for a = -30 to 30 do
    for b = -30 to 30 do
      let trial =
        if a = 0 && b = 0 then 0
        else
          List.fold_left (fun best d -> if a mod d = 0 && b mod d = 0 then d else best) 1
            (List.init (max (abs a) (abs b)) (fun i -> i + 1))
      in
      expect (Printf.sprintf "gcd %d %d" a b) (Rhema_integers.gcd a b) trial;
      let lcm = Rhema_integers.lcm a b in
      if a <> 0 && b <> 0 then begin
        if lcm mod a <> 0 || lcm mod b <> 0 then fail (Printf.sprintf "lcm %d %d = %d is not a multiple" a b lcm);
        expect (Printf.sprintf "lcm*gcd %d %d" a b) (lcm * trial) (abs (a * b))
      end
      else expect (Printf.sprintf "lcm %d %d" a b) lcm 0
    done
  done;
  (* pow_mod by repeated multiplication *)
  for a = -12 to 12 do
    for k = 0 to 20 do
      for n = 1 to 13 do
        let slow = ref (1 mod n) in
        for _ = 1 to k do slow := (!slow * (((a mod n) + n) mod n)) mod n done;
        expect (Printf.sprintf "pow_mod %d %d %d" a k n) (Rhema_integers.pow_mod a k n) !slow
      done
    done
  done;
  raises "pow_mod modulus 0" (fun () -> Rhema_integers.pow_mod 2 3 0);
  raises "pow_mod negative exponent" (fun () -> Rhema_integers.pow_mod 2 (-1) 5);
  (* mod_inverse by search *)
  for n = 2 to 40 do
    for a = -40 to 40 do
      let search = List.find_opt (fun x -> (((a * x) mod n) + n) mod n = 1) (List.init n Fun.id) in
      match search with
      | Some x -> expect (Printf.sprintf "mod_inverse %d %d" a n) (Rhema_integers.mod_inverse a n) x
      | None -> raises (Printf.sprintf "mod_inverse %d %d" a n) (fun () -> Rhema_integers.mod_inverse a n)
    done
  done;
  (* through the language: a grammar that uses each one *)
  let source =
    {|synth value on Q
start Q
Q -> "x" { value = factorial(5) + choose(10, 3) + permutations(5, 2) + gcd(84, 36) + lcm(4, 6) + pow_mod(3, 200, 7) + mod_inverse(3, 7) }
prompt "x"
answer Q.value
|}
  in
  (match Rhema_load.parse_string ~filename:"integers.rhm" source with
  | Error errors -> List.iter (fun e -> fail (Rhema_load.string_of_failure e)) errors
  | Ok spec -> (
      match (Rhema_engine.generate spec).Rhema_engine.answer with
      | Rhema_engine.Num n -> if Rhema_number.to_string n <> string_of_int (120 + 120 + 20 + 12 + 12 + 2 + 5) then fail ("grammar total " ^ Rhema_number.to_string n)
      | other -> fail ("grammar answer " ^ Rhema_engine.describe_value other)));
  if !failures = 0 then print_endline "Rhema integer tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d integer test(s) failed." !failures);
    exit 1
  end
