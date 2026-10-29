// Tests for reading rhema's output (src/messages.js), run with `npm test`.
// The samples are what rhema 0.1 prints.

"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { parseListing, parseProblems, quotedName } = require("../src/messages");

test("problems with and without a position", () => {
  const output = [
    "bad.rhm: error: declare at least one synthesized attribute, for example: synth value",
    "bad.rhm:2:12: error: 'value' is not declared; add 'attribute value = ...' or 'synth value'",
    "sub/lib.rhm:3:12: error: unknown name 'foo'",
    "ok.rhm: OK (4 rules; questions: main; sets: none)",
    "",
  ].join("\n");
  assert.deepEqual(parseProblems(output), [
    {
      file: "bad.rhm",
      line: 0,
      column: 0,
      located: false,
      severity: "error",
      message: "declare at least one synthesized attribute, for example: synth value",
    },
    {
      file: "bad.rhm",
      line: 1,
      column: 11,
      located: true,
      severity: "error",
      message: "'value' is not declared; add 'attribute value = ...' or 'synth value'",
    },
    {
      file: "sub/lib.rhm",
      line: 2,
      column: 11,
      located: true,
      severity: "error",
      message: "unknown name 'foo'",
    },
  ]);
});

test("a message may contain colons, and a file name a drive letter", () => {
  const [first, second] = parseProblems(
    [
      "imp.rhm:1:1: error: import \"lib.rhm\" as l: the module has problems of its own",
      "C:\\work\\quiz.rhm:4:2: warning: unused: x",
    ].join("\r\n"),
  );
  assert.equal(first.file, "imp.rhm");
  assert.equal(first.message, 'import "lib.rhm" as l: the module has problems of its own');
  assert.equal(second.file, "C:\\work\\quiz.rhm");
  assert.equal(second.line, 3);
  assert.equal(second.severity, "warning");
  assert.equal(second.message, "unused: x");
});

test("output without problems", () => {
  assert.deepEqual(parseProblems("ok.rhm: OK (4 rules; questions: main; sets: none)\n"), []);
  assert.deepEqual(parseProblems(""), []);
});

test("questions and sets from rhema list", () => {
  const listing = parseListing(
    [
      "imports:",
      "  seq = docs/examples/questions.rhm",
      "  calc = /usr/share/rhema/calculus.rhm",
      "questions: none (a library)",
      "sets:",
      "  week3          9 questions",
      "",
    ].join("\n"),
  );
  assert.deepEqual(listing, { questions: [], sets: [{ name: "week3", detail: "9 questions" }] });

  const questions = parseListing(
    [
      "questions:",
      "  main           start Q, context Numeric",
      "  derivative     start D, context Numeric",
      "budgets: cost = 7, calculus_mode = 0",
    ].join("\n"),
  );
  assert.deepEqual(questions.questions, [
    { name: "main", detail: "start Q, context Numeric" },
    { name: "derivative", detail: "start D, context Numeric" },
  ]);
  assert.deepEqual(questions.sets, []);
});

test("the name a message is about", () => {
  assert.equal(quotedName("unknown name 'foo'"), "foo");
  assert.equal(quotedName("'latex' is not declared; add 'attribute latex = ...'"), "latex");
  assert.equal(quotedName("$3 is out of range: this rule has 1 symbols on the right"), undefined);
  assert.equal(quotedName("child '$2' is not a nonterminal"), "$2");
  assert.equal(quotedName("a 'prompt \"...\"' declaration is required"), undefined);
});
