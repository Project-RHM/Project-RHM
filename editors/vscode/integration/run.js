// Runs integration/suite.js inside VS Code against a real rhema command.
//
//   npm run test:integration
//
// RHEMA names the rhema command (default: the development build in this
// repository, generator/_build/install/default/bin/rhema). VSCODE_PATH names
// a VS Code executable to use; without it a copy is downloaded into
// .vscode-test/.

"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { runTests } = require("@vscode/test-electron");

const EXTENSION = path.resolve(__dirname, "..");
const REPOSITORY = path.resolve(EXTENSION, "..", "..");

async function main() {
  const rhema = path.resolve(
    process.env.RHEMA ?? path.join(REPOSITORY, "generator", "_build", "install", "default", "bin", "rhema"),
  );
  if (!fs.existsSync(rhema)) {
    throw new Error(`no rhema command at ${rhema}; build it (dune build @install in generator/) or set RHEMA`);
  }

  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "rhema-vscode-test-"));
  const workspace = path.join(scratch, "workspace");
  fs.cpSync(path.join(__dirname, "workspace"), workspace, { recursive: true });
  fs.mkdirSync(path.join(workspace, ".vscode"));
  fs.writeFileSync(
    path.join(workspace, ".vscode", "settings.json"),
    JSON.stringify({ "rhema.path": rhema }, null, 2),
  );

  try {
    await runTests({
      vscodeExecutablePath: process.env.VSCODE_PATH,
      extensionDevelopmentPath: EXTENSION,
      extensionTestsPath: path.join(__dirname, "suite.js"),
      launchArgs: [
        workspace,
        "--disable-extensions",
        "--disable-workspace-trust",
        "--skip-welcome",
        "--skip-release-notes",
        "--user-data-dir",
        path.join(scratch, "user-data"),
        "--extensions-dir",
        path.join(scratch, "extensions"),
      ],
    });
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
