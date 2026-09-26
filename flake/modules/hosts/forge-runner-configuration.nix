# The Forgejo Actions runner VM -- a NixOS guest on nire-cube, instantiated
# by virtualization-cube.nix through VMs/_lib/libvirt-vm.nix. This file is
# the guest's whole config; cube-side support (the sops secret, the share
# staging, the registration against the forge) lives in
# git-forge/forgejo/actions-runner.nix.
#
# Why a VM at all: a CI runner executes workflow code, and workflow code on
# a runner with podman/docker access is one container escape away from the
# host. On cube that escape would land root access to everything sops
# decrypts there; in here it lands a disposable-ish VM that holds exactly
# one secret (its own runner token) -- GitHub's ephemeral-runner model,
# minus the ephemerality.
#
# The guest deliberately runs NO sops-nix, no Home Manager, and no user
# account -- same shape llm-sandbox used. Its one secret arrives over
# virtiofs (tag `runner-secret`, read-only on the host side and mounted
# read-only at /mnt/runner-secret)
# from cube's already-decrypted /run/secrets copy; the mount is the guest's
# entire trust surface from the host side, and the runner token is the only
# thing that crosses.
#
# Networking, without tailscaled: the guest is NOT on the tailnet. It
# reaches the forge through Caddy on the virbr0 gateway (192.168.122.1),
# the one host port vm-networking.nix opens to guests, and whose cert for
# git.moose-micro.ts.net is a real publicly-trusted one -- so the
# connection URL is the ordinary ROOT_URL and TLS validates against system
# CAs. The /etc/hosts pin below is what makes the name resolve at all
# (MagicDNS only answers tailnet members). Forgejo's own 127.0.0.1:3001
# listener stays unreachable from here, by design -- Caddy is the door.
{ lib, ... }:
{
    flake.modules.nixos.forgeRunnerConfiguration = { pkgs, modulesPath, ... }: {
        imports = [
            # DIRECT import, not image.modules -- the image.modules variant
            # builds an extendModules config that never feeds fileSystems/
            # bootloader back into the base config, and checks.nix's forced
            # toplevel dies with "the 'fileSystems' option does not specify
            # your root file system" (lessons-learned §36).
            (modulesPath + "/virtualisation/disk-image.nix")
        ];

        # SeaBIOS/BIOS, matching the generator's machine='pc' domain XML.
        image.efiSupport = false;

        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        system.stateVersion  = "26.11";

        # CI jobs get disk too -- builds, images, node_modules. qcow2 is
        # sparse; 30G virtual costs nothing until used.
        virtualisation.diskSize = 30 * 1024;

        networking = {
            # No `nire-` prefix: that prefix names the fleet machines
            # (hosts.nix explains); this is a component of cube.
            hostName = "forge-runner";
            useDHCP  = lib.mkDefault true;
            firewall.allowedTCPPorts = [ 22 ];

            # Egress policy for job code, enforced LOCALLY (guest iptables
            # OUTPUT): no pivoting to the LAN/NAS/tailnet. A host-side
            # nwfilter was attempted first and abandoned the same day --
            # its out-direction drops in libvirt 12.7 enforce against
            # inbound traffic as well, breaking the guest's own inbound
            # (five rule variants tested, all failing). Residual: VM-root
            # can flush these rules; the hard containment layer is the VM
            # boundary itself. Order is load-bearing: accepts before
            # drops; unmatched traffic falls to the OUTPUT policy (ACCEPT
            # -- the open internet). DHCP is unaffected either way (the
            # client uses packet sockets).
            firewall.extraCommands = ''
                iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                iptables -A OUTPUT -d 192.168.122.1 -p udp --dport 53 -j ACCEPT
                iptables -A OUTPUT -d 192.168.122.1 -p tcp --dport 53 -j ACCEPT
                iptables -A OUTPUT -d 192.168.122.1 -p udp --dport 67 -j ACCEPT
                iptables -A OUTPUT -d 192.168.122.1 -p tcp --dport 443 -j ACCEPT
                iptables -A OUTPUT -d 10.0.0.0/8 -j DROP
                iptables -A OUTPUT -d 172.16.0.0/12 -j DROP
                iptables -A OUTPUT -d 192.168.0.0/16 -j DROP
                iptables -A OUTPUT -d 100.64.0.0/10 -j DROP
            '';

            hosts = {
                # The forge, via Caddy on the virbr0 gateway. WITHOUT this
                # pin the name is unresolvable from the guest (MagicDNS
                # doesn't serve non-tailnet members) and the runner would
                # sit in DNS-retry loops. SNI still matches -- this is a
                # hosts-file trick, not a TLS shortcut.
                "192.168.122.1" = [ "git.moose-micro.ts.net" ];
            };
        };

        boot = {
            # virtiofs share of the runner token, read-only. systemd loads
            # the module and the mount unit comes from the fileSystems
            # entry; the runner unit below is ordered after it via
            # RequiresMountsFor.
            kernelModules = [ "virtiofs" ];

            # The initrd NEEDS these: importing disk-image.nix alone pulls
            # in only the generic hardware-detection module set (ahci,
            # nvme, usb -- no virtio anything), so stage-1 waits forever
            # on /dev/disk/by-label/nixos on a virtio disk and the guest
            # hangs at "Starting initrd.target" (hit on first boot
            # 2026-09-25; the same latent gap llm-sandbox carried, whose
            # boot was never verified). virtio_net is the NIC, virtio_blk
            # the root disk, virtio_pci the bus.
            initrd.availableKernelModules = lib.mkAfter [
                "virtio_pci"
                "virtio_blk"
                "virtio_net"
            ];

            # Eyes on the guest. The generator wires a serial console
            # (pty), but the base image's kernel only talks to VGA unless
            # told otherwise -- without this, a guest that fails to boot
            # fails SILENTLY from the host's `virsh console` (hit on first
            # boot 2026-09-25: guest running, no DHCP lease, vnet1
            # tx_packets=0, console dark).
            kernelParams = [ "console=ttyS0,115200n8" ];
        };

        fileSystems."/mnt/runner-secret" = {
            device  = "runner-secret";
            fsType  = "virtiofs";
            options = [ "ro" "nodev" "nosuid" ];
        };

        # Nix hardening for a CI guest. Jobs are supposed to build what
        # their own lockfiles pin -- these settings close the AD-HOC
        # channels:
        #   - no channels, and no `nixpkgs=flake:nixpkgs` NIX_PATH entry
        #     (setNixPath) -- so `<nixpkgs>` and `nix-shell -p` have
        #     nothing to draw from,
        #   - no flake registry: `flake-registry = ""` drops only the
        #     GLOBAL one; nixosSystem also pins `nixpkgs` in the SYSTEM
        #     registry (/etc/nix/registry.json), which kept
        #     `nixpkgs#pkg` working until setFlakeRegistry went too
        #     (setNixPath requires it). A flake input must now come from
        #     the repo's own lock or a typed full URL,
        #   - no silent fallback to unsandboxed builds, and a ceiling on
        #     hung or runaway ones,
        #   - daily GC so ad-hoc store paths don't accumulate.
        # The daemon-side rule that matters most is the one NOT set: the
        # runner user must never land in nix.settings.trusted-users --
        # a malicious practice repo's flake could then redirect the
        # daemon at an attacker-controlled substituter.
        nix = {
            settings = {
                experimental-features = [ "nix-command" "flakes" ];
                flake-registry        = "";
                sandbox-fallback      = false;
                max-silent-time       = 3600;   # 1h with no output
                timeout               = 14400;  # 4h per build
            };
            channel.enable = false;
            gc = {
                automatic = true;
                dates     = "daily";
                options   = "--delete-older-than 7d";
            };
        };
        nixpkgs.flake = {
            setNixPath       = false;
            setFlakeRegistry = false;
        };

        services.forgejo-runner.instances.forge-runner = {
            enable = true;

            settings = {
                runner = {
                    # The only label: jobs run directly in the VM with
                    # nix in PATH. There is no container runtime in this
                    # guest, so `runs-on: ubuntu-latest`-style container
                    # jobs find no runner here by design.
                    labels = [
                        "nix:host"
                    ];
                };

                server.connections.default = {
                    url = "https://git.moose-micro.ts.net/";

                    # Pinned 2026-09-25, derived from forgejo-runner-secret
                    # (the pairing the forge enforces: first 16 secret chars
                    # as ASCII bytes, google/uuid.FromBytes -- see the cube
                    # module's header for why this cannot ride the same
                    # secrets mechanism as the token).
                    uuid = "30343634-3961-3333-6665-303732653263";
                };
            };

            # The token, over the virtiofs share. nixpkgs renders this as
            # `token_url: file:$CREDENTIALS_DIRECTORY/...` + a
            # LoadCredential of this path, so the value never enters a
            # store path or the guest's config.yaml.
            secrets.server.connections.default.token_url =
                "/mnt/runner-secret/forgejo-runner-secret";

            # `nix:host` jobs get the VM's nix; default list restated (the
            # option replaces, not appends). tar/unzip: setup-* actions
            # extract their toolchain archives with them.
            hostPackages = with pkgs; [
                bash
                coreutils
                curl
                gawk
                gnused
                nodejs
                nix
                gnutar
                unzip
                wget
            ];
        };

        # The runner unit must not start before its credential source is
        # mounted; LoadCredential on a not-yet-mounted path is a hard
        # start failure, and the mount is NOT implicitly ordered before
        # an unrelated service.
        #
        # TRAP: the unit name escapes the instance name -- nixpkgs runs it
        # through utils.escapeSystemdPath, which turns the dash into a
        # literal `\x2d`, so the unit is "forgejo-runner-forge\x2drunner"
        # and targeting the plain "forge-runner" spelling silently creates
        # an EMPTY second unit (caught by reading the rendered unit, not
        # by eval).
        # Sandboxing for the runner unit -- and therefore every job, since
        # host-executor jobs are children of it (nix run included). The
        # filesystem goes read-only except the state dir and private /tmp;
        # kernel interfaces and privilege transitions are closed. This is
        # what bounds an ad-hoc `nix run` of something hostile: it runs,
        # but it cannot write the system, load modules, or flip kernel
        # knobs. Deliberately NOT set: MemoryDenyWriteExecute (breaks
        # node/v8 JIT, which actions need). Network stays open -- the
        # egress policy above is its bound. nixpkgs' unit already sets
        # DynamicUser plus most of the list below; restating those keeps
        # the bound readable here. The last five are the additions:
        # no device nodes beyond the pseudo-devices, an empty capability
        # bounding set, native syscalls only, and no clock or hostname
        # changes.
        systemd.services."forgejo-runner-forge\\x2drunner" = {
            unitConfig.RequiresMountsFor =
                "/mnt/runner-secret";
            serviceConfig = {
                NoNewPrivileges       = true;
                ProtectSystem         = "strict";
                PrivateTmp            = true;
                ProtectKernelTunables = true;
                ProtectKernelModules  = true;
                ProtectKernelLogs     = true;
                ProtectControlGroups  = true;
                RestrictSUIDSGID      = true;
                RestrictRealtime      = true;
                LockPersonality       = true;

                PrivateDevices          = true;
                CapabilityBoundingSet   = "";
                SystemCallArchitectures = "native";
                ProtectClock            = true;
                ProtectHostname         = true;
            };
        };

        # SSH for debugging a headless worker VM (the serial console is the
        # other way, and it is no fun). Reaches the guest through the
        # generator's sshForward DNAT: host port 2223, tailnet-only, to
        # 192.168.122.11:22 -- `ssh -p 2223 root@<cube>`.
        services.openssh = {
            enable = true;
            settings.PasswordAuthentication = false;
        };
        users.users.root.openssh.authorizedKeys.keys = [
            # Duplicated from system/ssh/ssh.nix rather than shared: the
            # guest imports no repo category (importing `system` would pull
            # in tailscaled, sops and the rest, none of which a runner VM
            # wants). Keep the two lists in step, with ONE deliberate
            # exception: the bare `elly@nire-lysithea` key is NOT here --
            # ssh.nix documents it as having no known private half, and a
            # new root login should not be backed by a key nobody can
            # account for. Everything below has a known owner.
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACfyClu9egyamrth/SspY6wPA78o8sJuSR7jyBX42ex elly@nire-lysithea.local"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrut9Gg3TR5omT4yWXBQhifKh6ksT46FWTYA1Gj9YpJ u0_a377@localhost"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFTe27f8e8B4DpqQYHFK7I7Pg3ZK12W7LqIrdI+ChI1 elly@nire-galatea"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqzV9o32OsJdkCfDJhR5X4uSu1nzRzrL/2gBWLp9QyX elly@nire-cube"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFFfyxNzG07CdeNEZof+l49+fqx+2E79gmYvnRqiGdNp elly@nire-tenacity"
            "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFwOpjlybwn/ebH4KKoAcsVQ41wxeqD41CyfIALkV61t8BXV2Wf2pdnrBMxLuHHi9+uq7DlGs2nrW938WtaHvRo= elly@deja"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMbt2aSZdU5732g4yNXo/pOnl2DZDMKKP4cPPHyAcIkF elly@nire-iona-termius"
        ];
    };
}
