(* Checks for what the commands share: how a paper's variant is derived, and
   how the library search path resolves an import that is not beside the
   importing file. *)

let failures = ref 0

let fail message =
  incr failures;
  prerr_endline ("FAIL: " ^ message)

(* An assignment is one paper; a student's paper is another; a number wins. *)
let () =
  let a = Rhema_cli.variant ~assignment:"hw1" ~student:None ~seed:None in
  if a <> Rhema_cli.variant ~assignment:"hw1" ~student:None ~seed:None then fail "an assignment is not reproducible";
  if a = Rhema_cli.variant ~assignment:"hw2" ~student:None ~seed:None then fail "two assignments share a paper";
  let s = Rhema_cli.variant ~assignment:"hw1" ~student:(Some "2330026211") ~seed:None in
  if s = a then fail "a student's paper equals the assignment's";
  if s <> Rhema_cli.variant ~assignment:"hw1" ~student:(Some "2330026211") ~seed:None then fail "a student's paper is not reproducible";
  if s = Rhema_cli.variant ~assignment:"hw1" ~student:(Some "2330026212") ~seed:None then fail "two students share a paper";
  if Rhema_cli.variant ~assignment:"hw1" ~student:(Some "x") ~seed:(Some 7) <> 7 then fail "an explicit variant should win";
  if Rhema_cli.paper ~assignment:"hw1" ~student:None <> "hw1" then fail "the assignment's paper is named after it";
  if Rhema_cli.paper ~assignment:"hw1" ~student:(Some "s") <> "hw1 for s" then fail "a student's paper names both";
  if Rhema_cli.default_assignment ~filename:"dir/calculus.rhm" ~question:(Some "integral") <> "calculus:integral" then
    fail "the default assignment should be FILE:QUESTION";
  if Rhema_cli.default_assignment ~filename:"calculus.rhm" ~question:None <> "calculus:main" then
    fail "the default question is main"

(* A file imported from another directory is found through the search path,
   and the message for a missing file names where it looked. *)
let () =
  let here = Sys.getcwd () in
  let lib = Filename.concat here "cli_lib_test" and user = Filename.concat here "cli_user_test" in
  List.iter (fun dir -> if not (Sys.file_exists dir) then Sys.mkdir dir 0o755) [ lib; user ];
  let write path content =
    let channel = open_out path in
    output_string channel content;
    close_out channel
  in
  write (Filename.concat lib "leaf.rhm") "synth value\nN -> integer(1) { value = $1.value }\n";
  let importer = Filename.concat user "uses_leaf.rhm" in
  write importer "import \"leaf.rhm\" as leaf\nsynth v\nstart M\nM -> leaf.N { v = $1.value }\nprompt \"[`{M.v}`]\"\nanswer M.v\n";
  Rhema_load.search_path := [];
  (match Rhema_load.parse_file importer with
  | Ok _ -> fail "an import away from the search path was found"
  | Error errors ->
      if not (List.exists (fun e -> let t = Rhema_load.string_of_failure e in String.length t > 0 && (try ignore (Str.search_forward (Str.regexp_string "cannot find") t 0); true with Not_found -> false)) errors)
      then fail "a missing import should say it cannot be found");
  Rhema_load.search_path := [ lib ];
  (match Rhema_load.parse_file importer with
  | Ok spec -> if List.map fst spec.Rhema_check.imports <> [ "leaf" ] then fail "the import was not resolved"
  | Error errors -> List.iter (fun e -> fail (Rhema_load.string_of_failure e)) errors);
  Rhema_load.search_path := [];
  List.iter Sys.remove [ Filename.concat lib "leaf.rhm"; importer ];
  List.iter Sys.rmdir [ lib; user ]

let () =
  if !failures = 0 then print_endline "Ag CLI tests passed."
  else begin
    prerr_endline (Printf.sprintf "%d AG CLI test(s) failed." !failures);
    exit 1
  end
