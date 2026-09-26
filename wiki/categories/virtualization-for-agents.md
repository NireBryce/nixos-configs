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
- `libvirt.nix` sets `qemu.runAsRoot = false` (QEMU as `qemu-libvirtd`;
  DAC chowns writable images, skips read-only store paths). **A switch
  doesn't apply qemu.conf changes** (libvirtd is X-RestartIfChanged=false;
  libvirtd-config copies qemu.conf only as its dependency): `sudo systemctl
  restart libvirtd-config libvirtd`, then restart running domains.
- `vm-networking.nix` — `virbr0` opens UDP 67 + TCP 443 (to
  192.168.122.1 only); guest DNS to the host dropped in `mangle` INPUT
  (dnsmasq forwards to MagicDNS);
  `cube-vm-in` (jumped first in nixos-fw) refuses the host's global ports
  there; `mangle` FORWARD chain `cube-vm-egress` drops guest→RFC1918/
  100.64/10 (filter FORWARD is libvirt's iptables-backend chains, whose
  accepts come first). Chain ends in DROP, never `nixos-fw-refuse` (it
  would block firewall-start's teardown). Does NOT start the default
  network.
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
missing (rebuilds never wipe guest state — unless `ephemeral`: overlay
recreated on host boot or base-image/XML change, stamp
`/run/libvirt-vm/<name>.stamp`), starts the default network if inactive,
DHCP-reserves the guest IP, then `virsh define` + start. Shares carry
`<readonly/>` unless `readonly = false`.

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
  reaches an existing guest unless it is `ephemeral` (forge-runner is);
  manual reset: [../maintenance.md](../maintenance.md#the-runner-vm).
- **sshForward DNAT lives in nat chain `vm-<name>-ssh`**, rebuilt per
  firewall start. Before 2026-09-25 it was raw PREROUTING rules the
  firewall never flushes: reloads stacked duplicates, and removing a
  forward left it live. Each start still deletes that legacy shape.
- **nwfilter egress drops break inbound** (libvirt 12.7): out-direction
  drops match inbound traffic too; five variants tested 2026-09-25, all
  dropping the guest's inbound. Egress is enforced guest-locally
  (`networking.firewall.extraCommands`) instead; residual — VM-root can
  flush it.
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
