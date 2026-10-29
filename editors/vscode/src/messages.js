// @ts-check
// Reading what the rhema command prints. Nothing here depends on VS Code, so
// the unit tests run under plain Node.

"use strict";

/**
 * One problem reported by `rhema`.
 * @typedef {object} Problem
 * @property {string} file      the file as rhema printed it
 * @property {number} line      0-based; 0 when rhema gave no position
 * @property {number} column    0-based; 0 when rhema gave no position
 * @property {boolean} located  whether rhema gave a line and column
 * @property {"error" | "warning"} severity
 * @property {string} message
 */

// file:line:column: error: message, or file: error: message. The file may
// itself contain colons (a Windows drive letter), so it is matched up to the
// first ":line:column: " or ": error: " rather than split at every colon.
const LOCATED = /^(.+?):(\d+):(\d+): (error|warning): (.*)$/;
const UNLOCATED = /^(.+?): (error|warning): (.*)$/;

/**
 * The problems in rhema's output, in the order printed.
 * @param {string} output
 * @returns {Problem[]}
 */
function parseProblems(output) {
  /** @type {Problem[]} */
  const problems = [];
  for (const line of output.split(/\r?\n/)) {
    const located = LOCATED.exec(line);
    if (located) {
      problems.push({
        file: located[1],
        line: Math.max(0, Number(located[2]) - 1),
        column: Math.max(0, Number(located[3]) - 1),
        located: true,
        severity: /** @type {"error" | "warning"} */ (located[4]),
        message: located[5],
      });
      continue;
    }
    const unlocated = UNLOCATED.exec(line);
    if (unlocated) {
      problems.push({
        file: unlocated[1],
        line: 0,
        column: 0,
        located: false,
        severity: /** @type {"error" | "warning"} */ (unlocated[2]),
        message: unlocated[3],
      });
    }
  }
  return problems;
}

/**
 * What `rhema list` says a file declares.
 * @typedef {object} Listing
 * @property {{ name: string, detail: string }[]} questions
 * @property {{ name: string, detail: string }[]} sets
 */

/**
 * The questions and sets in the output of `rhema list`.
 * @param {string} output
 * @returns {Listing}
 */
function parseListing(output) {
  /** @type {Listing} */
  const listing = { questions: [], sets: [] };
  /** @type {{ name: string, detail: string }[] | null} */
  let section = null;
  for (const line of output.split(/\r?\n/)) {
    const heading = /^([a-z]+):/.exec(line);
    if (heading) {
      section =
        heading[1] === "questions" ? listing.questions : heading[1] === "sets" ? listing.sets : null;
      continue;
    }
    const entry = /^\s+([A-Za-z_][A-Za-z0-9_]*)\s+(.*)$/.exec(line);
    if (section && entry) section.push({ name: entry[1], detail: entry[2].trim() });
  }
  return listing;
}

/**
 * The first name a message quotes, such as foo in "unknown name 'foo'". rhema
 * may report such a problem at the start of the equation that holds the
 * name, so the editor looks for the name itself on that line.
 * @param {string} message
 * @returns {string | undefined}
 */
function quotedName(message) {
  return /'(\$[0-9]+|[A-Za-z_][A-Za-z0-9_]*)'/.exec(message)?.[1];
}

module.exports = { parseProblems, parseListing, quotedName };
