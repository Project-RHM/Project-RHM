# Visual Question Builder

The visual builder creates a new Rhema specification by composing existing mathematical library operations. It does not execute user-supplied Python or OCaml, introduce a second mathematical engine, or require an AI API key.

## Create a Question Type

1. Select **Create question type** and enter a new `.rhm` filename.
2. Choose **Visual builder**. **Rhema source** still offers the original basic, blank and existing-file starting points.
3. Choose an example or **Empty definition**. Examples cover polynomial/calculus, Boolean evaluation, sequences, vectors, complex numbers and sets.
4. Define random integer, nonzero-integer or Boolean parameters.
5. Add mathematical steps. Each step can use literals and compatible values from earlier steps. Names are references, not executable code.
6. Write the question text. Use **Insert value** for mathematical objects and parameters. These inserts appear as `{name}` in the editor and are rendered as mathematics in the question.
7. Select the standard answer under **Use result from**. Conditions can reference true/false results and require either true or false.
8. Select **Check**. This runs the real Rhema checker and two deterministic sample generations. It is not a proof that all possible random assignments satisfy every constraint.
9. Enter an optional student ID and select **Generate questions**. The right panel contains real WeBWorK rendering and answer checking, generated Rhema, PGML and the generation tree. WeBWorK requires the existing Docker renderer.
10. Select **Save question type**, then **Open in Configure** for the ordinary parameter-based generation workflow.

The result is a new question type in **Question library**, not a form preset. **My presets** remains the place for saved Configure settings.

## Compose a Different Question

The polynomial example constructs `p`, differentiates it into `d`, and evaluates `d` at random point `k`. To ask about a squared polynomial instead:

1. Change the second step to **Power of polynomial**.
2. Keep `p` as its input and set the exponent to 2.
3. Leave the third step as **Evaluate polynomial at a point**, using `d` and `k`.
4. Change the wording to `Given P(x) = {p}, find the square of P({k}).`
5. Check, generate and save.

The question wording must describe the actual mathematical steps. The builder checks references and types, but does not interpret natural-language wording to prove that it asks for the selected answer.

## Edit and Protect Existing Work

Select a saved visual question type in the library, then **Visual definition**. Its definition can be edited and saved again. Updates require the source revision loaded by the editor; stale tabs cannot overwrite later source changes. Previous source and definition versions are backed up before an update.

Each visual type has two files:

- `generator/grammars/<name>.rhm`: executable Rhema specification; usable through Configure, source mode and the CLI.
- `generator/grammars/.visual/<name>.rhm.json`: structured definition and source revision, required to reopen Visual builder.

Keep both files when sharing a visual question type. Renaming a `.rhm` file alone does not rename its visual definition.

If its source is manually edited, the existing Rhema/Configure workflows remain available, but Visual builder refuses to overwrite the changed source. Arbitrary hand-written Rhema is not automatically converted back into a visual graph.

## Boundaries

- Only catalogued adapters to existing library functions are available. The catalog is defined in `visual_library.py`; compilation and validation are in `visual_builder.py`. Extending an existing mathematical primitive requires a typed adapter, not another question-specific generator.
- This version composes acyclic mathematical steps with one answer. It does not provide a visual editor for arbitrary recursive productions or multi-part questions. Existing recursive `.rhm` grammars remain available in Configure and Source mode.
- Scalar number inputs are integers; exact fractions can be formed with the division operation. Variable names and variable-order strings are restricted to safe identifier-like text.
- Type compatibility is checked before compilation. Domain conditions such as matrix dimensions, invertibility, equation support and valid exponents are also checked by the existing mathematical libraries at generation time.
- Finite sets and general sets are distinguished: insertion accepts a finite set, while union/intersection/difference also accept intervals.
- Constraints can be unsatisfiable or too restrictive. A failed check does not relax them silently. Prefer constructive generation and suitable random ranges.
- Same specification, settings, implementation and student ID reproduce question content. Different IDs do not guarantee unique or equally difficult questions.
- Definition limits: 12 random parameters, 30 steps, 12 constraints, 2,000 prompt characters, and an answer width of 1-100. These limits keep editor and runtime work bounded.

## Local Tests

```sh
python -m unittest tools.test_visual_builder
node --test tools/test_visual_builder.js tools/test_pg_preview.js
```

The Python suite exercises the real Rhema runtime in temporary folders, including every catalog adapter, source conflicts, deterministic generation, Configure interoperability and rollback after a failed metadata write. Browser rendering and live answer checking require WeBWorK and are additional integration checks.
