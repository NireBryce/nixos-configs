# Checks, guards and hooks

This chapter is for anyone debugging why a hook denied, warned or reminded, or
adding a guard or check. It lists the hooks under `.agents/hooks/`, the git
hooks under `.githooks/` and the static checks that preflight and CI run,
with the exemptions and failure modes the summary table leaves out. A
contributor who only edits modules can skip it; the commit-time flow is in
[git and agent workflows](git-and-agent-workflows.md).

## How a harness hook answers

A [hook](glossary.md#hook-claude-code) is a command the agent harness runs at
a fixed event. Its JSON reply decides whether the tool call goes ahead.
Claude Code reads the hook list from `.agents/settings.json` (seen as
`.claude/settings.json`). ZCode (a second agent harness) reads the same scripts from
`.zcode/config.json`, and `flake/scripts/tests/test_guards.py` fails when
the two lists differ. The events used are `SessionStart`, `PreToolUse`
(before a tool runs, matched by tool name: `Bash`, `Edit|Write|MultiEdit`,
`Read|Grep|Glob`) and `PostToolUse` (after it runs).

A hook's reply takes one of five forms:

- deny: `permissionDecision: "deny"` stops the call, and the reason
  reaches the agent in every permission mode.
- ask: `permissionDecision: "ask"` prompts the human. Under an auto
  permission mode an ask is a no-op and nobody is prompted, so the guards
  that must hold use deny.
- warn: a `systemMessage` shown to the human (in Claude Code), plus the
  same text in `hookSpecificOutput.additionalContext` for the agent. The
  call goes ahead.
- remind: `additionalContext` only, for the agent. The call goes ahead.
- block (after the call): `decision: "block"` with a reason, from a
  `PostToolUse` hook. The tool has already run; the reason is fed back to the
  agent. Only the secrets output scan uses it.

A *[guard hook](glossary.md#guard-hook)* is a hook that denies, asks or warns
on a pattern in the tool call. Every guard checks for `jq` first; without
it, the guard emits a `systemMessage` saying the call was not checked. The
guards match command strings and paths, so they are string matchers and not
a security boundary.

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
| Lesson-reminder hook ([lessons](glossary.md#lesson)) | `Bash` or `Edit`/`Write` matching a topic in `.agents/lessons-map.toml` | The lesson for that area, once per session | Reminds | `.agents/hooks/lesson-reminder-pretooluse.py` |
| Edit-check hook | After an `Edit`/`Write` | Stale sibling pair, shell-shaped `${…}` in a Nix `''` string, untracked new module | Reminds | `.agents/hooks/edit-check-posttooluse.sh` |
| ZCode canary | `Bash` call | Detects that the ZCode payload detection may be disarmed | Warns | `.agents/hooks/zcode-canary-pretooluse.sh` |
| pre-commit | `git commit` | [Lint ratchet](glossary.md#lint-ratchet), or the [offline checks](glossary.md#offline-checks) where nix cannot run | Blocks the commit | `.githooks/pre-commit` |
| commit-msg | `git commit` | Canonical `Co-Authored-By: Claude` trailer | Rewrites the trailer | `.githooks/commit-msg` |
| pre-push | `git push` | Preflight's offline steps where nix cannot run | Blocks the push | `.githooks/pre-push` |
| `just wiki-lint` | [Preflight](glossary.md#preflight), CI, by hand | Docs agree with the repo | Fails | the factcheck flake input (`flake/scripts/factcheck.sh`), with this repo's checkers in `tools/docchecks/` |
| `just modules` | Preflight, CI, by hand | No untracked `.nix`; static and evaluated module graphs agree | Fails | `flake/scripts/modules.py` |
| `just lint` | Preflight, CI, pre-commit | statix, deadnix and oversized-file counts never rise | Fails | `flake/scripts/lint.py` |
| `just check` | Preflight, CI | Every host's toplevel and home evaluate (including `module-orphans` and `module-class-contents`, set to `"eval"` so they fail under `--no-build`) | Fails | `flake/modules/checks.nix` |
| Trailer check | CI, on a PR's commits | No non-canonical Claude trailer | Fails the PR | `flake/scripts/check_trailers.py` |

## The session-start hook

The session-start hook also reports whether the checkout is a linked worktree
or the shared checkout, how many commits `experimental` is behind the
last-fetched `origin/experimental` (only on `experimental`), and the output
of `git worktree list`. When
`core.hooksPath` is unset it runs `git config core.hooksPath .githooks`, the
same command as `just install-hooks`; a different existing value is reported
and left alone. The hook exits 0 on every path.

## The git guard

The guard works in two tiers.

- State-checked tier: `reset --hard`, `checkout .`, `clean -f`, a forced
  `checkout` or `switch`, `checkout` onto paths, and `rm -f`. The guard runs
  `git status --porcelain` in the repository the command targets. A clean tree
  passes with no message; a dirty tree is denied with the dirty paths listed and an instruction to ask
  the user.
  When the guard cannot tell which repository the command acts on (anything
  beyond plain `cd <path>` and `git [-C <path>] <subcommand> <args>`
  segments), it asks.
- Ask tier: a force push without `--force-with-lease`, a remote branch
  deletion, `push --mirror`, `branch -D`, `filter-branch` or `filter-repo`,
  `stash drop` or `clear`, `restore` onto the worktree, `read-tree -u`,
  `worktree remove --force`, and resetting an existing branch pointer.

Under ZCode an ask resolves to allow, so the ask tier becomes denies. Two
routine cleanup steps the skills use are exempt when run as a single
command: the post-merge remote branch delete and `worktree remove --force`.
The remote delete is never exempt for a command that names `experimental` or
`main`.

The status checks run with `GIT_DIR`, `GIT_WORK_TREE` and `GIT_INDEX_FILE`
cleared and `core.fsmonitor` off, so the check never runs a program the
repository's config names.

## The just guard

`just` runs the nearest justfile above its working directory, and an allow
rule matches only the command text. The guard resolves which justfile each
`just` call would use and asks when:

- the justfile is not the repo's own `.justfile`;
- an option picks a justfile, directory, shell or dotenv;
- a `JUST_*` variable is set in the environment;
- it cannot parse the call.

The guard asks and never denies. Under ZCode, which reads no allow rules, it
does nothing.

## The untracked-nix guard

A flake in a git repository ignores untracked files, so a module written
minutes ago does not exist for the evaluation. The guard matches `nix eval`,
`build`, `run`, `develop`, `profile` and `flake`, `nh os|home|d`, and the
`just` recipes that evaluate (`build`, `boot`, `switch`, `check`, `update`,
`diff`, `fingerprint`, `fingerprint-home`). It runs `git ls-files --others` in
the repository containing the call's working directory, so it is correct
inside a worktree. It warns and never asks, because untracked files are often
intended.

## The secrets guards

- Command guard (`Bash`). It denies a `sops` decrypt whose pipeline stage
  prints the whole decrypted file, `sops exec-env` and `exec-file`, and any
  command touching `/run/secrets` other than a metadata command (`ls`,
  `stat`, `test`, a plain `find`). The deny reason names the narrower form
  that answers the same question, such as `just read-sops-names` for key
  names.
- Read guard (`Read|Grep|Glob`). It denies a call whose normalized target is
  under `/run/secrets` or `/run/secrets.d`, and a Grep rooted at `/` or
  `/run`. In Claude Code, `permissions.deny` in `.agents/settings.json` has
  matching `Read(...)` rules; the hook is the version ZCode can enforce.
- Output scan (`PostToolUse`, `Bash`). On a hit it tells the agent to stop,
  refer to the value by name only, and flag rotation. Ciphertext
  (`ENC[...]`) is not flagged.

See the skill `secrets-hygiene` for what to do after a leak.

## The impermanence edit guard

The guard covers `flake/modules/general-config/impermanence/` and host
hardware modules under `flake/modules/host-config/*/hardware/`. The warning
says what the code there does on boot and points at `AGENTS.md`'s Safety
section and the skill `impermanence-initrd`. For a host hardware module it
also recommends `just boot` over `just switch`.

It warns and does not ask, because most edits there are ordinary
maintenance. It matches paths only, so a Bash-tool edit of the same files
does not trip it. It also delivers the `impermanence` topic of the lessons
map; that topic names the guard in `delivered_by`, so the lesson-reminder
hook skips it.

## The lesson-reminder hook

The hook reads `.agents/lessons-map.toml` from the nearest ancestor of the
edited file (or the Bash call's working directory), so a worktree uses its
own map. A topic matches an edit by its `paths` globs, or a Bash command by
its `command` regex. `remind_on` narrows a path topic to file creation, or
switches the reminder off for topics too broad to remind on.

The hook never decides whether a call runs. Most errors become one
`systemMessage` and the call goes ahead; a state-file error, or a python3
older than 3.11, produces no message.

## The edit-check hook

The hook runs three checks after a write:

- Under `wiki/`: `factcheck siblings`, filtered to that page's pair.
- A `.nix` file: `.agents/hooks/nix_shell_interp.py`, which flags
  shell-shaped `${…}` inside a Nix `''` string that cannot be working Nix
  (`${x[1]}`, `${x:-y}`, `${#x}`). A bare `${VAR}` is not flagged, because
  only evaluation can say whether it is in scope.
- A new untracked `.nix` file under `flake/modules/`: the `git add` reminder.

The edit has already happened, so the hook never blocks.

## The ZCode canary

The git and just guards detect ZCode from camelCase fields in the hook
payload. The canary cross-checks that against `ZCODE_PROJECT_DIR` in the
environment. When the environment says ZCode but the payload carries none of
the camelCase fields, it warns on every Bash call. The reverse mismatch
produces no message.

## Git hooks

The hooks in `.githooks/` run only once `core.hooksPath` points at that
directory. `just install-hooks` sets it, and the session-start hook sets it
when it is unset. The setting lives in the shared `.git/config`, so it covers
every worktree. The commit-time flow is in
[git and agent workflows](git-and-agent-workflows.md).

- `pre-commit` runs the [lint ratchet](glossary.md#lint-ratchet)
  (`lint.py check`) through `flake/scripts/with-nix-tools.sh`, which enters
  the dev shell when statix and deadnix are not on `PATH`. When the ratchet
  improves, `lint.py` rewrites `flake/scripts/lint-baseline.json` and the hook
  stages it. When `with-nix-tools.sh` exits 75 (no nix, or the flake inputs
  cannot be fetched), the hook runs `offline_checks.py staged` instead.
- `commit-msg` rewrites a `Co-Authored-By: Claude …` trailer that carries a
  model name or email into the canonical `Co-Authored-By: Claude`. It never
  rejects a trailer. Other agents' trailers pass through untouched.
- `pre-push` does nothing where nix works. Where `with-nix-tools.sh`
  exits 75 it runs `offline_checks.py preflight`.

The [offline checks](glossary.md#offline-checks) have two modes:

- `staged` compiles staged `.py` files, runs `bash -n` on shell scripts and
  hooks, parses `.json` and `.toml`, runs `nix-instantiate --parse` on
  `.nix`, and runs the wiki lint without its nix-dependent `generated` check.
- `preflight` runs the preflight recipe's `python3` steps, except those the
  script lists as needing nix, and names the steps left to CI.

## Running the guards by hand

The hook scripts run only inside Claude Code and ZCode, and only on their
`Bash` tool. For any other harness, shell or tool,
`just agent guard-check -- '<command>'` (`.agents/scripts/guard_check.py`)
builds the same `PreToolUse` payload and pipes it through every hook that
`.agents/settings.json` attaches to the `Bash` matcher, so a hook added there
is covered with no edit to the script. It executes nothing itself, and it
never hands a `settings.json` entry to a shell: an entry must be a bare
script under `.agents/hooks/`, or it is refused and counts as a hook that
could not run, because the script may be run in a checkout nobody has vetted.
Hook output is printed with control characters replaced. Its exit
status is 0 for no objection, 2 for a deny, 3 for an ask and 4 when a hook
could not run (a missing `jq` counts, because the command was then not fully
checked). It is an honor system, and it covers only the pre-call `Bash` hooks:
the output scan for secrets and the edit and read guards have no manual form.
The skill `guards-without-hooks` tells an agent when to call it.
`.agents/scripts/test_guard_check.py` pins the exit-code mapping with fake
hooks and runs the real hooks against a temporary repo.

## Static checks

All of these run inside [preflight](glossary.md#preflight). factcheck
(`just wiki-lint`) is a set of registered sub-checks, and `factcheck
check` runs them all; the repo-specific sub-checks and the generated
regions are this repo's plugins under `tools/docchecks/`.

**factcheck is experimental** (it replaced
`wiki/meta/scripts/check_docs.py`, and is young upstream). It was
adopted only after parity verification -- identical findings to the
checker it replaced, on an untouched tree and with defects injected --
but it has not yet guarded this repo through real merges, and the
tool's API will still move. Until
it has a track record here: read a finding before acting on it, treat an
unexpected one as a prompt to check the tool before the doc, and if it
misbehaves, revert or pin the `factcheck` flake input -- the checker is
upstream, and this PR is the revert for the adoption.

| Sub-check | What it compares |
|---|---|
| `imports`, `table` | A category page's "Imported by" text against the hosts that import it |
| `counts` | Host-count phrases against `hosts.nix` |
| `secrets` | The enrollment sentence against `.sops.yaml` |
| `routes` | Routed URLs against the Caddy config |
| `recipes` | `just <recipe>` mentions against the `.justfile` |
| `skills` | Skill mentions against `.agents/skills/` |
| `docrefs` | `just agent <helper>` names, skill paths, quoted section headings, moved directories, and bare counts of files, subdirectories, modules, hosts, recipes or skills |
| `links`, `anchors` | Every relative link resolves; every `#fragment` matches a heading's slug |
| `contents` | The `## Contents` block against the headings |
| `dates` | A well-formed, non-future `_Last modified:_` line |
| `siblings` | Pairs link each other, and a sibling is not older than its source |
| `generated` | Each `wiki_gen.py` region against a fresh render |
| `skill-files` | Skill frontmatter shape, and the same name and link lookups inside skills |
| `rules` | Rules-file frontmatter and globs |
| `lessons` | The lessons index against `.agents/lessons-map.toml` |

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
  darwin), every Home Manager home, `module-orphans`, `module-class-contents`, and unit
  checks of the `flake.lib` helpers. All of them fail at evaluation, which
  `--no-build` still performs: the two library checks are set to `"eval"`
  ([adding a module](adding-a-module.md), Step 5).

## Tests for the guards

A checker is tested against a case it should catch, in the same commit that
adds it ([lesson 1](../../wiki/agent-lessons-learned/1-success-is-not-tested.md)).
The lessons-map `scripts` topic reminds an agent of this when it creates a
script. `flake/scripts/tests/test_guards.py` (`just guards-test`, in
preflight and CI) holds the fixtures for the hooks:

- each hook driven with synthetic JSON input, against throwaway git
  repositories where the verdict depends on git state;
- each hook again with `jq` off `PATH`, which must warn rather than allow;
- `.githooks/commit-msg` against a temporary message file, and `bash -n`
  over every hook;
- wiring: every hook script on disk is executable and named in
  `.agents/settings.json`, and every hook the settings name exists.

A guard's path patterns and its fixtures change together. When an existing
check fires on new work, fix the check's model before reaching for its
escape flag ([lesson 23](../../wiki/agent-lessons-learned/23-fix-the-checks-model.md)).
A new wiki check is registered with `@check` and gets a fixture test that
fails without it.

## `permissions.allow` and wildcard rules

`permissions.allow` in `.agents/settings.json` pre-approves a short list of
read-only commands. Only commands with a closed argument surface may join it:

- An exact recipe (`Bash(just wiki-lint)`) qualifies.
- A wildcard rule (`Bash(just threads *)`) qualifies only when the recipe is
  marked `[positional-arguments]`, so its arguments reach the script
  unparsed and never pass through the recipe's shell line.
- A rule for `nix` itself never qualifies, because its flags and `--expr`
  reach far beyond evaluating this flake. `just fingerprint` is the
  pre-approved way to get a `drvPath`.

`test_guards.py` enforces this (skipped where `just` is not on `PATH`). It
fails on any `Bash(nix …)` rule, on a wildcard outside the
`Bash(just <recipe> *)` form, and on a wildcard recipe that `just --show`
does not mark `[positional-arguments]`. Claude Code allows read-only git
forms itself, and a hook's deny outranks an allow rule.

## Sources

- `.agents/settings.json`, `.zcode/config.json`, `.agents/lessons-map.toml`
- `.agents/hooks/` scripts named in the table; `.agents/hooks/lessons_map.py`,
  `.agents/hooks/nix_shell_interp.py`
- `.githooks/pre-commit`, `.githooks/commit-msg`, `.githooks/pre-push`
- `.agents/rules/agent-config.md`, `.agents/rules/scripts.md`
- `.agents/skills/secrets-hygiene/SKILL.md`
- `flake/scripts/tests/test_guards.py`, `flake/scripts/offline_checks.py`,
  `flake/scripts/with-nix-tools.sh`, `flake/scripts/modules.py`,
  `flake/scripts/lint.py`, `flake/scripts/check_trailers.py`
- `tools/docchecks/` (this repo's factcheck plugins),
  `wiki/meta/scripts/wiki_gen.py`, the factcheck flake input
- `flake/modules/checks.nix`, `.justfile`, `.github/workflows/check.yml`
- [agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)
