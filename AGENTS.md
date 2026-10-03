# AGENTS.md

> **Written by agents, for agents.** An agent's working notes, not
> documentation — pitched at something with no memory between sessions;
> repeating a mistake is the failure mode it exists to prevent. The user has
> corrected the load-bearing claims; the framing is the machine's.
> `README.md` is the human entry point.
>
> This file is canonical; `CLAUDE.md` is a symlink to it, so every "see
> CLAUDE.md" reference in this repo resolves here. Skills referenced by name
> below are plain markdown at `.agents/skills/<name>/SKILL.md` — any agent
> can read them as files, with or without a harness that loads skills.
>
> `.claude/` is a real directory whose `settings.json`, `skills` and
> `rules` are symlinks into `.agents/` (a symlinked `.claude` itself makes
> Claude Code refuse to create subagent worktrees).
>
> This file holds what applies to every session. Detail that matters only
> under specific paths lives in `.agents/rules/*.md` (Claude Code reads them
> as `.claude/rules/` and loads each only when a file matching its `paths:`
> frontmatter is read). Other harnesses don't load rules: each has a
> pointer below — open it before working under its paths.

## Hard rules

Each is stated in full, with its reason, in the section named after it.
Every one has been broken here at least once.

- **Never suggest installing this config wholesale**; it deletes `/root`
  on boot. (Safety)
- **Never decrypt sops output into the conversation.** (Safety)
- **Never file anything outside `NireBryce/nixos-configs`** unasked.
  (Working in this repo)
- **"push" means skill `ship`, landing on `experimental`**; `main` is
  promotion-only. (Working)
- **Branching work happens in its own worktree.** (Working)
- **`git add` before `nix eval`.** (Working)
- **Public text stays mechanical.** (Working)
- **Say which rung you reached**, never more. (Before calling it done)
- **A change that makes a wiki page stale fixes it in the same change** —
  skill `wiki-sync`.
- **Trailer `Co-Authored-By: Claude`; prose says "the user".** (Conventions)

## Safety

This config enables impermanence: `WARN-impermanence.nix` (reached through
the `impermanence` category) deletes the `/root` btrfs subvolume in initrd
on every boot and needs a `root-blank` subvolume to exist. **Two of the
three NixOS hosts import it and wipe `/root` on boot: `nire-durandal`,
`nire-tenacity`.** `nire-cube` deliberately does not — plain persistent
root, not LUKS+impermanence. Don't assume "every host wipes root" or "no
host does" — check the specific host. Never suggest installing this config
wholesale; read `WARN-impermanence.nix` before changing anything near it,
and take care with `flake/modules/general-config/impermanence/` and
`fileSystems`/`boot` in the host hardware modules —
`.agents/rules/impermanence.md`.

Secrets are sops-nix (`flake/modules/general-config/system/secrets/`);
`secrets.yaml` is encrypted and committed on purpose. `sops -d` prints
every secret in the file — never into the conversation or a pipe;
`2>/dev/null` doesn't stop stdout. "Which secrets exist?" (answered by
decrypting, it has leaked values twice) is `just read-sops-names`, names
only. Skill `secrets-hygiene`; enrolled hosts: `.agents/rules/secrets.md`.

## State

**Switch/boot state is deliberately not recorded in this repo** — it rots.
Whether a host runs what the tree evaluates to is a live question, answered
only on the host: `just baseline`, `just diff-deployed`, or a forced
toplevel eval against `/run/current-system`. The repo is not the machine:
before claiming a change affects a host, find out what that host runs, and
for a hardware fact, ask (§2). Capture `just baseline` before switching;
once the old generation is collected it can't be re-derived (§24).

Roster, class, and which hosts wipe `/root`: `host-config/hosts.nix` (check
it before stating any count) and `wiki/hosts.md`'s table. First-boot
history: `wiki/history.md`'s "Confirmed-on-hardware facts".

- **Check `hostname` before assuming which machine the session is on.**
  Under Claude Code, `.agents/hooks/session-start.sh` injects hostname,
  branch, worktree, dirty count, `core.hooksPath` and the `just agent`
  helper names; elsewhere, check (`just agent where` for repo state).
- **ssh to another host over the tailnet as `ts-<x>`, never `nire-<x>`** —
  `nire-<x>` is the hostname (`nire-<x>.local` on the LAN only), and
  tenacity's sshd is tailnet-only. `just reach <x>` tries every name. Rule
  and table: `wiki/hosts.md`; as code: `tailnet-hosts.nix`.

## Before you start

- **Find the page for the task.** `wiki/00-INDEX-for-agents.md` routes by
  task; `wiki/lessons-learned.md` files every past mistake by the moment it
  applies. Bare `just` lists every recipe.
- **Someone reports a bug?** Skill `investigate-bug` first — `just threads
  "<keywords>"` — before reproducing anything.
- **Ask "did it work before?" first.** `journalctl --list-boots` plus a
  grep settles regression-vs-always-broken faster than any argument about
  mechanism.
- **Before hand-building a multi-step pipeline, check `just agent`** —
  agent-written scripts for recurring lookups. Adding one: skill
  `agent-scripts`.

## Traps, all of which have actually happened here

One line per task; read the rule (short version) or skill (full mechanism)
before the matching task.

- Writing, renaming or browsing a flake-parts module: names come from
  filenames, same-named modules merge — skill `new-flake-module`,
  `.agents/rules/flake-modules.md`.
- Home Manager shell/dotfiles: `home.file` text concatenates — skill
  `home-manager-dotfiles`, `.agents/rules/home-manager.md`.
- Impermanence, initrd, host hardware: trust `/proc/1/mountinfo` over
  `lsblk` — skill `impermanence-initrd`, `.agents/rules/impermanence.md`.
- Adding or platform-gating a package: Homebrew overlap is never automatic
  — skill `package-platform-support`, `.agents/rules/packages.md`.
- Adding a homelab service — skill `new-homelab-service`,
  `.agents/rules/homelab.md`.
- Any `.nix` edit: `${...}` in a `''` string interpolates, even in a
  comment; freeform `settings` swallow wrong keys — `.agents/rules/nix.md`.
- Scripts and recipes: no Python buried in bash — `.agents/rules/scripts.md`.
- Agent settings, guard hooks, `permissions.allow` —
  `.agents/rules/agent-config.md`.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked
files, so a new module silently does not exist. `just modules`' untracked
check is the backstop; `.agents/hooks/nix-untracked-guard-pretooluse.sh`
also warns at eval time.

**Read upstream source rather than guessing at options** (it settled
`perSystem` having no `freeformType`, `home.sessionPath` being `listOf
str`), and for third-party packages the project's current source too —
`handheld-daemon` got a shim for something upstream had already fixed.

**Read the links in a comment before deleting the code it annotates.** A
cited manual page is there because the code depends on it (§11).

**Calibrate severity.** Homelab, not production; the repo has gone six
months between commits. "This is broken and here is the fix" beats incident
framing.

**Security/threat-model analysis goes in the private `elly/infra-notes`
repo on the forge (tailnet-only), never in anything public: PR bodies,
commit messages, wiki pages, code comments, test names or test comments.**
Public text says what a guard or fix enforces and how it was verified --
not which inputs got past it, what they could reach, or which host is
exposed. Tests keep the inputs they check without narrating what they
would do. Merged history through #380, and #435's commit messages, predate
this rule and are not precedent.

**Default to a dedicated `git worktree` for any task that will branch,
commit, or check out — skill `use-a-worktree` (not for read-only work).**
If git state doesn't match your own last action, check `git reflog` before
concluding anything is broken.

**"push" means the `ship` skill, landing on `experimental`, the default
branch** — branch, PR, one combined ask covering both merging and deleting
the branch afterward. The user naming a branch outright means push directly
there — except `main`, the promoted known-good, which moves only by PR from
`experimental` after hardware verification. Don't assume a branch — check
`git branch --show-current`.

**Never file anything outside `NireBryce/nixos-configs` — an issue or PR on
nixpkgs, ble.sh, carapace, any other project — without the user saying so
explicitly, in those words, unprompted.** A yes to a bundled list does not
cover an upstream filing folded into it. `propose-issue` only ever files
here; `_loose-ends/bugs-pending-submission/` and `wiki/open-threads.md`'s
drafts are deliberately not worked through automatically. Filing here can
still reach another project via GitHub autolinking (`owner/repo#123` in a
title or body pings that repo), so grep for that shape first.

## Before calling it done

Each § is an entry in `wiki/lessons-learned.md`, full account in
`wiki/lessons-learned/<N>-*.md`.

**Say which rung you reached.** *Evaluates* (`nix eval`, `just check`),
*builds* (`just build`; `nix build --dry-run` gives the plan without
compiling), *runs* (switched and used), and for a setting that renders into
a file, *read the rendered artifact*. Each finds defects the one before
cannot. Treat an undated "verified" as *evaluates*, here and in what you
write (§18, §36).

**Bugs here serialize.** Evaluating a cheap attribute proves nothing; force
a toplevel — §25 records four defects that got past both a clean eval and a
clean build, which stop short of runtime (§37). Each fix can uncover the
next, so a defect count from reading is a lower bound (§6).

**Verify refactors by fingerprint, but not only by fingerprint.** A
differing hash doesn't prove breakage (import order permutes
`environment.systemPackages`); an unchanged one can mean dead code (§43),
and after a change you expected to matter, investigate (§4). Compare values
with `just diff`, including across any module *removal* (removing fish
removed the man index, §7), and make refactored paths run. Model and
evaluate a risky mechanism before betting a refactor on it (§12).

**Read the output, not the status.** `cmd | tail` exits 0 when `cmd`
failed; use `set -o pipefail` or don't pipe (§20). Nix puts the innermost
cause last; read a trace to the bottom (§21). Before believing a zero, show
the query can return non-zero; before believing a count, know what it
counts (§22, §31). When a tool contradicts you, check your own assumption
first (§3).

**A new checker is tested against a case it should catch**, in the same
commit (§1). When an existing check fires on new work, fix its model
before reaching for its escape flag (§23).

**Then:** `just preflight` is what CI runs; skill `wiki-sync` for any wiki
page the change made stale.

## Conventions

**Read `wiki/module-style-guide.md` before writing a new module** — its
formatting is deliberate, not a cleanup target. The other module
conventions (old names on renames, bugs recorded in comments stay, `elly`
hardcoded, `programs.*` first) are `.agents/rules/flake-modules.md`.

**Provenance trailer on every agent-authored commit:
`Co-Authored-By: <agent>` — the agent that wrote it, no model name, no
email.** An agent cannot verify which model is executing it, so the trailer
records what it knows. Claude's form is `Co-Authored-By: Claude`.
`.githooks/commit-msg` auto-corrects only the `Claude <model> <email>`
shape, so form any other agent's trailer correctly at write time.

**Prose that means the person says "the user," never the name.** `elly` in
an identifier is the account this config builds; in prose it reads as a
claim about who runs this repo, which doesn't hold for a fork or a fresh
session.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere; bare
`just` lists them with a one-line summary each, and that list (not a copy
here) is the source of truth. `just preflight` (wiki-lint + branches-test
+ check + modules + lint + the script tests; CI runs this recipe itself)
is the ship skill's step 0. `just hm-collisions`, `just root-drift`, and
`just home-drift` are read-only, and only meaningful on the hardware.
`.agents/settings.json` pre-approves a few read-only recipes; what may join
them: `.agents/rules/agent-config.md`.

`host` derives from `hostname`, falling back to `nire-durandal` off-host.
The override goes **before** the recipe name — `just host=nire-durandal
build`; after it, just reads it as a second recipe name and errors.

For iterating, evaluate directly from `flake/` (`elly` is literal: it reads
an *evaluated* config, where the attribute name is already resolved):

```sh
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
```

`build`/`boot`/`switch` go through `flake/scripts/rebuild.sh` (picks `nh
darwin` or `nh os` off the flake). On any real host, `just build`/`switch`
is a real test, not just evaluation. A NixOS host cannot be built from any
other machine (no remote builder, no binfmt); `rebuild.sh` says so.

## Architecture

`flake.nix` is a manifest. `(inputs.import-tree ./modules)` recursively
imports every `.nix` file under `flake/modules/`, and
`flake-parts.flakeModules.modules` declares the `flake.modules.<class>.<name>`
option they all write into. **Every `.nix` file under `modules/` is a
flake-parts module** — top level `{ flake.modules.<class>.<name> = …; }` or
similar, never a bare NixOS or Home Manager module.

**Membership comes from the directory**: each category's
`dirsAsCategory.nix` collects every `.nix` file beneath it; categories are
how shared things stay optional (no `mkEnableOption`). Areas:
`general-config/` (incl. `macos/` for darwin), `host-config/`,
`packages-config/`, `users-config/`. Detail: `.agents/rules/flake-modules.md`.
Host roster: `host-config/hosts.nix` (its comments cover naming, the
forge-runner guest, removed hosts) — don't restate it.

**Home Manager is NixOS-integrated** — no `homeConfigurations`, no separate
home switch; `just switch` applies both (`.agents/rules/home-manager.md`).
`ellyHomeManager` is shared verbatim by all four hosts including
`nire-lysithea`, so everything in it has to survive darwin.

## Docs

**A long wiki page is either a pair — read the `-for-agents.md` half — or
one page opening with `## Quick facts` — read that first.** A pair is for a
page that is long narrative: `<page>.md` is explanation written for a human
reading cold; `<page>-for-agents.md` is the same ground at maximum
information density — paths, option names, commands, host lists, every trap
as one line, no narrative. Loading the human page to answer a question the
sibling already answers is paying for prose you don't need. A page already
compact or procedural (runbook, how-to) gets `## Quick facts` instead, since
a sibling there only restated it and doubled every edit. Start at
`wiki/00-INDEX-for-agents.md`, which routes by task.

The tradeoff, stated so nobody has to rediscover it: this is deliberate
duplication, against the "index over restatement" rule the rest of the wiki
runs on, and `wiki/00-INDEX.md` says outright that this repo has been bitten
repeatedly by one fact living in two places. It is allowed here because it
is the one duplication with a mechanical guard — **`check_wiki.py siblings`
fails when a sibling's `_Last modified:_` predates its source's** (and when
a page over 1,000 words has neither a sibling nor a first-section
`## Quick facts`), so
editing a page without following in its sibling, in the same change, breaks
`just wiki-lint` and names the pair. Don't satisfy that by bumping the
sibling's date; that converts a caught omission into a silent one. When the
edit genuinely has nothing to sync, a dated `_Sibling reviewed:_` line with
a reason, on the sibling, is the way to say so. Full rule and the cut list:
`wiki/styleguide.md`'s "Two audiences per page"; the procedure is skill
`wiki-sync`, step 5.

- `wiki/00-INDEX.md` — topic index (`00-INDEX-for-agents.md` condensed).
  **Maintained the same way this file is**:
  a change that makes a wiki page stale corrects it in the same change
  (`just wiki-lint` checks the mechanical claims).
- `wiki/lessons-learned.md` — every past mistake as one line, grouped by
  the moment it applies (proving a change works, reading tool output,
  investigating on the machine, writing config, changing behaviour,
  collisions, git and process), each naming the skill or section that
  carries its rule and what enforces it. Full accounts are
  `wiki/lessons-learned/<N>-*.md`; § numbers are stable, cited from ~50
  files, never renumbered. No `-for-agents` sibling, deliberately:
  it is already written agent-facing. **A new lesson goes in its Home as
  well as the index** — a rule only that page states reaches nobody.
