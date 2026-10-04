---
paths:
  - ".agents/settings.json"
  - ".zcode/config.json"
  - ".agents/hooks/**"
  - ".githooks/**"
  - "flake/scripts/test_guards.py"
---

# Agent settings, permissions, and guard hooks

- `.agents/settings.json`'s `permissions.allow` pre-approves a short list
  of read-only recipes for every clone and agent. **Only read-only commands
  with a closed argument surface go on it**: exact recipes, or
  `just <recipe> *` only when the recipe is `[positional-arguments]`, so
  arguments reach the script unparsed. Never `nix` itself: its flags and
  `--expr` reach far beyond evaluating this flake, so it stays a prompt;
  `just fingerprint` is the pre-approved drvPath. `test_guards.py` enforces
  both rules.
- `just` runs the nearest justfile up from its cwd, so
  `.agents/hooks/just-guard-pretooluse.sh` asks whenever that isn't this
  repo's `.justfile`; an exact rule like `Bash(just preflight)` only ever
  pre-approves this repo's recipe.
- Read-only `git` forms are already allowed by Claude Code itself. The
  guard hooks run first and a hook's deny wins over an allow rule, but they
  are string matchers, not a boundary.
- `attribution.commit` in `.agents/settings.json` makes Claude Code ask for
  `Co-Authored-By: Claude`. `.githooks/commit-msg` (wired by
  `just install-hooks`, or by the SessionStart hook) is the backstop: it
  auto-corrects only the `Claude <model> <email>` shape; any other agent's
  trailer passes through.
- Guard fixtures live in `flake/scripts/test_guards.py` (`just guards-test`);
  a guard's path patterns and its fixtures change together.

- ZCode reads hooks from `.zcode/config.json` (`hooks.events`, with
  `hooks.enabled: true`), not `.agents/settings.json`. A hook added,
  removed or re-matched in one goes in the other too;
  `test_guards.py` fails when they differ.

- A hook's `systemMessage` reaches only the human (Claude Code's UI;
  ZCode drops it for PreToolUse). Anything the agent must read -- a
  warning, or why an `ask` fired, since an ask is ignored in auto modes
  and by ZCode -- also goes in `hookSpecificOutput.additionalContext`;
  `test_guards.py` checks it for each warn and ask.
