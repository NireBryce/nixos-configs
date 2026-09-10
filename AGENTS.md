# AGENTS.md

> **Written by agents, for agents.** An agent's working notes, not
> documentation — pitched at something with no memory between sessions;
> repeating a mistake is the failure mode it exists to prevent. Elly has
> corrected the load-bearing claims; the framing is the machine's.
> `README.md` is the human entry point.
>
> This file is canonical; `CLAUDE.md` is a symlink to it, so every "see
> CLAUDE.md" reference in this repo resolves here. Skills referenced by name
> below are plain markdown at `.agents/skills/<name>/SKILL.md` — any agent
> can read them as files, with or without a harness that loads skills.

Landing work targets `experimental`, the default branch (see "push" under
Working in this repo, and skill `ship`); `main` is the promoted known-good
and moves only via a PR from `experimental` after hardware verification.
Don't assume a branch — check `git branch --show-current`.

## Safety

This config enables impermanence and wipes `/root` on boot on most hosts.
Never suggest installing it wholesale; be careful touching
`flake/modules/nire/impermanence/` or `fileSystems`/`boot` in the host
hardware modules.

`WARN-impermanence.nix` (reached through the `impermanence` category)
deletes the `/root` btrfs subvolume in initrd on every boot and needs a
`root-blank` subvolume to exist. **Two of the three
NixOS hosts import it and wipe `/root` on boot: `nire-durandal`,
`nire-tenacity`.** `nire-cube` deliberately does not — plain persistent
root, not LUKS+impermanence. Don't assume "every host wipes root" or "no host does" — check
the specific host. Read `WARN-impermanence.nix` before changing anything
near it.

Secrets are sops-nix (`flake/modules/nire/system/secrets/`). `secrets.yaml`
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
toplevel eval against `/run/current-system`.

Roster, class, and which hosts wipe `/root`: `nireHost/hosts.nix` (check it
before stating any count) and `wiki/hosts.md`'s table. First-boot history
(dates, generations, the `/root` rollback):
`wiki/history.md`'s "Confirmed-on-hardware facts".

- **Check `hostname` before assuming which machine the session is on.**
  Sessions have run on `nire-lysithea`, `nire-durandal`, and
  `nire-tenacity`.
- Host *counts* in prose are claims about when someone last looked — check
  `hosts.nix`.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere — run
bare `just` for the full list with a one-line summary per recipe; that
list, not a copy of it here, is the source of truth, since `.justfile`'s
own comments are what `just` actually reads. `just preflight` (check +
modules + lint) is the ship skill's step 0. `just hm-collisions` and `just
root-drift` are read-only, and only meaningful on the hardware itself.

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

`build`/`boot`/`switch` go through `scripts/rebuild.sh` (picks `nh darwin`
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

Each category directory holds a `dirsAsCategory.nix` (a two-line shim over
`flake/modules/_lib/category-collector.nix` since 2026-08-27) that derives
the category name from its own directory and collects the modules beneath
it. **A module belongs to the category of the directory it is filed in**;
adding one is a one-file change. Read `flake/doc/dirsAsCategory.md` before
changing any `dirsAsCategory.nix`.

- **A category collects from its *sub*directories only.** A `.nix` file
  sitting directly in a category directory is collected by nothing.
- **Entry points sit outside every category tree** — `modules/checks.nix`,
  `nireHost/hosts.nix`, `nireHost/durandal-configuration.nix`, and
  `nireUser/elly-home-manager.nix`; `just modules` relies on exactly this.

Areas: `nire/` (shared system, incl. `nire/macos/` for darwin), `nireHost/`
(per-host), `nirePackages/`, `nireUser/`.

**The category is how something shared stays optional** — nothing in this
tree declares `mkEnableOption`. `kde-desktop` is the by-name variant: one
module imported directly while its category (`desktop-env`, which also
holds `jovian`) is never imported whole.

**`nire/homelab/` is an umbrella category (2026-08-27)** nesting several
cube-only categories, same coarse-and-fine overlap as
`nire/hardware`/`nire/hardware/amd`. Full account, including the nested
categories' names and a real collector quirk: `wiki/categories/homelab.md`.

**Hosts**: roster and class are `nireHost/hosts.nix` (commented at each
declaration) and `wiki/hosts.md`'s table — don't restate the list here, it
only rots.

### Home Manager is NixOS-integrated

`home-manager.users.elly` is set from the NixOS side with `useGlobalPkgs`
and `useUserPackages`, in `nire/system/home-manager/enable-home-manager.nix`.
No `homeConfigurations` output, no separate home switch; `just switch`
applies both. `flake/doc/trailhead-home-manager-standalone.md` is the way
back; skill `home-manager-dotfiles` has the traps and integration specifics
(rejected `nixpkgs.*`, `profileDirectory`, activation's `PATH`).

### Platform support is derived; Homebrew overlap is not

`ellyHomeManager` is shared verbatim by all four hosts including
`nire-lysithea`, so everything in it has to survive darwin. Two questions
when adding a package: can nixpkgs build it on darwin (answered
automatically off `meta.platforms`), and does Homebrew already install it
(never answered automatically). Skill `nirepackages-platform-support` has
the full detail.

## Traps, all of which have actually happened here

Short versions — the named skills have the full mechanism and worked
examples; read the skill before doing the matching task.

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
all unprivileged. (This repo moved to systemd stage 1 2026-08-10; the
skill's History section has the scripted-stage-1 template-injection trap
that mechanism retired.)

### Adding or platform-gating a package — skill `nirepackages-platform-support`

Can nixpkgs build it on darwin (automatic, via
`drop-unsupported-packages.nix` — don't hand-restate with
`lib.mkIf (!pkgs.stdenv.isDarwin)`) versus does Homebrew already install it
(never automatic; `just available --duplicates` finds the overlap).
`obsidian.nix` is the worked example.

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

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked
files, so a new module silently does not exist. `just modules`' untracked
check is the mechanical backstop.

**Read upstream source rather than guessing at options.** It settled that
`perSystem` has no `freeformType`, that `home.sessionPath` is `listOf str`,
and that HM has no blesh module. For third-party packages, check the
project's current source too — `handheld-daemon` got a bespoke shim for
something upstream had already fixed.

**Verify refactors by fingerprint, but not only by fingerprint.** A
differing hash doesn't prove breakage (reordering imports permutes
`environment.systemPackages`), and an unchanged one can pass for the wrong
reason — dead code looks exactly like safe code until you make it live
(§43). Compare values with `just diff`, and make refactored paths run.

**Bugs here serialize.** Evaluating a cheap attribute proves nothing;
`networking.hostName` resolved happily while four separate things were
broken. Force a toplevel — eval and build both stop short of defects that
only appear at runtime (§25, §37).

**Ask "did it work before?" first.** `journalctl --list-boots` plus a grep
settles regression-vs-always-broken faster than any argument about
mechanism.

**Calibrate severity.** Homelab, not production; the repo has gone six
months between commits. "This is broken and here is the fix" beats incident
framing.

**Browsing modules to find something — not editing them?** `just
history-line <file>` prints the line where the module's history section
starts; read up to it and skip the rest. Editing the module is different:
the history is there to be read before changing what it describes.

**Default to a dedicated `git worktree` for any task that will branch,
commit, or check out — skill `use-a-worktree` (not for read-only work; there
since the 2026-08-30 shared-checkout incident).** If git state doesn't match
your own last action, check `git reflog` before concluding anything is
actually broken.

**"push" means the `ship` skill, landing on `experimental`, the default
branch** — branch, PR, one combined ask covering both merging and deleting
the branch afterward. Elly naming a branch outright means push directly
there — except `main`, promotion-only (PR from `experimental`, after
hardware verification).

**Never file anything outside `NireBryce/nixos-configs` — an issue or PR on
nixpkgs, ble.sh, carapace, any other project — without Elly saying so
explicitly, in those words, unprompted.** A yes to a bundled list does not
cover an upstream filing folded into it. `propose-issue` only ever files
here; `bugs pending submission/` and `wiki/open-threads.md`'s drafts are
deliberately not worked through automatically (`wiki/lessons-learned.md` §39). Filing
here can still reach another project via GitHub autolinking — a title or
body containing `owner/repo#123` pings that repo — so grep for that shape
before naming a specific upstream issue/PR in anything filed here.

## Conventions

**Read `wiki/module-style-guide.md` before writing a new module** — the
formatting there (aligned `=` columns, why `nix fmt` isn't wired up) is
deliberate, not a cleanup target.

**Provenance trailer on every agent-authored commit:
`Co-Authored-By: <agent>` — the agent that wrote it, no model name, no
email.** An agent cannot verify which model is executing it (the log holds
dozens of wrong labels proving it), so the trailer records what it knows.
Claude's canonical form is `Co-Authored-By: Claude`. `.githooks/commit-msg`
(active after `just install-hooks`) auto-corrects only the
`Claude <model> <email>` shape; any other agent's trailer passes through,
so form it correctly at write time.

**Namespacing.** `nire` unless it needs a more specific tag; `nireHost`,
`nireUser`, `nirePackages` otherwise.

**When a rename makes the old name ungreppable, say what it was** on the
declaration — see `boot-durandal.nix`, `enable-home-manager.nix`.

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

**Check for an existing `programs.*` integration before hand-writing one.**

**Don't bury Python inside a bash script.** `python3 -c '...'` heredocs get
no highlighting, linting, or indentation help — exactly when quoting bugs
stop being visible. A little Python: a real `.py` in
`flake/scripts/util/`. Mostly Python: the whole thing in Python
(`modules.py` is the precedent). This rule exists because a
bash-wrapping-Nix-wrapping-Python checker shipped both bugs the shape
invites.

## Docs

- `wiki/README.md` — topic index. **Maintained the same way this file is**:
  a change that makes a wiki page stale corrects it in the same change
  (`just wiki-lint` checks the mechanical claims).
- `wiki/lessons-learned.md` — how the work went wrong in the doing;
  §§1–18 the port, §§19–31 first hardware. Long entries are per-§ articles
  under `wiki/lessons-learned/`; the page keeps every § number and a
  one-line version of each.
