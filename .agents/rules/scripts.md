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
  commit (§1 in `wiki/lessons-learned.md`).
- A `preflight` recipe step must use literal paths, not `{{scripts}}`:
  `.agents/scripts/preflight-brief.py` runs each step verbatim as just's
  `--show` prints it, without substitutions.
- `preflight-brief.py` runs preflight's steps concurrently. A step that
  writes into the repo tree (as `just lint` rewrites its baseline while
  `just check` hashes `flake/`) goes in its `SERIAL_LAST`, run after the
  rest; its header says how the other steps were shown not to write.
