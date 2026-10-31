// @ts-check
// Folding ranges for Rhema. Indentation alone folds badly here: a prompt is
// a string whose continuation lines start in column one, which would end the
// fold of the question around it. Nothing here depends on VS Code.

"use strict";

/**
 * @typedef {object} Fold
 * @property {number} start  0-based first line
 * @property {number} end    0-based last line
 * @property {"region" | "comment" | undefined} kind
 */

const REGION_START = /^\s*#\s*region\b/;
const REGION_END = /^\s*#\s*endregion\b/;

/**
 * Folds for braces and strings that span lines, runs of comment lines, and
 * `# region` ... `# endregion` markers.
 * @param {string} text
 * @returns {Fold[]}
 */
function foldingRanges(text) {
  const lines = text.split(/\r?\n/);
  /** @type {Fold[]} */
  const folds = [];
  /** @type {number[]} */
  const braces = [];
  /** @type {number[]} */
  const regions = [];
  let stringStart = -1;
  let commentStart = -1;

  /** @param {number} start @param {number} end @param {Fold["kind"]} kind */
  const add = (start, end, kind) => {
    if (end > start) folds.push({ start, end, kind });
  };

  for (let number = 0; number < lines.length; number++) {
    const line = lines[number];
    const wholeLineComment = stringStart < 0 && /^\s*#/.test(line);

    if (stringStart < 0 && REGION_START.test(line)) regions.push(number);
    else if (stringStart < 0 && REGION_END.test(line) && regions.length > 0) {
      add(/** @type {number} */ (regions.pop()), number, "region");
    }

    // A run of comment lines folds as one; region markers stand apart.
    const plainComment = wholeLineComment && !REGION_START.test(line) && !REGION_END.test(line);
    if (plainComment && commentStart < 0) commentStart = number;
    if (!plainComment && commentStart >= 0) {
      add(commentStart, number - 1, "comment");
      commentStart = -1;
    }

    for (let index = 0; index < line.length; index++) {
      const character = line[index];
      if (stringStart >= 0) {
        if (character === "\\" && (line[index + 1] === '"' || line[index + 1] === "\\")) index++;
        else if (character === '"') {
          add(stringStart, number, undefined);
          stringStart = -1;
        }
      } else if (character === "#") break;
      else if (character === '"') stringStart = number;
      else if (character === "{") braces.push(number);
      else if (character === "}" && braces.length > 0) {
        // The closing line stays visible, as in other languages.
        add(/** @type {number} */ (braces.pop()), number - 1, undefined);
      }
    }
  }
  if (commentStart >= 0) add(commentStart, lines.length - 1, "comment");
  return folds;
}

module.exports = { foldingRanges };
