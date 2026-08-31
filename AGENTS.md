# AGENTS.md

> **Written by agents, for agents.** An agent's working notes, not
> documentation — pitched at something with no memory between sessions, dwelling
> on mistakes because repeating them is the failure mode it exists to prevent.
> Elly has corrected the load-bearing claims; the framing is the machine's.
> `README.md` is the human entry point.
>
> This file is the canonical one; `CLAUDE.md` is a symlink to it, so every
> "see CLAUDE.md" reference in this repo (skills, wiki, scripts) resolves here.
> Skills referenced by name below are plain markdown at
> `.claude/skills/<name>/SKILL.md` — any agent can read them as files, with or
> without a harness that loads skills automatically.

Landing work targets `experimental` (see "push" under Working in this repo, and
skill `ship`); GitHub's default branch stays `main`. Don't assume a branch —
check `git branch --show-current`.

## Safety

The README's warning is real: this config enables impermanence and wipes `/root`
on boot on most hosts. Never suggest installing it wholesale on a machine, and
be careful with anything touching `flake/modules/nire/impermanence/` or the
`fileSystems`/`boot` options in the host hardware modules.

`WARN-impermanence.nix` (reached through the `impermanence` category; the
category was named `boot` until 2026-08-11) deletes the `/root` btrfs subvolume
in initrd on every boot and depends on a `root-blank` subvolume existing on the
machine. **Two of the three NixOS hosts import it and wipe `/root` on boot:
`nire-durandal`, `nire-tenacity`.** `nire-cube` deliberately does
not — its real install is a plain persistent root, not LUKS+impermanence (see
cube's own header; corrected in `2efca5e4`). Don't assume "every host wipes
root" or "no host does" — check the specific host. Read `WARN-impermanence.nix`
and `claude cave/lessons-learned-impermanence-stage1-migration.md` before
changing anything near it.

Secrets are sops-nix (`flake/modules/nire/system/secrets/`). `secrets.yaml` is
encrypted and committed; that is deliberate, not a mistake to be "fixed".
`.sops.yaml` (same directory) enrolls `nire-durandal`, `nire-lysithea`,
`nire-tenacity`, and `nire-cube` — all live hosts with current config here, the
normal case, not a leftover to prune. Read the file rather than this
paragraph — this paragraph has been stale before.

## State

| host | status |
| --- | --- |
| `nire-tenacity` | booted this config 2026-08-10 (gen 62, systemd stage 1); `/root` rollback confirmed by subvolid in the journal, not by the machine coming up |
| `nire-lysithea` | switched 2026-08-12 (gen 52, darwin) |
| `nire-durandal` | booted this config 2026-08-14 (gen 222); rollback confirmed in the journal the same way |
| `nire-cube` | switched 2026-08-23; monitoring, git-forge, shortlinks, reverse-proxy, and landing all confirmed working end to end 2026-08-24. Grafana's `secret_key` fix lives in the module (`grafana-secret-key-setup.service` in `grafana.nix`), deliberately not a hand fix — the hand fix regressed once already. Fix-by-fix detail: `wiki/open-threads.md`, lessons-learned §40–§43 |

- **Check `hostname` before assuming which machine the session is on.**
  Sessions have run on `nire-lysithea`, directly on `nire-durandal`, and on
  `nire-tenacity`.
- `nire-lego` (added, never built or switched) and `nire-installer` (the
  generic live-USB installer image, target chosen at build time) were both
  removed 2026-08-27 — see `wiki/history.md`. If a handheld or a live-USB
  installer is needed again, their last config (git history) is the starting
  point, not a reason to assume either is still wired up.
- `nire-testbed` (added 2026-08-14, removed 2026-08-22, never installed on real
  hardware) is gone. If a similar Intel workstation is ever added, its last
  config (git history) and the `new-host-config` skill's notes are the starting
  point — not a reason to assume any of it is still wired up.
- `nire-llm-sandbox` (a libvirt VM image on cube sandboxing an LLM coding
  agent, never booted on real hardware — see the "verified further than
  evaluation" caveat this section used to carry for it) was removed
  2026-08-28 — see `wiki/history.md`. The generic generator it was built on,
  `VMs/_lib/libvirt-vm.nix`, is kept as unexercised reusable infrastructure;
  its last full config (git history) is the starting point if a VM like it
  is wanted again.
- Host counts and statuses in prose are claims about when someone last looked,
  not about the tree — check `hosts.nix`.
- The den→flake-parts port is done. Its planning doc and four other
  `old`/`old-historical`-prefixed files under `claude cave/` were removed
  2026-08-26 as superseded by `lessons-learned.md` and this section — see
  `wiki/history.md`.
## Commands

`just` recipes live in the root `.justfile` and work from anywhere:

```sh
just preflight       # check + modules + lint in one shot -- the ship skill's step 0
just check           # nix flake check --all-systems --no-build
just modules         # static module-tree check; the only one that means anything on darwin
just lint            # statix + deadnix + oversized-file, ratcheted -- see flake/scripts/lint.py
just wiki-lint       # wiki/AGENTS.md claims (imports, tables, links, recipes, skills, secrets, routes) vs the repo; not in preflight yet
just wiki-churn      # rank wiki/ pages by git-log edit churn; reporting only, never fails
just wiki-stale-refs # backtick file/path mentions with no matching tracked file; reporting only, heuristic
just reach <host>    # ssh to durandal/tenacity/cube/lysithea, trying LAN mDNS then Tailscale then DNS
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

On the hardware, and read-only:

```sh
just baseline        # what the machine is REALLY running -- capture before switching
just hm-collisions   # which files HM will take over, and whether any would collide
just diff-deployed   # package-level diff, running vs new toplevel; needs `just build` first
just root-drift      # what's on / that no persistence entry covers -- needs sudo
```

`host` derives from `hostname`, falling back to `nire-durandal` off-host. The
override goes **before** the recipe name — `just host=nire-durandal build`;
after it, just reads it as a second recipe name and errors.

For iterating, evaluate directly from `flake/`:

```sh
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
```

`elly` is literal on purpose: it reads an *evaluated* config, where the
attribute name is already resolved.

`build`/`boot`/`switch` go through `scripts/rebuild.sh`, which asks the flake
whether the host is a `darwinConfiguration` and calls `nh darwin` or `nh os`.
On any real host, `just build`/`switch` there is a real test, not just
evaluation. A NixOS host cannot be built from any other machine (no remote
builder, no binfmt); `rebuild.sh` says so rather than failing inside nix.

## Architecture

`flake.nix` is a manifest. `(inputs.import-tree ./modules)` recursively imports
every `.nix` file under `flake/modules/`, and
`flake-parts.flakeModules.modules` declares the `flake.modules.<class>.<name>`
option they all write into. **Every `.nix` file under `modules/` is a
flake-parts module** — its top level is `{ flake.modules.<class>.<name> = …; }`
or similar, never a bare NixOS or Home Manager module.

### Membership is implicit, and comes from the directory

Each category directory holds a `dirsAsCategory.nix` (a two-line shim over
shared logic in `flake/modules/_lib/category-collector.nix` since 2026-08-27),
which derives the category name from its own directory, collects the modules
beneath it, and declares one aggregate per class. **A module belongs to the
category of the directory it is filed in**; adding one is a one-file change.
Read `flake/doc/dirsAsCategory.md` before changing any `dirsAsCategory.nix` —
it covers the mechanism, what is load-bearing in it, and its history.

Two consequences worth holding onto:

- **A category collects from its *sub*directories only.** A `.nix` file sitting
  directly in a category directory is collected by nothing.
- **Entry points are defined by being outside every category tree.**
  `modules/checks.nix`, `nireHost/hosts.nix`,
  `nireHost/durandal-configuration.nix`, and
  `nireUser/elly-home-manager.nix` all sit where `dirsAsCategory` cannot reach
  them, deliberately; `just modules` relies on exactly this rule.

Areas: `nire/` (shared system, including a `nire/macos/` subarea for darwin),
`nireHost/` (per-host), `nirePackages/` (packages), `nireUser/` (elly).

**The category is how something shared stays optional** — nothing in this tree
declares `mkEnableOption`. `kde-desktop` is the by-name variant of the same
idea: one module imported directly while its category (`desktop-env`, which
also holds `jovian`) is never imported whole.

**`nire/homelab/` is an umbrella category (2026-08-27)** nesting
`virtualization`, `containers`, `monitoring`, `git-forge`, `shortlinks`,
`reverse-proxy`, `landing`, and (added 2026-08-28) `backup` — the same coarse-and-fine overlap as
`nire/hardware`/`nire/hardware/amd`. Each nested category keeps its own name
and is still individually importable (`tenacity` imports `containers`
directly); `nire-cube` imports `homelab` as one line instead of eight. A bare
`.nix` file sitting directly in a nested category's own root (out of that
category's own aggregate, but swept into `homelab`'s) is a real quirk of the
mechanism — see `category-collector.nix`'s history section for the bug it
caused once — but nothing in the tree is currently filed that way. Full
account: `wiki/categories/homelab.md`.

Categories under `homelab/`, all cube-only unless noted (each has a
`wiki/categories/<name>.md` page; the "category isn't named after its module"
renames all dodge the same silent-merge collision `just modules` catches):

- **`virtualization`** — libvirt/QEMU VMs. Cube is the only importer; durandal
  dropped it 2026-08-27 (carried for unused parity — nothing in this repo's
  history records durandal ever running a VM), and the handhelds decline it.
  No VM is currently defined through it — `nire-llm-sandbox`, the one that
  was, is gone (removed 2026-08-28; see State). The generator it ran on,
  `VMs/_lib/libvirt-vm.nix` (see skill `nixos-vm-images`), is kept as
  unexercised reusable infrastructure: it starts libvirt's default NAT
  network itself when a VM asks for one (libvirt ships it
  defined-but-stopped), and takes an `sshForward` parameter restricted by
  source IP. Its first and only outing hit three runtime-only bugs invisible
  to eval and build (lessons-learned §40).
- **`containers`** — podman + distrobox (`podman/podman.nix`; the module was
  renamed from `containers.nix` for the collision reason above). Imported by
  cube and tenacity — durandal dropped it 2026-08-27. **"virtualization"
  means VMs only**; containers are a separate category, and the word means the
  other thing.
- **`monitoring`** — Prometheus + Grafana on the host's own metrics. Every
  listener is on `127.0.0.1`, Grafana included (since 2026-08-24; before, it
  leaned on `tailscale.nix`'s `trustedInterfaces` firewall rule). Reached via
  Caddy at `https://ts-cube.moose-micro.ts.net/grafana/`.
- **`git-forge`** — Forgejo, loopback `:3001` behind Caddy at `.../git/`.
  Generates its own secrets on first activation, unlike Grafana.
- **`shortlinks`** — golink. Two things easy to get wrong by analogy: **no
  `services.golink` exists in nixpkgs** — the module hand-writes its systemd
  unit (its first switch failed on a missing `AF_NETLINK` in
  `RestrictAddressFamilies`); and it is **not a service on cube's network** —
  tsnet joins the tailnet as its own device `go`, needing no firewall rule and
  no host `tailscaled`. Usage: `wiki/homelab/golinks.md`.
- **`reverse-proxy`** — Caddy, the single tailnet-facing HTTPS listener. Certs
  come from tailscaled itself (no plugin, no ACME), which needs
  `services.tailscale.permitCertUid = "caddy"`, set in `caddy.nix` rather than
  in `system`'s `tailscale.nix` so it doesn't reach hosts that don't run caddy.
  Routing is **by path, not subdomain** (MagicDNS gives a device one name):
  `handle` (prefix kept) is right for Grafana, `handle_path` (prefix stripped)
  is required for Forgejo, which serves at `/` regardless of its `ROOT_URL` —
  that mismatch survived eval, `caddy adapt`, a build, and reading the artifact
  back (lessons-learned #41).
- **`landing`** — glance, what Caddy serves at `/`. A **pair** with
  reverse-proxy: drop it and the front page 502s. Not a second monitoring
  system; and a 200 from the page proves little — glance renders behind
  `/api/pages/home/content/`, which is the check that matters.
- **`backup`** (2026-08-28) — restic to the QNAP. Shipped as a local-path
  repository on the QNAP NFS mount (`/mnt/restic-backup`,
  `nire/system/storage/storage-NFS.nix`); that failed for real
  (`access denied by server`, the share's export ACL never included cube),
  and as of 2026-08-31 switched to **SFTP** instead — issue #87's original
  plan, real per-connection key auth rather than an IP allowlist. SSH now
  works on the QNAP with a dedicated key generated for this, confirmed
  authenticating by hand; a real build on cube confirms everything else
  works, blocked only on two sops secrets this session can't set (the
  repository password, and the new SSH private key) — see the category's
  own page for the switch's reasoning; tracked in
  `wiki/homelab/pending-setup.md` item 4 and `wiki/homelab/backup-runbook.md`.

**Hosts**: `hosts.nix` declares one `darwinConfigurations` entry
(`nire-lysithea`, aarch64-darwin) alongside three `nixosConfigurations`, all
real hosts: `nire-durandal` workstation, `nire-tenacity` handheld, `nire-cube`
mini PC. `hosts.nix` comments each right at the declaration; check it before
stating any count.

### Home Manager is NixOS-integrated

`home-manager.users.elly` is set from the NixOS side with `useGlobalPkgs` and
`useUserPackages`, in `nire/system/home-manager/enable-home-manager.nix`. No
`homeConfigurations` output, no separate home switch; `just switch` applies
both. `flake/doc/trailhead-home-manager-standalone.md` is the way back.

- HM **rejects** `nixpkgs.*` under `useGlobalPkgs` — errors, not ignores.
  `allowUnfree` comes from the system side of `basic-nix-settings.nix`.
- `home.profileDirectory` is `/etc/profiles/per-user/elly`, not `~/.nix-profile`.
- Activation runs as a systemd unit, so its `PATH` is only
  coreutils/findutils/gnugrep/gnused/systemd.

### Platform support is derived; Homebrew overlap is not

`ellyHomeManager` is shared verbatim by all five hosts including
`nire-lysithea`, so everything in it has to survive darwin. Two questions when
adding a package: can nixpkgs build it on darwin (answered automatically off
`meta.platforms`), and does Homebrew already install it (never answered
automatically). Skill `nirepackages-platform-support` has the full detail and
worked examples.

## Traps, all of which have actually happened here

Short versions — the named skills have the full mechanism and worked examples;
read the skill before doing the matching task.

### Writing or renaming a flake-parts module — skill `new-flake-module`

`flake.modules` cannot live inside `perSystem` (no `<system>` axis, no
`freeformType` there — 151 files got this wrong in the port). A module's
declared name comes from its filename, so a rename silently drops it from its
category if the two disagree. Hyphens are legal in Nix identifiers (`kde-base`
is one token). Two modules sharing a name **merge** rather than conflict
(`just modules` catches this). Module classes aren't validated at declaration —
a wrong one fails later, at the import site. Raw `nixos-generate-config` output
needs wrapping or evaluation dies with a misleading `infinite recursion` naming
`modulesPath`.

### Editing Home Manager shell/dotfile modules — skill `home-manager-dotfiles`

`home.file.<n>.text` and `home.sessionPath` concatenate across modules rather
than override — two modules writing the "same" file double it, silently.
Reading a generated dotfile back is full of false negatives (wrong attribute
name returns empty; some entries have `.source`, not `.text`). HM's rc ordering
(`mkBefore` → `mkOrder 550` → `programs.zsh.plugins` → unordered) silently
orphaned a hand-written `starship init` and a 1,659-line p10k config.

### Editing impermanence or initrd — skill `impermanence-initrd`

Read `WARN-impermanence.nix` first regardless. In the scripted stage-1 hooks,
`@name@` inside a hook string — even in a comment — is a live template
placeholder substituted in the same fixed pass, so naming one can paste a whole
other script in and execute most of it. The shell's view of the machine
(`lsblk`, `findmnt`, `/etc`) is scoped to its mount namespace and can look
wrong while being correct — use `/proc/1/mountinfo`,
`/dev/disk/by-uuid/`, `/run/current-system` instead, all unprivileged.

### Adding or platform-gating a package — skill `nirepackages-platform-support`

Can nixpkgs build it on darwin (automatic, via `drop-unsupported-packages.nix`
— don't hand-restate with `lib.mkIf (!pkgs.stdenv.isDarwin)`) versus does
Homebrew already install it (never automatic; `just available --duplicates`
finds the overlap, which one wins is a judgement call). `obsidian.nix` is the
worked example.

### Debugging "can't reach a host by tailscale name" — wiki `system.md`

Neither trap is in this repo's config: tailnet device names don't match
`networking.hostName` (`nire-cube` is `ts-cube`, fleet-wide), and a tailnet ACL
can block peer-to-peer while every local firewall setting is right — fixed in
Tailscale's admin console. Full mechanism: `networking/tailscale.nix`'s header,
indexed at `wiki/categories/system.md`.

### `${...}` inside a Nix `''` string is interpolation

Writing `${terminfo[khome]}` in what you intend as a comment is an evaluation
error. Escape as `''${...}` or reword. General to any `''` string, hence inline
here rather than in a skill.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked files, so
a new module silently does not exist. `just modules`' untracked check catches
this mechanically now — this is the backstop for when it wasn't run.

**Read upstream source rather than guessing at options.** It settled that
`perSystem` has no `freeformType`, that `home.sessionPath` is `listOf str`, and
that HM has no blesh module (so `programs.bash.blesh.enable` did nothing). For
third-party packages, check the project's current source too — `handheld-daemon`
got a bespoke shim for something upstream had already fixed.

**Verify refactors by fingerprint, but not only by fingerprint.** A differing
hash doesn't prove breakage (reordering imports permutes
`environment.systemPackages`), and an unchanged one can pass for the wrong
reason — dead code looks exactly like safe code until you make it live
(lessons-learned §43). Compare values with `just diff`, and make refactored
paths actually run.

**Bugs here serialize.** Evaluating a cheap attribute proves nothing;
`networking.hostName` resolved happily while four separate things were broken.
Force a toplevel — and know that eval and build both stop short of defects that
only appear at runtime (§25, §37).

**Ask "did it work before?" first.** `journalctl --list-boots` plus a grep
settles regression-vs-always-broken faster than any argument about mechanism.

**Calibrate severity.** Homelab, not production; the repo has gone six months
between commits. "This is broken and here is the fix" beats incident framing.

**Default to a dedicated `git worktree` for any task that will branch,
commit, or check out — skill `use-a-worktree`.** Not for read-only work;
see that skill's own "Applies to" for the exceptions. A shared working
directory can change underneath you with no warning: two sessions (or a
session plus manual work) pointed at the same checkout see each other's
`git checkout`/commit/branch delete immediately, mid-task. Hit 2026-08-30:
files reverted to stale content, a different branch was suddenly checked
out, and it took several turns to recognize "something external changed
this" instead of "my last edit didn't take." If `git status`/`git branch
--show-current`/a file's content doesn't match what you expect from your
own last action, check `git reflog` for a checkout or commit you didn't
make before concluding anything is actually broken.

**"push" means the `ship` skill, landing on `experimental`** — branch, PR, ask
before merging, ask again before deleting the branch. Elly naming a branch
outright (`main` included) means push directly there instead, bypassing the
flow. The skill has the flow and why.

**Never file anything outside `NireBryce/nixos-configs` — an issue or PR on
nixpkgs, ble.sh, carapace, any other project — without Elly saying so
explicitly, in those words, unprompted.** A yes to a bundled "ok to do these
four things" does not cover an upstream filing folded into it, even if it was
one of the four and nothing was hidden. `propose-issue` only ever files in this
repo, and `bugs pending submission/` plus `wiki/open-threads.md`'s "Pending
upstream bug reports" are deliberately drafts nothing works through
automatically — this rule is what keeps that true (lessons-learned #39).

**Filing here can still reach another project's repo via GitHub autolinking.**
A title or body containing `owner/repo#123` cross-references and pings that
repo — a real ping, nothing filed there needed. Plain prose naming a project,
even `akinomyoga/ble.sh` without a trailing `#number`, does not trigger it.
Grep for the `owner/repo#number` shape before naming a specific upstream
issue/PR in anything filed here.

## Conventions

**Read `claude cave/claude-style-guide.md` before writing a new module.**
Formatting is deliberate: aligned-`=` columns are intentional and `nix fmt` is
deliberately not wired up because it would flatten them; module bodies sit one
level deeper than needed (left over from unwrapping `perSystem`) and
reindenting would risk the `''` strings in the shell modules.

**Provenance trailer on every agent-authored commit:
`Co-Authored-By: <agent>`, naming the agent that wrote it — no model name,
no email.** Claude's canonical form is `Co-Authored-By: Claude`; any other
agent uses the same shape with its own name. The reasoning generalizes: an
agent cannot verify which model is executing it — the name comes from a
system prompt that may be stale or generic, and the log holds dozens of
wrong labels proving it — so the trailer records the agent, which it does
know, and omits the model, which it doesn't. `.githooks/commit-msg` (active
after `just install-hooks`) auto-corrects only the `Claude <model> <email>`
shape to the canonical form; any other agent's trailer passes through
untouched, so form it correctly at write time. Existing commits keep
theirs.

**Namespacing.** `nire` unless it needs a more specific tag; `nireHost`,
`nireUser`, `nirePackages` otherwise.

**When a rename makes the old name ungreppable, say what it was** on the
declaration — see `boot-durandal.nix`, `enable-home-manager.nix`.

**A bug recorded in a comment stays in the file.** Nobody reads `git log`; the
comment is what the next editor sees. Do not trim one because the fix landed.
If a change strands a comment entirely, move it to a `history` heading at the
bottom — still written to stand alone (dates, mechanism, what was tried,
outcome), but under the same compression discipline as every other comment:
facts kept, narration cut (`boot-durandal.nix`, `WARN-impermanence.nix`,
`vscode.nix` have them).

**`elly` is hardcoded**, in `users.users.elly`, `home.username`, and
`home-manager.users.elly`. The sibling branch has `nire.primaryUser`;
introducing it here is a separate change, not a tidy-up.

**Check for an existing `programs.*` integration before hand-writing one.**

**Don't bury Python inside a bash script.** `python3 -c '...'` heredocs get no
highlighting, linting, or indentation help — exactly when quoting bugs stop
being visible. A little Python: a real `.py` in `flake/scripts/util/`. Mostly
Python: write the whole thing in Python (`modules.py` is the precedent). This
rule exists because a bash-wrapping-Nix-wrapping-Python checker shipped both
bugs the shape invites.

## Docs

- `wiki/README.md` — topic index over everything below and more. **Maintained
  the same way this file is**: a change that makes a wiki page stale corrects
  it in the same change, not as a follow-up (`just wiki-lint` checks the
  mechanical claims).
- `flake/doc/dirsAsCategory.md` — the category mechanism, what's load-bearing,
  and its History section.
- `flake/doc/disko-impermanence-layout.md` — reusable disko generator for the
  LUKS+btrfs+impermanence layout durandal/tenacity run; the template if cube
  ever adopts impermanence.
- `claude cave/lessons-learned-impermanence-stage1-migration.md` — the root
  rollback's move to systemd-initrd; evaluates, never booted. Read before
  touching initrd.
- `claude cave/lessons-learned.md` — how the work went wrong in the doing.
  §§1–18 port, §§19–31 first hardware, then: §32 manually pinned state, §33
  removed nixpkgs options assert, §34/§35 category/module name collisions
  merge silently, §36 read the built artifact, §37 some bugs need a real
  `switch`, §38 scope the fix to the caller that needs it, §39 live pty repro
  and newest-file bias, §40 unit failed ≠ resource down, §41 routing bugs
  survive eval+build+artifact-read, §42 `settings.local.json` is not a Nix
  module, §43 dead code passes fingerprints.
- `flake/doc/trailhead-home-manager-standalone.md` — reversing the HM decision,
  and the part that's one-way on the machine.
- `git show origin/flake-parts:SESSION-HANDOFF.md` — the sibling branch's dead
  ends and settled decisions (needs the `origin/` prefix; no local
  `flake-parts` branch exists).
- `git show origin/flake-parts:linux-flake/flake-parts-reference.md` —
  flake-parts machinery with upstream source behind each claim (that branch
  never went through the `flake/` rename, so the old path is correct there).
