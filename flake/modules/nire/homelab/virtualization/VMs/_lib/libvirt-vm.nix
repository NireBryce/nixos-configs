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
, uuid            # a fixed libvirt domain UUID, standard 8-4-4-4-12 hex format.
                   # Pin explicitly rather than omit and let libvirt generate
                   # one -- same "a human reasons about collisions" reasoning
                   # `guestId` below already gives, but here it's load-bearing
                   # for idempotency, not just collision-avoidance: if
                   # `domainXml` has no <uuid>, `virsh define` generates a
                   # FRESH random one on every single parse, and libvirt then
                   # refuses to redefine an already-registered domain of the
                   # same name under a different UUID -- "domain 'X' already
                   # exists with uuid Y". RUNTIME-VERIFIED TRAP, 2026-08-23,
                   # on nire-cube: this generator's own header comment claimed
                   # "virsh define redefining an already-running domain's
                   # persistent config does not stop or restart it (standard
                   # libvirt semantics)" -- true only once the UUID is fixed;
                   # without one, that redefine fails outright on the second
                   # and every subsequent activation, even though the domain
                   # from the first successful define was still running fine
                   # underneath the failing unit. `uuidgen` once per VM to
                   # produce one; for llm-sandbox this is the UUID libvirt
                   # itself assigned on its first successful `virsh define`
                   # (adopted here rather than picked fresh, so fixing this
                   # doesn't require tearing down the already-running guest).
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

, sshForward ? null
    # null (default: no inbound access to this VM at all -- NAT means
    # nothing can reach it unprompted, which is the right default for
    # something like llm-sandbox whose whole point is isolation), or
    # `{ guestId = <int, 2-254>; hostPort = <int>; sourceCidrs ? defaultAllowedSourceCidrs; }`
    # to forward hostPort on THIS HOST to the guest's SSH port. `sourceCidrs`
    # defaults to LAN-or-Tailscale (see `defaultAllowedSourceCidrs` below);
    # pass `tailnetOnlyCidrs` (also below) instead to admit only Tailscale
    # sources, or a bespoke list for anything narrower still.
    #
    # `guestId` is a plain human-assigned integer, not derived from `name`
    # or auto-allocated -- same "pin explicitly, a human reasons about
    # collisions" reasoning `nire/containers/podman/podman.nix` already
    # gives for its own `subUidRanges` (see that file's own comment on the
    # incident that taught it). It fixes both this guest's MAC
    # (`52:54:00:00:00:<guestId, hex>`) and its DHCP-reserved IP
    # (`192.168.122.<guestId>`) on libvirt's default network, so the port
    # forward below always has a stable, known destination -- no runtime
    # `virsh domifaddr` polling, no dependency on DHCP lease timing. Two
    # VMs sharing a `guestId` is a real, unchecked collision -- there's no
    # auto-allocator here on purpose, so avoiding that is on whoever wires
    # up the second VM, the same way avoiding a `subUidRanges` collision is.
}:
{ pkgs, lib, ... }:
let
    diskDir  = "/var/lib/libvirt/images";
    overlay  = "${diskDir}/${name}.qcow2";
    baseImg  = imagePath;
    xmlPath  = "/etc/libvirt/qemu/${name}.xml";

    hex2 = n: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n));
    # Both only meaningful (and only evaluated) when sshForward != null --
    # guarded at every use site below rather than given a placeholder value
    # here, so a mistaken reference with sshForward == null fails loudly
    # instead of silently pointing at 192.168.122.0.
    guestMac = "52:54:00:00:00:${hex2 sshForward.guestId}";
    guestIp  = "192.168.122.${toString sshForward.guestId}";

    interfaceXml = lib.optionalString networked ''
      <interface type='network'>
        <source network='default'/>
        <model type='virtio'/>
        ${lib.optionalString (sshForward != null) "<mac address='${guestMac}'/>"}
      </interface>
    '';

    # Tailscale's own CGNAT range. Its own constant (not folded into the
    # list below silently) so a caller can opt into *only* this -- pass
    # `sourceCidrs = tailnetOnlyCidrs` on `sshForward` for a VM that should
    # never be reachable from the plain LAN, tailnet or nothing.
    tailnetOnlyCidrs = [ "100.64.0.0/10" ];

    # RFC1918 (any private LAN) plus the tailnet range above -- the default
    # when `sshForward` doesn't say otherwise. Deliberately source-IP-based
    # rather than interface-based either way: an interface name (`enp3s0`,
    # `wlp4s0`, ...) isn't portable across hosts, which matters here
    # specifically because this generator is meant to be called from more
    # than one host's config (see this file's own header); a private-range
    # source check needs no per-host parameter to stay correct everywhere.
    # Real limit worth knowing, for either list: this is a network-layer
    # check, not authentication -- it keeps casual/scanning traffic from
    # the wider internet out (source-IP spoofing can't complete a TCP
    # handshake, so this isn't trivially bypassable), but SSH's own key
    # auth is still the actual security boundary once a connection is
    # allowed through at all.
    defaultAllowedSourceCidrs = [ "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" ] ++ tailnetOnlyCidrs;

    effectiveSourceCidrs =
        if sshForward != null
        then sshForward.sourceCidrs or defaultAllowedSourceCidrs
        else [ ]; # never read -- extraCommands below is gated on sshForward != null too

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

    # Idempotent by design, safe to re-run on every activation -- but this
    # claim only holds because `domainXml` now carries a fixed `uuid` (see
    # that parameter's own comment for the trap hit when it didn't):
    #   - the overlay is only ever CREATED if missing, so a rebuild never
    #     wipes a VM's accumulated state;
    #   - `virsh define` redefining an already-running domain's persistent
    #     config, UUID unchanged, does not stop or restart it (standard
    #     libvirt semantics);
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
      #
      # SECOND RUNTIME-VERIFIED TRAP, same day, found on the very next
      # switch: `net-list` has no `--state-active` flag (virsh 12.4.0:
      # "command 'net-list' doesn't support option --state-active"), so the
      # check above always errored and fell through to `net-start`
      # unconditionally -- which then fails with "network is already
      # active" on every activation after the first. Plain `net-list
      # --name` already lists active-only networks by default (no `--all`
      # or `--inactive` given), so that's the whole fix -- no flag needed.
      if ! ${pkgs.libvirt}/bin/virsh -c qemu:///system net-list --name | grep -qx default; then
        ${pkgs.libvirt}/bin/virsh -c qemu:///system net-start default
      fi
      ''}

      ${lib.optionalString (sshForward != null) ''
      # Pin this guest's DHCP lease to a known address so the port-forward
      # rule in networking.firewall.extraCommands (below) always has a
      # correct destination -- a static reservation, not something read
      # back from the guest at runtime. dnsmasq (what libvirt's network
      # driver actually runs) excludes a reserved address from its dynamic
      # pool automatically, so this can't collide with some OTHER guest's
      # ordinary DHCP lease -- only with another `sshForward.guestId` set
      # to the same integer, which is on whoever configures the second VM
      # to avoid, per this file's `guestId` parameter comment.
      # `--live --config`: applies immediately (the guest may already be
      # running and lease-renew into this) AND persists across a libvirtd
      # restart, matching `virsh define`'s own persistence below. Guarded
      # rather than reapplied unconditionally: `net-update add-last` on an
      # already-present entry errors, and this activation script runs on
      # every switch, not just the first one.
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

    # Inbound port-forward into this one guest, from whichever source
    # ranges `sshForward.sourceCidrs` names (LAN-and-tailnet by default,
    # tailnet-only if the caller asked for that) -- see
    # `defaultAllowedSourceCidrs`/`tailnetOnlyCidrs` above for what that
    # means and its actual limits. `extraCommands` is `lines`-typed (concatenates across
    # modules), so this is additive with any other VM's own forward and
    # with anything else that sets it -- not an override.
    #
    # PREROUTING DNAT only, deliberately no explicit FORWARD-chain rule
    # alongside it: `vm-networking.nix`'s `trustedInterfaces = [ "virbr0" ]`
    # already accepts everything to/from that bridge, which is what a
    # DNAT'd packet needs to cross once its destination has been rewritten
    # to this guest's address -- adding a second, narrower FORWARD rule here
    # would be redundant with, not additional to, that existing trust.
    networking.firewall.extraCommands = lib.optionalString (sshForward != null) (
        lib.concatMapStringsSep "\n"
            (cidr: "iptables -t nat -A PREROUTING -s ${cidr} -p tcp --dport ${toString sshForward.hostPort} -j DNAT --to-destination ${guestIp}:22")
            effectiveSourceCidrs
    );
}
