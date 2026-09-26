# The Forgejo Actions runner VM -- a NixOS guest on nire-cube, instantiated
# by virtualization-cube.nix through VMs/_lib/libvirt-vm.nix. This file is
# the guest's whole config; cube-side support (the per-job registration,
# the share staging, the cycle that recreates this guest after every job)
# lives in git-forge/forgejo/actions-runner.nix.
#
# Why a VM at all: a CI runner executes workflow code, and workflow code on
# a runner with podman/docker access is one container escape away from the
# host. On cube that escape would land root access to everything sops
# decrypts there; in here it lands a VM that runs ONE job and is then
# thrown away -- GitHub's ephemeral-runner model. The only secret it ever
# holds is that one job's single-use runner token.
#
# The guest deliberately runs NO sops-nix, no Home Manager, and no user
# account -- same shape llm-sandbox used. Its secret arrives over virtiofs
# (tag `runner-secret`, read-only on the host side and mounted read-only
# at /mnt/runner-secret), staged there by cube for this boot only; the
# mount is the guest's entire trust surface from the host side.
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

            # Public resolvers, and the DHCP-offered one ignored: cube's
            # dnsmasq forwards to cube's own resolver, which is MagicDNS
            # and would answer for tailnet names. cube drops guest DNS on
            # its side too (vm-networking.nix). The forge's name comes
            # from the /etc/hosts pin below, not DNS.
            nameservers = [ "9.9.9.9" "1.1.1.1" ];
            dhcpcd.extraConfig = "nooption domain_name_servers, domain_name, domain_search";

            # Egress policy for job code, enforced LOCALLY (guest iptables
            # OUTPUT): no pivoting to the LAN/NAS/tailnet. A host-side
            # nwfilter was attempted first and abandoned the same day --
            # its out-direction drops in libvirt 12.7 enforce against
            # inbound traffic as well, breaking the guest's own inbound
            # (five rule variants tested, all failing). VM-root can flush
            # these, so cube repeats the private-range and tailnet drops
            # on its own side (vm-networking.nix). Order is load-bearing: accepts before
            # drops; unmatched traffic falls to the OUTPUT policy (ACCEPT
            # -- the open internet). DHCP is unaffected either way (the
            # client uses packet sockets).
            firewall.extraCommands = ''
                iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
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

            # Kernel surface job code doesn't need: unprivileged BPF,
            # ptrace outside CAP_SYS_PTRACE (so one job can't read another
            # process's memory, the runner daemon's included), and kernel
            # pointers/dmesg for non-root. Unprivileged user namespaces
            # stay on here -- nix-daemon's build sandbox uses them -- and
            # are closed per-unit instead (RestrictNamespaces below).
            kernel.sysctl = {
                "kernel.unprivileged_bpf_disabled" = 1;
                "kernel.yama.ptrace_scope"         = 2;
                "kernel.kptr_restrict"             = 2;
                "kernel.dmesg_restrict"            = 1;
            };
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
        #     (setNixPath requires it),
        #   - no silent fallback to unsandboxed builds, a ceiling on
        #     hung or runaway ones, and GC during builds before the disk
        #     fills,
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
                # 30G overlay: collect garbage mid-build below 2G free,
                # up to 6G free.
                min-free              = 2 * 1024 * 1024 * 1024;
                max-free              = 6 * 1024 * 1024 * 1024;
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

        # The runner: ONE job per boot, then the guest powers off and cube
        # recreates it from the base image with a new single-use
        # registration (git-forge/forgejo/actions-runner.nix's
        # forge-runner-cycle). A hand-written unit rather than nixpkgs'
        # services.forgejo-runner: that module asserts a
        # `server.connections` entry and writes it into config.yaml, and
        # `one-job` refuses a config that defines a connection when its
        # own --url/--uuid/--token-url are given ("server connection
        # conflict", internal/app/cmd/args.go). Daemon mode, what the
        # module runs, refuses ephemeral runners outright
        # (internal/app/cmd/daemon.go). The module was used until
        # 2026-09-26, as instance `forge-runner` -- unit
        # "forgejo-runner-forge\x2drunner" (utils.escapeSystemdPath).
        #
        # The share holds this boot's 40-hex secret. Its UUID is derived
        # the way Forgejo derives it (models/actions/forgejo.go: the first
        # 16 characters as raw ASCII bytes, google/uuid.FromBytes), so
        # nothing about the runner's identity is baked into this config.
        #
        # SuccessAction/FailureAction power the guest off when the job
        # ends, or when the runner fails to start: systemd (PID 1) does
        # it, so the job's own sandbox needs no power to. cube sees the
        # domain shut off and starts the next cycle.
        systemd.services.forgejo-runner = let
            # Only `runner` and `cache` -- the connection comes from the
            # command line (see above).
            runnerConfig = (pkgs.formats.yaml { }).generate "forgejo-runner.yaml" {
                # One job at a time. one-job takes exactly one anyway.
                runner.capacity = 1;
                # No actions cache server: nothing here uses
                # `actions/cache`, and a fresh guest per job has nothing to
                # share. Turn it on per need.
                cache.enabled = false;
            };
            start = pkgs.writeShellScript "forgejo-runner-one-job" ''
                set -euo pipefail
                secret_file="$CREDENTIALS_DIRECTORY/runner-secret"
                secret="$(${pkgs.coreutils}/bin/head -c 16 "$secret_file")"
                hex="$(printf '%s' "$secret" | ${pkgs.coreutils}/bin/od -An -tx1 | ${pkgs.coreutils}/bin/tr -d ' \n')"
                uuid="''${hex:0:8}-''${hex:8:4}-''${hex:12:4}-''${hex:16:4}-''${hex:20:12}"
                exec ${lib.getExe pkgs.forgejo-runner} one-job --wait \
                    --config ${runnerConfig} \
                    --url https://git.moose-micro.ts.net/ \
                    --uuid "$uuid" \
                    --token-url "file:$secret_file" \
                    --label nix:host
            '';
        in {
            description = "Forgejo Runner (one job, then power off)";
            wants    = [ "network-online.target" ];
            after    = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];

            # TRAP: `--label nix:host` is the label `nix` run by the `host`
            # executor. Workflows say `runs-on: nix`; `runs-on: nix:host`
            # matches nothing and the job sits in "Waiting" forever (the
            # first real run, 2026-09-26, did exactly that). No container
            # runtime in this guest, so `ubuntu-latest`-style container
            # jobs find no runner here by design.

            # The credential source must be mounted first: LoadCredential
            # on a not-yet-mounted path is a hard start failure, and the
            # mount is NOT implicitly ordered before an unrelated service.
            unitConfig = {
                RequiresMountsFor = "/mnt/runner-secret";
                SuccessAction     = "poweroff";
                FailureAction     = "poweroff";
            };

            environment.HOME = "/var/lib/forgejo-runner";
            # What `runs-on: nix` jobs find in PATH. tar/unzip: setup-*
            # actions extract their toolchain archives with them. git: the
            # runner itself uses it (nixpkgs' module always added it).
            path = with pkgs; [
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
                gitMinimal
            ];

            # Sandboxing for the runner unit -- and therefore every job,
            # since host-executor jobs are children of it. The filesystem
            # goes read-only except the state dir and private /tmp; kernel
            # interfaces and privilege transitions are closed: no writing
            # the system, loading modules, or flipping kernel knobs.
            # Deliberately NOT set: MemoryDenyWriteExecute (breaks node/v8
            # JIT, which actions need). Network stays open -- the egress
            # policy above, and cube's, are its bound.
            serviceConfig = {
                ExecStart        = start;
                Restart          = "no";
                DynamicUser      = true;
                StateDirectory   = "forgejo-runner";
                WorkingDirectory = "/var/lib/forgejo-runner";
                # DynamicUser's state dir is mounted noexec otherwise, and
                # host jobs run scripts from it.
                ExecPaths        = [ "/var/lib/forgejo-runner" ];
                LoadCredential   = "runner-secret:/mnt/runner-secret/forgejo-runner-secret";

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

                # No new namespaces of any kind (most guest-kernel local
                # privilege escalations go through unprivileged user
                # namespaces), and sockets limited to what node, git and
                # nix's client use.
                RestrictNamespaces      = true;
                RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
            };
        };

        # SSH for debugging a headless worker VM (the serial console is the
        # other way, and it is no fun). From cube only: `ssh forge-runner`
        # on cube (actions-runner.nix's alias), or `ssh -t ts-cube ssh
        # forge-runner` from elsewhere. Only cube's key is trusted,
        # so guest access is never wider than access to cube itself, and
        # there is no tailnet port forward (virtualization-cube.nix).
        # Until 2026-09-25 this list was the whole fleet's (duplicated from
        # system/ssh/ssh.nix), reached through a tailnet DNAT on port 2223.
        services.openssh = {
            enable = true;
            settings.PasswordAuthentication = false;
        };
        users.users.root.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILqzV9o32OsJdkCfDJhR5X4uSu1nzRzrL/2gBWLp9QyX elly@nire-cube"
        ];
    };
}
