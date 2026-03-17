open Ast_printer
open Parser   (* for Parser.Settle *)
open Semantic
open Describe

let () =
  if Array.length Sys.argv = 2 then begin
    let student_id = Sys.argv.(1) in
    
    let seed = Generator.seed_of_id student_id in
    Random.init seed;
    
    let doc   = Generator.gen_document () in
    
    (* Print a nicely‐formatted AST followed by a newline: *)
    print_endline "";
    print_endline "Generated AST: ";
    print_endline "";
    Format.printf "%a@." pp_document doc;
    print_endline "";

    let dcst  = describe_document doc in

    let cst = match Settle.main dcst with
      | Some c -> c
      | None   -> prerr_endline "\n=== settle failed on this DCST tree ===\n";
                  failwith "settle fail"
    in
    
    (* Generate PGML code as string *)
    let pgml_code = 
      let buffer = Buffer.create 1024 in
      PPrint.ToBuffer.pretty 1.0 80 buffer (Print_pprint.to_doc cst);
      Buffer.contents buffer
    in
    
    (* Print to terminal *)
    print_endline ""; print_endline "Generated PGML code: "; print_endline "";
    print_string pgml_code;
    print_endline "";
    
    (* Save to file *)
    let now = Unix.time () in
    let gmt_tm = Unix.gmtime now in
    let beijing_tm = 
      { gmt_tm with 
        Unix.tm_hour = (gmt_tm.Unix.tm_hour + 8) mod 24;
        Unix.tm_mday = if gmt_tm.Unix.tm_hour + 8 >= 24 then gmt_tm.Unix.tm_mday + 1 else gmt_tm.Unix.tm_mday
      } in
    let formatted_date = 
      Printf.sprintf "%04d%02d%02d_%02d%02d%02d" 
        (beijing_tm.Unix.tm_year + 1900) (beijing_tm.Unix.tm_mon + 1) beijing_tm.Unix.tm_mday
        beijing_tm.Unix.tm_hour beijing_tm.Unix.tm_min beijing_tm.Unix.tm_sec
    in
    let base_filename = "generated_questions/" ^ student_id ^ "_" ^ formatted_date in
    
    (* Create directories if they don't exist *)
    (try 
        Unix.mkdir "generated_asts" 0o755 
     with 
        Unix.Unix_error (Unix.EEXIST, _, _) -> ()
      | e -> prerr_endline ("Warning: " ^ Printexc.to_string e)
    );

    (try 
        Unix.mkdir "generated_questions" 0o755 
     with 
        Unix.Unix_error (Unix.EEXIST, _, _) -> ()
      | e -> prerr_endline ("Warning: " ^ Printexc.to_string e)
    );

    (* Save AST *)
    let ast_filename = "generated_asts/" ^ student_id ^ "_" ^ formatted_date ^ "_ast.txt" in
    let ast_str = Format.asprintf "%a" pp_document doc in
    let oc_ast = open_out ast_filename in
    output_string oc_ast ast_str;
    close_out oc_ast;

    (* Save PGML code *)
    let pgml_filename = base_filename ^ ".pg" in
    let oc = open_out pgml_filename in
    output_string oc pgml_code;
    close_out oc;
    
    print_endline ("\nAST saved to: " ^ ast_filename);
    print_endline ("PGML code saved to: " ^ pgml_filename)
  
  end else begin
    (* Original parse-from-stdin → unparse → print *)
    let lexbuf = Lexing.from_channel stdin in
    let doc    = Parser.main Lexer.read lexbuf in
    
    (* 1. Run semantic validation: *)
    (try
        validate doc;
        print_endline ""; print_endline "";
        prerr_endline "Semantic: OK"
      with
      | Semantic_error msg ->
        print_endline ""; print_endline "";   
        prerr_endline ("Semantic error: " ^ msg);
        exit 1
    );

    (* 2. If we got here, AST is both syntactically and semantically valid *)
    (* Print a nicely‐formatted AST followed by a newline: *)
    print_endline "";
    print_endline "AST: ";
    print_endline "";
    Format.printf "%a@." pp_document doc;
    print_endline "";
    
    let dcst   = describe_document doc in
    let cst = match Settle.main dcst with
      | Some c -> c
      | None   -> failwith "settle fail" 
    in
      print_endline ""; print_endline "After unparsing: "; print_endline "";
      PPrint.ToChannel.pretty 1.0 80 stdout (Print_pprint.to_doc cst)
  end