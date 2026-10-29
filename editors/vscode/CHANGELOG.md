# Changelog

## 0.1.0 (unreleased)

- Highlighting for `.rhm` files and for `rhema` code blocks in Markdown:
  prompt fill-ins and PGML mathematics, set words inside `set` blocks only,
  characters the compiler rejects.
- Problems from `rhema check` as you type and on open and save, underlining
  the name each one is about; problems in imported modules are shown on
  their own files.
- **Rhema: Run Question**, **Rhema: Compile to PG** and **Rhema: Check
  File**, asking which question or set when a file has several.
- Settings `rhema.path`, `rhema.includePaths` and `rhema.check.trigger`;
  the first two are not read from untrusted workspaces.
- Folding of blocks, multi-line prompts, comment runs and regions; comments,
  brackets, indentation and snippets.
- Published as a preview, with an icon; `PUBLISHING.md` describes a release.
