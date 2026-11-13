(* Independent checks for base_conversion.rhm. The numbers are read back
   from the printed question as strings of digits with their base and
   converted here, digit by digit. An answer in decimal must be the value;
   an answer in another base, read as digits of that base, must be the
   value too, must use only digits that base has, and must be graded
   exactly: WeBWorK's usual tolerance would accept a neighbouring string of
   digits. *)

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

(* The value of a string of digits in a base; a digit the base does not
   have is an error. *)
let value_of digits base =
  String.fold_left
    (fun total character ->
      let digit =
        match character with
        | '0' .. '9' -> Char.code character - Char.code '0'
        | 'A' .. 'F' -> Char.code character - Char.code 'A' + 10
        | _ -> failwith (Printf.sprintf "not a digit: %c" character)
      in
      if digit >= base then failwith (Printf.sprintf "%c is not a digit of base %d" character base);
      (total * base) + digit)
    0 digits

(* Every number of the prompt written with its base, [`digits_{base}`] or
   [`\mathrm{digits}_{16}`], in order, as values. *)
let based p =
  let re = Str.regexp "\\[`\\(\\\\mathrm{\\)?\\([0-9A-F]+\\)}?_{\\([0-9]+\\)}`\\]" in
  let rec go start found =
    match Str.search_forward re p start with
    | exception Not_found -> List.rev found
    | _ ->
        let digits = Str.matched_group 2 p and base = int_of_string (Str.matched_group 3 p) in
        let next = Str.match_end () in
        go next ((digits, base) :: found)
  in
  go 0 []

let decimal p =
  ignore (Str.search_forward (Str.regexp "decimal number \\[`\\([0-9]+\\)`\\]") p 0);
  int_of_string (Str.matched_group 1 p)

let check (q : Rhema_engine.question) =
  let p = q.Rhema_engine.prompt and k = kind q in
  let wrong what = fail (Printf.sprintf "%s: %s, answer %s, for %S" k what q.Rhema_engine.answer_text p) in
  (* digits in another base are graded exactly; a decimal value as usual *)
  let answer, exact =
    match q.Rhema_engine.answer with
    | Rhema_engine.Num n when Rhema_number.is_integer n -> (Rhema_number.require_integer "answer" n, false)
    | Rhema_engine.Exactly n -> (Rhema_number.require_integer "answer" n, true)
    | other -> failwith ("not a whole number: " ^ Rhema_engine.describe_value other)
  in
  (* what is given, as a value, with the base it is written in *)
  let given, source =
    match (k, based p) with
    | ("binary_to_decimal" | "binary_to_octal"), [ (digits, 2) ] -> (value_of digits 2, 2)
    | ("hex_to_decimal" | "hex_to_binary"), [ (digits, 16) ] ->
        if not (String.exists (fun c -> c >= 'A') digits) then wrong "a hexadecimal number without a letter";
        (value_of digits 16, 16)
    | ("decimal_to_binary" | "decimal_to_octal"), [] -> (decimal p, 10)
    | "binary_sum", [ (first, 2); (second, 2) ] -> (value_of first 2 + value_of second 2, 2)
    | _ -> failwith "unexpected numbers in the prompt"
  in
  ignore source;
  let target =
    match k with
    | "binary_to_decimal" | "hex_to_decimal" -> 10
    | "decimal_to_binary" | "binary_sum" | "hex_to_binary" -> 2
    | "decimal_to_octal" | "binary_to_octal" -> 8
    | _ -> failwith ("unknown kind " ^ k)
  in
  if exact <> (target <> 10) then wrong "an answer in another base must be graded exactly, and only such an answer";
  if exact && not (try ignore (Str.search_forward (Str.regexp_string "->cmp(tolType=>\"absolute\",tolerance=>0.5)") (Rhema_pgml.document [ q ]) 0); true with Not_found -> false) then
    wrong "the PG answer has no absolute tolerance";
  (* the answer's decimal digits, read in the base asked for *)
  match value_of (string_of_int answer) target with
  | value -> if value <> given then wrong (Printf.sprintf "it is %d in decimal, the number given is %d" value given)
  | exception Failure message -> wrong message

let () =
  let base = load_file "base_conversion.rhm" in
  let prices =
    [ ("binary_to_decimal", 1); ("decimal_to_binary", 1); ("hex_to_decimal", 2); ("decimal_to_octal", 2);
      ("binary_to_octal", 2); ("binary_sum", 3); ("hex_to_binary", 3) ]
  in
  let seen = Hashtbl.create 8 in
  for cost = 1 to 3 do
    let spec = with_initial base "cost" cost in
    for seed = 0 to 149 do
      Random.init (seed + (1000 * cost));
      match Rhema_engine.generate spec with
      | exception Rhema_engine.Generation_error m -> fail (Printf.sprintf "cost %d seed %d: %s" cost seed m)
      | q ->
          let k = kind q in
          Hashtbl.replace seen k ();
          if List.assoc_opt k prices <> Some cost then fail (Printf.sprintf "%s at cost %d" k cost);
          if Rhema_engine.consumption q.Rhema_engine.tree "cost" <> cost then fail (k ^ " did not spend its budget");
          (try check q with e -> fail (Printf.sprintf "%s: %s for %S" k (Printexc.to_string e) q.Rhema_engine.prompt))
    done
  done;
  List.iter (fun (k, _) -> if not (Hashtbl.mem seen k) then fail ("never generated: " ^ k)) prices;
  (* The two builtins themselves, on every number they are used for. *)
  let spec name = Printf.sprintf "attribute cost = 1 split\nsynth text on Q\nsynth answer_value on Q\nstart Q\nQ -> integer_between(0, 600) {\n  cost = -1\n  text = %s\n  answer_value = $1.value\n}\nprompt \"{Q.text}\"\nanswer Q.answer_value\n" name in
  List.iter
    (fun (expression, base) ->
      let channel = open_out "base_builtin_test.rhm" in
      output_string channel (spec expression);
      close_out channel;
      (match Rhema_load.parse_file "base_builtin_test.rhm" with
      | Error errors -> List.iter (fun error -> fail (Rhema_load.string_of_failure error)) errors
      | Ok spec ->
          for seed = 0 to 199 do
            Random.init seed;
            match Rhema_engine.generate spec with
            | exception Rhema_engine.Generation_error m -> fail m
            | q -> (
                match q.Rhema_engine.answer with
                | Rhema_engine.Num n ->
                    let n = Rhema_number.require_integer "n" n in
                    if value_of q.Rhema_engine.prompt base <> n then
                      fail (Printf.sprintf "%d in base %d was written %s" n base q.Rhema_engine.prompt)
                | _ -> fail "not a number")
          done);
      Sys.remove "base_builtin_test.rhm")
    [ ("base_digits($1.value, 2)", 2); ("base_digits($1.value, 8)", 8); ("base_digits($1.value, 16)", 16);
      ("base_digits($1.value, 7)", 7); ("str(base_number($1.value, 2))", 2); ("str(base_number($1.value, 8))", 8);
      ("str(base_number($1.value, 10))", 10) ];
  if !failures = 0 then print_endline "Rhema base conversion tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d base conversion test(s) failed." !failures);
    exit 1
  end
