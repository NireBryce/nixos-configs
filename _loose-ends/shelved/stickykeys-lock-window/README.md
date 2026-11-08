# StickyKeysLockWindow (shelved 2026-11-07)

A kwin sticky-keys plugin patch that tells a deliberate double-tap of a
modifier (lock it) from a later second tap (unlatch it), built out-of-tree as
`StickyKeysLockWindowPlugin` and installed on `nire-tenacity` only. Issue
#255 has the design.

Removed from the config on 2026-11-07, when kwin 6.8.2 failed the patch's
second hunk (`Hunk #2 FAILED at 129`). The files here are not imported:
dirs-as-categories reads only `flake/modules/`.

- `stickykeys-lock-window-tenacity.nix`: the module file, as it was at removal.
- `stickykeys-lock-window.patch`: already rewritten against kwin 6.8.2, where
  a tap latches or locks on its release. The plugin built against 6.8.2 on
  2026-11-07 (rung: *builds*, plugin only); a full tenacity build and a
  hardware test were not done.

## Restoring it

1. `git mv` both files back to `flake/modules/host-config/tenacity/configuration/`.
2. In `plasma-tenacity.nix`, add `StickyKeysLockWindow = 230;` back to
   `kaccessrc.Keyboard`, and delete `StickyKeysPluginEnabled = true;` from
   `kwinrc.Plugins`: the module sets it to `false`, and two definitions of
   the key conflict.
3. Check the patch still applies to the current kwin: `just build` on
   tenacity fails in `patchPhase` if it does not.
