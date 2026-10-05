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
  `test_guards.py` fails when they differ. Live-checked on ZCode 3.14.3
  (2026-10-04, #448): every hook fires; an `ask` is treated as allow (so
  a guard that must hold in ZCode denies); `systemMessage` is dropped for
  PreToolUse. Re-check after a ZCode upgrade changes its hook docs
  (bundled skills `zcode-configuration-guide`, `diagnosing-hooks`).

- ZCode has no permission rules, so what carries over from
  `.agents/settings.json` is hook-shaped (#458):
  - An `ask` never pauses a ZCode session (treated as allow; since #456
    the reason still reaches the model as context). git-guard therefore
    returns `deny` under ZCode (`ZCODE_PROJECT_DIR` set in the hook's
    environment) -- a deny is the only decision it enforces -- except its
    two asks with a routine documented
    flow (ship's post-merge `push --delete`, use-a-worktree's
    `worktree remove --force`), which stay advisory there. just-guard
    does nothing under ZCode: it only protects Claude Code's `Bash(just
    ...)` allow rules, and ZCode reads none. In Claude
    Code every ask stays an ask. If the bundled docs' `PermissionRequest`
    event or an interactive mode turns out to honor an ask (untested),
    this split is worth revisiting.
  - `permissions.deny`'s Read rules (`//run/secrets/**`,
    `//run/secrets.d/**`) have no ZCode equivalent;
    `secrets-read-guard-pretooluse.sh` (matcher `Read|Grep|Glob`) is the
    hook-side translation, wired into both configs. It normalizes each
    path first, denies a Grep rooted at `/` or `/run`, and checks Glob
    and Grep patterns as paths. In Claude Code the
    rules and the hook both apply; the fixture pins the rule list.
  - session-start.sh prints `behind origin/experimental: N` when the
    checkout is behind the last-fetched ref, so a separate clone
    (ZCode's workspace was one) announces its staleness (#458 item 3)
    instead of acting on it unnoticed.
  - Still unverified: whether a ZCode model sees a deny's
    `permissionDecisionReason`, or only `additionalContext` (which is
    why the deny emitters this fix touched also carry the reason in
    `additionalContext`); the pre-existing deny emitters (git-guard's
    dirty-tree deny, secrets-guard) do not, and get it added only if a
    live check shows it is needed.
- `.zcode/skills/` was a per-machine symlink farm into `.claude/skills`,
  removed 2026-10-04 (#458 item 4): ZCode scans `.agents/skills/` itself,
  so the farm only duplicated every skill in its list. The path is
  gitignored; per-machine ZCode state belongs under ignored paths, and
  only `.zcode/config.json` is tracked.

- A hook's `systemMessage` reaches only the human (Claude Code's UI;
  ZCode drops it for PreToolUse). Anything the agent must read -- a
  warning, or a decision's reason -- also goes in
  `hookSpecificOutput.additionalContext`; `test_guards.py` checks it for
  each warn, ask, and the #458 deny emitters.
