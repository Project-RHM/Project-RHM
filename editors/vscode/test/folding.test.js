// Tests for the folding ranges (src/folding.js), run with `npm test`.

"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { foldingRanges } = require("../src/folding");

/** The folds of `lines`, as "start-end kind" strings in a stable order. */
function folds(lines) {
  return foldingRanges(lines.join("\n"))
    .map((fold) => `${fold.start}-${fold.end}${fold.kind ? " " + fold.kind : ""}`)
    .sort();
}

test("a question whose prompt runs over lines starting in column one", () => {
  assert.deepEqual(
    folds([
      "question nth {", //                              0
      "  start Q",
      '  prompt "An arithmetic sequence has first term', // 2
      "difference [`d = {step}`]. Find [`a_{{{n}}}`].",
      '{answer nth}"', //                               4
      "}", //                                           5
    ]),
    ["0-4", "2-4"],
  );
});

test("braces and quotes inside strings and comments do not count", () => {
  assert.deepEqual(
    folds([
      "E -> E + E {", //                     0
      '  latex = "\\"{" ++ $1.latex  # {',
      '  text = "a \\\\"',
      "}", //                                3
      'prompt "}"',
    ]),
    ["0-2"],
  );
});

test("comment runs and regions", () => {
  assert.deepEqual(
    folds([
      "# One", //            0
      "# Two",
      "# region Sums", //    2
      "start E",
      "# endregion", //      4
      "# Last",
    ]),
    ["0-1 comment", "2-4 region"],
  );
});

test("an unclosed block or string gives no fold", () => {
  assert.deepEqual(folds(["E -> E {", "  value = 1"]), []);
  assert.deepEqual(folds(['prompt "never', "closed"]), []);
});
