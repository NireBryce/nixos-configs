# Lessons learned

_Last modified: 2026-10-05_

> **Written by Claude Code, for Claude Code**, and largely a record of its own
> mistakes, so the "I" in the articles is a machine with no memory of having
> done any of it. `AGENTS.md` has the rules; this has the scar tissue.

Every lesson, filed by **the moment it applies**, not by when it happened. Each
entry is one line: the rule, its **Home** (where an agent doing that task will
already be reading, and which states the rule), and what **Enforced** it
mechanically, or `none`. The full account of §N is
`wiki/lessons-learned/<N>-*.md`, linked from the entry.

- **Look one up by number:** `ls wiki/lessons-learned/25-*`, or grep this
  page for `§25`. Numbers are stable and cited from ~50 files; never renumber.
- **Look one up by task:** read the group you're in.
- **Adding one:** take the next number, write the article, add the entry to
  the group where it applies, and put the rule in its Home too; a lesson only
  this page states reaches nobody. If it applies to particular paths or
  commands, give it a topic in [`.agents/lessons-map.toml`](../.agents/lessons-map.toml)
  too, so the lesson-reminder hook puts it in front of the next agent at that
  moment. `none` under Enforced is an honest answer and a candidate for a
  check; a reminder is noted as `none (reminded by …)`, because a reminder
  is not a check. `check_wiki.py lessons` (in `just wiki-lint`) fails on a
  number with no entry, no article, or an entry missing either field, and
  on a map that has drifted from the repo.
- **Look up what applies to a file:** `just agent lessons <path>` (no
  argument: this branch's changed files).

When each lesson was learned (the den → flake-parts port, the first sessions
on hardware, the homelab) is in each article's own dates and in
[history.md](history.md).

## Before claiming a change works

Home for most of this group: [AGENTS.md "Before calling it done"](../AGENTS.md#before-calling-it-done).

- **§18** [Say which rung you mean](lessons-learned/18-say-which-rung.md) — *evaluates*, *builds*, *runs* find different defects; name the one you reached, and read an undated "verified" as *evaluates*. Home: AGENTS.md "Before calling it done". Enforced: none.
- **§36** [Evaluating vs building](lessons-learned/36-evaluating-vs-building.md) — when a value's correctness depends on more than its type, build what consumes it and read the result. Home: AGENTS.md "Before calling it done". Enforced: none.
- **§25** [Running it is a rung of its own](lessons-learned/25-running-is-its-own-rung.md) — a clean eval and a clean build still miss runtime defects (a missing import, hook order, suspend mode); switch and use it. Home: AGENTS.md "Before calling it done". Enforced: none.
- **§37** [Bugs that need real system state](lessons-learned/37-bugs-that-need-real-system-state.md) — state a daemon holds (file owners set outside Nix, defined-vs-started) only shows at a switch; check `systemctl`/`journalctl` after it. Home: skill `new-homelab-service` §8; AGENTS.md "Bugs here serialize". Enforced: none (reminded by the lesson-reminder hook on homelab edits).
- **§6** [Bugs serialise](lessons-learned/6-bugs-serialise.md) — each fix can uncover the next; a defect count from static analysis is a lower bound. Home: AGENTS.md "Bugs here serialize". Enforced: none.
- **§4** [An unchanged fingerprint can mean inert code](lessons-learned/4-unchanged-fingerprint-inert-code.md) — an identical fingerprint after a change you expected to matter is a reason to investigate. Home: AGENTS.md "Before calling it done". Enforced: none.
- **§43** [A fingerprint can pass for the wrong reason](lessons-learned/43-fingerprint-passed-for-the-wrong-reason.md) — dead code looks exactly like safe code; trace that the changed path runs, then diff the real values. Home: AGENTS.md "Before calling it done". Enforced: none.
- **§7** [Cross-module side effects](lessons-learned/7-cross-module-side-effects.md) — removing an unrelated module can remove something another module switched on; run `just diff` across any removal. Home: AGENTS.md "Before calling it done". Enforced: `just diff` (when run).
- **§12** [Verify the mechanism before betting a refactor on it](lessons-learned/12-verify-mechanism-before-refactor.md) — model and evaluate the risky part first; it's cheap. Home: AGENTS.md "Before calling it done". Enforced: none.

## Before believing a tool, a check, or a count

- **§1** [A tool that reports success has not been tested](lessons-learned/1-success-is-not-tested.md) — test a checker against a case it should catch, in the same commit; prefer shapes that cannot lose evidence. Home: AGENTS.md "Before calling it done"; skill `agent-scripts`. Enforced: none (reminded by the lesson-reminder hook on creating a script).
- **§3** [When a tool contradicts you, suspect yourself first](lessons-learned/3-suspect-yourself-first.md) — check your own assumption (which commit, which shell semantics) before calling a tool broken. Home: AGENTS.md "Before calling it done". Enforced: none.
- **§20** [A pipeline reports its last command's status](lessons-learned/20-pipeline-exit-status.md) — `cmd | tail` exits 0 when `cmd` failed; use `set -o pipefail` or don't pipe, and believe the text over the status. Home: AGENTS.md "Before calling it done". Enforced: none (reminded by the lesson-reminder hook on a check piped into `tail`/`head`/`grep`).
- **§21** [An environment failure can look like a config failure](lessons-learned/21-environment-failure-as-config-failure.md) — nix puts the innermost cause last; read to the bottom of a trace. Home: AGENTS.md "Before calling it done". Enforced: none (reminded by the lesson-reminder hook on a check piped into `head`).
- **§22** [Name matching fails silently](lessons-learned/22-name-matching-fails-silently.md) — before believing a zero, show the query can return non-zero (spelling differs, already present, `\w` misses `-`). Home: AGENTS.md "Before calling it done"; skill `home-manager-dotfiles`. Enforced: `just dotfiles` (for dotfile names; reminded by the lesson-reminder hook on Home Manager edits).
- **§31** [Count the thing you mean](lessons-learned/31-count-the-thing-you-mean.md) — know what a count counts, look for the existing cleaner before writing one, and don't set a limit below the observed worst case. Home: AGENTS.md "Before calling it done"; [coredump-limit.nix](../flake/modules/general-config/system/storage/coredump-limit.nix). Enforced: none.
- **§23** [When a check fires on new work, fix its model](lessons-learned/23-fix-the-checks-model.md) — "this check is wrong" and "this check is incomplete" look the same; widen the checker before reaching for the escape flag. Home: AGENTS.md "Before calling it done". Enforced: none (`just modules`' orphan findings cite it).

## Investigating on the machine

Home for most of this group: [AGENTS.md "Before you start"](../AGENTS.md#before-you-start) and "State".

- **§2** [The repo is not the machine](lessons-learned/2-repo-is-not-the-machine.md) — find out what is deployed before claiming impact; for hardware facts, ask. Home: AGENTS.md "State". Enforced: `just diff-deployed` (when run).
- **§24** [Compare against what is deployed](lessons-learned/24-compare-against-deployed.md) — diff against the running system, not the last commit; capture the baseline before switching, because it expires. Home: AGENTS.md "State". Enforced: `just baseline` (when run).
- **§26** [Did it work before?](lessons-learned/26-did-it-work-before.md) — `journalctl --list-boots` plus a grep settles regression-vs-always-broken; do it before arguing about mechanism. Home: AGENTS.md "Before you start". Enforced: none.
- **§19** [The machine's own tools can lie](lessons-learned/19-machine-tools-can-lie.md) — `findmnt`/`lsblk`/`/etc` report the shell's mount namespace, and an agent's sandboxed shell has its own `/`; read `/proc/1/mountinfo` and `/dev/disk/by-uuid/`. Home: skill `impermanence-initrd`. Enforced: `just root-drift` and `just baseline` read the real tables (reminded by the lesson-reminder hook on `lsblk`/`findmnt`).
- **§39** [A live interactive bug needs a live interactive repro](lessons-learned/39-live-interactive-repro.md) — `ssh host 'cmd'` is not the pty a human types into; reproduce in a real session. Home: [blesh.md](categories/shell-config/blesh.md). Enforced: none.
- **§40** [Check the resource, not the unit](lessons-learned/40-check-the-resource-not-the-unit.md) — a failed unit doesn't mean what it manages is down, and vice versa. Home: skill `new-homelab-service` §8. Enforced: none (reminded by the lesson-reminder hook on homelab edits).
- **§46** ["Enabled" is not "holds the port"](lessons-learned/46-enabled-vs-socket-holder.md) — when two components can claim one resource, ask who holds the socket (`ss -lnp`). Home: skill `new-homelab-service` §8. Enforced: none (reminded by the lesson-reminder hook on homelab edits).
- **§48** [A recorded change is not an applied change](lessons-learned/48-recorded-is-not-applied.md) — state whose home is an external API needs a diff against the API, not a checked-in mirror. Home: skill `new-tailscale-service`. Enforced: `just tailscale-acl diff` (when run; reminded by the lesson-reminder hook on tailscale-services edits).

## Writing config against NixOS and upstream

- **§10** [Read upstream source](lessons-learned/10-reading-upstream-source.md) — option types, module existence and unit names come from the source, not from guessing. Home: AGENTS.md "Read upstream source". Enforced: none.
- **§27** [Check whether upstream already fixed it](lessons-learned/27-check-upstream-fixed-it.md) — read the project's current source and packaging before writing compatibility code; a backport deletes cleanly, an invention doesn't. Home: AGENTS.md "Read upstream source". Enforced: none.
- **§33** [Removed options, and defaults are worth reading](lessons-learned/33-removed-option-and-defaults.md) — read the nixpkgs module's `mkRenamedOptionModule`/`mkRemovedOptionModule` block, not a wiki; config that restates a default reads as a decision. Home: [`.agents/rules/nix.md`](../.agents/rules/nix.md) (pointer in AGENTS.md "Traps"). Enforced: none.
- **§49** [Freeform `settings.*` renders unknown keys](lessons-learned/49-freeform-settings-render-unknown-keys.md) — eval passing says nothing about whether the consumer reads a key; read the rendered file. Home: [`.agents/rules/nix.md`](../.agents/rules/nix.md) (pointer in AGENTS.md "Traps"). Enforced: [invariants.nix](../flake/modules/invariants.nix) (the pam_u2f key only).
- **§8** [An option existing is not it fitting](lessons-learned/8-option-existing-vs-fitting.md) — read what an option generates, not what it's called. Home: [manconfig.nix](../flake/modules/general-config/nix/manconfig/manconfig.nix). Enforced: none.
- **§9** [Cache placements](lessons-learned/9-cache-placements.md) — build time, activation, or timer; the built-in default is the expensive one. Home: this page; [manconfig.nix](../flake/modules/general-config/nix/manconfig/manconfig.nix) is the worked case. Enforced: none.
- **§45** [`systemd.user.services` is global](lessons-learned/45-systemd-user-services-are-global.md) — a NixOS user unit starts in every user's manager (sddm's included); gate it with `ConditionUser`. Home: skill `new-homelab-service` §1. Enforced: none (reminded by the lesson-reminder hook on homelab edits).
- **§47** [An explicit setting can switch off an implicit one](lessons-learned/47-explicit-setting-disables-implicit-one.md) — auto-detection fires only where nothing is declared; one Caddy `tls` line changed the issuer for every vhost. Home: [caddy.nix](../flake/modules/general-config/homelab/reverse-proxy/caddy/caddy.nix); [traps-and-skills.md](traps-and-skills.md). Enforced: none (reminded by the lesson-reminder hook on Caddy edits).
- **§41** [Per-app proxy prefix handling](lessons-learned/41-per-app-prefix-handling.md) — two apps behind one mechanism can want opposite prefix handling; `curl` the app itself. Home: skill `new-homelab-service` §5. Enforced: `check_wiki.py routes` (wiki claims only; reminded by the lesson-reminder hook on Caddy edits).

## Changing or removing behaviour

- **§11** [Read the links in a comment before deleting the code](lessons-learned/11-read-links-before-deleting.md) — a cited manual is there because the code depends on it. Home: AGENTS.md "Working in this repo". Enforced: none.
- **§28** [A guard keyed on a signal that never fires](lessons-learned/28-guard-on-a-signal-that-never-fires.md) — a condition is a claim about the world; check it fires on the machine before trusting it to prevent something. Home: [WARN-impermanence.nix](../flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix); skill `impermanence-initrd`. Enforced: [invariants.nix](../flake/modules/invariants.nix) (rollback unit); `impermanence-edit-guard-pretooluse.sh` warns on every edit there.
- **§30** [Removing a capability doesn't make consumers fall back](lessons-learned/30-removed-capability-no-fallback.md) — "it will fall back" is a claim about one named consumer; when turning something off, find what was asking for it. Home: [kde-sleepmode.nix](../flake/modules/general-config/impermanence/root-rollback/restore-root/kde-sleepmode.nix). Enforced: none ([invariants.nix](../flake/modules/invariants.nix) pins `nohibernate`, not what its consumers ask for; its failure cites §30).
- **§29** [Ordering fixes don't reach deferred code](lessons-learned/29-ordering-vs-deferred-code.md) — `mkOrder` can't move what schedules itself later; unbinding under a replaced mechanism leaves the key dead. Home: [blesh.md](categories/shell-config/blesh.md). Enforced: none (reminded by the lesson-reminder hook on Home Manager edits).
- **§38** [Scope the fix to what asked for it](lessons-learned/38-scope-the-fix-to-the-caller.md) — ask "does this affect the host that didn't ask" before writing a host-wide fix. Home: [where-modules-go.md](where-modules-go.md). Enforced: none.

## Names and resources that can collide

- **§34** [The dangerous collision is where both halves work](lessons-learned/34-collision-where-both-halves-work.md) — a category and a same-named module merge silently; name the file after the specific thing. Home: skill `new-flake-module`. Enforced: `just modules`, which cites it (reminded by the lesson-reminder hook on creating a module).
- **§35** [The same collision, a third time](lessons-learned/35-collision-a-third-time.md) — a new category directory's name is reserved for every module under it; check by construction when splitting one out. Home: skill `new-flake-module`. Enforced: `just modules`, which cites it (reminded by the lesson-reminder hook on creating a module).
- **§32** [An auto-allocator can't see manual entries](lessons-learned/32-auto-allocator-vs-manual.md) — before mixing auto and manual modes for one resource, check auto can see manual; a working host may be relying on state a fresh one lacks. Home: [podman.nix](../flake/modules/general-config/homelab/containers/podman/podman.nix). Enforced: [invariants.nix](../flake/modules/invariants.nix) (subuid ranges).

## Git, commits, and working with the user

- **§15** [Commit hygiene](lessons-learned/15-commit-hygiene.md) — check what's staged, don't describe state that doesn't exist yet, order commits so each is green. Home: skill `ship`. Enforced: `just agent commit` refuses a commit without a pathspec.
- **§44** [Git in hooks needs `-C`](lessons-learned/44-git-in-hooks-needs-c.md) — a hook running `git` from a non-toplevel cwd uses `git -C "$repo_root"`, not a cleared `GIT_DIR`. Home: skill `use-a-worktree`. Enforced: none (`.githooks/pre-commit` carries the fix; reminded by the lesson-reminder hook on agent-config edits).
- **§42** [`.claude/settings.local.json` is the user's](lessons-learned/42-settings-local-json.md) — resolve its merge conflicts the simplest way and move on. Home: skill `ship`. Enforced: none.
- **§14** [Read the repo's conventions before writing into it](lessons-learned/14-read-conventions-first.md) — the style guide exists; grep for it. Home: AGENTS.md "Conventions". Enforced: none.
- **§5** [Writing a trap down doesn't stop you walking into it](lessons-learned/5-writing-a-trap-down.md) — the fix is a tool that makes the mistake impossible, not a warning. Home: this page's Enforced field. Enforced: none (reminded by the lesson-reminder hook on Home Manager edits).
- **§16** [A redirect carries information](lessons-learned/16-user-redirects-carry-information.md) — a correction phrased as a small clarification is often load-bearing; act on what it implies. Home: this page. Enforced: none.
- **§13** [Reversibility can stand in for a decision](lessons-learned/13-reversibility-for-decision.md) — ask whether a close call needs deciding or just a documented way back. Home: this page. Enforced: none.
- **§17** [The record may already exist](lessons-learned/17-the-record-may-exist.md) — an earlier session's transcript can settle a question faster than re-deriving it. Home: skill `investigate-bug`. Enforced: none.
