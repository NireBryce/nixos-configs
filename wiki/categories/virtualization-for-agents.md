# `virtualization`, for agents

_Last modified: 2026-09-25_

Condensed from [virtualization.md](virtualization.md), which keeps the
narrative and verification records. Facts only here.

Libvirt/QEMU VMs on `nire-cube` only — podman/distrobox are the separate
[containers](containers.md) category, never this one. Nested under
`homelab`.

## Members (`libvirt/`, all `nixos`-class)

- `libvirt.nix` — `virtualisation.libvirtd`; also virtiofsd
  (`vhostUserPackages`, required for virtiofs shares), virt-manager,
  `elly` in `libvirtd`. No `ovmf` (removed option, eval fails).
- `vm-networking.nix` — `trustedInterfaces = [ "virbr0" ]` so guests get
  DHCP/DNS past the firewall. Does NOT start the default network.
- `virt-tools.nix` — client tooling only.
- `libvirt-persist.nix` — persists the libvirtd secrets key on
  impermanence hosts only; no-op on cube.

## The generator: `VMs/_lib/libvirt-vm.nix`

A curried function, not a module (`_lib/` because import-tree ignores
`/_`; auto-import would fail on its closed argument pattern). Current
caller: `virtualization-cube.nix`, bare in `virtualization/` — collected
by nothing of the category (bare files aren't), but swept into `homelab`
by its `bareModulesOf`. Guests get a `nixosConfigurations` entry; a guest
without the `nire-` prefix (e.g. `forge-runner`) is a component, not a
fleet machine — that prefix is what host-count claims count.

Parameters: `name`, `uuid` (PIN IT — without `<uuid>` libvirt generates a
fresh one per define and then refuses redefinition; runtime-verified),
`image` + `imagePath` (`"${image}/${image.filePath}"` — `filePath` is
relative), `memoryMB ? 4096`, `vcpus ? 2`, `networked ? true`,
`sshForward ? { guestId, hostPort, sourceCidrs ? … }`, `shares ? []`
(virtiofs mounts `{ source, tag }`; switches the domain to memfd/shared
memory).

Produces: domain XML at `/etc/libvirt/qemu/<name>.xml` + a oneshot
`libvirt-vm-<name>` unit (after/requires `libvirtd`, wantedBy
multi-user) that GC-roots the base image, creates the COW overlay only if
missing (rebuilds never wipe guest state), starts the default network if
inactive, DHCP-reserves the guest IP, then `virsh define` + start.

## Traps

- **Default network ships defined-but-inactive** — `virsh start` fails
  with "network 'default' is not active" without the activation script's
  guarded start; `net-list --name` lists active-only (no
  `--state-active` flag exists). Both runtime-verified 2026-08-23.
- **Instance-name dashes escape in unit names**: guest instance
  `forge-runner` → unit `forgejo-runner-forge\x2drunner.service`
  (`utils.escapeSystemdPath`). Targeting the plain spelling in
  `systemd.services` silently creates an EMPTY second unit — evals clean,
  does nothing. Catch by reading the rendered unit.
- **`image.modules.qemu`-style guests break toplevel checks** — import
  `modulesPath + "/virtualisation/disk-image.nix"` DIRECTLY in the guest
  config, and read `image.filePath` relative to the image derivation
  (lessons-learned §36).
- **GC the base image = VM cannot start** — overlays reference the
  backing file by path; the generator's GC root is the fix, removing it
  is a deliberate step.
- **Overlays pin their base at creation** — a rebuilt base image never
  reaches an existing guest; guest packages age in place. Periodic
  overlay reset (destroy + rm overlay + restart the VM unit): procedure
  in [../maintenance.md](../maintenance.md#the-runner-vm).
- **Boot-time start is a oneshot, not crash-restart** — no `Restart=`; a
  dead guest stays dead until next boot/switch.

## Imported by

`nire-cube` only (as part of `homelab`). `tenacity` imports `containers`,
never this.

## See also

[virtualization.md](virtualization.md) ·
[virtualization-history.md](virtualization-history.md) ·
[../homelab/forgejo.md](../homelab/forgejo.md) (the runner VM's user) ·
[git-forge.md](git-forge.md)
