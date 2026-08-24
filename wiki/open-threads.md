# Open threads

Todos, half-formed ideas, and things-to-look-into notes left in various
corners of the tree, plus upstream bugs found here but not yet filed. None
of this is acted on just by being listed here — this page exists so these
don't have to be rediscovered by grepping the whole tree.

## Pending upstream bug reports

`bugs pending submission/` — written up, not yet filed:

- **[nixpkgs: vscode ≥ 1.129 patches the wrong ripgrep on Linux](<../bugs pending submission/2026-08-11-bugreport-nixpkgs-vscode-ripgrep.md>)**
  (2026-08-11, still present on nixpkgs `master` as of that date).
- **[amd-s2idle: hardware sleep residency reported 100× too high](<../bugs pending submission/2026-08-12-bugreport-amd-s2idle-residency-percent.md>)**
  (2026-08-12, against `amd-debug-tools` 0.2.20).
- **[Jovian-NixOS: `amd_iommu=off` blocks s0i3 on non-Deck handhelds with an NPU](<../bugs pending submission/2026-08-12-bugreport-jovian-amd-iommu-s0i3.md>)**
  (2026-08-12, found on a GPD G1617-02-L).
- **[nix-darwin: `homebrew.onActivation.cleanup` requires Homebrew ≥ 6.0, with no version check or error naming it](<../bugs pending submission/2026-08-13-bugreport-nix-darwin-homebrew-force-cleanup.md>)**
  (2026-08-13).
- **ble.sh: spurious `read: `': not a valid identifier` on Tab / auto-complete
  when carapace is the active completer** — found 2026-08-22, not yet
  written up for submission. Reproduces in a minimal ble.sh+carapace config,
  unrelated to anything in this repo. Traced as far as ble.sh's global
  `read` override intercepting reads inside carapace's progcomp-invoked
  `_carapace_completer`, but not pinned to one statement; cosmetic only.
  Full diagnosis: [blesh.md](categories/shell-config/blesh.md).

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
- **`nire-llm-sandbox` still isn't confirmed to boot** — added 2026-08-22
  (see [hosts.md](hosts.md) and
  [categories/virtualization.md](categories/virtualization.md)). `nire-cube`'s
  first real `just switch` with it wired in (2026-08-23) got as far as
  `virsh define` succeeding and then failed to start the domain — libvirt's
  default network was defined but never started, a real bug, fixed the same
  day in `VMs/_lib/libvirt-vm.nix`. The fix evaluates and durandal's toplevel
  is confirmed unaffected, but nobody has watched the domain actually come up
  on `nire-cube` yet. The next real step is exactly that, not another round
  of `nix eval`.

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
