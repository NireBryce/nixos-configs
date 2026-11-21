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
- **Default to bash, or ideally Python.** Suggest another language (`awk`,
  `nu`, a Nix expression) only when it is a clear win, in one sentence, and
  let the user decide: each one adds a toolchain every host must build and
  isn't covered by `just short-names`, `ruff` or the tests. Skip the
  suggestion for a few-line script or one that extends an existing file.
- `.agents/scripts/` (behind `just agent`) is the exception: agent-written
  scripts for recurring lookups, any language. Adding one: skill
  `agent-scripts`.
- **A script's entry point is a `just` recipe**, not a path typed by hand: a
  one-line recipe in `.justfile` for `flake/scripts/`, or in
  `.agents/scripts/agent.just` for agent scripts. The recipe is what shows
  up in bare `just` and in permission prompts. The recipe only points at the
  script; logic stays in the script. If a recipe needs real logic, ask the
  user when you propose the script.
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
  `ruff check` (F821 is in the pinned set) and the file's tests, and grep for callers passing
  the old parameter name as a keyword (`rename-names callers` does; §54).
- **Python style the repo lints for** (`flake/scripts/py_style.py`
  checks these with ruff in preflight and CI; run it with `just py-style`).
  The rule list is the root `ruff.toml` (F401, F541, F821, F841, E702, E731),
  which `py_style.py` passes with `--config`; bare `ruff check` reads the same
  file and matches the preflight:
  - one statement per line: no `a; b`, no `if x: return` on one line (E702);
  - `def` for a named function, never `name = lambda ...` (E731); an inline
    `key=lambda item: ...` is fine;
  - no unused imports (F401), undefined names (F821), unused locals (F841) or unused loop variables
    (B007: name it `_` or iterate `.values()`; the check does not run B007);
  - an f-string has a placeholder, otherwise it is a plain string (F541);
  - no trailing whitespace in `.nix` and `.py` files (`.editorconfig`;
    `py_style.py` checks it too).
