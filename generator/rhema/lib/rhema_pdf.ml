(* rhema_pdf.ml — a LaTeX document made into a PDF by a TeX engine that is
   already on the machine. rhema does not carry one: the first of pdflatex,
   xelatex, lualatex and tectonic that answers is used, or the one named by
   the environment variable RHEMA_LATEX. The engine works in a directory of
   its own, which is removed afterwards, so that nothing but the PDF is left
   beside the user's files. *)

let engines = [ "pdflatex"; "xelatex"; "lualatex"; "tectonic" ]

let null = if Sys.win32 then "NUL" else "/dev/null"

let answers engine = Sys.command (Printf.sprintf "%s --version > %s 2>&1" (Filename.quote engine) null) = 0

(* The engine to use, or why there is none. *)
let engine () =
  match Sys.getenv_opt "RHEMA_LATEX" with
  | Some named when named <> "" ->
      if answers named then Ok named
      else Error (Printf.sprintf "RHEMA_LATEX names '%s', which does not run" named)
  | _ -> (
      match List.find_opt answers engines with
      | Some found -> Ok found
      | None ->
          Error
            ("no TeX engine was found (looked for " ^ String.concat ", " engines
           ^ "); install one, or write a .tex file and compile it elsewhere"))

let read_file path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))

let write_binary path contents =
  let channel = open_out_bin path in
  Fun.protect ~finally:(fun () -> close_out channel) (fun () -> output_string channel contents)

(* A new empty directory under the system's temporary one. *)
let fresh_directory () =
  let path = Filename.temp_file "rhema" "" in
  Sys.remove path;
  Sys.mkdir path 0o700;
  path

let remove_directory path =
  (try Array.iter (fun name -> try Sys.remove (Filename.concat path name) with Sys_error _ -> ()) (Sys.readdir path)
   with Sys_error _ -> ());
  try Sys.rmdir path with Sys_error _ -> ()

(* The lines of a TeX log that say what went wrong: each line that starts
   with "!" and the two after it. *)
let errors_of_log log =
  let lines = Array.of_list (String.split_on_char '\n' log) in
  let found = ref [] in
  Array.iteri
    (fun index line ->
      if String.length line > 0 && line.[0] = '!' then
        for offset = 0 to 2 do
          if index + offset < Array.length lines then found := lines.(index + offset) :: !found
        done)
    lines;
  match List.rev !found with [] -> "(the log has no line starting with !)" | messages -> String.concat "\n" messages

(* Compile [latex] and write the PDF to [output]. On failure the PDF is not
   written and the message holds what the engine complained of. *)
let compile ~latex ~output =
  match engine () with
  | Error message -> Error message
  | Ok engine ->
      let directory = fresh_directory () in
      Fun.protect
        ~finally:(fun () -> remove_directory directory)
        (fun () ->
          let source = Filename.concat directory "paper.tex" and log = Filename.concat directory "run.log" in
          write_binary source latex;
          let command =
            if Filename.basename engine = "tectonic" then
              Printf.sprintf "%s --outdir %s %s > %s 2>&1" (Filename.quote engine) (Filename.quote directory)
                (Filename.quote source) (Filename.quote log)
            else
              Printf.sprintf "%s -interaction=nonstopmode -halt-on-error -output-directory %s %s > %s 2>&1"
                (Filename.quote engine) (Filename.quote directory) (Filename.quote source) (Filename.quote log)
          in
          let status = Sys.command command in
          let pdf = Filename.concat directory "paper.pdf" in
          if status = 0 && Sys.file_exists pdf then begin
            write_binary output (read_file pdf);
            Ok engine
          end
          else
            let log = try read_file log with Sys_error _ -> "" in
            Error (Printf.sprintf "%s could not compile the paper:\n%s" engine (errors_of_log log)))
