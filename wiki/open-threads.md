# Open threads

Todos, half-formed ideas, and things-to-look-into notes left in various
corners of the tree, plus upstream bugs found here but not yet filed. None
of this is acted on just by being listed here — this page exists so these
don't have to be rediscovered by grepping the whole tree.

**Before starting work on any of these, or investigating a symptom that
might already be one of them: `gh issue list --search "<keywords>"` in
addition to grepping this page.** As of 2026-08-24 this repo actually files
GitHub issues (see below) rather than leaving everything here as prose —
started specifically because the ble.sh/carapace bug below had already been
independently rediscovered once, at real cost, before it was tracked this
way. `bugs pending submission/` (next section) is still the write-up stage
for a bug against a *third-party* project, before it's filed there; this
repo's own tracker is the issue queue, not another markdown list.

## Tracked as GitHub issues

- **[#72 — ble.sh + carapace: spurious `read: `': not a valid identifier` on
  Tab / auto-complete](https://github.com/NireBryce/nixos-configs/issues/72)**
  — a local workaround is in the tree, not yet confirmed with a real
  `just switch`. Full diagnosis: [blesh.md](categories/shell-config/blesh.md).

## Pending upstream bug reports

`bugs pending submission/` — written up, not yet filed against the
third-party project itself, and **not filed by anyone here on their own
initiative**: per `CLAUDE.md`, filing outside `NireBryce/nixos-configs`
happens only when Elly says so explicitly, in those words, for that
specific report — not as a housekeeping pass over this list:

- **[nixpkgs: vscode ≥ 1.129 patches the wrong ripgrep on Linux](<../bugs pending submission/2026-08-11-bugreport-nixpkgs-vscode-ripgrep.md>)**
  (2026-08-11, still present on nixpkgs `master` as of that date).
- **[amd-s2idle: hardware sleep residency reported 100× too high](<../bugs pending submission/2026-08-12-bugreport-amd-s2idle-residency-percent.md>)**
  (2026-08-12, against `amd-debug-tools` 0.2.20).
- **[Jovian-NixOS: `amd_iommu=off` blocks s0i3 on non-Deck handhelds with an NPU](<../bugs pending submission/2026-08-12-bugreport-jovian-amd-iommu-s0i3.md>)**
  (2026-08-12, found on a GPD G1617-02-L).
- **[nix-darwin: `homebrew.onActivation.cleanup` requires Homebrew ≥ 6.0, with no version check or error naming it](<../bugs pending submission/2026-08-13-bugreport-nix-darwin-homebrew-force-cleanup.md>)**
  (2026-08-13).

## Todos and ideas left next to the code

- **[`../flake/modules/nire/hardware/todo.md`](<../flake/modules/nire/hardware/todo.md>)**
  — eventually give the overarching `dirsAsCategory` mechanism flags so it
  can auto-import based on system type.
- **[`../flake/modules/nirePackages/idea.md`](<../flake/modules/nirePackages/idea.md>)**
  — consider migrating more unconfigured packages from Home Manager to
  plain `nix`. Also noted on [architecture.md](architecture.md).
- **[`../flake/scripts/mkPkgModule.md`](<../flake/scripts/mkPkgModule.md>)**
  — a ready-but-unused generator for the ~70 single-package module files
  under `nirePackages/`; a trailhead with the adoption cost spelled out, not
  a plan anyone's committed to. Also on [architecture.md](architecture.md).
- **[`../flake/scripts/script-wishlist.md`](<../flake/scripts/script-wishlist.md>)**
  — bare headings only (`vicinae`, `just`, `espanso`, `other`), no content
  yet. A placeholder for future script ideas, not current work.
- **[`../claude cave/2026-08-09 things to look into eventually.md`](<../claude cave/2026-08-09 things to look into eventually.md>)**
  — a security-hardening reference link, plus two questions rescued from a
  deleted handoff doc (are `logitech-g600`/`zsa-moonlander` peripheral
  modules still wanted on a handheld; is full desktop package parity still
  wanted on tenacity). Neither has been decided.
- **[`../flake/doc/notes-and-fixes.md`](<../flake/doc/notes-and-fixes.md>)**
  ends with a "things to look into" list — MyNixOS, nixpkgs-wayland,
  nix-direnv, haumea, flakelight, flake-utils(-plus), devshell, devbox,
  devenv, nixos-shell, nix-index, nix-prefetch — and an unanswered "learn
  what `outputs @ inputs:` means and figure out specialArgs" note. Also
  covered from the fix-snippet angle on [conventions.md](conventions.md).
- **`nire-llm-sandbox` boots and stays up on `nire-cube`, confirmed
  2026-08-24** — added 2026-08-22 (see [hosts.md](hosts.md) and
  [categories/virtualization.md](categories/virtualization.md)). Took three
  runtime-verified fixes to `VMs/_lib/libvirt-vm.nix` across 2026-08-23/24,
  all against real `virsh` behaviour on `nire-cube`, none caught by `nix
  eval` or a build: (1) libvirt's default NAT network is defined but never
  started, so `virsh start` failed outright until the activation script
  started it itself; (2) the fix for that used a `net-list --state-active`
  flag that doesn't exist on virsh 12.4.0, so the check errored and fell
  through to an unconditional `net-start`, which then failed with "network
  is already active" on every activation after the first -- plain `net-list
  --name` already lists active-only networks by default, no flag needed;
  (3) `domainXml` had no `<uuid>`, so `virsh define` generated a fresh
  random UUID on every parse and collided with the domain already
  registered under the UUID from the first successful define -- fixed by
  giving the generator a required `uuid` parameter, and for `llm-sandbox`
  adopting the UUID libvirt had already assigned the (already-running)
  guest rather than picking a new one. Each fix was confirmed not to touch
  durandal's toplevel (byte-identical drvPath) before being applied on
  cube. `systemctl status libvirt-vm-llm-sandbox.service` is `active
  (exited)` / exit 0, and `virsh dominfo llm-sandbox` shows the domain
  `running` with CPU time climbing across the fixes -- it was up the whole
  time even while the systemd unit itself was failing on (2) and (3).

## Not covered here

`ignore/` at the repo root and `flake/!IGNORE-maybe-useful-chunks/` hold
retired experiments — old library helpers that didn't pan out
(`extendLib.nix`, `findAspectUp.nix`, `findNamespaceUp.nix`,
`recursively-collect-dirnames.nix`, each with its own README noting why it
didn't work). The 2026-08-22 boy-scout cleanup dropped most of `ignore/`'s
cruft and salvaged the one useful thing in it — `root-drift.sh` — out to
`flake/scripts/root-drift.sh`, wired to `just root-drift` (see
[conventions.md](conventions.md)); see recent git history for that commit.
Treat anything still under an `ignore`/`IGNORE`-prefixed path as exactly
that; it's not indexed here on purpose.
