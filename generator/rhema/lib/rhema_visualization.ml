(* Native visualization for questions generated from a .rhm specification.

   The legacy visualizer starts from Ast.document and a Menhir DCST. Attribute
   grammars produce a different tree: every nonterminal records the selected
   production and the attributes evaluated at that node. Keeping this renderer
   on that native representation means arbitrary future specifications can be
   visualized without extending the fixed PG parser first. *)

open Rhema_ast

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
      | '<' -> Buffer.add_string buffer "\\u003c"
      | '>' -> Buffer.add_string buffer "\\u003e"
      | '&' -> Buffer.add_string buffer "\\u0026"
      | character when Char.code character < 0x20 ->
          Buffer.add_string buffer (Printf.sprintf "\\u%04x" (Char.code character))
      | character -> Buffer.add_char buffer character)
    text;
  Buffer.contents buffer

let json_string text = "\"" ^ json_escape text ^ "\""

let rec expression_text = function
  | Int value -> string_of_int value
  | Str text -> Printf.sprintf "%S" text
  | Attr_here name -> name
  | Attr_child (index, name) -> Printf.sprintf "$%d.%s" index name
  | Attr_child_named (owner, name) -> owner ^ "." ^ name
  | Child index -> "$" ^ string_of_int index
  | Unary (operator, body) -> operator ^ " " ^ expression_text body
  | Binary (operator, left, right) ->
      Printf.sprintf "(%s %s %s)" (expression_text left) operator
        (expression_text right)
  | Call (name, arguments) ->
      name ^ "(" ^ String.concat ", " (List.map expression_text arguments) ^ ")"

let symbol_text = function
  | Symbol name -> name
  | Module_symbol (alias, name, _) -> alias ^ "." ^ name
  | Literal text -> Printf.sprintf "%S" text
  | Generator (name, arguments) ->
      name ^ "(" ^ String.concat ", " (List.map expression_text arguments) ^ ")"

let rule_text rule =
  let rhs =
    match rule.rhs with
    | [] -> "<empty>"
    | symbols -> String.concat " " (List.map symbol_text symbols)
  in
  Printf.sprintf "%s -> %s [line %d]" rule.lhs rhs rule.rule_position.line

let equation_text = function
  | Assign (name, body, _) -> name ^ " = " ^ expression_text body
  | Require (condition, _) -> "require " ^ expression_text condition

let value_text = Rhema_engine.describe_value

let json_node ?semantic ~kind ~name children =
  let semantic_field =
    match semantic with
    | None -> ""
    | Some value -> ",\"semantic\":" ^ json_string value
  in
  Printf.sprintf "{\"name\":%s,\"kind\":%s%s,\"children\":[%s]}"
    (json_string name) (json_string kind) semantic_field (String.concat "," children)

let rec production_tree_json path (node : Rhema_engine.node) =
  let name, kind =
    match node.applied_rule with
    | Some rule -> (rule_text rule, "nonterminal")
    | None ->
        let generated_value =
          match node.attributes with
          | [ ("value", Rhema_engine.Num value) ] -> " = " ^ Rhema_number.to_string value
          | _ -> ""
        in
        (node.symbol ^ generated_value, "terminal")
  in
  let children =
    List.mapi
      (fun index child -> production_tree_json (path ^ "/" ^ string_of_int index) child)
      node.children
  in
  json_node ~semantic:path ~kind ~name children

let values_group kind title render values =
  let items =
    match values with
    | [] -> [ json_node ~kind:"value" ~name:"(none)" [] ]
    | values ->
        List.map
          (fun (name, value) -> json_node ~kind ~name:(name ^ " = " ^ render value) [])
          values
  in
  json_node ~kind:"attribute-group" ~name:title items

let rec attributed_tree_json ?globals path (node : Rhema_engine.node) =
  match node.applied_rule with
  | None ->
      let values =
        node.attributes
        |> List.map (fun (name, value) -> name ^ "=" ^ value_text value)
        |> String.concat ", "
      in
      let label = if values = "" then node.symbol else node.symbol ^ " {" ^ values ^ "}" in
      json_node ~semantic:path ~kind:"terminal" ~name:label []
  | Some _ ->
      let global_groups =
        match globals with
        | None -> []
        | Some values -> [ values_group "global" "Question values" value_text values ]
      in
      let inherited =
        values_group "inherited" "Inherited attributes" string_of_int
          node.inherited_attributes
      in
      let synthesized =
        values_group "synthesized" "Synthesized attributes" value_text node.attributes
      in
      let descendants =
        List.mapi
          (fun index child -> attributed_tree_json (path ^ "/" ^ string_of_int index) child)
          node.children
      in
      json_node ~semantic:path ~kind:"nonterminal" ~name:node.symbol
        (global_groups @ [ inherited; synthesized ] @ descendants)

let question_json index (question : Rhema_engine.question) =
  let source =
    question.prompt ^ "\n\nExpected answer: " ^ question.answer_text
  in
  Printf.sprintf
    "{\"number\":%d,\"production\":%s,\"attributes\":%s,\"source\":%s}"
    (index + 1) (production_tree_json "root" question.tree)
    (attributed_tree_json ~globals:question.globals "root" question.tree)
    (json_string source)

let append_bindings buffer indent label render bindings =
  Buffer.add_string buffer (String.make indent ' ' ^ label ^ ":");
  (match bindings with
  | [] -> Buffer.add_string buffer " (none)\n"
  | bindings ->
      Buffer.add_char buffer '\n';
      List.iter
        (fun (name, value) ->
          Buffer.add_string buffer
            (Printf.sprintf "%s%s = %s\n" (String.make (indent + 2) ' ') name
               (render value)))
        bindings)

let ast_text questions =
  let buffer = Buffer.create 4096 in
  Buffer.add_string buffer "Attribute Grammar Generated Derivations\n\n";
  List.iteri
    (fun index (question : Rhema_engine.question) ->
      Buffer.add_string buffer (Printf.sprintf "Question %d\n" (index + 1));
      Buffer.add_string buffer ("Prompt: " ^ question.prompt ^ "\n");
      Buffer.add_string buffer ("Expected answer: " ^ question.answer_text ^ "\n");
      append_bindings buffer 0 "Question values" value_text question.globals;
      Buffer.add_string buffer "Derivation:\n";
      let rec append_node depth (node : Rhema_engine.node) =
        let indent = 2 + (depth * 2) in
        Buffer.add_string buffer
          (Printf.sprintf "%s%s\n" (String.make indent ' ') node.symbol);
        (match node.applied_rule with
        | None -> ()
        | Some rule ->
            Buffer.add_string buffer
              (Printf.sprintf "%sproduction: %s\n" (String.make (indent + 2) ' ')
                 (rule_text rule));
            List.iter
              (fun equation ->
                Buffer.add_string buffer
                  (Printf.sprintf "%sequation: %s\n" (String.make (indent + 2) ' ')
                     (equation_text equation)))
              rule.equations);
        append_bindings buffer (indent + 2) "inherited" string_of_int
          node.inherited_attributes;
        append_bindings buffer (indent + 2) "synthesized" value_text node.attributes;
        List.iter (append_node (depth + 1)) node.children
      in
      append_node 0 question.tree;
      Buffer.add_char buffer '\n')
    questions;
  Buffer.contents buffer

let read_d3_source () =
  let candidates =
    [ "../static/vendor/d3.v7.min.js";
      "static/vendor/d3.v7.min.js";
      "../../static/vendor/d3.v7.min.js" ]
  in
  let rec find = function
    | [] ->
        failwith "Cannot find static/vendor/d3.v7.min.js required by the visualizer"
    | path :: rest ->
        if Sys.file_exists path then
          let channel = open_in_bin path in
          Fun.protect
            ~finally:(fun () -> close_in channel)
            (fun () -> really_input_string channel (in_channel_length channel))
        else find rest
  in
  find candidates

let html_document ~d3_source ~grammar questions =
  let questions_json =
    questions |> List.mapi question_json |> String.concat ","
  in
  String.concat ""
    [ {|<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Attribute Grammar Tree Visualizer</title>
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
.node.nonterminal rect { fill: #e7f0f8; stroke: #477ca5; }
.node.terminal rect { fill: #fff3d8; stroke: #b5862f; }
.node.attribute-group rect { fill: #f0edf6; stroke: #78639a; }
.node.inherited rect { fill: #e7f4ec; stroke: #4f8b68; }
.node.synthesized rect { fill: #fff0df; stroke: #bb7330; }
.node.global rect { fill: #e8f1f4; stroke: #50818c; }
.node.value rect { fill: #f4f5f6; stroke: #8b969f; }
.node.collapsed rect { stroke-width: 2.2; }
.node.semantic-match rect { stroke: #c2410c; stroke-width: 3; filter: drop-shadow(0 0 4px rgba(194, 65, 12, .4)); }
.node.semantic-muted { opacity: .22; }
.node.semantic-pinned rect { fill: #ffedd5; }
.details-dialog { width: min(780px, calc(100vw - 32px)); max-height: 72vh; padding: 0; border: 1px solid #aebbc5; border-radius: 6px; box-shadow: 0 18px 50px rgba(19, 31, 43, .24); }
.details-dialog::backdrop { background: rgba(21, 31, 40, .42); }
.dialog-head { position: sticky; top: 0; display: flex; align-items: center; justify-content: space-between; padding: 10px 12px; background: #f5f7f8; border-bottom: 1px solid #dce3e8; }
.dialog-head h2 { margin: 0; font-size: 14px; }
.dialog-head button { border: 0; background: transparent; padding: 4px 7px; font-size: 20px; line-height: 1; cursor: pointer; }
.details-dialog pre { margin: 0; padding: 14px; white-space: pre-wrap; font: 12px/1.5 Consolas, monospace; }
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
  <div class="brand"><h1>Attribute Grammar Explorer</h1><p id="grammar-name"></p></div>
  <div class="toolbar">
    <button id="previous" type="button" title="Previous question">Previous</button>
    <select id="question-select" aria-label="Question"></select>
    <span id="question-count" class="question-count"></span>
    <button id="next" type="button" title="Next question">Next</button>
    <button id="expand" type="button">Expand all</button>
    <button id="collapse" type="button">Collapse</button>
    <button id="fit" type="button">Fit</button>
    <button id="details-toggle" type="button">Question</button>
  </div>
</header>
<main class="workspace">
  <section class="panel">
    <div class="panel-head"><h2>Applied Production Tree</h2><div class="legend"><span><i class="swatch" style="background:#e7f0f8"></i>Production</span><span><i class="swatch" style="background:#fff3d8"></i>Terminal</span></div></div>
    <div id="production-canvas" class="canvas"></div>
  </section>
  <section class="panel">
    <div class="panel-head"><h2>Attributed Derivation Tree</h2><div class="legend"><span><i class="swatch" style="background:#e7f4ec"></i>Inherited</span><span><i class="swatch" style="background:#fff0df"></i>Synthesized</span><span><i class="swatch" style="background:#e8f1f4"></i>Question value</span></div></div>
    <div id="attribute-canvas" class="canvas"></div>
  </section>
</main>
<dialog id="details-dialog" class="details-dialog">
  <div class="dialog-head"><h2>Generated question and answer</h2><button id="details-close" type="button" aria-label="Close">&times;</button></div>
  <pre id="question-details"></pre>
</dialog>
<script>
|};
      d3_source;
      {|</script>
<script>
const grammarName = |};
      json_string grammar;
      {|;
const questions = [|};
      questions_json;
      {|];
let questionIndex = 0;
const charts = {};
let activeSemantic = null;
let pinnedSemantic = null;

function refreshSemanticHighlight() {
  const semantic = pinnedSemantic || activeSemantic;
  d3.selectAll("g.node")
    .classed("semantic-match", node => Boolean(semantic && node.data.semantic === semantic))
    .classed("semantic-muted", node => Boolean(semantic && node.data.semantic !== semantic))
    .classed("semantic-pinned", node => Boolean(pinnedSemantic && node.data.semantic === pinnedSemantic));
}

function collapseBelow(root, depth) {
  root.eachAfter(node => {
    if (node.depth >= depth && node.children) {
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

function createChart(containerId, data, initialDepth) {
  const container = document.getElementById(containerId);
  container.replaceChildren();
  const width = Math.max(container.clientWidth, 480);
  const height = Math.max(container.clientHeight, 480);
  const svg = d3.select(container).append("svg").attr("viewBox", [0, 0, width, height]);
  const viewport = svg.append("g");
  const linksLayer = viewport.append("g");
  const nodesLayer = viewport.append("g");
  const zoom = d3.zoom().scaleExtent([0.1, 2.5]).on("zoom", event => viewport.attr("transform", event.transform));
  svg.call(zoom);
  svg.on("click", () => { pinnedSemantic = null; activeSemantic = null; refreshSemanticHighlight(); });
  const root = d3.hierarchy(data);
  collapseBelow(root, initialDepth);
  root.x0 = height / 2;
  root.y0 = 24;
  let nextId = 0;

  function update(source, animate = true) {
    const visible = root.descendants();
    const leafCount = Math.max(visible.filter(node => !node.children).length, 1);
    const layoutHeight = Math.max(height - 70, leafCount * 42);
    const layoutWidth = Math.max(width - 220, root.height * 230);
    d3.tree().size([layoutHeight, layoutWidth])(root);
    visible.forEach(node => { node.y = node.depth * 230; });
    const duration = animate ? 220 : 0;
    const nodes = nodesLayer.selectAll("g.node").data(visible, node => node.id || (node.id = ++nextId));
    const enter = nodes.enter().append("g")
      .attr("class", node => `node ${node.data.kind}`)
      .attr("transform", `translate(${source.y0},${source.x0})`)
      .on("mouseenter", (event, node) => { if (node.data.semantic) activeSemantic = node.data.semantic; refreshSemanticHighlight(); })
      .on("mouseleave", () => { activeSemantic = null; refreshSemanticHighlight(); })
      .on("click", (event, node) => {
        event.stopPropagation();
        if (node.data.semantic) pinnedSemantic = pinnedSemantic === node.data.semantic ? null : node.data.semantic;
        if (node.children) { node._children = node.children; node.children = null; }
        else if (node._children) { node.children = node._children; node._children = null; }
        update(node);
      });
    enter.append("rect");
    enter.append("text").attr("dy", "0.32em");
    const merged = enter.merge(nodes).attr("class", node => `node ${node.data.kind}${node._children ? " collapsed" : ""}`);
    merged.each(function(node) {
      const label = node.data.name;
      const display = label.length > 46 ? label.slice(0, 43) + "..." : label;
      const textWidth = Math.min(Math.max(display.length * 6.7, 44), 330);
      d3.select(this).select("rect").attr("x", -8).attr("y", -13).attr("width", textWidth + 16).attr("height", 26);
      const text = d3.select(this).select("text").attr("x", 0).text(display);
      text.selectAll("title").remove();
      text.append("title").text(label);
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
    links.enter().append("path").attr("class", "link").merge(links).attr("d", diagonal);
    links.exit().remove();
    visible.forEach(node => { node.x0 = node.x; node.y0 = node.y; });
    refreshSemanticHighlight();
  }

  function fit() {
    const bounds = viewport.node().getBBox();
    if (!bounds.width || !bounds.height) return;
    const scale = Math.min(1.2, 0.9 / Math.max(bounds.width / width, bounds.height / height));
    const x = (width - bounds.width * scale) / 2 - bounds.x * scale;
    const y = (height - bounds.height * scale) / 2 - bounds.y * scale;
    svg.transition().duration(260).call(zoom.transform, d3.zoomIdentity.translate(x, y).scale(scale));
  }

  update(root, false);
  requestAnimationFrame(fit);
  return {
    fit,
    expand() { restoreAll(root); update(root); setTimeout(fit, 240); },
    collapse() { restoreAll(root); collapseBelow(root, 1); update(root); setTimeout(fit, 240); }
  };
}

function renderQuestion(index) {
  questionIndex = Math.max(0, Math.min(index, questions.length - 1));
  activeSemantic = null;
  pinnedSemantic = null;
  const question = questions[questionIndex];
  charts.production = createChart("production-canvas", question.production, 4);
  charts.attributes = createChart("attribute-canvas", question.attributes, 3);
  document.getElementById("question-select").value = String(questionIndex);
  document.getElementById("question-count").textContent = `Question ${questionIndex + 1} of ${questions.length}`;
  document.getElementById("question-details").textContent = question.source;
  document.getElementById("previous").disabled = questionIndex === 0;
  document.getElementById("next").disabled = questionIndex === questions.length - 1;
}

document.getElementById("grammar-name").textContent = grammarName;
if (typeof d3 === "undefined") {
  document.body.textContent = "D3 could not be loaded.";
} else if (!questions.length) {
  document.body.textContent = "No questions are available.";
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
  document.getElementById("fit").addEventListener("click", () => { charts.production.fit(); charts.attributes.fit(); });
  document.getElementById("expand").addEventListener("click", () => { charts.production.expand(); charts.attributes.expand(); });
  document.getElementById("collapse").addEventListener("click", () => { charts.production.collapse(); charts.attributes.collapse(); });
  const dialog = document.getElementById("details-dialog");
  document.getElementById("details-toggle").addEventListener("click", () => dialog.showModal());
  document.getElementById("details-close").addEventListener("click", () => dialog.close());
  renderQuestion(0);
}
</script>
</body>
</html>
|} ]

let write_file path content =
  let channel = open_out path in
  Fun.protect
    ~finally:(fun () -> close_out channel)
    (fun () -> output_string channel content)

let write_ast path questions = write_file path (ast_text questions)

let write_html path ~grammar questions =
  write_file path
    (html_document ~d3_source:(read_d3_source ()) ~grammar questions)
