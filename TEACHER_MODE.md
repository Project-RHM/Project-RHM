# Teacher workspace and WeBWorK preview

Choose a question type from the sidebar, then use **Configure** to edit its
parameters. The **Rhema source** editor and **Classic generator** remain
available. Settings and preview panels have a draggable divider; on narrow
screens they stack vertically. The header language button switches the UI
between English and Chinese, without translating source code or mathematics.

The form is derived from the parsed Rhema AST, including included libraries and imported modules. All 30 shipped runnable grammar files are supported. The form offers the settings the grammar exposes:

- Initial inherited attributes, with presets for the main complexity budget.
- Question-level random ranges, fixed true/false assignments and expression leaf ranges.
- Rule selection, weights and operation prices. Fixed-form grammars offer their valid budget choices.
- Optional expression operator-count bounds for grammars containing expression productions.
- Answer field width and an additional instruction.
- The file's existing named questions, through the Question selector.

Press **Generate questions** to see the WeBWorK question preview, PGML and the
native production/attribute trees. Form results also provide collapsed standard
answers and an explicitly labelled **Local preview** fallback. The fallback uses
bundled KaTeX (MIT license included) and cannot grade submissions.

**Save preset** writes a new `.rhm` and a configuration record under `generator/grammars/.teacher/`. Imported dependencies are saved as hidden sibling `.rhm` files. Standard-library sources are not overwritten. Select the saved file to reopen its form; changes can be saved under another name. **Export specification** downloads a ZIP containing the generated source, required modules and configuration.

If a saved source or dependency has been edited by hand, the form reports that it cannot safely reconstruct those edits. Continue in source mode, or make a new form preset from the original grammar. Form settings are not silently merged into hand-written source.

Budget, length and rule restrictions must be compatible. For example, `sequence.rhm` has fixed-cost question forms; setting cost to 4 does not create a longer sequence question. Expression length counts marked operator productions, not characters, number of questions or tree depth. Length constraints are checked on a synthesized count at a wrapper root; difficult combinations may require retries or be rejected. New mathematical operations still require the underlying Rhema library to support them.

The backend normalizes the inputs, transforms AST declarations, prints a complete specification, invokes `rhema check`, and runs the existing generator. It does not implement a second mathematical evaluator in Python. Assignment identity includes the normalized configuration, so repeating the same settings, question, count and optional student identifier is deterministic for the same source/runtime version.

## Local startup with Docker Renderer

Install and start Docker Desktop. Both Compose services target `linux/amd64`,
including on Apple Silicon, to match the digest-pinned official renderer image
and bundled x86_64 opam toolchain. Published ports bind to `127.0.0.1`.

From this checkout's root, with the local Python and OCaml toolchains installed:

```sh
docker compose -p rhema-workspace-local up -d --wait webwork-renderer
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
cd generator
dune build
cd ..
APP_PORT=5003 .venv/bin/python app.py
```

Open <http://127.0.0.1:5003>. The application defaults to port 5001 without
`APP_PORT`; 5003 is an example for avoiding an older checkout. Starting the
same port twice can show the old server instead of the checkout just launched.
The default renderer endpoint is `http://127.0.0.1:3000/render-api`.

For the full container stack instead of host-native Flask:

```sh
APP_PORT=5003 docker compose -p rhema-workspace-local up --build -d
```

The configuration and generated question directories are mounted from this
checkout; Linux `_build` files stay in the container. Personal credentials live
in the ignored `.project-rhm-data/` mount and are not copied into the image.
See `.env.example` for renderer options. Host-native Flask does not automatically
read that file; export any overrides in the shell.

Stop the renderer without deleting data:

```sh
docker compose -p rhema-workspace-local stop webwork-renderer
```

## Answer checking and isolation

Enter answers in the real WeBWorK inputs and select **Check answers**. The UI
shows the total score and per-answer feedback. Editing an answer invalidates the
old result. History previews support the same checks. A broken PG answer
evaluator is reported as an error instead of being silently graded. Regenerate
older Classic mixed documents to obtain the context-independent vector graders.

Rendering alone does not submit answers. Grading uses the PG evaluator: it is
not an independent proof that the generator's standard answer is correct, and
this preview does not save grades to a WeBWorK course gradebook.

Renderer HTML runs in an opaque-origin iframe with `sandbox="allow-scripts"`,
not same-origin access or native form submission. Optional MathQuill and
parent-frame interaction initializers are omitted; MathJax and plain inputs
remain. A token-bound `postMessage` bridge transfers only named answer fields.
The proxy validates names and sizes, fixes renderer options server-side, and
returns only scores and plain feedback from its internal grading response,
never correct-answer objects or session JWTs. The service session bypasses
workstation HTTP proxy variables so local PG source stays on its configured
service connection.

## Verification

```sh
cd generator
dune build
dune runtest
cd ..
python -m unittest discover -s tools -p test_teacher_builder.py -v
python tools/test_webwork_preview.py
node --check static/teacher_builder.js
```

The Python suite uses disposable folders and the real built Rhema executables. It covers every shipped grammar and named question, actual parameter effects, exact length constraints, module export and reload, deterministic generation, invalid combinations, and detection of subsequent source edits. It verifies that standard-library files remain unchanged.

With the renderer running, opt into live render and grading tests:

```sh
python tools/validate_webwork_renderer.py --renderer-url http://127.0.0.1:3000/render-api
python tools/test_webwork_grading_live.py
```

In the full container stack, run them with `docker compose exec -T app python3`.
The grading script covers all six Classic vector operations under different
contexts, a mixed typed-answer document, and actual Classic seed outputs. Its
last case uses the locally compiled Classic configuration; it does not rewrite
that configuration.
