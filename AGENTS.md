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

Landing work targets `experimental`, the default branch (see "push" under
Hard rules, and skill `ship`); `main` is the promoted known-good
and moves only via a PR from `experimental` after hardware verification.
Don't assume a branch — check `git branch --show-current`.

Sections run in the order a task meets them: the hard rules, what the
machine is, what to do before starting, the traps and rules while editing,
what to check before calling it done, then reference (commands,
architecture, docs).

## Hard rules

Each is stated in full, with its reason, in the section named after it.
Every one has been broken here at least once.

- **Never suggest installing this config wholesale**, and read
  `WARN-impermanence.nix` before changing anything near it: it deletes
  `/root` on boot. (Safety)
- **Never decrypt sops output into the conversation.** "Which secrets
  exist?" is `just read-sops-names`. (Traps; skill `secrets-hygiene`)
- **Never file anything outside `NireBryce/nixos-configs`** without the
  user saying so explicitly. (Working in this repo)
- **"push" means skill `ship`, landing on `experimental`.** `main` moves
  only by PR from `experimental` after hardware verification. (Working in
  this repo)
- **Branching work happens in its own worktree** — skill `use-a-worktree`.
- **`git add` before `nix eval`**, or a new file doesn't exist. (Working
  in this repo)
- **Say which rung you reached** — evaluates, builds, or runs — and never
  claim more. (Before calling it done)
- **A change that makes a wiki page stale fixes it in the same change** —
  skill `wiki-sync`. (Before calling it done)
- **Public PR and wiki prose stays mechanical**; threat-model analysis goes
  to the private notes repo. (Working in this repo)
- **Commit trailer `Co-Authored-By: Claude`**, no model name; prose says
  "the user", never the name. (Conventions)

## Safety

This config enables impermanence and wipes `/root` on boot on most hosts.
Never suggest installing it wholesale; be careful touching
`flake/modules/general-config/impermanence/` or `fileSystems`/`boot` in the host
hardware modules.

`WARN-impermanence.nix` (reached through the `impermanence` category)
deletes the `/root` btrfs subvolume in initrd on every boot and needs a
`root-blank` subvolume to exist. **Two of the three
NixOS hosts import it and wipe `/root` on boot: `nire-durandal`,
`nire-tenacity`.** `nire-cube` deliberately does not — plain persistent
root, not LUKS+impermanence. Don't assume "every host wipes root" or "no host does" — check
the specific host. Read `WARN-impermanence.nix` before changing anything
near it. A PreToolUse hook (`.agents/hooks/impermanence-edit-guard-pretooluse.sh`)
warns when a file edit lands in that tree or a host hardware module — a
signal to read this section first, not a block.

Secrets are sops-nix (`flake/modules/general-config/system/secrets/`). `secrets.yaml`
is encrypted and committed; that is deliberate, not a mistake to be "fixed".
`.sops.yaml` (same directory) enrolls `nire-durandal`, `nire-lysithea`,
`nire-tenacity`, and `nire-cube` — all live hosts with current config here,
the normal case, not a leftover to prune. That host list is checked against
`.sops.yaml` by `just wiki-lint`, so it cannot rot silently. "Which secrets
exist?" is `just read-sops-names` — names only, never values; everything
else about printing sops output is skill `secrets-hygiene` (Traps below).

## State

**Switch/boot state is deliberately not recorded in this repo** — it rots.
Whether a host runs what the tree evaluates to is a live question, answered
only on the host: `just baseline`, `just diff-deployed`, or a forced
toplevel eval against `/run/current-system`. The repo is not the machine:
before claiming a change affects a host, find out what that host runs, and
for a hardware fact, ask (§2). Capture `just baseline` before switching;
once the old generation is collected it can't be re-derived (§24).

Roster, class, and which hosts wipe `/root`: `host-config/hosts.nix` (check it
before stating any count) and `wiki/hosts.md`'s table. First-boot history
(dates, generations, the `/root` rollback):
`wiki/history.md`'s "Confirmed-on-hardware facts".

- **Check `hostname` before assuming which machine the session is on.**
  Under Claude Code, `.agents/hooks/session-start.sh` puts hostname,
  branch, worktree, dirty count and `core.hooksPath` into context at
  session start (other harnesses: check by hand).
- **ssh to another host over the tailnet as `ts-<x>`, never `nire-<x>`** —
  `nire-<x>` is the hostname (`nire-<x>.local` on the LAN only), and
  tenacity's sshd is tailnet-only. `just reach <x>` tries every name. Rule
  and table: `wiki/hosts.md`; as code: `tailnet-hosts.nix`.
- Host *counts* in prose are claims about when someone last looked — check
  `hosts.nix`.

## Before you start

**Find the page for the task.** `wiki/00-INDEX-for-agents.md` routes by
task; `wiki/lessons-learned.md` files every past mistake by the moment it
applies. Bare `just` lists every recipe.

**Someone reports a bug?** Skill `investigate-bug` first — `just threads
"<keywords>"` — before reproducing anything.

**Ask "did it work before?" first.** `journalctl --list-boots` plus a grep
settles regression-vs-always-broken faster than any argument about
mechanism.

**Before hand-building a multi-step pipeline, check `just agent`** —
agent-written scripts for recurring lookups, any language (the Python rule
under Conventions doesn't bind there). Adding one: skill `agent-scripts`.

**Browsing modules to find something — not editing them?** `just
history-line <file>` prints the line where the module's history section
starts; read up to it and skip the rest. Editing the module is different:
the history is there to be read before changing what it describes.

## Traps, all of which have actually happened here

Short versions — the named skills have the full mechanism and worked
examples; read the skill before doing the matching task. Each heading names
the task that triggers it.

### Writing or renaming a flake-parts module — skill `new-flake-module`

`flake.modules` cannot live inside `perSystem` (no `<system>` axis, no
`freeformType` there). A module's declared name comes from its filename, so
a rename silently drops it from its category if the two disagree; two
modules sharing a name **merge** rather than conflict (`just modules`
catches both). Module classes aren't validated at declaration — a wrong one
fails at the import site. Raw `nixos-generate-config` output needs wrapping
or evaluation dies with a misleading `infinite recursion` naming
`modulesPath`.

### Editing Home Manager shell/dotfile modules — skill `home-manager-dotfiles`

`home.file.<n>.text` and `home.sessionPath` concatenate across modules
rather than override — two modules writing the "same" file double it,
silently. Reading a generated dotfile back is full of false negatives
(wrong attribute name returns empty; some entries have `.source`, not
`.text`). HM's rc ordering silently orphaned a hand-written `starship init`
and a 1,659-line p10k config.

### Editing impermanence or initrd — skill `impermanence-initrd`

The shell's view of the machine (`lsblk`, `findmnt`, `/etc`) is scoped to
its mount namespace and can look wrong while being correct — use
`/proc/1/mountinfo`, `/dev/disk/by-uuid/`, `/run/current-system` instead,
all unprivileged.

### Adding or platform-gating a package — skill `package-platform-support`

Can nixpkgs build it on darwin (automatic, via
`drop-unsupported-packages.nix` — don't hand-restate with
`lib.mkIf (!pkgs.stdenv.isDarwin)`) versus does Homebrew already install it
(never automatic; `just available --duplicates` finds the overlap).
`obsidian.nix` is the worked example.

### Adding a homelab service — skill `new-homelab-service`

Three of the five broke on their first switch for reasons eval,
build and reading the artifact all missed. The skill's verification order
is what they cost; a Tailscale `svc:` name is skill `new-tailscale-service`.

### Printing sops values — skill `secrets-hygiene`

`sops -d` prints every secret in the file; never pipe it through anything,
and never count `2>/dev/null` as protection — that's stderr, stdout still
flows. Hit 2026-08-26 and again 2026-09-09 (three values, both times
answering "which secrets exist?" by decrypting). That question is
`just read-sops-names`, which reads the committed ciphertext and cannot
print a value.

### `${...}` inside a Nix `''` string is interpolation

Writing `${terminfo[khome]}` in what you intend as a comment is an
evaluation error. Escape as `''${...}` or reword. General to any `''`
string, hence inline here rather than in a skill.

### An option that renders into a generated file can swallow a wrong key silently

Freeform settings options (typed `attrsOf …` with a `freeformType`, like
`security.pam.u2f.settings`) render any key verbatim into the generated
config — a misspelled or renamed key evals clean and the consumer discards
it. `settings.authFile` (camelCase of nixpkgs' `authfile`) was ignored by
pam_u2f for five months, masked by the value coinciding with the consumer's
default — §49. Eval passing is a claim about the type, not about the
consumer: read the rendered artifact (`/etc/pam.d/<service>` on the host, or
eval `config.security.pam.services.<name>.text`) when a change touches one.
Reading the nixpkgs module's `mkRenamedOptionModule` block first is the
write-time half — §33; the same read shows the defaults, and config that
restates one reads as a decision nobody made, so leave it out.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked
files, so a new module silently does not exist. `just modules`' untracked
check is the mechanical backstop; `.agents/hooks/nix-untracked-guard-pretooluse.sh`
also warns at eval time, when the untracked file is about to matter.

**Read upstream source rather than guessing at options.** It settled that
`perSystem` has no `freeformType`, that `home.sessionPath` is `listOf str`,
and that HM has no blesh module. For third-party packages, check the
project's current source too — `handheld-daemon` got a bespoke shim for
something upstream had already fixed.

**Read the links in a comment before deleting the code it annotates.** A
cited manual page is there because the code depends on it; dropping a
`requires` it explained nearly changed "does not run" into "runs and fails"
on the unit that deletes `/root` (§11).

**Calibrate severity.** Homelab, not production; the repo has gone six
months between commits. "This is broken and here is the fix" beats incident
framing.

**Security/threat-model analysis for public-facing infra goes in the private `elly/infra-notes` repo on the forge (tailnet-only), not in public PR prose or wiki pages -- keep public descriptions mechanical (what changed, verified how) so they don't read as reconnaissance. Context for review stays intact in the private notes.** (Since 2026-09-25; the merged public history through #380 predates it.)

**Default to a dedicated `git worktree` for any task that will branch,
commit, or check out — skill `use-a-worktree` (not for read-only work; there
since the 2026-08-30 shared-checkout incident).** If git state doesn't match
your own last action, check `git reflog` before concluding anything is
actually broken.

**"push" means the `ship` skill, landing on `experimental`, the default
branch** — branch, PR, one combined ask covering both merging and deleting
the branch afterward. The user naming a branch outright means push directly
there — except `main`, promotion-only (PR from `experimental`, after
hardware verification).

**Never file anything outside `NireBryce/nixos-configs` — an issue or PR on
nixpkgs, ble.sh, carapace, any other project — without the user saying so
explicitly, in those words, unprompted.** A yes to a bundled list does not
cover an upstream filing folded into it. `propose-issue` only ever files
here; `_loose-ends/bugs-pending-submission/` and `wiki/open-threads.md`'s
drafts are deliberately not worked through automatically —
`wiki/open-threads.md` says so itself. Filing
here can still reach another project via GitHub autolinking — a title or
body containing `owner/repo#123` pings that repo — so grep for that shape
before naming a specific upstream issue/PR in anything filed here.

## Before calling it done

Every rule here is a lesson that cost something; each § number is an entry
in `wiki/lessons-learned.md` (the first two groups there), with the full
account in `wiki/lessons-learned/<N>-*.md`.

**Say which rung you reached.** *Evaluates* (`nix eval`, `just check`),
*builds* (`just build`; `nix build --dry-run` in between gives the plan
without compiling), *runs* (switched and used), and for a setting that
renders into a file, *read the rendered artifact*. Each finds defects the
one before cannot. Treat an undated "verified" as *evaluates*, in this repo
and in what you write (§18, §36).

**Bugs here serialize.** Evaluating a cheap attribute proves nothing — §25
records four things that got past both a clean eval and a clean build.
Force a toplevel — eval and build both stop short of defects that only
appear at runtime (§25, §37). Each fix can uncover the next, so a defect
count from reading is a lower bound (§6).

**Verify refactors by fingerprint, but not only by fingerprint.** A
differing hash doesn't prove breakage (reordering imports permutes
`environment.systemPackages`), and an unchanged one can pass for the wrong
reason — dead code looks exactly like safe code until you make it live
(§43). An unchanged fingerprint after a change you expected to matter means
investigate (§4). Compare values with `just diff`, and make refactored paths
run. Run `just diff` across any change that *removes* a module, however
unrelated: removing fish removed the man index (§7). Before betting a
refactor on a mechanism, model the risky part and evaluate it (§12).

**Read the output, not the status.** `cmd | tail` exits 0 when `cmd`
failed; use `set -o pipefail` or don't pipe (§20). Nix puts the innermost
cause last; read a trace to the bottom (§21). Before believing a zero, show
the query can return non-zero; before believing a count, know what it
counts (§22, §31). When a tool contradicts you, check your own assumption
first (§3).

**A new checker is tested against a case it should catch**, in the same
commit — every tool written in the port reported success while wrong (§1).
When an existing check fires on new work, fix its model before reaching for
its escape flag (§23).

**Then:** `just preflight` is what CI runs; skill `wiki-sync` for
any wiki page the change made stale.

## Conventions

**Read `wiki/module-style-guide.md` before writing a new module** — the
formatting there (aligned `=` columns, why `nix fmt` isn't wired up) is
deliberate, not a cleanup target.

**Provenance trailer on every agent-authored commit:
`Co-Authored-By: <agent>` — the agent that wrote it, no model name, no
email.** An agent cannot verify which model is executing it (the log holds
dozens of wrong labels proving it), so the trailer records what it knows.
Claude's canonical form is `Co-Authored-By: Claude`, and
`.agents/settings.json`'s `attribution.commit` makes Claude Code itself ask
for exactly that (since 2026-09-29). `.githooks/commit-msg` (wired by
`just install-hooks`, or by the SessionStart hook) is the backstop for other
harnesses and a stale settings file: it auto-corrects only the
`Claude <model> <email>` shape; any other agent's trailer passes through,
so form it correctly at write time.

**When a rename makes the old name ungreppable, say what it was** on the
declaration — see `boot-durandal.nix`, `boot-cube.nix`.

**A bug recorded in a comment stays in the file.** Nobody reads `git log`;
do not trim one because the fix landed. If a change strands a comment, move
it to a `history` heading at the bottom — still written to stand alone,
under the same compression discipline: facts kept, narration cut
(`boot-durandal.nix`, `WARN-impermanence.nix`, `vscode.nix` have them).

**`elly` is hardcoded**, in `users.users.elly`, `home.username`, and
`home-manager.users.elly`. The now-deleted `flake-parts` branch had a
`nire.primaryUser` option instead; introducing it here is a separate
change, not a tidy-up — `wiki/flake-parts-port-notes.md` has that branch's
reasoning, including the grep-trail convention it came with.

**Prose that means the person says "the user," never the name.** `elly` in
an identifier is the account this config builds; in prose it reads as a
claim about who runs this repo, which doesn't hold for a fork or a fresh
session. A 2026-09-14/15 pass genericized person-references (skills, wiki,
flake comments, this file, the git-guard hook); the `_Sibling reviewed:`
lines quoting "Elly" that it left as records were overwritten by later wiki
passes, and person-references persist in `wiki/experiments/` and one
durandal module comment.

**Check for an existing `programs.*` integration before hand-writing one.**

**Don't bury Python inside a bash script.** `python3 -c '...'` heredocs get
no highlighting, linting, or indentation help — exactly when quoting bugs
stop being visible. A little Python: a real `.py` in
`flake/scripts/`. Mostly Python: the whole thing in Python
(`modules.py` is the precedent). This rule exists because a
bash-wrapping-Nix-wrapping-Python checker shipped both bugs the shape
invites.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere — run
bare `just` for the full list with a one-line summary per recipe; that
list, not a copy of it here, is the source of truth, since `.justfile`'s
own comments are what `just` actually reads. `just preflight` (wiki-lint +
branches-test + check + modules + lint + the script tests; CI runs this
recipe itself) is the ship skill's step 0. `just
hm-collisions`, `just root-drift`, and `just home-drift` are read-only,
and only meaningful on the hardware itself.

`.agents/settings.json`'s `permissions.allow` pre-approves a short list of
read-only recipes for every clone and agent (since 2026-10-01). **Only
read-only commands with a closed argument surface go on it**: exact
recipes, or `just <recipe> *` only when the recipe is
`[positional-arguments]`, so arguments reach the script unparsed. Never
`nix` itself: its flags and `--expr` reach far beyond evaluating this
flake, so it stays a prompt; `just fingerprint` is the pre-approved
drvPath.
`test_guards.py` enforces both rules. `just` runs the nearest justfile
up from its cwd, so `.agents/hooks/just-guard-pretooluse.sh` asks
whenever that isn't this repo's `.justfile`, so an exact rule like
`Bash(just preflight)` only ever pre-approves this repo's recipe. Read-only `git` forms are already
allowed by Claude Code itself. The guard hooks still run first, and a
hook's deny wins over an allow rule — but they are string matchers, not a
boundary.

`host` derives from `hostname`, falling back to `nire-durandal` off-host.
The override goes **before** the recipe name — `just host=nire-durandal
build`; after it, just reads it as a second recipe name and errors.

For iterating, evaluate directly from `flake/`:

```sh
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
```

`elly` is literal on purpose: it reads an *evaluated* config, where the
attribute name is already resolved.

`build`/`boot`/`switch` go through `flake/scripts/rebuild.sh` (picks `nh darwin`
or `nh os` off the flake). On any real host, `just build`/`switch` is a
real test, not just evaluation. A NixOS host cannot be built from any other
machine (no remote builder, no binfmt); `rebuild.sh` says so rather than
failing inside nix.

## Architecture

`flake.nix` is a manifest. `(inputs.import-tree ./modules)` recursively
imports every `.nix` file under `flake/modules/`, and
`flake-parts.flakeModules.modules` declares the `flake.modules.<class>.<name>`
option they all write into. **Every `.nix` file under `modules/` is a
flake-parts module** — top level `{ flake.modules.<class>.<name> = …; }` or
similar, never a bare NixOS or Home Manager module.

### Membership is implicit, and comes from the directory

Each category directory holds a `dirsAsCategory.nix` (a shim over
`flake/modules/_lib/category-collector.nix` since 2026-08-27) that derives
the category name from its own directory and collects the modules beneath
it. **A module belongs to the category of the directory it is filed in**;
adding one is a one-file change. Read `flake/doc/dirsAsCategory.md` before
changing any `dirsAsCategory.nix`.

- **A category collects every `.nix` file under its directory**, at any
  depth, directly beside its `dirsAsCategory.nix` included (since
  2026-09-28; before that, files there were skipped). To keep a module out
  of a category, file it outside the category's tree.
- **Entry points sit outside every category tree** — `modules/checks.nix`,
  `modules/invariants.nix`, `host-config/hosts.nix` and the
  `<host>-configuration.nix` files beside it, and
  `users-config/elly-home-manager.nix`; `just modules` relies on exactly this.

Areas: `general-config/` (shared system, incl. `general-config/macos/` for
darwin), `host-config/` (per-host), `packages-config/`, `users-config/`.
The three were `hosts/`, `packages/`, `users/` until 2026-09-27 — renamed
so no area can share a name a module or category might take: module names
share one namespace per class, and a same-named pair merges silently.

**The category is how something shared stays optional** — nothing in this
tree declares `mkEnableOption`. `kde-desktop` is the by-name variant: one
module imported directly while its category (`desktop-env`, which also
holds `jovian`) is never imported whole.

**`general-config/homelab/` is an umbrella category (2026-08-27)** nesting
several cube-only categories, same coarse-and-fine overlap as
`general-config/hardware`/`general-config/hardware/amd`. Full account,
including the nested categories' names and a real collector quirk:
`wiki/categories/homelab.md`.

**Hosts**: roster and class are `host-config/hosts.nix` (its comments explain
the naming rule, the forge-runner guest, and the removed hosts) and
`wiki/hosts.md`'s table — don't restate the list here, it only rots.

### Home Manager is NixOS-integrated

`home-manager.users.elly` is set from the NixOS side with `useGlobalPkgs`
and `useUserPackages`, in
`general-config/system/home-manager/enable-home-manager.nix`.
No `homeConfigurations` output, no separate home switch; `just switch`
applies both. `flake/doc/trailhead-home-manager-standalone.md` is the way
back; skill `home-manager-dotfiles` has the traps and integration specifics
(rejected `nixpkgs.*`, `profileDirectory`, activation's `PATH`).

### Platform support is derived; Homebrew overlap is not

`ellyHomeManager` is shared verbatim by all four hosts including
`nire-lysithea`, so everything in it has to survive darwin. Two questions
when adding a package: can nixpkgs build it on darwin (answered
automatically off `meta.platforms`), and does Homebrew already install it
(never answered automatically). Skill `package-platform-support` has
the full detail.

## Docs

**Every long wiki page is a pair. Read the `-for-agents.md` half.**
`<page>.md` is explanation written for a human reading cold;
`<page>-for-agents.md` is the same ground at maximum information density —
paths, option names, commands, host lists, every trap as one line, no
narrative. Both exist for the same subject, so loading the human page to
answer a question the sibling already answers is paying for prose you don't
need. Start at `wiki/00-INDEX-for-agents.md`, which routes by task.

The tradeoff, stated so nobody has to rediscover it: this is deliberate
duplication, against the "index over restatement" rule the rest of the wiki
runs on, and `wiki/00-INDEX.md` says outright that this repo has been bitten
repeatedly by one fact living in two places. It is allowed here because it
is the one duplication with a mechanical guard — **`check_wiki.py siblings`
fails when a sibling's `_Last modified:_` predates its source's**, so
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
