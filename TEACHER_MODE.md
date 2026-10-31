# Teacher form editor

Choose **Attribute Grammar**, then **Form editor**. The original **Rhema source** editor and Classic workflow remain available.

The form is derived from the parsed Rhema AST, including included libraries and imported modules. All 30 shipped runnable grammar files are supported. The form offers the settings the grammar exposes:

- Initial inherited attributes, with presets for the main complexity budget.
- Question-level random ranges, fixed true/false assignments and expression leaf ranges.
- Rule selection, weights and operation prices. Fixed-form grammars offer their valid budget choices.
- Optional expression operator-count bounds for grammars containing expression productions.
- Answer field width and an additional instruction.
- The file's existing named questions, through the Question selector.

Press **Generate questions** to see a locally rendered question preview, expandable standard answers, PGML and the native production/attribute trees. KaTeX 0.19.1 and its fonts are bundled locally under `static/vendor/katex/` (MIT license included). Previewing does not submit answers to WeBWorK.

**Save new preset** writes a new `.rhm` and a configuration record under `generator/grammars/.teacher/`. Imported dependencies are saved as hidden sibling `.rhm` files. Standard-library sources are not overwritten. Select the saved file to reopen its form; changes can be saved under another name. **Export specification** downloads a ZIP containing the generated source, required modules and configuration.

If a saved source or dependency has been edited by hand, the form reports that it cannot safely reconstruct those edits. Continue in source mode, or make a new form preset from the original grammar. Form settings are not silently merged into hand-written source.

Budget, length and rule restrictions must be compatible. For example, `sequence.rhm` has fixed-cost question forms; setting cost to 4 does not create a longer sequence question. Expression length counts marked operator productions, not characters, number of questions or tree depth. Length constraints are checked on a synthesized count at a wrapper root; difficult combinations may require retries or be rejected. New mathematical operations still require the underlying Rhema library to support them.

The backend normalizes the inputs, transforms AST declarations, prints a complete specification, invokes `rhema check`, and runs the existing generator. It does not implement a second mathematical evaluator in Python. Assignment identity includes the normalized configuration, so repeating the same settings, question, count and optional student identifier is deterministic for the same source/runtime version.

## Local startup

```sh
cd /Users/ray/Desktop/Project-RHM_latest
source .venv/bin/activate
cd generator
dune build
cd ..
python app.py
```

The application normally uses port 5001. For an additional local instance:

```sh
python -m flask --app app run --host 127.0.0.1 --port 5002 --no-reload
```

## Verification

```sh
cd generator
dune build
dune runtest
cd ..
python -m unittest discover -s tools -p test_teacher_builder.py -v
node --check static/teacher_builder.js
```

The Python suite uses disposable folders and the real built Rhema executables. It covers every shipped grammar and named question, actual parameter effects, exact length constraints, module export and reload, deterministic generation, invalid combinations, and detection of subsequent source edits. It verifies that standard-library files remain unchanged.
