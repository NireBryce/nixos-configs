# AGENTS.md

> **Written by agents, for agents.** An agent's working notes, not
> documentation — pitched at something with no memory between sessions,
> dwelling on mistakes because repeating them is the failure mode it exists
> to prevent. Elly has corrected the load-bearing claims; the framing is the
> machine's. `README.md` is the human entry point.
>
> This file is canonical; `CLAUDE.md` is a symlink to it, so every "see
> CLAUDE.md" reference in this repo resolves here. Skills referenced by name
> below are plain markdown at `.claude/skills/<name>/SKILL.md` — any agent
> can read them as files, with or without a harness that loads skills.

Landing work targets `experimental`, the default branch (see "push" under
Working in this repo, and skill `ship`); `main` is the promoted known-good
and moves only via a PR from `experimental` after hardware verification.
Don't assume a branch — check `git branch --show-current`.

## Safety

This config enables impermanence and wipes `/root` on boot on most hosts.
Never suggest installing it wholesale on a machine, and be careful with
anything touching `flake/modules/nire/impermanence/` or the
`fileSystems`/`boot` options in the host hardware modules.

`WARN-impermanence.nix` (reached through the `impermanence` category; named
`boot` until 2026-08-11) deletes the `/root` btrfs subvolume in initrd on
every boot and needs a `root-blank` subvolume to exist. **Two of the three
NixOS hosts import it and wipe `/root` on boot: `nire-durandal`,
`nire-tenacity`.** `nire-cube` deliberately does not — plain persistent
root, not LUKS+impermanence (see cube's own header; corrected in
`2efca5e4`). Don't assume "every host wipes root" or "no host does" — check
the specific host. Read `WARN-impermanence.nix` before changing anything
near it.

Secrets are sops-nix (`flake/modules/nire/system/secrets/`). `secrets.yaml`
is encrypted and committed; that is deliberate, not a mistake to be "fixed".
`.sops.yaml` (same directory) enrolls `nire-durandal`, `nire-lysithea`,
`nire-tenacity`, and `nire-cube` — all live hosts with current config here,
the normal case, not a leftover to prune. Read the file rather than this
paragraph — this paragraph has been stale before.

## State

**Switch/boot state is deliberately not recorded in this repo** — it rots;
only a session standing on the machine at switch time can update it.
Whether a host runs what the tree evaluates to is a live question, answered
on the host: `just baseline` and `just diff-deployed` (Commands below), or
`nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.outPath`
compared with `readlink /run/current-system`.

Roster, class, and which hosts wipe `/root`: `nireHost/hosts.nix` (check it
before stating any count) and `wiki/hosts.md`'s table. First-boot history
(dates, generations, the `/root` rollback):
`wiki/history.md`'s "Confirmed-on-hardware facts".

- **Check `hostname` before assuming which machine the session is on.**
  Sessions have run on `nire-lysithea`, `nire-durandal`, and
  `nire-tenacity`.
- Removed (git history and `wiki/history.md` are the way back):
  `nire-lego` and `nire-installer` (2026-08-27), `nire-testbed` (never on
  real hardware; the `new-host-config` skill has its Intel-host notes),
  `nire-llm-sandbox` (2026-08-28; its generator `VMs/_lib/libvirt-vm.nix`
  is kept as unexercised infrastructure), the port's planning docs
  (2026-08-26), `claude cave/` (2026-09-02, became `wiki/` pages).
- A `claude cave/...` reference in an old commit means the pre-move path.
- Host *counts* in prose are claims about when someone last looked — check
  `hosts.nix`.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere:

```sh
just preflight       # check + modules + lint in one shot -- the ship skill's step 0
just check           # nix flake check --all-systems --no-build
just modules         # static module-tree check; the only one that means anything on darwin
just lint            # statix + deadnix + oversized-file, ratcheted -- see flake/scripts/lint.py
just wiki-lint       # wiki/ claims (imports, tables, links, recipes, skills, secrets, routes) vs the repo; not in preflight yet
just wiki-churn      # rank wiki/ pages by git-log edit churn; reporting only, never fails
just wiki-stale-refs # backtick file/path mentions with no matching tracked file; reporting only, heuristic
just reach <host>    # ssh to durandal/tenacity/cube/lysithea: LAN mDNS, then Tailscale, then DNS
just install-hooks   # one-time: run the checks locally pre-commit, plus the commit-trailer fixup
just available <pkg> # can it build on aarch64-darwin, and does a cask install it too
just available --duplicates   # only the ones homebrew ALSO installs, and what to do
just fingerprint     # drvPath of the host toplevel
just dotfiles        # every generated dotfile's attribute name
just diff HEAD~1     # what changed in a host's config, attribute by attribute
just build / boot / switch   # dispatches per host class; `boot` activates nothing until you reboot
just age-key         # a host's sops recipient key; --updatekeys re-encrypts secrets.yaml
just threads <term>  # search known threads: GitHub issues + wiki/ + lessons-learned.md
```

On the hardware, and read-only: `just hm-collisions` (files HM will take
over, and whether any collide), `just root-drift` (what's on / that no
persistence entry covers; needs sudo).

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

**`nire/homelab/` is an umbrella category (2026-08-27)** nesting
`virtualization`, `containers`, `monitoring`, `git-forge`, `shortlinks`,
`reverse-proxy`, `landing`, and `backup` (2026-08-28) — the same
coarse-and-fine overlap as `nire/hardware`/`nire/hardware/amd`. Each keeps
its own name and stays individually importable (`tenacity` imports
`containers` directly; `nire-cube` imports `homelab` as one line instead of
eight). A bare `.nix` in a nested category's own root is a real quirk of
the mechanism (see `category-collector.nix`'s history section) — nothing is
currently filed that way. Full account: `wiki/categories/homelab.md`.

Categories under `homelab/`, all cube-only unless noted (each has a
`wiki/categories/<name>.md` page; the "category isn't named after its
module" renames all dodge the same silent-merge collision `just modules`
catches):

- **`virtualization`** — libvirt/QEMU VMs; no VM currently defined
  through it.
- **`containers`** — podman + distrobox, cube and tenacity.
  **"virtualization" means VMs only** — containers is separate despite the
  name overlap.
- **`monitoring`** — Prometheus + Grafana, behind Caddy at `.../grafana/`.
- **`git-forge`** — Forgejo, behind Caddy at `.../git/`.
- **`shortlinks`** — golink. **Not a service on cube's network** — tsnet
  joins the tailnet as its own device `go`, no firewall rule, no host
  `tailscaled`. Usage: `wiki/homelab/golinks.md`.
- **`reverse-proxy`** — Caddy, the single tailnet-facing HTTPS listener;
  per-app path-prefix handling differs and has bitten before.
- **`landing`** — glance, what Caddy serves at `/`. A **pair** with
  reverse-proxy: drop it and the front page 502s.
- **`backup`** — restic to the QNAP over SFTP; both sops secrets set
  2026-08-30/31, restore drill still pending
  (`wiki/homelab/pending-setup.md` item 4).

**Hosts**: `hosts.nix` declares one `darwinConfigurations` entry
(`nire-lysithea`, aarch64-darwin) alongside three `nixosConfigurations`:
`nire-durandal` workstation, `nire-tenacity` handheld, `nire-cube` mini PC.
`hosts.nix` comments each right at the declaration.

### Home Manager is NixOS-integrated

`home-manager.users.elly` is set from the NixOS side with `useGlobalPkgs`
and `useUserPackages`, in
`nire/system/home-manager/enable-home-manager.nix`. No
`homeConfigurations` output, no separate home switch; `just switch` applies
both. `flake/doc/trailhead-home-manager-standalone.md` is the way back.

- HM **rejects** `nixpkgs.*` under `useGlobalPkgs` — errors, not ignores.
  `allowUnfree` comes from the system side of `basic-nix-settings.nix`.
- `home.profileDirectory` is `/etc/profiles/per-user/elly`, not
  `~/.nix-profile`.
- Activation runs as a systemd unit, so its `PATH` is only
  coreutils/findutils/gnugrep/gnused/systemd.

### Platform support is derived; Homebrew overlap is not

`ellyHomeManager` is shared verbatim by all five hosts including
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
catches both). Hyphens are legal in Nix identifiers. Module classes aren't
validated at declaration — a wrong one fails at the import site. Raw
`nixos-generate-config` output needs wrapping or evaluation dies with a
misleading `infinite recursion` naming `modulesPath`.

### Editing Home Manager shell/dotfile modules — skill `home-manager-dotfiles`

`home.file.<n>.text` and `home.sessionPath` concatenate across modules
rather than override — two modules writing the "same" file double it,
silently. Reading a generated dotfile back is full of false negatives
(wrong attribute name returns empty; some entries have `.source`, not
`.text`). HM's rc ordering silently orphaned a hand-written `starship init`
and a 1,659-line p10k config.

### Editing impermanence or initrd — skill `impermanence-initrd`

Read `WARN-impermanence.nix` first regardless. In scripted stage-1 hooks,
`@name@` inside a hook string — even in a comment — is a live template
placeholder substituted in the same fixed pass, so naming one can paste a
whole other script in and execute most of it. The shell's view of the
machine (`lsblk`, `findmnt`, `/etc`) is scoped to its mount namespace and
can look wrong while being correct — use `/proc/1/mountinfo`,
`/dev/disk/by-uuid/`, `/run/current-system` instead, all unprivileged.

### Adding or platform-gating a package — skill `nirepackages-platform-support`

Can nixpkgs build it on darwin (automatic, via
`drop-unsupported-packages.nix` — don't hand-restate with
`lib.mkIf (!pkgs.stdenv.isDarwin)`) versus does Homebrew already install it
(never automatic; `just available --duplicates` finds the overlap).
`obsidian.nix` is the worked example.

### Debugging "can't reach a host by tailscale name" — wiki `system.md`

Neither trap is in this repo's config: tailnet device names don't match
`networking.hostName` (`nire-cube` is `ts-cube`, fleet-wide), and a tailnet
ACL can block peer-to-peer while every local firewall setting is right.
Full mechanism: `networking/tailscale.nix`'s header, indexed at
`wiki/categories/system.md`.

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

**Default to a dedicated `git worktree` for any task that will branch,
commit, or check out — skill `use-a-worktree`.** Not for read-only work; a
shared checkout can change underneath you mid-task (hit 2026-08-30: a
session's files reverted and a different branch appeared). If `git
status`/`git branch --show-current`/a file's content doesn't match your own
last action, check `git reflog` before concluding anything is actually
broken.

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
deliberately not worked through automatically (lessons-learned #39).

**Filing here can still reach another project's repo via GitHub
autolinking**: a title or body containing `owner/repo#123` pings that repo.
Grep for that shape before naming a specific upstream issue/PR in anything
filed here.

## Conventions

**Read `wiki/module-style-guide.md` before writing a new module.**
Formatting is deliberate: aligned-`=` columns are intentional and `nix fmt`
is deliberately not wired up (it would flatten them); module bodies sit one
level deeper than needed, and reindenting would risk the `''` strings in
the shell modules.

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
`home-manager.users.elly`. The sibling branch has `nire.primaryUser`;
introducing it here is a separate change, not a tidy-up.

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
- `flake/doc/disko-impermanence-layout.md` — reusable disko generator for
  the LUKS+btrfs+impermanence layout durandal/tenacity run; the template if
  cube ever adopts impermanence.
- `wiki/lessons-learned.md` — how the work went wrong in the doing;
  §§1–18 the port, §§19–31 first hardware, §32+ one-liners in the page
  itself.
- `git show origin/flake-parts:SESSION-HANDOFF.md` — the sibling branch's
  dead ends and settled decisions (needs the `origin/` prefix; no local
  `flake-parts` branch exists).
- `git show origin/flake-parts:linux-flake/flake-parts-reference.md` —
  flake-parts machinery with upstream source behind each claim (that branch
  never went through the `flake/` rename, so the old path is correct there).
