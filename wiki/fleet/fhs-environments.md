# FHS environments and /etc evidence

_Last modified: 2026-10-31_

## Contents

- [Quick facts](#quick-facts)
- [Config custody](#config-custody)
- [See also](#see-also)

## Quick facts

How the fleet's bubblewrap-FHS packages behave, what an agent shell inherits
from them, and what that forbids. The `/etc` rules predate this page
(2026-09-16, fd315a83); what this page adds is the FHS inventory and the
config-custody consequences.

- **Fleet FHS packages**: `vscode-fhs` (editors/vscode.nix) and `heroic`
  (gaming-durandal.nix, with gamescope and gamemode added to its env — the
  nixpkgs heroic env leaves them out). android-studio was one until
  2026-09-09. Each launches its app inside a bwrap mount namespace.
- **An agent shell can be inside one.** zcode spawned from VS Code's
  integrated terminal inherits VS Code's FHS namespace: a synthetic `/etc`
  whose `/etc/profile` resolved into a VS Code FHS store path, 65 mounts
  against PID 1's 44. Found 2026-09-16 while chasing the [auto-suspend
  hang](../experiments/durandal-auto-suspend-hang.md).
- **`/etc` in such a shell is not evidence.** Read
  `/run/current-system/etc/...` and `/proc/1/mountinfo` instead. The rule
  lives in AGENTS.md (traps) and skill `impermanence-initrd`; three
  conclusions were retracted before it was written down.
- **Store files look `nobody`-owned inside the namespace**: only uid 1000 is
  mapped, so root-owned store paths read as `nobody`. `ssh` enforces
  ownership on its config, which is why `~/.ssh/config` must be a real
  user-owned file rather than a store symlink (0f1c2fb1).
- **App mechanisms that read `/etc` cannot be verified from such shells.**
  VS Code policy files (`/etc/vscode/policy/`, the `ExtensionsAutoUpdate`
  policy) were rejected on exactly this ground in the extension-auto-update
  decision (nixos-configs issue 604); proving them wants PID 1's namespace.

## Config custody

Files an FHS-wrapped app reads or writes are declared as **merges into
mutable files**, never store symlinks:

| File | Custody | Why |
|---|---|---|
| `~/.vscode/argv.json` | left mutable, hand-managed | VS Code writes it itself; declaring it committed a telemetry UUID or shared one across hosts (vscode.nix history, 2026-08-11) |
| `~/.ssh/config` | rendered text materialized as a 0600 user-owned file at activation | the store symlink was `nobody`-owned inside the namespace; ssh refused it (0f1c2fb1) |
| `~/.config/Code/User/settings.json` | HM `mutableUserSettings` merge (planned, issue 604) | declared keys re-asserted per switch; GUI edits to other keys survive |

The extensions directory stays mutable: never set `mutableExtensionsDir =
false` or add a second VS Code profile — the 2026-08-10 trap in
vscode.nix's history is that config's exact failure.

## See also

- [durandal gaming](durandal-gaming.md) — the heroic FHS override.
- [auto-suspend hang, for agents](../experiments/durandal-auto-suspend-hang-for-agents.md) — the namespace discovery.
- [vscode.nix](../../flake/modules/packages-config/editors/vscode/vscode.nix) — the traps in full.
