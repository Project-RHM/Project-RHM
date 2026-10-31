// The integration tests, run inside VS Code by integration/run.js against the
// workspace in integration/workspace and a real rhema command.

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vscode = require("vscode");

const TIMEOUT_MS = 15_000;

/** Waits until `condition()` is true. */
async function waitFor(condition, what) {
  const deadline = Date.now() + TIMEOUT_MS;
  while (!condition()) {
    if (Date.now() > deadline) throw new Error(`timed out waiting for ${what}`);
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

function fileUri(name) {
  return vscode.Uri.file(path.join(vscode.workspace.workspaceFolders[0].uri.fsPath, name));
}

/** The problems on `uri`, as "line:column text: message", sorted. */
function problems(uri, document) {
  return vscode.languages
    .getDiagnostics(uri)
    .map((d) => {
      const text = document ? ` ${document.getText(d.range)}` : "";
      return `${d.range.start.line + 1}:${d.range.start.character + 1}${text}: ${d.message}`;
    })
    .sort();
}

const tests = {
  async "a saved file's problems underline the names they are about"() {
    const document = await vscode.workspace.openTextDocument(fileUri("broken.rhm"));
    await vscode.window.showTextDocument(document);
    assert.equal(document.languageId, "rhema");
    await waitFor(() => vscode.languages.getDiagnostics(document.uri).length === 3, "three problems");
    assert.deepEqual(problems(document.uri, document), [
      "4:20 foo: unknown name 'foo'",
      "5:1 E: rule 'E' does not say how to compute 'value'; add 'value = ...' inside its braces",
      "5:12 latex: 'latex' is not declared; add 'attribute latex = ...' or 'synth latex'",
    ]);
    assert.ok(vscode.languages.getDiagnostics(document.uri).every((d) => d.source === "rhema"));
  },

  async "unsaved edits are checked as you type"() {
    const editor = await vscode.window.showTextDocument(fileUri("broken.rhm"));
    const document = editor.document;
    await editor.edit((edit) => {
      edit.replace(new vscode.Range(3, 0, 4, document.lineAt(4).text.length), [
        'E -> "a" { value = 1 }',
        'E -> "b" { value = 2 }',
      ].join("\n"));
    });
    assert.ok(document.isDirty);
    await waitFor(() => vscode.languages.getDiagnostics(document.uri).length === 0, "no problems");
    assert.ok(!fs.readFileSync(document.fileName, "utf8").includes("value = 2"), "the file was written");

    await vscode.commands.executeCommand("workbench.action.files.revert");
    await waitFor(() => vscode.languages.getDiagnostics(document.uri).length === 3, "the problems again");
  },

  async "problems in an imported module are shown on that module"() {
    const document = await vscode.workspace.openTextDocument(fileUri("uses_lib.rhm"));
    await vscode.window.showTextDocument(document);
    const helper = fileUri(path.join("lib", "helper.rhm"));
    await waitFor(() => vscode.languages.getDiagnostics(helper).length === 1, "the module's problem");
    assert.deepEqual(problems(helper), ["3:20: unknown name 'missing_name'"]);
    assert.deepEqual(problems(document.uri, document), [
      '2:1 import: import "lib/helper.rhm" as h: the module has problems of its own',
    ]);
  },

  async "Compile writes the PG file beside the source"() {
    const pg = path.join(vscode.workspace.workspaceFolders[0].uri.fsPath, "single.pg");
    assert.ok(!fs.existsSync(pg));
    await vscode.commands.executeCommand("rhema.compile", fileUri("single.rhm"));
    assert.ok(fs.existsSync(pg), "single.pg was not written");
    assert.match(fs.readFileSync(pg, "utf8"), /DOCUMENT\(\);/);
  },

  async "Run finishes on a file with one question"() {
    await vscode.commands.executeCommand("rhema.run", fileUri("single.rhm"));
  },

  async "an untitled document is checked too"() {
    const document = await vscode.workspace.openTextDocument({
      language: "rhema",
      content: "synth value on E\nstart E\nE -> \"a\" { value = nope }\n",
    });
    await vscode.window.showTextDocument(document);
    await waitFor(() => problems(document.uri).length > 0, "a problem in the untitled document");
    assert.ok(problems(document.uri, document).includes("3:20 nope: unknown name 'nope'"));
  },

  async "a missing rhema command clears the problems rather than failing"() {
    const config = vscode.workspace.getConfiguration("rhema");
    const original = config.get("path");
    const broken = fileUri("broken.rhm");
    await waitFor(() => vscode.languages.getDiagnostics(broken).length === 3, "the problems");
    await config.update("path", "/nonexistent/rhema", vscode.ConfigurationTarget.Workspace);
    try {
      await waitFor(() => vscode.languages.getDiagnostics(broken).length === 0, "no problems");
    } finally {
      await config.update("path", original, vscode.ConfigurationTarget.Workspace);
    }
    await waitFor(() => vscode.languages.getDiagnostics(broken).length === 3, "the problems again");
  },

  async "the commands are contributed"() {
    const commands = await vscode.commands.getCommands(true);
    for (const command of ["rhema.run", "rhema.compile", "rhema.check"]) {
      assert.ok(commands.includes(command), `${command} is missing`);
    }
  },
};

async function run() {
  const failures = [];
  for (const [name, body] of Object.entries(tests)) {
    try {
      await body();
      console.log(`ok - ${name}`);
    } catch (error) {
      failures.push(name);
      console.log(`not ok - ${name}\n  ${error instanceof Error ? error.stack : error}`);
    }
  }
  console.log(`# pass ${Object.keys(tests).length - failures.length}\n# fail ${failures.length}`);
  if (failures.length > 0) throw new Error(`${failures.length} integration test(s) failed`);
}

module.exports = { run };
