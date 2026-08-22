---
name: new-host-config
description: Adding a new machine (nixosConfigurations or darwinConfigurations entry) to this repo, or copying an existing host's config as the starting point for one. Use before creating a nireHost/<name>-configuration.nix, a nireHost/<name>/ directory, or editing hosts.nix to register a host -- covers which category imports a new host actually wants, real hardware vs. not-yet-installed hardware, and what NOT to copy from the host you're basing it on.
---

# Adding a new host

Every host is two things: an entry-point file directly under `nireHost/`
(`<name>-configuration.nix`, outside every category tree on purpose — see
`new-flake-module`'s skill for why that placement matters) and a `nireHost/<name>/`
directory holding that host's own hardware/boot/platform modules, collected by
its own `dirsAsCategory.nix` copy. `nire-durandal`, `nire-tenacity`,
`nire-lego`, `nire-cube`, `nire-installer`, and `nire-lysithea` (darwin) are
the worked examples — read the one closest in shape to what you're adding
before inventing anything.

## Decide the shape before copying a file

These are independent axes; check `hosts.nix` for the current roster rather
than assuming a count, per `CLAUDE.md`'s own standing warning that it changes.

- **Workstation or handheld?** Workstation (durandal, now cube) takes
  `kde-desktop` alone. Handheld (tenacity, lego) takes the `jovian` module
  instead, for the built-in-controller/SteamOS-session shape — `desktop-env`
  as a whole holds both `kde-desktop` and `jovian`, so import the specific one
  your host wants, not the category.
- **Impermanence or not?** Default yes (durandal, tenacity, and lego all wipe
  `/root` on boot) — but `nire-cube` deliberately opts out because it hits
  persistence assumptions the others don't (its real install turned out to be
  a plain root, not LUKS+impermanence). Read `WARN-impermanence.nix` and the
  `impermanence-initrd` skill before deciding either way, and if you opt out,
  say so explicitly in the host file's header the way `cube-configuration.nix`
  does, including the `invariants.nix` interaction. (`nire-testbed`, removed
  2026-08-22, was the earlier example of this — an Intel host that opted out
  the same way, for the same reason.)
- **Which CPU/GPU category?** AMD hosts (durandal, lego, and cube) import the
  shared `hardware` category (`amdcpu`, `amdgpu`) directly. **Do not add an
  `intel` sibling under `nire/hardware/` to make an Intel host fit the same
  shape** — `dirsAsCategory` recurses into subdirectories, so anything filed
  there would start applying to the AMD hosts too. An Intel host should skip
  `hardware` entirely and instead pull a `nixos-hardware` module scoped to the
  exact machine (e.g. `lenovo-thinkpad-x270`) from inside its own
  `<name>/hardware/hardware-<name>.nix` — `nire-testbed` did exactly this
  before it was removed; there is no live Intel host to point at as a worked
  example right now, so re-derive from that shape rather than nixos-hardware's
  own docs alone.
- **NixOS or darwin?** `mkHost`/`mkDarwinHost` in `hosts.nix` are the two
  entry points; darwin hosts have no `elly-user`, no impermanence, and take
  `flake.darwinConfigurations` instead of `flake.nixosConfigurations`.
  `nire-lysithea` is the only current example.

## Real hardware, or not installed yet?

This is the fork that matters most and is easy to get backwards.

**Hardware already exists and has been scanned** (`nixos-generate-config` run
against a real partitioned disk): capture its `fileSystems`/`boot.initrd.*`
block into `<name>/hardware/hardware-<name>.nix`, wrapped as a flake-parts
module. Dropping the raw generated file under `modules/` as-is makes
flake-parts resolve `modulesPath` through its own `_module.args` and die with
a misleading `infinite recursion` error — `new-flake-module`'s skill has the
wrapping shape and a second worked example (`installer-configuration.nix`).
`durandal/hardware/hardware-configuration.nix` and
`cube/hardware/hardware-cube.nix` are the two real ones in this repo;
hardware-cube.nix's own history note documents what it replaced (a disko
template pointed at a placeholder device, from when cube hadn't been
installed yet) and why that file was deleted rather than pointed at a real
device once the actual install turned out different — worth reading before
deciding a placeholder here is harmless.

**Hardware doesn't exist yet, or hasn't been partitioned** (this is the
common case for a newly-added host — check `CLAUDE.md`'s State section for
whether the machine has actually booted this config): use the disko
generator instead of inventing a `hardware-configuration.nix`.
`nire/impermanence/_disko/impermanence-luks-btrfs.nix`
(`flake/doc/disko-impermanence-layout.md` explains it) reproduces the LUKS +
btrfs + impermanence layout durandal and tenacity run by hand, curried over
`device`, `includeSecureboot`, and `swapSize`. `lego/hardware/disko-lego.nix`
and `cube/hardware/disko-cube.nix` are the worked examples. Two rules that
are easy to get backwards here:

- **The placeholder device path must be unmistakably fake**
  (`/dev/disk/by-id/REPLACE-ME-before-running-disko`), never a
  plausible-looking one like `/dev/nvme0n1`. That path exists on real
  machines in this repo already (tenacity) — a plausible guess run
  through disko's actual partitioning step on the wrong box would silently
  wipe a disk that has real data on it. A path that doesn't exist just fails
  loudly, which is the point.
- **`includeSecureboot`/`swapSize` are per-host judgement calls, not
  defaults to leave alone.** They default off/null because they're
  durandal's own addition, not universal. If the host you're basing this on
  has them (durandal does), decide whether the new host should too and set
  them explicitly, with a one-line reason — don't silently inherit or
  silently drop.

Either way, if the host imports `impermanence`, its rollback
(`WARN-impermanence.nix`) depends on a `root-blank` subvolume existing at the
btrfs top level — the disko template creates it, unmounted, but only once
disko is actually run against the real disk. A host can be fully wired up in
this repo and still be unable to boot before that happens; say so in the
host's own header, the way `lego-configuration.nix` and
`cube-configuration.nix` do.

## Naming: suffix anything host-specific

A module's declared name is its filename (`new-flake-module` skill), and
names in the same class **merge** rather than conflict. Every host-specific
file under `<name>/` needs its own host suffix — `hardware-cube.nix`,
`disko-lego.nix`, `boot-cube.nix` — precisely so a
second host's `boot-<name>.nix` doesn't merge into the first's. (Durandal's
own `hardware-configuration.nix` and `nixpkgs-hostPlatform-durandal.nix`
predate full consistency on this — the first is unsuffixed and gets away
with it only because no other host is named `configuration`. Don't repeat
that gap in something new; suffix everything.)

## `system.stateVersion`: don't copy the value, copy the reasoning

`stateVersion` pins option defaults to whatever release a host's data was
*first created under*, and is never bumped after the fact — it is not "what
release do we run now." A host with no data yet (newly added, not installed)
starts on the **current** release nixpkgs is actually pinned to, not on
durandal's `23.11` or tenacity's `25.05`. Check the current pin with:

```sh
nix eval --raw .#nixosConfigurations.nire-tenacity.config.system.nixos.release
```

`lego`'s state-version file explains this inline — copy the reasoning
comment, not just the string.

## Don't copy host-specific fixes without re-diagnosing

A fix keyed to specific hardware (PCI vendor/device IDs, a board revision, a
panel quirk) belongs to the machine it was diagnosed on, not to "the config."
`durandal/fixes/b550-suspend-fix.nix` clears PCI wakeup on two IDs specific to
a Gigabyte B550M board — copying it to a new host with different silicon is
superstition, not config, even if the new host is also AMD. Carry over
*generic* pieces (the shared `hardware` category, `boot-<name>.nix`'s
systemd-boot/sbctl shape) and leave hardware-keyed fixes behind unless you've
actually confirmed the new machine has the same bug. Say so in the new host's
header either way — `cube-configuration.nix` is the worked example of
recording a deliberate omission.

## Wiring it in

1. Write `nireHost/<name>-configuration.nix` — imports list plus
   `networking.hostName`, mirroring the shape decisions above.
2. Add `nireHost/<name>/` with its own `dirsAsCategory.nix` (copy verbatim —
   it derives everything from its own directory) and whatever
   `configuration/`, `hardware/`, `fixes/` subdirectories the host needs.
3. Register it in `hosts.nix`: add a line to `flake.nixosConfigurations` (via
   `mkHost`) or `flake.darwinConfigurations` (via `mkDarwinHost`), pointing at
   `config.flake.modules.nixos.<name>Configuration`.
4. If the host will ever need secrets: it is not auto-enrolled.
   `.sops.yaml` only lists hosts that actually need `secrets.yaml` — add the
   new host's SSH host key (converted with `ssh-to-age`) and run `sops
   updatekeys secrets.yaml` when that need actually arises, not preemptively.
5. Consider whether `CLAUDE.md`'s Architecture/State sections need a line —
   they've needed one every time a host was added so far, and they say so.

## Verifying

**`git add` before evaluating anything.** Flakes in a git repo ignore
untracked files, so a brand-new module tree silently doesn't exist until it's
staged.

```sh
git add -A flake/modules/nireHost/<name> flake/modules/nireHost/<name>-configuration.nix flake/modules/nireHost/hosts.nix
just modules      # category-membership check; catches name collisions
cd flake && nix eval --raw .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath
```

The last command is the one that matters — per `CLAUDE.md`, cheap attributes
(`networking.hostName`) can resolve fine while something else is broken, so
force a real toplevel rather than trusting a narrower eval. `just check` also
works but currently fails on an unrelated pre-existing `flake-parts` formatter
heuristic on this repo's `main` — confirm with `git stash` before treating
that failure as something the new host caused.

None of this proves the host boots. Say "evaluates" in whatever you write up,
not "verified" or "works" — the first real boot in this repo's history found
four defects that a green eval and a successful build both missed.
