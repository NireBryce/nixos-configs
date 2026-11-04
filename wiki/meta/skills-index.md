# Skills index

_Last modified: 2026-11-03_

Every skill in `.agents/skills/`, with what it does and when it fires. The
table is generated from each skill's frontmatter, so it cannot disagree with
the skills themselves. The task-to-skill routing for common mistakes is in
[traps-and-skills.md](traps-and-skills.md).

## Contents

- [Quick facts](#quick-facts)
- [How skills are found](#how-skills-are-found)
- [Naming](#naming)
- [Adding or changing a skill](#adding-or-changing-a-skill)

## Quick facts

<!-- generated:skills-index -- from the frontmatter of each .agents/skills/*/SKILL.md, by `just wiki-gen`; change the source, not this table -->

| Skill | Does | Use when |
|---|---|---|
| [`agent-scripts`](../../.agents/skills/agent-scripts/SKILL.md) | Finds command patterns agents keep re-typing and turns them into scripts behind `just agent`. | Periodic sweep for recurring commands, or mid-task when you're assembling the same pipeline again or writing a command too long to read in a permission prompt. |
| [`book-fact-check`](../../.agents/skills/book-fact-check/SKILL.md) | Fact-checks the mdBook chapters against the repo with read-only agents, applies the verified corrections, and rebuilds the book. | Asked to fact-check, lint or proofread the book, or after code or docs that the book describes change. |
| [`boyscouting`](../../.agents/skills/boyscouting/SKILL.md) | Fixes small, local problems in files you're already editing, in the same commit as the main task. | Noticing a stale comment, dead import, unused variable or similar small flaw in a file you're changing for another reason. |
| [`boyscouting-all`](../../.agents/skills/boyscouting-all/SKILL.md) | Sweeps the whole repo for small, local cleanups and lands them as one scoped change. | Asked to "boyscout the repo" or "clean up the small stuff everywhere" as a standalone task, not a fix noticed mid-task. |
| [`cod-completions`](../../.agents/skills/cod-completions/SKILL.md) | Adds ble.sh menu descriptions to cod's completions and keeps the curated description table current. | Candidates for a command show no descriptions in the ble.sh menu, adding a command to cod's coverage, or changing the cod-desc table. |
| [`comment-wrap`](../../.agents/skills/comment-wrap/SKILL.md) | Finds over-long comment blocks in the modules and re-flows them with the repo's checker and fixer. | A comment block runs past the column, a comment insert broke an existing wrap, or asked to re-wrap, reflow or sweep comment widths. |
| [`docs-audit-all`](../../.agents/skills/docs-audit-all/SKILL.md) | Audits every wiki page, rule file, skill and AGENTS.md claim against the code, with parallel subagents that each own separate files. | Asked to audit the docs or find stale or wrong docs everywhere, as a standalone whole-repo pass. |
| [`explain-tricky-code`](../../.agents/skills/explain-tricky-code/SKILL.md) | Writes comments for a module or function whose design isn't obvious, covering what it does, why it's shaped that way, and what breaks if it changes. | Asked to explain code like a talk, make comments clearer for newcomers, or redo a comment rewrite that is still confusing. |
| [`extract-agent-tooling`](../../.agents/skills/extract-agent-tooling/SKILL.md) | Records a skill, lesson, wiki convention, script or hook as an extraction candidate when its mechanism would work in any agent-run repo. | Writing or changing a skill, lesson, wiki convention, AGENTS.md section, checker script or hook whose mechanism isn't specific to this repo. |
| [`extract-agent-tooling-all`](../../.agents/skills/extract-agent-tooling-all/SKILL.md) | Sweeps the repo for skills, lessons, conventions, scripts and hooks that would work in any agent-run repo, and updates the extraction candidates folder. | Asked what here is worth extracting, what would work in other repos, or to refresh the agent-orchestration extraction candidates. |
| [`extract-nix-tooling`](../../.agents/skills/extract-nix-tooling/SKILL.md) | Records a Nix pattern or trap as an extraction candidate when it would work in any flake config. | Writing or changing a module, flake script, or Nix-related skill or lesson whose pattern isn't specific to this repo. |
| [`extract-nix-tooling-all`](../../.agents/skills/extract-nix-tooling-all/SKILL.md) | Sweeps the repo for Nix patterns, scripts and traps that would work in any flake, and updates the extraction candidates folder. | Asked what Nix patterns here are reusable, or to refresh the Nix extraction candidates. |
| [`fact-hygiene`](../../.agents/skills/fact-hygiene/SKILL.md) | Keeps facts, dated snapshots, cross-references and copied values from going stale when you write them. | Writing a claim about live state or an external system, a status as of a date, a comment asserting something about other modules or hosts, or a count or version copied from another file. |
| [`git-archaeology`](../../.agents/skills/git-archaeology/SKILL.md) | Finds the commit that added, changed or removed something when the file has since been renamed or moved. | Asked when something was removed, git log on a file's current path comes back empty, or about to conclude no commit ever touched it. |
| [`guards-without-hooks`](../../.agents/skills/guards-without-hooks/SKILL.md) | Runs a command through the repo's Bash guard hooks by hand when the harness does not run them. | Using a harness other than Claude Code or ZCode, a shell tool other than Bash, or unsure the guard hooks are active for a skill tagged Needs bash-guards. |
| [`home-manager-dotfiles`](../../.agents/skills/home-manager-dotfiles/SKILL.md) | Edits Home Manager shell and dotfile modules and reads a generated dotfile back correctly. | Editing zsh, bash or starship rc content, home.file or home.sessionPath, or a generated dotfile looks wrong or empty. |
| [`impermanence-initrd`](../../.agents/skills/impermanence-initrd/SKILL.md) | Edits impermanence and initrd config and reads real disk and mount state on a host that wipes /root on boot. | Touching boot.initrd options or impermanence config, or before trusting lsblk, findmnt or /etc output on a host that wipes /root on boot. |
| [`investigate-bug`](../../.agents/skills/investigate-bug/SKILL.md) | Checks whether a reported bug or symptom is already a tracked thread before you investigate it. | Someone reports an error, crash or odd behavior in this repo or on a host, before reproducing or diagnosing it. |
| [`keybinding-cheatsheet`](../../.agents/skills/keybinding-cheatsheet/SKILL.md) | Generates a normalized keybinding cheat sheet for a tool, and shows how to teach the generator a new input format. | Asked what a chord does in kitty, zsh, or bash with ble.sh, or to merge upstream keybinding defaults with this repo's overrides. |
| [`low-side-secrets`](../../.agents/skills/low-side-secrets/SKILL.md) | Adds and maintains a sops file keyed to a personal SSH key, for secrets that don't need activation-time decryption. | Adding a secrets file for an ad hoc secret whose recipient is a personal SSH key (via ssh-to-age). Not the main secrets.yaml. |
| [`maintenance-schedule`](../../.agents/skills/maintenance-schedule/SKILL.md) | Reviews and updates the checklist of key and credential expiry and rotation dates. | Asked what's due, to review key expiry, or when a change adds or rotates a key, credential or certificate that expires. |
| [`new-flake-input`](../../.agents/skills/new-flake-input/SKILL.md) | Adds an external flake as an input and wires a build-time check from it, so the check really runs in preflight and CI. | Adding an entry to the flake inputs, consuming another flake's package or check, or bumping such an input. |
| [`new-flake-module`](../../.agents/skills/new-flake-module/SKILL.md) | Creates, renames and wires a module in the flake modules tree. | Adding, renaming or moving a .nix file under the flake modules tree, making or removing a category, or a module that doesn't seem to apply. |
| [`new-homelab-service`](../../.agents/skills/new-homelab-service/SKILL.md) | Adds a self-hosted network service to a host and verifies it works after the first switch. | Adding a service that listens on a port and is reached from another machine, before creating its category. |
| [`new-host-config`](../../.agents/skills/new-host-config/SKILL.md) | Adds a new host to the repo. | Adding a machine, or a host entry point, host module directory or hosts.nix line. |
| [`new-package`](../../.agents/skills/new-package/SKILL.md) | Adds a package to the user environment and verifies it on the target host. | Adding a package to the Home Manager package set, before writing the module. |
| [`new-skill`](../../.agents/skills/new-skill/SKILL.md) | Writes a new SKILL.md, or fixes the frontmatter of an existing skill. | Creating a SKILL.md, or editing any skill's description or when_to_use. |
| [`new-tailscale-service`](../../.agents/skills/new-tailscale-service/SKILL.md) | Gives a homelab service its own Tailscale Services hostname, with Caddy terminating TLS. | A running homelab service should be reachable at its own tailnet hostname instead of a path under the host's shared name. |
| [`new-wiki-page`](../../.agents/skills/new-wiki-page/SKILL.md) | Creates a wiki page with the date line, Contents block, sibling decision and index entry that wiki-lint requires. | Creating any new page under wiki, such as a category page, a homelab runbook or a topic page. |
| [`package-platform-support`](../../.agents/skills/package-platform-support/SKILL.md) | Checks whether nixpkgs builds a package on darwin and whether Homebrew already installs it, for adding or platform-gating a package. | Before adding a package module, adding an isDarwin or platform guard, or deciding whether a cask duplicates a nixpkgs package. |
| [`propose-issue`](../../.agents/skills/propose-issue/SKILL.md) | Proposes a GitHub issue for a bug in this repo's config, code or docs that you found while doing other work. | Noticing a defect unrelated to the current task, such as a doc command that fails, a removed option, or a claim the machine contradicts. |
| [`review`](../../.agents/skills/review/SKILL.md) | Reviews a change using this repo's own checks and known traps. | Reviewing a PR, branch or commit, or before saying your own change is done. |
| [`secrets-hygiene`](../../.agents/skills/secrets-hygiene/SKILL.md) | Keeps sops-managed secret values out of the conversation, and covers what to do when one leaks. | Running any sops command, reading /run/secrets, asking which secrets exist, running env, printenv or journalctl near a unit that takes a secret, or a secret value showing up in output. |
| [`ship`](../../.agents/skills/ship/SKILL.md) | Lands work on experimental through a branch, a PR, a confirmed merge and delete, the merge, and deleting the branch. | A bare push, ship it, land this or merge this, or any ask to get changes onto experimental. Never push directly to main. |
| [`triage-flagged-secrets`](../../.agents/skills/triage-flagged-secrets/SKILL.md) | Decides whether a secret flagged by the guard hooks is a fresh leak or one already confirmed dead in old git history. | The secrets guard hook flags a Tailscale auth key, age key or private key block in tool output, before calling it a fresh leak. |
| [`trim-docs`](../../.agents/skills/trim-docs/SKILL.md) | Tightens wiki pages, skills and AGENTS.md prose without breaking wiki-lint or losing facts that matter. | Asked to lint, tighten, trim or make more concise the wiki, a skill or AGENTS.md. |
| [`trim-history`](../../.agents/skills/trim-history/SKILL.md) | Compresses a .nix module's bottom-of-file history section to the facts the module body doesn't already state, and shows the result side by side before landing. | Asked to compress, trim or shrink the history section at the bottom of a .nix module. |
| [`use-a-worktree`](../../.agents/skills/use-a-worktree/SKILL.md) | Sets up an isolated git worktree so work doesn't happen in the shared checkout. | Before any task that will branch, commit, merge or check out, at the first git command that moves a branch or changes what's checked out. |
| [`wiki-fact-check`](../../.agents/skills/wiki-fact-check/SKILL.md) | Checks claims in a chosen set of docs against the code with parallel read-only agents, then verifies and applies the corrections. | Asked to fact-check or verify some wiki pages, a section of the docs, or a set of pages against the repo. |
| [`wiki-history-sweep`](../../.agents/skills/wiki-history-sweep/SKILL.md) | Moves a wiki page's resolved-incident narrative into a history companion page, and finds the pages that need it. | A wiki page carries narrative about fully resolved problems, or running the history candidates sweep. |
| [`wiki-sync`](../../.agents/skills/wiki-sync/SKILL.md) | Checks whether your change left a wiki article stale, and fixes it in the same change. | At the end of any change that could make something the wiki states no longer true. |

<!-- /generated -->

## How skills are found

A session lists every skill by name, `description` and `when_to_use`, and
loads a skill's body only when the task matches. The listing is the only
thing the model has when it decides, so a trigger that is missing from a
skill's frontmatter is a skill that does not fire. Everything else in a
`SKILL.md` costs nothing until the skill loads.

The directory is flat on purpose. Skill discovery expects
`.agents/skills/<name>/SKILL.md` directly under the skills directory
(`.claude/skills` is a symlink to it), and the `skill-files` check, the
`skill` field in `.agents/lessons-map.toml` and the cross-references between
skills all use that path. Category folders and a routing skill that points to
the others have not been tried (2026-11-03): a folder level risks hiding
skills from discovery, and a routing skill adds a loading step before the
real skill, with a second trigger that can be missed. Prefixes group skills
instead.

## Naming

- `new-*` adds a thing to the repo: a module, package, host, service, flake
  input, wiki page or skill.
- `extract-*` records, or sweeps for, patterns that would work in other
  repos. A `-all` suffix means the repo-wide sweep of a single-purpose skill
  (`boyscouting` and `boyscouting-all`; `extract-nix-tooling` and
  `extract-nix-tooling-all`).
- `wiki-*`, `trim-*`, `docs-audit-all` and `book-fact-check` work on
  documentation.
- Names without a shared prefix are single-purpose workflows (`ship`,
  `review`, `use-a-worktree`).

## Adding or changing a skill

Follow `new-skill`. After adding a skill or editing a `description` or
`when_to_use`, regenerate the table:

```sh
just wiki-gen
```

`just wiki-lint` fails with a `STALE GENERATED` finding while the table is
out of date.
