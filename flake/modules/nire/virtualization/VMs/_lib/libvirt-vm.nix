# DRAFT -- structurally exercised only by virtualization-cube.nix so far, and
# that module itself hasn't been booted (see its header and this repo's own
# "Treat an undated 'verified' as *evaluates*" rule). A generator for a
# persistent, libvirt-managed QEMU guest backed by an immutable qcow2 base
# image from the Nix store -- currently has exactly one caller
# (virtualization-cube.nix's "llm-sandbox" instance), written as a generator
# rather than inlined there on the same reasoning
# nire/impermanence/_disko/impermanence-luks-btrfs.nix gives for being one:
# a second VM is a real possibility (a homelab reason this whole feature
# exists) and re-deriving this by hand a second time is worse than
# parameterizing it once.
#
# Not a flake-parts module itself -- a plain function, `import`ed by path.
# Filed under `_lib/` specifically because `import-tree` ignores any path
# containing `/_` by default: a plain function does not have the
# `{ flake.modules.<class>.<name> = ...; }` shape import-tree expects, and if
# it tried to auto-import this the normal way it would call it with
# flake-parts' own module args (`{ config, lib, pkgs, ... }`) against a
# function whose only parameter is `{ name, image, ... }` -- a closed
# pattern with no `...`, so it would reject every one of those as an
# unexpected argument and fail evaluation outright, not merely end up in the
# wrong scope. Same mechanism `_lib/mkPkgModule.nix` and
# `_disko/impermanence-luks-btrfs.nix` already rely on -- see
# `dirsAsCategory`'s own `collectModules`, which walks into `_`-prefixed
# directories too (it does not special-case them) but harmlessly: whatever
# name it collects there is filtered out because nothing under `_lib/` ever
# declares `flake.modules.nixos.<that-name>` in the first place, since
# import-tree never touched it.
#
# Deliberately does NOT sit directly under nire/virtualization/VMs/ as a
# normal category member. dirsAsCategory collects every .nix file in every
# *sub*directory of a category unconditionally -- VMs/ is a subdirectory of
# `virtualization`, so a module declared directly there would be swept into
# the shared `flake.modules.nixos.virtualization` aggregate and reach every
# host that imports it, durandal included. The whole point of this feature
# is that it reaches only cube (via virtualization-cube.nix, which sits
# bare in nire/virtualization/ for exactly the opposite reason -- see that
# file's own header). Putting the generator under `_lib/` and only ever
# invoking it from virtualization-cube.nix is what keeps the two host's
# coverage from merging back together the way `boot`/`boot-durandal` almost
# did.
{ name
, image           # the disk-image derivation itself (config.system.build.image
                   # off the guest's own nixosConfiguration) -- used only for
                   # the GC-root symlink below, so it stays alive regardless
                   # of what generation of this flake is current.
, imagePath        # config.image.filePath off that SAME nixosConfiguration --
                   # the exact in-store qcow2 path as a plain string, read
                   # programmatically by the caller rather than guessed here.
                   # Deliberately a separate parameter rather than derived
                   # from `image` inside this file: `image.filePath` is a
                   # NixOS option value, only reachable from a `config`, and
                   # this generator never has one of those for the guest --
                   # only for the host it's installing the VM onto.
, memoryMB ? 4096
, vcpus    ? 2
, networked ? true # NAT internet access via libvirt's default network, vs.
                   # none at all. NOT purely a security knob: an agent
                   # running inside with networked = false cannot reach
                   # Claude's API either, so the sandbox boots but the LLM
                   # agent inside it cannot actually do its job. A serial
                   # console (below, unconditional) is the only way in
                   # either way -- ssh needs the network too.
}:
{ pkgs, lib, ... }:
let
    diskDir  = "/var/lib/libvirt/images";
    overlay  = "${diskDir}/${name}.qcow2";
    baseImg  = imagePath;
    xmlPath  = "/etc/libvirt/qemu/${name}.xml";

    interfaceXml = lib.optionalString networked ''
      <interface type='network'>
        <source network='default'/>
        <model type='virtio'/>
      </interface>
    '';

    # machine='pc' (i440fx), not 'q35': the older chipset defaults
    # unambiguously to SeaBIOS with no <loader> element at all, matching
    # image.efiSupport = false's legacy/GRUB-targeting-/dev/vda partition
    # layout (nixos/modules/virtualisation/disk-image.nix ->
    # nixos/lib/make-disk-image.nix). q35 can also run BIOS-only, but its
    # firmware-selection defaults are less uniform across libvirt versions,
    # and there's nothing this guest needs from q35 (no PCIe passthrough, no
    # more than one disk/nic).
    domainXml = pkgs.writeText "${name}-domain.xml" ''
      <domain type='kvm'>
        <name>${name}</name>
        <memory unit='MiB'>${toString memoryMB}</memory>
        <currentMemory unit='MiB'>${toString memoryMB}</currentMemory>
        <vcpu placement='static'>${toString vcpus}</vcpu>
        <os>
          <type arch='x86_64' machine='pc'>hvm</type>
          <boot dev='hd'/>
        </os>
        <features>
          <acpi/>
          <apic/>
        </features>
        <cpu mode='host-passthrough'/>
        <clock offset='utc'/>
        <on_poweroff>destroy</on_poweroff>
        <on_reboot>restart</on_reboot>
        <on_crash>destroy</on_crash>
        <devices>
          <emulator>${pkgs.qemu}/bin/qemu-system-x86_64</emulator>
          <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2'/>
            <source file='${overlay}'/>
            <target dev='vda' bus='virtio'/>
          </disk>
          ${interfaceXml}
          <console type='pty'>
            <target type='serial' port='0'/>
          </console>
          <serial type='pty'>
            <target port='0'/>
          </serial>
          <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'/>
          <video><model type='qxl'/></video>
        </devices>
      </domain>
    '';

    # Idempotent by design, safe to re-run on every activation:
    #   - the overlay is only ever CREATED if missing, so a rebuild never
    #     wipes a VM's accumulated state;
    #   - `virsh define` redefining an already-running domain's persistent
    #     config does not stop or restart it (standard libvirt semantics);
    #   - the start is skipped if the domain is already running.
    #
    # The GC root matters more than it looks: `image` is a Nix store path,
    # and a qcow2 overlay references its backing file BY PATH, not by
    # content. If `image` is ever garbage-collected (e.g. a later flake
    # generation stops referencing it, `nix-collect-garbage` runs, nothing
    # else pins it), the overlay's backing file silently disappears and the
    # VM cannot start. The symlink below is a permanent GC root for exactly
    # that reason -- removing it is a deliberate step, not a side effect of
    # rebuilding this flake.
    activate = pkgs.writeShellScript "libvirt-vm-${name}-activate" ''
      set -euo pipefail

      if [ ! -e "${baseImg}" ]; then
        echo "libvirt-vm-${name}: expected base image at ${baseImg}, not found" >&2
        exit 1
      fi

      mkdir -p /nix/var/nix/gcroots/libvirt-vms
      ln -sfn "${image}" "/nix/var/nix/gcroots/libvirt-vms/${name}-base"

      mkdir -p "${diskDir}"
      if [ ! -e "${overlay}" ]; then
        ${pkgs.qemu}/bin/qemu-img create -f qcow2 -F qcow2 -b "${baseImg}" "${overlay}"
      fi

      ${lib.optionalString networked ''
      # libvirt ships the default NAT network DEFINED but never STARTED --
      # nothing in NixOS's own libvirtd module does that part (see
      # vm-networking.nix's header for the two-piece explanation: the
      # definition itself self-heals via libvirtd-config.service, only the
      # "is it running" half is missing). Deliberately scoped to exactly
      # this VM's own activation rather than a host-wide boot-time unit: it
      # only fires when a VM that actually declared `networked = true` is
      # being brought up, so a host with no networked VM defined through
      # this generator (durandal, today) sees no change in behaviour at
      # all. RUNTIME-VERIFIED TRAP, 2026-08-23, on nire-cube: without this,
      # `virsh start` below fails outright with "Requested operation is not
      # valid: network 'default' is not active".
      if ! ${pkgs.libvirt}/bin/virsh -c qemu:///system net-list --name --state-active | grep -qx default; then
        ${pkgs.libvirt}/bin/virsh -c qemu:///system net-start default
      fi
      ''}

      ${pkgs.libvirt}/bin/virsh -c qemu:///system define "${xmlPath}"

      state="$(${pkgs.libvirt}/bin/virsh -c qemu:///system domstate ${name})"
      if [ "$state" != "running" ]; then
        ${pkgs.libvirt}/bin/virsh -c qemu:///system start ${name}
      fi
    '';
in
{
    environment.etc."libvirt/qemu/${name}.xml".source = domainXml;

    systemd.services."libvirt-vm-${name}" = {
        description = "Define and start the ${name} libvirt VM";
        after       = [ "libvirtd.service" ];
        requires    = [ "libvirtd.service" ];
        wantedBy    = [ "multi-user.target" ];
        serviceConfig = {
            Type            = "oneshot";
            RemainAfterExit = true;
            ExecStart       = activate;
        };
    };
}
