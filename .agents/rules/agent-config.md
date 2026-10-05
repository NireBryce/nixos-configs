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
  (2026-10-04, #448): every hook fires; an unattended `ask` resolves to
  allow (so a guard that must hold in ZCode denies); `systemMessage` is
  dropped for PreToolUse. Re-check after a ZCode upgrade changes its hook
  docs (bundled skills `zcode-configuration-guide`, `diagnosing-hooks`).

- ZCode has no permission rules, so what carries over from
  `.agents/settings.json` is hook-shaped (#458):
  - An `ask` never pauses an unattended ZCode session (it resolves to
    allow; since #456 the reason still reaches the model as context).
    git-guard therefore
    returns `deny` under ZCode -- a deny is the only decision it enforces
    -- detected from the hook payload (ZCode's carries camelCase
    `hookEventName`/`transcriptPath`; an inherited `ZCODE_PROJECT_DIR`
    doesn't count), except its two asks with a routine documented
    flow (ship's post-merge `push --delete`, use-a-worktree's
    `worktree remove --force`), which stay advisory there only as a
    single command and never for `experimental`/`main`. just-guard
    does nothing under ZCode: it only protects Claude Code's `Bash(just
    ...)` allow rules, and ZCode reads none. In Claude
    Code every ask stays an ask.
  - That payload detection fails open: a ZCode upgrade that renames
    the camelCase fields would leave unattended ZCode sessions at
    ask-as-allow with nothing saying so. `zcode-canary-pretooluse.sh` (Bash matcher)
    cross-checks the payload against the inherited `ZCODE_PROJECT_DIR`
    -- independent signals, since ZCode injects the variable and Claude
    Code does not -- and while they disagree says so on every guarded
    call, in `additionalContext` and `systemMessage`. Under ZCode only
    the model sees it (`systemMessage` is dropped for PreToolUse, see
    above); the human sees it only in Claude Code. The disagreement is
    one of two things and the hook cannot tell which: Claude Code
    inheriting the variable from a ZCode-spawned shell (harmless), or
    the shape having changed (then run the live hook check and update
    the detection in git-guard and just-guard; `test_guards.py` keeps
    the three copies of the detection expression identical). Advisory
    only; it never decides.
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
  - Live-checked 2026-10-05 (ZCode 3.14.3 client, nire-tenacity): a deny
    is enforced -- the tool call is blocked -- and the model sees the
    reason. `permissionDecisionReason` arrives on its own (verified on
    secrets-guard's deny, which carries no `additionalContext`), and
    `additionalContext` rides along wherever the emitter has it. The
    denial text renders with newlines collapsed, so `additionalContext`
    is what keeps a multi-line reason readable: keep carrying both. A
    live ask was observed too: the routine `worktree remove --force`
    ask stayed advisory and the command ran.
  - One-off, not reproduced: on 2026-10-04, pre-restart, a
    `just agent commit ... <<'EOF'` call produced no output and no
    commit. After the client restart the same shape worked end to end
    (heredoc stdin reaches cat, just recipes, and ship.py), so it was
    a client glitch, not a just or hook behaviour. If a heredoc call
    goes silent again, note the client build and retry with the message
    on `< file`.
  - Verified 2026-10-05 (interactive session, screenshot): with a human
    at the client, an `ask` surfaces as ZCode's "Permission required"
    panel -- the guard's `permissionDecisionReason` is the panel body,
    with Allow / Always-allow-this-command / Full access / Deny / and a
    tell-the-model option; Deny leaves the call unrun. So an ask is
    advisory to the model and a prompt to a human who is there. Still
    unverified: what an ask resolves to when nobody answers (#448's
    measured case) -- that is the case the deny split protects against,
    so the split stays. The panel's "Always allow this command" is an
    interactive, per-machine allow rule the UI itself offers: ZCode has
    allow rules even though its docs describe none, and still no deny
    rules (#458 item 2's read-guard therefore stays).
- `.zcode/skills/` was a per-machine symlink farm into `.claude/skills`,
  removed 2026-10-04 (#458 item 4): ZCode scans `.agents/skills/` itself,
  so the farm only duplicated every skill in its list. The path is
  gitignored; per-machine ZCode state belongs under ignored paths, and
  only `.zcode/config.json` is tracked.

- `lesson-reminder-pretooluse.py` (matchers `Bash` and
  `Edit|Write|MultiEdit`, #460) is a Python hook, named `*-pretooluse.py`
  so the wiring tests count it as one; its imported module
  `lessons_map.py` is not a hook. It reads `.agents/lessons-map.toml` from
  the edited file's own tree (a worktree's map, not the main checkout's)
  and puts each matching topic's reminder in `additionalContext` only --
  context for the agent, not a banner for the human -- once per topic per
  session (state keyed by the payload's session id). It never decides; a
  broken map is one `systemMessage` and the call goes ahead. A guard that
  already warns on a topic's paths names itself in that topic's
  `delivered_by`, and a fixture checks it covers every glob.
- A hook's `systemMessage` reaches only the human (Claude Code's UI;
  ZCode drops it for PreToolUse). Anything the agent must read -- a
  warning, or a decision's reason -- also goes in
  `hookSpecificOutput.additionalContext`; `test_guards.py` checks it for
  each warn, ask, and the #458 deny emitters.
