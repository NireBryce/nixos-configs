# CLAUDE.md

> **Written by Claude Code, for Claude Code.** This is an agent's working notes,
> not documentation. It is pitched at something with no memory between sessions,
> so it belabours things a human would only need told once, and it dwells on
> mistakes because repeating them is the failure mode it exists to prevent.
> Elly has corrected the load-bearing claims; the framing is the machine's.
> `README.md` is the human entry point.

Guidance for Claude Code working in this repository, on `main`. (The
`flake-parts-consolidation` branch this was originally written on merged into
`main` via PR #30 on 2026-08-14; `main` is now well ahead of it. Don't assume
you're on that branch — check `git branch --show-current`.)

## Safety

The README's warning is real: this config enables impermanence and wipes `/root`
on boot on most hosts. Never suggest installing it wholesale on a machine, and
be careful with anything touching `flake/modules/nire/impermanence/` or the
`fileSystems`/`boot` options in the host hardware modules.

`WARN-impermanence.nix` is reached through the `impermanence` category --
named `boot` until 2026-08-11; renamed because `boot` had come to mean only
this. It deletes the `/root` btrfs subvolume in initrd on every boot, and it
depends on a `root-blank` subvolume existing on the machine. **Three of the
four NixOS hosts import it and wipe `/root` on every boot: `nire-durandal`,
`nire-tenacity`, `nire-lego`.** `nire-cube` (added 2026-08-20) deliberately
does **not** import it -- its config says so explicitly, because it hits
persistence assumptions the other hosts don't (see cube's header: its real
install turned out to be a plain root, not LUKS+impermanence, corrected
2026-08-21 in `2efca5e4`). `nire-testbed` opted out the same way, for the same
reason, before it was removed 2026-08-22 (never installed on real hardware --
see State). Don't assume "every host wipes root" or "no host
does" -- check the specific host. (`nire-installer`, added 2026-08-15, is
neither -- it's a live-USB image with no persistent `/root` to roll back, not
one of "the four" above; see State.) Read `WARN-impermanence.nix`, and
`claude cave/lessons-learned-impermanence-stage1-migration.md`, before changing anything near it.

Secrets are sops-nix (`flake/modules/nire/system/secrets/`).
`secrets.yaml` is encrypted and committed; that is deliberate, not a mistake to
be "fixed". `.sops.yaml` enrolls `nire-durandal`, `nire-lysithea`,
`nire-tenacity` and `nire-cube` (the last added 2026-08-21 in `9480b06a`) --
all four are live hosts with current config here, so this is the normal case,
not a leftover to prune. `nire-lego` (added 2026-08-14) is not yet enrolled;
if it ends up needing secrets, add its SSH host key converted with
`ssh-to-age` and run `sops updatekeys secrets.yaml`. (`nire-testbed` was the
other unenrolled host until it was removed 2026-08-22, having never needed
secrets.) Read the file rather than this paragraph -- it said "three"
for a day after cube was enrolled.

## State

**`nire-tenacity` booted this config** — 2026-08-10, generation 62, NixOS
26.11, kernel 6.18.43, systemd stage 1. The `/root` rollback ran and was
confirmed by subvolid (607 → 622), not merely by the machine coming up.

**`nire-lysithea` is switched and running this config** — generation 52 as of
2026-08-12, `darwin-system-26.11.15abb8c`.

**`nire-durandal` is switched and running this config too** — generation 222
(`nixos-system-nire-durandal-26.11.20260807.f13ff45`) as of 2026-08-14.
`switch-to-configuration boot` ran 2026-08-13 23:58 EDT (i.e. `just boot`, not
`switch` — it only sets the default for next boot); the machine was rebooted
at 23:59:46, and the journal for that boot confirms the `/root` rollback ran:
subvolume 1426 deleted, a fresh snapshot of `root-blank` created, `/root` now
mounted at subvolid 1431. Same confirmation pattern as tenacity's, found by
reading `journalctl` rather than trusting the mount coming up.

**`nire-cube` has been switched — 2026-08-23**, with the `monitoring`
category (Prometheus + Grafana, see Architecture) live, and `nire-llm-sandbox`
**confirmed booted and staying up as of 2026-08-24**. `grafana.service` took
three rounds to actually land: the first `just switch` with the sandbox VM
wired in failed it on a `secret_key` file-ownership bug
(`/persist/secrets/grafana-secret-key` owned `root:root`, unreadable to the
`grafana` user); a same-day hand fix was believed to have corrected it, but
a live re-check on `ts-cube` 2026-08-24 found it had regressed to the same
`root:root` state and `grafana.service` actively crash-looping
(`start-limit-hit`) on the same permission-denied error. Chowned by hand
again the same day — but a **hand fix regressing once already** was reason
enough not to trust a second hand fix either, so this time the fix went
into the module itself: `grafana-secret-key-setup.service`
(`grafana.nix`), a oneshot ordered before `grafana.service` on every
activation, generates the secret only if missing (never regenerates an
existing one — no official rotation path for `secret_key` as of nixpkgs
26.05, so overwriting would break re-decryption of whatever's already in
Grafana's DB) and unconditionally reasserts ownership/mode. **Confirmed
working end to end, 2026-08-24**: after `just switch` picked up the new
unit (inert until `grafana.service` itself next restarts — adding a
dependency to an already-running unit doesn't retroactively pull in a new
one), `sudo systemctl restart grafana.service` triggered it;
`grafana-secret-key-setup.service` exited `0/SUCCESS`, `grafana.service`
came back `active (running)`, and the secret file's mtime was unchanged
(not regenerated) while ownership was `grafana:grafana`. `grafana.nix`'s
old `warnings` entry describing the manual two-step fix is gone — replaced
by the unit itself, not by trusting a repeat of the same manual step that
already regressed once.
`libvirt-vm-llm-sandbox.service`, separately, took three
runtime-verified fixes to `VMs/_lib/libvirt-vm.nix` across 2026-08-23/24
before it stopped failing — libvirt's default network defined-but-never-
started, a nonexistent `net-list --state-active` flag in the fix for that,
and a missing fixed `<uuid>` in the domain XML that made every `virsh
define` collide with the domain's own prior definition. None of the three
was visible to `nix eval` or a build; all three only showed up against real
`virsh` on the real host. Each was confirmed not to touch durandal
(byte-identical toplevel drvPath) before being applied to cube. Full
diagnosis and fix-by-fix detail: `wiki/open-threads.md`. The guest was
actually running the whole time, including while the systemd unit itself
was failing on fixes two and three — `systemctl status` and `virsh
dominfo` are both now clean.

**A Claude Code session in this repo is not necessarily running on
`nire-lysithea`.** This section was corrected from a session running directly
on `nire-durandal` (`hostname` said so, and the boot evidence above is what
that session found); a later session found itself on `nire-tenacity` instead.
Check `hostname` before assuming which machine you're on.

**`nire-lego` exists in config but has not been built or switched** — added
2026-08-14. Not a blocker and doesn't need raising every session, same as
durandal's status used to read. It does mean a claim verified on one host is
not thereby verified for another: say which host you mean, and treat anything
host-shaped on lego as unanswered.

**`nire-testbed` (ThinkPad X270, added 2026-08-14) was removed 2026-08-22.**
Never built or switched, and nothing about its install was ever run to
completion against the real X270 -- see `claude cave/lessons-learned.md` and
this doc's own git history for what was tried. Removed at Elly's request
rather than left as a permanently-unbuilt host; if a similar Intel workstation
is ever added again, `testbed-configuration.nix`'s last version (git history)
and the `new-host-config` skill's notes on it are the starting point, not a
reason to assume any of this is still wired up.

**`nire-installer` (added 2026-08-15) is not a host awaiting install like
`nire-lego` — it's the mechanism for installing one.** A live-USB
`nixosConfigurations` entry, not a machine, built with `just liveusb` rather
than `just build`/`switch`. Originally built solely to install `nire-testbed`;
generalized 2026-08-22 when that host was removed, so it now installs
whichever host you give it at build time (see Architecture, and
`nireHost/installer/liveusb-installer.md` for the full walkthrough and how
the target host is chosen). Nothing about the install has actually been run
to completion against real hardware since that generalization — the doc says
so itself.

Most of this repo's history predates all of that, written from an
aarch64-darwin laptop against x86_64-linux hosts with no remote builder, where
the only thing that built was `checks.<system>.module-tree`. **Treat an
undated "verified" as *evaluates*.** The first boot found four defects that
evaluation and a successful build both missed (`lessons-learned.md` §25), so a
green `nix flake check` says nothing about behaviour.

Four NixOS *hosts* now: `nire-durandal` (workstation), `nire-tenacity`
(handheld, Jovian/SteamOS), `nire-lego` (Legion Go handheld, added 2026-08-14,
using tenacity's disk layout), and `nire-cube` (GMKtec mini PC, added
2026-08-20) — plus the darwin host, `nire-lysithea`. Two more
`nixosConfigurations` entries exist besides those four but aren't hosts:
`nire-installer` and `nire-llm-sandbox` (see above and Architecture for both).
This paragraph said "five NixOS hosts" (six
counting `nire-testbed`) until 2026-08-22, when testbed was removed; before
that it said "four" until 2026-08-21, when `nire-cube` had already been in
`hosts.nix` for a day; the count below has the standing warning about that.
`durandal`, `tenacity`, and `lego` import the `impermanence` category and wipe
`/root` on boot; `cube` deliberately does not (see Safety). Tenacity was
dropped by the den restructure and brought back from
`origin/backup-before-flake-parts-happened`, the last config it actually ran.

`claude cave/old-2026-08-08-PORT-PLAN-(COMPLETED).md` records the migration off
`vic/den`, where the plan turned out wrong, and what is still open (moved and
`old`-prefixed 2026-08-13; see Docs).

## Commands

`just` recipes live in the root `.justfile` and work from anywhere:

```sh
just check           # nix flake check --all-systems --no-build
just modules         # static module-tree check; the only one that means anything on darwin
just available <pkg> # can it build on aarch64-darwin, and does a cask install it too
just available --duplicates   # only the ones homebrew ALSO installs, and what to do
just fingerprint     # drvPath of the host toplevel
just dotfiles        # every generated dotfile's attribute name
just dotfile ./.zshrc
just diff HEAD~1     # what changed in a host's config, attribute by attribute
just build / boot / switch   # dispatches per host class; `boot` activates nothing until you reboot
just liveusb         # builds the nire-installer live-USB image, prints the dd command (doesn't run it)
```

On the hardware, and read-only:

```sh
just baseline        # what the machine is REALLY running -- capture before switching
just hm-collisions   # which files HM will take over, and whether any would collide
just diff-deployed   # package-level diff, running vs new toplevel; needs `just build` first
just root-drift      # what's on / that no persistence entry covers -- needs sudo
```

`host` derives from `hostname`, falling back to `nire-durandal` off-host. To
override, the assignment goes **before** the recipe name —
`just host=nire-durandal build`. `just build host=…` is not a variant; just
reads it as a second recipe name and errors.

For iterating, evaluate directly from `flake/`:

```sh
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
```

`elly` is literal there on purpose: it reads an *evaluated* config, where the
attribute name is already resolved.

`build`/`boot`/`switch` go through `scripts/rebuild.sh`, which asks the flake
whether the host is a `darwinConfiguration` and calls `nh darwin` or `nh os`
accordingly. **Which machine a given session is running on varies** — check
`hostname` rather than assuming `nire-lysithea`; sessions have also run
directly on `nire-durandal` (linux, not darwin), which is switched and booted
for real now too (see State). Wherever you're on one of the actual hosts,
`just build`/`switch` there is a real test, not just evaluation. From any
machine that is not the target NixOS host itself, a NixOS host still cannot be
built (no remote builder, no binfmt) and `rebuild.sh` says so rather than
failing inside nix.

## Architecture

`flake.nix` is a manifest. `(inputs.import-tree ./modules)` recursively imports
every `.nix` file under `flake/modules/`, and
`flake-parts.flakeModules.modules` declares the `flake.modules.<class>.<name>`
option they all write into.

**Every `.nix` file under `modules/` is a flake-parts module** — its top level is
`{ flake.modules.<class>.<name> = …; }` or similar, never a bare NixOS or Home
Manager module.

### Membership is implicit, and comes from the directory

Each category directory holds a copy of `dirsAsCategory.nix`, which derives the
category name from its own directory, collects the modules beneath it, and
declares one aggregate per class. **A module belongs to the category of the
directory it is filed in.** Adding a module is a one-file change: create the file
in the right place and it is in.

`flake/doc/dirsAsCategory.md` covers the mechanism, what is load-bearing in it,
and the trailhead to per-module opt-in if that is ever wanted. Read it before
changing any `dirsAsCategory.nix`.

Two consequences worth holding onto:

- **A category collects from its *sub*directories only.** A `.nix` file sitting
  directly in a category directory is collected by nothing.
- **Entry points are defined by being outside every category tree.**
  `modules/checks.nix`, `nireHost/hosts.nix`, `nireHost/durandal-configuration.nix`,
  `nireHost/installer/installer-configuration.nix`, and `nireUser/elly-home-manager.nix`
  all sit where `dirsAsCategory` cannot reach them, deliberately. `just modules`
  relies on exactly this rule. The installer one also hardcodes its declared
  name (`installerConfiguration`) instead of deriving it from the filename the
  way every category member does, on the same grounds durandal's does — entry
  points don't follow that pattern.

Areas: `nire/` (shared system, now including a `nire/macos/` subarea for
darwin-specific settings), `nireHost/` (per-host), `nirePackages/`
(packages), `nireUser/` (elly).

**Not every category is imported by every host, and `virtualization` is the
clearest example.** Added 2026-08-21 as `nire/virtualization/`, holding
`libvirt`, `virt-tools`, `vm-networking`, and `libvirt-persist.nix` (added
2026-08-22, persists libvirt's own secrets-encryption key). `nire-durandal`
and `nire-cube` import it (`nire-testbed` did too, before it was removed
2026-08-22); `nire-tenacity` and `nire-lego` — the handhelds, i.e.
the two that import `jovian` — deliberately do not, because libvirtd is a
boot-time daemon and a gamescope handheld will never open virt-manager. It got
its own category for exactly that reason: it started inside `nire/system/`,
which every Linux host imports whole, so there was no way to decline it. **If
something shared needs to be optional, a category is the mechanism; nothing in
this tree declares `mkEnableOption`.** `kde-desktop` is the other shape of the
same idea — a single module imported by name while its category (`desktop-env`,
which also holds `jovian`) is never imported whole.

`nire-cube` alone, via `virtualization-cube.nix` (deliberately not a category
member — see that file's own header), also runs `nire-llm-sandbox`: a
persistent libvirt-managed VM guest sandboxing an LLM coding agent, generated
by `VMs/_lib/libvirt-vm.nix` (added 2026-08-22; see skill `nixos-vm-images`
and `wiki/categories/virtualization.md`). That generator's activation script
also starts libvirt's default NAT network itself when a VM asks for one
(`networked = true`) — libvirt ships that network defined but never started,
a real bug found on `nire-cube`'s first switch with this VM wired in
(2026-08-23), fixed per-VM rather than as a host-wide unit specifically
because a host-wide unit would have changed durandal's behavior too, for a
bug durandal never had. The same generator also takes an optional
`sshForward` parameter (added 2026-08-23) to forward a host port into a VM's
SSH port, restricted by source IP (LAN-or-Tailscale by default, narrowable to
tailnet-only) rather than by interface name — `nire-llm-sandbox` uses it,
tailnet-only, `hostPort = 2222`.

**`monitoring`**, added 2026-08-23 as `nire/monitoring/`, is Prometheus +
Grafana scraping a host's own resource metrics — cube-only so far, same
"category is how something shared stays optional" mechanism as
`virtualization`, except nothing here was ever part of `system` to split out
of; it started as its own category. Everything but Grafana stays on
`127.0.0.1`; Grafana is reachable over Tailscale only, via the same
`trustedInterfaces = [ "tailscale0" ]` firewall rule `system`'s
`tailscale.nix` already sets, not a new mechanism. See
`wiki/categories/monitoring.md`.

**`git-forge`**, added 2026-08-24 as `nire/git-forge/`, is Forgejo, a
self-hosted git forge — cube-only, **confirmed working end to end,
2026-08-24**: `just switch` came up clean (0 failed units),
`forgejo-secrets.service` exited `0/SUCCESS`, `forgejo.service` stayed
`active (running)` past its first 40s, and `http://ts-cube:3001/` answered
`HTTP 200` from another tailnet host. Same tailnet-only mechanism as
Grafana above, on its own port (3001; Grafana already has 3000). Unlike
Grafana, needs no hand-created secret file — `services.forgejo` generates
its own `SECRET_KEY`/`INTERNAL_TOKEN`/`JWT_SECRET` on first activation. The category
is named `git-forge`, not `forgejo`, on purpose: naming both the category
and its one module `forgejo` would repeat the exact
`containers`/`podman.nix` collision two paragraphs below, and did on the
first attempt at writing this — caught by `just modules` before it shipped,
fixed by renaming the category rather than the module. See
`wiki/categories/git-forge.md`.

**`shortlinks`**, added 2026-08-24 as `nire/shortlinks/`, is golink --
Tailscale's `go/foo` shortlink service -- cube-only. **Its first real
switch failed** (generation 13, same day): a missing `AF_NETLINK` in the
module's own `RestrictAddressFamilies`, which Go's netlink interface
enumeration needs, surfacing as `netlinkrib: address family not supported
by protocol` -- a message that names netlink and reads like a kernel
problem, with nothing in it pointing at systemd. It shipped as "evaluates
only" because it was written from a darwin session that can't build an
x86_64-linux toplevel, and it then broke for exactly the reason its own
hardening comment claimed to be avoiding by leaving SystemCallFilter out.
The fix is verified by A/B on the real host; an authenticated node still
needs the one-time login. Named `shortlinks` rather than `golink` for the
same category/module collision reason `git-forge` isn't `forgejo`, and
deliberately not `golinks` either -- one letter off its own module reads
as a typo later. Two things about it are genuinely different from
`monitoring`/`git-forge` and are easy to get wrong by analogy: **there is
no `services.golink` in nixpkgs** (the package exists, the NixOS module
does not, checked against the pinned rev), so this module hand-writes its
own `systemd.services.golink`; and **it is not a service on cube's
network at all** -- golink embeds tsnet, joining the tailnet as its own
separate device named `go`, listening only there. No firewall rule, no
reliance on `trustedInterfaces`, and no dependency on the host's
`tailscaled`. It needs a one-time interactive login on first start
(`journalctl -u golink -f`, open the printed URL) because no `TS_AUTHKEY`
is wired in -- the same call `tailscale.nix` makes for the host daemon,
for the same reason (keys expire). See `wiki/categories/shortlinks.md`.

Related, and a live trap rather than history: containers and VMs are separate
here and the word "virtualization" means only the second.
`nire/containers/podman/podman.nix` is podman and distrobox. It was
`nire/system/virtualization/virtualization.nix` until 2026-08-21, then
`nire/system/containers/containers.nix` until 2026-08-22, when it moved out
of `system` entirely into its own category — same split `virtualization` got
the day before, for the same "if something shared needs to be optional, a
category is the mechanism" reason above, though the option wasn't actually
exercised: all four NixOS hosts import `containers` explicitly now, so
coverage didn't change, only the mechanism did. The file itself got renamed
in the same move, `containers.nix` → `podman.nix` — a category named
`containers` and a module named `containers` would declare the same
`flake.modules.nixos.containers` attribute and silently merge, the exact
near-miss `virtualization`'s own header already warned about, hit for real
this time and caught by `just modules`. A search for any of the old paths or
module names finds nothing, and a memory of "virtualization is the podman
one" is now exactly backwards regardless of which name you're picturing.
This file used to give a declared-class breakdown here (101 homeManager-only,
43 nixos-only, 9 both, one darwin) — it's stale as of 2026-08-15
(`nire/macos/` alone now holds several darwin-touching modules beyond the
`elly-user.nix` example that used to be "the one"), and nothing here derives
it mechanically the way `just modules` derives category membership. Don't
quote old numbers; recount if it matters.

**There are five hosts, not two, and one of them is darwin — plus two more
`nixosConfigurations` entries that aren't hosts at all, for two different
reasons.**
`nireHost/hosts.nix` declares `flake.darwinConfigurations.nire-lysithea`
alongside **six** `nixosConfigurations` — `nire-durandal`, `nire-tenacity`,
`nire-lego` (added 2026-08-14), `nire-cube` (added 2026-08-20),
`nire-installer` (added 2026-08-15), and `nire-llm-sandbox` (added
2026-08-22) — and the `darwin` class is live. Of those six, two aren't
machines anyone owns:

- `nire-installer` — a live-USB image, "not a host anyone switches to or
  boots persistently" per its own header
  (`nireHost/installer/installer-configuration.nix`), built to install
  whichever host you give it at build time. No `elly` user, no impermanence,
  no persistent state; `just liveusb` builds it rather than
  `just build`/`switch`.
- `nire-llm-sandbox` — also builds an image rather than being switched to,
  but unlike the installer this one is meant to run *persistently* once
  started, as a libvirt-managed VM guest on `nire-cube` (see the
  `virtualization` note above, and `wiki/hosts.md`).

Don't count either as a real host, but don't forget them either — `hosts.nix`
comments each with the reasoning above, right at the declaration. This file
claimed only two hosts total until 2026-08-12, then three until 2026-08-15,
then four real hosts (five `nixosConfigurations`) same day, then five (six)
on 2026-08-21 when `nire-testbed` was still around, then back to four real
hosts (five `nixosConfigurations`) on 2026-08-22 when `nire-testbed` was
removed, then (same day) six `nixosConfigurations` once more when
`nire-llm-sandbox` was added — still four real hosts throughout that last
change, only the non-host count moved. Check `hosts.nix` directly before
stating a count of anything; it has changed six times already and will
again — and it was stale for a day each of two of those times, so a count in
prose here is a claim about when someone last looked, not about the tree.

### Home Manager is NixOS-integrated

`home-manager.users.elly` is set from the NixOS side with `useGlobalPkgs` and
`useUserPackages`, in `nire/system/home-manager/enable-home-manager.nix`. There
is no `homeConfigurations` output and no separate home switch; `just switch`
applies both. `flake/doc/trailhead-home-manager-standalone.md` is the way back.

- HM **rejects** `nixpkgs.*` options under `useGlobalPkgs` — errors, not ignores.
  `allowUnfree` comes from the system side of `basic-nix-settings.nix`.
- `home.profileDirectory` is `/etc/profiles/per-user/elly`, not `~/.nix-profile`.
- Activation runs as a systemd unit, so its `PATH` is only
  coreutils/findutils/gnugrep/gnused/systemd.

### Platform support is derived; Homebrew overlap is not

`ellyHomeManager` is shared verbatim by all five hosts, including
`nire-lysithea` (aarch64-darwin), so everything in it has to survive darwin.
Two different questions come up when adding a package — can nixpkgs build it
on darwin (answered automatically, don't hand-restate `meta.platforms`), and
does Homebrew already install it (never answered automatically, and easy to
mistake for the first question when reading an `isDarwin` guard). Full detail,
worked examples (`vicinae.nix`, `obsidian.nix`), and the `just available
--duplicates` workflow: skill `nirepackages-platform-support`.

## Traps, all of which have actually happened here

As of 2026-08-15, most of these moved out to skills that load only when the
matching task comes up, rather than costing context on every session
regardless of what it's doing. What follows are the short versions — the
skills have the full mechanism, code, and worked examples; read the skill
before doing the matching task rather than re-deriving from these one-liners.

### Writing or renaming a flake-parts module — skill `new-flake-module`

`flake.modules` cannot live inside `perSystem` (no `<system>` axis, no
`freeformType` there — this is what 151 files got wrong in the original
port). A module's declared name comes from its own filename, so a rename
silently drops it from its category if the two disagree afterward. Hyphens
are legal in Nix identifiers (`kde-base` is one token, not `kde` minus
`base`) — a regex over module names that doesn't account for that will
misparse them. Two modules sharing a name **merge** rather than conflict
(`just modules` catches this). Every module has an outer flake-parts
`config` and an inner NixOS/HM `config` that shadow each other. Module
classes (`nixos`, `homeManager`, `darwin`, ...) aren't validated at
declaration time — a wrong one fails much later, at the import site. Raw
`nixos-generate-config` output needs wrapping before it can live under
`modules/`, or evaluation dies with a misleading `infinite recursion` error
naming `modulesPath`.

### Editing Home Manager shell/dotfile modules — skill `home-manager-dotfiles`

`home.file.<n>.text` and `home.sessionPath` both concatenate across modules
rather than override — two modules writing the "same" file or PATH entry
double it, silently. Reading a generated dotfile back is full of false
negatives: a wrong attribute name returns empty rather than erroring, and
some entries (`.bashrc`) have no `.text` at all, only `.source`. Home
Manager's shell rc ordering (`mkBefore` → `mkOrder 550` →
`programs.zsh.plugins` → unordered) means anything that must run after a
plugin can't sit at 550 — this silently orphaned a hand-written `starship
init` and a 1,659-line p10k config.

### Editing impermanence or initrd — skill `impermanence-initrd`

**Read `WARN-impermanence.nix` before changing anything near this
regardless.** In the scripted stage-1 hooks this repo still uses, `@name@`
inside a hook string — even inside what looks like a comment — is a live
template placeholder substituted later in the same fixed pass, so naming one
in a comment can paste a whole other script in and execute most of it. Also:
the shell's own view of the machine (`lsblk`, `findmnt`, `/etc`) is scoped
to its mount namespace, not the host's, and can describe a completely
different, wrong-looking disk layout that is nonetheless correct — use
`/proc/1/mountinfo`, `/dev/disk/by-uuid/`, and `/run/current-system` instead,
all unprivileged.

### Adding or platform-gating a package — skill `nirepackages-platform-support`

Two different questions, easy to conflate because both show up as an
`isDarwin` guard in a package module: can nixpkgs build it on darwin at
all (answered automatically by `drop-unsupported-packages.nix` off
`meta.platforms` — don't hand-restate it with `lib.mkIf
(!pkgs.stdenv.isDarwin)`), versus does Homebrew already install it on
lysithea, meaning this module should defer rather than double-install
(never answered automatically — `just available --duplicates` finds the
overlap, but which one wins is still a judgement call per app).
`obsidian.nix` is the worked example for the second question.

### Debugging "can't reach a host by tailscale name" — wiki `system.md`

Two traps, neither a bug in this repo's nix config: this tailnet's device
names don't match `networking.hostName` (`nire-cube` the host is `ts-cube`
on the tailnet, fleet-wide), and a tailnet ACL can silently block all
peer-to-peer traffic while every local firewall setting is correct and
`tailscale ping`/PeerAPI still work -- that one's fixed in Tailscale's admin
console, not in this repo. Full mechanism and the read-the-firewall-script-
without-root trick: `networking/tailscale.nix`'s own header, indexed at
`wiki/categories/system.md`'s "Tailscale" section.

### `${...}` inside a Nix `''` string is interpolation

Writing `${terminfo[khome]}` in what you intend as a comment is an evaluation
error. Escape as `''${...}` or reword. Small and general enough (any `''`
string, not one kind of module) that it stays inline here rather than in a
skill.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked files, so
a new module silently does not exist.

**Read upstream source rather than guessing at options.** It settled, during the
port, that `perSystem` has no `freeformType`, that `home.sessionPath` is
`listOf str`, and that Home Manager has no blesh module at all — so
`programs.bash.blesh.enable = true` had been doing nothing. For third-party
packages, check the project's own current source too: `handheld-daemon` got a
bespoke compatibility shim for something upstream had already fixed.

**Verify refactors by fingerprint, but not only by fingerprint.** A differing
hash does not prove breakage — reordering imports permutes
`environment.systemPackages` — so compare values with `just diff`, not just the
hash.

**A drvPath moving after a docs-only edit is `nire-installer`, and is
expected.** `nireHost/installer/installer-configuration.nix` sets
`environment.etc."nixos-configs".source = inputs.self`, so the image embeds this
whole flake — which makes its toplevel depend on *every tracked file*,
`CLAUDE.md` and `.claude/` included. Editing only markdown moves that one drv
and no other. Don't go looking for a config change that isn't there; check
whether the host that moved is the installer first.

**Bugs here serialize.** Evaluating a cheap attribute proves nothing;
`networking.hostName` resolved happily while four separate things were broken.
Force a toplevel. And note that evaluating and building both stop short of the
defects that only appear at runtime — `lessons-learned.md` §25.

**Ask "did it work before?" first.** These machines keep journals across boots,
so `journalctl --list-boots` plus a grep settles whether something is a
regression faster than any argument about mechanism.

**Calibrate severity.** Homelab, not production; the repo has gone six months
between commits. "This is broken and here is the fix" beats incident-report
framing.

**"push" means the `ship` skill, not `git push origin main`.** Branch, PR, ask
before merging, ask again before deleting the branch — two confirmations, not
one. Only for work headed to `main` — pushing a topic branch is just a push.
The skill has the flow and why.

**Never file anything outside `NireBryce/nixos-configs` — an issue or PR on
nixpkgs, ble.sh, carapace, any other project — without Elly saying so
explicitly, in those words, unprompted.** Asking and getting a yes does not
clear this: a yes to a bundled "ok to do these four things" does not cover
an upstream filing folded into it, even if upstream filing was one of the
four and nothing was hidden. It has to be Elly raising it, not a box
checked on the way to approving something else. `propose-issue` already
only ever files in this repo (`gh issue create --repo
NireBryce/nixos-configs`) and `bugs pending submission/` plus
`wiki/open-threads.md`'s "Pending upstream bug reports" are deliberately
drafts nothing works through automatically — this rule is what keeps that
true rather than something an efficient-looking bundled plan quietly
crosses. Written 2026-08-24: a same-repo issue got filed under a bundled
"ok to do these four things" approval, upstream filing was never actually
proposed in it, and Elly still stepped in ahead of time to draw this
boundary explicitly rather than leave it to be inferred from that. Treat
the boundary as this deliberate, not as something a careful-enough bundled
ask would have covered on its own; see `claude cave/lessons-learned.md`
#39.

**Filing in this repo can still reach another project's repo by accident, through GitHub's own
autolinking — not just through `gh issue create --repo <other>`.** A title
or body containing `owner/repo#123` (an actual org/repo name immediately
followed by `#` and a number) gets cross-referenced by GitHub automatically,
which notifies that other repo — a real ping, even though nothing was
filed there. Plain prose naming a project — "ble.sh", "carapace",
"ble.sh/carapace", even "akinomyoga/ble.sh" with no trailing `#number` —
does not trigger this; GitHub needs the `#number` to treat it as a
cross-reference rather than text. Checked 2026-08-24 across issues #72–76:
none contained the `owner/repo#number` shape, confirmed by grepping every
title and body for it rather than assuming from how they read. Do the same
grep before naming a specific upstream issue/PR number in anything filed
here.

## Conventions

**Read `claude cave/claude-style-guide.md` before writing a new module.** Formatting
here is deliberate: the aligned-`=` columns are intentional and `nix fmt` is
deliberately not wired up, because it would flatten them. Module bodies sit one
level deeper than they need to, left over from unwrapping `perSystem`;
reindenting would risk the `''` strings in the shell modules.

**Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`, with no
model name.** Not `Claude Opus 5`, not `Claude Sonnet 5`, whatever your system
prompt tells you to write. The log currently holds 82 `Sonnet 5` and 54
`Opus 5` trailers and Elly reports the label has been wrong — which is
unsurprising, because **an agent cannot verify which model is executing it.**
The name is copied from the system prompt; if that is stale or generic, the
commit records a confident claim about something the author had no way to
check. Dropping the model leaves the trailer true. Existing commits keep their
labels; rewriting merged history to fix a trailer is not worth a force-push.

**Namespacing.** `nire` unless it needs a more specific tag; `nireHost`,
`nireUser`, `nirePackages` otherwise.

**When a rename makes the old name ungreppable, say what it was** on the
declaration — see `boot-durandal.nix`, `enable-home-manager.nix`.

**A bug recorded in a comment stays in the file.** Nobody reads `git log`; the
comment is what the next person editing the code sees, and several of these
recur. Do not trim one because the fix landed.

If a later change strands a comment — the code it described is gone, or the name
it explained has changed — **move it to a `history` heading at the bottom rather
than deleting it**, and expand it enough to stand alone. It has lost the context
that made it terse, so it needs to say more, not less. `boot-durandal.nix`,
`WARN-impermanence.nix` and `vscode.nix` have them.

**`elly` is hardcoded**, in `users.users.elly`, `home.username` and
`home-manager.users.elly`. The sibling branch has `nire.primaryUser`;
introducing it here is a separate change, not a tidy-up.

**Check for an existing `programs.*` integration before hand-writing one.**

**Don't bury Python inside a bash script.** Bash is fine, and most of
`flake/scripts/` is bash. But `python3 -c '...'` heredocs inside it are
not: the Python is a quoted string as far as every editor is concerned, so it
gets no syntax highlighting, no linting, and no indentation help — which is
exactly when quoting bugs stop being visible. Two ways out, by proportion:

- **A little Python in an otherwise-shell script** — put it in
  `flake/scripts/util/` as a real `.py` file and call it.
- **Mostly Python** — write the whole thing in Python. `modules.py` is the
  precedent, and the trigger is the same one the `.justfile` header uses for
  shell: data structures, parsing, or anything with a reason worth explaining.

This was written after a package-availability checker went out as bash
wrapping Nix wrapping inline Python, and shipped both bugs the shape invites —
env vars passed where `argv` was read, and a mangled line nothing highlighted.

## Docs

- `wiki/README.md` — a topic index over everything below (and a few things
  not listed below), for finding the right doc without already knowing its
  path. Links out to these files rather than restating them; it isn't a
  replacement for reading this file. **Maintained the same way this file
  is**: whichever session's change makes a wiki page stale (a category's
  members, its host-import list, a fact a page states) corrects that page in
  the same change, not as a follow-up. `new-flake-module` and
  `new-host-config` name the specific pages each one tends to affect.
- `claude cave/old-2026-08-08-PORT-PLAN-(COMPLETED).md` — the migration off
  den: what was done, where the plan was wrong, and what is still open. Moved
  and `old-`-prefixed 2026-08-13; was at the repo root as
  `2026-08-08-PORT-PLAN-(COMPLETED).md` until then.
- `claude cave/old-historical-2026-08-11-HANDOFF-durandal-and-lysithea.md` —
  what tenacity's first boot bought the other two hosts, written when durandal
  hadn't booted this config and lysithea didn't exist in it yet. Both of those
  have since happened (see State) — read this one as history, not current
  status. Moved and prefixed 2026-08-13; was
  `2026-08-11-HANDOFF-durandal-and-lysithea.md` at the repo root until then.
- `flake/doc/dirsAsCategory.md` — the category mechanism and its trailhead.
- `nireHost/installer/liveusb-installer.md` — building the `nire-installer`
  live-USB image and the full walkthrough for installing a target host with
  it, step by step. Originally written for `nire-testbed` alone; generalized
  2026-08-22 when that host was removed, so the target host and its
  partition UUIDs are now chosen at build time. Nothing in it has been run
  against real hardware since that generalization — read step 3 (partition
  layout) skeptically first.
- `flake/doc/disko-impermanence-layout.md` — the reusable disko generator for
  the LUKS + btrfs + impermanence layout durandal and tenacity already run by
  hand; the template to reach for if cube's install ever adopts impermanence
  instead of the plain persistent root it has now.
- `claude cave/lessons-learned-impermanence-stage1-migration.md` — the root rollback's move from scripted
  stage 1 to a systemd-initrd unit, done 2026-08-10 because the 2026-08-07
  nixpkgs flipped `boot.initrd.systemd.enable` to default true. Evaluates, never
  booted. Read before touching anything in initrd.
- `claude cave/lessons-learned.md` — how the work went wrong in the doing: tools that
  reported success while being wrong, traps that were documented and hit anyway,
  and which questions were settled by reading source. §§1–18 are the port,
  §§19–24 the first session on the hardware, §§25–31 after it booted, §§32–40
  later work on booted or newly-added hosts. §32 (an auto-allocator cannot see
  manually pinned ranges, and a working host can be working on state a fresh
  one lacks), §33 (a removed nixpkgs option asserts rather than being
  ignored; `virtualisation.*` churns and the wiki is stale), §34 (a module
  name that collides with its own category *merges*, and the merge is
  invisible when both halves do the same thing) and §35 (the identical
  collision a third time, caught only because `just modules` was actually
  run) all came out of the virtualization work. §36 (a well-typed value can
  still be semantically wrong; build the artifact and read it, don't stop at
  evaluation), §37 (some bugs need real filesystem/daemon state that exists
  only once a real `switch` runs — a service's own runtime UID, a network
  daemon's runtime state — invisible to evaluation *and* to reading back a
  built artifact) and §38 (a fix scoped to the caller that actually needs it
  beats a general one; asking "does this affect a host that never asked"
  caught the wrong mechanism before it was written) came out of `nire-cube`'s
  `nire-llm-sandbox` VM and its `monitoring` category, 2026-08-22/23. §39 (a
  live-typing bug needs a live pty repro, not `ssh host 'cmd'`; and the
  newest, explicitly-unverified file is a suspect, not automatically the
  culprit) is the ble.sh/carapace completion bug reported on `nire-cube`
  2026-08-24 — diagnosed, fixed
  (`carapace-completer-read-fix.bash`), and as of the same day confirmed
  through a real `just switch` on `nire-cube` (generation 10) and
  re-verified live: repeated repro attempts, zero errors, where each
  reliably errored before. §40 (a failed systemd unit doesn't
  mean the resource it manages is down; check that resource itself, not
  just the unit) is `nire-llm-sandbox`'s first real end-to-end test on
  `nire-cube`, 2026-08-23/24 — three runtime-only bugs in a row in
  `VMs/_lib/libvirt-vm.nix` (default network never started; the fix for
  that using a nonexistent `virsh` flag; a missing fixed domain UUID making
  every redefine collide with the last), during which the guest itself was
  running the whole time even while the unit kept reporting failed. Now
  confirmed clean end to end; see State and `wiki/open-threads.md`.
- `flake/doc/trailhead-home-manager-standalone.md` — reversing the HM decision, and the
  part of the cutover that is one-way on the machine rather than in the repo.
- `git show origin/flake-parts:SESSION-HANDOFF.md` — the sibling branch's notes
  on dead ends and decisions that should not be silently relitigated. Needs the
  `origin/` prefix — there is no local `flake-parts` branch in a normal
  checkout of this repo, only `origin/flake-parts`, and the bare name 404s.
- `git show origin/flake-parts:linux-flake/flake-parts-reference.md` —
  flake-parts machinery, with upstream source backing each claim. That branch
  never went through the `linux-flake/` → `flake/` rename this one did
  (2026-08-14), so the old path is still correct *there*.
