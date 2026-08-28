# DRAFT -- no current caller. A generator for a persistent, libvirt-managed
# QEMU guest backed by an immutable qcow2 base image from the Nix store.
# Its one caller, virtualization-cube.nix (nire-llm-sandbox, a sandboxed-LLM-
# agent VM on nire-cube), was removed 2026-08-28 -- see wiki/history.md; this
# generator itself was kept as reusable infrastructure for the same reason
# nire/impermanence/_disko/impermanence-luks-btrfs.nix gives: a VM here is a
# real possibility, and hand-deriving one from scratch is worse than
# parameterizing once. Unexercised entirely until a new caller shows up --
# nothing here has been evaluated, let alone built or booted, since removal.
#
# Not a flake-parts module -- a plain function, `import`ed by path. Filed
# under `_lib/` because `import-tree` ignores any path containing `/_`: a
# plain function lacks the `{ flake.modules.<class>.<name> = ...; }` shape,
# and auto-import would call it with flake-parts' module args
# (`{ config, lib, pkgs, ... }`) against a closed pattern with no `...`,
# failing evaluation outright, not merely landing in the wrong scope. Same
# escape `_lib/mkPkgModule.nix` and `_disko/impermanence-luks-btrfs.nix`
# use -- `dirsAsCategory`'s `collectModules` walks into `_`-prefixed
# directories too, harmlessly: nothing under `_lib/` ever declares
# `flake.modules.nixos.<that-name>`, since import-tree never touched it.
#
# Deliberately does NOT sit directly under nire/homelab/virtualization/VMs/:
# a category collects every .nix file in every *sub*directory, and VMs/ is
# a subdirectory of `virtualization`, so a module there would be swept into
# the shared `flake.modules.nixos.virtualization` aggregate -- reaching
# every host that imports `virtualization` whole, not just whichever one
# a caller means it for. The one caller this generator ever had
# (virtualization-cube.nix, bare in nire/homelab/virtualization/ for the
# opposite reason -- see this file's own top comment) kept its VM
# cube-exclusive that way even while durandal still imported
# `virtualization` too; keeping the generator under `_lib/`, invoked only
# from a bare-in-category-root file like that one, is what any future
# caller wants for the same reason `boot`/`boot-durandal` almost merged.
{ name
, uuid            # a fixed libvirt domain UUID, standard 8-4-4-4-12 hex format.
                   # Pin explicitly rather than let libvirt generate one --
                   # same "a human reasons about collisions" reasoning as
                   # `guestId` below, but here load-bearing for idempotency:
                   # with no <uuid>, `virsh define` generates a FRESH random
                   # one on every parse, and libvirt refuses to redefine an
                   # already-registered domain of the same name under a
                   # different UUID ("domain 'X' already exists with uuid
                   # Y"). RUNTIME-VERIFIED TRAP, 2026-08-23, on nire-cube:
                   # the redefine then fails on every subsequent activation
                   # even though the domain from the first define was still
                   # running underneath the failing unit. `uuidgen` once per
                   # VM -- the trap's original repro (nire-llm-sandbox, since
                   # removed) adopted the UUID libvirt assigned on its first
                   # successful define, rather than picking a fresh one, so
                   # the fix needed no teardown of the running guest.
, image           # the disk-image derivation itself (config.system.build.image
                   # off the guest's own nixosConfiguration) -- used only for
                   # the GC-root symlink below, so it stays alive regardless
                   # of what generation of this flake is current.
, imagePath        # config.image.filePath off that SAME nixosConfiguration --
                   # the exact in-store qcow2 path, read programmatically by
                   # the caller. Deliberately separate from `image`:
                   # `image.filePath` is a NixOS option value, only
                   # reachable from a `config`, and this generator only ever
                   # has one for the host, never the guest.
, memoryMB ? 4096
, vcpus    ? 2
, networked ? true # NAT internet access via libvirt's default network, vs.
                   # none at all. NOT purely a security knob: whatever runs
                   # inside a networked = false guest also loses any network
                   # access it needed to do its job -- an isolation guest
                   # that boots but can't reach anything it depends on. The
                   # serial console (below, unconditional) is the only way in
                   # either way -- ssh needs the network too.

, sshForward ? null
    # null (default: no inbound access -- NAT means nothing reaches the
    # VM unprompted; right for an isolation guest, e.g. the sandboxed-LLM-
    # agent VM this generator originally shipped for, since removed), or
    # `{ guestId = <int, 2-254>; hostPort = <int>; sourceCidrs ? defaultAllowedSourceCidrs; }`
    # to forward hostPort on THIS HOST to the guest's SSH port. `sourceCidrs`
    # defaults to LAN-or-Tailscale (`defaultAllowedSourceCidrs` below); pass
    # `tailnetOnlyCidrs` (also below) for tailnet-only, or a bespoke list.
    #
    # `guestId` is a plain human-assigned integer, not derived or
    # auto-allocated -- same "pin explicitly, a human reasons about
    # collisions" reasoning as `nire/containers/podman/podman.nix`'s
    # `subUidRanges` (see its incident comment). It
    # fixes the guest's MAC (`52:54:00:00:00:<guestId, hex>`) and
    # DHCP-reserved IP (`192.168.122.<guestId>`) on libvirt's default
    # network, giving the port forward a stable destination -- no `virsh
    # domifaddr` polling, no DHCP timing. Two VMs sharing a guestId is a
    # real, unchecked collision -- no auto-allocator on purpose; avoiding
    # it is on whoever wires up the second VM, like a `subUidRanges`
    # collision.
}:
{ pkgs, lib, ... }:
let
    diskDir  = "/var/lib/libvirt/images";
    overlay  = "${diskDir}/${name}.qcow2";
    baseImg  = imagePath;
    xmlPath  = "/etc/libvirt/qemu/${name}.xml";

    hex2 = n: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n));
    # Only meaningful (and evaluated) when sshForward != null -- guarded
    # at every use site rather than given a placeholder, so a mistaken
    # reference with sshForward == null fails loudly instead of pointing
    # at 192.168.122.0.
    guestMac = "52:54:00:00:00:${hex2 sshForward.guestId}";
    guestIp  = "192.168.122.${toString sshForward.guestId}";

    interfaceXml = lib.optionalString networked ''
      <interface type='network'>
        <source network='default'/>
        <model type='virtio'/>
        ${lib.optionalString (sshForward != null) "<mac address='${guestMac}'/>"}
      </interface>
    '';

    # Tailscale's own CGNAT range, a separate constant (not folded into
    # the list below) so a caller can opt into *only* this: `sourceCidrs
    # = tailnetOnlyCidrs` for a VM reachable from the tailnet, never the
    # plain LAN.
    tailnetOnlyCidrs = [ "100.64.0.0/10" ];

    # RFC1918 (any private LAN) plus the tailnet range above -- the default
    # when `sshForward` doesn't say otherwise. Deliberately source-IP-based,
    # not interface-based: interface names (`enp3s0`, `wlp4s0`, ...) aren't
    # portable across hosts, which matters since this generator is meant
    # for more than one host's config (see header); a private-range source
    # check needs no per-host parameter. Real limit, either list:
    # network-layer check, not authentication -- casual/scanning traffic
    # stays out (spoofing can't complete a TCP handshake), but SSH key
    # auth is the actual boundary once a connection is allowed through.
    defaultAllowedSourceCidrs = [ "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" ] ++ tailnetOnlyCidrs;

    effectiveSourceCidrs =
        if sshForward != null
        then sshForward.sourceCidrs or defaultAllowedSourceCidrs
        else [ ]; # never read -- extraCommands below is gated on sshForward != null too

    # machine='pc' (i440fx), not 'q35': the older chipset defaults
    # unambiguously to SeaBIOS with no <loader> element, matching
    # image.efiSupport = false's legacy/GRUB-targeting-/dev/vda layout
    # (nixos/modules/virtualisation/disk-image.nix ->
    # nixos/lib/make-disk-image.nix). q35 can run BIOS-only too but its
    # firmware defaults are less uniform across libvirt versions, and
    # nothing here needs it (no PCIe passthrough, one disk/nic).
    domainXml = pkgs.writeText "${name}-domain.xml" ''
      <domain type='kvm'>
        <name>${name}</name>
        <uuid>${uuid}</uuid>
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

    # Idempotent by design, safe to re-run on every activation -- but only
    # because `domainXml` now carries a fixed `uuid` (see that parameter's
    # comment for the trap hit when it didn't):
    #   - the overlay is only ever CREATED if missing, so a rebuild never
    #     wipes a VM's accumulated state;
    #   - `virsh define` redefining an already-running domain's persistent
    #     config, UUID unchanged, does not stop or restart it (standard
    #     libvirt semantics);
    #   - the start is skipped if the domain is already running.
    #
    # The GC root matters: `image` is a Nix store path, and a qcow2
    # overlay references its backing file BY PATH, not by content. GC the
    # image (a later flake generation stops referencing it, nothing else
    # pins it) and the overlay's backing file silently disappears -- the
    # VM cannot start. The symlink below is a permanent GC root; removing
    # it is a deliberate step.
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
      # nothing in NixOS's libvirtd module does that part (see
      # vm-networking.nix's header: the definition self-heals via
      # libvirtd-config.service, only the "is it running" half is
      # missing). Scoped to this VM's activation, not a host-wide
      # boot-time unit: fires only when a VM declaring `networked = true`
      # comes up, so a host with no networked VM from this generator
      # (durandal, today) sees no change. RUNTIME-VERIFIED TRAP,
      # 2026-08-23, on nire-cube: without this, `virsh start` below fails
      # outright with "Requested operation is not valid: network 'default'
      # is not active".
      #
      # SECOND RUNTIME-VERIFIED TRAP, same day: `net-list` has no
      # `--state-active` flag (virsh 12.4.0), so a check using it always
      # errored and fell through to `net-start` unconditionally, failing
      # with "network is already active" on every activation after the
      # first. Plain `net-list --name` lists active-only networks by
      # default, so that's the whole fix.
      if ! ${pkgs.libvirt}/bin/virsh -c qemu:///system net-list --name | grep -qx default; then
        ${pkgs.libvirt}/bin/virsh -c qemu:///system net-start default
      fi
      ''}

      ${lib.optionalString (sshForward != null) ''
      # Pin this guest's DHCP lease to a known address so the port-forward
      # in networking.firewall.extraCommands (below) always has a correct
      # destination -- a static reservation, not read back from the guest
      # at runtime. dnsmasq (libvirt's network driver) excludes a reserved
      # address from its dynamic pool, so no collision with another
      # guest's ordinary lease -- only with another `sshForward.guestId`
      # set to the same integer, on the second VM's configurer to avoid
      # (see the `guestId` parameter comment). `--live --config`: applies
      # immediately AND persists across a libvirtd restart, matching `virsh
      # define`'s persistence below. Guarded, not reapplied: `net-update
      # add-last` on an existing entry errors, and this script runs on
      # every switch.
      if ! ${pkgs.libvirt}/bin/virsh -c qemu:///system net-dumpxml default | grep -qi "mac='${guestMac}'"; then
        ${pkgs.libvirt}/bin/virsh -c qemu:///system net-update default add-last ip-dhcp-host \
          "<host mac='${guestMac}' ip='${guestIp}'/>" --live --config
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
    assertions = [
        {
            assertion = sshForward != null -> networked;
            message   = "libvirt-vm ${name}: sshForward is set but networked = false -- there's no NIC for a forwarded port to reach.";
        }
    ];

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

    # Inbound port-forward into this one guest, from the source ranges
    # `sshForward.sourceCidrs` names (LAN-and-tailnet by default,
    # tailnet-only if asked -- see the two lists above for limits).
    # `extraCommands` is `lines`-typed (concatenates across modules), so
    # this is additive with any other VM's forward, not an override.
    #
    # PREROUTING DNAT only, deliberately no explicit FORWARD rule:
    # `vm-networking.nix`'s `trustedInterfaces = [ "virbr0" ]` already
    # accepts everything to/from that bridge, which is what a DNAT'd
    # packet needs to cross once its destination is rewritten to the guest
    # -- a narrower second FORWARD rule would be redundant, not additive.
    networking.firewall.extraCommands = lib.optionalString (sshForward != null) (
        lib.concatMapStringsSep "\n"
            (cidr: "iptables -t nat -A PREROUTING -s ${cidr} -p tcp --dport ${toString sshForward.hostPort} -j DNAT --to-destination ${guestIp}:22")
            effectiveSourceCidrs
    );
}
