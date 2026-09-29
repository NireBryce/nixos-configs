# 10. Reading upstream source settled things guessing would have got wrong

_Last modified: 2026-09-29_

§10 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §10's full account.

- `flake-parts/extras/modules.nix:33` — `flake.modules` is
  `lazyAttrsOf (lazyAttrsOf deferredModule)` at the **top level**; the only
  `freeformType` is on `flake`. That is why 151 files could not keep
  `flake.modules` inside `perSystem`.
- `home-environment.nix:322` — `home.sessionPath` is `listOf str`, so duplicate
  definitions concatenate.
- Home Manager has **no blesh module**, so `programs.bash.blesh.enable` had
  never applied.
- `luksroot.nix`, `stage1Crypttab` — the crypttab line is `"${n} ${v.device} …"`,
  so `systemd-cryptsetup@<n>.service` is named after the **LUKS volume**, not the
  host. `systemd-cryptsetup@nire-durandal.service` named a unit that never
  existed; interpolating `networking.hostName` would produce another.
