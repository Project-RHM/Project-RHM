(* Human-facing status goes to stderr. Keep stdout for command results. *)

type options = { plain : bool; no_color : bool; no_emoji : bool; verbose : bool }

let defaults = { plain = false; no_color = false; no_emoji = false; verbose = false }

let option options = function
  | "--plain" -> Some { options with plain = true }
  | "--no-color" -> Some { options with no_color = true }
  | "--no-emoji" -> Some { options with no_emoji = true }
  | "-v" | "--verbose" -> Some { options with verbose = true }
  | _ -> None

type palette = Basic | Indexed | Truecolor

type t = {
  interactive : bool;
  color : bool;
  palette : palette;
  unicode : bool;
  links : bool;
  verbose : bool;
  started : float;
  mutable last_redraw : float;
  mutable progress_open : bool;
  mutable pending_progress : (int * int) option;
  mutable quip_shown : bool;
}

let env name = Option.value ~default:"" (Sys.getenv_opt name)

let utf8_locale () =
  match List.find_opt (( <> ) "") (List.map env [ "LC_ALL"; "LC_CTYPE"; "LANG" ]) with
  | None -> false
  | Some locale ->
      let locale = String.lowercase_ascii locale in
      let normalized = String.concat "" (String.split_on_char '-' locale) in
      String.ends_with ~suffix:"utf8" (List.hd (String.split_on_char '@' normalized))

let create options =
  let term = env "TERM" and ci = String.lowercase_ascii (env "CI") in
  let interactive =
    not options.plain && term <> "" && term <> "dumb" && (ci = "" || ci = "false" || ci = "0")
    && Unix.isatty Unix.stdout && Unix.isatty Unix.stderr
  in
  let color = interactive && not options.no_color && env "NO_COLOR" = "" in
  let colorterm = String.lowercase_ascii (env "COLORTERM") in
  let palette =
    if colorterm = "truecolor" || colorterm = "24bit" || String.ends_with ~suffix:"-direct" term
    then Truecolor
    else if String.ends_with ~suffix:"256color" term then Indexed
    else Basic
  in
  let unicode = interactive && not options.no_emoji && utf8_locale () in
  let links =
    interactive
    && (List.mem (env "TERM_PROGRAM") [ "iTerm.app"; "WezTerm"; "vscode"; "ghostty"; "WarpTerminal" ]
       || Option.value ~default:0 (int_of_string_opt (env "VTE_VERSION")) >= 5000)
  in
  { interactive; color; palette; unicode; links; verbose = options.verbose; started = Unix.gettimeofday ();
    last_redraw = 0.; progress_open = false; pending_progress = None; quip_shown = false }

let paint t code text = if t.color then "\027[" ^ code ^ "m" ^ text ^ "\027[0m" else text

let orange t ((r, g, b), index) text =
  let code =
    match t.palette with
    | Truecolor -> Printf.sprintf "38;2;%d;%d;%d" r g b
    | Indexed -> Printf.sprintf "38;5;%d" index
    | Basic -> "33"
  in
  paint t code text

(* #E77500 from the Rhema logo; other banner rows are shades of this orange. *)
let brand_orange = ((231, 117, 0), 208)

let quip t ?(tag = "*") message =
  if t.interactive && not t.quip_shown then begin
    t.quip_shown <- true;
    Printf.eprintf "   %s %s\n%!" (orange t brand_orange tag) message
  end

let block_logo =
  let cell = function
    | '#' -> "\u{2588}"
    | '7' -> "\u{2557}"
    | 'F' -> "\u{2554}"
    | 'L' -> "\u{255A}"
    | 'J' -> "\u{255D}"
    | '-' -> "\u{2550}"
    | '|' -> "\u{2551}"
    | _ -> " "
  in
  let draw row =
    String.concat "" (List.init (String.length row) (fun i -> cell row.[i]))
  in
  List.map (fun (shade, row) -> (shade, draw row))
    [
      (((255, 185, 105), 215), "######7 ##7  ##7#######7###7   ###7 #####7");
      (((251, 158, 64), 214),  "##F--##7##|  ##|##F----J####7 ####|##F--##7");
      (((244, 139, 34), 208),  "######FJ#######|#####7  ##F####F##|#######|");
      (brand_orange,          "##F--##7##F--##|##F--J  ##|L##FJ##|##F--##|");
      (((202, 102, 5), 166),   "##|  ##|##|  ##|#######7##| L-J ##|##|  ##|");
      (((167, 83, 8), 130),    "L-J  L-JL-J  L-JL------JL-J     L-JL-J  L-J");
    ]

let banner t =
  if t.interactive then begin
    let logo =
      if t.unicode then
        String.concat "\n" (List.map (fun (shade, row) -> orange t shade row) block_logo)
      else orange t brand_orange "RHEMA"
    in
    Printf.eprintf "\n%s\n Math problem generator %s\n\n%!" logo Rhema_cli.version
  end

let hello t =
  banner t;
  let branch, last = if t.unicode then ("\u{251C}\u{2500}", "\u{2514}\u{2500}") else ("|-", "`-") in
  Printf.printf "%s\n\n  Q -> \"What if?\"\n" (orange t brand_orange "Hidden production discovered.");
  Printf.printf "  %s inherited:   curiosity = 1\n" branch;
  Printf.printf "  %s synthesized: question = \"What if?\"\n\n" last;
  print_endline "  Every good problem starts with a question."

(* Hide terminal controls in user-supplied paths, names, and source excerpts. *)
let safe_text text =
  let buffer = Buffer.create (String.length text) in
  let rec copy index =
    if index < String.length text then begin
      let decoded = String.get_utf_8_uchar text index in
      let length = Uchar.utf_decode_length decoded in
      let char = Uchar.to_int (Uchar.utf_decode_uchar decoded) in
      if not (Uchar.utf_decode_is_valid decoded) || char < 32 || (char >= 127 && char <= 159)
      then Buffer.add_char buffer '?'
      else Buffer.add_substring buffer text index length;
      copy (index + length)
    end
  in
  copy 0;
  Buffer.contents buffer

let path_link t path =
  let label = safe_text path in
  if not t.links || Sys.win32 then label
  else
    let path = if Filename.is_relative path then Filename.concat (Sys.getcwd ()) path else path in
    let uri = Buffer.create (String.length path + 20) in
    Buffer.add_string uri "file://localhost";
    String.iter
      (function
        | ('a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '/' | '-' | '.' | '_' | '~') as c ->
            Buffer.add_char uri c
        | c -> Printf.bprintf uri "%%%02X" (Char.code c))
      path;
    "\027]8;;" ^ Buffer.contents uri ^ "\027\\" ^ label ^ "\027]8;;\027\\"

let field t name value =
  if t.interactive then Printf.eprintf "   %-15s %s\n%!" name (safe_text value)

let stage t step label =
  if t.interactive then
    Printf.eprintf " %s %s\n%!" (orange t brand_orange (Printf.sprintf "[%d/4]" step)) label

let loaded t = stage t 2 "Syntax and semantic checks passed"
let generating t = stage t 3 "Generate questions"

let draw_progress t now done_count total =
  let width = 16 in
  let filled =
    if total <= 0 then width
    else int_of_float (float_of_int done_count /. float_of_int total *. float_of_int width)
  in
  let cell full =
    if t.unicode then (if full then "\u{2588}" else "\u{2591}") else if full then "#" else "."
  in
  let bar = String.concat "" (List.init width (fun i -> cell (i < filled))) in
  Printf.eprintf "\r       [%s]  %d / %d%!" (orange t brand_orange bar) done_count total;
  t.last_redraw <- now;
  t.progress_open <- true;
  t.pending_progress <- None

let progress t done_count total =
  if t.interactive then begin
    let now = Unix.gettimeofday () in
    if not t.progress_open || done_count = total || now -. t.last_redraw >= 0.08
    then draw_progress t now done_count total
    else t.pending_progress <- Some (done_count, total)
  end

let finish_progress t =
  if t.progress_open then begin
    Option.iter (fun (done_count, total) -> draw_progress t (Unix.gettimeofday ()) done_count total)
      t.pending_progress;
    Printf.eprintf "\n%!";
    t.progress_open <- false
  end

let summary t ~count ~variant ~explicit_seed ~paths =
  if t.interactive then begin
    let elapsed = max 0. (Unix.gettimeofday () -. t.started) in
    let mark = if t.unicode then "\u{2713}" else "OK" in
    Printf.eprintf "\n %s Generated %d question%s in %.2fs (seed %d).\n"
      (paint t "1;32" mark) count (if count = 1 then "" else "s") elapsed variant;
    List.iter (fun (kind, path) -> Printf.eprintf "   %-15s %s\n" kind (path_link t path)) paths;
    Printf.eprintf "   WeBWorK rendering and grading were not run.\n";
    if count > 0 && explicit_seed = Some 42 then
      quip t ~tag:"[42]" "The universe has the answer. Rhema brought the questions."
    else if count = 0 then
      quip t "Off-by-one avoided: exactly zero questions.";
    flush stderr
  end

(* Split from the right so locations also work with colons in paths. *)
let location text =
  let split text =
    Option.map
      (fun i -> (String.sub text 0 i, String.sub text (i + 1) (String.length text - i - 1)))
      (String.rindex_opt text ':')
  in
  let open Option in
  bind (split text) (fun (path_line, column) ->
      bind (split path_line) (fun (path, line) ->
          match (int_of_string_opt line, int_of_string_opt column) with
          | Some line, Some column when line > 0 && column > 0 -> Some (path, line, column)
          | _ -> None))

let source_excerpt t where =
  Option.iter
    (fun (path, line, column) ->
      let source =
        try
          if (Unix.stat path).Unix.st_kind <> Unix.S_REG then None
          else
            In_channel.with_open_text path (fun input ->
                let rec find n =
                  match In_channel.input_line input with
                  | Some text when n = 1 -> Some text
                  | Some _ -> find (n - 1)
                  | None -> None
                in
                find line)
        with Sys_error _ | Unix.Unix_error _ -> None
      in
      match source with
      | Some source when String.length source <= 240 ->
          let gutter = if t.unicode then "\u{2502}" else "|" in
          let show_char c = if c = '\t' then "    " else String.make 1 c in
          let text = String.concat "" (List.init (String.length source) (fun i -> show_char source.[i])) in
          let number = string_of_int line in
          Printf.eprintf "   %s %s %s\n" number gutter (safe_text text);
          (* Checker columns are byte offsets. Avoid guessing Unicode glyph widths. *)
          let prefix = String.sub source 0 (min (column - 1) (String.length source)) in
          if String.for_all (fun c -> Char.code c < 128) prefix then begin
            let spaces = String.fold_left (fun n c -> n + if c = '\t' then 4 else 1) 0 prefix in
            Printf.eprintf "   %s %s %s%s\n" (String.make (String.length number) ' ')
              gutter (String.make spaces ' ') (paint t "1;31" "^")
          end
      | _ -> ())
    (location where)

let errors t ?note ~heading failures =
  finish_progress t;
  if t.interactive then begin
    let mark = if t.unicode then "\u{2717}" else "ERROR" in
    Printf.eprintf "\n %s %s\n\n" (paint t "1;31" mark) heading
  end;
  List.iter
    (fun (failure : Rhema_load.failure) ->
      let message = Rhema_cli.describe_failure failure in
      prerr_endline (if t.interactive then safe_text message else message);
      if t.interactive then source_excerpt t failure.where)
    failures;
  if t.interactive then Option.iter (Printf.eprintf "\n   %s\n%!") note

let specification_errors t ?note failures =
  errors t ?note ~heading:"Specification check failed" failures;
  let has kind = List.exists (fun failure -> failure.Rhema_load.kind = kind) failures in
  if has Rhema_load.Syntax then quip t "You shall not parse!"
  else if has Rhema_load.Semantic then quip t "Not even wrong. This one didn't reach generation."

let trace t questions =
  if t.verbose then begin
    let attributes values describe =
      List.map (fun (name, value) -> name ^ "=" ^ describe value) values |> String.concat ", "
    in
    let show depth name value =
      Printf.eprintf "%s%s%s\n" (String.make (2 * depth) ' ') name (safe_text value)
    in
    let rec walk depth (node : Rhema_engine.node) =
      let rule =
        match node.applied_rule with
        | Some rule -> Rhema_visualization.rule_text rule
        | None -> node.symbol
      in
      show depth "" rule;
      if node.inherited_attributes <> [] then
        show (depth + 1) "Inherited: " (attributes node.inherited_attributes string_of_int);
      if node.attributes <> [] then
        show (depth + 1) "Synthesized: " (attributes node.attributes Rhema_engine.describe_value);
      List.iter (walk (depth + 1)) node.children
    in
    List.iteri
      (fun i (question : Rhema_engine.question) ->
        Printf.eprintf "\n Question %d: accepted derivation\n" (i + 1);
        if question.globals <> [] then
          show 1 "Globals: " (attributes question.globals Rhema_engine.describe_value);
        walk 1 question.tree)
      questions;
    flush stderr
  end
