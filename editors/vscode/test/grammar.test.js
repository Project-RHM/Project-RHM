// Tests for the Rhema TextMate grammar, run with `npm test`.
//
// The grammar is checked against the compiler itself: the keyword table is
// read from rhema_lexer.mll and the set words from rhema_parser.mly, so a word
// added to the language without a matching change here fails the suite. Every
// .rhm file in the repository must also tokenize without an invalid token and
// without leaving a block or string open.

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const oniguruma = require("vscode-oniguruma");
const textmate = require("vscode-textmate");

const EXTENSION = path.resolve(__dirname, "..");
const REPOSITORY = path.resolve(EXTENSION, "..", "..");
const LEXER = path.join(REPOSITORY, "generator", "rhema", "lib", "rhema_lexer.mll");
const PARSER = path.join(REPOSITORY, "generator", "rhema", "lib", "rhema_parser.mly");
const RHEMA_DIRECTORIES = ["generator/stdlib", "generator/grammars", "docs/examples"];

const GRAMMAR_FILES = {
  "source.rhema": "syntaxes/rhema.tmLanguage.json",
  "markdown.rhema.codeblock": "syntaxes/rhema.markdown.tmLanguage.json",
};

// A stand-in for VS Code's Markdown grammar, enough to host the injection.
const MARKDOWN_STUB = { scopeName: "text.html.markdown", patterns: [] };

const registry = new textmate.Registry({
  onigLib: (async () => {
    const wasm = fs.readFileSync(require.resolve("vscode-oniguruma/release/onig.wasm"));
    await oniguruma.loadWASM(wasm.buffer.slice(wasm.byteOffset, wasm.byteOffset + wasm.byteLength));
    return {
      createOnigScanner: (patterns) => new oniguruma.OnigScanner(patterns),
      createOnigString: (text) => new oniguruma.OnigString(text),
    };
  })(),
  loadGrammar: async (scopeName) => {
    if (scopeName === "text.html.markdown") return MARKDOWN_STUB;
    const file = GRAMMAR_FILES[scopeName];
    if (!file) return null;
    const text = fs.readFileSync(path.join(EXTENSION, file), "utf8");
    return textmate.parseRawGrammar(text, path.join(EXTENSION, file));
  },
  getInjections: (scopeName) =>
    scopeName === "text.html.markdown" ? ["markdown.rhema.codeblock"] : [],
});

// Returns the tokens of `text` as { text, scopes } and the state after the
// last line.
async function tokenize(text, scopeName = "source.rhema") {
  const grammar = await registry.loadGrammar(scopeName);
  let state = textmate.INITIAL;
  const tokens = [];
  for (const line of text.split(/\r?\n/)) {
    const result = grammar.tokenizeLine(line, state);
    for (const token of result.tokens) {
      tokens.push({ text: line.slice(token.startIndex, token.endIndex), scopes: token.scopes });
    }
    state = result.ruleStack;
  }
  return { tokens, state };
}

// The innermost scopes of the first token whose text is `word`, searched
// from the `occurrence`-th match (0-based).
function scopesOf(tokens, word, occurrence = 0) {
  const matches = tokens.filter((token) => token.text === word);
  assert.ok(matches.length > occurrence, `no token '${word}' (occurrence ${occurrence})`);
  return matches[occurrence].scopes;
}

function hasScope(scopes, prefix) {
  return scopes.some((scope) => scope === prefix || scope.startsWith(prefix + "."));
}

function assertScope(tokens, word, prefix, occurrence = 0) {
  const scopes = scopesOf(tokens, word, occurrence);
  assert.ok(hasScope(scopes, prefix), `'${word}' has scopes ${scopes.join(" ")}, expected ${prefix}`);
}

function compilerKeywords() {
  const source = fs.readFileSync(LEXER, "utf8");
  const table = source.match(/let keywords = \[([\s\S]*?)\]/);
  assert.ok(table, "keyword table not found in rhema_lexer.mll");
  const words = [...table[1].matchAll(/"([a-z_]+)"\s*,/g)].map((match) => match[1]);
  assert.ok(words.length > 20, `only ${words.length} keywords read from rhema_lexer.mll`);
  return words;
}

function setWords() {
  const source = fs.readFileSync(PARSER, "utf8");
  const words = new Set();
  for (const call of source.matchAll(/expect_(?:word|one_of)\s+(\[[^\]]*\]|"[a-z]+")/g)) {
    for (const word of call[1].matchAll(/"([a-z]+)"/g)) words.add(word[1]);
  }
  assert.ok(words.size >= 10, `only ${words.size} set words read from rhema_parser.mly`);
  return [...words];
}

function rhemaFiles() {
  const files = [];
  for (const directory of RHEMA_DIRECTORIES) {
    const absolute = path.join(REPOSITORY, directory);
    if (!fs.existsSync(absolute)) continue;
    for (const name of fs.readdirSync(absolute)) {
      if (name.endsWith(".rhm")) files.push(path.join(absolute, name));
    }
  }
  return files;
}

const KEYWORD_SCOPES = ["keyword", "storage"];

test("every keyword of the compiler is highlighted", async () => {
  for (const word of compilerKeywords()) {
    const { tokens } = await tokenize(word);
    const scopes = scopesOf(tokens, word);
    assert.ok(
      KEYWORD_SCOPES.some((prefix) => hasScope(scopes, prefix)),
      `keyword '${word}' from rhema_lexer.mll has scopes ${scopes.join(" ")}`,
    );
  }
});

test("set words are keywords inside a set and names outside it", async () => {
  for (const word of setWords()) {
    const inside = await tokenize(`set s {\n  ${word}\n}`);
    assertScope(inside.tokens, word, "keyword.other.set");
    const outside = await tokenize(`let x = ${word}`);
    assertScope(outside.tokens, word, "variable.other");
  }
});

test("every .rhm file in the repository tokenizes cleanly", async () => {
  const files = rhemaFiles();
  assert.ok(files.length > 30, `only ${files.length} .rhm files found`);
  for (const file of files) {
    const { tokens, state } = await tokenize(fs.readFileSync(file, "utf8"));
    const relative = path.relative(REPOSITORY, file);
    const invalid = tokens.find((token) => hasScope(token.scopes, "invalid"));
    assert.equal(invalid, undefined, `${relative}: invalid token '${invalid && invalid.text}'`);
    assert.equal(state.depth, 1, `${relative}: a block or string is still open at the end`);
  }
});

test("declarations name what they declare", async () => {
  const { tokens } = await tokenize(
    [
      'import "calculus.rhm" as calc',
      "attribute cost = 4 split",
      "random n = integer_between(2, 9)",
      "random p = boolean",
      "let total = n * 2",
      "synth latex on E",
      "start E",
      "precedence 1 left + -",
    ].join("\n"),
  );
  assertScope(tokens, "calc", "entity.name.namespace");
  assertScope(tokens, "cost", "variable.other.property");
  assertScope(tokens, "split", "storage.modifier");
  assertScope(tokens, "n", "variable.other.constant");
  assertScope(tokens, "integer_between", "support.function.builtin");
  assertScope(tokens, "boolean", "storage.type.boolean");
  assertScope(tokens, "total", "variable.other.constant");
  assertScope(tokens, "latex", "variable.other.property");
  assertScope(tokens, "on", "keyword.other");
  assertScope(tokens, "E", "entity.name.type.nonterminal");
  assertScope(tokens, "E", "entity.name.type.nonterminal", 1);
  assertScope(tokens, "left", "storage.modifier");
});

test("productions and their equations", async () => {
  const { tokens } = await tokenize(
    [
      "E -> E + calc.F(cost = cost)   when cost >= 1   weight 3 {",
      "  cost = -1",
      "  require $1.value != $3.value",
      '  latex = infix($1, "\\\\cdot", $3) ++ "x^{2}"',
      "}",
      'Q -> "arithmetic" { kind = "arithmetic" }',
    ].join("\n"),
  );
  assertScope(tokens, "E", "entity.name.type.nonterminal");
  assertScope(tokens, "->", "keyword.operator.arrow");
  assertScope(tokens, "calc", "entity.name.namespace");
  assertScope(tokens, "F", "entity.name.type.nonterminal");
  assertScope(tokens, "when", "keyword.control");
  assertScope(tokens, "weight", "keyword.control");
  assertScope(tokens, "require", "keyword.control");
  assertScope(tokens, "$1", "variable.language.child");
  assertScope(tokens, "value", "variable.other.property");
  assertScope(tokens, "latex", "variable.other.property");
  assertScope(tokens, "infix", "support.function.builtin");
  assertScope(tokens, "\\\\", "constant.character.escape");
  assertScope(tokens, "++", "keyword.operator.concatenation");
  assertScope(tokens, "kind", "variable.other.property");
  // Braces in an ordinary string are LaTeX, not prompt holes.
  const plain = tokens.find((token) => token.text.includes("x^{2}"));
  assert.ok(plain && !hasScope(plain.scopes, "meta.interpolation"), "x^{2} was read as a hole");
});

test("prompts have holes, escaped braces and mathematics", async () => {
  const { tokens, state } = await tokenize(
    [
      "# A two-line prompt.",
      'prompt "First term [`a_1 = {first}`]. Find [`a_{{{n}}}`].',
      'Value: {E.latex} from {calc.given}. {answer nth} and {answer E.value}"',
      "answer E.value",
    ].join("\n"),
  );
  assertScope(tokens, "#", "comment.line.number-sign");
  assertScope(tokens, "prompt", "keyword.other.declaration");
  assertScope(tokens, "[`", "punctuation.definition.math.begin");
  assertScope(tokens, "first", "variable.other");
  assertScope(tokens, "first", "meta.embedded.math");
  assertScope(tokens, "{{", "constant.character.escape.brace");
  assertScope(tokens, "}}", "constant.character.escape.brace");
  assertScope(tokens, "n", "meta.interpolation");
  assertScope(tokens, "E", "entity.name.type.nonterminal");
  assertScope(tokens, "calc", "entity.name.namespace");
  assertScope(tokens, "answer", "keyword.other.answer");
  assertScope(tokens, "nth", "meta.interpolation");
  assertScope(tokens, "answer", "keyword.other.declaration", 2);
  assert.equal(state.depth, 1, "the prompt string is still open");
});

test("questions and sets", async () => {
  const { tokens, state } = await tokenize(
    [
      "question nth {",
      "  start Q",
      "  cost = 6",
      '  prompt "Find {answer nth}."',
      "}",
      "set week3 {",
      '  part "Sequences"',
      "    1 of seq.nth",
      "    3 of calc.derivative(cost ~ 6 spread 2 low 2 allowed {4, 6, 8})",
      "    1 of any(nth, calc.integral(cost in {5, -7}))",
      "  distinct",
      "}",
    ].join("\n"),
  );
  assertScope(tokens, "nth", "entity.name.function.question");
  assertScope(tokens, "Q", "entity.name.type.nonterminal");
  assertScope(tokens, "cost", "variable.other.property");
  assertScope(tokens, "week3", "entity.name.function.set");
  assertScope(tokens, "part", "keyword.other.set");
  assertScope(tokens, "seq", "entity.name.namespace");
  assertScope(tokens, "derivative", "entity.name.function.question");
  assertScope(tokens, "cost", "variable.other.property", 1);
  assertScope(tokens, "~", "keyword.operator.around");
  assertScope(tokens, "spread", "keyword.other.set");
  assertScope(tokens, "any", "keyword.other.set");
  assertScope(tokens, "in", "keyword.other.set");
  assertScope(tokens, "7", "constant.numeric");
  assert.equal(state.depth, 1, "a block is still open");
});

test("characters the compiler rejects are marked invalid", async () => {
  const { tokens } = await tokenize("let x = a ; b");
  assertScope(tokens, ";", "invalid.illegal");
});

test("rhema code blocks in Markdown are highlighted", async () => {
  const { tokens } = await tokenize(
    ["Some text.", "", "```rhema", "start E", "```", "", "```text", "start E", "```"].join("\n"),
    "text.html.markdown",
  );
  assertScope(tokens, "start", "keyword.other.declaration");
  const other = tokens.filter((token) => token.text.includes("start"))[1];
  assert.ok(!hasScope(other.scopes, "source.rhema"), "a text block was highlighted as Rhema");
});
