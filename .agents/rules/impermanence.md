---
paths:
  - "flake/modules/general-config/impermanence/**"
  - "flake/modules/host-config/*/hardware/**"
---

# Impermanence, initrd, and host hardware modules

Full mechanism and worked examples: skill `impermanence-initrd`. Read it
before changing anything here.

- `WARN-impermanence.nix` (reached through the `impermanence` category)
  deletes the `/root` btrfs subvolume in initrd on every boot and needs a
  `root-blank` subvolume to exist. Read it before changing anything near it.
- Two of the three NixOS hosts import it and wipe `/root` on boot:
  `nire-durandal`, `nire-tenacity`. `nire-cube` deliberately does not
  (plain persistent root, not LUKS+impermanence). Check the specific host
  in `flake/modules/host-config/hosts.nix`; never assume "every host" or
  "no host".
- `flake/modules/host-config/<host>/hardware/` holds `fileSystems` and
  `boot`; a wrong entry can fail the next boot before anyone can intervene.
  Prefer `just boot` over `just switch` for these and for anything touching
  initrd, so the running generation stays the fallback.
- The shell's view of the machine (`lsblk`, `findmnt`, `/etc`) is scoped to
  its mount namespace and can look wrong while being correct. Use
  `/proc/1/mountinfo`, `/dev/disk/by-uuid/`, `/run/current-system`
  instead, all unprivileged.
- Read the links in a comment before deleting the code it annotates: a
  dropped `requires` that a cited manual page explained nearly turned the
  `/root`-deleting unit from "does not run" into "runs and fails" (§11 in
  `wiki/lessons-learned.md`).
- `.agents/hooks/impermanence-edit-guard-pretooluse.sh` warns (never
  blocks) when an Edit/Write lands in these trees.
