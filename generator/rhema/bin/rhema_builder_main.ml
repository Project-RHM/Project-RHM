(* The form editor reads and transforms Rhema ASTs, never source substrings. *)
open Rhema_ast

let fail message = prerr_endline message; exit 1
let quote text =
  let b = Buffer.create (String.length text + 8) in
  Buffer.add_char b '"';
  String.iter (function
    | '"' -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | '\r' -> Buffer.add_string b "\\r"
    | '\t' -> Buffer.add_string b "\\t"
    | c when Char.code c < 32 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
    | c -> Buffer.add_char b c) text;
  Buffer.add_char b '"'; Buffer.contents b
let obj fields = "{" ^ String.concat "," (List.map (fun (k,v) -> quote k ^ ":" ^ v) fields) ^ "}"
let arr values = "[" ^ String.concat "," values ^ "]"
let int = string_of_int
let boolean = string_of_bool
let option f = function None -> "null" | Some x -> f x
let rhm_string text =
  "\"" ^ String.concat "" (List.map (function
    | '"' -> "\\\"" | '\\' -> "\\\\" | c -> String.make 1 c)
    (List.init (String.length text) (String.get text))) ^ "\""

let rec expression = function
  | At (_,body) -> expression body
  | Int n -> int n | Str s -> rhm_string s | Attr_here s -> s
  | Attr_child (n,a) -> Printf.sprintf "$%d.%s" n a
  | Attr_child_named (n,a) -> n ^ "." ^ a | Child n -> "$" ^ int n
  | Unary (op,e) -> "(" ^ op ^ " " ^ expression e ^ ")"
  | Binary (op,a,b) -> "(" ^ expression a ^ " " ^ op ^ " " ^ expression b ^ ")"
  | Call (name,args) -> name ^ "(" ^ String.concat ", " (List.map expression args) ^ ")"
let distribution = function Copy -> "copy" | Split -> "split"
let symbol = function
  | Symbol s -> s | Literal s -> rhm_string s
  | Generator (name,args) -> name ^ "(" ^ String.concat ", " (List.map expression args) ^ ")"
  | Module_symbol (alias,name,args) -> alias ^ "." ^ name ^ "(" ^
      String.concat ", " (List.map (fun (n,e) -> n ^ " = " ^ expression e) args) ^ ")"
let equation = function
  | Assign (name,e,_) -> "  " ^ name ^ " = " ^ expression e
  | Require (e,_) -> "  require " ^ expression e
let question_item = function
  | Q_start (s,_) -> "start " ^ s | Q_context (s,_) -> "context " ^ rhm_string s
  | Q_prompt (s,_) -> "prompt " ^ rhm_string s | Q_answer (e,_) -> "answer " ^ expression e
  | Q_width (n,_) -> "width " ^ int n | Q_default (s,n,_) -> s ^ " = " ^ int n
let budget = function
  | Fixed n -> "= " ^ int n
  | Among ns -> "in {" ^ String.concat ", " (List.map int ns) ^ "}"
  | Around {mean;spread;low;allowed} -> "~ " ^ int mean ^ " spread " ^ int spread ^ " low " ^ int low ^
      (match allowed with None -> "" | Some ns -> " allowed {" ^ String.concat ", " (List.map int ns) ^ "}")
let set_question q = (match q.sq_alias with None -> "" | Some s -> s ^ ".") ^ q.sq_name ^
  (if q.sq_draws = [] then "" else "(" ^ String.concat ", " (List.map (fun (n,d) -> n ^ " " ^ budget d) q.sq_draws) ^ ")")
let set_item = function
  | Set_part (s,_) -> "part" ^ (match s with None -> "" | Some s -> " " ^ rhm_string s)
  | Set_distinct _ -> "distinct" | Set_balanced _ -> "balanced" | Set_ordered _ -> "ordered"
  | Set_entry e -> int e.se_count ^ " of " ^ (match e.se_choices with
      | [q] -> set_question q | qs -> "any(" ^ String.concat ", " (List.map set_question qs) ^ ")")
let declaration = function
  | Inherited_decl (s,n,d,_) -> "attribute " ^ s ^ " = " ^ int n ^ " " ^ distribution d
  | Random_decl (s,d,_) -> "random " ^ s ^ " = " ^ (match d with
      | Draw_boolean -> "boolean" | Draw_generator (n,args) -> n ^ "(" ^ String.concat ", " (List.map expression args) ^ ")")
  | Let_decl (s,e,_) -> "let " ^ s ^ " = " ^ expression e
  | Synthesized_decl (s,scope,_) -> "synth " ^ s ^ (match scope with None -> "" | Some n -> " on " ^ n)
  | Start_decl (s,_) -> "start " ^ s | Context_decl (s,_) -> "context " ^ rhm_string s
  | Prompt_decl (s,_) -> "prompt " ^ rhm_string s | Answer_decl (e,_) -> "answer " ^ expression e
  | Width_decl (n,_) -> "width " ^ int n
  | Include_decl (s,_) -> "include " ^ rhm_string s
  | Import_decl (s,a,_) -> "import " ^ rhm_string s ^ " as " ^ a
  | Precedence_decl (n,a,ops,_) -> "precedence " ^ int n ^ " " ^
      (match a with Left -> "left" | Right -> "right" | Nonassoc -> "nonassoc") ^ " " ^
      String.concat " " (List.map rhm_string ops)
  | Question_decl (s,items,_) -> "question " ^ s ^ " {\n  " ^ String.concat "\n  " (List.map question_item items) ^ "\n}"
  | Set_decl s -> "set " ^ s.set_name ^ " {\n  " ^ String.concat "\n  " (List.map set_item s.set_items) ^ "\n}"
  | Rule_decl r -> r.lhs ^ " -> " ^ String.concat " " (List.map symbol r.rhs) ^
      (match r.guard with None -> "" | Some e -> " when " ^ expression e) ^
      " weight " ^ int r.weight ^ " {\n" ^ String.concat "\n" (List.map equation r.equations) ^ "\n}"

let rec unlocated = function At (_,body) -> unlocated body | expression -> expression
let rec number = function
  | At (_,body) -> number body
  | Int n -> Some n | Unary ("-",Int n) -> Some (-n) | _ -> None
let numbers args =
  let ns = List.filter_map number args in if List.length ns = List.length args then Some ns else None
let operators = ["+";"-";"*";"/";"\\cdot";"\\div";"\\land";"\\lor";"\\neg";"\\to";
  "\\leftrightarrow";"\\oplus";"\\cup";"\\cap";"\\setminus";"power";"sin";"cos";"exp";
  "ln";"sqrt";"tan";"square";"cube";"dot";"cross";"norm";"transpose";"scale"]
let operator_count rule =
  if List.exists (fun s -> List.mem (symbol_name s) operators) rule.rhs then 1 else 0
let rule_label rule =
  match List.find_map (function Assign ("kind",Str s,_) -> Some s | _ -> None) rule.equations with
  | Some s -> s
  | None -> rule.lhs ^ " -> " ^ String.concat " " (List.map symbol_name rule.rhs)

type unit_file = { key:string; path:string; spec:Rhema_check.spec; declarations:declaration list }
let load path =
  match Rhema_load.parse_file path with Ok s -> s
  | Error es -> fail (String.concat "\n" (List.map Rhema_load.string_of_failure es))
let units root =
  let found = ref [] in
  let rec walk key spec =
    if not (List.exists (fun u -> u.path = spec.Rhema_check.source) !found) then begin
      let path = spec.Rhema_check.source in
      let declarations = match Rhema_load.load_declarations ~stack:[] path with
        | Ok d -> d | Error es -> fail (String.concat "\n" (List.map Rhema_load.string_of_failure es)) in
      found := !found @ [{key;path;spec;declarations}];
      List.iter (fun (alias,s) -> walk (key ^ "." ^ alias) s) spec.Rhema_check.imports
    end
  in walk "root" root; !found

let fields u =
  let field id name kind value extra = obj (["id",quote (u.key ^ ":" ^ id);"name",quote name;
    "module",quote u.key;"kind",quote kind;"value",value] @ extra) in
  let rule_index = ref 0 in
  let rec equal_values name expression = match unlocated expression with
    | Binary ("=",left,e) when unlocated left = Attr_here name -> (match number e with Some n -> [n] | None -> [])
    | Binary (_,a,b) -> equal_values name a @ equal_values name b | _ -> [] in
  let rec mode_values name expression = match unlocated expression with
    | Binary (("="|"!="),left,e) when unlocated left = Attr_here name -> (match number e with Some n -> [n] | None -> [])
    | Binary (_,a,b) -> mode_values name a @ mode_values name b | _ -> [] in
  let cost_values =
    let rs = List.filter (fun r -> r.lhs=u.spec.Rhema_check.start) u.spec.rules in
    let values = List.map (fun r -> match r.guard with None -> [] | Some e -> equal_values "cost" e) rs in
    if values=[] || List.exists ((=) []) values then [] else List.concat values |> List.sort_uniq compare in
  List.concat_map (function
    | Inherited_decl (n,v,d,_) ->
        let allowed = if n="cost" then cost_values else if Filename.check_suffix n "mode" then
          v :: List.concat_map (fun r -> match r.guard with None -> [] | Some e -> mode_values n e) u.spec.rules |> List.sort_uniq compare
          else [] in
        [field ("a:" ^ n) n "integer" (int v) ["distribution",quote (distribution d);"allowed",arr (List.map int allowed)]]
    | Random_decl (n,Draw_boolean,_) -> [field ("b:" ^ n) n "boolean" (quote "random") []]
    | Random_decl (n,Draw_generator (generator,args),_) -> (match numbers args with
        | Some ns -> [field ("r:" ^ n) n "range" (arr (List.map int ns)) ["generator",quote generator]] | None -> [])
    | Rule_decl r ->
        let i = !rule_index in incr rule_index;
        let id = "rule:" ^ int i in
        let common = ["group",quote r.lhs;"rule",quote (rule_label r)] in
        field (id ^ ":weight") (rule_label r) "weight" (int r.weight) common ::
        List.filter_map (function
          | Assign ("cost",e,_) -> (match number e with Some n when n <= 0 ->
              Some (field (id ^ ":cost") (rule_label r) "price" (int (-n)) common) | _ -> None)
          | _ -> None) r.equations @
        List.concat (List.mapi (fun j -> function
          | Generator (g,args) -> (match numbers args with Some ns ->
              [field (id ^ ":leaf:" ^ int j) (rule_label r) "range" (arr (List.map int ns))
                (common @ ["generator",quote g])] | None -> [])
          | _ -> []) r.rhs)
    | _ -> []) u.declarations

let starts declarations = List.filter_map (function Start_decl (s,_) -> Some s
  | Question_decl (_,items,_) -> List.find_map (function Q_start (s,_) -> Some s | _ -> None) items
  | _ -> None) declarations |> List.sort_uniq compare
let describe us =
  let root = List.hd us in
  obj ["fields",arr (List.concat_map fields us);
    "questions",arr (List.map (fun q -> obj ["name",quote q.Rhema_check.q_name;"start",quote q.q_start;
      "width",option int q.q_width;"context",quote q.q_context;
      "initials",obj (List.map (fun (n,v) -> n,int v) q.q_initials)]) root.spec.questions);
    "width",option int root.spec.width;
    "length_supported",boolean (List.exists (fun u -> List.exists (function Rule_decl r -> operator_count r > 0 | _ -> false) u.declarations) us)]

let replace_all pattern replacement text =
  let size = String.length pattern in
  let b = Buffer.create (String.length text) in
  let rec go i = if i < String.length text then
    if i + size <= String.length text && String.sub text i size = pattern then
      (Buffer.add_string b replacement; go (i+size))
    else (Buffer.add_char b text.[i]; go (i+1)) in
  go 0; Buffer.contents b
let counter = "teacher_operator_count"
let pos = dummy_position
let binary op a b = Binary (op,a,b)
let wrap_length minimum maximum declarations =
  let roots = starts declarations in
  let rename name = if List.mem name roots then "Teacher_" ^ name else name in
  let rec rename_expr = function
    | At (p,e) -> At (p,rename_expr e)
    | Attr_child_named (s,a) -> Attr_child_named (rename s,a)
    | Unary (op,e) -> Unary (op,rename_expr e)
    | Binary (op,a,b) -> Binary (op,rename_expr a,rename_expr b)
    | Call (n,args) -> Call (n,List.map rename_expr args) | e -> e in
  let template text =
    let pieces, errors = Rhema_check.parse_template pos text in
    if errors <> [] then fail "Cannot read this question's prompt";
    String.concat "" (List.map (function
      | Rhema_check.Text s -> replace_all "}" "}}" (replace_all "{" "{{" s)
      | Hole (s,a) -> "{" ^ rename s ^ "." ^ a ^ "}"
      | Value_hole s -> "{" ^ s ^ "}"
      | Answer_hole (s,a) -> "{answer " ^ rename s ^ "." ^ a ^ "}"
      | Answer_value_hole s -> "{answer " ^ s ^ "}") pieces) in
  let rewritten = List.map (function
    | Start_decl (s,p) -> Start_decl (rename s,p)
    | Prompt_decl (s,p) -> Prompt_decl (template s,p)
    | Answer_decl (e,p) -> Answer_decl (rename_expr e,p)
    | Question_decl (n,items,p) -> Question_decl (n,List.map (function
        | Q_start (s,p) -> Q_start (rename s,p) | Q_prompt (s,p) -> Q_prompt (template s,p)
        | Q_answer (e,p) -> Q_answer (rename_expr e,p) | x -> x) items,p)
    | d -> d) declarations in
  let wrappers = List.concat_map (fun root ->
    let attributes = declarations |> List.filter_map (function
      | Synthesized_decl (n,None,_) -> Some n
      | Synthesized_decl (n,Some s,_) when s = root -> Some n | _ -> None) |> List.sort_uniq compare in
    let declared = List.map (fun n -> Synthesized_decl (n,Some (rename root),pos))
      (List.filter (fun n -> not (List.exists (function Synthesized_decl (a,None,_) -> a=n | _ -> false) declarations)) attributes) in
    let constraints = (match minimum with None -> [] | Some n -> [Require (binary ">=" (Attr_child (1,counter)) (Int n),pos)]) @
      (match maximum with None -> [] | Some n -> [Require (binary "<=" (Attr_child (1,counter)) (Int n),pos)]) in
    declared @ [Rule_decl {lhs=rename root;rhs=[Symbol root];guard=None;weight=1;rule_position=pos;
      equations=List.map (fun n -> Assign (n,Attr_child (1,n),pos)) attributes @ constraints}]) roots in
  rewritten @ wrappers

let () =
  if Array.length Sys.argv < 4 then fail "usage: rhema_builder describe|build FILE STDLIB [--value ID JSON_SCALAR ...]";
  let mode = Sys.argv.(1) and file = Sys.argv.(2) and stdlib = Sys.argv.(3) in
  Rhema_load.search_path := [stdlib];
  let us = units (load file) in
  if mode = "preview" then begin
    if Array.length Sys.argv <> 8 then fail "preview needs count, question, assignment and student";
    let spec = match Rhema_check.select_question (List.hd us).spec Sys.argv.(5) with
      | Ok s -> s | Error e -> fail e in
    let student = if Sys.argv.(7) = "" then None else Some Sys.argv.(7) in
    let variant = Rhema_cli.variant ~assignment:Sys.argv.(6) ~student ~seed:None in
    let questions = try Rhema_cli.questions spec ~variant ~count:(int_of_string Sys.argv.(4))
      with Rhema_engine.Generation_error e -> fail e in
    print_endline (arr (List.map (fun q -> obj [
      "pieces",arr (List.map (function Rhema_engine.Piece_text s -> obj ["text",quote s]
        | Piece_blank v -> obj ["answer",quote (Rhema_engine.describe_value v)]) q.Rhema_engine.pieces);
      "context",quote q.context;"answer",quote q.answer_text;
      "operator_count",(try match Rhema_engine.attribute q.tree counter with
        | Rhema_engine.Num n -> int (Rhema_number.require_integer "length" n) | _ -> "null"
        with Rhema_engine.Generation_error _ -> "null")]) questions))
  end
  else if mode = "describe" then print_endline (describe us)
  else if mode <> "build" then fail "Unknown authoring operation"
  else begin
    let changes = ref [] and minimum = ref None and maximum = ref None and width = ref None and instruction = ref "" in
    let rec arguments i = if i < Array.length Sys.argv then
      match Sys.argv.(i) with
      | "--value" when i+2 < Array.length Sys.argv -> changes := (Sys.argv.(i+1),Sys.argv.(i+2)) :: !changes; arguments (i+3)
      | "--min-length" when i+1 < Array.length Sys.argv -> minimum := Some (int_of_string Sys.argv.(i+1)); arguments (i+2)
      | "--max-length" when i+1 < Array.length Sys.argv -> maximum := Some (int_of_string Sys.argv.(i+1)); arguments (i+2)
      | "--width" when i+1 < Array.length Sys.argv -> width := Some (int_of_string Sys.argv.(i+1)); arguments (i+2)
      | "--instruction" when i+1 < Array.length Sys.argv -> instruction := Sys.argv.(i+1); arguments (i+2)
      | _ -> fail "Unknown authoring argument" in
    arguments 4;
    let limited = !minimum <> None || !maximum <> None in
    let value id = List.assoc_opt id !changes in
    let as_int s = try int_of_string s with _ -> fail "A setting must be a whole number" in
    let as_args s = String.split_on_char ',' s |> List.map (fun n -> Int (as_int n)) in
    let names = List.mapi (fun i u -> u.path, if i=0 then "main.rhm" else "module_" ^ int i ^ ".rhm") us in
    let files = List.mapi (fun index u ->
      let get id = value (u.key ^ ":" ^ id) in
      let rule_index = ref 0 in
      let with_instruction text = if index<>0 || !instruction="" then text else
        replace_all "}" "}}" (replace_all "{" "{{" !instruction) ^ "\n" ^ text in
      let rec adjust_guard old_price new_price = function
        | At (p,e) -> At (p,adjust_guard old_price new_price e)
        | Binary (op,left,e) when unlocated left = Attr_here "cost" && List.mem op ["=";">=";">";"<=";"<"] ->
            (match number e with Some n -> Binary (op,left,Int (max 0 (n + new_price - old_price))) | None -> Binary(op,left,e))
        | Binary (op,a,b) -> Binary (op,adjust_guard old_price new_price a,adjust_guard old_price new_price b)
        | e -> e in
      let declarations = List.filter_map (function
        | Inherited_decl (n,v,d,p) -> Some (Inherited_decl (n,(match get ("a:"^n) with None -> v | Some s -> as_int s),d,p))
        | Random_decl (n,Draw_boolean,p) as original -> Some (match get ("b:"^n) with
            | Some "true" -> Let_decl(n,Binary("=",Int 1,Int 1),p)
            | Some "false" -> Let_decl(n,Binary("=",Int 1,Int 0),p) | _ -> original)
        | Random_decl (n,Draw_generator(g,args),p) -> Some (Random_decl(n,Draw_generator(g,
            (match get ("r:"^n) with None -> args | Some s -> as_args s)),p))
        | Import_decl (path,alias,p) -> Some (Import_decl(List.assoc path names,alias,p))
        | Width_decl (_,p) when !width <> None && index=0 -> Some (Width_decl(Option.get !width,p))
        | Prompt_decl (text,p) -> Some (Prompt_decl(with_instruction text,p))
        | Question_decl (n,items,p) -> Some (Question_decl(n,List.map (function
            | Q_default (name,v,p) -> Q_default(name,(match get ("a:"^name) with None -> v | Some s -> as_int s),p)
            | Q_prompt (text,p) -> Q_prompt(with_instruction text,p)
            | Q_width (_,p) when !width <> None && index=0 -> Q_width(Option.get !width,p) | x -> x) items,p))
        | Rule_decl r ->
            let i = !rule_index in incr rule_index;
            let key = "rule:" ^ int i in
            let weight = match get (key^":weight") with None -> r.weight | Some s -> as_int s in
            if weight=0 then None else
            let price = Option.map as_int (get (key^":cost")) in
            let old_price = List.find_map (function Assign("cost",e,_) -> Option.map (~-) (number e) | _ -> None) r.equations in
            let rhs = List.mapi (fun j -> function
              | Generator(g,args) -> Generator(g,(match get (key^":leaf:"^int j) with None -> args | Some s -> as_args s))
              | x -> x) r.rhs in
            let equations = List.map (function
              | Assign("cost",_,p) when price <> None -> Assign("cost",Int (-Option.get price),p) | x -> x) r.equations in
            let equations = if not limited then equations else
              let sum = List.mapi (fun j -> function
                | Symbol name when List.exists (function Rule_decl x -> x.lhs=name | _ -> false) u.declarations -> Some (Attr_child(j+1,counter))
                | Module_symbol _ -> Some (Attr_child(j+1,counter)) | _ -> None) rhs |> List.filter_map Fun.id in
              equations @ [Assign(counter,List.fold_left (binary "+") (Int (operator_count r)) sum,pos)] in
            let guard = match old_price,price with Some a,Some b -> Option.map (adjust_guard a b) r.guard | _ -> r.guard in
            Some (Rule_decl {r with rhs;weight;guard;equations})
        | d -> Some d) u.declarations in
      let declarations = if index=0 && !width<>None && not (List.exists (function Width_decl _ -> true | _ -> false) declarations)
        then declarations @ [Width_decl(Option.get !width,pos)] else declarations in
      let declarations = if limited then Synthesized_decl(counter,None,pos)::declarations else declarations in
      let declarations = if index=0 && limited then wrap_length !minimum !maximum declarations else declarations in
      obj ["name",quote (List.assoc u.path names);"content",quote
        ("# Generated by the Rhema form editor.\n\n" ^ String.concat "\n\n" (List.map declaration declarations) ^ "\n")]) us in
    print_endline (obj ["files",arr files])
  end
