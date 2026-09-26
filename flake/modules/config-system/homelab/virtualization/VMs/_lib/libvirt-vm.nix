# A generator for a persistent, libvirt-managed QEMU guest backed by an
# immutable qcow2 base image from the Nix store. Exercised as of
# 2026-09-25 by forge-runner (virtualization-cube.nix, the Forgejo Actions
# runner VM) after sitting DRAFT with no caller since its first one
# (virtualization-cube.nix, for nire-llm-sandbox) was removed 2026-08-28.
# Kept as a generator, not a module, for the same reason
# _disko/impermanence-luks-btrfs.nix is.
#
# Not a flake-parts module -- a plain function `import`ed by path, filed
# under `_lib/` because import-tree ignores any path containing `/_`.
# Auto-importing it would call a closed argument pattern with flake-parts'
# module args and fail evaluation outright, not merely land in the wrong
# scope. It must NOT sit directly under `VMs/` either: a category collects
# every `.nix` in every SUBdirectory, so a module there joins the shared
# `virtualization` aggregate and reaches every host importing it.
#
# wiki/categories/virtualization.md has the placement mechanism and the
# default-network trap in full; `virtualization-history.md` has the
# sshForward verification record from the llm-sandbox era.
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
    # collisions" reasoning as `system/containers/podman/podman.nix`'s
    # `subUidRanges` (see its incident comment). It
    # fixes the guest's MAC (`52:54:00:00:00:<guestId, hex>`) and
    # DHCP-reserved IP (`192.168.122.<guestId>`) on libvirt's default
    # network, giving the port forward a stable destination -- no `virsh
    # domifaddr` polling, no DHCP timing. Two VMs sharing a guestId is a
    # real, unchecked collision -- no auto-allocator on purpose; avoiding
    # it is on whoever wires up the second VM, like a `subUidRanges`
    # collision.

, shares ? []
    # Optional virtiofs mounts, host directory -> guest, each
    # `{ source = "/absolute/host/dir"; tag = "guest-tag"; }`. The guest
    # mounts it by the tag with fileSystems `fsType = "virtiofs"`
    # (device = the tag); the host directory should exist before the
    # domain starts and hold ONLY what the guest genuinely needs -- a
    # virtiofs share is a live window into the host filesystem, not a
    # copy (the intended delivery channel for single secrets a guest
    # needs without giving it a sops key; see virtualization-cube.nix).
    #
    # Non-empty shares switch the domain to shared memory
    # (<memoryBacking> memfd + shared access), which libvirt requires
    # for virtiofs, and libvirt spawns one virtiofsd per share --
    # `vhostUserPackages` on the host side is what makes that work
    # (libvirt/libvirt.nix).
    #
    # Read-only ON THE HOST by default (`<readonly/>`, which libvirt
    # turns into virtiofsd's `--readonly`): a guest-side `ro` mount
    # option is the guest's own choice, and guest root can remount rw.
    # With passthrough and a root virtiofsd, a writable share lets guest
    # root create root-owned files -- setuid ones included -- in the host
    # directory. Pass `readonly = false;` on a share that genuinely needs
    # writes back.

, ephemeral ? false
    # true: the guest's overlay is discarded and recreated from the
    # current base image whenever the base image or the domain XML
    # changes, and on every host boot -- the guest never carries state
    # across either. The activation script compares a stamp under /run
    # (tmpfs, so missing after a boot) against the current base image and
    # domain XML store paths, and on a mismatch destroys the running
    # domain, deletes the overlay, and lets the normal create/define/start
    # path below rebuild it. A switch that changes the guest therefore
    # kills whatever it was running. Without this, a new guest image
    # never reaches a running overlay (the overlay pins its base at
    # creation) and new domain XML waits for a manual `virsh destroy`.

}:
{ pkgs, lib, ... }:
let
    diskDir  = "/var/lib/libvirt/images";
    overlay  = "${diskDir}/${name}.qcow2";
    baseImg  = imagePath;
    xmlPath  = "/etc/libvirt/qemu/${name}.xml";
    stamp    = "/run/libvirt-vm/${name}.stamp";

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

    # One <filesystem> per share, inside <devices>. `accessmode='passthrough'`
    # presents host ownership as-is (a root:root 0600 secret stays
    # root-only in the guest, where guest-root can read it and nothing
    # else can) -- the right mode for the single-secret delivery these
    # exist for; a multi-user guest would want 'mapped' instead.
    sharesXml = lib.concatMapStrings (share: ''
          <filesystem type='mount' accessmode='passthrough'>
            <driver type='virtiofs'/>
            <source dir='${share.source}'/>
            <target dir='${share.tag}'/>
            ${lib.optionalString (share.readonly or true) "<readonly/>"}
          </filesystem>
    '') shares;

    # libvirt requires shared memory for virtiofs; memfd is the backend
    # its own docs use. Only emitted when there is something to share --
    # a plain NAT VM keeps the default (non-shared) memory so the element
    # order below never has an empty gap to reason about.
    memoryBackingXml = lib.optionalString (shares != [ ]) ''
        <memoryBacking>
          <source type='memfd'/>
          <access mode='shared'/>
        </memoryBacking>
    '';

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
        ${memoryBackingXml}
        <devices>
          <emulator>${pkgs.qemu}/bin/qemu-system-x86_64</emulator>
          <disk type='file' device='disk'>
            <driver name='qemu' type='qcow2'/>
            <source file='${overlay}'/>
            <target dev='vda' bus='virtio'/>
          </disk>
          ${interfaceXml}
          ${sharesXml}
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
    #     wipes a VM's accumulated state -- unless `ephemeral`, which
    #     deletes it on purpose first;
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

      ${lib.optionalString ephemeral ''
      # `ephemeral` (parameter comment): reset on a new base image, new
      # domain XML, or a fresh boot (the stamp lives on tmpfs). This
      # script's own store path embeds both paths, so any change that
      # matters here also changes ExecStart and makes switch re-run it.
      want="${baseImg} ${domainXml}"
      if [ "$(cat "${stamp}" 2>/dev/null || true)" != "$want" ]; then
        echo "libvirt-vm-${name}: ephemeral reset (base image, domain XML, or boot changed)"
        state="$(${pkgs.libvirt}/bin/virsh -c qemu:///system domstate ${name} 2>/dev/null || true)"
        if [ -n "$state" ] && [ "$state" != "shut off" ]; then
          ${pkgs.libvirt}/bin/virsh -c qemu:///system destroy ${name}
        fi
        rm -f "${overlay}"
      fi
      ''}
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
      ${lib.optionalString ephemeral ''

      # Written last, so a failed start above resets again next run.
      mkdir -p "$(dirname "${stamp}")"
      echo "$want" > "${stamp}"
      ''}
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
    # PREROUTING DNAT only, no FORWARD rule of its own. The reasoning
    # this used to give -- `trustedInterfaces = [ "virbr0" ]` accepts
    # everything to/from the bridge -- never held: trustedInterfaces
    # feeds the INPUT chain (nixos-fw), not FORWARD, and it was narrowed
    # away 2026-09-25 (vm-networking.nix). The DNAT'd connection
    # crosses FORWARD on libvirt's own chains' terms, and does: first
    # made 2026-09-25, `ssh -p 2223 root@ts-cube` from the tailnet into
    # forge-runner. `ssh -J <host> root@<guestIp>` is the other way in.
    networking.firewall.extraCommands = lib.optionalString (sshForward != null) (
        lib.concatMapStringsSep "\n"
            (cidr: "iptables -t nat -A PREROUTING -s ${cidr} -p tcp --dport ${toString sshForward.hostPort} -j DNAT --to-destination ${guestIp}:22")
            effectiveSourceCidrs
    );
}
