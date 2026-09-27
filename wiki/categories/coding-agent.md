# `coding-agent` — `config-system/homelab/coding-agent/`

_Last modified: 2026-09-26_

opencode, the AI coding agent, on `nire-cube` only: the CLI and `opencode
serve` as a systemd user service, so TUI sessions survive a TUI exit.
Nested under the [homelab](homelab.md) umbrella since 2026-09-26.

## Contents

- [What's in it](#whats-in-it)
- [Using it](#using-it)
- [Imported by](#imported-by)
- [See also](#see-also)

## What's in it

One module, `opencode/opencode-server.nix`:

- **The CLI**: `users.users.elly.packages`. No other NixOS host has
  opencode. Until 2026-09-26 a Home Manager module
  (`packages/development/tools/ai-tools/opencode.nix`) put it on every host;
  that was deleted. lysithea still has Homebrew's copy (`homebrew.nix`).
- **The server**: `opencode serve` on port 3003, bound to cube's tailnet
  IP only, lingering user unit. Before the move it lived at
  `hosts/cube/configuration/opencode-server-cube.nix`.
- **HTTP basic auth**: username `opencode`, password from the sops key
  `OPENCODE_SERVER_PASSWORD` (the bare password; a sops template writes the
  `KEY=value` EnvironmentFile, owned by the user because a user manager
  reads it as the user). Without it `opencode serve` answers every request
  unauthenticated, and its API runs shells as the user.

Named `coding-agent`, not `opencode`: a category and its only module
sharing a name silently merge ([../architecture.md](../architecture.md)).

## Using it

`just opencode-attach [dir] [args]` from a shell on cube or lysithea. It
prompts for the password unless `OPENCODE_SERVER_PASSWORD` is set; `-c`
resumes the last session. The unit and its traps (ConditionUser; the start script, which exits 1 until tailscaled
reports an IP, so a boot never leaves it bound to loopback) are commented in the module itself.

## Imported by

`nire-cube` only, through `homelab`.

## See also

[homelab.md](homelab.md) · [../hosts.md](../hosts.md) ·
[../lessons-learned.md](../lessons-learned.md) (the sddm user-manager race,
by searching `opencode-server`)
