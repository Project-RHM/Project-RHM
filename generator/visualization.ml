open Ast_printer
open Describe
open Parser

type tree = Node of string * tree list

let read_all channel =
  let buffer = Buffer.create 4096 in
  (try
     while true do
       Buffer.add_string buffer (input_line channel);
       Buffer.add_char buffer '\n'
     done
   with End_of_file -> ());
  Buffer.contents buffer

let trim = String.trim

let trim_trailing_whitespace text =
  let rec find index =
    if index < 0 then 0
    else
      match text.[index] with
      | ' ' | '\t' | '\r' | '\n' -> find (index - 1)
      | _ -> index + 1
  in
  String.sub text 0 (find (String.length text - 1))

let tree_of_pretty text =
  let length = String.length text in
  let rec skip_space index =
    if index < length then
      match text.[index] with
      | ' ' | '\t' | '\r' | '\n' -> skip_space (index + 1)
      | _ -> index
    else
      index
  in
  let rec quoted_end index escaped =
    if index >= length then length
    else if escaped then quoted_end (index + 1) false
    else
      match text.[index] with
      | '\\' -> quoted_end (index + 1) true
      | '"' -> index + 1
      | _ -> quoted_end (index + 1) false
  in
  let rec atom_end index =
    if index >= length then index
    else
      match text.[index] with
      | '(' | ')' | '[' | ']' | ',' | ';' -> index
      | _ -> atom_end (index + 1)
  in
  let rec parse_value index =
    let index = skip_space index in
    if index >= length then (Node ("<empty>", []), index)
    else if text.[index] = '"' then
      let finish = quoted_end (index + 1) false in
      (Node (String.sub text index (finish - index), []), finish)
    else if text.[index] = '[' then
      parse_children "list" ']' (index + 1)
    else
      let finish = atom_end index in
      let label = trim (String.sub text index (finish - index)) in
      let finish = skip_space finish in
      if finish < length && text.[finish] = '(' then
        parse_children (if label = "" then "tuple" else label) ')' (finish + 1)
      else
        (Node ((if label = "" then "<value>" else label), []), finish)
  and parse_children label closing index =
    let rec loop index children =
      let index = skip_space index in
      if index >= length then (Node (label, List.rev children), index)
      else if text.[index] = closing then
        (Node (label, List.rev children), index + 1)
      else
        let child, next = parse_value index in
        let next = skip_space next in
        let next =
          if next < length && (text.[next] = ',' || text.[next] = ';') then
            next + 1
          else
            next
        in
        loop next (child :: children)
    in
    loop index []
  in
  fst (parse_value 0)

(* MenhirCST intentionally hides this representation in Settle.mli. These
   constructors mirror the installed MenhirCST runtime used by Parser.DCST. *)
type raw_dcst =
  | Choice of raw_dcst * raw_dcst
  | Terminal of Parser.token
  | NonTerminal of int * raw_dcst array
[@@warning "-37"]

let token_name = function
  | X_VAR -> "X_VAR"
  | XOR_WORD -> "XOR_WORD"
  | WITH_METH -> "WITH_METH"
  | WIDTH_WORD -> "WIDTH_WORD"
  | WHEN_WORD -> "WHEN_WORD"
  | WHAT_WORD -> "WHAT_WORD"
  | VEC_LATEX -> "VEC_LATEX"
  | VECTOR_UNIT_PROB -> "VECTOR_UNIT_PROB"
  | VECTOR_SAME_PROB -> "VECTOR_SAME_PROB"
  | VECTOR_PARA_PROB -> "VECTOR_PARA_PROB"
  | VALUE_WORD -> "VALUE_WORD"
  | UNIT_METH -> "UNIT_METH"
  | UNION -> "UNION"
  | UNDEFINE_METH -> "UNDEFINE_METH"
  | TRUE_WORD -> "TRUE_WORD"
  | TO_WORD -> "TO_WORD"
  | TIMES_LATEX -> "TIMES_LATEX"
  | THE_WORD -> "THE_WORD"
  | SUPPOSE_PROB -> "SUPPOSE_PROB"
  | SUB_OP -> "SUB_OP"
  | SQRT_OP -> "SQRT_OP"
  | SIN_OP -> "SIN_OP"
  | SINGLE_QUOTE -> "SINGLE_QUOTE"
  | SET_METH -> "SET_METH"
  | SET_DEF_METH -> "SET_DEF_METH"
  | SEMI -> "SEMI"
  | RPAREN -> "RPAREN"
  | RIGHT_NORM_LATEX -> "RIGHT_NORM_LATEX"
  | REDEFINE_METH -> "REDEFINE_METH"
  | REAL_METH -> "REAL_METH"
  | RBRACKET -> "RBRACKET"
  | RBRACE_LATEX -> "RBRACE_LATEX"
  | RBRACE -> "RBRACE"
  | RANGLE_LATEX -> "RANGLE_LATEX"
  | RANDOM_METH -> "RANDOM_METH"
  | QUESTION_MARK -> "QUESTION_MARK"
  | POWER_OP -> "POWER_OP"
  | PIPE -> "PIPE"
  | PGSTANDARD -> "PGSTANDARD"
  | PGML -> "PGML"
  | PERIOD -> "PERIOD"
  | OR_WORD -> "OR_WORD"
  | OF_WORD -> "OF_WORD"
  | NUMBER value -> Printf.sprintf "NUMBER(%g)" value
  | NOT_WORD -> "NOT_WORD"
  | NORM_METH -> "NORM_METH"
  | NEWLINE -> "NEWLINE"
  | NEG_INFINITY -> "NEG_INFINITY"
  | NAT_LOG -> "NAT_LOG"
  | NAMING -> "NAMING"
  | MUL_OP -> "MUL_OP"
  | MATHOBJECTS -> "MATHOBJECTS"
  | MACRO value -> Printf.sprintf "MACRO(%S)" value
  | LT -> "LT"
  | LPAREN -> "LPAREN"
  | LOADMACROS -> "LOADMACROS"
  | LN_OP -> "LN_OP"
  | LEQ_LATEX -> "LEQ_LATEX"
  | LEFT_NORM_LATEX -> "LEFT_NORM_LATEX"
  | LBRACKET -> "LBRACKET"
  | LBRACE_LATEX -> "LBRACE_LATEX"
  | LBRACE -> "LBRACE"
  | LANGLE_LATEX -> "LANGLE_LATEX"
  | I_UNIT -> "I_UNIT"
  | IT_VAR_OPEN -> "IT_VAR_OPEN"
  | IT_VAR_CLOSE -> "IT_VAR_CLOSE"
  | IT_MATH_OPEN -> "IT_MATH_OPEN"
  | IT_MATH_CLOSE -> "IT_MATH_CLOSE"
  | IS_WORD -> "IS_WORD"
  | INTERSECT_METH -> "INTERSECT_METH"
  | INT value -> Printf.sprintf "INT(%d)" value
  | INFINITY -> "INFINITY"
  | INDEFINITE_INTEGRAL_PROB -> "INDEFINITE_INTEGRAL_PROB"
  | IMPLIES_WORD -> "IMPLIES_WORD"
  | IFF_WORD -> "IFF_WORD"
  | ID value -> Printf.sprintf "ID(%S)" value
  | GT -> "GT"
  | GIVEN_PROB -> "GIVEN_PROB"
  | GIVEN_FUN -> "GIVEN_FUN"
  | GEQ_LATEX -> "GEQ_LATEX"
  | F_FUN -> "F_FUN"
  | FORMULA_METH -> "FORMULA_METH"
  | FAT_COMMA -> "FAT_COMMA"
  | FALSE_WORD -> "FALSE_WORD"
  | EVAL_METH -> "EVAL_METH"
  | EVALUATE_BOOL_PROB -> "EVALUATE_BOOL_PROB"
  | EQUAL_WORD -> "EQUAL_WORD"
  | EQ -> "EQ"
  | EOF -> "EOF"
  | END_PGML -> "END_PGML"
  | ENDDOCUMENT -> "ENDDOCUMENT"
  | D_METH -> "D_METH"
  | DOUBLE_QUOTE -> "DOUBLE_QUOTE"
  | DOCUMENT -> "DOCUMENT"
  | DIV_OP -> "DIV_OP"
  | CUP -> "CUP"
  | COS_OP -> "COS_OP"
  | CONTEXT -> "CONTEXT"
  | COMPUTE_PROB -> "COMPUTE_PROB"
  | COMPUTE_METH -> "COMPUTE_METH"
  | COMPLEX_POWER_I_PROB -> "COMPLEX_POWER_I_PROB"
  | COMPLEX_MOD_PROB -> "COMPLEX_MOD_PROB"
  | COMPLEX_METH -> "COMPLEX_METH"
  | COMPLEX_CONJ_PROB -> "COMPLEX_CONJ_PROB"
  | COMPLEX_ARITH_PROB -> "COMPLEX_ARITH_PROB"
  | COMMA -> "COMMA"
  | CMP_2 -> "CMP_2"
  | CMP_1 -> "CMP_1"
  | CDOT_LATEX -> "CDOT_LATEX"
  | CAP -> "CAP"
  | BOOL_EQUIV_ANSWER_HINT -> "BOOL_EQUIV_ANSWER_HINT"
  | BOOL_ANSWER_HINT -> "BOOL_ANSWER_HINT"
  | BOOLEAN_EQUIV_PROB -> "BOOLEAN_EQUIV_PROB"
  | BLANK -> "BLANK"
  | BEGIN_PGML -> "BEGIN_PGML"
  | ARROW -> "ARROW"
  | ARE_METH -> "ARE_METH"
  | ANSWER_WORD -> "ANSWER_WORD"
  | AND_WORD -> "AND_WORD"
  | ADD_OP -> "ADD_OP"
  | ADD_METH -> "ADD_METH"

let production_name = function
  | 1 -> "ans_var"
  | 33 -> "ctx_only"
  | 37 -> "ctx_setup_no_vars_last"
  | 52 -> "fint"
  | 64 -> "header_simple"
  | 71 -> "ict_math"
  | 82 -> "doc_no_sol"
  | 83 -> "madd"
  | 85 -> "mterm"
  | 116 -> "problem_section"
  | 123 -> "qitem1"
  | 137 -> "qlist_single"
  | 138 -> "qvalue"
  | 172 -> "tmul"
  | 174 -> "tfac"
  | 178 -> "value_int_pos"
  | 184 -> "var_value"
  | id -> Printf.sprintf "production_%d" id

let rec tree_of_raw_dcst = function
  | Choice (left, right) ->
      Node ("Choice", [Node ("alternative 1", [tree_of_raw_dcst left]);
                       Node ("alternative 2", [tree_of_raw_dcst right])])
  | Terminal token ->
      Node ("Terminal: " ^ token_name token, [])
  | NonTerminal (production, children) ->
      Node
        (Printf.sprintf "NonTerminal: %s (#%d)" (production_name production) production,
         Array.to_list (Array.map tree_of_raw_dcst children))

let tree_of_dcst dcst =
  tree_of_raw_dcst (Obj.magic dcst : raw_dcst)

let html_escape text =
  let buffer = Buffer.create (String.length text) in
  String.iter
    (function
      | '&' -> Buffer.add_string buffer "&amp;"
      | '<' -> Buffer.add_string buffer "&lt;"
      | '>' -> Buffer.add_string buffer "&gt;"
      | '"' -> Buffer.add_string buffer "&quot;"
      | '\'' -> Buffer.add_string buffer "&#39;"
      | char -> Buffer.add_char buffer char)
    text;
  Buffer.contents buffer

let rec tree_html (Node (label, children)) =
  let children_html =
    match children with
    | [] -> ""
    | _ ->
        "<ul>"
        ^ String.concat "" (List.map (fun child -> "<li>" ^ tree_html child ^ "</li>") children)
        ^ "</ul>"
  in
  if children = [] then
    "<span class=\"leaf\">" ^ html_escape label ^ "</span>"
  else
    "<details open><summary>" ^ html_escape label ^ "</summary>" ^ children_html ^ "</details>"

let json_escape text =
  let buffer = Buffer.create (String.length text + 16) in
  String.iter
    (function
      | '"' -> Buffer.add_string buffer "\\\""
      | '\\' -> Buffer.add_string buffer "\\\\"
      | '\b' -> Buffer.add_string buffer "\\b"
      | '\012' -> Buffer.add_string buffer "\\f"
      | '\n' -> Buffer.add_string buffer "\\n"
      | '\r' -> Buffer.add_string buffer "\\r"
      | '\t' -> Buffer.add_string buffer "\\t"
      | char when Char.code char < 0x20 ->
          Buffer.add_string buffer (Printf.sprintf "\\u%04x" (Char.code char))
      | char -> Buffer.add_char buffer char)
    text;
  Buffer.contents buffer

let node_kind domain label children =
  if domain = "ast" then
    if children = [] then "value" else "ast"
  else if String.starts_with ~prefix:"Terminal:" label then "terminal"
  else if label = "Choice"
       || String.starts_with ~prefix:"alternative " label then "choice"
  else if String.starts_with ~prefix:"NonTerminal:" label then "nonterminal"
  else "value"

let rec tree_json domain (Node (label, children)) =
  let children_json =
    children
    |> List.map (tree_json domain)
    |> String.concat ","
  in
  Printf.sprintf
    {|{"name":"%s","kind":"%s","children":[%s]}|}
    (json_escape label)
    (node_kind domain label children)
    children_json

let concrete_text cst =
  let buffer = Buffer.create 4096 in
  PPrint.ToBuffer.pretty 1.0 80 buffer (Print_pprint.to_doc cst);
  Buffer.contents buffer

let document_trees document =
  let ast_text = Format.asprintf "%a" pp_document document in
  let ast_tree = tree_of_pretty ast_text in
  let dcst = describe_document document in
  let cst =
    match Settle.main dcst with
    | Some cst -> cst
    | None -> failwith "The DCST could not be settled into a CST"
  in
  (ast_tree, tree_of_dcst dcst, concrete_text cst)

let question_documents = function
  | Ast.Doc_No_Sol (header, contexts, Ast.Problem questions) ->
      List.map
        (fun question ->
          (question, Ast.Doc_No_Sol (header, contexts, Ast.Problem [question])))
        questions

let extract_question_dcst dcst =
  match (Obj.magic dcst : raw_dcst) with
  | NonTerminal (_, document_children) ->
      (match document_children.(7) with
       | NonTerminal (_, problem_children) ->
           (match problem_children.(2) with
            | NonTerminal (_, question_list_children) ->
                question_list_children.(0)
            | _ -> failwith "Unexpected DCST question-list structure")
       | _ -> failwith "Unexpected DCST problem-section structure")
  | _ -> failwith "Unexpected DCST document structure"

let question_views_json document =
  question_documents document
  |> List.mapi (fun index (question, question_document) ->
       let ast_tree =
         Format.asprintf "%a" Ast_printer.pp_question_item question
         |> tree_of_pretty
       in
       let dcst = describe_document question_document in
       let dcst_tree = tree_of_raw_dcst (extract_question_dcst dcst) in
       let cst =
         match Settle.main dcst with
         | Some cst -> cst
         | None -> failwith "The question DCST could not be settled into a CST"
       in
       let concrete = concrete_text cst in
       Printf.sprintf
         {|{"number":%d,"ast":%s,"dcst":%s,"source":"%s"}|}
         (index + 1)
         (tree_json "ast" ast_tree)
         (tree_json "dcst" dcst_tree)
         (json_escape concrete))
  |> String.concat ","

let read_d3_source () =
  let candidates =
    [ "../static/vendor/d3.v7.min.js";
      "static/vendor/d3.v7.min.js";
      "../../static/vendor/d3.v7.min.js" ]
  in
  let rec find = function
    | [] ->
        failwith
          "Cannot find static/vendor/d3.v7.min.js required by the visualizer"
    | path :: rest ->
        if Sys.file_exists path then
          let channel = open_in_bin path in
          let length = in_channel_length channel in
          let contents = really_input_string channel length in
          close_in channel;
          contents
        else find rest
  in
  find candidates

let write_html output_path questions_json source concrete =
  let channel = open_out output_path in
  output_string channel
    {|<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PG AST and DCST Visualizer</title>
<style>
* { box-sizing: border-box; }
:root { color-scheme: light; }
body { margin: 0; font-family: Inter, "Segoe UI", sans-serif; color: #18212b; background: #edf1f4; }
button, select { font: inherit; }
.topbar { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 16px; background: #17212b; color: #fff; }
.brand h1 { margin: 0; font-size: 17px; letter-spacing: 0; }
.brand p { margin: 3px 0 0; color: #aebbc7; font-size: 12px; }
.toolbar { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.toolbar button, .toolbar select { height: 34px; border: 1px solid #43515e; border-radius: 5px; background: #25313c; color: #fff; padding: 0 10px; cursor: pointer; }
.toolbar button:hover { background: #34424f; }
.toolbar button:disabled { opacity: .45; cursor: default; }
.question-count { min-width: 92px; text-align: center; color: #dbe3e9; font-size: 13px; }
.workspace { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 10px; padding: 10px; height: calc(100vh - 62px); min-height: 560px; }
.panel { min-width: 0; display: flex; flex-direction: column; background: #fff; border: 1px solid #cbd4dc; border-radius: 6px; overflow: hidden; }
.panel-head { display: flex; align-items: center; justify-content: space-between; min-height: 42px; padding: 8px 12px; border-bottom: 1px solid #dce3e8; background: #f7f9fa; }
.panel-head h2 { margin: 0; font-size: 14px; }
.legend { display: flex; gap: 10px; color: #5c6873; font-size: 11px; }
.legend span { display: inline-flex; align-items: center; gap: 4px; }
.swatch { width: 9px; height: 9px; border-radius: 2px; }
.canvas { position: relative; flex: 1; min-height: 0; overflow: hidden; background-color: #fff; background-image: linear-gradient(#eef2f4 1px, transparent 1px), linear-gradient(90deg, #eef2f4 1px, transparent 1px); background-size: 24px 24px; }
.canvas svg { display: block; width: 100%; height: 100%; cursor: grab; }
.canvas svg:active { cursor: grabbing; }
.link { fill: none; stroke: #9aa8b4; stroke-width: 1.4; }
.node rect { stroke-width: 1.2; rx: 4; ry: 4; }
.node text { font: 11px Consolas, "SFMono-Regular", monospace; pointer-events: none; }
.node.ast rect { fill: #e7f4ec; stroke: #4f8b68; }
.node.nonterminal rect { fill: #e7f0f8; stroke: #477ca5; }
.node.terminal rect { fill: #fff3d8; stroke: #b5862f; }
.node.choice rect { fill: #f3e9f5; stroke: #9362a1; }
.node.value rect { fill: #f4f5f6; stroke: #8b969f; }
.node.collapsed rect { stroke-width: 2.2; }
.empty-message { position: absolute; inset: 0; display: grid; place-items: center; color: #6d7882; }
.source-dialog { width: min(760px, calc(100vw - 32px)); max-height: 72vh; padding: 0; border: 1px solid #aebbc5; border-radius: 6px; box-shadow: 0 18px 50px rgba(19, 31, 43, .24); }
.source-dialog::backdrop { background: rgba(21, 31, 40, .42); }
.dialog-head { position: sticky; top: 0; display: flex; align-items: center; justify-content: space-between; padding: 10px 12px; background: #f5f7f8; border-bottom: 1px solid #dce3e8; }
.dialog-head h2 { margin: 0; font-size: 14px; }
.dialog-head button { border: 0; background: transparent; padding: 4px 7px; font-size: 20px; line-height: 1; cursor: pointer; }
.source-dialog pre { margin: 0; padding: 14px; white-space: pre-wrap; font: 12px/1.5 Consolas, monospace; }
.load-error { margin: 24px; padding: 16px; border: 1px solid #d89a9a; background: #fff0f0; color: #7b2525; }
@media (max-width: 850px) {
  .topbar { align-items: flex-start; flex-direction: column; }
  .workspace { grid-template-columns: 1fr; height: auto; }
  .panel { height: 70vh; min-height: 480px; }
}
</style>
</head>
<body>
<header class="topbar">
  <div class="brand"><h1>AST and DCST Explorer</h1><p>Semantic structure and concrete grammar choices</p></div>
  <div class="toolbar">
    <button id="previous" type="button" title="Previous question">Previous</button>
    <select id="question-select" aria-label="Question"></select>
    <span id="question-count" class="question-count"></span>
    <button id="next" type="button" title="Next question">Next</button>
    <button id="expand" type="button">Expand all</button>
    <button id="collapse" type="button">Collapse</button>
    <button id="fit" type="button">Fit</button>
    <button id="source-toggle" type="button">Source</button>
  </div>
</header>
<main class="workspace">
  <section class="panel">
    <div class="panel-head"><h2>Abstract Syntax Tree</h2><div class="legend"><span><i class="swatch" style="background:#e7f4ec"></i>Constructor</span><span><i class="swatch" style="background:#f4f5f6"></i>Value</span></div></div>
    <div id="ast-canvas" class="canvas"></div>
  </section>
  <section class="panel">
    <div class="panel-head"><h2>Disjunctive Concrete Syntax Tree</h2><div class="legend"><span><i class="swatch" style="background:#e7f0f8"></i>Nonterminal</span><span><i class="swatch" style="background:#fff3d8"></i>Terminal</span><span><i class="swatch" style="background:#f3e9f5"></i>Choice</span></div></div>
    <div id="dcst-canvas" class="canvas"></div>
  </section>
</main>
<dialog id="source-dialog" class="source-dialog">
  <div class="dialog-head"><h2>Settled source for this question</h2><button id="source-close" type="button" aria-label="Close">&times;</button></div>
  <pre id="question-source"></pre>
</dialog>
<script>
|};
  output_string channel (read_d3_source ());
  output_string channel
    {|</script>
<script>
const questions = [|};
  output_string channel questions_json;
  output_string channel
    {|];
let questionIndex = 0;
const charts = {};

function collapseBelowRoot(root) {
  root.eachAfter(node => {
    if (node.depth > 0 && node.children) {
      node._children = node.children;
      node.children = null;
    }
  });
}

function restoreAll(root) {
  root.each(node => {
    if (node._children) {
      node.children = node._children;
      node._children = null;
    }
  });
}

function collapseFromDepth(root, depth) {
  root.eachAfter(node => {
    if (node.depth >= depth && node.children) {
      node._children = node.children;
      node.children = null;
    }
  });
}

function createChart(containerId, data) {
  const container = document.getElementById(containerId);
  container.replaceChildren();
  const width = Math.max(container.clientWidth, 480);
  const height = Math.max(container.clientHeight, 480);
  const svg = d3.select(container).append("svg").attr("viewBox", [0, 0, width, height]);
  const viewport = svg.append("g");
  const linksLayer = viewport.append("g");
  const nodesLayer = viewport.append("g");
  const zoom = d3.zoom().scaleExtent([0.12, 2.5]).on("zoom", event => viewport.attr("transform", event.transform));
  svg.call(zoom);
  const root = d3.hierarchy(data);
  collapseFromDepth(root, containerId === "dcst-canvas" ? 3 : 4);
  root.x0 = height / 2;
  root.y0 = 24;
  let nextId = 0;

  function update(source, animate = true) {
    const visible = root.descendants();
    const leafCount = Math.max(visible.filter(node => !node.children).length, 1);
    const layoutHeight = Math.max(height - 70, leafCount * 40);
    const layoutWidth = Math.max(width - 180, root.height * 190);
    d3.tree().size([layoutHeight, layoutWidth])(root);
    visible.forEach(node => { node.y = node.depth * 190; });

    const duration = animate ? 240 : 0;
    const nodes = nodesLayer.selectAll("g.node").data(visible, node => node.id || (node.id = ++nextId));
    const enter = nodes.enter().append("g")
      .attr("class", node => `node ${node.data.kind}`)
      .attr("transform", `translate(${source.y0},${source.x0})`)
      .on("click", (event, node) => {
        event.stopPropagation();
        if (node.children) { node._children = node.children; node.children = null; }
        else if (node._children) { node.children = node._children; node._children = null; }
        update(node);
      });
    enter.append("rect");
    enter.append("text").attr("dy", "0.32em");

    const merged = enter.merge(nodes)
      .attr("class", node => `node ${node.data.kind}${node._children ? " collapsed" : ""}`);
    merged.select("text").text(node => node.data.name);
    merged.each(function(node) {
      const textWidth = Math.min(Math.max(node.data.name.length * 6.7, 44), 260);
      d3.select(this).select("rect")
        .attr("x", -8).attr("y", -13)
        .attr("width", textWidth + 16).attr("height", 26);
      d3.select(this).select("text")
        .attr("x", 0)
        .text(node.data.name.length > 38 ? node.data.name.slice(0, 35) + "..." : node.data.name)
        .append("title").text(node.data.name);
    });
    if (animate) {
      merged.transition().duration(duration).attr("transform", node => `translate(${node.y},${node.x})`);
      nodes.exit().transition().duration(duration).attr("transform", `translate(${source.y},${source.x})`).remove();
    } else {
      merged.attr("transform", node => `translate(${node.y},${node.x})`);
      nodes.exit().remove();
    }

    const links = linksLayer.selectAll("path.link").data(root.links(), link => link.target.id);
    const diagonal = d3.linkHorizontal().x(node => node.y).y(node => node.x);
    const mergedLinks = links.enter().append("path").attr("class", "link")
      .attr("d", () => {
        const point = {x: source.x0, y: source.y0};
        return diagonal({source: point, target: point});
      })
      .merge(links);
    if (animate) {
      mergedLinks.transition().duration(duration).attr("d", diagonal);
      links.exit().transition().duration(duration).remove();
    } else {
      mergedLinks.attr("d", diagonal);
      links.exit().remove();
    }
    visible.forEach(node => { node.x0 = node.x; node.y0 = node.y; });
  }

  function fit() {
    const bounds = viewport.node().getBBox();
    if (!bounds.width || !bounds.height) return;
    const scale = Math.min(1.25, 0.9 / Math.max(bounds.width / width, bounds.height / height));
    const x = (width - bounds.width * scale) / 2 - bounds.x * scale;
    const y = (height - bounds.height * scale) / 2 - bounds.y * scale;
    svg.transition().duration(280).call(zoom.transform, d3.zoomIdentity.translate(x, y).scale(scale));
  }

  update(root, false);
  requestAnimationFrame(fit);
  return {
    fit,
    expand() { restoreAll(root); update(root); setTimeout(fit, 260); },
    collapse() { collapseBelowRoot(root); update(root); setTimeout(fit, 260); }
  };
}

function renderQuestion(index) {
  questionIndex = Math.max(0, Math.min(index, questions.length - 1));
  const question = questions[questionIndex];
  charts.ast = createChart("ast-canvas", question.ast);
  charts.dcst = createChart("dcst-canvas", question.dcst);
  document.getElementById("question-select").value = String(questionIndex);
  document.getElementById("question-count").textContent = `Question ${questionIndex + 1} of ${questions.length}`;
  document.getElementById("question-source").textContent = question.source;
  document.getElementById("previous").disabled = questionIndex === 0;
  document.getElementById("next").disabled = questionIndex === questions.length - 1;
}

if (typeof d3 === "undefined") {
  document.body.innerHTML = '<div class="load-error">D3 could not be loaded.</div>';
} else if (!questions.length) {
  document.body.innerHTML = '<div class="load-error">No questions are available.</div>';
} else {
  const select = document.getElementById("question-select");
  questions.forEach((question, index) => {
    const option = document.createElement("option");
    option.value = String(index);
    option.textContent = `Question ${question.number}`;
    select.appendChild(option);
  });
  select.addEventListener("change", event => renderQuestion(Number(event.target.value)));
  document.getElementById("previous").addEventListener("click", () => renderQuestion(questionIndex - 1));
  document.getElementById("next").addEventListener("click", () => renderQuestion(questionIndex + 1));
  document.getElementById("fit").addEventListener("click", () => { charts.ast.fit(); charts.dcst.fit(); });
  document.getElementById("expand").addEventListener("click", () => { charts.ast.expand(); charts.dcst.expand(); });
  document.getElementById("collapse").addEventListener("click", () => { charts.ast.collapse(); charts.dcst.collapse(); });
  const sourceDialog = document.getElementById("source-dialog");
  document.getElementById("source-toggle").addEventListener("click", () => sourceDialog.showModal());
  document.getElementById("source-close").addEventListener("click", () => sourceDialog.close());
  renderQuestion(0);
}
</script>
</body>
</html>
|};
  close_out channel

let write_document_html output_path source document =
  let _, _, concrete = document_trees document in
  write_html output_path (question_views_json document) source concrete;
  Printf.printf "Visualization written to: %s\n" output_path

let parse_source source =
  let input = trim_trailing_whitespace source in
  let lexbuf = Lexing.from_string input in
  try (input, Parser.main Lexer.read lexbuf) with
  | Parser.Error ->
      let offset = Lexing.lexeme_start lexbuf in
      let before = String.sub input 0 (min offset (String.length input)) in
      let line =
        1 + String.fold_left (fun count char -> if char = '\n' then count + 1 else count) 0 before
      in
      let line_start =
        match String.rindex_opt before '\n' with
        | Some index -> index + 1
        | None -> 0
      in
      let column = offset - line_start + 1 in
      failwith (Printf.sprintf "Parse error at line %d, column %d (byte %d)" line column offset)

let write_source_html output_path source =
  let input, document = parse_source source in
  write_document_html output_path input document
