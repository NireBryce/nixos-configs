---
paths:
  - "**/*.sh"
  - "**/*.py"
  - "**/*.just"
  - ".justfile"
---

# Scripts and recipes

- **Don't bury Python inside a bash script.** `python3 -c '...'` heredocs
  get no highlighting, linting, or indentation help, exactly when quoting
  bugs stop being visible. A little Python: a real `.py` in
  `flake/scripts/`. Mostly Python: the whole thing in Python (`modules.py`
  is the precedent). A bash-wrapping-Nix-wrapping-Python checker here
  shipped both bugs the shape invites.
- `.agents/scripts/` (behind `just agent`) is the exception: agent-written
  scripts for recurring lookups, any language. Adding one: skill
  `agent-scripts`.
- A new checker is tested against a case it should catch, in the same
  commit (§1 in `wiki/agent-lessons-learned.md`).
- A `preflight` recipe step must use literal paths, not `{{scripts}}`:
  `.agents/scripts/preflight-brief.py` runs each step verbatim as just's
  `--show` prints it, without substitutions.
- `preflight-brief.py` runs preflight's steps concurrently. A step that
  writes into the repo tree (as `just lint` rewrites its baseline while
  `just check` hashes `flake/`) goes in its `SERIAL_LAST`, run after the
  rest; its header says how the other steps were shown not to write.
- **Name variables for what they hold, never one character.** `result`, `repo`,
  `match`, `path`, `line`; `_` for an ignored value is the only exception.
  This covers loop and comprehension variables, lambda parameters, `except ...
  as` names and import aliases. `just short-names` (in preflight) fails a
  Python file that gains one; `just short-names list <file>` shows where. Files
  not yet cleaned are in `flake/scripts/short-names-baseline.json`, whose counts
  may only fall: after cleaning one, `just short-names update`. When renaming,
  edit by syntax tree rather than text (`just agent rename-names`), then run
  `ruff check --select F821` and the file's tests, and grep for callers passing
  the old parameter name as a keyword (`rename-names callers` does; §54).
