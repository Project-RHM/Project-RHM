// @ts-check
// The Rhema extension: problems from `rhema check` as you type, the Run and
// Compile commands, and folding. Highlighting and snippets are declarative
// (see package.json) and work without this file.

"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const vscode = require("vscode");
const { parseListing, parseProblems, quotedName } = require("./messages");
const { foldingRanges } = require("./folding");

const LANGUAGE = "rhema";
const CHECK_DELAY_MS = 400;
const TIMEOUT_MS = 60_000;

// The same word as language-configuration.json, so that a problem underlines
// the whole name it is about.
const WORD = /\$[0-9]+|[A-Za-z_][A-Za-z0-9_]*|-?[0-9]+/;

/** @type {vscode.OutputChannel} */
let output;

/**
 * @typedef {object} Result
 * @property {number | null} code   the exit status; null when rhema did not run
 * @property {string} stdout
 * @property {string} stderr
 * @property {boolean} missing      the command was not found
 * @property {string} [failure]     why rhema did not run, when it did not
 */

/**
 * A running rhema process and its outcome.
 * @param {string} command
 * @param {string[]} args
 * @param {string} cwd
 * @returns {{ result: Promise<Result>, kill: () => void }}
 */
function spawnRhema(command, args, cwd) {
  /** @type {childProcess.ChildProcess | undefined} */
  let child;
  const result = new Promise((resolve) => {
    child = childProcess.execFile(
      command,
      args,
      { cwd, timeout: TIMEOUT_MS, maxBuffer: 64 * 1024 * 1024, windowsHide: true },
      (error, stdout, stderr) => {
        const code = /** @type {any} */ (error)?.code;
        if (!error) resolve({ code: 0, stdout, stderr, missing: false });
        else if (typeof code === "number") resolve({ code, stdout, stderr, missing: false });
        else
          resolve({
            code: null,
            stdout,
            stderr,
            missing: code === "ENOENT" || code === "EACCES",
            failure: error.killed ? "it was stopped" : error.message,
          });
      },
    );
  });
  return { result, kill: () => child?.kill() };
}

/**
 * The folder that relative settings are read against.
 * @param {vscode.Uri | undefined} resource
 */
function baseFolder(resource) {
  const folder = resource && vscode.workspace.getWorkspaceFolder(resource);
  return (folder ?? vscode.workspace.workspaceFolders?.[0])?.uri.fsPath;
}

/**
 * A path from the settings: `~` is the home directory, and a relative path
 * is relative to the workspace folder.
 * @param {string} setting
 * @param {vscode.Uri | undefined} resource
 */
function settingPath(setting, resource) {
  if (setting === "~" || setting.startsWith("~/")) return path.join(os.homedir(), setting.slice(1));
  if (path.isAbsolute(setting)) return setting;
  const base = baseFolder(resource);
  return base ? path.resolve(base, setting) : setting;
}

/**
 * The rhema command and the -I options for a file.
 * @param {vscode.Uri | undefined} resource
 */
function settings(resource) {
  const config = vscode.workspace.getConfiguration("rhema", resource);
  const configured = (config.get("path", "rhema") || "rhema").trim();
  // A bare name is looked up on PATH; anything with a separator is a path.
  const command = /[\\/]/.test(configured) || configured.startsWith("~")
    ? settingPath(configured, resource)
    : configured;
  const includes = config
    .get("includePaths", /** @type {string[]} */ ([]))
    .flatMap((directory) => ["-I", settingPath(directory, resource)]);
  const trigger = config.get("check.trigger", "onType");
  return { command, includes, trigger };
}

let warnedMissing = false;

/** @param {string} command */
async function reportMissing(command) {
  if (warnedMissing) return;
  warnedMissing = true;
  const choice = await vscode.window.showWarningMessage(
    `Rhema could not run '${command}'. Install Rhema (opam install rhema), or set rhema.path to the rhema command.`,
    "Open Settings",
  );
  if (choice === "Open Settings") {
    await vscode.commands.executeCommand("workbench.action.openSettings", "rhema.path");
  }
}

/** @param {vscode.TextDocument} document */
function isRhema(document) {
  return document.languageId === LANGUAGE;
}

// ---------------------------------------------------------------------------
// Problems
// ---------------------------------------------------------------------------

/**
 * Checks Rhema documents and shows what rhema reports in the Problems panel.
 * A check of one document may report problems in the files it imports; those
 * are kept per checked document, so that checking it again replaces them.
 */
class Checker {
  /** @param {vscode.DiagnosticCollection} collection */
  constructor(collection) {
    this.collection = collection;
    /** @type {Map<string, Map<string, vscode.Diagnostic[]>>} checked document -> file -> problems */
    this.found = new Map();
    /** @type {Map<string, NodeJS.Timeout>} */
    this.timers = new Map();
    /** @type {Map<string, { generation: number, kill: () => void }>} */
    this.running = new Map();
    this.generation = 0;
    /** @type {Set<string>} */
    this.published = new Set();
  }

  /** @param {vscode.TextDocument} document */
  schedule(document) {
    const key = document.uri.toString();
    clearTimeout(this.timers.get(key));
    this.timers.set(
      key,
      setTimeout(() => {
        this.timers.delete(key);
        void this.check(document);
      }, CHECK_DELAY_MS),
    );
  }

  /** @param {vscode.TextDocument} document */
  async check(document) {
    if (!isRhema(document) || document.isClosed) return;
    const key = document.uri.toString();
    const { command, includes, trigger } = settings(document.uri);
    if (trigger === "off") {
      this.forget(document);
      return;
    }
    clearTimeout(this.timers.get(key));
    this.running.get(key)?.kill();
    const generation = ++this.generation;

    // A saved file is checked where it is. Unsaved text is written to a
    // temporary file, and the document's own directory is searched first for
    // what it imports, as it would be beside the real file.
    const onDisk = document.uri.scheme === "file" && !document.isDirty;
    const directory = document.uri.scheme === "file" ? path.dirname(document.fileName) : undefined;
    let temporary;
    let file;
    let cwd;
    /** @type {string[]} */
    let args;
    if (onDisk) {
      file = document.fileName;
      cwd = /** @type {string} */ (directory);
      args = ["check", ...includes, path.basename(file)];
    } else {
      // The real path, so that it compares equal to the one rhema prints.
      temporary = await fs.promises.realpath(
        await fs.promises.mkdtemp(path.join(os.tmpdir(), "rhema-check-")),
      );
      const name = document.uri.scheme === "file" ? path.basename(document.fileName) : "untitled.rhm";
      file = path.join(temporary, name);
      await fs.promises.writeFile(file, document.getText());
      cwd = directory ?? temporary;
      args = ["check", ...(directory ? ["-I", directory] : []), ...includes, file];
    }

    const run = spawnRhema(command, args, cwd);
    this.running.set(key, { generation, kill: run.kill });
    const result = await run.result;
    if (temporary) await fs.promises.rm(temporary, { recursive: true, force: true });
    if (this.running.get(key)?.generation !== generation) return;
    this.running.delete(key);
    if (document.isClosed) return;

    if (result.missing) {
      this.forget(document);
      void reportMissing(command);
      return;
    }
    if (result.code === null) {
      output.appendLine(`rhema check did not finish for ${document.fileName}: ${result.failure}`);
      return;
    }

    /** @type {Map<string, vscode.Diagnostic[]>} */
    const byFile = new Map([[key, []]]);
    const problems = parseProblems(`${result.stderr}\n${result.stdout}`);
    for (const problem of problems) {
      const reported = path.resolve(cwd, problem.file);
      const own = reported === file || (document.uri.scheme === "file" && reported === document.fileName);
      const uri = own ? document.uri : vscode.Uri.file(reported);
      const diagnostic = new vscode.Diagnostic(
        own ? rangeIn(document, problem) : point(problem),
        problem.message,
        problem.severity === "warning" ? vscode.DiagnosticSeverity.Warning : vscode.DiagnosticSeverity.Error,
      );
      diagnostic.source = "rhema";
      const list = byFile.get(uri.toString()) ?? [];
      list.push(diagnostic);
      byFile.set(uri.toString(), list);
    }
    if (result.code !== 0 && problems.length === 0) {
      output.appendLine(`rhema ${args.join(" ")} (exit ${result.code}):`);
      output.appendLine(result.stderr || result.stdout);
    }
    this.found.set(key, byFile);
    this.publish();
  }

  /** @param {vscode.TextDocument} document */
  forget(document) {
    const key = document.uri.toString();
    clearTimeout(this.timers.get(key));
    this.timers.delete(key);
    this.running.get(key)?.kill();
    this.running.delete(key);
    if (this.found.delete(key)) this.publish();
  }

  publish() {
    /** @type {Map<string, vscode.Diagnostic[]>} */
    const merged = new Map();
    for (const byFile of this.found.values()) {
      for (const [uri, diagnostics] of byFile) {
        merged.set(uri, [...(merged.get(uri) ?? []), ...diagnostics]);
      }
    }
    for (const uri of this.published) {
      if (!merged.has(uri)) this.collection.delete(vscode.Uri.parse(uri));
    }
    for (const [uri, diagnostics] of merged) this.collection.set(vscode.Uri.parse(uri), diagnostics);
    this.published = new Set(merged.keys());
  }

  dispose() {
    for (const timer of this.timers.values()) clearTimeout(timer);
    for (const running of this.running.values()) running.kill();
  }
}

/**
 * The range a problem underlines in an open document: the word at its
 * position, or the first line for a problem about the whole file.
 * @param {vscode.TextDocument} document
 * @param {import("./messages").Problem} problem
 */
function rangeIn(document, problem) {
  const line = Math.min(problem.line, document.lineCount - 1);
  const text = document.lineAt(line);
  if (!problem.located) return text.range;
  const column = Math.min(problem.column, text.text.length);
  const name = quotedName(problem.message);
  if (name) {
    const escaped = name.replace(/\$/g, "\\$");
    const pattern = new RegExp(`(?<![A-Za-z0-9_$])${escaped}(?![A-Za-z0-9_])`, "g");
    const found = [...text.text.matchAll(pattern)].map((match) => /** @type {number} */ (match.index));
    const at = found.find((index) => index >= column) ?? found[0];
    if (at !== undefined) return new vscode.Range(line, at, line, at + name.length);
  }
  const position = new vscode.Position(line, column);
  const word = document.getWordRangeAtPosition(position, WORD);
  if (word) return word;
  const end = position.translate(0, position.character < text.text.length ? 1 : 0);
  return new vscode.Range(position, end);
}

/** @param {import("./messages").Problem} problem */
function point(problem) {
  const position = new vscode.Position(problem.line, problem.column);
  return new vscode.Range(position, position);
}

// ---------------------------------------------------------------------------
// Run and Compile
// ---------------------------------------------------------------------------

/** @type {Map<string, string>} file -> label of the question or set last chosen */
const lastChoice = new Map();

/**
 * The Rhema document a command acts on: the file it was invoked on, or the
 * active editor's.
 * @param {vscode.Uri | undefined} uri
 */
async function targetDocument(uri) {
  const document = uri
    ? await vscode.workspace.openTextDocument(uri)
    : vscode.window.activeTextEditor?.document;
  if (!document || !isRhema(document)) {
    void vscode.window.showWarningMessage("Open a Rhema (.rhm) file first.");
    return undefined;
  }
  if (document.isUntitled) {
    void vscode.window.showWarningMessage("Save the file first; rhema reads it from disk.");
    return undefined;
  }
  if (document.isDirty && !(await document.save())) return undefined;
  return document;
}

/**
 * Asks which of the file's questions or sets to use, unless it has only one.
 * @param {vscode.TextDocument} document
 * @param {"run" | "compile"} action
 * @param {Checker} checker
 * @returns {Promise<{ label: string, args: string[], set?: string } | undefined>}
 */
async function chooseTarget(document, action, checker) {
  const { command, includes } = settings(document.uri);
  const cwd = path.dirname(document.fileName);
  const listed = await spawnRhema(command, ["list", ...includes, path.basename(document.fileName)], cwd).result;
  if (listed.missing) {
    warnedMissing = false;
    void reportMissing(command);
    return undefined;
  }
  if (listed.code !== 0) {
    output.appendLine(listed.stderr || listed.stdout || `rhema list failed: ${listed.failure}`);
    void checker.check(document);
    void vscode.window.showErrorMessage(
      `${path.basename(document.fileName)} has problems; see the Problems panel.`,
    );
    return undefined;
  }
  const listing = parseListing(listed.stdout);
  const choices = [
    ...listing.questions.map((question) => ({
      label: question.name,
      description: question.detail,
      args: ["--question", question.name],
      set: undefined,
    })),
    ...listing.sets.map((set) => ({
      label: set.name,
      description: `set: ${set.detail}`,
      args: ["--run", set.name],
      set: set.name,
    })),
  ];
  if (choices.length === 0) {
    void vscode.window.showInformationMessage(
      `${path.basename(document.fileName)} is a library: it declares no question or set of its own.`,
    );
    return undefined;
  }
  if (choices.length === 1) return choices[0];
  const last = lastChoice.get(document.fileName);
  choices.sort((a, b) => Number(b.label === last) - Number(a.label === last));
  const choice = await vscode.window.showQuickPick(choices, {
    placeHolder: action === "run" ? "Run which question or set?" : "Compile which question or set?",
  });
  if (choice) lastChoice.set(document.fileName, choice.label);
  return choice;
}

/**
 * @param {"run" | "compile"} action
 * @param {Checker} checker
 * @param {vscode.Uri | undefined} uri
 */
async function runOrCompile(action, checker, uri) {
  const document = await targetDocument(uri);
  if (!document) return;
  const target = await chooseTarget(document, action, checker);
  if (!target) return;

  const { command, includes } = settings(document.uri);
  const cwd = path.dirname(document.fileName);
  const file = path.basename(document.fileName);
  const args = action === "run"
    ? ["run", ...target.args, ...includes, file]
    : [...target.args, ...includes, file];

  output.show(true);
  output.appendLine(`$ cd ${cwd}`);
  output.appendLine(`$ ${command} ${args.join(" ")}`);
  const result = await vscode.window.withProgress(
    { location: vscode.ProgressLocation.Window, title: `rhema: ${target.label}` },
    () => spawnRhema(command, args, cwd).result,
  );
  if (result.stdout) output.append(result.stdout.endsWith("\n") ? result.stdout : `${result.stdout}\n`);
  if (result.stderr) output.append(result.stderr.endsWith("\n") ? result.stderr : `${result.stderr}\n`);
  if (result.missing) {
    warnedMissing = false;
    void reportMissing(command);
    return;
  }
  if (result.code !== 0) {
    output.appendLine(result.code === null ? `(did not finish: ${result.failure})` : `(exit ${result.code})`);
    void checker.check(document);
    void vscode.window.showErrorMessage(`rhema could not ${action} ${target.label}; see the Rhema output.`);
    return;
  }
  output.appendLine("");
  if (action === "compile") {
    // As the command names it: after the set, or after the file.
    const written = path.join(cwd, `${target.set ?? path.basename(file, ".rhm")}.pg`);
    output.appendLine(`Wrote ${written}`);
    // Not awaited: the command is done once the file is written.
    void vscode.window.showInformationMessage(`Wrote ${path.basename(written)}.`, "Open").then((choice) => {
      if (choice === "Open") void vscode.window.showTextDocument(vscode.Uri.file(written));
    });
  }
}

// ---------------------------------------------------------------------------
// Activation
// ---------------------------------------------------------------------------

/** @param {vscode.ExtensionContext} context */
function activate(context) {
  output = vscode.window.createOutputChannel("Rhema");
  const checker = new Checker(vscode.languages.createDiagnosticCollection(LANGUAGE));
  const checkOpen = () => vscode.workspace.textDocuments.filter(isRhema).forEach((d) => void checker.check(d));

  context.subscriptions.push(
    output,
    checker.collection,
    checker,
    vscode.workspace.onDidOpenTextDocument((document) => void checker.check(document)),
    vscode.workspace.onDidChangeTextDocument((event) => {
      if (isRhema(event.document) && settings(event.document.uri).trigger === "onType") {
        checker.schedule(event.document);
      }
    }),
    // A saved file may be imported by the others, so all open files are
    // checked again.
    vscode.workspace.onDidSaveTextDocument((document) => {
      if (isRhema(document)) checkOpen();
    }),
    vscode.workspace.onDidCloseTextDocument((document) => checker.forget(document)),
    vscode.workspace.onDidChangeConfiguration((event) => {
      if (event.affectsConfiguration("rhema")) {
        warnedMissing = false;
        checkOpen();
      }
    }),
    vscode.commands.registerCommand("rhema.run", (uri) => runOrCompile("run", checker, uri)),
    vscode.commands.registerCommand("rhema.compile", (uri) => runOrCompile("compile", checker, uri)),
    vscode.commands.registerCommand("rhema.check", async (uri) => {
      const document = uri ? await vscode.workspace.openTextDocument(uri) : vscode.window.activeTextEditor?.document;
      if (document && isRhema(document)) {
        warnedMissing = false;
        await checker.check(document);
        await vscode.commands.executeCommand("workbench.actions.view.problems");
      }
    }),
    vscode.languages.registerFoldingRangeProvider(LANGUAGE, {
      provideFoldingRanges(document) {
        return foldingRanges(document.getText()).map(
          (fold) =>
            new vscode.FoldingRange(
              fold.start,
              fold.end,
              fold.kind === "region"
                ? vscode.FoldingRangeKind.Region
                : fold.kind === "comment"
                  ? vscode.FoldingRangeKind.Comment
                  : undefined,
            ),
        );
      },
    }),
  );
  checkOpen();
}

function deactivate() {}

module.exports = { activate, deactivate };
