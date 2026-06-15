let read_all channel =
  let buffer = Buffer.create 4096 in
  (try
     while true do
       Buffer.add_string buffer (input_line channel);
       Buffer.add_char buffer '\n'
     done
   with End_of_file -> ());
  Buffer.contents buffer

let usage () =
  prerr_endline "Usage: dune exec ./visualize.exe -- [input.pg|-] [output.html]";
  exit 2

let () =
  let input_path, output_path =
    match Array.to_list Sys.argv with
    | [_; input] -> (input, "ast_dcst_visualization.html")
    | [_; input; output] -> (input, output)
    | _ -> usage ()
  in
  let source =
    if input_path = "-" then read_all stdin
    else
      let channel = open_in input_path in
      let contents = read_all channel in
      close_in channel;
      contents
  in
  try Visualization.write_source_html output_path source with
  | Failure message ->
      prerr_endline message;
      exit 1
