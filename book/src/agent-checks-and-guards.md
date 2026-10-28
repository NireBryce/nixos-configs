# Checks, guards and hooks

Several layers stop or remind an agent working in this repo: the harness
hooks under `.agents/hooks/`, the git hooks under `.githooks/`, and the static
checks that preflight and CI run. Each section below gives one layer's
trigger, what it enforces, and whether a failure blocks the action, warns, or
only reminds. The last sections cover testing a guard and the pre-approved
command list.

## How a harness hook answers

A [hook](glossary.md#hook-claude-code) is a command the agent harness runs at
a fixed event. Its JSON reply decides whether the tool call goes ahead.
Claude Code reads the hook list from `.agents/settings.json` (seen as
`.claude/settings.json`). ZCode reads the same scripts from
`.zcode/config.json`, and `flake/scripts/tests/test_guards.py` fails when
the two lists differ. The events used here are `SessionStart`, `PreToolUse`
(before a tool runs, matched by tool name: `Bash`, `Edit|Write|MultiEdit`,
`Read|Grep|Glob`) and `PostToolUse` (after it runs).

A hook's reply takes one of five forms:

- deny: `permissionDecision: "deny"` stops the call, and the reason
  reaches the agent in every permission mode.
- ask: `permissionDecision: "ask"` withholds approval so the human is
  prompted. Under an auto permission mode an ask is a no-op and nobody is
  prompted, so the guards that must hold use deny.
- warn: a `systemMessage` shown to the human in Claude Code, plus the
  same text in `hookSpecificOutput.additionalContext` for the agent. The
  call goes ahead.
- remind: `additionalContext` only, for the agent. The call goes ahead.
- block (after the call): `decision: "block"` with a reason, from a
  `PostToolUse` hook. The tool has already run; the reason is fed back to the
  agent. Only the secrets output scan uses it.

A *[guard hook](glossary.md#guard-hook)* is a hook that denies, asks or warns
on a pattern in the tool call. Every guard checks for `jq` first. Without
`jq`, the guard emits a `systemMessage` saying the call was not checked, so
the call never passes unannounced. The guards match command strings and
paths. The rules file states that they are string matchers and not a
security boundary.

Source: `.agents/settings.json`; `.zcode/config.json`;
`.agents/rules/agent-config.md`; header of
`.agents/hooks/git-guard-pretooluse.sh`;
`flake/scripts/tests/test_guards.py`, docstring.

## Every layer at a glance

| Layer | Triggered by | Enforces | On failure | Lives in |
|---|---|---|---|---|
| Session-start hook | Session start | Puts host, branch, worktree, dirty count, hooks path and helper names in context; sets `core.hooksPath` to `.githooks` when unset | Reminds | `.agents/hooks/session-start.sh` |
| git guard | `Bash` call that runs git | No discarding uncommitted work; a pause before force pushes, branch force-deletes, history rewrites and similar | Denies discarding operations on a dirty tree (a clean tree passes); asks for the pause-worthy operations (denies under ZCode, except two routine cleanups) | `.agents/hooks/git-guard-pretooluse.sh` |
| just guard | `Bash` call that runs `just` | A `Bash(just …)` allow rule only ever approves this repo's `.justfile` | Asks | `.agents/hooks/just-guard-pretooluse.sh` |
| Untracked-nix guard | `Bash` call that evaluates the flake | `git add` before `nix eval` | Warns | `.agents/hooks/nix-untracked-guard-pretooluse.sh` |
| Secrets command guard | `Bash` call that runs `sops` or touches `/run/secrets` | No decrypted file in output; metadata-only access to deployed secrets | Blocks | `.agents/hooks/secrets-guard-pretooluse.sh` |
| Secrets read guard | `Read`, `Grep` or `Glob` | No read-tool access under `/run/secrets` or `/run/secrets.d` | Blocks | `.agents/hooks/secrets-read-guard-pretooluse.sh` |
| Secrets output scan | After a `Bash` call | Flags secret-shaped text in the output | Blocks after the call has run, with a reason telling the agent to name it only | `.agents/hooks/secrets-guard-posttooluse.sh` |
| Impermanence edit guard | `Edit`/`Write` in the impermanence tree or a host hardware module | Safety context before the edit | Warns | `.agents/hooks/impermanence-edit-guard-pretooluse.sh` |
| Lesson-reminder hook | `Bash` or `Edit`/`Write` matching a topic in `.agents/lessons-map.toml` | The lesson for that area, once per session | Reminds | `.agents/hooks/lesson-reminder-pretooluse.py` |
| Edit-check hook | After an `Edit`/`Write` | Stale sibling pair, shell-shaped `${…}` in a Nix `''` string, untracked new module | Reminds | `.agents/hooks/edit-check-posttooluse.sh` |
| ZCode canary | `Bash` call | Detects that the ZCode payload detection may be disarmed | Warns | `.agents/hooks/zcode-canary-pretooluse.sh` |
| pre-commit | `git commit` | Lint ratchet, or the offline checks where nix cannot run | Blocks the commit | `.githooks/pre-commit` |
| commit-msg | `git commit` | Canonical `Co-Authored-By: Claude` trailer | Rewrites the trailer | `.githooks/commit-msg` |
| pre-push | `git push` | Preflight's offline steps where nix cannot run | Blocks the push | `.githooks/pre-push` |
| `just wiki-lint` | Preflight, CI, by hand | Docs agree with the repo | Fails | `wiki/meta/scripts/check_wiki.py` |
| `just modules` | Preflight, CI, by hand | No untracked `.nix`; static and evaluated module graphs agree | Fails | `flake/scripts/modules.py` |
| `just lint` | Preflight, CI, pre-commit | statix, deadnix and oversized-file counts never rise | Fails | `flake/scripts/lint.py` |
| `just check` | Preflight, CI | Every host's toplevel and home evaluate (`module-orphans` fails only when built, so `--no-build` skips it; `just modules` is the orphan gate) | Fails | `flake/modules/checks.nix` |
| Trailer check | CI, on a PR's commits | No non-canonical Claude trailer | Fails the PR | `flake/scripts/check_trailers.py` |

Source: each file named in the table; `.agents/settings.json`;
`.github/workflows/check.yml`; `.justfile`, `preflight`.

## The session-start hook

The session-start hook hands the agent the repo state that `AGENTS.md`
otherwise asks it to check by hand. It reports:

- the hostname and the branch;
- whether the checkout is a linked [worktree](glossary.md#worktree) or the
  shared main checkout;
- the dirty-path count and `git worktree list`;
- on `experimental`, how many commits it is behind the last-fetched
  `origin/experimental`;
- the state of `core.hooksPath`;
- the `just agent` helper names.

When `core.hooksPath` is unset, the hook runs `git config core.hooksPath
.githooks`, the same command as `just install-hooks`. A different existing
value is reported and left alone. The hook never fails: it exits 0 on every
path.

Source: `.agents/hooks/session-start.sh`.

## The git guard

The git guard stops a git command that would discard uncommitted work, and
pauses before other git actions that are hard to undo. It works in two
tiers.

- State-checked tier. For `reset --hard`, `checkout .`, `clean -f`, a
  forced `checkout` or `switch`, `checkout` onto paths, and `rm -f`, the
  guard runs `git status --porcelain` in the repository the command targets.
  A clean tree passes with no message. A dirty tree is denied, with the dirty
  paths listed and an instruction to ask the user. When the guard cannot tell
  which repository the command acts on (anything beyond plain `cd <path>` and
  `git [-C <path>] <subcommand> <args>` segments), it asks.
- Ask tier. These all ask: a force push without `--force-with-lease`, a
  remote branch deletion, `push --mirror`, `branch -D`, `filter-branch` or
  `filter-repo`, `stash drop` or `clear`, `restore` onto the worktree,
  `read-tree -u`, `worktree remove --force`, and resetting an existing branch
  pointer.

Under ZCode an ask resolves to allow, so the ask tier becomes denies. Two
routine cleanup steps the skills use are exempt when run as a single
command: the post-merge remote branch delete and `worktree remove --force`.
The remote delete is never exempt for a command that names `experimental` or
`main`.

The guard's status checks run with `GIT_DIR`, `GIT_WORK_TREE` and
`GIT_INDEX_FILE` cleared and `core.fsmonitor` off, so the check never runs
a program the repository's config names.

Source: header and body of `.agents/hooks/git-guard-pretooluse.sh`;
`.agents/rules/agent-config.md`.

## The just guard

The just guard keeps each `Bash(just <recipe>)` allow rule meaning this
repo's recipe. `just` runs the nearest justfile above its working directory,
and an allow rule matches only the command text. The guard resolves which
justfile each `just` call would use. It asks when:

- the justfile is not the repo's own `.justfile`;
- an option picks a justfile, directory, shell or dotenv;
- a `JUST_*` variable is set in the environment;
- it cannot parse the call.

The guard asks and never denies, so a prompt still lets other justfiles run.
Under ZCode, which reads no allow rules, the guard does nothing.

Source: `.agents/hooks/just-guard-pretooluse.sh`, header;
`.agents/rules/agent-config.md`.

## The untracked-nix guard

The untracked-nix guard warns when a command that evaluates the flake runs
while untracked `.nix` files exist. A flake in a git repository ignores
untracked files, so a module written minutes ago does not exist for that
evaluation.

The guard matches `nix eval`, `build`, `run`, `develop`,
`profile` and `flake`, `nh os|home|d`, and the `just` recipes that evaluate
(`build`, `boot`, `switch`, `check`, `update`, `diff`, `fingerprint`,
`fingerprint-home`). It runs `git ls-files --others` in the repository that
contains the tool call's working directory, so it is correct when the
session runs inside a worktree. It only warns, because untracked files are
often intended.

Source: `.agents/hooks/nix-untracked-guard-pretooluse.sh`, header.

## The secrets guards

The secrets hooks keep secret values out of the conversation. The command
and read guards block before a call; the output scan checks after it.

- Command guard (`PreToolUse`, `Bash`). It denies a `sops` decrypt whose
  pipeline stage prints the whole decrypted file, `sops exec-env` and
  `exec-file`, and any command touching `/run/secrets` other than a metadata
  command (`ls`, `stat`, `test`, a plain `find`). The deny reason names the
  narrower form that answers the same question, such as `just
  read-sops-names` for key names.
- Read guard (`PreToolUse`, `Read|Grep|Glob`). It denies a read-tool call
  whose normalized target is under `/run/secrets` or `/run/secrets.d`, and a
  Grep rooted at `/` or `/run`. In Claude Code, `permissions.deny` in
  `.agents/settings.json` has matching `Read(...)` rules; the hook is the
  version ZCode can enforce.
- Output scan (`PostToolUse`, `Bash`). It looks for known secret shapes
  in a command's output and, on a hit, tells the agent to stop, refer to the
  value by name only, and flag rotation. Ciphertext (`ENC[...]`) is not
  flagged.

Source: headers of `.agents/hooks/secrets-guard-pretooluse.sh`,
`.agents/hooks/secrets-read-guard-pretooluse.sh` and
`.agents/hooks/secrets-guard-posttooluse.sh`; `.agents/settings.json`,
`permissions.deny`; `.agents/skills/secrets-hygiene/SKILL.md`.

## The impermanence edit guard

The impermanence edit guard warns when an `Edit` or `Write` lands in
`flake/modules/general-config/impermanence/` or in a host hardware module
under `flake/modules/host-config/*/hardware/`. The warning says what the
code there does on boot, and points at `AGENTS.md`'s Safety section and the
skill `impermanence-initrd`. For a host hardware module it also recommends
`just boot` over `just switch`.

The guard warns and does not ask, because most edits there are ordinary
maintenance. It matches paths only, so a Bash-tool edit of the same files
does not trip it. The guard also delivers the `impermanence` topic of the
lessons map. That topic names the guard in `delivered_by`, so the
lesson-reminder hook skips it.

Source: `.agents/hooks/impermanence-edit-guard-pretooluse.sh`, header;
`.agents/lessons-map.toml`, topic `impermanence`.

## The lesson-reminder hook

The lesson-reminder hook puts one topic's one-line reminder into the agent's
context before a call that touches the topic's area, once per topic per
session. It reads `.agents/lessons-map.toml` from the nearest ancestor of the
edited file (or the Bash call's working directory), so a worktree uses its
own map.

A topic matches an edit by its `paths` globs, or a Bash command by its
`command` regex. `remind_on` narrows a path topic to file creation, or
switches the reminder off for topics too broad to remind on. The hook never
decides whether a call runs. Most errors become one `systemMessage` and the
call goes ahead; a state-file error, or a python3 older than 3.11, produces
no message.

Source: `.agents/hooks/lesson-reminder-pretooluse.py`, docstring;
`.agents/hooks/lessons_map.py`, docstring; `.agents/lessons-map.toml`,
header.

## The edit-check hook

The edit-check hook runs these checks the moment a file is written, ahead of
preflight or the next evaluation:

- For a page under `wiki/`, `check_wiki.py siblings`, filtered to that
  page's pair.
- For a `.nix` file, `.agents/hooks/nix_shell_interp.py`, which flags
  shell-shaped `${…}` inside a Nix `''` string that cannot be working Nix
  (`${x[1]}`, `${x:-y}`, `${#x}`). A bare `${VAR}` is not flagged, because
  only evaluation can say whether it is in scope.
- For a new untracked `.nix` file under `flake/modules/`, the `git add`
  reminder.

The hook replies with `additionalContext` only and never blocks: the edit
has already happened.

Source: `.agents/hooks/edit-check-posttooluse.sh`, header;
`.agents/hooks/nix_shell_interp.py`, docstring.

## The ZCode canary

The ZCode canary warns when the git and just guards' ZCode detection may be
disarmed. Both guards detect ZCode from camelCase fields in the hook payload.
The canary cross-checks that against `ZCODE_PROJECT_DIR` in the environment.
When the environment says ZCode but the payload carries none of the camelCase
fields, the canary says so on every Bash call. The reverse mismatch produces
no message. The canary never blocks.

Source: `.agents/hooks/zcode-canary-pretooluse.sh`, header;
`.agents/rules/agent-config.md`.

## Git hooks

The git hooks in `.githooks/` run only once `core.hooksPath` points at that
directory. `just install-hooks` sets it, and the session-start hook sets it
when it is unset. The setting lives in the shared `.git/config`, so it covers
every worktree.

- `pre-commit` runs the [lint ratchet](glossary.md#lint-ratchet)
  (`lint.py check`) through `flake/scripts/with-nix-tools.sh`, which enters
  the dev shell when statix and deadnix are not on `PATH`. A regression
  blocks the commit. When the ratchet improves, `lint.py` rewrites
  `flake/scripts/lint-baseline.json` and the hook stages it. When
  `with-nix-tools.sh` exits 75 (no nix, or the flake inputs cannot be
  fetched), the hook runs `offline_checks.py staged` instead.
- `commit-msg` rewrites a `Co-Authored-By: Claude …` trailer that carries a
  model name or email into the canonical `Co-Authored-By: Claude`. It fixes
  the trailer and never rejects it. Other agents' trailers pass through
  untouched.
- `pre-push` does nothing where nix works. Where `with-nix-tools.sh`
  exits 75 it runs `offline_checks.py preflight` and blocks the push on a
  failure.

The [offline checks](glossary.md#offline-checks) have two modes:

- `staged` compiles staged `.py` files, runs `bash -n` on shell scripts and
  hooks, parses `.json` and `.toml`, runs `nix-instantiate --parse` on
  `.nix`, and runs the wiki lint without its nix-dependent `generated` check.
- `preflight` runs the preflight recipe's `python3` steps, except those the
  script lists as needing nix, and names the steps left to CI.

Source: `.githooks/pre-commit`, `.githooks/commit-msg`, `.githooks/pre-push`;
`flake/scripts/with-nix-tools.sh`; `flake/scripts/offline_checks.py`,
docstring; `.justfile`, `install-hooks`; `.agents/hooks/session-start.sh`.

## Static checks

The static checks compare what the repo says with what the repo is, and all
of them run inside [preflight](glossary.md#preflight).

`check_wiki.py` (`just wiki-lint`) is a set of registered sub-checks, and
`check_wiki.py check` runs them all. Grouped by the class of drift they catch:

- Claims about the module tree and hosts: `imports` and `table` (a
  category page's "Imported by" text against the hosts that import it),
  `counts` (host-count phrases against `hosts.nix`), `secrets` (the
  enrollment sentence against `.sops.yaml`), `routes` (routed URLs against
  the Caddy config).
- Names that can be renamed out from under a doc: `recipes` (`just
  <recipe>` mentions against the `.justfile`), `skills` (skill mentions
  against `.agents/skills/`), `docrefs` (`just agent <helper>` names, skill
  paths, quoted section headings, moved directories, and bare counts of
  files, subdirectories, modules, hosts, recipes or skills).
- Links: `links` (every relative link resolves) and `anchors` (every
  `#fragment` matches a heading's slug).
- Page structure: `contents` (the `## Contents` block matches the
  headings), `dates` (a well-formed, non-future `_Last modified:_` line),
  `siblings` (pairs link each other, and a sibling is not older than its
  source), `generated` (each `wiki_gen.py` region matches a fresh render).
- Agent files: `skill-files` (skill frontmatter shape, and the same
  name and link lookups inside skills), `rules` (rules-file frontmatter and
  globs), `lessons` (the lessons index and `.agents/lessons-map.toml`).

The other static checks:

- `modules.py` (`just modules`) reports untracked `.nix` files and drift
  between the module graph wiki-lint reads from the files and the evaluated
  `moduleGraph`.
- `lint.py` (`just lint`) is the lint ratchet: statix, deadnix and an
  oversized-file check, compared against `flake/scripts/lint-baseline.json`.
  A commit may lower a count and never raise it.
- `check_trailers.py` fails when a commit in a range carries a Claude
  `Co-Authored-By` trailer other than the canonical one. CI runs it over a
  PR's own commits (`HEAD^1..HEAD^2` of the merge ref), so it catches clones
  that never installed the commit-msg hook.
- `checks.nix` defines the flake checks `just check` evaluates with `nix
  flake check --all-systems --no-build`: every host's toplevel (NixOS and
  darwin), every Home Manager home, `module-orphans`, and unit checks of the
  `flake.lib` helpers. The helper checks fail at evaluation.
  `module-orphans` fails through a builder, which `--no-build` never runs,
  so `just modules` carries the orphan check
  ([adding a module](adding-a-module.md), Step 5).

Source: `wiki/meta/scripts/check_wiki.py`, docstring and `@check`
registrations; `wiki/meta/scripts/wiki_gen.py`; `flake/scripts/modules.py`,
docstring; `flake/scripts/lint.py`, docstring; `flake/scripts/check_trailers.py`,
docstring; `flake/modules/checks.nix`; `.justfile`, `check`.

## Tests for the guards

A checker is tested against a case it should catch, in the same commit that
adds it. `AGENTS.md` and lesson §1 state the rule, and the lessons-map
`scripts` topic reminds an agent of it when it creates a script.
`flake/scripts/tests/test_guards.py` (`just guards-test`, in preflight and
CI) holds the fixtures for the hooks:

- each hook driven with synthetic JSON input, against throwaway git
  repositories where the verdict depends on git state;
- each hook again with `jq` off `PATH`, which must warn rather than allow;
- `.githooks/commit-msg` against a temporary message file, and `bash -n`
  over every hook;
- wiring: every hook script on disk is executable and named in
  `.agents/settings.json`, and every hook the settings name exists.

A guard's path patterns and its fixtures change together. When an existing
check fires on new work, fix the check's model before reaching for its
escape flag (lesson §23). `wiki/meta/scripts/check_wiki.py` asks the
same of a new wiki check: register it with `@check` and give it a fixture
test that fails without it.

Source: `AGENTS.md`, "Before calling it done"; `.agents/rules/scripts.md`;
`.agents/rules/agent-config.md`; `flake/scripts/tests/test_guards.py`,
docstring; `.agents/lessons-map.toml`, topic `scripts`;
[agent-lessons-learned.md](../../wiki/agent-lessons-learned.md), §1;
[23-fix-the-checks-model.md](../../wiki/agent-lessons-learned/23-fix-the-checks-model.md).

## `permissions.allow` and wildcard rules

`permissions.allow` in `.agents/settings.json` pre-approves a short list of
read-only commands for every clone and agent. Only commands with a closed
argument surface may join it:

- An exact recipe (`Bash(just wiki-lint)`) qualifies.
- A wildcard rule (`Bash(just threads *)`) qualifies only when the recipe is
  marked `[positional-arguments]`. Its arguments then reach the script
  unparsed and never pass through the recipe's shell line.
- A rule for `nix` itself never qualifies, because its flags and `--expr`
  reach far beyond evaluating this flake. `just fingerprint` is the
  pre-approved way to get a `drvPath`.

`test_guards.py` enforces these rules; the test is skipped where `just` is
not on `PATH`. It fails on any `Bash(nix …)` rule, on a wildcard outside the
`Bash(just <recipe> *)` form, and on a wildcard recipe that `just --show`
does not mark `[positional-arguments]`. Read-only
git forms are allowed by Claude Code itself, and a hook's deny outranks an
allow rule.

Source: `.agents/rules/agent-config.md`; `.agents/settings.json`;
`flake/scripts/tests/test_guards.py`,
`test_wildcard_allow_rules_quote_their_arguments`.
