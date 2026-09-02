# `virtualization` — history

## Contents

- [`nire-llm-sandbox`'s `sshForward` verification](#nire-llm-sandboxs-sshforward-verification)
- [The near-miss this category's own header records](#the-near-miss-this-categorys-own-header-records)
- [See also](#see-also)

Resolved incidents and a removed VM's own verification record, split out of
[virtualization](virtualization.md) 2026-09-03 so that page stays about the
generator as it exists today. `nire-llm-sandbox` itself was removed
2026-08-28 — [../history.md](../history.md).

## `nire-llm-sandbox`'s `sshForward` verification

`nire-llm-sandbox` was the one caller of `VMs/_lib/libvirt-vm.nix`'s
`sshForward` parameter, before its removal 2026-08-28: `guestId = 10`,
`hostPort = 2222`, `sourceCidrs` narrowed to Tailscale only (not the
generator's own LAN-or-Tailscale default) — a per-VM choice in its cube
wiring (`virtualization-cube.nix`, also removed), not a property of the
generator itself.

While it existed it was verified by reading back the actual generated
domain XML, activation script, and firewall rule (not just evaluation) —
the domain XML carried the exact MAC, the activation script's
DHCP-reservation guard referenced it correctly, and
`networking.firewall.extraCommands` contained exactly one DNAT rule,
scoped to `100.64.0.0/10`, no LAN range. The domain itself was confirmed
booted and staying up on `nire-cube` (2026-08-24 — see
[../lessons-learned.md](../lessons-learned.md) §40), but an actual SSH
connection through this forward was never made before the VM was removed.
No caller uses `sshForward` today; the mechanism is unexercised until one
does.

## The near-miss this category's own header records

For about an hour on 2026-08-21, `libvirt.nix` was named
`virtualization.nix` and declared `flake.modules.nixos.virtualization` —
the exact attribute this category's `dirsAsCategory.nix` declares for its
aggregate. Both would have written to the same name and **merged**
invisibly. Caught and renamed before it shipped.

## See also

- [virtualization](virtualization.md) — the category as it works today.
- [../history.md](../history.md) — `nire-llm-sandbox`'s removal.
- Skill `nixos-vm-images` — the full mechanism and traps behind the
  generator.
